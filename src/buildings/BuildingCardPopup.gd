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
var flip_btn: Button                    = null

# Storage routing & capacity controls
@onready var storage_sub_card: PanelContainer = find_child("StorageSubCard", true, false) as PanelContainer
@onready var storage_section: VBoxContainer  = find_child("StorageSection", true, false) as VBoxContainer
@onready var fill_value_label: Label         = find_child("FillValueLabel", true, false) as Label
@onready var fill_progress_bar: ProgressBar   = find_child("FillProgressBar", true, false) as ProgressBar
@onready var preset_all_btn: Button          = find_child("PresetAllBtn", true, false) as Button
@onready var preset_grains_btn: Button       = find_child("PresetGrainsBtn", true, false) as Button
@onready var preset_perishables_btn: Button  = find_child("PresetPerishablesBtn", true, false) as Button
@onready var crop_buttons_grid: Container    = find_child("CropButtonsGrid", true, false) as Container

# Generic feature section (Center / Bigger Box for non-storage buildings)
@onready var generic_feature_section: VBoxContainer = find_child("GenericFeatureSection", true, false) as VBoxContainer
@onready var feature_title_label: Label             = find_child("FeatureTitleLabel", true, false) as Label
@onready var feature_content_vbox: VBoxContainer    = find_child("FeatureContentVBox", true, false) as VBoxContainer

const STYLE_GOLD_NORMAL  : StyleBox = preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres")
const STYLE_GOLD_HOVER   : StyleBox = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres")
const STYLE_GOLD_PRESSED : StyleBox = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres")
const STYLE_BROWN_NORMAL : StyleBox = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres")
const STYLE_BROWN_HOVER  : StyleBox = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres")
const STYLE_BROWN_PRESSED: StyleBox = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres")
const STYLE_DARK_WOOD    : StyleBox = preload("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres")

const CROPS_LIST: Array[Dictionary] = [
	{"key": "palay", "label": "🌾 Rice", "full": "Palay (Rice)"},
	{"key": "yellow_corn", "label": "🌽 Corn", "full": "Yellow Corn"},
	{"key": "sugarcane", "label": "🎋 Sugarcane", "full": "Sugar Cane"},
	{"key": "pineapple", "label": "🍍 Pineapple", "full": "Smooth Cayenne Pineapple"},
	{"key": "arabica_coffee", "label": "☕ Coffee", "full": "Arabica Coffee"},
	{"key": "banana", "label": "🍌 Banana", "full": "Cavendish Banana"},
	{"key": "coconut", "label": "🥥 Coconut", "full": "Tall Coconut Palm"}
]

func _ready() -> void:
	layer = 160
	visible = false
	if close_btn:
		close_btn.pressed.connect(func(): close())
	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)
	if demolish_btn:
		demolish_btn.pressed.connect(_on_demolish_pressed)
	if preset_all_btn:
		preset_all_btn.pressed.connect(_on_preset_all_pressed)
	if preset_grains_btn:
		preset_grains_btn.pressed.connect(_on_preset_grains_pressed)
	if preset_perishables_btn:
		preset_perishables_btn.pressed.connect(_on_preset_perishables_pressed)

	# Dynamic Flip orientation button
	var side_vbox: VBoxContainer = find_child("SideVBox", true, false) as VBoxContainer
	if side_vbox:
		flip_btn = Button.new()
		flip_btn.name = "FlipBtn"
		flip_btn.custom_minimum_size = Vector2(0, 36)
		flip_btn.text = "🔄 Flip Orientation [R]"
		flip_btn.add_theme_font_size_override("font_size", 13)
		flip_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82, 1.0))
		flip_btn.add_theme_stylebox_override("normal", STYLE_BROWN_NORMAL)
		flip_btn.add_theme_stylebox_override("hover", STYLE_BROWN_HOVER)
		flip_btn.add_theme_stylebox_override("pressed", STYLE_BROWN_PRESSED)
		flip_btn.pressed.connect(_on_flip_pressed)
		if demolish_btn:
			var idx: int = demolish_btn.get_index()
			side_vbox.add_child(flip_btn)
			side_vbox.move_child(flip_btn, idx)
		else:
			side_vbox.add_child(flip_btn)

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

	# Status text in right box
	match current_building.state:
		current_building.BuildingState.CONSTRUCTING:
			var remain := int(ceil(max(0.0, current_building.duration - current_building.progress_timer)))
			status_label.text = "🏗️ Under Construction (%ds remaining)" % remain
			status_label.modulate = Color.WHITE
			status_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
		current_building.BuildingState.UPGRADING:
			var remain := int(ceil(max(0.0, current_building.duration - current_building.progress_timer)))
			status_label.text = "⬆️ Upgrading to Level %d (%ds remaining)" % [current_building.level + 1, remain]
			status_label.modulate = Color.WHITE
			status_label.add_theme_color_override("font_color", Color(0.45, 0.80, 1.0))
		current_building.BuildingState.ACTIVE:
			status_label.text = "✅ Active & Operating"
			status_label.modulate = Color.WHITE
			status_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.55))

	if flip_btn:
		flip_btn.text = "🔄 Flipped (Left) [R]" if current_building.is_flipped else "🔄 Normal (Right) [R]"

	# Left / Center Bigger Box: Main Facility Features & Live Operational Telemetry
	var is_storage: bool = current_building.has_method("is_storage_building") and current_building.is_storage_building()
	if storage_sub_card:
		storage_sub_card.visible = is_storage
	if storage_section:
		storage_section.visible = is_storage
	if generic_feature_section:
		generic_feature_section.visible = not is_storage

	if is_storage:
		_refresh_storage_section()
	else:
		_refresh_generic_feature_section()

	# Right Smaller Box: Building Explanation & Active Level Perks
	var summary := _get_building_summary(current_building.building_type)
	current_stats_label.text = "%s\n\nActive Perks (Lv.%d):\n%s" % [
		summary,
		current_building.level,
		_format_stats(current_building.building_type, current_building.level)
	]

	if current_building.level < current_building.max_level:
		var next_cost := BuildingManager.get_upgrade_cost(current_building.building_type, current_building.level)
		var next_time := BuildingManager.get_upgrade_time(current_building.building_type, current_building.level)
		next_stats_label.text = "Next Tier (Level %d):\n%s\n\n💰 Cost: ₱%d   ⏱️ Build Time: %.0fs" % [
			current_building.level + 1,
			_format_stats(current_building.building_type, current_building.level + 1),
			next_cost,
			next_time
		]
		next_stats_label.visible = true

		upgrade_btn.text = "⬆️ Upgrade to Lv.%d (₱%d)" % [current_building.level + 1, next_cost]
		var can_afford: bool = EconomyManager.cash >= next_cost
		var is_active: bool = current_building.state == current_building.BuildingState.ACTIVE

		if can_afford and is_active:
			upgrade_btn.disabled = false
			upgrade_btn.add_theme_stylebox_override("normal", STYLE_GOLD_NORMAL)
			upgrade_btn.add_theme_stylebox_override("hover", STYLE_GOLD_HOVER)
			upgrade_btn.add_theme_stylebox_override("pressed", STYLE_GOLD_PRESSED)
			upgrade_btn.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1))
			upgrade_btn.tooltip_text = "Upgrade this facility to Level %d" % (current_building.level + 1)
		else:
			upgrade_btn.disabled = false
			upgrade_btn.add_theme_stylebox_override("normal", STYLE_DARK_WOOD)
			upgrade_btn.add_theme_stylebox_override("hover", STYLE_BROWN_HOVER)
			upgrade_btn.add_theme_stylebox_override("pressed", STYLE_BROWN_PRESSED)
			upgrade_btn.add_theme_color_override("font_color", Color(0.75, 0.68, 0.58, 1))
			if not is_active:
				upgrade_btn.tooltip_text = "Facility must be active and operating before upgrading."
			else:
				upgrade_btn.tooltip_text = "Insufficient funds: Need ₱%d (Current cash: ₱%d)" % [next_cost, EconomyManager.cash]
	else:
		next_stats_label.text = "🏆 Maximum Level Reached!"
		next_stats_label.visible = true
		upgrade_btn.text = "🏆 Max Level Reached"
		upgrade_btn.disabled = false
		upgrade_btn.add_theme_stylebox_override("normal", STYLE_DARK_WOOD)
		upgrade_btn.add_theme_stylebox_override("hover", STYLE_DARK_WOOD)
		upgrade_btn.add_theme_stylebox_override("pressed", STYLE_DARK_WOOD)
		upgrade_btn.add_theme_color_override("font_color", Color(0.65, 0.58, 0.48, 1))
		upgrade_btn.tooltip_text = "This facility has achieved peak operational tier."

	var base_cost: int = int(b_data.get("cost", 200))
	var refund: int = int(base_cost * 0.5 * current_building.level)
	demolish_btn.text = "🗑️ Demolish (+₱%d)" % refund

