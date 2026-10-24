# test_bayanihan_system.gd
# Verification script for Biyahero Trading Post (Bayanihan Post) and Market Middleman Buff.

extends Node

func _ready() -> void:
	print("\n========================================")
	print("Starting Biyahero Trading Post Verification")
	print("========================================")

	# 1. Verify Building Definition
	var b_data := Data.get_building("bayanihan_center")
	assert(not b_data.is_empty(), "bayanihan_center must exist in Data.BUILDINGS")
	assert(float(b_data.get("biyahero_price_bonus", 0.0)) == 0.08, "bayanihan_center must give +8% biyahero price bonus")
	assert(b_data.get("grid_size") == Vector2i(2, 2), "bayanihan_center must have 2x2 footprint")
	assert(b_data.get("unique") == true, "bayanihan_center must be a unique one-time purchase")
	print("✔ Biyahero Post data verified: 2x2 footprint, +8% biyahero bonus, unique: true")

	# 2. Worker speed multiplier remains 1.0 (no longer affects worker movement/speed)
	var base_mult := BuildingManager.get_worker_speed_multiplier()
	assert(base_mult == 1.0, "Worker speed multiplier should remain 1.0 baseline")
	print("✔ Worker speed multiplier verified at neutral 1.0x baseline")

	# 3. Verify Hub Price Multiplier before and after building placement
	var hub_before: Dictionary = Data.get_market_hub("local_biyahero")
	assert(is_equal_approx(float(hub_before.get("price_multiplier", 0.0)), 0.72), "Default local_biyahero rate should be 0.72")
	print("✔ Base local_biyahero price multiplier: %.2fx" % float(hub_before.get("price_multiplier")))

	# 4. Verify Building node with friend's byahero.png sprite and active state
	var b := Building.new()
	b.building_type = "bayanihan_center"
	b.grid_pos = Vector2i(4, 4)
	b.footprint = Vector2i(2, 2)
	b.level = 1
	b.state = Building.BuildingState.ACTIVE
	add_child(b)
	b.queue_redraw()
	BuildingManager.register_building(b)

	assert(BuildingManager.has_building("bayanihan_center") == true, "BuildingManager should detect active Bayanihan Center")
	assert(BuildingManager.get_biyahero_price_bonus() == 0.08, "Biyahero bonus should be 0.08")

	var hub_after: Dictionary = Data.get_market_hub("local_biyahero")
	assert(is_equal_approx(float(hub_after.get("price_multiplier", 0.0)), 0.80), "Boosted local_biyahero rate should be 0.80 (0.72 + 0.08)")
	print("✔ Boosted local_biyahero price multiplier: %.2fx (+8%% middleman buff active)" % float(hub_after.get("price_multiplier")))

	# Cleanup building
	BuildingManager.unregister_building(b)
	b.queue_free()

	print("========================================")
	print("ALL BIYAHERO TRADING POST ASSERTIONS PASSED!")
	print("========================================\n")
	get_tree().quit(0)
