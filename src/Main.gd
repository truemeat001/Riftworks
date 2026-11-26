extends Node2D

const Run = preload("res://src/Run.gd")
const ORIGIN = Vector2(32, 116)
const TILE = 68.0
const BOARD = Rect2(ORIGIN, Vector2(12,8)*TILE)
const BG = Color("111f27")
const PANEL = Color("20333a")
const PANEL_DARK = Color("172a31")
const BORDER = Color("455961")
const ACC = Color("6dd5ba")
const INK = Color("e5eef1")
const MUTED = Color("a6bdc9")
const ROUTE = Color("d5bc8a")
const WARN = Color("f1a36e")
const ERROR = Color("ff858c")
const AMP = Color("c6aafc")
const COLORS = [Color("80e4c0"),Color("75baf7"),Color("ffb16e")]
const ROLE = ["Precision", "Control", "Area damage"]
const SHORT_NAMES = ["Skirmisher", "Mist Weaver", "Reef Hammer"]
const FOE_LABELS = {"normal":"Hermit", "runner":"Sailbeast", "guard":"Shellguard", "boss":"Abyss Lord"}
const PHASES = {"build":"PLAN", "fight":"DEFEND", "won":"VICTORY", "lost":"DEFEAT"}

var game = Run.new()
var accumulator = 0.0
var selected_id:int = -1
var selected_core:String = ""
var merge_mode = false
var speed = 1.0
var paused = false
var seed_value = 437
var hover = Vector2i(-1,-1)
var notice = ""
var label_status:Label
var label_rule:Label
var label_forecast:Label
var label_phase:Label
var label_seed:Label
var label_tower_stats:Label
var label_feedback:Label
var label_message:Label
var label_reserve:Label
var label_core:Label
var label_selection:Label
var explore_button:Button
var skip_reveal_button:Button
var loot_reveal:Dictionary={}
var loot_age:float=2.0
const LOOT_DURATION=0.85
const CHEST=Vector2(1068,141)
var loot_label:Label
var scene_backdrops:Array[Texture2D]=[]
var chest_textures:Array[Texture2D]=[]
var crew_icons:Array[AtlasTexture]=[]
var sell_tower_button:Button
var merge_button:Button
var recall_button:Button
var sell_core_button:Button
var cancel_button:Button
var start_button:Button
var special_button:Button
var pause_button:Button
var speed_button:Button
var restart_button:Button
var new_seed_button:Button
var reserve_buttons:Array[Button] = []
var core_buttons:Array[Button] = []
var font:Font
var sprite_atlas:Texture2D
var sprite_manifest:Dictionary={}
var last_attacks:Dictionary={}
var last_directions:Dictionary={}
var idle_clock:float=0.0
var death_fx:Array=[]
const CREW_SPRITES=["pulse","frost","burst"]
const ENEMY_SPRITES={"normal":"crab","runner":"sail","guard":"urchin","boss":"boss"}

func load_sprites()->void:
	var atlas_path="res://assets/characters/atlas.png"
	var manifest_path="res://assets/characters/manifest.json"
	if ResourceLoader.exists(atlas_path) and FileAccess.file_exists(manifest_path):
		sprite_atlas=load(atlas_path)
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary: sprite_manifest=parsed
	for id in CREW_SPRITES:
		var frames:Array=sprite_manifest.get("characters",{}).get(id,{}).get("idle",[])
		if frames.is_empty() or sprite_atlas==null:
			crew_icons.append(null)
		else:
			var frame:Array=frames[0].rect
			var icon=AtlasTexture.new()
			icon.atlas=sprite_atlas
			icon.region=Rect2(frame[0],frame[1],frame[2],frame[3])
			icon.filter_clip=true
			crew_icons.append(icon)
	for filename in ["tidecross_background.png","twintide_background.png","echoreef_background.png"]:
		var path="res://assets/environment/"+filename
		scene_backdrops.append(load(path) if ResourceLoader.exists(path) else null)
	for filename in ["chest_closed.png","chest_open.png"]:
		var path="res://assets/items/"+filename
		chest_textures.append(load(path) if ResourceLoader.exists(path) else null)

func character_scale(id:String)->float:
	var frames:Array=sprite_manifest.get("characters",{}).get(id,{}).get("idle",[])
	if frames.is_empty():return 1.0
	var h:float=0.0
	for frame in frames:h=maxf(h,float(frame.rect[3]))
	var target_height=100.0 if id=="boss" else (46.0 if id=="crab" else (49.0 if id=="sail" else (60.0 if id=="urchin" else 70.0)))
	return target_height/maxf(1,h)

func draw_character(id:String,state:String,anchor:Vector2,scale_factor:float,elapsed:float,face_left:bool=false,ghost:bool=false)->bool:
	if sprite_atlas==null:return false
	var clips:Dictionary=sprite_manifest.get("characters",{}).get(id,{})
	if face_left and clips.has(state+"_left"):state+="_left"
	var frames:Array=clips.get(state,[])
	if frames.is_empty():return false
	var props:Dictionary=sprite_manifest.get("states",{}).get(state,sprite_manifest.get("states",{}).get(state.trim_suffix("_left"),{}))
	var idx:int=int(maxf(0,elapsed)*float(props.get("fps",8)))
	idx=posmod(idx,frames.size()) if props.get("loop",true) else mini(idx,frames.size()-1)
	var frame:Dictionary=frames[idx]
	var rect:Array=frame.rect
	var offset:Array=frame.offset
	var source=Rect2(rect[0],rect[1],rect[2],rect[3])
	var dest=Rect2(anchor+Vector2(offset[0],offset[1])*scale_factor,source.size*scale_factor)
	draw_texture_rect_region(sprite_atlas,dest,source,Color(1,1,1,0.48 if ghost else 1.0),false,true)
	return true

