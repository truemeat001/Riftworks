#!/usr/bin/env python3
"""Independent audio data checks. Does not establish subjective listening or hardware output."""
from pathlib import Path
import hashlib, json, math, sys, wave
import numpy as np
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
rows=json.loads((root/"docs/audio-p09-manifest.json").read_text(encoding="utf-8"))
checks=0; fails=[]; events={}; metrics=[]
def ck(v,tag):
 global checks
 checks+=1
 if not v:fails.append(tag)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def decoded(p):
 with wave.open(str(p),"rb") as w:
  rate=w.getframerate(); channels=w.getnchannels(); width=w.getsampwidth(); frames=w.getnframes()
  raw=w.readframes(frames)
 if width==2:a=np.frombuffer(raw,dtype="<i2").astype(np.float64)/32768
 elif width==3:
  b=np.frombuffer(raw,dtype=np.uint8).reshape(-1,3).astype(np.int32)
  n=b[:,0]+(b[:,1]<<8)+(b[:,2]<<16)
  n=np.where(n>=0x800000,n-0x1000000,n)
  a=n.astype(np.float64)/8388608
 else:raise ValueError(f"Unexpected PCM width {width}")
 return a.reshape(-1,channels),(rate,channels,width,frames)
def db(x):return 20*math.log10(max(float(x),1e-12))
ck(len(rows)==45,"45 manifest events/variants")
for r in rows:
 label=f"{r['event']}:{r['variant']}"
 m=root/r["master"]; runtime=root/r["runtime"]
 ck(m.is_file() and runtime.is_file(),label+" files exist")
 if not m.exists() or not runtime.exists():continue
 ck(sha(m)==r["master_sha256"],label+" master sha")
 ck(sha(runtime)==r["runtime_sha256"],label+" runtime sha")
 a,x=decoded(m);b,y=decoded(runtime)
 ck(x==(48000,r["channels"],3,r["frames"]),label+" original PCM24 header and count")
 ck(y==(48000,r["channels"],2,r["frames"]),label+" runtime PCM16 header and count")
 ck(abs(r["frames"]/48000-r["seconds"])<0.0001,label+" sample duration")
 peak=db(np.max(np.abs(b)));rms=db(np.sqrt(np.mean(b*b)))
 ck(peak<=-3+0.02 and peak>-60,label+" finite headroom and non-silent")
 ck(abs(peak-r["peak_dbfs"])<.08 and abs(rms-r["rms_dbfs"])<.08,label+" independently recomputed metrics")
 ck(a.shape==b.shape and np.max(np.abs(a-b))<3/32768,label+" master-runtime quantization alignment")
 if r["loop"]:
  seam=np.max(np.abs(b[0]-b[-1]))
  ck(r["frames"]==576000 and r["channels"]==2,label+" actual 12s stereo loop")
  ck(seam<.015,label+" bounded loop boundary delta (not subjective audition)")
  metrics.append([label,peak,rms,float(seam)])
 else:
  ck(r["channels"]==1,label+" mono event")
  ck(np.max(np.abs(b[-1]))<0.015,label+" non-loop tail near zero")
 events.setdefault(r["event"],set()).add(r["runtime_sha256"])
for event,hashes in events.items():
 ck(len(hashes)==sum(r["event"]==event for r in rows),event+" actual variant byte diversity")
print("AUDIO_FILE_QA",checks,"failures",fails,"loops",metrics)
sys.exit(bool(fails))
