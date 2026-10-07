# HUD.gd
# Dynamic and fully decoupled HUD controller.
# Automatically locates all UI elements anywhere in the scene hierarchy by name,
# allowing the player / designer to freely move, reparent, and style widgets on the canvas.
extends CanvasLayer

const SeasonResultsModalScript = preload("res://src/ui/SeasonResultsModal.gd")
const SUN_ICON = preload("res://assets/icons/Topleft/Sun.png")
const MOON_ICON = preload("res://assets/icons/Topleft/Moon.png")

var region_weather_box: Control = null
var region_capsule: Node = null
var region_label: Label = null
var weather_label: Label = null
var humidity_label: Label = null

var day_night_box: Control = null
var day_label: Label = null
var time_icon: TextureRect = null
var time_label: Label = null
var disaster_label: Label = null

var disaster_box: Control = null
var disaster_box_title: Label = null
var disaster_box_sub: Label = null
var _disaster_fade_tween: Tween = null

const STYLE_TOPBAR_BROWN: StyleBox  = preload("res://assets/sprites/hud/TopBar/Button/TopBarButtonBrown.tres")
const STYLE_TOPBAR_YELLOW: StyleBox = preload("res://assets/sprites/hud/TopBar/Button/TopBarButtonYellow.tres")
const STYLE_TOPBAR_HOVER: StyleBox  = preload("res://assets/sprites/hud/TopBar/Button/TopBarButtonHover.tres")

var _drag_states: Dictionary = {}

var pause_btn: Button = null
var speed1_btn: Button = null
var speed2_btn: Button = null
var speed3_btn: Button = null

var worker_label: Label = null
var storage_label: Label = null
var storage_bar: ProgressBar = null
var cash_label: Label = null
var task_label: Label = null

var region_hover_card: Node = null
var hover_title: Label = null
var hover_desc: Label = null
var hover_pros: Label = null
var hover_cons: Label = null

var market_btn: Button = null
var sell_btn: Button = null
var shop_btn: Button = null
var settings_btn: Button = null
var log_btn: Button = null
var leaderboard_btn: Button = null

var points_label: Label = null

var market_panel: Node = null
var sell_panel: Node = null
var shop_panel: Node = null
var tile_info_panel: Node = null
var plant_hotbar: Control = null
var _disaster_timer: float = 0.0

var _disaster_banner: PanelContainer = null
var _disaster_banner_title: Label = null
var _disaster_banner_sub: Label = null
var _disaster_countdown_remaining: float = 0.0
var _active_disaster_name: String = ""
var _is_counting_down: bool = false

