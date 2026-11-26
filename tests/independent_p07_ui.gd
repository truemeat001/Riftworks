extends SceneTree
const Main=preload("res://src/Main.tscn")
const Run=preload("res://src/Run.gd")
var failures:Array[String]=[]
var checks=0
func check(v:bool,s:String):
 checks+=1
 if not v:failures.append(s);print("FAIL ",s)
func mouse_button(ui,cell:Vector2i,pressed:bool,button=MOUSE_BUTTON_LEFT):
 var ev=InputEventMouseButton.new()
 ev.button_index=button;ev.pressed=pressed;ev.position=ui.coord(Vector2(cell))
 ui._unhandled_input(ev)
func click(ui,cell:Vector2i,button=MOUSE_BUTTON_LEFT):
 mouse_button(ui,cell,true,button)
 mouse_button(ui,cell,false,button)
func controls(node:Node,out:Array):
 for child in node.get_children():
  if child is Control and child.is_visible_in_tree() and not child.get_children().size():out.append(child)
  controls(child,out)
func layout(ui,tag:String):
 await process_frame
 await process_frame
 var all=[];controls(ui,all)
 var outside=[];var overlap=[]
 for i in range(all.size()):
  var a=all[i];var ar:Rect2=a.get_global_rect()
  if not Rect2(0,0,1280,800).encloses(ar):outside.append([a.text,ar])
  for j in range(i+1,all.size()):
   var b=all[j];var br:Rect2=b.get_global_rect()
   if ar.intersects(br) and ar.intersection(br).get_area()>50:overlap.append([a.text,b.text,ar.intersection(br)])
 print("LAYOUT ",tag," controls=",all.size()," outside=",outside," overlap=",overlap)
 check(outside.is_empty() and overlap.is_empty(),"layout "+tag)
func snapshot(ui):
 return var_to_str([ui.game.gold,ui.game.towers,ui.game.reserve,ui.game.upgrades,ui.game.rng.state,ui.game.last_loot])
func whole_snapshot(ui):
 return var_to_str([snapshot(ui),ui.game.phase,ui.game.hp,ui.game.stage,ui.game.wave,ui.game.route_choice,ui.game.opened,ui.game.tick_count,ui.game.pending,ui.game.enemies,ui.selected_id,ui.selected_core,ui.seed_value,ui.loot_reveal,ui.loot_age,ui.paused,ui.speed])
func settle_restart(ui):
 if ui.restart_cooldown>0.0:ui._process(0.36)
func retry(ui):
 settle_restart(ui)
 ui.restart_button.pressed.emit()
 if not ui.restart_confirm.is_empty():ui.restart_button.pressed.emit()
 settle_restart(ui)
func buy(ui):
 var before=ui.game.gold
 ui.explore_button.pressed.emit()
 var loot=ui.loot_reveal.duplicate(true)
 check(ui.game.gold==before-6 and loot==ui.game.last_loot and ui.loot_age<ui.LOOT_DURATION,"explore pays/funds exactly once, result committed before reveal")
 ui.skip_reveal_button.pressed.emit()
 return loot
func free_cell(ui):
 for y in range(Run.ROWS):
  for x in range(Run.COLS):
   var p=Vector2i(x,y)
   if ui.game.placement_error(p,0).is_empty():return p
 return Vector2i(-1,-1)
func rate_trial(ui,fps:int,rate:int)->Array:
 retry(ui);ui.speed=rate
 for i in range(4):
  ui.explore_button.pressed.emit();ui.skip_reveal_button.pressed.emit()
 var slots=[Vector2i(3,2),Vector2i(5,2),Vector2i(6,2),Vector2i(7,2)]
 while not ui.game.reserve.is_empty():ui.reserve_buttons[0].pressed.emit();click(ui,slots.pop_front())
 ui.start_button.pressed.emit()
 var frames=0
 while ui.game.phase=="fight" and frames<fps*60:
  ui._process(1.0/fps);frames+=1
 return [ui.game.phase,ui.game.tick_count,ui.game.hp,ui.game.gold,ui.game.kills,ui.game.wave_leaks,ui.game.rng.state]
func key(ui,keycode):
 var ev=InputEventKey.new();ev.keycode=keycode;ev.pressed=true
 ui._unhandled_input(ev)
func primary_count(ui)->int:
 var n=0
 for b in [ui.explore_button,ui.start_button]:
  if not b.disabled:
   var sb=b.get_theme_stylebox("normal")
   if sb is StyleBoxFlat and sb.bg_color.is_equal_approx(Color("AD4631")):n+=1
 return n
