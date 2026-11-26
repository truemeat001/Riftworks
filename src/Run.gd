extends RefCounted
class_name DefenseRun

signal changed

const COLS=12
const ROWS=8
const TICK=0.05
const NAMES=["Maze relay", "Rift survey", "Resonance field"]
const RULES=["Choose a long winding route, or a shorter concentrated route. Tower positions determine coverage.", "Optional rift adds enemies on a new route without replacing main-lane threats. Survive it for a second upgrade.", "Amplifier tiles boost nearby towers. A separate Relay upgrade rewards tightly grouped towers; the effects stack."]
const TYPES=["Pulse", "Frost", "Burst"]
const COST=[5,6,7]
const MAX_TOWERS=5
const AMP_CELLS=[Vector2i(3,2),Vector2i(5,4),Vector2i(5,6),Vector2i(9,6)]
const BASE_DAMAGE=[8.5,4.5,12.0]
const BASE_RANGE=[3.0,2.7,2.8]
const BASE_COOLDOWN=[0.7,0.85,1.4]
const WAVE_HP=[22.0,32.0,52.0,72.0,108.0,135.0]
const BOSS_HP=850.0
const UPGRADES=[
	{"id":"power","name":"Overcharge","description":"All towers deal 35% more base damage."},
	{"id":"rapid","name":"Rapid cycle","description":"All towers recharge 25% faster."},
	{"id":"range","name":"Long reach","description":"All towers gain one cell of range."},
	{"id":"chain","name":"Chain pulse","description":"Pulse can hit one more nearby enemy per rank."},
	{"id":"freeze","name":"Deep frost","description":"Frost slow lasts longer and becomes stronger."},
	{"id":"blast","name":"Echo burst","description":"Burst gains larger area and more splash damage."},
	{"id":"focus","name":"Execution focus","description":"All towers deal extra damage to enemies below half health."},
	{"id":"relay","name":"Resonant core","description":"Nearby friendly towers boost damage and range, stacking with terrain amplifiers."}
]
const MAX_RANK={"power":3,"rapid":3,"range":2,"chain":3,"freeze":2,"blast":3,"focus":3,"relay":3}

var stage=0
var wave=0
var hp=15
var gold=17
var phase="build"
var route_choice=0
var opened=false
var towers:Array=[]
var enemies:Array=[]
var upgrades:Dictionary={}
var choices:Array=[]
var shots:Array=[]
var tick_count=0
var pending=0
var pending_main=0
var pending_extra=0
var spawn_time=0.0
var kills=0
var wave_leaks=0
var run_leaks=0
var wave_damage=0.0
var boss_defeated=false
var bonus_reward=false
var spawn_count=0
var rng=RandomNumberGenerator.new()
var message="Build a defense, then start the wave."

func reset(seed_value:int=437) -> void:
	rng.seed=seed_value
	stage=0; wave=0; hp=15; gold=17; phase="build"; route_choice=0; opened=false
	towers.clear(); enemies.clear(); upgrades.clear(); choices.clear(); shots.clear()
	tick_count=0; pending=0; pending_main=0; pending_extra=0; spawn_time=0; spawn_count=0
	kills=0; wave_leaks=0; run_leaks=0; wave_damage=0; boss_defeated=false; bonus_reward=false
	message="Build a defense, then start the wave."
	changed.emit()

func maze_path(route_index:int)->Array[Vector2]:
	if route_index==0:
		return [Vector2(0,3),Vector2(4,3),Vector2(4,1),Vector2(8,1),Vector2(8,4),Vector2(11,4)]
	return [Vector2(0,3),Vector2(2,3),Vector2(2,5),Vector2(7,5),Vector2(7,4),Vector2(11,4)]

func path(first:bool=true) -> Array[Vector2]:
	if stage==0:
		return maze_path(route_choice)
	if stage==1:
		if first: return [Vector2(0,1),Vector2(3,1),Vector2(3,4),Vector2(11,4)]
		return [Vector2(0,6),Vector2(6,6),Vector2(6,4),Vector2(11,4)]
	return [Vector2(0,3),Vector2(3,3),Vector2(3,5),Vector2(8,5),Vector2(8,4),Vector2(11,4)]

func path_length(route:Array[Vector2])->float:
	var distance=0.0
	for i in range(route.size()-1):
		distance+=route[i].distance_to(route[i+1])
	return distance

func route_lengths()->Array:
	if stage==0: return [path_length(maze_path(0)),path_length(maze_path(1))]
	if stage==1: return [path_length(path()),path_length(path(false))]
	return [path_length(path())]

