extends SceneTree
## Real Main + Run callback integration, scripted first wave with deliberately weak coverage at 2x.
## Uses actual Godot software mixer (Master effect input); no physical device or human listening claim.
const Main=preload("res://src/Main.tscn")
var capture:AudioEffectCapture
var pcm=PackedByteArray()
var float_clips:int=0
var failures:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
	if not ok:failures+=1;push_error(msg)
func pull()->void:
	var n=capture.get_frames_available()
	if n<=0:return
	var frames=capture.get_buffer(n);var old=pcm.size();pcm.resize(old+frames.size()*4)
	for i in range(frames.size()):
		if absf(frames[i].x)>=1.0 or absf(frames[i].y)>=1.0:float_clips+=1
		pcm.encode_s16(old+4*i,clampi(roundi(frames[i].x*32767.0),-32768,32767))
		pcm.encode_s16(old+4*i+2,clampi(roundi(frames[i].y*32767.0),-32768,32767))
func hold(sec:float)->void:
	var deadline=Time.get_ticks_msec()+roundi(sec*1000.0)
	while Time.get_ticks_msec()<deadline:
		await process_frame;pull();OS.delay_msec(4)
func click_board(ui:Node,cell:Vector2i)->void:
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=ui.coord(Vector2(cell));e.pressed=true
	ui._input(e);ui._unhandled_input(e)
	e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=ui.coord(Vector2(cell));e.pressed=false
	ui._input(e);ui._unhandled_input(e)
func run()->void:
	var ui=Main.instantiate();root.add_child(ui);await process_frame
	capture=AudioEffectCapture.new();capture.buffer_length=1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"),capture)
	capture.clear_buffer();ui.seed_value=7;ui.game.reset(7);ui.atmosphere.reset(ui.game);ui.refresh()
	await hold(.3)
	check(not ui.audio.unlocked and ui.audio.voice_counts().Ambience==0,"Main ready must not auto-unlock")
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=ui.explore_button.get_global_rect().get_center();e.pressed=true
	ui._input(e);ui.explore_button.pressed.emit()
	await hold(1.5)
	check(ui.audio.unlocked and ui.game.reserve.size()==1 and ui.game.gold==18,"gesture unlock and one authoritative draw")
	var t:Dictionary=ui.game.reserve[0]
	var best:float=INF;var selected=Vector2i(-1,-1)
	for y in range(8):
		for x in range(12):
			var cell=Vector2i(x,y)
			var why:String=ui.game.placement_error(cell,t.kind,t.id)
			if not why.is_empty():continue
			var report:Dictionary=ui.game.coverage_preview(cell,t.kind,t.rank,t.id)
			if not report.valid:continue
			var score:float=0
			for lane in report.lanes:score+=float(lane.unit_covered)
			if score<best:best=score;selected=cell
	check(selected.x>=0,"valid weak tile selected")
	ui.selected_id=t.id;click_board(ui,selected)
	check(ui.game.towers.size()==1 and ui.game.reserve.is_empty(),"actual board deploy callback")
	ui._toggle_speed();check(ui.speed==2.0,"actual x2 switch")
	ui._start();check(ui.game.phase=="fight","actual wave start")
	await hold(.8)
	ui._toggle_pause();await hold(.1);var tick_before:int=ui.game.tick_count
	await hold(.35)
	check(ui.paused and ui.game.tick_count==tick_before and ui.audio.battle_paused,"pause freezes model and combat audio")
	ui._toggle_pause();await hold(.4)
	check(not ui.paused and ui.game.tick_count>tick_before,"model resumes")
	ui._toggle_sound();var mute_tick:int=ui.game.tick_count
	await hold(.35)
	check(ui.audio.is_muted() and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) and ui.game.tick_count>mute_tick,"mute toggles actual bus and does not freeze model")
	ui._toggle_sound();check(not ui.audio.is_muted(),"unmute")
	var deadline=Time.get_ticks_msec()+30000
	while ui.game.phase=="fight" and Time.get_ticks_msec()<deadline:await hold(.2)
	await hold(.45)
	check(ui.game.phase!="fight" and ui.game.run_leaks>0,"weak actual wave induced leak")
	var histogram:Dictionary={}
	for v in ui.audio.event_history():histogram[v.id]=int(histogram.get(v.id,0))+1
	check(int(histogram.get("danger",0))>=1 and int(histogram.get("leak",0))>=1,"actual model danger+leak audio binds")
	check(int(histogram.get("chest_charge",0))==1 and int(histogram.get("loot_crew",0))==1 and int(histogram.get("loot_relic",0))==0,"actual loot category")
	check(int(histogram.get("deploy",0))==1 and int(histogram.get("wave_start",0))==1,"actual deploy/start cues")
	check(int(histogram.get("wave_clear",0))+int(histogram.get("defeat",0))+int(histogram.get("victory",0))==1,"real completion cue")
	var stream=AudioStreamWAV.new();stream.data=pcm;stream.mix_rate=roundi(AudioServer.get_mix_rate());stream.stereo=true;stream.format=AudioStreamWAV.FORMAT_16_BITS
	var save=stream.save_to_wav("user://p08-main-mixed.wav")
	var report={"events":histogram,"wave_phase":ui.game.phase,"real_leaks":ui.game.run_leaks,"real_hp":ui.game.hp,"speed":ui.speed,"weak_coverage":best,"selected_cell":str(selected),"ticks":ui.game.tick_count,"first_gesture_unlocked":ui.audio.unlocked,"float_clips":float_clips,"discarded_frames":capture.get_discarded_frames(),"save":save,"failures":failures}
	var f=FileAccess.open("user://p08-main-audio.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("P08 MAIN AUDIO: ",JSON.stringify(report))
	ui.audio.reset_scene();ui.audio._sea.stop();ui.audio._battle_bed.stop();await hold(.25)
	ui.queue_free();await process_frame;await process_frame
	quit(0 if failures==0 and save==OK and float_clips==0 else 1)
