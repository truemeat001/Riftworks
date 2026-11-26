extends SceneTree
const Run=preload("res://src/Run.gd")
var checks=0
var failures=0

func expect(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)

func near(a:float,b:float,epsilon:float=0.00002)->bool:
	return absf(a-b)<=epsilon

func state(r)->Dictionary:
	return {"rng":r.rng.state,"gold":r.gold,"hp":r.hp,"stage":r.stage,"wave":r.wave,"phase":r.phase,"opened":r.opened,"route_choice":r.route_choice,"tick":r.tick_count,"next_id":r.next_tower_id,"towers":r.towers.duplicate(true),"reserve":r.reserve.duplicate(true),"upgrades":r.upgrades.duplicate(true),"shots":r.shots.duplicate(true),"deaths":r.deaths.duplicate(true),"enemies":r.enemies.duplicate(true),"message":r.message,"loot":r.last_loot.duplicate(true)}

func tower(id:int,kind:int,rank:int,cell:Vector2i)->Dictionary:
	return {"id":id,"kind":kind,"rank":rank,"cell":cell,"cool":0.0,"attack_tick":-1}

func verify_math()->void:
	var r=Run.new()
	expect(near(r._covered_segment(Vector2.ZERO,Vector2(10,0),[{"center":Vector2(5,0),"radius":3.0}]),6.0),"centered chord")
	expect(near(r._covered_segment(Vector2.ZERO,Vector2(10,0),[{"center":Vector2(5,3),"radius":5.0}]),8.0),"Pythagorean off-center chord")
	expect(near(r._covered_segment(Vector2.ZERO,Vector2(10,0),[{"center":Vector2(5,2),"radius":2.0}]),0.0),"tangent contributes no length")
	expect(near(r._covered_segment(Vector2.ZERO,Vector2(10,0),[{"center":Vector2(0,0),"radius":3.0}]),3.0),"clipped endpoints")
	expect(near(r._covered_segment(Vector2.ZERO,Vector2(0,10),[{"center":Vector2(0,5),"radius":3.0}]),6.0),"vertical segment")
	expect(near(r._covered_segment(Vector2.ZERO,Vector2(10,0),[{"center":Vector2(3,0),"radius":2.0},{"center":Vector2(5,0),"radius":2.0}]),6.0),"overlap union not sum")
	expect(near(r._covered_segment(Vector2.ZERO,Vector2(10,0),[{"center":Vector2(2,0),"radius":1.0},{"center":Vector2(8,0),"radius":1.0}]),4.0),"disjoint intervals")
	expect(near(r._covered_segment(Vector2.ZERO,Vector2(10,0),[{"center":Vector2(5,0),"radius":20.0}]),10.0),"clamps to path length")
	expect(near(r._covered_segment(Vector2.ZERO,Vector2.ZERO,[{"center":Vector2.ZERO,"radius":10.0}]),0.0),"degenerate segment")
	expect(near(r._covered_segment(Vector2.ZERO,Vector2(10,0),[]),0.0),"empty layout")

func compare_prediction(r,pred:Dictionary)->void:
	var actual=r.coverage_current()
	expect(pred.valid and pred.lanes.size()==actual.size(),"prediction and actual count")
	for i in range(actual.size()):
		var lane=pred.lanes[i]
		expect(lane.id==actual[i].id and near(lane.length,actual[i].length),"same active lane")
		expect(near(lane.team_after,actual[i].covered),"predicted union matches actual post-action range")
		expect(near(lane.delta,lane.team_after-lane.team_before),"delta arithmetic")
		expect(lane.team_after>=0.0 and lane.team_after<=lane.length+0.00002,"union within lane length")
		expect(lane.unit_covered>=0.0 and lane.unit_covered<=lane.length+0.00002,"candidate within lane length")

func verify_preview()->void:
	var r=Run.new();r.reset(437)
	expect(r.coverage_current().size()==1 and r.coverage_current()[0].id=="main" and near(r.coverage_current()[0].covered,0.0),"initial active main only")
	var a=r.draw_loot()
	var old=state(r)
	var p=r.coverage_preview(Vector2i(5,3),a.tower_kind,1,a.id)
	expect(p.valid and p.lanes[0].team_after>0.0 and near(p.lanes[0].team_before,0.0),"owned reservation preview")
	expect(state(r)==old,"placement preview no mutation incl RNG")
	expect(r.deploy(a.id,Vector2i(5,3)),"actual deployment")
	compare_prediction(r,p)
	old=state(r)
	p=r.coverage_preview(Vector2i(5,3),a.tower_kind,1,a.id)
	expect(p.valid and near(p.lanes[0].delta,0.0),"same position no coverage change")
	expect(state(r)==old,"same position preview no mutation")
	for cell in [Vector2i(-1,0),Vector2i(0,3)]:
		p=r.coverage_preview(cell,a.tower_kind,1,a.id)
		expect(not p.valid and p.lanes.is_empty() and not p.reason.is_empty(),"invalid cell rejected")
	expect(not r.coverage_preview(Vector2i(5,3),a.tower_kind,4,a.id).valid,"invalid rank rejected")
	expect(not r.coverage_preview(Vector2i(5,3),(a.tower_kind+1)%3,1,a.id).valid,"mismatched kind rejected")
	expect(not r.coverage_preview(Vector2i(6,3),a.tower_kind,1,999).valid,"missing unit rejected")
	expect(state(r)==old,"invalid previews no mutation")
	r.alter()
	expect(r.coverage_current().size()==1 and near(r.coverage_current()[0].length,14.0),"selected alternative only")
	expect(r.start(),"start with legal unit")
	expect(not r.coverage_preview(Vector2i(5,3),a.tower_kind,1,a.id).valid,"fight disallows placement proposal")

