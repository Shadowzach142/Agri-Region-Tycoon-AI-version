# DroneCommandDeck.gd
# Dedicated Autonomous Drone Command Center & Precision Agriculture Workstation.
# Operates 100% independently from human workers with explicit capability lock indicators.

class_name DroneCommandDeck
extends PanelContainer

signal closed()
signal zone_designation_requested()

const CROPS_LIST: Array[Dictionary] = [
	{"id": "palay", "name": "Palay (Rice)", "cost": 25, "icon": "🌾", "tex": "res://assets/sprites/Field/Crops/Rice/RICE-P3.png"},
	{"id": "yellow_corn", "name": "Yellow Corn", "cost": 30, "icon": "🌽", "tex": "res://assets/sprites/Field/Crops/Corn/CORN-P3.png"},
	{"id": "sugarcane", "name": "Sugar Cane", "cost": 30, "icon": "🎋", "tex": "res://assets/sprites/Field/Crops/Sugarcane/SUGARCANE-P3.png"},
	{"id": "pineapple", "name": "Pineapple", "cost": 40, "icon": "🍍", "tex": "res://assets/sprites/Field/Crops/Pineapple/PINEAPPLE-P3.png"},
	{"id": "arabica_coffee", "name": "Coffee", "cost": 50, "icon": "☕", "tex": "res://assets/sprites/Field/Crops/Coffee/COFFEE-P3.png"},
	{"id": "banana", "name": "Banana", "cost": 140, "icon": "🍌", "tex": "res://assets/sprites/Field/Crops/Banana/BANANA-P4.png"},
	{"id": "coconut", "name": "Coconut Palm", "cost": 160, "icon": "🥥", "tex": "res://assets/sprites/Field/Crops/Coconut/COCONUT-P3.png"}
]

var farm_grid: Node2D = null
var active_drone_index: int = 1

# UI References
var _status_badge: Label = null
var _drone_tabs_box: HBoxContainer = null
var _fleet_label: Label = null
var _zone_summary_label: Label = null

# Capability Card References
var _ability_badge: Label = null
var _ability_details: Label = null
var _upgrade_shop_btn: Button = null

var _crop_hdr: Label = null
var _crop_buttons: Dictionary = {}
var _directive_buttons: Dictionary = {}

var _zone_btn: Button = null
var _patrol_btn: Button = null
var _recall_btn: Button = null
var _diagnostics_label: Label = null

# No-hangar notice container
var _content_box: VBoxContainer = null
var _no_hangar_box: VBoxContainer = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	z_index = 175
	custom_minimum_size = Vector2(800, 480)

	# Positioning: centered in viewport
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	_setup_frame_style()
	_build_ui()

	# Re-sync when hangar is built, drones commissioned, or seeds unlocked
	BuildingManager.building_placed.connect(func(_b): _refresh_hangar_state())
	BuildingManager.drone_commissioned.connect(func(_d): _refresh_hangar_state())
	if BuildingManager.has_signal("crop_unlocked"):
		BuildingManager.crop_unlocked.connect(func(_c): refresh_all())

func _setup_frame_style() -> void:
	if ResourceLoader.exists("res://assets/sprites/hud/Big-Rectangle-Box/Samplebox1.tres"):
		add_theme_stylebox_override("panel", load("res://assets/sprites/hud/Big-Rectangle-Box/Samplebox1.tres"))
	elif ResourceLoader.exists("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"):
		add_theme_stylebox_override("panel", load("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"))
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.08, 0.05, 0.98)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(0.85, 0.68, 0.30, 0.95)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		add_theme_stylebox_override("panel", sb)

