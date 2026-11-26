extends Node2D

const Run = preload("res://src/Run.gd")
const ORIGIN = Vector2(52, 60)
const TILE = 76.0
const BOARD = Rect2(ORIGIN, Vector2(12,8)*TILE)
const MAP_RECT=Rect2(0,46,1016,630)
const BG = Color("c7ddda")
const PANEL = Color("f5ebd6")
const PANEL_DARK = Color("fff6e4")
const BORDER = Color("80999a")
const FUNCTIONAL_BORDER=Color("607c7d")
const ACC = Color("176d72")
const PRIMARY = Color("ad4631")
const RESOURCE = Color("865517")
const INK = Color("213d48")
const MUTED = Color("546568")
const ROUTE = Color("dfc79a")
const WARN = Color("9d343c")
const ERROR = Color("9d343c")
const AMP = Color("77608e")
const COLORS = [Color("a97544"),Color("287f91"),Color("b65a41")]
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
const CHEST=Vector2(1146,90)
var loot_label:Label
var scene_backdrops:Array[Texture2D]=[]
var chest_textures:Array[Texture2D]=[]
var crew_icons:Array[Texture2D]=[]
var environment_icons:Dictionary={}
var relic_icons:Array[Texture2D]=[]
var sell_confirm:String=""
var restart_confirm:String=""
var restart_cooldown:float=0.0
var pointer_cell:=Vector2i(-1,-1)
var pointer_button:int=0
var paper_styles:Dictionary={}
var route_visual_cache:Dictionary={}
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
		var portrait="res://assets/characters/portraits/"+id+".png"
		if ResourceLoader.exists(portrait):
			crew_icons.append(load(portrait))
			continue
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
	for id in ["portal","lighthouse","deployment_pad"]:
		var path="res://assets/environment/"+id+".png"
		if ResourceLoader.exists(path):environment_icons[id]=load(path)
	var glyphs=["<path d='M13 2 L4 15 H11 L8 25 L22 10 H14 Z'/>","<circle cx='13' cy='13' r='10' fill='none' stroke-width='3'/><path d='M13 6 V13 L20 15' fill='none' stroke-width='3'/>","<circle cx='13' cy='13' r='9' fill='none' stroke-width='3'/><path d='M13 1 V5 M13 21 V25 M1 13 H5 M21 13 H25' fill='none' stroke-width='2'/>","<path d='M3 8 L8 3 L17 3 L22 8 L17 13 H10 L6 17 L10 22 H18 L23 17' fill='none' stroke-width='3' stroke-linecap='round'/>","<path d='M13 1 V25 M3 6 L23 20 M23 6 L3 20 M8 3 L13 7 L18 3 M8 23 L13 19 L18 23' fill='none' stroke-width='2'/>","<path d='M13 1 L16 9 L25 5 L20 13 L25 20 L16 18 L13 26 L10 18 L2 22 L6 13 L1 5 L10 9 Z'/>","<circle cx='13' cy='13' r='10' fill='none' stroke-width='2.5'/><circle cx='13' cy='13' r='4'/><path d='M1 13 H6 M20 13 H25 M13 1 V6 M13 20 V25' fill='none' stroke-width='2'/>","<circle cx='5' cy='13' r='4'/><circle cx='21' cy='5' r='4'/><circle cx='21' cy='21' r='4'/><path d='M9 10 L17 6 M9 16 L17 20' fill='none' stroke-width='3'/>"]
	for i in range(Run.UPGRADES.size()):
		var id:String=Run.UPGRADES[i].id
		var path="res://assets/items/relics/"+id+".png"
		if ResourceLoader.exists(path):
			relic_icons.append(load(path))
		else:
			var svg="<svg xmlns='http://www.w3.org/2000/svg' width='52' height='52' viewBox='0 0 26 26'><g fill='#35646b' stroke='#35646b'>"+glyphs[i]+"</g></svg>"
			var im=Image.new()
			im.load_svg_from_string(svg)
			relic_icons.append(ImageTexture.create_from_image(im))

