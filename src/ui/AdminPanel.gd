# AdminPanel.gd
# Developer cheat / gameplay-test panel.
# Toggled with the ` (backtick) key during gameplay after being unlocked on the main menu.
#
# Commands available:
#   Add Money    (+500 / +5000 / +50000)
#   Set Climate  (Normal / El Nino / La Nina)
#   Trigger Disaster (flash flood / drought / pest swarm)
#   Time Control (jump to next day / advance 7 days)
#   Flood a Tile / Row / All tiles
#   Fill all tiles with a crop at full growth
#   Kill all pests instantly
#   Reset money to starting value

extends CanvasLayer

signal admin_closed

# Whether the panel is enabled at all (set by MainMenu unlock checkbox)
var is_enabled: bool = false

# ---------------------------------------------------------------------------
# Node refs (built programmatically — no .tscn needed)
# ---------------------------------------------------------------------------
var _panel:          PanelContainer = null
var _toggle_hint:    Label          = null

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	layer = 200   # Always on top
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_enabled = true
	_build_ui()
	visible = false

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
func open() -> void:
	is_enabled = true
	visible = true

func close() -> void:
	visible = false
	admin_closed.emit()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

# ---------------------------------------------------------------------------
# Input — ` key toggles the panel, ESC closes it
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not is_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:  # ` backtick
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			close()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Build the entire UI in code (no scene file required)
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Semi-transparent dark backdrop
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)

	# Main panel
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left   = -320
	_panel.offset_top    = -320
	_panel.offset_right  =  320
	_panel.offset_bottom =  320
	if ResourceLoader.exists("res://assets/sprites/StartMenu/BigRectangleLogs.tres"):
		_panel.add_theme_stylebox_override("panel", load("res://assets/sprites/StartMenu/BigRectangleLogs.tres"))
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# ── Header ───────────────────────────────────────────────────────────────
	var header_hbox := HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header_hbox)

	var header_spacer := Control.new()
	header_spacer.custom_minimum_size = Vector2(28, 0)
	header_hbox.add_child(header_spacer)

	var header := _make_label("🛠️  ADMIN / DEBUG PANEL", 18, true)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header)

	var header_close_btn := Button.new()
	header_close_btn.text = "✕"
	header_close_btn.custom_minimum_size = Vector2(28, 28)
	header_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header_close_btn.tooltip_text = "Close (ESC or `)"
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"):
		header_close_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"))
		header_close_btn.add_theme_stylebox_override("hover", load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres"))
		header_close_btn.add_theme_stylebox_override("pressed", load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres"))
	header_close_btn.pressed.connect(close)
	header_hbox.add_child(header_close_btn)

	var hint := _make_label("Press  `  (backtick) to toggle    •    Changes are NOT reversed on close", 12, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.42, 0.30, 0.18, 0.95))
	vbox.add_child(hint)

	var sep0 := HSeparator.new()
	sep0.modulate = Color(0.65, 0.55, 0.45, 0.40)
	vbox.add_child(sep0)

	# ── ECONOMY ──────────────────────────────────────────────────────────────
	vbox.add_child(_make_label("💰 ECONOMY", 13, true))

	var cash_row := HBoxContainer.new()
	vbox.add_child(cash_row)
	cash_row.add_child(_make_btn("+ ₱500",     func(): EconomyManager.add_cash(500)))
	cash_row.add_child(_make_btn("+ ₱5,000",   func(): EconomyManager.add_cash(5000)))
	cash_row.add_child(_make_btn("+ ₱50,000",  func(): EconomyManager.add_cash(50000)))
	cash_row.add_child(_make_btn("+ ₱500,000", func(): EconomyManager.add_cash(500000)))
	cash_row.add_child(_make_btn("↩ Reset ₱1,000", func(): _reset_money()))

	# ── TIME ─────────────────────────────────────────────────────────────────
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_label("⏱ TIME", 13, true))

	var time_row := HBoxContainer.new()
	vbox.add_child(time_row)
	time_row.add_child(_make_btn("⏭ Next Day",    func(): _advance_days(1)))
	time_row.add_child(_make_btn("⏭⏭ +7 Days",   func(): _advance_days(7)))
	time_row.add_child(_make_btn("⏭⏭ +30 Days",  func(): _advance_days(30)))
	time_row.add_child(_make_btn("⏸ Pause",       func(): TimeManager.set_speed_scale(0.0)))
	time_row.add_child(_make_btn("▶ 1×",           func(): TimeManager.set_speed_scale(1.0)))
	time_row.add_child(_make_btn("▶▶ 3×",          func(): TimeManager.set_speed_scale(3.0)))

	# ── WEATHER / CLIMATE ────────────────────────────────────────────────────
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_label("🌦 WEATHER & CLIMATE", 13, true))

	var weather_row := HBoxContainer.new()
	vbox.add_child(weather_row)
	weather_row.add_child(_make_btn("☀ Normal",   func(): _set_climate(WeatherManager.Climate.NORMAL)))
	weather_row.add_child(_make_btn("🔥 El Niño", func(): _set_climate(WeatherManager.Climate.EL_NINO)))
	weather_row.add_child(_make_btn("🌊 La Niña", func(): _set_climate(WeatherManager.Climate.LA_NINA)))

	var disaster_row := HBoxContainer.new()
	vbox.add_child(disaster_row)
	disaster_row.add_child(_make_btn("🌊 Trigger Flash Flood",  func(): WeatherManager.trigger_disaster("flash_flood", 5.0)))
	disaster_row.add_child(_make_btn("☀ Trigger El Niño Drought", func(): WeatherManager.trigger_disaster("el_nino_drought", 5.0)))
	disaster_row.add_child(_make_btn("🌪 Trigger Landslide",    func(): WeatherManager.trigger_disaster("landslide", 5.0)))

	# ── FARM GRID ────────────────────────────────────────────────────────────
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_label("🌾 FARM GRID", 13, true))

	var grid_row1 := HBoxContainer.new()
	vbox.add_child(grid_row1)
	grid_row1.add_child(_make_btn("💧 Max Water All",        func(): _water_all_tiles(100.0)))
	grid_row1.add_child(_make_btn("🌊 Flood All Tiles",      func(): _flood_all_tiles()))
	grid_row1.add_child(_make_btn("🌱 Grow (Palay)",     func(): _fill_all_crops("palay")))
	grid_row1.add_child(_make_btn("🌽 Grow (Corn)",      func(): _fill_all_crops("yellow_corn")))
	grid_row1.add_child(_make_btn("🎋 Grow (Cane)",      func(): _fill_all_crops("sugarcane")))
	grid_row1.add_child(_make_btn("🍍 Grow (Pineapple)", func(): _fill_all_crops("pineapple")))

	var grid_row2 := HBoxContainer.new()
	vbox.add_child(grid_row2)
	grid_row2.add_child(_make_btn("🌾 Ripen All Crops",       func(): _ripen_all()))
	grid_row2.add_child(_make_btn("🐛 Infest All Crops",      func(): _infest_all()))
	grid_row2.add_child(_make_btn("✅ Clear All Pests",       func(): _clear_all_pests()))
	grid_row2.add_child(_make_btn("🗺️ Unlock All Land",     func(): _unlock_all_land()))
	grid_row2.add_child(_make_btn("🧹 Reset All Tiles",      func(): _reset_all_tiles()))

	# ── CLOSE ────────────────────────────────────────────────────────────────
	vbox.add_child(HSeparator.new())
	var close_btn := _make_btn("✖ Close Admin Panel", func(): visible = false)
	close_btn.modulate = Color(1.0, 0.55, 0.55)
	vbox.add_child(close_btn)

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------
func _reset_money() -> void:
	var diff: int = 1000 - EconomyManager.cash
	if diff > 0:
		EconomyManager.add_cash(diff)
	elif diff < 0:
		# Force-set by subtracting excess
		EconomyManager.cash = 1000
		EconomyManager.cash_changed.emit(EconomyManager.cash)

