extends RefCounted
## Render-only crowd layout. Does not change the authoritative enemy route,
## velocity, hit/slow, targeting, damage, collision, range or RNG.
const MAX_OFFSET:float=12.0
const BASE_OFFSET:float=5.0
const MIN_SCALE:float=0.84
const HEALTH_H:float=4.0
const MAX_BAR_LINK:float=50.0
const INK=Color("213d48")
const PAPER=Color("fff6e4")
const HEALTH_BG=Color("36515a")
const HEALTH_FG=Color("f18b68")
const ROLE_WIDTH={"normal":55.0,"runner":68.0,"guard":70.0,"boss":105.0}
const ROLE_HEIGHT={"normal":53.0,"runner":50.0,"guard":67.0,"boss":112.0}
var _offsets:Dictionary={}
var _scales:Dictionary={}
var _last_stage:int=-1
var _last_wave:int=-1
var _last_phase:String=""
var _last_tick:int=-1

func reset()->void:
	_offsets.clear()
	_scales.clear()
	_last_stage=-1
	_last_wave=-1
	_last_phase=""
	_last_tick=-1

func world(pos:Vector2,origin:Vector2,tile:float)->Vector2:
	return origin+(pos+Vector2(0.5,0.5))*tile

func _tangent(enemy:Dictionary)->Vector2:
	var fallback:Vector2=enemy.get("direction",Vector2.RIGHT)
	if fallback.length_squared()<0.001:fallback=Vector2.RIGHT
	var route:Array=enemy.get("route",[])
	var seg:int=int(enemy.get("segment",0))
	var p:Vector2=enemy.get("pos",Vector2.ZERO)
	if seg<0 or seg+1>=route.size():return fallback.normalized()
	var a:Vector2=route[seg]
	var b:Vector2=route[seg+1]
	var v:Vector2=(b-a).normalized()
	if v.length_squared()<0.001:return fallback.normalized()
	# Round presentation-only side offset around an authoritative corner.
	# At the exact vertex, both adjoining segments give the same tangent.
	var bend:float=0.24
	if seg>0 and p.distance_to(a)<bend:
		var prev:Vector2=(a-Vector2(route[seg-1])).normalized()
		var u:float=clampf(p.distance_to(a)/bend,0.0,1.0)
		var mix:Vector2=prev.lerp(v,0.5+0.5*smoothstep(0.0,1.0,u))
		if mix.length_squared()>0.001:return mix.normalized()
	if seg+2<route.size() and p.distance_to(b)<bend:
		var next:Vector2=(Vector2(route[seg+2])-b).normalized()
		var u:float=clampf(p.distance_to(b)/bend,0.0,1.0)
		var mix:Vector2=v.lerp(next,0.5*(1.0-smoothstep(0.0,1.0,u)))
		if mix.length_squared()>0.001:return mix.normalized()
	return v

func _offset_for(enemy:Dictionary,tile:float,crowd:float)->Vector2:
	if bool(enemy.get("boss",false)):return Vector2.ZERO
	var lane:float=float(posmod(int(enemy.id),3)-1)
	var amplitude:float=minf(MAX_OFFSET,tile*0.158)*clampf((BASE_OFFSET+(MAX_OFFSET-BASE_OFFSET)*crowd)/MAX_OFFSET,0.0,1.0)
	return _tangent(enemy).orthogonal()*lane*amplitude

func death_anchor(death:Dictionary,origin:Vector2,tile:float)->Vector2:
	# Last actually rendered offset, if available; no stale previous-wave ID.
	var d:Vector2=death.get("direction",Vector2.RIGHT)
	var lane:float=float(posmod(int(death.id),3)-1)
	var fallback:Vector2=d.normalized().orthogonal()*lane*minf(BASE_OFFSET,tile*0.158)
	if str(death.get("role",""))=="boss":fallback=Vector2.ZERO
	return world(death.pos,origin,tile)+Vector2(_offsets.get(int(death.id),fallback))+Vector2(0,13)

func death_scale(death:Dictionary)->float:
	return float(_scales.get(int(death.id),1.0))

func _health_ok(rect:Rect2,used:Array,board:Rect2,reserved:Rect2)->bool:
	if not board.encloses(rect.grow(1.0)):return false
	if reserved.size.x>0 and rect.grow(2.0).intersects(reserved):return false
	for other in used:
		if rect.grow(1.35).intersects(other.grow(1.35)):return false
	return true