func character_scale(id:String)->float:
	var frames:Array=sprite_manifest.get("characters",{}).get(id,{}).get("idle",[])
	if frames.is_empty():return 1.0
	var h:float=0.0
	var w:float=0.0
	for frame in frames:
		h=maxf(h,float(frame.rect[3]))
		w=maxf(w,float(frame.rect[2]))
	var target_height=112.0 if id=="boss" else (53.0 if id=="crab" else (50.0 if id=="sail" else (67.0 if id=="urchin" else 84.0)))
	var target_width=105.0 if id=="boss" else (55.0 if id=="crab" else (68.0 if id=="sail" else (70.0 if id=="urchin" else 96.0)))
	return minf(target_height/maxf(1,h),target_width/maxf(1,w))

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
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	load_sprites()
	var layer = CanvasLayer.new()
	add_child(layer)
	var ui = Control.new()
	ui.name = "HUD"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	layer.add_child(ui)
	make_label(ui,"RIFTWORKS: TIDEWAY",Rect2(21,6,188,25),17)
	label_seed=make_label(ui,"",Rect2(21,32,188,15),10,MUTED)
	label_status=make_label(ui,"",Rect2(225,12,192,32),19,INK)
	label_rule=make_label(ui,"",Rect2(445,8,284,34),21,INK)
	label_phase=make_label(ui,"",Rect2(751,10,250,34),16,INK)
	# Two compact planning ribbons stay off the map's actionable cells.
	label_forecast=make_label(ui,"",Rect2(1031,265,231,72),12,MUTED)
	label_message=make_label(ui,"",Rect2(16,676,656,20),12,INK)
	explore_button=make_button(ui,"EXPLORE · 6",Rect2(1032,171,228,48),PRIMARY,19)
	explore_button.pressed.connect(_explore)
	loot_label=make_label(ui,"",Rect2(1034,224,224,40),13,INK)
	skip_reveal_button=make_button(ui,"SKIP",Rect2(1194,139,67,26),MUTED,12)
	skip_reveal_button.pressed.connect(func():restart_confirm="";sell_confirm="";_cancel_pointer();_skip_reveal();refresh())
	label_selection=make_label(ui,"",Rect2(1110,346,149,44),15,INK)
	label_tower_stats=make_label(ui,"",Rect2(1110,393,149,72),13,MUTED)
	merge_button=make_button(ui,"MERGE",Rect2(1032,472,109,44),ACC,16)
	merge_button.pressed.connect(_toggle_merge)
	sell_tower_button=make_button(ui,"SELL",Rect2(1150,472,110,44),WARN,16)
	sell_tower_button.pressed.connect(_sell_selected_tower)
	recall_button=make_button(ui,"RECALL",Rect2(1032,523,109,32),MUTED,12)
	recall_button.pressed.connect(_recall)
	cancel_button=make_button(ui,"CLEAR",Rect2(1150,523,110,32),MUTED,12)
	cancel_button.pressed.connect(_clear_selection)
	make_label(ui,"TIDAL RELICS",Rect2(1033,565,227,24),17,INK)
	for i in range(Run.UPGRADES.size()):
		var b=make_button(ui,"",Rect2(1032+(i%4)*58,591+int(i/4.0)*41,54,36),AMP,12)
		b.pressed.connect(_select_core.bind(str(Run.UPGRADES[i].id)))
		b.icon=relic_icons[i] if relic_icons.size()>i else null
		b.expand_icon=true
		b.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width",21)
		core_buttons.append(b)
	label_core=make_label(ui,"",Rect2(1033,671,226,72),11,MUTED)
	sell_core_button=make_button(ui,"SELL RELIC +4",Rect2(1032,748,228,39),WARN,14)
	sell_core_button.pressed.connect(_sell_selected_core)
	label_feedback=make_label(ui,"",Rect2(16,697,656,18),12,MUTED)
	label_reserve=make_label(ui,"",Rect2(680,677,119,20),12,INK)
	for i in range(9):
		var b=make_button(ui,"",Rect2(13+i*74,721,69,70),ACC,11)
		b.pressed.connect(_reserve_clicked.bind(i))
		b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",51)
		reserve_buttons.append(b)
	special_button=make_button(ui,"",Rect2(680,714,152,30),WARN,12)
	special_button.pressed.connect(func():_skip_reveal();sell_confirm="";restart_confirm="";_cancel_pointer();game.alter())
	pause_button=make_button(ui,"PAUSE",Rect2(838,714,96,30),ACC,12)
	pause_button.pressed.connect(_toggle_pause)
	speed_button=make_button(ui,"1x",Rect2(940,714,63,30),ACC,12)
	speed_button.pressed.connect(_toggle_speed)
	start_button=make_button(ui,"START WAVE",Rect2(680,749,323,44),PRIMARY,19)
	start_button.pressed.connect(_start)
	restart_button=make_button(ui,"RETRY",Rect2(806,680,92,28),MUTED,12)
	restart_button.pressed.connect(_restart.bind(false))
	new_seed_button=make_button(ui,"NEW RUN",Rect2(905,680,98,28),MUTED,12)
	new_seed_button.pressed.connect(_restart.bind(true))
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

func button_style(fill:Color, edge:Color, small:bool=false) -> StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=fill
	box.border_color=edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(6 if small else 9)
	box.content_margin_left=4
	box.content_margin_right=4
	box.content_margin_top=2
	box.content_margin_bottom=2
	box.shadow_color=Color(0.20,0.28,0.30,0.17)
	box.shadow_size=2
	box.shadow_offset=Vector2(0,2)
	return box

func configure_button(b:Button,color:Color,primary:bool=false)->void:
	var solid=primary or color==ACC
	var fill=color if solid else PANEL
	var edge=color if solid else FUNCTIONAL_BORDER
	var text=Color("fff8eb") if solid else INK
	b.add_theme_color_override("font_color",text)
	b.add_theme_color_override("font_hover_color",text)
	b.add_theme_color_override("font_pressed_color",text)
	b.add_theme_color_override("font_disabled_color",Color("526062"))
	b.add_theme_stylebox_override("normal",button_style(fill,edge))
	b.add_theme_stylebox_override("hover",button_style(fill.lightened(0.10),color))
	b.add_theme_stylebox_override("pressed",button_style(fill.darkened(0.07),color))
	b.add_theme_stylebox_override("disabled",button_style(Color("d9d8ca"),Color("b8b9ad")))
	b.add_theme_stylebox_override("focus",button_style(Color(0,0,0,0),ACC))

func make_button(parent:Node,value:String,area:Rect2,color:Color=ACC,sz:int=14)->Button:
	var b=Button.new()
	b.text=value
	b.position=area.position
	b.focus_mode=Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size",sz)
	configure_button(b,color,color==PRIMARY)
	parent.add_child(b)
	b.size=area.size
	return b

func _skip_reveal()->void:
	loot_age=LOOT_DURATION
	skip_reveal_button.visible=false
	queue_redraw()

