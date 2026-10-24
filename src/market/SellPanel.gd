# SellPanel.gd
# Bodega Sales Desk for dispatching harvested crops stored in Bodega.
# Streamlined 2-Step UX:
# 1. Top row: Crop selector pills (no wasted space, instant crop overview + storage count)
# 2. Destination Cards (2x2 grid): ONLY displays Destination Name, Distance, and Gas Price before selection.
# 3. Contract Details Box: Revealed once the player selects where to ship (Net payout, rate/unit, points, spoilage risk).
# 4. Action Button: Centered, prominent, fully visible without vertical clipping on 720p screens.

extends PanelContainer

const HUB_KEYS: Array[String] = [
	"local_biyahero",
	"tacurong",
	"koronadal",
	"gensan_port"
]

var selected_crop: String = ""
var selected_hub_idx: int = -1  # Unselected by default (-1). Player must select first!

# UI references
var _dim_overlay: ColorRect = null
var _header_label: Label = null
var _close_btn: Button = null

# Section 1: Crop Selector Bar
var _crop_selector_container: HBoxContainer = null
var _storage_cap_label: Label = null
var _empty_storage_banner: PanelContainer = null

# Section 2: Main Trading Area
var _trade_content_vbox: VBoxContainer = null
var _hub_cards: Array = []  # Array of {btn, name_lbl, dist_fuel_lbl, sel_badge, hub_key, hub_data}

# Section 3: Selected Contract Details
var _contract_box: PanelContainer = null
var _contract_title_lbl: Label = null
var _payout_lbl: Label = null
var _tradeoff_lbl: Label = null

# Section 4: Action Button & Status
var _sell_action_btn: Button = null
var _status_msg_label: Label = null

func _ready() -> void:
	for child in get_children():
		child.queue_free()

	_apply_panel_style()
	_create_dim_overlay()
	_build_ui()

	MarketManager.inventory_changed.connect(_on_inventory_changed)
	MarketManager.price_updated.connect(func(_c, _p): _refresh_view())
	EconomyManager.cash_changed.connect(func(_a): _refresh_view())
	TimeManager.period_changed.connect(func(_p, _n): _refresh_view())
	TimeManager.hour_changed.connect(func(_h): _refresh_view())

	_auto_select_crop()
	_refresh_view()

func _apply_panel_style() -> void:
	custom_minimum_size = Vector2(860, 490)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left   = -430.0
	offset_top    = -245.0
	offset_right  =  430.0
	offset_bottom =  245.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical   = Control.GROW_DIRECTION_BOTH

	var ps = preload("res://assets/sprites/hud/Big-Rectangle-Box/BigPlainBox.tres")
	add_theme_stylebox_override("panel", ps)

