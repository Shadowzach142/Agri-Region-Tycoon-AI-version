# BacklogPanel.gd
# Interactive Farm Chronicle / Activity Log modal window.
# Displays chronological history of farm events (planting, harvesting, sales, disasters, pests, hiring, construction)
# with category filtering, search, and real-time updates.

extends CanvasLayer

signal opened
signal closed

var _current_category: String = "all"
var _search_filter: String = ""

# UI References
var _dim_overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _count_label: Label
var _search_input: LineEdit
var _log_list_vbox: VBoxContainer
var _scroll_container: ScrollContainer
var _tab_buttons: Dictionary = {} # category -> Button

func _ready() -> void:
	add_to_group("backlog_panel")
	layer = 210
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_ui()

	# Listen for new logs in real-time
	if LogManager.has_signal("log_added"):
		LogManager.log_added.connect(_on_log_added)
	if LogManager.has_signal("logs_cleared"):
		LogManager.logs_cleared.connect(func(): refresh_logs())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			close()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	_search_filter = ""
	if _search_input:
		_search_input.text = ""
	refresh_logs()
	_animate_open()
	opened.emit()

func close() -> void:
	visible = false
	closed.emit()

func _animate_open() -> void:
	if not _panel:
		return
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.92, 0.92)
	_panel.modulate.a = 0.0
	if _dim_overlay:
		_dim_overlay.modulate.a = 0.0

	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.22)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	if _dim_overlay:
		tween.tween_property(_dim_overlay, "modulate:a", 1.0, 0.18)

func _build_ui() -> void:
	# 1. Dark semi-transparent backdrop
	_dim_overlay = ColorRect.new()
	_dim_overlay.color = Color(0.04, 0.06, 0.04, 0.65)
	_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	add_child(_dim_overlay)

	# 2. Main Centered Window
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left   = -410
	_panel.offset_top    = -280
	_panel.offset_right  = 410
	_panel.offset_bottom = 280
	_panel.custom_minimum_size = Vector2(820, 560)

	var panel_style = preload("res://assets/sprites/hud/BottomLeft/Clipboard.tres")
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# -- Header -------------------------------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "📜 Farm Activity Chronicle & Backlog"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_count_label = Label.new()
	_count_label.text = "0 events"
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.add_theme_color_override("font_color", Color(0.38, 0.26, 0.14, 1.0))
	header.add_child(_count_label)

	var clear_btn := Button.new()
	clear_btn.text = "🗑️ Clear"
	clear_btn.tooltip_text = "Clear backlog history"
	clear_btn.custom_minimum_size = Vector2(76, 28)
	clear_btn.add_theme_font_size_override("font_size", 12)
	clear_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	clear_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	clear_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	clear_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	clear_btn.pressed.connect(func(): LogManager.clear_logs())
	header.add_child(clear_btn)

	var close_btn := Button.new()
	close_btn.text = "✖ Close (Esc)"
	close_btn.custom_minimum_size = Vector2(105, 28)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	close_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	close_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	close_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	close_btn.pressed.connect(func(): close())
	header.add_child(close_btn)

	# -- Controls Row: Search & Tabs ----------------------------------------
	var filter_vbox := VBoxContainer.new()
	filter_vbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(filter_vbox)

	# Search box
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "🔍 Search events (e.g. palay, harvested, pest, sold, profit)..."
	_search_input.clear_button_enabled = true
	_search_input.custom_minimum_size = Vector2(0, 36)
	_search_input.add_theme_font_size_override("font_size", 13)
	_search_input.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	_search_input.add_theme_color_override("font_placeholder_color", Color(0.80, 0.75, 0.65, 0.75))
	_search_input.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/TopRight/BrownBox.tres"))
	_search_input.text_changed.connect(func(query: String):
		_search_filter = query
		refresh_logs()
	)
	filter_vbox.add_child(_search_input)

	# Category Tabs
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 6)
	filter_vbox.add_child(tabs_hbox)

	var categories := [
		{"id": "all",       "label": "All Events"},
		{"id": "crops",     "label": "🌾 Crops"},
		{"id": "finance",   "label": "💰 Finance"},
		{"id": "weather",   "label": "⚠️ Hazards & Pests"},
		{"id": "buildings", "label": "🏛️ Buildings & Tech"},
		{"id": "workers",   "label": "🧑‍🌾 Workers"}
	]

	for cat in categories:
		var btn := Button.new()
		btn.text = cat["label"]
		btn.custom_minimum_size = Vector2(90, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid: String = cat["id"]
		btn.pressed.connect(func():
			_current_category = cid
			_update_tab_styles()
			refresh_logs()
		)
		tabs_hbox.add_child(btn)
		_tab_buttons[cid] = btn

	_update_tab_styles()

	# -- Scrollable List of Logs --------------------------------------------
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_scroll_container)

	_log_list_vbox = VBoxContainer.new()
	_log_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_list_vbox.add_theme_constant_override("separation", 4)
	_scroll_container.add_child(_log_list_vbox)

