extends SceneTree
const Run=preload("res://src/Run.gd")
const Read=preload("res://src/BattleReadability.gd")
const Art=preload("res://src/BattleAtmosphere.gd")
var failures=0
func setup(stage:int,wave:int)->RefCounted:
	var g=Run.new()
	g.reset(437)
	g.stage=stage;g.wave=wave;g.opened=stage==1
	g.upgrades={"freeze":2,"blast":1,"chain":1,"relay":1}
	var cells=[Vector2i(5,2),Vector2i(6,2),Vector2i(7,2),Vector2i(8,3),Vector2i(9,3),Vector2i(4,4),Vector2i(7,4),Vector2i(10,3),Vector2i(2,2)]
	for c in cells:
		if g.reserved(c):continue
		var index=g.towers.size()
		var kind=index%3
		var t={"id":index+1,"kind":kind,"rank":2,"cell":c,"cool":0.0,"attack_tick":-1}
		if kind==1:t.order="screen"
		elif kind==2:t.order="cluster"
		g.towers.append(t)
		if g.towers.size()==5:break
	if not g.start():failures+=1
	return g

func percentiles(samples:Array)->Dictionary:
	samples.sort()
	if samples.is_empty():return {}
	return {"n":samples.size(),"median_us":samples[(samples.size()-1)/2],"p95_us":samples[ceili(samples.size()*0.95)-1],"p99_us":samples[ceili(samples.size()*0.99)-1],"max_us":samples[-1]}

func process_wave(stage:int,wave:int,rep:int)->Dictionary:
	var g=setup(stage,wave)
	var r=Read.new()
	var a=Art.new()
	a.reset(g)
	var ticks:Array=[];var observe:Array=[];var layout:Array=[];var guards:Array=[]
	var all_tick:int=0
	var max_enemy:int=0
	var result_context:Array=[]
	var origin=Vector2(52,60)
	var tile=76.0
	while g.phase=="fight" and all_tick<1600:
		var t=Time.get_ticks_usec()
		g.step()
		ticks.append(Time.get_ticks_usec()-t)
		t=Time.get_ticks_usec()
		a.observe(g)
		observe.append(Time.get_ticks_usec()-t)
		t=Time.get_ticks_usec()
		var l=r.layout(g,origin,tile)
		layout.append(Time.get_ticks_usec()-t)
		t=Time.get_ticks_usec()
		a.guard_status_records(g,l);a.guard_redirect_records(g)
		guards.append(Time.get_ticks_usec()-t)
		max_enemy=maxi(max_enemy,g.enemies.size())
		all_tick+=1
		result_context.append([g.phase,g.tick_count,g.enemies,g.towers,g.shots,g.deaths,g.tide_transfers,g.guard_intercepts,g.hp,g.gold,g.rng.state,g.wave_damage,g.kills,g.pending].hash())
	if all_tick>=1600:failures+=1
	return {"stage":stage,"wave":wave,"rep":rep,"tick":percentiles(ticks),"observe":percentiles(observe),"layout":percentiles(layout),"guard_queries":percentiles(guards),"max_enemies":max_enemy,"phase":g.phase,"result_hash":result_context.hash(),"ticks":all_tick,"hp":g.hp,"kills":g.kills}

func _initialize()->void:
	call_deferred("execute")
func execute()->void:
	var rows=[]
	for stage in range(3):
		for wave in range(2):
			process_wave(stage,wave,-1)
			var expected:int=0
			for rep in range(5):
				var row=process_wave(stage,wave,rep)
				if rep==0:expected=row.result_hash
				elif row.result_hash!=expected:failures+=1
				rows.append(row)
	print("P09_PERF ",JSON.stringify({"godot":Engine.get_version_info().string,"failures":failures,"rows":rows}))
	quit(1 if failures else 0)