func _create_dim_overlay() -> void:
	_dim_overlay = ColorRect.new()
	_dim_overlay.name = "SellDimOverlay"
	_dim_overlay.color = Color(0.03, 0.04, 0.03, 0.75)
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
			selected_hub_idx = -1  # Must select shipping destination first
			if _status_msg_label:
				_status_msg_label.text = ""
			_auto_select_crop()
			_refresh_view()

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

	# --- Header Row ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	_header_label = Label.new()
	_header_label.text = "🚚 BODEGA SALES DESK"
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
	header.add_child(_header_label)

	var sub_lbl := Label.new()
	sub_lbl.text = "— Dispatch produce to regional buyers"
	sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.40, 0.28, 0.16, 1.0))
	header.add_child(sub_lbl)

	_storage_cap_label = Label.new()
	_storage_cap_label.text = "📦 Storage: 0/200"
	_storage_cap_label.add_theme_font_size_override("font_size", 13)
	_storage_cap_label.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08, 1.0))
	header.add_child(_storage_cap_label)

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

	# --- 1. Top Section: Crop Selector Bar ---
	var crop_row := HBoxContainer.new()
	crop_row.add_theme_constant_override("separation", 10)
	root.add_child(crop_row)

	var crop_lbl := Label.new()
	crop_lbl.text = "HARVEST IN BODEGA:"
	crop_lbl.add_theme_font_size_override("font_size", 12)
	crop_lbl.add_theme_color_override("font_color", Color(0.35, 0.22, 0.12, 1.0))
	crop_row.add_child(crop_lbl)

	_crop_selector_container = HBoxContainer.new()
	_crop_selector_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crop_selector_container.add_theme_constant_override("separation", 8)
	crop_row.add_child(_crop_selector_container)

	# Empty Storage Banner (Samplebox - clean parchment with brown border)
	_empty_storage_banner = PanelContainer.new()
	_empty_storage_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_storage_banner.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_empty_storage_banner.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))
	root.add_child(_empty_storage_banner)

	var eb_margin := MarginContainer.new()
	eb_margin.add_theme_constant_override("margin_left", 24)
	eb_margin.add_theme_constant_override("margin_right", 24)
	eb_margin.add_theme_constant_override("margin_top", 32)
	eb_margin.add_theme_constant_override("margin_bottom", 32)
	_empty_storage_banner.add_child(eb_margin)

	var eb_inner := VBoxContainer.new()
	eb_inner.add_theme_constant_override("separation", 10)
	eb_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	eb_margin.add_child(eb_inner)

	var eb_lbl := Label.new()
	eb_lbl.text = "🧺 Bodega Storage is Empty"
	eb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eb_lbl.add_theme_font_size_override("font_size", 17)
	eb_lbl.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08, 1.0))
	eb_inner.add_child(eb_lbl)

	var eb_sub := Label.new()
	eb_sub.text = "Harvest ripe crops on your farm to store yield in your Grain Silos, then return here to sell!"
	eb_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eb_sub.add_theme_font_size_override("font_size", 13)
	eb_sub.add_theme_color_override("font_color", Color(0.38, 0.28, 0.18, 1.0))
	eb_inner.add_child(eb_sub)

	# --- 2. Main Trading Area (Split 2-Column Trade Desk) ---
	_trade_content_vbox = VBoxContainer.new()
	_trade_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_content_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_trade_content_vbox.add_theme_constant_override("separation", 6)
	root.add_child(_trade_content_vbox)

	var split_hbox := HBoxContainer.new()
	split_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 14)
	_trade_content_vbox.add_child(split_hbox)

	# --- Left Column: Choose Shipping Buyer (4 Cards) ---
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 6)
	split_hbox.add_child(left_col)

	var dest_hdr := Label.new()
	dest_hdr.text = "📍 1. CHOOSE SHIPPING BUYER:"
	dest_hdr.add_theme_font_size_override("font_size", 13)
	dest_hdr.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	left_col.add_child(dest_hdr)

	var buyers_vbox := VBoxContainer.new()
	buyers_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buyers_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	buyers_vbox.add_theme_constant_override("separation", 6)
	left_col.add_child(buyers_vbox)

	_hub_cards.clear()
	for i in range(HUB_KEYS.size()):
		var card_data := _build_hub_card(buyers_vbox, HUB_KEYS[i], i)
		_hub_cards.append(card_data)

	# --- Right Column: Dispatch Invoice & Action ---
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(340, 0)
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	split_hbox.add_child(right_col)

	var invoice_hdr := Label.new()
	invoice_hdr.text = "📋 2. DISPATCH INVOICE:"
	invoice_hdr.add_theme_font_size_override("font_size", 13)
	invoice_hdr.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	right_col.add_child(invoice_hdr)

	_contract_box = PanelContainer.new()
	_contract_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contract_box.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	if ResourceLoader.exists("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"):
		_contract_box.add_theme_stylebox_override("panel", load("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"))
	else:
		_contract_box.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/TopRight/BrownBox.tres"))
	right_col.add_child(_contract_box)

	var cb_margin := MarginContainer.new()
	cb_margin.add_theme_constant_override("margin_left", 14)
	cb_margin.add_theme_constant_override("margin_right", 14)
	cb_margin.add_theme_constant_override("margin_top", 10)
	cb_margin.add_theme_constant_override("margin_bottom", 10)
	_contract_box.add_child(cb_margin)

	var cb_inner := VBoxContainer.new()
	cb_inner.add_theme_constant_override("separation", 6)
	cb_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cb_margin.add_child(cb_inner)

	_contract_title_lbl = Label.new()
	_contract_title_lbl.text = "📋 Shipping Invoice"
	_contract_title_lbl.add_theme_font_size_override("font_size", 14)
	_contract_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	cb_inner.add_child(_contract_title_lbl)

	var inv_sep := HSeparator.new()
	inv_sep.add_theme_color_override("separator_color", Color(0.6, 0.5, 0.35, 0.5))
	cb_inner.add_child(inv_sep)

	_tradeoff_lbl = Label.new()
	_tradeoff_lbl.text = "👉 Select a destination buyer on the left to review transit logistics and earnings."
	_tradeoff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tradeoff_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tradeoff_lbl.add_theme_font_size_override("font_size", 12)
	_tradeoff_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.90))
	cb_inner.add_child(_tradeoff_lbl)

	var payout_sep := HSeparator.new()
	payout_sep.add_theme_color_override("separator_color", Color(0.6, 0.5, 0.35, 0.5))
	cb_inner.add_child(payout_sep)

	_payout_lbl = Label.new()
	_payout_lbl.text = ""
	_payout_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_payout_lbl.add_theme_font_size_override("font_size", 16)
	_payout_lbl.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
	cb_inner.add_child(_payout_lbl)

	# Action Button & Feedback
	_sell_action_btn = Button.new()
	_sell_action_btn.text = "👈 CHOOSE BUYER ON LEFT"
	_sell_action_btn.custom_minimum_size = Vector2(0, 42)
	_sell_action_btn.add_theme_font_size_override("font_size", 13)
	_sell_action_btn.disabled = true
	_sell_action_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sell_action_btn.pressed.connect(_on_sell_action_pressed)
	cb_inner.add_child(_sell_action_btn)

	_status_msg_label = Label.new()
	_status_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_msg_label.add_theme_font_size_override("font_size", 11)
	_status_msg_label.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
	cb_inner.add_child(_status_msg_label)

