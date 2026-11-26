extends Node2D

const Run = preload("res://src/Run.gd")
const ORIGIN = Vector2(397, 130)
const TILE = 64.0
const BOARD = Rect2(ORIGIN, Vector2(12,8)*TILE)
const BG = Color("0c1420")
const PANEL = Color("142331")
const PANEL_DARK = Color("101d2a")
const BORDER = Color("314959")
const ACC = Color("6dd5ba")
const INK = Color("e5eef1")
const MUTED = Color("a6bdc9")
const ROUTE = Color("d5bc8a")
const WARN = Color("f1a36e")
const ERROR = Color("ff858c")
const AMP = Color("c6aafc")
const COLORS = [Color("80e4c0"),Color("75baf7"),Color("ffb16e")]
const ROLE = ["Focused damage", "Slow and control", "Area damage"]
const PHASES = {"build":"PLAN", "fight":"DEFEND", "reward":"UPGRADE", "won":"VICTORY", "lost":"DEFEAT"}

var game = Run.new()
var accumulator = 0.0
var selected = 0
var speed = 1.0
var paused = false
var seed_value = 437
var hover = Vector2i(-1,-1)
var notice = ""
var label_title:Label
var label_status:Label
var label_rule:Label
var label_build:Label
var label_ups:Label
var label_forecast:Label
var label_phase:Label
var label_seed:Label
var label_tower_stats:Label
var label_feedback:Label
var start_button:Button
var special_button:Button
var pause_button:Button
var speed_button:Button
var restart_button:Button
var new_seed_button:Button
var reward_box:Control
var tower_buttons:Array[Button] = []
var font:Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	var layer = CanvasLayer.new()
	add_child(layer)
	var ui = Control.new()
	ui.name = "HUD"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	label_title = make_label(ui, "RIFTWORKS", Rect2(43,40,258,38), 27)
	make_label(ui, "EXPEDITION LAB  /  PROTOTYPE", Rect2(45,87,260,20), 12, ACC)
	label_seed = make_label(ui, "", Rect2(45,110,260,20), 13, MUTED)
	label_status = make_label(ui, "", Rect2(45,142,260,54), 19)
	label_phase = make_label(ui, "", Rect2(45,201,260,21), 13, ACC)
	label_rule = make_label(ui, "", Rect2(45,237,260,82), 15)
	label_forecast = make_label(ui, "", Rect2(45,321,260,38), 13, MUTED)
	label_build = make_label(ui, "BUILD  /  1 · 2 · 3   |   Right-click refund", Rect2(45,364,260,20), 12, ACC)
	for i in range(3):
		var b = make_button(ui, "", Rect2(43,390+i*43,264,39), COLORS[i], 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_select.bind(i))
		tower_buttons.append(b)
	label_tower_stats = make_label(ui, "", Rect2(45,522,260,42), 13, MUTED)
	special_button = make_button(ui, "", Rect2(43,566,264,39), WARN, 14)
	special_button.pressed.connect(game.alter)
	start_button = make_button(ui, "START WAVE", Rect2(43,610,264,43), ACC, 16)
	start_button.pressed.connect(_start)
	pause_button = make_button(ui, "PAUSE", Rect2(43,660,128,30), ACC, 12)
	pause_button.pressed.connect(_toggle_pause)
	speed_button = make_button(ui, "SPEED 1x", Rect2(177,660,130,30), ACC, 12)
	speed_button.pressed.connect(_toggle_speed)
	restart_button = make_button(ui, "RETRY SEED", Rect2(43,696,128,30), MUTED, 12)
	restart_button.pressed.connect(_restart.bind(false))
	new_seed_button = make_button(ui, "NEW SEED", Rect2(177,696,130,30), MUTED, 12)
	new_seed_button.pressed.connect(_restart.bind(true))
	make_label(ui, "Space: pause   •   Left click: build", Rect2(45,736,260,18), 12, MUTED)
	label_ups = make_label(ui, "", Rect2(339,90,902,35), 13, AMP)
	label_feedback = make_label(ui, "", Rect2(397,649,768,24), 14, MUTED)
	label_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_box = Control.new()
	reward_box.name = "RewardBox"
	reward_box.position = Vector2(352,682)
	reward_box.size = Vector2(875,91)
	reward_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(reward_box)
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

func _select(kind:int) -> void:
	selected = kind
	notice = ""
	refresh()

func _start()->void:
	notice = ""
	paused = false
	if not game.start():
		notice = "Place at least one tower before starting."
	refresh()