func _explore()->void:
	restart_confirm=""
	_cancel_pointer()
	sell_confirm=""
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
	restart_confirm=""
	_cancel_pointer()
	sell_confirm=""
	_skip_reveal()
	selected_core=id
	selected_id=-1
	merge_mode=false
	notice=""
	refresh()

func _sell_selected_core()->void:
	restart_confirm=""
	_cancel_pointer()
	_skip_reveal()
	notice=""
	if game.phase!="build" or selected_core.is_empty() or game.level(selected_core)<=0:
		sell_confirm=""
		refresh()
		return
	var key="core:%s:%d"%[selected_core,game.level(selected_core)]
	if sell_confirm!=key:
		sell_confirm=key
		notice="Confirm selling one relic rank for 4 coins."
	else:
		sell_confirm=""
		if not game.sell_core(selected_core): notice="Select a held relic rank to sell."
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
	_cancel_pointer()
	if not sell_confirm.is_empty() or not restart_confirm.is_empty():
		sell_confirm=""
		restart_confirm=""
		notice="Cancelled. Progress unchanged."
		refresh()
		return
	sell_confirm=""
	_skip_reveal()
	selected_id=-1
	selected_core=""
	merge_mode=false
	notice=""
	refresh()

func _select_tower(id:int)->void:
	restart_confirm=""
	_cancel_pointer()
	sell_confirm=""
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
		selected_core=""
		notice=""
	refresh()

func can_merge(a:Dictionary,b:Dictionary)->bool:
	return not a.is_empty() and not b.is_empty() and a.id!=b.id and a.kind==b.kind and a.rank==b.rank and a.rank<3

func has_merge_partner(t:Dictionary)->bool:
	for other in game.towers+game.reserve:
		if can_merge(t,other):return true
	return false

func _toggle_merge()->void:
	restart_confirm=""
	_cancel_pointer()
	sell_confirm=""
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
	restart_confirm=""
	_cancel_pointer()
	sell_confirm=""
	_skip_reveal()
	notice=""
	if not game.recall(selected_id):notice="Select a deployed tower to recall."
	refresh()

func _sell_selected_tower()->void:
	restart_confirm=""
	_cancel_pointer()
	_skip_reveal()
	notice=""
	var t=get_tower(selected_id)
	if game.phase!="build" or t.is_empty() or merge_mode:
		sell_confirm=""
		refresh()
		return
	var key="tower:%d:%d"%[t.id,t.rank]
	if sell_confirm!=key:
		sell_confirm=key
		notice="Confirm selling %s for %d coins."%[SHORT_NAMES[t.kind],game.tower_sale_value(t.rank)]
		refresh()
		return
	sell_confirm=""
	if game.sell_tower(selected_id):
		selected_id=-1
		merge_mode=false
	else:
		notice=game.message if game.phase=="build" and not get_tower(selected_id).is_empty() else "Select a tower to sell during planning."
	refresh()

func _start()->void:
	restart_confirm=""
	_cancel_pointer()
	sell_confirm=""
	_skip_reveal()
	notice=""
	merge_mode=false
	paused=false
	if not game.start():notice="Deploy at least one tower before starting."
	refresh()

func _toggle_pause()->void:
	restart_confirm=""
	_cancel_pointer()
	sell_confirm=""
	if game.phase=="fight":
		paused=not paused
		accumulator=0.0
		refresh()

func _toggle_speed()->void:
	restart_confirm=""
	_cancel_pointer()
	sell_confirm=""
	speed=2.0 if speed==1.0 else 1.0
	refresh()

func run_has_progress()->bool:
	return game.stage>0 or game.wave>0 or game.tick_count>0 or game.gold!=24 or not game.towers.is_empty() or not game.reserve.is_empty() or not game.upgrades.is_empty()

func _restart(random_seed:bool)->void:
	if restart_cooldown>0.0:return
	sell_confirm=""
	_cancel_pointer()
	var key="new" if random_seed else "same"
	if game.phase not in ["won","lost"] and run_has_progress() and restart_confirm!=key:
		restart_confirm=key
		notice=("Start a NEW run?" if random_seed else "Retry this seed?")+" Confirm to discard current progress. Esc cancels."
		refresh()
		return
	restart_confirm=""
	restart_cooldown=0.35
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
	label_status.text="♥ %02d    　 %02d" % [maxi(game.hp,0),game.gold]
	label_phase.text="WAVE %d/2  ·  %s" % [game.wave+1,"CONFIRM" if not restart_confirm.is_empty() else ("PAUSED" if paused else PHASES.get(game.phase,game.phase))]
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
		label_forecast.text="NEXT  •  %s"%(" / ".join(parts))
		if f.get("extra",0)>0: label_forecast.text+="\nExtra %d×%.0f HP"%[f.extra,f.extra_hp]
		if game.stage==2 and game.wave==1:label_forecast.text+="\nBoss escape = defeat."