func _build_ui() -> void:
	var main_margin := MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 20)
	main_margin.add_theme_constant_override("margin_right", 20)
	main_margin.add_theme_constant_override("margin_top", 12)
	main_margin.add_theme_constant_override("margin_bottom", 14)
	add_child(main_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	main_margin.add_child(root_vbox)

	# --- 1. HEADER ROW ---
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header_hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "🛸"
	icon_lbl.add_theme_font_size_override("font_size", 22)
	header_hbox.add_child(icon_lbl)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 1)
	header_hbox.add_child(title_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "AUTONOMOUS DRONE COMMAND DECK"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Independent Precision Agriculture • Autonomous Field Automation"
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72))
	title_vbox.add_child(sub_lbl)

	# Live Status Badge
	_status_badge = Label.new()
	_status_badge.text = "⚪ STANDING BY"
	_status_badge.add_theme_font_size_override("font_size", 11)
	_status_badge.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	header_hbox.add_child(_status_badge)

	# Close Button
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"):
		close_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"))
	close_btn.pressed.connect(func(): close())
	header_hbox.add_child(close_btn)

	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("separator_color", Color(0.7, 0.55, 0.35, 0.6))
	root_vbox.add_child(sep1)

	# --- 2. NO HANGAR VIEW ---
	_no_hangar_box = VBoxContainer.new()
	_no_hangar_box.add_theme_constant_override("separation", 14)
	_no_hangar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_no_hangar_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_no_hangar_box.visible = false
	root_vbox.add_child(_no_hangar_box)

	var no_hangar_title := Label.new()
	no_hangar_title.text = "🛸 Drone Command Hangar Not Built"
	no_hangar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_hangar_title.add_theme_font_size_override("font_size", 17)
	no_hangar_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	_no_hangar_box.add_child(no_hangar_title)

	var no_hangar_desc := Label.new()
	no_hangar_desc.text = "To unlock autonomous aerial farm drones, build a Drone Command Hangar on your farm.\nUpgrading the hangar advances capabilities from autonomous soil plowing & watering (Lv.1)\nto precision seeding and IPM pest treatment (Lv.2), and full-cycle harvesting delivery to the Bodega (Lv.3)."
	no_hangar_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_hangar_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	no_hangar_desc.add_theme_font_size_override("font_size", 12)
	no_hangar_desc.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
	_no_hangar_box.add_child(no_hangar_desc)

	var open_shop_btn := Button.new()
	open_shop_btn.text = "🛒 OPEN AGRI-SHOP (MACHINERY & DRONES)"
	open_shop_btn.custom_minimum_size = Vector2(340, 40)
	open_shop_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
		open_shop_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
		open_shop_btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
	open_shop_btn.pressed.connect(_on_upgrade_shop_pressed)
	_no_hangar_box.add_child(open_shop_btn)

	# --- 3. ACTIVE COMMAND DECK CONTENT ---
	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 8)
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_content_box)

	# Unit Tabs Selector Bar (Multi-drone individual switching)
	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.custom_minimum_size = Vector2(0, 34)
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content_box.add_child(tabs_scroll)

	_drone_tabs_box = HBoxContainer.new()
	_drone_tabs_box.add_theme_constant_override("separation", 8)
	tabs_scroll.add_child(_drone_tabs_box)

	# Telemetry Bar (Fleet & Capability status)
	var telemetry_bar := HBoxContainer.new()
	telemetry_bar.add_theme_constant_override("separation", 16)
	_content_box.add_child(telemetry_bar)

	_fleet_label = Label.new()
	_fleet_label.text = "🛸 Fleet: 1 Active Drone • Hangar Lv.1 (Ground Prep & Hydration)"
	_fleet_label.add_theme_font_size_override("font_size", 12)
	_fleet_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	_fleet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	telemetry_bar.add_child(_fleet_label)

	_zone_summary_label = Label.new()
	_zone_summary_label.text = "📍 Zone: Standing by (No active zone)"
	_zone_summary_label.add_theme_font_size_override("font_size", 12)
	_zone_summary_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	telemetry_bar.add_child(_zone_summary_label)

	# --- PROMINENT CAPABILITY CARD ---
	var ability_card := PanelContainer.new()
	var ac_sb := StyleBoxFlat.new()
	ac_sb.bg_color = Color(0.08, 0.05, 0.03, 0.85)
	ac_sb.border_width_left = 1
	ac_sb.border_width_top = 1
	ac_sb.border_width_right = 1
	ac_sb.border_width_bottom = 1
	ac_sb.border_color = Color(0.70, 0.55, 0.30, 0.80)
	ac_sb.corner_radius_top_left = 4
	ac_sb.corner_radius_top_right = 4
	ac_sb.corner_radius_bottom_left = 4
	ac_sb.corner_radius_bottom_right = 4
	ac_sb.content_margin_left = 10
	ac_sb.content_margin_right = 10
	ac_sb.content_margin_top = 6
	ac_sb.content_margin_bottom = 6
	ability_card.add_theme_stylebox_override("panel", ac_sb)
	_content_box.add_child(ability_card)

	var ac_hbox := HBoxContainer.new()
	ac_hbox.add_theme_constant_override("separation", 10)
	ability_card.add_child(ac_hbox)

	var ac_vbox := VBoxContainer.new()
	ac_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ac_vbox.add_theme_constant_override("separation", 2)
	ac_hbox.add_child(ac_vbox)

	_ability_badge = Label.new()
	_ability_badge.text = "⚡ LEVEL 1: GROUND PREPARATION & IRRIGATION"
	_ability_badge.add_theme_font_size_override("font_size", 12)
	_ability_badge.add_theme_color_override("font_color", Color(1.0, 0.80, 0.28))
	ac_vbox.add_child(_ability_badge)

	_ability_details = Label.new()
	_ability_details.text = "✔ Auto-Plow Dirt   ✔ Auto-Water (<50%)   |   🔒 Sowing (Req. Lv.2)   🔒 Blight IPM (Req. Lv.2)   🔒 Harvest (Req. Lv.3)"
	_ability_details.add_theme_font_size_override("font_size", 10)
	_ability_details.add_theme_color_override("font_color", Color(0.92, 0.85, 0.72))
	ac_vbox.add_child(_ability_details)

	_upgrade_shop_btn = Button.new()
	_upgrade_shop_btn.text = "🛒 Upgrade in Agri-Shop"
	_upgrade_shop_btn.custom_minimum_size = Vector2(170, 28)
	_upgrade_shop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_upgrade_shop_btn.tooltip_text = "Open Agri-Shop Machinery tab to upgrade Drone Command Hangar"
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
		_upgrade_shop_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
		_upgrade_shop_btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
	_upgrade_shop_btn.pressed.connect(_on_upgrade_shop_pressed)
	ac_hbox.add_child(_upgrade_shop_btn)

	# Action Controls Row
	var action_bar := HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 10)
	_content_box.add_child(action_bar)

	_zone_btn = Button.new()
	_zone_btn.text = "🎯 DESIGNATE ZONE (DRAG FIELD)"
	_zone_btn.custom_minimum_size = Vector2(230, 34)
	_zone_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
		_zone_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
		_zone_btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
	_zone_btn.pressed.connect(_on_designate_zone_pressed)
	action_bar.add_child(_zone_btn)

	_patrol_btn = Button.new()
	_patrol_btn.text = "🌐 AUTO-PATROL ENTIRE FARM (1-CLICK)"
	_patrol_btn.custom_minimum_size = Vector2(260, 34)
	_patrol_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
		_patrol_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
		_patrol_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	_patrol_btn.pressed.connect(_on_patrol_whole_farm_pressed)
	action_bar.add_child(_patrol_btn)

	_recall_btn = Button.new()
	_recall_btn.text = "🏠 RETURN & DOCK (RECALL)"
	_recall_btn.custom_minimum_size = Vector2(190, 34)
	_recall_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
		_recall_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
		_recall_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	_recall_btn.pressed.connect(_on_recall_pressed)
	action_bar.add_child(_recall_btn)

	# --- CROP SELECTION SECTION ---
	var crop_section := VBoxContainer.new()
	crop_section.add_theme_constant_override("separation", 3)
	_content_box.add_child(crop_section)

	_crop_hdr = Label.new()
	_crop_hdr.text = "🌱 DESIGNATED AUTOMATION SEED (Independent of Worker Hotbar):"
	_crop_hdr.add_theme_font_size_override("font_size", 11)
	_crop_hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	crop_section.add_child(_crop_hdr)

	var crops_hbox := HBoxContainer.new()
	crops_hbox.add_theme_constant_override("separation", 6)
	crop_section.add_child(crops_hbox)

	for c in CROPS_LIST:
		var c_id: String = c.id
		var btn := Button.new()
		btn.name = "DroneCrop_" + c_id
		btn.text = "%s %s\n₱%d" % [c.icon, c.name.split(" ")[0], c.cost]
		btn.custom_minimum_size = Vector2(94, 38)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(func(): _on_crop_selected(c_id))
		crops_hbox.add_child(btn)
		_crop_buttons[c_id] = btn

	# --- AUTOMATION DIRECTIVES CHECKLIST ---
	var dir_section := VBoxContainer.new()
	dir_section.add_theme_constant_override("separation", 3)
	_content_box.add_child(dir_section)

	var dir_hdr := Label.new()
	dir_hdr.text = "⚙️ ACTIVE AUTOMATION DIRECTIVES (Capability-gated behaviors):"
	dir_hdr.add_theme_font_size_override("font_size", 11)
	dir_hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	dir_section.add_child(dir_hdr)

	var dir_grid := GridContainer.new()
	dir_grid.columns = 3
	dir_grid.add_theme_constant_override("h_separation", 8)
	dir_grid.add_theme_constant_override("v_separation", 4)
	dir_section.add_child(dir_grid)

	var directives := [
		{"key": "auto_plow", "title": "Auto-Plow Soil", "icon": "⛏️", "desc": "Tills untilled/receded dirt"},
		{"key": "auto_plant", "title": "Auto-Sow Seeds", "icon": "🌱", "desc": "Sows designated seeds"},
		{"key": "auto_water", "title": "Auto-Water Plots", "icon": "💧", "desc": "Hydrates thirsty crops (<50%)"},
		{"key": "auto_spray", "title": "Auto-Pest Cure", "icon": "🧪", "desc": "Cures blighted crops (IPM)"},
		{"key": "auto_harvest", "title": "Auto-Harvest Produce", "icon": "🧺", "desc": "Reaps ripe crops to Bodega"},
		{"key": "auto_clear", "title": "Auto-Clear Debris", "icon": "🪓", "desc": "Excavates timber & rocks"}
	]

	for d in directives:
		var d_key: String = d.key
		var d_btn := Button.new()
		d_btn.name = "Directive_" + d_key
		d_btn.text = "☑ %s %s" % [d.icon, d.title]
		d_btn.custom_minimum_size = Vector2(235, 30)
		d_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		d_btn.add_theme_font_size_override("font_size", 10)
		d_btn.pressed.connect(func(): _toggle_directive(d_key))
		dir_grid.add_child(d_btn)
		_directive_buttons[d_key] = d_btn

	# Diagnostics line
	_diagnostics_label = Label.new()
	_diagnostics_label.text = "💡 Guide: Select 'Designate Zone' to drag a custom field box, or click 'Auto-Patrol Entire Farm' for complete automation."
	_diagnostics_label.add_theme_font_size_override("font_size", 10)
	_diagnostics_label.add_theme_color_override("font_color", Color(0.75, 0.92, 0.85))
	_diagnostics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_box.add_child(_diagnostics_label)

