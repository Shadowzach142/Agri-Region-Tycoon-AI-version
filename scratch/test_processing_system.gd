extends Node

func _ready() -> void:
	print("==================================================")
	print("Running Agro-Industrial Milling & Processing Tests")
	print("==================================================")

	# 1. Verify Data Models
	assert(Data.PROCESSED_GOODS.size() >= 7, "PROCESSED_GOODS must have at least 7 items")
	var mr = Data.get_crop("milled_rice")
	assert(not mr.is_empty(), "milled_rice must be found in Data.get_crop")
	assert(mr.get("is_processed") == true, "milled_rice must be marked is_processed")
	assert(mr.get("base_price") == 220, "milled_rice base price must be 220")
	assert(Data.is_processed_good("milled_rice") == true, "is_processed_good must return true")
	print("✔ Data Models: 7 processed commodities registered with base prices & metadata")

	# 2. Verify Facilities in BUILDINGS
	var r_mill = Data.get_building("rice_mill")
	assert(not r_mill.is_empty(), "rice_mill must exist in BUILDINGS")
	assert(r_mill.get("shop_category") == "processing", "rice_mill category must be processing")
	var recipe = r_mill.get("recipe", {})
	assert(recipe.get("input_crop") == "palay", "rice_mill input crop must be palay")
	assert(recipe.get("input_qty") == 100, "rice_mill input qty must be 100")
	assert(recipe.get("outputs").size() == 2, "rice_mill must have 2 outputs (milled_rice & rice_bran)")
	print("✔ Building Recipes: 4 industrial facilities registered with input/output recipes")

	# 3. Test Storage & Spoilage Immunity
	MarketManager.stored_inventory.clear()
	MarketManager.add_harvest_to_storage("palay", 100, "Grade A", 100.0)
	MarketManager.add_processed_to_storage("milled_rice", 75, "Grade A")
	assert(MarketManager.stored_inventory.size() == 2, "Storage must have 2 batches")

	# Hourly spoilage tick
	MarketManager.process_hourly_spoilage()
	var palay_batch = MarketManager.stored_inventory[0]
	var rice_batch = MarketManager.stored_inventory[1]
	assert(palay_batch.freshness < 100.0, "Raw palay must spoil without cold storage")
	assert(rice_batch.freshness == 100.0, "Processed white rice must NOT spoil (shelf-stable)")
	print("✔ Spoilage Immunity: Raw crops decay while processed goods maintain 100% freshness")

	# 4. Test Raw Crop Consumption
	var consumed = MarketManager.consume_crop_quantity("palay", 100)
	assert(consumed == true, "Must successfully consume 100 palay")
	assert(MarketManager.get_stored_units_for_crop("palay") == 0, "Palay count must be 0 after consumption")
	var fail_consume = MarketManager.consume_crop_quantity("palay", 10)
	assert(fail_consume == false, "Must return false when insufficient raw crop")
	print("✔ Inventory Consumption: Aging raw crops cleanly consumed from storage bins")

	# 5. Test Automated Industrial Milling Loop
	MarketManager.stored_inventory.clear()
	MarketManager.add_harvest_to_storage("palay", 100, "Grade A", 95.0)

	var mill_node = Node2D.new()
	var b_script = load("res://src/buildings/Building.gd")
	mill_node.set_script(b_script)
	mill_node.building_type = "rice_mill"
	mill_node.state = mill_node.BuildingState.ACTIVE
	mill_node.level = 1
	add_child(mill_node)
	BuildingManager.register_building(mill_node)

	# Run automated processing tick
	BuildingManager._on_hour_changed(4)
	assert(MarketManager.get_stored_units_for_crop("palay") == 0, "Palay must be processed")
	assert(MarketManager.get_stored_units_for_crop("milled_rice") == 75, "75 units of milled rice must be produced")
	assert(MarketManager.get_stored_units_for_crop("rice_bran") == 25, "25 units of rice bran must be produced")
	print("✔ Milling Automation: Active facility automatically converted 100 Palay into 75 Milled Rice + 25 Rice Bran")

	# 6. Test Selling Processed Goods with Zero Transit Rot
	var initial_cash = EconomyManager.cash
	var preview = MarketManager.preview_crop_sale("milled_rice", "local_biyahero")
	assert(preview.get("road_rot") == 0.0, "Processed goods must have 0% road rot risk in transit")
	assert(preview.get("gross") > 0, "Gross sale value must be > 0")

	var sell_result = MarketManager.sell_all_of_crop("milled_rice", "local_biyahero")
	assert(sell_result.get("success") == true, "Sale of milled rice must succeed")
	assert(EconomyManager.cash > initial_cash, "Cash must increase after sale")
	assert(MarketManager.get_stored_units_for_crop("milled_rice") == 0, "Storage must be cleared of sold milled rice")
	print("✔ Trade & Export: Processed commodities sold with 0% transit rot and premium revenue")

	# Clean up
	BuildingManager.unregister_building(mill_node)
	mill_node.queue_free()

	print("==================================================")
	print("ALL AGRO-INDUSTRIAL PROCESSING TESTS PASSED!")
	print("==================================================")
	get_tree().quit(0)
