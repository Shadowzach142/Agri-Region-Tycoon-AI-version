# LeaderboardPanel.gd
# Personal Records & High Scores modal window.
# You compete against yourself to achieve the highest points per run.
#
# Features:
# 1. Live comparison: Current run points vs. Personal All-Time Best
# 2. Top 10 Personal Runs table (saved locally to disk)
# 3. Simple scoring guide explaining how quantity, grade, and hub distance award points
# 4. Save Run button to record your current run

extends CanvasLayer

signal opened
signal closed

var _current_tab: String = "records" # "records" | "guide"

# UI References
var _dim_overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _current_score_lbl: Label
var _best_score_lbl: Label
var _status_comparison_lbl: Label
var _run_details_lbl: Label

var _content_container: Control
var _tab_buttons: Dictionary = {}

func _ready() -> void:
	add_to_group("leaderboard_panel")
	layer = 205
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_ui()

	if LeaderboardManager.has_signal("points_changed"):
		LeaderboardManager.points_changed.connect(func(_tp, _pa, _r): _refresh_ui())
	if LeaderboardManager.has_signal("run_recorded"):
		LeaderboardManager.run_recorded.connect(func(_e): _refresh_ui())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return

		if event.keycode == KEY_J or event.keycode == KEY_T:
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
	_refresh_ui()
	_animate_open()
	opened.emit()

func close() -> void:
	visible = false
	closed.emit()

func _animate_open() -> void:
	if not _panel:
		return
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.95, 0.95)
	_panel.modulate.a = 0.0
	if _dim_overlay:
		_dim_overlay.modulate.a = 0.0

	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.20)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.16)
	if _dim_overlay:
		tween.tween_property(_dim_overlay, "modulate:a", 1.0, 0.16)

func _build_ui() -> void:
	# 1. Dark Backdrop
	_dim_overlay = ColorRect.new()
	_dim_overlay.color = Color(0.03, 0.05, 0.03, 0.70)
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
	_panel.offset_left   = -400
	_panel.offset_top    = -270
	_panel.offset_right  = 400
	_panel.offset_bottom = 270
	_panel.custom_minimum_size = Vector2(800, 540)

	var panel_style = preload("res://assets/sprites/hud/Big-Rectangle-Box/BigPlainBox.tres")
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# -- Header Row ---------------------------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_vbox.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	_title_label = Label.new()
	_title_label.text = "🏆 Personal High Scores & Run Records"
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	title_box.add_child(_title_label)

	var sub_lbl := Label.new()
	sub_lbl.text = "Play against your best runs • Maximize points with high crop volume, Grade A quality, and seaport hubs"
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.42, 0.32, 0.20, 1.0))
	title_box.add_child(sub_lbl)

	var close_btn := Button.new()
	close_btn.text = "✖ Close (Esc)"
	close_btn.custom_minimum_size = Vector2(100, 28)
	close_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	close_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	close_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	close_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	close_btn.pressed.connect(func(): close())
	header.add_child(close_btn)

	# -- Current Run Live Performance Banner --------------------------------
	var live_banner := PanelContainer.new()
	live_banner.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/TopRight/BrownBox.tres"))
	root_vbox.add_child(live_banner)

	var live_vbox := VBoxContainer.new()
	live_vbox.add_theme_constant_override("separation", 6)
	live_banner.add_child(live_vbox)

	var live_top := HBoxContainer.new()
	live_top.add_theme_constant_override("separation", 16)
	live_vbox.add_child(live_top)

	# Metric 1: Current Run Score
	var c1 := VBoxContainer.new()
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c1_t := Label.new()
	c1_t.text = "CURRENT RUN SCORE"
	c1_t.add_theme_font_size_override("font_size", 10)
	c1_t.add_theme_color_override("font_color", Color(0.70, 0.80, 0.70))
	c1.add_child(c1_t)
	_current_score_lbl = Label.new()
	_current_score_lbl.text = "0 PTS"
	_current_score_lbl.add_theme_font_size_override("font_size", 18)
	_current_score_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
	c1.add_child(_current_score_lbl)
	live_top.add_child(c1)

	# Metric 2: Personal Best
	var c2 := VBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c2_t := Label.new()
	c2_t.text = "PERSONAL BEST (ALL-TIME)"
	c2_t.add_theme_font_size_override("font_size", 10)
	c2_t.add_theme_color_override("font_color", Color(0.70, 0.80, 0.70))
	c2.add_child(c2_t)
	_best_score_lbl = Label.new()
	_best_score_lbl.text = "0 PTS"
	_best_score_lbl.add_theme_font_size_override("font_size", 18)
	_best_score_lbl.add_theme_color_override("font_color", Color(0.50, 0.90, 1.0))
	c2.add_child(_best_score_lbl)
	live_top.add_child(c2)

	# Metric 3: Record Current Run Button
	var save_btn := Button.new()
	save_btn.text = "💾 Record Current Run"
	save_btn.tooltip_text = "Save this run's final score to your Top 10 Personal Records table"
	save_btn.custom_minimum_size = Vector2(170, 32)
	save_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	save_btn.pressed.connect(_on_save_run_pressed)
	live_top.add_child(save_btn)

	# Comparison Status Line
	_status_comparison_lbl = Label.new()
	_status_comparison_lbl.text = "Start selling crops to establish this run's score!"
	_status_comparison_lbl.add_theme_font_size_override("font_size", 11)
	_status_comparison_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75))
	live_vbox.add_child(_status_comparison_lbl)

	# Run Statistics Details
	_run_details_lbl = Label.new()
	_run_details_lbl.text = "Day 1 • 0 units shipped • 0 Grade A deliveries • Highest batch: 0 pts"
	_run_details_lbl.add_theme_font_size_override("font_size", 10)
	_run_details_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.65))
	live_vbox.add_child(_run_details_lbl)

	# -- Tabs Row -----------------------------------------------------------
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(tabs_hbox)

	var tabs_def = [
		{"id": "records", "label": "🏅 TOP 10 PERSONAL RUNS", "tip": "Your highest scoring runs recorded on this device"},
		{"id": "guide",   "label": "📜 HOW SCORING WORKS", "tip": "Learn how volume, grades, and destinations determine points"}
	]

	for t in tabs_def:
		var btn := Button.new()
		btn.text = t["label"]
		btn.tooltip_text = t["tip"]
		btn.custom_minimum_size = Vector2(180, 28)
		var tid: String = t["id"]
		btn.pressed.connect(func(): _switch_tab(tid))
		tabs_hbox.add_child(btn)
		_tab_buttons[tid] = btn

	# -- Content Container --------------------------------------------------
	_content_container = PanelContainer.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))
	root_vbox.add_child(_content_container)

	_update_tab_button_styles()
	_render_active_tab()

