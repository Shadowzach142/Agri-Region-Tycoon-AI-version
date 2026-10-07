# EarlyHarvestModal.gd
# Confirmation modal dialog explaining consequences and trade-offs of early/premature crop harvesting.

class_name EarlyHarvestModal
extends CanvasLayer

signal harvest_confirmed(target_tiles: Array)
signal harvest_cancelled()

var target_tiles: Array = []
var farm_grid: Node2D = null

var _backdrop: ColorRect = null
var _panel: PanelContainer = null
var _title_lbl: Label = null
var _crop_header_lbl: Label = null
var _growth_progress_bar: ProgressBar = null
var _growth_pct_lbl: Label = null
var _yield_lbl: Label = null
var _quality_lbl: Label = null
var _penalty_lbl: Label = null
var _perennial_lbl: Label = null
var _tactical_lbl: Label = null
var _storage_warn_lbl: Label = null

var _confirm_btn: Button = null
var _cancel_btn: Button = null
var _close_btn: Button = null

func _ready() -> void:
	layer = 180
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	# Full-screen dimming backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0, 0, 0, 0.60)
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
	_panel.custom_minimum_size = Vector2(540, 390)
	_panel.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# 1. Header (Title + Close Button)
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_lbl = Label.new()
	_title_lbl.text = "🧺 EARLY HARVEST CONFIRMATION"
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 18)
	_title_lbl.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	header.add_child(_title_lbl)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(30, 26)
	_close_btn.add_theme_font_size_override("font_size", 14)
	_close_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	_close_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	_close_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	_close_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	_close_btn.pressed.connect(func(): close())
	header.add_child(_close_btn)

	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("separator_color", Color(0.55, 0.42, 0.30, 0.5))
	vbox.add_child(sep1)

	# 2. Crop Overview
	_crop_header_lbl = Label.new()
	_crop_header_lbl.text = "🌱 Crop Name"
	_crop_header_lbl.add_theme_font_size_override("font_size", 16)
	_crop_header_lbl.add_theme_color_override("font_color", Color(0.12, 0.45, 0.16, 1.0))
	vbox.add_child(_crop_header_lbl)

	# Growth Progress Bar Row
	var prog_row := HBoxContainer.new()
	prog_row.add_theme_constant_override("separation", 10)
	vbox.add_child(prog_row)

	_growth_progress_bar = ProgressBar.new()
	_growth_progress_bar.custom_minimum_size = Vector2(0, 18)
	_growth_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_growth_progress_bar.max_value = 100.0
	_growth_progress_bar.show_percentage = false

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.20, 0.16, 0.12, 0.9)
	pb_bg.set_corner_radius_all(4)
	_growth_progress_bar.add_theme_stylebox_override("background", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.85, 0.65, 0.20, 0.95)
	pb_fill.set_corner_radius_all(4)
	_growth_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	prog_row.add_child(_growth_progress_bar)

	_growth_pct_lbl = Label.new()
	_growth_pct_lbl.text = "45% Grown"
	_growth_pct_lbl.add_theme_font_size_override("font_size", 13)
	_growth_pct_lbl.add_theme_color_override("font_color", Color(0.38, 0.25, 0.12, 1.0))
	prog_row.add_child(_growth_pct_lbl)

	# 3. Trade-offs Details Card
	var details_card := PanelContainer.new()
	details_card.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/TopRight/BrownBox.tres"))
	vbox.add_child(details_card)

	var d_margin := MarginContainer.new()
	d_margin.add_theme_constant_override("margin_left", 14)
	d_margin.add_theme_constant_override("margin_top", 10)
	d_margin.add_theme_constant_override("margin_right", 14)
	d_margin.add_theme_constant_override("margin_bottom", 10)
	details_card.add_child(d_margin)

	var d_vbox := VBoxContainer.new()
	d_vbox.add_theme_constant_override("separation", 6)
	d_margin.add_child(d_vbox)

	_yield_lbl = Label.new()
	_yield_lbl.text = "📦 Estimated Salvage Yield: ~45 / 100 units"
	_yield_lbl.add_theme_font_size_override("font_size", 13)
	_yield_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	d_vbox.add_child(_yield_lbl)

	_penalty_lbl = Label.new()
	_penalty_lbl.text = "⚠️ Premature Penalty: -55% yield reduction"
	_penalty_lbl.add_theme_font_size_override("font_size", 13)
	_penalty_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.50))
	d_vbox.add_child(_penalty_lbl)

	_quality_lbl = Label.new()
	_quality_lbl.text = "⭐ Quality Cap: Grade C (Unripe crops cannot achieve Grade A Organic premium)"
	_quality_lbl.add_theme_font_size_override("font_size", 13)
	_quality_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	d_vbox.add_child(_quality_lbl)

	_perennial_lbl = Label.new()
	_perennial_lbl.text = "🌿 Perennial Plant: Tree remains alive and will regrow automatically."
	_perennial_lbl.add_theme_font_size_override("font_size", 13)
	_perennial_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	d_vbox.add_child(_perennial_lbl)

	# 4. Tactical Advice & Storage Warning
	_tactical_lbl = Label.new()
	_tactical_lbl.text = "💡 Tactical Note: Early harvest salvages crop value before floods, droughts, or pests strike. If conditions are safe, waiting for 100% full maturity maximizes revenue."
	_tactical_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tactical_lbl.add_theme_font_size_override("font_size", 12)
	_tactical_lbl.add_theme_color_override("font_color", Color(0.38, 0.28, 0.18, 1.0))
	vbox.add_child(_tactical_lbl)

	_storage_warn_lbl = Label.new()
	_storage_warn_lbl.text = "⚠️ Warning: Farm Storage is nearly full!"
	_storage_warn_lbl.visible = false
	_storage_warn_lbl.add_theme_font_size_override("font_size", 12)
	_storage_warn_lbl.add_theme_color_override("font_color", Color(0.78, 0.18, 0.12, 1.0))
	vbox.add_child(_storage_warn_lbl)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("separator_color", Color(0.55, 0.42, 0.30, 0.5))
	vbox.add_child(sep2)

	# 5. Action Buttons (Confirm vs. Cancel)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_cancel_btn = Button.new()
	_cancel_btn.text = "❌ No, Wait for Ripe (Keep Growing)"
	_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_btn.custom_minimum_size = Vector2(0, 40)
	_cancel_btn.add_theme_font_size_override("font_size", 13)
	_cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_cancel_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	_cancel_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	_cancel_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	_cancel_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(_cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "🧺 Harvest Now (Salvage Yield)"
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.custom_minimum_size = Vector2(0, 40)
	_confirm_btn.add_theme_font_size_override("font_size", 13)
	_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_confirm_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
	_confirm_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
	_confirm_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
	_confirm_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(_confirm_btn)

func open_for_harvest(tiles_to_harvest: Array, grid_ref: Node2D) -> void:
	if _panel == null:
		_build_ui()

	target_tiles = tiles_to_harvest
	farm_grid = grid_ref
	if target_tiles.is_empty() or farm_grid == null:
		return

	# Gather crop stats from target tiles
	var is_batch: bool = target_tiles.size() > 1
	var first_pos: Vector2i = target_tiles[0]
	var t: FarmTile = farm_grid.tiles[first_pos.x][first_pos.y]
	var eff_root: Vector2i = t.multi_tile_root_pos if t.multi_tile_root_pos != Vector2i(-1, -1) else first_pos
	var root_t: FarmTile = farm_grid.tiles[eff_root.x][eff_root.y]

	var crop_name: String = root_t.crop_type
	if crop_name.is_empty():
		return
	var c_data: Dictionary = Data.get_crop(crop_name)
	var disp_name: String = c_data.get("display_name", crop_name.capitalize())
	var c_icon: String = c_data.get("icon", "🌱")
	var is_perennial: bool = c_data.get("is_perennial", false)
	var regrowth_days: int = int(c_data.get("regrowth_days", 0))

	print("[EarlyHarvestModal] Opened for crop: %s at %s (batch: %s, count: %d)" % [crop_name, eff_root, is_batch, target_tiles.size()])

	if not is_batch:
		var prog_pct: int = int(round(root_t.growth_progress * 100.0))
		_growth_progress_bar.value = float(prog_pct)
		_growth_pct_lbl.text = "%d%% Grown" % prog_pct

		var harvest_info := TileAgronomySystem.calculate_harvest(root_t)
		var est_yield: int = int(harvest_info.get("yield", 0))
		var max_yield: int = root_t.yield_quantity
		var penalty_pct: int = int(round((1.0 - float(est_yield) / maxf(float(max_yield), 1.0)) * 100.0))
		var grade_str: String = str(harvest_info.get("grade_string", "Grade C"))

		_crop_header_lbl.text = "%s %s (Plot %d, %d)" % [c_icon, disp_name, eff_root.x, eff_root.y]
		_yield_lbl.text = "📦 Estimated Salvage Yield: ~%d / %d units" % [est_yield, max_yield]
		_penalty_lbl.text = "⚠️ Premature Penalty: -%d%% yield reduction" % penalty_pct
		_quality_lbl.text = "⭐ Quality Grade: %s (Unripe crops cannot achieve Grade A Organic premium)" % grade_str

		if is_perennial:
			_perennial_lbl.visible = true
			_perennial_lbl.text = "🌿 Perennial Plant: Tree remains standing and will regrow in %d days." % regrowth_days
		else:
			_perennial_lbl.visible = false

		_confirm_btn.text = "🧺 Harvest %s Early (~%d Units)" % [disp_name, est_yield]
	else:
		# Batch selection
		var total_est_yield: int = 0
		var total_max_yield: int = 0
		var min_prog: float = 1.0

		for p in target_tiles:
			var sub_t: FarmTile = farm_grid.tiles[p.x][p.y]
			var sub_root: Vector2i = sub_t.multi_tile_root_pos if sub_t.multi_tile_root_pos != Vector2i(-1, -1) else p
			var s_root_t: FarmTile = farm_grid.tiles[sub_root.x][sub_root.y]
			var h_info := TileAgronomySystem.calculate_harvest(s_root_t)
			total_est_yield += int(h_info.get("yield", 0))
			total_max_yield += s_root_t.yield_quantity
			if s_root_t.growth_progress < min_prog:
				min_prog = s_root_t.growth_progress

		var avg_prog_pct: int = int(round(min_prog * 100.0))
		_growth_progress_bar.value = float(avg_prog_pct)
		_growth_pct_lbl.text = "Min ~%d%% Grown" % avg_prog_pct

		var penalty_pct: int = int(round((1.0 - float(total_est_yield) / maxf(float(total_max_yield), 1.0)) * 100.0))
		_crop_header_lbl.text = "🌱 Batch Harvest: %d Growing Plots Selected" % target_tiles.size()
		_yield_lbl.text = "📦 Estimated Total Salvage Yield: ~%d / %d units" % [total_est_yield, total_max_yield]
		_penalty_lbl.text = "⚠️ Premature Penalty: -%d%% average yield loss" % penalty_pct
		_quality_lbl.text = "⭐ Quality Grade: Reduced to Grade B/C based on current development"
		_perennial_lbl.visible = is_perennial
		if is_perennial:
			_perennial_lbl.text = "🌿 Perennials will remain standing and regrow automatically."
		_confirm_btn.text = "🧺 Harvest %d Plots Early (~%d Units)" % [target_tiles.size(), total_est_yield]

	# Storage check
	if BuildingManager.is_storage_full():
		_storage_warn_lbl.visible = true
		_storage_warn_lbl.text = "⚠️ Warning: Storage is FULL (%d/%d)! Harvested units cannot be stored." % [BuildingManager.used_storage, BuildingManager.total_storage_capacity]
		_confirm_btn.disabled = true
	else:
		_storage_warn_lbl.visible = false
		_confirm_btn.disabled = false

	visible = true
	AudioManager.play_ui("pause")

func close() -> void:
	if not visible:
		return
	visible = false
	harvest_cancelled.emit()
	AudioManager.play_ui("click")

func _on_confirm_pressed() -> void:
	visible = false
	AudioManager.play_farmer("harvest")
	harvest_confirmed.emit(target_tiles)

func _on_cancel_pressed() -> void:
	close()
