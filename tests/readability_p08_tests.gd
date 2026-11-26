extends SceneTree
const Run=preload("res://src/Run.gd")
const Read=preload("res://src/BattleReadability.gd")
const ORIGIN=Vector2(52,60)
const TILE=76.0
var passed:int=0
var failed:int=0
var sampled_ticks:int=0
var sampled_enemies:int=0
var max_live:int=0
var prior_overlap:float=0.0
var after_overlap:float=0.0
var prior_bar_pairs:int=0
var after_bar_pairs:int=0
var compact_bars:int=0
var max_overlap_sample:float=-1.0
var witness:Dictionary={}

func _initialize()->void:call_deferred("execute")

func check(ok:bool,name:String)->void:
	if ok:passed+=1
	else:
		failed+=1
		push_error(name)

func linear_channel(value:float)->float:
	return value/12.92 if value<=0.04045 else pow((value+0.055)/1.055,2.4)

func luminance(c:Color)->float:
	return 0.2126*linear_channel(c.r)+0.7152*linear_channel(c.g)+0.0722*linear_channel(c.b)

func xy(v:Vector2)->Array:
	return [v.x,v.y]

func shot_snapshot(g)->String:
	return var_to_str([g.stage,g.wave,g.phase,g.tick_count,g.enemies,g.towers,g.shots,g.deaths,g.pending,g.hp,g.gold,g.rng.state,g.upgrades,g.reserve,g.run_leaks])

func foe(g,id:int,pos:Vector2,role:String="normal",segment:int=0,route:Array=[])->Dictionary:
	var path:Array=g.path() if route.is_empty() else route
	return {"id":id,"hp":25.0,"maxhp":50.0,"pos":pos,"role":role,"boss":role=="boss",
		"direction":Vector2.RIGHT,"segment":segment,"route":path}

func row_contract(g,l:Dictionary,label:String)->void:
	var seen:Dictionary={}
	var all_good:bool=true
	var linked:bool=true
	var alive:int=0
	for e in g.enemies:
		if float(e.hp)<=0.0:
			all_good=all_good and not l.units.has(int(e.id))
			continue
		alive+=1
		var id:int=int(e.id)
		if not l.units.has(id):
			all_good=false
			continue
		var u:Dictionary=l.units[id]
		var true_p:Vector2=ORIGIN+(Vector2(e.pos)+Vector2(0.5,0.5))*TILE
		all_good=all_good and not seen.has(id) and u.id==id and u.logical_pos==true_p and u.pos.distance_to(true_p)<=Read.MAX_OFFSET+0.001 and u.anchor==u.pos+Vector2(0,13)
		all_good=all_good and float(u.scale_mul)>=Read.MIN_SCALE and float(u.scale_mul)<=1.0 and u.role==e.role
		all_good=all_good and (not e.boss or (u.offset==Vector2.ZERO and is_equal_approx(u.scale_mul,1.0)))
		all_good=all_good and u.logical_danger==(g.phase=="fight" and g.remaining_distance(e)<=2.0)
		linked=linked and u.bar_link==u.anchor
		if u.bar_draw:
			var rect:=Rect2(u.bar_pos,u.bar_size)
			linked=linked and rect.get_center()==u.bar_center and u.bar_link.distance_to(u.bar_center)<=Read.MAX_BAR_LINK+0.01
			linked=linked and l.board.encloses(rect.grow(1.0)) and (l.warning_rect.size.x<=0 or not rect.grow(2.0).intersects(l.warning_rect))
		seen[id]=true
	check(all_good and l.units.size()==alive,label+" each visual row tied to correct live logical id, offset/scale bounded")
	check(linked,label+" each health bar linked own rendered anchor, stays board and avoids alert")
	var sorted:bool=true
	for i in range(1,l.sorted_ids.size()):
		var a:Dictionary=l.units[l.sorted_ids[i-1]]
		var b:Dictionary=l.units[l.sorted_ids[i]]
		sorted=sorted and (a.anchor.y<=b.anchor.y+0.0001)
		if float(a.anchor.y)==float(b.anchor.y):sorted=sorted and a.id<b.id
	check(sorted,label+" foot-Y ordering deterministic")
	var rectangles:Array=[]
	var overlaps:int=0
	for u in l.units.values():
		if not u.bar_draw:continue
		var r:=Rect2(u.bar_pos,u.bar_size).grow(1.35)
		for previous in rectangles:
			if r.intersects(previous):overlaps+=1
		rectangles.append(r)
	check(overlaps==0,label+" no placed HP-bar overlaps")
	if l.unresolved_count>0:
		print("OVERFLOW ",label," total=",l.units.size())
		for u in l.units.values():
			if not u.bar_draw:print("ROW ",u)
	check(l.unresolved_count==0,label+" no unresolved bars")
	after_bar_pairs+=overlaps

