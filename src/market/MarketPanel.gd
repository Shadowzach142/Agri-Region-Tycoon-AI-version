# MarketPanel.gd
# Dedicated Agricultural Commodity Market Dashboard.
# Displays live commodity prices, 7-day trend stock charts, market advice,
# and regional price comparisons across all 4 provincial trading hubs.

extends PanelContainer

const CROP_KEYS: Array[String] = [
	"palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"
]

const HUB_KEYS: Array[String] = [
	"local_biyahero", "tacurong", "koronadal", "gensan_port"
]

const MarketChartScript = preload("res://src/market/MarketChart.gd")

var selected_crop: String = "palay"

# UI references
var _dim_overlay: ColorRect = null
var _header_label: Label = null
var _close_btn: Button = null

# Left Column (Ticker)
var _ticker_cards: Dictionary = {}
var _news_label: Label = null

# Right Column (Chart & Hub Comparison)
var _crop_title_label: Label = null
var _crop_price_label: Label = null
var _crop_base_label: Label = null
var _advice_badge: PanelContainer = null
var _advice_label: Label = null
var _chart: Control = null
var _hub_rows: Array = []

# Wholesale Buy/Sell & Cross-Region Strip
var _ask_bid_label: Label = null
var _stored_label: Label = null
var _buy_25_btn: Button = null
var _buy_50_btn: Button = null
var _sell_local_btn: Button = null
var _trade_feedback_label: Label = null
var _region_price_labels: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		child.queue_free()

	_apply_panel_style()
	_create_dim_overlay()
	_build_ui()

	MarketManager.price_updated.connect(_on_price_updated)
	if MarketManager.has_signal("market_region_updated"):
		MarketManager.market_region_updated.connect(_on_market_region_updated)
	MarketManager.inventory_changed.connect(_on_inventory_changed)
	EconomyManager.cash_changed.connect(_on_cash_changed)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	TimeManager.day_changed.connect(_on_day_changed)

	refresh_all()

func _apply_panel_style() -> void:
	custom_minimum_size = Vector2(920, 610)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left   = -460.0
	offset_top    = -305.0
	offset_right  =  460.0
	offset_bottom =  305.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical   = Control.GROW_DIRECTION_BOTH

	var ps = preload("res://assets/sprites/hud/Shop/Shop Backgroud.tres")
	add_theme_stylebox_override("panel", ps)

