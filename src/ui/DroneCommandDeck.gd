# DroneCommandDeck.gd
# Dedicated Autonomous Drone Command Center & Precision Agriculture Workstation.
# Operates 100% independently from human workers.

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

# UI References
var _status_badge: Label = null
var _fleet_label: Label = null
var _zone_summary_label: Label = null
var _diagnostics_label: Label = null
var _crop_buttons: Dictionary = {}
var _directive_buttons: Dictionary = {}

var _zone_btn: Button = null
var _patrol_btn: Button = null
var _recall_btn: Button = null

# No-hangar notice container
var _content_box: VBoxContainer = null
var _no_hangar_box: VBoxContainer = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	z_index = 175
	custom_minimum_size = Vector2(760, 420)

	# Positioning: centered in viewport
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	_setup_frame_style()
	_build_ui()

	# Re-sync when hangar is built or drones commissioned
	BuildingManager.building_placed.connect(func(_b): _refresh_hangar_state())
	BuildingManager.drone_commissioned.connect(func(_d): _refresh_hangar_state())

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
	main_margin.add_theme_constant_override("margin_left", 22)
	main_margin.add_theme_constant_override("margin_right", 22)
	main_margin.add_theme_constant_override("margin_top", 14)
	main_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(main_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
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
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Independent Precision Agriculture • Autonomous Field Automation"
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72))
	title_vbox.add_child(sub_lbl)

	# Live Status Badge
	_status_badge = Label.new()
	_status_badge.text = "⚪ STANDING BY"
	_status_badge.add_theme_font_size_override("font_size", 12)
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
	no_hangar_desc.text = "To unlock autonomous aerial farm drones, build a Drone Command Hangar on your farm.\nUpgrading the hangar advances automation capabilities from autonomous soil plowing & watering\nto precision seeding and full-cycle harvesting delivery to the Bodega."
	no_hangar_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_hangar_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	no_hangar_desc.add_theme_font_size_override("font_size", 13)
	no_hangar_desc.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
	_no_hangar_box.add_child(no_hangar_desc)

	var open_shop_btn := Button.new()
	open_shop_btn.text = "🛒 OPEN AGRI-SHOP (MACHINERY & DRONES)"
	open_shop_btn.custom_minimum_size = Vector2(340, 42)
	open_shop_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
		open_shop_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
		open_shop_btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
	open_shop_btn.pressed.connect(func():
		close()
		var hud = get_tree().root.find_child("HUDLayer", true, false)
		if hud and hud.has_method("_on_shop_toggle_pressed"):
			hud._on_shop_toggle_pressed()
	)
	_no_hangar_box.add_child(open_shop_btn)

	# --- 3. ACTIVE COMMAND DECK CONTENT ---
	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 10)
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_content_box)

	# Telemetry Bar (Fleet & Capability status)
	var telemetry_bar := HBoxContainer.new()
	telemetry_bar.add_theme_constant_override("separation", 16)
	_content_box.add_child(telemetry_bar)

	_fleet_label = Label.new()
	_fleet_label.text = "🛸 Fleet: 1 Active Drone • Hangar Lv.1 (Autonomous Plow & Hydration)"
	_fleet_label.add_theme_font_size_override("font_size", 13)
	_fleet_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	_fleet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	telemetry_bar.add_child(_fleet_label)

	_zone_summary_label = Label.new()
	_zone_summary_label.text = "📍 Zone: Standing by (No active zone)"
	_zone_summary_label.add_theme_font_size_override("font_size", 13)
	_zone_summary_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	telemetry_bar.add_child(_zone_summary_label)

	# Action Controls Row
	var action_bar := HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 10)
	_content_box.add_child(action_bar)

	_zone_btn = Button.new()
	_zone_btn.text = "🎯 DESIGNATE ZONE (DRAG FIELD)"
	_zone_btn.custom_minimum_size = Vector2(230, 38)
	_zone_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
		_zone_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
		_zone_btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
	_zone_btn.pressed.connect(_on_designate_zone_pressed)
	action_bar.add_child(_zone_btn)

	_patrol_btn = Button.new()
	_patrol_btn.text = "🌐 AUTO-PATROL ENTIRE FARM (1-CLICK)"
	_patrol_btn.custom_minimum_size = Vector2(260, 38)
	_patrol_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
		_patrol_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
		_patrol_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	_patrol_btn.pressed.connect(_on_patrol_whole_farm_pressed)
	action_bar.add_child(_patrol_btn)

	_recall_btn = Button.new()
	_recall_btn.text = "🏠 RETURN & DOCK (RECALL)"
	_recall_btn.custom_minimum_size = Vector2(190, 38)
	_recall_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
		_recall_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
		_recall_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	_recall_btn.pressed.connect(_on_recall_pressed)
	action_bar.add_child(_recall_btn)

	# --- CROP SELECTION SECTION ---
	var crop_section := VBoxContainer.new()
	crop_section.add_theme_constant_override("separation", 4)
	_content_box.add_child(crop_section)

	var crop_hdr := Label.new()
	crop_hdr.text = "🌱 DESIGNATED AUTOMATION SEED (Independent of Worker Hotbar):"
	crop_hdr.add_theme_font_size_override("font_size", 12)
	crop_hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	crop_section.add_child(crop_hdr)

	var crops_hbox := HBoxContainer.new()
	crops_hbox.add_theme_constant_override("separation", 6)
	crop_section.add_child(crops_hbox)

	for c in CROPS_LIST:
		var c_id: String = c.id
		var btn := Button.new()
		btn.name = "DroneCrop_" + c_id
		btn.text = "%s %s\n₱%d" % [c.icon, c.name.split(" ")[0], c.cost]
		btn.custom_minimum_size = Vector2(94, 42)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(func(): _on_crop_selected(c_id))
		crops_hbox.add_child(btn)
		_crop_buttons[c_id] = btn

	# --- AUTOMATION DIRECTIVES CHECKLIST ---
	var dir_section := VBoxContainer.new()
	dir_section.add_theme_constant_override("separation", 4)
	_content_box.add_child(dir_section)

	var dir_hdr := Label.new()
	dir_hdr.text = "⚙️ ACTIVE AUTOMATION DIRECTIVES (Click to Toggle Behaviors):"
	dir_hdr.add_theme_font_size_override("font_size", 12)
	dir_hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	dir_section.add_child(dir_hdr)

	var dir_grid := GridContainer.new()
	dir_grid.columns = 3
	dir_grid.add_theme_constant_override("h_separation", 8)
	dir_grid.add_theme_constant_override("v_separation", 6)
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
		d_btn.custom_minimum_size = Vector2(230, 32)
		d_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		d_btn.add_theme_font_size_override("font_size", 11)
		d_btn.pressed.connect(func(): _toggle_directive(d_key))
		dir_grid.add_child(d_btn)
		_directive_buttons[d_key] = d_btn

	# Diagnostics line
	_diagnostics_label = Label.new()
	_diagnostics_label.text = "💡 Guide: Select 'Designate Zone' to drag a custom field box, or click 'Auto-Patrol Entire Farm' for complete automation."
	_diagnostics_label.add_theme_font_size_override("font_size", 11)
	_diagnostics_label.add_theme_color_override("font_color", Color(0.75, 0.92, 0.85))
	_diagnostics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_box.add_child(_diagnostics_label)

