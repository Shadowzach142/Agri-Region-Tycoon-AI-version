# ShopPanel.gd
# Agri-Shop: function-based tabs (Housing & Labor, Storage, Weather & Irrigation, Machinery & Drones, Land).
# Includes prominent "!" info indicators with hover tooltips and interactive detail cards.
# Fully reactive to building construction, capacity changes, and funds.

extends PanelContainer

signal item_purchased(item_name: String, cost: int)
signal worker_spawn_requested()

@onready var close_btn: Button = $VBox/Header/CloseBtn
@onready var cash_label: Label = $VBox/Header/CashLabel
@onready var status_label: Label = $VBox/StatusLabel

# Containers for shop items (Labor tab comes from the scene; the rest are built in _ready)
@onready var labor_container: VBoxContainer = $VBox/TabContainer/Labor/VBox
var storage_container: VBoxContainer = null
var weather_container: VBoxContainer = null
var machinery_container: VBoxContainer = null
var _refresh_timer: float = 0.0

# Interactive Info Card for "!" clicks
@onready var item_info_card: PanelContainer = $VBox/ItemInfoCard
@onready var info_title_lbl: Label = $VBox/ItemInfoCard/HBox/TextVBox/InfoTitle
@onready var info_desc_lbl: Label = $VBox/ItemInfoCard/HBox/TextVBox/InfoDesc
@onready var info_close_btn: Button = $VBox/ItemInfoCard/HBox/InfoCloseBtn

var _labor_hire_btn: Button = null
var _labor_tip_lbl: Label = null
var _labor_info_lbl: Label = null
var _drone_hire_btn: Button = null
var _drone_tip_lbl: Label = null
var _drone_info_lbl: Label = null
var land_container: VBoxContainer = null

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	if info_close_btn:
		info_close_btn.pressed.connect(func(): item_info_card.visible = false)

	EconomyManager.cash_changed.connect(_on_cash_changed)
	_on_cash_changed(EconomyManager.cash)

	# Build the function-based tabs: Storage, Weather & Irrigation, Machinery & Drones, Land
	var tabs: TabContainer = find_child("TabContainer", true, false)
	if tabs:
		tabs.set_tab_title(tabs.get_tab_idx_from_control($VBox/TabContainer/Labor), "👷 Housing & Labor")
	storage_container = _make_tab("Storage", "📦 Storage")
	weather_container = _make_tab("Weather", "🌦️ Weather & Irrigation")
	machinery_container = _make_tab("Machinery", "🚜 Machinery & Drones")
	land_container = _make_tab("Land", "🗺️ Land (10×10)")

	# React immediately to construction completions, worker changes, and placements
	BuildingManager.worker_capacity_changed.connect(func(_cap, _act): _populate_labor())
	BuildingManager.worker_hired.connect(func(_act): _populate_labor())
	BuildingManager.drone_commissioned.connect(func(_d): _populate_labor())
	BuildingManager.building_placed.connect(func(_b): refresh())
	BuildingManager.storage_updated.connect(func(_c, _u): _populate_buildings())
	BuildingManager.weather_station_updated.connect(func(_l): _populate_buildings())
	BuildingManager.irrigation_updated.connect(func(_l): _populate_buildings())
	BuildingManager.sprinklers_updated.connect(func(_a, _c): _populate_buildings())
	BuildingManager.machinery_updated.connect(func(_l): _populate_buildings())

	# Always refresh data when panel becomes visible
	visibility_changed.connect(func():
		if visible:
			refresh()
	)

	_populate_shop()