func _ready() -> void:
	_discover_nodes()

	# Connect autoload signals
	EconomyManager.cash_changed.connect(_on_cash_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.period_changed.connect(func(_p, _n): _update_time_weather_display())
	TimeManager.season_ended.connect(_on_season_ended)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	WeatherManager.disaster_warning.connect(_on_disaster_warning)
	WeatherManager.disaster_struck.connect(_on_disaster_struck)
	WeatherManager.disaster_cleared.connect(_on_disaster_cleared)

	BuildingManager.storage_updated.connect(func(_c, _u): _refresh_storage_display())
	BuildingManager.worker_hired.connect(func(_w): _refresh_workers_display())
	BuildingManager.worker_capacity_changed.connect(func(_c, _a): _refresh_workers_display())
	BuildingManager.weather_station_updated.connect(func(_lvl): _update_time_weather_display())
	BuildingManager.building_purchased.connect(func(_b): 
		_refresh_storage_display()
		_refresh_workers_display()
	)
	MarketManager.inventory_changed.connect(_refresh_storage_display)

	# Speed button signals
	if pause_btn and not pause_btn.pressed.is_connected(_on_pause_pressed):
		pause_btn.pressed.connect(_on_pause_pressed)
	if speed1_btn and not speed1_btn.pressed.is_connected(_on_1x_pressed):
		speed1_btn.pressed.connect(_on_1x_pressed)
	if speed2_btn and not speed2_btn.pressed.is_connected(_on_2x_pressed):
		speed2_btn.pressed.connect(_on_2x_pressed)
	if speed3_btn and not speed3_btn.pressed.is_connected(_on_3x_pressed):
		speed3_btn.pressed.connect(_on_3x_pressed)

	# Command corner buttons
	if market_btn and not market_btn.pressed.is_connected(_on_market_toggle_pressed):
		market_btn.pressed.connect(_on_market_toggle_pressed)
	if sell_btn and not sell_btn.pressed.is_connected(_on_sell_toggle_pressed):
		sell_btn.pressed.connect(_on_sell_toggle_pressed)
	if shop_btn and not shop_btn.pressed.is_connected(_on_shop_toggle_pressed):
		shop_btn.pressed.connect(_on_shop_toggle_pressed)

	if shop_panel and shop_panel.has_signal("worker_spawn_requested"):
		if not shop_panel.worker_spawn_requested.is_connected(_on_worker_spawn_requested):
			shop_panel.worker_spawn_requested.connect(_on_worker_spawn_requested)

	# Region hover connections & input forwarding
	if region_capsule:
		if not region_capsule.mouse_entered.is_connected(_on_region_hover_entered):
			region_capsule.mouse_entered.connect(_on_region_hover_entered)
		if not region_capsule.mouse_exited.is_connected(_on_region_hover_exited):
			region_capsule.mouse_exited.connect(_on_region_hover_exited)
		if region_capsule is Control and region_weather_box:
			region_capsule.gui_input.connect(func(ev: InputEvent):
				_handle_box_gui_input(region_weather_box, ev)
			)

	# Setup draggable top-left boxes with runtime font adjustments
	_setup_draggable_hud_box(region_weather_box, ["RegionLabel", "WeatherLabel", "HumidityLabel"], Vector2(16, 8))
	_setup_draggable_hud_box(day_night_box, ["DayLabel", "TimeLabel"], Vector2(226, -2))
	if disaster_box:
		_setup_draggable_hud_box(disaster_box, ["TitleLabel", "SubLabel"], Vector2(0, 48))

	_update_speed_buttons_visual()
	_update_climate_disaster_box()

	# Initial values
	_on_cash_changed(EconomyManager.cash)
	_on_day_changed(TimeManager.current_day)
	_on_hour_changed(TimeManager.current_hour)
	_on_weather_changed(WeatherManager.temperature, WeatherManager.humidity)
	_refresh_storage_display()
	_refresh_workers_display()
	_update_region_display()

	if disaster_label:
		disaster_label.text = ""
	if task_label:
		task_label.text = "📋 0"

	_setup_disaster_banner()
	TaskManager.selection_changed.connect(_on_worker_selection_changed)

	_setup_menu_button()
	_setup_log_button()
	_setup_leaderboard_button()

	if LeaderboardManager.has_signal("points_changed"):
		LeaderboardManager.points_changed.connect(_on_points_changed)
	if LeaderboardManager.has_signal("new_personal_best"):
		LeaderboardManager.new_personal_best.connect(func(_nb, _ob): _update_points_display())

	_update_points_display()

	if market_panel:
		market_panel.visible = false
	if shop_panel:
		shop_panel.visible = false
	if region_hover_card:
		region_hover_card.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return

		if event.keycode == KEY_B or event.keycode == KEY_P:
			_on_shop_toggle_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			_on_market_toggle_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_K:
			_on_sell_toggle_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_J or event.keycode == KEY_T:
			_on_leaderboard_toggle_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			var handled_modal: bool = false
			if (shop_panel and shop_panel.visible) or (market_panel and market_panel.visible) or (sell_panel and sell_panel.visible):
				if shop_panel:
					shop_panel.visible = false
				if market_panel:
					market_panel.visible = false
				if sell_panel:
					sell_panel.visible = false
				handled_modal = true
			if handled_modal:
				get_viewport().set_input_as_handled()
			else:
				var pm: Node = get_tree().root.find_child("PauseMenu", true, false)
				if pm and pm.has_method("toggle"):
					pm.toggle()
					get_viewport().set_input_as_handled()

## Recursively discovers all UI nodes by name anywhere in HUDLayer
func _discover_nodes() -> void:
	region_weather_box = find_child("RegionWeatherBox", true, false) as Control
	region_capsule    = find_child("RegionCapsule", true, false)
	region_label      = find_child("RegionLabel", true, false) as Label
	weather_label     = find_child("WeatherLabel", true, false) as Label
	humidity_label    = find_child("HumidityLabel", true, false) as Label

	day_night_box     = find_child("DayNightBox", true, false) as Control
	day_label         = find_child("DayLabel", true, false) as Label
	time_icon         = find_child("TimeIcon", true, false) as TextureRect
	time_label        = find_child("TimeLabel", true, false) as Label
	disaster_label    = find_child("DisasterLabel", true, false) as Label

	disaster_box       = find_child("DisasterBox", true, false) as Control
	if disaster_box:
		disaster_box_title = disaster_box.find_child("TitleLabel", true, false) as Label
		disaster_box_sub   = disaster_box.find_child("SubLabel", true, false) as Label

	pause_btn         = find_child("PauseButton", true, false) as Button
	speed1_btn        = find_child("Speed1xButton", true, false) as Button
	speed2_btn        = find_child("Speed2xButton", true, false) as Button
	speed3_btn        = find_child("Speed3xButton", true, false) as Button

	worker_label      = find_child("WorkerLabel", true, false) as Label
	storage_label     = find_child("StorageLabel", true, false) as Label
	storage_bar       = find_child("StorageBar", true, false) as ProgressBar
	cash_label        = find_child("CashLabel", true, false) as Label
	task_label        = find_child("TaskLabel", true, false) as Label

	region_hover_card = find_child("RegionHoverCard", true, false)
	if region_hover_card:
		hover_title   = region_hover_card.find_child("TitleLabel", true, false) as Label
		hover_desc    = region_hover_card.find_child("DescLabel", true, false) as Label
		hover_pros    = region_hover_card.find_child("ProsLabel", true, false) as Label
		hover_cons    = region_hover_card.find_child("ConsLabel", true, false) as Label

	market_btn        = find_child("MarketButton", true, false) as Button
	sell_btn          = find_child("SellButton", true, false) as Button
	shop_btn          = find_child("ShopButton", true, false) as Button

	market_panel      = find_child("MarketPanel", true, false)
	sell_panel        = find_child("SellPanel", true, false)
	shop_panel        = find_child("ShopPanel", true, false)
	tile_info_panel   = find_child("TileInfoPanel", true, false)
	plant_hotbar      = find_child("PlantHotbar", true, false) as Control

	# Check if the user placed a settings or menu button in the scene
	settings_btn      = find_child("SettingsButton", true, false) as Button
	if not settings_btn:
		settings_btn  = find_child("MenuButton", true, false) as Button

	log_btn           = find_child("LogButton", true, false) as Button
	if not log_btn:
		log_btn       = find_child("BacklogButton", true, false) as Button

	leaderboard_btn   = find_child("LeaderboardButton", true, false) as Button
	points_label      = find_child("PointsLabel", true, false) as Label

func _process(delta: float) -> void:
	if _disaster_timer > 0.0:
		_disaster_timer -= delta
		if _disaster_timer <= 0.0 and disaster_label:
			disaster_label.text = ""

	if _is_counting_down:
		var scale: float = TimeManager.get_speed_scale()
		if scale > 0.0:
			_disaster_countdown_remaining = maxf(_disaster_countdown_remaining - delta * scale, 0.0)
			var hazard_title: String = _active_disaster_name.replace("_", " ").to_upper()
			if _disaster_banner and _disaster_banner.visible and _disaster_banner_title:
				_disaster_banner_title.text = "⚠️ INCOMING HAZARD: %s (%.1fs)" % [hazard_title, _disaster_countdown_remaining]
			if disaster_box and disaster_box.visible and disaster_box_title:
				disaster_box_title.text = "⚠️ %s (%.1fs)" % [hazard_title, _disaster_countdown_remaining]

	if task_label:
		task_label.text = "Tasks: %d" % TaskManager.get_task_count()

func _update_region_display() -> void:
	if region_label == null:
		return
	var reg_data: Dictionary = Data.get_region(Data.current_region)
	var full_name: String = reg_data.get("display_name", Data.current_region.capitalize())
	var short_name: String = full_name.split("(")[0].strip_edges()
	region_label.text = short_name

func _on_region_hover_entered() -> void:
	if not region_hover_card:
		return
	if _drag_states.has(region_weather_box) and _drag_states[region_weather_box].get("dragging", false):
		return
	if region_weather_box:
		var target_x: float = clampf(region_weather_box.position.x, 8.0, 1280.0 - region_hover_card.size.x - 8.0)
		var target_y: float = clampf(region_weather_box.position.y + region_weather_box.size.y + 6.0, 8.0, 720.0 - region_hover_card.size.y - 8.0)
		region_hover_card.position = Vector2(target_x, target_y)

	var reg_data: Dictionary = Data.get_region(Data.current_region)
	if hover_title:
		hover_title.text = "Region: %s" % reg_data.get("display_name", "")
	if hover_desc:
		hover_desc.text = "%s\nSpecialty: %s" % [reg_data.get("description", ""), reg_data.get("specialty", "")]

	var pros_arr: Array = reg_data.get("pros", [])
	var pros_str: String = "PROS & ADVANTAGES:\n"
	for p in pros_arr:
		pros_str += "  • %s\n" % p
	if hover_pros:
		hover_pros.text = pros_str.strip_edges()

	var cons_arr: Array = reg_data.get("cons", [])
	var cons_str: String = "CONS & RISKS:\n"
	for c in cons_arr:
		cons_str += "  • %s\n" % c

	# Append Telemetry Equipment & Forecast Status
	var t_name: String = BuildingManager.get_weather_station_tier_name() if BuildingManager.has_method("get_weather_station_tier_name") else "Farmer Almanac"
	var acc: int = int(round(BuildingManager.get_forecast_accuracy() * 100.0)) if BuildingManager.has_method("get_forecast_accuracy") else 35
	var warn_s: int = int(round(BuildingManager.get_disaster_warning_time())) if BuildingManager.has_method("get_disaster_warning_time") else 5
	var f_days: int = BuildingManager.get_forecast_days() if BuildingManager.has_method("get_forecast_days") else 0
	var f_desc: String = ("%d Days Ahead" % f_days) if f_days > 0 else "Today only"
	cons_str += "\n📡 WEATHER TELEMETRY: %s\n  • Accuracy: %d%% • Radar: %s • Disaster Lead Time: %ds" % [t_name, acc, f_desc, warn_s]

	if hover_cons:
		hover_cons.text = cons_str.strip_edges()

	region_hover_card.visible = true

func _on_region_hover_exited() -> void:
	if region_hover_card:
		region_hover_card.visible = false

func _on_cash_changed(amount: int) -> void:
	if cash_label:
		cash_label.text = "₱%s" % Utils.format_number(amount)

func _on_day_changed(day: int) -> void:
	if day_label:
		if TimeManager.is_freeplay_mode:
			day_label.text = "Day: %d" % day
			day_label.tooltip_text = "Freeplay Tycoon: Day %d" % day
		else:
			var target: int = Data.selected_season_days
			var left: int = maxi(target - day + 1, 0)
			day_label.text = "Day: %d/%d" % [day, target]
			day_label.tooltip_text = "Sprint Season: Day %d of %d (%d days left)" % [day, target, left]

func _on_season_ended(_target_days: int, _final_score: int) -> void:
	# Automatically save completed run into local records
	LeaderboardManager.save_current_run()

	# Spawn and display SeasonResultsModal
	var modal = SeasonResultsModalScript.new()
	get_tree().root.add_child(modal)

func _on_hour_changed(_hour: int) -> void:
	_update_time_weather_display()
	if task_label:
		task_label.text = "Tasks: %d" % TaskManager.get_task_count()
	_refresh_storage_display()

func _update_time_weather_display() -> void:
	if time_label:
		time_label.text = "%02d:00" % TimeManager.current_hour

	if time_icon:
		time_icon.texture = MOON_ICON if TimeManager.is_night() else SUN_ICON
		time_icon.tooltip_text = "%s (%s)" % [TimeManager.get_time_period_name(), "Night" if TimeManager.is_night() else "Day"]

	var eff_temp: float = WeatherManager.get_effective_temperature()
	var eff_hum: float = WeatherManager.get_effective_humidity()
	_on_weather_changed(eff_temp, eff_hum)

func _on_weather_changed(temp: float, hum: float) -> void:
	var climate_str: String = ""
	match WeatherManager.current_climate:
		WeatherManager.Climate.EL_NINO: climate_str = " (El Nino)"
		WeatherManager.Climate.LA_NINA: climate_str = " (La Nina)"
		WeatherManager.Climate.NORMAL:  climate_str = ""

	var t_name: String = BuildingManager.get_weather_station_tier_name() if BuildingManager.has_method("get_weather_station_tier_name") else "Farmer Almanac"
	var acc: int = int(round(BuildingManager.get_forecast_accuracy() * 100.0)) if BuildingManager.has_method("get_forecast_accuracy") else 35

	if weather_label and humidity_label:
		if WeatherManager.current_climate == WeatherManager.Climate.LA_NINA:
			weather_label.text = "🌧️ %.0f°C" % temp
			weather_label.tooltip_text = "Climate: La Niña Monsoon • Ambient Temp: %.1f°C\nTelemetry: %s (%d%% Accuracy)" % [temp, t_name, acc]
		elif WeatherManager.current_climate == WeatherManager.Climate.EL_NINO:
			weather_label.text = "☀️ %.0f°C" % temp
			weather_label.tooltip_text = "Climate: El Niño Drought • Ambient Temp: %.1f°C\nTelemetry: %s (%d%% Accuracy)" % [temp, t_name, acc]
		var irr_info: String = ""
		if BuildingManager.has_method("has_irrigation") and BuildingManager.has_irrigation():
			irr_info = "\nIrrigation System: %s (Evaporation Shield: -%d%%)" % [
				BuildingManager.get_irrigation_tier_name(),
				int(BuildingManager.get_irrigation_evap_reduction() * 100.0)
			]
		humidity_label.text = "💧 %.0f%%" % (hum * 100.0)
		humidity_label.tooltip_text = "Relative Humidity: %.0f%%%s%s" % [hum * 100.0, climate_str, irr_info]
	elif weather_label:
		weather_label.text = "%.0f°C  %.0f%%" % [temp, hum * 100.0]

	_update_climate_disaster_box()

func _update_climate_disaster_box() -> void:
	if not disaster_box:
		return

	# If an incoming emergency countdown or strike is processing, let disaster warnings take precedence
	if _is_counting_down or WeatherManager.active_disaster != "":
		return

	# Display regional climate phenomena (La Niña / El Niño) in the middle DisasterBox
	match WeatherManager.current_climate:
		WeatherManager.Climate.LA_NINA:
			disaster_box.visible = true
			if disaster_box_title:
				disaster_box_title.text = "🌧️ LA NIÑA"
				disaster_box_title.add_theme_color_override("font_color", Color(0.18, 0.42, 0.85, 1.0))
			if disaster_box_sub:
				disaster_box_sub.text = "Monsoon climate • Flooding & rot risk elevated"
				disaster_box_sub.add_theme_color_override("font_color", Color(0.26, 0.16, 0.10, 1.0))

			if _disaster_fade_tween and _disaster_fade_tween.is_valid():
				_disaster_fade_tween.kill()
			_disaster_fade_tween = create_tween()
			_disaster_fade_tween.tween_property(disaster_box, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		WeatherManager.Climate.EL_NINO:
			disaster_box.visible = true
			if disaster_box_title:
				disaster_box_title.text = "☀️ EL NIÑO"
				disaster_box_title.add_theme_color_override("font_color", Color(0.85, 0.40, 0.12, 1.0))
			if disaster_box_sub:
				disaster_box_sub.text = "Drought heatwave • Water thirsty crops regularly"
				disaster_box_sub.add_theme_color_override("font_color", Color(0.26, 0.16, 0.10, 1.0))

			if _disaster_fade_tween and _disaster_fade_tween.is_valid():
				_disaster_fade_tween.kill()
			_disaster_fade_tween = create_tween()
			_disaster_fade_tween.tween_property(disaster_box, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		WeatherManager.Climate.NORMAL:
			# Normal tropical climate: smoothly fade out DisasterBox if currently visible
			if disaster_box.visible and disaster_box.modulate.a > 0.0:
				if _disaster_fade_tween and _disaster_fade_tween.is_valid():
					_disaster_fade_tween.kill()
				_disaster_fade_tween = create_tween()
				_disaster_fade_tween.tween_property(disaster_box, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				_disaster_fade_tween.tween_callback(func():
					if is_instance_valid(disaster_box) and not _is_counting_down and WeatherManager.current_climate == WeatherManager.Climate.NORMAL and WeatherManager.active_disaster == "":
						disaster_box.visible = false
				)
			else:
				disaster_box.visible = false
				disaster_box.modulate.a = 0.0

func _refresh_storage_display(_c: int = 0, _u: int = 0) -> void:
	var status: Dictionary = BuildingManager.get_storage_status()
	if storage_label:
		storage_label.text = "%d/%d" % [status.used, status.capacity]
		storage_label.tooltip_text = "Farm Storage: %d / %d units stored" % [status.used, status.capacity]
		if status.used >= status.capacity:
			storage_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35, 1.0))
		elif float(status.used) / maxf(float(status.capacity), 1.0) >= 0.85:
			storage_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3, 1.0))
		else:
			storage_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	if storage_bar:
		storage_bar.max_value = status.capacity
		storage_bar.value     = status.used