func _toggle_pause()->void:
	if game.phase == "fight":
		paused = not paused
		accumulator = 0.0
		refresh()

func _toggle_speed()->void:
	speed = 2.0 if speed==1.0 else 1.0
	refresh()

func _restart(random_seed:bool)->void:
	if random_seed:
		seed_value = int(Time.get_ticks_msec()) + 437
	paused = false
	accumulator = 0.0
	notice = ""
	hover = Vector2i(-1,-1)
	game.reset(seed_value)

func update_status()->void:
	label_status.text = "CORE %02d     CREDITS %02d\nSector %d / 3    Wave %d / 2" % [maxi(game.hp,0),game.gold,game.stage+1,game.wave+1]
	label_phase.text = "%s   /   TOWERS %d / %d" % [PHASES.get(game.phase,game.phase),game.towers.size(),Run.MAX_TOWERS]
	if paused:
		label_phase.text = "PAUSED   /   TOWERS %d / %d" % [game.towers.size(),Run.MAX_TOWERS]
	var forecast_data:Dictionary = game.forecast()
	if game.phase=="fight":
		label_forecast.text = "Approaching: %d   •   Field: %d\nDefeated: %d   •   Leaks: %d" % [game.pending,game.enemies.size(),game.kills,game.wave_leaks]
	else:
		label_forecast.text = "Next: %d main%s%s\nEnemy HP %.0f%s" % [forecast_data.get("main",0),(" + %d extra" % forecast_data.get("extra",0)) if int(forecast_data.get("extra",0))>0 else "", " • BOSS" if forecast_data.get("boss",false) else "",forecast_data.get("hp",0),(" / Boss %.0f" % forecast_data.get("boss_hp",0)) if forecast_data.get("boss",false) else ""]

func refresh()->void:
	if game.phase!="fight":
		paused = false
	update_status()
	label_seed.text = "Seed %d  /  deterministic run" % seed_value
	label_rule.text = Run.NAMES[game.stage].to_upper()+"\n"+["Long route: coverage.\nShort route: concentrated defense.","Open second rift: more enemies\nfor an extra upgrade pick.","Purple amplifiers boost nearby\ntowers. Relay stacks with terrain."][game.stage]
	for i in range(3):
		tower_buttons[i].text = "%s %d  %-6s   %d    ·  %s" % [">" if selected==i else " ",i+1,Run.TYPES[i],Run.COST[i],ROLE[i]]
		tower_buttons[i].disabled = game.phase!="build" or game.gold<Run.COST[i] or game.towers.size()>=Run.MAX_TOWERS
		tower_buttons[i].modulate = Color.WHITE if selected==i else Color("c4d0d7")
	special_button.visible = game.stage<2
	special_button.disabled = game.phase!="build"
	if game.stage == 0:
		var lengths:Array = game.route_lengths()
		special_button.text = "SWITCH  /  %s  (%s cells)" % ["UPPER" if game.route_choice==0 else "LOWER",str(lengths[game.route_choice])]
	elif game.stage == 1:
		special_button.text = "EXTRA RIFT: %s" % ("OPEN  (+reward)" if game.opened else "CLOSED")
	start_button.disabled = game.phase!="build" or game.towers.is_empty()
	pause_button.disabled = game.phase!="fight"
	pause_button.text = "RESUME" if paused else "PAUSE"
	speed_button.text = "SPEED %dx" % int(speed)
	var names:Array[String] = []
	for u in Run.UPGRADES:
		if game.level(u.id)>0:
			names.append("%s ×%d" % [u.name,game.level(u.id)])
	label_ups.text = "RUN UPGRADES  /  "+("None yet · earn one after each wave" if names.is_empty() else "  ·  ".join(names))
	for old in reward_box.get_children():
		reward_box.remove_child(old)
		old.queue_free()
	if game.phase=="reward":
		make_label(reward_box, game.message.to_upper(), Rect2(0,0,875,22), 15, ACC)
		var count:int = game.choices.size()
		var card_width:float = (875-8*(count-1))/maxi(count,1)
		for i in range(count):
			var u:Dictionary = game.choices[i]
			var x:float = i * (card_width+8)
			var b = make_button(reward_box, u.name, Rect2(x,24,card_width,31), AMP, 14)
			b.tooltip_text = u.description
			b.pressed.connect(_reward.bind(i))
			make_label(reward_box,u.description,Rect2(x+4,58,card_width-8,35),12,MUTED)
	elif game.phase=="won" or game.phase=="lost":
		make_label(reward_box, game.message.to_upper(), Rect2(0,0,875,32), 23, ACC if game.phase=="won" else ERROR)
		make_label(reward_box, "Run leaks: %d  •  Earned upgrade picks: %d  •  Retry this seed or choose a fresh expedition." % [game.run_leaks,game.upgrades.values().reduce(func(a,b):return a+b,0)],Rect2(0,39,875,42),15,MUTED)
	else:
		make_label(reward_box,"MISSION  /  "+game.message,Rect2(0,3,875,26),17,INK)
		var tip = ["Choose a route, then position towers for sustained coverage. The reserved route stays clear.","Opening the second rift adds enemies but earns an extra upgrade pick.","Place towers near purple amplifier nodes. Relay upgrades stack with amplifier power."][game.stage]
		make_label(reward_box,tip,Rect2(0,39,875,44),15,MUTED)
	update_hover()
	queue_redraw()