func _get_primary_drone() -> FarmDrone:
	if farm_grid:
		if farm_grid.has_method("get_selected_drone"):
			var sel: FarmDrone = farm_grid.get_selected_drone()
			if is_instance_valid(sel):
				return sel
		if "drones" in farm_grid:
			for d in farm_grid.drones:
				if is_instance_valid(d) and d.drone_index == active_drone_index:
					return d
			if not farm_grid.drones.is_empty() and is_instance_valid(farm_grid.drones[0]):
				return farm_grid.drones[0]
	return null

func _refresh_drone_tabs() -> void:
	if _drone_tabs_box == null:
		return
	for ch in _drone_tabs_box.get_children():
		_drone_tabs_box.remove_child(ch)
		ch.queue_free()

	if farm_grid == null or not ("drones" in farm_grid):
		return

	var drones_list: Array = farm_grid.drones
	for d in drones_list:
		if not is_instance_valid(d):
			continue
		var d_btn := Button.new()
		d_btn.custom_minimum_size = Vector2(155, 30)
		d_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		d_btn.add_theme_font_size_override("font_size", 10)

		var is_cur: bool = (d.drone_index == active_drone_index)
		var lvl: int = d.get_level()
		var crop_name: String = str(Data.get_crop(d.crop_type).get("display_name", d.crop_type)).split(" ")[0]
		var status_icon: String = "🟢" if d.state == FarmDrone.State.WORKING else ("🔵" if d.state == FarmDrone.State.FLYING else ("🟡" if d.has_zone() else "⚪"))

		if lvl == 1:
			d_btn.text = "%s %s (Lv.1 - Prep)" % [status_icon, d.get_drone_name()]
		else:
			d_btn.text = "%s %s: %s (Lv.%d)" % [status_icon, d.get_drone_name(), crop_name, lvl]

		if is_cur:
			if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
				d_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
				d_btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
		else:
			if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
				d_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
				d_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))

		var d_idx: int = d.drone_index
		d_btn.pressed.connect(func():
			active_drone_index = d_idx
			if farm_grid and farm_grid.has_method("select_drone_by_index"):
				farm_grid.select_drone_by_index(d_idx)
			refresh_all()
		)
		_drone_tabs_box.add_child(d_btn)

	# "+ Build Landing Pad" shortcut button
	var add_hangar_btn := Button.new()
	add_hangar_btn.text = "➕ Build Pad in Shop" if BuildingManager.has_drone_station() else "➕ Build Hangar in Shop"
	add_hangar_btn.custom_minimum_size = Vector2(150, 30)
	add_hangar_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_hangar_btn.add_theme_font_size_override("font_size", 10)
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"):
		add_hangar_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"))
	add_hangar_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	add_hangar_btn.pressed.connect(_on_upgrade_shop_pressed)
	_drone_tabs_box.add_child(add_hangar_btn)