func note_attacks()->void:
	# Only the authoritative attack event may restart the presentation clip.
	for t in game.towers:
		if int(t.get("attack_tick",-1))!=game.tick_count:continue
		last_attacks[t.id]=game.tick_count
		for shot in game.shots:
			if int(shot.get("tower_id",-1))==t.id and Vector2(t.cell).is_equal_approx(shot.from):
				last_directions[t.id]=shot.to.x<shot.from.x
				break


func _ready() -> void:
	font = ThemeDB.fallback_font
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	load_sprites()
	var layer = CanvasLayer.new()
	add_child(layer)
	var ui = Control.new()
	ui.name = "HUD"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	make_label(ui, "RIFTWORKS", Rect2(32,14,220,34), 25)
	label_seed = make_label(ui, "", Rect2(32,52,220,20), 12, MUTED)
	label_status = make_label(ui, "", Rect2(270,14,350,52), 18)
	label_phase = make_label(ui, "", Rect2(630,15,230,20), 13, ACC)
	label_rule = make_label(ui, "", Rect2(630,38,230,52), 12, MUTED)
	label_forecast = make_label(ui, "", Rect2(883,14,365,66), 13, MUTED)
	label_message = make_label(ui, "", Rect2(32,78,590,32), 15, INK)
	explore_button = make_button(ui, "EXPLORE  /  6 COINS", Rect2(884,192,364,36), ACC, 16)
	explore_button.pressed.connect(_explore)
	loot_label = make_label(ui,"",Rect2(884,233,364,42),13,MUTED)
	skip_reveal_button = make_button(ui,"SKIP REVEAL",Rect2(1105,282,143,26),MUTED,12)
	skip_reveal_button.pressed.connect(func():_skip_reveal();refresh())
	label_selection = make_label(ui, "", Rect2(884,316,364,20), 14, ACC)
	label_tower_stats = make_label(ui, "", Rect2(884,341,364,38), 13, MUTED)
	merge_button = make_button(ui, "MERGE", Rect2(884,386,176,30), ACC, 13)
	merge_button.pressed.connect(_toggle_merge)
	recall_button = make_button(ui, "RECALL", Rect2(1072,386,176,30), MUTED, 13)
	recall_button.pressed.connect(_recall)
	sell_tower_button = make_button(ui, "SELL CREW", Rect2(884,421,176,30), WARN, 13)
	sell_tower_button.pressed.connect(_sell_selected_tower)
	cancel_button = make_button(ui, "CLEAR", Rect2(1072,421,176,30), MUTED, 13)
	cancel_button.pressed.connect(_clear_selection)
	make_label(ui,"TIDAL RELICS",Rect2(884,462,364,23),15,AMP)
	for i in range(Run.UPGRADES.size()):
		var b=make_button(ui,"",Rect2(884+(i%2)*188,489+int(i/2.0)*32,176,28),AMP,12)
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_select_core.bind(str(Run.UPGRADES[i].id)))
		core_buttons.append(b)
	label_core=make_label(ui,"",Rect2(884,622,364,65),12,MUTED)
	sell_core_button=make_button(ui,"SELL RANK +4",Rect2(884,690,364,29),WARN,13)
	sell_core_button.pressed.connect(_sell_selected_core)
	special_button = make_button(ui, "", Rect2(884,725,176,30), WARN, 12)
	special_button.pressed.connect(func():_skip_reveal();game.alter())
	start_button = make_button(ui, "START WAVE", Rect2(1072,725,176,30), ACC, 15)
	start_button.pressed.connect(_start)
	pause_button = make_button(ui, "PAUSE", Rect2(884,761,83,26), ACC, 12)
	pause_button.pressed.connect(_toggle_pause)
	speed_button = make_button(ui, "1x", Rect2(973,761,83,26), ACC, 12)
	speed_button.pressed.connect(_toggle_speed)
	restart_button = make_button(ui, "RETRY", Rect2(1062,761,83,26), MUTED, 12)
	restart_button.pressed.connect(_restart.bind(false))
	new_seed_button = make_button(ui, "NEW RUN", Rect2(1151,761,97,26), MUTED, 12)
	new_seed_button.pressed.connect(_restart.bind(true))
	label_feedback = make_label(ui, "", Rect2(32,668,816,24), 13, MUTED)
	label_reserve = make_label(ui, "", Rect2(32,696,816,22), 13, ACC)
	for i in range(9):
		var b=make_button(ui,"",Rect2(32+i*91,725,87,62),ACC,11)
		b.pressed.connect(_reserve_clicked.bind(i))
		b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",31)
		reserve_buttons.append(b)
	game.changed.connect(refresh)
	game.reset(seed_value)