func is_path(cell:Vector2i, route:Array[Vector2]) -> bool:
	for i in range(route.size()-1):
		var a=route[i]; var b=route[i+1]
		if cell.x>=min(a.x,b.x) and cell.x<=max(a.x,b.x) and cell.y>=min(a.y,b.y) and cell.y<=max(a.y,b.y): return true
	return false

func reserved(cell:Vector2i) -> bool:
	if stage==0: return is_path(cell,maze_path(0)) or is_path(cell,maze_path(1))
	if stage==1: return is_path(cell,path()) or is_path(cell,path(false))
	return is_path(cell,path()) or cell in AMP_CELLS

func placement_error(cell:Vector2i, kind:int)->String:
	if phase!="build": return "Build during preparation only."
	if kind<0 or kind>=TYPES.size(): return "Select a tower first."
	if cell.x<0 or cell.y<0 or cell.x>=COLS or cell.y>=ROWS: return "Outside the battlefield."
	if reserved(cell): return "Enemy route or amplifier: cannot place here."
	for t in towers:
		if t.cell==cell: return "Cell already occupied."
	if towers.size()>=MAX_TOWERS: return "Tower limit reached (5)."
	if gold<COST[kind]: return "Not enough credits."
	return ""

func placement_reason(cell:Vector2i, kind:int)->String:
	return placement_error(cell,kind)

func place(cell:Vector2i, kind:int) -> bool:
	if not placement_error(cell,kind).is_empty(): return false
	gold-=COST[kind]; towers.append({"cell":cell,"kind":kind,"cool":0.0}); changed.emit(); return true

func sell(cell:Vector2i) -> bool:
	if phase!="build": return false
	for i in range(towers.size()):
		if towers[i].cell==cell:
			gold+=COST[towers[i].kind]; towers.remove_at(i); changed.emit(); return true
	return false

func alter() -> void:
	if phase!="build": return
	if stage==0: route_choice=1-route_choice
	if stage==1: opened=not opened
	changed.emit()

func forecast()->Dictionary:
	var main=8+wave*3+stage*4
	var extra=(5+wave) if stage==1 and opened else 0
	return {"main":main,"extra":extra,"total":main+extra,"boss":stage==2 and wave==1,"hp":WAVE_HP[stage*2+wave],"boss_hp":BOSS_HP}

func start() -> bool:
	if phase!="build" or towers.is_empty(): return false
	var next=forecast()
	phase="fight"; pending=next.total; pending_main=next.main; pending_extra=next.extra
	spawn_time=0; spawn_count=0; kills=0; wave_leaks=0; wave_damage=0; bonus_reward=stage==1 and opened
	# Equal cooldown on every new wave means timing is a function of this wave's decisions.
	for t in towers: t.cool=0.0
	shots.clear()
	message="Defend the core!"; changed.emit(); return true

func level(id:String) -> int: return upgrades.get(id,0)

func preview_stats(cell:Vector2i, kind:int)->Array:
	var damage:float=BASE_DAMAGE[kind]*(1+0.35*level("power"))
	var radius:float=BASE_RANGE[kind]+level("range")
	var cd:float=BASE_COOLDOWN[kind]*pow(0.75,level("rapid"))
	var amp=false
	var relay=false
	if stage==2:
		for a in AMP_CELLS:
			if Vector2(cell).distance_to(Vector2(a))<=1.5: amp=true
	if level("relay")>0:
		for other in towers:
			if other.cell!=cell and Vector2(cell).distance_to(Vector2(other.cell))<=2.1:
				relay=true
				break
	if amp:
		damage*=1.35; radius+=0.5
	if relay:
		damage*=1+0.25*level("relay"); radius+=0.25*level("relay")
	return [damage,radius,cd,amp or relay,amp,relay]

func stats(t:Dictionary) -> Array:
	return preview_stats(t.cell,t.kind)

func spawn() -> void:
	# The bonus lane adds extra enemies, rather than replacing normal attackers.
	var second= pending_extra>0 and (pending_main<=0 or spawn_count%3==2)
	var route=path(not second)
	var boss=stage==2 and wave==1 and pending_main==1
	var health:float=BOSS_HP if boss else WAVE_HP[stage*2+wave]
	var speed=0.95+stage*0.12+float(spawn_count%3)*0.12
	if boss: speed=1.1
	enemies.append({"route":route,"pos":route[0],"segment":0,"hp":health,"maxhp":health,"slow":0.0,"boss":boss,"speed":speed,"second":second})
	if second: pending_extra-=1
	else: pending_main-=1
	spawn_count+=1

func remaining_distance(e:Dictionary)->float:
	var seg:int=e.segment
	var route:Array=e.route
	if seg>=route.size()-1: return 0.0
	var d:float=e.pos.distance_to(route[seg+1])
	for i in range(seg+1,route.size()-1): d+=route[i].distance_to(route[i+1])
	return d

