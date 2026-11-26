extends SceneTree
const Audio=preload("res://src/GameAudio.gd")
const Main=preload("res://src/Main.tscn")
var checks=0
var fails=0
func ck(ok:bool,msg:String)->void:
 checks+=1
 if not ok:fails+=1;push_error(msg)
func _initialize():call_deferred("run")
func ids(a:Node,group:String)->Array:
 var result=[]
 for v in a._voices:
  if v.group==group and is_instance_valid(v.player) and v.player.playing:result.append(v.id)
 return result
func history(a:Node,offset:int)->Array:return a.event_history().slice(offset)
func wait_real(sec:float)->void:
 var stop=Time.get_ticks_msec()+roundi(sec*1000)
 while Time.get_ticks_msec()<stop:
  await process_frame;OS.delay_msec(4)
func enemy(id:int,x:float,role:String="normal",slow:float=0.0)->Dictionary:
 return {"id":id,"hit_tick":-1,"route":[Vector2(0,3),Vector2(10,3)],"pos":Vector2(x,3),"direction":Vector2.RIGHT,"segment":0,"hp":100.0,"maxhp":100.0,"slow":slow,"role":role,"boss":role=="boss","speed":0.0,"second":false}
func step_fixture(ui:Node,kind:int,enemies:Array)->Array:
 ui.game.reset(437);ui.game.stage=1;ui.game.phase="fight";ui.game.pending=1;ui.game.spawn_time=100.0
 ui.game.towers=[{"id":7,"kind":kind,"rank":1,"cell":Vector2i(5,3),"cool":0.0,"attack_tick":-1}];ui.game.enemies=enemies
 ui.audio.reset_scene();ui.audio.set_battle_active(true)
 var start=ui.audio.event_history().size()
 ui.game.step();ui.note_attacks()
 return history(ui.audio,start)
func run():
 var ui=Main.instantiate();root.add_child(ui);await process_frame;ui.set_process(false)
 var a=ui.audio
 ck(not a.unlocked and not a.play_event("hit_intercept",Vector2(5,3)),"no pre-gesture interception audio")
 var ev=InputEventMouseButton.new();ev.pressed=true;ev.button_index=MOUSE_BUTTON_LEFT;ui._input(ev)
 ck(a.unlocked and a._streams.hit_intercept.size()==3,"actual gesture and all three guard streams")
 for s in a._streams.hit_intercept:
  ck(s is AudioStreamWAV and s.format==AudioStreamWAV.FORMAT_16_BITS and s.mix_rate==48000 and not s.stereo and absf(s.get_length()-.24)<.001,"actual imported PCM16 mono")
 # Direct actual guard recipient through shipped Main.note_attacks (no synthetic presentation event).
 for kind in [0,1]:
  var p=enemy(10,7);var g=enemy(5,6,"guard")
  var h=step_fixture(ui,kind,[p,g]);ck(ui.game.guard_intercepts.size()==1,"authoritative guard event")
  ck(h.size()==1 and h[0].id=="hit_intercept" and h[0].pos==g.pos,"exact one guard cue, position actual recipient, no ordinary duplicate")
  ck(not h.any(func(x):return x.id in ["hit_pulse","hit_frost"]),"ordinary primary replaced")
  await wait_real(.12)
 # Actual conductive synergy remains a distinct event without doubling the primary cue.
 var h=step_fixture(ui,0,[enemy(10,7),enemy(5,6,"guard",.8)])
 ck(h.size()==2 and h.map(func(x):return x.id)==["hit_intercept","conductive"],"one redirect and separate real conductive effect")
 await wait_real(.12)
 h=step_fixture(ui,2,[enemy(10,7),enemy(5,6,"guard")]);ck(ui.game.guard_intercepts.is_empty(),"Hammer bypass model")
 ck(h.size()==1 and h[0].id=="hit_burst","Burst primary only, no guard cue")
 await wait_real(.12)
 h=step_fixture(ui,0,[enemy(10,7)]);ck(h.size()==1 and h[0].id=="hit_pulse","ordinary direct hit unchanged")
 # A real cooldown ready guard still cannot trigger presentation twice in the same game tick.
 var start=a.event_history().size();ui.note_attacks();ck(a.event_history().size()==start,"immediate same-tick callback doesn't duplicate through rate gate")
 # Priority stress is controller-only, not an invented model event.
 a.reset_scene();a.set_battle_active(true)
 for id in ["hit_pulse","hit_frost","hit_burst","kill","conductive","shatter"]:ck(a.play_event(id,Vector2(5,3)),"ordinary fill "+id)
 ck(a.voice_counts().Combat==6,"six existing combat voices")
 ck(a.play_event("hit_intercept",Vector2(6,3)),"guard cue displaces ordinary tail even when cap saturated")
 ck(a.voice_counts().Combat==6 and "hit_intercept" in ids(a,"Combat") and not "hit_pulse" in ids(a,"Combat"),"actual guard retained cap, oldest ordinary replaced")
 ck(not a.play_event("hit_intercept",Vector2(6,3)),"coalesce simultaneous duplicate presentation")
 a._process(.16)
 ck(not a.play_event("hit_pulse",Vector2(5,3)) and "hit_intercept" in ids(a,"Combat"),"ordinary cannot displace guard")
 a.set_danger(true,Vector2(11,4));a.play_event("leak",Vector2(11,4))
 ck("danger" in ids(a,"Alert") and "leak" in ids(a,"Alert"),"critical Alert independent of Combat priority")
 a.set_battle_paused(true);ck(not a.play_event("hit_intercept",Vector2(6,3)),"pause no guard cue")
 a.set_battle_active(false);ck(a.voice_counts().Combat==0 and a.voice_counts().Alert==0,"end clears guard and alerts")
 print("P09_GUARD_AUDIO checks=",checks," failures=",fails)
 a.reset_scene();a._sea.stop();a._battle_bed.stop();await wait_real(.25)
 ui.queue_free();await process_frame;await process_frame
 quit(0 if fails==0 else 1)
