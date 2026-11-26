extends SceneTree
const Main=preload("res://src/Main.tscn")
const Run=preload("res://src/Run.gd")
var checks=0
var failures:Array[String]=[]
func ck(v:bool,s:String):
 checks+=1
 if not v:failures.append(s);print("FAIL ",s)
func state(ui):
 var r=ui.game
 return var_to_str([r.hp,r.gold,r.phase,r.stage,r.wave,r.route_choice,r.opened,r.towers,r.reserve,r.upgrades,r.rng.state,r.pending,r.tick_count,r.enemies,r.shots,r.deaths,r.last_loot,r.run_leaks])
func serial(ui)->int:
 var h=ui.audio.event_history()
 return 0 if h.is_empty() else int(h[-1].serial)
func since(ui,after:int)->Array:
 return ui.audio.event_history().filter(func(e):return int(e.serial)>after)
func ids(rows:Array)->Array:
 return rows.map(func(e):return str(e.id))
func loot_rows(ui,after:int)->Array:
 return since(ui,after).filter(func(e):return e.group=="loot")
func advance(ui,secs:float,dt:float=0.05):
 var n=ceili(secs/dt)
 for i in range(n):
  ui.audio._process(dt)
  ui._process(dt)
func restart(ui,seed:int):
 ui.seed_value=seed
 ui.audio.reset_scene()
 ui.game.reset(seed);ui.atmosphere.reset(ui.game)
 ui._skip_reveal();ui.loot_reveal.clear();ui.refresh()
func press_cell(ui,c:Vector2i):
 for flag in [true,false]:
  var ev=InputEventMouseButton.new();ev.position=ui.coord(Vector2(c));ev.button_index=MOUSE_BUTTON_LEFT;ev.pressed=flag
  ui._input(ev);ui._unhandled_input(ev)
