# BayanihanModal.gd
# Modal dialog for inspecting and configuring autonomous Bayanihan Parcel Directives
# (Auto-cycle, Harvest-only, Water-only, or Manual).

class_name BayanihanModal
extends CanvasLayer

signal directive_applied(parcel_id: String, directive: Dictionary)

var current_parcel_id: String = "homestead"
var farm_grid: Node2D = null

var selected_mode: String = "auto_cycle"
var selected_crop: String = "palay"

var _backdrop: ColorRect = null
var _panel: PanelContainer = null
var _title_lbl: Label = null
var _subtitle_lbl: Label = null
var _tier_lbl: Label = null
var _mode_buttons: Dictionary = {}
var _crop_container: VBoxContainer = null
var _crop_buttons: Dictionary = {}
var _summary_lbl: Label = null
var _apply_btn: Button = null
var _close_btn: Button = null
var _parcel_tabs_hbox: HBoxContainer = null

const CROPS_LIST: Array[String] = [
	"palay", "yellow_corn", "sugarcane", "pineapple",
	"arabica_coffee", "banana", "coconut"
]

const CROP_ICONS: Dictionary = {
	"palay": "🌾",
	"yellow_corn": "🌽",
	"sugarcane": "🎋",
	"pineapple": "🍍",
	"arabica_coffee": "☕",
	"banana": "🍌",
	"coconut": "🥥"
}

func _ready() -> void:
	layer = 175
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	if BuildingManager.has_signal("crop_unlocked"):
		BuildingManager.crop_unlocked.connect(func(_c):
			if visible:
				_refresh_display()
		)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func open_for_parcel(parcel_id: String, farm_grid_ref: Node2D = null) -> void:
	current_parcel_id = parcel_id
	farm_grid = farm_grid_ref

	var current_dir: Dictionary = BuildingManager.get_bayanihan_directive(parcel_id)
	selected_mode = current_dir.get("mode", "auto_cycle")
	selected_crop = current_dir.get("crop", "palay")

	_refresh_display()
	visible = true
	AudioManager.play_ui("click")

func close() -> void:
	visible = false
	AudioManager.play_ui("click")

