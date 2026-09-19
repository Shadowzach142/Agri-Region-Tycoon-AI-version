# PestManager.gd
# Manages pest infestations, spawn triggers, and spread mechanics.

extends Node

signal pest_spawned(pest_type: String, position: Vector2i)
signal pest_cleared(pest_type: String, position: Vector2i)

## key: "x_y" -> {"pest": String, "days": int}
var infected_tiles: Dictionary = {}

func _ready() -> void:
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.day_changed.connect(_on_day_changed)

func _on_day_changed(_day: int) -> void:
	# Full moon occurs every 7th day (Days 7, 14, 21, 28) - attracts Rice Black Bugs
	if _day % 7 == 0:
		_trigger_full_moon_black_bugs()

func _on_hour_changed(hour: int) -> void:
	# Spec: Spread check to adjacent tiles every 6 hours (00:00, 06:00, 12:00, 18:00)
	if hour % 6 == 0:
		_advance_spread()

func _trigger_full_moon_black_bugs() -> void:
	for key in infected_tiles.keys():
		pass # Existing infections

## Called by FarmGrid after a tile is planted or daily to evaluate spawn conditions.
func evaluate_spawn(tile_pos: Vector2i, crop_type: String, soil_moisture: int) -> void:
	var crop_data: Dictionary = Data.get_crop(crop_type)
	if crop_data.is_empty():
		return

	for pest_name in crop_data.get("pests", []):
		var pest_data: Dictionary = Data.get_pest(pest_name)
		var trigger: Dictionary = pest_data.get("spawn_trigger", {})
		var should_spawn: bool = false

		if trigger.has("soil_moisture_below"):
			if soil_moisture < int(trigger["soil_moisture_below"]):
				should_spawn = true
		if trigger.has("soil_moisture_above"):
			if soil_moisture > int(trigger["soil_moisture_above"]):
				should_spawn = true
		if trigger.has("heat_index_above"):
			if WeatherManager.temperature > float(trigger["heat_index_above"]):
				should_spawn = true
		if trigger.has("full_moon") and (TimeManager.current_day % 7 == 0):
			should_spawn = true

		if should_spawn and randf() < 0.35:
			var key: String = "%d_%d" % [tile_pos.x, tile_pos.y]
			if not infected_tiles.has(key):
				infected_tiles[key] = {"pest": pest_name, "days": 0, "crop": crop_type}
				pest_spawned.emit(pest_name, tile_pos)

func _advance_spread() -> void:
	var new_infections: Array = []
	for key: String in infected_tiles.keys():
		var info: Dictionary = infected_tiles[key]
		info["days"] += 1
		var pest_name: String = info["pest"]
		var pest_data: Dictionary = Data.get_pest(pest_name)
		var spread_rate: float = pest_data.get("spread_rate", 0.15)
		
		# Spec: Monoculture increases spread speed by 50%
		var monoculture_mult: float = 1.50
		var effective_spread: float = spread_rate * monoculture_mult

		var parts: PackedStringArray = key.split("_")
		var x: int = int(parts[0])
		var y: int = int(parts[1])
		var neighbours: Array = [
			Vector2i(x + 1, y), Vector2i(x - 1, y),
			Vector2i(x, y + 1), Vector2i(x, y - 1),
		]
		for n: Vector2i in neighbours:
			if n.x >= 0 and n.x < 12 and n.y >= 0 and n.y < 12:
				if randf() < effective_spread:
					var nkey: String = "%d_%d" % [n.x, n.y]
					if not infected_tiles.has(nkey):
						new_infections.append({"pos": n, "pest": pest_name})
	for inf: Dictionary in new_infections:
		var nkey: String = "%d_%d" % [inf.pos.x, inf.pos.y]
		infected_tiles[nkey] = {"pest": inf.pest, "days": 0}
		pest_spawned.emit(inf.pest, inf.pos)

## Called by FarmGrid when a player/farmer applies treatment.
func treat_tile(tile_pos: Vector2i, _method: String) -> void:
	var key: String = "%d_%d" % [tile_pos.x, tile_pos.y]
	if infected_tiles.has(key):
		var pest_name: String = infected_tiles[key]["pest"]
		infected_tiles.erase(key)
		pest_cleared.emit(pest_name, tile_pos)