func _process(delta: float) -> void:
	if not visible:
		return

	# While a one-time building is constructing/upgrading, refresh its card so the countdown stays live
	_refresh_timer += delta
	if _refresh_timer >= 1.0:
		_refresh_timer = 0.0
		for b in BuildingManager.placed_buildings:
			if is_instance_valid(b) and (b.state == b.BuildingState.CONSTRUCTING or b.state == b.BuildingState.UPGRADING):
				_populate_buildings()
				break

	# If a Bahay Kubo is currently constructing, keep the countdown label in the Labor tab fresh in real time
	if BuildingManager.has_constructing_building("bahay_kubo") and is_instance_valid(_labor_tip_lbl) and is_instance_valid(_labor_hire_btn):
		var rem_time: float = BuildingManager.get_building_construction_time_remaining("bahay_kubo")
		_labor_tip_lbl.text = "🔨 Bahay Kubo is under construction! (%.1fs left) — Worker slot will unlock as soon as it completes." % rem_time
		_labor_tip_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		_labor_hire_btn.text = "Building... (%.0fs)" % rem_time
		_labor_hire_btn.disabled = true

	# If a Drone Command Hangar is currently constructing, keep the countdown label fresh in real time
	if BuildingManager.has_constructing_building("drone_station") and is_instance_valid(_drone_tip_lbl) and is_instance_valid(_drone_hire_btn):
		var rem_d: float = BuildingManager.get_building_construction_time_remaining("drone_station")
		_drone_tip_lbl.text = "🔨 Drone Command Hangar is under construction! (%.1fs left) — Drone labor will unlock as soon as it completes." % rem_d
		_drone_tip_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		_drone_hire_btn.text = "Building... (%.0fs)" % rem_d
		_drone_hire_btn.disabled = true

func refresh() -> void:
	_on_cash_changed(EconomyManager.cash)
	_populate_shop()

func _create_shop_card(content: Control) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.16, 0.10, 0.08)
	style.border_color = Color(0.48, 0.34, 0.22, 0.40)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 16
	style.content_margin_top = 10
	style.content_margin_right = 16
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	card.add_child(content)
	return card

func _style_buy_btn(btn: Button) -> void:
	var normal = preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres")
	var hover = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres")
	var pressed = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres")
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02, 1.0))
	btn.add_theme_font_size_override("font_size", 14)

func _on_cash_changed(amount: int) -> void:
	if cash_label:
		cash_label.text = "Funds: ₱%s" % Utils.format_number(amount)
	_update_labor_ui()

func show_info(title: String, desc: String) -> void:
	if item_info_card and info_title_lbl and info_desc_lbl:
		info_title_lbl.text = title
		info_desc_lbl.text = desc
		item_info_card.visible = true

func _create_info_btn(title: String, desc: String) -> Button:
	var btn: Button = Button.new()
	btn.text = "!"
	btn.custom_minimum_size = Vector2(32, 32)
	btn.tooltip_text = "%s\n%s" % [title, desc]

	btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.60))
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func(): show_info(title, desc))
	return btn

func _make_tab(tab_name: String, title: String) -> VBoxContainer:
	var tab_container: TabContainer = find_child("TabContainer", true, false)
	if tab_container == null:
		return null
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.set_meta("_tab_title", title)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 2)
	pad.add_theme_constant_override("margin_top", 2)
	pad.add_theme_constant_override("margin_right", 2)
	pad.add_theme_constant_override("margin_bottom", 2)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)

	var box := VBoxContainer.new()
	box.name = "VBox"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	pad.add_child(box)
	tab_container.add_child(scroll)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, title)
	return box

func _populate_shop() -> void:
	_populate_buildings()
	_populate_labor()
	_populate_land()

func _populate_land() -> void:
	if not land_container:
		return
	for child in land_container.get_children():
		child.queue_free()

	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	var unlocked_parcels: Array = farm_grid.unlocked_parcels if (farm_grid and "unlocked_parcels" in farm_grid) else ["homestead"]

	for p in Data.LAND_PARCELS:
		var pid: String = p.get("id", "")
		var is_owned: bool = unlocked_parcels.has(pid)
		var cost: int = p.get("cost", 0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var r_sz: Vector2i = p.get("rect", Rect2i()).size
		var name_lbl := Label.new()
		name_lbl.text = "%s (%d×%d)" % [p.get("name", "Territory"), r_sz.x, r_sz.y]
		name_lbl.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var info_btn = _create_info_btn(p.get("name"), p.get("description", ""))
		row.add_child(info_btn)

		var cost_lbl := Label.new()
		cost_lbl.text = "₱%s" % Utils.format_number(cost) if cost > 0 else "Owned"
		cost_lbl.add_theme_color_override("font_color", Color(0.12, 0.48, 0.15, 1.0) if not is_owned else Color(0.35, 0.25, 0.15, 0.8))
		cost_lbl.add_theme_font_size_override("font_size", 15)
		cost_lbl.custom_minimum_size = Vector2(85, 0)
		row.add_child(cost_lbl)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(120, 38)
		_style_buy_btn(buy_btn)
		if is_owned:
			buy_btn.text = "Owned ✔"
			buy_btn.disabled = true
		else:
			buy_btn.text = "Buy Deed"
			buy_btn.disabled = (EconomyManager.cash < cost)
			buy_btn.pressed.connect(func():
				if farm_grid and farm_grid.has_method("open_land_expansion_modal"):
					farm_grid.open_land_expansion_modal(pid)
			)
		row.add_child(buy_btn)
		land_container.add_child(_create_shop_card(row))

func _make_tab_blurb(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.35, 0.24, 0.14, 0.95))
	return lbl

