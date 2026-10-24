# WeatherAppModal.gd
# Dedicated modern Weather App & PAGASA Meteorological Telemetry Dashboard.
# Opened when clicking on a placed Weather Station (or HUD weather telemetry widget).
# Features:
#   - Real-time current conditions & agronomic vitals hero card
#   - Full 7-Day weather predictions with temperature, moisture, rainfall, hazards, and plain crop advice
#   - Tier-locked radar range visualization (AM Radio 1d -> AWS 3d -> Satellite Dish 7d)
#   - Integrated Weather Station upgrade & demolition management
#   - Actionable farming tips to simplify weather predictions

class_name WeatherAppModal
extends CanvasLayer

signal closed()
signal upgrade_requested(building: Node)
signal demolish_requested(building: Node)

const SUN_ICON: Texture2D        = preload("res://assets/icons/Topleft/Sun.png")
const RAIN_ICON: Texture2D       = preload("res://assets/icons/Topleft/Rain.png")
const CLOUD_ICON: Texture2D      = preload("res://assets/icons/Topleft/Cloud.png")
const SUN_CLOUDS_ICON: Texture2D = preload("res://assets/icons/Topleft/Sunandclouds.png")
const WARNING_ICON: Texture2D    = preload("res://assets/icons/Disaster/Warning.png")
const FLOOD_WAVE_ICON: Texture2D = preload("res://assets/icons/Disaster/Wave.png")
const TEMP_FIRE_ICON: Texture2D       = preload("res://assets/icons/Tempreture/Fire.png")
const TEMP_SUNNY_ICON: Texture2D      = preload("res://assets/icons/Tempreture/Sunny.png")
const TEMP_JUST_RIGHT_ICON: Texture2D = preload("res://assets/icons/Tempreture/Just-Right.png")
const TEMP_COLD_ICON: Texture2D       = preload("res://assets/icons/Tempreture/Cold .png")
const WATER_DROP_ICON: Texture2D      = preload("res://assets/icons/Topleft/water-drop.png")

const STYLE_MAIN_PANEL: StyleBox     = preload("res://assets/sprites/hud/Big-Rectangle-Box/BigPlainBox.tres")
const STYLE_BROWN_BOX: StyleBox      = preload("res://assets/sprites/hud/TopRight/BrownBox.tres")
const STYLE_INNER_BOX: StyleBox      = preload("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres")
const STYLE_SAMPLEBOX: StyleBox      = preload("res://assets/sprites/hud/Samplebox.tres")

const STYLE_SQ_BROWN: StyleBox       = preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres")
const STYLE_SQ_BROWN_HOVER: StyleBox = preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres")
const STYLE_SQ_BROWN_PRESS: StyleBox = preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres")

const STYLE_GOLD_BTN: StyleBox       = preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres")
const STYLE_GOLD_HOVER: StyleBox     = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres")
const STYLE_GOLD_PRESS: StyleBox     = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres")

const STYLE_BROWN_BTN: StyleBox      = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres")
const STYLE_BROWN_HOVER: StyleBox    = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres")
const STYLE_BROWN_PRESS: StyleBox    = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres")

var current_building: Node = null

# UI Node References
var _backdrop: ColorRect             = null
var _main_panel: PanelContainer      = null
var _title_label: Label              = null
var _subtitle_label: Label           = null
var _tier_badge_label: Label         = null
var _close_btn: Button               = null

# Today / Hero Vitals
var _hero_icon: TextureRect          = null
var _hero_temp_label: Label          = null
var _hero_condition_label: Label     = null
var _hero_sub_label: Label           = null
var _hazard_status_label: Label      = null
var _humidity_chip_val: Label        = null
var _rainfall_chip_val: Label        = null
var _accuracy_chip_val: Label        = null
var _warning_chip_val: Label         = null

# 7-Day Forecast Cards Container
var _forecast_cards_hbox: HBoxContainer = null

# Footer Station Management
var _footer_station_info_label: Label   = null
var _footer_perks_label: Label          = null
var _progress_box: VBoxContainer        = null
var _progress_bar: ProgressBar          = null
var _progress_label: Label              = null
var _upgrade_btn: Button                = null
var _demolish_btn: Button               = null