func refresh()->void:
	if game.phase!="fight":
		paused=false
		last_attacks.clear()
	if game.phase!="build":
		merge_mode=false
		sell_confirm=""
	var t=get_tower(selected_id)
	if t.is_empty():selected_id=-1;merge_mode=false
	var planning:bool=game.phase=="build"
	update_status()
	label_seed.text="P05 · Seed %d"%seed_value
	label_rule.text=Run.NAMES[game.stage].to_upper()
	label_rule.tooltip_text=["Switch the tidal crossing.","Open second inlet: +6 if leak-free.","Echo reefs amplify your crew."][game.stage]
	if game.stage==2 and game.wave==1:label_rule.tooltip_text="Boss escape = immediate defeat."
	var odds:Dictionary=game.reward_odds()
	var crew_pct:float=float(odds.get("tower",0.0))*100.0
	var core_pct:float=float(odds.get("core",0.0))*100.0
	explore_button.disabled=loot_age>=LOOT_DURATION and (not planning or game.gold<6 or crew_pct+core_pct<=0)
	explore_button.text="SKIP REVEAL · FREE" if loot_age<LOOT_DURATION else "EXPLORE · 6 ◉"
	explore_button.tooltip_text="Skip visual only; no extra cost." if loot_age<LOOT_DURATION else "%d%% CREW / %d%% RELIC. Spend 6 run-only coins; equal within category. Below 2 crew, always crew."%[roundi(crew_pct),roundi(core_pct)]
	if loot_age>=LOOT_DURATION and explore_button.disabled:
		explore_button.text="BETWEEN WAVES" if not planning else ("NEED 6 COINS" if game.gold<6 else "POOL EMPTY")

	skip_reveal_button.visible=loot_age<LOOT_DURATION
	loot_label.text=("%s R%d"%[loot_reveal.get("name","Reward"),int(loot_reveal.get("rank",1))]) if not loot_reveal.is_empty() else "One random result per chest."
	loot_label.text+="\n%d%% crew  ·  %d%% relic"%[roundi(crew_pct),roundi(core_pct)]
	if planning and game.towers.size()+game.reserve.size()<2 and loot_age>=LOOT_DURATION:
		loot_label.tooltip_text="First two crew guaranteed. Relic applies immediately."
	merge_button.text="CANCEL" if merge_mode else "MERGE"
	merge_button.disabled=not planning or (not merge_mode and not has_merge_partner(t))
	recall_button.disabled=not planning or not is_deployed(t)
	sell_tower_button.text=("%s +%d"%["CONFIRM" if sell_confirm=="tower:%d:%d"%[t.id,t.rank] else "SELL",game.tower_sale_value(t.rank)]) if not t.is_empty() else "SELL"
	sell_tower_button.disabled=not planning or t.is_empty() or merge_mode
	cancel_button.text="CANCEL" if not restart_confirm.is_empty() or not sell_confirm.is_empty() else "CLEAR"
	cancel_button.disabled=selected_id<0 and selected_core.is_empty() and sell_confirm.is_empty() and restart_confirm.is_empty()
	label_selection.text=("%s\nRANK %d"%[SHORT_NAMES[t.kind],t.rank] if not t.is_empty() else "SELECT A CREW MEMBER")
	special_button.visible=game.stage<2
	special_button.disabled=not planning
	if game.stage==0:
		special_button.text="ROUTE %s · %d"%["UPPER" if game.route_choice==0 else "LOWER",int(game.route_lengths()[game.route_choice])]
	elif game.stage==1:
		special_button.text="RIFT "+("OPEN (+6)" if game.opened else "CLOSED")
	start_button.disabled=not planning or game.towers.is_empty()
	start_button.tooltip_text="Deploy at least one crew member first." if planning and game.towers.is_empty() else "Begin the next wave."
	configure_button(explore_button,PRIMARY if start_button.disabled else MUTED, start_button.disabled)
	configure_button(start_button,PRIMARY if not start_button.disabled else MUTED, not start_button.disabled)
	pause_button.disabled=game.phase!="fight"
	pause_button.text="RESUME" if paused else "PAUSE"
	speed_button.text="SPEED %dx"%int(speed)
	label_message.text=game.message
	restart_button.text="CONFIRM" if restart_confirm=="same" else "RETRY"
	new_seed_button.text="CONFIRM" if restart_confirm=="new" else "NEW RUN"
	restart_button.disabled=restart_cooldown>0.0
	new_seed_button.disabled=restart_cooldown>0.0
	if not restart_confirm.is_empty():
		label_message.text=("New run" if restart_confirm=="new" else "Retry seed")+" will discard progress. Confirm or Esc to cancel."
	elif game.phase=="won" or game.phase=="lost":
		label_message.text=game.message+"  •  Leaks: %d"%game.run_leaks
	elif planning and game.message=="Build a defense, then start the wave.":
		label_message.text="Explore for a random reward, then deploy crew on a free tile."
	label_reserve.text="FIELD %d/5 · %d/9"%[game.towers.size(),game.towers.size()+game.reserve.size()]
	for i in range(9):
		var b=reserve_buttons[i]
		b.disabled=i>=game.reserve.size() or not planning
		if i>=game.reserve.size():
			b.text="+";b.icon=null;b.modulate=Color.WHITE
		else:
			var r:Dictionary=game.reserve[i]
			b.text="%s%s R%d"%[">" if r.id==selected_id else "",["Brass","Mist","Reef"][r.kind],r.rank]
			b.icon=crew_icons[r.kind] if crew_icons.size()>r.kind else null
			b.modulate=Color.WHITE
			configure_button(b,ACC if r.id==selected_id or (merge_mode and can_merge(t,r)) else MUTED)
	for i in range(Run.UPGRADES.size()):
		var u:Dictionary=Run.UPGRADES[i]
		var rank:int=game.level(u.id)
		var b:Button=core_buttons[i]
		b.text="%d/%d"%[rank,Run.MAX_RANK[u.id]]
		b.tooltip_text=u.description
		b.modulate=Color.WHITE
		configure_button(b,ACC if selected_core==u.id else (AMP if rank>0 else MUTED))
	label_core.text="Select a module to see its effect and sell one rank."
	for u in Run.UPGRADES:
		if u.id==selected_core:
			label_core.text="%s  R%d\n%s"%[u.name,game.level(u.id),u.description]
	sell_core_button.text="CONFIRM +4" if sell_confirm=="core:%s:%d"%[selected_core,game.level(selected_core)] else "SELL RELIC +4"
	sell_core_button.disabled=not planning or selected_core.is_empty() or game.level(selected_core)<=0
	update_hover()
	queue_redraw()

