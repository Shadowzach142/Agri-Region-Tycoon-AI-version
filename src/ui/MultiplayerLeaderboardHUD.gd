# MultiplayerLeaderboardHUD.gd
# Live toggleable LAN Standings overlay for Multiplayer RTS mode.
# Players can click any rival row to spectate that player's farm & colored farmers live,
# or click the collapse toggle button if the box ever blocks their view.
# Disabled completely during Gameplay when Leaderboard Config is OFF ("Surprise Mode").

class_name MultiplayerLeaderboardHUD
extends CanvasLayer

const STYLE_BROWN_BOX: StyleBox = preload("res://assets/sprites/hud/TopRight/BrownBox.tres")
const STYLE_WOOD_BTN: StyleBox  = preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres")
const STYLE_WOOD_HOV: StyleBox  = preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres")

var _panel: PanelContainer = null
var _body_vbox: VBoxContainer = null
var _toggle_btn: Button = null
var _drag_grip: Label = null
var _rows_vbox: VBoxContainer = null
var _is_collapsed: bool = false
var _row_pool: Array[Dictionary] = []
var _last_standings_sig: String = ""
var _style_cache: Dictionary = {}

var _drag_pressed: bool = false
var _drag_active: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	name = "MultiplayerLeaderboardHUD"
	_build_ui()
	var mp := get_node_or_null("/root/MultiplayerManager")
	if mp:
		if not mp.snapshots_updated.is_connected(_refresh_rows):
			mp.snapshots_updated.connect(_refresh_rows)
		if not mp.spectate_changed.is_connected(func(_sid): _refresh_rows()):
			mp.spectate_changed.connect(func(_sid): _refresh_rows())
	var lbm := get_node_or_null("/root/LeaderboardManager")
	if lbm and lbm.has_signal("points_changed"):
		lbm.points_changed.connect(func(_tp, _pa, _r): _refresh_rows())
	var eco := get_node_or_null("/root/EconomyManager")
	if eco and eco.has_signal("cash_changed"):
		eco.cash_changed.connect(func(_c): _refresh_rows())
	_refresh_rows()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return
		if event.keycode == KEY_O:
			_toggle_collapse()
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "MultiplayerStandingsCard"
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	# Spawn cleanly below BACKLOG (L) so it never covers the logs button
	var vp_w: float = get_viewport().get_visible_rect().size.x if get_viewport() else 1280.0
	_panel.position = Vector2(maxf(4.0, vp_w - 302.0), 102.0)
	_panel.custom_minimum_size = Vector2(290.0, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _make_card_box(Color(0.11, 0.09, 0.07, 0.90), Color(0.70, 0.56, 0.30, 0.95), 2))
	_panel.gui_input.connect(_on_panel_drag_input.bind(false))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	root_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(root_vbox)

	# Header Row with Drag Handle + Collapse/Hide Toggle Button
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	hdr.mouse_filter = Control.MOUSE_FILTER_PASS
	root_vbox.add_child(hdr)

	_drag_grip = Label.new()
	_drag_grip.text = "⠿"
	_drag_grip.custom_minimum_size = Vector2(18, 26)
	_drag_grip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drag_grip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drag_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_drag_grip.tooltip_text = "Drag anywhere on the Standings header to move"
	_drag_grip.add_theme_font_size_override("font_size", 14)
	_drag_grip.add_theme_color_override("font_color", Color(0.86, 0.72, 0.40))
	_drag_grip.gui_input.connect(_on_panel_drag_input.bind(false))
	hdr.add_child(_drag_grip)

	_toggle_btn = Button.new()
	_toggle_btn.text = "🏆 Standings  ▾ [Hide]"
	_toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toggle_btn.custom_minimum_size = Vector2(0, 26)
	_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_toggle_btn.tooltip_text = "Drag to move Standings, or click (or press [O]) to hide/show"
	_toggle_btn.add_theme_stylebox_override("normal", STYLE_WOOD_BTN)
	_toggle_btn.add_theme_stylebox_override("hover", STYLE_WOOD_HOV)
	_toggle_btn.add_theme_stylebox_override("pressed", STYLE_WOOD_BTN)
	_toggle_btn.add_theme_font_size_override("font_size", 11)
	_toggle_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
	_toggle_btn.gui_input.connect(_on_panel_drag_input.bind(true))
	_toggle_btn.pressed.connect(_on_toggle_btn_pressed)
	hdr.add_child(_toggle_btn)

	_body_vbox = VBoxContainer.new()
	_body_vbox.add_theme_constant_override("separation", 4)
	_body_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	root_vbox.add_child(_body_vbox)

	var hint := Label.new()
	hint.text = "Drag frame to move • Click rival to spectate"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.76, 0.72, 0.64))
	_body_vbox.add_child(hint)

	_rows_vbox = VBoxContainer.new()
	_rows_vbox.add_theme_constant_override("separation", 4)
	_rows_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_body_vbox.add_child(_rows_vbox)