func _create_dim_overlay() -> void:
	_dim_overlay = ColorRect.new()
	_dim_overlay.name = "MarketDimOverlay"
	_dim_overlay.color = Color(0.03, 0.04, 0.03, 0.70)
	_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	_dim_overlay.visible = false

	var parent_ctrl = get_parent()
	if parent_ctrl:
		parent_ctrl.add_child.call_deferred(_dim_overlay)
		parent_ctrl.move_child.call_deferred(_dim_overlay, get_index())

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if _dim_overlay and is_instance_valid(_dim_overlay):
			_dim_overlay.visible = visible
		if visible:
			refresh_all()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	visible = false
	if _dim_overlay and is_instance_valid(_dim_overlay):
		_dim_overlay.visible = false

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(root)

	# 1. Header Bar
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	_header_label = Label.new()
	_header_label.text = "📈 REGIONAL COMMODITY MARKET"
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.add_theme_color_override("font_color", Color(0.18, 0.10, 0.05, 1.0))
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_header_label)

	_close_btn = Button.new()
	_close_btn.text = " ✕ "
	_close_btn.custom_minimum_size = Vector2(30, 30)
	_close_btn.add_theme_font_size_override("font_size", 14)
	_close_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"))
	_close_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres"))
	_close_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres"))
	_close_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	_close_btn.pressed.connect(close)
	header.add_child(_close_btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.55, 0.42, 0.30, 0.5))
	root.add_child(sep)

	# 2. Main Two-Column Layout
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# --- LEFT: Commodity Ticker (230px) ---
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(230, 0)
	left_col.add_theme_constant_override("separation", 6)
	body.add_child(left_col)

	var hdr := Label.new()
	hdr.text = "🌾 COMMODITIES (Click to View)"
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.24, 0.14, 0.06, 1.0))
	left_col.add_child(hdr)

	for crop_key in CROP_KEYS:
		var card := _build_ticker_card(crop_key)
		_ticker_cards[crop_key] = card
		left_col.add_child(card)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("separator_color", Color(0.55, 0.42, 0.30, 0.4))
	left_col.add_child(sep2)

	# News Intel Card
	var news_box := PanelContainer.new()
	news_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	news_box.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))
	left_col.add_child(news_box)

	var news_margin := MarginContainer.new()
	news_margin.add_theme_constant_override("margin_left", 8)
	news_margin.add_theme_constant_override("margin_right", 8)
	news_margin.add_theme_constant_override("margin_top", 6)
	news_margin.add_theme_constant_override("margin_bottom", 6)
	news_box.add_child(news_margin)

	var news_inner := VBoxContainer.new()
	news_inner.add_theme_constant_override("separation", 4)
	news_margin.add_child(news_inner)

	var news_title := Label.new()
	news_title.text = "📰 MARKET INTEL"
	news_title.add_theme_font_size_override("font_size", 13)
	news_title.add_theme_color_override("font_color", Color(0.24, 0.14, 0.06, 1.0))
	news_inner.add_child(news_title)

	_news_label = Label.new()
	_news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news_label.add_theme_font_size_override("font_size", 12)
	_news_label.add_theme_color_override("font_color", Color(0.18, 0.14, 0.10, 1.0))
	news_inner.add_child(_news_label)

	# --- RIGHT: Chart & Regional Price Comparison ---
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	body.add_child(right_col)

	# Header row with title, price, advice
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	right_col.add_child(info_row)

	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 2)
	info_row.add_child(title_col)

	_crop_title_label = Label.new()
	_crop_title_label.text = "🌾 Palay (Rice)"
	_crop_title_label.add_theme_font_size_override("font_size", 19)
	_crop_title_label.add_theme_color_override("font_color", Color(0.18, 0.10, 0.05, 1.0))
	title_col.add_child(_crop_title_label)

	_crop_base_label = Label.new()
	_crop_base_label.text = "Baseline: ₱100/u"
	_crop_base_label.add_theme_font_size_override("font_size", 13)
	_crop_base_label.add_theme_color_override("font_color", Color(0.35, 0.24, 0.14, 1.0))
	title_col.add_child(_crop_base_label)

	_crop_price_label = Label.new()
	_crop_price_label.text = "₱100 / u"
	_crop_price_label.add_theme_font_size_override("font_size", 22)
	_crop_price_label.add_theme_color_override("font_color", Color(0.04, 0.48, 0.12, 1.0))
	info_row.add_child(_crop_price_label)

	_advice_badge = PanelContainer.new()
	_advice_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advice_badge.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/TopRight/BrownBox.tres"))
	info_row.add_child(_advice_badge)

	var adv_margin := MarginContainer.new()
	adv_margin.add_theme_constant_override("margin_left", 8)
	adv_margin.add_theme_constant_override("margin_right", 8)
	adv_margin.add_theme_constant_override("margin_top", 4)
	adv_margin.add_theme_constant_override("margin_bottom", 4)
	_advice_badge.add_child(adv_margin)

	_advice_label = Label.new()
	_advice_label.text = "🟢 BULL MARKET — High Demand"
	_advice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_advice_label.add_theme_font_size_override("font_size", 13)
	adv_margin.add_child(_advice_label)

	# 7-Day Chart
	_chart = MarketChartScript.new()
	_chart.custom_minimum_size = Vector2(0, 145)
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_child(_chart)

	# Regional Price Comparison Table
	_build_regional_table(right_col)

	# Local Wholesale Buy/Sell & Cross-Region Comparison Strip
	_build_trade_and_region_strip(right_col)

