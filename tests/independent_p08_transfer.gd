extends SceneTree
const R=preload("res://src/Run.gd")
var checks=0
var failures=[]
func ck(v:bool,s:String):
 checks+=1
 if not v: failures.append(s);print("FAIL ",s)
func eq(a,b):return absf(float(a)-float(b))<0.00001
func foe(id:int,x:float,slow=0.0,hp=100.0,boss=false):
 return {"id":id,"hit_tick":-1,"route":[Vector2(0,2),Vector2(11,2)],"pos":Vector2(x,2),"direction":Vector2.RIGHT,"segment":0,"hp":hp,"maxhp":100.0,"slow":slow,"role":"boss" if boss else "normal","boss":boss,"speed":0.0,"second":false}
func run(rank:int,donor:Dictionary,others:Array,kind=2):
 var q=R.new();q.reset(437);q.phase="fight";q.pending=1;q.spawn_time=99
 if rank:q.upgrades={"freeze":rank}
 q.towers=[{"id":31,"kind":kind,"rank":1,"cell":Vector2i(2,1),"cool":0.0}]
 q.enemies=[donor.duplicate(true)]+others.duplicate(true)
 var old_rng=q.rng.state;var g=q.gold
 q.step()
 ck(q.gold==g and q.rng.state==old_rng,"no transfer economy/RNG change")
 return q
func slow(q,id):
 for e in q.enemies:
  if e.id==id:return e.slow
 return -1
func test_no(label,rank,donor,others,kind=2):
 var q=run(rank,donor,others,kind)
 ck(q.tide_transfers.is_empty(),label+" no event")
 return q
func _initialize():
 # Flow: existing simulation decrements duration by tick before targeting.
 var donor=foe(10,3,2.05)
 var b=foe(20,2.2)
 var c=foe(40,2.0)
 var d=foe(30,2.0)
 for lvl in [1,2]:
  var q=run(lvl,donor,[b])
  ck(q.tide_transfers.size()==1,"one recipient both ranks")
  ck(eq(slow(q,10),1.0) and eq(slow(q,20),1.0),"single recipient gets half at both ranks")
  if q.tide_transfers.size()==1:
   var e=q.tide_transfers[0]
   ck(e.donor_id==10 and e.recipient_id==20 and e.tower_id==31 and e.tick==q.tick_count,"event identities actual")
   ck(e.from==donor.pos and e.to==b.pos and eq(e.duration,1.0),"event position/duration exact")
  ck(q.shots.size()==2 and q.shots[0].synergy=="shatter","existing shots only")
  q.towers.clear()
  for j in range(11):q.step()
  ck(q.tide_transfers.is_empty(),"event expires after bounded retention")
  q.reset(7);ck(q.tide_transfers.is_empty(),"reset clears transfers")
 var q=run(2,donor,[c,d,b])
 ck(q.tide_transfers.size()==2,"rank2 cap")
 ck(eq(slow(q,10),1.0) and eq(slow(q,20),0.5) and eq(slow(q,30),0.5) and eq(slow(q,40),0),"nearest-to-exit then spawn ID tie")
 var p=run(2,donor,[d,b,c])
 ck(p.tide_transfers==q.tide_transfers,"array permutation invariant")
 p=run(1,donor,[c,d,b])
 ck(p.tide_transfers.size()==1 and eq(slow(p,20),1.0),"rank1 cap and preference")
 var farther=foe(60,1.2)
 var pre=foe(20,2.2,0.6)
 q=test_no("existing slow",2,donor,[pre])
 ck(eq(slow(q,10),2.0) and eq(slow(q,20),0.55),"no overwrite");
 q=test_no("out of splash",2,donor,[farther])
 ck(eq(slow(q,10),2.0) and eq(slow(q,60),0),"out of range no debit")
 q=test_no("dead recipient",2,donor,[foe(20,2.2,0,1)])
 ck(eq(slow(q,10),2.0) and slow(q,20)<0,"dead recipient no debit")
 q=test_no("dead donor",2,foe(10,3,2.05,1),[b])
 ck(slow(q,10)<0 and eq(slow(q,20),0),"no posthumous transfer")
 q=test_no("boss donor",2,foe(10,3,2.05,100,true),[b])
 ck(eq(slow(q,10),2.0),"boss donor unchanged")
 q=test_no("boss recipient",2,donor,[foe(20,2.2,0,100,true)])
 ck(eq(slow(q,10),2.0),"boss recipient cannot debit")
 q=test_no("unmarked donor",2,foe(10,3),[b])
 q=test_no("mark expires before hit",2,foe(10,3,0.02),[b])
 q=test_no("no relic",0,donor,[b])
 q=test_no("Brass",2,donor,[b],0)
 q=test_no("Mist",2,donor,[b],1)
 q=run(2,donor,[pre,c,d])
 ck(q.tide_transfers.size()==2 and eq(slow(q,40),0.5) and eq(slow(q,30),0.5) and eq(slow(q,20),0.55),"already slowed omitted before selecting")
 # Same rank, same damage/splash count regardless of recipient eligibility.
 p=test_no("all marked secondary",2,donor,[foe(20,2.2,0.5)])
 q=run(2,donor,[b])
 ck(eq(p.wave_damage,q.wave_damage) and p.shots==q.shots and eq(p.towers[0].cool,q.towers[0].cool),"transfer cannot add damage, shot, or alter cooldown")
 print("P08 TRANSFER ",checks-failures.size(),"/",checks," failures ",failures)
 quit(1 if failures.size() else 0)
