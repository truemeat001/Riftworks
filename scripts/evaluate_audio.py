#!/usr/bin/env python3
"""Objective WAV descriptors and regression gate; never a subjective quality score."""
from __future__ import annotations
import argparse, csv, hashlib, json, math, re, subprocess, wave
from pathlib import Path
from collections import defaultdict
import numpy as np

def db(value):
    return float(20*np.log10(max(float(value),1e-12)))

def decode(path):
    with wave.open(str(path),'rb') as w:
        rate,channels,bits,n=w.getframerate(),w.getnchannels(),w.getsampwidth()*8,w.getnframes()
        if w.getcomptype()!='NONE': raise ValueError(f'{path}: not PCM')
        raw=w.readframes(n)
    if bits==16: x=np.frombuffer(raw,dtype='<i2').astype(np.float64)/32768
    elif bits==24:
        a=np.frombuffer(raw,dtype=np.uint8).reshape(-1,3).astype(np.int32)
        v=a[:,0]|a[:,1]<<8|a[:,2]<<16
        v=(v^0x800000)-0x800000
        x=v/8388608.0
    else: raise ValueError(f'{path}: unsupported {bits}-bit PCM')
    if n<=0 or len(x)!=n*channels: raise ValueError(f'{path}: empty/truncated')
    return x.reshape(-1,channels),rate,bits

def spectrum(x,rate):
    if len(x)<2:return np.array([0.]),np.array([0.])
    s=np.abs(np.fft.rfft(x*np.hanning(len(x))[:,None],axis=0))**2
    power=s.sum(axis=1);return np.fft.rfftfreq(len(x),1/rate),power

def ffmpeg_meter(path,seconds):
    # EBU integrated gating uses 400 ms blocks. Never use -70 sentinel as short SFX loudness.
    p=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af','ebur128=peak=true','-f','null','-'],capture_output=True,text=True,check=True)
    summary=p.stderr.rsplit('Summary:',1)[-1]
    peak=re.search(r'True peak:\s*Peak:\s*(-?(?:\d+(?:\.\d+)?|inf))\s*dBFS',summary)
    integ=re.search(r'Integrated loudness:\s*I:\s*(-?\d+(?:\.\d+)?)\s*LUFS',summary)
    if peak is None:raise ValueError(f'No true peak meter result: {path}')
    lu=float(integ.group(1)) if integ else None
    return float(peak.group(1)), lu if seconds>=.4 and lu is not None and lu>-70 else None

