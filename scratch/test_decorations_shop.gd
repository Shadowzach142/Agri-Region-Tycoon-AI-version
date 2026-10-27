extends Node

func _ready() -> void:
	print("==================================================")
	print("🧪 RUNNING DECORATIONS SHOP & PLACEMENT TEST SUITE")
	print("==================================================")

	var flowers := [
		"flower_santan",
		"flower_gumamela",
		"flower_garden_hedge",
		"flower_bougainvillea",
		"flower_topiary_shrub",
		"flower_wildflower_bed",
		"flower_blossom_cluster"
	]

	# 1. Check Data.BUILDINGS registration
	print("\n--- 1. Testing Data.BUILDINGS registration ---")
	for f_key in flowers:
		assert(Data.BUILDINGS.has(f_key), "Data.BUILDINGS missing key: %s" % f_key)
		var b_data: Dictionary = Data.get_building(f_key)
		assert(b_data.get("shop_category", "") == "decorations", "%s must have shop_category == 'decorations'" % f_key)
		assert(b_data.get("is_decoration", false) == true, "%s must have is_decoration == true" % f_key)
		assert(b_data.get("grid_size", Vector2i.ZERO) == Vector2i(1, 1), "%s must have 1x1 footprint" % f_key)
		assert(b_data.get("build_time", -1.0) == 0.0, "%s must have 0.0 build_time" % f_key)
		assert(int(b_data.get("cost", 0)) > 0, "%s must have cost > 0" % f_key)
		print("  ✔ %s: %s (₱%d) - 1x1 instant decor" % [f_key, b_data.get("display_name"), b_data.get("cost")])

	# 2. Check Texture Loading & Placement Preview
	print("\n--- 2. Testing Texture Loading & Placement Previews ---")
	var BuildingScript = load("res://src/buildings/Building.gd")
	for f_key in flowers:
		var prev_norm: Dictionary = BuildingScript.get_placement_preview(f_key, false)
		assert(not prev_norm.is_empty(), "Missing placement preview for %s" % f_key)
		var tex: Texture2D = prev_norm.get("texture", null)
		assert(tex != null, "Missing texture for %s" % f_key)
		assert(tex.get_width() == 32 and tex.get_height() == 32, "%s texture should be 32x32, got %dx%d" % [f_key, tex.get_width(), tex.get_height()])
		assert(float(prev_norm.get("scale", 0.0)) == 2.0, "%s scale should be 2.0" % f_key)
		print("  ✔ %s: texture valid %s, scale 2.0x" % [f_key, tex.resource_path])

	# 3. Check MainGame: ShopPanel Category Tab & FarmGrid Placement
	print("\n--- 3. Testing MainGame Scene & ShopPanel Decorations Tab ---")
	var grid_scene = load("res://scenes/MainGame.tscn")
	var main_game = grid_scene.instantiate()
	add_child(main_game)
	var shop_panel = main_game.find_child("ShopPanel", true, false)
	assert(shop_panel != null, "ShopPanel not found in MainGame")
	assert(shop_panel.decorations_grid != null, "ShopPanel.decorations_grid must be initialized")
	var decor_cards: Array = shop_panel.decorations_grid.get_children()
	assert(decor_cards.size() == 7, "ShopPanel should have 7 decoration cards, got %d" % decor_cards.size())
	print("  ✔ ShopPanel decorations_grid initialized with %d flower cards" % decor_cards.size())

	# 4. Check Placement & BuildingCardPopup on FarmGrid
	print("\n--- 4. Testing Flower Placement on FarmGrid ---")
	var farm_grid = main_game.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid not found in MainGame")

	var place_pos := Vector2i(2, 2)
	EconomyManager.cash = 1000
	var success: bool = farm_grid.place_building(place_pos, "flower_santan")
	assert(success, "Failed to place flower_santan at (2, 2)")
	var tile = farm_grid.tiles[place_pos.x][place_pos.y]
	assert(tile.state == FarmTile.TileState.BUILDING, "Tile state must be BUILDING")
	var placed_flower = tile.building_ref
	assert(placed_flower != null, "Tile building_ref must be non-null")
	assert(placed_flower.building_type == "flower_santan", "Placed building_type must be flower_santan")
	assert(placed_flower.duration == 0.0, "Decoration duration must be 0.0")
	assert(placed_flower.state == placed_flower.BuildingState.ACTIVE, "Decoration must be immediately ACTIVE")
	print("  ✔ flower_santan placed instantly at (2, 2), state = ACTIVE")

	# Test horizontal flip
	print("\n--- 5. Testing Horizontal Flip ---")
	assert(placed_flower.is_flipped == false, "Initial flip should be false")
	placed_flower.toggle_flip()
	assert(placed_flower.is_flipped == true, "Flip state should be true after toggle")
	assert(placed_flower.art_sprite.flip_h == true, "art_sprite.flip_h must be true")
	print("  ✔ Horizontal flip toggles art_sprite.flip_h correctly")

	# Test BuildingCardPopup inspection
	print("\n--- 6. Testing BuildingCardPopup Inspection & Demolition ---")
	var card_popup_scene = load("res://scenes/BuildingCardPopup.tscn")
	var popup_node = card_popup_scene.instantiate()
	add_child(popup_node)
	popup_node.open_for_building(placed_flower)
	assert(popup_node.level_label.text == "Garden Flora • 1×1 Plot", "level_label unexpected: %s" % popup_node.level_label.text)
	assert(popup_node.status_label.text == "🌸 Beautifying Farmstead", "status_label unexpected: %s" % popup_node.status_label.text)
	assert(popup_node.upgrade_btn.visible == false, "upgrade_btn should be hidden for decorations")
	assert(popup_node.next_stats_label.visible == false, "next_stats_label should be hidden for decorations")
	assert("Dig Up" in popup_node.demolish_btn.text, "demolish_btn text should say Dig Up, got: %s" % popup_node.demolish_btn.text)
	print("  ✔ BuildingCardPopup correctly displays decoration mode")

	# Demolish & Dig up
	var starting_cash: int = EconomyManager.cash
	popup_node._on_demolish_pressed()
	assert(farm_grid.tiles[place_pos.x][place_pos.y].state == FarmTile.TileState.EMPTY, "Tile state after dig up should be EMPTY")
	assert(EconomyManager.cash > starting_cash, "Demolishing decoration should refund cash")
	print("  ✔ Decoration dug up cleanly, tile reset to EMPTY, cash refunded")

	print("\n==================================================")
	print("🎉 ALL DECORATIONS SHOP & PLACEMENT TESTS PASSED!")
	print("==================================================")
	get_tree().quit(0)