func _build_hub_card(parent: Control, hub_key: String, hub_idx: int) -> Dictionary:
	var hub_data: Dictionary = Data.get_market_hub(hub_key)
	var h_name: String = hub_data.get("display_name", hub_key)
	var short_name: String = h_name.split("(")[0].strip_edges()

	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 58)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(func():
		selected_hub_idx = hub_idx
		if _status_msg_label:
			_status_msg_label.text = ""
		_refresh_view()
	)
	parent.add_child(btn)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	btn.add_child(margin)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top_row)

	var name_lbl := Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = short_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	top_row.add_child(name_lbl)

	var sel_badge := Label.new()
	sel_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_badge.text = ""
	sel_badge.add_theme_font_size_override("font_size", 12)
	sel_badge.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
	top_row.add_child(sel_badge)

	var dist_fuel_lbl := Label.new()
	dist_fuel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dist_fuel_lbl.text = ""
	dist_fuel_lbl.add_theme_font_size_override("font_size", 12)
	dist_fuel_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
	vb.add_child(dist_fuel_lbl)

	return {
		"btn": btn,
		"hub_key": hub_key,
		"name_lbl": name_lbl,
		"sel_badge": sel_badge,
		"dist_fuel_lbl": dist_fuel_lbl,
		"hub_data": hub_data
	}

func _make_flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	return s

func _auto_select_crop() -> void:
	var summary: Array = MarketManager.get_stored_crop_summary()
	if not summary.is_empty():
		var exists: bool = false
		for item in summary:
			if item.get("crop", "") == selected_crop:
				exists = true
				break
		if not exists:
			selected_crop = summary[0].get("crop", "")
	else:
		selected_crop = ""

func _on_crop_clicked(c: String) -> void:
	selected_crop = c
	if _status_msg_label:
		_status_msg_label.text = ""
	_refresh_view()

