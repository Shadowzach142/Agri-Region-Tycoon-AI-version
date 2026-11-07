# TutorialOverlay.gd
# Compact, uncluttered RPG Dialogue Tutorial for Agri-Region Tycoon.
# Features:
#   - Sleek, compact dialogue bar (450×96 px) at top-center so the farm & HUD stay completely visible
#   - Minimalist layout: Mang Kanor avatar + short 2-line message + simple ◀ / Next ▶ / ✕ buttons
#   - 100% accurate game controls:
#       * Bottom Hotbar: [1] Seeds, [2] Tools (Plow, Water, Harvest, Clear, Inspect), [3] Pest Spray
#       * Workers: Click Farmer, press [TAB], or use the < Farmer 1 > bar
#       * Time Speed: Top-bar [||] [1x] [2x] [3x] buttons, or [SPACE] Pause & [F1]/[F2]/[F3] speeds
#       * Right-side menus: Market [M], Bodega Sell [K], Agri-Shop [B]
#   - Golden spotlight & pointer arrow highlighting the exact button or plot being taught

class_name TutorialOverlay
extends CanvasLayer

signal tutorial_completed()
signal tutorial_closed()

const STYLE_MAIN_PANEL: StyleBox     = preload("res://assets/sprites/hud/Big-Rectangle-Box/BigPlainBox.tres")
const STYLE_GOLD_BTN: StyleBox       = preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres")
const STYLE_GOLD_HOVER: StyleBox     = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres")
const STYLE_GOLD_PRESS: StyleBox     = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres")
const STYLE_WOOD_BTN: StyleBox       = preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres")
const STYLE_WOOD_HOVER: StyleBox     = preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres")
const STYLE_WOOD_PRESS: StyleBox     = preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonPressed.tres")
const STYLE_BROWN_BTN: StyleBox      = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres")
const STYLE_BROWN_HOVER: StyleBox    = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres")
const STYLE_BROWN_PRESS: StyleBox    = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres")

const FARMER_IDLE_TEX: Texture2D     = preload("res://assets/sprites/farmer/idle.png")
const FarmerMovementScript           = preload("res://src/farmer/FarmerMovement.gd")

const DEMO_PLOT_MAIN: Vector2i       = Vector2i(6, 6)
const DEMO_PLOT_SECOND: Vector2i     = Vector2i(5, 6)

# Safe autoload accessors
func _au() -> Node: return get_node_or_null("/root/AudioManager")
func _da() -> Node: return get_node_or_null("/root/Data")
func _ec() -> Node: return get_node_or_null("/root/EconomyManager")
func _ti() -> Node: return get_node_or_null("/root/TimeManager")
func _tm() -> Node: return get_node_or_null("/root/TaskManager")
func _mm() -> Node: return get_node_or_null("/root/MarketManager")

