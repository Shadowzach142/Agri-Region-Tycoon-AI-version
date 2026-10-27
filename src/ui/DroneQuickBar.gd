# DroneQuickBar.gd
# Minimalist, sleek floating capsule HUD for drone unit switching, capability telemetry, crop selection, and field designation.
# Anchored above the hotbar in a compact single-row pill layout with zero screen clutter.

class_name DroneQuickBar
extends PanelContainer

var farm_grid: Node2D = null

const CROPS_LIST: Array[Dictionary] = [
	{"id": "palay", "short": "Palay", "icon": "🌾", "cost": 25},
	{"id": "yellow_corn", "short": "Corn", "icon": "🌽", "cost": 30},
	{"id": "sugarcane", "short": "Cane", "icon": "🎋", "cost": 30},
	{"id": "pineapple", "short": "Pine", "icon": "🍍", "cost": 40},
	{"id": "arabica_coffee", "short": "Coffee", "icon": "☕", "cost": 50},
	{"id": "banana", "short": "Banana", "icon": "🍌", "cost": 140},
	{"id": "coconut", "short": "Coco", "icon": "🥥", "cost": 160}
]

# Single-Row Capsule Controls
var _drone_cycle_btn: Button = null
var _crop_btn: Button = null
var _drag_field_btn: Button = null
var _patrol_btn: Button = null
var _recall_btn: Button = null
var _deck_btn: Button = null
var _close_btn: Button = null

# Floating Crop Picker Flyout
var _crop_popup_panel: PanelContainer = null
var _crop_popup_buttons: Dictionary = {}
var _user_closed: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	z_index = 170

	# Anchored centered above the hotbar (450px wide × 38px high capsule pill)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -225.0
	offset_right = 225.0
	offset_top = -122.0
	offset_bottom = -84.0

	_setup_frame_style()
	_build_ui()
	_build_crop_popup()

	BuildingManager.building_placed.connect(func(_b): _check_visibility())
	BuildingManager.drone_commissioned.connect(func(_d): _check_visibility())
	if BuildingManager.has_signal("crop_unlocked"):
		BuildingManager.crop_unlocked.connect(func(_c): refresh_all())

func _setup_frame_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.06, 0.92) # Translucent dark espresso glass
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.68, 0.32, 0.85) # Warm gold trim
	sb.corner_radius_top_left = 19
	sb.corner_radius_top_right = 19
	sb.corner_radius_bottom_left = 19
	sb.corner_radius_bottom_right = 19
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 5
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	add_theme_stylebox_override("panel", sb)

func _build_ui() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	# 1. Drone Cycler Pill
	_drone_cycle_btn = Button.new()
	_style_button(_drone_cycle_btn, 104, Color(0.24, 0.17, 0.10, 0.95), Color(1.0, 0.88, 0.45))
	_drone_cycle_btn.text = "🛸 #1 (Lv.1)"
	_drone_cycle_btn.tooltip_text = "Click to cycle between active drones\nRight-click to open Command Deck"
	_drone_cycle_btn.pressed.connect(_on_cycle_drone_pressed)
	_drone_cycle_btn.gui_input.connect(_on_drone_btn_gui_input)
	row.add_child(_drone_cycle_btn)

	# 2. Crop Selector Pill
	_crop_btn = Button.new()
	_style_button(_crop_btn, 94, Color(0.18, 0.14, 0.10, 0.95), Color(0.92, 0.88, 0.80))
	_crop_btn.text = "🌾 Palay ▾"
	_crop_btn.tooltip_text = "Click to select crop for automated sowing"
	_crop_btn.pressed.connect(_on_crop_btn_pressed)
	row.add_child(_crop_btn)

	row.add_child(_make_divider())

	# 3. Action Buttons
	_drag_field_btn = Button.new()
	_style_button(_drag_field_btn, 58, Color(0.22, 0.18, 0.14, 0.90), Color(0.95, 0.90, 0.82))
	_drag_field_btn.text = "🎯 Field"
	_drag_field_btn.tooltip_text = "Click and drag a box on your farm to designate field for this drone"
	_drag_field_btn.pressed.connect(_on_drag_field_pressed)
	row.add_child(_drag_field_btn)

	_patrol_btn = Button.new()
	_style_button(_patrol_btn, 58, Color(0.22, 0.18, 0.14, 0.90), Color(0.95, 0.90, 0.82))
	_patrol_btn.text = "🌐 Auto"
	_patrol_btn.tooltip_text = "Deploy drone to automatically patrol and maintain all unlocked farmland"
	_patrol_btn.pressed.connect(_on_patrol_pressed)
	row.add_child(_patrol_btn)

	_recall_btn = Button.new()
	_style_button(_recall_btn, 52, Color(0.22, 0.18, 0.14, 0.90), Color(0.95, 0.90, 0.82))
	_recall_btn.text = "🏠 Dock"
	_recall_btn.tooltip_text = "Return drone to its landing berth"
	_recall_btn.pressed.connect(_on_recall_pressed)
	row.add_child(_recall_btn)

	row.add_child(_make_divider())

	# 4. Deck & Close Buttons
	_deck_btn = Button.new()
	_style_button(_deck_btn, 28, Color(0.25, 0.19, 0.12, 0.95), Color(1.0, 0.88, 0.45))
	_deck_btn.text = "⚙️"
	_deck_btn.tooltip_text = "Open Autonomous Drone Command Deck (U)"
	_deck_btn.pressed.connect(_on_open_deck_pressed)
	row.add_child(_deck_btn)

	_close_btn = Button.new()
	_style_button(_close_btn, 24, Color(0.20, 0.14, 0.12, 0.95), Color(0.85, 0.70, 0.70))
	_close_btn.text = "✕"
	_close_btn.tooltip_text = "Close quickbar (re-opens when drone selected or deck opens)"
	_close_btn.pressed.connect(func():
		_user_closed = true
		if _crop_popup_panel:
			_crop_popup_panel.visible = false
		visible = false
	)
	row.add_child(_close_btn)

