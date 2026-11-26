extends RefCounted
## Read-only presentation. Observe only after accepted start and each Run.step.
## All world points use the existing model's grid coordinate convention. No RNG,
## collision, economy, combat or phase mutations. The caller owns draw order.
const DANGER_DISTANCE:float=2.0
const TRACE_CAP:int=12
const IMPACT_CAP:int=28
const TRACE_FADE_TICKS:int=20
const IMPACT_TICKS:int=6
const ALERT_COLOR=Color("9d343c")
const TEAL=Color("176d72")
const ICE=Color("d4f2ec")
const SAND=Color("a67553")
const INK=Color("213d48")
const PAPER=Color("fff6e4")

var traces:Array=[]
var previous_traces:Array=[]
var impacts:Array=[]
var danger_active:bool=false
var danger_count:int=0
var danger_pos:Vector2=Vector2.ZERO
var last_alert_tick:int=-1
var last_contact_tick:int=-1
var last_leak_tick:int=-1
var last_wave_start_tick:int=-1
var last_tick:int=-1
var last_phase:String=""
var last_stage:int=-1
var last_wave:int=-1
var last_run_leaks:int=0
var first_contact_seen:bool=false
var events:Dictionary={}

func active_routes(game)->Array:
	var result:Array=[game.path()]
	if game.stage==1 and game.opened:result.append(game.path(false))
	return result

func remaining_threats(game)->Array:
	var threats:Array=[]
	if game.phase!="fight":return threats
	for enemy in game.enemies:
		if float(enemy.get("hp",0.0))<=0.0:continue
		var distance:float=game.remaining_distance(enemy)
		if distance>=0.0 and distance<=DANGER_DISTANCE:
			threats.append({"id":enemy.id,"pos":enemy.pos,"distance":distance})
	threats.sort_custom(func(a,b):return float(a.distance)<float(b.distance))
	return threats

func _base_events(game)->Dictionary:
	var path:Array=game.path()
	return {"wave_start":false,"first_contact":false,"alert_enter":false,
		"alert_exit":false,"leak_count":0,"wave_end":false,"entry":path[0],
		"core_pos":path[-1],"contact_pos":Vector2.ZERO,"danger_pos":danger_pos,
		"tick":game.tick_count}

func _record(game)->void:
	last_tick=game.tick_count
	last_phase=game.phase
	last_stage=game.stage
	last_wave=game.wave
	last_run_leaks=game.run_leaks

func reset(game)->void:
	traces.clear()
	previous_traces.clear()
	impacts.clear()
	danger_active=false
	danger_count=0
	danger_pos=Vector2.ZERO
	last_alert_tick=-1
	last_contact_tick=-1
	last_leak_tick=-1
	last_wave_start_tick=-1
	first_contact_seen=false
	_record(game)
	events=_base_events(game)

func _trace(pos:Vector2,kind:int,death:bool,tick:int)->void:
	var cell=Vector2i(roundi(pos.x),roundi(pos.y))
	if cell.x<0 or cell.x>11 or cell.y<0 or cell.y>7:return
	var nearest:int=-1
	for i in range(traces.size()):
		if traces[i].cell==cell:
			nearest=i
			break
	# A bounded, position-faithful heat mark: when full, merge only an adjacent
	# observed position; never place a mark at an unvisited cell.
	if nearest<0 and traces.size()>=TRACE_CAP:
		var best:float=1.01
		for i in range(traces.size()):
			var distance:float=Vector2(traces[i].cell).distance_to(Vector2(cell))
			if distance<best:
				nearest=i
				best=distance
		if nearest<0:return
	if nearest<0:
		traces.append({"cell":cell,"pos":pos,"kind":kind,"hits":0,"deaths":0,"last_tick":tick})
		nearest=traces.size()-1
	var mark:Dictionary=traces[nearest]
	if death:mark.deaths=mini(8,int(mark.deaths)+1)
	else:mark.hits=mini(8,int(mark.hits)+1)
	if kind==1:mark.kind=1 # cold residue if a real frost attack touched this mark
	mark.last_tick=tick

func _new_impact(shot:Dictionary,tick:int)->void:
	var impact={"from":Vector2(shot.from),"to":Vector2(shot.to),"kind":int(shot.kind),
		"synergy":str(shot.get("synergy","")),"tower_id":int(shot.get("tower_id",-1)),"tick":tick}
	# Preserve every recorded contact in aggregate traces; only optional spark
	# presentation is capped in worst-case chain/area scenes.
	if impacts.size()>=IMPACT_CAP:impacts.pop_front()
	impacts.append(impact)
	_trace(impact.to,impact.kind,false,tick)

