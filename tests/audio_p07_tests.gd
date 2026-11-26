extends SceneTree
const AudioController=preload("res://src/GameAudio.gd")
var fails=0
var n=0
func check(condition:bool,msg:String)->void:
	n+=1
	if not condition:
		fails+=1;push_error(msg)
func ids(a:Node)->Array:
	var result:Array=[]
	for e in a.event_history():result.append(e.id)
	return result
func new_ids(a:Node,at:int)->Array:return ids(a).slice(at)
func _initialize()->void:
	call_deferred("_go")
func _go()->void:
	var a=AudioController.new()
	root.add_child(a)
	await process_frame
	check(not a.unlocked,"no auto unlock")
	check(a.voice_counts().Ambience==0,"no autobed")
	check(not a.play_event("ui_press"),"non-gesture event refused")
	for bus in ["Master","SFX","UI","Combat","Alert","Ambience","Music"]:
		check(AudioServer.get_bus_index(bus)>=0,"bus "+bus)
	for bus in ["UI","Combat","Alert"]:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus))=="SFX","SFX route "+bus)
	for bus in ["SFX","Ambience","Music"]:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus))=="Master","Master route "+bus)
	var count=0
	for event in a.VARIANTS:
		var streams:Array=a._streams[event]
		check(streams.size()==int(a.VARIANTS[event]),"missing event variant "+event)
		for s in streams:
			count+=1
			check(s.format==AudioStreamWAV.FORMAT_16_BITS and s.mix_rate==48000 and not s.stereo,"bad runtime mono "+event)
			check(s.get_length()>0.05 and s.loop_mode==AudioStreamWAV.LOOP_DISABLED,"invalid duration/loop: "+event)
	check(count==40,"40 one-shot streams")
	for p in [a._sea,a._battle_bed]:
		var s:AudioStreamWAV=p.stream
		check(s.stereo and s.mix_rate==48000 and s.format==AudioStreamWAV.FORMAT_16_BITS,"ambient format")
		check(s.loop_mode==AudioStreamWAV.LOOP_FORWARD and s.loop_begin==0 and s.loop_end==576000,"loop indexes")
	a.unlock()
	for i in range(16):
		await process_frame
		OS.delay_msec(12)
	check(a.unlocked and a.voice_counts().Ambience==2,"bed playback")
	var play_pos:float=a._sea.get_playback_position()
	print("P07_AUDIO_DUMMY_SEA_POSITION=",play_pos)
	check(play_pos>0.03,"engine playback cursor didn't advance")
	# Six event contract across exact three result categories. No random selection in audio.
	for test in [{"kind":"tower","rank":1,"want":"loot_crew"},{"kind":"core","rank":1,"want":"loot_relic"},{"kind":"core","rank":2,"want":"loot_upgrade"}]:
		var start:int=ids(a).size()
		a.start_loot(test)
		a.advance_loot(.31)
		check(new_ids(a,start)==["chest_charge"],"charge only until .32")
		a.advance_loot(.32)
		check(new_ids(a,start)==["chest_charge","chest_open"],"open exactly at .32")
		a.advance_loot(.34)
		a.advance_loot(.8)
		a.advance_loot(1.21)
		check(new_ids(a,start)==["chest_charge","chest_open",test.want],"result exactly one actual category")
		a.advance_loot(1.22); a.advance_loot(1.35); a.advance_loot(1.40)
		check(new_ids(a,start)==["chest_charge","chest_open",test.want,"loot_arrive"],"arrive once")
		a.skip_loot()
		check(a.voice_counts().loot==0,"skip removes loot tails")
	var start:int=ids(a).size()
	a.start_loot({})
	a.advance_loot(.34)
	check(ids(a).size()==start,"failure no audio")
	a.start_loot({"kind":"tower","rank":1});a.advance_loot(.32);a.skip_loot();a.advance_loot(.34)
	check(new_ids(a,start)==["chest_charge","chest_open"],"skipped reward isn't replayed")
	start=ids(a).size()
	a.start_loot({"kind":"core","rank":2});a.advance_loot(1.35)
	check(new_ids(a,start)==["chest_charge"] and a.voice_counts().loot==0,"background jump suppresses stale cues")
	check(not a.play_event("hit_pulse",Vector2(2,3)),"no ghost combat in build")
	a.set_battle_active(true)
	check(a.play_event("hit_pulse",Vector2(2,3)),"actual first hit accepted")
	check(not a.play_event("hit_pulse",Vector2(2,3)),"same event gap suppresses storm")
	check(a.play_event("hit_frost",Vector2(4,3)),"different hit accepted")
	check(a.play_event("hit_burst",Vector2(8,4)),"burst accepted")
	check(a.play_event("kill",Vector2(6,4)),"kill accepted")
	check(a.play_event("conductive",Vector2(6,4)),"conductive accepted")
	check(a.play_event("shatter",Vector2(6,4)),"shatter accepted")
	check(a.voice_counts().Combat<=6 and a.dropped_events()>=1,"combat bounded")
	var direct=false
	for v in a._voices:
		if v.id=="hit_pulse":
			direct=v.player is AudioStreamPlayer2D and v.player.position.is_equal_approx(Vector2(242,326))
	check(direct,"real cell to 2D coordinate")
	start=ids(a).size()
	a.set_danger(true);a.set_danger(true)
	check(new_ids(a,start)==["danger"],"one danger edge")
	a._process(.15)
	check(is_equal_approx(a._duck,-4),"duck reaches -4dB")
	a.set_danger(false);a.set_danger(true)
	check(new_ids(a,start)==["danger"],"danger cooldown suppresses chatter")
	a.set_battle_paused(true)
	check(not a.play_event("hit_burst",Vector2(2,3)),"paused no new combat")
	a.set_battle_paused(false);a.set_danger(false);a._process(.5)
	check(is_equal_approx(a._duck,0),"duck released")
	a.set_volume("UI",.4)
	check(is_equal_approx(a.get_volume("UI"),.4),"volume saved within run")
	a.set_muted(true)
	check(a.is_muted() and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"mute actual master")
	a.set_volume("Master",0.0);a.set_muted(false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"unmute keeps zero fader silent")
	a.set_volume("Master",1.0)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"fader restores master")
	a.set_battle_active(false)
	check(a.voice_counts().Combat==0 and a.voice_counts().Alert==0 and not a.danger_active,"end clears battles")
	check(a.play_event("wave_clear"),"clear cue remains")
	a.reset_scene()
	check(a.voice_counts().UI==0 and a.voice_counts().loot==0 and a.voice_counts().Combat==0 and a.voice_counts().Alert==0,"restart clears old scene")
	check(a.get_volume("UI")==.4 and a.unlocked,"scene reset keeps audio user config")
	print("AUDIO P07 checks=",n," failures=",fails," dropped=",a.dropped_events())
	a._sea.stop();a._battle_bed.stop()
	for k in range(25):
		await process_frame
		OS.delay_msec(10)
	a.queue_free()
	await process_frame
	await process_frame
	quit(0 if fails==0 else 1)
