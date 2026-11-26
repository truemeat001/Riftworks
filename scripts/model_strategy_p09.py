#!/usr/bin/env python3
"""P09 actual four-rule matched strategy experiment, no human-play claim.

All assets obtained from real Run.draw_loot; use exact production and a temporary
copy with only GUARD_ESCORT_ENABLED=false. No edit to either frozen source.
"""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[1]
P08_SHA="d1a16caee466754bf25e1ae22a21ccd8e9701960e47366b2705e8178a4425681"
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
func plan(r,layout):
 for t in r.towers.duplicate():r.recall(t.id)
 var items=r.reserve.duplicate()
 items.sort_custom(func(a,b):return a.rank>b.rank or (a.rank==b.rank and a.id<b.id))
 var pts=points(r.path())
 if r.stage==1 and r.opened:pts.append_array(points(r.path(false)))
 var pair=[]
 if layout=="special":
  var mist={};var hammer={};var brass={}
  for t in items:
   if t.kind==1 and mist.is_empty():mist=t
   elif t.kind==2 and hammer.is_empty():hammer=t
   elif t.kind==0 and brass.is_empty():brass=t
  var partner=hammer if not hammer.is_empty() else brass
  if not mist.is_empty() and not partner.is_empty():
   items.erase(mist);items.erase(partner)
   items.push_front(partner);items.push_front(mist)
   pair=[mist.id,partner.id]
 for t in items:
  if r.towers.size()>=R.MAX_TOWERS:break
  var best_score=-1.0;var best=Vector2i(-1,-1)
  var mist={}
  if pair.size()==2 and t.id==pair[1] and not r.towers.is_empty():mist=r.towers[0]
  var miss_range=0.0 if mist.is_empty() else r.stats(mist)[1]
  for x in range(R.COLS):
   for y in range(R.ROWS):
    var c=Vector2i(x,y)
    if not r.placement_error(c,t.kind,t.id).is_empty():continue
    var st=r.preview_stats(c,t.kind,t.rank,t.id)
    var score=0.0
    for p in pts:
     if Vector2(c).distance_to(p)<=st[1]:
      score+=0.5
      if not mist.is_empty() and Vector2(mist.cell).distance_to(p)<=miss_range:score+=0.75
    if score>best_score:best_score=score;best=c
  if best.x>=0:r.deploy(t.id,best)
 return pair
func set_orders(r,policy):
 var modes=[]
 var gold=r.gold;var rng=r.rng.state
 for t in crew(r):
  var mode="front"
  if policy=="situational":
   if t.kind==1 and (r.stage>=1 or r.wave==1):mode="screen"
   elif t.kind==2 and not (r.stage==2 and r.wave==1):mode="cluster"
  if not r.set_order(t.id,mode):
   push_error("set_order rejected valid mode");quit(2)
  if mode!="front" and r.towers.any(func(item):return t.id==item.id):modes.append([t.id,mode])
 if gold!=r.gold or rng!=r.rng.state:push_error("order mutated currency/RNG");quit(3)
 return modes
func snapshot(r):
 # Guard presentation metadata intentionally excluded; everything that affects
 # authoritative combat and existing event streams remains.
 return {"stage":r.stage,"wave":r.wave,"hp":r.hp,"gold":r.gold,"phase":r.phase,
         "route_choice":r.route_choice,"opened":r.opened,"towers":r.towers,"reserve":r.reserve,
         "next_tower_id":r.next_tower_id,"enemies":r.enemies,"upgrades":r.upgrades,
         "shots":r.shots,"deaths":r.deaths,"tide_transfers":r.tide_transfers,
         "tick":r.tick_count,"pending":r.pending,"pending_main":r.pending_main,
         "pending_extra":r.pending_extra,"spawn_time":r.spawn_time,"kills":r.kills,
         "wave_leaks":r.wave_leaks,"run_leaks":r.run_leaks,"wave_damage":r.wave_damage,
         "boss_defeated":r.boss_defeated,"spawn_count":r.spawn_count,"rng":r.rng.state,"last_loot":r.last_loot}
