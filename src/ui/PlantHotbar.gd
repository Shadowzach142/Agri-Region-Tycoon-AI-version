# PlantHotbar.gd
# Minecraft-style Minimalist Square Hotbar System docked at HUD bottom-center.
#
# Primary Hotbar:
#   - Clean square boxes (just like Minecraft hotbar slots!)
#   - 3 Category slots: [1] Seeds, [2] Tools, [3] IPM
#   - All icons are 100% centered INSIDE the boxes using CenterContainer layout.
#   - Uses dedicated plant icons from assets/icons/Plants/ for all crops.
#   - No cluttering text or names on the hotbar - just pure pixel-art square boxes & icons.
#   - Active slot is highlighted with the light-box frame texture.
#   - Hovering any box for a short moment (0.25s) reveals the item's name, cost, and description.
#
# Flyout Selector Drawers:
#   - Clicking a category slot opens a horizontal palette of square item boxes directly above it.
#   - Seeds: All 7 crops with dedicated plant icons (Rice, Corn, Cane, Pineapple, Coffee, Banana, Coconut)
#   - Tools: Plow, Water, Harvest, Clear
#   - IPM: Chemical Spray, Biological IPM
#   - Hovering any drawer item displays its detailed tooltip card.
#   - Clicking an item equips it to that hotbar slot and arms the worker.

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
		var loop = Engine.get_main_loop()
		if loop and "root" in loop and loop.root:
			var bm = loop.root.get_node_or_null("BuildingManager")
			if bm and bm.has_method("is_crop_unlocked"):
				if not bm.is_crop_unlocked(selected_tool):
					return "palay"
		return selected_tool
	return "palay"

static func set_selected_crop(crop_name: String) -> void:
	var loop = Engine.get_main_loop()
	if loop and "root" in loop and loop.root:
		var bm = loop.root.get_node_or_null("BuildingManager")
		if bm and bm.has_method("is_crop_unlocked") and not bm.is_crop_unlocked(crop_name):
			selected_tool = "palay"
			return
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

# Dedicated UI plant icons in assets/icons/Plants/
const CROP_ICONS: Dictionary = {
	"palay": "res://assets/icons/Plants/Rice.png",
	"yellow_corn": "res://assets/icons/Plants/Corn.png",
	"sugarcane": "res://assets/icons/Plants/Sugarcane.png",
	"pineapple": "res://assets/icons/Plants/Pineapple.png",
	"arabica_coffee": "res://assets/icons/Plants/coffee.png",
	"banana": "res://assets/icons/Plants/Banana.png",
	"coconut": "res://assets/icons/Plants/Coconut.png"
}

# Dedicated UI tool icons in assets/icons/Tools/
const TOOL_ICONS: Dictionary = {
	"inspect": "res://assets/icons/Tools/Magnify.png",
	"plow": "res://assets/icons/Tools/Pick.png",
	"water": "res://assets/icons/Tools/watering.png",
	"harvest": "res://assets/icons/Tools/Basket.png",
	"clear": "res://assets/icons/Tools/Axe.png",
	"cancel_task": "res://assets/icons/Tools/Cancel.png",
	"spray_chemical": "res://assets/icons/Tools/Chem.png",
	"spray_biological": "res://assets/icons/Tools/duck.png",
	"auto_loop": "res://assets/icons/HUD/Drone.png",
	"drone_zone": "res://assets/icons/Tools/Magnify.png"
}

static func get_tool_sprite_texture(tool_id: String) -> Texture2D:
	if TOOL_ICONS.has(tool_id):
		var p: String = TOOL_ICONS[tool_id]
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null

const CATEGORY_DATA: Dictionary = {
	"seeds": {
		"id": "seeds",
		"title": "SEEDS",
		"icon": "🌱",
		"key_num": 1,
		"default_item": "palay",
		"items": [
			{"id": "palay", "name": "Palay (Rice)", "cost": 25, "icon": "🌾", "fp": Vector2i(1, 1), "desc": "Fast-growing wetland grain. Cotabato regional specialty."},
			{"id": "yellow_corn", "name": "Yellow Corn", "cost": 30, "icon": "🌽", "fp": Vector2i(1, 1), "desc": "Hardy cereal crop resilient against dry upland spells."},
			{"id": "sugarcane", "name": "Sugar Cane", "cost": 30, "icon": "🎋", "fp": Vector2i(1, 1), "desc": "High-yield cash crop favored in fertile river valleys."},
			{"id": "pineapple", "name": "Smooth Cayenne Pineapple", "cost": 40, "icon": "🍍", "fp": Vector2i(1, 1), "desc": "High market value fruit tailored for volcanic upland soils."},
			{"id": "arabica_coffee", "name": "Arabica Coffee", "cost": 50, "icon": "☕", "fp": Vector2i(1, 1), "desc": "Living perennial shrub. Regrows every 14 days without re-buying."},
			{"id": "banana", "name": "Cavendish Banana", "cost": 140, "icon": "🍌", "fp": Vector2i(2, 2), "desc": "Perennial 2×2 plantation grove. Yields 400 units every 18 days."},
			{"id": "coconut", "name": "Tall Coconut Palm", "cost": 160, "icon": "🥥", "fp": Vector2i(2, 2), "desc": "Durable perennial 2×2 palm tree. Regrows fresh buko nuts every 16 days."}
		]
	},
	"tools": {
		"id": "tools",
		"title": "TOOLS",
		"icon": "⛏️",
		"key_num": 2,
		"default_item": "plow",
		"items": [
			{"id": "inspect", "name": "Investigate / Soil Check", "cost": 0, "icon": "🔍", "desc": "Inspect soil diagnostics, moisture, nutrients, and crop progress without issuing farm labor tasks."},
			{"id": "plow", "name": "Plow & Hoe", "cost": 0, "icon": "⛏️", "desc": "Tills untilled earth, cleared land, or receded floodplains."},
			{"id": "water", "name": "Watering Can", "cost": 0, "icon": "💧", "desc": "Hydrates parched crops (+25% soil moisture)."},
			{"id": "harvest", "name": "Harvest Basket", "cost": 0, "icon": "🧺", "desc": "Gathers mature ripe crops or salvages flooded plots."},
			{"id": "clear", "name": "Clear Obstacle", "cost": 50, "icon": "🪓", "desc": "Excavates timber trees, pine stumps, and rocks."},
			{"id": "cancel_task", "name": "Stop / Cancel Action", "cost": 0, "icon": "🛑", "desc": "Cancels pending or active tasks on clicked plots and orders workers to halt immediately. [X]"}
		]
	},
	"treatments": {
		"id": "treatments",
		"title": "IPM",
		"icon": "🧪",
		"key_num": 3,
		"default_item": "spray_chemical",
		"items": [
			{"id": "spray_chemical", "name": "Chemical Spray", "cost": 30, "icon": "🧪", "desc": "Rapid pest knockdown against Golden Apple Snails and Armyworms."},
			{"id": "spray_biological", "name": "Biological IPM", "cost": 45, "icon": "🦆", "desc": "Organic biocontrol with ducks and fungi; protects crop grade."}
		]
	}
}

const DRONE_CATEGORY_DATA: Dictionary = {
	"seeds": {
		"id": "seeds",
		"title": "CROP",
		"icon": "🌱",
		"key_num": 1,
		"default_item": "palay",
		"items": [
			{"id": "palay", "name": "Palay (Rice)", "cost": 25, "icon": "🌾", "fp": Vector2i(1, 1), "desc": "Fast-growing wetland grain. Drone auto-sows on plowed plots."},
			{"id": "yellow_corn", "name": "Yellow Corn", "cost": 30, "icon": "🌽", "fp": Vector2i(1, 1), "desc": "Hardy cereal crop resilient against dry upland spells."},
			{"id": "sugarcane", "name": "Sugar Cane", "cost": 30, "icon": "🎋", "fp": Vector2i(1, 1), "desc": "High-yield cash crop favored in fertile river valleys."},
			{"id": "pineapple", "name": "Smooth Cayenne Pineapple", "cost": 40, "icon": "🍍", "fp": Vector2i(1, 1), "desc": "High market value fruit tailored for volcanic upland soils."},
			{"id": "arabica_coffee", "name": "Arabica Coffee", "cost": 50, "icon": "☕", "fp": Vector2i(1, 1), "desc": "Living perennial shrub. Regrows every 14 days without re-buying."},
			{"id": "banana", "name": "Cavendish Banana", "cost": 140, "icon": "🍌", "fp": Vector2i(2, 2), "desc": "Perennial 2×2 plantation grove. Yields 400 units every 18 days."},
			{"id": "coconut", "name": "Tall Coconut Palm", "cost": 160, "icon": "🥥", "fp": Vector2i(2, 2), "desc": "Durable perennial 2×2 palm tree. Regrows fresh buko nuts every 16 days."}
		]
	},
	"tools": {
		"id": "tools",
		"title": "MODE",
		"icon": "🛸",
		"key_num": 2,
		"default_item": "auto_loop",
		"items": [
			{"id": "auto_loop", "name": "Auto-Farm Loop", "cost": 0, "icon": "🌀", "desc": "Full autonomous cycle: Plow soil ➜ Sow assigned seeds ➜ Water parched crops ➜ Spray pests ➜ Harvest & deliver to Bodega!"},
			{"id": "plow", "name": "Plow Ground Only", "cost": 0, "icon": "⛏️", "desc": "Drone only tills untilled earth and flood-receded plots within its zone."},
			{"id": "plant", "name": "Sow Crop Only", "cost": 0, "icon": "🌱", "desc": "Drone only plants designated seeds on furrowed soil within its zone."},
			{"id": "water", "name": "Water Soil Only", "cost": 0, "icon": "💧", "desc": "Drone only hydrates thirsty crops (<50% soil moisture) within its zone."},
			{"id": "harvest", "name": "Harvest Crops Only", "cost": 0, "icon": "🧺", "desc": "Drone only reaps mature ripe crops and delivers them directly to storage."},
			{"id": "drone_zone", "name": "Designate Field Zone", "cost": 0, "icon": "🎯", "desc": "Click and drag a box across your farm to set this drone's operating zone."},
			{"id": "drone_whole_farm", "name": "Patrol Whole Farm", "cost": 0, "icon": "🌐", "desc": "1-Click deploy: Orders this drone to automatically patrol and maintain all unlocked farmland!"},
			{"id": "drone_recall", "name": "Return & Dock", "cost": 0, "icon": "🏠", "desc": "Recalls this drone back to its landing pad to dock and recharge."}
		]
	},
	"treatments": {
		"id": "treatments",
		"title": "IPM",
		"icon": "🧪",
		"key_num": 3,
		"default_item": "spray_chemical",
		"items": [
			{"id": "spray_chemical", "name": "Chemical Spray", "cost": 30, "icon": "🧪", "desc": "Fast chemical insecticide knockdown. Eliminates snails and worms automatically."},
			{"id": "spray_biological", "name": "Biological IPM", "cost": 45, "icon": "🦆", "desc": "Organic biocontrol with ducks and fungi; protects crop grade."}
		]
	}
}