func _initialize():call_deferred("run")
func run():
 var ui=Main.instantiate();root.add_child(ui);ui.set_process(false)
 await layout(ui,"opening")
 check(ui.game.gold==24 and ui.game.hp==15 and ui.start_button.disabled and ui.loot_label.text.contains("100%") and ui.loot_label.tooltip_text.to_lower().contains("guaranteed"),"opening guard odds and authentic HP/gold")
 check(ui.label_status.text.contains("15") and ui.label_status.text.contains("24"),"actual HUD initial numbers")
 check(ui.ORIGIN==Vector2(52,60) and ui.TILE==76.0 and ui.BOARD==Rect2(52,60,912,608),"approved 12×8 board geometry")
 check(ui.coord(Vector2.ZERO)==Vector2(90,98) and ui.coord(Vector2(11,7))==Vector2(926,630),"first/last cell centre geometry")
 check(ui.explore_button.get_global_rect().position.x>=1020 and ui.explore_button.size.y>=44,"explore right panel large target")
 check(ui.start_button.get_global_rect().position.y>=676 and ui.start_button.size.y>=44,"start button bottom panel large target")
 check(ui.reserve_buttons.size()==9 and ui.core_buttons.size()==8,"all real warehouse/relic slots present")
 check(primary_count(ui)==1,"opening single enabled primary CTA")
 check(ui.start_button.text.contains("DEPLOY") and ui.label_message.text.contains("Explore"),"P07 nonblocking first step and visible cannot-start reason")
 check(ui.sound_button.visible and ui.sound_button.text.contains("SOUND"),"P07 discoverable sound control")
 check(not ui.has_method("_draw_tower") and not ui.has_method("_draw_core"),"no UI type-select purchase callbacks")
 check(ui.sprite_atlas!=null and ui.sprite_manifest.get("characters",{}).size()==7,"real imported atlas and seven character entries")
 check(ui.crew_icons.size()==3 and ui.crew_icons.all(func(t):return t!=null),"three actual visible role portraits")
 check(ui.scene_backdrops.size()==3 and ui.scene_backdrops[0]!=null,"real representative environment texture and other-stage slots")
 check(ui.chest_textures.size()==2 and ui.chest_textures.all(func(t):return t!=null),"2 real chest textures")
 ui.explore_button.pressed.emit()
 var first=ui.selected_id
 check(ui.game.gold==18 and ui.game.reserve.size()==1 and first==ui.game.reserve[0].id and ui.explore_button.text.contains("FREE"),"first commit enters reserve and next button states free skip")
 var state=snapshot(ui);ui.explore_button.pressed.emit()
 check(snapshot(ui)==state and ui.loot_age>=ui.LOOT_DURATION,"fast repeat main control skips only")
 ui.explore_button.pressed.emit()
 check(ui.game.gold==12 and ui.game.reserve.size()==2 and ui.loot_age<ui.LOOT_DURATION,"new explicit third click pays and commits another")
 state=snapshot(ui);ui.skip_reveal_button.pressed.emit()
 check(snapshot(ui)==state and ui.loot_label.text.contains("70%") and ui.loot_label.text.contains("30%"),"separate free skip, mixed dynamic odds")
 # UXR07 active-run destructive intent must preserve everything until exact confirmation.
 var full_before=whole_snapshot(ui)
 ui.restart_button.pressed.emit()
 check(whole_snapshot(ui)==full_before and ui.restart_confirm=="same","UXR07 first Retry asks confirmation, no state reset")
 check(ui.restart_button.text.to_lower().contains("confirm") and ui.label_message.text.to_lower().contains("discard"),"UXR07 destructive confirmation displays progress-loss consequence")
 ui.new_seed_button.pressed.emit()
 check(whole_snapshot(ui)==full_before and ui.restart_confirm=="new","UXR07 clicking other restart mode only changes pending intent")
 key(ui,KEY_ESCAPE)
 check(whole_snapshot(ui)==full_before and ui.restart_confirm.is_empty(),"UXR07 Esc cancels without losing progress or selection")
 ui.new_seed_button.pressed.emit()
 ui.cancel_button.pressed.emit()
 check(whole_snapshot(ui)==full_before and ui.restart_confirm.is_empty(),"UXR07 visible Clear cancel preserves original progress/selection")
 ui.restart_button.pressed.emit()
 ui.reserve_buttons[0].pressed.emit()
 check(ui.restart_confirm.is_empty() and snapshot(ui)==state,"UXR07 unrelated crew selection cancels pending restart without spending")
 ui.reserve_buttons[0].pressed.emit()
 var pre_hover=snapshot(ui)
 ui.hover=Vector2i(1,2);ui.update_hover()
 check(snapshot(ui)==pre_hover and ui.label_feedback.text.to_lower().contains("route"),"P07 true placement coverage hint read-only")
 click(ui,Vector2i(0,3));check(ui.game.towers.is_empty(),"invalid path rejects")
 state=snapshot(ui)
 mouse_button(ui,Vector2i(1,2),true)
 check(snapshot(ui)==state,"UXR02 press alone does not deploy")
 mouse_button(ui,Vector2i(2,2),false)
 check(snapshot(ui)==state,"UXR02 release in different cell cancels deployment")
 mouse_button(ui,Vector2i(1,2),true)
 mouse_button(ui,Vector2i(-1,-1),false)
 check(snapshot(ui)==state,"UXR02 release outside board cancels")
 mouse_button(ui,Vector2i(1,2),true)
 key(ui,KEY_ESCAPE)
 mouse_button(ui,Vector2i(1,2),false)
 check(snapshot(ui)==state,"UXR02 Esc cancels pending press")
 ui.reserve_buttons[0].pressed.emit()
 click(ui,Vector2i(1,2));check(ui.game.towers.size()==1 and ui.game.towers[0].id==first,"real board input deploys selected crew")
 check(primary_count(ui)<=1 and not ui.start_button.disabled and ui.label_message.text.to_lower().contains("deploy"),"P07 no conflicting primary, reserve deploy prompt after first placement")
 click(ui,Vector2i(11,7));check(ui.game.towers[0].cell==Vector2i(11,7),"bottom-right board actual input reaches cell")
 click(ui,Vector2i(0,0));check(ui.game.towers[0].cell==Vector2i(0,0),"top-left board actual input reaches cell")
 click(ui,Vector2i(0,2));check(ui.game.towers[0].cell==Vector2i(0,2),"move same identity without cost")
 click(ui,Vector2i(0,2),MOUSE_BUTTON_RIGHT);check(ui.game.towers.is_empty(),"right click recall")
 await layout(ui,"mixed odds")
 ui.explore_button.pressed.emit();state=snapshot(ui)
 ui.restart_button.pressed.emit()
 check(ui.restart_confirm=="same" and snapshot(ui)==state,"UXR07 reveal-first restart only pending intent")
 ui.skip_reveal_button.pressed.emit()
 check(snapshot(ui)==state and ui.restart_confirm.is_empty() and ui.loot_age>=ui.LOOT_DURATION,"UXR07 independent skip cancels pending restart with no consumption")
 ui._process(ui.LOOT_DURATION+0.02);check(snapshot(ui)==state and ui.loot_age>=ui.LOOT_DURATION,"natural animation completion no extra payout/RNG")
 ui.game.gold=100;ui.refresh()
 var core={}
 for i in range(20):
  var result=buy(ui)
  if result.kind=="core":core=result;break
 check(not core.is_empty(),"natural core result reached")
 if not core.is_empty():
  var g=ui.game.gold;var rank=ui.game.level(core.id)
  check(ui.selected_core==core.id and ui.label_core.text.contains("R%d"%rank),"result auto-selects real relic")
  # First sale press MUST not change authoritative state; different selection or Esc cancels.
  var frozen_core_state=snapshot(ui)
  ui.sell_core_button.pressed.emit()
  check(snapshot(ui)==frozen_core_state and ui.sell_confirm=="core:%s:%d"%[core.id,rank],"first relic sale asks exact id/rank")
  key(ui,KEY_ESCAPE)
  check(snapshot(ui)==frozen_core_state and ui.sell_confirm.is_empty(),"Esc cancels relic confirmation no changes")
  for i in range(Run.UPGRADES.size()):
   if Run.UPGRADES[i].id==core.id:
    ui.core_buttons[i].pressed.emit();break
  check(ui.selected_core==core.id and ui.label_core.text.contains("R%d"%rank),"actual relic button selects held rank")
  ui.sell_core_button.pressed.emit();ui.sell_core_button.pressed.emit()
  check(ui.game.gold==g+4 and ui.game.level(core.id)==rank-1,"second exact relic sale +4 one rank")
  check(ui.sell_confirm.is_empty(),"confirmation clears after committed relic sale")
 var active_snapshot=whole_snapshot(ui)
 ui.restart_button.pressed.emit()
 check(whole_snapshot(ui)==active_snapshot and ui.restart_confirm=="same","UXR07 active Retry first click no destructive commit")
 ui.restart_button.pressed.emit()
 check(ui.game.gold==24 and ui.game.reserve.is_empty() and ui.loot_reveal.is_empty() and ui.game.last_loot.is_empty(),"restart clears all former rewards")
 var after_reset=whole_snapshot(ui)
 ui.new_seed_button.pressed.emit()
 check(whole_snapshot(ui)==after_reset and ui.restart_cooldown>0.0,"UXR07 immediate repeated reset callback suppressed by cooldown")
 settle_restart(ui)
 ui.game.gold=1000;ui.refresh()
 while ui.game.reserve.size()<9:buy(ui)
 check(ui.loot_label.text.contains("100% relic"),"full reserve fallback relic odds")
 await layout(ui,"full crew")
 var pair=[]
 for i in range(ui.game.reserve.size()):
  for j in range(i+1,ui.game.reserve.size()):
   if ui.game.reserve[i].kind==ui.game.reserve[j].kind and pair.is_empty():pair=[i,j]
 var id=ui.game.reserve[pair[0]].id
 ui.reserve_buttons[pair[0]].pressed.emit();ui.merge_button.pressed.emit()
 check(ui.merge_mode,"merge mode enabled")
 ui.reserve_buttons[pair[1]].pressed.emit()
 check(ui.get_tower(id).rank==2 and not ui.merge_mode,"merge callback same kind rank")
 while ui.game.reserve.size()<9:buy(ui)
 while ui.game.reward_odds().core>0:buy(ui)
 check(ui.explore_button.disabled,"both pools saturated disables")
 await layout(ui,"full reserve relic levels")
 ui.reserve_buttons[0].pressed.emit();click(ui,Vector2i(1,2))
 var sale_id=ui.selected_id
 var sale_rank=ui.get_tower(sale_id).rank
 var before_sale=snapshot(ui);var gold_before=ui.game.gold
 ui.sell_tower_button.pressed.emit()
 check(snapshot(ui)==before_sale and ui.sell_confirm=="tower:%d:%d"%[sale_id,sale_rank],"first tower sell exact id/rank no mutation")
 ui.reserve_buttons[0].pressed.emit()
 var other_id=ui.selected_id
 check(other_id!=sale_id and ui.sell_confirm.is_empty() and snapshot(ui)==before_sale,"selecting different crew cancels old confirmation")
 ui.sell_tower_button.pressed.emit()
 check(snapshot(ui)==before_sale and ui.sell_confirm.begins_with("tower:%d:"%other_id),"new selection cannot commit old sale")
 key(ui,KEY_ESCAPE)
 check(snapshot(ui)==before_sale and ui.sell_confirm.is_empty(),"Esc cancels unrelated sale")
 click(ui,Vector2i(1,2))
 ui.sell_tower_button.pressed.emit()
 check(ui.sell_confirm.begins_with("tower:%d:"%sale_id),"reselected exact field sale asks again")
 ui.sell_tower_button.pressed.emit()
 check(ui.game.towers.is_empty() and ui.get_tower(sale_id).is_empty() and ui.game.gold==gold_before+ui.game.tower_sale_value(sale_rank),"second same sale commits exactly one refund")
 ui.explore_button.pressed.emit()
 check(ui.loot_age<ui.LOOT_DURATION,"reveal in progress")
 # Board interaction skips reveal without duplicate spend.
 state=snapshot(ui)
 click(ui,Vector2i(0,3))
 check(ui.loot_age>=ui.LOOT_DURATION and snapshot(ui)==state,"invalid board click skips reveal only")
 ui.reserve_buttons[0].pressed.emit();click(ui,Vector2i(1,2))
 ui.game.gold=1000;ui.refresh()
 if all(ui.game).size()<9:
  ui.explore_button.pressed.emit()
 ui.start_button.pressed.emit()
 check(ui.game.phase=="fight" and ui.loot_age>=ui.LOOT_DURATION and ui.explore_button.disabled and ui.merge_button.disabled and ui.sell_tower_button.disabled,"wave start skips reveal and disables economy")
 state=snapshot(ui);ui.explore_button.pressed.emit();check(snapshot(ui)==state,"forced callback in fight cannot draw")
 var before=ui.game.rng.state
 var attempts=0
 while ui.game.phase=="fight" and ui.last_attacks.is_empty() and attempts<500:
  ui._process(0.05);attempts+=1
 check(not ui.last_attacks.is_empty(),"real attack updates UI clock")
 check(ui.game.rng.state==before,"fight UI not consuming draw RNG")
 var death_attempts=0
 while ui.game.phase=="fight" and ui.death_fx.is_empty() and death_attempts<500:
  ui._process(0.05);death_attempts+=1
 check(not ui.death_fx.is_empty(),"real kill produces cosmetic death animation")
 if not ui.death_fx.is_empty():
  var d=ui.death_fx[0]
  check(d.has("role") and d.has("age") and d.has("pos"),"death effect retains role and position")
 ui.pause_button.pressed.emit()
 var tick=ui.game.tick_count;ui._process(0.2)
 check(ui.game.tick_count==tick,"pause freezes logic")
 ui.pause_button.pressed.emit()
 await layout(ui,"fight")
 var active_fight=whole_snapshot(ui)
 ui.restart_button.pressed.emit()
 var pending_tick=ui.game.tick_count
 ui._process(0.20)
 check(ui.game.tick_count==pending_tick and not ui.paused and ui.restart_confirm=="same","UXR07 unpaused fight temporarily stops ticks without changing pause state")
 key(ui,KEY_ESCAPE)
 check(whole_snapshot(ui)==active_fight and ui.restart_confirm.is_empty(),"UXR07 cancel resumes unchanged unpaused state")
 # Paused fixture verifies cancellation keeps prior paused/speed/selected state.
 ui.pause_button.pressed.emit()
 var fight_snapshot=whole_snapshot(ui)
 ui.restart_button.pressed.emit()
 check(whole_snapshot(ui)==fight_snapshot and ui.restart_confirm=="same","UXR07 paused-fight confirmation preserves tick and pause")
 key(ui,KEY_ESCAPE)
 check(whole_snapshot(ui)==fight_snapshot and ui.restart_confirm.is_empty(),"UXR07 fight cancel preserves original pause/speed/selection")
 ui.new_seed_button.pressed.emit()
 check(whole_snapshot(ui)==fight_snapshot and ui.restart_confirm=="new","UXR07 first New Run cannot reset paused combat")
 ui.restart_button.pressed.emit()
 check(whole_snapshot(ui)==fight_snapshot and ui.restart_confirm=="same","UXR07 switching destructive intent never executes old New Run")
 ui.restart_button.pressed.emit()
 check(ui.loot_reveal.is_empty() and ui.game.gold==24 and ui.restart_confirm.is_empty(),"confirmed same retry exactly once, no pending payout")
 settle_restart(ui)
 ui.game.stage=1;ui.refresh();ui.special_button.pressed.emit()
 check(ui.game.opened and ui.label_forecast.text.contains("Extra"),"rift forecast")
 await layout(ui,"rift")
 ui.game.stage=2;ui.game.wave=1;ui.refresh()
 check(ui.label_rule.text.contains("Boss escape") or ui.label_forecast.text.contains("Boss escape") or ui.label_message.text.contains("Boss escape"),"final boss escape objective visibly warns (not tooltip only)")
 await layout(ui,"final boss")
 ui.game.phase="won";ui.refresh();await layout(ui,"terminal")
 ui.restart_button.pressed.emit()
 check(ui.game.phase=="build" and ui.game.gold==24 and ui.restart_confirm.is_empty(),"UXR07 terminal retry immediate and no stale confirmation")
 settle_restart(ui)
 # Test actual New Run success after a changed run, then restore seed for deterministic rate trial.
 ui.explore_button.pressed.emit();ui.skip_reveal_button.pressed.emit()
 var previous_seed=ui.seed_value
 var old_run=whole_snapshot(ui)
 ui.new_seed_button.pressed.emit()
 check(whole_snapshot(ui)==old_run and ui.restart_confirm=="new","UXR07 changed run New Run first click no state change")
 ui.new_seed_button.pressed.emit()
 check(ui.seed_value!=previous_seed and ui.game.gold==24 and ui.game.reserve.is_empty() and ui.restart_confirm.is_empty(),"UXR07 exact New Run commit clears prior progress")
 var committed_seed=ui.seed_value
 var committed=whole_snapshot(ui)
 ui.new_seed_button.pressed.emit()
 check(ui.seed_value==committed_seed and whole_snapshot(ui)==committed and ui.restart_cooldown>0.0,"UXR07 repeated New Run confirmation cannot reseed during cooldown")
 settle_restart(ui)
 ui.seed_value=437;ui.game.reset(437);ui.refresh()
 ui.game.phase="won";ui.refresh()
 root.size=Vector2i(960,600)
 await process_frame
 await layout(ui,"960x600")
 var ref=rate_trial(ui,60,1)
 for fps in [30,60,120]:
  for rate in [1,2]:
   check(rate_trial(ui,fps,rate)==ref,"same fixed tick wave %d fps %dx"%[fps,rate])
 print("RENDER REF ",ref)
 print("UI checks=",checks," fails=",failures.size()," ",failures)
 quit(1 if not failures.is_empty() else 0)
func all(r):return r.towers+r.reserve
