# BuildingCardPopup.gd
# Modal inspector card for inspecting, upgrading, and managing placed farm buildings.
# Clash of Clans / Strategy style UI with level stats, upgrade countdowns, and demolition.

class_name BuildingCardPopup
extends CanvasLayer

signal upgrade_requested(building: Node)
signal demolish_requested(building: Node)

var current_building: Node = null

@onready var panel: PanelContainer      = $CenterContainer/Panel
@onready var title_label: Label         = find_child("TitleLabel", true, false) as Label
@onready var close_btn: Button          = find_child("CloseBtn", true, false) as Button
@onready var level_label: Label         = find_child("LevelLabel", true, false) as Label
@onready var status_label: Label        = find_child("StatusLabel", true, false) as Label
@onready var current_stats_label: Label = find_child("CurrentStats", true, false) as Label
@onready var next_stats_label: Label    = find_child("NextStats", true, false) as Label
@onready var upgrade_btn: Button        = find_child("UpgradeBtn", true, false) as Button
@onready var demolish_btn: Button       = find_child("DemolishBtn", true, false) as Button

func _ready() -> void:
	layer = 160
	visible = false
	if close_btn:
		close_btn.pressed.connect(func(): close())
	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)
	if demolish_btn:
		demolish_btn.pressed.connect(_on_demolish_pressed)

func open_for_building(b: Node) -> void:
	current_building = b
	refresh()
	visible = true

func close() -> void:
	current_building = null
	visible = false

func refresh() -> void:
	if not is_instance_valid(current_building):
		close()
		return

	var b_data := Data.get_building(current_building.building_type)
	var b_name := str(b_data.get("display_name", current_building.building_type))
	var icon   := str(b_data.get("icon", "🏛️"))

	title_label.text = "%s %s" % [icon, b_name]

	var stars := ""
	for i in range(current_building.level):
		stars += "⭐"
	level_label.text = "%s Level %d / %d" % [stars, current_building.level, current_building.max_level]

	# Status text
	match current_building.state:
		current_building.BuildingState.CONSTRUCTING:
			var remain := int(ceil(max(0.0, current_building.duration - current_building.progress_timer)))
			status_label.text = "🏗️ Under Construction (%ds remaining)" % remain
			status_label.modulate = Color.WHITE
			status_label.add_theme_color_override("font_color", Color(0.65, 0.45, 0.10))
		current_building.BuildingState.UPGRADING:
			var remain := int(ceil(max(0.0, current_building.duration - current_building.progress_timer)))
			status_label.text = "⬆️ Upgrading to Level %d (%ds remaining)" % [current_building.level + 1, remain]
			status_label.modulate = Color.WHITE
			status_label.add_theme_color_override("font_color", Color(0.20, 0.45, 0.70))
		current_building.BuildingState.ACTIVE:
			status_label.text = "✅ Active & Operating"
			status_label.modulate = Color.WHITE
			status_label.add_theme_color_override("font_color", Color(0.12, 0.45, 0.16))

	# Stats display
	current_stats_label.text = _format_stats(current_building.building_type, current_building.level)

	if current_building.level < current_building.max_level:
		var next_cost := BuildingManager.get_upgrade_cost(current_building.building_type, current_building.level)
		var next_time := BuildingManager.get_upgrade_time(current_building.building_type, current_building.level)
		next_stats_label.text = "Next Tier (Level %d):\n%s\n💰 Cost: ₱%d   ⏱️ Build Time: %.0fs" % [
			current_building.level + 1,
			_format_stats(current_building.building_type, current_building.level + 1),
			next_cost,
			next_time
		]
		next_stats_label.visible = true

		upgrade_btn.text = "⬆️ Upgrade to Lv.%d (₱%d)" % [current_building.level + 1, next_cost]
		upgrade_btn.disabled = (
			current_building.state != current_building.BuildingState.ACTIVE or
			EconomyManager.cash < next_cost
		)
	else:
		next_stats_label.text = "🏆 Maximum Level Reached!"
		next_stats_label.visible = true
		upgrade_btn.text = "Max Level ✔"
		upgrade_btn.disabled = true

	if upgrade_btn.disabled:
		upgrade_btn.remove_theme_stylebox_override("normal")
		upgrade_btn.remove_theme_stylebox_override("hover")
		upgrade_btn.remove_theme_stylebox_override("pressed")
		upgrade_btn.remove_theme_stylebox_override("disabled")
		upgrade_btn.remove_theme_color_override("font_disabled_color")
		upgrade_btn.remove_theme_color_override("font_color")
	else:
		upgrade_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
		upgrade_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
		upgrade_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
		upgrade_btn.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1))


	var base_cost: int = int(b_data.get("cost", 200))
	var refund: int = int(base_cost * 0.5 * current_building.level)
	demolish_btn.text = "🗑️ Demolish (+₱%d)" % refund

