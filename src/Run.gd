extends RefCounted
class_name DefenseRun

signal changed

const COLS=12
const ROWS=8
const TICK=0.05
const NAMES=["Tidecross Ferry", "Twin-Tide Bay", "Echo Reef"]
const RULES=["Choose a long winding route, or a shorter concentrated route. Tower positions determine coverage.", "Optional rift adds twice-health enemies on a new route without replacing main-lane threats. Survive without leaks for six bonus credits.", "Amplifier tiles boost nearby towers. A separate Relay upgrade rewards tightly grouped towers; the effects stack."]
const TYPES=["Brass Skirmisher", "Mist Weaver", "Reef Hammer"]
const DRAW_COST=6
const CHARACTER_WEIGHT=0.7
const RELIC_WEIGHT=0.3
const FIRST_CHARACTER_GUARD=2
const COST=[6,6,6]
const MAX_INVENTORY=9
const RANK_DAMAGE=[1.0,2.15,4.6]
const RANK_RANGE=[0.0,0.2,0.4]
const MAX_TOWERS=5
const AMP_CELLS=[Vector2i(3,2),Vector2i(5,4),Vector2i(5,6),Vector2i(9,6)]
const BASE_DAMAGE=[8.5,6.5,12.0]
const BASE_RANGE=[3.0,2.7,2.8]
const BASE_COOLDOWN=[0.7,0.85,1.4]
const WAVE_HP=[22.0,38.0,66.0,96.0,180.0,215.0]
const ROLE_HP={"normal":1.0,"runner":0.6,"guard":1.6}
const ROLE_SPEED={"normal":1.0,"runner":1.5,"guard":0.75}
const ROLE_NAMES={"normal":"Rift Hermit","runner":"Sailbeast","guard":"Shellguard","boss":"Abyss Lord"}
const BOSS_HP=1275.0
const RIFT_HP_MULTIPLIER=2.0
const CONDUCTIVE_DAMAGE=1.20
const SHATTER_RADIUS=0.35
const SHATTER_SPLASH=1.10
const UPGRADES=[
	{"id":"power","name":"Overcharge","description":"All towers deal 35% more base damage."},
	{"id":"rapid","name":"Rapid cycle","description":"All towers recharge 25% faster."},
	{"id":"range","name":"Long reach","description":"All towers gain one cell of range."},
	{"id":"chain","name":"Chain pulse","description":"All damage +5%/rank. Brass Skirmisher hits another nearby target."},
	{"id":"freeze","name":"Deep frost","description":"All damage +3%/rank. Mist Weaver slow grows stronger and longer."},
	{"id":"blast","name":"Echo burst","description":"All damage +5%/rank. Reef Hammer gains larger splash and damage."},
	{"id":"focus","name":"Execution focus","description":"All towers deal extra damage to enemies below half health."},
	{"id":"relay","name":"Resonant core","description":"Nearby friendly towers boost damage and range, stacking with terrain amplifiers."}
]
const MAX_RANK={"power":3,"rapid":3,"range":2,"chain":3,"freeze":2,"blast":3,"focus":3,"relay":3}

var stage=0
var wave=0
var hp=15
var gold=24
var phase="build"
var route_choice=0
var opened=false
var towers:Array=[]
var reserve:Array=[]
var next_tower_id=1
var enemies:Array=[]
var upgrades:Dictionary={}
var shots:Array=[]
var deaths:Array=[]
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
var spawn_count=0
var rng=RandomNumberGenerator.new()
var message="Build a defense, then start the wave."
var last_loot:Dictionary={}

func reset(seed_value:int=437) -> void:
	rng.seed=seed_value
	stage=0; wave=0; hp=15; gold=24; phase="build"; route_choice=0; opened=false
	towers.clear(); reserve.clear(); next_tower_id=1; enemies.clear(); upgrades.clear(); shots.clear(); deaths.clear()
	tick_count=0; pending=0; pending_main=0; pending_extra=0; spawn_time=0; spawn_count=0
	kills=0; wave_leaks=0; run_leaks=0; wave_damage=0; boss_defeated=false
	message="Build a defense, then start the wave."
	last_loot.clear()
	changed.emit()

func maze_path(route_index:int)->Array[Vector2]:
	if route_index==0:
		return [Vector2(0,3),Vector2(4,3),Vector2(4,1),Vector2(8,1),Vector2(8,4),Vector2(11,4)]
	return [Vector2(0,3),Vector2(2,3),Vector2(2,5),Vector2(7,5),Vector2(7,4),Vector2(11,4)]

