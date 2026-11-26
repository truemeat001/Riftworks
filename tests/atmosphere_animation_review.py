#!/usr/bin/env python3
"""Asset-only visual review at actual nominal target sizes (NOT game capture).
Produce 3 explicitly repeated cycles and all active clips on light/dark fields.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/characters'
EVIDENCE=ROOT/'docs/p07-art-evidence'
EVIDENCE.mkdir(exist_ok=True)
meta=json.loads((BASE/'manifest.json').read_text())
a=Image.open(BASE/'atlas.png').convert('RGBA')
assert hashlib.sha256((BASE/'atlas.png').read_bytes()).hexdigest()==meta['atlas_sha256']
roles=['pulse','frost','burst','crab','sail','urchin','boss']
light='#c7ddda';dark='#213d48'
target={'pulse':(96,84),'frost':(96,84),'burst':(96,84),'crab':(55,53),'sail':(68,50),'urchin':(70,67),'boss':(105,112)}
scales={r:min(target[r][0]/max(f['rect'][2] for f in meta['characters'][r]['idle']),target[r][1]/max(f['rect'][3] for f in meta['characters'][r]['idle'])) for r in roles}

def draw_frame(c,role,state,n,anchor,scale):
    frame=meta['characters'][role][state][n]
    x,y,w,h=frame['rect'];dx,dy=frame['offset']
    im=a.crop((x,y,x+w,y+h)).resize((max(1,round(w*scale)),max(1,round(h*scale))),Image.Resampling.LANCZOS)
    pos=(round(anchor[0]+dx*scale),round(anchor[1]+dy*scale))
    c.alpha_composite(im,pos)

for factor,label in [(1.0,'1280'),(.75,'960')]:
    frames=[];sequence={}
    # 12 frames sampled at 125ms = exactly 3 complete cycles of 0.5s.
    # Timeline includes tail->head at frames 4 and 8; no GIF looping shortcut.
    for i in range(12):
        W,H=round(1050*factor),round(306*factor)
        c=Image.new('RGBA',(W,H),light);d=ImageDraw.Draw(c)
        d.rectangle((0,round(153*factor),W,H),fill=dark)
        for color_row in range(2):
            row_y=round((color_row*153+120)*factor)
            for k,role in enumerate(roles):
                st='idle' if k<3 else 'run'
                f=int(i*0.125*meta['states'][st]['fps'])%len(meta['characters'][role][st])
                if color_row==0:sequence.setdefault(role,[]).append(f)
                point=(round((k*150+75)*factor),row_y)
                line='#739092' if color_row==0 else '#526568'
                d.line((point[0]-round(26*factor),point[1],point[0]+round(26*factor),point[1]),fill=line,width=max(1,round(factor)))
                draw_frame(c,role,st,f,point,scales[role]*factor)
                if factor==1:d.text((k*150+5,row_y+4),f'{role} {st}:{f+1}',fill='#213d48' if color_row==0 else '#f5ebd6')
        frames.append(c.convert('RGB'))
    for role,seq in sequence.items():
        assert seq[:4]==seq[4:8]==seq[8:12],(role,seq)
        assert len(set(seq[:4]))==(2 if role in roles[:3] else 4)
    frames[0].save(EVIDENCE/f'loop-three-cycles-{label}.gif',save_all=True,append_images=frames[1:],duration=[125]*12,loop=0,optimize=False)
    frames[0].save(EVIDENCE/f'loop-contact-{label}.png')
    # All non-looping frames separate rows, each on paired backgrounds, no scaling up.
    clip_rows=[(r,st) for r in roles for st in ('attack','hurt','death') if st in meta['characters'][r]]
    row_h=round(142*factor);cell_w=round(142*factor);width=cell_w*6*2;h=row_h*len(clip_rows)
    c=Image.new('RGBA',(width,h),light);d=ImageDraw.Draw(c)
    d.rectangle((cell_w*6,0,width,h),fill=dark)
    for row,(role,st) in enumerate(clip_rows):
        frames_info=meta['characters'][role][st]
        n=len(frames_info)
        for side in range(2):
            for f in range(n):
                point=((side*6+f)*cell_w+cell_w//2,row*row_h+round(116*factor))
                d.line((point[0]-round(28*factor),point[1],point[0]+round(28*factor),point[1]),fill='#739092' if side==0 else '#526568',width=1)
                draw_frame(c,role,st,f,point,scales[role]*factor)
                if f==0 and factor==1:d.text((side*6*cell_w+4,row*row_h+4),f'{role} {st}',fill='#213d48' if side==0 else '#f5ebd6')
    c.convert('RGB').save(EVIDENCE/f'nonloop-contact-{label}.png')
print('PASS verified 3 cycles at 4fps idle and 8fps run, generated paired light/dark nominal size 1280 and 960 proof sheets/GIF. No native game capture.')
