extends SceneTree
const Run=preload("res://src/Run.gd")
var checks=0
var failures=0

func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(why)

func near(a:float,b:float)->bool:
	return absf(a-b)<0.000001

func enemy(id:int,x:float,slow:float=0.0,hp:float=100.0,boss:bool=false)->Dictionary:
	return {"id":id,"hit_tick":-1,"route":[Vector2(0,3),Vector2(10,3)],"pos":Vector2(x,3),"direction":Vector2.RIGHT,"segment":0,"hp":hp,"maxhp":hp,"slow":slow,"role":"boss" if boss else "normal","boss":boss,"speed":0.0,"second":false}

func tower(id:int,kind:int,cell:Vector2i)->Dictionary:
	return {"id":id,"kind":kind,"rank":1,"cell":cell,"cool":0.0,"attack_tick":-1}

func fixture(rank:int,donor:Dictionary,others:Array,kind:int=2):
	var r=Run.new();r.reset(437);r.phase="fight"
	if rank>0:r.upgrades={"freeze":rank}
	r.towers=[tower(7,kind,Vector2i(5,3))]
	r.enemies=[donor]+others
	r.pending=1;r.spawn_time=100.0
	return r

func check_positive()->void:
	for rank in [1,2]:
		var donor=enemy(10,7.0,1.05)
		# Input order intentionally opposite priority; ID 2 and 5 tie in position.
		var far=enemy(1,6.0);var high=enemy(5,6.6);var low=enemy(2,6.6)
		var r=fixture(rank,donor,[far,high,low])
		var old_rng=r.rng.state;var old_gold=r.gold
		r.step()
		var events=r.tide_transfers
		check(events.size()==rank,"recipient count exactly freeze rank when enough victims")
		check(near(donor.slow,0.5),"living donor debits exactly half post-movement slow")
		check(near(low.slow,0.5/float(rank)),"nearest-core tie resolves by ascending spawn ID")
		check(near(high.slow,0.25 if rank==2 else 0.0),"rank2 shares remaining half equally")
		check(near(far.slow,0.0),"farther actual recipient not selected")
		check(near(donor.slow+far.slow+high.slow+low.slow,1.0),"status-duration conservation")
		check(r.rng.state==old_rng and r.gold==old_gold,"transfer changes no economy or loot RNG")
		check(r.shots.size()==4,"transfer creates zero duplicate damage shots")
		var dmg=(12.0*(1.0+0.03*rank))
		var splash=dmg*0.55*1.1
		check(near(donor.hp,100.0-dmg),"direct damage unchanged")
		check(near(far.hp,100.0-splash) and near(high.hp,100.0-splash) and near(low.hp,100.0-splash),"existing splash damage applies exactly once")
		check(near(r.wave_damage,dmg+splash*3.0),"transfer doesn't increment damage accumulator")
		for i in range(events.size()):
			var e=events[i]
			check(e.tick==r.tick_count and e.tower_id==7 and e.donor_id==10,"authoritative transfer attribution")
			check(e.recipient_id==[2,5][i] and near(e.duration,0.5/float(rank)),"event target and exact duration")
			check(e.from==donor.pos and e.to==(low.pos if i==0 else high.pos),"event coordinates from actual impact")

func check_one_recipient()->void:
	var donor=enemy(10,7.0,1.05);var eligible=enemy(2,6.3)
	var old=enemy(1,6.7,0.45);var boss=enemy(3,6.5,0.0,100.0,true)
	var r=fixture(2,donor,[old,boss,eligible]);r.step()
	check(r.tide_transfers.size()==1 and r.tide_transfers[0].recipient_id==2,"rank2 divides among actual eligible survivors, not capacity")
	check(near(eligible.slow,0.5) and near(donor.slow,0.5),"one recipient receives whole half")
	check(near(old.slow,0.4),"existing slow never overwritten")
	check(near(boss.slow,0.0),"boss recipient excluded")

func check_no_transfer()->void:
	for c in ["no_relic","unmarked","expired","boss_donor","dead_donor","dead_secondary","already_slow","boss_secondary","outside_radius","pulse"]:
		var rank=0 if c=="no_relic" else 1
		var slow=0.0 if c=="unmarked" else (Run.TICK if c=="expired" else 1.05)
		var donor=enemy(10,7.0,slow,1.0 if c=="dead_donor" else 100.0,c=="boss_donor")
		var other=enemy(2,5.0 if c=="outside_radius" else 6.3,0.45 if c=="already_slow" else 0.0,1.0 if c=="dead_secondary" else 100.0,c=="boss_secondary")
		var r=fixture(rank,donor,[other],0 if c=="pulse" else 2)
		r.step()
		check(r.tide_transfers.is_empty(),"blocked transfer case "+c)
		check(near(donor.slow,maxf(0.0,slow-Run.TICK)),"blocked transfer leaves donor's normal decay only "+c)
		check(near(other.slow,0.4 if c=="already_slow" else 0.0),"blocked transfer does not mutate recipient status "+c)
		if c=="dead_secondary":check(not r.enemies.has(other),"dead recipient removed normally")
		if c=="dead_donor":check(not r.enemies.has(donor),"dead donor removed normally")
		if c=="outside_radius":check(near(other.hp,100.0),"outside victim not actually damaged or selected")

func check_same_tick_and_expiry()->void:
	var donor=enemy(10,7.0,1.05);var recipient=enemy(2,6.0)
	var r=fixture(1,donor,[recipient]);r.towers.append(tower(9,0,Vector2i(3,3)))
	r.step()
	check(r.tide_transfers.size()==1,"exactly one actual transfer with following tower")
	var pulse=[ ]
	for s in r.shots:
		if s.tower_id==9:pulse.append(s)
	check(pulse.size()==1 and pulse[0].synergy=="conductive","later same-tick Brass sees new slow")
	var expected=100.0-(12.0*1.03*0.55*1.1)-(8.5*1.03*1.2)
	check(near(recipient.hp,expected),"same-tick real conductive damage uses transferred state")
	r.towers.clear()
	for i in range(10):r.step()
	check(r.tide_transfers.size()==1,"event retained for last ten ticks")
	r.step()
	check(r.tide_transfers.is_empty(),"event expiry bounded")
	r.tide_transfers.append({"tick":r.tick_count});r.reset(437)
	check(r.tide_transfers.is_empty(),"reset discards visual history")
	var loot=r.draw_loot()
	check(r.deploy(loot.id,Vector2i(5,3)),"deploy actual RNG reward")
	r.tide_transfers.append({"tick":r.tick_count});check(r.start(),"start")
	check(r.tide_transfers.is_empty(),"begin next wave discards event history")

func check_no_recursion()->void:
	var donor=enemy(10,7.0,1.05);var a=enemy(1,6.6);var b=enemy(2,6.3);var c=enemy(3,6.0)
	var r=fixture(1,donor,[a,b,c])
	r.towers.append(tower(8,2,Vector2i(5,3)))
	r.step()
	check(r.tide_transfers.size()==2,"two actual Hammer attacks, at most one transfer recipient each")
	check(r.tide_transfers[0].recipient_id==1 and r.tide_transfers[1].recipient_id==2,"second attack skips already slowed recipient")
	check(near(donor.slow,0.25) and near(a.slow,0.5) and near(b.slow,0.25) and near(c.slow,0.0),"successive attacks conserve total duration")
	check(r.shots.size()==8,"no recursive damage/transfer shot")

func _initialize()->void:
	check_positive();check_one_recipient();check_no_transfer();check_same_tick_and_expiry();check_no_recursion()
	print("P08 shatter tide checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
