# ShopPanel.gd
# Clash of Clans-inspired visual card-grid Agri-Shop:
# Showcases prominent building, worker, drone, and land sprites on clean pedestals.
# Minimalistic, easy on the eyes, with intuitive card layouts:
# [Header: Title + Info (i)] -> [Center: Prominent Sprite Preview] -> [Meta Strip: Time / Size + Perks] -> [Bottom: Cost / Action Button]
# Fully reactive to funds, construction, capacity changes, and upgrades.

extends PanelContainer

signal item_purchased(item_name: String, cost: int)
signal worker_spawn_requested()

# Preloaded Textures for Visual Card Showcases
const TEX_KUBO: Texture2D            = preload("res://assets/sprites/buildings/KUBO.png")
const TEX_SILO: Texture2D            = preload("res://assets/sprites/buildings/Silo/SILO-100.PNG")
const TEX_DRYER: Texture2D           = preload("res://assets/sprites/buildings/DRYER.PNG")
const TEX_COLD_STORAGE: Texture2D    = preload("res://assets/sprites/buildings/Cold Storage.png")
const TEX_DRONE_STATION: Texture2D   = preload("res://assets/sprites/buildings/Drone Station.png")
const TEX_WEATHER_STATION: Texture2D = preload("res://assets/sprites/buildings/Weather Station.png")
const TEX_WATER_STATION: Texture2D   = preload("res://assets/sprites/buildings/Water Station.png")
const TEX_FARMER: Texture2D          = preload("res://assets/icons/Topright/Farmer icon.png")
const TEX_GRASS: Texture2D           = preload("res://assets/sprites/ground/NGRASS/NGRASS-01.png")
const TEX_HEATMAP: Texture2D         = preload("res://assets/icons/HUD/Heatmap.png")
const TEX_BYAHERO: Texture2D         = preload("res://assets/sprites/buildings/byahero.png")
const TEX_TACURONG: Texture2D        = preload("res://assets/sprites/buildings/Tacurong-Grain-mill.png")
const TEX_KORONADAL: Texture2D       = preload("res://assets/sprites/buildings/Koronadal-Wholesale.png")
const TEX_GENSAN: Texture2D          = preload("res://assets/sprites/buildings/Gensan-seaport.png")
const TEX_RICE_MILL: Texture2D       = preload("res://assets/sprites/buildings/Kiskisan_Rice_Mill.png")
const TEX_SUGAR_MILL: Texture2D      = preload("res://assets/sprites/buildings/Trapiche_Sugar_Central.png")
const TEX_COPRA_DRYER: Texture2D     = preload("res://assets/sprites/buildings/Tapahan_Copra_Dryer.png")
const TEX_COFFEE_ROASTERY: Texture2D = preload("res://assets/sprites/buildings/Artisan_Coffee_Roastery.png")

# Preloaded Arrow Textures for Category Navigation
const TEX_ARROW_L_NORM: Texture2D    = preload("res://assets/sprites/hud/Buttons/Arrows/arrow_left_normal.png")
const TEX_ARROW_L_HOV: Texture2D     = preload("res://assets/sprites/hud/Buttons/Arrows/arrow_left_hover.png")
const TEX_ARROW_L_PRESS: Texture2D   = preload("res://assets/sprites/hud/Buttons/Arrows/arrow_left_pressed.png")
const TEX_ARROW_R_NORM: Texture2D    = preload("res://assets/sprites/hud/Buttons/Arrows/arrow_right_normal.png")
const TEX_ARROW_R_HOV: Texture2D     = preload("res://assets/sprites/hud/Buttons/Arrows/arrow_right_hover.png")
const TEX_ARROW_R_PRESS: Texture2D   = preload("res://assets/sprites/hud/Buttons/Arrows/arrow_right_pressed.png")

const TEX_TAB_ARROW_L_NORM: Texture2D = preload("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_left_normal.png")
const TEX_TAB_ARROW_L_HOV: Texture2D  = preload("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_left_hover.png")
const TEX_TAB_ARROW_R_NORM: Texture2D = preload("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_right_normal.png")
const TEX_TAB_ARROW_R_HOV: Texture2D  = preload("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_right_hover.png")

# Preloaded Button Styles
const STYLE_GOLD_NORMAL  = preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres")
const STYLE_GOLD_HOVER   = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres")
const STYLE_GOLD_PRESSED = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres")

const STYLE_SQ_BROWN_NORMAL  = preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres")
const STYLE_SQ_BROWN_HOVER   = preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres")
const STYLE_SQ_BROWN_PRESSED = preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres")

@onready var close_btn: Button = $VBox/Header/CloseBtn
@onready var cash_label: Label = $VBox/Header/CashLabel
@onready var status_label: Label = $VBox/StatusLabel

# Category Navigation Controls
var category_nav_bar: HBoxContainer = null
var prev_cat_btn: TextureButton = null
var next_cat_btn: TextureButton = null
var cat_title_label: Label = null

# Containers for shop item grids across the 5 categories
var labor_grid: GridContainer = null
var storage_grid: GridContainer = null
var weather_grid: GridContainer = null
var machinery_grid: GridContainer = null
var processing_grid: GridContainer = null
var trade_grid: GridContainer = null
var land_grid: GridContainer = null

var _refresh_timer: float = 0.0

# Interactive Info Card for "!" / "i" clicks
@onready var item_info_card: PanelContainer = $VBox/ItemInfoCard
@onready var info_title_lbl: Label = $VBox/ItemInfoCard/HBox/TextVBox/InfoTitle
@onready var info_desc_lbl: Label = $VBox/ItemInfoCard/HBox/TextVBox/InfoDesc
@onready var info_close_btn: Button = $VBox/ItemInfoCard/HBox/InfoCloseBtn