func _on_worker_selection_changed(_selected_workers: Array) -> void:
	_refresh_workers_display()

func _refresh_workers_display() -> void:
	if worker_label:
		var sel_count: int = TaskManager.get_selected_farmers().size()
		if sel_count > 0:
			worker_label.text = "%d/%d (⭐%d)" % [BuildingManager.active_workers, BuildingManager.worker_capacity, sel_count]
		else:
			worker_label.text = "%d/%d" % [BuildingManager.active_workers, BuildingManager.worker_capacity]
		worker_label.tooltip_text = "Active Labor: %d / %d workers\nMechanized Fleet: %s\nTravel & Work Speed: %.1fx" % [
			BuildingManager.active_workers,
			BuildingManager.worker_capacity,
			BuildingManager.get_machinery_tier_name(),
			BuildingManager.get_worker_speed_multiplier()
		]

func _setup_disaster_banner() -> void:
	_disaster_banner = PanelContainer.new()
	_disaster_banner.name = "DisasterAlertBanner"
	_disaster_banner.visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.04, 0.04, 0.95)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.25, 0.25, 0.95)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_size = 10
	sb.shadow_color = Color(0, 0, 0, 0.6)
	_disaster_banner.add_theme_stylebox_override("panel", sb)

	_disaster_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_disaster_banner.offset_left   = 320
	_disaster_banner.offset_right  = -320
	_disaster_banner.offset_top    = 52
	_disaster_banner.offset_bottom = 106
	_disaster_banner.z_index       = 160

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_disaster_banner.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	_disaster_banner_title = Label.new()
	_disaster_banner_title.text = ""
	_disaster_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disaster_banner_title.add_theme_font_size_override("font_size", 13)
	_disaster_banner_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	vbox.add_child(_disaster_banner_title)

	_disaster_banner_sub = Label.new()
	_disaster_banner_sub.text = ""
	_disaster_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disaster_banner_sub.add_theme_font_size_override("font_size", 10)
	_disaster_banner_sub.add_theme_color_override("font_color", Color(1.0, 0.90, 0.80, 0.95))
	vbox.add_child(_disaster_banner_sub)

	var ctrl: Control = find_child("Control", true, false) as Control
	if ctrl:
		ctrl.add_child(_disaster_banner)