func _ready() -> void:
	layer = 165
	visible = false
	if _main_panel == null:
		_build_ui()
	_connect_signals()

func _connect_signals() -> void:
	TimeManager.hour_changed.connect(func(_h): if visible: refresh())
	TimeManager.day_changed.connect(func(_d): if visible: refresh())
	TimeManager.period_changed.connect(func(_p, _n): if visible: refresh())
	WeatherManager.weather_changed.connect(func(_t, _h): if visible: refresh())
	WeatherManager.disaster_warning.connect(func(_h, _c): if visible: refresh())
	WeatherManager.disaster_struck.connect(func(_h): if visible: refresh())
	WeatherManager.disaster_cleared.connect(func(_h): if visible: refresh())
	BuildingManager.weather_station_updated.connect(func(_l): if visible: refresh())
	EconomyManager.cash_changed.connect(func(_a): if visible: _update_footer_buttons())

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible:
		return

	# Live update construction or upgrade timer
	if is_instance_valid(current_building):
		if current_building.state != current_building.BuildingState.ACTIVE:
			_update_progress_display()

	# Live update hazard countdown
	if WeatherManager.incoming_disaster != "":
		_update_live_hazard_status()

func open_for_station(building: Node) -> void:
	if _main_panel == null:
		_build_ui()
	current_building = building
	if is_instance_valid(current_building):
		if not current_building.state_changed.is_connected(_on_building_state_changed):
			current_building.state_changed.connect(_on_building_state_changed)
		if not current_building.demolished.is_connected(_on_building_demolished):
			current_building.demolished.connect(_on_building_demolished)
	visible = true
	refresh()

func open_almanac() -> void:
	if _main_panel == null:
		_build_ui()
	current_building = BuildingManager.get_weather_station()
	visible = true
	refresh()

func close() -> void:
	visible = false
	if is_instance_valid(current_building):
		if current_building.state_changed.is_connected(_on_building_state_changed):
			current_building.state_changed.disconnect(_on_building_state_changed)
		if current_building.demolished.is_connected(_on_building_demolished):
			current_building.demolished.disconnect(_on_building_demolished)
	current_building = null
	closed.emit()

func _on_building_state_changed(_b: Node) -> void:
	if visible:
		refresh()

