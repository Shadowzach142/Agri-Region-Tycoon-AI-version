extends Node2D

func _ready() -> void:
	print("--- Running In-Game Diagnostic Heatmap Capture ---")
	var mg_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var mg = mg_scene.instantiate()
	add_child(mg)

	await get_tree().process_frame
	await get_tree().process_frame

	var farm_grid = mg.find_child("FarmGrid", true, false)
	var hud = mg.find_child("HUDLayer", true, false)

	# 1. Setup sample crops & soil conditions
	# Parched plot (x=2, y=2)
	var t1: FarmTile = farm_grid.tiles[2][2]
	t1.state = FarmTile.TileState.PLANTED
	t1.crop_type = "yellow_corn"
	t1.soil_moisture = 24.0
	t1.health = 0.55

	# Ripe Harvestable Corn (x=3, y=2)
	var t2: FarmTile = farm_grid.tiles[3][2]
	t2.state = FarmTile.TileState.HARVESTABLE
	t2.crop_type = "yellow_corn"
	t2.soil_moisture = 60.0
	t2.health = 1.0

	# Infested Crop (x=2, y=3)
	var t3: FarmTile = farm_grid.tiles[2][3]
	t3.state = FarmTile.TileState.INFECTED
	t3.crop_type = "palay"
	t3.pest_type = "kuhol"
	t3.soil_moisture = 85.0
	t3.health = 0.30

	# Optimal Moist Rice (x=3, y=3)
	var t4: FarmTile = farm_grid.tiles[3][3]
	t4.state = FarmTile.TileState.GROWING
	t4.crop_type = "palay"
	t4.growth_progress = 0.75
	t4.soil_moisture = 72.0
	t4.health = 0.95

	# 2. Place a mock sprinkler building at (5, 5)
	var building_script = load("res://src/buildings/Building.gd")
	var sp_node: Node = Node2D.new()
	sp_node.set_script(building_script)
	sp_node.name = "Sprinkler_1"
	sp_node.building_type = "sprinkler"
	sp_node.grid_pos = Vector2i(5, 5)
	sp_node.footprint = Vector2i(1, 1)
	sp_node.state = sp_node.BuildingState.ACTIVE
	farm_grid.add_child(sp_node)
	BuildingManager.register_building(sp_node)

	# 3. Activate Heatmap
	var overlay: FarmHeatmapOverlay = farm_grid.get_heatmap_overlay()
	overlay.activate()
	overlay.alpha = 1.0 # Immediately set full alpha for pristine screenshot

	var legend_bar = hud.find_child("HeatmapLegendBar", true, false) as HeatmapLegendBar
	if legend_bar:
		legend_bar.heatmap_overlay = overlay
		legend_bar.visible = true

	# Set hovered tile to (2, 2) to show hover telemetry readout
	farm_grid.hovered_grid_pos = Vector2i(2, 2)

	# Allow a few frames to render
	for i in range(12):
		await get_tree().process_frame

	var img = get_viewport().get_texture().get_image()
	var save_path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/diagnostic_heatmap_showcase.png"
	img.save_png(save_path)
	print("✔ Screenshot successfully saved to: ", save_path)
	get_tree().quit(0)