const CATEGORY_ORDER: Array[String] = ["seeds", "tools", "treatments"]

# Snappy hover delay (short pause before tooltip appears)
const HOVER_DELAY: float = 0.25

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
var category_labels: Dictionary = {} # cat_id -> Label (kept for backward compatibility)
var category_sublabels: Dictionary = {} # cat_id -> Label (kept for backward compatibility)
var category_icons: Dictionary = {} # cat_id -> CenterContainer
var category_price_labels: Dictionary = {} # cat_id -> Label (bottom-right price tag)
var flyout_drawer: PanelContainer = null
var flyout_header_label: Label = null
var flyout_items_vbox: BoxContainer = null # HBoxContainer of square items
var flyout_item_buttons: Dictionary = {} # item_id -> Button

# Unit Switcher UI (Switch between human workers and autonomous drones seamlessly!)
var _unit_prev_btn: Button = null
var _unit_pill_btn: Button = null
var _unit_next_btn: Button = null
var _unit_switch_type_btn: Button = null

var hover_card: PanelContainer = null
var hover_timer: Timer = null
var hovered_item_id: String = ""

var card_icon: Label = null
var card_texture: TextureRect = null
var card_title: Label = null
var card_price: Label = null
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
var tex_drone_dark_box: Texture2D = null
var tex_drone_light_box: Texture2D = null
var tex_info_box: Texture2D = null
var tex_tab_arrow_left: Texture2D = null
var tex_tab_arrow_left_hov: Texture2D = null
var tex_tab_arrow_right: Texture2D = null
var tex_tab_arrow_right_hov: Texture2D = null
var style_brown_btn: StyleBox = null
var style_brown_btn_hov: StyleBox = null
var style_brown_btn_press: StyleBox = null
var _texture_cache: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(160, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Load HUD square button textures for farmer (wood/brown)
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Squarebutton/brown-button.png"):
		tex_dark_box = load("res://assets/sprites/hud/Buttons/Squarebutton/brown-button.png")
	elif ResourceLoader.exists("res://assets/sprites/hud/Hopbar/small-dark-box.png"):
		tex_dark_box = load("res://assets/sprites/hud/Hopbar/small-dark-box.png")
	elif ResourceLoader.exists("res://assets/sprites/hud/Small-Rectangular-Box/small-dark-box.png"):
		tex_dark_box = load("res://assets/sprites/hud/Small-Rectangular-Box/small-dark-box.png")

	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Squarebutton/Light-button.png"):
		tex_light_box = load("res://assets/sprites/hud/Buttons/Squarebutton/Light-button.png")
	elif ResourceLoader.exists("res://assets/sprites/hud/Hopbar/small-ligh-box.png"):
		tex_light_box = load("res://assets/sprites/hud/Hopbar/small-ligh-box.png")
	elif ResourceLoader.exists("res://assets/sprites/hud/Small-Rectangular-Box/small-ligh-box.png"):
		tex_light_box = load("res://assets/sprites/hud/Small-Rectangular-Box/small-ligh-box.png")

	# Load HUD square button textures for drone (sleek grey/silver metallic chassis)
	if ResourceLoader.exists("res://assets/sprites/hud/Hopbar/drone-dark-box.png"):
		tex_drone_dark_box = load("res://assets/sprites/hud/Hopbar/drone-dark-box.png")
	if ResourceLoader.exists("res://assets/sprites/hud/Hopbar/drone-light-box.png"):
		tex_drone_light_box = load("res://assets/sprites/hud/Hopbar/drone-light-box.png")

	# Load official HUD arrow buttons
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_left_normal.png"):
		tex_tab_arrow_left = load("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_left_normal.png")
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_left_hover.png"):
		tex_tab_arrow_left_hov = load("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_left_hover.png")
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_right_normal.png"):
		tex_tab_arrow_right = load("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_right_normal.png")
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_right_hover.png"):
		tex_tab_arrow_right_hov = load("res://assets/sprites/hud/Buttons/Arrows/tab_arrow_right_hover.png")

	# Load official HUD wooden button styles
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"):
		style_brown_btn = load("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres")
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"):
		style_brown_btn_hov = load("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres")
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"):
		style_brown_btn_press = load("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres")

	if ResourceLoader.exists("res://assets/sprites/hud/Hopbar/information-box.png"):
		tex_info_box = load("res://assets/sprites/hud/Hopbar/information-box.png")

	_setup_ui()
	_update_category_slots_display()
	_highlight_active_selection()

	if EconomyManager.has_signal("cash_changed"):
		EconomyManager.cash_changed.connect(func(_c): _update_affordability())

	if TaskManager.has_signal("selection_changed"):
		TaskManager.selection_changed.connect(_on_worker_selection_changed)

	var fg = get_tree().root.find_child("FarmGrid", true, false)
	if fg and fg.has_signal("drone_selected"):
		fg.drone_selected.connect(func(_idx): _update_visibility_from_selection())

	if BuildingManager.has_signal("crop_unlocked"):
		BuildingManager.crop_unlocked.connect(func(_c):
			_update_category_slots_display()
			if flyout_drawer and flyout_drawer.visible and active_category == "seeds":
				_open_flyout_for_category("seeds")
		)

	_update_visibility_from_selection()

func _is_drone_mode() -> bool:
	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	return farm_grid != null and farm_grid.has_method("get_selected_drone") and farm_grid.get_selected_drone() != null

func _get_selected_drone() -> FarmDrone:
	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	if farm_grid and farm_grid.has_method("get_selected_drone"):
		return farm_grid.get_selected_drone()
	return null

func _get_drone_capability_level() -> int:
	var sel_drone := _get_selected_drone()
	if sel_drone:
		return sel_drone.get_level()
	return BuildingManager.get_drone_level()

func _is_category_locked_for_unit(cat_id: String) -> bool:
	if not _is_drone_mode():
		return false
	var lvl := _get_drone_capability_level()
	if cat_id == "seeds":
		return lvl < 2 # Requires Drone Command Hangar Lv. 2 for Precision Seeding
	if cat_id == "treatments":
		return lvl < 2 # Requires Drone Command Hangar Lv. 2 for IPM Spray
	return false

func _is_flyout_item_locked_for_drone(item_id: String) -> bool:
	if not _is_drone_mode():
		return false
	var lvl := _get_drone_capability_level()
	match item_id:
		"plant":
			return lvl < 2 # Requires Drone Command Hangar Lv. 2
		"harvest":
			return lvl < 3 # Requires Drone Command Hangar Lv. 3
		"auto_loop":
			return lvl < 2 # Requires at least Lv. 2 for seeding
	return false

func _get_slot_texture(is_active: bool) -> Texture2D:
	if _is_drone_mode():
		return (tex_drone_light_box if tex_drone_light_box else tex_light_box) if is_active else (tex_drone_dark_box if tex_drone_dark_box else tex_dark_box)
	return tex_light_box if is_active else tex_dark_box

func _get_active_category_data(cat_id: String) -> Dictionary:
	if _is_drone_mode() and DRONE_CATEGORY_DATA.has(cat_id):
		return DRONE_CATEGORY_DATA[cat_id]
	return CATEGORY_DATA.get(cat_id, {})

func _style_arrow_button(btn: Button, is_left: bool) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.flat = true
	var s_empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", s_empty)
	btn.add_theme_stylebox_override("hover", s_empty)
	btn.add_theme_stylebox_override("pressed", s_empty)
	btn.add_theme_stylebox_override("focus", s_empty)
	btn.mouse_entered.connect(func():
		if is_left and tex_tab_arrow_left_hov:
			btn.icon = tex_tab_arrow_left_hov
		elif not is_left and tex_tab_arrow_right_hov:
			btn.icon = tex_tab_arrow_right_hov
	)
	btn.mouse_exited.connect(func():
		if is_left and tex_tab_arrow_left:
			btn.icon = tex_tab_arrow_left
		elif not is_left and tex_tab_arrow_right:
			btn.icon = tex_tab_arrow_right
	)

func _style_capsule_button(btn: Button, is_drone: bool, _is_switch_action: bool = false) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.add_theme_font_size_override("font_size", 9)
	if is_drone:
		# High-tech gunmetal & cyan-silver border
		btn.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.85, 0.98, 1.0))
		var s_norm := StyleBoxFlat.new()
		s_norm.bg_color = Color(0.18, 0.22, 0.27, 0.95)
		s_norm.border_color = Color(0.40, 0.85, 1.0, 0.90)
		s_norm.border_width_left = 1
		s_norm.border_width_top = 1
		s_norm.border_width_right = 1
		s_norm.border_width_bottom = 1
		s_norm.corner_radius_top_left = 3
		s_norm.corner_radius_top_right = 3
		s_norm.corner_radius_bottom_left = 3
		s_norm.corner_radius_bottom_right = 3
		s_norm.content_margin_left = 6
		s_norm.content_margin_right = 6
		s_norm.content_margin_top = 2
		s_norm.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", s_norm)
		var s_hov := s_norm.duplicate()
		s_hov.bg_color = Color(0.24, 0.30, 0.38, 0.98)
		s_hov.border_color = Color(0.70, 0.95, 1.0, 1.0)
		btn.add_theme_stylebox_override("hover", s_hov)
		btn.add_theme_stylebox_override("pressed", s_hov)
	else:
		# Warm wooden HUD button style
		btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.75))
		if style_brown_btn:
			btn.add_theme_stylebox_override("normal", style_brown_btn)
			btn.add_theme_stylebox_override("hover", style_brown_btn_hov if style_brown_btn_hov else style_brown_btn)
			btn.add_theme_stylebox_override("pressed", style_brown_btn_press if style_brown_btn_press else style_brown_btn)
		else:
			var s_norm := StyleBoxFlat.new()
			s_norm.bg_color = Color(0.18, 0.12, 0.08, 0.95)
			s_norm.border_color = Color(0.75, 0.55, 0.28, 0.90)
			s_norm.border_width_left = 1
			s_norm.border_width_top = 1
			s_norm.border_width_right = 1
			s_norm.border_width_bottom = 1
			s_norm.corner_radius_top_left = 3
			s_norm.corner_radius_top_right = 3
			s_norm.corner_radius_bottom_left = 3
			s_norm.corner_radius_bottom_right = 3
			s_norm.content_margin_left = 6
			s_norm.content_margin_right = 6
			s_norm.content_margin_top = 2
			s_norm.content_margin_bottom = 2
			btn.add_theme_stylebox_override("normal", s_norm)
			var s_hov := s_norm.duplicate()
			s_hov.bg_color = Color(0.28, 0.19, 0.12, 0.98)
			s_hov.border_color = Color(0.95, 0.80, 0.35, 1.0)
			btn.add_theme_stylebox_override("hover", s_hov)
			btn.add_theme_stylebox_override("pressed", s_hov)