func make_label(parent:Node, value:String, area:Rect2, sz:int, c:Color=INK) -> Label:
	var l = Label.new()
	l.position = area.position
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",sz)
	l.add_theme_color_override("font_color",c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.size = area.size
	l.text = value
	l.set_deferred("size",area.size)
	return l

func button_style(fill:Color, edge:Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 11
	box.content_margin_right = 11
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

func make_button(parent:Node, value:String, area:Rect2, color:Color=ACC, sz:int=14)->Button:
	var b = Button.new()
	b.text = value
	b.position = area.position
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size",sz)
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	b.add_theme_color_override("font_pressed_color",Color.WHITE)
	b.add_theme_color_override("font_disabled_color",Color("748894"))
	b.add_theme_stylebox_override("normal",button_style(Color("1b3040"),color.darkened(0.43)))
	b.add_theme_stylebox_override("hover",button_style(Color("2b4350"),color))
	b.add_theme_stylebox_override("pressed",button_style(color.darkened(0.64),color))
	b.add_theme_stylebox_override("disabled",button_style(Color("18242d"),Color("263946")))
	b.add_theme_stylebox_override("focus",button_style(Color(0,0,0,0),color))
	parent.add_child(b)
	b.size = area.size
	return b

func _skip_reveal()->void:
	loot_age=LOOT_DURATION
	skip_reveal_button.visible=false
	queue_redraw()

func _explore()->void:
	if loot_age<LOOT_DURATION:
		_skip_reveal()
		refresh()
		return
	_skip_reveal()
	notice=""
	var result:Dictionary=game.draw_loot()
	if result.is_empty() or not result.get("ok",true):
		notice=game.message
	else:
		loot_reveal=result.duplicate(true)
		loot_age=0.0
		if result.get("kind","")=="tower":
			selected_id=int(result.get("id",-1))
			selected_core=""
			merge_mode=false
		elif result.get("kind","")=="core":
			selected_core=str(result.get("id",""))
			selected_id=-1
			merge_mode=false
	refresh()

func _select_core(id:String)->void:
	_skip_reveal()
	selected_core=id
	notice=""
	refresh()

func _sell_selected_core()->void:
	_skip_reveal()
	notice=""
	if not game.sell_core(selected_core): notice="Select a held core rank to sell."
	refresh()

func get_tower(id:int)->Dictionary:
	for t in game.towers:
		if t.id==id:return t
	for t in game.reserve:
		if t.id==id:return t
	return {}

func is_deployed(t:Dictionary)->bool:
	return not t.is_empty() and inside(t.cell)

func _clear_selection()->void:
	_skip_reveal()
	selected_id=-1
	merge_mode=false
	notice=""
	refresh()

func _select_tower(id:int)->void:
	_skip_reveal()
	if merge_mode:
		if id==selected_id:
			notice="Select a different matching tower."
		elif not can_merge(get_tower(selected_id),get_tower(id)):
			notice="Merge needs same type and rank below rank 3."
		elif game.merge_towers(selected_id,id):
			merge_mode=false
			notice=""
		else:
			notice="Merge was not available."
	else:
		selected_id=id
		notice=""
	refresh()

func can_merge(a:Dictionary,b:Dictionary)->bool:
	return not a.is_empty() and not b.is_empty() and a.id!=b.id and a.kind==b.kind and a.rank==b.rank and a.rank<3

func has_merge_partner(t:Dictionary)->bool:
	for other in game.towers+game.reserve:
		if can_merge(t,other):return true
	return false

func _toggle_merge()->void:
	_skip_reveal()
	if merge_mode:
		merge_mode=false
	else:
		merge_mode=has_merge_partner(get_tower(selected_id)) and game.phase=="build"
	notice=""
	refresh()

func _reserve_clicked(index:int)->void:
	if index<game.reserve.size(): _select_tower(game.reserve[index].id)

func _recall()->void:
	_skip_reveal()
	notice=""
	if not game.recall(selected_id):notice="Select a deployed tower to recall."
	refresh()

func _sell_selected_tower()->void:
	_skip_reveal()
	notice=""
	if game.sell_tower(selected_id):
		selected_id=-1
		merge_mode=false
	else:
		notice=game.message if game.phase=="build" and not get_tower(selected_id).is_empty() else "Select a tower to sell during planning."
	refresh()

func _start()->void:
	_skip_reveal()
	notice=""
	merge_mode=false
	paused=false
	if not game.start():notice="Deploy at least one tower before starting."
	refresh()

func _toggle_pause()->void:
	if game.phase=="fight":
		paused=not paused
		accumulator=0.0
		refresh()

func _toggle_speed()->void:
	speed=2.0 if speed==1.0 else 1.0
	refresh()

func _restart(random_seed:bool)->void:
	_skip_reveal()
	loot_reveal.clear()
	if random_seed:seed_value=int(Time.get_ticks_msec())+437
	paused=false
	accumulator=0.0
	notice=""
	hover=Vector2i(-1,-1)
	selected_id=-1
	selected_core=""
	merge_mode=false
	last_attacks.clear()
	last_directions.clear()
	death_fx.clear()
	idle_clock=0.0
	game.reset(seed_value)

func update_status()->void:
	label_status.text="STATION %02d   COINS %02d\nSector %d / 3    Wave %d / 2" % [maxi(game.hp,0),game.gold,game.stage+1,game.wave+1]
	label_phase.text="%s  /  FIELD %d/5  OWNED %d/9" % ["PAUSED" if paused else PHASES.get(game.phase,game.phase),game.towers.size(),game.towers.size()+game.reserve.size()]
	var f:Dictionary=game.forecast()
	if game.phase in ["won","lost"]:
		label_forecast.text="Run complete • %d total leaks"%game.run_leaks
	elif game.phase=="fight":
		label_forecast.text="Approaching %d  •  Field %d\nDefeated %d  •  Leaks %d" % [game.pending,game.enemies.size(),game.kills,game.wave_leaks]
	else:
		var roles:Dictionary=f.get("roles",{})
		var role_hp:Dictionary=f.get("role_hp",{})
		var parts:Array[String]=[]
		for key in ["normal","runner","guard","boss"]:
			if int(roles.get(key,0))>0:
				parts.append("%s %d×%.0f"%[FOE_LABELS[key],roles[key],role_hp[key]])
		label_forecast.text="NEXT  •  %s"%("  /  ".join(parts))
		if f.get("extra",0)>0: label_forecast.text+="\nExtra %d×%.0f HP"%[f.extra,f.extra_hp]

func refresh()->void:
	if game.phase!="fight":
		paused=false
		last_attacks.clear()
	if game.phase!="build":merge_mode=false
	var t=get_tower(selected_id)
	if t.is_empty():selected_id=-1;merge_mode=false
	var planning:bool=game.phase=="build"
	update_status()
	label_seed.text="P04 / Seed %d"%seed_value
	label_rule.text=Run.NAMES[game.stage].to_upper()+"\n"+["Switch the tidal crossing.","Open second inlet: +6 if leak-free.","Echo reefs amplify your crew."][game.stage]
	if game.stage==2 and game.wave==1 and planning:
		label_rule.text="ECHO REEF / FINAL WAVE\nBoss escape = immediate defeat."
	var odds:Dictionary=game.reward_odds()
	var crew_pct:float=float(odds.get("tower",0.0))*100.0
	var core_pct:float=float(odds.get("core",0.0))*100.0
	explore_button.disabled=loot_age>=LOOT_DURATION and (not planning or game.gold<6 or crew_pct+core_pct<=0)
	explore_button.text="SKIP REVEAL  /  FREE" if loot_age<LOOT_DURATION else ("EXPLORE 6  ·  %d%% CREW / %d%% RELIC"%[roundi(crew_pct),roundi(core_pct)])
	explore_button.tooltip_text="Skip visual only; no extra cost." if loot_age<LOOT_DURATION else "Spend 6 run-only coins for one random eligible reward. Equal within each category. Below 2 crew, always crew."
	if loot_age>=LOOT_DURATION and explore_button.disabled:
		explore_button.text="EXPLORE · "+("BETWEEN WAVES" if not planning else ("NEED 6 COINS" if game.gold<6 else "POOL EMPTY"))

	skip_reveal_button.visible=loot_age<LOOT_DURATION
	loot_label.text=("Found: %s  •  Rank %d"%[loot_reveal.get("name","Reward"),int(loot_reveal.get("rank",1))]) if not loot_reveal.is_empty() else "One random result. Crew joins reserve; relic applies immediately."
	if planning and game.towers.size()+game.reserve.size()<2 and loot_age>=LOOT_DURATION:
		loot_label.text+="\nFirst two crew guaranteed."
	merge_button.text="CANCEL MERGE" if merge_mode else "MERGE 2 → 1"
	merge_button.disabled=not planning or (not merge_mode and not has_merge_partner(t))
	recall_button.disabled=not planning or not is_deployed(t)
	sell_tower_button.text="SELL +%d"%game.tower_sale_value(t.rank) if not t.is_empty() else "SELL TOWER"
	sell_tower_button.disabled=not planning or t.is_empty() or merge_mode
	cancel_button.disabled=selected_id<0
	label_selection.text="SELECTED  /  "+("%s R%d #%d"%[SHORT_NAMES[t.kind],t.rank,t.id] if not t.is_empty() else "NONE")
	special_button.visible=game.stage<2
	special_button.disabled=not planning
	if game.stage==0:
		special_button.text="SWITCH  /  %s (%s cells)"%["UPPER" if game.route_choice==0 else "LOWER",str(game.route_lengths()[game.route_choice])]
	elif game.stage==1:
		special_button.text="EXTRA RIFT: "+("OPEN  (+6)" if game.opened else "CLOSED")
	start_button.disabled=not planning or game.towers.is_empty()
	pause_button.disabled=game.phase!="fight"
	pause_button.text="RESUME" if paused else "PAUSE"
	speed_button.text="SPEED %dx"%int(speed)
	label_message.text=game.message
	if game.phase=="won" or game.phase=="lost":
		label_message.text=game.message+"  •  Leaks: %d"%game.run_leaks
	elif planning and game.message=="Build a defense, then start the wave.":
		label_message.text="Explore for a random reward, then deploy crew on a free tile."
	label_reserve.text="CREW %d / 9  ·  Select then click free tile. Merge matching ranks."%game.reserve.size()
	for i in range(9):
		var b=reserve_buttons[i]
		b.disabled=i>=game.reserve.size() or not planning
		if i>=game.reserve.size():
			b.text="—";b.icon=null;b.modulate=Color("9aaab2")
		else:
			var r:Dictionary=game.reserve[i]
			b.text="%s%s R%d"%[">" if r.id==selected_id else "",["Brass","Mist","Reef"][r.kind],r.rank]
			b.icon=crew_icons[r.kind] if crew_icons.size()>r.kind else null
			b.modulate=COLORS[r.kind] if r.id==selected_id or (merge_mode and can_merge(t,r)) else Color.WHITE
	for i in range(Run.UPGRADES.size()):
		var u:Dictionary=Run.UPGRADES[i]
		var rank:int=game.level(u.id)
		var b:Button=core_buttons[i]
		b.text="%s%s  %d/%d"%["> " if selected_core==u.id else "",u.name,rank,Run.MAX_RANK[u.id]]
		b.tooltip_text=u.description
		b.modulate=AMP if selected_core==u.id else (Color.WHITE if rank>0 else Color("8497a5"))
	label_core.text="Select a module to see its effect and sell one rank."
	for u in Run.UPGRADES:
		if u.id==selected_core:
			label_core.text="%s  R%d\n%s"%[u.name,game.level(u.id),u.description]
	sell_core_button.disabled=not planning or selected_core.is_empty() or game.level(selected_core)<=0
	update_hover()
	queue_redraw()

func _process(delta:float)->void:
	if loot_age<LOOT_DURATION:
		loot_age=minf(LOOT_DURATION,loot_age+delta)
		skip_reveal_button.visible=loot_age<LOOT_DURATION
		if loot_age>=LOOT_DURATION:refresh()
	if not paused:
		idle_clock=fmod(idle_clock+minf(delta,0.25),60.0)
		for i in range(death_fx.size()-1,-1,-1):
			death_fx[i].age+=delta
			if death_fx[i].age>=0.45:death_fx.remove_at(i)
	if game.phase=="fight" and not paused:
		accumulator+=minf(delta,0.25)*speed
		while accumulator>=Run.TICK and game.phase=="fight":
			var stage_before:int=game.stage
			game.step()
			note_attacks()
			if stage_before!=game.stage:death_fx.clear()
			else:
				for d in game.get("deaths"):
					if int(d.tick)==game.tick_count:
						var visual:Dictionary=d.duplicate(true)
						visual.age=0.0
						death_fx.append(visual)
			accumulator-=Run.TICK
		update_status()
	else:
		accumulator=0.0
	var cursor=get_global_mouse_position()
	var next_hover=Vector2i(floor((cursor.x-ORIGIN.x)/TILE),floor((cursor.y-ORIGIN.y)/TILE))
	if next_hover!=hover:
		hover=next_hover
		notice=""
		update_hover()
	queue_redraw()

func inside(cell:Vector2i)->bool:
	return cell.x>=0 and cell.x<Run.COLS and cell.y>=0 and cell.y<Run.ROWS

func tower_at(cell:Vector2i)->Dictionary:
	for t in game.towers:
		if t.cell==cell:return t
	return {}

func coord(p:Vector2)->Vector2:
	return ORIGIN+(p+Vector2(0.5,0.5))*TILE

func candidate_error(cell:Vector2i,t:Dictionary)->String:
	if t.is_empty():return "Draw or select a tower first."
	return game.placement_error(cell,t.kind,t.id)

func update_hover()->void:
	var t=get_tower(selected_id)
	var viewed=tower_at(hover) if inside(hover) else {}
	var st:Array=[]
	if not viewed.is_empty():
		st=game.stats(viewed)
	elif not t.is_empty():
		st=game.preview_stats(hover if inside(hover) else t.cell,t.kind,t.rank,t.id)
		viewed=t
	if viewed.is_empty():
		label_tower_stats.text="Three crew roles: equal odds.\nSelect two matching towers to merge."
	else:
		label_tower_stats.text="%s R%d: %.1f dmg / %.2fs\n%.1f range  •  %s"%[SHORT_NAMES[viewed.kind],viewed.rank,st[0],st[2],st[1],"AMP + RELAY" if st[4] and st[5] else ("AMP" if st[4] else ("RELAY" if st[5] else ROLE[viewed.kind]))]
	label_feedback.add_theme_color_override("font_color",MUTED)
	if not notice.is_empty():
		label_feedback.text=notice
		label_feedback.add_theme_color_override("font_color",WARN)
	elif merge_mode:
		var old_stats:Array=game.stats(t)
		var merged_stats:Array=game.preview_stats(t.cell,t.kind,t.rank+1,t.id)
		label_feedback.text="MERGE: %s R%d + R%d → R%d  •  %.1f → %.1f dmg"%[SHORT_NAMES[t.kind],t.rank,t.rank,t.rank+1,old_stats[0],merged_stats[0]]
		label_feedback.add_theme_color_override("font_color",ACC)
	elif not inside(hover):
		label_feedback.text="Select a crew member to deploy or move  •  Solid path active  •  Purple amplifier"
	elif not tower_at(hover).is_empty():
		var other=tower_at(hover)
		label_feedback.text="Click %s R%d at %s to select  •  Right-click to recall"%[SHORT_NAMES[other.kind],other.rank,cell_name(hover)]
	elif game.phase=="build":
		var reason=candidate_error(hover,t)
		if reason.is_empty():
			label_feedback.text="%s %s R%d at %s  •  FREE"%["Move" if is_deployed(t) else "Deploy",SHORT_NAMES[t.kind],t.rank,cell_name(hover)]
			label_feedback.add_theme_color_override("font_color",ACC)
		else:
			label_feedback.text="%s: %s"%[cell_name(hover),reason]
			label_feedback.add_theme_color_override("font_color",WARN)
	else:
		label_feedback.text="Battle active  •  draw, deploy and sell between waves."

func cell_name(c:Vector2i)->String:
	return "%s%d"%[char(65+c.x),c.y+1]

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:_toggle_pause()
			KEY_ESCAPE:_clear_selection()
	if event is InputEventMouseButton and event.pressed:
		var cell=Vector2i(floor((event.position.x-ORIGIN.x)/TILE),floor((event.position.y-ORIGIN.y)/TILE))
		if not inside(cell):return
		_skip_reveal()
		hover=cell
		notice=""
		var target=tower_at(cell)
		if event.button_index==MOUSE_BUTTON_LEFT:
			if not target.is_empty():
				_select_tower(target.id)
			elif merge_mode:
				notice="Click a matching tower, not an empty cell."
			else:
				var t=get_tower(selected_id)
				var reason=candidate_error(cell,t)
				if not reason.is_empty():notice=reason
				elif not game.deploy(selected_id,cell):notice="Deployment unavailable."
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			if not target.is_empty():
				selected_id=target.id
				merge_mode=false
				_recall()
			else:
				notice="Select an existing tower to recall."
		refresh()

func draw_route(route:Array[Vector2],c:Color,active:bool=true)->void:
	for i in range(route.size()-1):
		var a=coord(route[i])
		var b=coord(route[i+1])
		if active:
			draw_line(a,b,Color("263842"),37,true)
			draw_line(a,b,c,32,true)
			draw_line(a,b,c.lightened(0.09),3,true)
		else:
			draw_dashed_line(a,b,Color("4e6572"),3,12,true)
	for p in route:
		if active: draw_circle(coord(p),16,c)
	if not active:
		return
	for i in range(route.size()-1):
		var a=coord(route[i]); var b=coord(route[i+1]); var d=(b-a).normalized()
		for step_idx in range(1,maxi(2,int(a.distance_to(b)/48))):
			var mid=a+d*(a.distance_to(b)*float(step_idx)/float(maxi(2,int(a.distance_to(b)/48))))
			draw_line(mid-d*6+d.orthogonal()*5,mid+d*2,Color("584d45"),2,true)
			draw_line(mid+d*2,mid-d*6-d.orthogonal()*5,Color("584d45"),2,true)

func draw_entry(cell:Vector2,name_text:String,active:bool)->void:
	var p=coord(cell)
	var c=WARN if active else Color("536875")
	draw_circle(p,22,Color("141e2a"))
	draw_arc(p,21,0,TAU,32,c,3,true)
	draw_arc(p,15,0.1,TAU-0.1,32,c,1.5,true)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-6,-8),p+Vector2(9,0),p+Vector2(-6,8)]),c)
	draw_string(font,p+Vector2(-27,-29),name_text,HORIZONTAL_ALIGNMENT_CENTER,54,10,c)