func _on_building_demolished(_b: Node) -> void:
	close()

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	# Full-screen dimming backdrop
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.60)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	# Main Weather App window panel
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(880, 560)
	_main_panel.add_theme_stylebox_override("panel", STYLE_MAIN_PANEL)
	center.add_child(_main_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_main_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# 1. Header Row
	_build_header(root_vbox)

	# 2. Current Conditions Hero Card
	_build_hero_card(root_vbox)

	# 3. 7-Day Forecast Section Header
	var f_header_box := HBoxContainer.new()
	var f_title := Label.new()
	f_title.text = "📅 7-DAY WEATHER PREDICTIONS & HAZARD RADAR"
	f_title.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	f_title.add_theme_font_size_override("font_size", 15)
	f_header_box.add_child(f_title)

	var f_spacer := Control.new()
	f_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f_header_box.add_child(f_spacer)

	var f_sub := Label.new()
	f_sub.text = "Daily predictions simplify irrigation planning & crop disaster mitigation"
	f_sub.add_theme_color_override("font_color", Color(0.42, 0.28, 0.10, 0.95))
	f_sub.add_theme_font_size_override("font_size", 12)
	f_header_box.add_child(f_sub)
	root_vbox.add_child(f_header_box)

	# 4. Horizontal Forecast Strip (7 Cards)
	_forecast_cards_hbox = HBoxContainer.new()
	_forecast_cards_hbox.add_theme_constant_override("separation", 6)
	_forecast_cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_forecast_cards_hbox.custom_minimum_size = Vector2(0, 168)
	root_vbox.add_child(_forecast_cards_hbox)

	# 5. Agronomic Impact Tip Bar
	_build_guide_bar(root_vbox)

	# 6. Station Management & Upgrade Footer
	_build_footer(root_vbox)

func _build_header(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 1)

	_title_label = Label.new()
	_title_label.text = "📡 PAGASA AGRI-WEATHER TELEMETRY"
	_title_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	_title_label.add_theme_font_size_override("font_size", 19)
	title_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "📍 Cotabato Basin • Live Meteorological Telemetry & Agronomic Predictions"
	_subtitle_label.add_theme_color_override("font_color", Color(0.42, 0.28, 0.10, 1.0))
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	title_vbox.add_child(_subtitle_label)
	hbox.add_child(title_vbox)

	# Equipment Tier Capsule
	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", STYLE_BROWN_BOX)
	_tier_badge_label = Label.new()
	_tier_badge_label.text = "📻 AM Radio Mast (Lv. 1) • 60% Accuracy"
	_tier_badge_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	_tier_badge_label.add_theme_font_size_override("font_size", 12)
	badge_panel.add_child(_tier_badge_label)
	hbox.add_child(badge_panel)

	# Close Button
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(32, 32)
	_close_btn.add_theme_font_size_override("font_size", 15)
	_close_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	_close_btn.add_theme_stylebox_override("normal", STYLE_SQ_BROWN)
	_close_btn.add_theme_stylebox_override("hover", STYLE_SQ_BROWN_HOVER)
	_close_btn.add_theme_stylebox_override("pressed", STYLE_SQ_BROWN_PRESS)
	_close_btn.pressed.connect(func(): close())
	hbox.add_child(_close_btn)

func _build_hero_card(parent: VBoxContainer) -> void:
	var hero_panel := PanelContainer.new()
	hero_panel.add_theme_stylebox_override("panel", STYLE_BROWN_BOX)
	parent.add_child(hero_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	hero_panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	# Left side: Weather Condition Hero
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cond_row := HBoxContainer.new()
	cond_row.add_theme_constant_override("separation", 12)

	_hero_icon = TextureRect.new()
	_hero_icon.texture = SUN_CLOUDS_ICON
	_hero_icon.custom_minimum_size = Vector2(56, 56)
	_hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cond_row.add_child(_hero_icon)

	var cond_text_vbox := VBoxContainer.new()
	cond_text_vbox.add_theme_constant_override("separation", 1)

	var temp_row := HBoxContainer.new()
	temp_row.add_theme_constant_override("separation", 8)

	_hero_temp_label = Label.new()
	_hero_temp_label.text = "28°C"
	_hero_temp_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	_hero_temp_label.add_theme_font_size_override("font_size", 28)
	temp_row.add_child(_hero_temp_label)

	_hero_condition_label = Label.new()
	_hero_condition_label.text = "Partly Cloudy & Fair"
	_hero_condition_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	_hero_condition_label.add_theme_font_size_override("font_size", 15)
	_hero_condition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	temp_row.add_child(_hero_condition_label)
	cond_text_vbox.add_child(temp_row)

	_hero_sub_label = Label.new()
	_hero_sub_label.text = "Feels like 30°C • Daylight (08:00)"
	_hero_sub_label.add_theme_color_override("font_color", Color(0.80, 0.75, 0.65, 0.9))
	_hero_sub_label.add_theme_font_size_override("font_size", 12)
	cond_text_vbox.add_child(_hero_sub_label)
	cond_row.add_child(cond_text_vbox)
	left_vbox.add_child(cond_row)

	# Live Hazard Radar Alert
	_hazard_status_label = Label.new()
	_hazard_status_label.text = "🟢 ALL SYSTEMS CLEAR — No imminent storms or floods detected"
	_hazard_status_label.add_theme_color_override("font_color", Color(0.40, 0.88, 0.50, 1.0))
	_hazard_status_label.add_theme_font_size_override("font_size", 12)
	left_vbox.add_child(_hazard_status_label)
	hbox.add_child(left_vbox)

	# Right side: 4 Agronomic Vital Chips (2x2 Grid)
	var vitals_grid := GridContainer.new()
	vitals_grid.columns = 2
	vitals_grid.add_theme_constant_override("h_separation", 8)
	vitals_grid.add_theme_constant_override("v_separation", 6)

	_humidity_chip_val = _create_vital_chip(vitals_grid, "💧 Relative Humidity", "65% (Optimal)")
	_rainfall_chip_val = _create_vital_chip(vitals_grid, "🌧️ Daily Rainfall", "12 mm (Moderate)")
	_accuracy_chip_val = _create_vital_chip(vitals_grid, "🎯 Radar Accuracy", "60% Moderate")
	_warning_chip_val  = _create_vital_chip(vitals_grid, "⏱️ Emergency Warning", "8s Lead Time")
	hbox.add_child(vitals_grid)

func _create_vital_chip(parent: Control, title_text: String, default_val: String) -> Label:
	var chip := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.14, 0.09, 0.05, 0.75)
	s.border_color = Color(0.48, 0.35, 0.22, 0.6)
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 6; s.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", s)
	chip.custom_minimum_size = Vector2(170, 48)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var lbl_title := Label.new()
	lbl_title.text = title_text
	lbl_title.add_theme_color_override("font_color", Color(0.80, 0.74, 0.64, 0.95))
	lbl_title.add_theme_font_size_override("font_size", 10)
	vbox.add_child(lbl_title)

	var lbl_val := Label.new()
	lbl_val.text = default_val
	lbl_val.add_theme_color_override("font_color", Color(1.0, 0.92, 0.76, 1.0))
	lbl_val.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl_val)

	chip.add_child(vbox)
	parent.add_child(chip)
	return lbl_val