func _style_mini_button(btn: Button, text_color: Color = Color(0.92, 0.88, 0.82)) -> void:
	_style_capsule_button(btn, false)

func _on_cycle_unit_next() -> void:
	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	if _is_drone_mode():
		if farm_grid and not farm_grid.drones.is_empty():
			var total: int = farm_grid.drones.size()
			var cur: int = maxi(farm_grid.selected_drone_index, 1)
			var nxt: int = (cur % total) + 1
			farm_grid.select_drone_by_index(nxt)
	else:
		var hud = get_tree().root.find_child("HUD", true, false)
		if hud and hud.has_method("_cycle_idle_worker"):
			hud._cycle_idle_worker()

func _on_cycle_unit_prev() -> void:
	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	if _is_drone_mode():
		if farm_grid and not farm_grid.drones.is_empty():
			var total: int = farm_grid.drones.size()
			var cur: int = maxi(farm_grid.selected_drone_index, 1)
			var prev: int = (cur - 2 + total) % total + 1
			farm_grid.select_drone_by_index(prev)
	else:
		var hud = get_tree().root.find_child("HUD", true, false)
		if hud and hud.has_method("_cycle_idle_worker"):
			hud._cycle_idle_worker()

func _on_switch_unit_type() -> void:
	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	if _is_drone_mode():
		# Switch to human farm workers
		var workers := get_tree().get_nodes_in_group("farmers")
		if not workers.is_empty() and is_instance_valid(workers[0]):
			if farm_grid:
				farm_grid.deselect_all_drones()
			TaskManager.select_farmer(workers[0])
			AudioManager.play_farmer("select")
	else:
		# Switch to autonomous drone fleet
		if farm_grid and not farm_grid.drones.is_empty():
			TaskManager.deselect_all_farmers()
			farm_grid.select_drone_by_index(1)
			var d_lvl: int = BuildingManager.get_drone_level()
			if d_lvl < 2:
				active_category = "tools"
				selected_category_items["tools"] = "plow"
				selected_tool = "plow"
		else:
			AudioManager.play_ui("error")
			LogManager.log_event("buildings", "Build a Drone Landing Pad in Agri-Shop to get drones!", "🛸", Color(1.0, 0.4, 0.4))

func show_hotbar_feedback(msg: String, col: Color = Color.WHITE) -> void:
	if worker_header_label:
		worker_header_label.text = msg
	LogManager.log_event("general", msg, "🛸", col)
	AudioManager.play_ui("click")

var is_tray_open: bool:
	get:
		return visible

func _on_worker_selection_changed(_selected_workers: Array) -> void:
	_update_visibility_from_selection()

func _update_visibility_from_selection() -> void:
	var selected: Array = TaskManager.get_selected_farmers()
	var sel_drone: FarmDrone = _get_selected_drone()
	var has_selection: bool = (selected.size() > 0) or (sel_drone != null)
	visible = has_selection
	if has_selection:
		_update_unit_header(selected, sel_drone)
		_update_category_slots_display()
		_highlight_active_selection()
		_update_affordability()
	else:
		_close_flyout()
		Input.set_custom_mouse_cursor(null)
		if hover_card and hover_card.visible:
			hover_card.visible = false
		if hover_timer and not hover_timer.is_stopped():
			hover_timer.stop()

func _update_unit_header(selected: Array, sel_drone: FarmDrone = null) -> void:
	if not _unit_pill_btn:
		return
	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	var active_drone_count: int = farm_grid.drones.size() if (farm_grid and "drones" in farm_grid) else 0

	if sel_drone != null:
		var d_lvl := sel_drone.get_level()
		var crop_disp: String = str(Data.get_crop(sel_drone.crop_type).get("display_name", sel_drone.crop_type))
		_unit_pill_btn.text = "🛸 %s (Lv.%d)" % [sel_drone.get_drone_name(), d_lvl]
		_unit_pill_btn.tooltip_text = "%s (Lv.%d)\nClick to cycle to next drone" % [sel_drone.get_drone_name(), d_lvl]
		_style_capsule_button(_unit_pill_btn, true, false)

		_unit_switch_type_btn.text = "👨‍🌾 Workers"
		_unit_switch_type_btn.tooltip_text = "Switch command to human farm workers"
		_unit_switch_type_btn.visible = true
		_style_capsule_button(_unit_switch_type_btn, false, true)

		# If Lv.1, ensure selected tool in slot 2 is valid for Lv.1 (e.g. plow)
		if d_lvl < 2 and selected_category_items.get("tools", "") in ["auto_loop", "plant", "harvest"]:
			selected_category_items["tools"] = "plow"
			if selected_tool in ["auto_loop", "plant", "harvest"]:
				selected_tool = "plow"

		if worker_header_label:
			var task_status: String = "Plow & Water" if d_lvl == 1 else ("Seeder & Spray" if d_lvl == 2 else "Full Harvest Loop")
			worker_header_label.text = "🛸 %s Ready (Lv.%d %s) • Field: %s" % [
				sel_drone.get_drone_name(),
				d_lvl,
				task_status,
				("%d Plots" % sel_drone.zone.size()) if not sel_drone.zone.is_empty() else "None (Drag Box on Farm)"
			]
	else:
		var w_name: String = "Worker 1"
		if selected.size() == 1:
			var w = selected[0]
			if is_instance_valid(w):
				if "worker_name" in w:
					w_name = str(w.worker_name)
				elif "worker_id" in w:
					w_name = "Worker %d" % int(w.worker_id)
				elif w.has_method("get") and w.get("name"):
					w_name = str(w.name)
			_unit_pill_btn.text = "👨‍🌾 %s" % w_name
			_unit_pill_btn.tooltip_text = "Click to cycle to next worker"
		else:
			_unit_pill_btn.text = "👨‍🌾 Squad (%d)" % selected.size()
			_unit_pill_btn.tooltip_text = "Click to cycle workers"
		_style_capsule_button(_unit_pill_btn, false, false)

		_unit_switch_type_btn.text = "🛸 Drones"
		_unit_switch_type_btn.visible = (active_drone_count > 0)
		_unit_switch_type_btn.tooltip_text = "Switch command to autonomous drone fleet"
		_style_capsule_button(_unit_switch_type_btn, true, true)
		if worker_header_label:
			worker_header_label.text = "👨‍🌾 %s Ready • Click Slot to Choose & Click/Drag Field" % w_name

func _update_worker_header(selected: Array) -> void:
	_update_unit_header(selected, _get_selected_drone())

func open_tray() -> void:
	visible = true
	var selected: Array = TaskManager.get_selected_farmers()
	_update_unit_header(selected, _get_selected_drone())