func _refresh_view() -> void:
	if not _crop_selector_container:
		return
	var st_status: Dictionary = BuildingManager.get_storage_status()
	if _storage_cap_label:
		_storage_cap_label.text = "📦 Storage: %d/%d" % [st_status.used, st_status.capacity]

	# 1. Populate horizontal crop selector bar
	for child in _crop_selector_container.get_children():
		child.queue_free()

	var summary: Array = MarketManager.get_stored_crop_summary()
	if summary.is_empty():
		_empty_storage_banner.visible = true
		_trade_content_vbox.visible = false
		selected_crop = ""
		selected_hub_idx = -1
		return

	_empty_storage_banner.visible = false
	_trade_content_vbox.visible = true

	if selected_crop == "":
		selected_crop = summary[0].get("crop", "")

	for item in summary:
		var c_name: String = item.get("crop", "")
		var qty: int       = int(item.get("total_quantity", 0))
		var avg_f: float   = float(item.get("avg_freshness", 100.0))
		var is_sel: bool   = (c_name == selected_crop)

		var crop_d: Dictionary = Data.get_crop(c_name)
		var icon_str: String = crop_d.get("icon", "🌱")
		var disp: String     = crop_d.get("display_name", c_name.capitalize()).split("(")[0].strip_edges()

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 32)
		btn.pressed.connect(func(): _on_crop_clicked(c_name))

		var bg_col := Color(0.16, 0.25, 0.16, 0.98) if is_sel else Color(0.09, 0.13, 0.09, 0.85)
		var bd_col := Color(1.0, 0.85, 0.35, 1.0) if is_sel else Color(0.28, 0.38, 0.26, 0.6)
		var bs := _make_flat_style(bg_col, bd_col)
		bs.border_width_left = 2 if is_sel else 1
		bs.border_width_top = 2 if is_sel else 1
		bs.border_width_right = 2 if is_sel else 1
		bs.border_width_bottom = 2 if is_sel else 1
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_stylebox_override("hover",  bs)

		btn.text = "%s %s: %d (%d%%)" % [icon_str, disp, qty, int(round(avg_f))]
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80) if is_sel else Color(0.85, 0.90, 0.85))

		_crop_selector_container.add_child(btn)

	if selected_crop == "":
		return

	var crop_data: Dictionary = Data.get_crop(selected_crop)
	var disp_name: String = crop_data.get("display_name", selected_crop.capitalize())
	var total_stored_qty: int = MarketManager.get_stored_units_for_crop(selected_crop)
	var is_night: bool = TimeManager.is_night()

	# 2. Update 4 Destination Cards (Clean: Name, Distance & Gas Price Only)
	for i in range(_hub_cards.size()):
		var card_d: Dictionary = _hub_cards[i]
		var btn: Button        = card_d["btn"]
		var sel_badge: Label   = card_d["sel_badge"]
		var dist_fuel_lbl: Label= card_d["dist_fuel_lbl"]
		var name_lbl: Label    = card_d["name_lbl"]
		var h_key: String      = card_d["hub_key"]
		var h_dict: Dictionary = Data.get_market_hub(h_key)
		var is_available: bool = Data.is_hub_available(h_key)
		var is_sel: bool       = (i == selected_hub_idx)

		if not is_available:
			btn.disabled = true
			if is_sel:
				selected_hub_idx = -1
				is_sel = false
			var req_b: String = str(Data.MARKET_HUBS.get(h_key, {}).get("requires_building", ""))
			var req_name: String = str(Data.get_building(req_b).get("display_name", req_b.capitalize()))
			dist_fuel_lbl.text = "🔒 Requires: %s (Agri-Shop → Trade)" % req_name
			sel_badge.text = "🔒 Locked"
			sel_badge.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
			btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
			name_lbl.add_theme_color_override("font_color", Color(0.50, 0.45, 0.40))
			dist_fuel_lbl.add_theme_color_override("font_color", Color(0.60, 0.30, 0.25))
			continue

		btn.disabled = false
		var km: int = int(h_dict.get("distance_km", 0))
		var base_fuel: int = int(h_dict.get("fuel_cost", 0))
		var actual_fuel: int = base_fuel + (25 if is_night and h_key != "local_biyahero" else 0)

		# Distance, fuel, and rate perk tag
		var fuel_tag := "₱%d Fuel" % actual_fuel if actual_fuel > 0 else "Free Fuel"
		if is_night and h_key != "local_biyahero":
			fuel_tag += " (+₱25 🌙)"
		
		var rate_tag := ""
		if h_key == "local_biyahero":
			var rate_pct: int = int(round(float(h_dict.get("price_multiplier", 0.72)) * 100.0))
			rate_tag = "%d%% Instant Rate" % rate_pct
		else:
			var mult: float = float(h_dict.get("price_multiplier", 1.0))
			var boost_tag: String = " ⭐" if h_dict.get("boosted", false) else ""
			rate_tag = "%.2fx Rate%s" % [mult, boost_tag]

		dist_fuel_lbl.text = "%d km  •  %s  •  %s" % [km, fuel_tag, rate_tag]
		sel_badge.text = "✔ Selected" if is_sel else ""

		# Styling with authentic pixel art buttons & high-contrast deep text
		if is_sel:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
			btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
			name_lbl.add_theme_color_override("font_color", Color(0.20, 0.10, 0.04))
			dist_fuel_lbl.add_theme_color_override("font_color", Color(0.32, 0.18, 0.08))
			sel_badge.add_theme_color_override("font_color", Color(0.06, 0.40, 0.10))
		else:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
			btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
			name_lbl.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08))
			dist_fuel_lbl.add_theme_color_override("font_color", Color(0.36, 0.24, 0.14))
			sel_badge.add_theme_color_override("font_color", Color(0.25, 0.45, 0.20))

	# 3. Contract Box & Action Button:
	# If NO destination is selected yet (selected_hub_idx == -1), guide the player and disable button!
	if selected_hub_idx < 0 or selected_hub_idx >= HUB_KEYS.size():
		_contract_title_lbl.text = "📋 Shipping Invoice"
		_payout_lbl.text = ""
		_tradeoff_lbl.text = "👉 Select a shipping buyer on the left to review transit logistics, transport fees, and net profits."
		_tradeoff_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.90))

		_sell_action_btn.disabled = true
		_sell_action_btn.text = "👈 CHOOSE BUYER ON LEFT"
		_sell_action_btn.remove_theme_stylebox_override("normal")
		_sell_action_btn.remove_theme_stylebox_override("hover")
		_sell_action_btn.remove_theme_stylebox_override("pressed")
		_sell_action_btn.remove_theme_stylebox_override("disabled")
		_sell_action_btn.remove_theme_color_override("font_disabled_color")
		_sell_action_btn.remove_theme_color_override("font_color")
		return

	# If a destination IS selected, reveal all contract information!
	var current_hub_key: String = HUB_KEYS[selected_hub_idx]
	var current_preview: Dictionary = MarketManager.preview_crop_sale(selected_crop, current_hub_key)
	var h_data: Dictionary = Data.get_market_hub(current_hub_key)
	var h_name: String = h_data.get("display_name", current_hub_key)
	var short_name: String = h_name.split("(")[0].strip_edges()
	var net_val: int = int(current_preview.get("net", 0))
	var gross_val: int = int(current_preview.get("gross", 0))
	var fuel_val: int = int(current_preview.get("fuel", 0))
	var rot_val: float = float(current_preview.get("road_rot", 0.0))
	var has_cold: bool = bool(current_preview.get("has_cold", false))
	var pts_val: int = int(current_preview.get("points", 0))
	var per_unit: float = float(net_val) / maxf(float(total_stored_qty), 1.0)
	var can_afford: bool = bool(current_preview.get("can_afford_fuel", true))
	var is_loss_val: bool = bool(current_preview.get("is_loss", false))
	var km_dest: int = int(h_data.get("distance_km", 0))

	_contract_title_lbl.text = "🚚 %s (%d km)" % [short_name, km_dest]

	if gross_val == 0:
		_payout_lbl.text = "💀 Produce Ruined (₱0)"
		_payout_lbl.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))
	elif is_loss_val:
		_payout_lbl.text = "-₱%s NET  (🏆 +%s Pts)" % [Utils.format_number(abs(net_val)), Utils.format_number(pts_val)]
		_payout_lbl.add_theme_color_override("font_color", Color(1.0, 0.50, 0.40))
	else:
		_payout_lbl.text = "+₱%s NET  (₱%.1f/u)  •  🏆 +%s Pts" % [
			Utils.format_number(net_val),
			per_unit,
			Utils.format_number(pts_val)
		]
		_payout_lbl.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))

	var rot_info := ""
	if has_cold:
		rot_info = "❄️ 0% (Cold Chain)"
	elif Data.is_processed_good(selected_crop):
		rot_info = "✨ 0% (Shelf-Stable)"
	elif current_hub_key == "local_biyahero":
		rot_info = "⚡ 0% (Instant Pickup)"
	else:
		rot_info = "%.0f%% Spoilage" % rot_val
		if is_night:
			rot_info += " (🌙 -40% Cool)"

	var streak_tag := ("  •  🔥 %.1fx Streak" % LeaderboardManager.get_combo_multiplier()) if LeaderboardManager.current_combo > 0 else ""
	_tradeoff_lbl.text = "🌾 Produce: %d units %s\n💰 Gross Value: ₱%s\n⛽ Fuel Expense: -₱%s\n📦 Spoilage Risk: %s%s" % [
		total_stored_qty, disp_name,
		Utils.format_number(gross_val),
		Utils.format_number(fuel_val),
		rot_info,
		streak_tag
	]

	# 4. Action Button Styling & State
	if not can_afford:
		_sell_action_btn.disabled = true
		_sell_action_btn.icon = null
		_sell_action_btn.text = "⚠️ NEED ₱%d CASH FOR FUEL" % fuel_val
		_sell_action_btn.remove_theme_stylebox_override("normal")
		_sell_action_btn.remove_theme_stylebox_override("hover")
		_sell_action_btn.remove_theme_stylebox_override("pressed")
		_sell_action_btn.remove_theme_stylebox_override("disabled")
		_sell_action_btn.remove_theme_color_override("font_disabled_color")
		_sell_action_btn.remove_theme_color_override("font_color")
	elif gross_val == 0:
		_sell_action_btn.disabled = true
		_sell_action_btn.icon = null
		_sell_action_btn.text = "💀 PRODUCE IS 100% RUINED"
		_sell_action_btn.remove_theme_stylebox_override("normal")
		_sell_action_btn.remove_theme_stylebox_override("hover")
		_sell_action_btn.remove_theme_stylebox_override("pressed")
		_sell_action_btn.remove_theme_stylebox_override("disabled")
		_sell_action_btn.remove_theme_color_override("font_disabled_color")
		_sell_action_btn.remove_theme_color_override("font_color")
	elif is_loss_val:
		_sell_action_btn.disabled = false
		_sell_action_btn.icon = preload("res://assets/icons/HUD/Truck.png")
		_sell_action_btn.text = " ⚠️ CONFIRM SALE AT A LOSS (-₱%s)" % Utils.format_number(abs(net_val))
		_sell_action_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
		_sell_action_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
		_sell_action_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
		_sell_action_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
	else:
		_sell_action_btn.disabled = false
		_sell_action_btn.icon = preload("res://assets/icons/HUD/Truck.png")
		_sell_action_btn.text = " CONFIRM & DISPATCH SHIPMENT"
		_sell_action_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
		_sell_action_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
		_sell_action_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
		_sell_action_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
		_sell_action_btn.add_theme_color_override("font_hover_color", Color(0.10, 0.06, 0.02))