func _switch_tab(tab_id: String) -> void:
	if _current_tab == tab_id:
		return
	_current_tab = tab_id
	_update_tab_button_styles()
	_render_active_tab()

func _update_tab_button_styles() -> void:
	for tid in _tab_buttons.keys():
		var btn: Button = _tab_buttons[tid]
		var is_active = (tid == _current_tab)
		if is_active:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
			btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
			btn.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08))
		else:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
			btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
			btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))

func _refresh_ui() -> void:
	_refresh_live_banner()
	_render_active_tab()

func _refresh_live_banner() -> void:
	if not _current_score_lbl or not _best_score_lbl:
		return

	var cur: int = LeaderboardManager.current_points
	var best: int = LeaderboardManager.get_personal_best()

	_current_score_lbl.text = "%s PTS" % Utils.format_number(cur)
	_best_score_lbl.text = "%s PTS" % Utils.format_number(best)

	# Comparison logic
	if best == 0 and cur == 0:
		_status_comparison_lbl.text = "🌱 New run started. Harvest & sell crops to establish your first personal record!"
		_status_comparison_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	elif cur > best:
		var lead = cur - best
		_status_comparison_lbl.text = "🎉 NEW PERSONAL RECORD! Current run leads your best by +%s pts!" % Utils.format_number(lead)
		_status_comparison_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
	elif cur == best and cur > 0:
		_status_comparison_lbl.text = "⭐ TIED WITH PERSONAL BEST! Sell more produce to break your record!"
		_status_comparison_lbl.add_theme_color_override("font_color", Color(0.50, 0.95, 0.55))
	else:
		var needed = best - cur
		var est_rank = LeaderboardManager.get_current_run_estimated_rank()
		_status_comparison_lbl.text = "📊 Current run ranks #%d • Needs +%s pts to beat your personal best (#1)" % [est_rank, Utils.format_number(needed)]
		_status_comparison_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.80))

	# Run statistics details
	var day = TimeManager.current_day
	var sold = LeaderboardManager.run_units_sold
	var ga = LeaderboardManager.run_grade_a
	var hi = LeaderboardManager.highest_single_sale_pts
	var streak = LeaderboardManager.current_combo
	var streak_tag = " • 🔥 %.1fx Streak" % LeaderboardManager.get_combo_multiplier() if streak > 0 else ""
	_run_details_lbl.text = "Day %d • %s units shipped (%d Grade A) • Best batch: +%s pts%s" % [
		day,
		Utils.format_number(sold),
		ga,
		Utils.format_number(hi),
		streak_tag
	]

func _on_save_run_pressed() -> void:
	var entry = LeaderboardManager.save_current_run()
	_status_comparison_lbl.text = "✅ Run saved to Personal Records table! (%s pts)" % Utils.format_number(entry["score"])
	_status_comparison_lbl.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
	_refresh_ui()

