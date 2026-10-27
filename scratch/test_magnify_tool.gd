extends Node

func _ready() -> void:
	print("--- BEGIN TEST: Magnify Icon & Investigate Tool ---")
	var passed := 0
	var total := 0

	# 1. Texture exists and is valid
	total += 1
	var tex = load("res://assets/icons/Tools/Magnify.png")
	if tex != null and tex is Texture2D and tex.get_width() == 32 and tex.get_height() == 32:
		print("✅ PASS: assets/icons/Tools/Magnify.png loaded cleanly (32x32).")
		passed += 1
	else:
		print("❌ FAIL: Magnify.png could not be loaded or wrong dimensions: %s" % tex)

	# 2. PlantHotbar constants and data
	total += 1
	var PlantHotbarScript = load("res://src/ui/PlantHotbar.gd")
	var hotbar_inst = Control.new()
	hotbar_inst.set_script(PlantHotbarScript)
	add_child(hotbar_inst)

	var tool_icons: Dictionary = hotbar_inst.TOOL_ICONS
	var has_inspect_icon: bool = tool_icons.has("inspect") and tool_icons["inspect"] == "res://assets/icons/Tools/Magnify.png"

	var cat_data: Dictionary = hotbar_inst.CATEGORY_DATA
	var tools_items: Array = cat_data.get("tools", {}).get("items", [])
	var first_tool_is_inspect: bool = (not tools_items.is_empty() and tools_items[0].get("id") == "inspect")

	if has_inspect_icon and first_tool_is_inspect:
		print("✅ PASS: PlantHotbar TOOL_ICONS and CATEGORY_DATA correctly configure 'inspect'.")
		passed += 1
	else:
		print("❌ FAIL: PlantHotbar inspect configuration mismatch: has_icon=%s, first_tool=%s" % [has_inspect_icon, first_tool_is_inspect])

	# 3. Test selecting the inspect tool in PlantHotbar
	total += 1
	hotbar_inst.select_tool("inspect")
	if hotbar_inst.get_selected_tool() == "inspect":
		print("✅ PASS: hotbar_inst.select_tool('inspect') succeeded.")
		passed += 1
	else:
		print("❌ FAIL: hotbar_inst selected tool is '%s', expected 'inspect'" % hotbar_inst.get_selected_tool())

	# 4. FarmGrid tool footprint and target validity
	total += 1
	var FarmGridScript = load("res://src/core/FarmGrid.gd")
	var grid_inst = Node2D.new()
	grid_inst.set_script(FarmGridScript)
	add_child(grid_inst)

	var fp: Vector2i = grid_inst.get_tool_footprint("inspect")
	if fp == Vector2i(1, 1):
		print("✅ PASS: FarmGrid.get_tool_footprint('inspect') == Vector2i(1, 1).")
		passed += 1
	else:
		print("❌ FAIL: FarmGrid footprint for inspect was %s" % fp)

	# 5. Non-destructive investigation check: auto-apply hotbar action
	total += 1
	var initial_tasks_count: int = TaskManager.get_task_count()
	grid_inst._auto_apply_hotbar_action([Vector2i(2, 2)], "inspect")
	var post_tasks_count: int = TaskManager.get_task_count()
	if initial_tasks_count == post_tasks_count:
		print("✅ PASS: _auto_apply_hotbar_action does not create any tasks when using 'inspect'.")
		passed += 1
	else:
		print("❌ FAIL: Tasks were queued during inspect: initial=%d, post=%d" % [initial_tasks_count, post_tasks_count])

	print("--- TEST SUMMARY: %d/%d PASSED ---" % [passed, total])
	if passed == total:
		print("ALL CHECKS SUCCESSFUL!")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
