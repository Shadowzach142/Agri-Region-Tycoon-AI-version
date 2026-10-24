extends Node2D

func _ready() -> void:
	print("--- Running In-Game Trade Hubs & Coastal Seaport Capture ---")
	var mg_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var mg = mg_scene.instantiate()
	add_child(mg)

	await get_tree().process_frame
	await get_tree().process_frame

	var farm_grid = mg.find_child("FarmGrid", true, false)
	var hud = mg.find_child("HUDLayer", true, false)
	var cam: Camera2D = mg.find_child("GameCamera", true, false)

	# 1. Unlock East Meadows parcel
	EconomyManager.cash = 99999
	farm_grid.unlock_parcel("east_meadows")

	# Clean plots in test areas
	for x in range(12, 24):
		for y in range(0, 12):
			var t: FarmTile = farm_grid.tiles[x][y]
			t.state = FarmTile.TileState.EMPTY

	# 2. Place General Santos Seaport Terminal at eastern coastline
	var port_placed: bool = farm_grid.place_building(Vector2i(20, 2), "gensan_seaport")
	if port_placed:
		var port_b = BuildingManager.get_building_at_tile(Vector2i(20, 2))
		if port_b:
			port_b.complete_construction()

	# 3. Place Tacurong Grain Mill Depot
	var mill_placed: bool = farm_grid.place_building(Vector2i(14, 2), "tacurong_mill")
	if mill_placed:
		var mill_b = BuildingManager.get_building_at_tile(Vector2i(14, 2))
		if mill_b:
			mill_b.complete_construction()

	# 4. Place Koronadal Wholesale Depot
	var koro_placed: bool = farm_grid.place_building(Vector2i(16, 7), "koronadal_wholesale")
	if koro_placed:
		var koro_b = BuildingManager.get_building_at_tile(Vector2i(16, 7))
		if koro_b:
			koro_b.complete_construction()

	# 5. Place Biyahero Trading Post
	var post_placed: bool = farm_grid.place_building(Vector2i(9, 2), "bayanihan_center")
	if post_placed:
		var post_b = BuildingManager.get_building_at_tile(Vector2i(9, 2))
		if post_b:
			post_b.complete_construction()

	# 6. Position Camera to showcase eastern ocean and new buildings
	if cam:
		var center_target := FarmerMovement.grid_to_pixel_center(Vector2i(17, 5), farm_grid)
		cam.global_position = center_target
		if "target_position" in cam:
			cam.target_position = center_target
		cam.zoom = Vector2(0.88, 0.88)
		if "target_zoom" in cam:
			cam.target_zoom = Vector2(0.88, 0.88)

	# Allow several frames for rendering, shaders, and animations to stabilize
	for i in range(20):
		await get_tree().process_frame

	var img = get_viewport().get_texture().get_image()
	var save_path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/trade_hubs_coastal_showcase.png"
	img.save_png(save_path)
	print("✔ Screenshot successfully saved to: ", save_path)
	get_tree().quit(0)
