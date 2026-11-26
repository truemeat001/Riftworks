extends SceneTree
const R=preload("res://src/Run.gd")
var checks=0
var failures=[]
func ck(v:bool,s:String):
 checks+=1
 if not v:failures.append(s);print("FAIL ",s)
func eq(a,b):return absf(float(a)-float(b))<0.00001
func foe(id:int,x:float,role="normal",hp=100.0,slow=0.0,y=3.0,last=11.0):
 return {"id":id,"role":role,"hp":hp,"maxhp":100.0,"slow":slow,"route":[Vector2(0,y),Vector2(last,y)],"pos":Vector2(x,y),"direction":Vector2.RIGHT,"segment":0,"boss":role=="boss","speed":0.0,"second":false,"hit_tick":-1}
func tower(id:int,kind:int,mode="front",cell=Vector2i(5,3)):
 var t={"id":id,"kind":kind,"rank":1,"cell":cell,"cool":0.0,"attack_tick":-1}
 if mode!="front":t.order=mode
 return t
func fight(enemies,towers,upgrades={}):
 var r=R.new();r.reset(437);r.stage=1;r.phase="fight";r.pending=1;r.spawn_time=100
 r.enemies=enemies;r.towers=towers;r.upgrades=upgrades
 return r
func controlled():
 # The nearest enemy is slowed. Screen chooses the unslowed farther runner,
 # then ready guard receives actual Mist slow (even if guard was already slowed).
 var a=foe(10,7,"runner",100,0);var g=foe(20,6,"guard",100,0.3);var front=foe(30,7.5,"normal",100,1.0)
 var r=fight([front,a,g],[tower(1,1,"screen")])
 ck(r.choose_target(r.towers[0],3).id==10,"Screen intended unslowed runner despite nearer slowed")
 var rng=r.rng.state;var gold=r.gold
 r.step()
 ck(r.guard_intercepts.size()==1 and r.guard_intercepts[0].intended_id==10 and r.guard_intercepts[0].guard_id==20,"Screen order precedes guard redirect")
 ck(eq(a.hp,100) and eq(a.slow,0) and eq(front.slow,0.95) and eq(g.hp,93.5) and eq(g.slow,0.8),"real recipient gets actual slow/damage only")
 ck(r.shots.size()==1 and r.shots[0].to==g.pos and eq(r.wave_damage,6.5),"one authoritative attack")
 ck(r.rng.state==rng and r.gold==gold and r.guard_remaining_ticks(g)==24,"no cost/RNG and exact cooldown")
 # Same tick two Screen attacks. Once guard redirects, next unslowed target really hit.
 a=foe(10,7,"runner");g=foe(20,6,"guard",100,0.3);front=foe(30,7.5,"normal",100,1.0)
 r=fight([front,a,g],[tower(1,1,"screen"),tower(2,1,"screen")]);r.step()
 ck(r.guard_intercepts.size()==1 and eq(a.hp,93.5) and eq(g.hp,93.5) and eq(a.slow,0.8) and eq(g.slow,0.8),"same-tick second Screen hits intended after cooldown")
 ck(r.shots.size()==2 and eq(r.wave_damage,13),"two and only two attacks")
 # Brass actual guard HP+slow, not intended; chain is legitimate separate secondary.
 a=foe(10,7,"runner");g=foe(20,6.3,"guard",40,0.5)
 r=fight([a,g],[tower(1,0)],{"focus":1,"chain":1});r.step()
 var direct=8.5*1.05*1.2*1.3;var chain=8.5*1.05*0.65
 ck(eq(g.hp,40-direct) and eq(a.hp,100-chain),"focus and conductive use recipient, chain actual origin")
 ck(r.shots.size()==2 and r.shots[0].synergy=="conductive" and r.shots[1].from==g.pos and r.shots[1].to==a.pos,"actual direct+secondary distinct")
 ck(eq(r.guard_intercepts[0].damage,direct) and eq(r.wave_damage,direct+chain),"event reports effective direct only")
 # Reverse states: intended slowed+low HP, guard fresh/unmarked high HP.
 a=foe(10,7,"runner",20,0.8);g=foe(20,6,"guard")
 r=fight([a,g],[tower(1,0)],{"focus":1});r.step()
 ck(eq(a.hp,20) and eq(g.hp,91.5) and r.shots[0].synergy=="","no hidden intended status bonus")
 # Same geometric cross-lane body: allowed when both in range; no teleport.
 a=foe(10,7,"runner",100,0,3,10);g=foe(20,7,"guard",100,0,4,11)
 g.second=true
 r=fight([a,g],[tower(1,0)]);r.step()
 ck(r.guard_intercepts.size()==1 and eq(g.hp,91.5) and g.pos==Vector2(7,4),"geometric cross-lane escort")
 # Hammer Cluster targets group itself, guard bypass (no cooldown spent).
 a=foe(10,7.8,"runner");g=foe(20,6,"guard");var b=foe(30,5.4);var c=foe(40,6.6)
 r=fight([a,g,b,c],[tower(1,2,"cluster")]);r.step()
 ck(r.guard_intercepts.is_empty() and r.guard_ready(g) and eq(g.hp,88),"Hammer Cluster chooses densest and no escort")
 ck(r.shots.size()==3 and eq(r.wave_damage,12+2*6.6),"actual secondary count equals chosen Cluster")
 # Cooldown and expiry do not create stale readiness or fake alerts.
 a=foe(10,7);g=foe(20,6,"guard")
 r=fight([a,g],[tower(1,0)]);r.step()
 r.towers[0].cool=999
 for i in range(23):r.step()
 ck(r.tick_count==24 and r.guard_remaining_ticks(g)==1 and r.guard_intercepts.is_empty(),"cooldown real ticks and event lifespan")
 r.towers[0].cool=0;r.step()
 ck(r.tick_count==25 and r.guard_intercepts.size()==1 and eq(g.hp,83),"exact ready boundary reintercepts")
func orders():
 var r=R.new();r.reset(437);r.gold=100
 for i in range(7):r.draw_loot()
 for t in r.reserve.duplicate():
  var old=var_to_str([r.gold,r.rng.state,r.reserve,r.message])
  ck(r.order_of(t)=="front" and not t.has("order"),"draw defaults Front no key")
  ck(not r.set_order(t.id,"heavy") and not r.set_order(t.id,"marked") and var_to_str([r.gold,r.rng.state,r.reserve,r.message])==old,"rejected discarded modes unchanged")
  if t.kind==0:ck(r.available_orders(t.kind)==["front"],"Brass only Front");continue
  var mode="screen" if t.kind==1 else "cluster"
  ck(r.set_order(t.id,mode) and r.order_of(t)==mode,"reserve explicit order")
  ck(r.gold==100-7*6,"order free")
  ck(r.set_order(t.id,"front") and not t.has("order"),"toggle back absent order")
  ck(r.set_order(t.id,mode),"restore alternate")
  var cell=Vector2i(-1,-1)
  for y in range(R.ROWS):
   for x in range(R.COLS):
    var p=Vector2i(x,y)
    if cell.x<0 and r.placement_error(p,t.kind).is_empty():cell=p
  ck(r.deploy(t.id,cell) and r.order_of(t)==mode,"deploy preserves")
  ck(r.recall(t.id) and r.order_of(t)==mode,"recall preserves")
 r.reset(1);ck(r.reserve.is_empty() and r.towers.is_empty(),"reset clears orders")
func _initialize():
 controlled();orders()
 print("P09 COMBINED ",checks-failures.size(),"/",checks," failures ",failures)
 quit(1 if failures.size() else 0)
