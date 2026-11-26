#!/usr/bin/env python3
"""P05 exact source-frame/alpha/anchor/padding verification."""
from PIL import Image
from pathlib import Path
import hashlib,json,sys
sys.dont_write_bytecode=True
import generate_character_atlas as gen
base=Path(__file__).parent
meta=json.loads((base/'manifest.json').read_text())
a=Image.open(base/'atlas.png').convert('RGBA')
assert gen.sha(base/'atlas.png')==meta['atlas_sha256']
assert list(a.size)==meta['atlas_size'] and meta['anchor']==list(gen.ANCHOR)
for path,digest in meta['source_sheets'].items():assert gen.sha(gen.SRC/path)==digest
assert gen.sha(gen.SRC/'crew-portraits.png')==meta['portrait_source_sha256']
poses,notes=gen.pose_masters();plan=gen.frame_plan(poses)
assert meta['source_poses']==json.loads(json.dumps(notes))
assert meta['padding']==2
pad=meta['padding'];allocated=bytearray(a.width*a.height);n=0;content=0;padded=0
for role,clips in plan.items():
 for state,seq in clips.items():
  distinct=len({i.tobytes() for i in seq})
  minimum={'idle':2 if role in gen.CREW else 1,'attack':4,'run':4,'hurt':2,'death':3}[state]
  assert distinct>=minimum,(role,state,distinct,minimum)
  for left in (False,True):
   key=state+'_left' if left else state
   assert meta['states'][key]==gen.STATES[state]
   frames=meta['characters'][role][key];assert len(frames)==len(seq)
   for im,record in zip(seq,frames):
    if left:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    bbox=im.getchannel('A').getbbox()
    assert bbox[0]>0 and bbox[1]>0 and bbox[2]<gen.SIZE and bbox[3]<gen.SIZE
    x,y,w,h=record['rect'];assert record['offset']==[bbox[0]-gen.ANCHOR[0],bbox[1]-gen.ANCHOR[1]]
    assert (w,h)==(bbox[2]-bbox[0],bbox[3]-bbox[1])
    crop=im.crop(bbox);assert a.crop((x,y,x+w,y+h)).tobytes()==crop.tobytes()
    assert x>=pad and y>=pad and x+w+pad<=a.width and y+h+pad<=a.height
    for dy in range(-pad,h+pad):
     y2=y+dy
     for dx in range(-pad,w+pad):
      x2=x+dx;idx=y2*a.width+x2;assert not allocated[idx],'padded blocks overlap';allocated[idx]=1
      assert a.getpixel((x2,y2))==crop.getpixel((min(w-1,max(dx,0)),min(h-1,max(dy,0))))
    restored=Image.new('RGBA',im.size);restored.paste(crop,(record['offset'][0]+gen.ANCHOR[0],record['offset'][1]+gen.ANCHOR[1]))
    assert restored.getchannel('A').tobytes()==im.getchannel('A').tobytes()
    n+=1;content+=w*h;padded+=(w+2*pad)*(h+2*pad)
for role,expected in gen.portrait_masters().items():
 path=base/'portraits'/f'{role}.png';record=meta['portraits'][role]
 assert gen.sha(path)==record['sha256']
 actual=Image.open(path).convert('RGBA');assert actual.size==(256,256) and actual.tobytes()==expected.tobytes()
 assert actual.getchannel('A').getextrema()[0]==0
print(f'PASS {n} atlas entries exact source reconstruction / alpha / anchor / mirror / exclusive 2px extrusion; 3 distinct exact source portraits.')
print(f'Content {content:,} px; padded {padded:,}; atlas {a.width*a.height:,}; untrimmed {n*gen.SIZE*gen.SIZE:,}.')