func path(first:bool=true) -> Array[Vector2]:
	if stage==0:
		return maze_path(route_choice)
	if stage==1:
		if first: return [Vector2(0,1),Vector2(8,1),Vector2(8,2),Vector2(11,2),Vector2(11,4)]
		return [Vector2(0,6),Vector2(8,6),Vector2(8,5),Vector2(11,5),Vector2(11,4)]
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

func placement_error(cell:Vector2i, kind:int, ignore_id:int=-1)->String:
	if phase!="build": return "Build during preparation only."
	if kind<0 or kind>=TYPES.size(): return "Select a tower first."
	if cell.x<0 or cell.y<0 or cell.x>=COLS or cell.y>=ROWS: return "Outside the battlefield."
	if reserved(cell): return "Enemy route or amplifier: cannot place here."
	for t in towers:
		if t.cell==cell and t.id!=ignore_id: return "Cell already occupied."
	if towers.size()>=MAX_TOWERS and not _has_id(towers,ignore_id): return "Tower limit reached (5)."
	return ""

func placement_reason(cell:Vector2i, kind:int)->String:
	return placement_error(cell,kind)

func _has_id(list:Array, id:int)->bool:
	for t in list:
		if t.id==id: return true
	return false

func _find_tower(id:int)->Dictionary:
	for t in towers+reserve:
		if t.id==id: return t
	return {}

func tower_sale_value(rank:int)->int:
	return 4*(1 << (rank-1))

func _reject(reason:String)->bool:
	message=reason; changed.emit(); return false

# Eligibility is explicit, not a post-draw reroll. A draw always awards one result.
func reward_odds()->Dictionary:
	var result={"tower":0.0,"core":0.0,"tower_types":[],"core_ids":[]}
	if phase!="build" or gold<DRAW_COST: return result
	var owned=towers.size()+reserve.size()
	var tower_eligible=owned<MAX_INVENTORY
	var core_pool:Array=[]
	for u in UPGRADES:
		if level(u.id)<MAX_RANK[u.id]: core_pool.append(u.id)
	var core_eligible=not core_pool.is_empty() and owned>=FIRST_CHARACTER_GUARD
	if tower_eligible and core_eligible:
		result.tower=CHARACTER_WEIGHT; result.core=RELIC_WEIGHT
	elif tower_eligible:
		result.tower=1.0
	elif core_eligible:
		result.core=1.0
	if result.tower>0.0: result.tower_types=range(TYPES.size())
	if result.core>0.0: result.core_ids=core_pool
	return result

func draw_loot()->Dictionary:
	if phase!="build": return {}
	if gold<DRAW_COST:
		_reject("Draw needs 6 credits.")
		return {}
	var odds=reward_odds()
	if odds.tower<=0.0 and odds.core<=0.0:
		_reject("Inventory is full and all relic ranks are maxed.")
		return {}
	# If only one category is eligible, do not consume an unnecessary category roll.
	var tower_result=odds.tower>0.0 and (odds.core<=0.0 or rng.randi_range(0,9)<7)
	var loot:Dictionary={}
	gold-=DRAW_COST
	if tower_result:
		var kind:int=odds.tower_types[rng.randi_range(0,odds.tower_types.size()-1)]
		reserve.append({"id":next_tower_id,"kind":kind,"rank":1,"cell":Vector2i(-1,-1),"cool":0.0,"attack_tick":-1})
		loot={"kind":"tower","id":next_tower_id,"tower_kind":kind,"rank":1,"name":TYPES[kind]}
		next_tower_id+=1
		message="Recruited %s." % TYPES[kind]
	else:
		var core_id:String=odds.core_ids[rng.randi_range(0,odds.core_ids.size()-1)]
		upgrades[core_id]=level(core_id)+1
		var core_name=core_id
		for u in UPGRADES:
			if u.id==core_id:
				core_name=u.name
				break
		loot={"kind":"core","id":core_id,"rank":level(core_id),"name":core_name}
		message="Drew relic %s, rank %d." % [core_name,level(core_id)]
	last_loot=loot.duplicate()
	changed.emit()
	return loot

func deploy(id:int,cell:Vector2i)->bool:
	var t=_find_tower(id)
	if t.is_empty() or not placement_error(cell,t.kind,id).is_empty(): return false
	if not _has_id(towers,id):
		reserve.erase(t); towers.append(t)
	t.cell=cell; t.cool=0.0
	message="Deployed %s." % TYPES[t.kind]
	changed.emit(); return true