func _process(delta:float)->void:
	if restart_cooldown>0.0:
		restart_cooldown=maxf(0.0,restart_cooldown-delta)
		if restart_cooldown<=0.0:refresh()
	if loot_age<LOOT_DURATION:
		loot_age=minf(LOOT_DURATION,loot_age+delta)
		skip_reveal_button.visible=loot_age<LOOT_DURATION
		if loot_age>=LOOT_DURATION:refresh()
	if not paused:
		idle_clock=fmod(idle_clock+minf(delta,0.25),60.0)
		for i in range(death_fx.size()-1,-1,-1):
			death_fx[i].age+=delta
			if death_fx[i].age>=0.45:death_fx.remove_at(i)
	if game.phase=="fight" and not paused and restart_confirm.is_empty():
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
	elif game.phase!="fight" or paused:
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
	var viewed=t
	var st:Array=[]
	if not viewed.is_empty():
		# Stats refer to the selected crew only; vacant legal hover gives explicit prospective deployment stats.
		var target_cell:Vector2i=hover if game.phase=="build" and inside(hover) and candidate_error(hover,t).is_empty() else t.cell
		st=game.preview_stats(target_cell,t.kind,t.rank,t.id)
	if viewed.is_empty():
		label_tower_stats.text="Recruit from chest.\nSelect to inspect."
	else:
		label_tower_stats.text="ATK  %.1f\nCD  %.2fs\nRANGE  %.1f"%[st[0],st[2],st[1]]
		label_tower_stats.tooltip_text="AMP + RELAY" if st[4] and st[5] else ("AMP" if st[4] else ("RELAY" if st[5] else ROLE[viewed.kind]))
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

func _cancel_pointer()->void:
	pointer_cell=Vector2i(-1,-1)
	pointer_button=0

func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_pointer()
		if not restart_confirm.is_empty() or not sell_confirm.is_empty():
			restart_confirm=""
			sell_confirm=""
			if is_node_ready():refresh()

func _input(event:InputEvent)->void:
	# Observe pointer movement before GUI consumption: crossing into another cell or UI
	# cancels the outstanding board gesture. Selection/deploy is still _unhandled_input only.
	if pointer_button==0:return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and not event.pressed):
		var cell=Vector2i(floor((event.position.x-ORIGIN.x)/TILE),floor((event.position.y-ORIGIN.y)/TILE))
		if cell!=pointer_cell:_cancel_pointer()

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:_toggle_pause()
			KEY_ESCAPE:_clear_selection()
	if not event is InputEventMouseButton:return
	if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:return
	var cell=Vector2i(floor((event.position.x-ORIGIN.x)/TILE),floor((event.position.y-ORIGIN.y)/TILE))
	if event.pressed:
		_cancel_pointer()
		if inside(cell):
			pointer_cell=cell
			pointer_button=int(event.button_index)
			hover=cell
			queue_redraw()
		return
	var same_cell=inside(cell) and pointer_cell==cell and pointer_button==int(event.button_index)
	_cancel_pointer()
	if not same_cell:return
	sell_confirm=""
	restart_confirm=""
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

