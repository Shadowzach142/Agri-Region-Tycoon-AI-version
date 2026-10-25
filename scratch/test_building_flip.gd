extends Node

func _ready() -> void:
	print("--- Starting Building Flip Verification ---")

	var buildings = [
		"bahay_kubo", "solar_dryer", "cold_storage", "drone_station",
		"weather_station", "water_tower", "bodega", "climate_silo",
		"bayanihan_center", "tacurong_mill", "koronadal_wholesale", "gensan_seaport",
		"rice_mill", "sugar_mill", "copra_dryer", "coffee_roastery"
	]

	# 1. Test get_placement_preview for all buildings
	print("[1/5] Testing get_placement_preview (normal and flipped)...")
	for b_id in buildings:
		var prev_norm: Dictionary = Building.get_placement_preview(b_id, false)
		assert(!prev_norm.is_empty(), "Preview normal should not be empty for " + b_id)
		assert(prev_norm.has("texture") and prev_norm["texture"] != null, "Preview normal texture missing for " + b_id)
		assert(prev_norm.has("scale") and float(prev_norm["scale"]) > 0.0, "Preview normal scale missing for " + b_id)
		assert(prev_norm.has("center_offset"), "Preview normal center_offset missing for " + b_id)

		var prev_flip: Dictionary = Building.get_placement_preview(b_id, true)
		assert(!prev_flip.is_empty(), "Preview flipped should not be empty for " + b_id)
		assert(prev_flip.has("texture") and prev_flip["texture"] != null, "Preview flipped texture missing for " + b_id)
		assert(prev_flip["texture"] != prev_norm["texture"], "Flipped texture should differ from normal texture for " + b_id)
		print("  ✔ %s: norm=%s, flip=%s" % [b_id, prev_norm["texture"].resource_path.get_file(), prev_flip["texture"].resource_path.get_file()])

	# 2. Test get_art_fit for processing & trade hub buildings
	print("[2/5] Testing get_art_fit for art buildings...")
	var art_buildings = [
		"bayanihan_center", "tacurong_mill", "koronadal_wholesale", "gensan_seaport",
		"rice_mill", "sugar_mill", "copra_dryer", "coffee_roastery"
	]
	for b_id in art_buildings:
		var fit_norm: Dictionary = Building.get_art_fit(b_id, false)
		var fit_flip: Dictionary = Building.get_art_fit(b_id, true)
		assert(!fit_norm.is_empty(), "Art fit normal missing for " + b_id)
		assert(!fit_flip.is_empty(), "Art fit flipped missing for " + b_id)
		assert(fit_norm["texture"] != fit_flip["texture"], "Flipped texture should differ for " + b_id)
		print("  ✔ Art fit %s: norm=%s, flip=%s" % [b_id, fit_norm["texture"].resource_path.get_file(), fit_flip["texture"].resource_path.get_file()])

	# 3. Test Building node instantiation and toggle_flip()
	print("[3/5] Testing Building node instantiation & toggle_flip()...")
	for b_id in ["bayanihan_center", "cold_storage", "bahay_kubo", "tacurong_mill", "water_tower"]:
		var b := Building.new()
		b.building_type = b_id
		b.grid_pos = Vector2i(2, 2)
		add_child(b)
		assert(b.is_flipped == false, "Default should be false")

		b.toggle_flip()
		assert(b.is_flipped == true, "Should now be flipped")
		if b.art_sprite != null:
			var fit_flip := Building.get_art_fit(b_id, true)
			assert(b.art_sprite.texture == fit_flip["texture"], "Art sprite should use flipped texture")

		b.set_flipped(false)
		assert(b.is_flipped == false, "Should be un-flipped")
		if b.art_sprite != null:
			var fit_norm := Building.get_art_fit(b_id, false)
			assert(b.art_sprite.texture == fit_norm["texture"], "Art sprite should use normal texture")

		b.queue_free()
		print("  ✔ Building node flip verified for %s" % b_id)

	# 4. Test Silo fill levels for both normal and flipped
	print("[4/5] Testing Silo fill textures normal and flipped...")
	var silo_b := Building.new()
	silo_b.building_type = "climate_silo"
	add_child(silo_b)
	for fill in [0, 25, 50, 75, 100]:
		silo_b.used_storage = fill
		silo_b.set_flipped(false)
		var t_norm := silo_b._get_silo_texture()
		assert(t_norm != null, "Silo texture normal should not be null")
		assert(not "_FLIPPED" in t_norm.resource_path, "Normal silo texture shouldn't have _FLIPPED")

		silo_b.set_flipped(true)
		var t_flip := silo_b._get_silo_texture()
		assert(t_flip != null, "Silo texture flipped should not be null")
		assert("_FLIPPED" in t_flip.resource_path, "Flipped silo texture should have _FLIPPED")
	silo_b.queue_free()
	print("  ✔ Silo textures verified for all levels.")

	# 5. Test SaveManager serialization contains is_flipped
	print("[5/5] Testing BuildingManager and SaveManager is_flipped serialization...")
	var b_test := Building.new()
	b_test.building_type = "tacurong_mill"
	b_test.grid_pos = Vector2i(5, 5)
	b_test.is_flipped = true
	BuildingManager.placed_buildings = [b_test]
	var data: Dictionary = SaveManager.capture_game_state("test_run")
	var bm_data: Dictionary = data.get("building_manager", {})
	var b_saved: Array = bm_data.get("buildings", [])
	assert(b_saved.size() == 1, "Should have 1 saved building")
	assert(b_saved[0].get("is_flipped", false) == true, "Saved building should have is_flipped=true")
	b_test.queue_free()
	BuildingManager.placed_buildings.clear()
	print("  ✔ SaveManager serialization of is_flipped verified.")

	print("--- ALL 5 FLIP TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