func damage_enemy(e:Dictionary, amount:float)->void:
	wave_damage+=minf(amount,maxf(0.0,e.hp))
	e.hp-=amount

func draw_reward(count:int)->void:
	choices.clear()
	var pool:Array=[]
	for upgrade in UPGRADES:
		if level(upgrade.id)<MAX_RANK[upgrade.id]: pool.append(upgrade)
	for i in range(mini(count,pool.size())):
		var idx=rng.randi_range(0,pool.size()-1); choices.append(pool.pop_at(idx))

func step() -> void:
	if phase!="fight":return
	tick_count+=1
	spawn_time-=TICK
	if pending>0 and spawn_time<=0:
		spawn(); pending-=1; spawn_time=0.48
	for e in enemies:
		if e.hp<=0: continue
		var slow_factor=maxf(0.2,0.55-0.15*level("freeze"))
		# Boss has reduced crowd-control vulnerability, and thus must be damaged.
		if e.boss: slow_factor=lerpf(1.0,slow_factor,0.35)
		var remaining:float=e.speed*TICK*(slow_factor if e.slow>0 else 1.0)
		e.slow=maxf(0,e.slow-TICK)
		while remaining>0 and e.segment<e.route.size()-1:
			var target:Vector2=e.route[e.segment+1]
			var dist:float=e.pos.distance_to(target)
			if dist<=remaining:
				e.pos=target; e.segment+=1; remaining-=dist
			else:
				e.pos=e.pos.move_toward(target,remaining); remaining=0
		if e.segment==e.route.size()-1:
			e.hp=0; e.escaped=true
			wave_leaks+=1; run_leaks+=1
			if e.boss:
				# The expedition objective requires defeating the boss, not merely preserving HP.
				phase="lost"; message="The rift guardian escaped. The expedition failed."; changed.emit(); return
			hp-=1
	for t in towers:
		t.cool-=TICK
		if t.cool>0: continue
		var st=stats(t); var target:Dictionary={}; var best=INF
		for e in enemies:
			if e.hp>0 and Vector2(t.cell).distance_to(e.pos)<=st[1]:
				var distance=remaining_distance(e)
				if distance<best: best=distance; target=e
		if target.is_empty():continue
		t.cool=st[2]
		damage_enemy(target,st[0]*(1.0+0.3*level("focus") if target.hp<target.maxhp*0.5 else 1.0))
		shots.append({"from":Vector2(t.cell),"to":target.pos,"kind":t.kind,"life":0.16})
		if t.kind==1:
			target.slow=0.8+level("freeze")*0.6
		if t.kind==2 or (t.kind==0 and level("chain")>0):
			var r:float=1.0+0.4*level("blast") if t.kind==2 else 1.5
			var chain_hits=0
			for e in enemies:
				if e!=target and e.hp>0 and e.pos.distance_to(target.pos)<=r:
					damage_enemy(e,st[0]*(0.55+0.15*level("blast") if t.kind==2 else 0.65))
					shots.append({"from":target.pos,"to":e.pos,"kind":t.kind,"life":0.12})
					chain_hits+=1
					if t.kind==0 and chain_hits>=level("chain"): break
	for i in range(enemies.size()-1,-1,-1):
		if enemies[i].hp<=0:
			if not enemies[i].get("escaped",false):
				kills+=1; gold+=1
				if enemies[i].boss: boss_defeated=true
			enemies.remove_at(i)
	for i in range(shots.size()-1,-1,-1):
		shots[i].life-=TICK
		if shots[i].life<=0: shots.remove_at(i)
	if hp<=0:
		phase="lost"; message="Core lost. Try a different build."; changed.emit()
	elif pending==0 and enemies.is_empty():
		gold=min(gold+4,35)
		if stage==2 and wave==1:
			phase="won" if boss_defeated else "lost"
			message="Expedition complete!" if boss_defeated else "The rift guardian escaped."
			changed.emit(); return
		phase="reward"; draw_reward(4 if bonus_reward else 3)
		message="Choose a permanent run upgrade."; changed.emit()

func choose(i:int) -> bool:
	if phase!="reward" or i<0 or i>=choices.size():return false
	var id=choices[i].id; upgrades[id]=level(id)+1; choices.clear()
	if bonus_reward:
		bonus_reward=false; draw_reward(3)
		message="Rift bonus! Choose a second permanent upgrade."; changed.emit(); return true
	if wave==1:
		stage+=1; wave=0; route_choice=0; opened=false
		# Rebuild freely on new terrain, but retain all run upgrades and refund tower value.
		for t in towers: gold+=COST[t.kind]
		towers.clear()
		gold=mini(gold,35)
	else: wave+=1
	phase="build"; message="Plan the next wave. Your run upgrades persist."; changed.emit(); return true