func _build_ticker_card(crop_key: String) -> Button:
	var crop_data: Dictionary = Data.get_crop(crop_key)
	var icon_str: String = crop_data.get("icon", "🌱")
	var disp_name: String = crop_data.get("display_name", crop_key.capitalize())
	var short_name: String = disp_name.split("(")[0].strip_edges()
	if crop_key == "pineapple":
		short_name = "Pineapple"
	elif crop_key == "banana":
		short_name = "Banana"
	elif crop_key == "coconut":
		short_name = "Coconut"

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(230, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(func(): _on_crop_selected(crop_key))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	btn.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.text = "%s %s" % [icon_str, short_name]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.name = "PriceLbl"
	price_lbl.text = "₱--"
	price_lbl.add_theme_font_size_override("font_size", 14)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	hbox.add_child(price_lbl)

	var trend_lbl := Label.new()
	trend_lbl.name = "TrendLbl"
	trend_lbl.text = "▲+0%"
	trend_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(trend_lbl)

	return btn

func _build_regional_table(parent: VBoxContainer) -> void:
	var table_box := PanelContainer.new()
	table_box.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))
	parent.add_child(table_box)

	var t_margin := MarginContainer.new()
	t_margin.add_theme_constant_override("margin_left", 12)
	t_margin.add_theme_constant_override("margin_right", 12)
	t_margin.add_theme_constant_override("margin_top", 8)
	t_margin.add_theme_constant_override("margin_bottom", 8)
	table_box.add_child(t_margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	t_margin.add_child(vb)

	# Column Header on Parchment background
	var col_hdr := HBoxContainer.new()
	col_hdr.add_theme_constant_override("separation", 0)
	vb.add_child(col_hdr)

	for pair in [["BUYER / HUB", true], ["FUEL", false], ["PAYOUT", false], ["TODAY'S PRICE", false], ["ROT RISK", false]]:
		var lbl := Label.new()
		lbl.text = String(pair[0])
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
		if bool(pair[1]):
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			lbl.custom_minimum_size = Vector2(85, 0)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col_hdr.add_child(lbl)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.55, 0.42, 0.30, 0.5))
	vb.add_child(sep)

	_hub_rows.clear()
	for hub_key in HUB_KEYS:
		var hub_data: Dictionary = Data.get_market_hub(hub_key)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 26)
		row.add_theme_constant_override("separation", 0)
		vb.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = hub_data.get("display_name", hub_key)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.18, 0.10, 0.05, 1.0))
		row.add_child(name_lbl)

		var fuel_lbl := Label.new()
		fuel_lbl.text = "₱%d" % int(hub_data.get("fuel_cost", 0))
		fuel_lbl.custom_minimum_size = Vector2(85, 0)
		fuel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fuel_lbl.add_theme_font_size_override("font_size", 13)
		fuel_lbl.add_theme_color_override("font_color", Color(0.32, 0.22, 0.14, 1.0))
		row.add_child(fuel_lbl)

		var pct_lbl := Label.new()
		pct_lbl.text = "%.0f%%" % (float(hub_data.get("price_multiplier", 1.0)) * 100.0)
		pct_lbl.custom_minimum_size = Vector2(85, 0)
		pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct_lbl.add_theme_font_size_override("font_size", 13)
		pct_lbl.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
		row.add_child(pct_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "₱---/u"
		price_lbl.custom_minimum_size = Vector2(85, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_lbl.add_theme_font_size_override("font_size", 14)
		price_lbl.add_theme_color_override("font_color", Color(0.04, 0.48, 0.12, 1.0))
		row.add_child(price_lbl)

		var rot_lbl := Label.new()
		rot_lbl.text = "0%"
		rot_lbl.custom_minimum_size = Vector2(85, 0)
		rot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rot_lbl.add_theme_font_size_override("font_size", 13)
		rot_lbl.add_theme_color_override("font_color", Color(0.08, 0.38, 0.65, 1.0))
		row.add_child(rot_lbl)

		_hub_rows.append({
			"hub_key": hub_key,
			"fuel_lbl": fuel_lbl,
			"pct_lbl": pct_lbl,
			"price_lbl": price_lbl,
			"rot_lbl": rot_lbl,
			"hub_data": hub_data
		})

func _build_trade_and_region_strip(parent: VBoxContainer) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))
	parent.add_child(box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	box.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	margin.add_child(vb)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	vb.add_child(action_row)

	_ask_bid_label = Label.new()
	_ask_bid_label.text = "Ask: ₱--/u"
	_ask_bid_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ask_bid_label.add_theme_font_size_override("font_size", 12)
	_ask_bid_label.add_theme_color_override("font_color", Color(0.18, 0.10, 0.05, 1.0))
	action_row.add_child(_ask_bid_label)

	var btn_norm = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres")
	var btn_hov  = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres")
	var btn_prs  = preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres")
	var gold_norm = preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres")
	var gold_hov  = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres")
	var gold_prs  = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres")

	_buy_25_btn = Button.new()
	_buy_25_btn.text = "Buy 25u"
	_buy_25_btn.custom_minimum_size = Vector2(105, 28)
	_buy_25_btn.tooltip_text = "Buy 25 units from your local province market into Bodega storage (raises local price)."
	_buy_25_btn.add_theme_font_size_override("font_size", 12)
	_buy_25_btn.add_theme_color_override("font_color", Color(0.98, 0.94, 0.85))
	_buy_25_btn.add_theme_stylebox_override("normal", btn_norm)
	_buy_25_btn.add_theme_stylebox_override("hover", btn_hov)
	_buy_25_btn.add_theme_stylebox_override("pressed", btn_prs)
	_buy_25_btn.pressed.connect(func(): _on_buy_wholesale(25))
	action_row.add_child(_buy_25_btn)

	_buy_50_btn = Button.new()
	_buy_50_btn.text = "Buy 50u"
	_buy_50_btn.custom_minimum_size = Vector2(105, 28)
	_buy_50_btn.tooltip_text = "Buy 50 units from your local province market into Bodega storage (raises local price)."
	_buy_50_btn.add_theme_font_size_override("font_size", 12)
	_buy_50_btn.add_theme_color_override("font_color", Color(0.98, 0.94, 0.85))
	_buy_50_btn.add_theme_stylebox_override("normal", btn_norm)
	_buy_50_btn.add_theme_stylebox_override("hover", btn_hov)
	_buy_50_btn.add_theme_stylebox_override("pressed", btn_prs)
	_buy_50_btn.pressed.connect(func(): _on_buy_wholesale(50))
	action_row.add_child(_buy_50_btn)

	_sell_local_btn = Button.new()
	_sell_local_btn.text = "Sell Stored"
	_sell_local_btn.custom_minimum_size = Vector2(128, 28)
	_sell_local_btn.tooltip_text = "Quick-sell all stored batches of this crop to your Local Biyahero immediately."
	_sell_local_btn.add_theme_font_size_override("font_size", 12)
	_sell_local_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.05))
	_sell_local_btn.add_theme_stylebox_override("normal", gold_norm)
	_sell_local_btn.add_theme_stylebox_override("hover", gold_hov)
	_sell_local_btn.add_theme_stylebox_override("pressed", gold_prs)
	_sell_local_btn.pressed.connect(_on_sell_stored_local)
	action_row.add_child(_sell_local_btn)

	var reg_row := HBoxContainer.new()
	reg_row.add_theme_constant_override("separation", 6)
	vb.add_child(reg_row)

	var reg_hdr := Label.new()
	reg_hdr.text = "5-Province Spot:"
	reg_hdr.add_theme_font_size_override("font_size", 11)
	reg_hdr.add_theme_color_override("font_color", Color(0.32, 0.22, 0.12, 1.0))
	reg_row.add_child(reg_hdr)

	_region_price_labels.clear()
	for reg_id in ["cotabato", "south_cotabato", "sarangani", "sultan_kudarat", "general_santos"]:
		var r_lbl := Label.new()
		r_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_lbl.add_theme_font_size_override("font_size", 11)
		_region_price_labels[reg_id] = r_lbl
		reg_row.add_child(r_lbl)

	_trade_feedback_label = Label.new()
	_trade_feedback_label.text = "💡 Buy low locally or haul to hubs — trades shift each province's price live! (Or use 🚚 SELL HARVEST)"
	_trade_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_feedback_label.add_theme_font_size_override("font_size", 11)
	_trade_feedback_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08, 1.0))
	vb.add_child(_trade_feedback_label)