# ---------------------------------------------------------------------------
# Sprite Preview Control (Embedded inside each card)
# ---------------------------------------------------------------------------
class ShopSpritePreview extends Control:
	var item_key: String = ""
	var tex: Texture2D = null
	var mod_color: Color = Color.WHITE
	var custom_draw: Callable = Callable()

	func _init(p_key: String, p_tex: Texture2D = null, p_mod: Color = Color.WHITE, p_draw: Callable = Callable()) -> void:
		item_key = p_key
		tex = p_tex
		mod_color = p_mod
		custom_draw = p_draw
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = Vector2(0, 94)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var center := Vector2(w * 0.5, h * 0.5 + 4.0)

		# 1. Soft isometric pedestal / circular spotlight (inspired by Clash of Clans)
		# Soft ground contact shadow
		draw_set_transform(center + Vector2(0, 14.0), 0.0, Vector2(1.0, 0.44))
		draw_circle(Vector2.ZERO, 40.0, Color(0.18, 0.12, 0.06, 0.15))
		draw_circle(Vector2.ZERO, 28.0, Color(0.18, 0.12, 0.06, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Subtle warm radial pedestal glow
		draw_circle(center + Vector2(0, -2.0), 36.0, Color(1.0, 0.95, 0.86, 0.38))
		draw_circle(center + Vector2(0, -2.0), 24.0, Color(1.0, 0.97, 0.90, 0.55))

		# 2. Draw Sprite / Artwork
		if custom_draw.is_valid():
			custom_draw.call(self, center)
		elif tex != null:
			var tsz: Vector2 = tex.get_size()
			var max_w: float = 88.0
			var max_h: float = 72.0
			var sc: float = minf(max_w / tsz.x, max_h / tsz.y)
			var dsz: Vector2 = (tsz * sc).floor()
			var dpos := Vector2(center.x - dsz.x * 0.5, center.y - dsz.y * 0.5 - 2.0)
			draw_texture_rect(tex, Rect2(dpos, dsz), false, mod_color)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	if info_close_btn:
		info_close_btn.pressed.connect(func(): item_info_card.visible = false)
	if is_instance_valid(item_info_card) and ResourceLoader.exists("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"):
		item_info_card.add_theme_stylebox_override("panel", load("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"))

	EconomyManager.cash_changed.connect(_on_cash_changed)
	_on_cash_changed(EconomyManager.cash)

	# Setup Labor tab container
	var tabs: TabContainer = find_child("TabContainer", true, false)
	if tabs:
		var labor_node: Control = tabs.get_node_or_null("Labor")
		if labor_node:
			tabs.set_tab_title(tabs.get_tab_idx_from_control(labor_node), "👷 Housing & Labor")
			labor_grid = labor_node.find_child("Grid", true, false) as GridContainer
			if labor_grid == null:
				# Fallback if structure is still VBox
				var vbox = labor_node.get_node_or_null("VBox")
				if vbox:
					labor_grid = GridContainer.new()
					labor_grid.name = "Grid"
					labor_grid.columns = 3
					labor_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					labor_grid.add_theme_constant_override("h_separation", 14)
					labor_grid.add_theme_constant_override("v_separation", 14)
					vbox.get_parent().add_child(labor_grid)
					vbox.queue_free()

	# Build remaining function-based tabs with GridContainers
	storage_grid = _make_tab("Storage", "📦 Storage & Bodega")
	weather_grid = _make_tab("Weather", "🌦️ Weather & Irrigation")
	machinery_grid = _make_tab("Machinery", "🚜 Machinery & Fleet")
	processing_grid = _make_tab("Processing", "🏭 Milling & Refining")
	trade_grid = _make_tab("Trade", "🚢 Trade Hubs & Ports")
	land_grid = _make_tab("Land", "🗺️ Land (10×10 Parcels)")

	_setup_category_navigation()

	# React immediately to construction completions, worker changes, and placements
	BuildingManager.worker_capacity_changed.connect(func(_cap, _act): _populate_labor())
	BuildingManager.worker_hired.connect(func(_act): _populate_labor())
	BuildingManager.drone_commissioned.connect(func(_d): _populate_labor())
	BuildingManager.building_placed.connect(func(_b): refresh())
	BuildingManager.storage_updated.connect(func(_c, _u): _populate_buildings())
	BuildingManager.weather_station_updated.connect(func(_l): _populate_buildings())
	BuildingManager.irrigation_updated.connect(func(_l): _populate_buildings())
	BuildingManager.sprinklers_updated.connect(func(_a, _c): _populate_buildings())
	BuildingManager.machinery_updated.connect(func(_l): _populate_buildings())
	if BuildingManager.has_signal("batch_processed"):
		BuildingManager.batch_processed.connect(func(_f, _i, _iq, _o): _populate_buildings())

	# Always refresh data when panel becomes visible
	visibility_changed.connect(func():
		if visible:
			refresh()
			_sync_category_nav()
	)

	_populate_shop()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.keycode == KEY_LEFT:
			_on_prev_category()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E or event.keycode == KEY_RIGHT:
			_on_next_category()
			get_viewport().set_input_as_handled()

func _setup_category_navigation() -> void:
	var tabs: TabContainer = find_child("TabContainer", true, false)
	if not tabs:
		return

	# 1. High-visibility theme icon overrides for TabContainer & internal TabBar
	tabs.add_theme_icon_override("decrement", TEX_TAB_ARROW_L_NORM)
	tabs.add_theme_icon_override("decrement_highlight", TEX_TAB_ARROW_L_HOV)
	tabs.add_theme_icon_override("increment", TEX_TAB_ARROW_R_NORM)
	tabs.add_theme_icon_override("increment_highlight", TEX_TAB_ARROW_R_HOV)

	var tab_bar: TabBar = tabs.get_tab_bar()
	if tab_bar:
		tab_bar.add_theme_icon_override("decrement", TEX_TAB_ARROW_L_NORM)
		tab_bar.add_theme_icon_override("decrement_highlight", TEX_TAB_ARROW_L_HOV)
		tab_bar.add_theme_icon_override("increment", TEX_TAB_ARROW_R_NORM)
		tab_bar.add_theme_icon_override("increment_highlight", TEX_TAB_ARROW_R_HOV)
		if not tab_bar.tab_changed.is_connected(_on_tab_changed):
			tab_bar.tab_changed.connect(_on_tab_changed)

	if not tabs.tab_changed.is_connected(_on_tab_changed):
		tabs.tab_changed.connect(_on_tab_changed)

	# 2. Prominent Category Navigation Bar
	if category_nav_bar and is_instance_valid(category_nav_bar):
		category_nav_bar.queue_free()

	category_nav_bar = HBoxContainer.new()
	category_nav_bar.name = "CategoryNavBar"
	category_nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	category_nav_bar.add_theme_constant_override("separation", 10)

	# Previous Category Button (◄)
	prev_cat_btn = TextureButton.new()
	prev_cat_btn.name = "PrevCategoryBtn"
	prev_cat_btn.custom_minimum_size = Vector2(36, 32)
	prev_cat_btn.texture_normal = TEX_ARROW_L_NORM
	prev_cat_btn.texture_hover = TEX_ARROW_L_HOV
	prev_cat_btn.texture_pressed = TEX_ARROW_L_PRESS
	prev_cat_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	prev_cat_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prev_cat_btn.tooltip_text = "Previous Category [Q or Left Arrow]"
	prev_cat_btn.pressed.connect(_on_prev_category)
	prev_cat_btn.mouse_entered.connect(func(): AudioManager.play_ui("hover"))
	category_nav_bar.add_child(prev_cat_btn)

	# Category Title Breadcrumb Pill
	var pill := PanelContainer.new()
	pill.name = "CategoryPill"
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.custom_minimum_size = Vector2(320, 32)

	if ResourceLoader.exists("res://assets/sprites/hud/Inner-container/InnerBarBg.tres"):
		pill.add_theme_stylebox_override("panel", load("res://assets/sprites/hud/Inner-container/InnerBarBg.tres"))
	else:
		var pill_style := StyleBoxFlat.new()
		pill_style.bg_color = Color(0.96, 0.93, 0.88, 0.95)
		pill_style.border_color = Color(0.42, 0.28, 0.16, 0.9)
		pill_style.border_width_left = 2; pill_style.border_width_top = 2
		pill_style.border_width_right = 2; pill_style.border_width_bottom = 2
		pill_style.corner_radius_top_left = 5; pill_style.corner_radius_top_right = 5
		pill_style.corner_radius_bottom_left = 5; pill_style.corner_radius_bottom_right = 5
		pill.add_theme_stylebox_override("panel", pill_style)
	category_nav_bar.add_child(pill)

	cat_title_label = Label.new()
	cat_title_label.name = "CategoryTitleLabel"
	cat_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_title_label.add_theme_font_size_override("font_size", 15)
	cat_title_label.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1.0))
	cat_title_label.add_theme_color_override("font_shadow_color", Color(0.96, 0.90, 0.80, 0.8))
	cat_title_label.add_theme_constant_override("shadow_offset_x", 1)
	cat_title_label.add_theme_constant_override("shadow_offset_y", 1)
	pill.add_child(cat_title_label)

	# Next Category Button (►)
	next_cat_btn = TextureButton.new()
	next_cat_btn.name = "NextCategoryBtn"
	next_cat_btn.custom_minimum_size = Vector2(36, 32)
	next_cat_btn.texture_normal = TEX_ARROW_R_NORM
	next_cat_btn.texture_hover = TEX_ARROW_R_HOV
	next_cat_btn.texture_pressed = TEX_ARROW_R_PRESS
	next_cat_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	next_cat_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	next_cat_btn.tooltip_text = "Next Category [E or Right Arrow]"
	next_cat_btn.pressed.connect(_on_next_category)
	next_cat_btn.mouse_entered.connect(func(): AudioManager.play_ui("hover"))
	category_nav_bar.add_child(next_cat_btn)

	# Insert above TabContainer
	var vbox: VBoxContainer = tabs.get_parent() as VBoxContainer
	if vbox:
		vbox.add_child(category_nav_bar)
		vbox.move_child(category_nav_bar, tabs.get_index())

	_sync_category_nav()

