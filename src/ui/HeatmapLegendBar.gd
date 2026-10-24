# HeatmapLegendBar.gd
# Minimalist, high-contrast HUD control bar for the Soil & Farm Diagnostic Heatmap.
# Provides 1-click mode switching, visual legend guide, and live hover telemetry chip.

class_name HeatmapLegendBar
extends PanelContainer

signal mode_selected(mode: int)
signal close_requested()

var heatmap_overlay: FarmHeatmapOverlay = null

# UI References
var _mode_buttons: Array[Button] = []
var _hover_info_label: Label = null
var _mode_title_label: Label = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	z_index = 180
	mouse_filter = Control.MOUSE_FILTER_PASS

	_setup_frame_style()
	_build_ui()

func _setup_frame_style() -> void:
	if ResourceLoader.exists("res://assets/sprites/hud/Big-Rectangle-Box/Samplebox1.tres"):
		add_theme_stylebox_override("panel", load("res://assets/sprites/hud/Big-Rectangle-Box/Samplebox1.tres"))
	elif ResourceLoader.exists("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"):
		add_theme_stylebox_override("panel", load("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"))
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.08, 0.05, 0.96)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.85, 0.68, 0.30, 0.95)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		add_theme_stylebox_override("panel", sb)

func _build_ui() -> void:
	# Main container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(root_vbox)

	# --- 1. TOP CONTROL ROW ---
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(top_hbox)

	var title_icon := Label.new()
	title_icon.text = "🗺️"
	title_icon.add_theme_font_size_override("font_size", 16)
	top_hbox.add_child(title_icon)

	_mode_title_label = Label.new()
	_mode_title_label.text = "DIAGNOSTIC HEATMAP"
	_mode_title_label.add_theme_font_size_override("font_size", 14)
	_mode_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	top_hbox.add_child(_mode_title_label)

	var vsep := VSeparator.new()
	top_hbox.add_child(vsep)

	# Mode buttons
	var modes := [
		{"id": 0, "name": "🌐 All / Tactical", "tooltip": "Unified overlay: moisture tint, harvest readiness, pest blights & sprinkler net"},
		{"id": 1, "name": "💧 Soil Moisture", "tooltip": "Soil moisture gradient: dry amber vs lush cyan"},
		{"id": 2, "name": "🌱 Crop Health & Ripe", "tooltip": "Crop vigor & ready harvestable plots"},
		{"id": 3, "name": "🚿 Sprinkler Net", "tooltip": "Sprinkler coverage arcs & dry gaps"}
	]

	for m in modes:
		var btn := Button.new()
		btn.name = "HeatmapModeBtn_%d" % m.id
		btn.text = m.name
		btn.tooltip_text = m.tooltip
		btn.custom_minimum_size = Vector2(130, 28)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 11)
		var mode_idx: int = m.id
		btn.pressed.connect(func(): _on_mode_button_pressed(mode_idx))
		top_hbox.add_child(btn)
		_mode_buttons.append(btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "✕ Close (F)"
	close_btn.custom_minimum_size = Vector2(86, 28)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_size_override("font_size", 11)
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"):
		close_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"))
	close_btn.pressed.connect(func(): close_requested.emit())
	top_hbox.add_child(close_btn)

	# --- 2. BOTTOM DIAGNOSTIC READOUT & LEGEND ROW ---
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(bottom_hbox)

	# Live Tile Diagnostics Telemetry
	_hover_info_label = Label.new()
	_hover_info_label.text = "💡 Hover over any farm plot for real-time agronomic telemetry • Press [F] to toggle"
	_hover_info_label.add_theme_font_size_override("font_size", 11)
	_hover_info_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.90))
	_hover_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(_hover_info_label)

	# Legend chips
	var legend_lbl := Label.new()
	legend_lbl.text = "🔴 Parched (<35%)   🟡 Low (35-50%)   🔵 Optimal (50-80%)   ⭐ Ripe   ⚠️ Blight   🚿 Sprinkler"
	legend_lbl.add_theme_font_size_override("font_size", 10)
	legend_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	bottom_hbox.add_child(legend_lbl)

	_update_active_mode_buttons(0)

func _process(_delta: float) -> void:
	if not visible or heatmap_overlay == null or not is_instance_valid(heatmap_overlay):
		return

	var farm_grid = heatmap_overlay.farm_grid
	if farm_grid and "hovered_grid_pos" in farm_grid:
		var gp: Vector2i = farm_grid.hovered_grid_pos
		if gp != Vector2i(-1, -1) and farm_grid._is_valid(gp) and farm_grid.is_tile_unlocked(gp):
			var info: Dictionary = heatmap_overlay.get_tile_diagnostic_info(gp)
			var sp_str: String = "Covered 🚿" if info.get("sprinkler", false) else "Dry gap (No sprinkler)"
			var crop_str: String = info.get("crop", "Empty")
			var m_val: float = float(info.get("moisture", 0.0))
			var h_val: float = float(info.get("health", 0.0))
			var status: String = info.get("status", "Normal")

			_hover_info_label.text = "📍 Tile (%d, %d): %s • 💧 Moisture: %.0f%% • ❤️ Health: %.0f%% • 🚿 %s • %s" % [
				gp.x, gp.y, crop_str, m_val, h_val, sp_str, status
			]
			_hover_info_label.add_theme_color_override("font_color", Color(0.40, 1.0, 0.65))
			return

	_hover_info_label.text = "💡 Hover over any farm plot for real-time agronomic telemetry • Mode: %s [F]" % heatmap_overlay.get_mode_name()
	_hover_info_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.90))

func _on_mode_button_pressed(mode: int) -> void:
	if heatmap_overlay:
		heatmap_overlay.set_mode(mode)
	_update_active_mode_buttons(mode)

func _update_active_mode_buttons(active_mode: int) -> void:
	for i in range(_mode_buttons.size()):
		var btn: Button = _mode_buttons[i]
		var is_cur: bool = (i == active_mode)
		if is_cur:
			if ResourceLoader.exists("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"):
				btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
				btn.add_theme_color_override("font_color", Color(0.2, 0.12, 0.06))
		else:
			if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
				btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"))
				btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
