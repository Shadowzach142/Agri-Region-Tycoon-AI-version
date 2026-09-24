# HUD.gd
# Main HUD controller: Clean Clash of Clans top bar, hover region pros/cons card,
# lightweight bottom-left tile inspector, and bottom-right command corner.
extends CanvasLayer

# Top Status Bar
@onready var region_capsule: PanelContainer = $Control/TopBar/Margin/HBox/LeftCluster/RegionCapsule
@onready var region_label: Label = $Control/TopBar/Margin/HBox/LeftCluster/RegionCapsule/RegionLabel
@onready var weather_label: Label = $Control/TopBar/Margin/HBox/LeftCluster/WeatherCapsule/WeatherLabel

@onready var day_label: Label = $Control/TopBar/Margin/HBox/CenterCluster/ClockBox/DayLabel
@onready var time_label: Label = $Control/TopBar/Margin/HBox/CenterCluster/ClockBox/TimeLabel
@onready var disaster_label: Label = $Control/TopBar/Margin/HBox/CenterCluster/DisasterLabel

@onready var pause_btn: Button = $Control/TopBar/Margin/HBox/CenterCluster/ClockBox/SpeedBar/PauseButton
@onready var speed1_btn: Button = $Control/TopBar/Margin/HBox/CenterCluster/ClockBox/SpeedBar/Speed1xButton
@onready var speed2_btn: Button = $Control/TopBar/Margin/HBox/CenterCluster/ClockBox/SpeedBar/Speed2xButton
@onready var speed3_btn: Button = $Control/TopBar/Margin/HBox/CenterCluster/ClockBox/SpeedBar/Speed3xButton

@onready var worker_label: Label = $Control/TopBar/Margin/HBox/RightCluster/WorkerCapsule/WorkerLabel
@onready var storage_label: Label = $Control/TopBar/Margin/HBox/RightCluster/StorageCapsule/VBox/StorageLabel
@onready var storage_bar: ProgressBar = $Control/TopBar/Margin/HBox/RightCluster/StorageCapsule/VBox/StorageBar
@onready var cash_label: Label = $Control/TopBar/Margin/HBox/RightCluster/CashCapsule/CashLabel
@onready var task_label: Label = $Control/TopBar/Margin/HBox/RightCluster/TaskCapsule/TaskLabel

# Hover Region Pros & Cons Card
@onready var region_hover_card: PanelContainer = $Control/RegionHoverCard
@onready var hover_title: Label = $Control/RegionHoverCard/VBox/TitleLabel
@onready var hover_desc: Label = $Control/RegionHoverCard/VBox/DescLabel
@onready var hover_pros: Label = $Control/RegionHoverCard/VBox/ProsLabel
@onready var hover_cons: Label = $Control/RegionHoverCard/VBox/ConsLabel

# Bottom-Right Command Corner
@onready var market_btn: Button = $Control/CommandCorner/MarketButton
@onready var shop_btn: Button = $Control/CommandCorner/ShopButton

# Modals & Bottom Console
@onready var market_panel: PanelContainer = $Control/MarketPanel
@onready var shop_panel: PanelContainer = $Control/ShopPanel
@onready var tile_info_panel: PanelContainer = $Control/TileInfoPanel

var _disaster_timer: float = 0.0