func _on_sell_action_pressed() -> void:
	if selected_crop == "" or selected_hub_idx < 0 or selected_hub_idx >= HUB_KEYS.size():
		return

	var crop_sold := selected_crop
	var hub_id: String = HUB_KEYS[selected_hub_idx]
	var res: Dictionary = MarketManager.sell_all_of_crop(selected_crop, hub_id)

	if bool(res.get("success", false)):
		var q: int = int(res.get("quantity", 0))
		var net: int = int(res.get("net", 0))
		var pts: int = int(res.get("points", 0))
		var h_name: String = String(res.get("hub_name", hub_id))
		_status_msg_label.text = "✅ Dispatched %d %s to %s! +₱%s Net Profit • 🏆 +%s Pts!" % [
			q, crop_sold.capitalize(), h_name, Utils.format_number(net), Utils.format_number(pts)
		]
		_status_msg_label.add_theme_color_override("font_color", Color(0.40, 1.0, 0.50))
		selected_hub_idx = -1  # Reset so player selects again for next sale
		_auto_select_crop()
		_refresh_view()
	else:
		var err: String = String(res.get("error", "failed"))
		if err == "insufficient_fuel":
			_status_msg_label.text = "⚠️ Not enough cash in treasury to pay fuel fee!"
		else:
			_status_msg_label.text = "Sale failed!"
		_status_msg_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func _on_inventory_changed() -> void:
	_auto_select_crop()
	_refresh_view()