func _make_flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.corner_radius_top_left = 5; s.corner_radius_top_right = 5
	s.corner_radius_bottom_left = 5; s.corner_radius_bottom_right = 5
	return s

func _on_crop_selected(crop_key: String) -> void:
	selected_crop = crop_key
	refresh_all()

func refresh_all() -> void:
	_update_header()
	_update_ticker()
	_update_news()
	_update_crop_view()

func _update_header() -> void:
	if not _header_label: return
	var reg: String = String(Data.get_region(Data.current_region).get("display_name", "Cotabato")).split("(")[0].strip_edges()
	_header_label.text = "📈 REGIONAL COMMODITY MARKET  •  %s, Day %d" % [reg, TimeManager.current_day]

func _fmt_price(val: float) -> String:
	if absf(val) < 100.0 and absf(val - roundf(val)) >= 0.05:
		return "%.1f" % val
	return "%d" % int(roundf(val))

func _update_ticker() -> void:
	for crop_key in CROP_KEYS:
		var btn: Button = _ticker_cards.get(crop_key, null)
		if not btn: continue

		var c_data: Dictionary = Data.get_crop(crop_key)
		var base_p: float = float(c_data.get("base_price", 10.0))
		var chg: Dictionary = MarketManager.get_price_change(crop_key)
		var curr_f: float = float(chg.get("current", base_p))
		var pct: float = float(chg.get("percent", 0.0))
		var is_up: bool = bool(chg.get("is_up", true))

		var name_lbl: Label = btn.find_child("NameLbl", true, false)
		var price_lbl: Label = btn.find_child("PriceLbl", true, false)
		var trend_lbl: Label = btn.find_child("TrendLbl", true, false)
		if price_lbl: price_lbl.text = "₱%s" % _fmt_price(curr_f)
		if trend_lbl:
			var arrow := "▲" if is_up else "▼"
			var sign := "+" if pct >= 0.0 else ""
			trend_lbl.text = "%s%s%.0f%%" % [arrow, sign, pct]

		var is_sel: bool = (crop_key == selected_crop)
		if is_sel:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
			btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
			if name_lbl: name_lbl.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
			if price_lbl: price_lbl.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
			if trend_lbl:
				trend_lbl.add_theme_color_override("font_color",
					Color(0.08, 0.45, 0.12) if is_up else Color(0.70, 0.15, 0.10))
		else:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/TopRight/BrownBox.tres"))
			btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
			if name_lbl: name_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
			if price_lbl: price_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
			if trend_lbl:
				trend_lbl.add_theme_color_override("font_color",
					Color(0.45, 1.0, 0.55) if is_up else Color(1.0, 0.50, 0.50))