func _on_disaster_warning(hazard_type: String, countdown_seconds: float = 5.0) -> void:
	var hazard_title: String = hazard_type.replace("_", " ").to_upper()
	if disaster_label:
		disaster_label.text = "⚠️ ALERT: %s!" % hazard_title
		disaster_label.modulate = Color(1.0, 0.25, 0.25)
	_disaster_timer = countdown_seconds + 5.0

	_active_disaster_name = hazard_type
	_disaster_countdown_remaining = countdown_seconds
	_is_counting_down = true

	var sub_msg: String = ""
	match hazard_type:
		"flash_flood":
			sub_msg = "Flash flood imminent! Salvage ripe crops or pause to strategize!"
		"el_nino_drought":
			sub_msg = "Scorching heatwave incoming! Water thirsty crops before drought strikes!"
		"landslide":
			sub_msg = "Mud & rockslide incoming! Outer plots at risk of debris!"
		_:
			sub_msg = "Extreme hazard approaching! Prepare your farm!"

	if _disaster_banner:
		_disaster_banner.visible = true
		_disaster_banner.modulate.a = 1.0
		_disaster_banner_title.text = "⚠️ INCOMING HAZARD: %s (%.1fs)" % [hazard_title, countdown_seconds]
		_disaster_banner_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_disaster_banner_sub.text = sub_msg

	# Smoothly fade in the parchment DisasterBox
	if disaster_box:
		disaster_box.visible = true
		if disaster_box_title:
			disaster_box_title.text = "⚠️ %s (%.1fs)" % [hazard_title, countdown_seconds]
			disaster_box_title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
		if disaster_box_sub:
			disaster_box_sub.text = sub_msg

		if _disaster_fade_tween and _disaster_fade_tween.is_valid():
			_disaster_fade_tween.kill()
		_disaster_fade_tween = create_tween()
		_disaster_fade_tween.tween_property(disaster_box, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_disaster_struck(hazard_type: String) -> void:
	_is_counting_down = false
	var hazard_title: String = hazard_type.replace("_", " ").to_upper()
	if _disaster_banner:
		_disaster_banner.visible = true
		_disaster_banner.modulate.a = 1.0
		_disaster_banner_title.text = "🌊 IMPACT: %s STRIKES!" % hazard_title
		_disaster_banner_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_disaster_banner_sub.text = "Disaster swept the grid! Calculating crop survival..."
		var tw := create_tween()
		tw.tween_interval(3.5)
		tw.tween_property(_disaster_banner, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func():
			if not _is_counting_down and is_instance_valid(_disaster_banner):
				_disaster_banner.visible = false
				_disaster_banner.modulate.a = 1.0
		)

	if disaster_box:
		disaster_box.visible = true
		if disaster_box_title:
			disaster_box_title.text = "🌊 %s STRIKES!" % hazard_title
			disaster_box_title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.1))
		if disaster_box_sub:
			disaster_box_sub.text = "Disaster struck! Assessing farm impact..."

		if _disaster_fade_tween and _disaster_fade_tween.is_valid():
			_disaster_fade_tween.kill()
		_disaster_fade_tween = create_tween()
		_disaster_fade_tween.tween_interval(4.0)
		_disaster_fade_tween.tween_callback(func():
			if not _is_counting_down and is_instance_valid(disaster_box):
				_update_climate_disaster_box()
		)