func observe(game)->Dictionary:
	# Detect reset defensively even if the caller forgot the explicit reset hook.
	if last_tick<0 or game.tick_count<last_tick or game.run_leaks<last_run_leaks:
		reset(game)
		return events
	var next:Dictionary=_base_events(game)
	var changed_stage:bool=game.stage!=last_stage
	var new_wave:bool=last_phase!="fight" and game.phase=="fight"
	var ended:bool=last_phase=="fight" and game.phase!="fight"
	var new_tick:bool=game.tick_count>last_tick
	var was_danger:bool=danger_active
	next.wave_end=ended
	next.leak_count=maxi(0,int(game.run_leaks)-last_run_leaks)
	if int(next.leak_count)>0:last_leak_tick=game.tick_count
	if changed_stage:
		traces.clear()
		previous_traces.clear()
		impacts.clear()
		first_contact_seen=false
		last_wave_start_tick=-1
		last_contact_tick=-1
		last_alert_tick=-1
		last_leak_tick=-1
	if new_wave:
		previous_traces=traces.duplicate(true)
		traces.clear()
		impacts.clear()
		first_contact_seen=false
		last_contact_tick=-1
		last_leak_tick=-1
		last_alert_tick=-1
		last_wave_start_tick=game.tick_count
		next.wave_start=true
	if not changed_stage and new_tick and (last_phase=="fight" or game.phase=="fight"):
		# Run stores current-tick attack ownership on each tower. Current primary
		# shot life is 0.16-0.05=.11; current secondary .12-.05=.07. Previous
		# shots are <=.06. Explicit shot.tick metadata, if added, takes priority.
		# Only current authoritative tick is consumed, never per rendered frame.
		var fired:Dictionary={}
		for tower in game.towers:
			if int(tower.get("attack_tick",-1))==game.tick_count:fired[int(tower.id)]=true
		for shot in game.shots:
			var current:bool=int(shot.get("tick",-1))==game.tick_count if shot.has("tick") else (fired.has(int(shot.get("tower_id",-1))) and float(shot.get("life",0.0))>0.065)
			if not current:continue
			_new_impact(shot,game.tick_count)
			if not first_contact_seen:
				first_contact_seen=true
				last_contact_tick=game.tick_count
				next.first_contact=true
				next.contact_pos=shot.to
		for death in game.deaths:
			if int(death.tick)==game.tick_count:_trace(death.pos,-1,true,game.tick_count)
	for i in range(impacts.size()-1,-1,-1):
		if game.tick_count-int(impacts[i].tick)>=IMPACT_TICKS:impacts.remove_at(i)
	if last_wave_start_tick>=0 and game.tick_count-last_wave_start_tick>=TRACE_FADE_TICKS:
		previous_traces.clear()
	var danger:Array=remaining_threats(game)
	danger_count=danger.size()
	danger_active=danger_count>0
	if danger_active:
		danger_pos=danger[0].pos
		if not was_danger:
			last_alert_tick=game.tick_count
			next.alert_enter=true
			next.danger_pos=danger_pos
	elif was_danger:
		next.alert_exit=true
	if ended:
		# Leave faint confirmed traces only on the same stage. Do not freeze
		# time-sensitive contact effects in preparation/terminal state.
		impacts.clear()
		previous_traces.clear()
	if game.phase=="lost":
		traces.clear()
		previous_traces.clear()
		impacts.clear()
	_record(game)
	next.danger_pos=danger_pos
	events=next
	return events

func _world(pos:Vector2,origin:Vector2,tile:float)->Vector2:
	return origin+(pos+Vector2(0.5,0.5))*tile

func _ring(canvas:CanvasItem,center:Vector2,radius:float,color:Color,width:float=1.6)->void:
	canvas.draw_arc(center,radius,0,TAU,32,color,width,true)