func _update_news() -> void:
	if not _news_label: return
	var news: String
	if WeatherManager.incoming_disaster != "":
		var d_name := WeatherManager.incoming_disaster.replace("_", " ").to_upper()
		news = "⚠️ %s incoming! Supply lines disrupted. Market prices surging." % d_name
		_news_label.add_theme_color_override("font_color", Color(0.75, 0.15, 0.10))
	elif WeatherManager.current_climate == WeatherManager.Climate.LA_NINA:
		news = "🌊 LA NIÑA: Lowland rainstorms restricting grain yield. Palay & Corn prices climbing."
		_news_label.add_theme_color_override("font_color", Color(0.10, 0.35, 0.65))
	elif WeatherManager.current_climate == WeatherManager.Climate.EL_NINO:
		news = "🔥 EL NIÑO: Arid heat spell. Drought-hardy Coconut & Coffee commanding premium value."
		_news_label.add_theme_color_override("font_color", Color(0.72, 0.30, 0.08))
	else:
		var reg: String = String(Data.get_region(Data.current_region).get("display_name", "Cotabato")).split("(")[0].strip_edges()
		news = "☀️ STABLE HARVEST: Good seasonal weather across %s. Steady regional trade volume." % reg
		_news_label.add_theme_color_override("font_color", Color(0.12, 0.28, 0.10))
	_news_label.text = news

