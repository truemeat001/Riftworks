#!/usr/bin/env python3
"""P05 original non-pixel character frame adaptation.
ImageGen original sheets are saved unchanged, separately. Generated alpha is
preserved within crop; smooth resampling matches the hand-painted art direction.
"""
from PIL import Image, ImageDraw
from pathlib import Path
import hashlib,json
HERE=Path(__file__).parent
PROJECT=HERE.parent.parent
SRC=PROJECT/'docs'/'art-sources-p05'
SIZE=400
ANCHOR=(200,310)
NATIVE_HEIGHT={'pulse':152,'frost':152,'burst':152,'crab':108,'sail':95,'urchin':125,'boss':170}
CREW=['pulse','frost','burst']; ENEMY=['crab','sail','urchin','boss']
ROLE_NAMES={'pulse':'Diving Engineer','frost':'Wind Caller','burst':'Shell Hammer Guard','crab':'Tide Crab','sail':'Sail Ray','urchin':'Coralback','boss':'Reef Monarch'}
STATES={'idle':{'fps':4,'loop':True},'attack':{'fps':18,'loop':False},'run':{'fps':8,'loop':True},'hurt':{'fps':12,'loop':False},'death':{'fps':9,'loop':False}}
SHEETS={'crew':('crew-poses.png',[0,378,712,1164,1536],[0,310,623,1024]),'walk':('enemy-walk.png',[0,386,776,1154,1536],[0,195,399,640,1024]),'damage':('enemy-damage.png',[0,536,1020,1536],[0,198,386,645,1024])}
# Explicit planted-foot anchor measurements on original generated sheet.
# Particularly important for downward hammer-pose impact effect (which extends
# beyond shoes) and long scarf (which shifts whole bounding-box centroid).
CREW_ANCHORS={
 'pulse':[(187,288),(536,288),(880,285),(1316,288)],
 'frost':[(211,617),(565,611),(942,617),(1340,615)],
 'burst':[(187,931),(554,932),(857,928),(1360,931)]}
# Floating ray has no planted feet. Use stable body-bottom reference below the
# body mass, independent of upward/downward fin extents.
RAY_ANCHORS={
 'walk':[(202,339),(583,339),(964,339),(1348,339)],
 'damage':[(258,339),(760,339),(1250,339)]}

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def core_bbox(im):return im.getchannel('A').point(lambda x:255 if x>=128 else 0).getbbox()
def source_cell(sheet,row,col):
 file,xs,ys=SHEETS[sheet]; im=Image.open(SRC/file).convert('RGBA')
 cell=(xs[col],ys[row],xs[col+1],ys[row+1]); im=im.crop(cell)
 bb=core_bbox(im);assert bb and bb[0]>0 and bb[1]>0 and bb[2]<im.width and bb[3]<im.height,(sheet,row,col,bb,im.size)
 crop=(max(0,bb[0]-3),max(0,bb[1]-3),min(im.width,bb[2]+3),min(im.height,bb[3]+3))
 absolute=tuple(cell[i%2]+crop[i] for i in range(4))
 return im.crop(crop),{'sheet':file,'cell':cell,'crop':absolute}

def detected_anchor(im):
 a=im.getchannel('A');x0,y0,x1,y1=core_bbox(im)
 band=max(4,int((y1-y0)*.10));lower=a.crop((x0,y1-band,x1,y1)).point(lambda n:255 if n>=128 else 0).getbbox()
 return (x0+(lower[0]+lower[2])/2 if lower else (x0+x1)/2,y1)

def master(im,scale,record,anchor_abs=None):
 if anchor_abs is not None:
  x0,y0,_,_=record['crop']; source_anchor=(anchor_abs[0]-x0,anchor_abs[1]-y0); method='manual planted-foot or ray body reference'
 else:source_anchor=detected_anchor(im);method='opaque lower 10% band midpoint'
 w,h=max(1,round(im.width*scale)),max(1,round(im.height*scale))
 resized=im.resize((w,h),Image.Resampling.LANCZOS)
 x=round(ANCHOR[0]-source_anchor[0]*(w/im.width));y=round(ANCHOR[1]-source_anchor[1]*(h/im.height))
 assert x>=0 and y>=0 and x+w<=SIZE and y+h<=SIZE,(im.size,w,h,x,y)
 canvas=Image.new('RGBA',(SIZE,SIZE));canvas.paste(resized,(x,y))
 return canvas,dict(record,source_scale=scale,master_offset=[x,y],source_anchor=list(source_anchor),anchor_method=method)

def pose_masters():
 result={};notes={};nominal_width={}
 for roles,sheet in [(CREW,'crew'),(ENEMY,'walk'),(ENEMY,'damage')]:
  for row,role in enumerate(roles):
   poses=[];source_notes=[]
   for col in range(3 if sheet=='damage' else 4):
    im,record=source_cell(sheet,row,col)
    if col==0:
     x0,y0,x1,y1=core_bbox(im)
     if sheet=='damage':scale=nominal_width[role]/(x1-x0)
     else:
      scale=NATIVE_HEIGHT[role]/(y1-y0);nominal_width[role]=(x1-x0)*scale
    abs_anchor=CREW_ANCHORS[role][col] if sheet=='crew' else RAY_ANCHORS[sheet][col] if role=='sail' else None
    pose,note=master(im,scale,record,abs_anchor);poses.append(pose);source_notes.append(note)
   result[(role,sheet)]=poses;notes[f'{role}/{sheet}']=source_notes
 return result,notes