## Rebuilds every building-based tab (Storage, Weather & Irrigation, Machinery & Drones).
func _populate_buildings() -> void:
	_fill_building_tab(storage_container, "storage",
		"Warehouses and processing. Build as many as you need — capacity stacks. Click a placed building on your farm to upgrade it.")
	_fill_building_tab(weather_container, "weather",
		"Weather forecast stations, central irrigation towers, and deployable rotary field sprinklers.")
	_fill_building_tab(machinery_container, "machinery",
		"One-time purchases. Buy each once, then click the building on your farm to upgrade it. Drones are commissioned in Housing & Labor.")

func _fill_building_tab(container: VBoxContainer, category: String, blurb: String) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	container.add_child(_make_tab_blurb(blurb))
	for b_key in Data.BUILDINGS.keys():
		if str(Data.get_building(b_key).get("shop_category", "")) == category:
			container.add_child(_create_building_card(b_key))

## Short status line for a one-time building that already exists on the farm.
func _get_owned_status(b_key: String, b: Node) -> String:
	var b_data: Dictionary = Data.get_building(b_key)
	var max_lvl: int = int(b_data.get("max_level", 3))
	if b.state == b.BuildingState.CONSTRUCTING:
		return "🔨 Under construction (%.0fs left)" % BuildingManager.get_building_construction_time_remaining(b_key)
	if b.state == b.BuildingState.UPGRADING:
		return "⬆️ Upgrading to Lv.%d..." % (b.level + 1)
	var tier: String = ""
	match b_key:
		"weather_station":
			tier = BuildingManager.get_weather_station_tier_name()
		"water_tower":
			tier = BuildingManager.get_irrigation_tier_name()
		"machine_garage":
			tier = BuildingManager.get_machinery_tier_name()
		"drone_station":
			tier = ["Plow Drones", "Seeder Drones", "Harvester Drones"][clampi(b.level - 1, 0, 2)]
	var tail: String = "Max level reached." if b.level >= max_lvl else "Click it on your farm to upgrade."
	return "✔ Built — Lv.%d/%d%s • %s" % [b.level, max_lvl, (" • " + tier) if tier != "" else "", tail]