func _bar_candidates(row:Dictionary,board:Rect2,used:Array,reserved:Rect2)->Dictionary:
	var p:Vector2=row.pos
	var anchor:Vector2=row.anchor
	var boss:bool=row.boss
	var tightly_packed:bool=int(row.crowd_count)>=8 and not boss
	if tightly_packed:p=row.logical_pos
	# Prefer a normal bar centered below the feet. In crowding, route compact
	# individual bars across up to five local rows. Every placement stays local,
	# and any displaced bar has an explicit line to its own rendered foot.
	var widths:Array=[38.0,28.0,20.0,14.0] if boss else ([14.0] if int(row.crowd_count)>=8 else ([20.0,14.0] if int(row.crowd_count)>=5 else [28.0,20.0,14.0]))
	for w_variant in widths:
		var w:float=float(w_variant)
		var h:float=5.0 if boss and w>=28.0 else HEALTH_H
		var max_dx:float=10.0 if w>=28.0 else (22.0 if w>=20.0 else 33.0)
		var max_row:int=3 if w>=28.0 else 5
		var offsets:Array[float]=[0.0]
		if tightly_packed:offsets=[0.0,17.0,-17.0,34.0,-34.0]
		else:
			for i in range(1,int(max_dx/6.0)+1):
				offsets.append(float(i)*6.0)
				offsets.append(-float(i)*6.0)
		var row_offsets:Array[float]=[]
		for i in range(max_row+1):row_offsets.append(float(i)*(h+3.2 if tightly_packed else h+4.0))
		# A warning label can occupy every ordinary below-foot candidate.
		# Only then allow a nearby bar beside/just above the contact point;
		# its leader keeps the exact association instead of masking the alert.
		if reserved.size.x>0.0:
			row_offsets.append(-8.0)
			row_offsets.append(-16.0)
			row_offsets.append(-24.0)
		for dy in row_offsets:
			for dx in offsets:
				var center:Vector2=p+Vector2(dx,26.0+dy+h/2.0)
				if tightly_packed:
					# Keep the compact grid spacing at board edges; individual clamping
					# would merge slots and unnecessarily hide per-unit HP.
					var grid_center:float=clampf(p.x,board.position.x+34.0+w/2.0+2.0,board.end.x-34.0-w/2.0-2.0)
					center.x=grid_center+dx
				center.x=clampf(center.x,board.position.x+w/2.0+2.0,board.end.x-w/2.0-2.0)
				center.y=clampf(center.y,board.position.y+h/2.0+2.0,board.end.y-h/2.0-2.0)
				if center.distance_to(anchor)>MAX_BAR_LINK:continue
				var r:=Rect2(center-Vector2(w/2.0,h/2.0),Vector2(w,h))
				if _health_ok(r,used,board,reserved):
					return {"bar_pos":r.position,"bar_size":r.size,"bar_link":anchor,
						"bar_center":center,"bar_draw":true,"bar_compact":w<(38.0 if boss else 28.0),
						"bar_routed":tightly_packed or absf(dx)>0.5 or absf(dy)>0.5 or center.distance_to(p+Vector2(0,26.0+h/2.0))>1.0}
	# Severe synthetic piles can exceed local non-overlap capacity. Retain an
	# exact per-unit rendered badge anchored on its own body instead of moving
	# it outside the local region or masking another bar. The count is exposed
	# for QA; actual supported waves must avoid this overflow.
	return {"bar_pos":anchor,"bar_size":Vector2.ZERO,"bar_link":anchor,"bar_center":anchor,
		"bar_draw":false,"bar_compact":true,"bar_routed":true}

