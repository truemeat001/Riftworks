#!/usr/bin/env python3
"""Prepare randomized blinded audio stimuli and separate answer key. No listener scores invented."""
import argparse,csv,json,random,wave,zipfile
from pathlib import Path
import numpy as np

def read(path):
    with wave.open(str(path),'rb') as w:
        assert w.getsampwidth()==2
        return np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,w.getnchannels()).astype(float)/32768,w.getframerate()
def write(path,x,fs):
    path.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(path),'wb') as w:
        w.setnchannels(x.shape[1]);w.setsampwidth(2);w.setframerate(fs)
        w.writeframes(np.clip(np.rint(x*32768),-32768,32767).astype('<i2').tobytes())

def main():
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--out',type=Path,required=True);p.add_argument('--seed',type=int,default=20261126);p.add_argument('--repeats',type=int,default=3);a=p.parse_args()
    if a.repeats<1 or a.repeats>10:raise ValueError('repeats must be 1..10')
    out=a.out;out.mkdir(parents=True,exist_ok=True)
    preview,rate=read(a.root/'docs/audio-review-preview.wav')
    names=['crew','relic','upgrade']
    # Sequence clips from P07 offline mix with actual GameAudio gains. No real hardware claim.
    mix={name:preview[round(i*2*rate):round((i*2+1.35)*rate)] for i,name in enumerate(names)}
    singles={name:read(a.root/f'assets/audio/runtime/sfx_loot_{name}_01.wav')[0] for name in names}
    rms={name:np.sqrt(np.mean(v*v)) for name,v in singles.items()}
    target=min(rms.values()); equal={}
    for name,v in singles.items():
        x=v*target/max(rms[name],1e-12)
        # Equal whole-event RMS; approximate level control, not equal human-perceived loudness.
        equal[name]=np.pad(x,((0,round(1.0*rate)-len(x)),(0,0)))
    rnd=random.Random(a.seed);rows=[];key=[];files=[]
    for block,source in [('A_game_gain',mix),('B_matched_rms',equal)]:
        order=names*a.repeats;rnd.shuffle(order)
        for i,name in enumerate(order,1):
            code=f'{block[0]}{i:02d}';file=out/(code+'.wav');write(file,source[name],rate);files.append(file)
            rows.append({'block':block,'trial_id':code,'guessed_tier_crew_relic_upgrade':'','clarity_1_5':'','impact_1_5':'','material_fit_1_5':'','tail_natural_1_5':'','style_fit_1_5':'','fatigue_1_5_high_is_bad':'','notes':''})
            key.append({'block':block,'trial_id':code,'true_tier':name})
    for name,rs in [('listening-score.csv',rows),('answer-key.csv',key)]:
        with (out/name).open('w',newline='',encoding='utf-8') as f:
            w=csv.DictWriter(f,fieldnames=list(rs[0]));w.writeheader();w.writerows(rs)
    guide=out/'README.txt';guide.write_text('Riftworks P07 盲听。请勿先查看答案。固定设备、音量、环境，按每组编号播放。A组真实游戏增益的离线开箱序列，判断普通/遗物/升级；B组独立奖励音按整段RMS匹配且补静音，比较音色和冲击感，非等主观响度。每组重复仅用于同人稳定性，不算独立玩家。记录设备/耳机/环境并填写 listening-score.csv；疲劳5=最强，其它5=最好。不能听清标注备注，不要硬猜。\n',encoding='utf-8')
    with zipfile.ZipFile(out/'RiftworksP07-blind-listening.zip','w',zipfile.ZIP_DEFLATED) as z:
        for f in files+[out/'listening-score.csv',guide]:z.write(f,f.name)
    print(f'{len(rows)} blinded trials; answer key separate; seed={a.seed}')
if __name__=='__main__':main()
