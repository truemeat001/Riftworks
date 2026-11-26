#!/usr/bin/env python3
"""Analyze actual Godot software-mixer bus capture from tests/p08_audio_stress.gd.
Reuses evaluate_audio.py for PCM and standards-based true-peak; no subjective score.
"""
from __future__ import annotations
import argparse,json
from pathlib import Path
import numpy as np
from evaluate_audio import decode, metrics

BUSES=['Alert','Combat','Ambience','Master']
def rms_db(x):return float(20*np.log10(max(1e-12,float(np.sqrt(np.mean(x*x))))))
def band_db(x,rate,lo=150,hi=800):
 y=np.fft.rfft(x*np.hanning(len(x))[:,None],axis=0);fr=np.fft.rfftfreq(len(x),1/rate)
 return float(10*np.log10(max(1e-20,float(np.sum(abs(y[(fr>=lo)&(fr<hi)])**2)))))
def parse(folder):
 r=json.loads((folder/'p08-stress-report.json').read_text());rate=r['rate'];M=r['capture_markers'];Y={}
 for name in BUSES:
  w,actual_rate,bits=decode(folder/f'p08-stress-{name.lower()}.wav');assert actual_rate==rate and bits==16 and w.shape[1]==2
  assert not r['capture_'+name]['discarded'] and not r['capture_'+name]['float_clipped_frames'];Y[name]=w
 def first_on(k0,k1):
  x0=M[k0]['Alert'];x1=M[k1]['Alert'];hits=np.flatnonzero(np.max(abs(Y['Alert'][x0:x1]),axis=1)>10**(-70/20))
  assert len(hits)>0,(folder,k0);return x0+int(hits[0])
 onset=first_on('danger_on','danger_off');priority=first_on('priority_danger_on','priority_end')
 sl=lambda a,b: slice(onset+round(a*rate),onset+round(b*rate))
 # The effect taps are before their respective faders. Verify this directly:
 # stable duck period should reconstruct actual Master input -3dB alert, -10dB combat, -4dB ambience.
 # Least squares checks the real captured electrical relationship. Master fader/mute is downstream of its effect tap.
 s=sl(.2,.7);X=np.column_stack([Y[name][s].reshape(-1) for name in BUSES[:3]])
 y=Y['Master'][s].reshape(-1);g,_,_,_=np.linalg.lstsq(X,y,rcond=None)
 residual=float(np.linalg.norm(y-X@g)/np.linalg.norm(y));fit_db=(20*np.log10(np.abs(g))).tolist()
 assert residual<.02 and np.max(np.abs(np.asarray(fit_db)-np.asarray([-3,-10,-4])))<.5,(folder,residual,fit_db)
 second=sl(.27,.39);alert=Y['Alert'][second]*g[0];background=Y['Combat'][second]*g[1]+Y['Ambience'][second]*g[2]
 second_margin=rms_db(alert)-rms_db(background);second_band=band_db(alert,rate)-band_db(background,rate)
 # Isolated warning captured in scenario A supplies same real mixer signal as template.
 # Projection in second chime interval in saturated scenario B verifies that its waveform survives.
 ps=slice(priority+round(.27*rate),priority+round(.39*rate));a=Y['Alert'][second].reshape(-1);b=Y['Alert'][ps].reshape(-1)
 projection=float(np.dot(a,b)/np.dot(a,a));corr=float(np.dot(a,b)/(np.linalg.norm(a)*np.linalg.norm(b)))
 # Allow 200ms for buffer and actual pause transition, then no active combat/alert.
 def between(bus,a,b,margin=0.0):return Y[bus][M[a][bus]+round(margin*rate):M[b][bus]]
 pause_combat=rms_db(between('Combat','pause_on','pause_off',.20));pause_alert=rms_db(between('Alert','pause_on','pause_off',.20))
 locked=rms_db(between('Master','locked_start','locked_end'))
 # Do NOT judge muted master by its pre-fader capture; check real engine mute flag and document device gap.
 m=metrics(folder/'p08-stress-master.wav');result={
  'capture_rate':rate,'headroom_peak_dbtp':m['true_peak_dbtp'],'master_clip_samples':m['clip_samples'], 'master_duration_ms':m['duration_ms'],
  'fit_fader_db':fit_db,'fit_relative_residual':residual,'danger_second_chime_rms_margin_db':second_margin,'danger_second_chime_150_800Hz_margin_db':second_band,
  'saturated_second_chime_projection':projection,'saturated_second_chime_correlation':corr,'danger_survives_leaks':r['danger_survives_leaks'],'leak_survives':r['damage_survives'],
  'alert_ids_after_leaks':r['priority_active_after_leaks'],'alert_ids_after_low_priority':r['priority_active_after_wave_start'],'low_priority_accepted':r['low_priority_wave_start_accepted'],
  'locked_master_rms_dbfs':locked,'no_autoplay':r['no_autoplay'],'paused_rejects_combat':r['paused_rejects_combat'],'settled_paused_combat_rms_dbfs':pause_combat,'settled_paused_alert_rms_dbfs':pause_alert,
  'mute_flag':r['engine_master_muted'],'unmute_flag':r['engine_master_restored'],'muted_master_capture_is_pre_fader':True,
  'max_voices':r['max_voices'],'dropped_events':r['dropped_events'],'subjective_listening':'NOT_TESTED'}
 # Proposed engineering acceptance for this fixture only, not proven psychoacoustic thresholds.
 result['gate_pass']=all([m['true_peak_dbtp']<=-1,m['clip_samples']==0,second_margin>=2,second_band>=4,projection>=.8,corr>=.7,
    r['danger_survives_leaks'],r['damage_survives'],not r['low_priority_wave_start_accepted'],locked<=-80,r['no_autoplay'],r['paused_rejects_combat'],pause_combat<=-60,pause_alert<=-60,r['engine_master_muted'],r['engine_master_restored'],r['max_voices']['Combat']<=6])
 return result

def main():
 p=argparse.ArgumentParser();p.add_argument('baseline',type=Path);p.add_argument('candidate',type=Path);p.add_argument('--output',type=Path);a=p.parse_args()
 report={'baseline':parse(a.baseline),'candidate':parse(a.candidate),'limit':'Controller stress directly invokes genuine audio events with synthetic x2-equivalent schedule; not a real campaign nor browser speaker audition. Capture is actual software mixer electrical signal; mute is verified flag, Master capture is pre-fader. Spectral margins are descriptive project gates, not proven perception.'}
 s=json.dumps(report,indent=2);print(s)
 if a.output:a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(s+'\n')
 return 0 if report['candidate']['gate_pass'] else 1
if __name__=='__main__':raise SystemExit(main())
