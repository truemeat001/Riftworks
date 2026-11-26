"""Offline exact source-pixel atlas dedup. Runtime flip_x integration is a separate gate."""
from pathlib import Path
import hashlib,json,sys
from PIL import Image, ImageOps
def pack(manifest_path, input_atlas, output_dir):
    m=json.loads(Path(manifest_path).read_text())
    old=Image.open(input_atlas).convert('RGBA')
    pad=m['padding']
    items={}; frames=[]; count=0
    for char,states in m['characters'].items():
        for state,seq in states.items():
            for i,f in enumerate(seq):
                x,y,w,h=f['rect']
                rgba=old.crop((x-pad,y-pad,x+w+pad,y+h+pad))
                flip=ImageOps.mirror(rgba)
                direct=hashlib.sha256(rgba.tobytes()).hexdigest()
                mirrored=hashlib.sha256(flip.tobytes()).hexdigest()
                key=(rgba.size,min(direct,mirrored))
                rev=direct>mirrored
                canonical=flip if rev else rgba
                if key in items:
                    assert items[key].tobytes()==canonical.tobytes()
                else: items[key]=canonical
                frames.append((f,key,rev,rgba))
                count+=1
    def shelf(width):
        x=y=row_h=0; placements={}
        for key,img in sorted(items.items(),key=lambda z:(-z[1].height,-z[1].width,z[0])):
            if img.width>width:return None
            if x+img.width>width:
                y+=row_h; x=0; row_h=0
            placements[key]=(x,y);x+=img.width;row_h=max(row_h,img.height)
        return width,y+row_h,placements
    candidates=[shelf(w) for w in range(256,2049,64)]
    w,h,placements=min((z for z in candidates if z),key=lambda z:(z[0]*z[1],max(z[0],z[1])))
    out=Image.new('RGBA',(w,h))
    for key,img in items.items():out.paste(img,placements[key])
    for f,key,rev,orig in frames:
        x,y=placements[key];ww,hh=orig.size
        actual=out.crop((x,y,x+ww,y+hh))
        if rev:actual=ImageOps.mirror(actual)
        assert actual.tobytes()==orig.tobytes(), 'Mismatch incl extrusion border'
        f['rect']=[x+pad,y+pad,ww-2*pad,hh-2*pad]
        f['flip_x']=rev
    dest=Path(output_dir);dest.mkdir(parents=True,exist_ok=True)
    out.save(dest/'atlas.png',optimize=True)
    m['atlas_size']=[w,h];m['atlas_sha256']=hashlib.sha256((dest/'atlas.png').read_bytes()).hexdigest()
    m['note']='Dedup candidate. Source rectangles can share pixels; flip_x flag must be supported by renderer. Offsets preserved.'
    (dest/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
    report=dict(old_size=list(old.size),new_size=[w,h],old_frames=count,unique_padded_images=len(items),pixel_exact_reconstructed=count,old_rgba_bytes=old.width*old.height*4,new_rgba_bytes=w*h*4,old_png=Path(input_atlas).stat().st_size,new_png=(dest/'atlas.png').stat().st_size,padded_utilization=sum(i.width*i.height for i in items.values())/(w*h))
    (dest/'metrics.json').write_text(json.dumps(report,indent=2)+'\n')
    return report
if __name__=='__main__':
    print(json.dumps(pack(*sys.argv[1:]),indent=2))
