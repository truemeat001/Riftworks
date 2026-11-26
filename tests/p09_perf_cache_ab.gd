extends SceneTree
const Baseline=preload("res://tests/p09_perf_ticks.gd")
const Read=preload("res://src/BattleReadability.gd")
const Art=preload("res://src/BattleAtmosphere.gd")
const O=Vector2(52,60)
const TILE=76.0

# Isolated proof: fixed Run state between three presentation frames (60Hz/20Hz,
# no animation clocks included). A caller controls invalidation on step/reset/start.
# Not a production cache or native frame renderer.
func candidate(r,a,g)->Array:
	var l=r.layout(g,O,TILE)
	return [l,a.guard_status_records(g,l),a.guard_redirect_records(g)]
func batch(r,a,g,cache:bool)->Array:
	var rows=[]
	if cache:
		var b=candidate(r,a,g)
		for i in range(3):rows.append(b)
	else:
		for i in range(3):rows.append(candidate(r,a,g))
	return rows

func _initialize()->void:call_deferred("execute")
func execute()->void:
	var baseline=Baseline.new()
	var report=[]
	var fails=0
	for stage in range(3):
		for wave in range(2):
			var g=baseline.setup(stage,wave)
			var a=Art.new();a.reset(g)
			var r0=Read.new();var r1=Read.new()
			var a_times=[];var b_times=[]
			var n=0
			while g.phase=="fight" and n<1600:
				g.step();a.observe(g);n+=1
				var first_cache=n%2==0
				var t=Time.get_ticks_usec()
				var first=batch(r0 if first_cache else r1,a,g,first_cache)
				var elapsed=Time.get_ticks_usec()-t
				if first_cache:b_times.append(elapsed)
				else:a_times.append(elapsed)
				t=Time.get_ticks_usec()
				var second=batch(r1 if first_cache else r0,a,g,not first_cache)
				elapsed=Time.get_ticks_usec()-t
				if first_cache:a_times.append(elapsed)
				else:b_times.append(elapsed)
				if first!=second:fails+=1
			report.append({"stage":stage,"wave":wave,"ticks":n,"uncached":baseline.percentiles(a_times),"cached":baseline.percentiles(b_times)})
	print("CACHE_AB ",JSON.stringify({"equal_failures":fails,"rows":report}))
	baseline.free()
	quit(1 if fails else 0)