func _format_stats(b_type: String, lvl: int) -> String:
	var b_data := Data.get_building(b_type)
	var lines: Array[String] = []

	var base_storage: int = int(b_data.get("storage_limit", 0))
	if base_storage > 0:
		var mult: float = 1.0 + (lvl - 1) * 1.0
		lines.append("• 📦 Crop Storage Capacity: %d units" % int(base_storage * mult))

	var base_worker: int = int(b_data.get("worker_capacity", 0))
	if base_worker > 0:
		lines.append("• 🧑‍🌾 Worker Housing Capacity: +%d workers" % lvl)

	if b_data.get("halts_spoilage", false):
		lines.append("• ❄️ Warehouse Spoilage: 0% (Completely halted)")

	var drying: float = float(b_data.get("drying_bonus", 0.0))
	if drying > 0.0:
		var bonus_pct: int = int(round((drying + (lvl - 1) * 0.15) * 100.0))
		lines.append("• ☀️ Grain Sun-Drying Value Bonus: +%d%%" % bonus_pct)

	if b_type == "water_tower" or b_data.get("irrigation_equipment", false):
		var tier_desc: String = [
			"Groundwater Well Pump (Pressure for 6 Sprinklers • 3×3 Diamond • 15% drought resist)",
			"Elevated Water Tower (Pressure for 16 Sprinklers • 5×5 Diamond • 25% evap reduction)",
			"Solar Drip Network (Unlimited Sprinklers + Full-farm drip lines • 35% evap reduction • 30% disaster resilience)"
		][clampi(lvl - 1, 0, 2)]
		lines.append("• 🚰 Irrigation Tier: %s" % tier_desc)
		lines.append("• 💦 Sprinkler Capacity: %d Sprinklers supported (%d active)" % [
			[6, 16, 999][clampi(lvl - 1, 0, 2)],
			BuildingManager.get_active_sprinkler_count()
		])
		lines.append("• 💧 Soil Evaporation Shield: -%d%%" % [10, 25, 35][clampi(lvl - 1, 0, 2)])

	if b_type == "sprinkler" or b_data.get("is_sprinkler", false):
		var rad: int = BuildingManager.get_sprinkler_radius()
		var cov_str: String = "3×3 Diamond (8 surrounding plots)" if rad == 1 else "5×5 Diamond (24 surrounding plots)"
		lines.append("• 💦 Spray Coverage: %s" % cov_str)
		lines.append("• 💧 Automatic Watering: Hydrates parched & growing plots to optimal moisture")
		lines.append("• 🛡️ Drought Shield: Prevents wilting & heat damage during dry spells")
		lines.append("• 🚰 Pressure Network: %d/%d Sprinklers active" % [
			BuildingManager.get_active_sprinkler_count(),
			BuildingManager.get_sprinkler_capacity()
		])

	if b_type == "machine_garage" or b_data.get("unlocks_machines", false):
		var fleet_desc: String = [
			"Kuliglig Hand-Tractor Bay (2x Plowing Speed)",
			"Combine Harvester Bay (5x Harvesting Speed)",
			"Heavy Mechanized Fleet (+20% Fleet Speed Bonus)"
		][clampi(lvl - 1, 0, 2)]
		lines.append("• 🚜 Fleet Mechanization: %s" % fleet_desc)

	if b_type == "drone_station" or b_data.get("unlocks_drones", false):
		var cap_desc: String = ["Plow Drone (Auto-tills land)", "Seeder Drone (Auto-plows & sows seeds)", "Harvester Drone (Auto-plows, plants & harvests)"][clampi(lvl - 1, 0, 2)]
		lines.append("• 🛸 Drone Automation Tier: %s" % cap_desc)
		lines.append("• 🎮 Pilot Operator Limit: 1 Drone per Active Farmer")

	if b_type == "weather_station" or b_data.get("forecast_equipment", false):
		var tier_desc: String = [
			"AM Radio Mast (1-Day Forecast • 60% Accuracy)",
			"Automated Weather Station (3-Day Forecast • 90% Accuracy)",
			"Satellite Uplink Dish (7-Day Forecast • 100% Accuracy)"
		][clampi(lvl - 1, 0, 2)]
		var warning_secs: int = [8, 12, 18][clampi(lvl - 1, 0, 2)]
		lines.append("• 📡 Equipment Tier: %s" % tier_desc)
		lines.append("• 🚨 Emergency Early Warning Lead Time: %ds" % warning_secs)

	return "\n".join(lines) if lines.size() > 0 else "• Operational Facility"

func _on_upgrade_pressed() -> void:
	if not is_instance_valid(current_building):
		return
	var up_cost := BuildingManager.get_upgrade_cost(current_building.building_type, current_building.level)
	var up_time := BuildingManager.get_upgrade_time(current_building.building_type, current_building.level)
	if current_building.start_upgrade(up_cost, up_time):
		upgrade_requested.emit(current_building)
		refresh()

func _on_demolish_pressed() -> void:
	if not is_instance_valid(current_building):
		return
	var b := current_building
	close()
	b.demolish()
	demolish_requested.emit(b)
