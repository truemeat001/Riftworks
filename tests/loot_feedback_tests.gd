extends SceneTree
var failed=0
func check(ok:bool,why:String)->void:
	if not ok:
		failed+=1
		push_error(why)
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var main=load("res://src/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.loot_feedback_tier({"kind":"tower","rank":1})==0,"crew")
	check(main.loot_feedback_tier({"kind":"core","rank":1})==1,"relic")
	check(main.loot_feedback_tier({"kind":"core","rank":2})==2,"upgrade")
	var initial=main.game.gold
	main._explore()
	check(main.game.gold==initial-6,"single debit")
	var receipt=main.game.last_loot.duplicate(true)
	var rng=main.game.rng.state
	main._explore()
	check(main.game.gold==initial-6 and main.game.rng.state==rng and main.game.last_loot==receipt,"free skip preserves result")
	check(main.loot_age==main.LOOT_DURATION,"skip ends effect")
	main._explore()
	check(main.game.gold==initial-12,"next draw only after skip")
	main._skip_reveal()
	print("Loot feedback callback checks: ",7-failed,"/7")
	quit(0 if failed==0 else 1)
