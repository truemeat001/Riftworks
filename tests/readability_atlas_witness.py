#!/usr/bin/env python3
"""Actual Run snapshot + shipped art geometry comparative compositing.
Not a Godot/GPU screenshot: no towers or full HUD. Diagnostic of sprite and
health occlusion using exact atlas frames, dimensions and live model positions.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
import json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/p08-readability-evidence'
sample=json.loads((OUT/'actual-run-dense-sample.json').read_text())
base=ROOT/'assets/characters'
atlas=Image.open(base/'atlas.png').convert('RGBA')
manifest=json.loads((base/'manifest.json').read_text())
role_ids={'normal':'crab','runner':'sail','guard':'urchin','boss':'boss'}
target={'normal':(55,53),'runner':(68,50),'guard':(70,67),'boss':(105,112)}
source_rows={int(e['id']):e for e in sample['rows']}
origin=(52,60);tile=76
MAP_RECT=(0,46,1016,676)
def world(p):return (origin[0]+(p[0]+.5)*tile,origin[1]+(p[1]+.5)*tile)
def sprite(row,enhanced,factor):
    role=row['role'];sid=role_ids[role];clips=manifest['characters'][sid]
    state='hurt' if 0<=row['hit_age']<.16 else 'run'
    if row['face_left'] and state+'_left' in clips:state+='_left'
    fps=manifest['states'][state]['fps'];loop=manifest['states'][state]['loop']
    elapsed=row['hit_age'] if state.startswith('hurt') else sample['tick']*.05+(row['phase_offset'] if enhanced else 0)
    i=int(max(0,elapsed)*fps); frames=clips[state];i=i%len(frames) if loop else min(i,len(frames)-1)
    frame=frames[i];x,y,w,h=frame['rect'];dx,dy=frame['offset']
    mw=max(f['rect'][2] for f in clips['idle']);mh=max(f['rect'][3] for f in clips['idle'])
    scale=min(target[role][0]/mw,target[role][1]/mh)*(row['scale_mul'] if enhanced else 1)*factor
    pic=atlas.crop((x,y,x+w,y+h)).resize((max(1,round(w*scale)),max(1,round(h*scale))),Image.Resampling.LANCZOS)
    anchor=row['anchor'] if enhanced else (row['old_pos'][0],row['old_pos'][1]+13)
    p=(round(anchor[0]*factor+dx*scale),round(anchor[1]*factor+dy*scale))
    return pic,p
def clippedmask(pic,point,canvas_size):
    x,y=point;w,h=pic.size;W,H=canvas_size
    area=np.zeros((H,W),dtype=bool)
    x0=max(0,x);y0=max(0,y);x1=min(W,x+w);y1=min(H,y+h)
    if x0<x1 and y0<y1:
        alpha=np.asarray(pic.getchannel('A'))
        area[y0:y1,x0:x1]=alpha[y0-y:y1-y,x0-x:x1-x]>=128
    return area

def render(enhanced,factor):
    size=(round(1280*factor),round(800*factor))
    W,H=size;c=Image.new('RGBA',size,'#c7ddda')
    stage=sample['stage'];name=['tidecross_background','twintide_background','echoreef_background'][stage]
    bg=Image.open(ROOT/f'assets/environment/{name}.png').convert('RGBA').resize((round((MAP_RECT[2]-MAP_RECT[0])*factor),round((MAP_RECT[3]-MAP_RECT[1])*factor)),Image.Resampling.LANCZOS)
    c.alpha_composite(bg,(0,round(46*factor)))
    d=ImageDraw.Draw(c)
    def pt(p):return (round(p[0]*factor),round(p[1]*factor))
    def rect(r):return tuple(round(z*factor) for z in r)
    for route in [sample['route'],sample['extra_route']]:
        if route:d.line([pt(world(k)) for k in route],fill='#dfc79a',width=round(39*factor),joint='curve')
    order=sample['sorted_ids'] if enhanced else [r['id'] for r in sample['rows']]
    pics=[]
    for ident in order:
        row=source_rows[int(ident)];pic,p=sprite(row,enhanced,factor)
        c.alpha_composite(pic,p);pics.append((ident,clippedmask(pic,p,size)))
    occluded={};covered=np.zeros((H,W),dtype=bool)
    for ident,mask in reversed(pics):
        n=mask.sum();occluded[str(ident)]=float((mask&covered).sum()/max(1,n));covered|=mask
    d=ImageDraw.Draw(c)
    if enhanced:
        for ident in sample['bar_ids']:
            row=source_rows[int(ident)]
            if row['bar_draw'] and row['bar_routed']:
                x,y=row['bar_pos'];w,h=row['bar_size']
                d.line([pt(row['bar_link']),pt((x+w/2,y+h/2))],fill='#213d48',width=max(1,round(factor)))
    for ident in (sample['bar_ids'] if enhanced else order):
        row=source_rows[int(ident)]
        if enhanced:
            if not row['bar_draw']:continue
            x,y=row['bar_pos'];w,h=row['bar_size']
        else:
            w,h=(38,5) if row['boss'] else (28,4)
            x,y=row['old_pos'][0]-w/2,row['old_pos'][1]+27
        ratio=max(0,min(1,row['hp']/row['maxhp']))
        d.rectangle(rect((x-1,y-1,x+w+1,y+h+1)),fill='#213d48')
        d.rectangle(rect((x,y,x+w,y+h)),fill='#36515a' if enhanced else '#768287')
        d.rectangle(rect((x,y,x+w*ratio,y+h)),fill='#f18b68' if enhanced else '#d15e43')
        if enhanced:d.line([pt((x,y-1)),pt((x+w,y-1))],fill='#d0b36a' if row['boss'] else '#fff6e4',width=1)
    wx,wy,ww,wh=sample['warning']
    if ww:
        d.rectangle(rect((wx,wy,wx+ww,wy+wh)),fill='#fff6e4',outline='#9d343c',width=max(1,round(2*factor)))
        d.text(pt((wx+8,wy+6)),'CORE ALERT',fill='#9d343c')
    crop=c.crop(rect(MAP_RECT)).convert('RGB')
    return crop,occluded
metrics={}
for factor,label in [(1,'1280'),(.75,'960')]:
    before,old=render(False,factor);after,new=render(True,factor)
    W,H=before.size;s=Image.new('RGB',(W,H*2+56),'#f5ebd6');d=ImageDraw.Draw(s)
    d.text((5,5),f'P07 nominal before | actual Run snapshot S{sample["stage"]+1} W{sample["wave"]+1} T{sample["tick"]}; diagnostic composite, NOT game screenshot',fill='#213d48')
    s.paste(before,(0,20));d.text((5,H+24),'P08 render layout after | same authoritative positions, HP and actual atlas',fill='#213d48')
    s.paste(after,(0,H+40));s.save(OUT/f'actual-sample-comparison-{label}.png')
    metrics[label]={'count':len(old),'old_mean_opaque_occlusion':sum(old.values())/len(old),'new_mean_opaque_occlusion':sum(new.values())/len(new),'old_over_half_hidden':sum(v>.5 for v in old.values()),'new_over_half_hidden':sum(v>.5 for v in new.values()),'old_per_unit':old,'new_per_unit':new}
(OUT/'atlas-occlusion-proxy.json').write_text(json.dumps(metrics,indent=2)+'\n')
print(json.dumps({k:{n:v for n,v in l.items() if not n.endswith('per_unit')} for k,l in metrics.items()},indent=2))