func _build_guide_bar(parent: VBoxContainer) -> void:
	var guide_panel := PanelContainer.new()
	guide_panel.add_theme_stylebox_override("panel", STYLE_BROWN_BOX)
	guide_panel.custom_minimum_size = Vector2(0, 32)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 4)
	guide_panel.add_child(margin)

	var guide_lbl := Label.new()
	guide_lbl.text = "💡 AGRONOMY TIPS:  🌾 Palay: 70–90% moist  •  🌽 Corn: 30–60%  •  🍍 Pineapple: 35–65%  •  💧 Sprinklers combat Drought  •  ⚡ Harvest before Floods"
	guide_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.84, 0.98))
	guide_lbl.add_theme_font_size_override("font_size", 11)
	margin.add_child(guide_lbl)
	parent.add_child(guide_panel)

func _build_footer(parent: VBoxContainer) -> void:
	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 12)
	parent.add_child(footer_hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)

	_footer_station_info_label = Label.new()
	_footer_station_info_label.text = "⭐ Equipment: AM Radio Mast (Level 1 / 3) • ✅ Operating"
	_footer_station_info_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	_footer_station_info_label.add_theme_font_size_override("font_size", 13)
	info_vbox.add_child(_footer_station_info_label)

	_footer_perks_label = Label.new()
	_footer_perks_label.text = "Next Tier: Automated Weather Station (Lv.2) — Unlocks 3-Day Forecast • 90% Accuracy"
	_footer_perks_label.add_theme_color_override("font_color", Color(0.12, 0.45, 0.16, 1.0))
	_footer_perks_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(_footer_perks_label)

	# Construction / Upgrade Progress Bar
	_progress_box = VBoxContainer.new()
	_progress_box.visible = false
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 14)
	_progress_bar.show_percentage = false
	_progress_box.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.text = "🔨 Sensor array calibration in progress..."
	_progress_label.add_theme_color_override("font_color", Color(0.20, 0.45, 0.70, 1.0))
	_progress_label.add_theme_font_size_override("font_size", 11)
	_progress_box.add_child(_progress_label)
	info_vbox.add_child(_progress_box)
	footer_hbox.add_child(info_vbox)

	# Upgrade Button
	_upgrade_btn = Button.new()
	_upgrade_btn.text = "⬆️ Upgrade to AWS Lv.2 (₱600)"
	_upgrade_btn.custom_minimum_size = Vector2(240, 38)
	_upgrade_btn.add_theme_font_size_override("font_size", 13)
	_upgrade_btn.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
	_upgrade_btn.add_theme_stylebox_override("normal", STYLE_GOLD_BTN)
	_upgrade_btn.add_theme_stylebox_override("hover", STYLE_GOLD_HOVER)
	_upgrade_btn.add_theme_stylebox_override("pressed", STYLE_GOLD_PRESS)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	footer_hbox.add_child(_upgrade_btn)

	# Demolish Button
	_demolish_btn = Button.new()
	_demolish_btn.text = "🗑️ Demolish (+₱225)"
	_demolish_btn.custom_minimum_size = Vector2(140, 38)
	_demolish_btn.add_theme_font_size_override("font_size", 13)
	_demolish_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	_demolish_btn.add_theme_stylebox_override("normal", STYLE_BROWN_BTN)
	_demolish_btn.add_theme_stylebox_override("hover", STYLE_BROWN_HOVER)
	_demolish_btn.add_theme_stylebox_override("pressed", STYLE_BROWN_PRESS)
	_demolish_btn.pressed.connect(_on_demolish_pressed)
	footer_hbox.add_child(_demolish_btn)