func _make_divider() -> Control:
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(2, 22)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.draw.connect(func():
		sep.draw_line(Vector2(1, 2), Vector2(1, 20), Color(0.70, 0.55, 0.35, 0.45), 1.0)
	)
	return sep

func _style_button(btn: Button, min_w: float, bg_col: Color, text_col: Color) -> void:
	btn.custom_minimum_size = Vector2(min_w, 28)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", text_col)

	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = bg_col
	sb_norm.corner_radius_top_left = 14
	sb_norm.corner_radius_top_right = 14
	sb_norm.corner_radius_bottom_left = 14
	sb_norm.corner_radius_bottom_right = 14
	sb_norm.border_width_left = 1
	sb_norm.border_width_top = 1
	sb_norm.border_width_right = 1
	sb_norm.border_width_bottom = 1
	sb_norm.border_color = Color(0.85, 0.68, 0.32, 0.60)
	sb_norm.content_margin_left = 6
	sb_norm.content_margin_right = 6
	sb_norm.content_margin_top = 2
	sb_norm.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", sb_norm)

	var sb_hov := sb_norm.duplicate() as StyleBoxFlat
	sb_hov.bg_color = bg_col.lightened(0.18)
	sb_hov.border_color = Color(1.0, 0.88, 0.45, 0.95)
	btn.add_theme_stylebox_override("hover", sb_hov)

	var sb_press := sb_norm.duplicate() as StyleBoxFlat
	sb_press.bg_color = bg_col.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", sb_press)

	var sb_dis := sb_norm.duplicate() as StyleBoxFlat
	sb_dis.bg_color = Color(0.14, 0.11, 0.09, 0.70)
	sb_dis.border_color = Color(0.40, 0.35, 0.30, 0.40)
	btn.add_theme_stylebox_override("disabled", sb_dis)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.50, 0.45))

func _build_crop_popup() -> void:
	_crop_popup_panel = PanelContainer.new()
	_crop_popup_panel.top_level = true
	_crop_popup_panel.visible = false
	_crop_popup_panel.z_index = 180

	var sb_pop := StyleBoxFlat.new()
	sb_pop.bg_color = Color(0.09, 0.07, 0.05, 0.96)
	sb_pop.corner_radius_top_left = 16
	sb_pop.corner_radius_top_right = 16
	sb_pop.corner_radius_bottom_left = 16
	sb_pop.corner_radius_bottom_right = 16
	sb_pop.border_width_left = 1
	sb_pop.border_width_top = 1
	sb_pop.border_width_right = 1
	sb_pop.border_width_bottom = 1
	sb_pop.border_color = Color(0.90, 0.75, 0.35, 0.85)
	sb_pop.shadow_color = Color(0, 0, 0, 0.55)
	sb_pop.shadow_size = 6
	sb_pop.content_margin_left = 8
	sb_pop.content_margin_right = 8
	sb_pop.content_margin_top = 4
	sb_pop.content_margin_bottom = 4
	_crop_popup_panel.add_theme_stylebox_override("panel", sb_pop)

	add_child(_crop_popup_panel)

	var pop_row := HBoxContainer.new()
	pop_row.add_theme_constant_override("separation", 4)
	_crop_popup_panel.add_child(pop_row)

	for c in CROPS_LIST:
		var c_id: String = c.id
		var p_btn := Button.new()
		p_btn.name = "PopCrop_" + c_id
		p_btn.text = "%s %s" % [c.icon, c.short]
		_style_button(p_btn, 42, Color(0.18, 0.14, 0.10, 0.95), Color(0.95, 0.90, 0.80))
		p_btn.pressed.connect(func(): _on_crop_selected_from_popup(c_id))
		pop_row.add_child(p_btn)
		_crop_popup_buttons[c_id] = p_btn

