extends Node2D

func _ready() -> void:
	# Set background color to farm grass green
	RenderingServer.set_default_clear_color(Color(0.22, 0.38, 0.18, 1.0))

	# Setup FarmGrid mock
	var farm_grid = Node2D.new()
	farm_grid.name = "FarmGrid"
	add_child(farm_grid)

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
"""
	grid_script.reload()
	farm_grid.set_script(grid_script)

	# Mock drone
	var d1 = Node2D.new()
	var d1_script = GDScript.new()
	d1_script.source_code = """
extends Node2D
var drone_index: int = 1
var crop_type: String = "palay"
var zone: Array = [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 3)]
var cur_lvl: int = 1
func get_drone_name() -> String: return "Drone #1"
func get_level() -> int: return cur_lvl
"""
	d1_script.reload()
	d1.set_script(d1_script)
	farm_grid.drones.append(d1)

	# Create PlantHotbar inside a centered container
	var layer = CanvasLayer.new()
	add_child(layer)

	var hotbar = PlantHotbar.new()
	hotbar.name = "PlantHotbar"
	layer.add_child(hotbar)
	hotbar.position = Vector2(460, 460)

	# Give Godot 2 frames to layout
	await get_tree().process_frame
	await get_tree().process_frame

	# SCENE 1: Worker Mode (Wood theme)
	hotbar.visible = true
	hotbar._update_unit_header([], null)
	hotbar._update_category_slots_display()
	hotbar._highlight_active_selection()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_screenshot("c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/shot_1_worker_wood_hotbar.png")

	# SCENE 2: Drone Mode Lv. 1 (Silver metallic theme, Seeds locked with 🔒)
	farm_grid.selected_drone_index = 1
	d1.set("cur_lvl", 1)
	hotbar._update_unit_header([], d1)
	hotbar._update_category_slots_display()
	hotbar._highlight_active_selection()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_screenshot("c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/shot_2_drone_lv1_silver_hotbar.png")

	# SCENE 3: Drone Mode Lv. 1 Flyout for Directives (Showing lock badges on locked tools)
	hotbar._open_flyout_for_category("tools")
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_screenshot("c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/shot_3_drone_lv1_flyout_locks.png")

	# SCENE 4: Drone Mode Lv. 2 (Hangar upgraded, Seeds unlocked in silver hotbar)
	d1.set("cur_lvl", 2)
	hotbar._close_flyout()
	hotbar._update_unit_header([], d1)
	hotbar._update_category_slots_display()
	hotbar._highlight_active_selection()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_screenshot("c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/shot_4_drone_lv2_silver_hotbar.png")

	print("[DONE] Captured all 4 screenshots successfully!")
	get_tree().quit(0)

func _capture_screenshot(file_path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(file_path)
		print("Saved screenshot: ", file_path)
