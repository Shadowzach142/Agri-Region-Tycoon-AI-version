extends Node2D

func _ready() -> void:
	# Create a simple view with ground tile and obstacles
	var vp = get_viewport()
	
	# Load textures
	var stump_tex = load("res://assets/sprites/obstacles/OBSTACLE_Old-Tree-Stump..png")
	var rock1_tex = load("res://assets/sprites/obstacles/OBSTACLE_Boulder-Oval.png")
	var rock2_tex = load("res://assets/sprites/obstacles/OBSTACLE_Boulder-kinda-round..png")
	var rock3_tex = load("res://assets/sprites/obstacles/OBSTACLE_Boulder-Trio.png")
	
	var snail_tex = load("res://assets/sprites/TILE OVERLAYS/TO-KUHOL-SNAIL.png")
	var worm_tex = load("res://assets/sprites/TILE OVERLAYS/TO-ARMY-WORM.png")
	var bug_tex = load("res://assets/sprites/TILE OVERLAYS/TO-RICE-BLACKBUG.png")
	var wilt_tex = load("res://assets/sprites/TILE OVERLAYS/TO-Wilt-Spores.png")
	
	var ground_tex = load("res://assets/sprites/ground/NGRASS/NGRASS-1.png")
	if ground_tex == null:
		ground_tex = load("res://assets/sprites/ground/ground_grass.png")
	
	# Test drawing 4 obstacles on top row, 4 overlays on bottom row
	var positions = [
		Vector2(150, 150), Vector2(350, 150), Vector2(550, 150), Vector2(750, 150),
		Vector2(150, 400), Vector2(350, 400), Vector2(550, 400), Vector2(750, 400)
	]
	
	# Draw background diamonds
	for i in range(8):
		var p = positions[i]
		
		# Draw diamond fill
		var fill = Polygon2D.new()
		fill.polygon = PackedVector2Array([
			p + Vector2(0, -32), p + Vector2(64, 0), p + Vector2(0, 32), p + Vector2(-64, 0)
		])
		fill.color = Color(0.35, 0.58, 0.28, 1.0)
		add_child(fill)
		
		# Draw diamond outline
		var border = Line2D.new()
		border.width = 1.5
		border.default_color = Color(0.18, 0.28, 0.14, 0.6)
		border.closed = true
		border.add_point(p + Vector2(0, -32))
		border.add_point(p + Vector2(64, 0))
		border.add_point(p + Vector2(0, 32))
		border.add_point(p + Vector2(-64, 0))
		add_child(border)
	
	# Top row: 4 obstacles
	var obs_list = [
		{"tex": stump_tex, "scale": 4.0, "offset_y": -16.0, "name": "Stump (4x)"},
		{"tex": rock1_tex, "scale": 3.2, "offset_y": -10.0, "name": "Rock Oval (3.2x)"},
		{"tex": rock2_tex, "scale": 3.2, "offset_y": -10.0, "name": "Rock Round (3.2x)"},
		{"tex": rock3_tex, "scale": 3.2, "offset_y": -10.0, "name": "Rock Trio (3.2x)"}
	]
	
	for i in range(4):
		var o = obs_list[i]
		var spr = Sprite2D.new()
		spr.texture = o["tex"]
		spr.scale = Vector2(o["scale"], o["scale"])
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		spr.position = positions[i] + Vector2(0, o["offset_y"])
		add_child(spr)
		
		var lbl = Label.new()
		lbl.text = o["name"]
		lbl.position = positions[i] + Vector2(-50, 40)
		add_child(lbl)
		
	# Bottom row: 4 overlays
	var over_list = [
		{"tex": snail_tex, "name": "Kuhol Snail"},
		{"tex": worm_tex, "name": "Armyworm"},
		{"tex": bug_tex, "name": "Rice Blackbug"},
		{"tex": wilt_tex, "name": "Wilt Spores"}
	]
	
	for i in range(4):
		var o = over_list[i]
		var spr = Sprite2D.new()
		spr.texture = o["tex"]
		spr.scale = Vector2(4.0, 4.0)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		# 48px height, center at 32 - 48*4/2 = -64
		spr.position = positions[4 + i] + Vector2(0, 32.0 - 48.0 * 4.0 / 2.0)
		add_child(spr)
		
		var lbl = Label.new()
		lbl.text = o["name"]
		lbl.position = positions[4 + i] + Vector2(-50, 40)
		add_child(lbl)

	# Wait two frames and save image
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img = get_viewport().get_texture().get_image()
	img.save_png("scratch/test_obstacle_visual.png")
	print("Saved scratch/test_obstacle_visual.png successfully!")
	get_tree().quit(0)