func _build_ui() -> void:
	# Full-screen dimming backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0, 0, 0, 0.58)
	_backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 430)
	_panel.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# 1. Header Row
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(title_vbox)

	_title_lbl = Label.new()
	_title_lbl.text = "🤝 BAYANIHAN PARCEL DIRECTIVE"
	_title_lbl.add_theme_font_size_override("font_size", 14)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title_vbox.add_child(_title_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.text = "Central Homestead (16×16 Plots)"
	_subtitle_lbl.add_theme_font_size_override("font_size", 10)
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	title_vbox.add_child(_subtitle_lbl)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	_close_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"))
	_close_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres"))
	_close_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres"))
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.pressed.connect(close)
	header_hbox.add_child(_close_btn)

	# 1.5 Parcel Selection Switcher Tabs
	_parcel_tabs_hbox = HBoxContainer.new()
	_parcel_tabs_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_parcel_tabs_hbox)

	# 2. Cooperative Status Banner
	var tier_panel := PanelContainer.new()
	var tier_box := StyleBoxFlat.new()
	tier_box.bg_color = Color(0.12, 0.20, 0.14, 0.85)
	tier_box.set_border_width_all(1)
	tier_box.border_color = Color(0.35, 0.65, 0.40, 0.7)
	tier_box.set_corner_radius_all(4)
	tier_panel.add_theme_stylebox_override("panel", tier_box)
	main_vbox.add_child(tier_panel)

	var tier_m := MarginContainer.new()
	tier_m.add_theme_constant_override("margin_left", 8)
	tier_m.add_theme_constant_override("margin_top", 4)
	tier_m.add_theme_constant_override("margin_right", 8)
	tier_m.add_theme_constant_override("margin_bottom", 4)
	tier_panel.add_child(tier_m)

	_tier_lbl = Label.new()
	_tier_lbl.text = "🤝 Bayanihan Post Lv.1 • +35% Teamwork Speed"
	_tier_lbl.add_theme_font_size_override("font_size", 10)
	_tier_lbl.add_theme_color_override("font_color", Color(0.70, 0.95, 0.75))
	tier_m.add_child(_tier_lbl)

	# 3. Directive Mode Selection (Radio / Grid)
	var mode_header := Label.new()
	mode_header.text = "Select Parcel Directive:"
	mode_header.add_theme_font_size_override("font_size", 11)
	mode_header.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	main_vbox.add_child(mode_header)

	var modes_grid := GridContainer.new()
	modes_grid.columns = 2
	modes_grid.add_theme_constant_override("h_separation", 8)
	modes_grid.add_theme_constant_override("v_separation", 6)
	main_vbox.add_child(modes_grid)

	var mode_defs: Array[Dictionary] = [
		{"id": "auto_cycle", "title": "🔄 Auto-Cycle", "sub": "Plow → Sow → Water → Harvest"},
		{"id": "harvest_only", "title": "🌾 Harvest Only", "sub": "Gather mature produce only"},
		{"id": "water_only", "title": "💧 Water Only", "sub": "Prioritize thirsty/dry plots"},
		{"id": "manual", "title": "✋ Manual Control", "sub": "Player orders only (no auto)"}
	]

	for md in mode_defs:
		var m_btn := Button.new()
		m_btn.text = "%s\n%s" % [md.title, md.sub]
		m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_btn.custom_minimum_size = Vector2(240, 40)
		m_btn.add_theme_font_size_override("font_size", 9)
		m_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var mid: String = md.id
		m_btn.pressed.connect(func(): _select_mode(mid))
		modes_grid.add_child(m_btn)
		_mode_buttons[mid] = m_btn

	# 4. Crop Selector (Visible during auto_cycle)
	_crop_container = VBoxContainer.new()
	_crop_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_crop_container)

	var crop_hdr := Label.new()
	crop_hdr.text = "Designated Communal Crop:"
	crop_hdr.add_theme_font_size_override("font_size", 10)
	crop_hdr.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_crop_container.add_child(crop_hdr)

	var crops_hbox := HBoxContainer.new()
	crops_hbox.add_theme_constant_override("separation", 6)
	_crop_container.add_child(crops_hbox)

	for c_id in CROPS_LIST:
		var c_data: Dictionary = Data.get_crop(c_id)
		var c_name: String = c_data.get("name", c_id.capitalize())
		var icon_str: String = CROP_ICONS.get(c_id, "🌱")
		var btn := Button.new()
		btn.text = "%s\n%s" % [icon_str, c_name.split(" ")[0]]
		btn.custom_minimum_size = Vector2(68, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 8)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): _select_crop(c_id))
		crops_hbox.add_child(btn)
		_crop_buttons[c_id] = btn

	# 5. Directive Description Summary
	_summary_lbl = Label.new()
	_summary_lbl.text = ""
	_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_lbl.add_theme_font_size_override("font_size", 9)
	_summary_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	main_vbox.add_child(_summary_lbl)

	# 6. Bottom Action Buttons
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(bottom_hbox)

	_apply_btn = Button.new()
	_apply_btn.text = "✔ APPLY DIRECTIVE"
	_apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_btn.custom_minimum_size = Vector2(0, 36)
	_apply_btn.add_theme_font_size_override("font_size", 12)
	_apply_btn.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	_apply_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
	_apply_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
	_apply_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
	_apply_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_btn.pressed.connect(_on_apply_pressed)
	bottom_hbox.add_child(_apply_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "CLOSE"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.add_theme_font_size_override("font_size", 12)
	cancel_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	cancel_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
	cancel_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres"))
	cancel_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonPressed.tres"))
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_btn.pressed.connect(close)
	bottom_hbox.add_child(cancel_btn)

func _select_mode(mode_id: String) -> void:
	selected_mode = mode_id
	_refresh_display()
	AudioManager.play_ui("click")

func _select_crop(crop_id: String) -> void:
	if not BuildingManager.is_crop_unlocked(crop_id):
		AudioManager.play_ui("error")
		return
	selected_crop = crop_id
	_refresh_display()
	AudioManager.play_ui("click")

func _switch_parcel(new_pid: String) -> void:
	current_parcel_id = new_pid
	var current_dir: Dictionary = BuildingManager.get_bayanihan_directive(new_pid)
	selected_mode = current_dir.get("mode", "auto_cycle")
	selected_crop = current_dir.get("crop", "palay")
	_refresh_display()
	AudioManager.play_ui("click")

func _refresh_display() -> void:
	var p_data: Dictionary = Data.get_parcel(current_parcel_id)
	var p_name: String = p_data.get("name", "Parcel")
	var r: Rect2i = p_data.get("rect", Rect2i())
	_subtitle_lbl.text = "%s (%d×%d Plots • %d Total Tiles)" % [p_name, r.size.x, r.size.y, r.size.x * r.size.y]

	# Update parcel tabs
	if _parcel_tabs_hbox:
		for child in _parcel_tabs_hbox.get_children():
			child.queue_free()

		var unlocked_list: Array = []
		if farm_grid and "unlocked_parcels" in farm_grid:
			unlocked_list = farm_grid.unlocked_parcels
		else:
			unlocked_list = ["homestead"]

		for pid in unlocked_list:
			var pd: Dictionary = Data.get_parcel(pid)
			var p_label: String = pd.get("name", pid.capitalize()).split(" ")[0]
			var tab_btn := Button.new()
			tab_btn.text = "📍 %s" % p_label
			tab_btn.custom_minimum_size = Vector2(80, 26)
			tab_btn.add_theme_font_size_override("font_size", 9)
			tab_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if pid == current_parcel_id:
				tab_btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
			else:
				tab_btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
			var p_copy: String = pid
			tab_btn.pressed.connect(func(): _switch_parcel(p_copy))
			_parcel_tabs_hbox.add_child(tab_btn)

	# Bayanihan Center status
	if BuildingManager.has_bayanihan_center():
		var tier_title: String = BuildingManager.get_cooperative_tier_name()
		var badge: String = BuildingManager.get_cooperative_badge()
		_tier_lbl.text = "✅ %s Active • Teamwork Bonus: %s" % [tier_title, badge]
		_tier_lbl.add_theme_color_override("font_color", Color(0.70, 0.95, 0.75))
	else:
		_tier_lbl.text = "⚠️ No Bayanihan Cooperative Post placed yet. Build one in the Agri-Shop to activate team automation!"
		_tier_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.40))

	# Update mode buttons style
	for m_id in _mode_buttons.keys():
		var btn: Button = _mode_buttons[m_id]
		if m_id == selected_mode:
			btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
		else:
			btn.remove_theme_color_override("font_color")

	# Update crop container visibility
	_crop_container.visible = (selected_mode == "auto_cycle")

	# Update crop buttons style
	for c_id in _crop_buttons.keys():
		var btn: Button = _crop_buttons[c_id]
		var is_unlocked: bool = BuildingManager.is_crop_unlocked(c_id)
		btn.disabled = not is_unlocked
		if not is_unlocked:
			btn.text = "🔒\nLocked"
			btn.tooltip_text = "Unlock %s variety license in Agri-Shop!" % c_id.capitalize()
			btn.add_theme_color_override("font_disabled_color", Color(0.60, 0.55, 0.50))
		else:
			var c_data: Dictionary = Data.get_crop(c_id)
			var c_name: String = c_data.get("name", c_id.capitalize())
			var icon_str: String = CROP_ICONS.get(c_id, "🌱")
			btn.text = "%s\n%s" % [icon_str, c_name.split(" ")[0]]
			btn.tooltip_text = "Set %s for communal auto-cycle." % c_id.capitalize()
			if c_id == selected_crop:
				btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
			else:
				btn.remove_theme_color_override("font_color")

	# Update summary text
	match selected_mode:
		"auto_cycle":
			var c_data: Dictionary = Data.get_crop(selected_crop)
			var c_name: String = c_data.get("name", selected_crop.capitalize())
			var c_cost: int = int(c_data.get("seed_cost", 25))
			var c_growth: int = int(c_data.get("growth_days", 15))
			_summary_lbl.text = "🔄 Autonomous Cycle: Unassigned farmworkers continuously harvest mature plots, water parched soil (under 50 percent moisture), plow empty ground, and sow %s (₱%d seed, %dd growth). Full hands-free team operation." % [
				c_name, c_cost, c_growth
			]
		"harvest_only":
			_summary_lbl.text = "🌾 Harvest Priority: Workers automatically reap mature crops across this parcel and haul produce to storage. Empty plots will remain fallow."
		"water_only":
			_summary_lbl.text = "💧 Hydration Priority: Workers automatically irrigate dry plots across this parcel whenever soil moisture falls below 50%."
		"manual":
			_summary_lbl.text = "✋ Manual Orders: Autonomous labor is disabled for this parcel. Workers only move when you explicitly issue orders."

func _on_apply_pressed() -> void:
	var dir := {
		"mode": selected_mode,
		"crop": selected_crop
	}
	BuildingManager.set_bayanihan_directive(current_parcel_id, dir)
	directive_applied.emit(current_parcel_id, dir)
	LogManager.log_event("action", "Updated Bayanihan Directive for %s: %s" % [current_parcel_id.capitalize(), selected_mode.to_upper()], "🤝", Color(0.95, 0.85, 0.35))
	AudioManager.play_ui("click")
	close()
