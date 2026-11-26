extends SceneTree
const R=preload("res://src/Run.gd")
func all(r):return r.towers+r.reserve
func best(r,t,adapter=false):
 var score=-1.0;var cell=Vector2i(-1,-1)
 var routes=[r.path()]
 if r.stage==1 and r.opened:routes.append(r.path(false))
 for x in range(R.COLS):
  for y in range(R.ROWS):
   var c=Vector2i(x,y)
   if not r.placement_error(c,t.kind,t.id).is_empty():continue
   var stats=r.preview_stats(c,t.kind,t.rank)
   var cover=0.0
   for route in routes:
    for j in range(route.size()-1):
     var p:Vector2=route[j]
     while p.distance_to(route[j+1])>0.1:
      if p.distance_to(Vector2(c))<=stats[1]:
       cover+=1.0
       if adapter and t.kind!=1:
        for ally in r.towers:
         if ally.kind==1 and Vector2(ally.cell).distance_to(p)<=r.stats(ally)[1]:
          cover+=0.15
          break
      p=p.move_toward(route[j+1],0.5)
   var value=cover*stats[0]/stats[2]
   if t.kind==1:value*=1.1
   if value>score:score=value;cell=c
 return cell
func deploy_all(r,style,rand):
 for t in r.towers.duplicate():r.recall(t.id)
 var available=r.reserve.duplicate()
 available.sort_custom(func(a,b):
  if style==3 and (a.kind==1)!=(b.kind==1):return a.kind==1
  return a.rank>b.rank or (a.rank==b.rank and a.kind<b.kind))
 for t in available:
  if r.towers.size()>=5:break
  var c=Vector2i(-1,-1)
  if style==4:
   var slots=[]
   for x in range(R.COLS):
    for y in range(R.ROWS):
     var p=Vector2i(x,y)
     if r.placement_error(p,t.kind,t.id).is_empty():slots.append(p)
   if not slots.is_empty():c=slots[rand.randi_range(0,slots.size()-1)]
  else:c=best(r,t,style==3)
  r.deploy(t.id,c)
func merge(r,aggressive=false,preserve=false):
 var items=all(r)
 for i in range(items.size()):
  for j in range(i+1,items.size()):
   var a=items[i];var b=items[j]
   if a.kind==b.kind and a.rank==b.rank and a.rank<3 and (aggressive or items.size()>5):
    if preserve and a.kind==1 and items.filter(func(t):return t.kind==1).size()<=2 and r.stage==1 and r.opened:continue
    return r.merge_towers(a.id,b.id)
 return false
func buy(r,style):
 var draws=0;var sold=0
 while r.gold>=6:
  var loot=r.draw_loot()
  if loot.is_empty():break
  draws+=1
  if style==2:
   while merge(r,true):pass
  elif style==1:
   while merge(r,false):pass
  elif style==3:
   while merge(r,false,true):pass
   # Sell overrepresented low-rank type only once each wave, preserve adaptive synergy.
   if sold==0 and all(r).size()>=5 and r.gold>=2 and loot.kind=="tower":
    var typecount=all(r).filter(func(t):return t.kind==loot.tower_kind).size()
    if typecount>=4 and r.sell_tower(loot.id):sold+=1
  elif style==0:
   # Fill board, only merge when inventory is essentially saturated.
   if all(r).size()>=9:
    while merge(r,false):pass
  if draws>40:break
 return [draws,sold]
func simulate(seed,risk,style,one_wave=false):
 var r=R.new();r.reset(seed);var hist=[];var phase_count=0;var rand=RandomNumberGenerator.new();rand.seed=seed
 var synergies=0;var draw_count=0;var sale_count=0;var transfers=0;var transfer_seconds=0.0
 var has_tide=r.get_property_list().any(func(p):return p.name=="tide_transfers")
 while r.phase=="build" and phase_count<7:
  phase_count+=1
  if r.stage==1 and risk!=r.opened:r.alter()
  var act=buy(r,style);draw_count+=act[0];sale_count+=act[1]
  deploy_all(r,style,rand)
  if not r.start():break
  var start=r.gold;var n=0;var wave=r.wave;var stage=r.stage;var opened=r.opened;var pre_wave_rng=r.rng.state
  while r.phase=="fight" and n<4000:
   r.step();n+=1
   if has_tide:
    for transfer in r.get("tide_transfers"):
     if transfer.tick==r.tick_count:transfers+=1;transfer_seconds+=transfer.duration
   for s in r.shots:
    if not s.get("synergy","").is_empty() and s.life>0.105:synergies+=1
  hist.append([stage,wave,r.hp,r.gold,r.wave_leaks,n,r.phase,r.upgrades.duplicate(),all(r).map(func(t):return [t.kind,t.rank]),r.gold-start,pre_wave_rng==r.rng.state])
  if one_wave:break
 return {"phase":r.phase,"hp":r.hp,"history":hist,"draws":draw_count,"sales":sale_count,"synergies":synergies,"transfers":transfers,"transfer_seconds":transfer_seconds,"upgrades":r.upgrades,"towers":all(r).map(func(t):return [t.kind,t.rank])}
func _initialize():
 var outcomes=[]
 for risk in [false,true]:
  for style in [0,1,2,3,4]:
   var wins=0;var hps=[];var syn=0
   for seed in range(437,467):
    var v=simulate(seed,risk,style)
    outcomes.append({"seed":seed,"risk":risk,"style":style,"result":v})
    if v.phase=="won":wins+=1
    hps.append(v.hp);syn+=v.synergies
   print("GROUP risk=",risk," style=",style," wins=",wins,"/30 HP=",hps," synergy=",syn)
 var args=OS.get_cmdline_user_args()
 var out=args[0] if not args.is_empty() else "user://p08-model-results.json"
 var f=FileAccess.open(out,FileAccess.WRITE)
 if f==null:push_error("Could not write model result: "+out);quit(1);return
 f.store_string(JSON.stringify(outcomes));f.close()
 print("WROTE ",out," runs=",outcomes.size())
 quit()