func _render_active_tab() -> void:
	if not _content_container:
		return

	for c in _content_container.get_children():
		c.queue_free()

	match _current_tab:
		"records":
			_render_records_tab()
		"guide":
			_render_guide_tab()

# ===========================================================================
# TAB 1: TOP 10 PERSONAL RUNS
# ===========================================================================
func _render_records_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	_content_container.add_child(vbox)

	# Table Header on parchment background
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	vbox.add_child(th)

	var h_rank := Label.new()
	h_rank.text = "RANK"
	h_rank.custom_minimum_size = Vector2(45, 18)
	h_rank.add_theme_font_size_override("font_size", 11)
	h_rank.add_theme_color_override("font_color", Color(0.28, 0.18, 0.10, 1.0))
	th.add_child(h_rank)

	var h_title := Label.new()
	h_title.text = "RUN TITLE & REGION"
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.add_theme_font_size_override("font_size", 11)
	h_title.add_theme_color_override("font_color", Color(0.28, 0.18, 0.10, 1.0))
	th.add_child(h_title)

	var h_stat := Label.new()
	h_stat.text = "HARVEST STATS"
	h_stat.custom_minimum_size = Vector2(200, 18)
	h_stat.add_theme_font_size_override("font_size", 11)
	h_stat.add_theme_color_override("font_color", Color(0.28, 0.18, 0.10, 1.0))
	th.add_child(h_stat)

	var h_date := Label.new()
	h_date.text = "DATE"
	h_date.custom_minimum_size = Vector2(85, 18)
	h_date.add_theme_font_size_override("font_size", 11)
	h_date.add_theme_color_override("font_color", Color(0.28, 0.18, 0.10, 1.0))
	th.add_child(h_date)

	var h_pts := Label.new()
	h_pts.text = "FINAL SCORE"
	h_pts.custom_minimum_size = Vector2(110, 18)
	h_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_pts.add_theme_font_size_override("font_size", 11)
	h_pts.add_theme_color_override("font_color", Color(0.28, 0.18, 0.10, 1.0))
	th.add_child(h_pts)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.55, 0.42, 0.30, 0.5))
	vbox.add_child(sep)

	# Scroll list of runs
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(list_vbox)

	var runs: Array = LeaderboardManager.get_personal_leaderboard()

	if runs.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No saved runs yet. Complete harvests and click 'Record Current Run' above to save your best runs!"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.38, 0.28, 0.18, 1.0))
		list_vbox.add_child(empty_lbl)
		return

	var idx: int = 1
	for r in runs:
		var row := PanelContainer.new()
		var rs := StyleBoxFlat.new()

		if idx == 1:
			rs.bg_color = Color(0.22, 0.25, 0.12, 0.95)
			rs.border_color = Color(1.0, 0.85, 0.35, 1.0)
			rs.border_width_left = 2
		else:
			rs.bg_color = Color(0.14, 0.18, 0.14, 0.90)
			rs.border_color = Color(0.32, 0.40, 0.30, 0.6)
			rs.border_width_left = 1

		rs.border_width_top = 1
		rs.border_width_right = 1
		rs.border_width_bottom = 1
		rs.corner_radius_top_left = 4
		rs.corner_radius_top_right = 4
		rs.corner_radius_bottom_right = 4
		rs.corner_radius_bottom_left = 4
		rs.content_margin_left = 10
		rs.content_margin_top = 6
		rs.content_margin_right = 10
		rs.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", rs)
		list_vbox.add_child(row)

		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 10)
		row.add_child(rh)

		# Rank
		var rank_str = "🥇 #1" if idx == 1 else ("🥈 #2" if idx == 2 else ("🥉 #3" if idx == 3 else "  #%d" % idx))
		var r_lbl := Label.new()
		r_lbl.text = rank_str
		r_lbl.custom_minimum_size = Vector2(45, 20)
		r_lbl.add_theme_font_size_override("font_size", 13)
		if idx == 1:
			r_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		elif idx == 2:
			r_lbl.add_theme_color_override("font_color", Color(0.90, 0.94, 0.98))
		elif idx == 3:
			r_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.50))
		else:
			r_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.85))
		rh.add_child(r_lbl)

		# Run Title & Region
		var title_box := VBoxContainer.new()
		title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(title_box)

		var t_lbl := Label.new()
		t_lbl.text = String(r.get("title", "Farm Run"))
		t_lbl.add_theme_font_size_override("font_size", 13)
		t_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
		title_box.add_child(t_lbl)

		var reg_sub := Label.new()
		reg_sub.text = String(r.get("region_display", "Mindanao"))
		reg_sub.add_theme_font_size_override("font_size", 11)
		reg_sub.add_theme_color_override("font_color", Color(0.90, 0.85, 0.75))
		title_box.add_child(reg_sub)

		# Harvest Stats
		var s_lbl := Label.new()
		var d = int(r.get("days_survived", 1))
		var u = int(r.get("units_sold", 0))
		var ga = int(r.get("grade_a_units", 0))
		s_lbl.text = "Day %d • %s units (%d Gr.A)" % [d, Utils.format_number(u), ga]
		s_lbl.custom_minimum_size = Vector2(200, 20)
		s_lbl.add_theme_font_size_override("font_size", 11)
		s_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.88))
		rh.add_child(s_lbl)

		# Date
		var d_lbl := Label.new()
		d_lbl.text = String(r.get("date", "2026-09-28"))
		d_lbl.custom_minimum_size = Vector2(85, 20)
		d_lbl.add_theme_font_size_override("font_size", 11)
		d_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.80))
		rh.add_child(d_lbl)

		# Score
		var sc = int(r.get("score", 0))
		var pts_lbl := Label.new()
		pts_lbl.text = "%s pts" % Utils.format_number(sc)
		pts_lbl.custom_minimum_size = Vector2(110, 20)
		pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pts_lbl.add_theme_font_size_override("font_size", 14)
		if idx == 1:
			pts_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
		else:
			pts_lbl.add_theme_color_override("font_color", Color(0.90, 0.98, 0.90))
		rh.add_child(pts_lbl)

		idx += 1