func refresh_all() -> void:
	_refresh_hangar_state()
	_refresh_drone_tabs()
	var d := _get_primary_drone()
	if d == null or not is_instance_valid(d):
		return

	# Telemetry & Capabilities
	var t: Dictionary = d.get_telemetry()
	var lvl: int = d.get_level()
	var lvl_names := ["", "Lv.1 Ground Prep & Irrigation", "Lv.2 Precision Seeder & IPM", "Lv.3 Full Agricultural Loop"]
	var lvl_title: String = lvl_names[clampi(lvl, 0, 3)] if lvl > 0 else "Hangar Under Construction"
	_fleet_label.text = "🛸 %s • Fleet Avionics Lv.%d (%s) • Fleet: %d/%d Drone(s)" % [d.get_drone_name(), lvl, lvl_title, BuildingManager.active_drones, BuildingManager.get_drone_capacity()]

	# Capability Card Update
	if lvl == 1:
		_ability_badge.text = "⚡ LEVEL 1: GROUND PREPARATION & IRRIGATION"
		_ability_badge.add_theme_color_override("font_color", Color(1.0, 0.80, 0.28))
		_ability_details.text = "✔ Autonomous Dirt Plowing   ✔ Plot Hydration (<50%)   |   🔒 Sowing (Req. Lv.2)   🔒 Blight IPM (Req. Lv.2)   🔒 Harvest (Req. Lv.3)"
		_ability_details.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
		_upgrade_shop_btn.visible = true
		_upgrade_shop_btn.text = "🛒 Upgrade to Hangar Lv.2 in Shop"
	elif lvl == 2:
		_ability_badge.text = "🌱 LEVEL 2: PRECISION SEEDER & BIOCONTROL"
		_ability_badge.add_theme_color_override("font_color", Color(0.40, 1.0, 0.55))
		_ability_details.text = "✔ Dirt Plowing   ✔ Sowing Designated Seed   ✔ Plot Hydration   ✔ Pest Blight Curing (IPM)   |   🔒 Harvest to Bodega (Req. Lv.3)"
		_ability_details.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
		_upgrade_shop_btn.visible = true
		_upgrade_shop_btn.text = "🛒 Upgrade to Hangar Lv.3 in Shop"
	else:
		_ability_badge.text = "⚡ LEVEL 3: FULL AUTONOMOUS AGRICULTURAL LOOP"
		_ability_badge.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
		_ability_details.text = "✔ Complete Loop: Plow ➔ Sow ➔ Water ➔ IPM Spray ➔ Harvest & Deliver to Bodega ➔ Clear Obstacles"
		_ability_details.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
		_upgrade_shop_btn.visible = false

	# Status badge
	var act: String = t.get("current_action", "Standing By")
	var s_name: String = t.get("state_name", "IDLE")
	if not str(t.get("blocked_reason", "")).is_empty() and s_name == "IDLE":
		_status_badge.text = "⚠️ %s" % str(t.get("blocked_reason", "")).to_upper()
		_status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	elif s_name == "WORKING":
		_status_badge.text = "🟢 WORKING: %s" % act
		_status_badge.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
	elif s_name == "FLYING":
		_status_badge.text = "🔵 EN ROUTE: %s" % act
		_status_badge.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	elif d.has_zone():
		_status_badge.text = "🟡 PATROLLING ZONE"
		_status_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	else:
		_status_badge.text = "⚪ DOCKED AT HANGAR"
		_status_badge.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	# Zone summary
	if d.has_zone():
		var z_cnt: int = int(t.get("zone_count", 0))
		var is_whole: bool = bool(t.get("is_whole_farm", false))
		var zone_type: String = "All Farm Patrol" if is_whole else "Custom Zone"
		_zone_summary_label.text = "📍 %s: %d Plots (%d Ready • %d Thirsty • %d Blighted • %d Growing)" % [
			zone_type, z_cnt,
			int(t.get("harvestable_count", 0)),
			int(t.get("thirsty_count", 0)),
			int(t.get("infected_count", 0)),
			int(t.get("growing_count", 0))
		]
	else:
		_zone_summary_label.text = "📍 Zone: Docked at Hangar (Ready for assignment)"

	# Crop Selection Handling
	if lvl < 2:
		_crop_hdr.text = "🌱 DESIGNATED AUTOMATION SEED: 🔒 SOWING LOCKED (Requires Hangar Lv.2 in Agri-Shop)"
		_crop_hdr.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	else:
		_crop_hdr.text = "🌱 DESIGNATED AUTOMATION SEED (Independent of Worker Hotbar):"
		_crop_hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	for c_id in _crop_buttons:
		var btn: Button = _crop_buttons[c_id]
		var c_info: Dictionary = {}
		for item in CROPS_LIST:
			if item.id == c_id:
				c_info = item
				break

		if lvl < 2:
			btn.disabled = true
			btn.text = "🔒 %s\n(Lv.2 Req)" % str(c_info.get("name", c_id.capitalize())).split(" ")[0]
			btn.tooltip_text = "🔒 Sowing locked! Drone is Lv.1 (Ground Prep only). Upgrade Hangar to Lv.2 in Agri-Shop to sow %s." % c_id.capitalize()
			if ResourceLoader.exists("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres"):
				btn.add_theme_stylebox_override("disabled", load("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres"))
			btn.add_theme_color_override("font_disabled_color", Color(0.60, 0.55, 0.50))
		else:
			var is_unlocked: bool = BuildingManager.is_crop_unlocked(c_id)
			var is_cur: bool = (c_id == d.crop_type)
			btn.disabled = not is_unlocked

			if not is_unlocked:
				btn.text = "🔒 %s\nLocked" % str(c_info.get("name", c_id.capitalize())).split(" ")[0]
				btn.tooltip_text = "Unlock %s variety in the Agri-Shop before assigning to drone!" % c_id.capitalize()
				if ResourceLoader.exists("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres"):
					btn.add_theme_stylebox_override("disabled", load("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres"))
				btn.add_theme_color_override("font_disabled_color", Color(0.60, 0.55, 0.50))
			elif is_cur:
				btn.text = "✔ %s\n₱%d" % [str(c_info.get("name", c_id.capitalize())).split(" ")[0], c_info.get("cost", 25)]
				btn.tooltip_text = "Currently selected for autonomous sowing."
				if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
					btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
					btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
			else:
				btn.text = "%s %s\n₱%d" % [c_info.get("icon", "🌱"), str(c_info.get("name", c_id.capitalize())).split(" ")[0], c_info.get("cost", 25)]
				btn.tooltip_text = "Assign %s to automated sowing." % c_id.capitalize()
				if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
					btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
					btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))

	# Directive toggles styling with capability gating
	_update_directive_button_visual("auto_plow", d.auto_plow, "⛏️", "Auto-Plow Soil", false, 1, "")
	_update_directive_button_visual("auto_plant", d.auto_plant, "🌱", "Auto-Sow Seeds", lvl < 2, 2, "Upgrade Hangar to Lv.2 in Agri-Shop to unlock seed planting.")
	_update_directive_button_visual("auto_water", d.auto_water, "💧", "Auto-Water Plots", false, 1, "")
	_update_directive_button_visual("auto_spray", d.auto_spray, "🧪", "Auto-Pest Cure", lvl < 2, 2, "Upgrade Hangar to Lv.2 in Agri-Shop to unlock IPM pest misting.")
	_update_directive_button_visual("auto_harvest", d.auto_harvest, "🧺", "Auto-Harvest", lvl < 3, 3, "Upgrade Hangar to Lv.3 in Agri-Shop to unlock produce harvesting.")
	_update_directive_button_visual("auto_clear", d.auto_clear, "🪓", "Auto-Clear Debris", lvl < 3, 3, "Upgrade Hangar to Lv.3 in Agri-Shop to unlock debris clearing.")

	# Diagnostics
	if not str(t.get("blocked_reason", "")).is_empty():
		_diagnostics_label.text = "⚠️ Active Alert: %s (Drone paused until condition resolves)" % str(t.get("blocked_reason", ""))
		_diagnostics_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.40))
	else:
		_diagnostics_label.text = "⚡ Telemetry Active • %s executing operations autonomously hands-free." % d.get_drone_name()
		_diagnostics_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.60))