func _ready() -> void:
	# Autoload signals
	EconomyManager.cash_changed.connect(_on_cash_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.hour_changed.connect(_on_hour_changed)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	WeatherManager.disaster_warning.connect(_on_disaster_warning)

	BuildingManager.storage_updated.connect(func(_c, _u): _refresh_storage_display())
	BuildingManager.worker_hired.connect(func(_w): _refresh_workers_display())
	BuildingManager.building_purchased.connect(func(_b): 
		_refresh_storage_display()
		_refresh_workers_display()
	)
	MarketManager.inventory_changed.connect(_refresh_storage_display)

	# Speed button signals
	pause_btn.pressed.connect(_on_pause_pressed)
	speed1_btn.pressed.connect(_on_1x_pressed)
	speed2_btn.pressed.connect(_on_2x_pressed)
	speed3_btn.pressed.connect(_on_3x_pressed)

	# Command corner buttons
	market_btn.pressed.connect(_on_market_toggle_pressed)
	shop_btn.pressed.connect(_on_shop_toggle_pressed)

	if shop_panel and shop_panel.has_signal("worker_spawn_requested"):
		shop_panel.worker_spawn_requested.connect(_on_worker_spawn_requested)

	# Region hover connections
	if region_capsule:
		region_capsule.mouse_entered.connect(_on_region_hover_entered)
		region_capsule.mouse_exited.connect(_on_region_hover_exited)

	# Initial values
	_on_cash_changed(EconomyManager.cash)
	_on_day_changed(TimeManager.current_day)
	_on_hour_changed(TimeManager.current_hour)
	_on_weather_changed(WeatherManager.temperature, WeatherManager.humidity)
	_refresh_storage_display()
	_refresh_workers_display()
	_update_region_display()

	disaster_label.text = ""
	task_label.text = "📋 0"

	_setup_worker_banner()
	TaskManager.selection_changed.connect(_on_worker_selection_changed)

	market_panel.visible = false
	shop_panel.visible = false
	if region_hover_card:
		region_hover_card.visible = false

func _process(delta: float) -> void:
	if _disaster_timer > 0.0:
		_disaster_timer -= delta
		if _disaster_timer <= 0.0:
			disaster_label.text = ""

	if task_label:
		task_label.text = "📋 %d" % TaskManager.get_task_count()

func _update_region_display() -> void:
	var reg_data = Data.get_region(Data.current_region)
	# Extract short name (before parenthesis) for clean, compact top bar pill
	var full_name: String = reg_data.get("display_name", Data.current_region.capitalize())
	var short_name: String = full_name.split("(")[0].strip_edges()
	region_label.text = "📍 " + short_name

func _on_region_hover_entered() -> void:
	if not region_hover_card:
		return
	var reg_data = Data.get_region(Data.current_region)
	hover_title.text = "🗺️ %s" % reg_data.get("display_name", "")
	hover_desc.text = "%s\nSpecialty: %s" % [reg_data.get("description", ""), reg_data.get("specialty", "")]

	var pros_arr: Array = reg_data.get("pros", [])
	var pros_str: String = "✔ PROS & ADVANTAGES:\n"
	for p in pros_arr:
		pros_str += "  • %s\n" % p
	hover_pros.text = pros_str.strip_edges()

	var cons_arr: Array = reg_data.get("cons", [])
	var cons_str: String = "⚠️ CONS & RISKS:\n"
	for c in cons_arr:
		cons_str += "  • %s\n" % c
	hover_cons.text = cons_str.strip_edges()

	region_hover_card.visible = true

func _on_region_hover_exited() -> void:
	if region_hover_card:
		region_hover_card.visible = false

func _on_cash_changed(amount: int) -> void:
	if cash_label:
		cash_label.text = "💰 ₱%s" % Utils.format_number(amount)


func _on_day_changed(day: int) -> void:
	if day_label:
		day_label.text = "📅 Day: %d" % day

func _on_hour_changed(hour: int) -> void:
	if time_label:
		time_label.text = "⏰ %02d:00" % hour
	if task_label:
		task_label.text = "📋 %d" % TaskManager.get_task_count()
	_refresh_storage_display()

func _on_weather_changed(temp: float, hum: float) -> void:
	var climate_str: String = ""
	match WeatherManager.current_climate:
		WeatherManager.Climate.EL_NINO: climate_str = " 🔥"
		WeatherManager.Climate.LA_NINA: climate_str = " 🌧️"
		WeatherManager.Climate.NORMAL: climate_str = " ⛅"
	if weather_label:
		weather_label.text = "%s %.0f°C 💧 %.0f%%" % [climate_str, temp, hum * 100.0]

func _refresh_storage_display() -> void:
	var total_stored: int = 0
	for b in MarketManager.stored_inventory:
		total_stored += int(b.get("quantity", 0))
	var capacity: int = max(BuildingManager.total_storage_capacity, 1000)
	if storage_label:
		storage_label.text = "📦 %d/%d" % [total_stored, capacity]
	if storage_bar:
		storage_bar.value = float(total_stored) / float(capacity) * 100.0

var _worker_banner: PanelContainer = null
var _worker_banner_label: Label = null

func _setup_worker_banner() -> void:
	_worker_banner = PanelContainer.new()
	_worker_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_worker_banner.offset_left = 300
	_worker_banner.offset_top = 58
	_worker_banner.offset_right = -300
	_worker_banner.offset_bottom = 92
	_worker_banner.mouse_filter = Control.MOUSE_FILTER_PASS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.18, 0.94)
	style.border_color = Color(1.0, 0.85, 0.25, 0.95)
	style.border_width_bottom = 2
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	_worker_banner.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	_worker_banner.add_child(hbox)

	_worker_banner_label = Label.new()
	_worker_banner_label.add_theme_font_size_override("font_size", 12)
	_worker_banner_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
	_worker_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_worker_banner_label)

	var deselect_btn := Button.new()
	deselect_btn.text = "✖ Deselect (Esc)"
	deselect_btn.add_theme_font_size_override("font_size", 10)
	deselect_btn.pressed.connect(func(): TaskManager.deselect_all_farmers())
	hbox.add_child(deselect_btn)

	$Control.add_child(_worker_banner)
	_worker_banner.visible = false