# Concise, accurate 8-step tutorial curriculum
const LESSONS: Array[Dictionary] = [
	{
		"id": "welcome",
		"dialogue": "[b]Mabuhay![/b] Welcome to your farm! Pan the camera with [color=#b45309][b]W, A, S, D[/b][/color] and zoom with the [color=#b45309][b]Mouse Wheel[/b][/color]. Click any plot to inspect it.",
		"target_type": "world_tile",
		"target_tile": Vector2i(6, 6),
		"callout_text": "🌾 Your Homestead"
	},
	{
		"id": "select_worker",
		"dialogue": "[b]1. Select Your Farmer:[/b] Left-click your [color=#b45309][b]Farmer[/b][/color] in the field (or press [color=#b45309][b]TAB[/b][/color]) so they are ready to take orders.",
		"target_type": "farmer",
		"callout_text": "👷 Click Farmer or Press [TAB]"
	},
	{
		"id": "plow_soil",
		"dialogue": "[b]2. Plow the Soil:[/b] Press [color=#b45309][b][2] Tools[/b][/color] on the bottom hotbar and pick the [color=#b45309][b]⛏️ Pickaxe (Plow)[/b][/color], then click grass plots to till them!",
		"target_type": "hotbar_slot",
		"target_slot": "tools",
		"callout_text": "⛏️ [2] Tools ➔ Plow & Hoe"
	},
	{
		"id": "plant_crops",
		"dialogue": "[b]3. Plant Seeds:[/b] Press [color=#b45309][b][1] Seeds[/b][/color] on the bottom hotbar to choose a crop like [color=#15803d][b]Palay (Rice)[/b][/color], then click your plowed soil!",
		"target_type": "hotbar_slot",
		"target_slot": "seeds",
		"callout_text": "🌱 [1] Seeds ➔ Choose Crop"
	},
	{
		"id": "water_and_pests",
		"dialogue": "[b]4. Water & Protect:[/b] Use [color=#b45309][b][2] Tools ➔ 💧 Watering Can[/b][/color] to keep soil moisture optimal, and [color=#b45309][b][3] Pest Spray[/b][/color] if pests appear.",
		"target_type": "world_tile",
		"target_tile": Vector2i(6, 6),
		"callout_text": "💧 Keep Moisture Optimal for Grade A"
	},
	{
		"id": "time_and_harvest",
		"dialogue": "[b]5. Speed & Harvest:[/b] Change game speed with top-bar [color=#b45309][b]||  1x  2x  3x[/b][/color] ([b]SPACE[/b] / [b]F1–F3[/b]). When crops turn golden, press [color=#b45309][b]V[/b][/color] or use [b][2] Tools ➔ 🧺 Harvest[/b]!",
		"target_type": "speed_bar",
		"callout_text": "⏱️ Pause [SPACE] & Speeds [F1 / F2 / F3]"
	},
	{
		"id": "bodega_market",
		"dialogue": "[b]6. Sell Harvests:[/b] Click the [color=#b45309][b]🚛 Truck Button [K][/b][/color] on the right to sell stored crops from your Bodega, or [color=#b45309][b]📊 Market [M][/b][/color] to check prices.",
		"target_type": "hud_control",
		"target_node": "sell_btn",
		"callout_text": "🚛 Bodega Sales [K]"
	},
	{
		"id": "shop_and_weather",
		"dialogue": "[b]7. Expand & Watch Weather:[/b] Open [color=#b45309][b]🔨 Agri-Shop [B][/b][/color] to buy buildings, workers & drones, and click the [color=#b45309][b]Top-Left Weather Box[/b][/color] for PAGASA forecasts!",
		"target_type": "hud_control",
		"target_node": "shop_btn",
		"callout_text": "🔨 Agri-Shop [B]"
	}
]

var current_step: int = 0
var _pulse_time: float = 0.0
var _typewriter_progress: float = 0.0
var _typewriter_speed: float = 110.0
var _total_visible_chars: int = 0

# Scene references
var _farm_grid: Node2D = null
var _game_camera: Camera2D = null
var _hud: CanvasLayer = null

# UI Nodes
var _root_ctrl: Control = null
var _spotlight_canvas: Control = null
var _dialogue_card: PanelContainer = null
var _portrait_rect: TextureRect = null
var _step_lbl: Label = null
var _dialogue_rtl: RichTextLabel = null
var _prev_btn: Button = null
var _next_btn: Button = null
var _close_btn: Button = null

func _ready() -> void:
	layer = 190
	process_mode = Node.PROCESS_MODE_ALWAYS

	_discover_game_nodes()
	_build_ui()
	_prepare_tutorial_homestead()
	_show_step(0)

func _discover_game_nodes() -> void:
	var root := get_tree().root
	_farm_grid = root.find_child("FarmGrid", true, false) as Node2D
	_game_camera = root.find_child("GameCamera", true, false) as Camera2D
	_hud = root.find_child("HUDLayer", true, false) as CanvasLayer

func _prepare_tutorial_homestead() -> void:
	if _ec() and _ec().cash < 1000:
		_ec().cash = 1000
		_ec().cash_changed.emit(_ec().cash)

	if _ti():
		_ti().set_speed_scale(1.0)

	if _farm_grid and "tiles" in _farm_grid and _farm_grid.tiles.size() > 8:
		for x in range(4, 9):
			for y in range(4, 9):
				var t = _farm_grid.tiles[x][y]
				if t and t.state == FarmTile.TileState.OBSTACLE:
					t.reset()
					if _farm_grid.renderer:
						_farm_grid.renderer.update_tile(Vector2i(x, y), _farm_grid.tiles)