func _create_building_card(b_key: String) -> PanelContainer:
	var b_data: Dictionary = Data.get_building(b_key)
	var is_unique: bool = BuildingManager.is_unique_building(b_key)
	var existing: Node = BuildingManager.get_building_of_type(b_key) if is_unique else null

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var perk: String = ""
	if b_data.get("halts_spoilage", false):
		perk = " [Halts ROT]"
	elif b_data.get("storage_limit", 0) > 0:
		perk = " [+%d Cap]" % b_data.get("storage_limit", 0)
	elif b_data.get("worker_capacity", 0) > 0:
		perk = " [+%d Worker]" % b_data.get("worker_capacity", 0)
	elif b_data.get("unlocks_drones", false):
		perk = " [Drone Hangar]"
	elif b_data.get("forecast_equipment", false):
		perk = " [Forecast]"
	elif b_data.get("irrigation_equipment", false):
		perk = " [Water Tower]"
	elif b_data.get("is_sprinkler", false):
		perk = " [Auto-Spray Diamond]"
	elif b_data.get("unlocks_machines", false):
		perk = " [Tractor & Combine]"
	elif b_data.get("drying_bonus", 0.0) > 0.0:
		perk = " [+Quality]"
	if is_unique:
		perk += " ★ One-time"

	var name_lbl: Label = Label.new()
	name_lbl.text = "%s %s%s" % [b_data.get("icon", ""), b_data.get("display_name", b_key), perk]
	name_lbl.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var desc: String = b_data.get("description", "Farm infrastructure facility.")
	row.add_child(_create_info_btn(b_data.get("display_name", b_key), desc))

	var cost: int = int(b_data.get("cost", 400))
	var cost_lbl: Label = Label.new()
	cost_lbl.add_theme_font_size_override("font_size", 15)
	cost_lbl.custom_minimum_size = Vector2(85, 0)
	if existing != null:
		cost_lbl.text = "Lv.%d" % existing.level
		cost_lbl.add_theme_color_override("font_color", Color(0.35, 0.25, 0.15, 0.85))
	else:
		cost_lbl.text = "₱%s" % Utils.format_number(cost)
		cost_lbl.add_theme_color_override("font_color", Color(0.12, 0.48, 0.15, 1.0))
	row.add_child(cost_lbl)

	var buy_btn: Button = Button.new()
	buy_btn.custom_minimum_size = Vector2(120, 38)
	_style_buy_btn(buy_btn)
	if existing != null:
		buy_btn.text = "Built ✔"
		buy_btn.disabled = true
	elif b_key == "sprinkler":
		var has_pump: bool = BuildingManager.has_irrigation()
		var active_spk: int = BuildingManager.get_active_sprinkler_count()
		var cap_spk: int = BuildingManager.get_sprinkler_capacity()
		var rad: int = BuildingManager.get_sprinkler_radius()
		var cov_str: String = "3×3 Diamond (8 plots)" if rad == 1 else "5×5 Diamond (24 plots)"

		if not has_pump:
			buy_btn.text = "Locked 🔒"
			buy_btn.disabled = true
		elif not BuildingManager.can_place_sprinkler():
			buy_btn.text = "Pressure Max"
			buy_btn.disabled = true
		else:
			buy_btn.text = "Deploy"
			buy_btn.disabled = (EconomyManager.cash < cost)
			buy_btn.pressed.connect(func(): _buy_building(b_key, cost))
	else:
		buy_btn.text = "Construct"
		buy_btn.disabled = (EconomyManager.cash < cost)
		buy_btn.pressed.connect(func(): _buy_building(b_key, cost))
	row.add_child(buy_btn)
	col.add_child(row)

	if existing != null:
		var status := Label.new()
		status.text = _get_owned_status(b_key, existing)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.add_theme_font_size_override("font_size", 13)
		status.add_theme_color_override("font_color", Color(0.12, 0.45, 0.18, 1.0))
		col.add_child(status)
	elif b_key == "sprinkler":
		var status := Label.new()
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.add_theme_font_size_override("font_size", 13)
		var has_pump: bool = BuildingManager.has_irrigation()
		var active_spk: int = BuildingManager.get_active_sprinkler_count()
		var cap_spk: int = BuildingManager.get_sprinkler_capacity()
		var rad: int = BuildingManager.get_sprinkler_radius()
		var cov_str: String = "3×3 Diamond" if rad == 1 else "5×5 Diamond"

		if not has_pump:
			status.text = "🔒 Requires Irrigation Pump & Tower! Construct a tower first to pressurize water lines."
			status.add_theme_color_override("font_color", Color(0.78, 0.35, 0.15))
		elif not BuildingManager.can_place_sprinkler():
			status.text = "⚠️ Water pressure maxed (%d/%d Sprinklers)! Upgrade Irrigation Tower to Lv.%d to increase pressure capacity." % [
				active_spk, cap_spk, BuildingManager.get_irrigation_level() + 1
			]
			status.add_theme_color_override("font_color", Color(0.85, 0.45, 0.15))
		else:
			var cap_str: String = str(cap_spk) if cap_spk < 999 else "Unlimited"
			status.text = "💧 Pressure: %d/%s Sprinklers • Coverage: %s auto-spray" % [active_spk, cap_str, cov_str]
			status.add_theme_color_override("font_color", Color(0.12, 0.48, 0.18))
		col.add_child(status)

	return _create_shop_card(col)