func layout(game,origin:Vector2,tile:float)->Dictionary:
	if _last_stage!=game.stage or _last_wave!=game.wave or game.tick_count<_last_tick or (_last_phase!="fight" and game.phase=="fight"):
		_offsets.clear()
		_scales.clear()
	_last_stage=game.stage
	_last_wave=game.wave
	_last_phase=game.phase
	_last_tick=game.tick_count
	var board:=Rect2(origin,Vector2(12,8)*tile)
	var units:Dictionary={}
	var ids:Array=[]
	var live:Array=[]
	for e in game.enemies:
		if float(e.get("hp",0.0))<=0.0:continue
		live.append(e)
	live.sort_custom(func(a,b):return int(a.id)<int(b.id))
	var warning:=Rect2()
	var warning_required:bool=false
	for e in live:
		if game.phase=="fight" and game.remaining_distance(e)<=2.0:warning_required=true
	if warning_required:
		var route:Array=game.path()
		var core:=world(route[-1],origin,tile)
		# Same footprint as BattleAtmosphere.draw_alert; critical label wins.
		warning=Rect2(core+Vector2(-120,-132),Vector2(154,26))
	for e in live:
		var p:Vector2=world(e.pos,origin,tile)
		var role:String=str(e.get("role","normal"))
		var nearest:float=INF
		var close_count:int=0
		for other in live:
			if int(other.id)==int(e.id):continue
			var dist:float=p.distance_to(world(other.pos,origin,tile))
			nearest=minf(nearest,dist)
			if dist<tile*0.83:close_count+=1
		var quiet_distance:float=minf(float(ROLE_WIDTH.get(role,55.0))+5.0,tile*0.88)
		var congested:float=clampf((quiet_distance-nearest)/maxf(quiet_distance-tile*0.20,1.0),0.0,1.0)
		# Smoothly ease crowding; do not pop as a neighbor crosses a cutoff.
		congested=smoothstep(0.0,1.0,congested)
		var offset:Vector2=_offset_for(e,tile,congested)
		var pos:Vector2=p+offset
		var boss:bool=bool(e.get("boss",false))
		# The boss keeps its scale and center to preserve importance. Other
		# silhouettes reduce only modestly in a dense pack, never below 84%.
		var mul:float=1.0 if boss else lerpf(1.0,MIN_SCALE,congested)
		var row={"id":int(e.id),"logical_pos":p,"pos":pos,"anchor":pos+Vector2(0,13),
			"offset":offset,"scale_mul":mul,"crowded":congested>0.1,"crowd_strength":congested,
			"phase_offset":float(posmod(int(e.id),4))*0.125,"role":role,"boss":boss,"crowd_count":close_count,
			"logical_danger":game.phase=="fight" and game.remaining_distance(e)<=2.0}
		units[int(e.id)]=row
		ids.append(int(e.id))
		_offsets[int(e.id)]=offset
		_scales[int(e.id)]=mul
	# Draw sprites back-to-front by actual visual feet, stable ID tie break.
	var sorted_ids:Array=ids.duplicate()
	sorted_ids.sort_custom(func(a,b):
		var ay:float=units[a].anchor.y
		var by:float=units[b].anchor.y
		return int(a)<int(b) if ay==by else ay<by)
	# Place priority bars first, then stable spawn ID. This keeps boss and
	# nearest threats legible; warning label is reserved, never hidden by bar.
	var bar_ids:Array=ids.duplicate()
	bar_ids.sort_custom(func(a,b):
		var ar:Dictionary=units[a]
		var br:Dictionary=units[b]
		if ar.boss!=br.boss:return ar.boss
		if ar.logical_danger!=br.logical_danger:return ar.logical_danger
		if int(ar.crowd_count)>=8 and int(br.crowd_count)>=8:
			if float(ar.anchor.y)!=float(br.anchor.y):return ar.anchor.y<br.anchor.y
		return int(a)<int(b))
	var used:Array=[]
	var overflow:int=0
	for id in bar_ids:
		var row:Dictionary=units[id]
		var bar:Dictionary=_bar_candidates(row,board,used,warning)
		row.merge(bar,true)
		if row.bar_draw:
			used.append(Rect2(row.bar_pos,row.bar_size))
		else:overflow+=1
	return {"units":units,"sorted_ids":sorted_ids,"bar_ids":bar_ids,
		"unresolved_count":overflow,"warning_rect":warning,"board":board}

func draw_ground_link(canvas:CanvasItem,row:Dictionary)->void:
	if Vector2(row.offset).length()<7.0:return
	var logical:Vector2=row.logical_pos+Vector2(0,13)
	var visual:Vector2=row.anchor
	# Quiet sand contact dash, only for meaningful visual offsets. It locates
	# the actual lane center and is not a tether, attack or new hitbox.
	canvas.draw_line(logical,visual,Color(0.25,0.31,0.30,0.33),1.2,true)

func draw_health(canvas:CanvasItem,game,layout_data:Dictionary)->void:
	var units:Dictionary=layout_data.get("units",{})
	var live:Dictionary={}
	for e in game.enemies:
		if float(e.get("hp",0.0))>0.0:live[int(e.id)]=e
	# Route hairlines under all bars; then each actual individual HP.
	for id in layout_data.get("bar_ids",[]):
		if not live.has(id) or not units.has(id):continue
		var row:Dictionary=units[id]
		if not row.bar_draw or not row.bar_routed:continue
		var from:Vector2=row.bar_link
		var to:Vector2=row.bar_center
		canvas.draw_line(from,to,Color(PAPER,0.78),2.0,true)
		canvas.draw_line(from,to,Color(INK,0.82),1.0,true)
	for id in layout_data.get("bar_ids",[]):
		if not live.has(id) or not units.has(id):continue
		var row:Dictionary=units[id]
		var e:Dictionary=live[id]
		var ratio:float=clampf(float(e.hp)/maxf(float(e.maxhp),0.001),0.0,1.0)
		if not row.bar_draw:
			# No false aggregate HP. Exact individual fallback dot, bounded at
			# its own visible foot. Unresolved count is a QA budget failure.
			canvas.draw_circle(row.anchor,3.0,INK)
			canvas.draw_arc(row.anchor,2.1,-PI/2,-PI/2+TAU*ratio,16,HEALTH_FG,1.5,true)
			continue
		var pos:Vector2=row.bar_pos
		var size:Vector2=row.bar_size
		canvas.draw_rect(Rect2(pos-Vector2.ONE,size+Vector2.ONE*2.0),INK)
		canvas.draw_rect(Rect2(pos,size),HEALTH_BG)
		canvas.draw_rect(Rect2(pos,Vector2(size.x*ratio,size.y)),HEALTH_FG)
		canvas.draw_line(pos+Vector2(0,-1),pos+Vector2(size.x,-1),Color("d0b36a") if row.boss else PAPER,1.0,true)