# ---------------------------------------------------------------------------
# Data Refresh & Rendering
# ---------------------------------------------------------------------------
func refresh() -> void:
	if not visible:
		return

	# 1. Update Title and Location
	var reg_data: Dictionary = Data.get_region(Data.current_region)
	var reg_name: String = reg_data.get("display_name", Data.current_region.capitalize()).split("(")[0].strip_edges()
	_subtitle_label.text = "📍 %s • PAGASA Meteorological Telemetry" % reg_name

	# 2. Update Current Weather Hero Card
	var eff_temp: float = WeatherManager.get_effective_temperature()
	var eff_hum: float  = WeatherManager.get_effective_humidity()
	var rain: float     = WeatherManager.rainfall_mm

	_hero_temp_label.text = "%.0f°C" % eff_temp
	_hero_condition_label.text = WeatherManager.get_condition_title(WeatherManager.current_climate, WeatherManager.incoming_disaster)
	_hero_icon.texture = _get_weather_icon(WeatherManager.current_climate, WeatherManager.incoming_disaster, eff_temp, rain)

	var period_name: String = TimeManager.get_time_period_name()
	var time_str: String = "%02d:00" % TimeManager.current_hour
	var feels_like: float = eff_temp + (eff_hum * 3.0) - (rain * 0.1)
	_hero_sub_label.text = "Feels like %.0f°C • %s (%s)" % [feels_like, period_name, time_str]

	# Vitals chips
	var hum_status: String = "Optimal"
	if eff_hum < 0.40:
		hum_status = "Arid / Parched"
	elif eff_hum > 0.85:
		hum_status = "Saturated / Paddies"
	_humidity_chip_val.text = "%.0f%% (%s)" % [eff_hum * 100.0, hum_status]

	var rain_desc: String = "Zero"
	if rain > 50.0:
		rain_desc = "Torrential"
	elif rain > 15.0:
		rain_desc = "Heavy"
	elif rain > 0.1:
		rain_desc = "Showers"
	_rainfall_chip_val.text = "%.1f mm (%s)" % [rain, rain_desc]

	var st_acc: float = BuildingManager.get_forecast_accuracy()
	var st_warn: float = BuildingManager.get_disaster_warning_time()
	var tier_name: String = BuildingManager.get_weather_station_tier_name()

	_accuracy_chip_val.text = "%d%% Accuracy" % int(round(st_acc * 100.0))
	_warning_chip_val.text  = "%.0fs Lead Time" % st_warn
	_tier_badge_label.text  = "%s • %d%% Accuracy" % [tier_name, int(round(st_acc * 100.0))]

	_update_live_hazard_status()

	# 3. Populate 7-Day Forecast Cards
	_populate_forecast_strip()

	# 4. Update Footer & Buttons
	_update_footer_buttons()