func close_tray() -> void:
	_close_flyout()
	Input.set_custom_mouse_cursor(null)
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

	# 1. Floating Hover Info Card (Minecraft tooltip style)
	_setup_hover_card(vbox)

	# 2. Horizontal Flyout Selector Drawer (opens right above hotbar)
	_setup_flyout_drawer(vbox)

	# 3. Docked Minecraft-Style Primary Hotbar
	_setup_primary_dock(vbox)

func _setup_primary_dock(parent: VBoxContainer) -> void:
	tray_panel = PanelContainer.new()
	tray_panel.name = "PrimaryHotbarPanel"
	tray_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# No background container - pure floating square boxes!
	var empty_style := StyleBoxEmpty.new()
	tray_panel.add_theme_stylebox_override("panel", empty_style)
	parent.add_child(tray_panel)

	var tray_vbox := VBoxContainer.new()
	tray_vbox.name = "TrayVBox"
	tray_vbox.add_theme_constant_override("separation", 0)
	tray_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_panel.add_child(tray_vbox)

	# Hidden header labels preserved for automated test compatibility
	worker_header_label = Label.new()
	worker_header_label.name = "WorkerHeaderLabel"
	worker_header_label.visible = false
	worker_header_label.text = "👨‍🌾 Worker Command Hotbar"
	tray_vbox.add_child(worker_header_label)

	close_btn = Button.new()
	close_btn.name = "CloseWorkerHotbarButton"
	close_btn.visible = false
	close_btn.pressed.connect(func(): close_tray())
	tray_vbox.add_child(close_btn)

	# Unit Switcher Bar (Switch between workers and individual drones seamlessly!)
	var unit_bar := HBoxContainer.new()
	unit_bar.name = "UnitSwitcherBar"
	unit_bar.add_theme_constant_override("separation", 3)
	unit_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	unit_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_vbox.add_child(unit_bar)

	_unit_prev_btn = Button.new()
	_unit_prev_btn.name = "UnitPrevBtn"
	_unit_prev_btn.custom_minimum_size = Vector2(18, 20)
	_unit_prev_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unit_prev_btn.expand_icon = true
	if tex_tab_arrow_left:
		_unit_prev_btn.icon = tex_tab_arrow_left
	else:
		_unit_prev_btn.text = "◀"
	_style_arrow_button(_unit_prev_btn, true)
	_unit_prev_btn.pressed.connect(_on_cycle_unit_prev)
	unit_bar.add_child(_unit_prev_btn)

	_unit_pill_btn = Button.new()
	_unit_pill_btn.name = "UnitPillBtn"
	_unit_pill_btn.text = "👨‍🌾 Worker 1"
	_unit_pill_btn.custom_minimum_size = Vector2(104, 20)
	_style_capsule_button(_unit_pill_btn, false, false)
	_unit_pill_btn.pressed.connect(_on_cycle_unit_next)
	unit_bar.add_child(_unit_pill_btn)

	_unit_next_btn = Button.new()
	_unit_next_btn.name = "UnitNextBtn"
	_unit_next_btn.custom_minimum_size = Vector2(18, 20)
	_unit_next_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unit_next_btn.expand_icon = true
	if tex_tab_arrow_right:
		_unit_next_btn.icon = tex_tab_arrow_right
	else:
		_unit_next_btn.text = "▶"
	_style_arrow_button(_unit_next_btn, false)
	_unit_next_btn.pressed.connect(_on_cycle_unit_next)
	unit_bar.add_child(_unit_next_btn)

	_unit_switch_type_btn = Button.new()
	_unit_switch_type_btn.name = "UnitSwitchTypeBtn"
	_unit_switch_type_btn.text = "🛸 Drones"
	_unit_switch_type_btn.custom_minimum_size = Vector2(64, 20)
	_style_capsule_button(_unit_switch_type_btn, true, true)
	_unit_switch_type_btn.pressed.connect(_on_switch_unit_type)
	unit_bar.add_child(_unit_switch_type_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 3)
	tray_vbox.add_child(spacer)

	# Minecraft-style Hotbar Slots Row
	var slots_hbox := HBoxContainer.new()
	slots_hbox.name = "CategorySlotsHBox"
	slots_hbox.add_theme_constant_override("separation", 4)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_vbox.add_child(slots_hbox)

	for cat_id in CATEGORY_ORDER:
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
		sbt.content_margin_left = 3
		sbt.content_margin_right = 3
		sbt.content_margin_top = 3
		sbt.content_margin_bottom = 3
		if is_active:
			sbt.modulate_color = Color(1.25, 1.15, 0.85)
		elif is_hover:
			sbt.modulate_color = Color(1.12, 1.08, 1.0)
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

func _create_box_frame(box_size: Vector2 = Vector2(36, 36), is_active: bool = false) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = tex_light_box if is_active else tex_dark_box
	np.patch_margin_left = 6
	np.patch_margin_top = 6
	np.patch_margin_right = 6
	np.patch_margin_bottom = 6
	np.custom_minimum_size = box_size
	np.size = box_size
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return np