func _refresh_storage_section() -> void:
	if not is_instance_valid(current_building) or not storage_section:
		return

	var b_data := Data.get_building(current_building.building_type)
	var cap: int = current_building.get_storage_capacity()
	var used: int = current_building.used_storage
	var ratio: float = clampf(float(used) / float(max(1, cap)), 0.0, 1.0)
	var pct: float = ratio * 100.0

	if fill_value_label:
		fill_value_label.text = "%d / %d units (%.0f%%)" % [used, cap, pct]
		if ratio >= 0.90:
			fill_value_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.40))
		elif ratio >= 0.70:
			fill_value_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
		else:
			fill_value_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.60))

	if fill_progress_bar:
		fill_progress_bar.max_value = max(1, cap)
		fill_progress_bar.value = used

		var fill_color: Color = Color(0.28, 0.78, 0.35)
		if ratio >= 0.90:
			fill_color = Color(0.92, 0.32, 0.25)
		elif ratio >= 0.70:
			fill_color = Color(0.98, 0.75, 0.22)

		var sb_bg := StyleBoxFlat.new()
		sb_bg.bg_color = Color(0.12, 0.08, 0.05, 1.0)
		sb_bg.border_width_left = 1
		sb_bg.border_width_right = 1
		sb_bg.border_width_top = 1
		sb_bg.border_width_bottom = 1
		sb_bg.border_color = Color(0.48, 0.36, 0.22, 1.0)
		sb_bg.corner_radius_top_left = 3
		sb_bg.corner_radius_top_right = 3
		sb_bg.corner_radius_bottom_left = 3
		sb_bg.corner_radius_bottom_right = 3
		fill_progress_bar.add_theme_stylebox_override("background", sb_bg)

		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = fill_color
		sb_fill.corner_radius_top_left = 3
		sb_fill.corner_radius_top_right = 3
		sb_fill.corner_radius_bottom_left = 3
		sb_fill.corner_radius_bottom_right = 3
		fill_progress_bar.add_theme_stylebox_override("fill", sb_fill)

	# Optional cold storage banner in storage section
	var cold_banner := storage_section.get_node_or_null("ColdStorageBanner") as Label
	var halts_spoil: bool = b_data.get("halts_spoilage", false)
	if halts_spoil:
		if not cold_banner:
			cold_banner = Label.new()
			cold_banner.name = "ColdStorageBanner"
			cold_banner.add_theme_font_size_override("font_size", 12)
			cold_banner.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0, 1.0))
			storage_section.add_child(cold_banner)
			storage_section.move_child(cold_banner, 2)
		cold_banner.text = "❄️ Deep Cold Storage Active (0% Decay • Spoilage Completely Halted)"
		cold_banner.visible = true
	elif cold_banner:
		cold_banner.visible = false

	# Update preset button highlight
	var is_all_active: bool = current_building.assigned_crops.is_empty() or current_building.assigned_crops.size() >= 7
	var is_grains_active: bool = (
		current_building.assigned_crops.size() == 3 and
		current_building.assigned_crops.has("palay") and
		current_building.assigned_crops.has("yellow_corn") and
		current_building.assigned_crops.has("sugarcane")
	)
	var is_perishables_active: bool = (
		current_building.assigned_crops.size() == 4 and
		current_building.assigned_crops.has("arabica_coffee") and
		current_building.assigned_crops.has("banana") and
		current_building.assigned_crops.has("pineapple") and
		current_building.assigned_crops.has("coconut")
	)

	_style_preset_button(preset_all_btn, is_all_active)
	_style_preset_button(preset_grains_btn, is_grains_active)
	_style_preset_button(preset_perishables_btn, is_perishables_active)

	# Update or recreate crop buttons in crop_buttons_grid
	if crop_buttons_grid:
		for c in crop_buttons_grid.get_children():
			c.queue_free()

		for item in CROPS_LIST:
			var c_key: String = str(item.key)
			var c_label: String = str(item.label)
			var c_full: String = str(item.full)
			var is_accepted: bool = current_building.accepts_crop(c_key)

			var btn := Button.new()
			btn.name = "CropBtn_" + c_key
			btn.custom_minimum_size = Vector2(112, 32)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", 12)

			if is_accepted:
				btn.text = "✓ " + c_label
				btn.add_theme_stylebox_override("normal", STYLE_GOLD_NORMAL)
				btn.add_theme_stylebox_override("hover", STYLE_GOLD_HOVER)
				btn.add_theme_stylebox_override("pressed", STYLE_GOLD_PRESSED)
				btn.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1.0))
				btn.add_theme_color_override("font_hover_color", Color(0.12, 0.06, 0.02, 1.0))
				btn.tooltip_text = "%s: ACCEPTED\nClick to reject this crop from this storage facility." % c_full
			else:
				btn.text = "✕ " + c_label
				btn.add_theme_stylebox_override("normal", STYLE_BROWN_NORMAL)
				btn.add_theme_stylebox_override("hover", STYLE_BROWN_HOVER)
				btn.add_theme_stylebox_override("pressed", STYLE_BROWN_PRESSED)
				btn.add_theme_color_override("font_color", Color(0.85, 0.78, 0.70, 1.0))
				btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.92, 1.0))
				btn.tooltip_text = "%s: REJECTED\nClick to accept and route this crop to this storage facility." % c_full

			btn.pressed.connect(func(): _toggle_crop_acceptance(c_key))
			crop_buttons_grid.add_child(btn)

		# Slot 8: Deselect All
		var clear_btn := Button.new()
		clear_btn.name = "CropBtn_deselect_all"
		clear_btn.custom_minimum_size = Vector2(112, 32)
		clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clear_btn.add_theme_font_size_override("font_size", 12)
		clear_btn.text = "🚫 Deselect All"
		clear_btn.add_theme_stylebox_override("normal", STYLE_BROWN_NORMAL)
		clear_btn.add_theme_stylebox_override("hover", STYLE_BROWN_HOVER)
		clear_btn.add_theme_stylebox_override("pressed", STYLE_BROWN_PRESSED)
		clear_btn.add_theme_color_override("font_color", Color(0.95, 0.65, 0.60, 1.0))
		clear_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.80, 1.0))
		clear_btn.tooltip_text = "Deselect and reject all crops from this facility."
		clear_btn.pressed.connect(_on_deselect_all_pressed)
		crop_buttons_grid.add_child(clear_btn)

	# Storage facility preservation intelligence note
	var note_panel := storage_section.get_node_or_null("StorageInfoCard") as PanelContainer
	if not note_panel:
		note_panel = PanelContainer.new()
		note_panel.name = "StorageInfoCard"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.09, 0.05, 0.85)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.42, 0.30, 0.18, 0.9)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		note_panel.add_theme_stylebox_override("panel", sb)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		note_panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		margin.add_child(vbox)

		var h_lbl := Label.new()
		h_lbl.name = "InfoTitle"
		h_lbl.add_theme_font_size_override("font_size", 12)
		h_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
		vbox.add_child(h_lbl)

		var body_lbl := Label.new()
		body_lbl.name = "InfoBody"
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_lbl.add_theme_font_size_override("font_size", 11)
		body_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.74, 1.0))
		vbox.add_child(body_lbl)

		storage_section.add_child(note_panel)

	var h_node := note_panel.find_child("InfoTitle", true, false) as Label
	var b_node := note_panel.find_child("InfoBody", true, false) as Label
	if h_node and b_node:
		if halts_spoil:
			h_node.text = "❄️ Sub-Zero Climate Storage Active"
			b_node.text = "• Crop Spoilage Rate: 0% per hour (Preserves 100% freshness indefinitely)\n• Transit Shield: Produce stored here is immune to road decay during sales."
		else:
			h_node.text = "📦 Conventional Grain Silo Storage"
			b_node.text = "• Spoilage Rate: Standard crops lose freshness at 5% per hour without cold storage.\n• Smart Routing: Workers automatically deliver allowed crops to this facility."

