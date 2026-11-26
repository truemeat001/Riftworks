extends SceneTree
const Run=preload("res://src/Run.gd")
var checks=0
var failures=0
func ck(ok:bool,msg:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(msg)
func near(a:float,b:float)->bool:return absf(a-b)<0.000001
func enemy(id:int,x:float,role:String="normal",hp:float=100.0,slow:float=0.0,y:float=3.0,end:float=10.0)->Dictionary:
	return {"id":id,"hit_tick":-1,"route":[Vector2(0,y),Vector2(end,y)],"pos":Vector2(x,y),"direction":Vector2.RIGHT,"segment":0,"hp":hp,"maxhp":100.0,"slow":slow,"role":role,"boss":role=="boss","speed":0.0,"second":false}
func tower(id:int,kind:int,cell:Vector2i=Vector2i(5,3))->Dictionary:
	return {"id":id,"kind":kind,"rank":1,"cell":cell,"cool":0.0,"attack_tick":-1}
func trial(enemies:Array,kind:int=0,cell:Vector2i=Vector2i(5,3)):
	var r=Run.new();r.reset(437);r.phase="fight";r.towers=[tower(7,kind,cell)];r.enemies=enemies;r.pending=1;r.spawn_time=100.0
	return r
func basic()->void:
	for kind in [0,1]:
		var intended=enemy(10,7.0,"runner");var g=enemy(5,6.0,"guard")
		var r=trial([intended,g],kind);var rng=r.rng.state;var gold=r.gold
		ck(r.guard_ready(g),"fresh guard ready")
		r.step()
		var dmg=Run.BASE_DAMAGE[kind]
		ck(near(intended.hp,100.0) and near(g.hp,100.0-dmg),"exact direct only recipient")
		ck(near(r.wave_damage,dmg) and r.shots.size()==1,"one damage/shot, no extra attack")
		ck(r.shots[0].from==Vector2(5,3) and r.shots[0].to==g.pos,"shot points at actual guard")
		ck(r.guard_intercepts.size()==1,"one actual event")
		var ev:Dictionary=r.guard_intercepts[0]
		ck(ev.tick==1 and ev.intended_id==10 and ev.guard_id==5 and ev.tower_id==7,"event attribution")
		ck(ev.from==intended.pos and ev.to==g.pos and ev.attacker_pos==Vector2(5,3) and near(ev.damage,dmg),"event actual positions/effective direct damage")
		ck(ev.ready_tick==25 and g.intercept_ready_tick==25 and r.guard_remaining_ticks(g)==24 and not r.guard_ready(g),"exact cooldown")
		ck(near(intended.slow,0.0) and near(g.slow,0.8 if kind==1 else 0.0),"Mist status only actual guard")
		ck(r.towers[0].attack_tick==1 and near(r.towers[0].cool,Run.BASE_COOLDOWN[kind]),"single actual cooldown")
		ck(r.rng.state==rng and r.gold==gold,"no economic or loot RNG mutation")
func tie_and_range()->void:
	var a=enemy(10,7);var far=enemy(1,5.9,"guard");var close=enemy(8,6.5,"guard")
	var r=trial([a,far,close]);r.step();ck(r.guard_intercepts[0].guard_id==8,"nearest intended target first")
	a=enemy(10,7);var g1=enemy(1,6,"guard");var g2=enemy(9,7,"guard",100,0,2,10.75)
	r=trial([a,g1,g2]);r.step();ck(r.guard_intercepts[0].guard_id==9,"equal proximity prefers remaining route")
	a=enemy(10,7);g1=enemy(9,6,"guard");g2=enemy(1,6,"guard")
	r=trial([a,g1,g2]);r.step();ck(r.guard_intercepts[0].guard_id==1,"equal proximity/distance uses ascending id, not array order")
	# Explicit boundary checks avoid relying on solver movement or float approximation.
	a=enemy(10,7);g1=enemy(1,5.8,"guard")
	r=trial([a,g1]);r.step();ck(r.guard_intercepts.size()==1,"radius exactly 1.2 inclusive")
	a=enemy(10,7);g1=enemy(1,5.79,"guard")
	r=trial([a,g1]);r.step();ck(r.guard_intercepts.is_empty() and a.hp<100 and g1.hp==100,"radius outside bypass")
	a=enemy(10,7.9);g1=enemy(1,8.5,"guard")
	r=trial([a,g1]);r.step();ck(r.guard_intercepts.is_empty() and a.hp<100 and g1.hp==100,"guard in ally radius but outside attacker range bypass")
func cooldown_cases()->void:
	var a=enemy(10,7);var g=enemy(5,6,"guard");var r=trial([a,g]);r.towers.append(tower(8,0));r.step()
	ck(r.guard_intercepts.size()==1 and near(a.hp,91.5) and near(g.hp,91.5),"only one of same tick two direct attacks redirected")
	ck(near(r.wave_damage,17.0) and r.shots.size()==2,"same tick no duplication")
	# Advance actual 20Hz ticks, forcing fixture towers to cool except at exact test boundaries.
	r.towers=[tower(7,0)];r.towers[0].cool=1000.0
	for i in range(22):r.step()
	ck(r.tick_count==23 and r.guard_remaining_ticks(g)==2,"cooldown ages in ticks")
	r.towers[0].cool=0.0;r.step()
	ck(r.tick_count==24 and not r.guard_ready(g) and near(a.hp,83.0) and near(g.hp,91.5),"one tick before ready bypass")
	r.towers[0].cool=0.0;r.step()
	ck(r.tick_count==25 and r.guard_remaining_ticks(g)==24 and near(g.hp,83.0),"exact 24-tick expiry reintercepts")
	ck(r.guard_intercepts.size()==1 and r.guard_intercepts[0].tick==25,"old presentation event expired")
	r.reset(437);ck(r.guard_intercepts.is_empty(),"reset clears events")
func statuses_and_secondary()->void:
	var a=enemy(10,7);var g=enemy(5,6,"guard",40.0,1.0)
	var r=trial([a,g]);r.upgrades={"focus":1};r.step()
	var dmg=8.5*1.2*1.3
	ck(near(g.hp,40.0-dmg) and near(a.hp,100.0),"conductive/focus use recipient status and current HP")
	ck(r.shots[0].synergy=="conductive" and near(r.guard_intercepts[0].damage,dmg),"actual recipient synergy/damage event")
	# Burst primary and secondary are never intercepted.
	a=enemy(10,7);g=enemy(5,6.5,"guard");r=trial([a,g],2);r.step()
	ck(r.guard_intercepts.is_empty() and near(a.hp,88) and near(g.hp,93.4),"Hammer main+area bypass")
	ck(near(r.wave_damage,18.6) and r.shots.size()==2 and r.guard_ready(g),"AoE unconsumed guardian cooldown")
	# Secondary chain near an eligible guard but direct target out of ally radius.
	a=enemy(10,7);var secondary=enemy(20,5.7);g=enemy(5,4.55,"guard");r=trial([a,secondary,g]);r.upgrades={"chain":1};r.step()
	var base=8.5*1.05
	ck(r.guard_intercepts.is_empty() and near(a.hp,100-base) and near(secondary.hp,100-base*.65) and g.hp==100,"chain secondary bypasses nearby guard")
	# Actual intercept changes origin; original target may be legitimately hit by secondary chain.
	a=enemy(10,7);g=enemy(5,6.5,"guard");r=trial([a,g]);r.upgrades={"chain":1};r.step()
	ck(r.guard_intercepts.size()==1 and near(g.hp,100-base) and near(a.hp,100-base*.65),"redirected chain legitimate original secondary")
	ck(r.shots.size()==2 and r.shots[0].to==g.pos and r.shots[1].from==g.pos and r.shots[1].to==a.pos,"chain origin actual guard, no recursive intercept")
	# A lethal redirect reports HP actually removed, not nominal overkill.
	a=enemy(10,7);g=enemy(5,6,"guard",1.0);r=trial([a,g]);r.step()
	ck(r.guard_intercepts.size()==1 and near(r.guard_intercepts[0].damage,1.0) and not r.enemies.has(g) and r.kills==1,"lethal guard intercept event effective damage")
func blocked()->void:
	for reason in ["boss","guard","dead_guard","unready","outside"]:
		var a=enemy(10,7,"boss" if reason=="boss" else ("guard" if reason=="guard" else "normal"));var g=enemy(5,6,"guard",0.0 if reason=="dead_guard" else 100.0)
		if reason=="unready":g.intercept_ready_tick=2
		if reason=="outside":g.pos=Vector2(4.5,3)
		var r=trial([a,g]);r.step();ck(r.guard_intercepts.is_empty() and a.hp<100,"no invalid redirect "+reason)
	# Dead would-be foremost enemy must never create a redirect; closest live direct target only.
	var dead=enemy(10,7.5,"normal",0.0);var live=enemy(20,7.0);var g=enemy(5,6,"guard")
	var r=trial([dead,live,g]);r.step()
	ck(r.guard_intercepts.size()==1 and r.guard_intercepts[0].intended_id==20,"dead foremost enemy never a protected direct target")
	# Eligible guard precisely on actual attack-range boundary.
	live=enemy(20,7.75);g=enemy(5,8.0,"guard",100,0,3,11.0);r=trial([live,g]);r.step()
	ck(r.guard_intercepts.size()==1 and r.guard_intercepts[0].guard_id==5,"actual attacker range exact inclusive")
	# Directly targeted guard's normal hit cannot spend escort readiness.
	g=enemy(5,7,"guard");var other=enemy(9,6,"guard");r=trial([g,other]);r.step()
	ck(r.guard_intercepts.is_empty() and r.guard_ready(g) and g.hp<100 and other.hp==100,"guard direct hit does not consume either escort")
	r=Run.new();r.reset(437);ck(not r.forecast().has("guard_escort"),"forecast no fake guard on first wave")
	r.stage=1;var forecast:Dictionary=r.forecast();ck(forecast.roles.guard>0 and near(forecast.guard_escort.radius,1.2) and near(forecast.guard_escort.cooldown_seconds,1.2),"authoritative forecast rule bound to actual guard count")
func _initialize()->void:
	basic();tie_and_range();cooldown_cases();statuses_and_secondary();blocked()
	print("P09_GUARD_FIXTURES checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
