extends Node

func _ready() -> void:
	print("--- Running Building Calibration Verification ---")
	
	var buildings_to_test = ["cold_storage", "weather_station", "drone_station", "water_tower"]
	
	for b_type in buildings_to_test:
		var b_data = Data.get_building(b_type)
		assert(not b_data.is_empty(), "Building data should exist for %s" % b_type)
		print("\nChecking building: %s" % b_type)
		print("  Display name: %s" % b_data.get("display_name", ""))
		print("  Grid size: %s" % str(b_data.get("grid_size")))
		
		var b = Building.new()
		b.building_type = b_type
		add_child(b)
		
		# Verify footprint
		var expected_fp = b_data.get("grid_size")
		assert(b.footprint == expected_fp, "Footprint mismatch for %s: got %s, expected %s" % [b_type, b.footprint, expected_fp])
		print("  [PASS] Footprint matches Data.BUILDINGS (%s)" % str(b.footprint))
		
		# Verify UI nodes created
		assert(b.level_label != null, "Level label should be created")
		assert(b.progress_bar != null, "Progress bar should be created")
		print("  [PASS] UI nodes verified. Level label pos: %s" % str(b.level_label.position))
		
		# Test drawing
		b.queue_redraw()
		b.state = Building.BuildingState.ACTIVE
		b.queue_redraw()
		b.state = Building.BuildingState.CONSTRUCTING
		b.queue_redraw()
		
		b.queue_free()
	
	print("\n--- All 4 Buildings Calibrated and Verified Successfully! ---")
	get_tree().quit(0)