func _on_disaster_cleared(_hazard_type: String) -> void:
	_is_counting_down = false
	if _disaster_banner:
		_disaster_banner.visible = false

	# After disaster clears, update disaster box to current climate state (or fade out if normal)
	_update_climate_disaster_box()

func _on_market_toggle_pressed() -> void:
	if market_panel:
		market_panel.visible = not market_panel.visible
		if market_panel.visible:
			if sell_panel:
				sell_panel.visible = false
			if shop_panel:
				shop_panel.visible = false
			if market_panel.has_method("refresh_all"):
				market_panel.refresh_all()

func _on_sell_toggle_pressed() -> void:
	if sell_panel:
		sell_panel.visible = not sell_panel.visible
		if sell_panel.visible:
			if market_panel:
				market_panel.visible = false
			if shop_panel:
				shop_panel.visible = false
			if sell_panel.has_method("_refresh_view"):
				sell_panel._refresh_view()

func _on_shop_toggle_pressed() -> void:
	if shop_panel:
		shop_panel.visible = not shop_panel.visible
		if shop_panel.visible:
			if market_panel:
				market_panel.visible = false
			if sell_panel:
				sell_panel.visible = false
			if shop_panel.has_method("refresh"):
				shop_panel.refresh()

func _on_worker_spawn_requested() -> void:
	var template: Node = get_tree().root.find_child("Farmer", true, false)
	var farmer: CharacterBody2D = null

	if template and is_instance_valid(template):
		farmer = template.duplicate() as CharacterBody2D
		farmer.name = "Farmer_%d" % BuildingManager.active_workers
		var depot_pos: Vector2 = FarmerMovement.grid_to_pixel_center(Vector2i(0, 0), null)
		farmer.position = depot_pos + Vector2(randf_range(-30, 30), randf_range(-15, 15))
		farmer.assigned_tasks = []
		farmer.current_task = {}
		farmer.is_selected = false
		farmer.state = FarmerStateMachine.WorkerState.IDLE
		get_parent().add_child(farmer)
	else:
		var farmer_script = load("res://src/farmer/Farmer.gd")
		farmer = CharacterBody2D.new()
		farmer.set_script(farmer_script)
		farmer.name = "Farmer_%d" % BuildingManager.active_workers
		var depot_pos: Vector2 = FarmerMovement.grid_to_pixel_center(Vector2i(0, 0), null)
		farmer.position = depot_pos + Vector2(randf_range(-30, 30), randf_range(-15, 15))

		var sprite = ColorRect.new()
		sprite.name = "FarmerSprite"
		sprite.offset_left = -16.0
		sprite.offset_top = -16.0
		sprite.offset_right = 16.0
		sprite.offset_bottom = 16.0
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.color = Color(0.35, 0.70, 0.95, 1.0)
		farmer.add_child(sprite)

		var label = Label.new()
		label.name = "FarmerLabel"
		label.offset_left = -60.0
		label.offset_top = -36.0
		label.offset_right = 60.0
		label.offset_bottom = -13.0
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "🧑‍🌾 Ready"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		farmer.add_child(label)

		get_parent().add_child(farmer)

	_refresh_workers_display()