# ---------------------------------------------------------------------------
# Compact, Uncluttered UI Construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_root_ctrl = Control.new()
	_root_ctrl.name = "TutorialRootControl"
	_root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_ctrl)

	# 1. Spotlight & Pointer Canvas
	_spotlight_canvas = Control.new()
	_spotlight_canvas.name = "SpotlightCanvas"
	_spotlight_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spotlight_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spotlight_canvas.draw.connect(_on_draw_spotlight)
	_root_ctrl.add_child(_spotlight_canvas)

	# 2. Compact RPG Dialogue Box (460×92 px at top-center, below the top bar)
	_dialogue_card = PanelContainer.new()
	_dialogue_card.name = "TutorialDialogueCard"
	_dialogue_card.add_theme_stylebox_override("panel", STYLE_MAIN_PANEL)
	_dialogue_card.custom_minimum_size = Vector2(460, 92)
	_dialogue_card.size = Vector2(460, 92)
	_dialogue_card.position = Vector2((1280.0 - 460.0) * 0.5, 52.0)
	_dialogue_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_ctrl.add_child(_dialogue_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_dialogue_card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	# Left: Small Mentor Avatar + Step Counter
	var avatar_vbox := VBoxContainer.new()
	avatar_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	avatar_vbox.add_theme_constant_override("separation", 1)
	avatar_vbox.custom_minimum_size = Vector2(54, 0)
	hbox.add_child(avatar_vbox)

	_portrait_rect = TextureRect.new()
	_portrait_rect.texture = FARMER_IDLE_TEX
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.custom_minimum_size = Vector2(36, 36)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_vbox.add_child(_portrait_rect)

	var name_lbl := Label.new()
	name_lbl.text = "Kanor"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.28, 0.16, 0.06, 1.0))
	avatar_vbox.add_child(name_lbl)

	_step_lbl = Label.new()
	_step_lbl.text = "1 / 8"
	_step_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_lbl.add_theme_font_size_override("font_size", 10)
	_step_lbl.add_theme_color_override("font_color", Color(0.48, 0.32, 0.16, 0.95))
	avatar_vbox.add_child(_step_lbl)

	# Center: Clean 2-3 line dialogue text directly on the parchment card
	_dialogue_rtl = RichTextLabel.new()
	_dialogue_rtl.bbcode_enabled = true
	_dialogue_rtl.fit_content = true
	_dialogue_rtl.scroll_active = false
	_dialogue_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_rtl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dialogue_rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	_dialogue_rtl.add_theme_font_size_override("normal_font_size", 13)
	_dialogue_rtl.add_theme_font_size_override("bold_font_size", 13)
	_dialogue_rtl.add_theme_color_override("default_color", Color(0.18, 0.11, 0.05, 1.0))
	_dialogue_rtl.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _dialogue_rtl.visible_characters != -1 and _dialogue_rtl.visible_characters < _total_visible_chars:
				_dialogue_rtl.visible_characters = -1
	)
	hbox.add_child(_dialogue_rtl)

	# Right: Simple, clean navigation column (✕ Close on top, ◀ / Next ▶ on bottom)
	var btn_vbox := VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(btn_vbox)

	var top_right_row := HBoxContainer.new()
	top_right_row.alignment = BoxContainer.ALIGNMENT_END
	btn_vbox.add_child(top_right_row)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.tooltip_text = "Close Tutorial"
	_close_btn.custom_minimum_size = Vector2(24, 22)
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.add_theme_font_size_override("font_size", 11)
	_close_btn.add_theme_color_override("font_color", Color(0.96, 0.90, 0.84, 1.0))
	_close_btn.add_theme_stylebox_override("normal", STYLE_BROWN_BTN)
	_close_btn.add_theme_stylebox_override("hover", STYLE_BROWN_HOVER)
	_close_btn.add_theme_stylebox_override("pressed", STYLE_BROWN_PRESS)
	_close_btn.pressed.connect(_on_close_tutorial_pressed)
	top_right_row.add_child(_close_btn)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 4)
	btn_vbox.add_child(nav_row)

	_prev_btn = Button.new()
	_prev_btn.text = "◀"
	_prev_btn.tooltip_text = "Previous Step"
	_prev_btn.custom_minimum_size = Vector2(28, 28)
	_prev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_prev_btn.add_theme_font_size_override("font_size", 11)
	_prev_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	_prev_btn.add_theme_stylebox_override("normal", STYLE_WOOD_BTN)
	_prev_btn.add_theme_stylebox_override("hover", STYLE_WOOD_HOVER)
	_prev_btn.add_theme_stylebox_override("pressed", STYLE_WOOD_PRESS)
	_prev_btn.pressed.connect(_on_prev_pressed)
	nav_row.add_child(_prev_btn)

	_next_btn = Button.new()
	_next_btn.text = "Next ▶"
	_next_btn.custom_minimum_size = Vector2(68, 28)
	_next_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_next_btn.add_theme_font_size_override("font_size", 12)
	_next_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
	_next_btn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02, 1.0))
	_next_btn.add_theme_stylebox_override("normal", STYLE_GOLD_BTN)
	_next_btn.add_theme_stylebox_override("hover", STYLE_GOLD_HOVER)
	_next_btn.add_theme_stylebox_override("pressed", STYLE_GOLD_PRESS)
	_next_btn.pressed.connect(_on_next_pressed)
	nav_row.add_child(_next_btn)