func _populate_labor() -> void:
	for child in labor_container.get_children():
		child.queue_free()

	# ── 0. Housing (Bahay Kubo) — repeatable, raises worker capacity ───
	labor_container.add_child(_make_tab_blurb("Housing: each Bahay Kubo adds +1 worker slot. Hire workers below, then commission drones (each drone needs a farmer pilot)."))
	labor_container.add_child(_create_building_card("bahay_kubo"))
	var hsep := HSeparator.new()
	hsep.modulate = Color(0.65, 0.55, 0.45, 0.35)
	labor_container.add_child(hsep)

	# ── 1. Autonomous Farm Worker (Human Laborer) ──────────────────────
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	_labor_info_lbl = Label.new()
	_labor_info_lbl.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
	_labor_info_lbl.add_theme_font_size_override("font_size", 15)
	_labor_info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_labor_info_lbl)

	var labor_desc: String = "Hires an additional autonomous farm worker. Farmers automatically navigate to queued tasks (Plowing, Planting, Watering, Pest Spraying, and Harvesting) and deposit harvested produce into storage. Daily wage: ₱15."
	var info_btn = _create_info_btn("Autonomous Farm Laborer", labor_desc)
	row.add_child(info_btn)

	var cost_lbl: Label = Label.new()
	cost_lbl.text = "₱200"
	cost_lbl.add_theme_color_override("font_color", Color(0.12, 0.48, 0.15, 1.0))
	cost_lbl.add_theme_font_size_override("font_size", 15)
	cost_lbl.custom_minimum_size = Vector2(85, 0)
	row.add_child(cost_lbl)

	_labor_hire_btn = Button.new()
	_labor_hire_btn.custom_minimum_size = Vector2(128, 38)
	_style_buy_btn(_labor_hire_btn)
	_labor_hire_btn.pressed.connect(_hire_worker)
	row.add_child(_labor_hire_btn)

	labor_container.add_child(_create_shop_card(row))

	_labor_tip_lbl = Label.new()
	_labor_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_labor_tip_lbl.add_theme_font_size_override("font_size", 13)
	labor_container.add_child(_labor_tip_lbl)

	# Spacer between Human Labor and Drone Labor
	var sep := HSeparator.new()
	sep.modulate = Color(0.65, 0.55, 0.45, 0.35)
	labor_container.add_child(sep)

	# ── 2. Precision Farm Drone (Mechanized Drone Labor) ───────────────
	var drone_row: HBoxContainer = HBoxContainer.new()
	drone_row.add_theme_constant_override("separation", 10)

	_drone_info_lbl = Label.new()
	_drone_info_lbl.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
	_drone_info_lbl.add_theme_font_size_override("font_size", 15)
	_drone_info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drone_row.add_child(_drone_info_lbl)

	var drone_desc: String = "Commissions an autonomous precision farm drone. Drones fly directly to your designated hotbar zone to plow, plant, and harvest without fatigue. Requires an operational Drone Command Hangar (Shop > Machinery & Drones). The number of drones cannot exceed the number of farmers available to pilot them."
	var d_info_btn := _create_info_btn("Precision Farm Drone", drone_desc)
	drone_row.add_child(d_info_btn)

	var d_cost_lbl := Label.new()
	d_cost_lbl.text = "₱350"
	d_cost_lbl.add_theme_color_override("font_color", Color(0.12, 0.48, 0.15, 1.0))
	d_cost_lbl.add_theme_font_size_override("font_size", 15)
	d_cost_lbl.custom_minimum_size = Vector2(85, 0)
	drone_row.add_child(d_cost_lbl)

	_drone_hire_btn = Button.new()
	_drone_hire_btn.custom_minimum_size = Vector2(128, 38)
	_style_buy_btn(_drone_hire_btn)
	_drone_hire_btn.pressed.connect(_commission_drone)
	drone_row.add_child(_drone_hire_btn)

	labor_container.add_child(_create_shop_card(drone_row))

	_drone_tip_lbl = Label.new()
	_drone_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drone_tip_lbl.add_theme_font_size_override("font_size", 13)
	labor_container.add_child(_drone_tip_lbl)

	_update_labor_ui()

