#!/usr/bin/env python3
"""P04 imagegen sprite-sheet adaptation. No NGame or P03 raster reuse.
All animation poses are crops from saved source sheets. Held frames explicit.
Crop by sufficiently opaque foreground bounds; preserve generated alpha inside crop.
Render original pixel clusters at fixed uniform per-role nearest-neighbor scale,
locate visual foot-band anchor, then AABB crop with 1px extrusion.
"""
from PIL import Image, ImageDraw
from pathlib import Path
import json, hashlib, math
HERE=Path(__file__).parent
PROJECT=HERE.parent.parent
SRC=PROJECT/'docs'/'art-sources'
SIZE=192
ANCHOR=(96,148)
NATIVE_HEIGHT={'pulse':92,'frost':92,'burst':92,'crab':84,'sail':84,'urchin':86,'boss':120}
ROLE_NAMES={'pulse':'Copper Scout','frost':'Mist Weaver','burst':'Reef Guard','crab':'Rift Hermit','sail':'Sailbeast','urchin':'Spine Revenant','boss':'Abyss Warden'}
CREW=['pulse','frost','burst']; ENEMY=['crab','sail','urchin','boss']
STATES={'idle':{'fps':4,'loop':True},'attack':{'fps':18,'loop':False},'run':{'fps':8,'loop':True},'hurt':{'fps':12,'loop':False},'death':{'fps':9,'loop':False}}
# Cell boundaries measured from opaque projection gaps, not naively equal grid.
SHEETS={'crew':('crew-poses.png',[0,300,680,1100,1448],[0,346,687,1086]),'walk':('enemy-walk.png',[0,310,600,904,1199],[0,284,540,851,1312]),'damage':('enemy-damage.png',[0,357,694,1086],[0,320,605,940,1448]),'chest':('chest-pair.png',[0,1086,2172],[0,724])}

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def core_bbox(im):
    return im.getchannel('A').point(lambda x:255 if x>=128 else 0).getbbox()
def alpha_bbox(im): return im.getchannel('A').getbbox()

def source_cell(sheet,row,col):
    file,xs,ys=SHEETS[sheet]
    img=Image.open(SRC/file).convert('RGBA')
    cell=(xs[col],ys[row],xs[col+1],ys[row+1]); im=img.crop(cell)
    bb=core_bbox(im)
    assert bb and bb[0]>0 and bb[1]>0 and bb[2]<im.width and bb[3]<im.height,(sheet,row,col,bb,im.size)
    # Retain 2px outer fringe while excluding faint background far from subject.
    crop=(max(0,bb[0]-2),max(0,bb[1]-2),min(im.width,bb[2]+2),min(im.height,bb[3]+2))
    return im.crop(crop),{'sheet':file,'cell':cell,'crop':tuple(cell[i%2]+crop[i] for i in range(4))}

def anchor_in_crop(im):
    # Weighted midpoint of sufficiently opaque lower band for stable contact.
    a=im.getchannel('A'); bb=core_bbox(im)
    x0,y0,x1,y1=bb
    band=max(4,int((y1-y0)*0.10))
    band_im=a.crop((x0,y1-band,x1,y1)).point(lambda x:255 if x>=128 else 0)
    lower=band_im.getbbox()
    return (x0+(lower[0]+lower[2])/2 if lower else (x0+x1)/2,y1)

def master(im,scale,record):
    # Same source-scale for all poses of same role/sheet; no per-frame stretch.
    w,h=max(1,round(im.width*scale)),max(1,round(im.height*scale))
    resized=im.resize((w,h),Image.Resampling.NEAREST)
    a=anchor_in_crop(resized); x=round(ANCHOR[0]-a[0]); y=round(ANCHOR[1]-a[1])
    assert x>=0 and y>=0 and x+w<=SIZE and y+h<=SIZE, (im.size,w,h,x,y)
    canvas=Image.new('RGBA',(SIZE,SIZE));canvas.paste(resized,(x,y))
    return canvas,dict(record,source_scale=scale,master_offset=[x,y],anchor_method='opaque lower 10% band midpoint')

def pose_masters():
    result={}; source_notes={}
    for roles,sheet in [(CREW,'crew'),(ENEMY,'walk'),(ENEMY,'damage')]:
        for row,role in enumerate(roles):
            poses=[]; notes=[]
            for col in range(3 if sheet=='damage' else 4):
                im,record=source_cell(sheet,row,col)
                if col==0:
                    x0,y0,x1,y1=core_bbox(im); scale=NATIVE_HEIGHT[role]/(y1-y0)
                pose,note=master(im,scale,record);poses.append(pose);notes.append(note)
            result[(role,sheet)]=poses;source_notes[f'{role}/{sheet}']=notes
    return result,source_notes