func _update_crop_view() -> void:
	if not _crop_title_label: return
	var crop_data: Dictionary = Data.get_crop(selected_crop)
	var icon_str: String = crop_data.get("icon", "🌱")
	var disp: String = crop_data.get("display_name", selected_crop.capitalize())
	var base_p: float = float(crop_data.get("base_price", 10))

	_crop_title_label.text = "%s %s — 7-Day Price Trend" % [icon_str, disp]
	_crop_base_label.text = "Normal Baseline: ₱%s/u" % _fmt_price(base_p)

	var chg: Dictionary = MarketManager.get_price_change(selected_crop)
	var curr_f: float = float(chg.get("current", base_p))
	var diff: float = float(chg.get("diff", 0.0))
	var pct: float = float(chg.get("percent", 0.0))
	var is_up: bool = bool(chg.get("is_up", true))

	var sign_s: String = "+" if diff >= 0.0 else "-"
	_crop_price_label.text = "₱%s/u (%s%s)" % [_fmt_price(curr_f), sign_s, _fmt_price(absf(diff))]
	_crop_price_label.add_theme_color_override("font_color",
		Color(0.06, 0.50, 0.14) if is_up else Color(0.75, 0.16, 0.12))

	var adv_s: StyleBoxFlat = _advice_badge.get_theme_stylebox("panel") as StyleBoxFlat
	if curr_f >= base_p * 1.10:
		_advice_label.text = "🟢 BULL MARKET (+%.0f%%) — High Demand! Good time to sell." % pct
		_advice_label.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
		if adv_s: adv_s.bg_color = Color(0.10, 0.22, 0.10, 0.90); adv_s.border_color = Color(0.40, 0.90, 0.45, 0.9)
	elif curr_f <= base_p * 0.90:
		_advice_label.text = "🔴 BEAR MARKET (%.0f%%) — Oversupplied. Consider storing yield." % pct
		_advice_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
		if adv_s: adv_s.bg_color = Color(0.24, 0.10, 0.10, 0.90); adv_s.border_color = Color(0.90, 0.40, 0.40, 0.9)
	else:
		_advice_label.text = "🟡 STABLE MARKET (±%.0f%%) — Fair price. Balanced supply & demand." % absf(pct)
		_advice_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
		if adv_s: adv_s.bg_color = Color(0.18, 0.18, 0.08, 0.90); adv_s.border_color = Color(0.85, 0.75, 0.35, 0.9)

	_chart.set_chart_data(selected_crop, disp, MarketManager.get_price_history(selected_crop), base_p)

	# Update Regional Hub Comparison Table using live regional logistics
	var is_night: bool = TimeManager.is_night()
	for row_data in _hub_rows:
		var hub_key: String = row_data["hub_key"]
		var hub_d: Dictionary = row_data["hub_data"]
		var logi: Dictionary = MarketManager._get_hub_logistics(hub_key)
		var rot: float = float(logi.get("road_rot", 0.0))
		var has_cold: bool = bool(logi.get("has_cold", false))
		var fuel_cost: int = int(logi.get("fuel_cost", 0))
		var arrival_fresh: float = maxf(100.0 - rot, 0.0)
		var unit_price: float = MarketManager.calculate_unit_price(selected_crop, "Grade A", arrival_fresh, hub_key)
		var unlocked: bool = BuildingManager.is_hub_unlocked(hub_key)

		var fuel_lbl: Label  = row_data["fuel_lbl"]
		var price_lbl: Label = row_data["price_lbl"]
		var rot_lbl: Label   = row_data["rot_lbl"]
		var pct_lbl: Label   = row_data["pct_lbl"]

		if fuel_cost <= 0:
			fuel_lbl.text = "Free"
		elif is_night and hub_key != "local_biyahero":
			fuel_lbl.text = "₱%d🌙" % fuel_cost
		else:
			fuel_lbl.text = "₱%d" % fuel_cost

		price_lbl.text = "₱%s/u" % _fmt_price(unit_price)
		var col := Color(0.06, 0.50, 0.14) if unit_price >= base_p else Color(0.75, 0.16, 0.12)
		price_lbl.add_theme_color_override("font_color", col)

		if has_cold or rot <= 0.01:
			rot_lbl.text = "❄️ 0%" if has_cold else "⚡ 0%"
			rot_lbl.add_theme_color_override("font_color", Color(0.12, 0.40, 0.65))
		else:
			rot_lbl.text = "⚠️ %.0f%%" % rot
			var rot_col := Color(0.75, 0.16, 0.10) if rot >= 25.0 else Color(0.65, 0.35, 0.10)
			rot_lbl.add_theme_color_override("font_color", rot_col)

		if not unlocked:
			pct_lbl.text = "Locked"
			pct_lbl.add_theme_color_override("font_color", Color(0.55, 0.40, 0.30))
		else:
			pct_lbl.text = "%.0f%%" % (float(hub_d.get("price_multiplier", 1.0)) * 100.0)
			pct_lbl.add_theme_color_override("font_color",
				Color(0.24, 0.16, 0.08) if float(hub_d.get("price_multiplier", 1.0)) >= 1.0 else Color(0.45, 0.35, 0.25))

	_update_trade_and_region_strip(crop_data, base_p)

