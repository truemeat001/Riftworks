#!/usr/bin/env python3
"""P07 isolated actual-Godot strategy probes, NOT human usability evidence.

Usage: python scripts/model_balance_p07.py --source ../RiftworksP06/src/Run.gd
The optional rank candidate exists ONLY in a temporary Run.gd copy.
No product assets or production source are modified. --json can save results.
"""
from pathlib import Path
from fractions import Fraction as F
import argparse, hashlib, json, os, subprocess, tempfile

BASE_HASH="7f623075e85a6f4f8ce898c9622c75f0d605694be1a5c114b06570088bd2e0e0"
ROOT=Path(__file__).resolve().parents[1]
GDS=r'''
extends SceneTree
const R=preload("res://src/Run.gd")
func all_crew(r):return r.towers+r.reserve
func merge(r,aggressive=false):
 var items=all_crew(r)
 for i in range(items.size()):
  for j in range(i+1,items.size()):
   var a=items[i];var b=items[j]
   if a.kind==b.kind and a.rank==b.rank and a.rank<3 and (aggressive or items.size()>5):
    return r.merge_towers(a.id,b.id)
 return false
func draw_and_train(r,aggressive=false):
 while r.gold>=6:
  if r.draw_loot().is_empty():break
  while merge(r,aggressive):pass
func points(route):
 var out=[]
 for i in range(route.size()-1):
  var p:Vector2=route[i]
  while p.distance_to(route[i+1])>0.01:
   out.append(p);p=p.move_toward(route[i+1],0.5)
 return out
func cover(r,c,t,route):
 var st=r.preview_stats(c,t.kind,t.rank,t.id)
 var hit=0
 for p in points(route):
  if Vector2(c).distance_to(p)<=st[1]:hit+=1
 return float(hit)*0.5
func deploy_policy(r,policy,seed):
 for t in r.towers.duplicate():r.recall(t.id)
 var items=r.reserve.duplicate()
 items.sort_custom(func(a,b):return a.rank>b.rank or (a.rank==b.rank and a.id<b.id))
 var rr=RandomNumberGenerator.new();rr.seed=seed*917+r.stage*23+r.wave*13+41
 var routes=[r.path()]
 if r.stage==1 and r.opened:routes.append(r.path(false))
 for t in items:
  if r.towers.size()>=R.MAX_TOWERS:break
  var choices=[];var best_score=-1.0;var best=Vector2i(-1,-1)
  var lane=0 if r.towers.size()%2==0 else 1
  for x in range(R.COLS):
   for y in range(R.ROWS):
    var c=Vector2i(x,y)
    if not r.placement_error(c,t.kind,t.id).is_empty():continue
    var a=cover(r,c,t,routes[0])
    var b=cover(r,c,t,routes[1]) if routes.size()==2 else 0.0
    if policy=="near":
     var near=false
     for path in routes:
      for p in points(path):
       if Vector2(c).distance_to(p)<=1.5:near=true;break
      if near:break
     if near:choices.append(c)
    elif policy=="split" and routes.size()==2:
     # Deliberately assign 3/2 active ranks to separate lanes. Avoid formal DPS claims.
     var score=(a if lane==0 else b)+0.1*(b if lane==0 else a)
     if score>best_score:best_score=score;best=c
    else:
     # Sum route coverage, analogous to a player selecting a slot with greatest visible coverage.
     var score=a+b
     if score>best_score:best_score=score;best=c
  if policy=="near" and not choices.is_empty():best=choices[rr.randi_range(0,choices.size()-1)]
  if best.x>=0:r.deploy(t.id,best)
func fight(r):
 if not r.start():return {}
 var ticks=0;var main_leaks=0;var extra_leaks=0;var boss_remain=0.0
 while r.phase=="fight" and ticks<4000:
  var before=r.enemies.duplicate()
  for e in before:
   if e.boss:boss_remain=e.hp
  r.step();ticks+=1
  for e in before:
   if e.get("escaped",false):
    if e.second:extra_leaks+=1
    else:main_leaks+=1
 return {"ticks":ticks,"main":main_leaks,"extra":extra_leaks,"hp":r.hp,"leaks":r.wave_leaks,"phase":r.phase,"boss_previous_tick_hp":0.0 if r.boss_defeated else boss_remain}
func simulate(seed,policy,risk,aggressive):
 var r=R.new();r.reset(seed);var hist=[];var first_r3=-1;var paid=0
 while r.phase=="build" and hist.size()<6:
  var stage=r.stage;var wave=r.wave
  if stage==1 and r.opened!=risk:r.alter()
  draw_and_train(r,aggressive)
  if first_r3<0 and all_crew(r).any(func(t):return t.rank==3):first_r3=stage*2+wave+1
  deploy_policy(r,policy,seed)
  var gold=r.gold;var v=fight(r)
  if v.is_empty():break
  v["wave"]=stage*2+wave+1;v["payout"]=r.gold-gold
  if v["payout"]==18:paid+=1
  hist.append(v)
 return {"seed":seed,"policy":policy,"risk":risk,"aggressive":aggressive,"phase":r.phase,"hp":r.hp,"first_r3":first_r3,"paid":paid,"history":hist}
func lane_probe(seed,risk,policy):
 # Four legal branches begin with exactly same paid draws: replay first stage closed,
 # buy second-stage wave1 assets before altering lane, no additional draws per branch.
 var r=R.new();r.reset(seed)
 for i in range(2):
  draw_and_train(r,false);deploy_policy(r,"union",seed);fight(r)
  if r.phase!="build":return {"seed":seed,"reachable":false}
 if r.stage!=1:return {"seed":seed,"reachable":false}
 draw_and_train(r,false)
 var assets=all_crew(r).map(func(t):return [t.id,t.kind,t.rank])
 var opening_hp=r.hp;var gold=r.gold;var cores=r.upgrades.duplicate()
 if risk:r.alter()
 deploy_policy(r,policy,seed)
 var cells=r.towers.map(func(t):return [t.id,t.cell.x,t.cell.y])
 var v=fight(r)
 return {"seed":seed,"reachable":true,"risk":risk,"policy":policy,"assets":assets,"cores":cores,"gold":gold,"hp_before":opening_hp,"cells":cells,"result":v,"payout":r.gold-gold}
func _initialize():
 var args=OS.get_cmdline_user_args()
 var mode=args[0] if not args.is_empty() else "all"
 var seeds=[]
 for i in range(30):seeds.append(437+i)
 if mode=="base":
  for seed in seeds:
   for risk in [false,true]:
    for policy in ["union","near"]:
     print("REC ",JSON.stringify(simulate(seed,policy,risk,false)))
    print("REC ",JSON.stringify(simulate(seed,"union",risk,true)))
   for risk in [false,true]:
    for policy in ["union","split"]:
     print("LANE ",JSON.stringify(lane_probe(seed,risk,policy)))
 if mode=="rank":
  for seed in seeds:
   for risk in [false,true]:
    for agg in [false,true]:
     print("REC ",JSON.stringify(simulate(seed,"union",risk,agg)))
 quit()
'''