func route_stroke(route:Array[Vector2])->Dictionary:
	# Stable, cosmetic edge variation. The original logical cell centers are unchanged.
	var key=str(route)
	if route_visual_cache.has(key):return route_visual_cache[key]
	var center=PackedVector2Array()
	for i in range(route.size()-1):
		var a=coord(route[i]);var b=coord(route[i+1])
		var direction=(b-a).normalized()
		var count=maxi(1,int(a.distance_to(b)/18.0))
		center.append(a)
		for j in range(1,count):
			var f=float(j)/count
			var drift=(sin(j*1.9+i*2.7)*1.9+sin(j*0.63+i)*1.3)*sin(f*PI)
			center.append(a.lerp(b,f)+direction.orthogonal()*drift)
	center.append(coord(route[-1]))
	var outer=Geometry2D.offset_polyline(center,23.0,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
	var middle=Geometry2D.offset_polyline(center,20.0,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
	var inner=Geometry2D.offset_polyline(center,15.0,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
	var result={"outer":outer,"middle":middle,"inner":inner}
	route_visual_cache[key]=result
	return result

func draw_route(route:Array[Vector2],c:Color,active:bool=true)->void:
	if not active:
		for i in range(route.size()-1):
			draw_dashed_line(coord(route[i]),coord(route[i+1]),Color(0.30,0.43,0.46,0.40),2,10,true)
		return
	var stroke=route_stroke(route)
	# Soft sand washes blend into the painted landscape without an engineering outline.
	for polygon in stroke.outer:draw_colored_polygon(polygon,Color(0.71,0.57,0.39,0.30))
	for polygon in stroke.middle:draw_colored_polygon(polygon,Color(0.91,0.78,0.55,0.71) if c==WARN else Color(0.92,0.79,0.59,0.68))
	for polygon in stroke.inner:draw_colored_polygon(polygon,Color(1.0,0.93,0.78,0.32))
	for i in range(route.size()-1):
		var a=coord(route[i]);var b=coord(route[i+1]);var d=(b-a).normalized()
		var length=a.distance_to(b)
		# Tiny sea-sand flecks and subdued arrowheads create direction without hiding painted art.
		for j in range(1,int(length/17.0)):
			var p=a+d*j*17.0+d.orthogonal()*(sin(j*2.16+i)*15.0)
			draw_circle(p,1.3 if j%3==0 else 0.7,Color(0.50,0.40,0.28,0.21))
		for j in range(1,maxi(2,int(length/82.0))):
			var mid=a+d*(length*float(j)/float(maxi(2,int(length/82.0))))
			draw_line(mid-d*5+d.orthogonal()*4,mid+d*3,Color(0.36,0.28,0.17,0.85),2.0,true)
			draw_line(mid+d*3,mid-d*5-d.orthogonal()*4,Color(0.36,0.28,0.17,0.85),2.0,true)

func draw_bridge(from_cell:Vector2,to_cell:Vector2)->void:
	var a=coord(from_cell);var b=coord(to_cell)
	var d=(b-a).normalized();var n=d.orthogonal()
	var length=a.distance_to(b)
	# Warm weathered boards, shallow shadow and small posts follow the actual route.
	draw_line(a+Vector2(1,4),b+Vector2(1,4),Color(0.26,0.22,0.15,0.22),35,true)
	var plank_count=maxi(1,ceili(length/11.0))
	var step=length/plank_count
	for i in range(plank_count):
		var p=a+d*(i*step+step/2)
		var half_length=maxf(1,step/2-0.45)
		var span=17.5+sin(i*1.9)*1.7
		var corners=PackedVector2Array([p-d*half_length-n*span,p+d*half_length-n*(span-0.6),p+d*half_length+n*span,p-d*half_length+n*(span+0.6)])
		draw_colored_polygon(corners,Color("c6a67b").lightened((sin(i*2.31)+1.0)*0.07))
		draw_line(corners[0]+d*1.2,corners[3]+d*1.2,Color(0.96,0.87,0.70,0.45),1,true)
	for side in [-1,1]:
		var offset=n*side*18.0
		draw_line(a+offset,b+offset,Color(0.45,0.32,0.21,0.56),1.8,true)
		for j in range(0,maxi(1,ceili(length/66.0))+1):
			var p=a+d*minf(j*66,length)+offset
			draw_circle(p+Vector2(1,2),3.6,Color(0.31,0.25,0.16,0.29))
			draw_circle(p,2.8,Color("9a7650"))
			draw_circle(p+Vector2(-0.6,-0.6),1.2,Color("ead1a4"))

func draw_entry(cell:Vector2,name_text:String,active:bool)->void:
	var p=coord(cell)
	var tex:Texture2D=environment_icons.get("portal")
	if tex!=null:
		draw_texture_rect(tex,Rect2(p+Vector2(-52,-91),Vector2(104,95)),false,Color.WHITE if active else Color(1,1,1,0.55))
	else:
		draw_circle(p,23,Color("315f6d"))
		draw_arc(p,20,0,TAU,32,Color("8cdddf"),3,true)
		draw_arc(p,15,0.1,TAU-0.1,32,Color("c9e9e1"),1.5,true)
	draw_string(font,p+Vector2(-40,34),name_text,HORIZONTAL_ALIGNMENT_CENTER,80,12,INK)

func draw_socket(p:Vector2,active:bool=false,occupied:bool=false)->void:
	var tex:Texture2D=environment_icons.get("deployment_pad")
	if tex!=null:
		draw_texture_rect(tex,Rect2(p+Vector2(-35,-10),Vector2(70,51)),false,Color.WHITE if occupied or active else Color(1,1,1,0.70))
		if active:draw_arc(p+Vector2(0,13),30,0,TAU,36,ACC,2,true)
		elif not occupied:draw_arc(p+Vector2(0,13),28,0,TAU,36,FUNCTIONAL_BORDER,1.4,true)
		return
	var base_color=Color("d1c5ae") if occupied else Color(0.96,0.90,0.77,0.45)
	draw_set_transform(p+Vector2(0,13),0,Vector2(1,0.57))
	draw_circle(Vector2(1,5),29,Color(0.24,0.31,0.29,0.20 if occupied else 0.10))
	draw_circle(Vector2.ZERO,28,base_color)
	draw_arc(Vector2.ZERO,27,0,TAU,36,FUNCTIONAL_BORDER,2,true)
	if active:draw_arc(Vector2.ZERO,30,0,TAU,36,ACC,3,true)
	draw_set_transform(Vector2.ZERO)

func draw_range(center:Vector2,radius:float,c:Color)->void:
	var alpha=Color(c,0.10)
	# Shaded cells show usable coverage without drawing beyond map boundaries.
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			var p=coord(Vector2(x,y))
			if center.distance_to(p)<=radius:
				draw_circle(p+Vector2(0,13),3.5,alpha)
	var previous=center+Vector2(radius,0)
	for i in range(1,97):
		var next=center+Vector2.from_angle(TAU*float(i)/96.0)*radius
		if BOARD.has_point(previous) and BOARD.has_point(next):
			draw_line(previous,next,ACC,1.8,true)
		previous=next

func draw_tower(p:Vector2,kind:int,ghost:bool=false,id:int=-1)->void:
	# Feet remain within the top row instead of obscuring the header.
	var anchor=p+Vector2(0,28 if p.y<ORIGIN.y+TILE else 13)
	var attack_age=(game.tick_count-int(last_attacks.get(id,-999)))*Run.TICK
	var attacking=game.phase=="fight" and attack_age>=0 and attack_age<0.33
	draw_ellipse_shadow(anchor,19)
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
	draw_circle(Vector2.ZERO,radius,Color(0.20,0.28,0.28,0.30))
	draw_set_transform(Vector2.ZERO)

func draw_loot_presentation()->void:
	var chest_open=loot_age>=0.18 and loot_age<LOOT_DURATION and not loot_reveal.is_empty()
	var shake=sin(loot_age*80)*3.0 if loot_age<0.18 else 0.0
	var p=CHEST+Vector2(shake,0)
	# Brass framed treasure chest, grounded at dock. Reward is credited before this cosmetic motion.
	draw_ellipse_shadow(p+Vector2(0,65),67)
	var tex:Texture2D=chest_textures[int(chest_open)] if chest_textures.size()==2 else null
	if tex!=null:
		draw_texture_rect(tex,Rect2(p-Vector2(80,80),Vector2(160,160)),false)
	else:
		draw_chest_fallback(p,chest_open)
	if loot_reveal.is_empty() or loot_age<0.18 or loot_age>=LOOT_DURATION:return
	var flash=maxf(0,1-(loot_age-0.18)/0.3)
	draw_circle(p-Vector2(0,18),69*flash,Color(0.78,0.93,0.8,0.28*flash))
	var progress=clampf((loot_age-0.3)/0.55,0,1)
	var target=Vector2(640,750)
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
func draw_paper(rect:Rect2,rounding:float=11.0)->void:
	var key=int(rounding)
	if not paper_styles.has(key):
		var created=StyleBoxFlat.new()
		created.bg_color=PANEL
		created.border_color=Color("b2aaa0")
		created.set_border_width_all(2)
		created.set_corner_radius_all(key)
		created.shadow_color=Color(0.17,0.28,0.29,0.18)
		created.shadow_size=3
		created.shadow_offset=Vector2(0,2)
		paper_styles[key]=created
	var style:StyleBoxFlat=paper_styles[key]
	draw_style_box(style,rect)
	draw_rect(rect.grow(-5),Color(1,0.98,0.91,0.42),false,1)
	# restrained chart paper corners
	for corner in [rect.position+Vector2(8,8),rect.end-Vector2(8,8)]:
		draw_circle(corner,2,Color("a59d88"))

func draw_interface_paper()->void:
	draw_paper(Rect2(6,3,419,45),10)
	draw_paper(Rect2(435,3,304,45),10)
	draw_paper(Rect2(745,3,268,45),10)
	# Gold token is a small owned UI illustration; amount remains actual model text.
	draw_set_transform(Vector2(303,28),0,Vector2(1,0.76))
	draw_circle(Vector2(1,1),8.3,Color("865517"))
	draw_circle(Vector2.ZERO,7.8,Color("d8a343"))
	draw_arc(Vector2.ZERO,7.6,0,TAU,32,Color("865517"),1.5,true)
	draw_arc(Vector2.ZERO,5.8,0,TAU,32,Color("f5d48b"),1.2,true)
	draw_line(Vector2(-2,-2),Vector2(2,2),Color("9e7330"),1.2,true)
	draw_set_transform(Vector2.ZERO)
	draw_paper(Rect2(6,674,1008,123),12)
	draw_paper(Rect2(1020,6,254,788),12)
	for y in [337.0,559.0]:
		draw_line(Vector2(1034,y),Vector2(1260,y),BORDER,1,true)
		var center=Vector2(1147,y)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-4,0),center+Vector2(0,-4),center+Vector2(4,0),center+Vector2(0,4)]),BORDER)
	var t=get_tower(selected_id)
	var area=Rect2(1032,346,72,117)
	draw_paper(area,7)
	if not t.is_empty() and crew_icons.size()>t.kind and crew_icons[t.kind]!=null:
		var tex=crew_icons[t.kind]
		var fit_scale=minf(66.0/tex.get_width(),85.0/tex.get_height())
		var fit_size=tex.get_size()*fit_scale
		draw_texture_rect(tex,Rect2(area.get_center()-fit_size/2.0,fit_size),false)
	else:
		draw_string(font,area.get_center()+Vector2(-23,4),"+",HORIZONTAL_ALIGNMENT_CENTER,46,24,MUTED)