func _trace_draw(canvas:CanvasItem,mark:Dictionary,origin:Vector2,tile:float,fade:float)->void:
	var p:Vector2=_world(mark.pos,origin,tile)+Vector2(0,8)
	var strength:float=minf(1.0,0.45+0.055*float(int(mark.hits)+int(mark.deaths)))
	var a:float=0.25*strength*fade
	var cold:bool=int(mark.kind)==1
	var tint:Color=Color(0.20,0.54,0.55,a) if cold else Color(SAND,a)
	# Short three gull-wing marks evoke scuffed sandstone/salt, not obstacle.
	canvas.draw_line(p+Vector2(-13,2),p+Vector2(4,-3),tint,3.0,true)
	canvas.draw_line(p+Vector2(-8,7),p+Vector2(16,0),tint,2.0,true)
	canvas.draw_line(p+Vector2(3,9),p+Vector2(12,6),tint,1.5,true)
	if int(mark.deaths)>0:
		for j in range(2):
			var q:=p+Vector2(float(j)*8-6,-7+float(j)*3)
			canvas.draw_colored_polygon(PackedVector2Array([q,q+Vector2(5,-3),q+Vector2(7,2),q+Vector2(0,4)]),Color(0.71,0.38,0.28,a*0.9))
	if cold:
		canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(1,-9),p+Vector2(4,-1),p+Vector2(1,2),p+Vector2(-2,-1)]),Color(ICE,0.40*fade))

func draw_ground(canvas:CanvasItem,game,origin:Vector2,tile:float,idle_seconds:float,layout:Dictionary={})->void:
	for mark in previous_traces:
		var fade:float=clampf(1.0-float(game.tick_count-last_wave_start_tick)/TRACE_FADE_TICKS,0.0,1.0)
		if fade>0.0:_trace_draw(canvas,mark,origin,tile,fade)
	for mark in traces:_trace_draw(canvas,mark,origin,tile,1.0)
	if game.phase=="build" or game.phase=="fight":
		for path in active_routes(game):
			if path.size()<2:continue
			var direction:Vector2=(Vector2(path[1])-Vector2(path[0])).normalized()
			var start:Vector2=_world(path[0],origin,tile)
			var flow_time:float=idle_seconds if game.phase=="build" else float(game.tick_count)*0.05
			# These restrained chevrons always describe the actual active entry;
			# no red warning and no implied countdown while the player plans.
			for k in range(3):
				var dist:float=tile*0.50+float(k)*13.0
				var p:Vector2=start+direction*dist
				var n:Vector2=direction.orthogonal()*4.5
				var alpha:float=0.35+0.18*sin(flow_time*2.6-float(k)*0.9)
				canvas.draw_polyline(PackedVector2Array([p-direction*5+n,p,p-direction*5-n]),Color(TEAL,alpha),2.0,true)
			if game.phase=="fight" and last_wave_start_tick>=0 and game.tick_count-last_wave_start_tick<10:
				var u:float=clampf(float(game.tick_count-last_wave_start_tick)/10.0,0.0,1.0)
				_ring(canvas,start+direction*17.0,15.0+u*14.0,Color(0.35,0.65,0.65,0.48*(1.0-u)),2.4)
	# Persistent ice state, not a fake pre-hit signal. Layer before sprites.
	if game.phase=="fight":
		for e in game.enemies:
			if float(e.get("hp",0))<=0.0 or float(e.get("slow",0.0))<=0.0:continue
			var dir:Vector2=e.get("direction",Vector2.RIGHT)
			var p:Vector2=_world(e.pos,origin,tile)+dir.orthogonal()*float((int(e.id)%3)-1)*5.0+Vector2(0,13)
			var units:Dictionary=layout.get("units",{})
			if units.has(int(e.id)):p=Vector2(units[int(e.id)].anchor)
			for k in range(4):
				var angle:float=TAU*float(k)/4.0+PI/4.0
				var n:Vector2=Vector2.from_angle(angle)
				var q:Vector2=p+n*14.0
				canvas.draw_colored_polygon(PackedVector2Array([q+n*5.5,q+n.orthogonal()*3.0,q-n*3.0,q-n.orthogonal()*3.0]),Color(0.32,0.67,0.74,0.82))
				canvas.draw_line(q+n*5.5,q-n*3.0,Color(ICE,0.90),1.5,true)

func _conductive(canvas:CanvasItem,from:Vector2,to:Vector2,a:float)->void:
	var distance:float=from.distance_to(to)
	if distance<0.1:return
	var n:Vector2=(to-from).normalized().orthogonal()
	var points:=PackedVector2Array([from])
	for i in range(1,5):
		var f:float=float(i)/5.0
		points.append(from.lerp(to,f)+n*(5.0 if i%2 else -5.0)*minf(1.0,distance/38.0))
	points.append(to)
	canvas.draw_polyline(points,Color(0.15,0.47,0.54,0.65*a),3.8,true)
	canvas.draw_polyline(points,Color(0.83,1.0,0.94,0.92*a),1.6,true)

