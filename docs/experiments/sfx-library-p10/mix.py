"""Reproducible real-source-only P10 audio lab. Run from this folder."""
from pathlib import Path
import subprocess as sp, zipfile, json, hashlib, csv
import numpy as np
from scipy.signal import butter,sosfilt,resample_poly
SR=48000
root=Path(__file__).parent
src=root/'originals'; stems=root/'stems'; mixes=root/'mixes'
stems.mkdir(exist_ok=True); mixes.mkdir(exist_ok=True)
packs={
 'a':('100-CC0-SFX_0.zip','100-cc0-sfx','rubberduck'),
 'b':('sfx_100_v2.zip','100-cc0-sfx-2','rubberduck'),
 'm':('100-CC0-wood-metal-SFX.zip','100-cc0-metal-and-wood-sfx','rubberduck'),
 'w':('water-splash-slime-sfx.zip','40-cc0-water-splash-slime-sfx','rubberduck'),
 'bell':(None,'bell-dingschimes','PWL'),
 'coin':(None,'coin-drop','Vinrax')}
catalog={
 'wood_latch_01':('m','lock_open_01.ogg','木箱锁扣'),
 'wood_latch_02':('b','sfx100v2_lock_open_01.ogg','木箱锁扣'),
 'wood_open_01':('a','wooded_box_open.ogg','木箱开盖'),
 'wood_open_02':('m','wood_squeak_01.ogg','木箱合页'),
 'wood_hit_01':('m','wood_slam_01.ogg','木撞'),
 'wood_hit_02':('m','wood_hit_01.ogg','木撞'),
 'glass_01':('a','glass_01.ogg','玻璃碰撞'),
 'glass_02':('b','sfx100v2_glass_03.ogg','玻璃碎响候选'),
 'glass_03':('b','sfx100v2_glass_05.ogg','玻璃碎响候选'),
 'brass_clasp_01':('m','metal_close_01.ogg','金属合拢（铜材质待试听）'),
 'brass_clasp_02':('m','metal_slam_01.ogg','金属碰撞（铜材质待试听）'),
 'metal_resonance_01':('a','gong_01.ogg','大型金属共鸣'),
 'metal_resonance_02':('a','gong_02.ogg','大型金属共鸣'),
 'water_01':('w','splash_09.ogg','潮水飞溅'),
 'water_02':('w','splash_10.ogg','潮水飞溅'),
 'water_air_01':('b','sfx100v2_air_03.ogg','潮汐/气流'),
 'magic_bell_01':('bell','bell_ding1.wav','清亮魔法铃音'),
 'magic_bell_02':('bell','bell_ding2.wav','清亮魔法铃音'),
 'arrival_01':('coin','coin_drop.wav','奖励入仓/金属掉落'),
 'arrival_02':('b','sfx100v2_items_01.ogg','奖励入仓/物件声'),
}
def ff(args, data=None): return sp.run(['ffmpeg','-v','error','-nostdin']+args,input=data,stdout=sp.PIPE,check=True).stdout
def decode(b): return np.frombuffer(ff(['-i','pipe:0','-f','f32le','-ac','1','-ar',str(SR),'pipe:1'], b),np.float32).copy()
def wav(path,x): ff(['-y','-f','f32le','-ar',str(SR),'-ac','1','-i','pipe:0','-c:a','pcm_s24le',str(path)],np.asarray(x,dtype=np.float32).tobytes())
def db(x): return 20*np.log10(max(x,1e-12))
def metrics(x):
 return {'duration_s':round(len(x)/SR,4),'peak_dbfs':round(db(np.max(abs(x))),2),'rms_dbfs':round(db(np.sqrt(np.mean(x*x))),2),'clipped_samples':int((abs(x)>=1).sum())}
def source(group,name):
 pack,slug,author=packs[group]
 if pack:
  with zipfile.ZipFile(src/pack) as z: b=z.read(name)
 else: b=(src/name).read_bytes()
 url='https://opengameart.org/sites/default/files/'+(pack or name)
 return b,url,slug,author
def trim(x):
 # Only remove near-silent lead/tail; preserve 12ms head and 40ms tail.
 rms=np.sqrt(np.convolve(x*x,np.ones(240)/240,'same'))
 active=np.flatnonzero(rms>rms.max()*0.0316)
 if active.size: x=x[max(0,active[0]-576):min(len(x),active[-1]+1920)]
 return x
