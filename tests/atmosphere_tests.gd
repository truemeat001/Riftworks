extends SceneTree
const Atmosphere=preload("res://src/BattleAtmosphere.gd")
const Run=preload("res://src/Run.gd")
var passed:int=0
var failed:int=0

func _initialize()->void:call_deferred("execute")

func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:
		failed+=1
		push_error(label)

func snapshot(g)->String:
	# Explicit all authoritative state consumed by atmosphere (including RNG).
	return var_to_str([g.stage,g.wave,g.phase,g.hp,g.gold,g.tick_count,g.run_leaks,g.wave_leaks,
	g.pending,g.pending_main,g.pending_extra,g.towers,g.enemies,g.shots,g.deaths,g.reserve,
	g.upgrades,g.route_choice,g.opened,g.rng.state,g.last_loot])

func setup_run()->RefCounted:
	var g=Run.new()
	g.reset(437)
	g.draw_loot()
	check(not g.reserve.is_empty(),"seed437 first draw unit")
	check(g.deploy(g.reserve[0].id,Vector2i(1,2)),"deploy close actual route")
	return g

func actual_observation()->void:
	var g=setup_run()
	var a=Atmosphere.new()
	a.reset(g)
	check(a.active_routes(g).size()==1 and a.active_routes(g)[0]==g.path(),"ATM01 active route derives model")
	var initial:Array=a.active_routes(g)[0]
	g.alter()
	check(a.active_routes(g)[0]==g.path() and a.active_routes(g)[0]!=initial,"ATM01 maze switch changes real path")
	g.alter()
	check(not a.danger_active and a.traces.is_empty(),"preparation no danger/no premature traces")
	check(g.start(),"actual accepted start")
	var ev:Dictionary=a.observe(g)
	check(ev.wave_start and not ev.first_contact and not ev.alert_enter,"start edge no false contact")
	check(not a.observe(g).wave_start,"same accepted start not replayed")
	var first_count:int=0
	var contacted:bool=false
	for i in range(1500):
		if g.phase!="fight":break
		g.step()
		var before:String=snapshot(g)
		ev=a.observe(g)
		check(snapshot(g)==before,"observe does not mutate any Run data tick %d"%g.tick_count)
		if ev.first_contact:
			first_count+=1
			contacted=true
			check(not g.shots.is_empty(),"first contact actual shot exists")
			check(ev.contact_pos==g.shots[-1].to or g.shots.any(func(s):return s.to==ev.contact_pos),"first contact position exact actual impact")
		var traces_before:String=var_to_str(a.traces)
		var impacts_before:String=var_to_str(a.impacts)
		var duplicate:Dictionary=a.observe(g)
		check(not duplicate.first_contact and not duplicate.wave_start and int(duplicate.leak_count)==0 and not duplicate.wave_end,"same tick edge idempotence")
		check(var_to_str(a.traces)==traces_before and var_to_str(a.impacts)==impacts_before,"same tick no double effect")
		check(a.traces.size()<=Atmosphere.TRACE_CAP and a.impacts.size()<=Atmosphere.IMPACT_CAP,"bounded world presentation")
	check(contacted and first_count==1,"exact one first-contact edge actual complete wave")
	check(g.phase!="fight","first actual wave ended")
	check(a.impacts.is_empty() and not a.danger_active,"combat effects and alarm clear at wave end")
	check(not a.traces.is_empty() if g.phase=="build" else a.traces.is_empty(),"successful same-stage traces persist / failure clears")
	if g.phase=="build":
		var previous:Dictionary=a.traces[0].duplicate()
		check(g.start(),"second real wave accepts")
		ev=a.observe(g)
		check(ev.wave_start and a.traces.is_empty() and a.previous_traces[0]==previous,"new wave fades prior real traces")
		for i in range(20):
			if g.phase!="fight":break
			g.step()
			a.observe(g)
		check(a.previous_traces.is_empty(),"old-wave trace fade completes in 20 actual ticks")
	g.reset(437)
	a.reset(g)
	check(a.traces.is_empty() and a.impacts.is_empty() and a.previous_traces.is_empty() and a.last_contact_tick==-1,"explicit restart clears presentation")