func _on_prev_category() -> void:
	var tabs: TabContainer = find_child("TabContainer", true, false)
	if not tabs or tabs.get_tab_count() == 0:
		return
	var count: int = tabs.get_tab_count()
	var cur: int = tabs.current_tab
	tabs.current_tab = (cur - 1 + count) % count
	AudioManager.play_ui("click")
	_sync_category_nav()

func _on_next_category() -> void:
	var tabs: TabContainer = find_child("TabContainer", true, false)
	if not tabs or tabs.get_tab_count() == 0:
		return
	var count: int = tabs.get_tab_count()
	var cur: int = tabs.current_tab
	tabs.current_tab = (cur + 1) % count
	AudioManager.play_ui("click")
	_sync_category_nav()

func _on_tab_changed(_tab_idx: int) -> void:
	_sync_category_nav()

func _sync_category_nav() -> void:
	var tabs: TabContainer = find_child("TabContainer", true, false)
	if not tabs:
		return
	var count: int = tabs.get_tab_count()
	if count == 0:
		return
	var cur: int = tabs.current_tab
	var title: String = tabs.get_tab_title(cur)
	if cat_title_label and is_instance_valid(cat_title_label):
		cat_title_label.text = "Category %d of %d: %s" % [cur + 1, count, title]
	var tab_bar: TabBar = tabs.get_tab_bar()
	if tab_bar and is_instance_valid(tab_bar):
		tab_bar.ensure_tab_visible(cur)

func _process(delta: float) -> void:
	if not visible:
		return

	# While any building is constructing/upgrading, refresh cards periodically so countdowns stay fresh
	_refresh_timer += delta
	if _refresh_timer >= 1.0:
		_refresh_timer = 0.0
		var has_constructing: bool = false
		for b in BuildingManager.placed_buildings:
			if is_instance_valid(b) and (b.state == b.BuildingState.CONSTRUCTING or b.state == b.BuildingState.UPGRADING):
				has_constructing = true
				break
		if has_constructing or BuildingManager.has_constructing_building("bahay_kubo") or BuildingManager.has_constructing_building("drone_station"):
			_populate_shop()

func refresh() -> void:
	_on_cash_changed(EconomyManager.cash)
	_populate_shop()
	_sync_category_nav()

func _on_cash_changed(amount: int) -> void:
	if cash_label:
		cash_label.text = "Funds: ₱%s" % Utils.format_number(amount)

# ---------------------------------------------------------------------------
# Tab Creation
# ---------------------------------------------------------------------------
func _make_tab(tab_name: String, title: String) -> GridContainer:
	var tab_container: TabContainer = find_child("TabContainer", true, false)
	if tab_container == null:
		return null

	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	pad.add_child(grid)

	tab_container.add_child(scroll)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, title)
	return grid

# ---------------------------------------------------------------------------
# CoC-Style Card Factory
# ---------------------------------------------------------------------------
func _create_coc_card(
	card_title: String,
	preview_node: Control,
	meta_left: String,
	meta_right: String,
	is_btn_disabled: bool,
	btn_text: String,
	info_title: String,
	info_desc: String,
	on_buy: Callable
) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(244, 218)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Warm parchment panel with dark wood border
	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color(0.96, 0.93, 0.88, 0.96)
	normal_box.border_color = Color(0.40, 0.28, 0.18, 0.85)
	normal_box.border_width_left = 2
	normal_box.border_width_top = 2
	normal_box.border_width_right = 2
	normal_box.border_width_bottom = 2
	normal_box.corner_radius_top_left = 6
	normal_box.corner_radius_top_right = 6
	normal_box.corner_radius_bottom_right = 6
	normal_box.corner_radius_bottom_left = 6
	normal_box.content_margin_left = 8
	normal_box.content_margin_top = 8
	normal_box.content_margin_right = 8
	normal_box.content_margin_bottom = 8
	normal_box.shadow_color = Color(0.15, 0.10, 0.05, 0.14)
	normal_box.shadow_size = 2
	normal_box.shadow_offset = Vector2(0, 2)
	card.add_theme_stylebox_override("panel", normal_box)

	# Hover style with warm gold glow
	var hover_box: StyleBoxFlat = normal_box.duplicate()
	hover_box.border_color = Color(0.85, 0.65, 0.20, 1.0)
	hover_box.bg_color = Color(0.98, 0.96, 0.91, 1.0)
	hover_box.shadow_color = Color(0.85, 0.65, 0.20, 0.22)
	hover_box.shadow_size = 3

	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hover_box))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", normal_box))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 1. Header (Title + Info Button)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 24)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_lbl := Label.new()
	title_lbl.text = card_title.to_upper()
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title_lbl)

	var info_btn := _create_info_btn(info_title, info_desc)
	header.add_child(info_btn)
	vbox.add_child(header)

	# 2. Central Sprite Preview Showcase (94px)
	if preview_node:
		preview_node.custom_minimum_size = Vector2(0, 94)
		preview_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(preview_node)

	# 3. Meta / Status Row (20px)
	var meta_row := HBoxContainer.new()
	meta_row.custom_minimum_size = Vector2(0, 20)
	meta_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var meta_l := Label.new()
	meta_l.text = meta_left
	meta_l.add_theme_font_size_override("font_size", 12)
	meta_l.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25, 1.0))
	meta_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(meta_l)

	var meta_r := Label.new()
	meta_r.text = meta_right
	meta_r.add_theme_font_size_override("font_size", 12)
	meta_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var is_green: bool = meta_right.begins_with("+") or meta_right.contains("Fresh") or meta_right.contains("Rot")
	meta_r.add_theme_color_override("font_color", Color(0.15, 0.45, 0.18, 1.0) if is_green else Color(0.55, 0.38, 0.15, 1.0))
	meta_row.add_child(meta_r)
	vbox.add_child(meta_row)

	# 4. Action / Cost Button (36px)
	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(0, 36)
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.text = btn_text
	buy_btn.disabled = is_btn_disabled

	if not is_btn_disabled:
		_style_buy_btn(buy_btn)
		buy_btn.pressed.connect(on_buy)
	else:
		buy_btn.add_theme_font_size_override("font_size", 13)

	vbox.add_child(buy_btn)
	card.add_child(vbox)
	return card

