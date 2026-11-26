#!/usr/bin/env python3
"""Original reproducible Riftworks P07 Foley-style synthesis, no source recordings/API."""
from pathlib import Path
import wave, hashlib, json
import numpy as np
from scipy.signal import butter, sosfilt

RATE=48000
ROOT=Path(__file__).resolve().parents[1]
MASTER=ROOT/'assets/audio/master'; RUNTIME=ROOT/'assets/audio/runtime'
MASTER.mkdir(parents=True,exist_ok=True);RUNTIME.mkdir(parents=True,exist_ok=True)
(MASTER/'.gdignore').write_text('')
SEED=70926

def time(d): return np.arange(round(d*RATE))/RATE

def taper(x, ms=6):
    y=x.copy(); n=min(round(ms*RATE/1000),len(y)//2)
    if n: y[:n]*=np.linspace(0,1,n).reshape((-1,)+(1,)*(y.ndim-1)); y[-n:]*=np.linspace(1,0,n).reshape((-1,)+(1,)*(y.ndim-1))
    return y

def env(t,decay,attack=.001):return np.minimum(t/max(attack,1/RATE),1)*np.exp(-t/decay)

def ring(d,f,decay,partials=(1,2.1,3.7),weights=(1,.45,.18),attack=.001,glide=0):
    t=time(d);phase=2*np.pi*(f*t+glide*t*t/2)
    return env(t,decay,attack)*sum(w*np.sin(phase*p) for p,w in zip(partials,weights))

def noise(d,rng,low,high,decay=.04,attack=.001,rise=False):
    t=time(d);x=sosfilt(butter(2,[low,high],fs=RATE,btype='bandpass',output='sos'),rng.standard_normal(len(t)))
    x/=max(np.max(np.abs(x)),1e-9)
    e=np.sin(np.pi*t/d/2)**1.7 if rise else env(t,decay,attack)
    return x*e

def wood(d,rng,f=160):
    return .68*ring(d,f,.042,(1,1.77,2.63),(.9,.35,.15),glide=-30)+.62*noise(d,rng,200,2800,.022)

def metal(d,rng,f=780):
    return .72*ring(d,f,.085,(1,1.48,2.43,3.82),(1,.46,.2,.09))+.32*noise(d,rng,1800,6200,.015)

def add(out,at,y,gain=1):
    i=round(at*RATE);n=min(len(y),len(out)-i)
    if n>0:out[i:i+n]+=gain*y[:n]

def event(name,d,rng,variant):
    y=np.zeros(len(time(d)));j=1+(variant-1)*.026
    if name=='chest_charge':
        add(y,.008,metal(.12,rng,520),.32);add(y,.048,wood(.13,rng,110),.24);add(y,.09,noise(.23,rng,280,2600,rise=True),.28)
        add(y,.11,ring(.21,240,.20,(1,2,3),(.8,.24,.04),.09,glide=880),.35)
    elif name=='chest_open':
        add(y,.002,wood(.22,rng,138*j),.95);add(y,.026,metal(.23,rng,610*j),.38);add(y,.047,noise(.20,rng,440,4900,.045),.31);add(y,.093,wood(.18,rng,99*j),.3)
    elif name=='loot_crew':
        add(y,.01,ring(.30,523,.12,(1,2.0,3.02),(1,.16,.055)),.78);add(y,.084,ring(.27,659,.13,(1,2.0,3.02),(1,.2,.05)),.45);add(y,.003,wood(.09,rng,330),.20)
    elif name=='loot_relic':
        add(y,.005,metal(.44,rng,880),.32);add(y,.018,ring(.49,784,.18,(1,2.01,2.76,4.06),(1,.22,.18,.07)),.53);add(y,.10,ring(.40,1175,.15,(1,2.02,3.04),(1,.2,.095)),.30);add(y,.20,ring(.31,1568,.11,(1,2.01),(1,.12)),.15)
    elif name=='loot_upgrade':
        add(y,.002,wood(.19,rng,115),.32);add(y,.01,metal(.55,rng,392),.58)
        for at,f,g in [(0.01,392,.68),(.072,523,.46),(.14,659,.43),(.223,784,.37),(.30,1046,.15)]:add(y,at,ring(.65-at,f,.20,(1,2,3.1,4.25),(1,.32,.08,.04)),g)
    elif name=='loot_arrive':add(y,.001,wood(.10,rng,280),.75);add(y,.021,metal(.07,rng,920),.22)
    elif name=='ui_press':add(y,.001,wood(.078,rng,290),.70)
    elif name=='ui_reject':add(y,.002,ring(.12,275,.036,(1,1.51,2.1),(1,.3,.11),glide=-800),.8);add(y,.005,noise(.08,rng,240,1500,.018),.25)
    elif name=='deploy':add(y,.002,wood(.15,rng,130*j),.86);add(y,.02,noise(.13,rng,600,2500,.029),.34)
    elif name=='recall':add(y,.001,noise(.14,rng,650,3500,.05,.012),.54);add(y,.002,ring(.14,440,.05,(1,2.1),(1,.21),glide=-1050),.58)
    elif name=='merge':
        add(y,.002,wood(.20,rng,120),.36);add(y,.045,ring(.30,392,.10),.37);add(y,.10,ring(.32,587,.13,(1,2,3.02),(1,.34,.06)),.66);add(y,.18,ring(.23,784,.095,(1,2.2),(1,.2)),.42)
    elif name=='sell':add(y,.001,metal(.23,rng,1050),.65);add(y,.06,metal(.16,rng,1270),.42)
    elif name=='wave_start':
        add(y,.0,noise(.6,rng,110,850,.27,.06),.45);add(y,.055,ring(.57,82,.19,(1,2.05,3.02),(1,.60,.14),.06,glide=-25),.74);add(y,.19,wood(.35,rng,137),.42)
    elif name=='hit_pulse':
        add(y,.001,ring(.14,330*j,.028,(1,2.3,3.1),(1,.45,.12),glide=-950),.67);add(y,.001,noise(.13,rng,650,4500,.025),.52);add(y,.017,wood(.09,rng,165*j),.19)
    elif name=='hit_frost':
        add(y,.0,noise(.20,rng,1000,6500,.067,.006),.72);add(y,.012,ring(.18,1450*j,.07,(1,1.73,2.59),(1,.22,.11)),.52);add(y,.055,ring(.14,990*j,.04,(1,2.13),(1,.26)),.26)
    elif name=='hit_burst':
        add(y,.001,wood(.25,rng,85*j),.94);add(y,.001,noise(.23,rng,100,1900,.075),.76);add(y,.035,noise(.18,rng,900,4700,.040),.38)
    elif name=='kill':add(y,.0,noise(.18,rng,410,4200,.045),.75);add(y,.017,wood(.16,rng,105*j),.32)
    elif name=='conductive':add(y,.0,noise(.17,rng,900,6700,.04,.002),.47);add(y,.008,ring(.15,780*j,.039,(1,2.7,3.5),(1,.32,.1),glide=360),.52)
    elif name=='shatter':add(y,.0,noise(.22,rng,1700,8400,.047),.65);add(y,.012,ring(.2,1650*j,.056,(1,2.61,3.54),(1,.19,.07)),.45)
    elif name=='danger':
        add(y,.003,metal(.54,rng,297),.8);add(y,.27,metal(.50,rng,297),.72);add(y,.009,ring(.56,149,.20,(1,2.0,3.1),(1,.4,.1)),.42)
    elif name=='leak':add(y,.003,wood(.36,rng,83),.95);add(y,.03,noise(.33,rng,150,1150,.094),.76);add(y,.03,ring(.30,235,.08,(1,1.47),(1,.34),glide=-230),.22)
    elif name=='wave_clear':
        for at,f,g in [(0,392,.6),(.10,523,.48),(.20,659,.40)]:add(y,at,ring(.56-at,f,.17,(1,2,3.05),(1,.23,.1)),g)
    elif name=='victory':
        for at,f,g in [(0,392,.7),(.09,494,.52),(.18,587,.48),(.27,784,.47),(.34,987,.29)]:add(y,at,ring(.95-at,f,.26,(1,2,3.1),(1,.29,.08)),g)
        add(y,.0,wood(.22,rng,120),.26)
    elif name=='defeat':
        for at,f,g in [(0,392,.48),(.14,311,.54),(.28,196,.48)]:add(y,at,ring(.78-at,f,.22,(1,2.05,3.1),(1,.23,.06)),g)
        add(y,0,noise(.72,rng,130,600,.22,.012),.25)
    else:raise ValueError(name)
    return taper(y,5)

def circular_noise(d,rng,lo,hi):
    n=len(time(d));freq=np.fft.rfftfreq(n,1/RATE);f=np.maximum(freq,1e-7)
    amp=(1/(1+(lo/f)**8))**.5*(1/(1+(f/hi)**8))**.5
    fft=np.fft.rfft(rng.standard_normal(n));fft*=amp;fft[0]=0
    y=np.fft.irfft(fft,n);return y/max(np.sqrt(np.mean(y*y)),1e-9)

def ambient(d,rng,combat=False):
    t=time(d);phase=2*np.pi*t/d;s=[]
    shared=circular_noise(d,rng,105,1050);higher=circular_noise(d,rng,850,4000)
    for ch in range(2):
        foam=circular_noise(d,rng,600,4700);base=(.53+.26*np.sin(phase*4+ch*.3)+.11*np.sin(phase*7+.6))*shared
        y=base*.30 + higher*.13*(.55+.35*np.sin(phase*5+ch*.5)) + foam*.12*(.6+.25*np.sin(phase*6+ch*.6))
        if combat:
            # Subtle periodic broad sea swell, not fake countdown or enemy count.
            y+=.10*circular_noise(d,rng,55,260)*(.5+.2*np.sin(phase*4))
            y+=.035*np.sin(phase*433)*(.5+.4*np.sin(phase*2+.5))
        s.append(y)
    return np.stack(s,axis=1)

# Event durations, variation counts, target sample peak dBFS, bus.
SPECS={
'chest_charge':(.32,1,-12,'UI'),'chest_open':(.30,3,-8,'UI'),'loot_crew':(.36,1,-10,'UI'),'loot_relic':(.52,1,-8,'UI'),'loot_upgrade':(.65,1,-6,'UI'),'loot_arrive':(.10,1,-14,'UI'),
'ui_press':(.08,1,-18,'UI'),'ui_reject':(.14,1,-12,'UI'),'deploy':(.16,3,-13,'UI'),'recall':(.14,1,-16,'UI'),'merge':(.44,1,-9,'UI'),'sell':(.24,1,-14,'UI'),
'wave_start':(.65,1,-9,'Alert'),'hit_pulse':(.14,3,-12,'Combat'),'hit_frost':(.20,3,-13,'Combat'),'hit_burst':(.26,3,-10,'Combat'),'kill':(.2,3,-15,'Combat'),'conductive':(.18,3,-15,'Combat'),'shatter':(.22,3,-14,'Combat'),
'danger':(.82,1,-7,'Alert'),'leak':(.36,1,-9,'Alert'),'wave_clear':(.58,1,-10,'UI'),'victory':(.95,1,-7,'UI'),'defeat':(.80,1,-10,'UI'),
'ambience_sea':(12,1,-18,'Ambience'),'ambience_battle':(12,1,-19,'Ambience')}

def write_pcm(p,x,bits):
    lim=(1<<(bits-1))-1;z=np.rint(np.clip(x,-1,1)*lim).astype(np.int32)
    if bits==16:data=z.astype('<i2').tobytes()
    else:
        zz=z.reshape(-1);data=np.stack([zz&255,(zz>>8)&255,(zz>>16)&255],axis=1).astype(np.uint8).tobytes()
    with wave.open(str(p),'wb') as w:w.setnchannels(1 if x.ndim==1 else x.shape[1]);w.setsampwidth(bits//8);w.setframerate(RATE);w.writeframes(data)

def file_hash(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    rec=[]
    for idx,(name,(d,n,db,bus)) in enumerate(SPECS.items()):
        for v in range(1,n+1):
            seed=SEED+idx*101+v; rng=np.random.default_rng(seed)
            loop=name.startswith('ambience_');x=ambient(d,rng,name=='ambience_battle') if loop else event(name,d,rng,v)
            assert np.isfinite(x).all() and np.max(np.abs(x))>0
            x=x*(10**(db/20)/np.max(np.abs(x)))
            stem=(name+'_loop') if loop else f'sfx_{name}_{v:02d}'
            m=MASTER/(stem+'.wav');p=RUNTIME/(stem+'.wav')
            write_pcm(m,x,24);write_pcm(p,x,16)
            peak=float(np.max(np.abs(x)));rms=float(np.sqrt(np.mean(x*x)))
            rec.append({'event':name,'variant':v,'seed':seed,'bus':bus,'loop':loop,'seconds':d,'frames':len(x),'channels':1 if x.ndim==1 else 2,'sample_rate':RATE,'master_bits':24,'runtime_bits':16,'master':str(m.relative_to(ROOT)),'runtime':str(p.relative_to(ROOT)),'master_sha256':file_hash(m),'runtime_sha256':file_hash(p),'peak_dbfs':round(20*np.log10(peak),3),'rms_dbfs':round(20*np.log10(rms),3),'loop_seam_delta':float(np.max(np.abs(x[0]-x[-1]))) if loop else None})
    (ROOT/'docs'/'audio-p07-manifest.json').write_text(json.dumps(rec,indent=2)+'\n')
    print('generated',len(rec),'WAV masters and runtime copies')
def read_pcm(p):
    with wave.open(str(p),'rb') as w:
        fmt=(w.getframerate(),w.getsampwidth(),w.getnchannels(),w.getnframes()); raw=w.readframes(w.getnframes())
    if fmt[1]==2:y=np.frombuffer(raw,'<i2').astype(np.float64)/32767
    else:
        b=np.frombuffer(raw,'u1').reshape(-1,3).astype(np.int32)
        n=b[:,0]|(b[:,1]<<8)|(b[:,2]<<16);n=np.where(n&0x800000,n-(1<<24),n)
        y=n.astype(np.float64)/8388607
    return y.reshape(-1,fmt[2]),fmt

def verify():
    import re, ast
    records=json.loads((ROOT/'docs/audio-p07-manifest.json').read_text())
    x={};diff_max=0;peak_max=-100;loop_checks=[]
    for r in records:
        p=ROOT/r['runtime'];m=ROOT/r['master'];rv,rf=read_pcm(p);mv,mf=read_pcm(m)
        assert file_hash(p)==r['runtime_sha256'] and file_hash(m)==r['master_sha256']
        assert rf==(RATE,2,r['channels'],r['frames']) and mf==(RATE,3,r['channels'],r['frames'])
        assert np.isfinite(rv).all() and 0<np.max(abs(rv))<10**(-3/20)
        err=float(np.max(abs(rv-mv)));diff_max=max(err,diff_max);assert err<1/32767
        peak_max=max(peak_max,20*np.log10(np.max(abs(rv))))
        if r['loop']:
            seam=np.abs(rv[0]-rv[-1]);q=np.quantile(abs(np.diff(rv,axis=0)),.95,axis=0)
            loop_checks.append({'event':r['event'],'seam':seam.tolist(),'p95_adjacent':q.tolist(),'pass':bool(np.all(seam<=q))});assert np.all(seam<=q)
        else:assert np.max(abs(rv[0]))<.0001 and np.max(abs(rv[-1]))<.0001
        x[(r['event'],r['variant'])]=rv
    # Reflect the actual controller gain constants rather than testing normalized files only.
    source=(ROOT/'src/GameAudio.gd').read_text()
    base=ast.literal_eval(re.search(r'const BASE_DB=(\{[^\n]+\})',source)[1]);gain=ast.literal_eval(re.search(r'const EVENT_GAIN=(\{[^\n]+\})',source)[1]);bus={r['event']:r['bus'] for r in records}
    lin=lambda db:10**(db/20)
    def insert(dst,ev,at,n=1,duck=False):
        a=x[(ev,n)];a=np.repeat(a,2,axis=1) if a.shape[1]==1 else a
        trim=base['Master']+base[bus[ev]]+(base['SFX'] if bus[ev] in ['UI','Combat','Alert'] else 0)+gain.get(ev,0)+(-4 if duck and bus[ev]=='Combat' else 0)
        i=round(at*RATE);length=min(len(a),len(dst)-i);dst[i:i+length]+=a[:length]*lin(trim)
    loot_peaks=[];preview=np.zeros((RATE*6,2))
    for i,name in enumerate(['loot_crew','loot_relic','loot_upgrade']):
        w=np.zeros((round(RATE*1.35),2))
        for ev,t in [('chest_charge',0),('chest_open',.32),(name,.34),('loot_arrive',1.22)]:insert(w,ev,t,i+1 if ev=='chest_open' else 1)
        peak=20*np.log10(np.max(abs(w)));loot_peaks.append({'result':name,'peak_dbfs':peak});preview[i*RATE*2:i*RATE*2+len(w)]=w;assert peak<-3
    # Simulated capped overlap: all six combat types, two distinct real alerts,
    # both environmental beds, and a UI press, conservative unpanned stereo.
    rng=np.random.default_rng(177);combat=['hit_pulse','hit_frost','hit_burst','kill','conductive','shatter'];peak_mix=-100
    for i in range(250):
        z=np.zeros((RATE*2,2));z+=x[('ambience_sea',1)][:len(z)]*.27*lin(base['Master']+base['Ambience']);z+=x[('ambience_battle',1)][:len(z)]*.55*lin(base['Master']+base['Ambience'])
        for ev in combat:insert(z,ev,float(rng.uniform(0,.13)),int(rng.integers(1,4)),i%2==0)
        insert(z,'danger',float(rng.uniform(0,.13)));insert(z,'leak',float(rng.uniform(0,.13)));insert(z,'ui_press',float(rng.uniform(0,.13)))
        peak_mix=max(peak_mix,20*np.log10(np.max(abs(z))))
    assert peak_mix<-3
    review=ROOT/'docs/audio-review-preview.wav';write_pcm(review,preview,16)
    report={'decoded_pairs':len(records),'maximum_master_runtime_diff':diff_max,'max_source_peak_dbfs':peak_max,'loops':loop_checks,'loot_mix':loot_peaks,'combat_overlap_runs':250,'combat_overlap_peak_dbfs':peak_mix,'preview':str(review.relative_to(ROOT)),'preview_sha256':file_hash(review),'preview_order':['crew (0-1.35s)','relic (2-3.35s)','upgrade (4-5.35s)'],'limitations':'offline mixing with current gain constants, not a real hardware audio audition'}
    (ROOT/'docs/audio-p07-qa.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

if __name__=='__main__':
    import sys
    if '--verify-only' not in sys.argv:main()
    verify()