# ---------------------------------------------------------------------------
# Generic Feature Section Populators (Center / Bigger Box)
# ---------------------------------------------------------------------------
func _refresh_generic_feature_section() -> void:
	if not is_instance_valid(current_building) or not feature_content_vbox:
		return

	# Clear previous cards
	for c in feature_content_vbox.get_children():
		c.queue_free()

	var b_type: String = str(current_building.building_type)
	var lvl: int = int(current_building.level)
	var b_data: Dictionary = Data.get_building(b_type)

	var recipe: Dictionary = b_data.get("recipe", {})
	if not recipe.is_empty():
		_populate_processing_features(b_type, lvl, b_data, recipe)
	elif b_type == "water_tower" or b_data.get("irrigation_equipment", false):
		_populate_water_tower_features(b_type, lvl, b_data)
	elif b_type == "sprinkler" or b_data.get("is_sprinkler", false):
		_populate_sprinkler_features(b_type, lvl, b_data)
	elif b_data.has("hub_id"):
		_populate_hub_features(b_type, lvl, b_data)
	elif b_type == "bayanihan_center" or b_data.get("biyahero_price_bonus", 0.0) > 0.0:
		_populate_bayanihan_features(b_type, lvl, b_data)
	elif b_type == "weather_station" or b_data.get("forecast_equipment", false):
		_populate_weather_station_features(b_type, lvl, b_data)
	elif b_type == "solar_dryer" or float(b_data.get("drying_bonus", 0.0)) > 0.0:
		_populate_solar_dryer_features(b_type, lvl, b_data)
	elif b_type == "bahay_kubo" or int(b_data.get("worker_capacity", 0)) > 0:
		_populate_housing_features(b_type, lvl, b_data)
	else:
		_populate_default_features(b_type, lvl, b_data)