func _update_trade_and_region_strip(crop_data: Dictionary, base_p: float) -> void:
	if not _ask_bid_label:
		return
	var ask_p: float = MarketManager.get_commodity_buy_price(selected_crop)
	var seed_p: int = MarketManager.get_seed_buy_price(selected_crop)
	var is_2x2: bool = (crop_data.get("footprint", Vector2i(1, 1)) == Vector2i(2, 2))
	var seed_word: String = "Grove" if is_2x2 else "Seed"
	var crop_stored: int = MarketManager.get_stored_units_for_crop(selected_crop)

	var total_used: int = 0
	for b in MarketManager.stored_inventory:
		total_used += int(b.get("quantity", 0))
	var cap: int = BuildingManager.total_storage_capacity
	var free_space: int = maxi(0, cap - total_used)

	_ask_bid_label.text = "Buy Ask: ₱%s/u  •  %s: ₱%d  •  In Bodega: %du (%d free)" % [
		_fmt_price(ask_p), seed_word, seed_p, crop_stored, free_space
	]

	var cost25: int = maxi(1, int(ceilf(ask_p * 25.0)))
	var cost50: int = maxi(1, int(ceilf(ask_p * 50.0)))
	_buy_25_btn.text = "Buy 25u (₱%d)" % cost25
	_buy_25_btn.disabled = (EconomyManager.cash < cost25 or free_space < 25)
	_buy_50_btn.text = "Buy 50u (₱%d)" % cost50
	_buy_50_btn.disabled = (EconomyManager.cash < cost50 or free_space < 50)

	var local_bid: float = MarketManager.calculate_unit_price(selected_crop, "Grade A", 100.0, "local_biyahero")
	_sell_local_btn.text = "Sell %du (~₱%d)" % [crop_stored, int(roundf(local_bid * crop_stored))] if crop_stored > 0 else "Sell Stored (0u)"
	_sell_local_btn.disabled = (crop_stored <= 0)

	const SHORT_NAMES := {
		"cotabato": "Cotabato",
		"south_cotabato": "S.Cot",
		"sarangani": "Sarangani",
		"sultan_kudarat": "S.Kudarat",
		"general_santos": "GenSan",
	}
	for reg_id in _region_price_labels.keys():
		var lbl: Label = _region_price_labels[reg_id]
		var reg_p: float = MarketManager.get_benchmark_price_for_region(selected_crop, reg_id)
		var is_home: bool = (reg_id == Data.current_region)
		var prefix: String = "★" if is_home else ""
		lbl.text = "%s%s: ₱%s" % [prefix, SHORT_NAMES.get(reg_id, reg_id), _fmt_price(reg_p)]
		if is_home:
			lbl.add_theme_color_override("font_color", Color(0.55, 0.25, 0.02))
		elif reg_p >= base_p * 1.12:
			lbl.add_theme_color_override("font_color", Color(0.06, 0.48, 0.14))
		elif reg_p <= base_p * 0.90:
			lbl.add_theme_color_override("font_color", Color(0.70, 0.16, 0.12))
		else:
			lbl.add_theme_color_override("font_color", Color(0.24, 0.16, 0.10))

