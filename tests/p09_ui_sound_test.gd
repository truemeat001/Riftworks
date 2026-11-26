extends SceneTree
const Main=preload("res://src/Main.tscn")
var n=0
var fails=0
func ck(ok:bool,msg:String):
	n+=1
	if not ok:fails+=1;push_error(msg)
func _initialize():call_deferred("run")
func snap(ui:Node)->Array:
	return [ui.game.gold,ui.game.rng.state,ui.game.tick_count,ui.game.phase,ui.game.towers.duplicate(true),ui.game.reserve.duplicate(true),ui.selected_id,ui.game.message]
func run():
	var ui=Main.instantiate();root.add_child(ui);await process_frame;ui.set_process(false)
	var a=ui.audio
	ck(not a.unlocked and not ui.test_sound_button.disabled,"sound test enabled before first gesture")
	var source=InputEventMouseButton.new();source.pressed=true;source.button_index=MOUSE_BUTTON_LEFT;ui._input(source)
	var state=snap(ui)
	var old_history=a.event_history().size()
	ui.test_sound_button.pressed.emit()
	var records=a.event_history().slice(old_history)
	ck(records.size()==1 and records[0].id=="ui_press","one explicit test cue, not generic duplicate")
	ck(snap(ui)==state,"model RNG and selection unchanged by cue")
	ck("Test cue requested" in ui.notice,"feedback describes cue request not audible output")
	var bed_count=a.voice_counts().Ambience
	ui.test_sound_button.pressed.emit()
	ck(a.voice_counts().Ambience==bed_count,"retry doesn't add ambient loops")
	ui._toggle_sound();ck(a.is_muted() and ui.test_sound_button.disabled,"mute disables test")
	old_history=a.event_history().size()
	ui.test_sound_button.pressed.emit()
	ck(a.is_muted() and a.event_history().size()==old_history and snap(ui)==state,"muted callback cannot silently unmute, send cue or change model")
	ui._toggle_sound();ck(not a.is_muted() and not ui.test_sound_button.disabled,"unmute enables explicit retry")
	for size in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=size;await process_frame
		var b:Button=ui.test_sound_button
		ck(Rect2(0,0,1280,800).encloses(b.get_global_rect()) and not b.get_global_rect().intersects(ui.sound_button.get_global_rect()),"test sound bounds and tap separation")
		ck(b.size.x>=b.get_minimum_size().x and b.size.y>=b.get_minimum_size().y,"label fits button")
		for phase in ["build","fight","won","lost"]:
			ui.game.phase=phase;ui.refresh();await process_frame
			ck(ui.label_phase.get_line_count()*ui.label_phase.get_line_height()<=ui.label_phase.size.y+1,"phase retained fitting across modes")
	a.reset_scene();a._sea.stop();a._battle_bed.stop();await create_timer(.3).timeout
	ui.queue_free();await process_frame;await process_frame
	print("P09 SOUND UI checks=",n," failures=",fails);quit(fails)