func _style_buy_btn(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", STYLE_GOLD_NORMAL)
	btn.add_theme_stylebox_override("hover", STYLE_GOLD_HOVER)
	btn.add_theme_stylebox_override("pressed", STYLE_GOLD_PRESSED)
	btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02, 1.0))
	btn.add_theme_font_size_override("font_size", 14)

func _create_info_btn(title: String, desc: String) -> Button:
	var btn: Button = Button.new()
	btn.text = "i"
	btn.custom_minimum_size = Vector2(22, 22)
	btn.tooltip_text = "%s\n%s" % [title, desc]

	btn.add_theme_stylebox_override("normal", STYLE_SQ_BROWN_NORMAL)
	btn.add_theme_stylebox_override("hover", STYLE_SQ_BROWN_HOVER)
	btn.add_theme_stylebox_override("pressed", STYLE_SQ_BROWN_PRESSED)
	btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.60))
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func(): show_info(title, desc))
	return btn

func show_info(title: String, desc: String) -> void:
	if item_info_card and info_title_lbl and info_desc_lbl:
		info_title_lbl.text = title
		info_desc_lbl.text = desc
		item_info_card.visible = true

# ---------------------------------------------------------------------------
# Procedural Art Callbacks (for items without dedicated static PNG files)
# ---------------------------------------------------------------------------
func _draw_bayanihan_preview(ci: CanvasItem, c: Vector2) -> void:
	# 1. Raised bamboo platform
	var deck := PackedVector2Array([c + Vector2(-28, 12), c + Vector2(28, 12), c + Vector2(22, 22), c + Vector2(-22, 22)])
	ci.draw_colored_polygon(deck, Color(0.72, 0.58, 0.34))
	ci.draw_polyline(deck, Color(0.42, 0.30, 0.16), 1.2)

	# 2. Bamboo timber posts
	for px in [-24, -8, 8, 24]:
		ci.draw_line(c + Vector2(px, 14), c + Vector2(px, -12), Color(0.48, 0.36, 0.22), 3.0)
		ci.draw_line(c + Vector2(px, 14), c + Vector2(px, -12), Color(0.68, 0.52, 0.30), 1.5)

	# 3. Communal chalkboard bulletin
	ci.draw_rect(Rect2(c.x - 12, c.y - 8, 24, 14), Color(0.38, 0.26, 0.14)) # Frame
	ci.draw_rect(Rect2(c.x - 10, c.y - 6, 20, 10), Color(0.18, 0.26, 0.20)) # Green slate
	ci.draw_line(c + Vector2(-7, -3), c + Vector2(7, -3), Color(1.0, 1.0, 1.0, 0.8), 1.0)
	ci.draw_line(c + Vector2(-6, 0), c + Vector2(4, 0), Color(0.95, 0.85, 0.40, 0.7), 1.0)

	# 4. Clay water jar on left
	ci.draw_circle(c + Vector2(-16, 14), 4.5, Color(0.68, 0.36, 0.18))
	ci.draw_circle(c + Vector2(-16, 11), 2.5, Color(0.45, 0.20, 0.10))

	# 5. Thatched nipa roof
	var roof := PackedVector2Array([
		c + Vector2(0, -26),
		c + Vector2(32, -10),
		c + Vector2(-32, -10)
	])
	ci.draw_colored_polygon(roof, Color(0.76, 0.62, 0.34))
	ci.draw_polyline(roof, Color(0.42, 0.30, 0.14), 1.5)

	# 6. Festive Banderitas (Fiesta Bunting)
	var flag_cols: Array[Color] = [
		Color(0.92, 0.22, 0.18),
		Color(0.96, 0.82, 0.18),
		Color(0.20, 0.65, 0.30),
		Color(0.18, 0.50, 0.90)
	]
	ci.draw_line(c + Vector2(-30, -9), c + Vector2(30, -9), Color(0.85, 0.80, 0.70, 0.8), 1.0)
	for i in range(5):
		var fx: float = -20.0 + float(i) * 10.0
		var tri := PackedVector2Array([
			c + Vector2(fx - 2, -9), c + Vector2(fx + 2, -9),
			c + Vector2(fx, -5)
		])
		ci.draw_colored_polygon(tri, flag_cols[i % flag_cols.size()])

func _draw_sprinkler_preview(ci: CanvasItem, c: Vector2) -> void:
	# Concrete anchor pad
	var pad := PackedVector2Array([c + Vector2(-18, 14), c + Vector2(0, 22), c + Vector2(18, 14), c + Vector2(0, 6)])
	ci.draw_colored_polygon(pad, Color(0.65, 0.62, 0.58))
	ci.draw_polyline(pad, Color(0.38, 0.35, 0.30), 1.2)
	# Galvanized steel riser pipe
	ci.draw_line(c + Vector2(0, 12), c + Vector2(0, -12), Color(0.42, 0.46, 0.50), 4.5)
	ci.draw_line(c + Vector2(-1, 12), c + Vector2(-1, -12), Color(0.68, 0.72, 0.76), 1.5)
	# Rotating brass impact head & hammer arm
	ci.draw_circle(c + Vector2(0, -12), 5.0, Color(0.85, 0.68, 0.25))
	ci.draw_line(c + Vector2(0, -12), c + Vector2(12, -18), Color(0.92, 0.75, 0.30), 2.5)
	# Dynamic water spray stream
	var stream := PackedVector2Array([
		c + Vector2(12, -18), c + Vector2(22, -22), c + Vector2(32, -20), c + Vector2(38, -14)
	])
	ci.draw_polyline(stream, Color(0.45, 0.85, 1.0, 0.85), 2.0)
	ci.draw_circle(c + Vector2(26, -22), 2.0, Color(0.85, 0.96, 1.0, 0.95))
	ci.draw_circle(c + Vector2(38, -14), 2.2, Color(0.75, 0.95, 1.0, 0.90))
	ci.draw_circle(c + Vector2(34, -26), 1.5, Color(0.75, 0.95, 1.0, 0.80))

