extends Node2D

func _ready() -> void:
	print("--- BEGIN TEST: Farm Diagnostic Heatmap & Field Survey Kit Tech Gate ---")

	# Ensure clean tech state
	if "field_survey_kit" in BuildingManager.unlocked_techs:
		BuildingManager.unlocked_techs.erase("field_survey_kit")

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

	# 2. Check HeatmapButton in CommandCorner when locked
	var heatmap_btn = hud.find_child("HeatmapButton", true, false) as Button
	assert(heatmap_btn != null, "HeatmapButton must exist in CommandCorner")
	assert(not BuildingManager.has_heatmap(), "Field survey kit should start locked")
	assert(heatmap_btn.tooltip_text.contains("Locked"), "Tooltip should show locked state")

	# Verify toggle is blocked when locked
	var f_event := InputEventKey.new()
	f_event.keycode = KEY_F
	f_event.pressed = true
	hud._unhandled_input(f_event)

	var overlay: FarmHeatmapOverlay = farm_grid.get_heatmap_overlay()
	assert(not overlay.is_active, "Heatmap must not activate when locked")
	print("✔ Check 1 Passed: Diagnostic Heatmap is properly locked before purchasing Field Survey Kit.")

	# 3. Buy Field Survey Kit tech
	EconomyManager.cash = 10000
	var tech_bought: bool = BuildingManager.buy_tech("field_survey_kit")
	assert(tech_bought, "buy_tech should succeed with ₱10000 cash")
	assert(BuildingManager.has_heatmap(), "Field survey kit must be unlocked after buy_tech")
	hud._update_heatmap_btn_state()
	assert(heatmap_btn.tooltip_text.contains("Hotkey F"), "Tooltip should reflect unlocked hotkey F")
	print("✔ Check 2 Passed: Field Survey Kit purchased and unlocks radar HUD button.")

	# 4. Check FarmHeatmapOverlay in FarmGrid
	assert(overlay != null, "FarmHeatmapOverlay must be instantiated in FarmGrid")
	assert(overlay.z_index == 195, "FarmHeatmapOverlay must have z_index 195")
	assert(not overlay.is_active, "FarmHeatmapOverlay starts inactive")

	# 5. Check HeatmapLegendBar
	var legend_bar = hud.find_child("HeatmapLegendBar", true, false) as HeatmapLegendBar
	assert(legend_bar != null, "HeatmapLegendBar must exist in HUDLayer")
	assert(not legend_bar.visible, "HeatmapLegendBar starts invisible")

	# 6. Test Toggling Overlay ON via hotkey F
	hud._unhandled_input(f_event)
	assert(overlay.is_active, "Overlay must be active after F toggle")
	assert(legend_bar.visible, "HeatmapLegendBar must be visible when overlay is active")
	print("✔ Check 3 Passed: Hotkey F toggles overlay and legend bar ON once unlocked.")

	# 7. Test All 4 Diagnostic Modes
	overlay.set_mode(FarmHeatmapOverlay.HeatmapMode.MOISTURE)
	assert(overlay.current_mode == FarmHeatmapOverlay.HeatmapMode.MOISTURE, "Mode must switch to MOISTURE")
	assert(overlay.get_mode_name() == "Soil Moisture", "Mode name must be Soil Moisture")

	overlay.set_mode(FarmHeatmapOverlay.HeatmapMode.HEALTH)
	assert(overlay.current_mode == FarmHeatmapOverlay.HeatmapMode.HEALTH, "Mode must switch to HEALTH")
	assert(overlay.get_mode_name() == "Crop Health & Ripe Yield", "Mode name must be Crop Health")

	overlay.set_mode(FarmHeatmapOverlay.HeatmapMode.IRRIGATION)
	assert(overlay.current_mode == FarmHeatmapOverlay.HeatmapMode.IRRIGATION, "Mode must switch to IRRIGATION")
	assert(overlay.get_mode_name() == "Sprinkler Coverage Network", "Mode name must be Sprinkler Coverage Network")

	overlay.set_mode(FarmHeatmapOverlay.HeatmapMode.UNIFIED)
	assert(overlay.current_mode == FarmHeatmapOverlay.HeatmapMode.UNIFIED, "Mode must switch back to UNIFIED")
	print("✔ Check 4 Passed: All 4 diagnostic modes (Unified, Moisture, Health, Irrigation) switch cleanly.")

	# 8. Test Diagnostic Telemetry Dictionary
	var test_pos := Vector2i(2, 2)
	var tile: FarmTile = farm_grid.tiles[test_pos.x][test_pos.y]
	tile.soil_moisture = 22.0
	var diag: Dictionary = overlay.get_tile_diagnostic_info(test_pos)
	assert(diag.get("pos") == test_pos, "Diag pos must match")
	assert(diag.get("moisture") == 22.0, "Diag moisture must match")
	assert(diag.get("status").contains("Parched"), "Status should indicate parched for moisture < 35%")
	print("✔ Check 5 Passed: get_tile_diagnostic_info() accurately computes agronomic telemetry.")

	# 9. Test Hotkey F toggle OFF
	hud._unhandled_input(f_event)
	assert(not overlay.is_active, "Hotkey F should toggle overlay off")
	assert(not legend_bar.visible, "Hotkey F should toggle legend bar off")

	# Toggle back ON
	hud._unhandled_input(f_event)
	assert(overlay.is_active, "Hotkey F should toggle overlay back on")

	# 10. Test ESC closing modal
	var esc_event := InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_event.pressed = true
	hud._unhandled_input(esc_event)
	assert(not overlay.is_active, "ESC should close heatmap overlay")
	assert(not legend_bar.visible, "ESC should close heatmap legend bar")
	print("✔ Check 6 Passed: ESC key closes heatmap overlay cleanly.")

	print("\n🎉 ALL DIAGNOSTIC HEATMAP & TECH GATE CHECKS PASSED PERFECTLY! 🎉")
	get_tree().quit(0)