func _on_buy_wholesale(qty: int) -> void:
	var res: Dictionary = MarketManager.buy_commodity(selected_crop, qty)
	if bool(res.get("success", false)):
		AudioManager.play_economy("spend")
		if _trade_feedback_label:
			_trade_feedback_label.text = "✅ Bought %du %s for ₱%d — local Ask/Bid nudged up!" % [
				int(res.get("quantity", qty)), selected_crop.capitalize(), int(res.get("total_cost", 0))
			]
			_trade_feedback_label.add_theme_color_override("font_color", Color(0.06, 0.48, 0.14))
		refresh_all()
	else:
		AudioManager.play_ui("error")
		var err: String = str(res.get("error", "failed"))
		if _trade_feedback_label:
			if err == "storage_full":
				_trade_feedback_label.text = "⚠️ Bodega storage full! Build/upgrade storage or sell stock first."
			elif err == "insufficient_cash":
				_trade_feedback_label.text = "⚠️ Not enough cash in treasury to buy %du!" % qty
			else:
				_trade_feedback_label.text = "⚠️ Trade could not be completed."
			_trade_feedback_label.add_theme_color_override("font_color", Color(0.75, 0.16, 0.12))

func _on_sell_stored_local() -> void:
	var total_sold: int = 0
	for i in range(MarketManager.stored_inventory.size() - 1, -1, -1):
		var batch: Dictionary = MarketManager.stored_inventory[i]
		if str(batch.get("crop", "")) == selected_crop:
			var q: int = int(batch.get("quantity", 0))
			if MarketManager.sell_stored_batch(i, "local_biyahero"):
				total_sold += q
	if total_sold > 0:
		AudioManager.play_economy("market_sell")
		if _trade_feedback_label:
			_trade_feedback_label.text = "💰 Sold %du %s locally — local supply rose & price shifted!" % [
				total_sold, selected_crop.capitalize()
			]
			_trade_feedback_label.add_theme_color_override("font_color", Color(0.06, 0.48, 0.14))
		refresh_all()
	else:
		AudioManager.play_ui("error")
		if _trade_feedback_label:
			_trade_feedback_label.text = "⚠️ No stored %s in Bodega to sell!" % selected_crop.capitalize()
			_trade_feedback_label.add_theme_color_override("font_color", Color(0.75, 0.16, 0.12))

func _on_price_updated(_c: String, _p: float) -> void:
	refresh_all()

func _on_market_region_updated(_reg: String, _c: String, _p: float) -> void:
	refresh_all()

func _on_inventory_changed() -> void:
	refresh_all()

func _on_cash_changed(_amt: int) -> void:
	if visible:
		_update_crop_view()

func _on_weather_changed(_t: float, _h: float) -> void:
	refresh_all()

func _on_day_changed(_d: int) -> void:
	refresh_all()

func refresh_prices() -> void:
	refresh_all()

func refresh_forecast() -> void:
	refresh_all()

func refresh_inventory() -> void:
	refresh_all()