func _update_directive_button_visual(key: String, is_on: bool, icon: String, title: String, is_locked: bool, req_lvl: int, lock_hint: String) -> void:
	var btn: Button = _directive_buttons.get(key, null)
	if not is_instance_valid(btn):
		return
	if is_locked:
		btn.disabled = true
		btn.text = "🔒 %s %s (Lv.%d Req)" % [icon, title, req_lvl]
		btn.tooltip_text = "🔒 LOCKED: %s" % lock_hint
		if ResourceLoader.exists("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres"):
			btn.add_theme_stylebox_override("disabled", load("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres"))
		btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.58, 0.50))
	else:
		btn.disabled = false
		if is_on:
			btn.text = "☑ %s %s" % [icon, title]
			btn.tooltip_text = "Click to toggle %s directive." % title
			if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
				btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
				btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
		else:
			btn.text = "☐ %s %s (Off)" % [icon, title]
			btn.tooltip_text = "Click to toggle %s directive." % title
			if ResourceLoader.exists("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres"):
				btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres"))
				btn.add_theme_color_override("font_color", Color(0.70, 0.65, 0.58))
			elif ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
				btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
				btn.add_theme_color_override("font_color", Color(0.70, 0.65, 0.58))

func _refresh_hangar_state() -> void:
	var has_hangar: bool = BuildingManager.has_drone_station()
	_no_hangar_box.visible = not has_hangar
	_content_box.visible = has_hangar