def stat(raw):
    rows=[]
    for x in raw:
        hist=x["history"]
        ticks=sum(v["ticks"] for v in hist)
        leaks=sum(v["leaks"] for v in hist)
        row=dict(phase=x["phase"],hp=x["hp"],ticks=ticks,leaks=leaks,
                 opening_clear=len(hist)>=2 and all(v["phase"]=="build" for v in hist[:2]),
                 r3=x["first_r3"],failure_wave=hist[-1]["wave"] if x["phase"]!="won" and hist else 0,
                 risk_paid=x["paid"])
        rows.append(row)
    def quant(vs):
        vs=sorted(vs)
        return [vs[round((len(vs)-1)*p)] for p in (.1,.5,.9)] if vs else []
    return dict(n=len(rows),wins=sum(x["phase"]=="won" for x in rows),
                opening_clear=sum(x["opening_clear"] for x in rows),
                hp_p10_50_90=quant([x["hp"] for x in rows]),leaks_p10_50_90=quant([x["leaks"] for x in rows]),
                combat_seconds_p10_50_90=[t*.05 for t in quant([x["ticks"] for x in rows])],
                r3_first_wave_p10_50_90=quant([x["r3"] for x in rows if x["r3"]>=0]),r3_runs=sum(x["r3"]>=0 for x in rows),
                risk_paid=sum(x["risk_paid"] for x in rows),
                loss_wave={str(i):sum(x["failure_wave"]==i for x in rows) for i in range(1,7)})

