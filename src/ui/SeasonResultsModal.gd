# SeasonResultsModal.gd
# Displays campaign completion results when the season duration ends.
# Shows final score, tycoon prestige tier, personal best status, harvest statistics,
# and offers options to view hall of fame, start a new campaign, or continue in freeplay.

class_name SeasonResultsModal
extends CanvasLayer

signal freeplay_requested()
signal new_run_requested()
signal hall_of_fame_requested()

var _panel: PanelContainer
var _score_label: Label
var _tier_label: Label
var _record_badge: Label
var _stats_grid: GridContainer

func _init() -> void:
	layer = 220
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Semi-transparent backdrop overlay
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.06, 0.05, 0.85)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 530)
	_panel.add_theme_stylebox_override("panel", preload("res://assets/sprites/StartMenu/BigRectangleLogs.tres"))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# 1. Header Banner
	var title := Label.new()
	title.text = "🌾 SEASON FINALE: CAMPAIGN COMPLETE! 🌾"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	var reg_name: String = Data.REGIONS.get(Data.current_region, {}).get("display_name", "Region").split("(")[0].strip_edges()
	var mode_name: String = Data.SEASON_MODES.get(Data.selected_season_days, {}).get("title", "%d-Day Campaign" % Data.selected_season_days)
	subtitle.text = "%s  •  %s (%d Days)" % [reg_name, mode_name, Data.selected_season_days]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.35, 0.25, 0.15, 1.0))
	vbox.add_child(subtitle)

	var sep1 := HSeparator.new()
	sep1.modulate = Color(0.65, 0.55, 0.45, 0.40)
	vbox.add_child(sep1)

	# 2. Main Score Showcase
	var score_box := VBoxContainer.new()
	score_box.add_theme_constant_override("separation", 4)
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(score_box)

	var score_title := Label.new()
	score_title.text = "FINAL SCORE ACHIEVED"
	score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_title.add_theme_font_size_override("font_size", 12)
	score_title.add_theme_color_override("font_color", Color(0.38, 0.26, 0.16, 1.0))
	score_box.add_child(score_title)

	_score_label = Label.new()
	_score_label.text = "%s PTS" % Utils.format_number(LeaderboardManager.current_points)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 30)
	_score_label.add_theme_color_override("font_color", Color(0.68, 0.35, 0.08, 1.0))
	score_box.add_child(_score_label)

	var tier_info: Dictionary = LeaderboardManager.get_tycoon_tier(LeaderboardManager.current_points)
	_tier_label = Label.new()
	_tier_label.text = "%s %s" % [tier_info.get("badge", ""), tier_info.get("title", "Planter")]
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.add_theme_font_size_override("font_size", 15)
	_tier_label.add_theme_color_override("font_color", Color(0.18, 0.45, 0.18, 1.0))
	score_box.add_child(_tier_label)

	_record_badge = Label.new()
	var pb: int = LeaderboardManager.get_personal_best()
	if LeaderboardManager.current_points >= pb and LeaderboardManager.current_points > 0:
		_record_badge.text = "⭐ NEW ALL-TIME PERSONAL RECORD! ⭐"
		_record_badge.add_theme_color_override("font_color", Color(0.10, 0.52, 0.16, 1.0))
	else:
		_record_badge.text = "Personal Best: %s pts" % Utils.format_number(pb)
		_record_badge.add_theme_color_override("font_color", Color(0.32, 0.22, 0.12, 1.0))
	_record_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record_badge.add_theme_font_size_override("font_size", 12)
	score_box.add_child(_record_badge)

	var sep2 := HSeparator.new()
	sep2.modulate = Color(0.65, 0.55, 0.45, 0.40)
	vbox.add_child(sep2)

	# 3. Campaign Statistics Grid
	var stats_title := Label.new()
	stats_title.text = "CAMPAIGN HARVEST SUMMARY"
	stats_title.add_theme_font_size_override("font_size", 13)
	stats_title.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	vbox.add_child(stats_title)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 24)
	_stats_grid.add_theme_constant_override("v_separation", 6)
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_stats_grid)

	var grade_a_pct: float = 0.0
	if LeaderboardManager.run_units_sold > 0:
		grade_a_pct = (float(LeaderboardManager.run_grade_a) / float(LeaderboardManager.run_units_sold)) * 100.0

	_add_stat_row("Total Units Exported:", "%d crates" % LeaderboardManager.run_units_sold)
	_add_stat_row("Grade A Harvest Ratio:", "%.1f%%" % grade_a_pct)
	_add_stat_row("Successful Shipments:", "%d deliveries" % LeaderboardManager.run_deliveries)
	_add_stat_row("Max Export Streak:", "%d consecutive" % LeaderboardManager.max_combo)
	_add_stat_row("Top Single Delivery:", "%s pts" % Utils.format_number(LeaderboardManager.highest_single_sale_pts))
	_add_stat_row("Final Treasury Balance:", "₱%s" % Utils.format_number(EconomyManager.cash))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 4. Action Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var records_btn := Button.new()
	records_btn.text = "📜 View Records (J)"
	records_btn.custom_minimum_size = Vector2(160, 40)
	records_btn.add_theme_font_size_override("font_size", 13)
	records_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	records_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	records_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	records_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	records_btn.pressed.connect(_on_records_pressed)
	btn_row.add_child(records_btn)

	var new_run_btn := Button.new()
	new_run_btn.text = "🔄 New Campaign"
	new_run_btn.custom_minimum_size = Vector2(160, 40)
	new_run_btn.add_theme_font_size_override("font_size", 13)
	new_run_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	new_run_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	new_run_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	new_run_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	new_run_btn.pressed.connect(_on_new_run_pressed)
	btn_row.add_child(new_run_btn)

	var freeplay_btn := Button.new()
	freeplay_btn.text = "🌾 Continue Freeplay"
	freeplay_btn.custom_minimum_size = Vector2(180, 40)
	freeplay_btn.add_theme_font_size_override("font_size", 13)
	freeplay_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
	freeplay_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
	freeplay_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
	freeplay_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
	freeplay_btn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02))
	freeplay_btn.pressed.connect(_on_freeplay_pressed)
	btn_row.add_child(freeplay_btn)

func _add_stat_row(label_text: String, value_text: String) -> void:
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.35, 0.25, 0.15, 1.0))
	_stats_grid.add_child(l)

	var v := Label.new()
	v.text = value_text
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
	_stats_grid.add_child(v)

func _on_records_pressed() -> void:
	hall_of_fame_requested.emit()
	var lb = get_tree().get_first_node_in_group("leaderboard_panel")
	if lb and lb.has_method("open"):
		lb.open()

func _on_new_run_pressed() -> void:
	new_run_requested.emit()
	queue_free()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_freeplay_pressed() -> void:
	freeplay_requested.emit()
	TimeManager.enable_freeplay()
	queue_free()