func _on_crop_selected(crop_id: String) -> void:
	var d := _get_primary_drone()
	if d:
		if d.get_level() < 2:
			AudioManager.play_ui("error")
			LogManager.log_event("crops", "🔒 Sowing locked: Drone is Lv.1. Upgrade Hangar to Lv.2 in Agri-Shop to sow crops!", "🛸", Color(1.0, 0.65, 0.40))
			return
		d.set_crop(crop_id)
		AudioManager.play_ui("click")
		refresh_all()
		var qbar = get_tree().root.find_child("DroneQuickBar", true, false)
		if qbar and qbar.has_method("refresh_all"):
			qbar.refresh_all()

func _toggle_directive(key: String) -> void:
	var d := _get_primary_drone()
	if d:
		var lvl: int = d.get_level()
		if (key == "auto_plant" or key == "auto_spray") and lvl < 2:
			AudioManager.play_ui("error")
			LogManager.log_event("crops", "🔒 Directive locked: Requires Hangar Lv.2 in Agri-Shop!", "🛸", Color(1.0, 0.65, 0.40))
			return
		if (key == "auto_harvest" or key == "auto_clear") and lvl < 3:
			AudioManager.play_ui("error")
			LogManager.log_event("crops", "🔒 Directive locked: Requires Hangar Lv.3 in Agri-Shop!", "🛸", Color(1.0, 0.65, 0.40))
			return

		match key:
			"auto_plow": d.auto_plow = not d.auto_plow
			"auto_plant": d.auto_plant = not d.auto_plant
			"auto_water": d.auto_water = not d.auto_water
			"auto_spray": d.auto_spray = not d.auto_spray
			"auto_harvest": d.auto_harvest = not d.auto_harvest
			"auto_clear": d.auto_clear = not d.auto_clear
		AudioManager.play_ui("click")
		refresh_all()

