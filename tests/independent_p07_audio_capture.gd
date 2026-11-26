extends SceneTree
## Captures the actual software mixer via Godot Master bus, not a generated waveform.
## Device output, browser gesture and subjective listening remain separate.
const Main=preload("res://src/Main.tscn")
var capture:AudioEffectCapture
var samples=PackedByteArray()
func _initialize():call_deferred("execute")
func pull():
 var n=capture.get_frames_available()
 if n<=0:return
 var frames=capture.get_buffer(n)
 var old=samples.size()
 samples.resize(old+frames.size()*4)
 for i in range(frames.size()):
  var l=clampi(roundi(frames[i].x*32767.0),-32768,32767)
  var r=clampi(roundi(frames[i].y*32767.0),-32768,32767)
  samples.encode_s16(old+4*i,l)
  samples.encode_s16(old+4*i+2,r)
func interval(t:float):
 var end=Time.get_ticks_msec()+roundi(t*1000)
 while Time.get_ticks_msec()<end:
  await process_frame
  pull()
func save_record(path:String):
 pull()
 if samples.is_empty():
  print("MIXER_CAPTURE missing frames ",path)
  return false
 var w=AudioStreamWAV.new()
 w.format=AudioStreamWAV.FORMAT_16_BITS;w.stereo=true;w.mix_rate=roundi(AudioServer.get_mix_rate());w.data=samples
 var err=w.save_to_wav(path)
 print("MIXER_CAPTURE ",path," frames=",samples.size()/4," rate=",w.mix_rate," discarded=",capture.get_discarded_frames()," error=",err)
 return err==OK
func execute():
 var ui=Main.instantiate()
 root.add_child(ui)
 await process_frame
 capture=AudioEffectCapture.new();capture.buffer_length=1.0
 AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"),capture)
 capture.clear_buffer()
 ui.seed_value=7;ui.game.reset(7);ui.atmosphere.reset(ui.game)
 var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=ui.explore_button.get_global_rect().get_center();e.pressed=true
 ui._input(e)
 for i in range(4):
  ui.explore_button.pressed.emit()
  await interval(1.5)
 await interval(.3)
 var ok=save_record("user://p07-loot-software-mixer.wav")
 samples=PackedByteArray();capture.clear_buffer();ui.audio.reset_scene()
 await interval(36.4)
 var ok2=save_record("user://p07-ambience-three-loops-software-mixer.wav")
 quit(0 if ok and ok2 else 1)