# ---------------------------------------------------------------------------
# Step Progression & Live Demonstrations
# ---------------------------------------------------------------------------
func _show_step(idx: int) -> void:
	current_step = clampi(idx, 0, LESSONS.size() - 1)
	var data: Dictionary = LESSONS[current_step]

	_step_lbl.text = "%d / %d" % [current_step + 1, LESSONS.size()]
	_dialogue_rtl.text = str(data.get("dialogue", ""))

	_total_visible_chars = _dialogue_rtl.get_total_character_count()
	_typewriter_progress = 0.0
	_dialogue_rtl.visible_characters = 0

	_prev_btn.disabled = (current_step <= 0)
	_next_btn.text = "Done ✔" if current_step >= LESSONS.size() - 1 else "Next ▶"

	# Position card cleanly at top-center (or slightly lower if highlighting top speed bar)
	var vp_w: float = get_viewport().get_visible_rect().size.x if get_viewport() else 1280.0
	var target_y: float = 52.0
	if str(data.get("target_type", "")) == "speed_bar":
		target_y = 92.0
	_dialogue_card.position = Vector2((vp_w - _dialogue_card.size.x) * 0.5, target_y)

	_close_open_hud_panels()
	_focus_camera_for_step(current_step)
	_execute_step_demonstration(current_step)
	_spotlight_canvas.queue_redraw()

func _focus_camera_for_step(_step_idx: int) -> void:
	if not _game_camera or not _farm_grid:
		return
	var world_p: Vector2 = FarmerMovementScript.grid_to_pixel_center(DEMO_PLOT_MAIN, _farm_grid)
	if _game_camera.has_method("pan_to"):
		_game_camera.pan_to(world_p)

func _close_open_hud_panels() -> void:
	if not _hud:
		return
	if "market_panel" in _hud and _hud.market_panel and _hud.market_panel.visible:
		_hud.market_panel.visible = false
	if "sell_panel" in _hud and _hud.sell_panel and _hud.sell_panel.visible:
		_hud.sell_panel.visible = false
	if "shop_panel" in _hud and _hud.shop_panel and _hud.shop_panel.visible:
		_hud.shop_panel.visible = false
	if _farm_grid and "weather_app_modal" in _farm_grid and _farm_grid.weather_app_modal and _farm_grid.weather_app_modal.visible:
		_farm_grid.weather_app_modal.close()

func _execute_step_demonstration(step_idx: int, _manual_trigger: bool = false) -> void:
	if not _farm_grid:
		return
	if step_idx < 0 or step_idx >= LESSONS.size():
		return

	var lesson_id: String = str(LESSONS[step_idx].get("id", ""))
	match lesson_id:
		"welcome":
			_farm_grid.select_tile(DEMO_PLOT_MAIN)

		"select_worker":
			var farmers := get_tree().get_nodes_in_group("farmers")
			if not farmers.is_empty() and _tm():
				var f = farmers[0]
				if _tm().has_method("select_farmer"):
					_tm().select_farmer(f)
				elif "selected_farmers" in _tm():
					_tm().selected_farmers = [f]
					_tm().selection_changed.emit(_tm().selected_farmers)

		"plow_soil":
			_farm_grid.plow_tile(DEMO_PLOT_MAIN)
			_farm_grid.plow_tile(DEMO_PLOT_SECOND)
			_farm_grid.select_tile(DEMO_PLOT_MAIN)

		"plant_crops":
			_ensure_plot_planted(DEMO_PLOT_MAIN)
			_ensure_plot_planted(DEMO_PLOT_SECOND)
			_farm_grid.select_tile(DEMO_PLOT_MAIN)

		"water_and_pests":
			_ensure_plot_planted(DEMO_PLOT_MAIN)
			_farm_grid.water_tile(DEMO_PLOT_MAIN, 25.0)
			_farm_grid.select_tile(DEMO_PLOT_MAIN)

		"time_and_harvest":
			_ensure_plot_planted(DEMO_PLOT_MAIN)
			_ensure_plot_planted(DEMO_PLOT_SECOND)
			for pos in [DEMO_PLOT_MAIN, DEMO_PLOT_SECOND]:
				var t: FarmTile = _farm_grid.get_tile(pos)
				if t:
					t.growth_progress = 1.0
					t.health = 1.0
					t.quality = FarmTile.QualityGrade.A
					t.state = FarmTile.TileState.HARVESTABLE
					if _farm_grid.renderer:
						_farm_grid.renderer.update_tile(pos, _farm_grid.tiles)
			_farm_grid.select_tile(DEMO_PLOT_MAIN)

		"bodega_market":
			if _mm() and _mm().get_stored_units_for_crop("palay") <= 0:
				var t: FarmTile = _farm_grid.get_tile(DEMO_PLOT_MAIN)
				if t and t.state == FarmTile.TileState.HARVESTABLE:
					_farm_grid.harvest_tile(DEMO_PLOT_MAIN)
				else:
					_mm().add_harvest_to_storage("palay", 100, "Grade A", 100.0)

