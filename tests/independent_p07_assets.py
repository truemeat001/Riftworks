from PIL import Image
from pathlib import Path
import sys,hashlib
p=Path(sys.argv[1]);checks=0;failures=[]; hashes={}
def check(v,name):
 global checks
 checks+=1
 if not v:failures.append(name)
def file(name,alpha=False):
 f=p/name;check(f.is_file(),name+" exists")
 if not f.is_file():return
 with Image.open(f) as i:
  im=i.convert("RGBA");a=im.getchannel('A');check(im.width>32 and im.height>32,name+" usable dimensions")
  if alpha:
   check(a.getextrema()[0]==0 and a.getextrema()[1]>=220,name+" alpha background+foreground")
   check(a.getbbox() is not None,name+" nonempty")
  else:check(len(im.getcolors(im.width*im.height))>50,name+" not blank")
 hashes[name]=hashlib.sha256(f.read_bytes()).hexdigest()
for x in ["tidecross","twintide","echoreef"]:file(f"environment/{x}_background.png")
for x in ["portal","lighthouse","deployment_pad"]:file(f"environment/{x}.png",True)
for x in ["open","closed"]:file(f"items/chest_{x}.png",True)
for x in ["rapid","blast","range","relay","chain","focus","power","freeze"]:file(f"items/relics/{x}.png",True)
for x in ["pulse","frost","burst"]:file(f"characters/portraits/{x}.png",True)
for group in [["environment/tidecross_background.png","environment/twintide_background.png","environment/echoreef_background.png"],["items/chest_open.png","items/chest_closed.png"],[f"items/relics/{x}.png" for x in ["rapid","blast","range","relay","chain","focus","power","freeze"]]]:
 check(len({hashes.get(x) for x in group})==len(group),"unique member content "+str(group))
print("ART",checks,"checks","failures",failures,"hashes",hashes)
sys.exit(bool(failures))
