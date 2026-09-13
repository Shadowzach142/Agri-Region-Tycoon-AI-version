# TaskManager.gd
# Manages a simple task queue for farmer workers.

extends Node

var task_queue: Array = []

## Add a new task dict.
## Expected format: {"type": String, "position": Vector2i, "crop_type": String (optional)}
func add_task(task: Dictionary) -> void:
	task_queue.append(task)

## Return the nearest pending task for a farmer at farmer_pos, or {} if none.
func get_next_task_for_farmer(farmer_pos: Vector2i) -> Dictionary:
	if task_queue.is_empty():
		return {}
	var best_index: int  = 0
	var best_dist:  float = INF
	for i in range(task_queue.size()):
		var t: Dictionary = task_queue[i]
		var tpos: Vector2i = t.get("position", Vector2i.ZERO)
		# Vector2i lacks distance_to, so cast to Vector2
		var dist: float = Vector2(farmer_pos).distance_to(Vector2(tpos))
		if dist < best_dist:
			best_dist  = dist
			best_index = i
	var task: Dictionary = task_queue[best_index]
	task_queue.remove_at(best_index)
	return task

func get_task_count() -> int:
	return task_queue.size()
