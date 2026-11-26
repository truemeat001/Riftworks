extends SceneTree
const Main=preload("res://src/Main.tscn")
var fails=0
var checks=0
func ck(ok:bool,msg:String)->void:
	checks+=1
	if not ok:fails+=1;push_error(msg)
func _initialize()->void:call_deferred("run")
func fit(label:Label)->bool:return label.get_line_height()*label.get_line_count()<=label.size.y+1.0
func run()->void:
	var ui=Main.instantiate();root.add_child(ui);await process_frame;await process_frame
	# Fixture forecast at guard-free and guard waves; no gameplay state change from refresh.
	ck(not "Escort:" in ui.label_forecast.text,"no early guard warning")
	for stage in [1,2]:
		for wave in [0,1]:
			ui.game.stage=stage;ui.game.wave=wave;ui.game.opened=stage==1;ui.refresh();await process_frame
			var label:Label=ui.label_forecast
			print("GUARD_UI stage=",stage," wave=",wave," lines=",label.get_line_count()," h=",label.get_line_height()," size=",label.size," text=",label.text)
			ck("Escort:" in label.text and "Brass/Mist" in label.text and "1.2s" in label.text and "Hammer bypass" in label.text,"visible escort rules")
			ck(fit(label),"forecast text contained")
			ck(label.get_global_rect().end.y<=ui.label_selection.get_global_rect().position.y,"forecast above selection")
	# Actual fight step with intercept; event positions and readiness support same UI drawing path.
	ui.game.reset(437);ui.game.stage=1;ui.game.phase="fight";ui.game.pending=1;ui.game.spawn_time=100.0
	ui.game.towers=[{"id":1,"kind":0,"rank":1,"cell":Vector2i(5,3),"cool":0.0,"attack_tick":-1}]
	var route=[Vector2(0,3),Vector2(10,3)]
	var a={"id":1,"hit_tick":-1,"route":route,"pos":Vector2(7,3),"direction":Vector2.RIGHT,"segment":0,"hp":100.0,"maxhp":100.0,"slow":0.0,"role":"normal","boss":false,"speed":0.0,"second":false}
	var g=a.duplicate(true);g.id=2;g.role="guard";g.pos=Vector2(6,3)
	ui.game.enemies=[a,g];ui.game.step();ui.set_process(false);ui.refresh()
	await process_frame
	ck(ui.game.guard_intercepts.size()==1 and not ui.game.guard_ready(g),"actual intercept produces event/readiness")
	ck("Escort ready 0/1" in ui.label_forecast.text,"fight readiness text real count")
	ck(fit(ui.label_forecast),"fight forecast contained")
	ui.queue_free();await process_frame
	print("P09_GUARD_UI checks=",checks," failures=",fails)
	quit(0 if fails==0 else 1)