func verify_layout()->void:
	# Isolated fixture with valid placements; exercises relay changes after movement
	# and amplifier bonuses through the real range formula, not through injected damage.
	var r=Run.new();r.reset(437);r.stage=1;r.opened=true
	r.towers=[tower(1,0,1,Vector2i(2,2)),tower(2,1,2,Vector2i(3,2))]
	r.reserve=[tower(3,2,3,Vector2i(-1,-1))]
	r.upgrades={"relay":2,"range":1}
	var old=state(r);var p=r.coverage_preview(Vector2i(3,5),1,2,2)
	expect(p.valid and p.lanes.size()==2 and p.lanes[1].id=="extra","open rift exposes distinct lane")
	expect(state(r)==old,"dual-lane proposal no mutation")
	expect(r.deploy(2,Vector2i(3,5)),"real move")
	compare_prediction(r,p)
	r.alter()
	expect(r.coverage_current().size()==1,"closed rift hides inactive extra")
	r.stage=2;r.towers.clear();r.reserve=[tower(3,2,3,Vector2i(-1,-1))]
	p=r.coverage_preview(Vector2i(4,2),2,3,3)
	expect(p.valid,"nearby amplifier position feasible")
	expect(r.deploy(3,Vector2i(4,2)),"deploy near amplifier")
	expect(r.stats(r.towers[0])[4],"actual amplifier active")
	compare_prediction(r,p)

func verify_merge()->void:
	for mode in range(3):
		var r=Run.new();r.reset(437);r.stage=1;r.opened=true
		var a=tower(1,0,1,Vector2i(2,2) if mode==0 else Vector2i(-1,-1))
		var b=tower(2,0,1,Vector2i(2,5) if mode!=2 else Vector2i(-1,-1))
		for t in [a,b]:
			if t.cell.x>=0:r.towers.append(t)
			else:r.reserve.append(t)
		r.towers.append(tower(3,2,1,Vector2i(3,2)));r.upgrades={"relay":1}
		var old=state(r);var p=r.coverage_merge_preview(1,2)
		expect(p.valid,"legal pair merge preview mode %d"%mode)
		expect(state(r)==old,"merge preview no mutation")
		expect(not r.coverage_merge_preview(1,1).valid,"same pair rejected")
		expect(not r.coverage_merge_preview(1,3).valid,"different kind rejected")
		expect(state(r)==old,"invalid merge preview atomic")
		expect(r.merge_towers(1,2),"actual merge")
		compare_prediction(r,p)
		if mode==0:expect(p.lanes[1].delta<0.0,"split-role merge loses lower-lane coverage")
		if mode==2:expect(near(p.lanes[0].delta,0.0) and near(p.lanes[1].delta,0.0),"reserve-only merge has no deployed effect")

func verify_sampled_geometry()->void:
	# Independent numerical midpoint sample checks union across all stage variants.
	var r=Run.new();r.reset(437)
	var layouts=[
		[tower(1,0,1,Vector2i(2,2)),tower(2,1,2,Vector2i(5,3))],
		[tower(1,0,3,Vector2i(3,2)),tower(2,2,2,Vector2i(7,5))],
		[tower(1,1,1,Vector2i(2,2)),tower(2,2,1,Vector2i(3,2)),tower(3,0,2,Vector2i(6,5))]]
	for stage in range(3):
		r.stage=stage
		for variant in range(2):
			r.route_choice=variant;r.opened=variant==1
			for layout in layouts:
				r.towers=layout
				r.upgrades={"range":1,"relay":1} if variant==1 else {}
				var routes=[r.path()]
				if stage==1 and r.opened: routes.append(r.path(false))
				var results=r.coverage_current()
				for lane_index in range(routes.size()):
					var sample=0.0;var route=routes[lane_index]
					for i in range(route.size()-1):
						var length:float=route[i].distance_to(route[i+1]);var steps=maxi(1,ceili(length*1000))
						for k in range(steps):
							var v:Vector2=route[i].lerp(route[i+1],(float(k)+0.5)/float(steps))
							for t in r.towers:
								if v.distance_to(Vector2(t.cell))<=float(r.stats(t)[1]):
									sample+=length/float(steps)
									break
					expect(near(sample,results[lane_index].covered,0.012),"independent midpoint sample agrees stage %d lane %d"%( [stage,lane_index]))

func _initialize()->void:
	verify_math()
	verify_preview()
	verify_layout()
	verify_merge()
	verify_sampled_geometry()
	print("P07 gameplay coverage checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