func _draw_drone_preview(ci: CanvasItem, c: Vector2) -> void:
	FarmDrone.draw_drone_art(ci, c + Vector2(0, -2), 2.6, 2, 0.0, 0.0)

func _draw_rice_mill_preview(ci: CanvasItem, c: Vector2) -> void:
	# Concrete base pad
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-30, 16), c + Vector2(30, 16), c + Vector2(24, 26), c + Vector2(-24, 26)]), Color(0.35, 0.32, 0.28))
	# Mill shed body
	var body := PackedVector2Array([c + Vector2(-24, 16), c + Vector2(24, 16), c + Vector2(24, -14), c + Vector2(-24, -14)])
	ci.draw_colored_polygon(body, Color(0.52, 0.46, 0.38))
	ci.draw_polyline(body, Color(0.25, 0.20, 0.16), 1.5)
	# Corrugated gable roof
	var roof := PackedVector2Array([c + Vector2(-28, -12), c + Vector2(28, -12), c + Vector2(0, -32)])
	ci.draw_colored_polygon(roof, Color(0.65, 0.70, 0.75))
	ci.draw_polyline(roof, Color(0.35, 0.40, 0.45), 1.8)
	# Intake hopper with golden paddy
	var hop := PackedVector2Array([c + Vector2(-22, -10), c + Vector2(-8, -10), c + Vector2(-12, 4), c + Vector2(-18, 4)])
	ci.draw_colored_polygon(hop, Color(0.32, 0.36, 0.40))
	ci.draw_circle(c + Vector2(-15, -8), 4.5, Color(0.92, 0.78, 0.25))
	# White rice sack & bin
	ci.draw_rect(Rect2(c + Vector2(8, 2), Vector2(14, 12)), Color(0.40, 0.28, 0.16))
	ci.draw_circle(c + Vector2(15, 6), 5.0, Color(0.95, 0.98, 0.98))

func _draw_sugar_mill_preview(ci: CanvasItem, c: Vector2) -> void:
	# Brick foundation
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-32, 16), c + Vector2(32, 16), c + Vector2(26, 26), c + Vector2(-26, 26)]), Color(0.48, 0.22, 0.16))
	# Boiler chimney
	var chim := PackedVector2Array([c + Vector2(-22, 14), c + Vector2(-10, 14), c + Vector2(-12, -30), c + Vector2(-20, -30)])
	ci.draw_colored_polygon(chim, Color(0.56, 0.24, 0.18))
	ci.draw_polyline(chim, Color(0.30, 0.12, 0.08), 1.5)
	# Soft smoke puffs
	ci.draw_circle(c + Vector2(-16, -34), 4.0, Color(0.90, 0.92, 0.95, 0.7))
	ci.draw_circle(c + Vector2(-14, -40), 5.5, Color(0.90, 0.92, 0.95, 0.4))
	# Crushing shed & terracotta roof
	var shed := PackedVector2Array([c + Vector2(-8, 14), c + Vector2(28, 14), c + Vector2(28, -6), c + Vector2(-8, -6)])
	ci.draw_colored_polygon(shed, Color(0.42, 0.35, 0.28))
	var s_roof := PackedVector2Array([c + Vector2(-12, -4), c + Vector2(32, -4), c + Vector2(10, -22)])
	ci.draw_colored_polygon(s_roof, Color(0.75, 0.38, 0.20))
	# Cane stalks & dark muscovado blocks
	ci.draw_line(c + Vector2(-4, 4), c + Vector2(8, 12), Color(0.45, 0.72, 0.25), 3.0)
	ci.draw_rect(Rect2(c + Vector2(14, 6), Vector2(10, 8)), Color(0.28, 0.14, 0.06))

func _draw_copra_dryer_preview(ci: CanvasItem, c: Vector2) -> void:
	# Stone hearth structure
	var hearth := PackedVector2Array([c + Vector2(-26, 16), c + Vector2(26, 16), c + Vector2(26, -10), c + Vector2(-26, -10)])
	ci.draw_colored_polygon(hearth, Color(0.45, 0.40, 0.35))
	ci.draw_polyline(hearth, Color(0.24, 0.20, 0.16), 1.5)
	# Glowing fire pit
	ci.draw_circle(c + Vector2(-6, 6), 7.0, Color(0.12, 0.08, 0.05))
	ci.draw_circle(c + Vector2(-6, 7), 5.0, Color(1.0, 0.45, 0.10))
	ci.draw_circle(c + Vector2(-6, 6), 2.5, Color(1.0, 0.90, 0.25))
	# Drying bamboo grate & coconuts
	ci.draw_line(c + Vector2(-24, -10), c + Vector2(14, -10), Color(0.68, 0.58, 0.42), 3.0)
	ci.draw_circle(c + Vector2(-16, -12), 3.5, Color(0.38, 0.22, 0.12))
	ci.draw_circle(c + Vector2(-16, -12), 2.0, Color(0.95, 0.95, 0.95))
	ci.draw_circle(c + Vector2(-6, -12), 3.5, Color(0.38, 0.22, 0.12))
	ci.draw_circle(c + Vector2(-6, -12), 2.0, Color(0.95, 0.95, 0.95))
	ci.draw_circle(c + Vector2(4, -12), 3.5, Color(0.38, 0.22, 0.12))
	ci.draw_circle(c + Vector2(4, -12), 2.0, Color(0.95, 0.95, 0.95))
	# Oil screw press
	ci.draw_line(c + Vector2(18, 14), c + Vector2(18, -20), Color(0.32, 0.24, 0.18), 4.5)
	ci.draw_line(c + Vector2(12, -18), c + Vector2(24, -18), Color(0.65, 0.68, 0.72), 2.5)
	ci.draw_circle(c + Vector2(18, 10), 3.5, Color(0.90, 0.98, 0.85))