func _populate_processing_features(_b_type: String, _lvl: int, _b_data: Dictionary, recipe: Dictionary) -> void:
	if feature_title_label:
		feature_title_label.text = "🏭 Automated Commodity Processing Engine"

	# Card 1: Batch Cycle & Quality Assurance
	var c1 := _create_card("Batch Operation Cycle", "⏱️")
	_add_card_line(c1, "Automated Milling: Triggers automatically every 4 in-game hours.", Color(0.95, 0.90, 0.82))
	_add_card_line(c1, "✨ 100% Shelf-Stable: Processed goods never spoil or rot in transit or storage!", Color(0.55, 0.95, 0.60))

	# Card 2: Inputs Required & Live Storage Stock Check
	var in_crop: String = str(recipe.get("input_crop", ""))
	var in_qty: int = int(recipe.get("input_qty", 0))
	var in_data: Dictionary = Data.get_crop(in_crop)
	var in_disp: String = str(in_data.get("display_name", in_crop.capitalize())).split("(")[0].strip_edges()
	var in_icon: String = str(in_data.get("icon", "🌾"))

	var stored_units: int = MarketManager.get_stored_units_for_crop(in_crop)
	var has_enough: bool = stored_units >= in_qty

	var c2 := _create_card("Input Conversion & Farm Storage Stock", "📥")
	_add_card_line(c2, "Consumes per Batch: %s %d units %s" % [in_icon, in_qty, in_disp], Color(1.0, 0.88, 0.45))

	var stock_str: String = "📦 Farm Storage Stock: %d units %s" % [
		stored_units,
		"(✓ READY FOR BATCH)" if has_enough else "(⚠ HARVEST REQUIRED)"
	]
	var stock_color: Color = Color(0.55, 0.95, 0.60) if has_enough else Color(1.0, 0.45, 0.40)
	_add_card_line(c2, stock_str, stock_color)

	# Mini stock ratio bar
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = max(1, in_qty)
	bar.value = clampi(stored_units, 0, in_qty)
	bar.show_percentage = false
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.28, 0.78, 0.35) if has_enough else Color(0.85, 0.35, 0.25)
	sb_fill.corner_radius_top_left = 2
	sb_fill.corner_radius_top_right = 2
	sb_fill.corner_radius_bottom_left = 2
	sb_fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", sb_fill)
	c2.add_child(bar)

	# Card 3: Outputs Produced & Value Potential
	var c3 := _create_card("Processed Output Commodities", "📤")
	var total_batch_revenue: int = 0
	for out_item in recipe.get("outputs", []):
		var out_name: String = str(out_item.get("item", ""))
		var out_qty: int = int(out_item.get("qty", 0))
		var out_data: Dictionary = Data.get_crop(out_name)
		var out_disp: String = str(out_data.get("display_name", out_name.capitalize())).split("(")[0].strip_edges()
		var out_icon: String = str(out_data.get("icon", "📦"))
		var out_price: int = int(out_data.get("base_price", 100))
		var rev: int = out_qty * out_price
		total_batch_revenue += rev
		_add_card_line(c3, "• %s %d %s (Market Benchmark: ₱%d/ea)" % [out_icon, out_qty, out_disp, out_price], Color(0.92, 0.86, 0.78))

	_add_card_line(c3, "💰 Total Revenue Potential: ₱%d per batch" % total_batch_revenue, Color(1.0, 0.88, 0.45))

func _populate_water_tower_features(_b_type: String, lvl: int, _b_data: Dictionary) -> void:
	if feature_title_label:
		feature_title_label.text = "🚰 Central Farm Aquifer & Pressure Subsystem"

	var active_sp: int = BuildingManager.get_active_sprinkler_count()
	var cap_sp: int = [6, 16, 999][clampi(lvl - 1, 0, 2)]
	var cap_text: String = "Unlimited" if cap_sp >= 999 else "%d Sprinklers" % cap_sp

	# Card 1: Equipment & Pressure Capacity
	var c1 := _create_card("Equipment Tier & Pressure Load", "💦")
	var tier_name: String = [
		"Groundwater Well Pump (Level 1)",
		"Elevated Water Tower (Level 2)",
		"Solar Drip Network (Level 3)"
	][clampi(lvl - 1, 0, 2)]
	_add_card_line(c1, "Equipment: %s" % tier_name, Color(1.0, 0.88, 0.45))
	_add_card_line(c1, "Sprinkler Network Load: %d / %s active" % [active_sp, cap_text], Color(0.55, 0.95, 0.60))

	if cap_sp < 999:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 10)
		bar.max_value = max(1, cap_sp)
		bar.value = active_sp
		bar.show_percentage = false
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = Color(0.25, 0.65, 0.95)
		sb_fill.corner_radius_top_left = 2
		sb_fill.corner_radius_top_right = 2
		sb_fill.corner_radius_bottom_left = 2
		sb_fill.corner_radius_bottom_right = 2
		bar.add_theme_stylebox_override("fill", sb_fill)
		c1.add_child(bar)

	# Card 2: Farmwide Moisture & Climate Shields
	var evap: int = [10, 25, 35][clampi(lvl - 1, 0, 2)]
	var c2 := _create_card("Agronomic Moisture Shields", "💧")
	_add_card_line(c2, "Soil Evaporation Shield: -%d%% slower moisture loss" % evap, Color(0.55, 0.95, 0.60))
	_add_card_line(c2, "Drought Protection: Hydrates parched plots to prevent crop wilting.", Color(0.92, 0.86, 0.78))
	_add_card_line(c2, "Flood Drainage: Drains excess standing water 20% faster after downpours.", Color(0.92, 0.86, 0.78))