func _reward(index:int)->void:
	notice=""
	game.choose(index)

func _process(delta:float)->void:
	if game.phase=="fight" and not paused:
		accumulator += minf(delta,0.25)*speed
		while accumulator>=Run.TICK and game.phase=="fight":
			game.step()
			accumulator-=Run.TICK
		update_status()
	else:
		accumulator=0.0
	# Viewport transforms global pointer coordinates even when a HUD control has consumed motion.
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
		if t.cell==cell:
			return t
	return {}

func coord(p:Vector2)->Vector2:
	return ORIGIN+(p+Vector2(0.5,0.5))*TILE

func update_hover()->void:
	var cell = hover if inside(hover) else Vector2i(0,0)
	var t = tower_at(cell) if inside(hover) else {}
	var kind:int = t.kind if not t.is_empty() else selected
	var st:Array = game.stats(t) if not t.is_empty() else game.preview_stats(cell,kind)
	label_tower_stats.text = "%s  %.1f dmg / %.2fs  •  %.1f range\n%s" % [Run.TYPES[kind],st[0],st[2],st[1],"AMP + RELAY" if st[4] and st[5] else ("Amplified" if st[4] else ("Linked to relay" if st[5] else ROLE[kind]))]
	label_feedback.add_theme_color_override("font_color",MUTED)
	if not notice.is_empty():
		label_feedback.text=notice
		label_feedback.add_theme_color_override("font_color",WARN)
	elif not inside(hover):
		label_feedback.text = "SOLID = active lane    ·    DASHED = reserved lane    ·    Violet = amplifier"
	elif not t.is_empty():
		label_feedback.text = "%s at %s  •  right-click to refund %d" % [Run.TYPES[t.kind],cell_name(hover),Run.COST[t.kind]]
	elif game.phase=="build":
		var reason:String = game.placement_error(hover,selected)
		if reason.is_empty():
			label_feedback.text = "Place %s at %s  •  Cost %d  •  Range %.1f" % [Run.TYPES[selected],cell_name(hover),Run.COST[selected],st[1]]
			label_feedback.add_theme_color_override("font_color",ACC)
		else:
			label_feedback.text = "%s: %s" % [cell_name(hover),reason]
			label_feedback.add_theme_color_override("font_color",WARN)
	else:
		label_feedback.text = "Battle active  •  build and refund are available between waves"

func cell_name(c:Vector2i)->String:
	return "%s%d" % [char(65+c.x),c.y+1]

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _select(0)
			KEY_2: _select(1)
			KEY_3: _select(2)
			KEY_SPACE: _toggle_pause()
	if event is InputEventMouseButton and event.pressed:
		var cell=Vector2i(floor((event.position.x-ORIGIN.x)/TILE),floor((event.position.y-ORIGIN.y)/TILE))
		if not inside(cell):
			return
		hover=cell
		notice=""
		if event.button_index==MOUSE_BUTTON_LEFT:
			if not game.place(cell,selected):
				notice=game.placement_error(cell,selected)
				if notice.is_empty(): notice="Placement unavailable."
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			if not game.sell(cell):
				notice="Refund only existing towers between waves."
		update_hover()

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
				draw_rect(Rect2(p-Vector2.ONE*30,Vector2.ONE*60),alpha)
	var previous=center+Vector2(radius,0)
	for i in range(1,97):
		var next=center+Vector2.from_angle(TAU*float(i)/96.0)*radius
		if BOARD.has_point(previous) and BOARD.has_point(next):
			draw_line(previous,next,Color(c,0.78),1.5,true)
		previous=next

