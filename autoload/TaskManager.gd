# TaskManager.gd
# Manages task queues and worker assignments.
# Supports selecting individual farmers, multi-selecting with Ctrl+click,
# and distributing assigned tasks across selected workers for faster execution.

extends Node

signal selection_changed(selected_workers: Array)
signal tasks_assigned(worker_count: int, task_count: int)

var task_queue: Array = []
var selected_farmers: Array = []

## Add a new task dict to the global unassigned queue.
## Expected format: {"type": String, "position": Vector2i, "crop_type": String (optional)}
func add_task(task: Dictionary) -> void:
	task_queue.append(task)

## Return true if a task with the given position and optional type already exists in queue
func has_task_at(pos: Vector2i, type: String = "") -> bool:
	for t in task_queue:
		if t.get("position", Vector2i(-1, -1)) == pos:
			if type == "" or t.get("type", "") == type:
				return true
	# Also check personal queues of all workers
	var all_farmers := get_tree().get_nodes_in_group("farmers")
	for f in all_farmers:
		if not is_instance_valid(f):
			continue
		if f.has_task_at(pos, type):
			return true
	return false

## Return the nearest pending task from the global unassigned queue.
func get_next_task_for_farmer(farmer_pos: Vector2i) -> Dictionary:
	if task_queue.is_empty():
		return {}
	var best_index: int  = 0
	var best_dist:  float = INF
	for i in range(task_queue.size()):
		var t: Dictionary = task_queue[i]
		var tpos: Vector2i = t.get("position", Vector2i.ZERO)
		var dist: float = Vector2(farmer_pos).distance_to(Vector2(tpos))
		if dist < best_dist:
			best_dist  = dist
			best_index = i
	var task: Dictionary = task_queue[best_index]
	task_queue.remove_at(best_index)
	return task

func get_task_count() -> int:
	var count: int = task_queue.size()
	var all_farmers := get_tree().get_nodes_in_group("farmers")
	for f in all_farmers:
		if is_instance_valid(f):
			count += f.assigned_tasks.size()
			if not f.current_task.is_empty():
				count += 1
	return count

# ---------------------------------------------------------------------------
# Worker Selection (Single Click & Ctrl+Click Multi-select)
# ---------------------------------------------------------------------------
func select_farmer(farmer: Node, is_multi: bool) -> void:
	if not is_instance_valid(farmer):
		return

	if not is_multi:
		# Single selection: deselect all others and select this one
		for f in selected_farmers:
			if is_instance_valid(f) and f != farmer:
				f.is_selected = false
		selected_farmers.clear()
		farmer.is_selected = true
		selected_farmers.append(farmer)
	else:
		# Multi-selection (Ctrl+click): toggle this farmer's selection
		if farmer in selected_farmers:
			farmer.is_selected = false
			selected_farmers.erase(farmer)
		else:
			farmer.is_selected = true
			selected_farmers.append(farmer)

	_cleanup_selected_farmers()
	selection_changed.emit(selected_farmers)

func deselect_all_farmers() -> void:
	for f in selected_farmers:
		if is_instance_valid(f):
			f.is_selected = false
	selected_farmers.clear()
	selection_changed.emit(selected_farmers)

func get_selected_farmers() -> Array:
	_cleanup_selected_farmers()
	return selected_farmers

func _cleanup_selected_farmers() -> void:
	selected_farmers = selected_farmers.filter(func(f): return is_instance_valid(f))

# ---------------------------------------------------------------------------
# Task Assignment & Distribution
# ---------------------------------------------------------------------------
## Assigns a list of tasks. If farmers are selected, distributes tasks among them.
## Otherwise, tasks go to the global unassigned queue.
func assign_tasks(tasks: Array) -> void:
	if tasks.is_empty():
		return

	var workers := get_selected_farmers()
	if not workers.is_empty():
		if tasks.size() == 1 and workers.size() > 1:
			# Single task with multiple workers selected:
			# Assign to the worker closest to the target tile / with least workload
			var target_pos: Vector2i = tasks[0].get("position", Vector2i.ZERO)
			var best_worker = workers[0]
			var best_score: float = INF
			for w in workers:
				var queue_len: int = w.assigned_tasks.size()
				var w_pos: Vector2 = w.global_position
				var dist: float = w_pos.distance_to(Vector2(target_pos) * 64.0)
				var score: float = (queue_len * 500.0) + dist
				if score < best_score:
					best_score = score
					best_worker = w
			best_worker.assign_task(tasks[0])
		else:
			# Multiple tasks: round-robin distribute across selected workers
			# so they execute the tasks in parallel for a quicker completion
			for i in range(tasks.size()):
				var w = workers[i % workers.size()]
				w.assign_task(tasks[i])
		tasks_assigned.emit(workers.size(), tasks.size())
	else:
		# No specific workers selected: push to global pool
		for t in tasks:
			add_task(t)
		tasks_assigned.emit(0, tasks.size())
