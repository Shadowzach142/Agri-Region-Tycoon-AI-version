extends Node

func _ready() -> void:
	print("========================================")
	print("Starting Storage Fill Bars & Routing Tests")
	print("========================================")

	# 1. Test HUD Storage Bar
	var hud_scene = load("res://scenes/MainGame.tscn")
	assert(hud_scene != null, "MainGame.tscn must load")
	var main_game = hud_scene.instantiate()
	add_child(main_game)

	var hud_layer = main_game.get_node_or_null("HUDLayer")
	assert(hud_layer != null, "HUDLayer must exist")
	var hud_script = hud_layer.get_script()
	assert(hud_script != null, "HUDLayer must have script")

	var storage_bar = hud_layer.find_child("StorageBar", true, false) as ProgressBar
	assert(storage_bar != null, "StorageBar must exist in HUD")
	assert(storage_bar.visible, "StorageBar must be visible in HUD")
	assert(storage_bar.custom_minimum_size.x >= 40, "StorageBar must have >= 40px width")
	print("✔ HUD: StorageBar is visible and sized in StorageCapsule")

	# 2. Test Building storage methods and overhead fill bar
	var silo = Building.new()
	silo.building_type = "bodega"
	silo.state = Building.BuildingState.ACTIVE
	silo.level = 1
	main_game.add_child(silo)
	silo._setup_ui()

	assert(silo.is_storage_building(), "Bodega must be identified as storage building")
	assert(silo.get_storage_capacity() == 200, "Bodega Lv.1 capacity must be 200")
	assert(silo.has_space(100), "Bodega must have space for 100")
	assert(silo.accepts_crop("palay"), "Bodega default accepts all crops")
	assert(silo.storage_fill_box != null, "Bodega must have overhead storage_fill_box")
	assert(silo.storage_fill_bar != null, "Bodega must have overhead storage_fill_bar")
	assert(silo.storage_fill_label != null, "Bodega must have overhead storage_fill_label")
	assert(silo.storage_fill_box.visible, "Bodega storage_fill_box must be visible when ACTIVE")

	silo.used_storage = 150
	silo.update_storage_display()
	assert(silo.storage_fill_bar.value == 150, "Fill bar value must equal used_storage")
	assert(silo.storage_fill_label.text.contains("150/200"), "Fill label must display 150/200")
	print("✔ Building: Overhead storage fill bar updates correctly on active storage facility")

	# 3. Test Cold Storage and Per-Facility Crop Filtering
	var cold_storage = Building.new()
	cold_storage.building_type = "cold_storage"
	cold_storage.state = Building.BuildingState.ACTIVE
	cold_storage.level = 1
	main_game.add_child(cold_storage)
	cold_storage._setup_ui()

	BuildingManager.placed_buildings.clear()
	silo.used_storage = 0
	cold_storage.used_storage = 0
	BuildingManager.register_building(silo)
	BuildingManager.register_building(cold_storage)

	# Configure routing: Silo = Grains, Cold Storage = Perishables
	silo.assigned_crops = ["palay", "yellow_corn", "sugarcane"]
	cold_storage.assigned_crops = ["arabica_coffee", "banana", "pineapple", "coconut"]

	assert(silo.accepts_crop("palay"), "Silo accepts palay")
	assert(not silo.accepts_crop("arabica_coffee"), "Silo rejects coffee")
	assert(cold_storage.accepts_crop("arabica_coffee"), "Cold storage accepts coffee")
	assert(not cold_storage.accepts_crop("palay"), "Cold storage rejects palay")

	var best_for_palay = BuildingManager.get_best_storage_for_crop("palay", 100)
	assert(best_for_palay == silo, "Best storage for palay must be Silo")

	var best_for_coffee = BuildingManager.get_best_storage_for_crop("arabica_coffee", 100)
	assert(best_for_coffee == cold_storage, "Best storage for coffee must be Cold Storage")

	assert(BuildingManager.has_storage_for_crop("palay", 100), "Has storage for palay")
	assert(BuildingManager.has_storage_for_crop("arabica_coffee", 100), "Has storage for coffee")

	print("✔ BuildingManager: Smart crop routing prioritizes assigned facilities for Grains vs Perishables")

	# 4. Test MarketManager deposit into specific facilities
	MarketManager.stored_inventory.clear()
	MarketManager.add_harvest_to_storage("palay", 100, "Grade A", 100.0)
	MarketManager.add_harvest_to_storage("arabica_coffee", 100, "Grade A", 100.0)

	var palay_batch = MarketManager.stored_inventory[0]
	var coffee_batch = MarketManager.stored_inventory[1]

	assert(palay_batch.facility_id == silo.get_instance_id(), "Palay must be routed to Silo facility ID")
	assert(not palay_batch.is_cold_storage, "Palay in basic Silo is not cold storage")
	assert(coffee_batch.facility_id == cold_storage.get_instance_id(), "Coffee must be routed to Cold Storage facility ID")
	assert(coffee_batch.is_cold_storage, "Coffee in Cold Storage has cold protection")

	print("✔ MarketManager: Crops deposited into appropriate facility IDs with respective cold storage flags")

	# 5. Test Full Storage rejection
	silo.used_storage = 200 # Fill Silo to cap
	assert(not silo.has_space(50), "Full Silo has no space")
	var best_palay_full = BuildingManager.get_best_storage_for_crop("palay", 50)
	assert(best_palay_full == null, "When Silo is full and Cold Storage rejects palay, no storage available")
	assert(not BuildingManager.has_storage_for_crop("palay", 50), "BuildingManager reports full for palay")
	assert(BuildingManager.has_storage_for_crop("arabica_coffee", 50), "Cold storage still has space for coffee")

	print("✔ Capacity Checks: Per-crop storage full checks correctly block unauthorized/overflow harvests")

	# 6. Test BuildingCardPopup interactive routing UI
	var popup_scene = load("res://scenes/BuildingCardPopup.tscn")
	assert(popup_scene != null, "BuildingCardPopup.tscn must load")
	var popup = popup_scene.instantiate()
	main_game.add_child(popup)

	popup.open_for_building(cold_storage)
	assert(popup.storage_section.visible, "StorageSection must be visible for storage building")
	assert(popup.fill_value_label.text.contains("units"), "FillValueLabel must show unit count")

	# Test preset buttons
	popup._on_preset_grains_pressed()
	assert(cold_storage.assigned_crops.has("palay"), "Preset grains sets palay")
	assert(not cold_storage.assigned_crops.has("arabica_coffee"), "Preset grains removes coffee")

	popup._on_preset_all_pressed()
	assert(cold_storage.assigned_crops.is_empty(), "Preset all clears filter so all are accepted")
	assert(cold_storage.accepts_crop("palay"), "Accepts all includes palay")
	assert(cold_storage.accepts_crop("arabica_coffee"), "Accepts all includes coffee")

	print("✔ BuildingCardPopup: Storage fill meter and interactive presets/toggles work seamlessly")

	print("========================================")
	print("ALL STORAGE FILL BAR & ROUTING TESTS PASSED 100%!")
	print("========================================")
	get_tree().quit(0)
