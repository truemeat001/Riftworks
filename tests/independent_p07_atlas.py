# Independent atlas integrity, distinct authored poses and anchor reconstruction.
import json, sys, hashlib
from pathlib import Path
from PIL import Image
p=Path(sys.argv[1]); m=json.loads((p/'manifest.json').read_text()); a=Image.open(p/'atlas.png').convert("RGBA")
checks=0; failures=[]; rects=[]; counts={}; reconstructed={}; occupancy=Image.new("1",a.size)
def ck(v,label):
    global checks
    checks+=1
    if not v: failures.append(label)
def sha(b): return hashlib.sha256(b).hexdigest()
ck(list(a.size)==m["atlas_size"],"atlas dims")
ck(sha((p/'atlas.png').read_bytes())==m["atlas_sha256"],"atlas sha")
for filename,digest in m.get("source_sheets",{}).items():
    f=p.parent.parent/"docs"/"art-sources-p05"/filename
    ck(f.exists() and sha(f.read_bytes())==digest,"recorded source sheet byte hash "+filename)
for key,note in m.get("portraits",{}).items():
    f=p.parent.parent/note["path"]
    ck(f.exists() and sha(f.read_bytes())==note["sha256"],"recorded source portrait hash "+key)
    if f.exists():
        with Image.open(f) as portrait:
            ck(portrait.size==(256,256),key+" portrait dimensions")
            ck(portrait.convert("RGBA").getchannel("A").getextrema()[0]==0,key+" transparent portrait")
f=p.parent.parent/"docs"/"art-sources-p05"/"crew-portraits.png"
ck(f.exists() and sha(f.read_bytes())==m["portrait_source_sha256"],"original portrait source hash")
ck(set(m["characters"])=={"pulse","frost","burst","crab","sail","urchin","boss"},"7 roles")
aw,ah=m["authoring_size"]; ax,ay=m["anchor"]; pad=m["padding"]
for k, clips in m["characters"].items():
    counts[k]={}; reconstructed[k]={}
    active={"idle":(2,2),"attack":(6,4)} if k in {"pulse","frost","burst"} else {"run":(4,4),"hurt":(2,2),"death":(4,3)}
    for state,(count,unique) in active.items():
        ck(state in clips and state+"_left" in clips,f"{k}/{state}: active clip exists both directions")
        if state in clips:
            ck(len(clips[state])>=count,f"{k}/{state}: enough active frames")
    for state, frames in clips.items():
        if not isinstance(frames,list):continue
        ck(len(frames)>0,f"{k}/{state}: nonempty")
        recon=[]
        for i,f in enumerate(frames):
            tag=f"{k}/{state}/{i}"; x,y,w,h=f["rect"]; ox,oy=f["offset"]; l=ax+ox;t=ay+oy
            ck(pad<=x and pad<=y and x+w+pad<=a.width and y+h+pad<=a.height and w>0 and h>0,tag+" bounds")
            ck(0<=l and 0<=t and l+w<=aw and t+h<=ah,tag+" anchor restore")
            r=a.crop((x,y,x+w,y+h))
            ck(r.getchannel('A').getbbox()==(0,0,w,h),tag+" tight AABB")
            padded=(x-pad,y-pad,x+w+pad,y+h+pad)
            # Deduplication is valid if rectangles have exactly identical extent and pixels.
            if (x,y,w,h) not in rects:
                ck(occupancy.crop(padded).getbbox() is None,tag+" padded rects disjoint")
                occupancy.paste(1,padded); rects.append((x,y,w,h))
            for actual, expected in [
                (a.crop((x,y-pad,x+w,y)),r.crop((0,0,w,1)).resize((w,pad),Image.Resampling.NEAREST)),
                (a.crop((x,y+h,x+w,y+h+pad)),r.crop((0,h-1,w,h)).resize((w,pad),Image.Resampling.NEAREST)),
                (a.crop((x-pad,y,x,y+h)),r.crop((0,0,1,h)).resize((pad,h),Image.Resampling.NEAREST)),
                (a.crop((x+w,y,x+w+pad,y+h)),r.crop((w-1,0,w,h)).resize((pad,h),Image.Resampling.NEAREST)),
            ]:
                ck(actual.tobytes()==expected.tobytes(),tag+f" {pad}px edge extrusion")
            restored=Image.new("RGBA",(aw,ah)); restored.paste(r,(l,t)); recon.append(sha(restored.tobytes())); reconstructed[k].setdefault(state,[]).append(restored)
        distinct=len(set(recon));counts[k][state]=distinct
        active_name=state.removesuffix("_left")
        if active_name in active:
            ck(distinct>=active[active_name][1],f"{k}/{state}: active distinct reconstructed poses >= {active[active_name][1]}")
    for state in active:
        if state not in reconstructed[k] or state+"_left" not in reconstructed[k]:continue
        for i,img in enumerate(reconstructed[k][state]):
            mirrored=img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            ck(mirrored.tobytes()==reconstructed[k][state+"_left"][i].tobytes(),f"{k}/{state}/{i}: mirror exact pivot")
print("ATLAS",a.size,"unique_rects",len(rects),"distinct frames",counts,"checks",checks,"failures",failures)
sys.exit(bool(failures))