func _draw_coffee_roastery_preview(ci: CanvasItem, c: Vector2) -> void:
	# Red brick oven base
	var base := PackedVector2Array([c + Vector2(-26, 16), c + Vector2(26, 16), c + Vector2(26, -12), c + Vector2(-26, -12)])
	ci.draw_colored_polygon(base, Color(0.55, 0.24, 0.20))
	ci.draw_polyline(base, Color(0.28, 0.10, 0.08), 1.5)
	# Cast iron drum roaster cylinder
	ci.draw_circle(c + Vector2(-6, -14), 11.0, Color(0.22, 0.24, 0.26))
	ci.draw_circle(c + Vector2(-6, -14), 9.0, Color(0.30, 0.32, 0.36))
	ci.draw_line(c + Vector2(-16, -14), c + Vector2(4, -14), Color(0.80, 0.50, 0.25), 2.0)
	ci.draw_circle(c + Vector2(-6, -8), 2.5, Color(1.0, 0.50, 0.15))
	# Stainless exhaust chimney with aromatic smoke
	ci.draw_line(c + Vector2(-16, -22), c + Vector2(-16, -34), Color(0.68, 0.72, 0.76), 3.0)
	ci.draw_circle(c + Vector2(-16, -38), 3.5, Color(0.88, 0.82, 0.75, 0.6))
	# Circular cooling tray with roasted dark beans
	ci.draw_circle(c + Vector2(14, 6), 9.0, Color(0.68, 0.72, 0.76))
	ci.draw_circle(c + Vector2(14, 6), 7.5, Color(0.24, 0.14, 0.08))


# ---------------------------------------------------------------------------
# Populating Tabs
# ---------------------------------------------------------------------------
func _populate_shop() -> void:
	_populate_labor()
	_populate_buildings()
	_populate_land()

func _populate_labor() -> void:
	if labor_grid == null:
		return
	for child in labor_grid.get_children():
		labor_grid.remove_child(child)
		child.queue_free()

	var act: int = BuildingManager.active_workers
	var cap: int = BuildingManager.worker_capacity
	var cash: int = EconomyManager.cash
	var is_constructing_kubo: bool = BuildingManager.has_constructing_building("bahay_kubo")

	# ── 1. Bahay Kubo Card ─────────────────────────────────────────────
	var kubo_data: Dictionary = Data.get_building("bahay_kubo")
	var kubo_cost: int = int(kubo_data.get("cost", 200))
	var kubo_btn_text: String = "₱%s" % Utils.format_number(kubo_cost)
	var kubo_disabled: bool = (cash < kubo_cost)

	if is_constructing_kubo:
		var rem_time: float = BuildingManager.get_building_construction_time_remaining("bahay_kubo")
		kubo_btn_text = "Building (%.0fs)" % rem_time
		kubo_disabled = true
	elif cash < kubo_cost:
		kubo_btn_text = "Need ₱%d" % kubo_cost

	var kubo_card = _create_coc_card(
		"Bahay Kubo",
		ShopSpritePreview.new("bahay_kubo", TEX_KUBO),
		"⏱ 8s Build",
		"+1 Worker Slot",
		kubo_disabled,
		kubo_btn_text,
		"Bahay Kubo (Farm Shack)",
		kubo_data.get("description", "Expands worker housing."),
		func(): _buy_building("bahay_kubo", kubo_cost)
	)
	labor_grid.add_child(kubo_card)

	# ── 2. Farm Worker Card ────────────────────────────────────────────
	var worker_cost: int = 200
	var worker_btn_text: String = "₱200 Hire"
	var worker_disabled: bool = false

	if is_constructing_kubo and act >= cap:
		var rem: float = BuildingManager.get_building_construction_time_remaining("bahay_kubo")
		worker_btn_text = "Building (%.0fs)" % rem
		worker_disabled = true
	elif act >= cap:
		worker_btn_text = "Housing Full"
		worker_disabled = true
	elif cash < worker_cost:
		worker_btn_text = "Need ₱200"
		worker_disabled = true

	var worker_card = _create_coc_card(
		"Farm Worker",
		ShopSpritePreview.new("farmer", TEX_FARMER),
		"⏱ Instant",
		"Active: %d/%d" % [act, cap],
		worker_disabled,
		worker_btn_text,
		"Autonomous Farm Laborer",
		"Hires an autonomous worker to till, plant, water, spray, and harvest directly to storage. Daily wage: ₱15.",
		_hire_worker
	)
	labor_grid.add_child(worker_card)

	# ── 3. Farm Drone Card ─────────────────────────────────────────────
	var d_act: int = BuildingManager.active_drones
	var d_cap: int = BuildingManager.get_drone_capacity()
	var has_hangar: bool = BuildingManager.has_drone_station()
	var is_building_hangar: bool = BuildingManager.has_constructing_building("drone_station")
	var drone_cost: int = 350
	var drone_btn_text: String = "₱350 Commission"
	var drone_disabled: bool = false

	if not has_hangar and not is_building_hangar:
		drone_btn_text = "No Hangar"
		drone_disabled = true
	elif is_building_hangar:
		var rem_d: float = BuildingManager.get_building_construction_time_remaining("drone_station")
		drone_btn_text = "Building (%.0fs)" % rem_d
		drone_disabled = true
	elif d_act >= d_cap:
		drone_btn_text = "No Pilots (%d/%d)" % [d_act, d_cap]
		drone_disabled = true
	elif cash < drone_cost:
		drone_btn_text = "Need ₱350"
		drone_disabled = true

	var drone_card = _create_coc_card(
		"Precision Drone",
		ShopSpritePreview.new("drone", null, Color.WHITE, _draw_drone_preview),
		"⏱ Instant",
		"Active: %d/%d Pilots" % [d_act, d_cap],
		drone_disabled,
		drone_btn_text,
		"Autonomous Precision Drone",
		"Automated farm drone. Automatically plows, plants, and harvests in assigned zones. Requires Drone Hangar & pilot capacity.",
		_commission_drone
	)
	labor_grid.add_child(drone_card)

func _populate_buildings() -> void:
	_fill_category_grid(storage_grid, "storage")
	_fill_category_grid(weather_grid, "weather")
	if weather_grid:
		weather_grid.add_child(_create_heatmap_tech_card())
	_fill_category_grid(machinery_grid, "machinery")
	_fill_category_grid(processing_grid, "processing")
	_fill_category_grid(trade_grid, "trade")

func _fill_category_grid(grid: GridContainer, category: String) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	for b_key in Data.BUILDINGS.keys():
		var b_data: Dictionary = Data.get_building(b_key)
		if str(b_data.get("shop_category", "")) == category:
			grid.add_child(_create_building_coc_card(b_key))

