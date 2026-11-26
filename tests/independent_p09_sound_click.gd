extends SceneTree
const Main=preload("res://src/Main.tscn")
var checks=0
var failures=[]
func ck(v:bool,s:String):
 checks+=1
 if not v:failures.append(s);print("FAIL ",s)
func _initialize():call_deferred("run")
func press(p):
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=p;e.global_position=p
  Input.parse_input_event(e);await process_frame
func snapshot(ui):
 var g=ui.game;return var_to_str([g.gold,g.phase,g.rng.state,g.hp,g.towers,g.reserve,g.upgrades,g.tick_count,ui.selected_id])
func run():
 root.size=Vector2i(1280,800)
 var ui=Main.instantiate();ui.tutorial.persist_enabled=false;root.add_child(ui);ui.set_process(false)
 await process_frame
 var state=snapshot(ui);var a=ui.audio
 ck(not a.unlocked and a.voice_counts().Ambience==0,"cold start no autoplay")
 var cap=AudioEffectCapture.new();cap.buffer_length=2.0;AudioServer.add_bus_effect(0,cap);cap.clear_buffer()
 var pos=ui.test_sound_button.get_global_rect().get_center()
 await press(pos)
 ck(a.unlocked and a.event_history().size()==1 and a.event_history()[0].id=="ui_press","real viewport Test Sound first click exactly one")
 ck(snapshot(ui)==state and ui.notice.contains("requested"),"truthful cue request no gameplay changes")
 await create_timer(.5).timeout
 var data=cap.get_buffer(cap.get_frames_available());var peak=0.0
 for frame in data:peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
 ck(data.size()>1000 and peak>0.01 and peak<1.0,"actual native PCM software signal not silent/clipped")
 print("P09 SOUND_CLICK ",checks-failures.size(),"/",checks," failures ",failures," frames ",data.size()," peak ",peak," backend ",DisplayServer.get_name())
 a.reset_scene();a._sea.stop();a._battle_bed.stop();ui.queue_free();await process_frame;await process_frame
 quit(1 if failures.size() else 0)