func _on_pause_pressed() -> void:
	TimeManager.set_speed_mode(TimeManager.Speed.PAUSE)
	_update_speed_buttons_visual()
	AudioManager.play_ui("pause")

func _on_1x_pressed() -> void:
	TimeManager.set_speed_mode(TimeManager.Speed.ONE_X)
	_update_speed_buttons_visual()

func _on_2x_pressed() -> void:
	TimeManager.set_speed_mode(TimeManager.Speed.TWO_X)
	_update_speed_buttons_visual()

func _on_3x_pressed() -> void:
	TimeManager.set_speed_mode(TimeManager.Speed.THREE_X)
	_update_speed_buttons_visual()

func _update_speed_buttons_visual() -> void:
	var scale: float = TimeManager.get_speed_scale()
	var is_paused: bool = (scale == 0.0)
	var is_1x: bool     = (scale > 0.0 and scale <= 1.0)
	var is_2x: bool     = (scale > 1.0 and scale <= 2.0)
	var is_3x: bool     = (scale > 2.0)

	_set_speed_btn_state(pause_btn, is_paused)
	_set_speed_btn_state(speed1_btn, is_1x)
	_set_speed_btn_state(speed2_btn, is_2x)
	_set_speed_btn_state(speed3_btn, is_3x)

func _set_speed_btn_state(btn: Button, active: bool) -> void:
	if btn == null:
		return
	if active:
		btn.add_theme_stylebox_override("normal", STYLE_TOPBAR_YELLOW)
		btn.add_theme_stylebox_override("hover", STYLE_TOPBAR_YELLOW)
		btn.add_theme_stylebox_override("pressed", STYLE_TOPBAR_YELLOW)
		btn.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.24, 0.14, 0.08, 1.0))
	else:
		btn.add_theme_stylebox_override("normal", STYLE_TOPBAR_BROWN)
		btn.add_theme_stylebox_override("hover", STYLE_TOPBAR_HOVER)
		btn.add_theme_stylebox_override("pressed", STYLE_TOPBAR_YELLOW)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95, 1.0))