func _advance_days(count: int) -> void:
	for _i in range(count):
		TimeManager._increment_day()

func _set_climate(climate: int) -> void:
	WeatherManager.current_climate = climate
	match climate:
		WeatherManager.Climate.NORMAL:
			WeatherManager.temperature = 29.0
			WeatherManager.humidity    = 0.60
			WeatherManager.rainfall_mm = 6.0
		WeatherManager.Climate.EL_NINO:
			WeatherManager.temperature = 36.0
			WeatherManager.humidity    = 0.20
			WeatherManager.rainfall_mm = 0.0
		WeatherManager.Climate.LA_NINA:
			WeatherManager.temperature = 24.0
			WeatherManager.humidity    = 0.90
			WeatherManager.rainfall_mm = 80.0
	WeatherManager.weather_changed.emit(WeatherManager.temperature, WeatherManager.humidity)

func _get_farm_grid() -> Node2D:
	return get_tree().root.find_child("FarmGrid", true, false)

func _water_all_tiles(amount: float) -> void:
	var grid := _get_farm_grid()
	if grid == null:
		return
	for x in range(grid.GRID_SIZE.x):
		for y in range(grid.GRID_SIZE.y):
			grid.tiles[x][y].soil_moisture = amount
	grid.renderer.update_all(grid.tiles, grid.GRID_SIZE)

