extends SceneTree
const Run=preload("res://src/Run.gd")
const Art=preload("res://src/BattleAtmosphere.gd")
const Read=preload("res://src/BattleReadability.gd")
const ORIGIN=Vector2(52,60)
const TILE=76.0
var passed:int=0
var failed:int=0
var observed_redirects:int=0
var observed_status:int=0
var hidden_status:int=0

class OldModel:
	extends RefCounted
	var phase:String="fight"
	var tick_count:int=0
	var enemies:Array=[]

func _initialize()->void:call_deferred("execute")
func ck(ok:bool,msg:String)->void:
	if ok:passed+=1
	else:failed+=1;push_error(msg)

func enemy(id:int,p:Vector2,role:String="normal",hp:float=100.0)->Dictionary:
	var route:Array=[Vector2(0,p.y),Vector2(11,p.y)]
	return {"id":id,"pos":p,"route":route,"segment":0,"direction":Vector2.RIGHT,"hp":hp,"maxhp":100.0,
		"slow":0.0,"role":role,"boss":role=="boss","speed":0.0,"second":false,"hit_tick":-1}

func trial(t:int=0,guard_hp:float=100.0)->RefCounted:
	var g=Run.new()
	g.reset(437)
	g.stage=1
	g.phase="fight"
	g.spawn_time=100.0
	g.pending=1
	g.towers=[{"id":7,"kind":t,"rank":1,"cell":Vector2i(5,3),"cool":0.0,"attack_tick":-1}]
	g.enemies=[enemy(10,Vector2(7,3),"runner"),enemy(5,Vector2(6,3),"guard",guard_hp)]
	return g

func snapshot(g)->String:
	return var_to_str([g.stage,g.wave,g.phase,g.tick_count,g.enemies,g.towers,g.shots,g.guard_intercepts,
		g.deaths,g.tide_transfers,g.hp,g.gold,g.rng.state,g.wave_damage,g.kills,g.pending,g.reserve,g.upgrades])

func status_contract(g,a,r,label:String)->void:
	var l:Dictionary=r.layout(g,ORIGIN,TILE)
	var before:String=snapshot(g)
	var records:Array=a.guard_status_records(g,l)
	ck(snapshot(g)==before,label+" status query read-only")
	var expected:Array=g.enemies.filter(func(e):return e.hp>0.0 and e.role=="guard" and not e.boss and (g.guard_ready(e) or g.guard_remaining_ticks(e)>0)) if g.phase=="fight" else []
	ck(records.size()==expected.size(),label+" only exact living guard readiness/cooldown states")
	var protected_rects:Array=[]
	if l.warning_rect.size.x>0.0:protected_rects.append(l.warning_rect.grow(2.0))
	for row in l.units.values():
		if row.bar_draw:protected_rects.append(Rect2(row.bar_pos,row.bar_size).grow(3.0))
		else:protected_rects.append(Rect2(Vector2(row.anchor)-Vector2(5,5),Vector2(10,10)))
	var all_correct:bool=true
	var all_clear:bool=true
	for record in records:
		var match:Array=expected.filter(func(e):return int(e.id)==record.guard_id)
		all_correct=all_correct and match.size()==1
		if match.size()==1:
			all_correct=all_correct and record.ready==g.guard_ready(match[0]) and record.remaining==g.guard_remaining_ticks(match[0]) and record.cooldown_ticks==Run.GUARD_INTERCEPT_TICKS
		all_correct=all_correct and record.anchor==l.units[record.guard_id].anchor
		if record.draw:
			all_clear=all_clear and l.board.encloses(record.rect.grow(1.0)) and Vector2(record.point).distance_to(record.anchor)<43.0
			for rect in protected_rects:
				all_clear=all_clear and not record.rect.grow(1.0).intersects(rect)
			protected_rects.append(record.rect.grow(2.0))
		else:
			hidden_status+=1
			print("HIDDEN ",label," guard=",record.guard_id," anchor=",record.anchor," warning=",l.warning_rect," n=",l.units.size())
		observed_status+=1
	ck(all_correct,label+" exact readiness type/remaining/anchor")
	ck(all_clear,label+" status badges avoid HP/critical warning and each other")
	ck(var_to_str(a.guard_status_records(g,l))==var_to_str(records),label+" repeated layout query deterministic")

func event_contract(g,a,label:String)->void:
	var before:String=snapshot(g)
	var records:Array=a.guard_redirect_records(g)
	var truth:Array=g.guard_intercepts.filter(func(e):return g.phase=="fight" and g.tick_count-int(e.tick)>=0 and g.tick_count-int(e.tick)<Art.GUARD_EVENT_TICKS)
	ck(records.size()==truth.size(),label+" exact live historical event count")
	var correct:bool=true
	for i in range(records.size()):
		var rec:Dictionary=records[i]
		var evt:Dictionary=truth[i]
		correct=correct and rec.tick==evt.tick and rec.age==g.tick_count-int(evt.tick) and rec.guard_id==evt.guard_id and rec.intended_id==evt.intended_id and rec.from==evt.from and rec.to==evt.to and rec.attacker_pos==evt.attacker_pos and is_equal_approx(rec.damage,evt.damage)
		observed_redirects+=1
	ck(correct,label+" donor/recipient actual event coordinates, not current visual offset")
	ck(snapshot(g)==before,label+" event read-only")
	ck(var_to_str(a.guard_redirect_records(g))==var_to_str(records),label+" same tick no change or duplicate state")