func recall(id:int)->bool:
	if phase!="build" or not _has_id(towers,id): return false
	var t=_find_tower(id)
	towers.erase(t); t.cell=Vector2i(-1,-1); t.cool=0.0; reserve.append(t)
	message="Tower returned to reserve."
	changed.emit(); return true

func sell_tower(id:int)->bool:
	if phase!="build": return false
	var t=_find_tower(id)
	if t.is_empty(): return false
	if towers.size()+reserve.size()==1 and gold+tower_sale_value(t.rank)<DRAW_COST: return _reject("Keep your last tower until you can afford a replacement.")
	gold+=tower_sale_value(t.rank); towers.erase(t); reserve.erase(t)
	message="Sold tower."
	changed.emit(); return true

func merge_towers(id_a:int,id_b:int)->bool:
	if phase!="build" or id_a==id_b: return false
	var a=_find_tower(id_a); var b=_find_tower(id_b)
	if a.is_empty() or b.is_empty() or a.kind!=b.kind or a.rank!=b.rank or a.rank>=3: return false
	var a_deployed=_has_id(towers,id_a)
	var b_deployed=_has_id(towers,id_b)
	var dest=b.cell
	towers.erase(b); reserve.erase(b)
	if not a_deployed and b_deployed:
		reserve.erase(a); towers.append(a); a.cell=dest
	a.rank+=1; a.cool=0.0
	message="Merged %s to rank %d." % [TYPES[a.kind],a.rank]
	changed.emit(); return true

func sell_core(id:String)->bool:
	if phase!="build" or level(id)<=0: return false
	var rank=level(id)-1
	if rank==0: upgrades.erase(id)
	else: upgrades[id]=rank
	gold+=4
	message="Sold one core rank."
	changed.emit(); return true

func alter() -> void:
	if phase!="build": return
	if stage==0: route_choice=1-route_choice
	if stage==1: opened=not opened
	changed.emit()

func _role_for_main(index:int, count:int)->String:
	if stage==2 and wave==1 and index==count-1: return "boss"
	if stage==0 and wave==0: return "normal"
	if stage>=1 and index%5==3: return "guard"
	if index%4==1: return "runner"
	return "normal"

func forecast()->Dictionary:
	var main=8+wave*3+stage*4
	var extra=(5+wave) if stage==1 and opened else 0
	var counts={"normal":0,"runner":0,"guard":0,"boss":0}
	for i in range(main):
		var role=_role_for_main(i,main)
		counts[role]+=1
	var role_hp={"normal":WAVE_HP[stage*2+wave], "runner":WAVE_HP[stage*2+wave]*ROLE_HP.runner,"guard":WAVE_HP[stage*2+wave]*ROLE_HP.guard,"boss":BOSS_HP}
	return {"main":main,"extra":extra,"total":main+extra,"boss":stage==2 and wave==1,"hp":WAVE_HP[stage*2+wave],"boss_hp":BOSS_HP,"extra_hp":WAVE_HP[stage*2+wave]*RIFT_HP_MULTIPLIER,"roles":counts,"role_hp":role_hp}

func start() -> bool:
	if phase!="build" or towers.is_empty(): return false
	var next=forecast()
	phase="fight"; pending=next.total; pending_main=next.main; pending_extra=next.extra
	spawn_time=0; spawn_count=0; kills=0; wave_leaks=0; wave_damage=0
	# Equal cooldown on every new wave means timing is a function of this wave's decisions.
	for t in towers: t.cool=0.0
	shots.clear(); deaths.clear()
	message="Defend the core!"; changed.emit(); return true

func level(id:String) -> int: return upgrades.get(id,0)

func preview_stats(cell:Vector2i, kind:int, rank:int=1, ignore_id:int=-1)->Array:
	var damage:float=BASE_DAMAGE[kind]*RANK_DAMAGE[rank-1]*(1+0.35*level("power")+0.05*level("chain")+0.03*level("freeze")+0.05*level("blast"))
	var radius:float=BASE_RANGE[kind]+level("range")+RANK_RANGE[rank-1]
	var cd:float=BASE_COOLDOWN[kind]*pow(0.75,level("rapid"))
	var amp=false
	var relay=false
	if stage==2:
		for a in AMP_CELLS:
			if Vector2(cell).distance_to(Vector2(a))<=1.5: amp=true
	if level("relay")>0:
		for other in towers:
			if other.id!=ignore_id and other.cell!=cell and Vector2(cell).distance_to(Vector2(other.cell))<=2.1:
				relay=true
				break
	if amp:
		damage*=1.35; radius+=0.5
	if relay:
		damage*=1+0.25*level("relay"); radius+=0.25*level("relay")
	return [damage,radius,cd,amp or relay,amp,relay]