func _initialize():call_deferred("run")
func run():
 var ui=Main.instantiate()
 root.add_child(ui)
 ui.set_process(false);ui.audio.set_process(false)
 await process_frame
 ck(not ui.audio.unlocked and ui.audio.voice_counts().Ambience==0 and ui.audio.event_history().is_empty(),"AUD04 no autoplay before input")
 # Simulated event callback tests only; actual browser gesture and acoustic output are separate.
 var gesture=InputEventMouseButton.new();gesture.position=ui.explore_button.get_global_rect().get_center();gesture.button_index=MOUSE_BUTTON_LEFT;gesture.pressed=true
 ui._input(gesture)
 ck(ui.audio.unlocked,"AUD04 real input callback unlocks audio controller")
 for bus in ["Master","SFX","UI","Combat","Alert","Ambience","Music"]:
  ck(AudioServer.get_bus_index(bus)>=0,"AUD bus "+bus)
 for bus in ["UI","Combat","Alert"]:
  ck(AudioServer.get_bus_send(AudioServer.get_bus_index(bus))=="SFX","AUD intended subgroup routing "+bus)
 restart(ui,7)
 var expected=["loot_crew","loot_crew","loot_relic","loot_upgrade"]
 for i in range(4):
  var before=serial(ui);var cash=ui.game.gold
  ui.explore_button.pressed.emit()
  var result=ui.loot_reveal.duplicate(true)
  ck(ui.game.gold==cash-6 and ui.game.last_loot==result,"FX03 real seed7 one draw immediate committed")
  ck(ui.loot_feedback_tier(result)==[0,0,1,2][i],"FX03 category corresponds to real result")
  var frozen=state(ui)
  advance(ui,1.4)
  ck(state(ui)==frozen,"AUD02 animations and sound don't affect model")
  var heard=loot_rows(ui,before)
  ck(ids(heard)==["chest_charge","chest_open",expected[i],"loot_arrive"],"AUD02 unique actual category sequence "+str(i)+" got "+str(ids(heard)))
  if heard.size()==4:
   ck(float(heard[1].loot_age)>=0.32 and float(heard[2].loot_age)>=0.34 and float(heard[3].loot_age)>=1.22,"AUD02 real result thresholds")
  ck(ui.audio.voice_counts().loot<=4,"AUD02 loot polyphony cap")
  if i==0:
   var matured=state(ui)
   ui.reserve_buttons[0].pressed.emit()
   ck(state(ui)==matured and ui.audio.voice_counts().loot==0,"AUD02 board/selection after natural reveal stops remaining loot tail")
 var exhausted=state(ui);var before=serial(ui)
 ui.explore_button.pressed.emit()
 ck(state(ui)==exhausted and loot_rows(ui,before).is_empty(),"AUD02 rejected draw no reward audio")
 restart(ui,7)
 before=serial(ui);ui.explore_button.pressed.emit();advance(ui,0.2);var same=state(ui)
 ui.skip_reveal_button.pressed.emit()
 ck(state(ui)==same and ui.audio.voice_counts().loot==0,"AUD02 independent skip stops current loot tail without altering model")
 advance(ui,1.5)
 ck(ids(loot_rows(ui,before))==["chest_charge"],"AUD02 skipped loot does not replay stale open/result/arrival")
 # Mute actual UI, check Master mute + no game mutation, resume without replaying old rewards.
 same=state(ui)
 ui.sound_button.pressed.emit()
 ck(ui.audio.is_muted() and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) and state(ui)==same,"AUD04 sound button mutes bus; model unaffected")
 before=serial(ui);advance(ui,0.5);ui.sound_button.pressed.emit()
 ck(not ui.audio.is_muted() and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) and loot_rows(ui,before).is_empty(),"AUD04 unmute never replays skipped loot")
 # Actual intentionally weak solo layout produces true danger/leaks; no injected enemy or RNG.
 restart(ui,437)
 before=serial(ui);ui.start_button.pressed.emit()
 ck(ui.game.phase=="build" and not ids(since(ui,before)).has("wave_start"),"ATM01 rejected start no fake entrance sound")
 ui.explore_button.pressed.emit();ui.skip_reveal_button.pressed.emit()
 var chosen=ui.game.reserve[0].id
 ui.reserve_buttons[0].pressed.emit();press_cell(ui,Vector2i(0,7))
 ck(ui.game.towers.size()==1 and ui.game.towers[0].id==chosen,"ATM actual weak deployment")
 before=serial(ui)
 ui.start_button.pressed.emit()
 ck(ui.game.phase=="fight" and ui.audio.battle_active and ui.atmosphere.last_wave_start_tick==ui.game.tick_count,"ATM01 accepted wave real edge and audio")
 var start_rows=since(ui,before).filter(func(e):return e.id=="wave_start")
 ck(start_rows.size()==1 and start_rows[0].pos==ui.game.path()[0],"ATM01 actual main entry location voice")
 var danger_seen=false;var leak_seen=false;var contact_seen=false;var end_seen=false;var final_leak_seen=false
 var prev_leaks=ui.game.run_leaks
 for i in range(1800):
  if ui.game.phase!="fight":break
  before=serial(ui)
  var tick_before=ui.game.tick_count
  advance(ui,0.05)
  if ui.game.tick_count==tick_before:continue
  var active=false
  for e in ui.game.enemies:
   if ui.game.phase=="fight" and e.hp>0 and ui.game.remaining_distance(e)<=2.0:active=true
  ck(ui.atmosphere.danger_active==active,"ATM03 danger derives actual living route threshold")
  ck(ui.atmosphere.traces.size()<=12 and ui.atmosphere.impacts.size()<=28,"ATM bounded active traces/impacts")
  for ev in since(ui,before):
   match str(ev.id):
    "danger":
     danger_seen=true
     ck(active,"AUD03 danger only actual threat")
    "leak":
     leak_seen=true
     ck(ui.game.run_leaks>prev_leaks,"AUD03 leak sound only actual leak")
    "wave_clear","victory","defeat":
     end_seen=true
     ck(ui.game.phase!="fight","AUD03 conclusion only actual wave end")
    "hit_pulse","hit_frost","hit_burst":
     contact_seen=true
     ck(ui.game.shots.any(func(s):return s.to==ev.pos),"AUD03 combat sound uses real shot position")
  if ui.game.phase!="fight" and ui.game.run_leaks>prev_leaks:
   var boundary_ids=ids(since(ui,before))
   final_leak_seen=boundary_ids.has("leak") and (boundary_ids.has("wave_clear") or boundary_ids.has("defeat"))
   ck(final_leak_seen,"AUD03 final leak same tick as wave closure retains actual leak and conclusion cue")
  var counts=ui.audio.voice_counts()
  ck(counts.loot<=4 and counts.UI<=2 and counts.Combat<=6 and counts.Alert<=2 and counts.Ambience<=2,"AUD03 actual voice group capacity")
  prev_leaks=ui.game.run_leaks
 ck(danger_seen and leak_seen and end_seen and final_leak_seen,"ATM03 exercised real danger and final leak with end")
 ck(not ui.audio.battle_active and not ui.atmosphere.danger_active and ui.atmosphere.impacts.is_empty(),"ATM04 wave end clears threat and impacts")
 ck(ui.audio.voice_counts().Combat==0 and ui.audio.voice_counts().Alert<=1,"AUD03 conclusion clears old combat/alert voices; only final leak tail allowed")
 restart(ui,437)
 ck(ui.atmosphere.traces.is_empty() and ui.atmosphere.previous_traces.is_empty() and ui.audio.voice_counts().loot==0,"ATM04 restart fully clears traces/loot")
 # Actual closer placement yields real hits and trace origins.
 restart(ui,4)
 for i in range(4):
  ui.explore_button.pressed.emit();ui.skip_reveal_button.pressed.emit()
 var placements=[Vector2i(3,2),Vector2i(5,2),Vector2i(6,2),Vector2i(7,2)]
 while not ui.game.reserve.is_empty():
  ui.reserve_buttons[0].pressed.emit();press_cell(ui,placements.pop_front())
 ui.start_button.pressed.emit()
 var seen=[]
 var first_contacts=0
 var touched=false
 for i in range(1000):
  if ui.game.phase!="fight":break
  before=serial(ui);advance(ui,0.05)
  for shot in ui.game.shots:
   if shot.to not in seen:seen.append(shot.to)
  for death in ui.game.deaths:
   if death.pos not in seen:seen.append(death.pos)
  if ui.atmosphere.events.first_contact:
   first_contacts+=1
   ck(seen.has(ui.atmosphere.events.contact_pos),"ATM02 first contact precise actual hit position")
  for ev in since(ui,before):
   if str(ev.id).begins_with("hit_"):
    touched=true
    ck(seen.has(ev.pos),"AUD03 actual strong layout hit sound position")
 ck(touched and first_contacts==1,"ATM02 actual strong lineup exercises sound and one-first-contact")
 ck(not ui.atmosphere.traces.is_empty(),"ATM04 real same-stage battle leaves traces")
 for tr in ui.atmosphere.traces:ck(seen.has(tr.pos),"ATM04 every trace location observed in actual shot/death")
 restart(ui,437)
 # Stage setup fixture uses actual legal random roster; verifies open B entrance semantics.
 ui.game.stage=1;ui.game.opened=true;ui.atmosphere.reset(ui.game);ui.refresh()
 ui.explore_button.pressed.emit();ui.skip_reveal_button.pressed.emit();ui.reserve_buttons[0].pressed.emit();press_cell(ui,Vector2i(3,2))
 before=serial(ui);ui.start_button.pressed.emit()
 var entries=since(ui,before).filter(func(e):return e.id=="wave_start").map(func(e):return e.pos)
 ck(entries.has(ui.game.path()[0]) and entries.has(ui.game.path(false)[0]) and entries.size()==2,"ATM01 actual open B starts exactly two entrance voices")
 var oldtick=ui.game.tick_count
 ui.pause_button.pressed.emit();advance(ui,0.2)
 ck(ui.game.tick_count==oldtick and ui.audio.battle_paused,"AUD04 actual pause freezes combat")
 before=serial(ui);ui.pause_button.pressed.emit();advance(ui,0.05)
 ck(not ui.audio.battle_paused and not ids(since(ui,before)).has("wave_start"),"AUD04 resume no replay of old entry")
 restart(ui,437)
 print("PRESENTATION_QA checks=",checks," failures=",failures," contact_exercised=",touched)
 quit(1 if not failures.is_empty() else 0)