func _setup_menu_button() -> void:
	if settings_btn:
		if not settings_btn.pressed.is_connected(_on_menu_toggle_pressed):
			settings_btn.pressed.connect(_on_menu_toggle_pressed)
	else:
		_inject_menu_button()

func _on_menu_toggle_pressed() -> void:
	var pm: Node = get_tree().root.find_child("PauseMenu", true, false)
	if pm and pm.has_method("toggle"):
		pm.toggle()

# Fallback menu icon button if no settings/menu button is found in the scene
func _inject_menu_button() -> void:
	var ctrl: Control = find_child("Control", true, false) as Control
	if ctrl == null:
		return

	var menu_btn := Button.new()
	menu_btn.name = "InjectedMenuButton"
	menu_btn.text = "≡"
	menu_btn.tooltip_text = "Menu (ESC)"
	menu_btn.flat = true
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.add_theme_color_override("font_color",          Color(0.85, 1.0, 0.55, 1.0))
	menu_btn.add_theme_color_override("font_hover_color",    Color(1.0,  1.0, 0.75, 1.0))
	menu_btn.add_theme_color_override("font_pressed_color",  Color(0.55, 0.85, 0.3,  1.0))
	menu_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left   = -48
	menu_btn.offset_top    = 6
	menu_btn.offset_right  = -6
	menu_btn.offset_bottom = 42
	menu_btn.z_index = 10
	menu_btn.mouse_filter  = Control.MOUSE_FILTER_STOP
	ctrl.add_child(menu_btn)

	menu_btn.pressed.connect(_on_menu_toggle_pressed)

