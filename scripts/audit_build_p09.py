#!/usr/bin/env python3
"""Read-only Godot v4 Web ZIP/PCK inventory. Refuse unknown layout, verify payload digests."""
import argparse, collections, hashlib, json, struct, wave, zipfile
from pathlib import Path
from PIL import Image

def digest(b): return hashlib.sha256(b).hexdigest()

def inventory(pck):
    if pck[:4] != b"GDPC" or struct.unpack_from("<I", pck, 4)[0] != 4:
        raise ValueError("unsupported PCK format")
    flags, base, pos = struct.unpack_from("<IQQ", pck, 20)
    if flags != 2: raise ValueError(f"unrecognized flags {flags}")
    count, = struct.unpack_from("<I", pck, pos)
    pos += 4
    rows = []
    for _ in range(count):
        n, = struct.unpack_from("<I", pck, pos); pos += 4
        name = pck[pos:pos+n].rstrip(b"\0").decode(); pos += n
        off, size, md5, entry_flags = struct.unpack_from("<QQ16sI", pck, pos); pos += 36
        data = pck[base+off:base+off+size]
        if entry_flags or len(data) != size or hashlib.md5(data).digest() != md5:
            raise ValueError(f"unsupported/invalid entry: {name}")
        rows.append(dict(name=name,size=size,sha256=digest(data)))
    if pos != len(pck): raise ValueError("unparsed directory trailer")
    return rows

def audit(archive, source):
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None: raise ValueError("ZIP CRC mismatch")
        pck = z.read("index.pck")
        rows = inventory(pck)
        lookup = {r["name"]: r for r in rows}
        cat=collections.Counter()
        texture_bytes=pcm_bytes=0
        assets=[]
        for r in rows:
            n=r["name"]
            category=("texture" if n.endswith(".ctex") else "audio" if n.endswith(".sample") else "scripts" if n.endswith(".gdc") else "other")
            cat[category]+=r["size"]
        for f in sorted((source/"assets").rglob("*")):
            if f.suffix not in (".wav",".png"):continue
            rel=f.relative_to(source).as_posix()
            obj=dict(source=rel,source_bytes=f.stat().st_size)
            if f.suffix==".png":
                with Image.open(f) as im:
                    obj.update(width=im.width,height=im.height,rgba_upper=im.width*im.height*4)
            else:
                with wave.open(str(f)) as w:
                    obj.update(channels=w.getnchannels(),frames=w.getnframes(),rate=w.getframerate(),sample_width=w.getsampwidth(),pcm_bytes=w.getnframes()*w.getnchannels()*w.getsampwidth())
            # Map via exact packaged import remap file, not basename guess.
            remap=rel+".import"
            obj["packaged"]=remap in lookup
            if obj["packaged"]:
                import re
                imp=(source/remap).read_text() if (source/remap).exists() else ""
                m=re.search(r'^path="res://([^"]+)"',imp,re.M)
                if m and m[1] in lookup:obj["imported_bytes"]=lookup[m[1]]["size"]
                if f.suffix==".png":texture_bytes+=obj["rgba_upper"]
                else:pcm_bytes+=obj["pcm_bytes"]
            assets.append(obj)
        return dict(archive=str(archive),zip_bytes=archive.stat().st_size,zip_sha256=digest(archive.read_bytes()),
                    zip_entries=[dict(name=i.filename,raw=i.file_size,compressed=i.compress_size) for i in z.infolist()],
                    pck_bytes=len(pck),pck_sha256=digest(pck),pck_entries=len(rows),payload_bytes=sum(r["size"] for r in rows),
                    payload_categories=dict(cat),pck_overhead=len(pck)-sum(r["size"] for r in rows),
                    unexpected_authoring=[r for r in rows if any(r["name"].startswith(prefix) for prefix in ("docs/","tests/","scripts/","assets/audio/master/"))],
                    packaged_rgba_upper=texture_bytes,packaged_pcm16_bytes=pcm_bytes,assets=assets,entries=rows)

if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("archive",type=Path);ap.add_argument("source",type=Path);a=ap.parse_args()
    print(json.dumps(audit(a.archive,a.source),indent=2))