def frame_plan(poses):
    # Explicit held frames preserve requested phase timing; only implemented
    # active direction clips are listed and each source pose comes from ImageGen.
    result={}
    for role in CREW:
        p=poses[(role,'crew')]
        result[role]={'idle':[p[0],p[3]],'attack':[p[i] for i in [0,1,1,2,3,0]]}
    for role in ENEMY:
        p=poses[(role,'walk')]; d=poses[(role,'damage')]
        result[role]={'idle':[p[0]],'run':p,'hurt':[d[0],p[0]],'death':[d[0],d[1],d[1],d[2]]}
    return result

def generate():
    poses,notes=pose_masters()
    plan=frame_plan(poses)
    manifest={'version':2,'authoring_size':[SIZE,SIZE],'anchor':list(ANCHOR),'padding':1,
       'source':'Original ImageGen authored keyframe sheets, fixed per-role source-scale and alpha-preserving frame packing; no P03/NGame imagery.',
       'states':{},'characters':{},'names':ROLE_NAMES,'source_sheets':{file:sha(SRC/file) for file,_,_ in SHEETS.values()},'source_poses':notes}
    for st,meta in STATES.items():manifest['states'][st]=meta;manifest['states'][st+'_left']=meta
    # Pack per entry (explicit held frames allowed), simplest auditable contract.
    entries=[]
    for role,clips in plan.items():
        manifest['characters'][role]={}
        for st,frames in clips.items():
            for left in (False,True):
                key=st+'_left' if left else st; out=[]
                for im in frames:
                    if left:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    bb=alpha_bbox(im); assert bb and all(v>0 for v in bb[:2]) and all(v<SIZE for v in bb[2:]),(role,st,bb)
                    crop=im.crop(bb); record={'rect':None,'offset':[bb[0]-ANCHOR[0],bb[1]-ANCHOR[1]]}
                    entries.append((crop,record));out.append(record)
                manifest['characters'][role][key]=out
    width=1024;x=y=1;rowh=0
    for crop,record in entries:
        w,h=crop.size
        if x+w+1>width:x=1;y+=rowh+2;rowh=0
        record['rect']=[x,y,w,h];x+=w+2;rowh=max(rowh,h)
    height=y+rowh+1;atlas=Image.new('RGBA',(width,height))
    for im,info in entries:
        x,y,w,h=info['rect'];atlas.paste(im,(x,y))
        atlas.paste(im.crop((0,0,w,1)),(x,y-1));atlas.paste(im.crop((0,h-1,w,h)),(x,y+h));atlas.paste(im.crop((0,0,1,h)),(x-1,y));atlas.paste(im.crop((w-1,0,w,h)),(x+w,y))
        for dx,dy,sx,sy in [(-1,-1,0,0),(w,-1,w-1,0),(-1,h,0,h-1),(w,h,w-1,h-1)]:atlas.putpixel((x+dx,y+dy),im.getpixel((sx,sy)))
    atlas.save(HERE/'atlas.png',optimize=True)
    manifest['atlas_size']=[width,height];manifest['atlas_sha256']=sha(HERE/'atlas.png')
    (HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    preview=Image.new('RGB',(7*160,170),'#203744')
    for i,role in enumerate(ROLE_NAMES):
        im=plan[role]['idle'][0];preview.paste(im,(i*160-16,-8),im)
    preview.save(HERE/'concept-lineup.png')
    # Two chest frames are separate UI assets; preserve native base geometry width
    # with the same source-scale for both; common canvas and bottom anchor.
    chest_img=[]; chest_src=[]
    for c in range(2):
        crop,rec=source_cell('chest',0,c)
        if c==0:scale=112/core_bbox(crop)[2]
        chest_img.append(crop);chest_src.append(rec)
    dest=PROJECT/'assets'/'items';dest.mkdir(parents=True,exist_ok=True)
    for i,im in enumerate(chest_img):
        w,h=round(im.width*scale),round(im.height*scale);im=im.resize((w,h),Image.Resampling.NEAREST)
        cx=Image.new('RGBA',(144,160));cx.paste(im,((144-w)//2,151-h))
        cx.save(dest/('chest_closed.png' if i==0 else 'chest_open.png'),optimize=True)
    print(len(entries),'entries; atlas',width,height,'bytes',(HERE/'atlas.png').stat().st_size)
if __name__=='__main__':generate()