func fixture_tests()->void:
	var g=Run.new()
	g.reset(437)
	var a=Atmosphere.new()
	a.reset(g)
	g.stage=1
	g.opened=false
	check(a.active_routes(g).size()==1 and a.active_routes(g)[0][0]==g.path()[0],"ATM01 B closed no false entry")
	g.opened=true
	var routes:Array=a.active_routes(g)
	check(routes.size()==2 and routes[0]==g.path() and routes[1]==g.path(false) and routes[0][0]!=routes[1][0],"ATM01 B open actual dual entries")
	a.reset(g)
	g.phase="fight"
	a.observe(g)
	# Synthetic fixture explicitly tests remaining route length, not distance to
	# endpoint: visually near terminal but actual remaining route is 9.
	var winding:Array=[Vector2(11,3),Vector2(7,3),Vector2(7,4),Vector2(11,4)]
	g.enemies=[{"id":17,"hp":50.0,"pos":Vector2(11,3),"segment":0,"route":winding}]
	g.tick_count+=1
	var ev:Dictionary=a.observe(g)
	check(g.remaining_distance(g.enemies[0])>2.0 and not ev.alert_enter and not a.danger_active,"ATM03 geometric proximity alone not danger")
	g.enemies[0].route=[Vector2(9,4),Vector2(11,4)]
	g.enemies[0].pos=Vector2(9,4)
	g.tick_count+=1
	ev=a.observe(g)
	check(ev.alert_enter and a.danger_count==1 and a.danger_pos==Vector2(9,4),"ATM03 exactly two remaining path cells alert")
	check(not a.observe(g).alert_enter,"ATM03 alert duplicate no replay")
	g.enemies[0].hp=0.0
	g.tick_count+=1
	ev=a.observe(g)
	check(ev.alert_exit and not a.danger_active,"ATM03 killed enemy immediately clears danger")
	# More than one live threat; nearest threatened path is first.
	g.enemies=[{"id":22,"hp":10.0,"pos":Vector2(10.9,4),"segment":0,"route":[Vector2(9,4),Vector2(11,4)]},
		{"id":23,"hp":10.0,"pos":Vector2(10,4),"segment":0,"route":[Vector2(9,4),Vector2(11,4)]}]
	g.tick_count+=1
	ev=a.observe(g)
	check(ev.alert_enter and a.danger_count==2 and a.danger_pos==Vector2(10.9,4),"ATM03 tracks both real threats and nearest location")
	# Actual Run.step leak fixture (spawn exactly approaching final endpoint).
	g.stage=0
	g.opened=false
	g.phase="fight"
	g.pending=0
	g.pending_main=0
	g.pending_extra=0
	g.towers=[]
	g.enemies=[{"id":3,"hp":5.0,"maxhp":5.0,"route":[Vector2(10,4),Vector2(11,4)],
		"pos":Vector2(10.999,4),"segment":0,"speed":1.0,"slow":0.0,"boss":false,"direction":Vector2.RIGHT,"role":"normal"}]
	a.reset(g)
	a.observe(g)
	var hp_before:int=g.hp
	g.step()
	ev=a.observe(g)
	check(g.hp==hp_before-1 and ev.leak_count==1,"actual Run.step emits one true damage/leak observation")
	check(ev.wave_end and not a.danger_active,"leak reaching completed wave clears active alert")
	check(a.traces.is_empty(),"missed enemy does not fabricate battle impact scar")
	check(a.observe(g).leak_count==0,"true leak not replayed")
	# Multi-hit source fixture: explicit same tick shots and one death. Trace
	# records only actual impact positions, caps count and effects globally.
	g.reset(437)
	a.reset(g)
	g.phase="fight"
	a.observe(g)
	g.tick_count=1
	for y in range(8):
		for x in range(12):
			g.shots.append({"from":Vector2(0,0),"to":Vector2(x,y),"kind":1,"tower_id":1,"synergy":"","life":0.11,"tick":1})
	g.deaths=[{"pos":Vector2(0,0),"tick":1}]
	ev=a.observe(g)
	check(ev.first_contact and a.traces.size()==Atmosphere.TRACE_CAP and a.impacts.size()==Atmosphere.IMPACT_CAP,"ATM04 bounded trace/effect caps under worst-case observed positions")
	check(a.traces.all(func(t):return int(t.hits)>0 or int(t.deaths)>0),"every stored trace originates in actual fixture event")
	check(a.traces[0].deaths==1,"death at hit position adds true trace")
	var same:String=var_to_str(a.traces)
	a.observe(g)
	check(var_to_str(a.traces)==same,"many impacts not duplicated on repeated render observation")
	g.tick_count=7
	g.shots=[]
	g.deaths=[]
	a.observe(g)
	check(a.impacts.is_empty(),"transient world impact lifetime bounded by tick time")
	g.phase="build"
	a.observe(g)
	check(not a.traces.is_empty(),"confirmed event traces retained in same stage build")
	g.stage+=1
	a.observe(g)
	check(a.traces.is_empty() and a.previous_traces.is_empty(),"ATM04 stage change clears all prior positions")
	g.phase="fight"
	a.observe(g)
	g.tick_count+=1
	g.shots=[{"from":Vector2(0,0),"to":Vector2(2,2),"kind":2,"tower_id":1,"synergy":"shatter","life":0.11,"tick":g.tick_count}]
	a.observe(g)
	check(a.traces.size()==1,"new stage can record new confirmed event")
	g.phase="lost"
	a.observe(g)
	check(a.traces.is_empty() and a.impacts.is_empty() and not a.danger_active,"failure clears traces and transient warning")
	g.reset(437)
	a.observe(g)
	check(a.last_contact_tick==-1 and a.traces.is_empty(),"implicit reset observed by decreasing authoritative tick")

func execute()->void:
	actual_observation()
	fixture_tests()
	print("ATMOSPHERE_TESTS passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
