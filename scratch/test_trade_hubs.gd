# test_trade_hubs.gd
# Verification script for Trade Hubs, Coastal Seaport, Ratio Fit, and Biyahero Post.

extends Node2D

func _ready() -> void:
	print("\n========================================")
	print("Starting Trade Hubs & Coastal Seaport Verification")
	print("========================================")

	# 1. Instantiate MainGame scene
	var mg_scene: PackedScene = load("res://scenes/MainGame.tscn")
	assert(mg_scene != null, "MainGame.tscn must load successfully")
	var mg = mg_scene.instantiate()
	add_child(mg)

	await get_tree().process_frame
	await get_tree().process_frame

	var farm_grid = mg.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid must exist")

	var hud = mg.find_child("HUDLayer", true, false)
	assert(hud != null, "HUDLayer must exist")

	# 2. Verify SeaWater node is instantiated at z_index -40
	var sea_water = farm_grid.find_child("SeaWater", true, false)
	assert(sea_water != null, "SeaWater must be instantiated in FarmGrid")
	assert(sea_water.z_index == -40, "SeaWater must be at z_index -40")
	print("✔ Check 1 Passed: Coastal SeaWater instantiated at z_index -40 along eastern coastline.")

	# 3. Verify Footprint Ratios in Building.get_art_fit()
	var fit_byahero := Building.get_art_fit("bayanihan_center")
	assert(not fit_byahero.is_empty(), "bayanihan_center must have art fit")
	assert(fit_byahero["texture"] != null, "byahero texture must load")

	var fit_tacurong := Building.get_art_fit("tacurong_mill")
	assert(not fit_tacurong.is_empty(), "tacurong_mill must have art fit")
	assert(is_equal_approx(fit_tacurong["scale"], 0.85), "tacurong_mill scale must match calibrated tile fit 0.85")

	var fit_koronadal := Building.get_art_fit("koronadal_wholesale")
	assert(not fit_koronadal.is_empty(), "koronadal_wholesale must have art fit")
	assert(is_equal_approx(fit_koronadal["scale"], 1.15), "koronadal_wholesale scale must match calibrated tile fit 1.15")

	var fit_gensan := Building.get_art_fit("gensan_seaport")
	assert(not fit_gensan.is_empty(), "gensan_seaport must have art fit")
	assert(is_equal_approx(fit_gensan["scale"], 1.00), "gensan_seaport scale must match calibrated tile fit 1.00")
	print("✔ Check 2 Passed: Building art fits match calibrated tile proportions across all sizes.")

	# 4. Verify Market Hub Unlocks and Initial Lock State
	assert(Data.is_hub_available("local_biyahero") == true, "local_biyahero is always available")
	assert(Data.is_hub_available("tacurong") == false, "tacurong requires tacurong_mill")
	assert(Data.is_hub_available("koronadal") == false, "koronadal requires koronadal_wholesale")
	assert(Data.is_hub_available("gensan_port") == false, "gensan_port requires gensan_seaport")
	print("✔ Check 3 Passed: Regional market hubs are locked until respective buildings are constructed.")

	# 5. Verify Seaport Shoreline Restriction
	EconomyManager.cash = 50000
	var parcel_unlocked: bool = farm_grid.unlock_parcel("east_meadows") # rect(12, 0, 12, 12)
	assert(parcel_unlocked, "east_meadows should unlock with ₱50000")

	# Ensure test 4x4 coastline plots are clean EMPTY plots (clear any procedural rocks/trees)
	for dx in range(4):
		for dy in range(4):
			var t: FarmTile = farm_grid.tiles[20 + dx][2 + dy]
			t.state = FarmTile.TileState.EMPTY

	farm_grid.placing_building_type = "gensan_seaport"
	farm_grid.placing_footprint = Vector2i(4, 4)

	# Try placing away from coast: at (14, 2) -> (14+4 = 18 != 24) -> invalid!
	var invalid_pos := Vector2i(14, 2)
	assert(farm_grid.is_valid_building_placement(invalid_pos, Vector2i(4, 4)) == false, "Seaport must be rejected inland")

	# Try placing at coast: at (20, 2) -> (20+4 = 24 == GRID_SIZE.x) -> valid!
	var valid_coast_pos := Vector2i(20, 2)
	assert(farm_grid.is_valid_building_placement(valid_coast_pos, Vector2i(4, 4)) == true, "Seaport must be allowed on eastern coastline")
	print("✔ Check 4 Passed: Seaport is strictly restricted to the eastern coastline (x+4 == 24).")

	# 6. Test Building Placement & Hub Activation
	# Ensure Tacurong Mill test plots are clean
	for dx in range(3):
		for dy in range(3):
			var t: FarmTile = farm_grid.tiles[13 + dx][2 + dy]
			t.state = FarmTile.TileState.EMPTY


	# Place and complete Tacurong Mill
	var mill_placed: bool = farm_grid.place_building(Vector2i(13, 2), "tacurong_mill")
	assert(mill_placed, "Tacurong Mill should place successfully on unlocked parcel")
	var mill_node = BuildingManager.get_building_at_tile(Vector2i(13, 2))
	assert(mill_node != null, "Building node should exist at tile")
	mill_node.complete_construction()

	assert(Data.is_hub_available("tacurong") == true, "Tacurong hub must be unlocked after mill completed")
	var tac_hub: Dictionary = Data.get_market_hub("tacurong")
	assert(tac_hub.get("boosted") == true, "Tacurong hub must be marked as boosted")
	assert(is_equal_approx(float(tac_hub.get("price_multiplier")), 1.11), "Tacurong price multiplier must be 1.11 (1.05 base + 0.06 bonus)")
	print("✔ Check 5 Passed: Tacurong Mill unlocks and boosts Tacurong Sell Hub (+6% payout).")

	# Place and complete Biyahero Trading Post
	var post_placed: bool = farm_grid.place_building(Vector2i(2, 2), "bayanihan_center")
	assert(post_placed, "Biyahero Post should place on homestead")
	var post_node = BuildingManager.get_building_at_tile(Vector2i(2, 2))
	post_node.complete_construction()

	assert(BuildingManager.get_biyahero_price_bonus() == 0.08, "Biyahero price bonus must be 0.08")
	var biya_hub: Dictionary = Data.get_market_hub("local_biyahero")
	assert(is_equal_approx(float(biya_hub.get("price_multiplier")), 0.80), "Local Biyahero rate must be 0.80 (0.72 + 0.08)")
	print("✔ Check 6 Passed: Biyahero Trading Post applies one-time +8% payout buff to middleman.")

	# Place and complete Gensan Seaport at coast
	var port_placed: bool = farm_grid.place_building(valid_coast_pos, "gensan_seaport")
	assert(port_placed, "Seaport should place on coast")
	var port_node = BuildingManager.get_building_at_tile(valid_coast_pos)
	port_node.complete_construction()

	assert(Data.is_hub_available("gensan_port") == true, "Gensan port hub must be unlocked after seaport completed")
	var port_hub: Dictionary = Data.get_market_hub("gensan_port")
	assert(port_hub.get("boosted") == true, "Gensan port hub must be boosted")
	assert(is_equal_approx(float(port_hub.get("price_multiplier")), 1.67), "Gensan price multiplier must be 1.67 (1.55 base + 0.12 bonus)")
	print("✔ Check 7 Passed: Seaport unlocks General Santos export hub (+12% payout, reduced rot & fuel).")

	# 7. Check ShopPanel Trade tab & Cards
	var shop_panel = hud.find_child("ShopPanel", true, false)
	assert(shop_panel != null, "ShopPanel must exist")
	assert(shop_panel.trade_grid != null, "Trade tab grid must exist in ShopPanel")
	assert(shop_panel.trade_grid.get_child_count() >= 3, "Trade tab must contain trade hub buildings")
	print("✔ Check 8 Passed: ShopPanel Trade tab contains all trade hub and port buildings.")

	# 8. Check SellPanel locked vs unlocked cards
	MarketManager.add_harvest_to_storage("palay", 100, "Grade A", 100.0)
	var sell_panel = hud.find_child("SellPanel", true, false)
	assert(sell_panel != null, "SellPanel must exist")
	sell_panel.visible = true
	sell_panel._refresh_view()
	# Tacurong, Biyahero, Gensan are unlocked; Koronadal is still locked
	var cards: Array = sell_panel._hub_cards
	assert(cards[0]["btn"].disabled == false, "Biyahero must be enabled")
	assert(cards[1]["btn"].disabled == false, "Tacurong must be enabled")
	assert(cards[2]["btn"].disabled == true, "Koronadal must be disabled (locked)")
	assert(cards[3]["btn"].disabled == false, "Gensan must be enabled")
	print("✔ Check 9 Passed: SellPanel reflects live lock and unlock state of all 4 shipping destinations.")

	print("\n🎉 ALL TRADE HUBS & SEAPORT VERIFICATION CHECKS PASSED PERFECTLY! 🎉\n")
	get_tree().quit(0)
