# BuildingCardPopup.gd
# Modal inspector card for inspecting, upgrading, and managing placed farm buildings.
# Clash of Clans / Strategy style UI with level stats, upgrade countdowns, and demolition.

class_name BuildingCardPopup
extends CanvasLayer

signal upgrade_requested(building: Node)
signal demolish_requested(building: Node)

var current_building: Node = null

@onready var panel: PanelContainer      = $CenterContainer/Panel
@onready var title_label: Label         = $CenterContainer/Panel/VBox/Header/TitleLabel
@onready var close_btn: Button          = $CenterContainer/Panel/VBox/Header/CloseBtn
@onready var level_label: Label         = $CenterContainer/Panel/VBox/LevelLabel
@onready var status_label: Label        = $CenterContainer/Panel/VBox/StatusLabel
@onready var current_stats_label: Label = $CenterContainer/Panel/VBox/CurrentStats
@onready var next_stats_label: Label    = $CenterContainer/Panel/VBox/NextStats
@onready var upgrade_btn: Button        = $CenterContainer/Panel/VBox/ButtonHBox/UpgradeBtn
@onready var demolish_btn: Button       = $CenterContainer/Panel/VBox/ButtonHBox/DemolishBtn

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
			status_label.modulate = Color(1.0, 0.85, 0.2)
		current_building.BuildingState.UPGRADING:
			var remain := int(ceil(max(0.0, current_building.duration - current_building.progress_timer)))
			status_label.text = "⬆️ Upgrading to Level %d (%ds remaining)" % [current_building.level + 1, remain]
			status_label.modulate = Color(0.4, 0.85, 1.0)
		current_building.BuildingState.ACTIVE:
			status_label.text = "✅ Active & Operating"
			status_label.modulate = Color(0.4, 1.0, 0.4)

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

	if b_data.get("unlocks_machines", false):
		var speed_pct: int = 10 + (lvl - 1) * 15
		lines.append("• 🚜 Machinery Fleet Speed Bonus: +%d%%" % speed_pct)

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