func draw_range(center:Vector2,radius:float,c:Color)->void:
	var alpha=Color(c,0.10)
	# Shaded cells show usable coverage without drawing beyond map boundaries.
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			var p=coord(Vector2(x,y))
			if center.distance_to(p)<=radius:
				draw_rect(Rect2(p-Vector2.ONE*(TILE/2-2),Vector2.ONE*(TILE-4)),alpha)
	var previous=center+Vector2(radius,0)
	for i in range(1,97):
		var next=center+Vector2.from_angle(TAU*float(i)/96.0)*radius
		if BOARD.has_point(previous) and BOARD.has_point(next):
			draw_line(previous,next,Color(c,0.78),1.5,true)
		previous=next

func draw_tower(p:Vector2,kind:int,ghost:bool=false,id:int=-1)->void:
	# Feet remain within the top row instead of obscuring the header.
	var anchor=p+Vector2(0,30 if p.y<ORIGIN.y+TILE else 13)
	var attack_age=(game.tick_count-int(last_attacks.get(id,-999)))*Run.TICK
	var attacking=game.phase=="fight" and attack_age>=0 and attack_age<0.33
	draw_ellipse_shadow(anchor,15)
	if draw_character(CREW_SPRITES[kind],"attack" if attacking else "idle",anchor,character_scale(CREW_SPRITES[kind]),attack_age if attacking else (game.tick_count*Run.TICK if game.phase=="fight" else idle_clock),bool(last_directions.get(id,false)),ghost):
		return
	var c=Color(COLORS[kind],0.55 if ghost else 1.0)
	draw_circle(p+Vector2(0,4),20,Color("111b26"))
	draw_circle(p,17,Color("203746"))
	draw_arc(p,20,0,TAU,32,c,2,true)
	match kind:
		0:
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-13),p+Vector2(12,0),p+Vector2(0,13),p+Vector2(-12,0)]),c)
			draw_circle(p,4,BG)
		1:
			for i in range(6):
				var d=Vector2.from_angle(TAU*float(i)/6.0)
				draw_line(p,p+d*13,c,3,true)
			draw_circle(p,4,c)
		2:
			draw_rect(Rect2(p-Vector2.ONE*12,Vector2.ONE*24),c,false,3)
			draw_circle(p,6,c)

