# LogManager.gd
# Centralized game event logger and backlog chronicle for the farm.
# Records all notable events (crops, finance, weather, pests, construction, labor)
# with timestamps and categories so the player can review farm history anytime.

extends Node

signal log_added(entry: Dictionary)
signal logs_cleared()

const MAX_LOGS: int = 300

# Ordered list of log entries (newest first):
# [{
#    "id": int,
#    "day": int,
#    "hour": int,
#    "time_str": String,
#    "category": String,   # "all", "crops", "finance", "weather", "buildings", "workers"
#    "icon": String,
#    "message": String,
#    "details": String,
#    "color": Color
# }]
var logs: Array[Dictionary] = []
var _next_id: int = 1

func _ready() -> void:
	# Autoload signal connections
	TimeManager.day_changed.connect(_on_day_changed)
	MarketManager.sale_completed.connect(_on_sale_completed)
	WeatherManager.disaster_warning.connect(_on_disaster_warning)
	PestManager.pest_spawned.connect(_on_pest_spawned)
	PestManager.pest_cleared.connect(_on_pest_cleared)
	BuildingManager.worker_hired.connect(_on_worker_hired)
	BuildingManager.tech_unlocked.connect(_on_tech_unlocked)
	BuildingManager.building_placed.connect(_on_building_placed)

	# Initial opening log
	var reg_name: String = Data.get_region(Data.current_region).get("display_name", "Cotabato Basin")
	log_event("all", "📜 Farm Chronicle opened. Welcome to %s!" % reg_name, "📖", Color(1.0, 0.92, 0.45))

func log_event(category: String, message: String, icon: String = "📜", color: Color = Color.WHITE, details: String = "") -> void:
	var d: int = TimeManager.current_day
	var h: int = TimeManager.current_hour
	var time_str: String = "Day %d, %02d:00" % [d, h]

	var entry: Dictionary = {
		"id": _next_id,
		"day": d,
		"hour": h,
		"time_str": time_str,
		"category": category,
		"icon": icon,
		"message": message,
		"details": details,
		"color": color
	}
	_next_id += 1

	logs.insert(0, entry)
	if logs.size() > MAX_LOGS:
		logs.pop_back()

	log_added.emit(entry)

func get_logs(category: String = "all", search_query: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var query: String = search_query.strip_edges().to_lower()

	for entry in logs:
		if category != "all" and entry.category != category:
			continue
		if query != "":
			var msg: String = entry.message.to_lower()
			var det: String = entry.details.to_lower()
			if not (query in msg or query in det):
				continue
		result.append(entry)
	return result

func clear_logs() -> void:
	logs.clear()
	logs_cleared.emit()
	log_event("all", "Chronicle history cleared.", "🧹", Color(0.7, 0.7, 0.7))

# ---------------------------------------------------------------------------
# Autoload Event Handlers
# ---------------------------------------------------------------------------
func _on_day_changed(day: int) -> void:
	var reg_data: Dictionary = Data.get_region(Data.current_region)
	var reg_name: String = reg_data.get("display_name", "the region")
	log_event("all", "🌅 Day %d begins in %s." % [day, reg_name], "📅", Color(1.0, 0.9, 0.5))

func _on_sale_completed(crop: String, revenue: int, net_profit: int, hub_name: String, rot_loss: float) -> void:
	var c_data := Data.get_crop(crop)
	var c_name := str(c_data.get("display_name", crop.capitalize()))
	var rot_note := ""
	if rot_loss > 0.0:
		rot_note = " (Lost ₱%s to spoilage)" % Utils.format_number(int(rot_loss))
	log_event("finance", "Sold %s batch to %s for ₱%s (Net: +₱%s)%s." % [
		c_name,
		hub_name,
		Utils.format_number(revenue),
		Utils.format_number(net_profit),
		rot_note
	], "💰", Color(0.4, 1.0, 0.4))

func _on_disaster_warning(hazard: String, countdown: float = 5.0) -> void:
	var hazard_title: String = hazard.replace("_", " ").to_upper()
	log_event("weather", "⚠️ WARNING: %s incoming in %.0f seconds! Protect your crops!" % [hazard_title, countdown], "🚨", Color(1.0, 0.3, 0.3))

func _on_pest_spawned(pest_type: String, pos: Vector2i) -> void:
	var p_data := Data.get_pest(pest_type)
	var p_name := str(p_data.get("display_name", pest_type.capitalize()))
	log_event("weather", "🐛 Infestation: %s detected at tile (%d, %d)!" % [p_name, pos.x, pos.y], "🐛", Color(1.0, 0.55, 0.3))

func _on_pest_cleared(pest_type: String, pos: Vector2i) -> void:
	var p_data := Data.get_pest(pest_type)
	var p_name := str(p_data.get("display_name", pest_type.capitalize()))
	log_event("crops", "Infestation cleared: %s eradicated from tile (%d, %d)." % [p_name, pos.x, pos.y], "✅", Color(0.5, 1.0, 0.5))

func _on_worker_hired(total_workers: int) -> void:
	log_event("workers", "Labor Hired: Autonomous farmer joined the workforce (Active: %d)." % total_workers, "🧑‍🌾", Color(0.75, 1.0, 0.6))

func _on_tech_unlocked(tech_type: String) -> void:
	var t_data := Data.get_tech(tech_type)
	var t_name := str(t_data.get("display_name", tech_type.capitalize()))
	log_event("buildings", "Technology Researched: %s unlocked!" % t_name, "⚡", Color(0.45, 0.85, 1.0))

func _on_building_placed(b: Node) -> void:
	if not is_instance_valid(b):
		return
	var b_data := Data.get_building(b.building_type)
	var b_name := str(b_data.get("display_name", b.building_type.capitalize()))
	log_event("buildings", "Ground Broken: %s construction started at (%d, %d)." % [b_name, b.grid_pos.x, b.grid_pos.y], "🔨", Color(0.9, 0.78, 0.4))