func _populate_sprinkler_features(_b_type: String, _lvl: int, _b_data: Dictionary) -> void:
	if feature_title_label:
		feature_title_label.text = "🚿 Rotary Impact Spray Subsystem"

	var rad: int = BuildingManager.get_sprinkler_radius()
	var cov_str: String = "3×3 Diamond (8 surrounding plots)" if rad == 1 else "5×5 Diamond (24 surrounding plots)"
	var active_sp: int = BuildingManager.get_active_sprinkler_count()
	var cap_sp: int = BuildingManager.get_sprinkler_capacity()

	var c1 := _create_card("Spray Coverage & Automation", "💦")
	_add_card_line(c1, "Spray Coverage Radius: %s" % cov_str, Color(1.0, 0.88, 0.45))
	_add_card_line(c1, "Morning Hydration: Automatically irrigates covered plots at 06:00 AM.", Color(0.55, 0.95, 0.60))
	_add_card_line(c1, "Heat Stress Shield: Prevents sun scorch & wilting during scorching midday.", Color(0.92, 0.86, 0.78))

	var c2 := _create_card("Network Pressure Link", "🚰")
	_add_card_line(c2, "Pressure Source: Linked to Irrigation Pump & Tower", Color(0.92, 0.86, 0.78))
	_add_card_line(c2, "Network Status: %d / %d Sprinklers active" % [active_sp, cap_sp], Color(0.55, 0.95, 0.60))

func _populate_drone_features(_b_type: String, lvl: int, _b_data: Dictionary) -> void:
	if feature_title_label:
		feature_title_label.text = "🛸 Autonomous Precision Flight Operations"

	var cap_desc: String = [
		"🌱 Plow Drone (Autonomous soil plowing)",
		"🌾 Seeder Drone (Auto-plows & sows designated seeds)",
		"🚜 Harvester Drone (Auto-plows, plants & harvests ripe crops)"
	][clampi(lvl - 1, 0, 2)]

	var c1 := _create_card("Flight Automation Capability", "🎮")
	_add_card_line(c1, "Current Automation Tier: %s" % cap_desc, Color(1.0, 0.88, 0.45))
	match lvl:
		1:
			_add_card_line(c1, "• Autonomous Plow: Detects untilled or flood-receded plots in zone and prepares soil.", Color(0.92, 0.86, 0.78))
			_add_card_line(c1, "• Upgrade to Lv.2 to unlock automatic seeding of designated crop varieties.", Color(0.95, 0.75, 0.35))
		2:
			_add_card_line(c1, "• Autonomous Seeder: Automatically plows ground and sows designated seeds from hotbar.", Color(0.92, 0.86, 0.78))
			_add_card_line(c1, "• Upgrade to Lv.3 to unlock full hands-free harvesting & storage delivery.", Color(0.95, 0.75, 0.35))
		3:
			_add_card_line(c1, "• Full Agricultural Loop: Gathers ripe produce to Bodega, clears soil, plows, and re-seeds continuously.", Color(0.55, 0.95, 0.60))

	_add_card_line(c1, "• Obstacle & Terrain Immunity: Flies smoothly over obstacles, waterlogged paddies, and fences.", Color(0.55, 0.95, 0.60))

	var c2 := _create_card("Fleet Operations & Solar Power", "🧑‍🌾")
	var d_act: int = BuildingManager.active_drones
	var d_cap: int = BuildingManager.get_drone_capacity()
	_add_card_line(c2, "Remote Pilot Requirement: 1 Drone per Active Farmer on duty.", Color(0.95, 0.90, 0.82))
	_add_card_line(c2, "Commissioned Fleet: %d Drones active (%d Farmer Pilots available)." % [d_act, d_cap], Color(1.0, 0.88, 0.45))
	_add_card_line(c2, "Solar Charging Pads: Autonomous return-to-base docking & battery recharge.", Color(0.55, 0.95, 0.60))

	var c3 := _create_card("Autonomous Drone Command", "📡")
	_add_card_line(c3, "1. Open the Drone Command Deck via HUD button or hotkey [U].", Color(0.92, 0.86, 0.78))
	_add_card_line(c3, "2. Toggle automation directives: Plow, Seed, Water, Spray, Harvest, Clear.", Color(0.92, 0.86, 0.78))
	_add_card_line(c3, "3. Designate a custom patrol zone or 1-click deploy to the whole farm.", Color(0.92, 0.86, 0.78))

	_add_card_action_button(c3, "🛸 Open Drone Command Deck (U)", func():
		close()
		var deck = get_tree().root.find_child("DroneCommandDeck", true, false)
		if deck and deck.has_method("open"):
			deck.open()
		else:
			var hotbar = get_tree().root.find_child("PlantHotbar", true, false)
			if hotbar and hotbar.has_method("select_tool"):
				hotbar.select_tool("drone_zone")
	)