# ===========================================================================
# TAB 2: SCORING RULES & MECHANICS GUIDE
# ===========================================================================
func _render_guide_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var intro := Label.new()
	intro.text = "Maximize your score in each run by mastering the four scoring pillars: Volume, Quality Grade, Delivery Distance, and Regional Synergy."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 11)
	intro.add_theme_color_override("font_color", Color(0.85, 0.90, 0.80))
	vbox.add_child(intro)

	# Grid of 4 Guide Cards
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	# Card 1: Crop Base Points & Volume
	grid.add_child(_make_guide_card(
		"📦 1. CROP BASE POINTS & VOLUME",
		"Every unit sold earns points scaled by crop difficulty:\n" +
		"• Palay (Rice, 30 days): 10 pts / unit\n" +
		"• Yellow Corn (45 days): 15 pts / unit\n" +
		"• Cavendish Banana (120 days): 30 pts / unit\n" +
		"• Arabica Coffee (60 days): 35 pts / unit\n" +
		"• Coconut Palm (365 days): 60 pts / unit\n" +
		"Selling in bulk (50+ units) generates huge score bursts!",
		Color(0.95, 0.85, 0.40)
	))

	# Card 2: Quality Grade Multiplier
	grid.add_child(_make_guide_card(
		"⭐ 2. HARVEST QUALITY & FRESHNESS",
		"Soil moisture and pest care directly multiply your score:\n" +
		"• Grade A (Golden Harvest): 2.5x Multiplier\n" +
		"• Grade B (Commercial Standard): 1.5x Multiplier\n" +
		"• Grade C (Low Yield / Damaged): 0.8x Multiplier\n" +
		"• Freshness: Spoiled produce earns zero points\n" +
		"• Pristine condition (>95% arrival freshness): +15% BONUS!",
		Color(0.45, 0.95, 0.55)
	))

	# Card 3: Selling Destination / Market Hub
	grid.add_child(_make_guide_card(
		"🚢 3. SELLING DESTINATION & LOGISTICS",
		"Farther markets carry fuel fees and decay risk, but multiply points:\n" +
		"• Local Biyahero (0 km): 1.0x (Instant farmgate cash)\n" +
		"• Tacurong Grain Mill (45 km): 1.35x (Provincial bulk trade)\n" +
		"• Koronadal City Hub (68 km): 1.75x (Regional wholesale market)\n" +
		"• Gensan Export Seaport (135 km): 2.50x (Massive export points!)",
		Color(0.40, 0.85, 1.00)
	))

	# Card 4: Strategy & Streaks
	grid.add_child(_make_guide_card(
		"🔥 4. REGIONAL SYNERGY & STREAKS",
		"Specialized agricultural tactics for high-scoring runs:\n" +
		"• Regional Specialty: +25% bonus points when selling your home region's signature harvest!\n" +
		"• Quality Streak: Delivering consecutive Grade A/B harvests builds up to a 1.5x Multiplier!\n" +
		"• Cold Storage: Eliminates road rot, guaranteeing pristine seaport delivery scores.",
		Color(1.00, 0.65, 0.35)
	))

func _make_guide_card(title: String, body: String, title_color: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.17, 0.12, 0.90)
	s.border_color = Color(0.28, 0.38, 0.25, 0.8)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_bottom_left = 6
	s.content_margin_left = 12
	s.content_margin_top = 10
	s.content_margin_right = 12
	s.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", s)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", title_color)
	vb.add_child(t)

	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", Color(0.80, 0.85, 0.80))
	vb.add_child(b)

	return pc