func _flood_all_tiles() -> void:
	var grid := _get_farm_grid()
	if grid == null:
		return
	for x in range(grid.GRID_SIZE.x):
		for y in range(grid.GRID_SIZE.y):
			var tile: FarmTile = grid.tiles[x][y]
			if tile.state != FarmTile.TileState.EMPTY and tile.state != FarmTile.TileState.PLOWED and tile.state != FarmTile.TileState.LOCKED:
				tile.state          = FarmTile.TileState.FLOODED
				tile.soil_moisture  = 100.0
				tile.yield_quantity = int(tile.yield_quantity * 0.3)
				tile.health         = 0.2
	grid.renderer.update_all(grid.tiles, grid.GRID_SIZE)

func _fill_all_crops(crop_name: String) -> void:
	var grid := _get_farm_grid()
	if grid == null:
		return
	var crop_data: Dictionary = Data.get_crop(crop_name)
	for x in range(grid.GRID_SIZE.x):
		for y in range(grid.GRID_SIZE.y):
			var tile: FarmTile = grid.tiles[x][y]
			if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.LOCKED:
				continue
			tile.crop_type       = crop_name
			tile.state           = FarmTile.TileState.GROWING
			tile.growth_progress = 0.45
			tile.health          = 1.0
			tile.quality         = FarmTile.QualityGrade.A
			tile.soil_moisture   = float(crop_data.get("water_min", 50)) + 10.0
			tile.soil_fertility  = 1.0
			tile.pest_type       = ""
			tile.yield_quantity  = 100
	grid.renderer.update_all(grid.tiles, grid.GRID_SIZE)

func _ripen_all() -> void:
	var grid := _get_farm_grid()
	if grid == null:
		return
	for x in range(grid.GRID_SIZE.x):
		for y in range(grid.GRID_SIZE.y):
			var tile: FarmTile = grid.tiles[x][y]
			if tile.crop_type != "":
				tile.growth_progress = 1.0
				tile.state           = FarmTile.TileState.HARVESTABLE
				tile.quality         = FarmTile.QualityGrade.A
				tile.health          = 1.0
	grid.renderer.update_all(grid.tiles, grid.GRID_SIZE)

func _infest_all() -> void:
	var grid := _get_farm_grid()
	if grid == null:
		return
	for x in range(grid.GRID_SIZE.x):
		for y in range(grid.GRID_SIZE.y):
			var tile: FarmTile = grid.tiles[x][y]
			if tile.crop_type != "" and tile.state != FarmTile.TileState.FLOODED and tile.state != FarmTile.TileState.OBSTACLE and tile.state != FarmTile.TileState.LOCKED:
				tile.pest_type = "rice_black_bug"
				tile.state     = FarmTile.TileState.INFECTED
				var key: String = "%d_%d" % [x, y]
				if not PestManager.infected_tiles.has(key):
					PestManager.infected_tiles[key] = {"pest": "rice_black_bug", "days": 0}
				PestManager.pest_spawned.emit("rice_black_bug", Vector2i(x, y))
	grid.renderer.update_all(grid.tiles, grid.GRID_SIZE)

func _clear_all_pests() -> void:
	var grid := _get_farm_grid()
	if grid == null:
		return
	PestManager.infected_tiles.clear()
	for x in range(grid.GRID_SIZE.x):
		for y in range(grid.GRID_SIZE.y):
			var tile: FarmTile = grid.tiles[x][y]
			if tile.pest_type != "":
				tile.pest_type = ""
				if tile.state == FarmTile.TileState.INFECTED:
					tile.state = FarmTile.TileState.GROWING if tile.growth_progress < 1.0 else FarmTile.TileState.HARVESTABLE
	grid.renderer.update_all(grid.tiles, grid.GRID_SIZE)

func _unlock_all_land() -> void:
	var grid := _get_farm_grid()
	if grid == null:
		return
	for p in Data.LAND_PARCELS:
		grid.unlock_parcel(p.get("id"))

func _reset_all_tiles() -> void:
	var grid := _get_farm_grid()
	if grid == null:
		return
	PestManager.infected_tiles.clear()
	for x in range(grid.GRID_SIZE.x):
		for y in range(grid.GRID_SIZE.y):
			grid.tiles[x][y].reset()
	grid._seed_natural_obstacles()
	grid.renderer.update_all(grid.tiles, grid.GRID_SIZE)

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------
func _make_label(text: String, font_size: int, bold: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	if bold:
		lbl.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
	else:
		lbl.add_theme_color_override("font_color", Color(0.35, 0.25, 0.15, 1.0))
	return lbl

func _make_btn(label: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text    = label
	btn.pressed.connect(cb)
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 12)
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"):
		btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
		btn.add_theme_stylebox_override("hover", load("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
		btn.add_theme_stylebox_override("pressed", load("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
		btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
	return btn