func _update_labor_ui() -> void:
	if not is_instance_valid(_labor_info_lbl) or not is_instance_valid(_labor_hire_btn) or not is_instance_valid(_labor_tip_lbl):
		return

	var act: int = BuildingManager.active_workers
	var cap: int = BuildingManager.worker_capacity
	var cash: int = EconomyManager.cash
	var is_constructing_kubo: bool = BuildingManager.has_constructing_building("bahay_kubo")

	_labor_info_lbl.text = "Hire Extra Farm Worker (Workers: %d / %d Cap)" % [act, cap]

	if is_constructing_kubo and act >= cap:
		var rem_time: float = BuildingManager.get_building_construction_time_remaining("bahay_kubo")
		_labor_tip_lbl.text = "Bahay Kubo is under construction! (%.1fs left) — Worker slot will unlock as soon as it completes." % rem_time
		_labor_tip_lbl.add_theme_color_override("font_color", Color(0.65, 0.40, 0.10))
		_labor_hire_btn.text = "Building... (%.0fs)" % rem_time
		_labor_hire_btn.disabled = true
	elif act >= cap:
		_labor_tip_lbl.text = "Worker housing capacity full (%d/%d)! Construct a Bahay Kubo above for more slots." % [act, cap]
		_labor_tip_lbl.add_theme_color_override("font_color", Color(0.70, 0.20, 0.15))
		_labor_hire_btn.text = "Housing Full"
		_labor_hire_btn.disabled = true
	else:
		# There is capacity!
		if cash >= 200:
			_labor_tip_lbl.text = "Housing slot available! Room for %d more autonomous farmer(s)." % (cap - act)
			_labor_tip_lbl.add_theme_color_override("font_color", Color(0.12, 0.50, 0.15))
			_labor_hire_btn.text = "Hire Worker"
			_labor_hire_btn.disabled = false
		else:
			_labor_tip_lbl.text = "Housing slot available, but you need ₱200 to hire (Current: ₱%s)." % Utils.format_number(cash)
			_labor_tip_lbl.add_theme_color_override("font_color", Color(0.65, 0.38, 0.10))
			_labor_hire_btn.text = "Need ₱200"
			_labor_hire_btn.disabled = true

	# ── Update Precision Drone Labor UI ────────────────────────────────
	if is_instance_valid(_drone_info_lbl) and is_instance_valid(_drone_hire_btn) and is_instance_valid(_drone_tip_lbl):
		var d_act: int = BuildingManager.active_drones
		var d_cap: int = BuildingManager.get_drone_capacity()
		var has_hangar: bool = BuildingManager.has_drone_station()
		var is_building_hangar: bool = BuildingManager.has_constructing_building("drone_station")

		_drone_info_lbl.text = "Commission Farm Drone (Active Drones: %d / %d Pilots)" % [d_act, d_cap]

		if not has_hangar and not is_building_hangar:
			_drone_tip_lbl.text = "⚠️ Requires Drone Hangar! Construct a Drone Command Hangar in the Machinery & Drones tab to unlock drone labor."
			_drone_tip_lbl.add_theme_color_override("font_color", Color(0.70, 0.20, 0.15))
			_drone_hire_btn.text = "No Hangar"
			_drone_hire_btn.disabled = true
		elif is_building_hangar:
			var rem_d: float = BuildingManager.get_building_construction_time_remaining("drone_station")
			_drone_tip_lbl.text = "🔨 Drone Command Hangar is under construction! (%.1fs left) — Drone labor unlocks when it completes." % rem_d
			_drone_tip_lbl.add_theme_color_override("font_color", Color(0.65, 0.40, 0.10))
			_drone_hire_btn.text = "Building... (%.0fs)" % rem_d
			_drone_hire_btn.disabled = true
		elif d_act >= d_cap:
			_drone_tip_lbl.text = "⚠️ Pilot Limit Reached (%d/%d)! Each drone requires 1 active farmer to pilot it via remote control. Hire more farm workers above to control more drones." % [d_act, d_cap]
			_drone_tip_lbl.add_theme_color_override("font_color", Color(0.70, 0.20, 0.15))
			_drone_hire_btn.text = "Pilot Limit Reached"
			_drone_hire_btn.disabled = true
		else:
			if cash >= 350:
				var lvl: int = BuildingManager.get_drone_level()
				var lvl_str: String = ["Plow", "Seeder", "Harvester"][clampi(lvl - 1, 0, 2)]
				_drone_tip_lbl.text = "✅ Pilot available! Ready to deploy Lv.%d (%s) drone. Remote control opens on worker hotbar (hotkey 4)." % [lvl, lvl_str]
				_drone_tip_lbl.add_theme_color_override("font_color", Color(0.12, 0.50, 0.15))
				_drone_hire_btn.text = "Commission Drone"
				_drone_hire_btn.disabled = false
			else:
				_drone_tip_lbl.text = "Pilot slot available, but you need ₱350 to commission a drone (Current: ₱%s)." % Utils.format_number(cash)
				_drone_tip_lbl.add_theme_color_override("font_color", Color(0.65, 0.38, 0.10))
				_drone_hire_btn.text = "Need ₱350"
				_drone_hire_btn.disabled = true