func bbox_overlap(rectangles:Array)->float:
	var result:float=0.0
	for i in range(rectangles.size()):
		for j in range(i):
			var a:Rect2=rectangles[i]
			var b:Rect2=rectangles[j]
			if a.intersects(b):
				var i_rect:Rect2=a.intersection(b)
				result+=i_rect.get_area()/maxf(1.0,minf(a.get_area(),b.get_area()))
	return result

func geometry_stats(g,l:Dictionary)->void:
	# Conservative nominal AABB proxy, not pixel or GPU occlusion. Main uses
	# actual atlas sprite scale inside these role bounding dimensions.
	var new_rects:Array=[]
	var old_rects:Array=[]
	var old_bars:Array=[]
	for e in g.enemies:
		if float(e.hp)<=0.0:continue
		var row:Dictionary=l.units[int(e.id)]
		var role:String=e.role
		var w:float=Read.ROLE_WIDTH.get(role,55.0)
		var h:float=Read.ROLE_HEIGHT.get(role,53.0)
		var old:Vector2=ORIGIN+(Vector2(e.pos)+Vector2(0.5,0.5))*TILE+Vector2(e.direction).orthogonal()*float(posmod(int(e.id),3)-1)*5.0
		var old_anchor:Vector2=old+Vector2(0,13)
		old_rects.append(Rect2(old_anchor-Vector2(w/2.0,h),Vector2(w,h)))
		var d:float=row.scale_mul
		new_rects.append(Rect2(Vector2(row.anchor)-Vector2(w*d/2.0,h*d),Vector2(w*d,h*d)))
		var size:Vector2=Vector2(38,5) if e.boss else Vector2(28,4)
		var bar:=Rect2(old+Vector2(-size.x/2.0,27),size).grow(1.35)
		for previous in old_bars:
			if bar.intersects(previous):prior_bar_pairs+=1
		old_bars.append(bar)
		if row.bar_compact:compact_bars+=1
	var old_overlap:float=bbox_overlap(old_rects)
	var new_overlap:float=bbox_overlap(new_rects)
	prior_overlap+=old_overlap
	after_overlap+=new_overlap
	if old_overlap>max_overlap_sample:
		max_overlap_sample=old_overlap
		var rows:Array=[]
		for e in g.enemies:
			if float(e.hp)<=0.0:continue
			var row:Dictionary=l.units[int(e.id)]
			var old:Vector2=ORIGIN+(Vector2(e.pos)+Vector2(0.5,0.5))*TILE+Vector2(e.direction).orthogonal()*float(posmod(int(e.id),3)-1)*5.0
			rows.append({"id":int(e.id),"role":e.role,"boss":e.boss,"hp":e.hp,"maxhp":e.maxhp,
				"old_pos":xy(old),"pos":xy(row.pos),"anchor":xy(row.anchor),"logical":xy(row.logical_pos),
				"scale_mul":row.scale_mul,"phase_offset":row.phase_offset,"face_left":e.direction.x<0,
				"hit_age":(int(g.tick_count)-int(e.get("hit_tick",-999)))*Run.TICK,
				"bar_pos":xy(row.bar_pos),"bar_size":xy(row.bar_size),"bar_link":xy(row.bar_link),
				"bar_routed":row.bar_routed,"bar_draw":row.bar_draw})
		var route:Array=[]
		for point in g.path():route.append(xy(point))
		var extra:Array=[]
		if g.stage==1 and g.opened:
			for point in g.path(false):extra.append(xy(point))
		witness={"stage":g.stage,"wave":g.wave,"tick":g.tick_count,"rows":rows,"sorted_ids":l.sorted_ids,
			"bar_ids":l.bar_ids,"old_nominal_overlap":old_overlap,"new_nominal_overlap":new_overlap,
			"route":route,"extra_route":extra,"warning":[l.warning_rect.position.x,l.warning_rect.position.y,l.warning_rect.size.x,l.warning_rect.size.y]}

	sampled_ticks+=1
	sampled_enemies+=old_rects.size()
	max_live=maxi(max_live,old_rects.size())