def run(src, mode, godot, temp_dir):
    d=Path(temp_dir)
    d.mkdir(exist_ok=True)
    (d/"src").mkdir(exist_ok=True)
    (d/"src/Run.gd").write_text(src)
    (d/"project.godot").write_text('[application]\nconfig/name="Riftworks balance isolation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (d/"probe.gd").write_text(GDS)
    env=os.environ.copy()
    for key,name in [("XDG_CACHE_HOME","cache"),("XDG_DATA_HOME","data"),("XDG_CONFIG_HOME","config")]:
        (d/name).mkdir(exist_ok=True)
        env[key]=str(d/name)
    cp=subprocess.run([godot,"--headless","--path",str(d),"--script","res://probe.gd","--",mode],capture_output=True,text=True,check=True,timeout=240,env=env)
    if "SCRIPT ERROR" in cp.stderr:raise RuntimeError(cp.stderr)
    records=[];lanes=[]
    for line in cp.stdout.splitlines():
        if line.startswith("REC "):records.append(json.loads(line[4:]))
        if line.startswith("LANE "):lanes.append(json.loads(line[5:]))
    assert len(records)==(180 if mode=="base" else 120),len(records)
    assert len(lanes)==(120 if mode=="base" else 0)
    return records,lanes

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--source",type=Path,default=ROOT.parent/"RiftworksP06/src/Run.gd")
    p.add_argument("--godot",default="godot")
    p.add_argument("--json",type=Path)
    args=p.parse_args()
    src=args.source.read_bytes()
    assert hashlib.sha256(src).hexdigest()==BASE_HASH,"requires exact frozen P06 baseline"
    s=src.decode()
    # Exact arithmetic and static parameter invariants; no assumption independent draws when pool changes.
    p=F(7,10);q=1-p
    assert F(24)+5*12==84 and F(24)+5*12+2*6==96
    assert 2*q*q+3*2*p*q+4*p*p==F(17,5)
    print("opening 2/3/4 crew",float(q*q),float(2*p*q),float(p*p),"expected 3.4")
    print("rank2 / rank3 efficiency",float(F("2.15")/2),float(F("4.6")/4),"rank3 candidate",float(F("4.4")/4))
    cand=s.replace("const RANK_DAMAGE=[1.0,2.15,4.6]","const RANK_DAMAGE=[1.0,2.15,4.4]")
    assert cand!=s
    with tempfile.TemporaryDirectory(prefix="riftworks-p07-model-") as tmp:
        records,lanes=run(s,"base",args.godot,Path(tmp)/"base")
        candidate,_=run(cand,"rank",args.godot,Path(tmp)/"rank")
    data={"source_sha256":BASE_HASH,"rank_candidate_sha256":hashlib.sha256(cand.encode()).hexdigest(),"seeds":[437,466],"groups":{}}
    for name,rs in [("baseline",records),("rank4.4",candidate)]:
        for policy,risk,agg in sorted({(x["policy"],x["risk"],x["aggressive"]) for x in rs}):
            group=[x for x in rs if x["policy"]==policy and x["risk"]==risk and x["aggressive"]==agg]
            data["groups"][f"{name}:{policy}:risk={risk}:aggressive={agg}"]=stat(group)
    # Paired only: lane_probe same seed/asset/gold & cores before battle, first stage2 wave.
    pairing={}
    for row in lanes:
        if row["reachable"]:pairing.setdefault(row["seed"],{})[(row["risk"],row["policy"])]=row
    comp=[]
    for seed,group in pairing.items():
        assert len(group)==4
        a=group[(False,"union")]
        for b in group.values():
            for k in ("assets","gold","cores","hp_before"):assert a[k]==b[k],(seed,k)
        u=group[(True,"union")];v=group[(True,"split")]
        comp.append({"seed":seed,"concentrated_leaks":u["result"]["leaks"],"split_leaks":v["result"]["leaks"],
                     "union_main":u["result"]["main"],"union_extra":u["result"]["extra"],
                     "split_main":v["result"]["main"],"split_extra":v["result"]["extra"],
                     "closed_leaks":a["result"]["leaks"],"union_paid":u["payout"]==18,"split_paid":v["payout"]==18})
    data["lane_paired"]={"n":len(comp),"split_fewer":sum(x["split_leaks"]<x["concentrated_leaks"] for x in comp),"union_fewer":sum(x["split_leaks"]>x["concentrated_leaks"] for x in comp),"same":sum(x["split_leaks"]==x["concentrated_leaks"] for x in comp),"union_bonus":sum(x["union_paid"] for x in comp),"split_bonus":sum(x["split_paid"] for x in comp),"closed_leaks":sum(x["closed_leaks"] for x in comp),"union_leaks":sum(x["concentrated_leaks"] for x in comp),"split_leaks":sum(x["split_leaks"] for x in comp),"examples":comp}
    print(json.dumps(data,ensure_ascii=False,indent=2))
    if args.json:args.json.write_text(json.dumps({"summary":data,"base_records":records,"lane_records":lanes,"candidate_records":candidate},ensure_ascii=False,indent=2))
if __name__=="__main__":main()