func _create_category_slot_button(cat_data: Dictionary) -> Button:
	var cat_id: String = cat_data.id
	var btn := Button.new()
	btn.name = "CategorySlot_" + cat_id
	btn.custom_minimum_size = Vector2(46, 46) # Pure square box like Minecraft!
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var s_norm := _create_stylebox_from_texture(tex_dark_box, false, false)
	var s_hov := _create_stylebox_from_texture(tex_light_box, false, true)
	var s_press := _create_stylebox_from_texture(tex_light_box, true, false)
	btn.add_theme_stylebox_override("normal", s_norm)
	btn.add_theme_stylebox_override("hover", s_hov)
	btn.add_theme_stylebox_override("pressed", s_press)

	# CenterContainer ensures the icon is 100% symmetrically centered INSIDE the box!
	var center_box := CenterContainer.new()
	center_box.name = "CenterContainer"
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center_box)
	category_icons[cat_id] = center_box

	# Corner Hotkey Number (1, 2, 3) like Minecraft slot counts
	var key_lbl := Label.new()
	key_lbl.text = str(cat_data.key_num)
	key_lbl.add_theme_font_size_override("font_size", 9)
	key_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50, 0.85))
	key_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	key_lbl.offset_left = 4
	key_lbl.offset_top = 2
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(key_lbl)

	# Corner Price Tag in bottom-right (Minecraft stack count style!)
	var price_lbl := Label.new()
	price_lbl.name = "PriceLabel"
	price_lbl.add_theme_font_size_override("font_size", 8)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40))
	price_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	price_lbl.add_theme_constant_override("shadow_offset_x", 1)
	price_lbl.add_theme_constant_override("shadow_offset_y", 1)
	price_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	price_lbl.offset_right = -3
	price_lbl.offset_bottom = -2
	price_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	price_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(price_lbl)
	category_price_labels[cat_id] = price_lbl

	# Dummy labels to safely satisfy tests/properties without showing text on the hotbar
	var dummy_title := Label.new()
	dummy_title.visible = false
	btn.add_child(dummy_title)
	category_labels[cat_id] = dummy_title

	var dummy_sub := Label.new()
	dummy_sub.visible = false
	btn.add_child(dummy_sub)
	category_sublabels[cat_id] = dummy_sub

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

	if ResourceLoader.exists("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"):
		flyout_drawer.add_theme_stylebox_override("panel", load("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres"))
	elif ResourceLoader.exists("res://assets/sprites/hud/TopRight/BrownBox.tres"):
		flyout_drawer.add_theme_stylebox_override("panel", load("res://assets/sprites/hud/TopRight/BrownBox.tres"))
	else:
		var draw_style := StyleBoxFlat.new()
		draw_style.bg_color = Color(0.12, 0.08, 0.05, 0.96)
		draw_style.border_width_left = 2
		draw_style.border_width_top = 2
		draw_style.border_width_right = 2
		draw_style.border_width_bottom = 2
		draw_style.border_color = Color(0.85, 0.68, 0.30, 0.95)
		draw_style.corner_radius_top_left = 5
		draw_style.corner_radius_top_right = 5
		draw_style.corner_radius_bottom_left = 5
		draw_style.corner_radius_bottom_right = 5
		draw_style.shadow_size = 6
		draw_style.shadow_color = Color(0, 0, 0, 0.6)
		draw_style.content_margin_left = 6
		draw_style.content_margin_right = 6
		draw_style.content_margin_top = 4
		draw_style.content_margin_bottom = 4
		flyout_drawer.add_theme_stylebox_override("panel", draw_style)
	parent.add_child(flyout_drawer)

	var vbox := VBoxContainer.new()
	vbox.name = "FlyoutVBox"
	vbox.add_theme_constant_override("separation", 3)
	flyout_drawer.add_child(vbox)

	# Minimal header row
	var h_row := HBoxContainer.new()
	h_row.name = "FlyoutHeaderRow"
	vbox.add_child(h_row)

	flyout_header_label = Label.new()
	flyout_header_label.text = "🌱 SELECT CROP"
	flyout_header_label.add_theme_font_size_override("font_size", 9)
	flyout_header_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	flyout_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_row.add_child(flyout_header_label)

	var min_btn := Button.new()
	min_btn.text = "✕"
	min_btn.custom_minimum_size = Vector2(18, 18)
	min_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"):
		min_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"))
		min_btn.add_theme_stylebox_override("hover", load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres"))
		min_btn.add_theme_stylebox_override("pressed", load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres"))
	elif ResourceLoader.exists("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"):
		min_btn.add_theme_stylebox_override("normal", load("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
		min_btn.add_theme_stylebox_override("hover", load("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
		min_btn.add_theme_stylebox_override("pressed", load("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	min_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	min_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60))
	min_btn.pressed.connect(func(): _close_flyout())
	h_row.add_child(min_btn)

	# Horizontal row of Minecraft-style square item boxes!
	flyout_items_vbox = HBoxContainer.new()
	flyout_items_vbox.name = "ItemsHBox"
	flyout_items_vbox.add_theme_constant_override("separation", 4)
	flyout_items_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(flyout_items_vbox)

func _setup_hover_card(parent: VBoxContainer) -> void:
	hover_card = PanelContainer.new()
	hover_card.name = "CropHoverCard"
	hover_card.visible = false
	hover_card.custom_minimum_size = Vector2(340, 0)
	hover_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tex_info_box != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex_info_box
		sbt.texture_margin_left = 24
		sbt.texture_margin_right = 24
		sbt.texture_margin_top = 47
		sbt.texture_margin_bottom = 16
		sbt.content_margin_left = 22
		sbt.content_margin_right = 22
		sbt.content_margin_top = 10
		sbt.content_margin_bottom = 16
		hover_card.add_theme_stylebox_override("panel", sbt)
	else:
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.12, 0.08, 0.05, 0.96)
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color(0.85, 0.68, 0.30, 0.95)
		card_style.corner_radius_top_left = 5
		card_style.corner_radius_top_right = 5
		card_style.corner_radius_bottom_left = 5
		card_style.corner_radius_bottom_right = 5
		card_style.shadow_size = 6
		card_style.shadow_color = Color(0, 0, 0, 0.55)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		hover_card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(hover_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 0)
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_card.add_child(card_vbox)

	# 1. Header row (sits cleanly inside top parchment box, height 28px)
	var header_hbox := HBoxContainer.new()
	header_hbox.custom_minimum_size = Vector2(0, 28)
	header_hbox.add_theme_constant_override("separation", 6)
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(header_hbox)

	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(24, 24)
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_hbox.add_child(icon_center)

	card_icon = Label.new()
	card_icon.text = "🌱"
	card_icon.add_theme_font_size_override("font_size", 14)
	card_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(card_icon)

	card_texture = TextureRect.new()
	card_texture.custom_minimum_size = Vector2(22, 22)
	card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_texture.visible = false
	card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(card_texture)

	card_title = Label.new()
	card_title.text = "Item Name"
	card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_title.add_theme_font_size_override("font_size", 14)
	card_title.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1.0))
	card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_hbox.add_child(card_title)

	card_price = Label.new()
	card_price.text = "₱0"
	card_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_price.add_theme_font_size_override("font_size", 13)
	card_price.add_theme_color_override("font_color", Color(0.48, 0.28, 0.08, 1.0))
	card_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_hbox.add_child(card_price)

	# 2. Wooden bar spacer (skips directly over the 10px horizontal dividing bar)
	var bar_spacer := Control.new()
	bar_spacer.custom_minimum_size = Vector2(0, 10)
	bar_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(bar_spacer)

	# 3. Content VBox (sits inside bottom parchment box)
	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 2)
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(content_vbox)

	card_type = Label.new()
	card_type.text = "Type description"
	card_type.add_theme_font_size_override("font_size", 11)
	card_type.add_theme_color_override("font_color", Color(0.38, 0.24, 0.12, 1.0))
	card_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(card_type)

	card_stats = Label.new()
	card_stats.text = "Stats..."
	card_stats.add_theme_font_size_override("font_size", 12)
	card_stats.add_theme_color_override("font_color", Color(0.26, 0.16, 0.10, 1.0))
	card_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(card_stats)

	card_desc = Label.new()
	card_desc.text = "Description text..."
	card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_desc.custom_minimum_size = Vector2(296, 0)
	card_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_desc.add_theme_font_size_override("font_size", 12)
	card_desc.add_theme_color_override("font_color", Color(0.20, 0.14, 0.08, 1.0))
	card_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(card_desc)

	card_region_title = Label.new()
	card_region_title.text = "📍 Regional Affinity"
	card_region_title.add_theme_font_size_override("font_size", 12)
	card_region_title.add_theme_color_override("font_color", Color(0.18, 0.40, 0.15, 1.0))
	card_region_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(card_region_title)

	card_buffs = Label.new()
	card_buffs.text = "✔ Buffs"
	card_buffs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_buffs.custom_minimum_size = Vector2(296, 0)
	card_buffs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_buffs.add_theme_font_size_override("font_size", 12)
	card_buffs.add_theme_color_override("font_color", Color(0.12, 0.45, 0.15, 1.0))
	card_buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(card_buffs)

	card_debuffs = Label.new()
	card_debuffs.text = "⚠️ Debuffs"
	card_debuffs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_debuffs.custom_minimum_size = Vector2(296, 0)
	card_debuffs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_debuffs.add_theme_font_size_override("font_size", 12)
	card_debuffs.add_theme_color_override("font_color", Color(0.65, 0.18, 0.12, 1.0))
	card_debuffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(card_debuffs)

# ---------------------------------------------------------------------------
# Category Slot Interactions & Flyout Populating
# ---------------------------------------------------------------------------
func _on_category_slot_pressed(cat_id: String) -> void:
	if _is_drone_mode() and _is_category_locked_for_unit(cat_id):
		AudioManager.play_ui("error")
		if cat_id == "seeds":
			show_hotbar_feedback("🔒 Drone Seeder Locked: Requires Drone Command Hangar Lv. 2", Color(1.0, 0.45, 0.45))
		elif cat_id == "treatments":
			show_hotbar_feedback("🔒 Drone IPM Locked: Requires Drone Command Hangar Lv. 2", Color(1.0, 0.45, 0.45))
		return

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
	var c_data: Dictionary = _get_active_category_data(cat_id)
	if c_data.is_empty():
		return
	flyout_header_label.text = "%s SELECT %s" % [c_data.get("icon", "🌱"), c_data.get("title", cat_id.to_upper())]

	# Clear previous items
	for ch in flyout_items_vbox.get_children():
		flyout_items_vbox.remove_child(ch)
		ch.queue_free()
	flyout_item_buttons.clear()

	var sel_drone: FarmDrone = _get_selected_drone() if _is_drone_mode() else null
	var cur_sel: String = ""
	if sel_drone != null:
		if cat_id == "seeds":
			cur_sel = sel_drone.crop_type
		elif cat_id == "tools":
			cur_sel = selected_category_items.get("tools", "plow" if _get_drone_capability_level() < 2 else "auto_loop")
		elif cat_id == "treatments":
			cur_sel = selected_category_items.get("treatments", "spray_chemical")
	else:
		cur_sel = selected_category_items.get(cat_id, "")

	for item in c_data.get("items", []):
		var item_id: String = item.id
		if cat_id == "seeds" and not BuildingManager.is_crop_unlocked(item_id):
			continue
		var is_locked: bool = _is_flyout_item_locked_for_drone(item_id)
		var btn := Button.new()
		btn.name = "FlyoutItem_" + item_id
		btn.custom_minimum_size = Vector2(40, 40) # Pure square box like Minecraft!
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		var is_cur: bool = (item_id == cur_sel)
		var norm_tex: Texture2D = _get_slot_texture(is_cur)
		var hov_tex: Texture2D = _get_slot_texture(true)
		var s_item := _create_stylebox_from_texture(norm_tex, is_cur, false)
		var s_item_hov := _create_stylebox_from_texture(hov_tex, is_cur, true)
		btn.add_theme_stylebox_override("normal", s_item)
		btn.add_theme_stylebox_override("hover", s_item_hov)
		btn.add_theme_stylebox_override("pressed", s_item_hov)

		if is_locked:
			btn.modulate = Color(0.65, 0.65, 0.75, 0.75)

		# CenterContainer inside the square flyout button guarantees perfect centering IN THE BOX!
		var center_box := CenterContainer.new()
		center_box.name = "CenterContainer"
		center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(center_box)

		# Thumbnail inside the center box
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
				center_box.add_child(tr)
			else:
				var ic := Label.new()
				ic.text = item.icon
				ic.add_theme_font_size_override("font_size", 16)
				ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				center_box.add_child(ic)
		elif (cat_id == "tools" or cat_id == "treatments") and get_tool_sprite_texture(item_id) != null:
			var t_tex: Texture2D = get_tool_sprite_texture(item_id)
			var tr := TextureRect.new()
			tr.texture = t_tex
			tr.custom_minimum_size = Vector2(26, 26)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center_box.add_child(tr)
		else:
			var ic := Label.new()
			ic.text = item.icon
			ic.add_theme_font_size_override("font_size", 16)
			ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center_box.add_child(ic)

		# If locked for drone, overlay padlock icon
		if is_locked:
			var lock_badge := Label.new()
			lock_badge.text = "🔒"
			lock_badge.add_theme_font_size_override("font_size", 10)
			lock_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			lock_badge.offset_left = -14
			lock_badge.offset_top = 2
			lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(lock_badge)

		# Price label at bottom right (Minecraft stack count style!)
		if item.cost > 0:
			var price_lbl := Label.new()
			price_lbl.name = "PriceLabel"
			price_lbl.text = "₱%d" % item.cost
			price_lbl.add_theme_font_size_override("font_size", 8)
			price_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40))
			price_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			price_lbl.add_theme_constant_override("shadow_offset_x", 1)
			price_lbl.add_theme_constant_override("shadow_offset_y", 1)
			price_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			price_lbl.offset_right = -3
			price_lbl.offset_bottom = -2
			price_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			price_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
			price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(price_lbl)

		# Signals
		btn.pressed.connect(func(): _on_flyout_item_selected(cat_id, item_id))
		btn.mouse_entered.connect(func(): _on_item_hover_entered(item_id))
		btn.mouse_exited.connect(func(): _on_item_hover_exited(item_id))

		flyout_items_vbox.add_child(btn)
		flyout_item_buttons[item_id] = btn

	# If there are still locked crops, display an expansion shortcut to the Agri-Shop Seeds tab!
	if cat_id == "seeds" and BuildingManager.get_unlocked_crops().size() < Data.CROPS.size():
		var shop_btn := Button.new()
		shop_btn.name = "FlyoutItem_ShopSeeds"
		shop_btn.custom_minimum_size = Vector2(40, 40)
		shop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		shop_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shop_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		shop_btn.tooltip_text = "Unlock more seed varieties in the Agri-Shop!"

		var norm_tex: Texture2D = _get_slot_texture(false)
		var hov_tex: Texture2D = _get_slot_texture(true)
		var s_item := _create_stylebox_from_texture(norm_tex, false, false)
		var s_item_hov := _create_stylebox_from_texture(hov_tex, false, true)
		shop_btn.add_theme_stylebox_override("normal", s_item)
		shop_btn.add_theme_stylebox_override("hover", s_item_hov)
		shop_btn.add_theme_stylebox_override("pressed", s_item_hov)

		var center_box := CenterContainer.new()
		center_box.name = "CenterContainer"
		center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shop_btn.add_child(center_box)

		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", -2)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_box.add_child(vb)

		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_font_size_override("font_size", 13)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lock_lbl)

		var txt_lbl := Label.new()
		txt_lbl.text = "+Shop"
		txt_lbl.add_theme_font_size_override("font_size", 8)
		txt_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		txt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		txt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(txt_lbl)

		shop_btn.pressed.connect(func():
			_close_flyout()
			var shop_panel = get_tree().root.find_child("ShopPanel", true, false)
			if shop_panel:
				if shop_panel.has_method("open_to_tab"):
					shop_panel.open_to_tab("Seeds")
				else:
					shop_panel.visible = true
		)
		flyout_items_vbox.add_child(shop_btn)

	flyout_drawer.visible = true

func _on_flyout_item_selected(cat_id: String, item_id: String) -> void:
	if _is_drone_mode() and _is_flyout_item_locked_for_drone(item_id):
		AudioManager.play_ui("error")
		var req_lvl: int = 2 if item_id in ["plant", "auto_loop"] else 3
		show_hotbar_feedback("🔒 Feature Locked: Requires Drone Command Hangar Lv. %d" % req_lvl, Color(1.0, 0.45, 0.45))
		return

	selected_category_items[cat_id] = item_id
	active_category = cat_id

	if _is_drone_mode():
		var sel_d: FarmDrone = _get_selected_drone()
		if sel_d:
			if cat_id == "seeds":
				sel_d.set_crop(item_id)
				select_tool(item_id)
				var c_info := Data.get_crop(item_id)
				show_hotbar_feedback("🛸 %s crop set to %s!" % [sel_d.get_drone_name(), c_info.get("display_name", item_id)], Color(0.4, 0.9, 0.5))
			elif cat_id == "tools":
				match item_id:
					"auto_loop", "plow", "plant", "water", "harvest":
						sel_d.set_directive_mode(item_id)
						match item_id:
							"auto_loop": show_hotbar_feedback("🛸 %s set to Auto-Farm Loop!" % sel_d.get_drone_name(), Color(0.3, 0.8, 1.0))
							"plow": show_hotbar_feedback("🛸 %s set to Plow Ground Only!" % sel_d.get_drone_name(), Color(0.9, 0.7, 0.3))
							"plant": show_hotbar_feedback("🛸 %s set to Sow Crops Only!" % sel_d.get_drone_name(), Color(0.4, 0.9, 0.4))
							"water": show_hotbar_feedback("🛸 %s set to Water Soil Only!" % sel_d.get_drone_name(), Color(0.4, 0.7, 1.0))
							"harvest": show_hotbar_feedback("🛸 %s set to Harvest Crops Only!" % sel_d.get_drone_name(), Color(1.0, 0.8, 0.2))
					"drone_zone":
						show_hotbar_feedback("🎯 Drag a box across the farm to set %s's zone!" % sel_d.get_drone_name(), Color(1.0, 0.9, 0.4))
					"drone_whole_farm":
						var fg = get_tree().root.find_child("FarmGrid", true, false)
						if fg:
							var all_unlocked: Array[Vector2i] = fg.get_unlocked_tiles()
							sel_d.deploy(all_unlocked, sel_d.crop_type)
							show_hotbar_feedback("🌐 %s deployed to Whole Farm (%d plots)!" % [sel_d.get_drone_name(), all_unlocked.size()], Color(0.3, 1.0, 0.6))
					"drone_recall":
						sel_d.recall()
						show_hotbar_feedback("🏠 %s returning to dock..." % sel_d.get_drone_name(), Color(0.8, 0.8, 0.8))
				select_tool(item_id)
			elif cat_id == "treatments":
				sel_d.set_ipm_method(item_id)
				select_tool(item_id)
				show_hotbar_feedback("🛸 %s IPM set to %s" % [sel_d.get_drone_name(), item_id], Color(0.7, 0.5, 1.0))
	else:
		select_tool(item_id)

	_update_category_slots_display()
	_highlight_active_selection()
	_close_flyout()

func _update_category_slots_display() -> void:
	var sel_drone: FarmDrone = _get_selected_drone() if _is_drone_mode() else null
	for cat_id in CATEGORY_ORDER:
		var c_data: Dictionary = _get_active_category_data(cat_id)
		var is_locked: bool = _is_category_locked_for_unit(cat_id)
		var cur_item_id: String = ""
		if sel_drone != null:
			if cat_id == "seeds":
				cur_item_id = sel_drone.crop_type
			elif cat_id == "tools":
				cur_item_id = selected_category_items.get("tools", "plow" if _get_drone_capability_level() < 2 else "auto_loop")
			elif cat_id == "treatments":
				cur_item_id = selected_category_items.get("treatments", "spray_chemical")
		else:
			cur_item_id = selected_category_items.get(cat_id, "")

		var icon_container: Control = category_icons.get(cat_id, null)
		if not is_instance_valid(icon_container):
			continue

		var is_cur_cat: bool = (cat_id == active_category)
		var btn: Button = category_slots.get(cat_id, null)
		if is_instance_valid(btn):
			var norm_tex: Texture2D = _get_slot_texture(is_cur_cat)
			var hov_tex: Texture2D = _get_slot_texture(true)
			var s_norm := _create_stylebox_from_texture(norm_tex, is_cur_cat, false)
			var s_hov := _create_stylebox_from_texture(hov_tex, is_cur_cat, true)
			btn.add_theme_stylebox_override("normal", s_norm)
			btn.add_theme_stylebox_override("hover", s_hov)
			if is_locked:
				btn.modulate = Color(0.70, 0.70, 0.80, 0.85)
			else:
				btn.modulate = Color.WHITE

		for ch in icon_container.get_children():
			ch.queue_free()

		var price_lbl: Label = category_price_labels.get(cat_id, null)

		if is_locked:
			var lock_ic := Label.new()
			lock_ic.text = "🔒"
			lock_ic.add_theme_font_size_override("font_size", 16)
			lock_ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_container.add_child(lock_ic)
			if is_instance_valid(price_lbl):
				price_lbl.text = ""
			continue

		var item_data: Dictionary = {}
		for it in c_data.get("items", []):
			if it.id == cur_item_id:
				item_data = it
				break

		if cat_id == "seeds":
			var tex := get_crop_sprite_texture(cur_item_id)
			if tex != null:
				var tr := TextureRect.new()
				tr.texture = tex
				tr.custom_minimum_size = Vector2(28, 28)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_container.add_child(tr)
			else:
				var ic := Label.new()
				ic.text = item_data.get("icon", "🌱")
				ic.add_theme_font_size_override("font_size", 18)
				ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_container.add_child(ic)
		elif (cat_id == "tools" or cat_id == "treatments") and get_tool_sprite_texture(cur_item_id) != null:
			var t_tex: Texture2D = get_tool_sprite_texture(cur_item_id)
			var tr := TextureRect.new()
			tr.texture = t_tex
			tr.custom_minimum_size = Vector2(28, 28)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_container.add_child(tr)
		else:
			var ic := Label.new()
			ic.text = item_data.get("icon", "⛏️")
			ic.add_theme_font_size_override("font_size", 18)
			ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_container.add_child(ic)

		# Update corner price tag for this category slot
		if is_instance_valid(price_lbl):
			var cost: int = int(item_data.get("cost", 0))
			if cost > 0:
				price_lbl.text = "₱%d" % cost
			else:
				price_lbl.text = ""

func _highlight_active_selection() -> void:
	for cat_id in category_slots:
		var btn: Button = category_slots[cat_id]
		if not is_instance_valid(btn):
			continue
		var is_cur: bool = (cat_id == active_category)
		var is_locked: bool = _is_category_locked_for_unit(cat_id)
		var norm_tex: Texture2D = _get_slot_texture(is_cur)
		var hov_tex: Texture2D = _get_slot_texture(true)
		var s_norm := _create_stylebox_from_texture(norm_tex, is_cur, false)
		var s_hov := _create_stylebox_from_texture(hov_tex, is_cur, true)
		btn.add_theme_stylebox_override("normal", s_norm)
		btn.add_theme_stylebox_override("hover", s_hov)
		btn.modulate = Color(0.70, 0.70, 0.80, 0.85) if is_locked else Color.WHITE

func select_tool(tool_id: String) -> void:
	selected_tool = tool_id

	for cat_id in CATEGORY_ORDER:
		var c_data: Dictionary = _get_active_category_data(cat_id)
		for it in c_data.get("items", []):
			if it.id == tool_id:
				active_category = cat_id
				selected_category_items[cat_id] = tool_id
				break

	_update_category_slots_display()
	_highlight_active_selection()
	tool_selected.emit(tool_id)
	if tool_id in CROP_KEYS:
		crop_selected.emit(tool_id)

	if tool_id == "inspect":
		var tex := get_tool_sprite_texture("inspect")
		if tex:
			Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(19, 11))
	elif tool_id == "cancel_task":
		var tex := get_tool_sprite_texture("cancel_task")
		if tex:
			Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		Input.set_custom_mouse_cursor(null)

	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	if farm_grid and farm_grid.drag_overlay:
		farm_grid.drag_overlay.queue_redraw()