func fixture_tests()->void:
	var g=Run.new()
	g.reset(437)
	g.stage=1
	g.opened=true
	g.phase="fight"
	var r=Read.new()
	for p in [Vector2(0,1),Vector2(5,1),Vector2(11,4),Vector2(11,6)]:
		for n in [19,21]:
			g.enemies=[]
			# 19 unit boss pile / 21 unit open-rift pile, adversarial co-location.
			# Boss never co-occurs with open-rift in actual campaign, fixture only.
			for i in range(n):
				var role:String="boss" if n==19 and i==0 else "normal"
				var seg:int=g.path().size()-2 if p.x==11 else 0
				g.enemies.append(foe(g,i,p,role,seg))
			var before:String=shot_snapshot(g)
			var l:Dictionary=r.layout(g,ORIGIN,TILE)
			row_contract(g,l,"synthetic %d at %s"%[n,p])
			check(shot_snapshot(g)==before,"synthetic no mutation")
	# Visual offset should be continuous around an authoritative path corner.
	g.enemies=[]
	var route:Array=[Vector2(0,3),Vector2(4,3),Vector2(4,1)]
	for i in range(2):g.enemies.append(foe(g,i,Vector2(4,3),"normal",0,route))
	var before_corner:Dictionary=r.layout(g,ORIGIN,TILE)
	g.enemies[0].segment=1
	g.enemies[1].segment=1
	var after_corner:Dictionary=r.layout(g,ORIGIN,TILE)
	check(Vector2(before_corner.units[0].offset).distance_to(after_corner.units[0].offset)<0.01,"corner transition no lateral teleport")
	# Preserve exact last rendered offset for death sprite, no logical mutation.
	var last_offset:Vector2=after_corner.units[0].offset
	g.enemies.remove_at(0)
	r.layout(g,ORIGIN,TILE)
	var vanished:Dictionary={"id":0,"pos":Vector2(4,3),"direction":Vector2.UP,"role":"normal"}
	var death:Vector2=r.death_anchor(vanished,ORIGIN,TILE)
	check(death==ORIGIN+(Vector2(4,3)+Vector2(0.5,0.5))*TILE+last_offset+Vector2(0,13),"death uses same presentation lane")
	check(is_equal_approx(r.death_scale(vanished),float(after_corner.units[0].scale_mul)),"death retains last rendered scale (no crowd-size pop)")
	# Cache resets on next wave, so no stale ID.
	g.wave+=1
	r.layout(g,ORIGIN,TILE)
	var no_cache:Vector2=r.death_anchor(vanished,ORIGIN,TILE)
	check(no_cache!=death and is_equal_approx(r.death_scale(vanished),1.0),"next wave discards stale offset and size id cache")
	# Reorder fixture input: stable IDs and geometry remain exactly identical.
	g.enemies=[]
	for i in range(8):g.enemies.append(foe(g,i,Vector2(float(i)*0.23+2.0,1),"runner" if i%2 else "normal"))
	var ordered:Dictionary=r.layout(g,ORIGIN,TILE)
	g.enemies.reverse()
	var reverse:Dictionary=r.layout(g,ORIGIN,TILE)
	check(var_to_str(ordered)==var_to_str(reverse),"layout independent of input array order")
	var phases:Dictionary={}
	for row in ordered.units.values():phases[row.phase_offset]=true
	check(phases.size()==4,"walk offsets use 4 stable frame phases")
	g.enemies[0].hp=0.0
	var dead:Dictionary=r.layout(g,ORIGIN,TILE)
	check(not dead.units.has(int(g.enemies[0].id)),"dead model entity absent from live health/sprite layout")

