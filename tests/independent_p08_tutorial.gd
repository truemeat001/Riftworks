extends SceneTree
const Main=preload("res://src/Main.tscn")
const Run=preload("res://src/Run.gd")
const Tutorial=preload("res://src/Tutorial.gd")
var checks=0
var failures=[]
func ck(v:bool,s:String):
 checks+=1
 if not v: failures.append(s);print("FAIL ",s)
func snap(ui):
 return var_to_str([ui.game.phase,ui.game.stage,ui.game.wave,ui.game.gold,ui.game.hp,ui.game.towers,ui.game.reserve,ui.game.upgrades,ui.game.rng.state,ui.game.tick_count,ui.game.enemies,ui.game.pending,ui.game.route_choice,ui.game.opened,ui.game.last_loot,ui.selected_id,ui.selected_core,ui.loot_reveal,ui.loot_age,ui.paused,ui.speed,ui.seed_value])
func click_cell(ui,cell):
 for pressed in [true,false]:
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=ui.coord(Vector2(cell))
  ui._unhandled_input(e)
func ui_click(p:Vector2):
 for pressed in [true,false]:
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=p;e.global_position=p
  Input.parse_input_event(e)
  await process_frame
func toggle(ui):
 var old=snap(ui);var active=ui.tutorial.active
 ui.tutorial_button.pressed.emit()
 ck(snap(ui)==old and ui.tutorial.active!=active,"guide toggle only presentation")
func explore(ui):
 var g=ui.game.gold;var rng=ui.game.rng.state
 ui.explore_button.pressed.emit()
 ck(ui.game.gold==g-6 and ui.game.rng.state!=rng and not ui.game.last_loot.is_empty(),"explicit single actual Explore")
 var old=ui.game.gold
 ui.skip_reveal_button.pressed.emit()
 ck(ui.game.gold==old,"skip reveal free")
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,800)
 var ui=Main.instantiate();ui.tutorial.persist_enabled=false;root.add_child(ui);ui.set_process(false)
 await process_frame
 ck(ui.tutorial.active and ui.tutorial.step=="explore" and ui.game.gold==24,"fresh optional first step")
 ck(ui.label_message.text.to_lower().contains("explore") and ui.explore_button.visible and not ui.explore_button.disabled,"explicit first action")
 ck(ui.start_button.disabled,"no crew cannot start")
 toggle(ui);ck(not ui.tutorial.active,"skip before purchase")
 toggle(ui);ck(ui.tutorial.step=="explore","replay initial step")
 # Actual viewport input, not signal or callback, for a complete button click.
 var pos=ui.explore_button.get_global_rect().get_center()
 await ui_click(pos)
 ck(ui.game.gold==18 and ui.game.reserve.size()==1 and ui.tutorial.step=="deploy","physical-style viewport input buys first actual crew")
 ui.skip_reveal_button.pressed.emit()
 var old=snap(ui)
 toggle(ui);toggle(ui);ck(ui.tutorial.step=="deploy" and snap(ui)==old,"replay after purchase stays in current task")
 var selected=ui.selected_id
 var hint=ui.guide_hint_cell
 ck(hint.x>=0 and ui.game.placement_error(hint,ui.game.reserve[0].kind,selected).is_empty(),"hint actual legal")
 old=snap(ui)
 var blocked=Vector2i(ui.game.path()[0])
 ck(not ui.game.placement_error(blocked,ui.game.reserve[0].kind,selected).is_empty(),"fixture route cell is invalid")
 click_cell(ui,blocked)
 ck(snap(ui)==old,"route cell rejection preserves whole run and selection")
 # Alternate valid (not recommended) place accepted: no tutorial lock.
 var alternative=Vector2i(-1,-1)
 for y in range(Run.ROWS):
  for x in range(Run.COLS):
   var c=Vector2i(x,y)
   if c!=hint and ui.game.placement_error(c,ui.game.reserve[0].kind,selected).is_empty() and alternative.x<0:alternative=c
 click_cell(ui,alternative)
 ck(ui.game.towers.size()==1 and ui.tutorial.step=="start","alternate valid deployment advances guide")
 toggle(ui);toggle(ui);ck(ui.tutorial.step=="start","replay after deployment")
 ui._recall()
 ck(ui.game.towers.is_empty() and ui.tutorial.step=="deploy","recall returns to useful instruction")
 ui.reserve_buttons[0].pressed.emit();click_cell(ui,ui.guide_hint_cell)
 ck(ui.game.towers.size()==1,"re-deploy")
 # Build useful real lineup through regular random purchase only.
 for i in range(3):
  explore(ui)
  if ui.game.last_loot.kind=="tower":
   var t=ui.game.reserve[-1];ui._select_tower(t.id)
   var best=-INF;var cell=Vector2i(-1,-1)
   for y in range(Run.ROWS):
    for x in range(Run.COLS):
     var c=Vector2i(x,y);var p=ui.game.coverage_preview(c,t.kind,t.rank,t.id)
     if p.valid:
      var v=float(p.lanes[0].team_after)
      if v>best:best=v;cell=c
   click_cell(ui,cell)
 ck(ui.game.gold==0 and not ui.game.towers.is_empty(),"draw budget unchanged by guide")
 ui.start_button.pressed.emit()
 ck(ui.game.phase=="fight" and ui.tutorial.step=="fight","real start advances guide")
 toggle(ui);toggle(ui);ck(ui.tutorial.step=="fight","replay midfight does not restart")
 ui.pause_button.pressed.emit()
 toggle(ui);toggle(ui);ck(ui.paused,"guide preserves pause")
 ui.pause_button.pressed.emit()
 for i in range(4000):
  if ui.game.phase!="fight":break
  ui._process(0.05)
 ck(ui.game.phase=="build" and ui.game.wave==1 and ui.game.gold==12 and ui.tutorial.step=="after_wave","actual W1 settlement guides after wave")
 old=snap(ui);ui.restart_button.pressed.emit();ck(snap(ui)==old and ui.restart_confirm=="same","active-run restart confirm")
 var e=InputEventKey.new();e.keycode=KEY_ESCAPE;e.pressed=true;ui._unhandled_input(e)
 ck(snap(ui)==old and ui.restart_confirm.is_empty(),"Esc cancels destructive confirmation without losing run")
 # Starting next wave with no further payment is permitted and closes guide.
 ui.start_button.pressed.emit()
 ck(ui.game.phase=="fight" and not ui.tutorial.active and ui.game.gold==12,"guide completion no forced purchase")
 toggle(ui);ck(ui.tutorial.step=="fight","replay after completion")
 # Persistence independent invalid file: no load failure should disable gameplay.
 var t=Tutorial.new();t.preference_path="user://independent_p08_tutorial-invalid.cfg"
 var f=FileAccess.open(t.preference_path,FileAccess.WRITE);f.store_string("[bad config");f.close()
 t.load_preference();ck(t.active,"bad preference default safely active")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(t.preference_path))
 t.preference_path="user://independent_p08_tutorial-pref.cfg";t.skip()
 var t2=Tutorial.new();t2.preference_path=t.preference_path;t2.load_preference();ck(not t2.active,"skip preference persistent")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(t.preference_path))
 print("P08 TUTORIAL ",checks-failures.size(),"/",checks," failures ",failures)
 ui.audio.reset_scene();ui.audio._sea.stop();ui.audio._battle_bed.stop()
 ui.queue_free();await process_frame;await process_frame
 quit(1 if failures.size() else 0)
