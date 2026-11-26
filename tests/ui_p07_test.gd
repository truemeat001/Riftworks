extends SceneTree
const Main=preload("res://src/Main.tscn")
const Run=preload("res://src/Run.gd")
var checks=0
var failures=0
func check(condition:bool,label:String):
	checks+=1
	if not condition:
		failures+=1
		print("FAIL ",label)
func _initialize():call_deferred("run")
func board(ui,cell:Vector2i,pressed:bool):
	var e=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=pressed
	e.position=ui.coord(Vector2(cell))
	ui._input(e)
	ui._unhandled_input(e)
func events(audio,id:String)->int:
	var count=0
	for event in audio.event_history():
		if event.id==id:count+=1
	return count
func run():
	var ui=Main.instantiate()
	root.add_child(ui)
	ui.set_process(false)
	check("Explore for 6 coins" in ui.label_message.text,"novice explore guidance")
	check(ui.start_button.disabled and "DEPLOY" in ui.start_button.text,"visible start disabled reason")
	check(not ui.audio.unlocked,"no sound before gesture")
	var gesture=InputEventKey.new()
	gesture.keycode=KEY_A;gesture.pressed=true
	ui._input(gesture)
	check(ui.audio.unlocked,"first input unlock")
	var state=ui.game.rng.state
	var coins=ui.game.gold
	ui._toggle_sound()
	check(ui.audio.is_muted() and "OFF" in ui.sound_button.text and ui.game.rng.state==state and ui.game.gold==coins,"mute model invariant")
	ui._toggle_sound()
	check(not ui.audio.is_muted() and "ON" in ui.sound_button.text,"unmute")
	ui._explore()
	check(ui.game.gold==18 and ui.game.reserve.size()==1 and events(ui.audio,"chest_charge")==1,"actual draw and charge once")
	var reward=ui.loot_reveal.duplicate(true)
	for i in range(14): ui._process(0.1)
	check(events(ui.audio,"chest_open")==1 and events(ui.audio,"loot_crew")==1 and events(ui.audio,"loot_arrive")==1,"one complete crew reveal audio sequence")
	check(ui.game.gold==18 and ui.loot_reveal==reward,"reveal read-only")
	ui._skip_reveal()
	check(ui.audio.voice_counts().loot==0,"skip clears natural reveal tail as well")
	check("highlighted tile" in ui.label_message.text,"novice deployment guidance")
	var t=ui.get_tower(ui.selected_id)
	var good=Vector2i(1,0)
	ui.hover=good;ui.update_hover()
	var expected=ui.coverage_summary(ui.game.coverage_preview(good,t.kind,t.rank,t.id).lanes,true)
	check(expected in ui.label_feedback.text and "%" in expected,"correct exact coverage preview")
	var blocked=Vector2i(ui.game.path()[0])
	board(ui,blocked,true);board(ui,blocked,false)
	check(ui.game.towers.is_empty() and ui.selected_id==t.id and not ui.notice.is_empty(),"illegal placement preserves selection")
	var rejection=ui.notice
	ui.hover=good;ui.update_hover()
	check(ui.notice==rejection and rejection in ui.label_feedback.text,"durable error after hover")
	board(ui,good,true)
	check(ui.game.towers.is_empty(),"press no deploy")
	board(ui,good,false)
	check(ui.game.towers.size()==1 and events(ui.audio,"deploy")==1,"release deploy and cue once")
	check(not ui.start_button.disabled,"deployed can start")
	var old=ui.game.route_choice
	ui._alter_route()
	check(ui.game.route_choice!=old and "SWITCH" in ui.special_button.text and "Route now" in ui.label_feedback.text,"route toggle visible/reversible")
	ui._alter_route()
	check(ui.game.route_choice==old,"route returns")
	ui._start()
	check(ui.game.phase=="fight" and ui.audio.battle_active and events(ui.audio,"wave_start")==1,"real wave entry cue")
	for i in range(60):ui._process(0.05)
	check(ui.game.tick_count>0 and ui.atmosphere.last_tick==ui.game.tick_count,"logic tick observes atmosphere")
	ui._toggle_pause()
	ui._process(0.1)
	check(ui.audio.battle_paused and ui.paused,"pause synced")
	ui._toggle_pause()
	ui._process(0.1)
	check(not ui.audio.battle_paused and not ui.paused,"resume synced")
	var before_restart=ui.game.tick_count
	ui._restart(false)
	ui._process(0.3)
	check(ui.game.tick_count==before_restart and ui.audio.battle_paused,"pending restart pauses audio and model")
	ui._clear_selection()
	ui._process(0.1)
	check(ui.game.tick_count>before_restart and not ui.audio.battle_paused,"cancel restores previous run")
	var match_seed=0
	for candidate in range(1,100):
		var probe=Run.new();probe.reset(candidate)
		var a:Dictionary=probe.draw_loot();var b:Dictionary=probe.draw_loot()
		if a.tower_kind==b.tower_kind:
			match_seed=candidate
			break
	check(match_seed>0,"seeded matching crew fixture")
	ui.seed_value=match_seed
	ui._restart(false);ui._restart(false)
	ui._process(0.36)
	ui._explore();ui._skip_reveal()
	ui._explore();ui._skip_reveal()
	check(ui.game.reserve.size()==2 and ui.has_merge_partner(ui.get_tower(ui.selected_id)),"actual seeded matching pair")
	var other_id:int=ui.game.reserve[0].id
	ui._toggle_merge()
	ui.merge_hover_id=other_id
	ui.update_hover()
	var merge_cov:Dictionary=ui.game.coverage_merge_preview(ui.selected_id,other_id)
	check(ui.coverage_summary(merge_cov.lanes,true) in ui.label_feedback.text,"exact merge coverage preview")
	ui._select_tower(other_id)
	check(ui.game.reserve.size()==1 and ui.game.reserve[0].rank==2 and events(ui.audio,"merge")>=1,"actual merge and sound once")
	check(ui.loot_feedback_tier({"kind":"tower","rank":1})==0 and ui.loot_feedback_tier({"kind":"core","rank":1})==1 and ui.loot_feedback_tier({"kind":"core","rank":2})==2,"category and actual rank only")
	# Isolated terminal-tick leak fixture: actual Run.step consumes the last station HP.
	var survivor:int=ui.game.reserve[0].id
	ui._select_tower(survivor)
	board(ui,Vector2i(1,0),true);board(ui,Vector2i(1,0),false)
	ui._start()
	var lane:Array=ui.game.path()
	var finish:Vector2=lane[-1]
	var dir:Vector2=(finish-lane[-2]).normalized()
	ui.game.pending=0
	ui.game.pending_main=0
	ui.game.pending_extra=0
	ui.game.hp=1
	ui.game.enemies=[{"route":lane,"pos":finish-dir*0.01,"direction":dir,"segment":lane.size()-2,"id":99,"hit_tick":-1,"hp":1.0,"maxhp":1.0,"slow":0.0,"role":"normal","boss":false,"speed":1.0,"second":false}]
	var leak_before=events(ui.audio,"leak")
	ui._process(0.06)
	var tail=ui.audio.event_history()
	check(ui.game.phase=="lost" and events(ui.audio,"leak")==leak_before+1 and tail[-2].id=="leak" and tail[-1].id=="defeat","final leak cue follows phase cleanup before defeat")
	check(ui.audio.voice_counts().Alert>=1,"final alert voices survive battle group cleanup")
	print("P07 UI checks=",checks," failures=",failures)
	ui.audio.reset_scene()
	ui.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	quit(failures)