func _populate_bayanihan_features(_b_type: String, _lvl: int, _b_data: Dictionary) -> void:
	if feature_title_label:
		feature_title_label.text = "🤝 Biyahero Roadside Post & Middleman Trade"

	var bonus_pct: int = int(round(float(Data.get_building("bayanihan_center").get("biyahero_price_bonus", 0.08)) * 100.0))

	# Card 1: Local Middleman Direct Trade
	var c1 := _create_card("Local Biyahero Direct Trade", "🚚")
	_add_card_line(c1, "Farmgate Payout Bonus: +%d%% on all produce sold to the Local Middleman (72%% → 80%% base rate)." % bonus_pct, Color(0.55, 0.95, 0.60))
	_add_card_line(c1, "Zero Logistics Fee: 0 km distance • ₱0 fuel expense • 0%% road spoilage decay.", Color(1.0, 0.88, 0.45))
	_add_card_line(c1, "Instant Settlement: Middleman loads right at the farm post with immediate cash in hand.", Color(0.92, 0.86, 0.78))

	# Card 2: Operations & Sales Strategy
	var c2 := _create_card("Trading Operations & Bodega Integration", "📦")
	_add_card_line(c2, "Permanent One-Time Facility: Active indefinitely across all seasons without upkeep fees.", Color(0.92, 0.86, 0.78))
	_add_card_line(c2, "Disaster Rescue: Ideal for dumping perishable produce immediately during typhoon warnings without long-distance road risks.", Color(0.55, 0.95, 0.60))

func _populate_hub_features(_b_type: String, _lvl: int, b_data: Dictionary) -> void:
	var hub_id: String = str(b_data.get("hub_id", ""))
	var hub_data: Dictionary = Data.get_market_hub(hub_id)
	var hub_name: String = str(hub_data.get("display_name", hub_id))
	var price_bonus: int = int(round(float(b_data.get("hub_price_bonus", 0.0)) * 100.0))
	var rot_cut: int = int(round(float(b_data.get("hub_rot_cut", 0.0)) * 100.0))
	var fuel_cut: int = int(round(float(b_data.get("hub_fuel_cut", 0.0)) * 100.0))

	if feature_title_label:
		feature_title_label.text = "🚢 %s Hub Logistics" % hub_name.split("(")[0].strip_edges()

	var c1 := _create_card("Unlocked Shipping Destination", "🗺️")
	_add_card_line(c1, "Contract Hub: %s" % hub_name, Color(1.0, 0.88, 0.45))
	_add_card_line(c1, "Exclusive Payout Premium: +%d%% sale value on all dispatches to this buyer." % price_bonus, Color(0.55, 0.95, 0.60))
	_add_card_line(c1, "Logistics Perks: -%d%% transport road rot • -%d%% diesel fuel costs." % [rot_cut, fuel_cut], Color(0.55, 0.95, 0.60))

	var c2 := _create_card("Bodega Dispatch Desk", "📋")
	_add_card_line(c2, "Access: Open the Bodega Sales Desk (Sell Produce) to select this destination.", Color(0.92, 0.86, 0.78))
	if b_data.get("requires_shore", false):
		_add_card_line(c2, "Deepwater Port: Harbor pier berthed along the eastern sea channel for ocean-going container freighters.", Color(0.40, 0.85, 1.0))

func _populate_weather_station_features(_b_type: String, lvl: int, _b_data: Dictionary) -> void:
	if feature_title_label:
		feature_title_label.text = "📡 PAGASA Meteorological Radar & Telemetry"

	var tier_desc: String = [
		"AM Radio Mast (1-Day Forecast • 60% Accuracy)",
		"Automated Weather Station (3-Day Forecast • 90% Accuracy)",
		"Satellite Uplink Dish (7-Day Forecast • 100% Accuracy)"
	][clampi(lvl - 1, 0, 2)]
	var warning_secs: int = [8, 12, 18][clampi(lvl - 1, 0, 2)]

	var c1 := _create_card("Meteorological Radar Tier", "🛰️")
	_add_card_line(c1, "Instrumentation: %s" % tier_desc, Color(1.0, 0.88, 0.45))
	_add_card_line(c1, "🚨 Early Warning Lead Time: %ds advance notice before disaster strikes!" % warning_secs, Color(0.55, 0.95, 0.60))

	var c2 := _create_card("PAGASA Agri-Weather Telemetry Dashboard", "🌦️")
	_add_card_line(c2, "View 7-day temperature trends, typhoon warnings, and tactical harvest advice.", Color(0.92, 0.86, 0.78))

	_add_card_action_button(c2, "🌦️ Open Full 7-Day Weather App", func():
		var ws = current_building
		close()
		var farm_grid = ws.get_parent() if is_instance_valid(ws) else null
		if farm_grid and "weather_app_modal" in farm_grid and is_instance_valid(farm_grid.weather_app_modal):
			farm_grid.weather_app_modal.open_for_station(ws)
	)

func _populate_solar_dryer_features(_b_type: String, lvl: int, b_data: Dictionary) -> void:
	if feature_title_label:
		feature_title_label.text = "☀️ Traditional Sun-Drying Concrete Pavement"

	var drying: float = float(b_data.get("drying_bonus", 0.25))
	var bonus_pct: int = int(round((drying + (lvl - 1) * 0.15) * 100.0))

	var c1 := _create_card("Grain Quality & Value Surge", "💰")
	_add_card_line(c1, "Selling Value Bonus: +%d%% on sun-cured grain harvests" % bonus_pct, Color(1.0, 0.88, 0.45))
	_add_card_line(c1, "Eligible Commodities: Palay (Rice), Yellow Corn, Arabica Coffee", Color(0.55, 0.95, 0.60))

	var c2 := _create_card("Traditional Bilaran Curing", "🌾")
	_add_card_line(c2, "Sun-dried grains achieve Grade A export quality with superior moisture balance.", Color(0.92, 0.86, 0.78))
	_add_card_line(c2, "✨ Zero Fuel / Operating Cost: Powered purely by natural sunlight.", Color(0.92, 0.86, 0.78))