func _update_live_hazard_status() -> void:
	if WeatherManager.incoming_disaster != "":
		var hazard_title := WeatherManager.incoming_disaster.replace("_", " ").to_upper()
		_hazard_status_label.text = "⚠️ IMMINENT HAZARD: %s STRIKING IN %.1fs!" % [hazard_title, WeatherManager.disaster_countdown]
		_hazard_status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25, 1.0))
	elif WeatherManager.active_disaster != "":
		var hazard_title := WeatherManager.active_disaster.replace("_", " ").to_upper()
		_hazard_status_label.text = "🚨 ACTIVE HAZARD: %s IN PROGRESS (%.1fs remaining)" % [hazard_title, WeatherManager.disaster_duration]
		_hazard_status_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	else:
		_hazard_status_label.text = "🟢 ALL SYSTEMS CLEAR — No imminent storms or floods detected"
		_hazard_status_label.add_theme_color_override("font_color", Color(0.40, 0.88, 0.50, 1.0))

func _populate_forecast_strip() -> void:
	for c in _forecast_cards_hbox.get_children():
		c.queue_free()

	var forecast_data: Array = WeatherManager.get_forecast()
	var cur_day: int = TimeManager.current_day

	for i in range(7):
		var entry: Dictionary = {}
		if i < forecast_data.size():
			entry = forecast_data[i]
		else:
			entry = {
				"day": i + 1,
				"target_day": cur_day + i + 1,
				"temperature": 28.0,
				"humidity": 0.65,
				"rainfall": 5.0,
				"hazard": "clear",
				"accuracy": 0.35,
				"required_tier": 3 if i >= 3 else (2 if i >= 1 else 1),
				"unlocked": false
			}

		var is_unlocked: bool = entry.get("unlocked", false)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(116, 168)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		card.add_child(margin)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 3)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(card_vbox)

		var day_offset: int = entry.get("day", i + 1)
		var target_day: int = entry.get("target_day", cur_day + day_offset)
		var day_header_str: String = "Day %d" % target_day
		if day_offset == 1:
			day_header_str = "Tomorrow"

		var day_lbl := Label.new()
		day_lbl.text = day_header_str
		day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_lbl.add_theme_font_size_override("font_size", 12)

		if is_unlocked:
			card.add_theme_stylebox_override("panel", STYLE_SAMPLEBOX)
			day_lbl.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
			card_vbox.add_child(day_lbl)

			var f_temp: float = float(entry.get("temperature", 28.0))
			var f_hum: float  = float(entry.get("humidity", 0.65))
			var f_rain: float = float(entry.get("rainfall", 5.0))
			var f_haz: String = str(entry.get("hazard", "clear"))

			# Forecast weather icon
			var f_icon := TextureRect.new()
			f_icon.texture = _get_weather_icon(WeatherManager.current_climate, f_haz, f_temp, f_rain)
			f_icon.custom_minimum_size = Vector2(36, 36)
			f_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			f_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			card_vbox.add_child(f_icon)

			# Temperature
			var temp_lbl := Label.new()
			temp_lbl.text = "%.0f°C" % f_temp
			temp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			temp_lbl.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
			temp_lbl.add_theme_font_size_override("font_size", 13)
			card_vbox.add_child(temp_lbl)

			# Moisture index
			var hum_lbl := Label.new()
			hum_lbl.text = "💧 %.0f%%" % (f_hum * 100.0)
			hum_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hum_lbl.add_theme_color_override("font_color", Color(0.12, 0.40, 0.65, 1.0))
			hum_lbl.add_theme_font_size_override("font_size", 11)
			card_vbox.add_child(hum_lbl)

			# Hazard Tag Pill
			var haz_pill := PanelContainer.new()
			haz_pill.add_theme_stylebox_override("panel", STYLE_BROWN_BOX)
			var haz_lbl := Label.new()
			haz_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			haz_lbl.add_theme_font_size_override("font_size", 10)

			match f_haz:
				"flash_flood":
					haz_lbl.text = "⚠️ Flood"
					haz_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 1.0))
				"el_nino_drought":
					haz_lbl.text = "🔥 Drought"
					haz_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25, 1.0))
				"landslide":
					haz_lbl.text = "⛰️ Slide"
					haz_lbl.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45, 1.0))
				_:
					haz_lbl.text = "✅ Clear"
					haz_lbl.add_theme_color_override("font_color", Color(0.40, 0.85, 0.45, 1.0))

			haz_pill.add_child(haz_lbl)
			card_vbox.add_child(haz_pill)

			# Action tip tooltip
			var advice_tip: String = WeatherManager.get_hazard_advice(f_haz, WeatherManager.current_climate)
			card.tooltip_text = "%s (Day %d)\nPredicted Temp: %.1f°C • Moisture: %.0f%%\nRainfall: %.1f mm • Hazard: %s\nAgronomic Advice: %s" % [
				day_header_str, target_day, f_temp, f_hum * 100.0, f_rain, WeatherManager.get_hazard_display_name(f_haz), advice_tip
			]

		else:
			# Locked / Radar out-of-range card (sleek, subtle radar slot)
			var locked_style := StyleBoxFlat.new()
			locked_style.bg_color = Color(0.18, 0.12, 0.08, 0.65)
			locked_style.border_color = Color(0.40, 0.28, 0.18, 0.45)
			locked_style.border_width_left = 1; locked_style.border_width_top = 1
			locked_style.border_width_right = 1; locked_style.border_width_bottom = 1
			locked_style.corner_radius_top_left = 4; locked_style.corner_radius_top_right = 4
			locked_style.corner_radius_bottom_left = 4; locked_style.corner_radius_bottom_right = 4
			card.add_theme_stylebox_override("panel", locked_style)

			day_lbl.add_theme_color_override("font_color", Color(0.80, 0.74, 0.65, 0.9))
			card_vbox.add_child(day_lbl)

			var lock_lbl := Label.new()
			lock_lbl.text = "🔒"
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.add_theme_font_size_override("font_size", 20)
			card_vbox.add_child(lock_lbl)

			var req_tier: int = int(entry.get("required_tier", 2))
			var tier_badge := PanelContainer.new()
			var tb_style := StyleBoxFlat.new()
			tb_style.bg_color = Color(0.28, 0.18, 0.10, 0.9)
			tb_style.border_color = Color(0.55, 0.42, 0.25, 0.6)
			tb_style.border_width_left = 1; tb_style.border_width_top = 1
			tb_style.border_width_right = 1; tb_style.border_width_bottom = 1
			tb_style.corner_radius_top_left = 3; tb_style.corner_radius_top_right = 3
			tb_style.corner_radius_bottom_left = 3; tb_style.corner_radius_bottom_right = 3
			tb_style.content_margin_left = 4; tb_style.content_margin_right = 4
			tb_style.content_margin_top = 2; tb_style.content_margin_bottom = 2
			tier_badge.add_theme_stylebox_override("panel", tb_style)

			var req_lbl := Label.new()
			req_lbl.text = "AWS Lv.2" if req_tier == 2 else "Satellite Lv.3"
			req_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			req_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 1.0))
			req_lbl.add_theme_font_size_override("font_size", 10)
			tier_badge.add_child(req_lbl)
			card_vbox.add_child(tier_badge)

			var teaser_lbl := Label.new()
			teaser_lbl.text = "Radar Locked"
			teaser_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			teaser_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55, 0.75))
			teaser_lbl.add_theme_font_size_override("font_size", 9)
			card_vbox.add_child(teaser_lbl)

			card.tooltip_text = "Forecast out of radar range.\nUpgrade your Weather Station to unlock %s telemetry!" % ("AWS Lv.2" if req_tier == 2 else "Satellite Uplink Lv.3")

		_forecast_cards_hbox.add_child(card)