func draw_ellipse_shadow(anchor:Vector2,radius:float)->void:
	draw_set_transform(anchor,0,Vector2(1,0.32))
	draw_circle(Vector2.ZERO,radius,Color("172a31"))
	draw_set_transform(Vector2.ZERO)

func draw_loot_presentation()->void:
	var chest_open=loot_age>=0.18 and loot_age<LOOT_DURATION and not loot_reveal.is_empty()
	var shake=sin(loot_age*80)*3.0 if loot_age<0.18 else 0.0
	var p=CHEST+Vector2(shake,0)
	# Brass framed treasure chest, grounded at dock. Reward is credited before this cosmetic motion.
	draw_ellipse_shadow(p+Vector2(0,35),45)
	var tex:Texture2D=chest_textures[int(chest_open)] if chest_textures.size()==2 else null
	if tex!=null:
		draw_texture_rect(tex,Rect2(p-Vector2(44,43),Vector2(88,88)),false)
	else:
		draw_chest_fallback(p,chest_open)
	if loot_reveal.is_empty() or loot_age<0.18 or loot_age>=LOOT_DURATION:return
	var flash=maxf(0,1-(loot_age-0.18)/0.3)
	draw_circle(p-Vector2(0,18),52*flash,Color(0.78,0.93,0.8,0.28*flash))
	var progress=clampf((loot_age-0.3)/0.55,0,1)
	var target=Vector2(800,745)
	if loot_reveal.kind=="core":
		for i in range(Run.UPGRADES.size()):
			if Run.UPGRADES[i].id==loot_reveal.id:target=core_buttons[i].get_global_rect().get_center()
	else:
		for i in range(game.reserve.size()):
			if game.reserve[i].id==loot_reveal.id:target=reserve_buttons[i].get_global_rect().get_center()
	var from=p+Vector2(-58,38-10*sin(clampf((loot_age-0.18)/0.2,0,1)*PI/2))
	var point=from.lerp(target,progress*progress*(3-2*progress))
	if loot_reveal.kind=="tower":
		draw_character(CREW_SPRITES[int(loot_reveal.tower_kind)],"idle",point,character_scale(CREW_SPRITES[int(loot_reveal.tower_kind)])*(0.82-0.42*progress),loot_age)
	else:
		draw_colored_polygon(PackedVector2Array([point+Vector2(0,-22),point+Vector2(16,0),point+Vector2(0,22),point+Vector2(-16,0)]),AMP)
		draw_arc(point,24,0,TAU,48,Color(AMP,0.7),2,true)

