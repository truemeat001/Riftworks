extends SceneTree
const Run=preload("res://src/Run.gd")
var checks=0
var failures=0
func ck(ok:bool,m:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(m)
func near(a:float,b:float)->bool:return absf(a-b)<0.000001
func enemy(id:int,x:float,role:String="normal",slow:float=0.0,y:float=3.0)->Dictionary:
	return {"id":id,"route":[Vector2(0,y),Vector2(10,y)],"segment":0,"pos":Vector2(x,y),"direction":Vector2.RIGHT,"hp":100.0,"maxhp":100.0,"speed":0.0,"role":role,"boss":false,"slow":slow,"second":false,"hit_tick":-1}
func tower(id:int,kind:int,mode:String="front",pos:Vector2i=Vector2i(5,3))->Dictionary:
	var t={"id":id,"kind":kind,"rank":1,"cell":pos,"cool":0.0,"attack_tick":-1}
	if mode!="front":t.order=mode
	return t
func trial(enemies:Array,towers:Array):
	var r=Run.new();r.reset(437);r.phase="fight";r.towers=towers;r.enemies=enemies;r.pending=1;r.spawn_time=100.0
	return r
func _initialize()->void:
	# SCREEN chooses the unmarked intended target, then actual escort changes recipient.
	var a=enemy(1,7.0,"normal");var g=enemy(2,6.2,"guard",0.6)
	var r=trial([a,g],[tower(10,1,"screen"),tower(11,1,"screen")])
	r.step()
	ck(r.guard_intercepts.size()==1 and r.guard_intercepts[0].intended_id==a.id and r.guard_intercepts[0].guard_id==g.id,"first SCREEN redirects to ready guard")
	ck(near(g.hp,100.0-6.5) and near(a.hp,100.0-6.5),"same-tick second attack respects guard cooldown")
	ck(near(g.slow,0.8) and near(a.slow,0.8),"slow applied once per actual recipient")
	ck(r.shots.size()==2 and r.shots[0].to==g.pos and r.shots[1].to==a.pos,"actual primary destination correct")
	# Escort uses geometry and actual range, not a hidden lane condition.
	a=enemy(1,7.0,"normal");a.second=true
	g=enemy(2,6.7,"guard",0.0,3.7)
	r=trial([a,g],[tower(10,0)])
	r.step()
	ck(r.guard_intercepts.size()==1 and r.guard_intercepts[0].guard_id==g.id,"cross-lane nearby in range guard supported")
	# Chamber: CLUSTER targets actual dense group, Hammer bypasses even ready guards.
	var lead=enemy(1,7.4);var center=enemy(3,5.3,"normal",1.05)
	g=enemy(2,5.6,"guard")
	var side=enemy(4,4.5)
	r=trial([lead,center,g,side],[tower(10,2,"cluster")])
	r.upgrades={"freeze":2}
	r.step()
	ck(r.guard_intercepts.is_empty() and r.guard_ready(g),"Hammer CLUSTER bypasses escort entirely")
	ck(r.shots[0].to==center.pos and near(lead.hp,100.0),"cluster chooses exact dense marked target")
	ck(r.tide_transfers.size()==2 and near(center.slow,0.5) and near(g.slow,0.25) and near(side.slow,0.25),"P08 Tide transfers conserve on actual eligible victims including guard")
	ck(r.shots.size()==3,"no duplicate shot from either mechanism")
	# Brass cannot set heavy but defensive fallback also handles corrupted/manual dictionaries.
	var brass=tower(15,0,"heavy");r=trial([a,g],[brass])
	ck(r.order_of(brass)=="front","unsupported heavy cannot change actual priority")
	ck(not r.set_order(15,"heavy"),"battle cannot assign heavy")
	print("P09 integrated guard/orders/tide checks=",checks," failures=",failures)
	quit(1 if failures else 0)