func draw_tower(p:Vector2,kind:int,ghost:bool=false)->void:
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

func _draw()->void:
	if font==null:return
	draw_rect(Rect2(0,0,1280,800),BG)
	draw_rect(Rect2(24,24,300,752),PANEL)
	draw_rect(Rect2(24,24,300,752),BORDER,false,1.0)
	draw_rect(Rect2(24,24,4,752),ACC)
	for y in [133.0,229.0,357.0,559.0,731.0]:
		draw_line(Vector2(43,y),Vector2(307,y),BORDER,1.0)
	draw_rect(Rect2(339,24,901,61),PANEL_DARK)
	draw_string(font,Vector2(352,50),"EXPEDITION   /   "+Run.NAMES[game.stage].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,25,INK)
	draw_string(font,Vector2(353,72),"ORTHOGRAPHIC TACTICAL MAP  •  PLAN  >  DEFEND  >  UPGRADE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ACC)
	draw_rect(Rect2(339,677,901,103),PANEL_DARK)
	draw_rect(Rect2(339,677,901,103),BORDER,false,1.0)
	draw_rect(BOARD.grow(3),BORDER)
	for y in range(Run.ROWS):
		for x in range(Run.COLS):
			var p=ORIGIN+Vector2(x,y)*TILE
			var c=Color("21333f") if (x+y)%2==0 else Color("1d303b")
			draw_rect(Rect2(p+Vector2(1,1),Vector2(TILE-2,TILE-2)),c)
			if game.reserved(Vector2i(x,y)):
				draw_rect(Rect2(p+Vector2(2,2),Vector2(TILE-4,TILE-4)),Color("283b45"))
			if x==0: draw_string(font,p+Vector2(-18,35),str(y+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
			if y==0: draw_string(font,p+Vector2(27,-5),char(65+x),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
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
	draw_circle(core,28,Color("123e43"))
	draw_arc(core,24,0,TAU,40,ACC,3,true)
	draw_colored_polygon(PackedVector2Array([core+Vector2(0,-18),core+Vector2(15,-7),core+Vector2(11,17),core+Vector2(-11,17),core+Vector2(-15,-7)]),ACC)
	draw_string(font,core+Vector2(-20,40),"CORE",HORIZONTAL_ALIGNMENT_CENTER,40,11,INK)
	if inside(hover):
		var hovered=tower_at(hover)
		if not hovered.is_empty():
			draw_range(coord(Vector2(hover)),game.stats(hovered)[1]*TILE,COLORS[hovered.kind])
		elif game.phase=="build" and game.placement_error(hover,selected).is_empty():
			draw_range(coord(Vector2(hover)),game.preview_stats(hover,selected)[1]*TILE,COLORS[selected])
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
		draw_tower(p,t.kind)
	for e in game.enemies:
		var p=coord(e.pos)
		var r=19.0 if e.boss else 9.0
		var c=Color("f2767c") if e.slow<=0 else Color("9bcdf7")
		draw_circle(p+Vector2(0,3),r+2,Color("192330"))
		draw_circle(p,r,c)
		if e.boss: draw_arc(p,r+4,0,TAU,36,WARN,3,true)
		draw_rect(Rect2(p+Vector2(-15,-r-8),Vector2(30,4)),BG)
		draw_rect(Rect2(p+Vector2(-15,-r-8),Vector2(30*clampf(e.hp/e.maxhp,0,1),4)),Color("ffc0a5"))
	for s in game.shots:
		draw_line(coord(s.from),coord(s.to),Color(COLORS[s.kind],0.7),3,true)
		draw_circle(coord(s.to),3,COLORS[s.kind])
	if game.phase=="build" and inside(hover):
		var p=coord(Vector2(hover))
		var legal=game.placement_error(hover,selected).is_empty()
		draw_rect(Rect2(p-Vector2.ONE*30,Vector2.ONE*60),ACC if legal else WARN,false,2)
		if legal:
			draw_tower(p,selected,true)
	if paused:
		draw_rect(BOARD,Color(0.05,0.08,0.14,0.42))
		draw_rect(Rect2(BOARD.get_center()-Vector2(112,26),Vector2(224,52)),PANEL)
		draw_string(font,BOARD.get_center()+Vector2(-112,9),"PAUSED",HORIZONTAL_ALIGNMENT_CENTER,224,24,INK)
