extends SceneTree

func _init() -> void:
	print("=== Running Farmer Action Cancellation Unit & Integration Tests ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var passed := 0
	var failed := 0

	# -------------------------------------------------------------
	# Test 1: Verify Cancel Icon exists and is loaded
	# -------------------------------------------------------------
	var cancel_tex = PlantHotbar.get_tool_sprite_texture("cancel_task")
	if cancel_tex != null:
		print("PASS: cancel_task tool icon exists and loads correctly (%dx%d)" % [cancel_tex.get_width(), cancel_tex.get_height()])
		passed += 1
	else:
		printerr("FAIL: cancel_task tool icon failed to load!")
		failed += 1

	# -------------------------------------------------------------
	# Test 2: Verify PlantHotbar tools category contains cancel_task
	# -------------------------------------------------------------
	var tools_items: Array = PlantHotbar.CATEGORY_DATA["tools"]["items"]
	var found_cancel := false
	for it in tools_items:
		if it["id"] == "cancel_task":
			found_cancel = true
			break
	if found_cancel:
		print("PASS: cancel_task item registered in PlantHotbar tools items")
		passed += 1
	else:
		printerr("FAIL: cancel_task not found in PlantHotbar tools items!")
		failed += 1

	# -------------------------------------------------------------
	# Test 3: TaskManager cancel_task_at with unassigned task
	# -------------------------------------------------------------
	TaskManager.task_queue.clear()
	var test_pos := Vector2i(5, 5)
	TaskManager.add_task({"type": "plow", "position": test_pos})
	if TaskManager.has_task_at(test_pos):
		var count = TaskManager.cancel_task_at(test_pos)
		if count == 1 and not TaskManager.has_task_at(test_pos):
			print("PASS: TaskManager successfully cancelled unassigned task at %s" % str(test_pos))
			passed += 1
		else:
			printerr("FAIL: TaskManager failed to cancel task at %s (count=%d)" % [str(test_pos), count])
			failed += 1
	else:
		printerr("FAIL: Task failed to queue initially!")
		failed += 1

	# -------------------------------------------------------------
	# Test 4: Prepaid refund logic on task cancellation
	# -------------------------------------------------------------
	var initial_cash = EconomyManager.cash
	var obstacle_pos := Vector2i(8, 8)
	# Queue a prepaid task like clear_obstacle with cost 50
	TaskManager.add_task({"type": "clear_obstacle", "position": obstacle_pos, "cost": 50})
	var cancelled_obstacle = TaskManager.cancel_task_at(obstacle_pos)
	if cancelled_obstacle == 1 and EconomyManager.cash == initial_cash + 50:
		print("PASS: Prepaid obstacle clear (50 cash) successfully refunded on cancellation")
		passed += 1
	else:
		printerr("FAIL: Obstacle clear refund failed! Cash: %d vs Expected: %d" % [EconomyManager.cash, initial_cash + 50])
		failed += 1
	# Revert cash
	EconomyManager.cash = initial_cash

	# -------------------------------------------------------------
	# Test 5: Worker task cancellation & transition to IDLE
	# -------------------------------------------------------------
	var farmer_script = load("res://src/farmer/Farmer.gd")
	var farmer = CharacterBody2D.new()
	farmer.set_script(farmer_script)
	root.add_child(farmer)
	farmer.add_to_group("farmers")

	farmer.current_task = {"type": "plow", "position": Vector2i(3, 4)}
	farmer.target_grid_pos = Vector2i(3, 4)
	farmer.state = 2 # WORK
	farmer.assigned_tasks.append({"type": "water", "position": Vector2i(3, 5)})

	if farmer.has_task_at(Vector2i(3, 4)):
		print("PASS: Farmer has active task at (3, 4)")
		passed += 1
	else:
		printerr("FAIL: Farmer reports no task at (3, 4)")
		failed += 1

	# Test cancel_task_at targeted at worker's current active task
	var w_cancelled = TaskManager.cancel_task_at(Vector2i(3, 4))
	if w_cancelled == 1 and farmer.state == 0 and farmer.current_task.is_empty():
		print("PASS: Active worker task cancelled successfully; worker reset to IDLE")
		passed += 1
	else:
		printerr("FAIL: Active worker task cancellation failed (count=%d, state=%d)" % [w_cancelled, farmer.state])
		failed += 1

	# Test cancel_active_or_selected_tasks with farmer selected
	farmer.current_task = {"type": "harvest", "position": Vector2i(6, 6)}
	farmer.target_grid_pos = Vector2i(6, 6)
	farmer.state = 2 # WORK
	TaskManager.select_farmer(farmer)
	var halted = TaskManager.cancel_active_or_selected_tasks()
	if halted >= 1 and farmer.state == 0 and farmer.current_task.is_empty():
		print("PASS: Selected worker halted via cancel_active_or_selected_tasks()")
		passed += 1
	else:
		printerr("FAIL: cancel_active_or_selected_tasks failed to halt worker (halted=%d, state=%d)" % [halted, farmer.state])
		failed += 1

	farmer.queue_free()
	TaskManager.deselect_all_farmers()
	TaskManager.task_queue.clear()

	# -------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------
	print("\n=======================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("=======================================================")
	if failed == 0:
		print("ALL FARMER ACTION CANCELLATION TESTS PASSED!")
		quit(0)
	else:
		printerr("SOME TESTS FAILED!")
		quit(1)