func _create_building_coc_card(b_key: String) -> PanelContainer:
	var b_data: Dictionary = Data.get_building(b_key)
	var is_unique: bool = BuildingManager.is_unique_building(b_key)
	var existing: Node = BuildingManager.get_building_of_type(b_key) if is_unique else null
	var cost: int = int(b_data.get("cost", 400))
	var cash: int = EconomyManager.cash
	var build_sec: float = float(b_data.get("build_time", 15.0))

	# 1. Meta left & right
	var fp: Vector2i = b_data.get("grid_size", Vector2i(2, 2))
	var meta_left: String = "⏱ %.0fs • %d×%d" % [build_sec, fp.x, fp.y]
	var meta_right: String = ""

	if b_data.get("halts_spoilage", false):
		meta_right = "Halts Rot • 100%"
	elif b_data.get("storage_limit", 0) > 0:
		meta_right = "+%d Cap" % b_data.get("storage_limit", 0)
	elif b_data.get("worker_capacity", 0) > 0:
		meta_right = "+%d Worker" % b_data.get("worker_capacity", 0)
	elif b_data.get("unlocks_drones", false):
		meta_right = "★ One-time • Drones"
	elif b_data.get("forecast_equipment", false):
		meta_right = "★ One-time • Radar"
	elif b_data.get("irrigation_equipment", false):
		meta_right = "★ One-time • Pump"
	elif b_data.get("is_sprinkler", false):
		var act_spk: int = BuildingManager.get_active_sprinkler_count()
		var cap_spk: int = BuildingManager.get_sprinkler_capacity()
		var cap_str: String = str(cap_spk) if cap_spk < 999 else "∞"
		meta_right = "💧 %d/%s Active" % [act_spk, cap_str]
	elif b_data.get("biyahero_price_bonus", 0.0) > 0.0:
		meta_right = "+8% Biyahero"
	elif b_data.has("hub_id"):
		meta_right = "Unlocks Hub"
	elif b_data.get("unlocks_bayanihan", false) or b_data.get("unlocks_machines", false):
		meta_right = "🤝 Cooperative"
	elif b_data.get("drying_bonus", 0.0) > 0.0:
		meta_right = "+25% Quality"
	elif b_data.get("shop_category", "") == "processing":
		var prereqs: Dictionary = BuildingManager.get_processing_prerequisites(b_key)
		if not prereqs.allowed:
			meta_right = "Locked 🔒"
		else:
			meta_right = "⚡ Auto 4h"

	# 2. Button state & text
	var btn_text: String = "₱%s" % Utils.format_number(cost)
	var is_disabled: bool = (cash < cost)

	if existing != null:
		var max_lvl: int = int(b_data.get("max_level", 3))
		if existing.state == existing.BuildingState.CONSTRUCTING:
			btn_text = "Building (%.0fs)" % BuildingManager.get_building_construction_time_remaining(b_key)
		elif existing.state == existing.BuildingState.UPGRADING:
			btn_text = "Upgrading Lv.%d" % (existing.level + 1)
		else:
			btn_text = "Built ✔ (Lv.%d/%d)" % [existing.level, max_lvl]
		is_disabled = true
	elif b_key == "sprinkler":
		meta_left = "⏱ 4s Deploy"
		var has_pump: bool = BuildingManager.has_irrigation()
		if not has_pump:
			btn_text = "Locked 🔒"
			is_disabled = true
			meta_right = "Req. Water Tower"
		elif not BuildingManager.can_place_sprinkler():
			btn_text = "Pressure Max"
			is_disabled = true
		elif cash < cost:
			btn_text = "Need ₱%d" % cost
			is_disabled = true
		else:
			btn_text = "₱%d Deploy" % cost
	elif b_data.get("shop_category", "") == "processing":
		var prereqs: Dictionary = BuildingManager.get_processing_prerequisites(b_key)
		if not prereqs.allowed:
			btn_text = "Locked 🔒"
			is_disabled = true
			if not prereqs.has_land_deed:
				meta_right = "Req. Land Deed"
			elif not prereqs.has_storage_cap:
				meta_right = "Req. Lv.2 Silo"
		elif cash < cost:
			btn_text = "Need ₱%d" % cost
			is_disabled = true
	elif cash < cost:
		btn_text = "Need ₱%d" % cost

	# 3. Sprite Preview
	var preview_node: Control = null
	match b_key:
		"bodega":
			preview_node = ShopSpritePreview.new(b_key, TEX_SILO)
		"solar_dryer":
			preview_node = ShopSpritePreview.new(b_key, TEX_DRYER)
		"cold_storage":
			preview_node = ShopSpritePreview.new(b_key, TEX_COLD_STORAGE)
		"climate_silo":
			preview_node = ShopSpritePreview.new(b_key, TEX_SILO, Color(0.85, 0.95, 1.15))
		"weather_station":
			preview_node = ShopSpritePreview.new(b_key, TEX_WEATHER_STATION)
		"water_tower":
			preview_node = ShopSpritePreview.new(b_key, TEX_WATER_STATION)
		"drone_station":
			preview_node = ShopSpritePreview.new(b_key, TEX_DRONE_STATION)
		"bayanihan_center":
			preview_node = ShopSpritePreview.new(b_key, TEX_BYAHERO)
		"tacurong_mill":
			preview_node = ShopSpritePreview.new(b_key, TEX_TACURONG)
		"koronadal_wholesale":
			preview_node = ShopSpritePreview.new(b_key, TEX_KORONADAL)
		"gensan_seaport":
			preview_node = ShopSpritePreview.new(b_key, TEX_GENSAN)
		"machine_garage":
			preview_node = ShopSpritePreview.new(b_key, null, Color.WHITE, _draw_bayanihan_preview)
		"sprinkler":
			preview_node = ShopSpritePreview.new(b_key, null, Color.WHITE, _draw_sprinkler_preview)
		"rice_mill":
			preview_node = ShopSpritePreview.new(b_key, TEX_RICE_MILL)
		"sugar_mill":
			preview_node = ShopSpritePreview.new(b_key, TEX_SUGAR_MILL)
		"copra_dryer":
			preview_node = ShopSpritePreview.new(b_key, TEX_COPRA_DRYER)
		"coffee_roastery":
			preview_node = ShopSpritePreview.new(b_key, TEX_COFFEE_ROASTERY)
		_:
			preview_node = ShopSpritePreview.new(b_key, TEX_KUBO)

	return _create_coc_card(
		b_data.get("display_name", b_key),
		preview_node,
		meta_left,
		meta_right,
		is_disabled,
		btn_text,
		b_data.get("display_name", b_key),
		b_data.get("description", "Agricultural facility."),
		func(): _buy_building(b_key, cost)
	)