func select_crop(crop_key: String) -> void:
	select_tool(crop_key)

func _update_affordability() -> void:
	var cur_cash: int = EconomyManager.cash
	for cat_id in CATEGORY_ORDER:
		var c_data: Dictionary = _get_active_category_data(cat_id)
		for it in c_data.get("items", []):
			var btn: Button = flyout_item_buttons.get(it.id, null)
			if is_instance_valid(btn):
				if it.cost > cur_cash:
					btn.modulate = Color(0.9, 0.65, 0.65, 0.8)
				else:
					btn.modulate = Color.WHITE

# ---------------------------------------------------------------------------
# Hover Card Timing & Display
# ---------------------------------------------------------------------------
func _on_category_hover_entered(cat_id: String) -> void:
	if _is_drone_mode() and _is_category_locked_for_unit(cat_id):
		hovered_item_id = "drone_locked_" + cat_id
		_populate_drone_locked_hover(cat_id)
		if hover_card:
			hover_card.visible = true
		return
	var item_id: String = selected_category_items.get(cat_id, "")
	_on_item_hover_entered(item_id)

func _on_item_hover_entered(item_id: String) -> void:
	if item_id.is_empty():
		return
	hovered_item_id = item_id
	if _is_drone_mode() and _is_flyout_item_locked_for_drone(item_id):
		_populate_drone_locked_item_hover(item_id)
		if hover_card:
			hover_card.visible = true
		return
	if hover_card and hover_card.visible:
		_populate_hover_card(item_id)
	else:
		hover_timer.start(HOVER_DELAY)

