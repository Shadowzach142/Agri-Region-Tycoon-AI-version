# scratch/build_hotbar.py
import os

code = """# PlantHotbar.gd
# Tiered Category Hotbar System docked at HUD bottom-center.
#
# Primary Hotbar:
#   - 3 Category slots: 🌱 SEEDS [1], ⛏️ TOOLS [2], 🧪 IPM [3]
#   - Each slot displays the currently active selection with pixel-art small-box frames.
#   - Clicking a category slot arms that item and toggles its vertical flyout drawer!
#
# Vertical Flyout Drawers:
#   - Seeds: All 7 regional crops (🌾 Palay, 🌽 Corn, 🎋 Cane, 🍍 Pineapple, ☕ Coffee, 🍌 Banana 2×2, 🥥 Coconut 2×2)
#   - Tools: ⛏️ Plow & Hoe, 💧 Watering Can, 🧺 Harvest Basket, 🪓 Clear Obstacle
#   - Treatments: 🧪 Chemical Spray (₱30), 🦆 Biological IPM (₱45)
#   - Selecting an item updates the primary hotbar slot and arms the worker!
#
# Floating Hover Card:
#   - Displays vital stats, pixel-art stage previews, and Mindanao regional agronomic buffs/debuffs.

class_name PlantHotbar
extends Control

signal tool_selected(tool_id: String)
signal crop_selected(crop_key: String)

# Static active tool state: "plow", crop key, "water", "harvest", "clear", "spray_chemical", "spray_biological"
static var selected_tool: String = "plow"

static func get_selected_tool() -> String:
	return selected_tool

static func set_selected_tool(tool_id: String) -> void:
	selected_tool = tool_id

static func get_selected_crop() -> String:
	if selected_tool in CROP_KEYS:
		return selected_tool
	return "palay"

static func set_selected_crop(crop_name: String) -> void:
	selected_tool = crop_name

const CROP_KEYS: Array[String] = [
	"palay",
	"yellow_corn",
	"sugarcane",
	"pineapple",
	"arabica_coffee",
	"banana",
	"coconut"
]

const CROP_ICONS: Dictionary = {
	"palay": "res://assets/sprites/Field/Crops/Rice/RICE-P3.png",
	"yellow_corn": "res://assets/sprites/Field/Crops/Corn/CORN-P3.png",
	"sugarcane": "res://assets/sprites/Field/Crops/Sugarcane/SUGARCANE-P3.png",
	"pineapple": "res://assets/sprites/Field/Crops/Pineapple/PINEAPPLE-P3.png",
	"arabica_coffee": "res://assets/sprites/Field/Crops/Coffee/COFFEE-P3.png",
	"banana": "res://assets/sprites/Field/Crops/Banana/BANANA-P4.png",
	"coconut": "res://assets/sprites/Field/Crops/Coconut/COCONUT-P3.png"
}

const CATEGORY_DATA: Dictionary = {
	"seeds": {
		"id": "seeds",
		"title": "SEEDS",
		"icon": "🌱",
		"key_num": 1,
		"default_item": "palay",
		"items": [
			{"id": "palay", "name": "Palay (Rice)", "cost": 25, "icon": "🌾", "fp": Vector2i(1, 1)},
			{"id": "yellow_corn", "name": "Yellow Corn", "cost": 30, "icon": "🌽", "fp": Vector2i(1, 1)},
			{"id": "sugarcane", "name": "Sugar Cane", "cost": 30, "icon": "🎋", "fp": Vector2i(1, 1)},
			{"id": "pineapple", "name": "Pineapple", "cost": 40, "icon": "🍍", "fp": Vector2i(1, 1)},
			{"id": "arabica_coffee", "name": "Arabica Coffee", "cost": 50, "icon": "☕", "fp": Vector2i(1, 1)},
			{"id": "banana", "name": "Cavendish Banana", "cost": 140, "icon": "🍌", "fp": Vector2i(2, 2)},
			{"id": "coconut", "name": "Tall Coconut Palm", "cost": 160, "icon": "🥥", "fp": Vector2i(2, 2)}
		]
	},
	"tools": {
		"id": "tools",
		"title": "TOOLS",
		"icon": "⛏️",
		"key_num": 2,
		"default_item": "plow",
		"items": [
			{"id": "plow", "name": "Plow & Hoe", "cost": 0, "icon": "⛏️", "desc": "Till soil ready for seeds"},
			{"id": "water", "name": "Watering Can", "cost": 0, "icon": "💧", "desc": "Water soil (+25% moisture)"},
			{"id": "harvest", "name": "Harvest Basket", "cost": 0, "icon": "🧺", "desc": "Gather ripe or salvage crops"},
			{"id": "clear", "name": "Clear Obstacle", "cost": 50, "icon": "🪓", "desc": "Remove trees, trunks, rocks"}
		]
	},
	"treatments": {
		"id": "treatments",
		"title": "IPM",
		"icon": "🧪",
		"key_num": 3,
		"default_item": "spray_chemical",
		"items": [
			{"id": "spray_chemical", "name": "Chemical Spray", "cost": 30, "icon": "🧪", "desc": "Rapid pest elimination"},
			{"id": "spray_biological", "name": "Biological IPM", "cost": 45, "icon": "🦆", "desc": "Eco-friendly pest shield"}
		]
	}
}

const HOVER_DELAY: float = 0.8

# State
var active_category: String = "tools"
var selected_category_items: Dictionary = {
	"seeds": "palay",
	"tools": "plow",
	"treatments": "spray_chemical"
}
var open_flyout_category: String = ""

# UI Nodes
var tray_panel: PanelContainer = null
var category_slots: Dictionary = {} # cat_id -> Button
var category_labels: Dictionary = {} # cat_id -> Label
var category_sublabels: Dictionary = {} # cat_id -> Label
var category_icons: Dictionary = {} # cat_id -> Control
var flyout_drawer: PanelContainer = null
var flyout_header_label: Label = null
var flyout_items_vbox: VBoxContainer = null
var flyout_item_buttons: Dictionary = {} # item_id -> Button

var hover_card: PanelContainer = null
var hover_timer: Timer = null
var hovered_item_id: String = ""

var card_icon: Label = null
var card_texture: TextureRect = null
var card_title: Label = null
var card_type: Label = null
var card_stats: Label = null
var card_desc: Label = null
var card_region_title: Label = null
var card_buffs: Label = null
var card_debuffs: Label = null

var worker_header_label: Label = null
var close_btn: Button = null

var tex_dark_box: Texture2D = null
var tex_light_box: Texture2D = null
var _texture_cache: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(480, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Load HUD box textures
	if ResourceLoader.exists("res://assets/sprites/hud/Small-Rectangular-Box/small-dark-box.png"):
		tex_dark_box = load("res://assets/sprites/hud/Small-Rectangular-Box/small-dark-box.png")
	if ResourceLoader.exists("res://assets/sprites/hud/Small-Rectangular-Box/small-ligh-box.png"):
		tex_light_box = load("res://assets/sprites/hud/Small-Rectangular-Box/small-ligh-box.png")

	_setup_ui()
	_update_category_slots_display()
	_highlight_active_selection()

	if EconomyManager.has_signal("cash_changed"):
		EconomyManager.cash_changed.connect(func(_c): _update_affordability())

	if TaskManager.has_signal("selection_changed"):
		TaskManager.selection_changed.connect(_on_worker_selection_changed)

	_update_visibility_from_selection()

var is_tray_open: bool:
	get:
		return visible

func _on_worker_selection_changed(_selected_workers: Array) -> void:
	_update_visibility_from_selection()

func _update_visibility_from_selection() -> void:
	var selected: Array = TaskManager.get_selected_farmers()
	var has_selection: bool = (selected.size() > 0)
	visible = has_selection
	if has_selection:
		_update_worker_header(selected)
		_highlight_active_selection()
		_update_affordability()
	else:
		_close_flyout()
		if hover_card and hover_card.visible:
			hover_card.visible = false
		if hover_timer and not hover_timer.is_stopped():
			hover_timer.stop()

func _update_worker_header(selected: Array) -> void:
	if not worker_header_label:
		return
	if selected.is_empty():
		worker_header_label.text = "👨‍🌾 Worker Tools & Crops"
		return
	if selected.size() == 1:
		var w = selected[0]
		var w_name: String = "Worker 1"
		if is_instance_valid(w):
			if "worker_name" in w:
				w_name = str(w.worker_name)
			elif "worker_id" in w:
				w_name = "Worker %d" % int(w.worker_id)
			elif w.has_method("get") and w.get("name"):
				w_name = str(w.name)
		worker_header_label.text = "👨‍🌾 %s Ready • Click Slot to Choose & Click/Drag Field" % w_name
	else:
		worker_header_label.text = "👨‍🌾 Squad Selected (%d Workers) • Click Slot to Choose & Click/Drag Field" % selected.size()

func open_tray() -> void:
	visible = true
	var selected: Array = TaskManager.get_selected_farmers()
	if selected.size() > 0:
		_update_worker_header(selected)

func close_tray() -> void:
	_close_flyout()
	TaskManager.deselect_all_farmers()

func _setup_ui() -> void:
	# Hover timer
	hover_timer = Timer.new()
	hover_timer.one_shot = true
	hover_timer.wait_time = HOVER_DELAY
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)

	# Main vertical container (Hover Card top, Flyout middle, Primary Dock bottom)
	var vbox := VBoxContainer.new()
	vbox.name = "HotbarVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 6)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	# 1. Floating Hover Info Card
	_setup_hover_card(vbox)

	# 2. Vertical Flyout Drawer (pops open above categories)
	_setup_flyout_drawer(vbox)

	# 3. Docked Primary Hotbar Panel
	_setup_primary_dock(vbox)

func _setup_primary_dock(parent: VBoxContainer) -> void:
	tray_panel = PanelContainer.new()
	tray_panel.name = "PrimaryHotbarPanel"
	tray_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var tray_style := StyleBoxFlat.new()
	tray_style.bg_color = Color(0.18, 0.12, 0.08, 0.98)
	tray_style.border_width_left = 2
	tray_style.border_width_top = 2
	tray_style.border_width_right = 2
	tray_style.border_width_bottom = 2
	tray_style.border_color = Color(0.85, 0.68, 0.32, 0.95) # Gold
	tray_style.corner_radius_top_left = 6
	tray_style.corner_radius_top_right = 6
	tray_style.corner_radius_bottom_left = 6
	tray_style.corner_radius_bottom_right = 6
	tray_style.shadow_size = 6
	tray_style.shadow_color = Color(0, 0, 0, 0.6)
	tray_style.content_margin_left = 10
	tray_style.content_margin_right = 10
	tray_style.content_margin_top = 6
	tray_style.content_margin_bottom = 6
	tray_panel.add_theme_stylebox_override("panel", tray_style)
	parent.add_child(tray_panel)

	var tray_vbox := VBoxContainer.new()
	tray_vbox.name = "TrayVBox"
	tray_vbox.add_theme_constant_override("separation", 4)
	tray_panel.add_child(tray_vbox)

	# Header row (Worker name + close button)
	var header_hbox := HBoxContainer.new()
	header_hbox.name = "HeaderHBox"
	header_hbox.add_theme_constant_override("separation", 6)
	tray_vbox.add_child(header_hbox)

	worker_header_label = Label.new()
	worker_header_label.name = "WorkerHeaderLabel"
	worker_header_label.text = "👨‍🌾 Worker Command Hotbar"
	worker_header_label.add_theme_font_size_override("font_size", 10)
	worker_header_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	worker_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(worker_header_label)

	close_btn = Button.new()
	close_btn.name = "CloseWorkerHotbarButton"
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(22, 18)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.tooltip_text = "Deselect worker (Esc)"
	var s_close := StyleBoxFlat.new()
	s_close.bg_color = Color(0.35, 0.12, 0.12, 0.9)
	s_close.border_color = Color(0.85, 0.45, 0.45, 0.9)
	s_close.border_width_left = 1
	s_close.border_width_top = 1
	s_close.border_width_right = 1
	s_close.border_width_bottom = 1
	s_close.corner_radius_top_left = 3
	s_close.corner_radius_top_right = 3
	s_close.corner_radius_bottom_left = 3
	s_close.corner_radius_bottom_right = 3
	close_btn.add_theme_stylebox_override("normal", s_close)
	var s_close_hover := s_close.duplicate() as StyleBoxFlat
	s_close_hover.bg_color = Color(0.60, 0.15, 0.15, 1.0)
	close_btn.add_theme_stylebox_override("hover", s_close_hover)
	close_btn.pressed.connect(func(): close_tray())
	header_hbox.add_child(close_btn)

	# Category Slots Row
	var slots_hbox := HBoxContainer.new()
	slots_hbox.name = "CategorySlotsHBox"
	slots_hbox.add_theme_constant_override("separation", 12)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tray_vbox.add_child(slots_hbox)

	for cat_id in ["seeds", "tools", "treatments"]:
		var c_data: Dictionary = CATEGORY_DATA[cat_id]
		var slot_btn := _create_category_slot_button(c_data)
		slots_hbox.add_child(slot_btn)
		category_slots[cat_id] = slot_btn

func _create_stylebox_from_texture(tex: Texture2D, is_active: bool = false, is_hover: bool = false) -> StyleBox:
	if tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.texture_margin_left = 6
		sbt.texture_margin_right = 6
		sbt.texture_margin_top = 6
		sbt.texture_margin_bottom = 6
		sbt.content_margin_left = 4
		sbt.content_margin_right = 4
		sbt.content_margin_top = 4
		sbt.content_margin_bottom = 4
		if is_active:
			sbt.modulate_color = Color(1.25, 1.15, 0.85)
		elif is_hover:
			sbt.modulate_color = Color(1.1, 1.05, 1.0)
		return sbt
	else:
		var sbf := StyleBoxFlat.new()
		sbf.bg_color = Color(0.32, 0.22, 0.12, 1.0) if is_active else Color(0.14, 0.09, 0.05, 0.95)
		sbf.border_color = Color(1.0, 0.92, 0.35, 1.0) if is_active else Color(0.42, 0.30, 0.18, 0.9)
		sbf.border_width_left = 2 if (is_active or is_hover) else 1
		sbf.border_width_top = 2 if (is_active or is_hover) else 1
		sbf.border_width_right = 2 if (is_active or is_hover) else 1
		sbf.border_width_bottom = 2 if (is_active or is_hover) else 1
		sbf.corner_radius_top_left = 4
		sbf.corner_radius_top_right = 4
		sbf.corner_radius_bottom_left = 4
		sbf.corner_radius_bottom_right = 4
		return sbf

func _create_category_slot_button(cat_data: Dictionary) -> Button:
	var cat_id: String = cat_data.id
	var btn := Button.new()
	btn.name = "CategorySlot_" + cat_id
	btn.custom_minimum_size = Vector2(106, 56)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var s_norm := _create_stylebox_from_texture(tex_dark_box, false, false)
	var s_hov := _create_stylebox_from_texture(tex_light_box, false, true)
	var s_press := _create_stylebox_from_texture(tex_light_box, true, false)
	btn.add_theme_stylebox_override("normal", s_norm)
	btn.add_theme_stylebox_override("hover", s_hov)
	btn.add_theme_stylebox_override("pressed", s_press)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	btn.add_child(hbox)

	# Left: Icon/Texture Box
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(36, 36)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_box)
	category_icons[cat_id] = icon_box

	# Right: Title & Current Item Sublabel
	var text_vbox := VBoxContainer.new()
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(text_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "%s [%d]" % [cat_data.title, cat_data.key_num]
	title_lbl.add_theme_font_size_override("font_size", 10)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	text_vbox.add_child(title_lbl)
	category_labels[cat_id] = title_lbl

	var sub_lbl := Label.new()
	sub_lbl.text = "Default"
	sub_lbl.add_theme_font_size_override("font_size", 9)
	sub_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	text_vbox.add_child(sub_lbl)
	category_sublabels[cat_id] = sub_lbl

	# Expand arrow indicator at top right
	var arrow_lbl := Label.new()
	arrow_lbl.text = "▲"
	arrow_lbl.add_theme_font_size_override("font_size", 8)
	arrow_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 0.8))
	arrow_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	arrow_lbl.offset_left = -12
	arrow_lbl.offset_top = 2
	arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(arrow_lbl)

	btn.pressed.connect(func(): _on_category_slot_pressed(cat_id))
	btn.mouse_entered.connect(func(): _on_category_hover_entered(cat_id))
	btn.mouse_exited.connect(func(): _on_item_hover_exited(selected_category_items.get(cat_id, "")))

	return btn

func _setup_flyout_drawer(parent: VBoxContainer) -> void:
	flyout_drawer = PanelContainer.new()
	flyout_drawer.name = "FlyoutDrawer"
	flyout_drawer.visible = false
	flyout_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	flyout_drawer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	flyout_drawer.custom_minimum_size = Vector2(230, 0)

	var draw_style := StyleBoxFlat.new()
	draw_style.bg_color = Color(0.16, 0.10, 0.06, 0.98)
	draw_style.border_width_left = 2
	draw_style.border_width_top = 2
	draw_style.border_width_right = 2
	draw_style.border_width_bottom = 2
	draw_style.border_color = Color(0.88, 0.70, 0.32, 0.98) # Rich Gold
	draw_style.corner_radius_top_left = 6
	draw_style.corner_radius_top_right = 6
	draw_style.corner_radius_bottom_left = 6
	draw_style.corner_radius_bottom_right = 6
	draw_style.shadow_size = 8
	draw_style.shadow_color = Color(0, 0, 0, 0.65)
	draw_style.content_margin_left = 8
	draw_style.content_margin_right = 8
	draw_style.content_margin_top = 6
	draw_style.content_margin_bottom = 6
	flyout_drawer.add_theme_stylebox_override("panel", draw_style)
	parent.add_child(flyout_drawer)

	var vbox := VBoxContainer.new()
	vbox.name = "FlyoutVBox"
	vbox.add_theme_constant_override("separation", 4)
	flyout_drawer.add_child(vbox)

	# Header row
	var h_row := HBoxContainer.new()
	h_row.name = "FlyoutHeaderRow"
	vbox.add_child(h_row)

	flyout_header_label = Label.new()
	flyout_header_label.text = "🌱 SELECT CROP SEED"
	flyout_header_label.add_theme_font_size_override("font_size", 11)
	flyout_header_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	flyout_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_row.add_child(flyout_header_label)

	var min_btn := Button.new()
	min_btn.text = "▼"
	min_btn.custom_minimum_size = Vector2(20, 18)
	min_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var s_min := StyleBoxFlat.new()
	s_min.bg_color = Color(0.25, 0.16, 0.08, 0.8)
	s_min.border_color = Color(0.65, 0.50, 0.25, 0.8)
	s_min.border_width_left = 1
	s_min.border_width_top = 1
	s_min.border_width_right = 1
	s_min.border_width_bottom = 1
	s_min.corner_radius_top_left = 3
	s_min.corner_radius_top_right = 3
	s_min.corner_radius_bottom_left = 3
	s_min.corner_radius_bottom_right = 3
	min_btn.add_theme_stylebox_override("normal", s_min)
	min_btn.pressed.connect(func(): _close_flyout())
	h_row.add_child(min_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	flyout_items_vbox = VBoxContainer.new()
	flyout_items_vbox.name = "ItemsVBox"
	flyout_items_vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(flyout_items_vbox)

func _setup_hover_card(parent: VBoxContainer) -> void:
	hover_card = PanelContainer.new()
	hover_card.name = "CropHoverCard"
	hover_card.visible = false
	hover_card.custom_minimum_size = Vector2(340, 0)
	hover_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.16, 0.10, 0.06, 0.98)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.92, 0.75, 0.35, 0.95)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.shadow_size = 6
	card_style.shadow_color = Color(0, 0, 0, 0.55)
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	hover_card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(hover_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	hover_card.add_child(card_vbox)

	# 1. Header row
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	card_vbox.add_child(header_hbox)

	card_icon = Label.new()
	card_icon.text = "🌱"
	card_icon.add_theme_font_size_override("font_size", 22)
	header_hbox.add_child(card_icon)

	card_texture = TextureRect.new()
	card_texture.custom_minimum_size = Vector2(26, 26)
	card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_texture.visible = false
	header_hbox.add_child(card_texture)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 1)
	header_hbox.add_child(title_vbox)

	card_title = Label.new()
	card_title.text = "Item Name"
	card_title.add_theme_font_size_override("font_size", 13)
	card_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title_vbox.add_child(card_title)

	card_type = Label.new()
	card_type.text = "Type description"
	card_type.add_theme_font_size_override("font_size", 10)
	card_type.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	title_vbox.add_child(card_type)

	# 2. Vital Stats Row
	card_stats = Label.new()
	card_stats.text = "Stats..."
	card_stats.add_theme_font_size_override("font_size", 10)
	card_stats.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
	card_vbox.add_child(card_stats)

	var sep1 := HSeparator.new()
	card_vbox.add_child(sep1)

	# 3. Description
	card_desc = Label.new()
	card_desc.text = "Description text..."
	card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_desc.add_theme_font_size_override("font_size", 10)
	card_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.80))
	card_vbox.add_child(card_desc)

	var sep2 := HSeparator.new()
	card_vbox.add_child(sep2)

	# 4. Regional Impact Section
	card_region_title = Label.new()
	card_region_title.text = "📍 Regional Impact"
	card_region_title.add_theme_font_size_override("font_size", 10)
	card_region_title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.40))
	card_vbox.add_child(card_region_title)

	card_buffs = Label.new()
	card_buffs.text = "✔ Buffs"
	card_buffs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_buffs.add_theme_font_size_override("font_size", 10)
	card_buffs.add_theme_color_override("font_color", Color(0.45, 0.95, 0.45))
	card_vbox.add_child(card_buffs)

	card_debuffs = Label.new()
	card_debuffs.text = "⚠️ Debuffs"
	card_debuffs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_debuffs.add_theme_font_size_override("font_size", 10)
	card_debuffs.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	card_vbox.add_child(card_debuffs)

# ---------------------------------------------------------------------------
# Category Slot Interactions & Flyout Populating
# ---------------------------------------------------------------------------
func _on_category_slot_pressed(cat_id: String) -> void:
	if open_flyout_category == cat_id:
		_close_flyout()
	else:
		open_flyout_category = cat_id
		active_category = cat_id
		var cur_item: String = selected_category_items.get(cat_id, "")
		if not cur_item.is_empty():
			select_tool(cur_item)
		_open_flyout_for_category(cat_id)
		_highlight_active_selection()

func _close_flyout() -> void:
	open_flyout_category = ""
	if flyout_drawer:
		flyout_drawer.visible = false

func _open_flyout_for_category(cat_id: String) -> void:
	if not CATEGORY_DATA.has(cat_id):
		return
	var c_data: Dictionary = CATEGORY_DATA[cat_id]
	flyout_header_label.text = "%s SELECT %s" % [c_data.icon, c_data.title]

	# Clear previous items
	for ch in flyout_items_vbox.get_children():
		ch.queue_free()
	flyout_item_buttons.clear()

	var cur_sel: String = selected_category_items.get(cat_id, "")

	for item in c_data.items:
		var item_id: String = item.id
		var btn := Button.new()
		btn.name = "FlyoutItem_" + item_id
		btn.custom_minimum_size = Vector2(214, 34)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		var is_cur: bool = (item_id == cur_sel)
		var s_item := _create_stylebox_from_texture(tex_light_box if is_cur else tex_dark_box, is_cur, false)
		var s_item_hov := _create_stylebox_from_texture(tex_light_box, is_cur, true)
		btn.add_theme_stylebox_override("normal", s_item)
		btn.add_theme_stylebox_override("hover", s_item_hov)
		btn.add_theme_stylebox_override("pressed", s_item_hov)

		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 6)
		btn.add_child(hbox)

		# Icon/Sprite thumbnail on left
		var thumb := Control.new()
		thumb.custom_minimum_size = Vector2(28, 28)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(thumb)

		if cat_id == "seeds":
			var tex := get_crop_sprite_texture(item_id)
			if tex != null:
				var tr := TextureRect.new()
				tr.texture = tex
				tr.custom_minimum_size = Vector2(26, 26)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tr.position = Vector2(1, 1)
				thumb.add_child(tr)
			else:
				var ic := Label.new()
				ic.text = item.icon
				ic.add_theme_font_size_override("font_size", 16)
				ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				thumb.add_child(ic)
		else:
			var ic := Label.new()
			ic.text = item.icon
			ic.add_theme_font_size_override("font_size", 16)
			ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumb.add_child(ic)

		# Name label
		var name_lbl := Label.new()
		name_lbl.text = item.name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85) if is_cur else Color(0.9, 0.85, 0.75))
		hbox.add_child(name_lbl)

		# Tag / Price badge
		var tag_lbl := Label.new()
		if item.cost > 0:
			var fp: Vector2i = item.get("fp", Vector2i(1, 1))
			if fp.x > 1 or fp.y > 1:
				tag_lbl.text = "%d×%d ₱%d" % [fp.x, fp.y, item.cost]
			else:
				tag_lbl.text = "₱%d" % item.cost
			tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
		else:
			tag_lbl.text = "Free"
			tag_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
		tag_lbl.add_theme_font_size_override("font_size", 9)
		hbox.add_child(tag_lbl)

		# Signals
		btn.pressed.connect(func(): _on_flyout_item_selected(cat_id, item_id))
		btn.mouse_entered.connect(func(): _on_item_hover_entered(item_id))
		btn.mouse_exited.connect(func(): _on_item_hover_exited(item_id))

		flyout_items_vbox.add_child(btn)
		flyout_item_buttons[item_id] = btn

	flyout_drawer.visible = true

func _on_flyout_item_selected(cat_id: String, item_id: String) -> void:
	selected_category_items[cat_id] = item_id
	active_category = cat_id
	select_tool(item_id)
	_update_category_slots_display()
	_highlight_active_selection()
	_close_flyout()

func _update_category_slots_display() -> void:
	for cat_id in ["seeds", "tools", "treatments"]:
		var cur_item_id: String = selected_category_items.get(cat_id, "")
		var sub_lbl: Label = category_sublabels.get(cat_id, null)
		var icon_container: Control = category_icons.get(cat_id, null)
		if not is_instance_valid(icon_container):
			continue

		for ch in icon_container.get_children():
			ch.queue_free()

		var c_data: Dictionary = CATEGORY_DATA[cat_id]
		var item_data: Dictionary = {}
		for it in c_data.items:
			if it.id == cur_item_id:
				item_data = it
				break

		var item_display_name: String = item_data.get("name", cur_item_id.capitalize())
		if sub_lbl:
			if item_data.get("cost", 0) > 0:
				sub_lbl.text = "%s (₱%d)" % [item_display_name.split(" ")[0], item_data.cost]
			else:
				sub_lbl.text = item_display_name.split(" ")[0]

		if cat_id == "seeds":
			var tex := get_crop_sprite_texture(cur_item_id)
			if tex != null:
				var tr := TextureRect.new()
				tr.texture = tex
				tr.custom_minimum_size = Vector2(32, 32)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tr.position = Vector2(2, 2)
				icon_container.add_child(tr)
			else:
				var ic := Label.new()
				ic.text = item_data.get("icon", "🌱")
				ic.add_theme_font_size_override("font_size", 22)
				ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_container.add_child(ic)
		else:
			var ic := Label.new()
			ic.text = item_data.get("icon", "⛏️")
			ic.add_theme_font_size_override("font_size", 22)
			ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_container.add_child(ic)

func _highlight_active_selection() -> void:
	for cat_id in category_slots:
		var btn: Button = category_slots[cat_id]
		if not is_instance_valid(btn):
			continue
		var is_cur: bool = (cat_id == active_category)
		var s_norm := _create_stylebox_from_texture(tex_light_box if is_cur else tex_dark_box, is_cur, false)
		var s_hov := _create_stylebox_from_texture(tex_light_box, is_cur, true)
		btn.add_theme_stylebox_override("normal", s_norm)
		btn.add_theme_stylebox_override("hover", s_hov)

func select_tool(tool_id: String) -> void:
	selected_tool = tool_id

	for cat_id in CATEGORY_DATA:
		var c_data: Dictionary = CATEGORY_DATA[cat_id]
		for it in c_data.items:
			if it.id == tool_id:
				active_category = cat_id
				selected_category_items[cat_id] = tool_id
				break

	_update_category_slots_display()
	_highlight_active_selection()
	tool_selected.emit(tool_id)
	if tool_id in CROP_KEYS:
		crop_selected.emit(tool_id)

	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	if farm_grid and farm_grid.drag_overlay:
		farm_grid.drag_overlay.queue_redraw()

func select_crop(crop_key: String) -> void:
	select_tool(crop_key)

func _update_affordability() -> void:
	var cur_cash: int = EconomyManager.cash
	for cat_id in CATEGORY_DATA:
		var c_data: Dictionary = CATEGORY_DATA[cat_id]
		for it in c_data.items:
			var btn: Button = flyout_item_buttons.get(it.id, null)
			if is_instance_valid(btn):
				if it.cost > cur_cash:
					btn.modulate = Color(0.9, 0.65, 0.65, 0.8)
				else:
					btn.modulate = Color.WHITE

# ---------------------------------------------------------------------------
# Hover Card Timing & Regional Analysis
# ---------------------------------------------------------------------------
func _on_category_hover_entered(cat_id: String) -> void:
	var item_id: String = selected_category_items.get(cat_id, "")
	_on_item_hover_entered(item_id)

func _on_item_hover_entered(item_id: String) -> void:
	if item_id.is_empty():
		return
	hovered_item_id = item_id
	if hover_card and hover_card.visible:
		_populate_hover_card(item_id)
	else:
		hover_timer.start(HOVER_DELAY)

func _on_item_hover_exited(item_id: String) -> void:
	if hovered_item_id == item_id:
		hover_timer.stop()
		hovered_item_id = ""
		if hover_card:
			hover_card.visible = false

func _on_hover_timer_timeout() -> void:
	if not hovered_item_id.is_empty():
		_populate_hover_card(hovered_item_id)
		if hover_card:
			hover_card.visible = true

func _populate_hover_card(item_id: String) -> void:
	if item_id in CROP_KEYS:
		_populate_crop_hover(item_id)
	else:
		_populate_tool_or_treatment_hover(item_id)

func _populate_tool_or_treatment_hover(tool_id: String) -> void:
	card_texture.visible = false
	card_icon.visible = true

	match tool_id:
		"plow":
			card_icon.text = "⛏️"
			card_title.text = "Farm Plow & Hoe Tool"
			card_type.text = "Soil Preparation • Free Action"
			card_stats.text = "Targets: Uncultivated Soil & Flooded Plots • ₱0"
			card_desc.text = "Tills untilled earth, cleared land, or receded floodplains into fertile furrowed soil ready for crops. Left-click or click-drag over land to assign tasks."
			card_region_title.text = "📍 Regional Soil Preparation"
			card_buffs.text = "✔ Essential across all 5 Mindanao regions before planting."
			card_debuffs.text = "⚠️ Cannot plow plots with tree or rock obstacles (clear them first)."

		"water":
			card_icon.text = "💧"
			card_title.text = "Watering Can & Irrigation"
			card_type.text = "Soil Hydration • Free Action"
			card_stats.text = "Targets: Planted, Growing, or Infected Crops • +25% Soil Moisture"
			card_desc.text = "Hydrates parched crops to maintain optimal agronomic moisture. Crucial during heatwaves, El Niño droughts, and arid inland valleys."
			card_region_title.text = "📍 Climate Protection"
			card_buffs.text = "✔ Prevents crop withering and heat stress in South Cotabato & Sarangani."
			card_debuffs.text = "⚠️ Over-watering high moisture soil (>90%) risks root rot in wetland crops."

		"harvest":
			card_icon.text = "🧺"
			card_title.text = "Harvest Basket & Sickle"
			card_type.text = "Produce Gathering • Free Action"
			card_stats.text = "Targets: 100% Ripe Crops, Fresh Buko (75%+), or Salvageable Flooded Plots"
			card_desc.text = "Reaps mature crops and transports fresh harvest to the regional bodega depot. Perennial crops (Coffee, Banana, Coconut) regrow automatically after harvest!"
			card_region_title.text = "📍 Supply Chain Delivery"
			card_buffs.text = "✔ High freshness at harvest yields maximum Grade A market revenue."
			card_debuffs.text = "⚠️ Ensure depot storage capacity is available before mass harvesting."

		"clear":
			card_icon.text = "🪓"
			card_title.text = "Obstacle Clearing Gear"
			card_type.text = "Land Reclamation • ₱50 per plot"
			card_stats.text = "Targets: Timber Trees, Pine Stumps, Roots, & Rocks"
			card_desc.text = "Clears wilderness debris and boulders to expand tillable homestead land. Workers excavate the plot and leave bare soil ready for plowing."
			card_region_title.text = "📍 Territory Development"
			card_buffs.text = "✔ Converts uncultivable terrain into high-yield agricultural plots."
			card_debuffs.text = "⚠️ Requires ₱50 municipal reclamation permit per plot."

		"spray_chemical":
			card_icon.text = "🧪"
			card_title.text = "Chemical Insecticide Treatment"
			card_type.text = "Crop Protection • ₱30 per application"
			card_stats.text = "Targets: Pests (Kuhol, Armyworm, Wilt, Black Bug) • Instant Eradication"
			card_desc.text = "Powerful chemical spray that immediately eliminates active pest infestations and cures blighted crops. Can also be applied as pre-planting soil prophylaxis."
			card_region_title.text = "📍 Pest Defense"
			card_buffs.text = "✔ 100% effective knockdown against Golden Apple Snails and Armyworms."
			card_debuffs.text = "⚠️ Frequent non-organic chemical use incurs minor long-term soil fatigue."

		"spray_biological":
			card_icon.text = "🦆"
			card_title.text = "Biological IPM Pest Management"
			card_type.text = "Integrated Pest Management • ₱45 per application"
			card_stats.text = "Targets: Natural Biological Predators & Eco-Fungicides • 100% Organic"
			card_desc.text = "Eco-friendly biocontrol deploying ducks for snails, parasitic wasps for armyworms, and beneficial Trichoderma fungi. Preserves soil micro-ecology and organic crop grading."
			card_region_title.text = "📍 Agro-Ecological Synergy"
			card_buffs.text = "✔ Protects organic crop grade and bolsters Regional League prestige points."
			card_debuffs.text = "⚠️ Higher initial cost (₱45) compared to conventional chemical spray."

		_:
			card_icon.text = "🛠️"
			card_title.text = tool_id.capitalize()
			card_type.text = "Farming Action"
			card_stats.text = "Field Command"
			card_desc.text = "Standard agricultural action."
			card_region_title.text = "📍 Information"
			card_buffs.text = "Standard operation."
			card_debuffs.text = "No risks."

func _populate_crop_hover(crop_key: String) -> void:
	var c_data: Dictionary = Data.get_crop(crop_key)
	if c_data.is_empty():
		return

	var is_2x2: bool = (c_data.get("footprint", Vector2i(1, 1)) == Vector2i(2, 2))
	var is_peren: bool = c_data.get("is_perennial", false)
	var g_days: int = int(c_data.get("growth_days", 25))
	var reg_days: int = int(c_data.get("regrowth_days", 0))
	var yield_qty: int = int(c_data.get("yield_quantity", 100))
	var seed_cost: int = int(c_data.get("seed_cost", 25))
	var base_price: int = int(c_data.get("base_price", 100))

	var crop_tex := get_crop_sprite_texture(crop_key)
	if crop_tex != null:
		card_texture.texture = crop_tex
		card_texture.visible = true
		card_icon.visible = false
	else:
		card_icon.text = c_data.get("icon", "🌱")
		card_icon.visible = true
		card_texture.visible = false

	card_title.text = c_data.get("display_name", crop_key.capitalize())
	var type_str: String = "Perennial Tree • 2×2 Diamond Grove" if is_2x2 else ("Perennial Shrub • 1×1 Plot" if is_peren else "Annual Field Crop • 1×1 Plot")
	card_type.text = type_str

	var growth_str: String = ("%dd (+%dd Regrowth)" % [g_days, reg_days]) if is_peren else ("%dd Cycle" % g_days)
	card_stats.text = "Growth: %s • Yield: %d • Seed: ₱%d • Base: ₱%d" % [growth_str, yield_qty, seed_cost, base_price]

	card_desc.text = c_data.get("description", "")

	var cur_reg: String = Data.current_region
	var reg_data: Dictionary = Data.get_region(cur_reg)
	card_region_title.text = "📍 Regional Affinity: %s" % reg_data.get("display_name", cur_reg.capitalize())

	var analysis: Dictionary = get_regional_crop_analysis(crop_key, cur_reg)
	var buffs: Array = analysis.get("buffs", [])
	var debuffs: Array = analysis.get("debuffs", [])

	card_buffs.text = "\n".join(buffs) if buffs.size() > 0 else "✔ Standard growth in this region."
	card_debuffs.text = "\n".join(debuffs) if debuffs.size() > 0 else "No acute climate risks."

static func get_regional_crop_analysis(crop_key: String, region_key: String) -> Dictionary:
	var crop: Dictionary = Data.get_crop(crop_key)
	var region: Dictionary = Data.get_region(region_key)
	var reg_moisture: float = float(region.get("soil_moisture", 50))
	var hazards: Dictionary = region.get("hazards", {})

	var buffs: Array[String] = []
	var debuffs: Array[String] = []

	var specialties: Array = LeaderboardManager.REGION_SPECIALTIES.get(region_key, [])
	if specialties.has(crop_key):
		buffs.append("✨ Regional Specialty: +20%% Market Value & +25%% Leaderboard Prestige in %s!" % region.get("display_name", region_key))

	var w_min: float = float(crop.get("water_min", 40))
	var w_max: float = float(crop.get("water_max", 70))

	if reg_moisture >= w_min and reg_moisture <= w_max:
		buffs.append("✔ Optimal Climate: Natural baseline soil moisture (%.0f%%) fosters bumper Grade A yields." % reg_moisture)
	elif reg_moisture < w_min:
		debuffs.append("⚠️ Moisture Deficit: Regional moisture (%.0f%%) is below crop minimum (%.0f%%). Requires frequent irrigation!" % [reg_moisture, w_min])
	elif reg_moisture > w_max:
		debuffs.append("⚠️ Over-saturation: Regional moisture (%.0f%%) exceeds ideal threshold (%.0f%%). Risk of root rot!" % [reg_moisture, w_max])

	var flood_risk: float = float(hazards.get("flash_flood", 0.0))
	var drought_risk: float = float(hazards.get("el_nino_drought", 0.0))

	if flood_risk >= 0.10 and w_max <= 75.0:
		debuffs.append("⚠️ Flood Susceptibility: River overflow and flash floods will drown crops lacking wetland tolerance!")
	if drought_risk >= 0.10 and w_min >= 50.0:
		debuffs.append("⚠️ Drought Threat: Blistering dry spells halt growth; needs steady water reserves!")

	var crop_pests: Array = crop.get("pests", [])
	if crop_pests.has("kuhol") and region_key == "cotabato":
		debuffs.append("⚠️ Pest Risk: Wetland paddies heavily attract Golden Apple Snails (Kuhol)!")
	if crop_pests.has("fusarium_wilt") and (region_key == "south_cotabato" or region_key == "general_santos"):
		debuffs.append("⚠️ Disease Risk: Upland and coastal humidity favors Fusarium Wilt (Panama disease)!")
	if crop_pests.has("armyworm") and (region_key == "sarangani" or region_key == "sultan_kudarat"):
		debuffs.append("⚠️ Pest Risk: Arid spells trigger sudden Fall Armyworm outbreaks!")

	if crop.get("is_perennial", false):
		buffs.append("✔ Living Perennial: Regrows automatically in only %d days without seed costs." % int(crop.get("regrowth_days", 14)))
	if float(crop.get("heat_max", 35)) >= 40.0:
		buffs.append("✔ Heat Resilient: Resists blistering tropical heat up to %.0f°C." % float(crop.get("heat_max", 35)))

	return {
		"buffs": buffs,
		"debuffs": debuffs
	}

func get_crop_sprite_texture(crop_type: String) -> Texture2D:
	if crop_type.is_empty():
		return null
	if _texture_cache.has(crop_type):
		return _texture_cache[crop_type]

	if CROP_ICONS.has(crop_type):
		var p: String = CROP_ICONS[crop_type]
		if ResourceLoader.exists(p):
			var tex: Texture2D = load(p) as Texture2D
			if tex:
				_texture_cache[crop_type] = tex
				return tex

	var candidates: Array[String] = [
		"res://assets/sprites/crops/%s.png" % crop_type,
		"res://assets/sprites/crops/%s.png" % crop_type.capitalize(),
		"res://assets/sprites/crops/crop_%s.png" % crop_type,
		"res://assets/sprites/%s.png" % crop_type,
		"res://assets/sprites/%s.png" % crop_type.capitalize(),
		"res://assets/icons/%s.png" % crop_type,
		"res://assets/icons/%s.png" % crop_type.capitalize(),
		"res://assets/icons/%s_sprite.png" % crop_type
	]

	for path in candidates:
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			if tex:
				_texture_cache[crop_type] = tex
				return tex

	_texture_cache[crop_type] = null
	return null

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return

		match event.keycode:
			KEY_1:
				_on_category_slot_pressed("seeds")
			KEY_2:
				_on_category_slot_pressed("tools")
			KEY_3:
				_on_category_slot_pressed("treatments")
			KEY_ESCAPE:
				if not open_flyout_category.is_empty():
					_close_flyout()
					get_viewport().set_input_as_handled()
"""

with open(r'c:\Users\ADMIN\Documents\agri-region-ai-version\src\ui\PlantHotbar.gd', 'w', encoding='utf-8') as f:
	f.write(code)
print("Successfully generated src/ui/PlantHotbar.gd")