func _update_footer_buttons() -> void:
	if not is_instance_valid(current_building):
		# Almanac mode (no active building)
		var ws = BuildingManager.get_weather_station()
		if ws != null:
			current_building = ws
			_update_footer_buttons()
			return

		_footer_station_info_label.text = "📜 Almanac Mode Active (Lv. 0)"
		_footer_perks_label.text = "Build a Weather Station in Agri-Shop (₱450) to unlock 7-Day Radar & 90% Accuracy!"
		_footer_perks_label.add_theme_color_override("font_color", Color(0.38, 0.25, 0.10, 1.0))
		_upgrade_btn.visible = false
		_demolish_btn.visible = false
		_progress_box.visible = false
		return

	_upgrade_btn.visible = true
	_demolish_btn.visible = true

	var lvl: int = current_building.level
	var max_lvl: int = current_building.max_level
	var b_data := Data.get_building(current_building.building_type)
	var tier_name := BuildingManager.get_weather_station_tier_name()

	var stars := ""
	for s in range(lvl):
		stars += "⭐"

	match current_building.state:
		current_building.BuildingState.CONSTRUCTING:
			_footer_station_info_label.text = "%s Construction (Level 1 / %d)" % [stars, max_lvl]
			_footer_perks_label.text = "Calibrating atmospheric barometers & radio antenna..."
			_progress_box.visible = true
			_upgrade_btn.disabled = true
			_demolish_btn.disabled = false
		current_building.BuildingState.UPGRADING:
			_footer_station_info_label.text = "%s Upgrading to Tier %d..." % [stars, lvl + 1]
			_footer_perks_label.text = "Installing high-gain telemetry sensors & telemetry dishes..."
			_progress_box.visible = true
			_upgrade_btn.disabled = true
			_demolish_btn.disabled = false
		current_building.BuildingState.ACTIVE:
			_footer_station_info_label.text = "%s %s (Level %d / %d) • ✅ Active" % [stars, tier_name, lvl, max_lvl]
			_progress_box.visible = false
			_demolish_btn.disabled = false

			if lvl < max_lvl:
				var next_cost: int = BuildingManager.get_upgrade_cost(current_building.building_type, lvl)
				var perks_desc: String = BuildingManager.get_weather_station_upgrade_perks(lvl + 1)
				_footer_perks_label.text = "Next Tier: %s" % perks_desc
				_upgrade_btn.text = "⬆️ Upgrade to Lv.%d (₱%d)" % [lvl + 1, next_cost]
				_upgrade_btn.disabled = (EconomyManager.cash < next_cost)
			else:
				_footer_perks_label.text = "🏆 Maximum Telemetry Reached (100% Precision Radar • 7-Day Horizon • 18s Lead Time)"
				_upgrade_btn.text = "Max Level ✔"
				_upgrade_btn.disabled = true

	var base_cost: int = int(b_data.get("cost", 450))
	var refund: int = int(base_cost * 0.5 * lvl)
	_demolish_btn.text = "🗑️ Demolish (+₱%d)" % refund

