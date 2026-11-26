extends SceneTree
const Main=preload("res://src/Main.tscn")
var checks=0
var failures=[]
func ck(v:bool,s:String):
 checks+=1
 if not v:failures.append(s);print("FAIL ",s)
func snapshot(ui):
 var g=ui.game
 return var_to_str([g.gold,g.phase,g.hp,g.stage,g.wave,g.route_choice,g.opened,g.towers,g.reserve,g.upgrades,g.rng.state,g.tick_count,g.kills,g.wave_leaks,g.run_leaks,g.last_loot,ui.seed_value,ui.selected_id,ui.selected_core,ui.paused,ui.speed])
func _initialize():call_deferred("run")
func run():
 var ui=Main.instantiate();ui.tutorial.persist_enabled=false;root.add_child(ui);ui.set_process(false)
 await process_frame
 ck(not ui.report_button.visible and ui.start_button.visible,"no report in build")
 var s=snapshot(ui)
 ui.report_button.pressed.emit()
 ck(snapshot(ui)==s and not ui.notice.begins_with("Copy requested"),"direct hidden callback rejected")
 # Real final-boss escape simulation; not writing phase lost directly.
 ui.seed_value=9001;ui.game.reset(ui.seed_value);ui.game.stage=2;ui.game.wave=1
 ui.game.reserve=[{"id":4,"kind":1,"rank":2,"cell":Vector2i(-1,-1),"cool":0.0,"order":"screen"}]
 ui.game.upgrades={"freeze":2};ui.game.deploy(4,Vector2i(0,0))
 ui.game.phase="fight";ui.game.pending=0
 ui.game.enemies=[{"id":99,"role":"boss","boss":true,"hp":100.0,"maxhp":100.0,"slow":0.0,"route":[Vector2(0,7),Vector2(1,7)],"pos":Vector2(0.99,7),"direction":Vector2.RIGHT,"segment":0,"speed":1.0,"second":false,"hit_tick":-1}]
 ui.refresh()
 ck(not ui.report_button.visible,"no report while active")
 ui.game.step();ui.refresh()
 ck(ui.game.phase=="lost" and ui.game.run_leaks==1 and ui.report_button.visible and not ui.start_button.visible,"terminal actual loss reveals optional report")
 var report=ui.test_report();s=snapshot(ui)
 ck(report.contains("P09") and report.contains("seed 9001") and report.contains("lost") and report.contains("stage 3 wave 2") and report.contains("HP 15") and report.contains("leaks 1") and report.contains("tick 1"),"report exact true data")
 ck(report.contains("screen, field") and report.contains("R2") and report.contains("freeze R2"),"actual crew order and relic")
 ck(not report.contains("user://") and not report.contains("http") and not report.contains("@") and not report.contains("device"),"report gameplay-only no identity/network URL")
 ck(snapshot(ui)==s and not ui.notice.begins_with("Copy requested"),"formatting is pure and terminal entry does not request copy")
 ui.report_button.pressed.emit()
 ck(snapshot(ui)==s and ui.notice.contains("nothing sent"),"explicit click local clipboard requested, no gameplay mutation")
 ui._restart(false)
 ck(ui.game.phase=="build" and not ui.report_button.visible and ui.start_button.visible,"retry clears report affordance")
 print("P09 REPORT ",checks-failures.size(),"/",checks," failures ",failures," clipboard backend ",DisplayServer.get_name())
 ui.audio.reset_scene();ui.audio._sea.stop();ui.audio._battle_bed.stop();ui.queue_free();await process_frame;await process_frame
 quit(1 if failures.size() else 0)