func stats(t:Dictionary) -> Array:
	return preview_stats(t.cell,t.kind,t.rank,t.id)

func spawn() -> void:
	# Rift enemies supplement the deterministic main role sequence; opening it never changes main roles or speed.
	var second= pending_extra>0 and (pending_main<=0 or spawn_count%3==2)
	var route=path(not second)
	var main_count=8+wave*3+stage*4
	var main_index=main_count-pending_main
	var role="normal" if second else _role_for_main(main_index,main_count)
	var boss=role=="boss"
	var health:float=BOSS_HP if boss else WAVE_HP[stage*2+wave]*ROLE_HP[role]
	if second: health*=RIFT_HP_MULTIPLIER
	var index=(5+wave)-pending_extra if second else main_index
	var speed=(0.95+stage*0.12+float(index%3)*0.12)*ROLE_SPEED.get(role,1.0)
	if boss: speed=1.1
	enemies.append({"route":route,"pos":route[0],"direction":(route[1]-route[0]).normalized(),"segment":0,"id":spawn_count,"hit_tick":-1,"hp":health,"maxhp":health,"slow":0.0,"role":role,"boss":boss,"speed":speed,"second":second})
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
	e.hit_tick=tick_count

func step() -> void:
	if phase!="fight":return
	tick_count+=1
	while not deaths.is_empty() and tick_count-int(deaths[0].tick)>10: deaths.pop_front()
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
			e.direction=(target-e.pos).normalized()
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
			hp=maxi(0,hp-1)
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
		t.attack_tick=tick_count
		var marked:bool=target.slow>0.0
		var bonus:float=CONDUCTIVE_DAMAGE if t.kind==0 and marked else 1.0
		var synergy:String="conductive" if t.kind==0 and marked else ("shatter" if t.kind==2 and marked else "")
		damage_enemy(target,st[0]*bonus*(1.0+0.3*level("focus") if target.hp<target.maxhp*0.5 else 1.0))
		shots.append({"from":Vector2(t.cell),"to":target.pos,"kind":t.kind,"tower_id":t.id,"synergy":synergy,"life":0.16})
		if t.kind==1:
			target.slow=0.8+level("freeze")*0.6+0.25*(t.rank-1)
		var chain_limit=level("chain")+(1 if t.rank==3 else 0)
		if t.kind==2 or (t.kind==0 and chain_limit>0):
			var r:float=1.0+0.4*level("blast")+0.2*(t.rank-1)+(SHATTER_RADIUS if marked else 0.0) if t.kind==2 else 1.5
			var chain_hits=0
			for e in enemies:
				if e!=target and e.hp>0 and e.pos.distance_to(target.pos)<=r:
					damage_enemy(e,st[0]*((0.55+0.15*level("blast"))*(SHATTER_SPLASH if marked else 1.0) if t.kind==2 else 0.65))
					shots.append({"from":target.pos,"to":e.pos,"kind":t.kind,"tower_id":t.id,"synergy":synergy if t.kind==2 else "","life":0.12})
					chain_hits+=1
					if t.kind==0 and chain_hits>=chain_limit: break
	for i in range(enemies.size()-1,-1,-1):
		if enemies[i].hp<=0:
			if not enemies[i].get("escaped",false):
				kills+=1
				deaths.append({"role":enemies[i].role,"pos":enemies[i].pos,"direction":enemies[i].get("direction",Vector2.RIGHT),"tick":tick_count,"id":enemies[i].id})
				if enemies[i].boss: boss_defeated=true
			enemies.remove_at(i)
	for i in range(shots.size()-1,-1,-1):
		shots[i].life-=TICK
		if shots[i].life<=0: shots.remove_at(i)
	if hp<=0:
		phase="lost"; message="Core lost. Try a different build."; changed.emit()
	elif pending==0 and enemies.is_empty():
		if stage==2 and wave==1:
			phase="won" if boss_defeated else "lost"
			message="Expedition complete!" if boss_defeated else "The rift guardian escaped."
			changed.emit(); return
		var reward=12+(6 if stage==1 and opened and wave_leaks==0 else 0)
		gold+=reward
		if wave==1:
			stage+=1; wave=0; route_choice=0; opened=false
			for t in towers:
				t.cell=Vector2i(-1,-1); t.cool=0.0; reserve.append(t)
			towers.clear()
		else: wave+=1
		phase="build"; message="Wave clear! Earned %d credits. Prepare the next defense." % reward
		changed.emit()
