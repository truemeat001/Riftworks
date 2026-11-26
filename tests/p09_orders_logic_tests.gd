extends SceneTree
const Run=preload("res://src/Run.gd")
var checks=0
var failures=0
func check(c:bool,m:String):
	checks+=1
	if not c:failures+=1;print("FAIL ",m)
func _initialize():call_deferred("run")
func enemy(id:int,x:float,hp:float,slow:float,y:float=0.0)->Dictionary:
	var route:Array[Vector2]=[Vector2(0,y),Vector2(11,y)]
	return {"id":id,"route":route,"segment":0,"pos":Vector2(x,y),"direction":Vector2.RIGHT,
		"hp":hp,"maxhp":hp,"slow":slow,"role":"normal","boss":false,"speed":1.0,"second":false,"hit_tick":-1}
func model_snapshot(g)->Dictionary:
	return {"gold":g.gold,"rng":g.rng.state,"towers":g.towers.duplicate(true),"reserve":g.reserve.duplicate(true),"message":g.message}
func run():
	var g=Run.new()
	g.reset(437)
	var reward:Dictionary=g.draw_loot()
	var id:int=reward.id
	var t:Dictionary=g.reserve[0]
	check(not t.has("order") and g.order_of(t)=="front","absent order default Front")
	var before=model_snapshot(g)
	check(not g.set_order(-999,"front") and not g.set_order(id,"invalid") and model_snapshot(g)==before,"invalid id/mode unchanged")
	var alt:String=g.available_orders(t.kind)[1]
	check(g.available_orders(0)==["front"] and g.available_orders(1)==["front","screen"] and g.available_orders(2)==["front","cluster"],"exact approved orders; no heavy")
	for bad in ["heavy","screen","cluster"]:
		if bad!=alt:check(not g.set_order(id,bad) and model_snapshot(g)==before,"wrong role order rejected")
	check(g.set_order(id,alt) and g.order_of(t)==alt and g.gold==before.gold and g.rng.state==before.rng,"build reserve order free")
	var set_snapshot=model_snapshot(g)
	check(g.set_order(id,alt) and model_snapshot(g)==set_snapshot,"no-op idempotent")
	check(g.set_order(id,"front") and not t.has("order"),"Front erases optional key")
	check(g.set_order(id,alt) and g.deploy(id,Vector2i(1,0)) and g.order_of(t)==alt,"deploy preserves order")
	check(g.recall(id) and g.order_of(t)==alt,"recall preserves order")
	check(g.deploy(id,Vector2i(1,0)) and g.start(),"start fixture")
	before=model_snapshot(g)
	check(not g.set_order(id,"front") and model_snapshot(g)==before,"fight edit rejected")
	# Pure targeting fixtures, exact actual-distance semantics.
	g.reset(437)
	var synthetic={"id":1,"kind":0,"rank":1,"cell":Vector2i(5,0)}
	g.enemies=[enemy(30,8.5,10,0),enemy(20,5.0,80,0),enemy(10,5.3,80,0)]
	check(g.choose_target(synthetic,6).id==30,"front nearest exit")
	synthetic.order="heavy"
	check(g.order_of(synthetic)=="front" and g.choose_target(synthetic,6).id==30,"unapproved heavy raw field cannot override Front")
	g.enemies=[enemy(20,5,80,0),enemy(10,5,80,0)]
	synthetic.kind=1;synthetic.order="screen"
	check(g.choose_target(synthetic,6).id==10,"alternate equal-distance stable spawn-ID tie")
	synthetic.erase("order")
	check(g.choose_target(synthetic,6).id==20,"front exact old array-order tie")
	g.enemies=[enemy(30,8,100,2.0),enemy(20,6,10,0),enemy(10,5,12,0)]
	synthetic.kind=1;synthetic.order="screen"
	check(g.choose_target(synthetic,6).id==20,"screen currently unslowed nearest exit")
	g.enemies[1].slow=1.0;g.enemies[2].slow=1.0
	check(g.choose_target(synthetic,6).id==30,"screen all slowed fallback front")
	g.enemies=[enemy(30,9,100,0),enemy(20,5,40,0),enemy(10,4.3,40,0),enemy(11,5.7,40,0)]
	synthetic.kind=2;synthetic.order="cluster"
	check(g.choose_target(synthetic,6).id==20,"cluster chooses max actual splash victims")
	g.enemies=[enemy(20,5,40,0),enemy(10,4.3,40,0),enemy(11,6.25,40,0),enemy(12,5.1,0,0)]
	check(g._cluster_score(g.enemies[0],1)==1,"cluster no dead victims, base radius")
	g.enemies[0].slow=1.0
	check(g._cluster_score(g.enemies[0],1)==2,"cluster marked prospective splash radius")
	synthetic.kind=1;synthetic.order="screen";g.enemies=[enemy(40,11,1000,0),enemy(10,5,10,0)]
	check(g.choose_target(synthetic,1).id==10,"screen cannot target out of range")
	# Isolated real Run.step fixtures verify the selected primary shot, not just helper scoring.
	for kind in [1,2]:
		g.reset(437)
		g.towers=[{"id":1,"kind":kind,"rank":1,"cell":Vector2i(5,0),"cool":0.0,"attack_tick":-1}]
		var mode:String=g.available_orders(kind)[1]
		check(g.set_order(1,mode) and g.start(),"actual alternate fixture starts")
		g.pending=0;g.pending_main=0;g.pending_extra=0
		var expected_id:int
		match kind:
			1:
				g.enemies=[enemy(30,7.4,100,2.0),enemy(20,6.0,80,0),enemy(10,5.0,100,0)]
				expected_id=20
			2:
				g.enemies=[enemy(30,7.4,100,0),enemy(20,5.0,100,0),enemy(10,4.3,100,0),enemy(11,5.7,100,0)]
				expected_id=20
		g.step()
		var chosen:Dictionary={}
		for e in g.enemies:
			if int(e.id)==expected_id:chosen=e
		check(not chosen.is_empty() and not g.shots.is_empty() and g.shots[0].to==chosen.pos,"actual primary shot honors "+mode)
	# Stage transition uses the real step/return-to-reserve path.
	g.reset(437)
	g.wave=1
	g.towers=[{"id":1,"kind":1,"rank":1,"cell":Vector2i(1,0),"cool":0.0,"attack_tick":-1}]
	check(g.set_order(1,"screen") and g.start(),"stage fixture set")
	g.pending=0;g.pending_main=0;g.pending_extra=0
	g.step()
	check(g.stage==1 and g.towers.is_empty() and g.reserve[0].id==1 and g.order_of(g.reserve[0])=="screen","season recall preserves order")
	# Find an actual deterministic matching draw pair and test surviving identity.
	var match_seed=0
	for seed in range(1,100):
		g.reset(seed)
		var a:Dictionary=g.draw_loot();var b:Dictionary=g.draw_loot()
		if a.tower_kind==b.tower_kind and a.tower_kind!=0:
			match_seed=seed
			break
	check(match_seed>0,"matching draw fixture")
	var a:Dictionary=g.reserve[0];var b:Dictionary=g.reserve[1]
	var survivor:int=a.id;var consumed:int=b.id
	alt=g.available_orders(a.kind)[1]
	check(g.set_order(survivor,alt) and g.deploy(consumed,Vector2i(1,0)),"merge setup")
	var coins:int=g.gold;var rng=g.rng.state
	check(g.merge_towers(survivor,consumed) and g.towers[0].id==survivor and g.towers[0].rank==2 and g.order_of(g.towers[0])==alt and g.gold==coins and g.rng.state==rng,"merge survivor keeps its own order and inherited position")
	check(g.sell_tower(survivor) and g.towers.is_empty(),"sale removes order with unit")
	g.reset(437)
	for i in range(2):g.draw_loot()
	var brass=g.reserve.filter(func(v):return v.kind==0)[0]
	before=model_snapshot(g)
	for bad in ["heavy","screen","cluster"]:
		check(not g.set_order(brass.id,bad) and model_snapshot(g)==before,"Brass can never set alternate "+bad)
	check(g.set_order(brass.id,"front") and not brass.has("order"),"Brass Front no optional field")
	print("P09 ORDERS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