func _get_selected_drone() -> FarmDrone:
	if farm_grid:
		if farm_grid.has_method("get_selected_drone"):
			return farm_grid.get_selected_drone()
		elif "drone" in farm_grid:
			return farm_grid.drone
	return null

func refresh_all() -> void:
	var d := _get_selected_drone()
	if d == null or not is_instance_valid(d):
		return

	var total_drones: int = farm_grid.drones.size() if (farm_grid and "drones" in farm_grid) else 1
	var lvl: int = d.get_level()
	var c_meta := Data.get_crop(d.crop_type)
	var crop_disp: String = str(c_meta.get("display_name", d.crop_type)).split(" ")[0]
	var crop_icon: String = str(c_meta.get("icon", "🌱"))

	# 1. Drone Cycler Pill Text & Tooltip
	_drone_cycle_btn.text = "🛸 #%d (Lv.%d)%s" % [
		d.drone_index,
		lvl,
		(" ▾" if total_drones > 1 else "")
	]

	var t: Dictionary = d.get_telemetry()
	var act: String = str(t.get("current_action", ""))
	var blocked: String = str(t.get("blocked_reason", ""))
	var status_summary: String = "Docked"
	if not blocked.is_empty() and d.state == FarmDrone.State.IDLE:
		status_summary = "⚠️ " + blocked
	elif d.state == FarmDrone.State.WORKING:
		status_summary = "🟢 " + (act if not act.is_empty() else "Working")
	elif d.state == FarmDrone.State.FLYING:
		status_summary = "🔵 En Route"
	elif d.has_zone():
		status_summary = "🟡 Patrolling Zone (%d plots)" % d.zone.size()

	_drone_cycle_btn.tooltip_text = (
		"🛸 %s (Avionics Lv.%d)\n"
		+ "• Status: %s\n"
		+ "• Crop: %s %s\n"
		+ "• Left-click: Cycle next drone (%d in fleet)\n"
		+ "• Right-click: Open Command Deck"
	) % [d.get_drone_name(), lvl, status_summary, crop_icon, crop_disp, total_drones]

	# 2. Crop Selector Pill Text & Capability Lock State
	if lvl == 1:
		_crop_btn.text = "🔒 Sowing (Lv.2)"
		_crop_btn.tooltip_text = "🔒 Sowing locked: Central Avionics is Lv.1 (Tills & Waters only).\nClick to open Agri-Shop and upgrade Drone Command Hangar to Lv.2!"
		if _crop_popup_panel:
			_crop_popup_panel.visible = false
	else:
		_crop_btn.text = "%s %s ▾" % [crop_icon, crop_disp]
		_crop_btn.tooltip_text = "Assigned crop: %s %s\nClick to change seed assignment" % [crop_icon, crop_disp]

	# 3. Update Crop Popup Buttons
	for c_id in _crop_popup_buttons:
		var btn: Button = _crop_popup_buttons[c_id]
		var is_unlocked: bool = BuildingManager.is_crop_unlocked(c_id)
		var is_cur: bool = (c_id == d.crop_type)
		btn.disabled = not is_unlocked

		var c_short: String = ""
		var c_ico: String = ""
		var c_cost: int = 25
		for item in CROPS_LIST:
			if item.id == c_id:
				c_short = item.short
				c_ico = item.icon
				c_cost = item.cost
				break

		if not is_unlocked:
			btn.text = "🔒 %s" % c_short
			btn.tooltip_text = "🔒 Locked: Acquire %s license in Agri-Shop" % c_id.capitalize()
		elif is_cur:
			btn.text = "✔ %s" % c_short
			btn.tooltip_text = "Currently selected for autonomous sowing"
			var sb := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			sb.bg_color = Color(0.40, 0.30, 0.15, 0.95)
			sb.border_color = Color(1.0, 0.88, 0.40, 0.95)
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
		else:
			btn.text = "%s %s" % [c_ico, c_short]
			btn.tooltip_text = "Assign %s (₱%d seed cost)" % [c_id.capitalize(), c_cost]
			var sb := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			sb.bg_color = Color(0.18, 0.14, 0.10, 0.95)
			sb.border_color = Color(0.85, 0.68, 0.32, 0.60)
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))

