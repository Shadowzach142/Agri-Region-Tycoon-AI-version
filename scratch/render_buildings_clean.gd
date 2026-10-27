extends Node2D

func _ready() -> void:
	var buildings_to_test := [
		{"type": "bahay_kubo", "name": "Bahay Kubo", "pos": Vector2(180, 220), "fp": Vector2i(2, 2)},
		{"type": "bodega", "name": "Bodega / Silo", "pos": Vector2(480, 220), "fp": Vector2i(2, 2)},
		{"type": "drone_station", "name": "Drone Hangar", "pos": Vector2(780, 220), "fp": Vector2i(2, 2)},
		{"type": "sprinkler", "name": "Sprinkler", "pos": Vector2(1040, 220), "fp": Vector2i(1, 1)},
		{"type": "bayanihan_center", "name": "Bayanihan Center", "pos": Vector2(280, 520), "fp": Vector2i(2, 2)},
		{"type": "water_tower", "name": "Water Tower", "pos": Vector2(680, 520), "fp": Vector2i(2, 2)},
		{"type": "cold_storage", "name": "Cold Storage", "pos": Vector2(1040, 520), "fp": Vector2i(3, 3)},
	]

	for item in buildings_to_test:
		var base_p: Vector2 = item["pos"]
		var b := Building.new()
		b.building_type = item["type"]
		b.state = Building.BuildingState.ACTIVE
		b.level = 1
		b.position = base_p
		add_child(b)

	await get_tree().process_frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	if img:
		var out_path := "c:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/clean_buildings_preview.png"
		img.save_png(out_path)
		print("SAVED PREVIEW: clean_buildings_preview.png")
	get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.16, 0.14))

	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(40, 40), "BUILDINGS VISUAL VERIFICATION (Circles Removed)", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.95, 0.7))

	# Load grass ground tile
	var grass_tex := load("res://assets/sprites/ground/ground_normal_grass.png") as Texture2D

	var buildings_to_test := [
		{"type": "bahay_kubo", "name": "Bahay Kubo", "pos": Vector2(180, 220), "fp": Vector2i(2, 2)},
		{"type": "bodega", "name": "Bodega / Silo", "pos": Vector2(480, 220), "fp": Vector2i(2, 2)},
		{"type": "drone_station", "name": "Drone Hangar", "pos": Vector2(780, 220), "fp": Vector2i(2, 2)},
		{"type": "sprinkler", "name": "Sprinkler", "pos": Vector2(1040, 220), "fp": Vector2i(1, 1)},
		{"type": "bayanihan_center", "name": "Bayanihan Center", "pos": Vector2(280, 520), "fp": Vector2i(2, 2)},
		{"type": "water_tower", "name": "Water Tower", "pos": Vector2(680, 520), "fp": Vector2i(2, 2)},
		{"type": "cold_storage", "name": "Cold Storage", "pos": Vector2(1040, 520), "fp": Vector2i(3, 3)},
	]

	for item in buildings_to_test:
		var base_p: Vector2 = item["pos"]
		if grass_tex:
			for gx in range(item["fp"].x):
				for gy in range(item["fp"].y):
					var tile_iso := base_p + Vector2((gx - gy) * 32.0, (gx + gy) * 16.0)
					draw_texture_rect(grass_tex, Rect2(tile_iso - Vector2(64, 32), Vector2(128, 64)), false)

		draw_string(font, base_p + Vector2(-50, 60), item["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
