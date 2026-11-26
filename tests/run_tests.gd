extends SceneTree

const Run = preload("res://src/Run.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, desc: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(desc)

func finish_wave(r) -> void:
	var n := 0
	while r.phase == "fight" and n < 4000:
		r.step()
		n += 1
	check(n < 4000, "wave ends within fixed-step bound")

func route_length(route: Array) -> float:
	var total := 0.0
	for i in range(route.size() - 1):
		total += route[i].distance_to(route[i + 1])
	return total

func check_placement() -> void:
	var r = Run.new()
	r.reset(437)
	var initial: int = r.gold
	check(not r.start(), "requires at least one tower")
	check(not r.place(Vector2i(-1, 0), 0) and not r.place(Vector2i(Run.COLS, 0), 0), "bounds enforced")
	check(not r.place(Vector2i(0, 3), 0), "route blocked")
	check(not r.placement_error(Vector2i(0, 3), 0).is_empty(), "placement denial is explained")
	check(not r.place(Vector2i(5, 3), -1) and not r.place(Vector2i(5, 3), 3), "invalid tower index denied")
	check(r.gold == initial, "invalid placement preserves funds")
	check(r.place(Vector2i(5, 3), 0), "valid placement")
	check(r.gold == initial - Run.COST[0], "exact cost deducted")
	check(not r.place(Vector2i(5, 3), 1), "no stacking")
	check(not r.placement_error(Vector2i(5, 3), 1).is_empty(), "occupied denial explained")
	check(r.sell(Vector2i(5, 3)) and r.gold == initial, "full refund")
	check(not r.sell(Vector2i(5, 3)), "no double refund")
	r.gold = 200 # isolated cap fixture, not a normal run
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			if r.towers.size() < Run.MAX_TOWERS:
				r.place(Vector2i(x, y), 0)
	check(r.towers.size() == Run.MAX_TOWERS, "exactly MAX_TOWERS placements")
	var empty := Vector2i(-1,-1)
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			var c := Vector2i(x,y)
			if not r.reserved(c) and not r.towers.any(func(t):return t.cell==c):
				empty = c
	check(empty.x >= 0 and not r.place(empty, 0), "legal empty cell denied when full")
	check(not r.placement_error(empty, 0).is_empty(), "cap denial explained")
	check(r.start(), "wave starts with towers")
	check(not r.sell(r.towers[0].cell) and not r.place(empty, 0), "no build edits during battle")

func check_routes() -> void:
	var r = Run.new()
	r.reset(437)
	var a: Array = r.path()
	r.alter()
	var b: Array = r.path()
	check(r.route_choice == 1 and a != b, "route toggles")
	check(absf(route_length(a) - route_length(b)) > 0.1, "routes have meaningful length difference")
	check(a[0] == b[0] and a[-1] == b[-1], "routes share the same entry/core")
	for route in [a,b]:
		for i in range(route.size()-1):
			check(route[i].x == route[i+1].x or route[i].y == route[i+1].y, "orthogonal route segments")
		for p in route:
			check(p.x >= 0 and p.x < Run.COLS and p.y >= 0 and p.y < Run.ROWS, "route endpoints in board")
	check(r.reserved(Vector2i(a[0])) and r.reserved(Vector2i(b[0])), "route endpoints remain reserved")

func observe_spawns(opened: bool, wave: int) -> Dictionary:
	var r = Run.new()
	r.reset(437)
	r.stage = 1
	r.wave = wave
	r.opened = opened
	var estimate: Dictionary = r.forecast()
	var placed := false
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			if not placed:
				placed = r.place(Vector2i(x,y), 0)
	check(placed and r.start(), "risk fixture can start")
	r.towers.clear() # isolated spawn probe, prevents damage removing a freshly spawned enemy
	var main := 0
	var extra := 0
	var loops := 0
	while r.pending > 0 and r.phase == "fight" and loops < 4000:
		var previous: int = r.pending
		r.step()
		if r.pending < previous:
			check(previous - r.pending == 1, "one spawn per step")
			var e: Dictionary = r.enemies.back()
			if e.route[0] == r.path()[0]:
				main += 1
			elif e.route[0] == r.path(false)[0]:
				extra += 1
			else:
				check(false, "spawn lane is recognized")
		loops += 1
	check(r.pending == 0 and loops < 4000, "all forecast enemies spawn")
	check(main == int(estimate.main) and extra == int(estimate.extra) and main + extra == int(estimate.total), "actual lane counts equal forecast")
	return {"main":main,"extra":extra}

func check_risk() -> void:
	for wave in range(2):
		var a := observe_spawns(false, wave)
		var b := observe_spawns(true, wave)
		check(a.main == b.main and a.extra == 0 and b.extra > 0, "open rift adds enemies without replacing main-stream enemies")

func check_amplifier() -> void:
	var r = Run.new()
	r.reset(437)
	r.stage = 2
	var amp_cell := Vector2i(-1,-1)
	var normal_cell := Vector2i(-1,-1)
	var relay_neighbor := Vector2i(-1,-1)
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			var c := Vector2i(x,y)
			if r.reserved(c):
				continue
			var s: Array = r.preview_stats(c, 0)
			if bool(s[4]) and amp_cell.x < 0:
				amp_cell = c
			elif not bool(s[4]):
				normal_cell = c
	check(amp_cell.x >= 0 and normal_cell.x >= 0, "map has both amplified and normal cells")
	if amp_cell.x < 0 or normal_cell.x < 0:
		return
	var normal: Array = r.preview_stats(normal_cell,0)
	var amp_only: Array = r.preview_stats(amp_cell,0)
	check(bool(amp_only[4]) and not bool(amp_only[5]), "amp-only preview accurately tagged")
	check(float(amp_only[0]) > float(normal[0]) or float(amp_only[1]) > float(normal[1]), "amplifier mechanical benefit")
	check(r.place(amp_cell,0), "place on valid amp-adjacent cell")
	var tower: Dictionary = r.towers[0]
	check(r.stats(tower) == amp_only, "preview equals actual tower stats")
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			var c := Vector2i(x,y)
			if c != amp_cell and not r.reserved(c) and Vector2(c).distance_to(Vector2(amp_cell)) <= 2.0:
				relay_neighbor = c
	check(relay_neighbor.x >= 0 and r.place(relay_neighbor,0), "place relay neighbor")
	r.upgrades["relay"] = 1 # isolate upgrade modifier
	var both: Array = r.stats(tower)
	check(bool(both[4]) and bool(both[5]), "amp and relay flags separately active")
	check(float(both[0]) > float(amp_only[0]) or float(both[1]) > float(amp_only[1]) or float(both[2]) < float(amp_only[2]), "relay stacks distinct improvement atop amplifier")

func placement_score(r, cell: Vector2i, kind: int) -> float:
	var stats: Array = r.preview_stats(cell,kind)
	# Sample along the actual selected routes. Multiply by effective range/damage,
	# spread the towers slightly to avoid overlapping every shot.
	var score := 0.0
	var routes: Array = [r.path()]
	if r.stage == 1 and r.opened:
		routes.append(r.path(false))
	for route in routes:
		for j in range(route.size()-1):
			var pos: Vector2 = route[j]
			while pos.distance_to(route[j+1]) > 0.1:
				if pos.distance_to(Vector2(cell)) <= float(stats[1]):
					score += 1.0
				pos = pos.move_toward(route[j+1],0.5)
	for t in r.towers:
		if Vector2(t.cell).distance_to(Vector2(cell)) <= 1.1:
			score -= 0.6
	return score * float(stats[0]) / float(stats[2])

func deploy(r, kinds: Array) -> Array:
	var placed: Array = []
	var n := 0
	while r.towers.size() < Run.MAX_TOWERS and n < Run.MAX_TOWERS:
		var kind: int = kinds[r.towers.size() % kinds.size()]
		if r.gold < Run.COST[kind]:
			if r.gold < Run.COST[0]:
				break
			kind = 0
		var best := -INF
		var best_cell := Vector2i(-1,-1)
		for y in range(Run.ROWS):
			for x in range(Run.COLS):
				var c := Vector2i(x,y)
				if not r.placement_error(c,kind).is_empty():
					continue
				var score := placement_score(r,c,kind)
				if score > best:
					best = score
					best_cell = c
		if best_cell.x < 0 or not r.place(best_cell,kind):
			break
		placed.append([best_cell,kind])
		n += 1
	return placed

func pick_reward(r, preferences: Array) -> String:
	var index := 0
	for id in preferences:
		var found := -1
		for j in range(r.choices.size()):
			if r.choices[j].id == id:
				found = j
				break
		if found >= 0:
			index = found
			break
	var chosen: String = r.choices[index].id
	check(r.choose(index),"legitimate upgrade selected")
	return chosen

# All choices go through public choose(). The erased-upgrade baseline is a
# counterfactual fixture; it is not a game mode or a claimed player strategy.
func simulate(seed_value: int, kinds: Array, preferences: Array, risk: bool, erase: bool=false, fixed_layouts: Array=[]) -> Dictionary:
	var r = Run.new()
	r.reset(seed_value)
	var reward_ids: Array = []
	var layouts: Array = []
	var wave_results: Array = []
	var round_no := 0
	while r.phase == "build" and round_no < 6:
		if r.stage == 0 and r.wave == 0:
			r.alter()
		if r.stage == 1 and r.wave == 0 and risk:
			r.alter()
		var planned: Array = []
		if fixed_layouts.is_empty():
			planned = deploy(r,kinds)
		else:
			for p in fixed_layouts[round_no]:
				if not r.place(p[0],p[1]):
					check(false,"counterfactual couldn't afford identical placement")
				else:
					planned.append(p)
		layouts.append(planned)
		var stage_before: int = r.stage
		var wave_before: int = r.wave
		var upgrades_before: Dictionary = r.upgrades.duplicate()
		check(r.start(), "scripted run enters combat")
		finish_wave(r)
		wave_results.append({"stage":stage_before,"wave":wave_before,"hp":r.hp,"kills":r.kills,"phase":r.phase,"leaks":r.run_leaks,"damage":r.wave_damage,"boss_defeated":r.boss_defeated})
		var picks := 0
		while r.phase == "reward" and picks < 3:
			check(not r.choices.is_empty(), "nonempty reward offers")
			if r.choices.is_empty(): break
			if picks == 0 and stage_before == 1 and risk:
				check(r.choices.size() == 4, "rift first reward gives four choices")
			else:
				check(r.choices.size() == 3, "standard or bonus reward gives three choices")
			var id := pick_reward(r,preferences)
			reward_ids.append(id)
			picks += 1
			if not erase:
				check(r.level(id) >= 1, "chosen upgrade applied")
				check(r.level(id) <= Run.MAX_RANK[id], "chosen upgrade rank respects cap")
		check(r.phase != "reward", "reward flow completes")
		if stage_before == 1 and risk and wave_before <= 1 and r.phase == "build":
			check(picks == 2,"extra rift produces two reward picks")
		elif stage_before < 2 and r.phase == "build":
			check(picks == 1,"standard wave produces one reward pick")
		if not erase:
			for id in upgrades_before:
				check(r.level(id) >= upgrades_before[id], "upgrades survive across waves/stages")
		else:
			r.upgrades.clear()
		if r.stage != stage_before:
			check(r.towers.is_empty(), "stage change rebuilds the board")
		round_no += 1
	return {"phase":r.phase,"hp":r.hp,"gold":r.gold,"leaks":r.run_leaks,"boss_defeated":r.boss_defeated,"upgrades":r.upgrades,"rewards":reward_ids,"layouts":layouts,"waves":wave_results}

func check_loss_restart() -> void:
	var r = Run.new()
	r.reset(437)
	var initial_hp: int = r.hp
	r.hp=1
	check(r.place(Vector2i(0,7),0) and r.start(),"loss fixture begins")
	finish_wave(r)
	check(r.phase == "lost", "a bad defense produces terminal loss")
	r.reset(437)
	check(r.phase == "build" and r.stage == 0 and r.wave == 0 and r.hp == initial_hp and r.towers.is_empty() and r.upgrades.is_empty(),"restart cleanly resets run state")

func check_boss_escape() -> void:
	var r = Run.new()
	r.reset(437)
	r.stage = 2
	r.wave = 1
	check(r.forecast().boss, "final wave forecast includes boss")
	check(r.place(Vector2i(0,7),0) and r.start(),"boss fixture begins")
	r.towers.clear()
	r.hp = 100 # isolated fixture: boss escape must fail even if normal leaks are survivable.
	finish_wave(r)
	check(r.phase == "lost" and not r.boss_defeated and r.hp > 0, "boss escape causes terminal loss regardless of remaining HP")

func _initialize() -> void:
	check_placement()
	check_routes()
	check_risk()
	check_amplifier()
	check_loss_restart()
	check_boss_escape()
	# Scripted strategy fixtures; these will be confirmed against the frozen balance.
	var pulse_pref := ["chain","power","rapid","relay","range","focus","freeze","blast"]
	var burst_pref := ["blast","power","rapid","relay","range","focus","freeze","chain"]
	var a := simulate(437,[0,0,1],pulse_pref,true)
	var replay := simulate(437,[0,0,1],pulse_pref,true)
	check(a == replay,"same seed plus same actions replays full outcome")
	var b := simulate(437,[2,1,2],burst_pref,false)
	print("RIFTWORKS pulse: ",a.phase," hp=",a.hp," leaks=",a.leaks," rewards=",a.rewards," waves=",a.waves)
	print("RIFTWORKS burst: ",b.phase," hp=",b.hp," leaks=",b.leaks," rewards=",b.rewards," waves=",b.waves)
	check(a.phase=="won" and a.boss_defeated,"coherent pulse/frost build wins")
	check(b.phase=="won" and b.boss_defeated,"coherent burst/frost build wins")
	var none := simulate(437,[0,0,1],pulse_pref,true,true,a.layouts)
	print("RIFTWORKS no-upgrade (same layout): ",none.phase," hp=",none.hp," leaks=",none.leaks," waves=",none.waves)
	check(none.phase!="won" or none.hp<=a.hp-5 or none.leaks>=a.leaks+5,"removing upgrades materially worsens same-layout run")
	var none_burst := simulate(437,[2,1,2],burst_pref,false,true,b.layouts)
	print("RIFTWORKS burst no-upgrade: ",none_burst.phase," hp=",none_burst.hp," leaks=",none_burst.leaks," waves=",none_burst.waves)
	check(none_burst.phase!="won" or none_burst.hp<=b.hp-5 or none_burst.leaks>=b.leaks+5,"removing upgrades materially worsens same-layout burst run")
	print("RIFTWORKS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