def fade(x,a=.003,b=.035):
 x=x.copy(); n=min(int(SR*a),len(x)//2); m=min(int(SR*b),len(x)//2)
 if n:x[:n]*=np.linspace(0,1,n,endpoint=True)
 if m:x[-m:]*=np.linspace(1,0,m,endpoint=True)
 return x
def filt(x, hp,lp):
 return sosfilt(butter(2,[hp,lp],fs=SR,btype='bandpass',output='sos'),x)
signals={}; records=[]
for tag,(group,name,role) in catalog.items():
 data,url,slug,author=source(group,name)
 raw=decode(data)
 stem=fade(trim(raw))
 if len(stem)>2*SR: stem=fade(stem[:2*SR],b=.14)
 stem=fade(filt(stem,65,13500),a=.002,b=.008)
 stem *= .7079/max(abs(stem).max(),1e-6)
 wav(stems/(tag+'.wav'),stem); signals[tag]=stem
 records.append(dict(element=tag,role=role,author=author,license='CC0 1.0',original_page='https://opengameart.org/content/'+slug,download=url,original_member=name,sha256=hashlib.sha256(data).hexdigest(),original_duration_s=round(len(raw)/SR,4),**metrics(stem)))
with (root/'elements.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
# Every preview has five frozen event triggers. Separate underlying layers by event.
# (onset, source, max duration, gain in dBFS peak before mix, speed, filter hp/lp)
shared_charge=[(0,'water_air_01',.26,-24, .85,150,6600)]
plans={}
def make(tier,dur,arrival,material,result):
 layers=[]
 for cue, event in [('charge', shared_charge),('material',material),('open',[(.32,'wood_open_01',.26,-13,1.08,110,9000),(.34,'wood_hit_01',.15,-19,1.15,75,6000)]),('result',result),('arrival',[(arrival,'arrival_01',.13,-21,1.25,250,9400)])]:
  ys=[]
  for at,tag,length,gain,speed,hp,lp in event:
   xx=signals[tag]; xx=np.interp(np.arange(0,len(xx),speed),np.arange(len(xx)),xx)
   xx=filt(xx,hp,lp)[:int(length*SR)];xx=fade(xx,a=.003,b=min(.08,length/3))
   xx*=10**(gain/20)/max(abs(xx).max(),1e-6)
   pos=round(at*SR)
   layers.append(dict(cue=cue,at=at,element=tag,max_s=length,peak_target_dbfs=gain,speed=speed,bandpass=[hp,lp],fade_in_s=.003,fade_out_s=min(.08,length/3),used_s=len(xx)/SR))
   ys.append((pos,xx))
  # store independent cue stems from time zero at event boundary
  start=round(event[0][0]*SR)
  end=max(p+len(x) for p,x in ys)
  z=np.zeros(end-start)
  for p,x in ys:z[p-start:p-start+len(x)]+=x
  wav(mixes/f'{tier}_{cue}.wav',z)
  if cue=='charge': y=np.zeros(round(dur*SR))
  for p,x in ys:
   if p<len(y): y[p:min(len(y),p+len(x))]+=x[:len(y)-p]
 y=fade(y,b=.006)
 wav(mixes/f'{tier}_full.wav',y)
 plans[tier]=dict(arrival_s=arrival,layers=layers,**metrics(y))
make('crew',1.35,1.22,[(.12,'wood_latch_01',.2,-19,1.15,120,10000)],[(.34,'water_01',.24,-18,1.05,140,9000),(.40,'magic_bell_02',.42,-24,1.05,350,10000)])
make('relic',1.60,1.47,[(.12,'glass_02',.2,-16,1.3,300,10000)],[(.34,'glass_01',.30,-16,.86,250,12000),(.39,'magic_bell_01',.64,-21,1.12,280,10000),(.52,'water_02',.18,-27,1.12,100,6500)])
make('upgrade',1.85,1.72,[(.12,'brass_clasp_01',.2,-13,.94,110,9000)],[(.34,'metal_resonance_01',.95,-14,.83,65,6500),(.37,'magic_bell_02',.71,-18,.93,450,10500),(.52,'metal_resonance_02',.54,-22,1.1,290,9000),(.57,'glass_03',.24,-24,1.23,700,12000)])
(root/'mix-recipes.json').write_text(json.dumps(plans,ensure_ascii=False,indent=2))
print(json.dumps({k:{x:v[x] for x in ('duration_s','peak_dbfs','rms_dbfs','clipped_samples')} for k,v in plans.items()},indent=2))
# Explicit audition concatenation, not a runtime event.
def readwav(p):return decode(p.read_bytes())
gap=np.zeros(int(.4*SR),dtype=np.float32)
wav(mixes/'comparison_preview.wav',np.concatenate([readwav(mixes/'crew_full.wav'),gap,readwav(mixes/'relic_full.wav'),gap,readwav(mixes/'upgrade_full.wav')]))
