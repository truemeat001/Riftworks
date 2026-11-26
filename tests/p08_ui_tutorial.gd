extends SceneTree
const Main=preload("res://src/Main.tscn")
const Tutorial=preload("res://src/Tutorial.gd")
var checks:int=0
var failures:int=0
func check(c:bool,m:String):
	checks+=1
	if not c:failures+=1;print("FAIL ",m)
func _initialize():call_deferred("run")
func click_board(ui,cell:Vector2i,pressed:bool):
	var e=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=pressed
	e.position=ui.coord(Vector2(cell))
	ui._input(e);ui._unhandled_input(e)
func snapshot(ui)->Dictionary:
	return {"gold":ui.game.gold,"hp":ui.game.hp,"tick":ui.game.tick_count,"stage":ui.game.stage,"wave":ui.game.wave,
		"rng":ui.game.rng.state,"towers":ui.game.towers.duplicate(true),"reserve":ui.game.reserve.duplicate(true),
		"upgrades":ui.game.upgrades.duplicate(true),"route":ui.game.route_choice,"opened":ui.game.opened,
		"phase":ui.game.phase,"selected":ui.selected_id,"core":ui.selected_core,"paused":ui.paused,
		"loot":ui.loot_reveal.duplicate(true)}
func run():
	var ui=Main.instantiate()
	root.add_child(ui)
	ui.set_process(false)
	ui.tutorial.persist_enabled=false
	ui.tutorial.begin(ui.game)
	ui.refresh()
	check(ui.tutorial.active and ui.tutorial.step=="explore" and "GUIDE 1/5" in ui.label_message.text,"first-run guide")
	check("SKIP GUIDE"==ui.tutorial_button.text,"visible skip")
	var opening=snapshot(ui)
	ui._toggle_tutorial()
	check(not ui.tutorial.active and ui.tutorial_button.text=="GUIDE" and snapshot(ui)==opening,"skip no model change")
	ui._toggle_tutorial()
	check(ui.tutorial.active and snapshot(ui)==opening and ui.tutorial.step=="explore","replay no model change")
	ui._explore()
	check(ui.game.gold==18 and ui.game.reserve.size()==1 and ui.selected_id==ui.game.reserve[0].id and ui.tutorial.step=="deploy","real crew advances")
	check(ui.guide_hint_cell.x>=0 and ui.candidate_error(ui.guide_hint_cell,ui.get_tower(ui.selected_id)).is_empty(),"real legal suggestion")
	var picked_id=ui.selected_id
	var paid=snapshot(ui)
	ui._toggle_tutorial()
	check(not ui.tutorial.active and snapshot(ui)==paid and ui.loot_age<ui.LOOT_DURATION,"skip during loot preserves actual reward and presentation")
	ui._toggle_tutorial()
	check(ui.tutorial.step=="deploy" and snapshot(ui)==paid,"replay during active loot")
	ui._skip_reveal()
	ui._clear_selection()
	check(ui.tutorial.step=="deploy" and ui.selected_id==-1 and "portrait" in ui.label_message.text,"guide shows selection after clear")
	ui.reserve_buttons[0].pressed.emit()
	check(ui.selected_id==picked_id and ui.guide_hint_cell.x>=0,"actual portrait select")
	var blocked=Vector2i(ui.game.path()[0])
	click_board(ui,blocked,true);click_board(ui,blocked,false)
	check(ui.tutorial.step=="deploy" and ui.game.towers.is_empty() and ui.selected_id==picked_id and ui.game.gold==18,"invalid tile no progression or loss")
	var legal:Vector2i=ui.guide_hint_cell
	click_board(ui,legal,true)
	check(ui.tutorial.step=="deploy" and ui.game.towers.is_empty(),"press alone no guide advance")
	click_board(ui,legal,false)
	check(ui.tutorial.step=="start" and ui.game.towers.size()==1 and ui.game.gold==18,"actual legal deploy advances")
	check("GUIDE 3/5" in ui.label_message.text and not ui.start_button.disabled,"start discoverable, no required second draw")
	ui._start()
	check(ui.game.phase=="fight" and ui.tutorial.step=="fight","actual start advances")
	ui._toggle_pause()
	var paused_state=snapshot(ui)
	ui._toggle_tutorial();ui._toggle_tutorial()
	check(snapshot(ui)==paused_state and ui.tutorial.active and ui.tutorial.step=="fight","skip/replay preserves paused actual battle")
	ui._toggle_pause()
	for i in range(1200):
		ui._process(0.05)
		if ui.game.phase!="fight":break
	check(ui.game.phase=="build" and ui.tutorial.step=="after_wave" and "GUIDE 5/5" in ui.label_message.text,"actual wave end advances")
	check(ui.game.gold==30 and ui.game.towers.size()==1,"no forced extra spend")
	var wave_gold=ui.game.gold
	ui._alter_route()
	check(not ui.tutorial.active and ui.tutorial.step=="done" and ui.game.gold==wave_gold,"free route action completes guide")
	ui._toggle_tutorial()
	check(ui.tutorial.active and ui.tutorial.step=="start" and ui.game.gold==wave_gold,"replay current context, not initial reset")
	ui._sell_selected_tower()
	check(not ui.sell_confirm.is_empty() and not "GUIDE" in ui.label_message.text,"danger confirmation takes precedence")
	var confirm_snapshot=snapshot(ui)
	ui._toggle_tutorial()
	check(ui.sell_confirm.is_empty() and snapshot(ui)==confirm_snapshot,"guide control cancels confirm without loss")
	ui._toggle_tutorial()
	ui._restart(false)
	check(not ui.restart_confirm.is_empty(),"restart confirmation remains")
	var before=snapshot(ui)
	ui._clear_selection()
	check(ui.restart_confirm.is_empty() and snapshot(ui)==before,"Esc/CANCEL confirmation preserves guide state and run")
	ui._recall()
	check(ui.game.towers.is_empty() and ui.game.reserve.size()==1 and ui.tutorial.step=="deploy","all recalled returns deploy guidance")
	ui._select_tower(ui.game.reserve[0].id)
	click_board(ui,ui.guide_hint_cell,true);click_board(ui,ui.guide_hint_cell,false)
	check(ui.tutorial.step=="start" and ui.game.towers.size()==1,"redeploy guide recovers")
	# Terminal presentation fixture: replay never resets the actual run.
	ui.game.phase="lost";ui.refresh()
	check(not ui.tutorial.active,"terminal ends the guide")
	var terminal=snapshot(ui)
	ui._toggle_tutorial()
	check(ui.tutorial.active and ui.tutorial.step=="terminal" and snapshot(ui)==terminal,"terminal replay is non-destructive")
	ui._restart(false)
	check(ui.game.phase=="build" and ui.game.gold==24 and ui.tutorial.active and ui.tutorial.step=="explore","terminal retry restarts active guide")
	ui._process(0.36)
	ui._toggle_tutorial()
	ui._restart(false)
	check(not ui.tutorial.active and ui.game.gold==24,"skipped guide stays skipped through untouched retry")
	# Isolated preference roundtrip: no production preference is written by this test.
	var prefs=Tutorial.new();prefs.preference_path="user://p08-tutorial-test.cfg"
	prefs.skip()
	var loaded=Tutorial.new();loaded.preference_path=prefs.preference_path;loaded.load_preference()
	check(not loaded.active and loaded.dismissed,"dismissal persisted")
	loaded.begin(ui.game)
	check(loaded.active and loaded.step=="explore","saved dismissal can replay")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.preference_path))
	for size in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=size
		await process_frame
		var scale=root.get_final_transform().x.x
		check(is_equal_approx(scale,float(size.x)/1280.0),"viewport transforms")
		var control=ui.tutorial_button.get_global_rect()
		check(Rect2(0,0,1280,800).encloses(control) and control.size.y>=32,"visible guide button logical bounds")
	print("P08 tutorial checks=",checks," failures=",failures)
	ui.audio.reset_scene();ui.queue_free()
	await process_frame;await process_frame;await create_timer(0.2).timeout
	quit(failures)
