#!/usr/bin/env python3
"""Independently reconstruct source poses and verify each packed frame."""
import hashlib,json,sys
from pathlib import Path
from PIL import Image
sys.dont_write_bytecode=True
import generate_character_atlas as gen
base=Path(__file__).parent
meta=json.loads((base/'manifest.json').read_text())
atlas=Image.open(base/'atlas.png').convert('RGBA')
assert list(atlas.size)==meta['atlas_size']
assert gen.sha(base/'atlas.png')==meta['atlas_sha256']
for p,want in meta['source_sheets'].items():assert gen.sha(gen.SRC/p)==want
poses,notes=gen.pose_masters();plan=gen.frame_plan(poses);assert meta['source_poses']==json.loads(json.dumps(notes))
occupied=bytearray(atlas.width*atlas.height);n=0;area=0;pad_area=0
for role,clips in plan.items():
 for state,seq in clips.items():
  unique=len({im.tobytes() for im in seq})
  required=len(seq) if state in {'run','hurt'} else {'attack':4,'death':3,'idle':1}[state]
  assert unique>=required,(role,state,unique,required)
  for left in (False,True):
   key=state+'_left' if left else state
   assert meta['states'][key]==gen.STATES[state]
   frames=meta['characters'][role][key];assert len(frames)==len(seq)
   for im,info in zip(seq,frames):
    if left:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    bb=im.getchannel('A').getbbox();x,y,w,h=info['rect']
    assert bb[0]>0 and bb[1]>0 and bb[2]<gen.SIZE and bb[3]<gen.SIZE
    assert info['offset']==[bb[0]-gen.ANCHOR[0],bb[1]-gen.ANCHOR[1]]
    assert (w,h)==(bb[2]-bb[0],bb[3]-bb[1])
    crop=im.crop(bb); assert atlas.crop((x,y,x+w,y+h)).tobytes()==crop.tobytes()
    assert x>=1 and y>=1 and x+w+1<=atlas.width and y+h+1<=atlas.height
    for dy in range(-1,h+1):
     for dx in range(-1,w+1):
      px=x+dx;py=y+dy;loc=py*atlas.width+px;assert not occupied[loc],'overlap';occupied[loc]=1
      assert atlas.getpixel((px,py))==crop.getpixel((min(w-1,max(dx,0)),min(h-1,max(dy,0))))
    restored=Image.new('RGBA',im.size);restored.paste(crop,(info['offset'][0]+gen.ANCHOR[0],info['offset'][1]+gen.ANCHOR[1]))
    assert restored.getchannel('A').tobytes()==im.getchannel('A').tobytes()
    n+=1;area+=w*h;pad_area+=(w+2)*(h+2)
print(f'PASS {n} packed frame entries, source hashes, actual master payload, alpha bounds, offsets, mirror, separated 1px extrusion, distinct active poses.')
print(f'Content {area:,} px, padded {pad_area:,}, atlas {atlas.width*atlas.height:,}, authoring canvas equivalent {n*gen.SIZE*gen.SIZE:,}.')
for name in ('chest_closed','chest_open'):
 im=Image.open(gen.PROJECT/'assets/items'/f'{name}.png').convert('RGBA')
 assert im.size==(144,160) and im.getchannel('A').getextrema()[0]==0
 # Verify opaque core extraction from resize and placement preserved from clean source.
 c=int(name.endswith('open'));crop,_=gen.source_cell('chest',0,c)
 raw_closed,_=gen.source_cell('chest',0,0);scale=112/gen.core_bbox(raw_closed)[2]
 w,h=round(crop.width*scale),round(crop.height*scale);resize=crop.resize((w,h),Image.Resampling.NEAREST);restore=Image.new('RGBA',(144,160));restore.paste(resize,((144-w)//2,151-h))
 assert restore.tobytes()==im.tobytes()
 print(name,'verified alpha crop/scale/placement')