func _on_designate_zone_pressed() -> void:
	var d := _get_primary_drone()
	var c_type: String = d.crop_type if d else ""
	var d_idx: int = d.drone_index if d else 1
	close()
	if farm_grid and farm_grid.has_method("start_drone_zone_designation"):
		farm_grid.start_drone_zone_designation(c_type, d_idx)
	zone_designation_requested.emit()

func _on_patrol_whole_farm_pressed() -> void:
	var d := _get_primary_drone()
	if d and farm_grid:
		d.deploy_whole_farm(d.crop_type)
		AudioManager.play_ui("click")
		refresh_all()

func _on_recall_pressed() -> void:
	var d := _get_primary_drone()
	if d:
		d.recall()
		AudioManager.play_ui("click")
		refresh_all()

func _on_upgrade_shop_pressed() -> void:
	close()
	var hud = get_tree().root.find_child("HUDLayer", true, false)
	if hud and hud.has_method("_on_shop_toggle_pressed"):
		hud._on_shop_toggle_pressed()
	var shop = get_tree().root.find_child("ShopPanel", true, false)
	if shop and shop.has_method("_on_tab_pressed"):
		shop._on_tab_pressed("machinery")

func open() -> void:
	if farm_grid and farm_grid.has_method("get_selected_drone"):
		var sel: FarmDrone = farm_grid.get_selected_drone()
		if is_instance_valid(sel):
			active_drone_index = sel.drone_index
	visible = true
	refresh_all()
	AudioManager.play_ui("click")

func close() -> void:
	visible = false
	closed.emit()
	AudioManager.play_ui("click")

func toggle() -> void:
	if visible:
		close()
	else:
		open()
