extends SceneTree

const Run=preload("res://src/Run.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(why)
func owned(r)->Array:return r.towers+r.reserve
func snapshot(r)->Dictionary:
	return {"gold":r.gold,"phase":r.phase,"stage":r.stage,"wave":r.wave,"hp":r.hp,"rng":r.rng.state,"towers":r.towers.duplicate(true),"reserve":r.reserve.duplicate(true),"cores":r.upgrades.duplicate(true),"leaks":r.run_leaks}
func cash(r)->int:
	var v:int=r.gold
	for t in owned(r):v+=r.tower_sale_value(t.rank)
	for rank in r.upgrades.values():v+=int(rank)*4
	return v
func draw_checked(r)->Dictionary:
	var before:=snapshot(r)
	var value:=cash(r)
	var n:=owned(r).size()
	var outcome:Dictionary=r.draw_loot()
	if outcome.is_empty():
		check(snapshot(r)==before,"failed draw does not mutate gold, RNG, or inventory")
		return outcome
	check(r.gold==before.gold-6 and cash(r)==value-2,"one draw debit 6, liquidation value +4")
	if outcome.kind=="tower":
		check(owned(r).size()==n+1 and r.upgrades==before.cores,"one tower exactly, no relic side effect")
		check(r.reserve.back().id==outcome.id and r.reserve.back().kind==outcome.tower_kind and r.reserve.back().rank==outcome.rank,"receipt matches owned tower")
	elif outcome.kind=="core":
		check(owned(r).size()==n and r.level(outcome.id)==int(before.cores.get(outcome.id,0))+1,"one core rank exactly")
		check(outcome.rank==r.level(outcome.id) and outcome.rank<=Run.MAX_RANK[outcome.id],"receipt matches owned core")
	else:check(false,"unknown outcome category")
	return outcome
func invariant(r)->void:
	check(r.gold>=0 and r.towers.size()<=Run.MAX_TOWERS and owned(r).size()<=Run.MAX_INVENTORY,"valid economy/capacity")
	var ids={}
	var cells={}
	for t in owned(r):
		check(not ids.has(t.id) and t.rank>=1 and t.rank<=3,"unique id and rank")
		ids[t.id]=true
	for t in r.towers:
		check(not r.reserved(t.cell) and not cells.has(t.cell),"legal unique deployed cell")
		cells[t.cell]=true
func score(r,cell:Vector2i,t:Dictionary)->float:
	var s:Array=r.preview_stats(cell,t.kind,t.rank)
	var total=0.0
	var paths=[r.path()]
	if r.stage==1 and r.opened:paths.append(r.path(false))
	for route in paths:
		for i in range(route.size()-1):
			var p:Vector2=route[i]
			while p.distance_to(route[i+1])>0.1:
				if p.distance_to(Vector2(cell))<=float(s[1]):total+=1
				p=p.move_toward(route[i+1],0.5)
	for deployed in r.towers:
		if Vector2(deployed.cell).distance_to(Vector2(cell))<=1.1:total-=0.6
	return total*float(s[0])/float(s[2])
func replan(r)->void:
	for t in r.towers.duplicate():check(r.recall(t.id),"recall deployed tower")
	var remaining:Array=r.reserve.duplicate()
	remaining.sort_custom(func(a,b):return a.rank>b.rank)
	for t in remaining:
		if r.towers.size()>=Run.MAX_TOWERS:break
		var best=-INF
		var cell=Vector2i(-1,-1)
		for y in range(Run.ROWS):
			for x in range(Run.COLS):
				var c=Vector2i(x,y)
				if r.reserved(c) or r.towers.any(func(o):return o.cell==c):continue
				var s:=score(r,c,t)
				if s>best:best=s;cell=c
		check(cell.x>=0 and r.deploy(t.id,cell),"deploy valid candidate")
func merge_pair(r)->bool:
	var a:Array=owned(r)
	for i in range(a.size()):
		for j in range(i+1,a.size()):
			if a[i].kind==a[j].kind and a[i].rank==a[j].rank and a[i].rank<3:
				var v:=cash(r);var g:int=r.gold
				check(r.merge_towers(a[i].id,a[j].id),"legal pair merge succeeds")
				check(cash(r)==v and r.gold==g and owned(r).size()==a.size()-1,"merge preserves value and consumes exactly one")
				return true
	return false
func finish_wave(r)->void:
	var n=0
	while r.phase=="fight" and n<5000:r.step();n+=1
	check(n<5000,"wave terminates")
func run(seed_value:int,risk:bool,merge:bool)->Dictionary:
	var r=Run.new();r.reset(seed_value)
	var results=[]
	for round_no in range(6):
		if r.phase!="build":break
		if r.stage==1 and r.wave==0 and risk:r.alter()
		while r.gold>=6:
			if draw_checked(r).is_empty():break
		if merge:
			while owned(r).size()>4:
				if not merge_pair(r):break
		replan(r); invariant(r)
		check(r.start(),"start with actual random deployed roster")
		var b:=snapshot(r)
		check(r.draw_loot().is_empty() and snapshot(r)==b,"no draw in fight")
		finish_wave(r)
		results.append([r.phase,r.hp,r.gold,r.run_leaks,r.kills])
		if r.phase=="build":
			check(r.gold==b.gold+12+(6 if b.stage==1 and risk and r.wave_leaks==0 else 0),"wave gold exact")
			if r.stage!=b.stage:check(r.towers.is_empty(),"cross-sector recall")
	return {"state":snapshot(r),"results":results}
func check_draws()->void:
	var counts=[0,0]
	var towers=[0,0,0]
	for seed_value in range(2000):
		var r=Run.new();r.reset(seed_value)
		check(not r.has_method("choose") and not r.has_method("draw_tower") and not r.has_method("draw_core"),"no direct choice or typed old draws")
		var first:=draw_checked(r);var second:=draw_checked(r)
		check(first.kind=="tower" and second.kind=="tower","opening guarantees two paid random characters")
		towers[first.tower_kind]+=1
		var third:=draw_checked(r)
		counts[0 if third.kind=="tower" else 1]+=1
		draw_checked(r)
		check(draw_checked(r).is_empty(),"empty wallet rejects atomically")
		invariant(r)
	check(counts[0]>1300 and counts[0]<1500,"mixed result proportions around 70/30")
	for count in towers:check(count>550 and count<800,"opening character distribution uniform")
	print("P04 distribution tower/core=",counts," opening types=",towers)
	var r=Run.new();r.reset(437);r.gold=300
	while owned(r).size()<Run.MAX_INVENTORY:check(not draw_checked(r).is_empty(),"draw until tower cap")
	check(is_equal_approx(float(r.reward_odds().tower),0.0),"full tower inventory excludes tower category")
	while not draw_checked(r).is_empty():pass
	check(r.reward_odds().tower==0.0 and r.reward_odds().core==0.0,"both caps deny draw")
	check(r.sell_core(str(r.upgrades.keys()[0])),"sell relic restores eligible slot")
	check(draw_checked(r).kind=="core","single eligible category draws relic")
func _initialize()->void:
	check_draws()
	var a:=run(437,true,true)
	check(a==run(437,true,true),"same seed and inputs replay exactly")
	var b:=run(438,false,false)
	print("P04 seed437 risk/merge ",a.results," seed438 safe ",b.results)
	print("P04 checks=",checks," failures=",failures)
	quit(1 if failures else 0)