func actual_tests()->void:
	# Actual Run.start/step on every changed route/stage/wave; fixture assigns
	# two valid deployed towers toward the late route (delayed kills -> crowd).
	# This is a deterministic stress plan, not a player's unknown choices.
	for stage in range(3):
		for wave in range(2):
			for variant in range(2):
				var g=Run.new()
				g.reset(437)
				g.stage=stage
				g.wave=wave
				g.route_choice=variant if stage==0 else 0
				g.opened=stage==1 and variant==1
				var coords:Array=[Vector2i(10,6),Vector2i(9,6),Vector2i(10,7),Vector2i(8,7),Vector2i(9,3),Vector2i(10,3)]
				for cell in coords:
					if g.reserved(cell):continue
					g.towers.append({"id":g.towers.size()+1,"cell":cell,"kind":1 if g.towers.is_empty() else 0,"rank":3 if variant==1 else 1,"cool":0.0})
					if g.towers.size()>=2:break
				check(g.towers.size()==2 and g.start(),"stress real wave start stage%d wave%d variant%d"%[stage,wave,variant])
				var r=Read.new()
				for it in range(1600):
					if g.phase!="fight":break
					g.step()
					if it%5!=0 or g.enemies.is_empty():continue
					var before:String=shot_snapshot(g)
					var l:Dictionary=r.layout(g,ORIGIN,TILE)
					row_contract(g,l,"actual s%dw%dv%d t%d"%[stage,wave,variant,g.tick_count])
					check(shot_snapshot(g)==before,"actual layout no authoritative mutation")
					geometry_stats(g,l)
					if it%25==0:
						var again:Dictionary=r.layout(g,ORIGIN,TILE)
						check(var_to_str(again)==var_to_str(l),"same tick draw layout stable")
	check(prior_bar_pairs>0 and after_bar_pairs==0,"real samples improve legacy overlapping health bars")
	check(after_overlap<prior_overlap,"nominal role AABB overlap reduced across real sample geometry")

func execute()->void:
	fixture_tests()
	actual_tests()
	var contrast:float=(luminance(Read.HEALTH_FG)+0.05)/(luminance(Read.HEALTH_BG)+0.05)
	check(contrast>=3.0,"health fill/track actual token contrast >=3:1")
	if "--evidence" in OS.get_cmdline_user_args() and not witness.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/p08-readability-evidence"))
		var f:=FileAccess.open("res://docs/p08-readability-evidence/actual-run-dense-sample.json",FileAccess.WRITE)
		if f!=null:f.store_string(JSON.stringify(witness,"  ")+"\n")
	print("P08_READABILITY passed=%d failed=%d sampled_ticks=%d enemies_total=%d max_live=%d prior_aabb_overlap=%.5f after_aabb_overlap=%.5f prior_bar_pairs=%d after_bar_pairs=%d compact_bars=%d"%[passed,failed,sampled_ticks,sampled_enemies,max_live,prior_overlap,after_overlap,prior_bar_pairs,after_bar_pairs,compact_bars])
	quit(1 if failed else 0)