func _ensure_plot_planted(pos: Vector2i) -> void:
	if not _farm_grid:
		return
	var t: FarmTile = _farm_grid.get_tile(pos)
	if not t:
		return
	if t.crop_type == "":
		_farm_grid.plow_tile(pos)
		_farm_grid.plant_crop(pos, "palay")

func _process(delta: float) -> void:
	_pulse_time += delta
	_spotlight_canvas.queue_redraw()

	if _dialogue_rtl and _dialogue_rtl.visible_characters != -1:
		if _dialogue_rtl.visible_characters < _total_visible_chars:
			_typewriter_progress += delta * _typewriter_speed
			_dialogue_rtl.visible_characters = mini(int(_typewriter_progress), _total_visible_chars)
		else:
			_dialogue_rtl.visible_characters = -1

# ---------------------------------------------------------------------------
# Spotlight & Bouncing Golden Arrow Renderer
# ---------------------------------------------------------------------------
func _on_draw_spotlight() -> void:
	if current_step < 0 or current_step >= LESSONS.size():
		return
	var data: Dictionary = LESSONS[current_step]
	var target_rect: Rect2 = _resolve_target_screen_rect(data)
	if target_rect.size == Vector2.ZERO:
		return

	var pulse: float = 0.5 + 0.5 * sin(_pulse_time * 5.0)
	var pad: float = 5.0 + pulse * 3.0
	var hl_rect := target_rect.grow(pad)

	var outer_col := Color(1.0, 0.85, 0.20, 0.25 + pulse * 0.20)
	var inner_col := Color(1.0, 0.92, 0.35, 0.95)
	_spotlight_canvas.draw_rect(hl_rect.grow(2.0), outer_col, false, 4.0)
	_spotlight_canvas.draw_rect(hl_rect, inner_col, false, 2.0)

	var bounce: float = sin(_pulse_time * 6.5) * 6.0
	var callout_str: String = str(data.get("callout_text", ""))
	var center_x: float = clampf(hl_rect.get_center().x, 120.0, 1160.0)

	var point_from_above: bool = (hl_rect.position.y > 220.0)
	var arrow_tip: Vector2
	var arrow_base_y: float
	var pill_y: float

	if point_from_above:
		arrow_tip = Vector2(hl_rect.get_center().x, hl_rect.position.y - 5.0 + bounce)
		arrow_base_y = arrow_tip.y - 18.0
		pill_y = arrow_base_y - 28.0
	else:
		arrow_tip = Vector2(hl_rect.get_center().x, hl_rect.end.y + 5.0 - bounce)
		arrow_base_y = arrow_tip.y + 18.0
		pill_y = arrow_base_y + 5.0

	var tri := PackedVector2Array([
		arrow_tip,
		Vector2(arrow_tip.x - 10.0, arrow_base_y),
		Vector2(arrow_tip.x + 10.0, arrow_base_y)
	])
	_spotlight_canvas.draw_colored_polygon(tri, Color(1.0, 0.86, 0.22, 0.98))
	_spotlight_canvas.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.24, 0.14, 0.04, 1.0), 2.0)

	if callout_str != "":
		var font: Font = ThemeDB.fallback_font
		var pill_w: float = maxf(float(callout_str.length()) * 7.0 + 20.0, 140.0)
		var pill_rect := Rect2(center_x - pill_w * 0.5, pill_y, pill_w, 24.0)
		_spotlight_canvas.draw_rect(pill_rect, Color(0.16, 0.10, 0.05, 0.92), true)
		_spotlight_canvas.draw_rect(pill_rect, Color(1.0, 0.85, 0.25, 0.95), false, 1.5)
		if font:
			_spotlight_canvas.draw_string(
				font,
				Vector2(pill_rect.position.x + 8.0, pill_rect.position.y + 16.0),
				callout_str,
				HORIZONTAL_ALIGNMENT_CENTER,
				pill_w - 16.0,
				12,
				Color(1.0, 0.94, 0.65, 1.0)
			)