func draw_chest_fallback(p:Vector2,chest_open:bool)->void:
	draw_rect(Rect2(p+Vector2(-42,-3),Vector2(84,35)),Color("96614a"))
	draw_rect(Rect2(p+Vector2(-42,-3),Vector2(84,35)),Color("deb482"),false,3)
	for x in [-32,27]: draw_rect(Rect2(p+Vector2(x,-3),Vector2(6,35)),Color("ca9b61"))
	var lid_y=-22.0 if not chest_open else -39.0
	draw_rect(Rect2(p+Vector2(-42,lid_y),Vector2(84,22)),Color("b57b52"))
	draw_rect(Rect2(p+Vector2(-42,lid_y),Vector2(84,22)),Color("e2bd7b"),false,3)
	draw_rect(Rect2(p+Vector2(-7,-8),Vector2(14,16)),Color("e7c38b"))
func _draw()->void:
	if font==null:return
	draw_rect(Rect2(0,0,1280,800),BG)
	var scene:Texture2D=scene_backdrops[game.stage] if scene_backdrops.size()>game.stage else null
	if scene==null and not scene_backdrops.is_empty():scene=scene_backdrops[0]
	if scene!=null:draw_texture_rect(scene,BOARD,false)
	draw_rect(Rect2(18,8,1244,101),PANEL_DARK)
	draw_rect(Rect2(868,110,396,682),PANEL_DARK)
	draw_rect(Rect2(18,662,844,130),PANEL_DARK)
	draw_rect(Rect2(868,110,396,682),BORDER,false,1)
	draw_rect(Rect2(18,662,844,130),BORDER,false,1)
	draw_rect(BOARD.grow(3),BORDER,false,2)
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			var p=ORIGIN+Vector2(x,y)*TILE
			var ground=[Color("42514d"),Color("29484d"),Color("394653")][game.stage]
			var c=ground.lightened(0.035) if (x+y)%2==0 else ground
			# Tidal deck cells use muted plank seams and rivets rather than noisy scenery.
			draw_rect(Rect2(p+Vector2(1,1),Vector2(TILE-2,TILE-2)),Color(c,0.35) if scene!=null else c)
			if scene==null and not game.reserved(Vector2i(x,y)):
				draw_line(p+Vector2(3,18),p+Vector2(TILE-3,18),Color("263b3f"),1)
				draw_line(p+Vector2(3,36),p+Vector2(TILE-3,36),Color("263b3f"),1)
				draw_rect(Rect2(p+Vector2(5,5),Vector2(2,2)),Color("878276"))
			if game.reserved(Vector2i(x,y)):
				draw_rect(Rect2(p+Vector2(2,2),Vector2(TILE-4,TILE-4)),Color(0.18,0.22,0.23,0.35))
			if x==0: draw_string(font,p+Vector2(-16,30),str(y+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
			if y==0: draw_string(font,p+Vector2(23,-5),char(65+x),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
	if game.stage==0:
		var inactive=game.maze_path(1-game.route_choice)
		draw_route(inactive,ROUTE,false)
	if game.stage==1:
		draw_route(game.path(false),WARN,game.opened)
	draw_route(game.path(),ROUTE,true)
	if game.stage==1: draw_entry(game.path(false)[0],"RIFT B",game.opened)
	draw_entry(game.path()[0],"RIFT A",true)
	if game.stage==2:
		for cell in Run.AMP_CELLS:
			var p=coord(Vector2(cell))
			draw_rect(Rect2(p-Vector2.ONE*24,Vector2.ONE*48),Color("39344d"))
			draw_arc(p,19,0,TAU,32,AMP,2,true)
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-17),p+Vector2(12,0),p+Vector2(0,17),p+Vector2(-12,0)]),AMP)
			draw_string(font,p+Vector2(-16,4),"AMP",HORIZONTAL_ALIGNMENT_LEFT,-1,11,BG)
	var core=coord(Vector2(11,4))
	draw_circle(core,25,Color("123e43"))
	draw_arc(core,24,0,TAU,40,ACC,3,true)
	draw_colored_polygon(PackedVector2Array([core+Vector2(0,-18),core+Vector2(15,-7),core+Vector2(11,17),core+Vector2(-11,17),core+Vector2(-15,-7)]),ACC)
	draw_string(font,core+Vector2(-20,40),"CORE",HORIZONTAL_ALIGNMENT_CENTER,40,11,INK)
	if inside(hover):
		var hovered=tower_at(hover)
		if not hovered.is_empty():
			draw_range(coord(Vector2(hover)),game.stats(hovered)[1]*TILE,COLORS[hovered.kind])
		else:
			var t=get_tower(selected_id)
			if game.phase=="build" and not merge_mode and candidate_error(hover,t).is_empty():
				draw_range(coord(Vector2(hover)),game.preview_stats(hover,t.kind,t.rank,t.id)[1]*TILE,COLORS[t.kind])
	if game.stage==2:
		for t in game.towers:
			var p=coord(Vector2(t.cell))
			for a in Run.AMP_CELLS:
				if Vector2(t.cell).distance_to(Vector2(a))<=1.5:
					draw_dashed_line(p,coord(Vector2(a)),Color(AMP,0.75),2.0,6.0,true)
	if game.level("relay")>0:
		for i in range(game.towers.size()):
			var t=game.towers[i]
			for j in range(i+1,game.towers.size()):
				var other=game.towers[j]
				if Vector2(t.cell).distance_to(Vector2(other.cell))<=2.1:
					draw_line(coord(Vector2(t.cell)),coord(Vector2(other.cell)),Color(ACC,0.70),2,true)
	for t in game.towers:
		var p=coord(Vector2(t.cell))
		var st=game.stats(t)
		if st[4]:
			draw_arc(p,24,0,TAU,32,AMP,2,true)
		if st[5]:
			draw_arc(p,26,0,PI,24,ACC,2,true)
		draw_tower(p,t.kind,false,t.id)
		if t.id==selected_id or (merge_mode and can_merge(get_tower(selected_id),t)):
			draw_rect(Rect2(p-Vector2.ONE*24,Vector2.ONE*48),ACC,false,2)
		draw_string(font,p+Vector2(-23,22),"R%d"%t.rank,HORIZONTAL_ALIGNMENT_LEFT,-1,11,INK)
	for e in game.enemies:
		var p=coord(e.pos)
		var r=19.0 if e.boss else 9.0
		var c=Color("f2767c") if e.slow<=0 else Color("9bcdf7")
		var sprite_id:String=ENEMY_SPRITES.get(e.get("role","normal"),"crab")
		var dir:Vector2=e.get("direction",Vector2.RIGHT)
		var anchor=p+Vector2(0,13)
		draw_ellipse_shadow(anchor,r+3)
		var hit_age=(game.tick_count-int(e.get("hit_tick",-999)))*Run.TICK
		var hurt=hit_age>=0 and hit_age<0.16
		if not draw_character(sprite_id,"hurt" if hurt else "run",anchor,character_scale(sprite_id),hit_age if hurt else game.tick_count*Run.TICK,dir.x<0):
			draw_circle(p,r,c)
		if e.slow>0:draw_arc(anchor,12,0,TAU,24,c,1.5,true)
		if e.boss: draw_arc(p,r+4,0,TAU,36,WARN,3,true)
		draw_rect(Rect2(p+Vector2(-15,28),Vector2(30,4)),BG)
		draw_rect(Rect2(p+Vector2(-15,28),Vector2(30*clampf(e.hp/e.maxhp,0,1),4)),Color("ffc0a5"))
	for d in death_fx:
		var p=coord(d.pos)+Vector2(0,13)
		var sprite_id:String=ENEMY_SPRITES.get(d.role,"crab")
		draw_character(sprite_id,"death",p,character_scale(sprite_id),d.age,d.direction.x<0)
	if game.phase=="fight":
		for s in game.shots:
			draw_line(coord(s.from),coord(s.to),Color(COLORS[s.kind],0.7),3,true)
			draw_circle(coord(s.to),5,COLORS[s.kind])
			var synergy:String=s.get("synergy","")
			if not synergy.is_empty():
				var color=Color("a2e9f0") if synergy=="conductive" else Color("ffd18f")
				draw_arc(coord(s.to),17,0,TAU,24,color,2,true)
				draw_string(font,coord(s.to)+Vector2(-31,-12),synergy.to_upper(),HORIZONTAL_ALIGNMENT_CENTER,62,10,color)
	if game.phase=="build" and inside(hover) and not merge_mode and tower_at(hover).is_empty():
		var t=get_tower(selected_id)
		if not t.is_empty():
			var p=coord(Vector2(hover))
			var legal=candidate_error(hover,t).is_empty()
			draw_rect(Rect2(p-Vector2.ONE*(TILE/2-2),Vector2.ONE*(TILE-4)),ACC if legal else WARN,false,2)
			if legal:draw_tower(p,t.kind,true)
	draw_loot_presentation()
	if paused:
		draw_rect(BOARD,Color(0.05,0.08,0.14,0.42))
		draw_rect(Rect2(BOARD.get_center()-Vector2(112,26),Vector2(224,52)),PANEL)
		draw_string(font,BOARD.get_center()+Vector2(-112,9),"PAUSED",HORIZONTAL_ALIGNMENT_CENTER,224,24,INK)