func _populate_housing_features(_b_type: String, lvl: int, _b_data: Dictionary) -> void:
	if feature_title_label:
		feature_title_label.text = "🏡 Farmworker Living Quarters & Welfare"

	var c1 := _create_card("Labor Force Housing Allowance", "🧑‍🌾")
	_add_card_line(c1, "Housing Capacity: +%d Maximum Farmworkers" % lvl, Color(1.0, 0.88, 0.45))
	_add_card_line(c1, "Active Labor Force: %d Active Laborers Hired" % BuildingManager.worker_capacity, Color(0.55, 0.95, 0.60))

	var c2 := _create_card("Worker Accommodations", "🌴")
	_add_card_line(c2, "Elevated bamboo and nipa thatch shelter protects laborers from floods and heat.", Color(0.92, 0.86, 0.78))
	_add_card_line(c2, "⭐ Upgrades expand bunk capacity and shaded rest areas for your field crew.", Color(0.92, 0.86, 0.78))

func _populate_default_features(_b_type: String, _lvl: int, b_data: Dictionary) -> void:
	if feature_title_label:
		feature_title_label.text = "⚙️ Facility Operations & Main Feature"
	var c := _create_card("Operational Overview", "🏛️")
	_add_card_line(c, str(b_data.get("description", "Active farm infrastructure facility.")), Color(0.92, 0.86, 0.78))

# ---------------------------------------------------------------------------
# Card & Label Helper Methods
# ---------------------------------------------------------------------------
func _create_card(title: String, icon: String = "") -> VBoxContainer:
	var card_panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.85)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.42, 0.30, 0.18, 0.9)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	card_panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	if title != "":
		var header := Label.new()
		header.text = ("%s %s" % [icon, title]).strip_edges()
		header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
		header.add_theme_font_size_override("font_size", 13)
		vbox.add_child(header)

	feature_content_vbox.add_child(card_panel)
	return vbox

func _add_card_line(card_vbox: VBoxContainer, text: String, color: Color = Color(0.92, 0.86, 0.78, 1.0), font_size: int = 12) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	card_vbox.add_child(lbl)
	return lbl

func _add_card_action_button(card_vbox: VBoxContainer, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 34)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_stylebox_override("normal", STYLE_GOLD_NORMAL)
	btn.add_theme_stylebox_override("hover", STYLE_GOLD_HOVER)
	btn.add_theme_stylebox_override("pressed", STYLE_GOLD_PRESSED)
	btn.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.12, 0.06, 0.02, 1.0))
	btn.pressed.connect(callback)
	card_vbox.add_child(btn)
	return btn

func _style_preset_button(btn: Button, is_active: bool) -> void:
	if not is_instance_valid(btn):
		return
	if is_active:
		btn.add_theme_stylebox_override("normal", STYLE_GOLD_NORMAL)
		btn.add_theme_stylebox_override("hover", STYLE_GOLD_HOVER)
		btn.add_theme_stylebox_override("pressed", STYLE_GOLD_PRESSED)
		btn.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.12, 0.06, 0.02, 1.0))
	else:
		btn.add_theme_stylebox_override("normal", STYLE_BROWN_NORMAL)
		btn.add_theme_stylebox_override("hover", STYLE_BROWN_HOVER)
		btn.add_theme_stylebox_override("pressed", STYLE_BROWN_PRESSED)
		btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.92, 1.0))

func _on_preset_all_pressed() -> void:
	if not is_instance_valid(current_building):
		return
	current_building.assigned_crops.clear()
	AudioManager.play_ui("click")
	_refresh_storage_section()
	MarketManager._sync_storage_with_building_manager()

func _on_preset_grains_pressed() -> void:
	if not is_instance_valid(current_building):
		return
	current_building.assigned_crops = ["palay", "yellow_corn", "sugarcane"]
	AudioManager.play_ui("click")
	_refresh_storage_section()
	MarketManager._sync_storage_with_building_manager()

func _on_preset_perishables_pressed() -> void:
	if not is_instance_valid(current_building):
		return
	current_building.assigned_crops = ["arabica_coffee", "banana", "pineapple", "coconut"]
	AudioManager.play_ui("click")
	_refresh_storage_section()
	MarketManager._sync_storage_with_building_manager()

func _on_deselect_all_pressed() -> void:
	if not is_instance_valid(current_building):
		return
	current_building.assigned_crops = ["none"]
	AudioManager.play_ui("click")
	_refresh_storage_section()
	MarketManager._sync_storage_with_building_manager()

func _toggle_crop_acceptance(crop_key: String) -> void:
	if not is_instance_valid(current_building):
		return
	if current_building.assigned_crops.is_empty():
		var all_crops: Array[String] = ["palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"]
		current_building.assigned_crops = all_crops.duplicate()
		current_building.assigned_crops.erase(crop_key)
	elif current_building.assigned_crops == ["none"]:
		current_building.assigned_crops = [crop_key]
	else:
		if current_building.assigned_crops.has(crop_key):
			current_building.assigned_crops.erase(crop_key)
			if current_building.assigned_crops.is_empty():
				current_building.assigned_crops = ["none"]
		else:
			current_building.assigned_crops.append(crop_key)

		if current_building.assigned_crops.size() >= 7:
			current_building.assigned_crops.clear()

	AudioManager.play_ui("click")
	_refresh_storage_section()
	MarketManager._sync_storage_with_building_manager()