func _on_item_hover_exited(item_id: String) -> void:
	if hovered_item_id == item_id or hovered_item_id.begins_with("drone_locked_"):
		hover_timer.stop()
		hovered_item_id = ""
		if hover_card:
			hover_card.visible = false

func _on_hover_timer_timeout() -> void:
	if not hovered_item_id.is_empty():
		_populate_hover_card(hovered_item_id)
		if hover_card:
			hover_card.visible = true

func _populate_drone_locked_hover(cat_id: String) -> void:
	if not hover_card:
		return
	card_texture.visible = false
	card_icon.visible = true
	card_icon.text = "🔒"
	card_region_title.visible = true
	card_buffs.visible = false
	card_debuffs.visible = false
	var d_lvl := _get_drone_capability_level()
	if cat_id == "seeds":
		card_title.text = "Automated Seeder (Locked)"
		card_price.text = "Req. Hangar Lv.2"
		card_type.text = "Drone Avionics Module"
		card_stats.text = "Current Fleet: Level %d (Basic Tillage)" % d_lvl
		card_desc.text = "Automated seed sowing requires Drone Command Hangar Lv. 2. At Level 1, drones only perform basic soil tillage (plowing and watering). Upgrade the Hangar in Agri-Shop to unlock precision seeding!"
		card_region_title.text = "🔧 Upgrade in Agri-Shop ➜ Machinery"
	elif cat_id == "treatments":
		card_title.text = "IPM Biocontrol Spray (Locked)"
		card_price.text = "Req. Hangar Lv.2"
		card_type.text = "Drone Avionics Module"
		card_stats.text = "Current Fleet: Level %d (Basic Tillage)" % d_lvl
		card_desc.text = "Automated pest eradication requires Drone Command Hangar Lv. 2. Upgrade the Hangar in the Agri-Shop to enable autonomous crop treatments."
		card_region_title.text = "🔧 Upgrade in Agri-Shop ➜ Machinery"

func _populate_drone_locked_item_hover(item_id: String) -> void:
	if not hover_card:
		return
	card_texture.visible = false
	card_icon.visible = true
	card_icon.text = "🔒"
	card_region_title.visible = true
	card_buffs.visible = false
	card_debuffs.visible = false
	var req_lvl: int = 2 if item_id in ["plant", "auto_loop"] else 3
	var d_lvl := _get_drone_capability_level()
	match item_id:
		"plant":
			card_title.text = "Sow Crops Directive (Locked)"
			card_price.text = "Req. Hangar Lv.2"
			card_type.text = "Autonomous Seeding Directive"
			card_stats.text = "Current Fleet: Level %d • Requires Level 2" % d_lvl
			card_desc.text = "Orders drone to sow designated seed varieties onto tilled soil. Requires Drone Command Hangar Lv. 2."
			card_region_title.text = "🔧 Upgrade in Agri-Shop ➜ Machinery"
		"harvest":
			card_title.text = "Harvest Crops Directive (Locked)"
			card_price.text = "Req. Hangar Lv.3"
			card_type.text = "Autonomous Harvesting Directive"
			card_stats.text = "Current Fleet: Level %d • Requires Level 3" % d_lvl
			card_desc.text = "Orders drone to reap ripe mature crops and deliver them directly to bodega storage. Requires Drone Command Hangar Lv. 3."
			card_region_title.text = "🔧 Upgrade in Agri-Shop ➜ Machinery"
		"auto_loop":
			card_title.text = "Auto-Farm Loop (Locked)"
			card_price.text = "Req. Hangar Lv.2+"
			card_type.text = "Autonomous Cycle Directive"
			card_stats.text = "Current Fleet: Level %d • Requires Level 2+" % d_lvl
			card_desc.text = "Full cycle automation requires at least Drone Command Hangar Lv. 2 (to seed) and Lv. 3 (to harvest)."
			card_region_title.text = "🔧 Upgrade in Agri-Shop ➜ Machinery"
		_:
			card_title.text = "Directive (Locked)"
			card_price.text = "Req. Hangar Lv.%d" % req_lvl
			card_type.text = "Drone Capability"
			card_stats.text = "Requires Level %d" % req_lvl
			card_desc.text = "Upgrade Drone Command Hangar in Agri-Shop to unlock."
			card_region_title.text = "🔧 Upgrade in Agri-Shop ➜ Machinery"

func _populate_hover_card(item_id: String) -> void:
	if item_id in CROP_KEYS:
		_populate_crop_hover(item_id)
	else:
		_populate_tool_or_treatment_hover(item_id)

