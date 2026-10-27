extends Node2D

func _ready() -> void:
	# Give it 2 frames to draw and then capture viewport
	await get_tree().process_frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("c:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/beach_and_machines_preview.png")
		print("SAVED PREVIEW: beach_and_machines_preview.png")
	get_tree().quit()

func _draw() -> void:
	# Dark background
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.12, 0.14))

	# 1. Beach Sand Tiles Row
	var sand_1 := load("res://assets/sprites/ground/SAND/Sand-01.png") as Texture2D
	var sand_2 := load("res://assets/sprites/ground/SAND/Sand-02.png") as Texture2D
	var sand_3 := load("res://assets/sprites/ground/SAND/Sand-03.png") as Texture2D
	var wsand_1 := load("res://assets/sprites/ground/SAND/WSand-01.png") as Texture2D
	var wsand_2 := load("res://assets/sprites/ground/SAND/WSand-02.png") as Texture2D
	var wsand_3 := load("res://assets/sprites/ground/SAND/WSand-03.png") as Texture2D

	var sands: Array[Texture2D] = [sand_1, sand_2, sand_3, wsand_1, wsand_2, wsand_3]
	var sand_names: Array[String] = ["Dry Sand 1", "Dry Sand 2", "Dry Sand 3", "Wet Sand 1", "Wet Sand 2", "Wet Sand 3"]

	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(60, 40), "BEACH SAND SPRITES (Scale 4x Nearest-Neighbor)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.9, 0.6))

	for i in range(sands.size()):
		var tex := sands[i]
		if tex:
			var px := 60.0 + float(i) * 190.0
			var py := 80.0
			draw_texture_rect(tex, Rect2(px, py, 128, 128), false)
			draw_string(font, Vector2(px, py + 145), sand_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# 2. Drone Machine Sprites (Lv. 1, 2, 3)
	draw_string(font, Vector2(60, 270), "FARM DRONE SPRITES (Lv.1 Plow, Lv.2 Seeder, Lv.3 Harvester)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 0.9, 1.0))
	for lvl in [1, 2, 3]:
		for row in [0, 1]:
			var center_x := 120.0 + float(lvl - 1) * 360.0 + float(row) * 150.0
			var center_y := 350.0
			var ph: float = 0.0 if row == 0 else 3.5
			# Draw shadow
			draw_set_transform(Vector2(center_x, center_y + 35), 0.0, Vector2(1.0, 0.4))
			draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.4))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

			# Draw drone art
			FarmDrone.draw_drone_art(self, Vector2(center_x, center_y), 3.0, lvl, ph, 0.0)
			var sub := "Frame A" if row == 0 else "Frame B"
			draw_string(font, Vector2(center_x - 30, center_y + 60), "Lv.%d %s" % [lvl, sub], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.9, 1.0))

	# 3. Sprinkler Machine Sprites (Idle + Active Frames)
	draw_string(font, Vector2(60, 480), "FIELD SPRINKLER SPRITES (Idle Tripod + 4-Angle Rotating Spray Cycles)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.5, 1.0, 0.8))
	var tex_spk := load("res://assets/sprites/Machine/Sprinklers.png") as Texture2D
	if tex_spk:
		for f_idx in range(Building.SPRINKLER_FRAMES.size()):
			var f_info: Dictionary = Building.SPRINKLER_FRAMES[f_idx]
			var reg: Rect2 = f_info.region
			var stem: Vector2 = f_info.stem
			var cx := 100.0 + float(f_idx) * 230.0
			var cy := 590.0

			# Wet patch base
			draw_set_transform(Vector2(cx, cy), 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 24.0, Color(0.12, 0.28, 0.35, 0.5))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

			var dest_pos := Vector2(cx, cy) - stem
			draw_texture_rect_region(tex_spk, Rect2(dest_pos, reg.size), reg)

			var desc := "Frame 0 (Idle)" if f_idx == 0 else "Spray Angle %d" % f_idx
			draw_string(font, Vector2(cx - 40, cy + 30), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
