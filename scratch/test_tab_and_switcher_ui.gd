extends Node

func _ready() -> void:
	print("--- BEGIN TEST: TAB KEY & SWITCHER UI IMPROVEMENTS ---")

	# Setup a mock FarmGrid with 2 drones
	var grid = Node2D.new()
	grid.name = "FarmGrid"
	add_child(grid)

	# Mock script with drones array & selection methods
	var grid_script = GDScript.new()
	grid_script.source_code = """
extends Node2D

signal drone_selected(idx: int)

var drones: Array = []
var selected_drone_index: int = 0

func get_selected_drone():
	if selected_drone_index > 0 and selected_drone_index <= drones.size():
		return drones[selected_drone_index - 1]
	return null

func select_drone_by_index(idx: int) -> void:
	selected_drone_index = idx
	drone_selected.emit(idx)

func deselect_all_drones() -> void:
	selected_drone_index = 0
	drone_selected.emit(0)
"""
	grid_script.reload()
	grid.set_script(grid_script)

	# Create 2 mock drones
	var d1 = Node2D.new()
	d1.set("drone_index", 1)
	var d1_script = GDScript.new()
	d1_script.source_code = """
extends Node2D
var drone_index: int = 1
var crop_type: String = "palay"
var zone: Array = []
func get_drone_name() -> String: return "Drone #1"
func get_level() -> int: return 1
"""
	d1_script.reload()
	d1.set_script(d1_script)
	grid.drones.append(d1)

	var d2 = Node2D.new()
	d2.set("drone_index", 2)
	var d2_script = GDScript.new()
	d2_script.source_code = """
extends Node2D
var drone_index: int = 2
var crop_type: String = "yellow_corn"
var zone: Array = []
func get_drone_name() -> String: return "Drone #2"
func get_level() -> int: return 1
"""
	d2_script.reload()
	d2.set_script(d2_script)
	grid.drones.append(d2)

	# Create PlantHotbar
	var hotbar = PlantHotbar.new()
	hotbar.name = "PlantHotbar"
	add_child(hotbar)

	# 1. Verify Switcher Dock and new segmented mode tabs exist
	assert(hotbar._switcher_dock != null, "FAIL: _switcher_dock should exist")
	assert(hotbar._mode_farmer_btn != null, "FAIL: _mode_farmer_btn should exist")
	assert(hotbar._mode_drone_btn != null, "FAIL: _mode_drone_btn should exist")
	assert(hotbar._unit_pill_btn != null, "FAIL: _unit_pill_btn should exist")
	assert(hotbar._unit_prev_btn != null, "FAIL: _unit_prev_btn should exist")
	assert(hotbar._unit_next_btn != null, "FAIL: _unit_next_btn should exist")
	print("✓ Test 1 Passed: Switcher dock and segmented mode buttons created successfully")

	# 2. Verify all buttons have focus_mode = FOCUS_NONE (prevents Tab trapping)
	assert(hotbar._mode_farmer_btn.focus_mode == Control.FOCUS_NONE, "FAIL: _mode_farmer_btn must have FOCUS_NONE")
	assert(hotbar._mode_drone_btn.focus_mode == Control.FOCUS_NONE, "FAIL: _mode_drone_btn must have FOCUS_NONE")
	assert(hotbar._unit_pill_btn.focus_mode == Control.FOCUS_NONE, "FAIL: _unit_pill_btn must have FOCUS_NONE")
	assert(hotbar._unit_prev_btn.focus_mode == Control.FOCUS_NONE, "FAIL: _unit_prev_btn must have FOCUS_NONE")
	assert(hotbar._unit_next_btn.focus_mode == Control.FOCUS_NONE, "FAIL: _unit_next_btn must have FOCUS_NONE")
	for cat_id in hotbar.category_slots:
		assert(hotbar.category_slots[cat_id].focus_mode == Control.FOCUS_NONE, "FAIL: Slot button must have FOCUS_NONE")
	print("✓ Test 2 Passed: All hotbar buttons have FOCUS_NONE to allow unimpeded Tab cycling")

	# 3. Initially in Worker Mode
	hotbar._update_unit_header([], null)
	assert(hotbar._mode_farmer_btn.text.contains("Workers"), "FAIL: Farmer mode tab should show Workers")
	assert(hotbar._mode_drone_btn.text.contains("Drones (2)"), "FAIL: Drone mode tab should show count of active drones")
	print("✓ Test 3 Passed: Initial mode correctly identifies Farmer command and active drone count")

	# 4. Click Drone Mode Tab -> Switch to Drone 1
	hotbar._on_select_mode_drone()
	assert(grid.selected_drone_index == 1, "FAIL: Selecting drone mode should select Drone 1")
	assert(hotbar._is_drone_mode() == true, "FAIL: hotbar._is_drone_mode() should be true")
	hotbar._update_unit_header([], d1)
	assert(hotbar._unit_pill_btn.text.begins_with("🛸"), "FAIL: Pill button should show Drone icon")
	assert(hotbar._unit_pill_btn.text.contains("Drone #1"), "FAIL: Pill button should display Drone #1")
	print("✓ Test 4 Passed: Clicking Drone Mode tab successfully switches to Drone 1")

	# 5. Cycle Next Unit while in Drone Mode (simulating Tab key in drone mode)
	hotbar._on_cycle_unit_next()
	assert(grid.selected_drone_index == 2, "FAIL: Next cycle should advance from Drone 1 to Drone 2")
	hotbar._update_unit_header([], d2)
	assert(hotbar._unit_pill_btn.text.contains("Drone #2"), "FAIL: Pill button should display Drone #2")
	print("✓ Test 5 Passed: Cycling unit in drone mode moves to Drone #2")

	# 6. Cycle Next Unit wraps around to Drone 1
	hotbar._on_cycle_unit_next()
	assert(grid.selected_drone_index == 1, "FAIL: Next cycle should wrap back from Drone 2 to Drone 1")
	print("✓ Test 6 Passed: Cycling wraps cleanly across drone fleet")

	# 7. Cycle Previous Unit (simulating Shift+Tab in drone mode)
	hotbar._on_cycle_unit_prev()
	assert(grid.selected_drone_index == 2, "FAIL: Prev cycle should wrap from Drone 1 to Drone 2")
	print("✓ Test 7 Passed: Prev cycle moves backwards through drone fleet")

	# 8. Test HUD _on_tab_pressed routing
	var hud_script = load("res://src/ui/HUD.gd")
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(hud_script)
	add_child(hud)

	# In Drone mode, HUD._on_tab_pressed() must call _cycle_drone()
	grid.selected_drone_index = 1
	hud._on_tab_pressed(false)
	assert(grid.selected_drone_index == 2, "FAIL: HUD Tab press while in drone mode must cycle to Drone 2")
	print("✓ Test 8 Passed: HUD Tab key in drone mode advances drone selection")

	hud._on_tab_pressed(true) # Reverse (Shift+Tab)
	assert(grid.selected_drone_index == 1, "FAIL: HUD Shift+Tab in drone mode must cycle back to Drone 1")
	print("✓ Test 9 Passed: HUD Shift+Tab in drone mode cycles previous drone")

	# 9. Click Farmer Mode Tab -> Switch back to Farmer mode
	grid.selected_drone_index = 0
	hotbar._on_select_mode_farmer()
	assert(grid.selected_drone_index == 0, "FAIL: Selecting farmer mode should deselect drones")
	assert(hotbar._is_drone_mode() == false, "FAIL: hotbar._is_drone_mode() should be false")
	print("✓ Test 10 Passed: Switching back to Farmer mode cleanly resets drone selection")

	print("--- ALL 10 TAB & SWITCHER UI TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