func _populate_tool_or_treatment_hover(tool_id: String) -> void:
	var t_tex: Texture2D = get_tool_sprite_texture(tool_id)
	if t_tex != null:
		card_texture.texture = t_tex
		card_texture.visible = true
		card_icon.visible = false
	else:
		card_texture.visible = false
		card_icon.visible = true
	card_region_title.visible = false
	card_buffs.visible = false
	card_debuffs.visible = false

	match tool_id:
		"inspect":
			card_icon.text = "🔍"
			card_title.text = "Investigate & Soil Diagnostics"
			if card_price: card_price.text = "Free Action"
			card_type.text = "Farmer Diagnostic • Non-Destructive"
			card_stats.text = "Targets: Any Farm Plot or Standing Crop"
			card_desc.text = "Examines live soil diagnostics, moisture levels, crop growth stages, and pest infestations in the Tile Inspector without issuing labor commands."

		"plow":
			card_icon.text = "⛏️"
			card_title.text = "Farm Plow & Hoe"
			if card_price: card_price.text = "Free Tool"
			card_type.text = "Soil Preparation • Basic Action"
			card_stats.text = "Targets: Untilled Soil & Flood Recessions"
			card_desc.text = "Tills untilled earth, cleared plots, or receded floodplains into furrowed soil ready for seeds. Left-click or drag to assign."

		"water":
			card_icon.text = "💧"
			card_title.text = "Watering Can & Irrigation"
			if card_price: card_price.text = "Free Tool"
			card_type.text = "Soil Hydration • Basic Action"
			card_stats.text = "Targets: Planted Crops • +25% Soil Moisture"
			card_desc.text = "Hydrates parched crops to maintain optimal agronomic moisture. Crucial during heatwaves and El Niño droughts."

		"harvest":
			card_icon.text = "🧺"
			card_title.text = "Harvest Basket & Sickle"
			if card_price: card_price.text = "Free Tool"
			card_type.text = "Produce Gathering • Free Action"
			card_stats.text = "Targets: Ready Harvests & Early Salvages"
			card_desc.text = "Reaps mature crops or emergency-salvages threatened crops before disasters strike. Perennials regrow automatically!"

		"clear":
			card_icon.text = "🪓"
			card_title.text = "Obstacle Clearing Gear"
			if card_price: card_price.text = "₱50 / Plot"
			card_type.text = "Land Reclamation • Heavy Labor"
			card_stats.text = "Targets: Timber Trees, Pine Stumps & Rocks"
			card_desc.text = "Clears boulders and fells trees to expand tillable homestead land. Workers excavate the plot into bare soil ready for plowing."

		"spray_chemical":
			card_icon.text = "🧪"
			card_title.text = "Chemical Insecticide Spray"
			if card_price: card_price.text = "₱30 / Spray"
			card_type.text = "Crop Protection • Chemical Cure"
			card_stats.text = "Targets: Kuhol, Armyworm, Wilt, Bugs"
			card_desc.text = "Fast-acting chemical treatment that eliminates active pest infestations and immediately cures blighted crops."

		"spray_biological":
			card_icon.text = "🦆"
			card_title.text = "Biological IPM Management"
			if card_price: card_price.text = "₱45 / Spray"
			card_type.text = "Eco-Control • 100% Organic"
			card_stats.text = "Targets: Natural Biological Predators"
			card_desc.text = "Eco-friendly biocontrol deploying ducks and Trichoderma fungi. Completely preserves Grade A organic status."

		"auto_loop":
			card_icon.text = "🌀"
			card_title.text = "Auto-Farm Loop"
			if card_price: card_price.text = "Autonomous"
			card_type.text = "Drone Command • Full Automation"
			card_stats.text = "Plow ➜ Sow ➜ Water ➜ Treat ➜ Harvest"
			card_desc.text = "Orders this drone to continuously maintain its field zone: auto-plowing soil, planting designated seeds, watering dry plots, spraying pests, and harvesting mature crops to storage."

		"plant":
			card_icon.text = "🌱"
			card_title.text = "Sow Seeds Only"
			if card_price: card_price.text = "Drone Command"
			card_type.text = "Planting Automation"
			card_stats.text = "Targets: Furrowed Plots in Field Zone"
			card_desc.text = "Drone focuses solely on planting designated seeds on plowed plots within its zone without performing other farming tasks."

		"drone_zone":
			card_icon.text = "🎯"
			card_title.text = "Designate Field Zone"
			if card_price: card_price.text = "Free Action"
			card_type.text = "Zone Designation • Tactical"
			card_stats.text = "Click & Drag Box Across Farmland"
			card_desc.text = "Click and drag across your farm to set this specific drone's working area. Only this drone will operate within and highlight these plots."

		"drone_whole_farm":
			card_icon.text = "🌐"
			card_title.text = "Patrol Whole Farmland"
			if card_price: card_price.text = "1-Click Deploy"
			card_type.text = "Autonomous Coverage • Whole Farm"
			card_stats.text = "Targets: All Unlocked Farmland Plots"
			card_desc.text = "1-Click deployment: Orders this drone to patrol and maintain all unlocked farmland plots across your entire farm!"

		"drone_recall":
			card_icon.text = "🏠"
			card_title.text = "Return & Dock Drone"
			if card_price: card_price.text = "Standby"
			card_type.text = "Drone Command • Pad Docking"
			card_stats.text = "Returns to Drone Landing Pad"
			card_desc.text = "Directs this drone to immediately conclude field actions and return to its landing pad to stand by."

		_:
			card_icon.text = "🛠️"
			card_title.text = tool_id.capitalize()
			if card_price: card_price.text = ""
			card_type.text = "Farming Action"
			card_stats.text = "Field Command"
			card_desc.text = "Standard agricultural action."

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
	if card_price:
		card_price.text = "₱%d / Grove" % seed_cost if is_2x2 else "₱%d / Seed" % seed_cost

	var type_str: String = "Perennial Tree (2×2 Grove)" if is_2x2 else (
		"Perennial Living Shrub" if is_peren else "Annual Cultivated Crop"
	)
	card_type.text = type_str

	var growth_str: String = ("%dd (+%dd regrow)" % [g_days, reg_days]) if is_peren else ("%dd Cycle" % g_days)
	card_stats.text = "Growth: %s • Yield: %d • Base: ₱%d" % [growth_str, yield_qty, base_price]
	card_desc.text = c_data.get("description", "")

	var cur_reg: String = Data.current_region
	var reg_data: Dictionary = Data.get_region(cur_reg)
	var reg_short: String = reg_data.get("display_name", cur_reg.capitalize()).split("(")[0].strip_edges()
	card_region_title.visible = true
	card_region_title.text = "📍 Region: %s" % reg_short

	var analysis: Dictionary = get_regional_crop_analysis(crop_key, cur_reg)
	var buffs: Array = analysis.get("buffs", [])
	var debuffs: Array = analysis.get("debuffs", [])

	if buffs.size() > 0:
		card_buffs.visible = true
		card_buffs.text = buffs[0]
	else:
		card_buffs.visible = false

	if debuffs.size() > 0:
		card_debuffs.visible = true
		card_debuffs.text = debuffs[0]
	else:
		card_debuffs.visible = false

static func get_regional_crop_analysis(crop_key: String, region_key: String) -> Dictionary:
	var crop: Dictionary = Data.get_crop(crop_key)
	var region: Dictionary = Data.get_region(region_key)
	var reg_moisture: float = float(region.get("soil_moisture", 50))
	var hazards: Dictionary = region.get("hazards", {})
	var reg_short: String = region.get("display_name", region_key).split("(")[0].strip_edges()

	var buffs: Array[String] = []
	var debuffs: Array[String] = []

	var specialties: Array = LeaderboardManager.REGION_SPECIALTIES.get(region_key, [])
	if specialties.has(crop_key):
		buffs.append("✨ Specialty: +20%% Market Value in %s!" % reg_short)

	var w_min: float = float(crop.get("water_min", 40))
	var w_max: float = float(crop.get("water_max", 70))

	if reg_moisture >= w_min and reg_moisture <= w_max:
		buffs.append("✔ Optimal Climate: Baseline moisture (%.0f%%) ideal for Grade A." % reg_moisture)
	elif reg_moisture < w_min:
		debuffs.append("⚠️ Moisture Deficit: Regional (%.0f%%) is below ideal (%.0f%%)." % [reg_moisture, w_min])
	elif reg_moisture > w_max:
		debuffs.append("⚠️ Over-saturation: Regional (%.0f%%) exceeds ideal (%.0f%%)." % [reg_moisture, w_max])

	var flood_risk: float = float(hazards.get("flash_flood", 0.0))
	var drought_risk: float = float(hazards.get("el_nino_drought", 0.0))

	if flood_risk >= 0.10 and w_max <= 75.0:
		debuffs.append("⚠️ Flood Susceptibility: River overflow risks drowning crops.")
	if drought_risk >= 0.10 and w_min >= 50.0:
		debuffs.append("⚠️ Drought Threat: Blistering dry spells halt growth without irrigation.")

	var crop_pests: Array = crop.get("pests", [])
	if crop_pests.has("kuhol") and region_key == "cotabato":
		debuffs.append("⚠️ Pest Risk: Wetland paddies attract Golden Apple Snails (Kuhol).")
	if crop_pests.has("fusarium_wilt") and (region_key == "south_cotabato" or region_key == "general_santos"):
		debuffs.append("⚠️ Disease Risk: High humidity triggers Fusarium Wilt.")
	if crop_pests.has("armyworm") and (region_key == "sarangani" or region_key == "sultan_kudarat"):
		debuffs.append("⚠️ Pest Risk: Arid spells trigger Fall Armyworm outbreaks.")

	if crop.get("is_perennial", false):
		buffs.append("✔ Living Perennial: Regrows automatically in %dd without seed costs." % int(crop.get("regrowth_days", 14)))

	return {
		"buffs": buffs,
		"debuffs": debuffs
	}

func _get_crop_simple_name(crop_key: String) -> String:
	match crop_key:
		"palay": return "Rice"
		"yellow_corn": return "Corn"
		"sugarcane": return "Sugarcane"
		"pineapple": return "Pineapple"
		"arabica_coffee": return "Coffee"
		"banana": return "Banana"
		"coconut": return "Coconut"
		_: return crop_key.capitalize()

func get_crop_sprite_texture(crop_type: String) -> Texture2D:
	if crop_type.is_empty():
		return null
	if _texture_cache.has(crop_type):
		return _texture_cache[crop_type]

	# 1. Primary: dedicated square plant icon in CROP_ICONS
	if CROP_ICONS.has(crop_type):
		var p: String = CROP_ICONS[crop_type]
		if ResourceLoader.exists(p):
			var tex: Texture2D = load(p) as Texture2D
			if tex:
				_texture_cache[crop_type] = tex
				return tex

	# 2. Secondary: search assets/icons/Plants/
	var icon_candidates: Array[String] = [
		"res://assets/icons/Plants/%s.png" % _get_crop_simple_name(crop_type),
		"res://assets/icons/Plants/%s.png" % crop_type.capitalize(),
		"res://assets/icons/Plants/%s.png" % crop_type
	]
	for path in icon_candidates:
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			if tex:
				_texture_cache[crop_type] = tex
				return tex

	# 3. Fallback: in-field stage sprites
	var field_candidates: Array[String] = [
		"res://assets/sprites/Field/Crops/%s/%s-P3.png" % [_get_crop_simple_name(crop_type), _get_crop_simple_name(crop_type).to_upper()],
		"res://assets/sprites/crops/%s.png" % crop_type,
		"res://assets/sprites/crops/%s.png" % crop_type.capitalize()
	]
	for path in field_candidates:
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

func get_drone_crop() -> String:
	return selected_category_items.get("seeds", "palay")
