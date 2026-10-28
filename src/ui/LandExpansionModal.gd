# LandExpansionModal.gd
# Modal dialog for purchasing and unlocking 10x10 land territory parcels.

class_name LandExpansionModal
extends CanvasLayer

signal parcel_unlocked(parcel_id: String)

var current_parcel_id: String = ""
var farm_grid: Node2D = null

var _backdrop: ColorRect = null
var _panel: PanelContainer = null
var _title_lbl: Label = null
var _subtitle_lbl: Label = null
var _desc_lbl: Label = null
var _stats_lbl: Label = null
var _cost_lbl: Label = null
var _funds_lbl: Label = null
var _unlock_btn: Button = null
var _close_btn: Button = null

func _ready() -> void:
	layer = 175
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	EconomyManager.cash_changed.connect(func(_amount): _refresh_funds())

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	if _panel != null:
		return
	# Full screen dimming backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0, 0, 0, 0.55)
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
	_panel.custom_minimum_size = Vector2(520, 360)
	_panel.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_lbl = Label.new()
	_title_lbl.text = "📜 TERRITORY LAND DEED"
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 18)
	_title_lbl.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
	header.add_child(_title_lbl)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.add_theme_font_size_override("font_size", 13)
	_close_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"))
	_close_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres"))
	_close_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres"))
	_close_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	_close_btn.pressed.connect(func(): close())
	header.add_child(_close_btn)

	var hsep1 := HSeparator.new()
	hsep1.modulate = Color(0.65, 0.55, 0.45, 0.40)
	vbox.add_child(hsep1)

	# Subtitle & Area
	_subtitle_lbl = Label.new()
	_subtitle_lbl.text = "Parcel Name"
	_subtitle_lbl.add_theme_font_size_override("font_size", 16)
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.18, 0.42, 0.16, 1.0))
	vbox.add_child(_subtitle_lbl)

	_stats_lbl = Label.new()
	_stats_lbl.text = "📐 Plot Size: 10×10 Grid (100 New Plots for Crops & Buildings)"
	_stats_lbl.add_theme_font_size_override("font_size", 13)
	_stats_lbl.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	vbox.add_child(_stats_lbl)

	# Description
	_desc_lbl = Label.new()
	_desc_lbl.text = "Description..."
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.add_theme_font_size_override("font_size", 12)
	_desc_lbl.add_theme_color_override("font_color", Color(0.35, 0.24, 0.14, 0.95))
	vbox.add_child(_desc_lbl)

	var hsep2 := HSeparator.new()
	hsep2.modulate = Color(0.65, 0.55, 0.45, 0.40)
	vbox.add_child(hsep2)

	# Financials Row
	var fin_row := HBoxContainer.new()
	fin_row.add_theme_constant_override("separation", 16)
	vbox.add_child(fin_row)

	_cost_lbl = Label.new()
	_cost_lbl.text = "Deed Price: ₱1,200"
	_cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cost_lbl.add_theme_font_size_override("font_size", 14)
	_cost_lbl.add_theme_color_override("font_color", Color(0.65, 0.25, 0.08, 1.0))
	fin_row.add_child(_cost_lbl)

	_funds_lbl = Label.new()
	_funds_lbl.text = "Funds: ₱1,000"
	_funds_lbl.add_theme_font_size_override("font_size", 14)
	_funds_lbl.add_theme_color_override("font_color", Color(0.08, 0.48, 0.14, 1.0))
	fin_row.add_child(_funds_lbl)

	# Action Button
	_unlock_btn = Button.new()
	_unlock_btn.custom_minimum_size = Vector2(0, 42)
	_unlock_btn.add_theme_font_size_override("font_size", 14)
	_unlock_btn.text = "🔓 Purchase & Unlock Land"
	_unlock_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_unlock_btn.pressed.connect(_on_unlock_pressed)
	vbox.add_child(_unlock_btn)

func open_for_parcel(parcel_id: String, grid_ref: Node2D) -> void:
	if _panel == null:
		_build_ui()
	current_parcel_id = parcel_id
	farm_grid = grid_ref
	var p: Dictionary = Data.get_parcel(parcel_id)
	if p.is_empty():
		return

	_subtitle_lbl.text = "📍 %s" % p.get("name", "Territory")
	_desc_lbl.text = p.get("description", "")
	var r_sz: Vector2i = p.get("rect", Rect2i()).size
	_stats_lbl.text = "📐 Plot Size: %d×%d Grid (%d New Plots for Crops & Buildings)" % [r_sz.x, r_sz.y, r_sz.x * r_sz.y]
	var cost: int = p.get("cost", 0)
	_cost_lbl.text = "Deed Price: 💰 ₱%s" % Utils.format_number(cost)
	_refresh_funds()
	visible = true

func close() -> void:
	visible = false

func _refresh_funds() -> void:
	if not visible:
		return
	var p: Dictionary = Data.get_parcel(current_parcel_id)
	var cost: int = p.get("cost", 0)
	var r_sz: Vector2i = p.get("rect", Rect2i()).size
	var has_funds: bool = EconomyManager.cash >= cost
	_funds_lbl.text = "Treasury: 💰 ₱%s" % Utils.format_number(EconomyManager.cash)

	if has_funds:
		_unlock_btn.disabled = false
		_unlock_btn.text = "🔓 Purchase & Unlock %d×%d Land (₱%s)" % [r_sz.x, r_sz.y, Utils.format_number(cost)]
		_unlock_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
		_unlock_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
		_unlock_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
		_unlock_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
		_unlock_btn.add_theme_color_override("font_hover_color", Color(0.10, 0.06, 0.02))
	else:
		_unlock_btn.disabled = true
		_unlock_btn.text = "❌ Insufficient Funds (Needs ₱%s)" % Utils.format_number(cost)
		_unlock_btn.remove_theme_stylebox_override("normal")
		_unlock_btn.remove_theme_stylebox_override("hover")
		_unlock_btn.remove_theme_stylebox_override("pressed")
		_unlock_btn.remove_theme_stylebox_override("disabled")
		_unlock_btn.remove_theme_color_override("font_disabled_color")
		_unlock_btn.remove_theme_color_override("font_color")

func _on_unlock_pressed() -> void:
	if farm_grid and farm_grid.has_method("unlock_parcel"):
		var success: bool = farm_grid.unlock_parcel(current_parcel_id)
		if success:
			parcel_unlocked.emit(current_parcel_id)
			close()