func _shards(canvas:CanvasItem,p:Vector2,u:float,ice:bool)->void:
	var a:float=1.0-u
	for k in range(4):
		var n:Vector2=Vector2.from_angle(float(k)*TAU/4.0+0.45)
		var q:Vector2=p+n*(7.0+u*14.0)
		var color:Color=Color(0.35,0.75,0.78,a) if ice else Color(0.76,0.42,0.26,a*0.82)
		canvas.draw_colored_polygon(PackedVector2Array([q+n*6.0,q+n.orthogonal()*3.0,q-n*2.0,q-n.orthogonal()*3.0]),color)
		canvas.draw_line(q+n*5.0,q-n*2.0,Color(PAPER,a*0.77),1.2,true)

func draw_combat(canvas:CanvasItem,game,origin:Vector2,tile:float)->void:
	if game.phase!="fight":return
	for impact in impacts:
		var u:float=clampf(float(game.tick_count-int(impact.tick))/IMPACT_TICKS,0.0,1.0)
		var a:float=1.0-u
		var p:Vector2=_world(impact.to,origin,tile)
		var from:Vector2=_world(impact.from,origin,tile)
		var kind:int=impact.kind
		var synergy:String=impact.synergy
		if synergy=="conductive":
			if u<0.55:_conductive(canvas,from,p,a)
			_ring(canvas,p,7.0+u*11.0,Color(0.24,0.78,0.79,a),2.0)
		elif synergy=="shatter":
			if u<0.4:canvas.draw_line(from,p,Color(0.68,0.43,0.23,0.65*a),2.4,true)
			_shards(canvas,p,u,true)
		elif kind==0:
			# Short travel line and actual impact glint. No broad AoE claim.
			if u<0.55:
				canvas.draw_line(from.lerp(p,0.22),p,Color(0.74,0.43,0.19,0.72*a),2.0,true)
				canvas.draw_line(from.lerp(p,0.65),p,Color(PAPER,0.87*a),1.1,true)
			_ring(canvas,p,4.0+u*8.0,Color(0.83,0.52,0.24,0.85*a),1.5)
		elif kind==1:
			if u<0.60:canvas.draw_line(from.lerp(p,0.32),p,Color(0.29,0.66,0.73,0.70*a),2.2,true)
			_ring(canvas,p,6.0+u*9.0,Color(0.35,0.70,0.75,0.85*a),2.0)
			_shards(canvas,p,u,true)
		else:
			if u<0.45:canvas.draw_line(from.lerp(p,0.45),p,Color(0.65,0.36,0.27,0.72*a),2.2,true)
			_shards(canvas,p,u,false)
		if game.tick_count-last_contact_tick<6 and int(impact.tick)==last_contact_tick:
			# First contact emphasized locally, not a full-screen flash.
			_ring(canvas,p,10.0+u*8.0,Color(PAPER,0.4*a),2.0)

	_draw_transfers(canvas,game,origin,tile)

func _draw_transfers(canvas:CanvasItem,game,origin:Vector2,tile:float)->void:
	# Actual non-damage tide transfer event; old/disabled Run has no list.
	# Positions stay the authoritative event coordinates, never the readability
	# render offset (damage/target logic must remain visually truthful).
	var transfers=game.get("tide_transfers")
	if not transfers is Array:return
	for transfer in transfers:
		var age:int=int(game.tick_count)-int(transfer.get("tick",-999))
		if age<0 or age>=10:continue
		var u:float=float(age)/10.0
		var a:float=1.0-u
		var from:Vector2=_world(transfer.from,origin,tile)
		var to:Vector2=_world(transfer.to,origin,tile)
		if from.distance_to(to)<0.01:continue
		var dir:Vector2=(to-from).normalized()
		var n:Vector2=dir.orthogonal()
		var points:=PackedVector2Array()
		for i in range(9):
			var f:float=float(i)/8.0
			points.append(from.lerp(to,f)+n*sin(f*PI)*6.0)
		# Teal water ribbon, not copper damage impulse. Two chevrons travel in
		# the actual transfer direction, then a small cold-status ripple.
		canvas.draw_polyline(points,Color(0.13,0.48,0.54,a*0.55),3.0,true)
		canvas.draw_polyline(points,Color(0.76,0.94,0.90,a*0.82),1.2,true)
		for j in range(2):
			var f:float=clampf(u+float(j)*0.18,0.0,1.0)
			var p:Vector2=from.lerp(to,f)+n*sin(f*PI)*6.0
			canvas.draw_polyline(PackedVector2Array([p-dir*5.0+n*3.0,p,p-dir*5.0-n*3.0]),Color(0.81,0.99,0.96,a*0.8),1.5,true)
		_ring(canvas,to,5.0+u*7.0,Color(0.20,0.60,0.64,a*0.68),1.4)