func _draw()->void:
	if font==null:return
	draw_rect(Rect2(0,0,1280,800),BG)
	var scene:Texture2D=scene_backdrops[game.stage] if scene_backdrops.size()>game.stage else null
	if scene==null and not scene_backdrops.is_empty():scene=scene_backdrops[0]
	if scene!=null:draw_texture_rect(scene,MAP_RECT,false)
	else:draw_rect(MAP_RECT,Color("92b8b5"))
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			var cell=Vector2i(x,y)
			var p=coord(Vector2(cell))
			if game.phase=="build" and not game.reserved(cell):
				var selected=get_tower(selected_id)
				var active=not selected.is_empty() and candidate_error(cell,selected).is_empty()
				if tower_at(cell).is_empty():
					if active and cell==hover:draw_socket(p,true)
					elif active:
						draw_circle(p+Vector2(0,13),5.3,Color(0.99,0.94,0.80,0.72))
						draw_arc(p+Vector2(0,13),4.8,0,TAU,24,Color(0.09,0.43,0.45,0.70),1.5,true)
					else:draw_circle(p+Vector2(0,13),2.8,Color(0.38,0.49,0.49,0.68))
			if scene==null:
				draw_rect(Rect2(p-Vector2.ONE*TILE/2,Vector2.ONE*TILE),Color(1,1,1,0.12),false,1)
	if game.stage==0:
		var inactive=game.maze_path(1-game.route_choice)
		draw_route(inactive,ROUTE,false)
	if game.stage==1:
		draw_route(game.path(false),WARN,game.opened)
	draw_route(game.path(),ROUTE,true)
	if game.stage==0:
		if game.route_choice==0:draw_bridge(Vector2(4.3,1),Vector2(6.7,1))
		else:draw_bridge(Vector2(2.3,5),Vector2(4,5))
		draw_bridge(Vector2(8,4),Vector2(10.7,4))
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
	var lighthouse:Texture2D=environment_icons.get("lighthouse")
	if lighthouse!=null:draw_texture_rect(lighthouse,Rect2(core+Vector2(-30,-112),Vector2(59,114)),false)
	else:
		draw_circle(core,25,Color("f5ebd6"))
		draw_arc(core,24,0,TAU,40,ACC,3,true)
		draw_colored_polygon(PackedVector2Array([core+Vector2(0,-18),core+Vector2(15,-7),core+Vector2(11,17),core+Vector2(-11,17),core+Vector2(-15,-7)]),ACC)
	draw_string(font,core+Vector2(-30,39),"STATION",HORIZONTAL_ALIGNMENT_CENTER,60,12,INK)
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
		draw_socket(p,t.id==selected_id or (merge_mode and can_merge(get_tower(selected_id),t)),true)
		draw_tower(p,t.kind,false,t.id)
		if t.id==selected_id or (merge_mode and can_merge(get_tower(selected_id),t)):
			draw_arc(p+Vector2(0,13),32,0,TAU,40,ACC,2,true)
		draw_circle(p+Vector2(21,26),10,PANEL_DARK)
		draw_string(font,p+Vector2(9,30),str(t.rank),HORIZONTAL_ALIGNMENT_CENTER,24,12,INK)
	for e in game.enemies:
		var dir:Vector2=e.get("direction",Vector2.RIGHT)
		var p=coord(e.pos)+dir.orthogonal()*float((int(e.id)%3)-1)*5.0
		var r=19.0 if e.boss else 9.0
		var c=Color("f2767c") if e.slow<=0 else Color("9bcdf7")
		var sprite_id:String=ENEMY_SPRITES.get(e.get("role","normal"),"crab")
		var anchor=p+Vector2(0,13)
		draw_ellipse_shadow(anchor,r+3)
		var hit_age=(game.tick_count-int(e.get("hit_tick",-999)))*Run.TICK
		var hurt=hit_age>=0 and hit_age<0.16
		if not draw_character(sprite_id,"hurt" if hurt else "run",anchor,character_scale(sprite_id),hit_age if hurt else game.tick_count*Run.TICK,dir.x<0):
			draw_circle(p,r,c)
		if e.slow>0:draw_arc(anchor,12,0,TAU,24,c,1.5,true)
		if e.boss: draw_arc(p,r+4,0,TAU,36,WARN,3,true)
		# Health is drawn after all enemy sprites so a trailing crab cannot hide a bar.
	for e in game.enemies:
		var dir:Vector2=e.get("direction",Vector2.RIGHT)
		var p=coord(e.pos)+dir.orthogonal()*float((int(e.id)%3)-1)*5.0
		var size=Vector2(38,5) if e.boss else Vector2(28,4)
		var pos=p+Vector2(-size.x/2,27)
		draw_rect(Rect2(pos-Vector2.ONE,size+Vector2.ONE*2),Color("213d48"))
		draw_rect(Rect2(pos,size),Color("768287"))
		draw_rect(Rect2(pos,Vector2(size.x*clampf(e.hp/e.maxhp,0,1),size.y)),Color("d15e43"))
	for d in death_fx:
		var p=coord(d.pos)+d.direction.orthogonal()*float((int(d.id)%3)-1)*5.0+Vector2(0,13)
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
				draw_string(font,coord(s.to)+Vector2(-31,-12),synergy.to_upper(),HORIZONTAL_ALIGNMENT_CENTER,62,10,INK)
	if game.phase=="build" and inside(hover) and not merge_mode and tower_at(hover).is_empty():
		var t=get_tower(selected_id)
		if not t.is_empty():
			var p=coord(Vector2(hover))
			var legal=candidate_error(hover,t).is_empty()
			draw_rect(Rect2(p-Vector2.ONE*(TILE/2-2),Vector2.ONE*(TILE-4)),ACC if legal else WARN,false,2)
			if legal:draw_tower(p,t.kind,true)
	if pointer_button!=0 and inside(pointer_cell):
		draw_arc(coord(Vector2(pointer_cell))+Vector2(0,13),32,0,TAU,40,Color(ACC,0.8),3,true)
	draw_interface_paper()
	draw_loot_presentation()
	if paused:
		draw_rect(BOARD,Color(0.05,0.08,0.14,0.42))
		draw_rect(Rect2(BOARD.get_center()-Vector2(112,26),Vector2(224,52)),PANEL)
		draw_string(font,BOARD.get_center()+Vector2(-112,9),"PAUSED",HORIZONTAL_ALIGNMENT_CENTER,224,24,INK)