def frame_plan(poses):
 result={}
 for role in CREW:
  p=poses[(role,'crew')];result[role]={'idle':[p[0],p[3]],'attack':[p[i] for i in [0,1,1,2,3,0]]}
 for role in ENEMY:
  p=poses[(role,'walk')]; d=poses[(role,'damage')];result[role]={'idle':[p[0]],'run':p,'hurt':[d[0],p[0]],'death':[d[0],d[1],d[1],d[2]]}
 return result

# Card crops are intentionally tighter than full-body frames. Rectangles chosen
# from the independently generated portrait sheet around each own face and chest;
# no neighboring face is visible. Keep photo-derived true alpha inside crop.
PORTRAIT_CROPS={'pulse':(128,25,688,690),'frost':(801,28,1340,690),'burst':(1531,20,2172,690)}
def portrait_masters():
 im=Image.open(SRC/'crew-portraits.png').convert('RGBA')
 result={}
 for role,cell in PORTRAIT_CROPS.items():
  cropped=im.crop(cell)
  w,h=cropped.size;scale=min(256/w,256/h)
  fit=cropped.resize((round(w*scale),round(h*scale)),Image.Resampling.LANCZOS)
  out=Image.new('RGBA',(256,256));out.paste(fit,((256-fit.width)//2,256-fit.height));result[role]=out
 return result

def generate():
 poses,notes=pose_masters();plan=frame_plan(poses)
 manifest={'version':3,'authoring_size':[SIZE,SIZE],'anchor':list(ANCHOR),'padding':2,'source':'P05 original ImageGen hand-painted Concept A key poses; source alpha retained; LANCZOS reduction; no P04/NGame raster.',
 'states':{},'characters':{},'names':ROLE_NAMES,'source_sheets':{file:sha(SRC/file) for file,_,_ in SHEETS.values()},'source_poses':notes,'portrait_source_sha256':sha(SRC/'crew-portraits.png'),'portraits':{}}
 for st,meta in STATES.items():manifest['states'][st]=meta;manifest['states'][st+'_left']=meta
 entries=[]
 for role,clips in plan.items():
  manifest['characters'][role]={}
  for st,seq in clips.items():
   for left in (False,True):
    key=st+'_left' if left else st;out=[]
    for im in seq:
     if left:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
     bb=im.getchannel('A').getbbox();assert bb and all(v>0 for v in bb[:2]) and all(v<SIZE for v in bb[2:]),(role,st,bb)
     crop=im.crop(bb);rec={'rect':None,'offset':[bb[0]-ANCHOR[0],bb[1]-ANCHOR[1]]};entries.append((crop,rec));out.append(rec)
    manifest['characters'][role][key]=out
 # 2px edge extrusion for smooth bilinear filtering (>=1px NGame rule).
 pad=manifest['padding'];width=2048;x=y=pad;rowh=0
 for crop,rec in entries:
  w,h=crop.size
  if x+w+pad>width:x=pad;y+=rowh+2*pad;rowh=0
  rec['rect']=[x,y,w,h];x+=w+2*pad;rowh=max(rowh,h)
 height=y+rowh+pad;atlas=Image.new('RGBA',(width,height))
 for image,rec in entries:
  x,y,w,h=rec['rect'];atlas.paste(image,(x,y))
  for j in range(1,pad+1):
   atlas.paste(image.crop((0,0,w,1)),(x,y-j));atlas.paste(image.crop((0,h-1,w,h)),(x,y+h-1+j));atlas.paste(image.crop((0,0,1,h)),(x-j,y));atlas.paste(image.crop((w-1,0,w,h)),(x+w-1+j,y))
   for k in range(1,pad+1):
    for dx,dy,sx,sy in [(-j,-k,0,0),(w-1+j,-k,w-1,0),(-j,h-1+k,0,h-1),(w-1+j,h-1+k,w-1,h-1)]:atlas.putpixel((x+dx,y+dy),image.getpixel((sx,sy)))
 atlas.save(HERE/'atlas.png',optimize=True);manifest['atlas_size']=list(atlas.size);manifest['atlas_sha256']=sha(HERE/'atlas.png')
 (HERE/'portraits').mkdir(exist_ok=True)
 for role,im in portrait_masters().items():
  path=HERE/'portraits'/f'{role}.png';im.save(path,optimize=True);manifest['portraits'][role]={'path':f'assets/characters/portraits/{role}.png','sha256':sha(path),'source_crop':PORTRAIT_CROPS[role]}
 (HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 # Actual authoring contact sheet: no concept image used for game.
 preview=Image.new('RGB',(7*224,240),'#c7ddda');d=ImageDraw.Draw(preview)
 for i,role in enumerate(ROLE_NAMES):
  source=plan[role]['idle'][0];crop=source.crop(source.getchannel('A').getbbox());crop.thumbnail((208,198),Image.Resampling.LANCZOS);preview.paste(crop,(i*224+(224-crop.width)//2,220-crop.height),crop);d.text((i*224+8,225),ROLE_NAMES[role],fill='#213d48')
 preview.save(HERE/'concept-lineup.png')
 print('PASS generated',len(entries),'frame entries and 3 portraits; atlas',atlas.size,(HERE/'atlas.png').stat().st_size,'bytes')
if __name__=='__main__':generate()
