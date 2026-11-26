extends Node
class Board extends Node2D:
	var tex:Texture2D
	var manifest:Dictionary
	var scale_mult:float=1.0
	func _draw():
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		var n:int=0
		for c in manifest.characters.values():
			for seq in c.values():
				for f in seq:
					var r:Rect2=Rect2(f.rect[0],f.rect[1],f.rect[2],f.rect[3])
					var anchor:Vector2=Vector2(55+(n%12)*105,95+int(n/12.0)*125)
					var s:float=scale_mult*(0.28 if n%2==0 else 0.45)
					var d:=Rect2(anchor+Vector2(f.offset[0],f.offset[1])*s,r.size*s)
					var mod:=Color(1,1,1,0.48 if n%3==0 else 1.0)
					if f.get("flip_x",false):
						# An explicit transform guarantees destination bounds and pivot.
						draw_set_transform(Vector2(d.position.x+d.size.x,d.position.y),0,Vector2(-1,1))
						draw_texture_rect_region(tex,Rect2(0,0,d.size.x,d.size.y),r,mod,false,true)
						draw_set_transform(Vector2.ZERO)
					else:
						draw_texture_rect_region(tex,d,r,mod,false,true)
					n+=1
func _ready():
	var views:Array[SubViewport]=[]
	for prefix in ["","new-"]:
		var v:=SubViewport.new()
		v.size=Vector2i(1280,1600)
		v.transparent_bg=true
		v.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		add_child(v)
		var node:=Board.new()
		node.tex=load("res://assets/"+prefix+"atlas.png")
		node.manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+prefix+"manifest.json"))
		v.add_child(node)
		views.append(v)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var a:Image=views[0].get_texture().get_image()
	var b:Image=views[1].get_texture().get_image()
	a.save_png("res://native-original.png")
	b.save_png("res://native-optimized.png")
	var d:=FileAccess.open("res://native-proof.json",FileAccess.WRITE)
	d.store_string(JSON.stringify({"size":[a.get_width(),a.get_height()],"equal":a.get_data()==b.get_data(),"render_driver":RenderingServer.get_current_rendering_driver_name()}))
	# Native rendered evidence saved, show both image regions for manual check.
	var sprite:=Sprite2D.new()
	sprite.texture=ImageTexture.create_from_image(b)
	sprite.centered=false
	sprite.scale=Vector2(.5,.5)
	add_child(sprite)