func state_hash(r):
 var ctx=HashingContext.new()
 ctx.start(HashingContext.HASH_SHA256)
 ctx.update(var_to_bytes(snapshot(r)))
 return ctx.finish().hex_encode()
func simulate(seed,risk,layout,policy,api,trace_count):
 var r=R.new();r.reset(seed);var hist=[]
 while r.phase=="build" and hist.size()<6:
  var wave=r.stage*2+r.wave+1
  if r.stage==1 and r.opened!=risk:r.alter()
  buy(r);var pair=plan(r,layout)
  var active=set_orders(r,policy) if api else []
  var assets=crew(r).map(func(t):return [t.id,t.kind,t.rank,t.cell.x,t.cell.y])
  var has_hammer=r.towers.any(func(t):return t.kind==2)
  var cores=r.upgrades.duplicate();var gold=r.gold;var hp_before=r.hp
  var rng_before=str(r.rng.state);var tick_before=r.tick_count
  if not r.start():break
  var prep_hash=state_hash(r)
  var trace=HashingContext.new();var tracing=seed<437+trace_count
  if tracing:
   trace.start(HashingContext.HASH_SHA256);trace.update(var_to_bytes(snapshot(r)))
  var ticks=0;var boss_hp=0.0;var tides=0;var events=0;var transferred=0.0
  while r.phase=="fight" and ticks<4000:
   for e in r.enemies:
    if e.boss:boss_hp=e.hp
   r.step();ticks+=1
   for event in r.tide_transfers:
    if event.tick==r.tick_count:tides+=1
   if api:
    for event in r.guard_intercepts:
     if event.tick==r.tick_count:
      events+=1;transferred+=event.damage
      if event.ready_tick!=event.tick+24:push_error("invalid guard cooldown");quit(4)
   if tracing:trace.update(var_to_bytes(snapshot(r)))
  hist.append({"wave":wave,"assets":assets,"cores":cores,"gold":gold,"rng":rng_before,
               "tick_before":tick_before,"hp_before":hp_before,"active_orders":active,"pair":pair,
               "has_hammer":has_hammer,"prep_hash":prep_hash,"end_hash":state_hash(r),
               "trace_hash":trace.finish().hex_encode() if tracing else "",
               "phase":r.phase,"hp":r.hp,"leaks":r.wave_leaks,"ticks":ticks,"kills":r.kills,
               "damage":r.wave_damage,"payout":r.gold-gold,"tide":tides,"guard_events":events,
               "guard_damage":transferred,"boss_previous_tick_hp":0 if r.boss_defeated else boss_hp})
 return {"seed":seed,"risk":risk,"layout":layout,"policy":policy,"phase":r.phase,"hp":r.hp,"history":hist}
func _initialize():
 var args=OS.get_cmdline_user_args()
 var count=int(args[0]);var api=args[1]!="base";var trace_count=int(args[2])
 for seed in range(437,437+count):
  for layout in ["generic","special"]:
   for risk in [false,true]:
    for policy in (["front","situational"] if api else ["front"]):
     print("REC ",JSON.stringify(simulate(seed,risk,layout,policy,api,trace_count)))
 quit()