func _buy_building(b_key: String, cost: int) -> void:
	if BuildingManager.is_unique_building(b_key) and BuildingManager.owns_building(b_key):
		status_label.text = "%s is already built — click it on your farm to upgrade it." % str(Data.get_building(b_key).get("display_name", b_key))
		status_label.modulate = Color(1.0, 0.75, 0.2)
		_populate_buildings()
		return

	if b_key == "sprinkler":
		if not BuildingManager.has_irrigation():
			status_label.text = "Cannot deploy Sprinkler! Requires an active Irrigation Pump & Tower."
			status_label.modulate = Color(1.0, 0.3, 0.3)
			return
		if not BuildingManager.can_place_sprinkler():
			status_label.text = "Cannot deploy Sprinkler! Water pressure capacity reached (%d/%d)." % [
				BuildingManager.get_active_sprinkler_count(),
				BuildingManager.get_sprinkler_capacity()
			]
			status_label.modulate = Color(1.0, 0.3, 0.3)
			return

	# Verify funds before entering placement mode
	if EconomyManager.cash < cost:
		status_label.text = "Insufficient funds for %s! (₱%d required)" % [b_key.capitalize(), cost]
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	# Find FarmGrid and enter placement mode
	var farm_grid: Node = get_tree().root.find_child("FarmGrid", true, false)
	if farm_grid == null:
		status_label.text = "Cannot place building — FarmGrid not found!"
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	# Close shop so the player can see the grid
	visible = false

	# Start CoC-style ghost placement
	farm_grid.start_building_placement(b_key)

func _hire_worker() -> void:
	var act: int = BuildingManager.active_workers
	var cap: int = BuildingManager.worker_capacity

	if act >= cap:
		if BuildingManager.has_constructing_building("bahay_kubo"):
			var rem: float = BuildingManager.get_building_construction_time_remaining("bahay_kubo")
			status_label.text = "Bahay Kubo is still under construction (%.0fs remaining)! Please wait for it to finish." % rem
			status_label.modulate = Color(1.0, 0.75, 0.2)
		else:
			status_label.text = "Cannot hire! Housing capacity full. Construct a Bahay Kubo first."
			status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if EconomyManager.cash < 200:
		status_label.text = "Cannot hire! Insufficient funds (₱200 required, you have ₱%d)." % EconomyManager.cash
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if BuildingManager.hire_worker():
		status_label.text = "🎉 Hired worker! New autonomous farmer spawned at depot."
		status_label.modulate = Color(0.4, 1.0, 0.4)
		_populate_labor()
		worker_spawn_requested.emit()
	else:
		status_label.text = "Could not hire worker!"
		status_label.modulate = Color(1.0, 0.3, 0.3)

func _commission_drone() -> void:
	if not BuildingManager.has_drone_station():
		if BuildingManager.has_constructing_building("drone_station"):
			var rem: float = BuildingManager.get_building_construction_time_remaining("drone_station")
			status_label.text = "Drone Command Hangar is under construction (%.0fs left)! Please wait for it to complete." % rem
			status_label.modulate = Color(1.0, 0.75, 0.2)
		else:
			status_label.text = "Cannot commission drone! Construct a Drone Command Hangar (Machinery & Drones tab) first."
			status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if BuildingManager.active_drones >= BuildingManager.get_drone_capacity():
		status_label.text = "Cannot commission drone! Drone pilot limit reached (%d/%d farmers). Hire more farmers to control more drones." % [
			BuildingManager.active_drones, BuildingManager.active_workers
		]
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if EconomyManager.cash < 350:
		status_label.text = "Cannot commission drone! Insufficient funds (₱350 required, you have ₱%d)." % EconomyManager.cash
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if BuildingManager.commission_drone(350):
		status_label.text = "🛸 Commissioned Farm Drone #%d! Remote control unlocked on worker hotbar (hotkey 4)." % BuildingManager.active_drones
		status_label.modulate = Color(0.4, 1.0, 0.4)
		_populate_labor()
		item_purchased.emit("farm_drone", 350)
	else:
		status_label.text = "Could not commission drone!"
		status_label.modulate = Color(1.0, 0.3, 0.3)

func _on_close_pressed() -> void:
	if item_info_card:
		item_info_card.visible = false
	visible = false
