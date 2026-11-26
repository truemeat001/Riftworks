extends RefCounted
## Optional presentation-only guide. It reads actual Run state and accepted UI actions.
## No model writes, no random calls, no tutorial-only rewards.
const PREFERENCE_PATH="user://riftworks_tutorial.cfg"
var active:bool=true
var step:String="explore"
var dismissed:bool=false
var persist_enabled:bool=true
var preference_path:String=PREFERENCE_PATH

func load_preference()->void:
	if not persist_enabled:return
	var cfg=ConfigFile.new()
	if cfg.load(preference_path)==OK:
		dismissed=bool(cfg.get_value("guide","dismissed",false))
		active=not dismissed

func _remember_dismissed()->void:
	dismissed=true
	if persist_enabled:
		var cfg=ConfigFile.new()
		cfg.set_value("guide","dismissed",true)
		# A storage failure must never block normal gameplay (e.g. private Web context).
		cfg.save(preference_path)

func begin(game)->void:
	active=true
	step="terminal" if game.phase in ["won","lost"] else ("fight" if game.phase=="fight" else "explore")
	observe(game)

func skip()->void:
	active=false
	step="done"
	_remember_dismissed()

func complete()->void:
	active=false
	step="done"
	_remember_dismissed()

func observe(game)->void:
	if not active:return
	if game.phase in ["won","lost"]:
		if step=="terminal":return
		complete()
		return
	if step=="after_wave":
		# Starting the next wave is itself a valid choice; no extra purchase is required.
		if game.phase=="fight":complete()
		return
	if game.phase=="fight":
		step="fight"
	elif step=="fight":
		step="after_wave"
	elif not game.towers.is_empty():
		step="start"
	elif not game.reserve.is_empty():
		step="deploy"
	else:
		step="explore"

func accepted_action(action:String)->void:
	if active and step=="after_wave" and action in ["explore","merge","route","deploy","start","mechanic"]:
		complete()

func instruction(game,selected:Dictionary)->String:
	if not active:return ""
	match step:
		"explore":return "GUIDE 1/5 · Explore for 6 coins. First two draws are crew."
		"deploy":return "GUIDE 2/5 · Click a highlighted tile; any legal tile is allowed." if not selected.is_empty() else "GUIDE 2/5 · Click a crew portrait, then a highlighted tile."
		"start":return "GUIDE 3/5 · %d deployed. Add crew or Start Wave (free)."%game.towers.size()
		"fight":return "GUIDE 4/5 · Watch the defense. Pause/resume or change speed."
		"after_wave":
			var receipt:String=str(game.message).split(" Prepare")[0]
			if receipt.begins_with("Wave clear!"):
				receipt=receipt.replace("Wave clear! Earned ","+").replace(" credits."," coins.")
				return "GUIDE 5/5 · "+receipt+" Route, merge, explore, deploy or start."
			return "GUIDE 5/5 · Choose route, merge, explore, deploy or start."
		"terminal":return "GUIDE · Run ended. Retry or New Run to practice."
	return ""
