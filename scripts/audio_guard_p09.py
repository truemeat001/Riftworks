#!/usr/bin/env python3
"""Original P09 guard interception cue. Reuses synthesis/verification helpers; no recordings or paid assets."""
from pathlib import Path
import argparse, hashlib, json, math
import numpy as np
from make_audio_p07 import RATE, time, ring, noise, wood, metal, add, taper, write_pcm, read_pcm
from evaluate_audio import metrics, decode
ROOT=Path(__file__).resolve().parents[1]
P07=ROOT/'docs/audio-p07-manifest.json'
P09=ROOT/'docs/audio-p09-manifest.json'
NEW_EVENT='hit_intercept'
DURATION=.24
SOURCE_PEAK_DBFS=-10.0
MASTER=ROOT/'assets/audio/master';RUNTIME=ROOT/'assets/audio/runtime'

def source(v):
    rng=np.random.default_rng(90926+101*v);j=1+(v-2)*.035
    y=np.zeros(len(time(DURATION)))
    # A dry deflect: shell edge impulse, muted copper plate resonance, brief ceramic scrape.
    # Not an alarm, coin/loot chime, music, or a second attack.
    add(y,.001,wood(.23,rng,170*j),.48)
    add(y,.005,ring(.225,615*j,.047,(1,1.68,2.56,3.82),(1,.42,.24,.07),.001,glide=-110),.81)
    add(y,.013,noise(.18,rng,1150,5600,.026,.002),.32)
    add(y,.032,ring(.20,1320*j,.024,(1,1.52,2.15),(1,.28,.10),.001,glide=-220),.49)
    add(y,.060,noise(.16,rng,480,2180,.047,.008),.20)
    y=taper(y,5);return y*(10**(SOURCE_PEAK_DBFS/20)/max(np.max(np.abs(y)),1e-12))

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def records(generate):
    base=json.loads(P07.read_text());out=[]
    for r in base:
        assert digest(ROOT/r['runtime'])==r['runtime_sha256'] and digest(ROOT/r['master'])==r['master_sha256'],f"P07 source changed: {r['event']}:{r['variant']}"
    for v in range(1,4):
        name=f'sfx_{NEW_EVENT}_{v:02d}.wav';m=MASTER/name;p=RUNTIME/name
        if generate:
            y=source(v);write_pcm(m,y,24);write_pcm(p,y,16)
        y,f=read_pcm(m);x,q=read_pcm(p)
        assert f==(RATE,3,1,round(DURATION*RATE)) and q==(RATE,2,1,round(DURATION*RATE))
        assert np.max(abs(x-y))<1/32767 and np.isfinite(x).all()
        peak=20*np.log10(np.max(abs(x)));rms=20*np.log10(np.sqrt(np.mean(x*x)))
        out.append({'event':NEW_EVENT,'variant':v,'seed':90926+101*v,'bus':'Combat','loop':False,'seconds':DURATION,'frames':len(x),'channels':1,'sample_rate':RATE,'master_bits':24,'runtime_bits':16,'master':str(m.relative_to(ROOT)),'runtime':str(p.relative_to(ROOT)),'master_sha256':digest(m),'runtime_sha256':digest(p),'peak_dbfs':round(float(peak),3),'rms_dbfs':round(float(rms),3),'loop_seam_delta':None})
    merged=base+out
    if generate:P09.write_text(json.dumps(merged,indent=2)+'\n')
    assert merged==json.loads(P09.read_text()),'P09 complete manifest differs'
    return base,out

def verify(base,new):
    measured=[]
    for r in new:
        x=metrics(ROOT/r['runtime'],False);assert x['true_peak_dbtp']<=-3 and x['clip_samples']==0 and x['rms_dbfs']>-65 and x['onset_ms'] is not None
        measured.append({'event':r['event'],'variant':r['variant'],**x})
    spread=max(v['rms_dbfs'] for v in measured)-min(v['rms_dbfs'] for v in measured);assert spread<=3
    old_type=[]
    for r in base:
        if r['event'] in ['hit_pulse','hit_frost','hit_burst','danger']:
            m=metrics(ROOT/r['runtime']);old_type.append({'event':r['event'],'variant':r['variant'],'true_peak_dbtp':m['true_peak_dbtp'],'rms_dbfs':m['rms_dbfs'],'onset_centroid_hz':m['onset_centroid_hz'],'rise_ms':m['rise_to_rms_apex_ms'],'tail_ms':m['tail_from_apex_ms']})
    # Audition-ready unnormalized sequence: P07 pulse, frost, burst, three P09 guard variations.
    review=np.zeros(RATE*6)
    samples=[next(r for r in base if r['event']==e and r['variant']==1) for e in ['hit_pulse','hit_frost','hit_burst']]+new
    for i,r in enumerate(samples):
        v,_,_=decode(ROOT/r['runtime']);assert v.shape[1]==1;review[i*RATE:i*RATE+len(v)]=v[:,0]
    path=ROOT/'docs/audio-guard-preview-p09.wav';write_pcm(path,review,16)
    result={'preserved_p07_pairs':len(base),'new_pairs':len(new),'asset_gate_pass':True,'new_metrics':measured,'variant_rms_spread_db':spread,'baseline_comparison':old_type,'preview':str(path.relative_to(ROOT)),'preview_order':['pulse','frost','burst','guard01','guard02','guard03'],'preview_sha256':digest(path),'listening':'NOT_TESTED'}
    (ROOT/'docs/audio-guard-metrics-p09.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

def main():
    p=argparse.ArgumentParser();p.add_argument('--verify-only',action='store_true');a=p.parse_args()
    base,new=records(not a.verify_only);verify(base,new)
if __name__=='__main__':main()