func _resolve_target_screen_rect(data: Dictionary) -> Rect2:
	var t_type: String = str(data.get("target_type", ""))

	if t_type == "hotbar_slot" and _hud and "plant_hotbar" in _hud and _hud.plant_hotbar:
		var slot_key: String = str(data.get("target_slot", "seeds"))
		var hb = _hud.plant_hotbar
		if "category_slots" in hb and hb.category_slots.has(slot_key):
			var btn = hb.category_slots[slot_key]
			if btn is Control and is_instance_valid(btn) and btn.visible:
				return (btn as Control).get_global_rect()
		if hb is Control and hb.visible:
			return (hb as Control).get_global_rect()

	elif t_type == "speed_bar" and _hud:
		var p_btn = _hud.get("pause_btn") as Control
		var s3_btn = _hud.get("speed3_btn") as Control
		if p_btn and s3_btn and is_instance_valid(p_btn) and is_instance_valid(s3_btn):
			return p_btn.get_global_rect().merge(s3_btn.get_global_rect())

	elif t_type == "hud_control" and _hud:
		var prop_name: String = str(data.get("target_node", ""))
		var node = _hud.get(prop_name)
		if node is Control and is_instance_valid(node) and node.visible:
			return (node as Control).get_global_rect()

	elif t_type == "farmer":
		var farmers := get_tree().get_nodes_in_group("farmers")
		if not farmers.is_empty() and is_instance_valid(farmers[0]) and get_viewport():
			var f_world: Vector2 = (farmers[0] as Node2D).global_position
			var f_screen: Vector2 = get_viewport().get_canvas_transform() * f_world
			return Rect2(f_screen - Vector2(32, 42), Vector2(64, 64))

	elif t_type == "world_tile" and _farm_grid and get_viewport():
		var gpos: Vector2i = data.get("target_tile", DEMO_PLOT_MAIN)
		var t_world: Vector2 = FarmerMovementScript.grid_to_pixel_center(gpos, _farm_grid)
		var t_screen: Vector2 = get_viewport().get_canvas_transform() * t_world
		return Rect2(t_screen - Vector2(48, 24), Vector2(96, 48))

	return Rect2()

# ---------------------------------------------------------------------------
# Button Handlers
# ---------------------------------------------------------------------------
func _on_prev_pressed() -> void:
	if _au(): _au().play_ui("click")
	if current_step > 0:
		_show_step(current_step - 1)

func _on_next_pressed() -> void:
	if _au(): _au().play_ui("click")
	if LESSONS[current_step].get("id", "") == "time_and_harvest" and _farm_grid:
		var t: FarmTile = _farm_grid.get_tile(DEMO_PLOT_MAIN)
		if t and t.state == FarmTile.TileState.HARVESTABLE:
			_farm_grid.harvest_tile(DEMO_PLOT_MAIN)

	if current_step < LESSONS.size() - 1:
		_show_step(current_step + 1)
	else:
		_finish_tutorial()

func _finish_tutorial() -> void:
	if _da():
		_da().is_tutorial_mode = false
	_close_open_hud_panels()
	if _farm_grid:
		_farm_grid.show_floating_text(DEMO_PLOT_MAIN, "🎓 Tutorial Complete! Happy Farming!", Color(0.45, 1.0, 0.55))
	tutorial_completed.emit()
	queue_free()

func _on_close_tutorial_pressed() -> void:
	if _au(): _au().play_ui("click")
	if _da():
		_da().is_tutorial_mode = false
	_close_open_hud_panels()
	tutorial_closed.emit()
	queue_free()