func _on_panel_drag_input(event: InputEvent, from_toggle_btn: bool) -> void:
	if not _panel:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_pressed = true
			_drag_active = false
			_drag_start_mouse = get_viewport().get_mouse_position()
			_drag_start_pos = _panel.position
		else:
			if _drag_active and from_toggle_btn:
				get_viewport().set_input_as_handled()
			_drag_pressed = false
			# Reset _drag_active deferred so pressed signal sees whether drag occurred
			call_deferred("_clear_drag_flag")
	elif event is InputEventMouseMotion and _drag_pressed:
		var cur_mouse := get_viewport().get_mouse_position()
		var delta_m := cur_mouse - _drag_start_mouse
		if not _drag_active and delta_m.length() >= 6.0:
			_drag_active = true
		if _drag_active:
			_panel.position = _drag_start_pos + delta_m
			_clamp_panel_to_viewport()
			get_viewport().set_input_as_handled()

func _clear_drag_flag() -> void:
	_drag_active = false

func _on_toggle_btn_pressed() -> void:
	if _drag_active:
		return
	_toggle_collapse()

func _clamp_panel_to_viewport() -> void:
	if not _panel:
		return
	var vp_rect := get_viewport().get_visible_rect()
	var max_x := maxf(4.0, vp_rect.size.x - _panel.size.x - 4.0)
	var max_y := maxf(4.0, vp_rect.size.y - _panel.size.y - 4.0)
	_panel.position = Vector2(
		clampf(_panel.position.x, 4.0, max_x),
		clampf(_panel.position.y, 4.0, max_y)
	)

func _toggle_collapse() -> void:
	_is_collapsed = not _is_collapsed
	if _body_vbox:
		_body_vbox.visible = not _is_collapsed
	if _toggle_btn:
		_toggle_btn.text = "🏆 Standings ▸" if _is_collapsed else "🏆 Standings  ▾ [Hide]"
	if _panel:
		_panel.custom_minimum_size.x = 175.0 if _is_collapsed else 290.0
		_panel.reset_size()
		call_deferred("_clamp_panel_to_viewport")
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ui"):
		am.play_ui("click")

func _get_cached_card_box(bg: Color, border: Color, bw: int = 1) -> StyleBoxFlat:
	var key := "%s|%s|%d" % [bg.to_html(true), border.to_html(true), bw]
	if not _style_cache.has(key):
		_style_cache[key] = _make_card_box(bg, border, bw)
	return _style_cache[key]

func _create_pooled_row() -> Dictionary:
	var row_btn := Button.new()
	row_btn.custom_minimum_size = Vector2(268, 34)
	row_btn.clip_text = true
	_rows_vbox.add_child(row_btn)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 7
	hbox.offset_right = -7
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)
	row_btn.add_child(hbox)

	var rk := Label.new()
	rk.custom_minimum_size = Vector2(20, 0)
	rk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rk.add_theme_font_size_override("font_size", 11)
	hbox.add_child(rk)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(dot)

	var name_vb := VBoxContainer.new()
	name_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	name_vb.add_theme_constant_override("separation", -2)
	hbox.add_child(name_vb)

	var nm := Label.new()
	nm.clip_text = true
	nm.add_theme_font_size_override("font_size", 11)
	name_vb.add_child(nm)

	var reg_lbl := Label.new()
	reg_lbl.clip_text = true
	reg_lbl.add_theme_font_size_override("font_size", 9)
	name_vb.add_child(reg_lbl)

	var stats_vb := VBoxContainer.new()
	stats_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_vb.add_theme_constant_override("separation", -2)
	hbox.add_child(stats_vb)

	var pts_lbl := Label.new()
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts_lbl.add_theme_font_size_override("font_size", 11)
	pts_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	stats_vb.add_child(pts_lbl)

	var cash_lbl := Label.new()
	cash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cash_lbl.add_theme_font_size_override("font_size", 9)
	cash_lbl.add_theme_color_override("font_color", Color(0.60, 0.92, 0.65))
	stats_vb.add_child(cash_lbl)

	var entry := {
		"btn": row_btn,
		"rk": rk,
		"dot": dot,
		"nm": nm,
		"reg_lbl": reg_lbl,
		"pts_lbl": pts_lbl,
		"cash_lbl": cash_lbl,
		"slot_id": "",
		"style_sig": ""
	}
	row_btn.pressed.connect(func():
		var mp_ref := get_node_or_null("/root/MultiplayerManager")
		var target_sid := str(entry["slot_id"])
		if mp_ref and not target_sid.is_empty():
			mp_ref.request_spectate(target_sid)
	)
	return entry

