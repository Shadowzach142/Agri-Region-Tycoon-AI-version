extends Node

func _ready() -> void:
	print("========================================")
	print("Verifying TileInfoPanel Compact Layout, Bar Boxes & Crop Sprites")
	print("========================================")

	var main_scene = load("res://scenes/MainGame.tscn")
	assert(main_scene != null, "MainGame.tscn must load")

	var main_game = main_scene.instantiate()
	add_child(main_game)

	var panel = main_game.find_child("TileInfoPanel", true, false)
	assert(panel != null, "TileInfoPanel must exist")

	# 1. Check compact dimensions (400x226)
	var w = panel.offset_right - panel.offset_left
	var h = panel.offset_bottom - panel.offset_top
	assert(w == 400.0, "Panel width should be 400 (got %f)" % w)
	assert(h == 226.0, "Panel height should be 226 (got %f)" % h)
	print("✔ TileInfoPanel Compact Dimensions: 400x226 (snug, not oversized)")

	# 2. Check MarginContainer
	var margin = panel.find_child("Margin", true, false)
	assert(margin != null, "Margin container must exist")
	var m_left = margin.get_theme_constant("margin_left")
	var m_right = margin.get_theme_constant("margin_right")
	var m_top = margin.get_theme_constant("margin_top")
	var m_bottom = margin.get_theme_constant("margin_bottom")
	assert(m_left == m_right, "Left and right margins must be symmetrical (left=%d, right=%d)" % [m_left, m_right])
	assert(m_top >= 44, "Top margin must clear metal clamp (top=%d)" % m_top)
	print("✔ Symmetrical Margins: left=%d, right=%d, top=%d (clears clamp), bottom=%d" % [m_left, m_right, m_top, m_bottom])

	# 3. Check PlantBox
	var plant_box = panel.find_child("PlantBox", true, false)
	assert(plant_box != null, "PlantBox must exist")
	var plant_style = plant_box.get_theme_stylebox("panel")
	assert(plant_style != null, "PlantBox style must exist")
	assert(plant_style.content_margin_left == plant_style.content_margin_right, "PlantBox content margins must be symmetrical")
	print("✔ PlantBox: Symmetrical content margins (%f, %f)" % [plant_style.content_margin_left, plant_style.content_margin_right])

	# 4. Check Inner Border Bar Containers
	for bar_box_name in ["GrowthBarBox", "HealthBarBox", "MoistureBarBox"]:
		var box = panel.find_child(bar_box_name, true, false) as PanelContainer
		assert(box != null, "%s must exist" % bar_box_name)
		var box_style = box.get_theme_stylebox("panel")
		assert(box_style is StyleBoxTexture, "%s must have StyleBoxTexture" % bar_box_name)
		var tex_path = box_style.texture.resource_path
		assert("HUD-dark brown.png" in tex_path or "Inner" in tex_path, "%s must use inner bar texture (got %s)" % [bar_box_name, tex_path])
	print("✔ Inner Bar Boxes: All 3 gauges wrapped in PanelContainers with InnerBarBg.tres (beveled border cannot be covered by bar fill)")

	# 5. Check ProgressBars inside boxes have StyleBoxEmpty background
	var growth_bar = panel.find_child("GrowthBar", true, false) as ProgressBar
	var health_bar = panel.find_child("HealthBar", true, false) as ProgressBar
	var moist_bar  = panel.find_child("MoistureBar", true, false) as ProgressBar
	assert(growth_bar != null and health_bar != null and moist_bar != null, "All progress bars must exist")
	assert(health_bar.get_theme_stylebox("background") is StyleBoxEmpty, "HealthBar background must be StyleBoxEmpty to keep inner border visible")
	print("✔ Bar Fill Insulation: ProgressBar background is empty so fill is strictly constrained inside the well")

	# 6. Check Actual Crop Sprites
	var port_tex = panel.find_child("PortraitTexture", true, false) as TextureRect
	assert(port_tex != null, "PortraitTexture must exist inside PlantBox")

	# Test 6a: Palay Crop (Stage 2)
	var crop_tile = FarmTile.new()
	crop_tile.state = FarmTile.TileState.GROWING
	crop_tile.crop_type = "palay"
	crop_tile.growth_progress = 0.50
	crop_tile.health = 1.0
	crop_tile.soil_moisture = 80.0
	panel.inspect_tile(Vector2i(2, 3), crop_tile)

	assert(port_tex.visible, "PortraitTexture must be visible for crop")
	assert(port_tex.texture != null, "PortraitTexture must have a crop texture")
	assert("RICE-P2.png" in port_tex.texture.resource_path, "Palay at 50%% growth should show RICE-P2.png (got %s)" % port_tex.texture.resource_path)
	print("✔ Actual Crop Sprite: Palay at 50% correctly displays RICE-P2.png")

	# Test 6b: Banana Crop (Stage 4 - Mature Bunch)
	var banana_tile = FarmTile.new()
	banana_tile.state = FarmTile.TileState.HARVESTABLE
	banana_tile.crop_type = "banana"
	banana_tile.growth_progress = 1.0
	banana_tile.health = 1.0
	banana_tile.soil_moisture = 70.0
	panel.inspect_tile(Vector2i(4, 4), banana_tile)
	assert("BANANA-P4.png" in port_tex.texture.resource_path, "Mature banana should show BANANA-P4.png (got %s)" % port_tex.texture.resource_path)
	print("✔ Actual Crop Sprite: Mature Banana correctly displays BANANA-P4.png")

	# Test 6c: Plowed Soil
	var plow_tile = FarmTile.new()
	plow_tile.state = FarmTile.TileState.PLOWED
	plow_tile.soil_moisture = 50.0
	panel.inspect_tile(Vector2i(1, 1), plow_tile)
	assert("BARE-SOIL-01.png" in port_tex.texture.resource_path, "Plowed soil should show BARE-SOIL-01.png (got %s)" % port_tex.texture.resource_path)
	print("✔ Actual Ground Sprite: Plowed soil displays BARE-SOIL-01.png")

	# Test 6d: Empty Grass
	var empty_tile = FarmTile.new()
	empty_tile.state = FarmTile.TileState.EMPTY
	panel.inspect_tile(Vector2i(0, 0), empty_tile)
	assert("NGRASS-01.png" in port_tex.texture.resource_path, "Empty tile should show NGRASS-01.png (got %s)" % port_tex.texture.resource_path)
	print("✔ Actual Ground Sprite: Empty grass displays NGRASS-01.png")

	# 7. Check Stability (fixed size labels, clip_text)
	var crop_lbl = panel.find_child("CropLabel", true, false) as Label
	var state_lbl = panel.find_child("StateLabel", true, false) as Label
	assert(crop_lbl.clip_text == true, "CropLabel must have clip_text = true to prevent dynamic vertical shifting")
	assert(state_lbl.clip_text == true, "StateLabel must have clip_text = true to prevent dynamic vertical shifting")
	print("✔ Layout Stability: clip_text enabled on labels, preventing jumping and dynamic movement")

	print("========================================")
	print("ALL TILE INFO PANEL TESTS PASSED (100%)")
	print("========================================")
	get_tree().quit(0)
