# PestManager.gd
# Manages pest infestations, spawn triggers, regional pest susceptibilities, and spread mechanics.

extends Node

signal pest_spawned(pest_type: String, position: Vector2i)
signal pest_cleared(pest_type: String, position: Vector2i)
signal pest_spread(count: int)

const GRID_LIMIT: int = 32

## key: "x_y" -> {"pest": String, "days": int}
var infected_tiles: Dictionary = {}


func _ready() -> void:
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.day_changed.connect(_on_day_changed)


func reset_for_new_session() -> void:
	infected_tiles.clear()


func _get_farm_grid() -> Node:
	if not is_inside_tree():
		return null
	var g := get_tree().get_first_node_in_group("farm_grid")
	if g:
		return g
	var root := get_tree().current_scene
	if root:
		return root.find_child("FarmGrid", true, false)
	return null


func _on_day_changed(_day: int) -> void:
	# Full moon occurs every 7th day (Days 7, 14, 21, 28) - attracts Rice Black Bugs
	if _day % 7 == 0:
		_trigger_full_moon_black_bugs()


func _on_hour_changed(hour: int) -> void:
	# Spread check to adjacent tiles every 6 hours (00:00, 06:00, 12:00, 18:00)
	if hour % 6 == 0:
		_advance_spread()


func _trigger_full_moon_black_bugs() -> void:
	var grid_node: Node = _get_farm_grid()
	if not grid_node or not ("grid" in grid_node):
		return
	var r_mods: Dictionary = Data.get_region_modifiers(Data.current_region)
	var pest_mult: float = float(r_mods.get("pest_mults", {}).get("rice_black_bug", 1.0))
	var rice_candidates: Array[Vector2i] = []
	for pos_key in grid_node.grid.keys():
		var tile = grid_node.grid[pos_key]
		if tile and tile.crop_type == "palay" and (tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING):
			var key: String = "%d_%d" % [pos_key.x, pos_key.y]
			if not infected_tiles.has(key):
				rice_candidates.append(pos_key)
	rice_candidates.shuffle()
	var spawned: int = 0
	for tile_pos in rice_candidates:
		if spawned >= 3:
			break
		if randf() < minf(0.28 * pest_mult, 0.75):
			var key: String = "%d_%d" % [tile_pos.x, tile_pos.y]
			infected_tiles[key] = {"pest": "rice_black_bug", "days": 0, "crop": "palay"}
			pest_spawned.emit("rice_black_bug", tile_pos)
			spawned += 1


## Called by FarmGrid after a tile is planted or daily to evaluate spawn conditions.
func evaluate_spawn(tile_pos: Vector2i, crop_type: String, soil_moisture: int) -> void:
	var crop_data: Dictionary = Data.get_crop(crop_type)
	if crop_data.is_empty():
		return

	var pest_mults: Dictionary = Data.get_region_modifiers(Data.current_region).get("pest_mults", {})

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

		# Nocturnal Philippine pest surge: Rice Black Bug and Kuhol swarm under darkness
		var spawn_chance: float = 0.30
		if TimeManager.is_night() and (pest_name == "rice_black_bug" or pest_name == "kuhol"):
			spawn_chance = 0.48
		spawn_chance = minf(spawn_chance * float(pest_mults.get(pest_name, 1.0)), 0.85)

		if should_spawn and randf() < spawn_chance:
			var key: String = "%d_%d" % [tile_pos.x, tile_pos.y]
			if not infected_tiles.has(key):
				infected_tiles[key] = {"pest": pest_name, "days": 0, "crop": crop_type}
				pest_spawned.emit(pest_name, tile_pos)


func _advance_spread() -> void:
	var new_infections: Array = []
	var grid_node: Node = _get_farm_grid()
	var pest_mults: Dictionary = Data.get_region_modifiers(Data.current_region).get("pest_mults", {})

	for key: String in infected_tiles.keys():
		var info: Dictionary = infected_tiles[key]
		info["days"] += 1
		var pest_name: String = info["pest"]
		var src_crop: String = str(info.get("crop", ""))
		var pest_data: Dictionary = Data.get_pest(pest_name)
		var spread_rate: float = float(pest_data.get("spread_rate", 0.15))
		var region_mult: float = float(pest_mults.get(pest_name, 1.0))

		var parts: PackedStringArray = key.split("_")
		var x: int = int(parts[0])
		var y: int = int(parts[1])
		var neighbours: Array = [
			Vector2i(x + 1, y), Vector2i(x - 1, y),
			Vector2i(x, y + 1), Vector2i(x, y - 1),
		]
		for n: Vector2i in neighbours:
			if n.x >= 0 and n.x < GRID_LIMIT and n.y >= 0 and n.y < GRID_LIMIT:
				var nkey: String = "%d_%d" % [n.x, n.y]
				if infected_tiles.has(nkey):
					continue
				# Spread preferentially into planted/growing crops and accelerate in monoculture
				var monoculture_mult: float = 1.0
				var target_crop: String = src_crop
				if grid_node and ("grid" in grid_node) and grid_node.grid.has(n):
					var n_tile = grid_node.grid[n]
					if n_tile == null or not (n_tile.state == FarmTile.TileState.PLANTED or n_tile.state == FarmTile.TileState.GROWING or n_tile.state == FarmTile.TileState.HARVESTABLE):
						continue
					target_crop = n_tile.crop_type
					var c_pests: Array = Data.get_crop(target_crop).get("pests", [])
					if not (pest_name in c_pests):
						continue
					if src_crop != "" and target_crop == src_crop:
						monoculture_mult = 1.50
				var effective_spread: float = minf(spread_rate * monoculture_mult * region_mult, 0.75)
				if randf() < effective_spread:
					new_infections.append({"pos": n, "pest": pest_name, "crop": target_crop})
	for inf: Dictionary in new_infections:
		var nkey: String = "%d_%d" % [inf.pos.x, inf.pos.y]
		infected_tiles[nkey] = {"pest": inf.pest, "days": 0, "crop": inf.get("crop", "")}
		pest_spawned.emit(inf.pest, inf.pos)
	if new_infections.size() > 0:
		pest_spread.emit(new_infections.size())


## Called by FarmGrid when a player/farmer applies treatment.
func treat_tile(tile_pos: Vector2i, _method: String) -> void:
	var key: String = "%d_%d" % [tile_pos.x, tile_pos.y]
	if infected_tiles.has(key):
		var pest_name: String = infected_tiles[key]["pest"]
		infected_tiles.erase(key)
		pest_cleared.emit(pest_name, tile_pos)
