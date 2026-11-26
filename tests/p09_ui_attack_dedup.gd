extends SceneTree
const Main=preload("res://src/Main.tscn")
var checks=0
var fails=0
func ck(ok:bool,msg:String):
	checks+=1
	if not ok:fails+=1;push_error(msg)
func _initialize():call_deferred("run")
func enemy(id:int,x:float,role:String,slow:float)->Dictionary:
	return {"id":id,"hit_tick":-1,"route":[Vector2(0,3),Vector2(10,3)],"pos":Vector2(x,3),"direction":Vector2.RIGHT,"segment":0,"hp":500.0,"maxhp":500.0,"slow":slow,"role":role,"boss":false,"speed":0.0,"second":false}
func wait_real(sec:float):
	var stop=Time.get_ticks_msec()+roundi(sec*1000)
	while Time.get_ticks_msec()<stop:
		await process_frame
		OS.delay_msec(4)
func run():
	var ui=Main.instantiate();root.add_child(ui);await process_frame;ui.set_process(false)
	ui.audio.unlock()
	ui.game.reset(437);ui.game.stage=1;ui.game.phase="fight";ui.game.pending=1;ui.game.spawn_time=100.0
	ui.game.towers=[{"id":7,"kind":0,"rank":1,"cell":Vector2i(5,3),"cool":0.0,"attack_tick":-1}]
	ui.game.enemies=[enemy(10,7,"normal",0),enemy(5,6,"guard",.8)]
	ui.audio.set_battle_active(true)
	var start=ui.audio.event_history().size()
	ui.game.step();ui.note_attacks()
	var events=ui.audio.event_history().slice(start)
	ck(ui.game.guard_intercepts.size()==1,"real redirect witnessed")
	ck(events.map(func(x):return x.id)==["hit_intercept","conductive"],"redirect primary and independent real synergy exactly once")
	var tick=ui.game.tick_count
	var original_clock=ui.audio._clock
	await wait_real(.24)
	ck(ui.audio._clock-original_clock>.15,"audio wall clock really elapsed beyond both coalescing gaps")
	ui.note_attacks()
	ck(ui.game.tick_count==tick and ui.audio.event_history().size()==start+2,"repeated callback cannot replay same tick after throttle expiry")
	ui.game.towers[0].cool=0.0
	ui.game.step();ui.note_attacks()
	ck(ui.audio.event_history().size()>start+2,"next real attack unaffected")
	ui.audio.reset_scene();ui.audio._sea.stop();ui.audio._battle_bed.stop();await wait_real(.3)
	ui.queue_free();await process_frame;await process_frame
	print("P09 ATTACK DEDUP checks=",checks," failures=",fails)
	quit(fails)
