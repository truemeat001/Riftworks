extends SceneTree
const R=preload("res://src/Run.gd")
var checks=0
var failures:Array[String]=[]
var emissions=0
func ck(v:bool,s:String):
 checks+=1
 if not v:failures.append(s);print("FAIL ",s)
func all(r): return r.towers+r.reserve
func find(r,id):
 for t in all(r):
  if t.id==id:return t
 return {}
func state(r):
 return var_to_str([r.gold,r.phase,r.stage,r.wave,r.hp,r.route_choice,r.opened,r.towers,r.reserve,r.upgrades,r.next_tower_id,r.rng.state,r.pending,r.spawn_count,r.last_loot])
func unchanged(r,b,snapshot,why):
 ck(not b and state(r)==snapshot,why)
func credits(r):
 var v=r.gold
 for t in all(r):v+=4*(1<<(t.rank-1))
 for n in r.upgrades.values():v+=4*n
 return v
func draw(r):
 var c=credits(r);var g=r.gold;var count=all(r).size()
 var before_ranks=0
 for n in r.upgrades.values():before_ranks+=n
 var odds=r.reward_odds()
 var result=r.draw_loot()
 if result.is_empty():
  ck(false,"draw unexpectedly rejected")
  return result
 ck(r.gold==g-6 and credits(r)==c-2,"single draw economic delta")
 ck(r.last_loot==result,"last loot equals committed result")
 if result.kind=="tower":
  ck(odds.tower>0.0 and all(r).size()==count+1 and find(r,result.id).kind==result.tower_kind and find(r,result.id).rank==result.rank,"tower exactly one eligible committed")
 else:
  var after_ranks=0
  for n in r.upgrades.values():after_ranks+=n
  ck(odds.core>0.0 and odds.core_ids.has(result.id) and all(r).size()==count and after_ranks==before_ranks+1 and r.level(result.id)==result.rank,"core exactly one eligible rank committed")
 return result
func free_cell(r,kind=0):
 for y in range(R.ROWS):
  for x in range(R.COLS):
   var p=Vector2i(x,y)
   if r.placement_error(p,kind).is_empty():return p
 return Vector2i(-1,-1)
func merge_pair(r,max_rank=3):
 var items=all(r)
 for i in range(items.size()):
  for j in range(i+1,items.size()):
   var a=items[i];var b=items[j]
   if a.kind==b.kind and a.rank==b.rank and a.rank<max_rank:
    var g=r.gold;var c=credits(r);var rank=a.rank;var id=a.id
    var kind=a.kind;var prior=r.preview_stats(Vector2i(0,0),kind,rank)[0]
    ck(r.merge_towers(id,b.id),"merge equal kind/rank")
    ck(find(r,id).rank==rank+1 and r.gold==g and credits(r)==c,"merge exact conservation and survivor ID")
    var current=r.preview_stats(Vector2i(0,0),kind,rank+1)[0]
    ck(current>prior,"rank damage improves")
    return true
 return false
func sim(r):
 var n=0
 while r.phase=="fight" and n<4000:
  r.step();n+=1
 return n
func set_eligible(r,owned,cores_saturated):
 r.reset(437);r.gold=1000
 if cores_saturated: r.upgrades=R.MAX_RANK.duplicate()
 for i in range(owned):
  r.reserve.append({"id":i+1,"kind":i%3,"rank":1,"cell":Vector2i(-1,-1),"cool":0.0})
 r.next_tower_id=owned+1
func synergy_trial(kind:int,slow:float,offset:float)->Dictionary:
 var q=R.new();q.reset(437);q.phase="fight";q.pending=1;q.spawn_time=99
 var route=[Vector2(2,2),Vector2(11,2)]
 q.towers=[{"id":1,"kind":kind,"rank":1,"cell":Vector2i(2,1),"cool":0.0}]
 var i=0
 for v in [Vector2(2,2),Vector2(2-offset,2)]:
  q.enemies.append({"id":i,"hit_tick":-1,"route":route,"pos":v,"direction":Vector2.RIGHT,"segment":0,"hp":100.0,"maxhp":100.0,"slow":slow if i==0 else 0.0,"role":"normal","boss":false,"speed":0.0,"second":false});i+=1
 q.step()
 return {"primary":100-q.enemies[0].hp,"secondary":100-q.enemies[1].hp,"shots":q.shots.duplicate(true)}