func _refresh_rows() -> void:
	if not _rows_vbox:
		return
	var mp := get_node_or_null("/root/MultiplayerManager")
	if not mp:
		return

	var list: Array = mp.get_sorted_standings()
	var my_sid: String = str(mp.my_slot_id)
	var cur_spec: String = str(mp.spectating_slot_id)

	var sig_parts: PackedStringArray = []
	for snap in list:
		var f_cnt := int(snap.get("farmer_count", (snap.get("farmers", []) as Array).size()))
		var d_cnt := int(snap.get("drone_count", 0))
		sig_parts.append("%s:%d:%d:%d:%d:%s" % [
			str(snap.get("slot_id", "")),
			int(snap.get("score", 0)),
			int(snap.get("cash", 0)),
			f_cnt,
			d_cnt,
			"1" if (str(snap.get("slot_id", "")) == cur_spec and str(snap.get("slot_id", "")) != my_sid) else "0"
		])
	var sig: String = "|".join(sig_parts)
	if sig == _last_standings_sig:
		return
	_last_standings_sig = sig

	while _row_pool.size() < list.size():
		_row_pool.append(_create_pooled_row())

	for idx in range(_row_pool.size()):
		var entry: Dictionary = _row_pool[idx]
		var row_btn: Button = entry["btn"]
		if idx >= list.size():
			row_btn.visible = false
			continue
		row_btn.visible = true
		var snap: Dictionary = list[idx]
		var sid := str(snap.get("slot_id", ""))
		entry["slot_id"] = sid
		var is_me := (sid == my_sid)
		var is_spec := (sid == cur_spec and not is_me)
		var c_idx := posmod(int(snap.get("color_idx", 0)), mp.FARMER_COLORS.size())
		var f_col: Color = mp.FARMER_COLORS[c_idx]

		var style_sig := "%d|%d|%d" % [1 if is_spec else 0, 1 if is_me else 0, c_idx]
		if str(entry["style_sig"]) != style_sig:
			entry["style_sig"] = style_sig
			var bg := Color(0.24, 0.20, 0.12, 0.96) if is_spec else (Color(0.18, 0.16, 0.11, 0.92) if is_me else Color(0.14, 0.13, 0.12, 0.88))
			var bdr := Color(1.0, 0.86, 0.35) if is_spec else (f_col if is_me else Color(0.40, 0.34, 0.24, 0.8))
			var norm := _get_cached_card_box(bg, bdr, 2 if (is_spec or is_me) else 1)
			var hov  := _get_cached_card_box(bg.lightened(0.08), Color(1.0, 0.86, 0.35), 2)
			row_btn.add_theme_stylebox_override("normal", norm)
			row_btn.add_theme_stylebox_override("hover", hov)
			row_btn.add_theme_stylebox_override("pressed", hov)
			row_btn.add_theme_stylebox_override("focus", norm)

		if is_me:
			row_btn.tooltip_text = "Your farm (%s)" % str(snap.get("region_short", ""))
		elif is_spec:
			row_btn.tooltip_text = "Currently viewing — click to return to your farm"
		else:
			row_btn.tooltip_text = "Click to spectate %s's farm in %s" % [str(snap.get("name", "")), str(snap.get("region_short", ""))]

		var rk: Label = entry["rk"]
		rk.text = "#%d" % (idx + 1)
		rk.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35) if idx == 0 else Color(0.75, 0.72, 0.66))

		var dot: ColorRect = entry["dot"]
		dot.color = f_col

		var nm: Label = entry["nm"]
		var p_name := str(snap.get("name", "Player"))
		nm.text = ("%s (You)" % p_name) if is_me else p_name
		nm.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42) if is_me else Color(0.95, 0.92, 0.86))

		var reg_lbl: Label = entry["reg_lbl"]
		var f_cnt := int(snap.get("farmer_count", (snap.get("farmers", []) as Array).size()))
		var d_cnt := int(snap.get("drone_count", 0))
		var d_str := " • 🛸%d" % d_cnt if d_cnt > 0 else ""
		reg_lbl.text = "%s • 👨‍🌾%d%s%s" % [str(snap.get("region_short", "")), f_cnt, d_str, " • 👁 VIEW" if is_spec else ""]
		reg_lbl.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0) if is_spec else Color(0.72, 0.70, 0.64))

		var pts_lbl: Label = entry["pts_lbl"]
		pts_lbl.text = "%d pts" % int(snap.get("score", 0))

		var cash_lbl: Label = entry["cash_lbl"]
		cash_lbl.text = "₱%d" % int(snap.get("cash", 0))

func _make_card_box(bg: Color, border: Color, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = bw
	s.border_width_top = bw
	s.border_width_right = bw
	s.border_width_bottom = bw
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s
