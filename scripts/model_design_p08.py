#!/usr/bin/env python3
"""Actual Godot P07/P08 paired strategy experiment. No human-play claim.

Run with exact P07 source and isolated candidate. Candidate must expose
tide_transfers [{tick,tower_id,donor_id,recipient_id,duration,...}].
Every character/relic is obtained through real draw_loot; no fixtures/injection.
"""
import argparse, hashlib, json, os, subprocess, tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
P07_HASH="55f266962887b78956bc80542594ec337fe533d62c4deeee5b725888653dbf6e"
GDS=r'''
extends SceneTree
const R=preload("res://src/Run.gd")
func crew(r):return r.towers+r.reserve
func merge_pair(r):
 var items=crew(r)
 if items.size()<=5:return false
 for i in range(items.size()):
  for j in range(i+1,items.size()):
   var a=items[i];var b=items[j]
   if a.kind==b.kind and a.rank==b.rank and a.rank<3:return r.merge_towers(a.id,b.id)
 return false
func buy(r):
 while r.gold>=6:
  if r.draw_loot().is_empty():break
  while merge_pair(r):pass
func points(route):
 var out=[]
 for i in range(route.size()-1):
  var p:Vector2=route[i]
  while p.distance_to(route[i+1])>0.01:
   out.append(p);p=p.move_toward(route[i+1],0.5)
 return out
func deploy_policy(r,strategy):
 for t in r.towers.duplicate():r.recall(t.id)
 var items=r.reserve.duplicate()
 items.sort_custom(func(a,b):return a.rank>b.rank or (a.rank==b.rank and a.id<b.id))
 var points_all=points(r.path())
 if r.stage==1 and r.opened:points_all.append_array(points(r.path(false)))
 var using_special=false
 var pair=[]
 if strategy=="special" and r.level("freeze")>0:
  var frost={};var burst={}
  for t in items:
   if t.kind==1 and frost.is_empty():frost=t
   if t.kind==2 and burst.is_empty():burst=t
  if not frost.is_empty() and not burst.is_empty():
   items.erase(frost);items.erase(burst)
   items.push_front(burst);items.push_front(frost)
   pair=[frost.id,burst.id];using_special=true
 for t in items:
  if r.towers.size()>=R.MAX_TOWERS:break
  var best_score=-1.0;var best=Vector2i(-1,-1)
  var frost={}
  if using_special and t.id==pair[1] and not r.towers.is_empty():frost=r.towers[0]
  for x in range(R.COLS):
   for y in range(R.ROWS):
    var c=Vector2i(x,y)
    if not r.placement_error(c,t.kind,t.id).is_empty():continue
    var st=r.preview_stats(c,t.kind,t.rank,t.id)
    var score=0.0
    var frost_range=0.0
    if not frost.is_empty():frost_range=r.stats(frost)[1]
    for p in points_all:
     if Vector2(c).distance_to(p)<=st[1]:
      score+=0.5
      # Favor overlapping a Frost footprint when the acquired relic unlocks transfer.
      # Same placement objective executed under P07 and P08 to isolate mechanics.
      if not frost.is_empty() and Vector2(frost.cell).distance_to(p)<=frost_range:score+=0.75
    if score>best_score:best_score=score;best=c
  if best.x>=0:r.deploy(t.id,best)
 return using_special
func simulate(seed,strategy,risk,is_candidate):
 var r=R.new();r.reset(seed);var hist=[]
 while r.phase=="build" and hist.size()<6:
  var wave=r.stage*2+r.wave+1
  if r.stage==1 and r.opened!=risk:r.alter()
  buy(r)
  var used_special=deploy_policy(r,strategy)
  var eligible=r.level("freeze")>0 and r.towers.any(func(t):return t.kind==1) and r.towers.any(func(t):return t.kind==2)
  var assets=crew(r).map(func(t):return [t.id,t.kind,t.rank,t.cell.x,t.cell.y])
  var cores=r.upgrades.duplicate();var gold=r.gold;var hp_before=r.hp
  if not r.start():break
  var ticks=0;var transferred=0.0;var events=0;var primary_events=0
  var boss_prev_hp=0.0
  while r.phase=="fight" and ticks<4000:
   for e in r.enemies:
    if e.boss:boss_prev_hp=e.hp
   r.step();ticks+=1
   if is_candidate:
    var donor_set={}
    for event in r.tide_transfers:
     if event.tick==r.tick_count:
      events+=1;transferred+=event.duration
      donor_set["%s:%s"%[event.tower_id,event.donor_id]]=true
    primary_events+=donor_set.size()
  hist.append({"wave":wave,"assets":assets,"cores":cores,"gold_before":gold,"hp_before":hp_before,
               "eligible":eligible,"used_special":used_special,"hp":r.hp,"leaks":r.wave_leaks,"ticks":ticks,
               "payout":r.gold-gold,"phase":r.phase,"events":events,"donations":primary_events,
               "seconds":transferred,"boss_previous_tick_hp":0 if r.boss_defeated else boss_prev_hp})
 return {"seed":seed,"strategy":strategy,"risk":risk,"phase":r.phase,"hp":r.hp,"waves":hist}
func _initialize():
 var args=OS.get_cmdline_user_args()
 var start=int(args[0]);var count=int(args[1]);var candidate=args[2]=="candidate"
 for seed in range(start,start+count):
  for risk in [false,true]:
   for policy in ["generic","special"]:
    print("REC ",JSON.stringify(simulate(seed,policy,risk,candidate)))
 quit()
'''

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def simulate(src,mode,path,godot,start,count):
    path.mkdir();(path/"src").mkdir()
    (path/"src/Run.gd").write_bytes(src.read_bytes())
    (path/"probe.gd").write_text(GDS)
    (path/"project.godot").write_text('[application]\nconfig/name="Riftworks P08 model"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    env=os.environ.copy()
    for key,sub in [("XDG_CACHE_HOME","cache"),("XDG_DATA_HOME","data"),("XDG_CONFIG_HOME","config")]:
        (path/sub).mkdir();env[key]=str(path/sub)
    cp=subprocess.run([godot,"--headless","--path",str(path),"--script","res://probe.gd","--",str(start),str(count),mode],capture_output=True,text=True,check=True,timeout=420,env=env)
    if "SCRIPT ERROR" in cp.stderr:raise RuntimeError(cp.stderr)
    rows=[json.loads(line[4:]) for line in cp.stdout.splitlines() if line.startswith("REC ")]
    assert len(rows)==count*4,len(rows)
    return rows

def outcomes(rows):
    return {"runs":len(rows),"wins":sum(x["phase"]=="won" for x in rows),
            "two_waves_clear":sum(len(x["waves"])>=2 and all(w["phase"]=="build" for w in x["waves"][:2]) for x in rows),
            "eligible_runs":sum(any(w["eligible"] for w in x["waves"]) for x in rows),
            "transfer_runs":sum(any(w["events"] for w in x["waves"]) for x in rows),
            "transfer_recipients":sum(w["events"] for x in rows for w in x["waves"]),
            "donations":sum(w["donations"] for x in rows for w in x["waves"]),
            "slow_seconds_redistributed":round(sum(w["seconds"] for x in rows for w in x["waves"]),3),
            "risk_bonus":sum(w["payout"]==18 for x in rows for w in x["waves"])}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--baseline",type=Path,default=ROOT.parent/"RiftworksP07/src/Run.gd")
    p.add_argument("--candidate",type=Path,default=ROOT/"src/Run.gd")
    p.add_argument("--start",type=int,default=437);p.add_argument("--count",type=int,default=60)
    p.add_argument("--godot",default="godot");p.add_argument("--json",type=Path)
    args=p.parse_args()
    assert sha(args.baseline)==P07_HASH,"require frozen P07 baseline"
    assert "tide_transfers" in args.candidate.read_text(),"candidate source lacks transfer mechanic"
    with tempfile.TemporaryDirectory(prefix="riftworks-p08-design-") as tmp:
        base=simulate(args.baseline,"baseline",Path(tmp)/"base",args.godot,args.start,args.count)
        candidate=simulate(args.candidate,"candidate",Path(tmp)/"candidate",args.godot,args.start,args.count)
    keys=lambda rows:{(x["seed"],x["strategy"],x["risk"]):x for x in rows}
    a,b=keys(base),keys(candidate)
    assert a.keys()==b.keys()
    groups={}
    for strategy in ("generic","special"):
        for risk in (False,True):
            kk=[k for k in a if k[1:]==(strategy,risk)]
            before=[a[k] for k in kk];after=[b[k] for k in kk]
            result={"baseline":outcomes(before),"candidate":outcomes(after),"wins_gained":[],"wins_lost":[],
                    "eligible_same_asset_waves":0,"improved_leak_or_outcome":[],"worse_leak_or_outcome":[],
                    "transfer_waves_same_input":0,"no_transfer_runs_changed":[]}
            for k in kk:
                v1,v2=a[k],b[k]
                if v1["phase"]!="won" and v2["phase"]=="won":result["wins_gained"].append(k[0])
                if v1["phase"]=="won" and v2["phase"]!="won":result["wins_lost"].append(k[0])
                if not any(w["events"] for w in v2["waves"]) and v1!=v2:
                    result["no_transfer_runs_changed"].append(k[0])
                for w1,w2 in zip(v1["waves"],v2["waves"]):
                    # Same paid roster IDs/type/rank/positions and starting state;
                    # same wave, HP, and residual gold; no comparison after economic divergence.
                    if not all(w1[k0]==w2[k0] for k0 in ("wave","assets","cores","gold_before","hp_before")):continue
                    if w2["eligible"]:result["eligible_same_asset_waves"]+=1
                    if w2["events"]:
                        result["transfer_waves_same_input"]+=1
                        row=[k[0],w2["wave"],w1["leaks"],w2["leaks"],w1["phase"],w2["phase"],w2["events"],w1["payout"],w2["payout"]]
                        win_improved=(w1["phase"]=="lost" and w2["phase"]!="lost")
                        win_worse=(w1["phase"]!="lost" and w2["phase"]=="lost")
                        if win_improved or (not win_worse and w2["leaks"]<w1["leaks"]):result["improved_leak_or_outcome"].append(row)
                        if win_worse or (not win_improved and w2["leaks"]>w1["leaks"]):result["worse_leak_or_outcome"].append(row)
            groups[f"{strategy}:risk={risk}"]=result
    report={"baseline_sha256":sha(args.baseline),"candidate_sha256":sha(args.candidate),"seed_range":[args.start,args.start+args.count-1],"runs":len(base)+len(candidate),"groups":groups}
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if args.json:args.json.write_text(json.dumps({"report":report,"baseline":base,"candidate":candidate},ensure_ascii=False,indent=2))
if __name__=="__main__":main()
