# FarmerStateMachine.gd
# Defines the Farmer worker state enum and helper methods for state labels.
# Extracted from Farmer.gd so the state logic has its own file.
#
# Usage (all static — no instance needed):
#   FarmerStateMachine.WorkerState.IDLE
#   FarmerStateMachine.work_label("plow")  -> "⛏️ Plowing..."

class_name FarmerStateMachine
extends RefCounted

# ---------------------------------------------------------------------------
# Worker states
# ---------------------------------------------------------------------------
enum WorkerState {
	IDLE,        # No task — wandering or waiting
	MOVING,      # Walking to task tile
	WORKING,     # Performing the action on the tile
	DEPOSITING,  # Walking harvested yield to the depot
}

# ---------------------------------------------------------------------------
# Status label helpers
# ---------------------------------------------------------------------------
static func idle_label() -> String:
	return "🧑‍🌾 Idle"

static func moving_label() -> String:
	return "🏃 Moving..."

static func depositing_label() -> String:
	return "📦 Depositing..."

static func wandering_label() -> String:
	return "🧑‍🌾 Wandering..."

static func ready_label() -> String:
	return "🧑‍🌾 Ready"

## Returns the correct working status string for a given task type
static func work_label(task_type: String) -> String:
	match task_type:
		"plow":       return "⛏️ Plowing..."
		"plant":      return "🌱 Planting..."
		"water":      return "💧 Watering..."
		"spray_pest": return "🧪 Spraying..."
		"harvest":        return "🧺 Harvesting..."
		"clear_obstacle": return "🪓 Chopping Tree..."
		_:            return "⚙️ Working..."