func _get_primary_drone() -> FarmDrone:
	if farm_grid and "drone" in farm_grid and is_instance_valid(farm_grid.drone):
		return farm_grid.drone
	return null

func refresh_all() -> void:
	_refresh_hangar_state()
	var d := _get_primary_drone()
	if d == null or not is_instance_valid(d):
		return

	# Telemetry
	var t: Dictionary = d.get_telemetry()
	var lvl: int = d.get_level()
	var lvl_names := ["", "Lv.1 Ground Prep & Irrigation", "Lv.2 Precision Seeder & IPM", "Lv.3 Full Agricultural Loop"]
	var lvl_title: String = lvl_names[clampi(lvl, 0, 3)] if lvl > 0 else "Hangar Under Construction"
	_fleet_label.text = "🛸 Fleet: %d Active Drone(s) • %s" % [BuildingManager.active_drones, lvl_title]

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
		var zone_type: String = "全 Farm Patrol" if is_whole else "Custom Zone"
		_zone_summary_label.text = "📍 %s: %d Plots (%d Ready • %d Thirsty • %d Blighted • %d Growing)" % [
			zone_type, z_cnt,
			int(t.get("harvestable_count", 0)),
			int(t.get("thirsty_count", 0)),
			int(t.get("infected_count", 0)),
			int(t.get("growing_count", 0))
		]
	else:
		_zone_summary_label.text = "📍 Zone: Docked at Hangar (Ready for assignment)"

	# Highlight active crop
	for c_id in _crop_buttons:
		var btn: Button = _crop_buttons[c_id]
		var is_cur: bool = (c_id == d.crop_type)
		if is_cur:
			if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
				btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
				btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
		else:
			if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
				btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
				btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))

	# Directive toggles styling
	_update_directive_button_visual("auto_plow", d.auto_plow, "⛏️", "Auto-Plow Soil")
	_update_directive_button_visual("auto_plant", d.auto_plant, "🌱", "Auto-Sow Seeds")
	_update_directive_button_visual("auto_water", d.auto_water, "💧", "Auto-Water Plots")
	_update_directive_button_visual("auto_spray", d.auto_spray, "🧪", "Auto-Pest Cure")
	_update_directive_button_visual("auto_harvest", d.auto_harvest, "🧺", "Auto-Harvest")
	_update_directive_button_visual("auto_clear", d.auto_clear, "🪓", "Auto-Clear Debris")

	# Diagnostics
	if not str(t.get("blocked_reason", "")).is_empty():
		_diagnostics_label.text = "⚠️ Active Alert: %s (Drone paused until condition resolves)" % str(t.get("blocked_reason", ""))
		_diagnostics_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.40))
	else:
		_diagnostics_label.text = "⚡ Telemetry Active • %d total operations executed hands-free • Farm Drone operating autonomously." % d.jobs_done
		_diagnostics_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.60))

func _update_directive_button_visual(key: String, is_on: bool, icon: String, title: String) -> void:
	var btn: Button = _directive_buttons.get(key, null)
	if not is_instance_valid(btn):
		return
	if is_on:
		btn.text = "☑ %s %s" % [icon, title]
		if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
			btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
			btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
	else:
		btn.text = "☐ %s %s (Off)" % [icon, title]
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
		d.crop_type = crop_id
		AudioManager.play_ui("click")
		refresh_all()
		LogManager.log_event("crops", "🛸 Drone automated seed set to: %s." % crop_id.capitalize(), "🛸", Color(0.4, 0.85, 1.0))

func _toggle_directive(key: String) -> void:
	var d := _get_primary_drone()
	if d:
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
	close()
	if farm_grid and farm_grid.has_method("start_drone_zone_designation"):
		farm_grid.start_drone_zone_designation()
	zone_designation_requested.emit()

func _on_patrol_whole_farm_pressed() -> void:
	var d := _get_primary_drone()
	if d and farm_grid:
		d.deploy_whole_farm()
		AudioManager.play_ui("click")
		refresh_all()

func _on_recall_pressed() -> void:
	var d := _get_primary_drone()
	if d:
		d.recall()
		AudioManager.play_ui("click")
		refresh_all()

func open() -> void:
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