func _on_crop_btn_pressed() -> void:
	var d := _get_selected_drone()
	if d and d.get_level() < 2:
		_on_upgrade_shop_pressed()
		return

	if _crop_popup_panel:
		_crop_popup_panel.visible = not _crop_popup_panel.visible
		if _crop_popup_panel.visible:
			AudioManager.play_ui("click")
			_crop_popup_panel.reset_size()
			var btn_rect := _crop_btn.get_global_rect()
			var pop_x: float = maxf(btn_rect.position.x - 30.0, 390.0)
			_crop_popup_panel.global_position = Vector2(
				pop_x,
				btn_rect.position.y - 38.0
			)
			refresh_all()

func _on_crop_selected_from_popup(crop_id: String) -> void:
	if not BuildingManager.is_crop_unlocked(crop_id):
		AudioManager.play_ui("error")
		return
	var d := _get_selected_drone()
	if d:
		if d.get_level() < 2:
			AudioManager.play_ui("error")
			return
		d.set_crop(crop_id)
		AudioManager.play_ui("click")
		if _crop_popup_panel:
			_crop_popup_panel.visible = false
		refresh_all()
		var deck = get_tree().root.find_child("DroneCommandDeck", true, false)
		if deck and deck.has_method("refresh_all"):
			deck.refresh_all()

func _check_visibility() -> void:
	if not BuildingManager.has_drone_station():
		visible = false
		return
	if _user_closed:
		return
	visible = true
	refresh_all()

func show_for_drone() -> void:
	_user_closed = false
	visible = true
	refresh_all()

func _on_cycle_drone_pressed() -> void:
	if farm_grid == null or not ("drones" in farm_grid) or farm_grid.drones.is_empty():
		return
	var cur_idx: int = farm_grid.selected_drone_index
	var next_idx: int = (cur_idx % farm_grid.drones.size()) + 1
	farm_grid.select_drone_by_index(next_idx)
	if _crop_popup_panel:
		_crop_popup_panel.visible = false
	refresh_all()

func _on_drone_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_on_open_deck_pressed()

func _on_drag_field_pressed() -> void:
	if _crop_popup_panel:
		_crop_popup_panel.visible = false
	var d := _get_selected_drone()
	var c_type: String = d.crop_type if d else ""
	var d_idx: int = d.drone_index if d else 1
	if farm_grid and farm_grid.has_method("start_drone_zone_designation"):
		farm_grid.start_drone_zone_designation(c_type, d_idx)

func _on_patrol_pressed() -> void:
	if _crop_popup_panel:
		_crop_popup_panel.visible = false
	var d := _get_selected_drone()
	if d:
		d.deploy_whole_farm(d.crop_type)
		AudioManager.play_ui("click")
		refresh_all()

func _on_recall_pressed() -> void:
	if _crop_popup_panel:
		_crop_popup_panel.visible = false
	var d := _get_selected_drone()
	if d:
		d.recall()
		AudioManager.play_ui("click")
		refresh_all()

func _on_upgrade_shop_pressed() -> void:
	if _crop_popup_panel:
		_crop_popup_panel.visible = false
	AudioManager.play_ui("click")
	var hud = get_tree().root.find_child("HUDLayer", true, false)
	if hud and hud.has_method("_on_shop_toggle_pressed"):
		hud._on_shop_toggle_pressed()
	var shop = get_tree().root.find_child("ShopPanel", true, false)
	if shop and shop.has_method("open_to_tab"):
		shop.open_to_tab("machinery")
	elif shop and shop.has_method("_on_tab_pressed"):
		shop._on_tab_pressed("machinery")

func _on_open_deck_pressed() -> void:
	if _crop_popup_panel:
		_crop_popup_panel.visible = false
	var deck = get_tree().root.find_child("DroneCommandDeck", true, false)
	if deck and deck.has_method("open"):
		deck.open()