func _on_worker_selection_changed(selected_workers: Array) -> void:
	_refresh_workers_display()
	if _worker_banner == null or _worker_banner_label == null:
		return

	if selected_workers.is_empty():
		_worker_banner.visible = false
	else:
		_worker_banner.visible = true
		if selected_workers.size() == 1:
			var w = selected_workers[0]
			_worker_banner_label.text = "⭐ Selected: %s  •  Right-click tiles to assign task" % w.worker_name
		else:
			var names: Array = []
			for w in selected_workers:
				names.append(w.worker_name)
			_worker_banner_label.text = "👥 Selected (%d): %s  •  Parallel task sharing!" % [selected_workers.size(), ", ".join(names)]

func _refresh_workers_display() -> void:
	if worker_label:
		var sel_count: int = TaskManager.get_selected_farmers().size()
		if sel_count > 0:
			worker_label.text = "🧑‍🌾 %d/%d (⭐%d)" % [BuildingManager.active_workers, BuildingManager.worker_capacity, sel_count]
		else:
			worker_label.text = "🧑‍🌾 %d/%d" % [BuildingManager.active_workers, BuildingManager.worker_capacity]

func _on_disaster_warning(hazard_type: String) -> void:
	if disaster_label:
		disaster_label.text = "⚠️ ALERT: %s!" % hazard_type.replace("_", " ").to_upper()
		disaster_label.modulate = Color(1.0, 0.25, 0.25)
	_disaster_timer = 6.0

func _on_market_toggle_pressed() -> void:
	market_panel.visible = not market_panel.visible
	if market_panel.visible:
		shop_panel.visible = false
		market_panel.refresh_prices()
		market_panel.refresh_forecast()
		market_panel.refresh_inventory()

func _on_shop_toggle_pressed() -> void:
	shop_panel.visible = not shop_panel.visible
	if shop_panel.visible:
		market_panel.visible = false

func _on_worker_spawn_requested() -> void:
	var farmer_script = load("res://src/Farmer.gd")
	var farmer = CharacterBody2D.new()
	farmer.set_script(farmer_script)
	farmer.name = "Farmer_%d" % BuildingManager.active_workers
	farmer.position = Vector2(480, 240) + Vector2(randf_range(-30, 30), randf_range(-30, 30))

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

func _on_pause_pressed() -> void: TimeManager.set_speed_mode(TimeManager.Speed.PAUSE)
func _on_1x_pressed()    -> void: TimeManager.set_speed_mode(TimeManager.Speed.ONE_X)
func _on_2x_pressed()    -> void: TimeManager.set_speed_mode(TimeManager.Speed.TWO_X)
func _on_3x_pressed()    -> void: TimeManager.set_speed_mode(TimeManager.Speed.THREE_X)