# Independent numerical quadrature, not the production closed-form circle intersection.
func sample_coverage(r,route:Array)->float:
 var total=0.0
 for i in range(route.size()-1):
  var a:Vector2=route[i];var b:Vector2=route[i+1];var d=a.distance_to(b);var n=maxi(1,ceili(d/0.015))
  for j in range(n):
   var point=a.lerp(b,(j+0.5)/n)
   var reached=false
   for t in r.towers:
    if Vector2(t.cell).distance_to(point)<=float(r.stats(t)[1]):reached=true;break
   if reached:total+=d/n
 return total
func coverage_fixture(r,stage:int,risk:bool):
 r.reset(437);r.stage=stage;r.opened=risk;r.gold=200;r.upgrades={"range":1,"relay":1}
 for i in range(6):r.draw_loot()
 # Guard ensures at least two, choose actual deployed and inventory units.
 var emissions_before=emissions
 for _i in range(2):
  var t=r.reserve[0];var c=free_cell(r,t.kind)
  var snapshot=state(r)
  var p=r.coverage_preview(c,t.kind,t.rank,t.id)
  ck(p.valid and state(r)==snapshot,"read-only deployment preview exact state")
  ck(r.deploy(t.id,c),"actual corresponding preview deployment")
  var now=r.coverage_current()
  ck(now.size()==p.lanes.size(),"preview lane count actual")
  for i in range(now.size()):
   ck(now[i].id==p.lanes[i].id and is_equal_approx(now[i].covered,p.lanes[i].team_after),"preview predicted actual covered length")
   var route=r.path(now[i].id=="main")
   ck(absf(sample_coverage(r,route)-now[i].covered)<0.15,"independent sampled union coverage close to exact geometry")
   ck(now[i].fraction>=0.0 and now[i].fraction<=1.0,"coverage bounded")
 var s=state(r);var t=r.towers[0]
 var bad=r.coverage_preview(Vector2i(-1,0),t.kind,t.rank,t.id)
 ck(not bad.valid and state(r)==s,"invalid preview preserves entire state")
 bad=r.coverage_preview(free_cell(r,t.kind),t.kind,9,t.id)
 ck(not bad.valid and state(r)==s,"invalid rank preview rejected")
 # Compare a real merge prediction and actual subsequent model value when available.
 var pair=[]
 var items=all(r)
 for i in range(items.size()):
  for j in range(i+1,items.size()):
   if items[i].kind==items[j].kind and items[i].rank==items[j].rank and pair.is_empty():
    pair=[items[i],items[j]]
 if not pair.is_empty():
  var pre=state(r);var pred=r.coverage_merge_preview(pair[0].id,pair[1].id)
  ck(pred.valid and state(r)==pre,"merge prediction read-only")
  ck(r.merge_towers(pair[0].id,pair[1].id),"actual matched merge")
  var actual=r.coverage_current()
  for i in range(actual.size()):ck(is_equal_approx(pred.lanes[i].team_after,actual[i].covered),"merge predicts actual coverage")
 else:ck(false,"actual seed repeated type for merge fixture")
 ck(emissions>emissions_before,"actual model actions signal changes")