func _setup_log_button() -> void:
	if log_btn:
		if not log_btn.pressed.is_connected(_on_log_toggle_pressed):
			log_btn.pressed.connect(_on_log_toggle_pressed)

func _on_log_toggle_pressed() -> void:
	var panel = get_tree().get_first_node_in_group("backlog_panel")
	if panel and panel.has_method("toggle"):
		panel.toggle()

func _setup_leaderboard_button() -> void:
	if leaderboard_btn:
		if not leaderboard_btn.pressed.is_connected(_on_leaderboard_toggle_pressed):
			leaderboard_btn.pressed.connect(_on_leaderboard_toggle_pressed)

func _on_leaderboard_toggle_pressed() -> void:
	var panel = get_tree().get_first_node_in_group("leaderboard_panel")
	if panel and panel.has_method("toggle"):
		panel.toggle()

func _on_points_changed(_total_pts: int, _added: int, _reason: String) -> void:
	_update_points_display()

func _update_points_display() -> void:
	if points_label:
		var cur: int = LeaderboardManager.current_points
		var best: int = LeaderboardManager.get_personal_best()
		if best > 0:
			points_label.text = "🏆 %s pts (Best: %s)" % [Utils.format_number(cur), Utils.format_number(best)]
		else:
			points_label.text = "🏆 %s pts" % Utils.format_number(cur)

## Configures runtime dragging, double-click reset, and mouse wheel font sizing for HUD boxes
func _setup_draggable_hud_box(box: Control, label_names: Array[String], default_pos: Vector2) -> void:
	if not box:
		return
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = "Drag to reposition • Mouse Wheel to scale font • Double-click to reset"

	var labels: Array[Label] = []
	var default_font_sizes: Dictionary = {}
	for l_name in label_names:
		var lbl: Label = box.find_child(l_name, true, false) as Label
		if lbl:
			labels.append(lbl)
			default_font_sizes[lbl] = lbl.get_theme_font_size("font_size")

	_drag_states[box] = {
		"dragging": false,
		"drag_start_mouse": Vector2.ZERO,
		"drag_start_box_pos": Vector2.ZERO,
		"labels": labels,
		"default_pos": default_pos,
		"default_font_sizes": default_font_sizes
	}

	box.gui_input.connect(func(event: InputEvent):
		_handle_box_gui_input(box, event)
	)

func _handle_box_gui_input(box: Control, event: InputEvent) -> void:
	if not _drag_states.has(box):
		return
	var state: Dictionary = _drag_states[box]

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				box.position = state.default_pos
				for lbl in state.labels:
					if state.default_font_sizes.has(lbl):
						lbl.add_theme_font_size_override("font_size", state.default_font_sizes[lbl])
				print("[HUD] %s reset to default position: %s" % [box.name, str(box.position)])
				box.accept_event()
				return

			if mb.pressed:
				state.dragging = true
				state.drag_start_mouse = box.get_global_mouse_position()
				state.drag_start_box_pos = box.position
				if region_hover_card and region_hover_card.visible:
					region_hover_card.visible = false
				box.accept_event()
			else:
				if state.dragging:
					state.dragging = false
					print("[HUD] %s moved to: Vector2(%.0f, %.0f)" % [box.name, box.position.x, box.position.y])
					box.accept_event()

		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var delta: int = 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			var info: Array[String] = []
			for lbl in state.labels:
				var cur: int = lbl.get_theme_font_size("font_size")
				var nxt: int = clampi(cur + delta, 8, 32)
				lbl.add_theme_font_size_override("font_size", nxt)
				info.append("%s=%d" % [lbl.name, nxt])
			print("[HUD] %s font size adjusted: %s" % [box.name, ", ".join(info)])
			box.accept_event()

	elif event is InputEventMouseMotion and state.dragging:
		var mouse_delta: Vector2 = box.get_global_mouse_position() - state.drag_start_mouse
		var new_pos: Vector2 = state.drag_start_box_pos + mouse_delta
		new_pos.x = clampf(new_pos.x, 0.0, 1280.0 - box.size.x)
		new_pos.y = clampf(new_pos.y, 0.0, 720.0 - box.size.y)
		box.position = new_pos
		box.accept_event()
