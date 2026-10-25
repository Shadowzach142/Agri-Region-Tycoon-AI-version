extends Node

func _ready() -> void:
	var main_scene = load("res://scenes/MainGame.tscn").instantiate()
	add_child(main_scene)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var farm_grid = main_scene.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid not found")
	
	# Unlock land parcels so the entire grid is buildable
	if farm_grid.has_method("unlock_parcel"):
		farm_grid.unlock_parcel("north_orchard")
		farm_grid.unlock_parcel("south_pastures")
		farm_grid.unlock_parcel("west_expansion")
		farm_grid.unlock_parcel("east_meadows")
	
	# Place an assortment of original and newly added buildings on the farm grid:
	# 1. Bahay Kubo (2x2) at (1, 1) - Original
	_place(farm_grid, "bahay_kubo", Vector2i(1, 1))
	
	# 2. Silo / Bodega (2x2) at (4, 1) - Original
	_place(farm_grid, "bodega", Vector2i(4, 1))
	
	# 3. Cold Storage (3x3) at (7, 1) - Original
	_place(farm_grid, "cold_storage", Vector2i(7, 1))
	
	# 4. Drone Station (2x2) at (11, 1) - Original
	_place(farm_grid, "drone_station", Vector2i(11, 1))
	
	# 5. Water Tower (2x2) at (14, 1) - Original
	_place(farm_grid, "water_tower", Vector2i(14, 1))
	
	# 6. Weather Station (3x3) at (1, 5) - Original
	_place(farm_grid, "weather_station", Vector2i(1, 5))
	
	# 7. Solar Dryer (2x3) at (5, 5) - Original
	_place(farm_grid, "solar_dryer", Vector2i(5, 5))
	
	# 8. Bayanihan Center (2x2) at (9, 5) - Newly Added
	_place(farm_grid, "bayanihan_center", Vector2i(9, 5))
	
	# 9. Rice Mill (2x2) at (12, 5) - Newly Added
	_place(farm_grid, "rice_mill", Vector2i(12, 5))
	
	# 10. Tacurong Mill (3x3) at (1, 9) - Newly Added
	_place(farm_grid, "tacurong_mill", Vector2i(1, 9))
	
	# 11. Sugar Mill (3x2) at (5, 9) - Newly Added
	_place(farm_grid, "sugar_mill", Vector2i(5, 9))
	
	# 12. Copra Dryer (3x2) at (9, 9) - Newly Added
	_place(farm_grid, "copra_dryer", Vector2i(9, 9))
	
	# 13. Coffee Roastery (2x2) at (13, 9) - Newly Added
	_place(farm_grid, "coffee_roastery", Vector2i(13, 9))
	
	# 14. Koronadal Wholesale (4x4) at (1, 13) - Newly Added
	_place(farm_grid, "koronadal_wholesale", Vector2i(1, 13))
	
	# 15. GenSan Seaport (4x4) at (20, 4) - Newly Added (east coastline)
	_place(farm_grid, "gensan_seaport", Vector2i(20, 4))
	
	# Center camera over farm
	var cam = main_scene.find_child("GameCamera", true, false)
	if cam:
		cam.position = Vector2(768, 560)
		cam.target_position = Vector2(768, 560)
		cam.zoom = Vector2(0.58, 0.58)
		cam.target_zoom = Vector2(0.58, 0.58)
	
	# Wait 5 frames for rendering
	for i in range(5):
		await get_tree().process_frame
	
	var img := get_viewport().get_texture().get_image()
	var out_path := "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/farm_grid_all_buildings_capture.png"
	img.save_png(out_path)
	print("Captured full farm grid with all buildings to: ", out_path)
	get_tree().quit(0)

func _place(farm_grid: Node2D, b_type: String, pos: Vector2i) -> void:
	var b_data = Data.get_building(b_type)
	var fp: Vector2i = b_data.get("grid_size", Vector2i(2, 2))
	var b := Building.new()
	b.building_type = b_type
	b.grid_pos = pos
	b.footprint = fp
	b.state = Building.BuildingState.ACTIVE
	farm_grid.add_child(b)
	BuildingManager.register_building(b)