func fixtures()->void:
	var a=Art.new()
	var r=Read.new()
	var g=trial()
	a.reset(g)
	status_contract(g,a,r,"fresh ready")
	ck(a.guard_redirect_records(g).is_empty(),"ready does not invent interception")
	var ready:Array=a.guard_status_records(g,r.layout(g,ORIGIN,TILE))
	ck(ready.size()==1 and ready[0].ready and ready[0].remaining==0 and ready[0].draw,"ready shield shown")
	g.step()
	a.observe(g)
	event_contract(g,a,"actual direct redirect")
	status_contract(g,a,r,"actual cooldown")
	var evt:Dictionary=g.guard_intercepts[0]
	ck(g.shots.size()==1 and g.shots[0].to==evt.to and g.shots[0].from==evt.attacker_pos,"ordinary shot remains actual guard recipient")
	ck(a.impacts.size()==1 and a.impacts[0].to==evt.to and a.impacts[0].to!=evt.from,"guard art not second damage/trace at intended target")
	var cooldown:Array=a.guard_status_records(g,r.layout(g,ORIGIN,TILE))
	ck(cooldown.size()==1 and not cooldown[0].ready and cooldown[0].remaining==24,"true cooldown not ready symbol")
	var old_from:Vector2=evt.from
	var old_to:Vector2=evt.to
	g.towers[0].cool=1000.0
	for e in g.enemies:e.speed=1.0
	g.step()
	a.observe(g)
	ck(g.enemies[0].pos!=old_from and g.enemies[1].pos!=old_to,"real next tick moves both units")
	var persisted:Dictionary=a.guard_redirect_records(g)[0]
	ck(persisted.from==old_from and persisted.to==old_to,"redirect stays at historical actual hit point")
	for i in range(8):g.step();a.observe(g)
	ck(g.tick_count==10 and a.guard_redirect_records(g).size()==1,"last visible redirect tick age9")
	g.step();a.observe(g)
	ck(g.tick_count==11 and a.guard_redirect_records(g).is_empty(),"age10 already ends visual")
	ck(not g.guard_ready(g.enemies[1]) and a.guard_status_records(g,r.layout(g,ORIGIN,TILE))[0].remaining==14,"cooldown badge outlives actual flash truthfully")
	for i in range(14):g.step();a.observe(g)
	ck(g.tick_count==25 and a.guard_status_records(g,r.layout(g,ORIGIN,TILE))[0].ready,"exact model ready tick")
	ck(a.guard_redirect_records(g).is_empty(),"refresh cooldown never creates interception")
	g=trial(2)
	a.reset(g)
	g.step();a.observe(g)
	ck(a.guard_redirect_records(g).is_empty(),"Hammer bypass no intercept VFX")
	ck(a.guard_status_records(g,r.layout(g,ORIGIN,TILE))[0].ready,"Hammer bypass preserves shield state")
	g=trial(0,1.0)
	a.reset(g)
	g.step();a.observe(g)
	ck(g.enemies.size()==1 and a.guard_status_records(g,r.layout(g,ORIGIN,TILE)).is_empty(),"lethal guard removed, no ghost readiness")
	ck(a.guard_redirect_records(g).size()==1,"lethal actual redirect still visible at confirmed event")
	# Duplicate event fixture: only one historical VFX for unique event identity.
	g.guard_intercepts.append(g.guard_intercepts[0].duplicate(true))
	ck(a.guard_redirect_records(g).size()==1,"duplicate record doesn't yield duplicate redirect")
	g.phase="build"
	ck(a.guard_redirect_records(g).is_empty() and a.guard_status_records(g,r.layout(g,ORIGIN,TILE)).is_empty(),"wave phase end clears all visual readiness/redirects")
	var legacy=OldModel.new()
	ck(a.guard_redirect_records(legacy).is_empty() and a.guard_status_records(legacy,{}).is_empty(),"legacy/no feature model tolerant")
	# Dense terminal warning fixture. Badge can be hidden if impossible without
	# obstructing truth; never moves to another guard's anchor/warning/HP.
	g=Run.new();g.reset();g.stage=2;g.phase="fight";g.enemies=[]
	for i in range(12):g.enemies.append(enemy(i,Vector2(10.0+float(i%3)*0.15,4.0),"guard" if i%2 else "normal"))
	status_contract(g,a,r,"dense alert fixture")

func actual_waves()->void:
	for stage in [1,2]:
		for wave in [0,1]:
			for variant in [0,1]:
				var g=Run.new();g.reset(437);g.stage=stage;g.wave=wave;g.opened=stage==1 and variant==1
				var placements:Array=[Vector2i(10,6),Vector2i(9,6),Vector2i(10,7),Vector2i(8,7),Vector2i(9,3),Vector2i(10,3)]
				for cell in placements:
					if g.reserved(cell):continue
					g.towers.append({"id":g.towers.size()+1,"cell":cell,"kind":0 if g.towers.is_empty() else 1,"rank":2 if variant else 1,"cool":0.0})
					if g.towers.size()==2:break
				ck(g.start(),"actual guard wave start")
				var a=Art.new()
				var r=Read.new()
				a.reset(g)
				for i in range(1400):
					if g.phase!="fight":break
					g.step()
					a.observe(g)
					if i%8!=0:continue
					var tag:String="%d/%d/%d/t%d"%[stage,wave,variant,g.tick_count]
					status_contract(g,a,r,tag)
					event_contract(g,a,tag)

func execute()->void:
	fixtures()
	var fixture_hidden:int=hidden_status
	actual_waves()
	ck(observed_redirects>0 and observed_status>0,"actual wave sample includes real redirects/status")
	ck(hidden_status-fixture_hidden==0,"actual sampled guard badges never dropped to protect critical geometry")
	print("P09_GUARD_ART passed=%d failed=%d observed_redirects=%d observed_status=%d hidden_status=%d fixture_hidden=%d actual_hidden=%d"%[passed,failed,observed_redirects,observed_status,hidden_status,fixture_hidden,hidden_status-fixture_hidden])
	quit(1 if failed else 0)