func _populate_land() -> void:
	if land_grid == null:
		return
	for child in land_grid.get_children():
		land_grid.remove_child(child)
		child.queue_free()

	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	var unlocked_parcels: Array = farm_grid.unlocked_parcels if (farm_grid and "unlocked_parcels" in farm_grid) else ["homestead"]
	var cash: int = EconomyManager.cash

	for p in Data.LAND_PARCELS:
		var pid: String = p.get("id", "")
		var is_owned: bool = unlocked_parcels.has(pid)
		var cost: int = p.get("cost", 0)
		var r_sz: Vector2i = p.get("rect", Rect2i()).size

		var meta_left: String = "📐 %d×%d Plots" % [r_sz.x, r_sz.y]
		var meta_right: String = pid.capitalize()
		var btn_text: String = "₱%s Buy" % Utils.format_number(cost)
		var is_disabled: bool = (cash < cost)

		if is_owned:
			btn_text = "Owned ✔"
			is_disabled = true
		elif cash < cost:
			btn_text = "Need ₱%d" % cost

		var card = _create_coc_card(
			p.get("name", "Territory"),
			ShopSpritePreview.new("land", TEX_GRASS),
			meta_left,
			meta_right,
			is_disabled,
			btn_text,
			p.get("name", "Territory"),
			p.get("description", "Expandable agricultural territory."),
			func():
				if farm_grid and farm_grid.has_method("open_land_expansion_modal"):
					farm_grid.open_land_expansion_modal(pid)
		)
		land_grid.add_child(card)

# ---------------------------------------------------------------------------
# Purchasing Actions
# ---------------------------------------------------------------------------
func _buy_building(b_key: String, cost: int) -> void:
	if BuildingManager.is_unique_building(b_key) and BuildingManager.owns_building(b_key):
		status_label.text = "%s is already built — click it on your farm to upgrade it." % str(Data.get_building(b_key).get("display_name", b_key))
		status_label.modulate = Color(1.0, 0.75, 0.2)
		_populate_buildings()
		return

	if b_key == "sprinkler":
		if not BuildingManager.has_irrigation():
			status_label.text = "Cannot deploy Sprinkler! Requires an active Irrigation Pump & Tower."
			status_label.modulate = Color(1.0, 0.3, 0.3)
			return
		if not BuildingManager.can_place_sprinkler():
			status_label.text = "Cannot deploy Sprinkler! Water pressure capacity reached (%d/%d)." % [
				BuildingManager.get_active_sprinkler_count(),
				BuildingManager.get_sprinkler_capacity()
			]
			status_label.modulate = Color(1.0, 0.3, 0.3)
			return

	if EconomyManager.cash < cost:
		status_label.text = "Insufficient funds for %s! (₱%d required)" % [b_key.capitalize(), cost]
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	var farm_grid: Node = get_tree().root.find_child("FarmGrid", true, false)
	if farm_grid == null:
		status_label.text = "Cannot place building — FarmGrid not found!"
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	# Close shop so the player can see the grid for ghost placement
	visible = false
	farm_grid.start_building_placement(b_key)

func _hire_worker() -> void:
	var act: int = BuildingManager.active_workers
	var cap: int = BuildingManager.worker_capacity

	if act >= cap:
		if BuildingManager.has_constructing_building("bahay_kubo"):
			var rem: float = BuildingManager.get_building_construction_time_remaining("bahay_kubo")
			status_label.text = "Bahay Kubo is still under construction (%.0fs remaining)! Please wait for it to finish." % rem
			status_label.modulate = Color(1.0, 0.75, 0.2)
		else:
			status_label.text = "Cannot hire! Housing capacity full. Construct a Bahay Kubo first."
			status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if EconomyManager.cash < 200:
		status_label.text = "Cannot hire! Insufficient funds (₱200 required, you have ₱%d)." % EconomyManager.cash
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if BuildingManager.hire_worker():
		status_label.text = "🎉 Hired worker! New autonomous farmer spawned at depot."
		status_label.modulate = Color(0.4, 1.0, 0.4)
		_populate_labor()
		worker_spawn_requested.emit()
	else:
		status_label.text = "Could not hire worker!"
		status_label.modulate = Color(1.0, 0.3, 0.3)

func _commission_drone() -> void:
	if not BuildingManager.has_drone_station():
		if BuildingManager.has_constructing_building("drone_station"):
			var rem: float = BuildingManager.get_building_construction_time_remaining("drone_station")
			status_label.text = "Drone Command Hangar is under construction (%.0fs left)! Please wait for it to complete." % rem
			status_label.modulate = Color(1.0, 0.75, 0.2)
		else:
			status_label.text = "Cannot commission drone! Construct a Drone Command Hangar in Machinery first."
			status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if BuildingManager.active_drones >= BuildingManager.get_drone_capacity():
		status_label.text = "Cannot commission drone! Drone pilot limit reached (%d/%d farmers). Hire more farmers to control more drones." % [
			BuildingManager.active_drones, BuildingManager.active_workers
		]
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if EconomyManager.cash < 350:
		status_label.text = "Cannot commission drone! Insufficient funds (₱350 required, you have ₱%d)." % EconomyManager.cash
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	if BuildingManager.commission_drone(350):
		status_label.text = "🛸 Commissioned Farm Drone #%d! Remote control unlocked on worker hotbar (hotkey 4)." % BuildingManager.active_drones
		status_label.modulate = Color(0.4, 1.0, 0.4)
		_populate_labor()
		item_purchased.emit("farm_drone", 350)
	else:
		status_label.text = "Could not commission drone!"
		status_label.modulate = Color(1.0, 0.3, 0.3)

func _create_heatmap_tech_card() -> PanelContainer:
	var tech_data: Dictionary = Data.get_tech("field_survey_kit")
	var cost: int = int(tech_data.get("cost", 400))
	var cash: int = EconomyManager.cash
	var is_owned: bool = BuildingManager.has_heatmap()

	var meta_left: String = "📡 Soil Scanner"
	var meta_right: String = "Diagnostic F"

	var btn_text: String = ""
	var is_disabled: bool = false
	if is_owned:
		btn_text = "Owned ✔"
		is_disabled = true
	elif cash < cost:
		btn_text = "Need ₱%d" % cost
		is_disabled = true
	else:
		btn_text = "₱%d Buy" % cost

	var preview_node = ShopSpritePreview.new("field_survey_kit", TEX_HEATMAP)

	var on_buy = func():
		if BuildingManager.buy_tech("field_survey_kit"):
			AudioManager.play_ui("click")
			status_label.text = "📡 Unlocked Field Survey Kit! Press F or click radar HUD button to open Soil & Diagnostic Heatmap."
			status_label.modulate = Color(0.4, 1.0, 0.4)
			_populate_buildings()
			_on_cash_changed(EconomyManager.cash)

	return _create_coc_card(
		"Field Survey Kit",
		preview_node,
		meta_left,
		meta_right,
		is_disabled,
		btn_text,
		"Field Survey Kit (Diagnostic Heatmap)",
		"Unlocks the live Soil & Farm Diagnostic Heatmap overlay (hotkey F). View live soil moisture gradients, plant health, ripe harvests, pest blights, and sprinkler coverage across your whole farm.",
		on_buy
	)

func _on_close_pressed() -> void:
	if item_info_card:
		item_info_card.visible = false
	visible = false