func draw_alert(canvas:CanvasItem,game,origin:Vector2,tile:float,font:Font)->void:
	if game.phase!="fight":return
	var path:Array=game.path()
	var p:Vector2=_world(path[-1],origin,tile)
	if danger_active:
		var age:float=float(game.tick_count-last_alert_tick)*0.05
		var edge_alpha:float=0.72 if age>=0.45 else 0.72+0.24*(1.0-age/0.45)
		_ring(canvas,p+Vector2(0,8),29.0,Color(ALERT_COLOR,edge_alpha),3.1)
		var rect:=Rect2(p+Vector2(-120,-132),Vector2(154,26))
		canvas.draw_rect(rect,PAPER)
		canvas.draw_rect(rect,ALERT_COLOR,false,2.0)
		var q:Vector2=rect.position+Vector2(13,5)
		canvas.draw_colored_polygon(PackedVector2Array([q+Vector2(0,15),q+Vector2(8,0),q+Vector2(16,15)]),ALERT_COLOR)
		canvas.draw_line(q+Vector2(8,5),q+Vector2(8,9),PAPER,1.6,true)
		canvas.draw_circle(q+Vector2(8,12),1.0,PAPER)
		if font!=null:canvas.draw_string(font,rect.position+Vector2(33,18),"CORE ALERT  %d"%danger_count,HORIZONTAL_ALIGNMENT_LEFT,-1,12,ALERT_COLOR)
	if last_leak_tick>=0 and game.tick_count-last_leak_tick<8:
		var u:float=float(game.tick_count-last_leak_tick)/8.0
		_ring(canvas,p+Vector2(0,8),33.0+u*15.0,Color(ALERT_COLOR,1.0-u),3.0)

func draw_rank(canvas:CanvasItem,position:Vector2,rank:int)->void:
	# Nonintrusive physical-looking brass enamel chevrons on socket's left
	# edge. Existing numeric rank badge remains the semantic source.
	for i in range(clampi(rank-1,0,2)):
		var p:Vector2=position+Vector2(-24.0+float(i)*8.0,27.0)
		canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(-4,1),p+Vector2(0,-6),p+Vector2(4,1),p+Vector2(0,4)]),Color("b18449"))
		canvas.draw_line(p+Vector2(-4,1),p+Vector2(0,-6),Color(PAPER,0.94),1.1,true)

func draw_amplifier(canvas:CanvasItem,p:Vector2,active:bool)->void:
	# Small saltwashed stone plinth with a crystal shard cluster. Actual model
	# AMP_CELLS still owns placement; this geometry does not imply collision.
	var base:=p+Vector2(0,12)
	var shadow:=PackedVector2Array()
	var top:=PackedVector2Array()
	for i in range(32):
		var a:float=float(i)*TAU/32.0
		shadow.append(base+Vector2(cos(a)*23.0,sin(a)*10.0+4.0))
		top.append(base+Vector2(cos(a)*21.0,sin(a)*9.0-1.0))
	canvas.draw_colored_polygon(shadow,Color(0.18,0.25,0.24,0.20))
	canvas.draw_colored_polygon(top,Color("d9c8a9"))
	canvas.draw_polyline(top+PackedVector2Array([top[0]]),Color("8a877e"),1.8,true)
	for i in range(3):
		var shift:float=float(i-1)*10.0
		var h:float=22.0 if i==1 else 14.0
		var q:Vector2=base+Vector2(shift,-4.0)
		var tip:Vector2=q+Vector2(float(i-1)*3.0,-h)
		var left:Vector2=q+Vector2(-5.5,-3.0)
		var right:Vector2=q+Vector2(5.5,-3.0)
		var side:Vector2=q+Vector2(0,3.0)
		canvas.draw_colored_polygon(PackedVector2Array([tip,left,side,right]),Color("8f77a3"))
		canvas.draw_colored_polygon(PackedVector2Array([tip,right,side]),Color("665a81"))
		canvas.draw_line(tip,side,Color("d5c7da"),1.4,true)
		canvas.draw_line(tip,left,Color("b9adc7"),1.6,true)
	if active:
		_ring(canvas,base,24.0,Color(0.53,0.36,0.61,0.70),2.0)
