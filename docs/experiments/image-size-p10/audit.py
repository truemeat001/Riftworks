from pathlib import Path
from PIL import Image
import json
root=Path('RiftworksP09/assets')
groups={
 'atlas.png':(0,0,'exact atlas dedup; not arbitrary whole-sheet rescale'),
 'concept-lineup.png':(0,0,'unused concept reference; exclude from runtime only'),
 'deployment_pad.png':(70,51,'candidate 140x102'),
 'lighthouse.png':(59,114,'candidate 118x228'),
 'portal.png':(104,95,'candidate 208x190'),
 'chest_closed.png':(160,160,'candidate 320x320'),
 'chest_open.png':(160,160,'candidate 320x320'),
}
rows=[]
for f in sorted(root.rglob('*')):
 if not f.is_file() or f.suffix.lower() not in {'.png','.jpeg','.jpg','.webp','.gif'}:continue
 im=Image.open(f)
 if f.name in groups:w,h,s=groups[f.name]
 elif 'background' in f.name:w,h,s=1016,630,'candidate 1280x800 or 1024x640, compare WebP with PNG lossless/quality'
 elif 'portraits' in f.parts:w,h,s=106,106,'candidate 208x208; largest loot reveal not reserve icon'
 elif 'relics' in f.parts:w,h,s=106,106,'128x128 keep; loot reveal larger than 21px button'
 else:w,h,s=0,0,'inspect'
 rows.append(dict(path=str(f.relative_to(root)),source=[im.width,im.height],display=[w,h],file_bytes=f.stat().st_size,rgba8_bytes=im.width*im.height*4,linear_ratio=round(max(im.width/w,im.height/h),2) if w and h else None,recommendation=s))
print(json.dumps(rows,indent=2))
Path('RiftworksP10-lab/image-size-audit/metrics.json').write_text(json.dumps(rows,indent=2)+'\n')
print('count',len(rows),'RGBA8 bytes',sum(x['rgba8_bytes'] for x in rows),'PNG bytes',sum(x['file_bytes'] for x in rows))