'''
def sha(b):return hashlib.sha256(b).hexdigest()
def run(src,name,path,args):
    path.mkdir();(path/"src").mkdir()
    (path/"src/Run.gd").write_bytes(src);(path/"probe.gd").write_text(GDS)
    (path/"project.godot").write_text('[application]\nconfig/name="Riftworks P09 factorial model"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    env=os.environ.copy()
    for key,sub in [("XDG_CACHE_HOME","cache"),("XDG_DATA_HOME","data"),("XDG_CONFIG_HOME","config")]:
        (path/sub).mkdir();env[key]=str(path/sub)
    cp=subprocess.run([args.godot,"--headless","--path",str(path),"--script","res://probe.gd","--",str(args.count),name,str(args.trace_count)],capture_output=True,text=True,check=True,timeout=720,env=env)
    if "SCRIPT ERROR" in cp.stderr or "ERROR:" in cp.stderr:raise RuntimeError(cp.stderr)
    data=[json.loads(l[4:]) for l in cp.stdout.splitlines() if l.startswith("REC ")]
    assert len(data)==args.count*(4 if name=="base" else 8),len(data)
    return data
def index(rows):
    return {(x["seed"],x["layout"],x["risk"],x["policy"]):x for x in rows}
def stats(rows):
    return {"n":len(rows),"wins":sum(x["phase"]=="won" for x in rows),
            "opening_clear":sum(len(x["history"])>=2 and all(w["phase"]=="build" for w in x["history"][:2]) for x in rows),
            "mean_hp":round(sum(x["hp"] for x in rows)/len(rows),3),
            "risk_bonus":sum(w["payout"]==18 for x in rows for w in x["history"]),
            "guard_active":sum(any(w["guard_events"] for w in x["history"]) for x in rows),
            "guard_intercepts":sum(w["guard_events"] for x in rows for w in x["history"]),
            "guard_hp_transferred":round(sum(w["guard_damage"] for x in rows for w in x["history"]),3),
            "wins_no_hammer_guard_waves":sum(x["phase"]=="won" and all(not w["has_hammer"] for w in x["history"] if w["wave"]>=3) for x in rows)}
def pair(a,b,same_order):
    out={"n":len(a),"win_gains":[],"win_losses":[],"same_prepared_waves":0,
         "improved":[],"worse":[],"no_event_same_prepared":0,"no_event_full_trace":0,
         "no_event_mismatch":[],"same_prepared_intercept_waves":0}
    for x,y in zip(a,b):
        seed=x["seed"]
        assert seed==y["seed"]
        if x["phase"]!="won" and y["phase"]=="won":out["win_gains"].append(seed)
        if x["phase"]=="won" and y["phase"]!="won":out["win_losses"].append(seed)
        for w1,w2 in zip(x["history"],y["history"]):
            # Guard-only compare exact prepared state (including order and absolute tick);
            # order contrast holds actual paid inputs but necessarily changes orders.
            same=w1["prep_hash"]==w2["prep_hash"] if same_order else all(w1[k]==w2[k] for k in ("wave","assets","cores","gold","hp_before","rng"))
            if not same:continue
            out["same_prepared_waves"]+=1
            if w2["guard_events"]:out["same_prepared_intercept_waves"]+=1
            if same_order and not w2["guard_events"]:
                out["no_event_same_prepared"]+=1
                if w1["trace_hash"] and w2["trace_hash"]:out["no_event_full_trace"]+=1
                if not all(w1[k]==w2[k] for k in ("end_hash","trace_hash","phase","payout","ticks","damage","kills","tide")):
                    out["no_event_mismatch"].append([seed,w2["wave"],w1["end_hash"],w2["end_hash"]])
            row=[seed,w2["wave"],w1["leaks"],w2["leaks"],w1["phase"],w2["phase"],w1["payout"],w2["payout"],w1["guard_events"],w2["guard_events"]]
            gain=w1["phase"]=="lost" and w2["phase"]!="lost"
            loss=w1["phase"]!="lost" and w2["phase"]=="lost"
            if gain or (not loss and w2["leaks"]<w1["leaks"]):out["improved"].append(row)
            if loss or (not gain and w2["leaks"]>w1["leaks"]):out["worse"].append(row)
    return out
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--baseline",type=Path,default=ROOT.parent/"RiftworksP08/src/Run.gd")
    p.add_argument("--candidate",type=Path,default=ROOT/"src/Run.gd")
    p.add_argument("--count",type=int,default=30);p.add_argument("--trace-count",type=int,default=10)
    p.add_argument("--godot",default="godot");p.add_argument("--json",type=Path)
    args=p.parse_args()
    base=args.baseline.read_bytes();on=args.candidate.read_bytes()
    assert sha(base)==P08_SHA,"requires frozen P08 source"
    assert on.count(b"const GUARD_ESCORT_ENABLED=true")==1,"requires final combined implementation"
    off=on.replace(b"const GUARD_ESCORT_ENABLED=true",b"const GUARD_ESCORT_ENABLED=false",1)
    print("hashes",sha(base),sha(on),sha(off),flush=True)
    with tempfile.TemporaryDirectory(prefix="riftworks-p09-factorial-") as tmp:
        br=run(base,"base",Path(tmp)/"base",args)
        print("P08 baseline",len(br),flush=True)
        orr=run(off,"off",Path(tmp)/"off",args)
        print("guard off",len(orr),flush=True)
        cr=run(on,"on",Path(tmp)/"on",args)
        print("guard on",len(cr),flush=True)
    assert sha(args.candidate.read_bytes())==sha(on),"candidate changed during simulation"
    bi,oi,ci=index(br),index(orr),index(cr)
    report={"base_sha":sha(base),"combined_sha":sha(on),"guard_off_sha":sha(off),
            "seed_range":[437,436+args.count],"trace_seed_count":args.trace_count,
            "actual_runs":len(br)+len(orr)+len(cr),"baseline_mismatch":[],"groups":{}}
    for k,x in bi.items():
        if x!=oi[k]:report["baseline_mismatch"].append(k)
    for layout in ("generic","special"):
        for risk in (False,True):
            def select(ind,policy):return [ind[(seed,layout,risk,policy)] for seed in range(437,437+args.count)]
            a=select(oi,"front");b=select(oi,"situational");c=select(ci,"front");d=select(ci,"situational")
            g={"front_none":stats(a),"orders_only":stats(b),"guard_only":stats(c),"combined":stats(d),
               "guard_front":pair(a,c,True),"guard_with_orders":pair(b,d,True),
               "orders_without_guard":pair(a,b,False),"orders_with_guard":pair(c,d,False)}
            g["orders_win_delta_guard_off"]=g["orders_only"]["wins"]-g["front_none"]["wins"]
            g["orders_win_delta_guard_on"]=g["combined"]["wins"]-g["guard_only"]["wins"]
            report["groups"][f"{layout}:risk={risk}"]=g
    report["layout_w3_same_roster"]={}
    for version,ind in (("off",oi),("on",ci)):
        for risk in (False,True):
            for policy in ("front","situational"):
                group={"n":0,"special_better":[],"special_worse":[],"same":0}
                for seed in range(437,437+args.count):
                    old=ind[seed,"generic",risk,policy];new=ind[seed,"special",risk,policy]
                    if len(old["history"])<3 or len(new["history"])<3:continue
                    a,b=old["history"][2],new["history"][2]
                    if a["wave"]!=3 or b["wave"]!=3:continue
                    roster=lambda w:sorted(tuple(t[:3]) for t in w["assets"])
                    if roster(a)!=roster(b) or not all(a[k]==b[k] for k in ("cores","gold","hp_before","rng")):continue
                    group["n"]+=1
                    row=[seed,a["leaks"],b["leaks"],a["guard_events"],b["guard_events"],a["payout"],b["payout"]]
                    if b["leaks"]<a["leaks"]:group["special_better"].append(row)
                    elif b["leaks"]>a["leaks"]:group["special_worse"].append(row)
                    else:group["same"]+=1
                report["layout_w3_same_roster"][f"{version}:{risk}:{policy}"]=group
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if args.json:args.json.write_text(json.dumps({"report":report,"baseline":br,"guard_off":orr,"guard_on":cr},ensure_ascii=False,indent=2))
    assert not report["baseline_mismatch"],"default guard-off differs P08"
    assert not any(g[k]["no_event_mismatch"] for g in report["groups"].values() for k in ("guard_front","guard_with_orders")),"no-intercept guard regression"
if __name__=="__main__":main()