func _get_building_summary(b_type: String) -> String:
	match b_type:
		"bodega":
			return "Corrugated steel grain silo bin compound. Stores bulk harvests safely for market sales and processing."
		"cold_storage":
			return "Industrial refrigerated warehouse. Completely halts spoilage and prevents road transit decay."
		"climate_silo":
			return "High-tech airtight silo. Eliminates moisture rot and maintains 100% grain freshness."
		"rice_mill":
			return "Automated hulling and polishing mill. Refines raw Palay into White Rice and Bran."
		"sugar_mill":
			return "Mechanized crusher central. Refines Sugarcane into Muscovado Sugar and Molasses."
		"copra_dryer":
			return "Biomass smokehouse kiln & press. Converts Coconuts into Virgin Coconut Oil and Copra Meal."
		"coffee_roastery":
			return "Artisan batch drum roaster. Transforms Arabica beans into Premium Roast packs."
		"water_tower":
			return "Central farm irrigation pump & tower. Pressurizes field sprinklers and dampens soil evaporation."
		"sprinkler":
			return "Ground-mounted rotary sprinkler. Automates morning irrigation across surrounding plots."
		"drone_station":
			return "High-tech drone command hangar. Deploys autonomous precision agriculture drones to designated field zones for hands-free plowing, seeding, and automated harvesting."
		"bayanihan_center":
			return "Roadside trading post for the local biyahero (middleman). Improves farmgate sale payouts by +8% with instant, zero-rot, zero-fuel pickup."
		"tacurong_mill":
			return "Regional grain mill loading depot. Unlocks the Tacurong sell hub with +6% payout, -30% road rot, and -20% fuel costs."
		"koronadal_wholesale":
			return "Wholesale trade depot. Unlocks the Koronadal commercial center sell hub with +8% payout, -30% road rot, and -25% fuel costs."
		"gensan_seaport":
			return "Deepwater coastal container terminal with ocean freighter berth. Unlocks the General Santos Seaport export hub with +12% payout, -50% transit decay, and -30% fuel costs."
		"weather_station":
			return "Meteorological station linked to PAGASA radar. Forecasts weather and warns of typhoons."
		"solar_dryer":
			return "Traditional concrete bilaran pavement. Sun-cures grains to elevate quality and selling price."
		"bahay_kubo":
			return "Traditional farm shack living quarters. Expands housing capacity to hire more farm laborers."
		_:
			return "Operational farm infrastructure facility."

func _format_stats(b_type: String, lvl: int) -> String:
	var b_data := Data.get_building(b_type)
	var lines: Array[String] = []

	var base_storage: int = int(b_data.get("storage_limit", 0))
	if base_storage > 0:
		var mult: float = 1.0 + (lvl - 1) * 1.0
		lines.append("📦 Storage Capacity: %d units" % int(base_storage * mult))

	var base_worker: int = int(b_data.get("worker_capacity", 0))
	if base_worker > 0:
		lines.append("🧑‍🌾 Worker Housing: +%d workers" % lvl)

	if b_data.get("halts_spoilage", false):
		lines.append("❄️ Spoilage Rot: 0% (Halted)")

	var drying: float = float(b_data.get("drying_bonus", 0.0))
	if drying > 0.0:
		var bonus_pct: int = int(round((drying + (lvl - 1) * 0.15) * 100.0))
		lines.append("☀️ Sun-Drying Value Bonus: +%d%%" % bonus_pct)

	if b_type == "water_tower" or b_data.get("irrigation_equipment", false):
		var tier_desc: String = ["Well Pump (6 Sprinklers)", "Elevated Tower (16 Sprinklers)", "Solar Drip (Unlimited)"][clampi(lvl - 1, 0, 2)]
		lines.append("🚰 Equipment Tier: %s" % tier_desc)
		lines.append("💧 Evaporation Shield: -%d%%" % [10, 25, 35][clampi(lvl - 1, 0, 2)])

	if b_type == "sprinkler" or b_data.get("is_sprinkler", false):
		var rad: int = BuildingManager.get_sprinkler_radius()
		var cov_str: String = "3×3 Diamond (8 plots)" if rad == 1 else "5×5 Diamond (24 plots)"
		lines.append("💦 Coverage: %s" % cov_str)

	var fp: Vector2i = b_data.get("grid_size", Vector2i(2, 2))
	lines.append("📐 Footprint: %d×%d tiles" % [fp.x, fp.y])

	if b_data.get("biyahero_price_bonus", 0.0) > 0.0:
		var bonus_pct: int = int(round(float(b_data.get("biyahero_price_bonus", 0.08)) * 100.0))
		lines.append("🤝 Middleman Payout: +%d%%" % bonus_pct)

	if b_data.has("hub_id"):
		var h_bonus: int = int(round(float(b_data.get("hub_price_bonus", 0.0)) * 100.0))
		lines.append("🚢 Hub Markup: +%d%%" % h_bonus)

	if b_type == "drone_station" or b_data.get("unlocks_drones", false):
		var cap_desc: String = ["Plow Drone", "Seeder Drone", "Harvester Drone"][clampi(lvl - 1, 0, 2)]
		lines.append("🛸 Automation Tier: %s" % cap_desc)

	if b_type == "weather_station" or b_data.get("forecast_equipment", false):
		var tier_desc: String = ["1-Day Radar (60%)", "3-Day Station (90%)", "7-Day Satellite (100%)"][clampi(lvl - 1, 0, 2)]
		var warning_secs: int = [8, 12, 18][clampi(lvl - 1, 0, 2)]
		lines.append("📡 Radar: %s" % tier_desc)
		lines.append("🚨 Warning Lead Time: %ds" % warning_secs)

	var recipe: Dictionary = b_data.get("recipe", {})
	if not recipe.is_empty():
		var in_crop: String = str(recipe.get("input_crop", ""))
		var in_qty: int = int(recipe.get("input_qty", 0))
		lines.append("🏭 Batch Cycle: Every 4 in-game hours")
		lines.append("📥 Batch Input: %d %s" % [in_qty, in_crop.capitalize()])

	return "\n".join(lines) if lines.size() > 0 else "Operational Facility"

func _on_upgrade_pressed() -> void:
	if not is_instance_valid(current_building):
		return
	if current_building.level >= current_building.max_level:
		AudioManager.play_ui("error")
		return
	var up_cost := BuildingManager.get_upgrade_cost(current_building.building_type, current_building.level)
	var up_time := BuildingManager.get_upgrade_time(current_building.building_type, current_building.level)
	if current_building.state != current_building.BuildingState.ACTIVE or EconomyManager.cash < up_cost:
		AudioManager.play_ui("error")
		return
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

func _on_flip_pressed() -> void:
	if is_instance_valid(current_building):
		current_building.toggle_flip()
		AudioManager.play_ui("click")
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_on_flip_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