func _update_progress_display() -> void:
	if not is_instance_valid(current_building) or not _progress_box.visible:
		return
	var rem: float = maxf(0.0, current_building.duration - current_building.progress_timer)
	var ratio: float = 0.0
	if current_building.duration > 0.0:
		ratio = clampf(current_building.progress_timer / current_building.duration, 0.0, 1.0)
	_progress_bar.value = ratio * 100.0

	if current_building.state == current_building.BuildingState.CONSTRUCTING:
		_progress_label.text = "🔨 Assembling Weather Station... %.0fs remaining" % ceil(rem)
	elif current_building.state == current_building.BuildingState.UPGRADING:
		_progress_label.text = "⚡ Upgrading Telemetry Array to Lv.%d... %.0fs remaining" % [current_building.level + 1, ceil(rem)]

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

func _get_weather_icon(climate: int, hazard: String, temp: float, rain: float) -> Texture2D:
	if hazard == "flash_flood":
		return FLOOD_WAVE_ICON
	if hazard == "landslide":
		return WARNING_ICON
	if hazard == "el_nino_drought" or temp >= 34.0 or climate == WeatherManager.Climate.EL_NINO:
		return TEMP_FIRE_ICON
	if rain >= 25.0 or climate == WeatherManager.Climate.LA_NINA:
		return RAIN_ICON
	if rain >= 8.0:
		return CLOUD_ICON
	if temp >= 29.0:
		return TEMP_SUNNY_ICON
	if temp >= 23.0:
		return TEMP_JUST_RIGHT_ICON
	return TEMP_COLD_ICON

static func get_temperature_icon(temp: float, climate: int = 0) -> Texture2D:
	if climate == WeatherManager.Climate.EL_NINO or temp >= 34.0:
		return TEMP_FIRE_ICON
	elif temp >= 29.0:
		return TEMP_SUNNY_ICON
	elif temp >= 23.0:
		return TEMP_JUST_RIGHT_ICON
	else:
		return TEMP_COLD_ICON