func _update_tab_styles() -> void:
	for cid in _tab_buttons.keys():
		var btn: Button = _tab_buttons[cid]
		if cid == _current_category:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
			btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
			btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
		else:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
			btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
			btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))

func refresh_logs() -> void:
	if not _log_list_vbox:
		return

	for c in _log_list_vbox.get_children():
		c.queue_free()

	var entries: Array[Dictionary] = LogManager.get_logs(_current_category, _search_filter)

	if _count_label:
		_count_label.text = "%d events" % entries.size()

	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No recorded events matching this filter."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.38, 0.28, 0.18))
		empty_lbl.custom_minimum_size = Vector2(0, 80)
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_log_list_vbox.add_child(empty_lbl)
		return

	for entry in entries:
		var row := _create_log_row(entry)
		_log_list_vbox.add_child(row)

func _create_log_row(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/TopRight/BrownBox.tres"))

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 10)
	row_margin.add_theme_constant_override("margin_right", 10)
	row_margin.add_theme_constant_override("margin_top", 5)
	row_margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(row_margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row_margin.add_child(hbox)

	# Timestamp pill
	var time_lbl := Label.new()
	time_lbl.text = "[%s]" % entry.get("time_str", "Day 1")
	time_lbl.add_theme_font_size_override("font_size", 12)
	time_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	time_lbl.custom_minimum_size = Vector2(95, 0)
	hbox.add_child(time_lbl)

	# Icon
	var icon_lbl := Label.new()
	icon_lbl.text = entry.get("icon", "📜")
	icon_lbl.add_theme_font_size_override("font_size", 15)
	hbox.add_child(icon_lbl)

	# Message
	var msg_lbl := Label.new()
	msg_lbl.text = entry.get("message", "")
	msg_lbl.add_theme_font_size_override("font_size", 12)
	var col: Color = entry.get("color", Color.WHITE)
	# Ensure crisp, readable contrast on dark brown wood background
	var lum: float = 0.299 * col.r + 0.587 * col.g + 0.114 * col.b
	if lum < 0.65:
		col = col.lerp(Color(1.0, 0.96, 0.88), 0.50)
	msg_lbl.add_theme_color_override("font_color", col)
	msg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(msg_lbl)

	return card

func _on_log_added(entry: Dictionary) -> void:
	if not visible:
		return
	# If currently matching filter, insert card at top
	if _current_category == "all" or _current_category == entry.get("category", ""):
		if _search_filter == "" or _search_filter.to_lower() in entry.get("message", "").to_lower():
			var row := _create_log_row(entry)
			_log_list_vbox.add_child(row)
			_log_list_vbox.move_child(row, 0)
			if _count_label:
				_count_label.text = "%d events" % _log_list_vbox.get_child_count()
