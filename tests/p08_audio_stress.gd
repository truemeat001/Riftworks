extends SceneTree
## Deterministic controller stress fixture with real Godot mixer bus capture.
## The event schedule simulates x2 20 Hz pressure; it is not a playthrough or a browser audio audition.
const Audio=preload("res://src/GameAudio.gd")
const TEST_BUSES=["Master","Combat","Alert","Ambience"]
const ATTACKS=["hit_pulse","hit_frost","hit_burst","kill","conductive","shatter"]
var controller:Node
var caps:Dictionary={}
var samples:Dictionary={}
var markers:Dictionary={}
var bus_peaks:Dictionary={}
var audio_clipped:Dictionary={}
var report:Dictionary={}
func _initialize()->void:call_deferred("run")
func pull()->void:
	for name in TEST_BUSES:
		var cap:AudioEffectCapture=caps[name]
		var frames=cap.get_frames_available()
		if frames<=0:continue
		var data=cap.get_buffer(frames)
		var pcm:PackedByteArray=samples[name]
		var at=pcm.size()
		pcm.resize(at+data.size()*4)
		for i in range(data.size()):
			if absf(data[i].x)>=1.0 or absf(data[i].y)>=1.0:audio_clipped[name]+=1
			pcm.encode_s16(at+i*4,clampi(roundi(data[i].x*32767.0),-32768,32767))
			pcm.encode_s16(at+i*4+2,clampi(roundi(data[i].y*32767.0),-32768,32767))
		samples[name]=pcm
func mark(key:String)->void:
	pull()
	var frames:Dictionary={}
	for name in TEST_BUSES:frames[name]=int(samples[name].size()/4.0)
	markers[key]=frames
func hold(seconds:float)->void:
	var end:int=Time.get_ticks_msec()+roundi(seconds*1000.0)
	while Time.get_ticks_msec()<end:
		await process_frame
		pull()
		OS.delay_msec(4)
func dense(seconds:float)->void:
	# At x2, 20 Hz simulation advances 40 ticks per wall second.
	# Burst each logical tick with all six genuine existing event IDs.
	var duration:int=roundi(seconds*1000.0)
	var begin:int=Time.get_ticks_msec()
	var next_tick:int=0
	while Time.get_ticks_msec()-begin<duration:
		var elapsed:int=Time.get_ticks_msec()-begin
		while next_tick*25<=elapsed:
			for i in range(ATTACKS.size()):controller.play_event(ATTACKS[i],Vector2(float((i+next_tick)%12),float(i%8)),1+(next_tick%3))
			next_tick+=1
		await process_frame
		pull()
		var counts:Dictionary=controller.voice_counts()
		for group in counts:bus_peaks[group]=maxi(int(bus_peaks.get(group,0)),int(counts[group]))
		OS.delay_msec(4)
func active_alerts()->Array:
	var ids:Array=[]
	for v in controller._voices:
		if v.group=="Alert" and is_instance_valid(v.player) and v.player.playing:ids.append(v.id)
	return ids
func save_capture(name:String)->void:
	var data:PackedByteArray=samples[name]
	var w=AudioStreamWAV.new()
	w.format=AudioStreamWAV.FORMAT_16_BITS;w.stereo=true;w.mix_rate=roundi(AudioServer.get_mix_rate());w.data=data
	var err=w.save_to_wav("user://p08-stress-"+name.to_lower()+".wav")
	report["capture_"+name]={"frames":int(data.size()/4.0),"discarded":caps[name].get_discarded_frames(),"float_clipped_frames":audio_clipped[name],"error":err}
func run()->void:
	controller=Audio.new()
	root.add_child(controller)
	await process_frame
	for name in TEST_BUSES:
		var cap=AudioEffectCapture.new();cap.buffer_length=1.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index(name),cap)
		cap.clear_buffer();caps[name]=cap;samples[name]=PackedByteArray();audio_clipped[name]=0
	mark("locked_start");await hold(.32);mark("locked_end")
	report["no_autoplay"]=not controller.unlocked and controller.voice_counts().Ambience==0
	controller.unlock();await hold(.25);mark("unlocked")
	controller.set_battle_active(true);await dense(.5);mark("danger_on")
	controller.set_danger(true,Vector2(11,4));await dense(.95);mark("danger_off")
	controller.set_danger(false);await dense(.5);mark("pause_on")
	controller.set_battle_paused(true)
	report["paused_rejects_combat"]=not controller.play_event("hit_pulse",Vector2(11,4))
	await hold(.4);mark("pause_off")
	controller.set_battle_paused(false);await dense(.2)
	controller.set_battle_active(false);controller.reset_scene();await hold(.2)
	# Alert saturation fixture reproduces real multiple leak notifications close together.
	controller.set_battle_active(true);mark("priority_danger_on")
	controller.set_danger(true,Vector2(11,4));await hold(.07)
	controller.play_event("leak",Vector2(11,4));await hold(.06)
	controller.play_event("leak",Vector2(11,4));await hold(.05)
	var alerts=active_alerts()
	report["priority_active_after_leaks"]=alerts
	report["danger_survives_leaks"]="danger" in alerts
	report["damage_survives"]="leak" in alerts
	var low=controller.play_event("wave_start",Vector2(0,3));await hold(.05)
	report["low_priority_wave_start_accepted"]=low
	report["priority_active_after_wave_start"]=active_alerts()
	await hold(.65);mark("priority_end")
	controller.set_battle_active(false);controller.reset_scene();await hold(.15)
	mark("mute_on");controller.set_muted(true);await hold(.08)
	controller.play_event("ui_press");await hold(.30);mark("mute_off")
	report["engine_master_muted"]=AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	controller.set_muted(false);controller.play_event("ui_press");await hold(.25);mark("unmuted")
	report["engine_master_restored"]=not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	report["dropped_events"]=controller.dropped_events();report["max_voices"]=bus_peaks
	report["capture_markers"]=markers;report["rate"]=roundi(AudioServer.get_mix_rate())
	pull()
	for name in TEST_BUSES:save_capture(name)
	var f=FileAccess.open("user://p08-stress-report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "));f.close()
	print("P08 audio stress report: ",JSON.stringify(report))
	controller.reset_scene();controller._sea.stop();controller._battle_bed.stop()
	await hold(.25)
	controller.queue_free();await process_frame;await process_frame
	quit()
