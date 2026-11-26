extends SceneTree
const Audio=preload("res://src/GameAudio.gd")
var checks=0
var failures=0
func ck(ok:bool,msg:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(msg)
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var a=Audio.new();root.add_child(a)
	await process_frame
	var names=["Master","SFX","UI","Combat","Alert","Ambience","Music"]
	ck(AudioServer.bus_count==7,"fixed count")
	for i in range(7):
		ck(AudioServer.get_bus_name(i)==names[i],"stable order")
		if i>0:
			ck(AudioServer.get_bus_send(i)==a.BUS_PARENT[names[i]],"parent send")
			ck(AudioServer.get_bus_index(AudioServer.get_bus_send(i))<i,"lower index route")
		ck(is_equal_approx(AudioServer.get_bus_volume_db(i),float(a.BASE_DB[names[i]])),"base gain")
	ck(not a.unlocked and a.voice_counts().Ambience==0,"no autoplay")
	a.set_muted(true)
	ck(not a.test_sound() and not a.unlocked and a.event_history().is_empty(),"muted test does not unlock or emit")
	a.set_muted(false)
	ck(a.test_sound() and a.unlocked,"test requests real cue")
	ck(not a.event_history().is_empty() and a.event_history().back().id=="ui_press" and a.voice_counts().Ambience==2,"test starts two beds and actual UI cue")
	var sea=a._sea
	var bed=a._battle_bed
	for i in range(10):
		await create_timer(0.15).timeout
		if sea.get_playback_position()>0.05:break
	var before=sea.get_playback_position()
	ck(before>0.05,"actual native playback advances")
	a.unlock()
	ck(a._sea==sea and a._battle_bed==bed and a.voice_counts().Ambience==2,"gesture reuses players")
	for i in range(10):
		await create_timer(0.15).timeout
		if sea.get_playback_position()>before:break
	ck(sea.get_playback_position()>before,"another gesture doesn't rewind")
	sea.stop()
	ck(a.test_sound(),"explicit retry emits cue")
	ck(a._sea==sea and a._battle_bed==bed and a.voice_counts().Ambience==2,"retry revives stopped bed only")
	a.set_muted(true)
	var events=a.event_history().size()
	ck(not a.test_sound() and a.event_history().size()==events,"muted retry no cue")
	ck(AudioServer.is_bus_mute(0),"Master muted")
	a.set_muted(false)
	ck(not AudioServer.is_bus_mute(0),"Master restored")
	a.set_volume("UI",0.0)
	ck(AudioServer.is_bus_mute(2),"UI zero muted")
	a.set_volume("UI",1.0)
	ck(not AudioServer.is_bus_mute(2),"UI restored")
	print("WEB_AUDIO_CONTRACT checks=",checks," failures=",failures)
	a.reset_scene()
	sea.stop();bed.stop()
	a.queue_free()
	await create_timer(0.25).timeout
	quit(1 if failures else 0)