def metrics(path,loop=False):
    x,rate,bits=decode(path);duration=len(x)/rate
    peak=float(np.max(np.abs(x)));rms=float(np.sqrt(np.mean(x*x)))
    step=max(1,round(rate*.005)); n=len(x)//step
    env=np.sqrt(np.mean(x[:n*step].reshape(n,step,x.shape[1])**2,axis=(1,2))) if n else np.array([rms])
    apex=int(np.argmax(env));threshold=float(np.max(env))*.1 # -20 dB to peak 5ms RMS
    active=np.flatnonzero(env>=threshold) if threshold>0 else np.array([],dtype=int)
    fr,powf=spectrum(x[:min(len(x),round(rate*.08))],rate)
    centroid=float(np.dot(fr,powf)/np.sum(powf)) if np.sum(powf)>0 else 0.
    fr,powf=spectrum(x,rate)
    total=max(float(np.sum(powf)),1e-24)
    bands=[float(np.sum(powf[(fr>=lo)&(fr<hi)])/total*100) for lo,hi in [(0,150),(150,800),(800,3000),(3000,8000),(8000,rate/2+1)]]
    true_peak,lufs=ffmpeg_meter(path,duration)
    delta=np.abs(np.diff(x,axis=0)); seam=float(np.max(np.abs(x[0]-x[-1]))) if loop else None
    p95=float(np.quantile(delta,.95)) if loop and delta.size else None
    peak_i=int(np.argmax(np.abs(x).max(axis=1)))
    return dict(sample_rate=rate,bits=bits,channels=x.shape[1],frames=len(x),duration_ms=round(duration*1000,3),
      peak_dbfs=round(db(peak),3),true_peak_dbtp=true_peak,rms_dbfs=round(db(rms),3),crest_db=round(db(peak/max(rms,1e-12)),3),
      integrated_lufs=lufs,clip_samples=int(np.sum(np.abs(x)>=(1-1/(2**(bits-1))))),
      peak_time_ms=round(peak_i/rate*1000,3),onset_ms=round(int(active[0])*step/rate*1000,3) if len(active) else None,
      rise_to_rms_apex_ms=round((apex-int(active[0]))*step/rate*1000,3) if len(active) else None,
      tail_from_apex_ms=round((int(active[-1])-apex)*step/rate*1000,3) if len(active) else None,
      trailing_below_threshold_ms=round(max(0,duration-(int(active[-1])+1)*step/rate)*1000,3) if len(active) else None,
      onset_centroid_hz=round(centroid,2),band_0_150_pct=round(bands[0],3),band_150_800_pct=round(bands[1],3),band_800_3000_pct=round(bands[2],3),
      band_3000_8000_pct=round(bands[3],3),band_gt_8000_pct=round(bands[4],3),
      dc_abs_max=round(float(np.max(np.abs(x.mean(axis=0)))),7),loop_seam_delta=round(seam,7) if seam is not None else None,
      loop_adjacent_delta_p95=round(p95,7) if p95 is not None else None,
      loop_seam_ratio_p95=round(seam/max(p95,1e-12),4) if p95 is not None else None)

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('--output',type=Path)
    p.add_argument('--manifest',type=Path,help='Optional version manifest; default preserved P07 baseline')
    p.add_argument('--baseline',type=Path,help='Prior CSV to flag descriptive changes; no auto subjective judgement')
    p.add_argument('--mixed',type=Path,action='append',default=[],help='Optional actual engine recorded mix; evaluated separately')
    a=p.parse_args();root=a.root.resolve();out=a.output or root/'docs/audio-quantitative-p07.csv'
    manifest_path=a.manifest or root/'docs/audio-p07-manifest.json'
    manifest=json.loads(manifest_path.read_text())
    rows=[]; failures=[];warnings=[];groups=defaultdict(list)
    for item in manifest:
        path=root/item['runtime']; m=metrics(path,item['loop'])
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        errors=[]
        if (m['sample_rate'],m['bits'],m['channels'],m['frames'])!=(item['sample_rate'],item['runtime_bits'],item['channels'],item['frames']):errors.append('format_or_duration')
        if digest!=item['runtime_sha256']:errors.append('manifest_hash_mismatch')
        if m['clip_samples'] or m['true_peak_dbtp']>-3:errors.append('headroom')
        if m['rms_dbfs']<-65 or m['onset_ms'] is None:errors.append('silent')
        if item['loop'] and m['loop_seam_ratio_p95']>2:warnings.append(f"{item['event']}: seam ratio >2; listen before modifying")
        row={'event':item['event'],'variant':item['variant'],'bus':item['bus'],'path':item['runtime'],'loop':item['loop'],'sha256':digest,**m,'technical_gate':'PASS' if not errors else ';'.join(errors)}
        rows.append(row);groups[item['event']].append(row)
        for err in errors:failures.append(f'{path.name}: {err}')
    for event,g in groups.items():
        if len(g)>1:
            spread=max(r['rms_dbfs'] for r in g)-min(r['rms_dbfs'] for r in g)
            if spread>3:warnings.append(f'{event}: variant RMS spread {spread:.2f} dB')
    if a.baseline:
        old={(r['event'],r['variant']):r for r in csv.DictReader(a.baseline.open())}
        for r in rows:
            q=old.get((r['event'],str(r['variant'])))
            if not q: warnings.append(f"new event {r['event']}:{r['variant']}");continue
            if abs(r['rms_dbfs']-float(q['rms_dbfs']))>2:warnings.append(f"{r['event']}:{r['variant']} RMS delta >2dB")
            if abs(r['duration_ms']-float(q['duration_ms']))>max(10,.1*float(q['duration_ms'])):warnings.append(f"{r['event']}:{r['variant']} duration changed")
            if abs(r['onset_centroid_hz']-float(q['onset_centroid_hz']))>max(100,.25*float(q['onset_centroid_hz'])):warnings.append(f"{r['event']}:{r['variant']} centroid changed")
    out.parent.mkdir(parents=True,exist_ok=True)
    with out.open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    mix_rows=[]
    for path in a.mixed:
        m=metrics(path)
        # Whole-sequence onset/tail are not sound-event descriptors; leave them out.
        mix_rows.append({'path':path.parent.name+'/'+path.name,**{k:v for k,v in m.items() if k in ('sample_rate','bits','channels','frames','duration_ms','peak_dbfs','true_peak_dbtp','rms_dbfs','integrated_lufs','clip_samples','crest_db')}})
        if m['clip_samples'] or m['true_peak_dbtp']>-1:failures.append(f'{path.name}: mixed headroom')
    summary={'assets':len(rows),'technical_pass':sum(r['technical_gate']=='PASS' for r in rows),'failures':failures,'review_warnings':warnings,
             'worst_asset_true_peak_dbtp':max(r['true_peak_dbtp'] for r in rows),'clip_samples_total':sum(r['clip_samples'] for r in rows),
             'lufs_unavailable_short_or_gated':sum(r['integrated_lufs'] is None for r in rows),'actual_engine_mix':mix_rows,
             'subjective_listening':'NOT_TESTED','limits':'thresholds are Riftworks engineering suggestions, not universal psychoacoustic quality scores; LUFS omitted under 400 ms; true peak uses FFmpeg ebur128; spectral centroid uses 80 ms power spectrum.'}
    out.with_suffix('.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(summary,indent=2,ensure_ascii=False))
    return 1 if failures else 0
if __name__=='__main__':raise SystemExit(main())