func _initialize():
 var r=R.new();r.reset(437)
 ck(not r.has_method("draw_tower") and not r.has_method("draw_core"),"no separate direct type-specific draw API")
 ck(r.gold==24 and all(r).is_empty() and r.upgrades.is_empty() and r.last_loot.is_empty(),"start24 empty roster, loot and upgrades")
 var s=state(r);unchanged(r,r.start(),s,"reject no deployed tower")
 ck(r.reward_odds().tower==1.0 and r.reward_odds().core==0.0,"zero-owned category guard")
 r.changed.connect(func():emissions+=1)
 var before=emissions;draw(r)
 ck(emissions==before+1,"one successful payout one changed signal")
 ck(r.reward_odds().tower==1.0 and r.reward_odds().core==0.0,"one-owned category guard")
 draw(r)
 ck(is_equal_approx(r.reward_odds().tower,0.7) and is_equal_approx(r.reward_odds().core,0.3),"two-owned both categories eligible")
 var id=r.reserve[0].id;var g=r.gold
 s=state(r);unchanged(r,r.deploy(id,Vector2i(0,3)),s,"reject path no change")
 s=state(r);unchanged(r,r.deploy(id,Vector2i(-1,0)),s,"reject bounds")
 ck(r.deploy(id,Vector2i(1,2)) and r.gold==g,"deploy free")
 ck(r.deploy(id,Vector2i(0,2)) and r.gold==g,"move free")
 ck(r.recall(id) and r.gold==g,"recall free")
 ck(r.sell_tower(id) and r.gold==g+4,"sell rank1 +4")
 r.reset(437);r.gold=500
 for i in range(100):
  if all(r).size()>=9:break
  draw(r)
 ck(all(r).size()==9 and r.reward_odds().tower==0.0 and r.reward_odds().core==1.0,"owned cap9 falls back core")
 draw(r);ck(all(r).size()==9,"full roster draws core not extra tower")
 for i in range(5):ck(r.deploy(r.reserve[0].id,free_cell(r)),"deploy slot %d"%i)
 s=state(r);unchanged(r,r.deploy(r.reserve[0].id,Vector2i(11,0)),s,"deployed cap5")
 var chosen=r.towers[0]
 s=state(r);unchanged(r,r.merge_towers(chosen.id,chosen.id),s,"reject self-merge")
 while merge_pair(r):pass
 # fixture to verify both categories maxed, no mutation and no RNG consumed
 set_eligible(r,9,true)
 s=state(r);ck(r.reward_odds().tower==0.0 and r.reward_odds().core==0.0,"both pools saturated")
 ck(r.draw_loot().is_empty() and state(r)==s,"reject both full without RNG/gold")
 set_eligible(r,3,true)
 ck(r.reward_odds().tower==1.0 and r.reward_odds().core==0.0,"max core ranks falls back tower")
 draw(r)
 r.reset(99);r.gold=1000
 # Actual draws saturate both eligible pools.
 var ranks=0
 for n in R.MAX_RANK.values():ranks+=n
 for i in range(ranks+9):draw(r)
 ck(r.upgrades==R.MAX_RANK and all(r).size()==9,"full bounded pools acquired with actual draws")
 s=state(r);ck(r.draw_loot().is_empty() and state(r)==s,"actual saturated pools reject")
 r.reset(0);r.draw_loot();r.gold=0
 s=state(r);unchanged(r,r.sell_tower(r.reserve[0].id),s,"last crew cannot strand balance")
 s=state(r);ck(r.draw_loot().is_empty() and state(r)==s,"no funds no mutation")
 ck(r.reward_odds().tower==0.0 and r.reward_odds().core==0.0,"poor balance no eligible odds")
 var first_type=[0,0,0];var mixed_type=[0,0,0];var core_freq={};var core_results=0;var tower_results=0;var two_crew=0;var min_roster=99
 for core in R.UPGRADES:core_freq[core.id]=0
 for seed_value in range(3000):
  r.reset(seed_value)
  var f=r.draw_loot();first_type[f.tower_kind]+=1
  var f2=r.draw_loot()
  if f2.kind=="tower":two_crew+=1
  var f3=r.draw_loot()
  if f3.kind=="tower":mixed_type[f3.tower_kind]+=1;tower_results+=1
  else:core_freq[f3.id]+=1;core_results+=1
  r.draw_loot()
  min_roster=mini(min_roster,all(r).size())
 ck(two_crew==3000 and min_roster>=2,"all 3000 seeds first2 are tower; min2 after 4")
 ck(abs(tower_results-2100)<150 and abs(core_results-900)<150,"conditional 70/30 statistical tolerance")
 for n in first_type:ck(abs(n-1000)<110,"first tower uniform")
 for n in mixed_type:ck(abs(n-tower_results/3.0)<100,"conditional tower uniform")
 for n in core_freq.values():ck(abs(n-core_results/8.0)<75,"conditional core uniform")
 print("DISTRIBUTION first ",first_type," mixed towers ",tower_results," ",mixed_type," cores ",core_results," ",core_freq," minRoster ",min_roster)
 var a=R.new();var b=R.new();a.reset(117);b.reset(117)
 for i in range(4):
  a.draw_loot();b.draw_loot()
 ck(state(a)==state(b),"same seed identical draw actions")
 r.reset(437)
 for i in range(4):draw(r)
 var slots=[Vector2i(3,2),Vector2i(5,2),Vector2i(6,2),Vector2i(7,2)]
 for t in r.reserve.duplicate():r.deploy(t.id,slots.pop_front())
 ck(r.start(),"first wave starts")
 r.gold=100;var rng_before=r.rng.state
 s=state(r);ck(r.draw_loot().is_empty() and state(r)==s,"battle draw rejected atomically")
 ck(r.reward_odds().tower==0.0 and r.reward_odds().core==0.0,"battle odds zero")
 var initial=r.gold;sim(r)
 ck(r.phase=="build" and r.wave==1 and r.gold==initial+12,"wave clear direct build +12")
 ck(r.rng.state==rng_before,"battle spends no loot RNG")
 # For stage transition correctness use appropriately strengthened build, not a fixed poor layout.
 for i in range(5):draw(r)
 for t in r.reserve.duplicate():
  if r.towers.size()>=5:break
  r.deploy(t.id,free_cell(r))
 var roster_before=all(r).duplicate(true);var ups=r.upgrades.duplicate()
 initial=r.gold;r.start();sim(r)
 ck(r.phase=="build" and r.stage==1 and r.wave==0 and r.gold==initial+12,"stage clear +12 no refund")
 ck(r.towers.is_empty() and r.reserve.size()==roster_before.size() and r.upgrades==ups,"transition recall and persistence")
 for item in roster_before:ck(find(r,item.id).kind==item.kind and find(r,item.id).rank==item.rank,"transition preserves identity")
 # Role count, HP/speed and no RNG from actual spawn sequence through every wave.
 for stage in range(3):
  for wave in range(2):
   for risk in [false,true]:
    if risk and stage!=1: continue
    r.reset(437);r.stage=stage;r.wave=wave;r.opened=risk;r.draw_loot();r.deploy(r.reserve[0].id,free_cell(r))
    var f=r.forecast()
    var counts_roles={"normal":0,"runner":0,"guard":0,"boss":0};var extra_count=0;var main_speeds=[]
    rng_before=r.rng.state
    ck(r.start(),"forecast trial start")
    while r.pending_main+r.pending_extra>0:
     r.spawn();var enemy=r.enemies[-1]
     if enemy.second:
      extra_count+=1
      ck(enemy.role=="normal" and is_equal_approx(enemy.maxhp,f.extra_hp),"rift enemy role + exact HP")
     else:
      counts_roles[enemy.role]+=1
      ck(is_equal_approx(enemy.maxhp,f.role_hp[enemy.role]),"main forecast role HP")
      var i=main_speeds.size()
      var expected_speed=1.1 if enemy.role=="boss" else (0.95+stage*0.12+float(i%3)*0.12)*{"normal":1.0,"runner":1.5,"guard":0.75}[enemy.role]
      ck(is_equal_approx(enemy.speed,expected_speed),"main speed unaffected by optional rift")
      main_speeds.append(enemy.speed)
    ck(f.roles==counts_roles and extra_count==f.extra,"forecast actual per role + rift")
    ck(r.rng.state==rng_before,"spawning no loot RNG")
    if stage==2 and wave==1:ck(counts_roles.boss==1,"final boss unique")
 r.reset(437);r.stage=1
 var shared=[]
 for x in range(R.COLS):
  for y in range(R.ROWS):
   var c=Vector2i(x,y)
   if r.is_path(c,r.path(true)) and r.is_path(c,r.path(false)):shared.append(c)
 ck(shared==[Vector2i(11,4)],"dual lanes share exactly one logical endpoint")
 ck(r.path_length(r.path(true))==14 and r.path_length(r.path(false))==13,"dual route known lengths")
 var main_before=r.path(true);var f_before=r.forecast();r.alter()
 ck(r.path(true)==main_before and r.forecast().main==f_before.main and r.forecast().roles==f_before.roles,"rift opening preserves main route, count and roles")
 var plain=synergy_trial(0,0.0,1.2);var effect=synergy_trial(0,1.0,1.2)
 ck(is_equal_approx(effect.primary/plain.primary,1.2),"actual pulse conductive damage +20% prior slow")
 ck(effect.shots.any(func(s):return s.get("synergy","")=="conductive"),"conductive shot event")
 plain=synergy_trial(2,0.0,1.2);effect=synergy_trial(2,1.0,1.2)
 ck(plain.secondary==0 and effect.secondary>0,"actual hammer shatter expands splash")
 ck(effect.shots.any(func(s):return s.get("synergy","")=="shatter"),"shatter shot event")
 var b1=synergy_trial(2,0.0,0.75);var b2=synergy_trial(2,1.0,0.75)
 ck(is_equal_approx(b2.secondary/b1.secondary,1.1),"actual shatter splash damage +10%")
 # Existing slow expires before attack, so no bonus on expired status.
 var expiry=synergy_trial(0,0.01,1.2)
 ck(is_equal_approx(expiry.primary,synergy_trial(0,0.0,1.2).primary),"no stale slow damage bonus")
 print("SYNERGY ",[synergy_trial(0,0,1.2),synergy_trial(0,1,1.2),b1,b2])
 for st in range(3):
  coverage_fixture(r,st,false)
  if st==1:coverage_fixture(r,st,true)
 print("RULES checks=",checks," fails=",failures.size()," ",failures)
 quit(1 if not failures.is_empty() else 0)
