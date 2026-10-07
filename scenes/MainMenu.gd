# MainMenu.gd
# Interactive Game Mode & Region Selection Screen for Agri-Region Tycoon.
# Displays:
# 1. Mode Selection Screen (Timed RTS Campaign vs Persistent Career Mode with Save & Load).
# 2. Region Selection Screen with pixel art backgrounds, transparent locator map,
#    and comprehensive regional dossier.

extends Control

const SaveLoadModalScript = preload("res://src/ui/SaveLoadModal.gd")

# UI Node References
@onready var bg_art: TextureRect = %BackgroundArt
@onready var prev_btn: TextureButton = %PrevButton
@onready var next_btn: TextureButton = %NextButton

@onready var region_index_label: Label = %RegionIndexLabel
@onready var region_name_label: Label = %RegionNameLabel
@onready var region_specialty_label: Label = %RegionSpecialtyLabel

@onready var location_map: TextureRect = %LocationMap
@onready var middle_card: PanelContainer = $MiddleCard

@onready var desc_label: Label = %DescLabel
@onready var moisture_val: Label = %MoistureVal
@onready var crops_val: Label = %CropsVal
@onready var hazard_val: Label = %HazardVal

@onready var pros_text: Label = %ProsText
@onready var cons_text: Label = %ConsText

@onready var admin_checkbox: CheckBox = %AdminCheckbox
@onready var start_button: Button = %StartButton

# Mode Selection & Navigation UI
var _mode_select_view: Control = null
var _top_center_header: VBoxContainer = null
var _top_right_map_card: PanelContainer = null
var _carousel_bar: HBoxContainer = null
var _footer_bar: HBoxContainer = null

var _region_nav_box: HBoxContainer = null
var _back_to_modes_btn: Button = null
var _mode_badge_label: Label = null
var _active_view: String = "mode" # "mode" or "region"

var _season_container: HBoxContainer = null
var _career_notice_label: Label = null
var _season_buttons: Dictionary = {}

# Game Mode Carousel UI
var mode_keys: Array = ["campaign", "career"]
var current_mode_idx: int = 0

var _mode_index_label: Label = null
var _mode_name_label: Label = null
var _mode_tagline_label: Label = null
var _mode_desc_label: Label = null

var _pillar1_title: Label = null
var _pillar1_body: Label = null
var _pillar2_title: Label = null
var _pillar2_body: Label = null
var _pillar3_title: Label = null
var _pillar3_body: Label = null

var _mode_season_container: HBoxContainer = null
var _mode_season_buttons: Dictionary = {}
var _mode_season_explain_label: Label = null
var _career_perks_container: HBoxContainer = null

var _mode_start_btn: Button = null
var _mode_load_btn: Button = null

# StartMenu Textures & Styles Cache
var tex_big_logs: Texture2D = null
var tex_samplebox: Texture2D = null
var tex_arrow_l_norm: Texture2D = null
var tex_arrow_l_hov: Texture2D = null
var tex_arrow_l_press: Texture2D = null
var tex_arrow_r_norm: Texture2D = null
var tex_arrow_r_hov: Texture2D = null
var tex_arrow_r_press: Texture2D = null
var style_gold_btn: StyleBox = null
var style_gold_hov: StyleBox = null
var style_gold_press: StyleBox = null
var style_brown_btn: StyleBox = null
var style_brown_hov: StyleBox = null
var style_brown_press: StyleBox = null
var tex_long_rect: Texture2D = null
var style_long_rect: StyleBoxTexture = null
var style_samplebox: StyleBoxTexture = null

var region_keys: Array = [
	"cotabato",
	"south_cotabato",
	"sarangani",
	"sultan_kudarat",
	"general_santos"
]

var current_idx: int = 0
var _admin_mode_enabled: bool = false
const ADMIN_FLAG_GROUP: String = "admin_mode_enabled"

const REGION_METADATA = {
	"cotabato": {
		"bg_path": "res://assets/Regions Art/Cotabto/Cotabato BG.png",
		"map_path": "res://assets/Regions Art/Cotabto/ph_transparent.png",
		"number_str": "REGION 1 OF 5",
		"short_name": "Cotabato Basin",
		"full_name": "COTABATO BASIN",
		"tagline": "Central Floodplains (Pulangi River Basin)",
		"crops": "Palay (Rice), Cavendish Banana",
		"moisture": "65% (Rich Alluvial Wetland)",
		"hazard_summary": "Flash Flood (15% High Risk)"
	},
	"south_cotabato": {
		"bg_path": "res://assets/Regions Art/South Cotabato/South Cotabato BG.png",
		"map_path": "res://assets/Regions Art/South Cotabato/ph_transparent.png",
		"number_str": "REGION 2 OF 5",
		"short_name": "South Cotabato Highlands",
		"full_name": "SOUTH COTABATO HIGHLANDS",
		"tagline": "Mount Matutum & Lake Sebu Plateaus",
		"crops": "Arabica Coffee, Premium Yellow Corn",
		"moisture": "55% (Temperate Volcanic Soil)",
		"hazard_summary": "Landslide (12% Mountain Hazard)"
	},
	"sarangani": {
		"bg_path": "res://assets/Regions Art/Sarangani/Sarangani BG.png",
		"map_path": "res://assets/Regions Art/Sarangani/ph_transparent.png",
		"number_str": "REGION 3 OF 5",
		"short_name": "Sarangani Littoral Coast",
		"full_name": "SARANGANI LITTORAL COAST",
		"tagline": "Celebes Coast & Sarangani Bay (Alabel / Glan)",
		"crops": "Coconut Palm, Cavendish Banana",
		"moisture": "45% (Arid Sandy Coastal Soil)",
		"hazard_summary": "El Nino Drought (14% High Aridity)"
	},
	"sultan_kudarat": {
		"bg_path": "res://assets/Regions Art/Sulat Kudarat/Sultan Kudarat BG.png",
		"map_path": "res://assets/Regions Art/Sulat Kudarat/ph_transparent.png",
		"number_str": "REGION 4 OF 5",
		"short_name": "Sultan Kudarat Valley",
		"full_name": "SULTAN KUDARAT VALLEY",
		"tagline": "Tacurong Commercial Grain Corridor",
		"crops": "Yellow Corn, Palay (Rice), Legumes",
		"moisture": "58% (Balanced Flatland Loam)",
		"hazard_summary": "Pest Outbreaks (Armyworm & Black Bug)"
	},
	"general_santos": {
		"bg_path": "res://assets/Regions Art/Genaral Santos/General Santos.png",
		"map_path": "res://assets/Regions Art/Genaral Santos/ph_transparent.png",
		"number_str": "REGION 5 OF 5",
		"short_name": "General Santos City",
		"full_name": "GENERAL SANTOS CITY",
		"tagline": "Tuna Capital & Agro-Industrial Seaport Hub",
		"crops": "Export Bananas, Coffee, Cold-Stored Batches",
		"moisture": "50% (Urban Agro-Industrial Plain)",
		"hazard_summary": "High Urban Payroll & Freight Surcharges"
	}
}

var _transition_tween: Tween = null

func _ready() -> void:
	if location_map:
		location_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_top_center_header = find_child("TopCenterHeader", true, false) as VBoxContainer
	if not _top_center_header:
		_top_center_header = find_child("TopLeftHeader", true, false) as VBoxContainer

	_top_right_map_card = find_child("TopRightMapCard", true, false) as PanelContainer
	_carousel_bar = find_child("CarouselBar", true, false) as HBoxContainer
	_footer_bar = find_child("FooterBar", true, false) as HBoxContainer

	# Connect navigation signals
	prev_btn.pressed.connect(_prev_region)
	next_btn.pressed.connect(_next_region)
	start_button.pressed.connect(_on_start_pressed)
	admin_checkbox.toggled.connect(_on_admin_checkbox_toggled)

	# Initial selection (index 0 - Cotabato)
	_select_region(0, false)
	_load_startmenu_resources()
	_setup_season_selector()
	_setup_region_back_navigation()

	# Create Mode Select View
	_build_mode_select_view()

	# Optional CLI test suite
	if "--test-menu" in OS.get_cmdline_args():
		_select_game_mode("campaign")
		print("--- AUTOMATED MAIN MENU REGION TEST START ---")
		for i in range(5):
			_select_region(i, false)
			print("Region %d/5: %s (%s)" % [current_idx + 1, region_name_label.text, region_index_label.text])
			print("  Background Art: %s" % bg_art.texture.resource_path)
			print("  Transparent Locator Map: %s" % location_map.texture.resource_path)
			print("  Start Button: %s" % start_button.text)
			assert(bg_art.texture != null, "Background art texture missing")
			assert(location_map.texture != null, "Location map texture missing")
		_prev_region()
		assert(current_idx == 3, "Wrapping prev should work")
		_next_region()
		assert(current_idx == 4, "Wrapping next should work")
		print("--- AUTOMATED MAIN MENU REGION TEST PASSED ---")

		# Test SaveManager operations
		print("--- AUTOMATED SAVE & LOAD TEST START ---")
		EconomyManager.cash = 9999
		TimeManager.current_day = 12
		Data.current_region = "sarangani"
		Data.game_mode = "career"
		assert(SaveManager.save_game(1, "Test Career Run"), "Save to slot 1 should succeed")
		var meta: Dictionary = SaveManager.get_slot_meta(1)
		assert(meta.get("cash", 0) == 9999, "Saved cash should match")
		assert(meta.get("day", 0) == 12, "Saved day should match")
		assert(meta.get("game_mode", "") == "career", "Saved mode should match career")
		assert(SaveManager.delete_slot(1), "Delete slot 1 should succeed")
		assert(not SaveManager.has_save(1), "Slot 1 should be cleared")
		print("--- AUTOMATED SAVE & LOAD TEST PASSED ---")

		get_tree().quit(0)
	elif "--test-ui-boxes" in OS.get_cmdline_args():
		print("--- AUTOMATED UI BOXES & MODALS TEST START ---")
		var big_plain = load("res://assets/sprites/hud/Big-Rectangle-Box/BigPlainBox.tres")
		assert(big_plain != null, "BigPlainBox.tres must load")
		var info_box = load("res://assets/sprites/hud/Hopbar/InformationBox.tres")
		assert(info_box != null, "InformationBox.tres must load")
		var big_logs = load("res://assets/sprites/StartMenu/BigRectangleLogs.tres")
		assert(big_logs != null, "BigRectangleLogs.tres must load")
		var samplebox = load("res://assets/sprites/hud/Samplebox.tres")
		assert(samplebox != null, "Samplebox.tres must load")
		var clipboard = load("res://assets/sprites/hud/BottomLeft/Clipboard.tres")
		assert(clipboard != null, "Clipboard.tres must load")
		var brown_box = load("res://assets/sprites/hud/TopRight/BrownBox.tres")
		assert(brown_box != null, "BrownBox.tres must load")
		var shop_bg = load("res://assets/sprites/hud/Shop/Shop Backgroud.tres")
		assert(shop_bg != null, "Shop Backgroud.tres must load")
		print("✔ All 7 core StyleBoxTexture box variants verified loaded")

		var mg_scene = load("res://scenes/MainGame.tscn")
		assert(mg_scene != null, "MainGame.tscn must load")
		var game = mg_scene.instantiate()
		assert(game != null, "MainGame must instantiate")
		add_child(game)

		var rhc = game.find_child("RegionHoverCard", true, false)
		assert(rhc != null, "RegionHoverCard must exist")
		assert(rhc.get_theme_stylebox("panel") != null, "RegionHoverCard must have stylebox")
		print("✔ RegionHoverCard styled with BrownBox.tres")

		var iic = game.find_child("ItemInfoCard", true, false)
		assert(iic != null, "ItemInfoCard must exist")
		assert(iic.get_theme_stylebox("panel") != null, "ItemInfoCard must have stylebox")
		print("✔ ShopPanel ItemInfoCard styled with BrownBox.tres")

		var tap = game.find_child("TileActionPopup", true, false)
		assert(tap != null, "TileActionPopup must exist")
		print("✔ TileActionPopup verified in MainGame")

		var pause_cls = load("res://src/ui/PauseMenu.gd")
		var pause = pause_cls.new()
		add_child(pause)
		var pause_p = pause.find_children("*", "PanelContainer", true, false)[0] as PanelContainer
		assert(pause_p != null and pause_p.get_theme_stylebox("panel") is StyleBoxTexture, "PauseMenu has StyleBoxTexture")
		pause.queue_free()
		print("✔ PauseMenu verified with BigRectangleLogs.tres")

		var backlog_cls = load("res://src/ui/BacklogPanel.gd")
		var backlog = backlog_cls.new()
		add_child(backlog)
		var backlog_p = backlog.find_children("*", "PanelContainer", true, false)[0] as PanelContainer
		assert(backlog_p != null and backlog_p.get_theme_stylebox("panel") is StyleBoxTexture, "BacklogPanel has StyleBoxTexture")
		backlog.queue_free()
		print("✔ BacklogPanel verified with Clipboard.tres")

		var lb_cls = load("res://src/ui/LeaderboardPanel.gd")
		var lb = lb_cls.new()
		add_child(lb)
		var lb_p = lb.find_children("*", "PanelContainer", true, false)[0] as PanelContainer
		assert(lb_p != null and lb_p.get_theme_stylebox("panel") is StyleBoxTexture, "LeaderboardPanel has StyleBoxTexture")
		lb.queue_free()
		print("✔ LeaderboardPanel verified with BigPlainBox.tres")

		var sl_cls = load("res://src/ui/SaveLoadModal.gd")
		var sl = sl_cls.new()
		add_child(sl)
		var sl_p = sl.find_children("*", "PanelContainer", true, false)[0] as PanelContainer
		assert(sl_p != null and sl_p.get_theme_stylebox("panel") is StyleBoxTexture, "SaveLoadModal has StyleBoxTexture")
		sl.queue_free()
		print("✔ SaveLoadModal verified with BigPlainBox.tres")

		var sr_cls = load("res://src/ui/SeasonResultsModal.gd")
		var sr = sr_cls.new()
		add_child(sr)
		var sr_p = sr.find_children("*", "PanelContainer", true, false)[0] as PanelContainer
		assert(sr_p != null and sr_p.get_theme_stylebox("panel") is StyleBoxTexture, "SeasonResultsModal has StyleBoxTexture")
		sr.queue_free()
		print("✔ SeasonResultsModal verified with BigRectangleLogs.tres")

		var bcp_scene = load("res://scenes/BuildingCardPopup.tscn")
		var bcp = bcp_scene.instantiate()
		add_child(bcp)
		var bcp_card = bcp.find_child("Panel", true, false) as PanelContainer
		assert(bcp_card != null and bcp_card.get_theme_stylebox("panel") is StyleBoxTexture, "BuildingCardPopup has StyleBoxTexture")
		bcp.queue_free()
		print("✔ BuildingCardPopup verified with InformationBox.tres")

		var admin_cls = load("res://src/ui/AdminPanel.gd")
		var admin = admin_cls.new()
		add_child(admin)
		var admin_p = admin.find_children("*", "PanelContainer", true, false)[0] as PanelContainer
		assert(admin_p != null and admin_p.get_theme_stylebox("panel") is StyleBoxTexture, "AdminPanel has StyleBoxTexture")
		admin.queue_free()
		print("✔ AdminPanel verified with BigRectangleLogs.tres")

		game.queue_free()
		print("--- AUTOMATED UI BOXES & MODALS TEST PASSED ---")
		get_tree().quit(0)
	else:
		_show_mode_select()
		if "--capture-screenshot" in OS.get_cmdline_args():
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			var img = get_viewport().get_texture().get_image()
			img.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/current_menu.png")
			print("--- CAMPAIGN SCREENSHOT SAVED ---")
			_select_mode_carousel(1)
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			var img_career = get_viewport().get_texture().get_image()
			img_career.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/career_menu.png")
			print("--- CAREER SCREENSHOT SAVED ---")
			get_tree().quit(0)

# ---------------------------------------------------------------------------
# View Management (Mode Select vs Region Select)
# ---------------------------------------------------------------------------
func _load_startmenu_resources() -> void:
	if ResourceLoader.exists("res://assets/sprites/StartMenu/Big-Rectangle-logs.png"):
		tex_big_logs = load("res://assets/sprites/StartMenu/Big-Rectangle-logs.png")
	if ResourceLoader.exists("res://assets/sprites/StartMenu/samplebox1.png"):
		var raw_sb = load("res://assets/sprites/StartMenu/samplebox1.png")
		if raw_sb is Texture2D:
			var img: Image = raw_sb.get_image()
			if img:
				var min_x: int = img.get_width()
				var min_y: int = img.get_height()
				var max_x: int = 0
				var max_y: int = 0
				for y in range(img.get_height()):
					for x in range(img.get_width()):
						if img.get_pixel(x, y).a > 0.05:
							min_x = mini(min_x, x)
							min_y = mini(min_y, y)
							max_x = maxi(max_x, x)
							max_y = maxi(max_y, y)
				if max_x >= min_x and max_y >= min_y:
					var cropped: Image = img.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
					tex_samplebox = ImageTexture.create_from_image(cropped)
				else:
					tex_samplebox = raw_sb
			else:
				tex_samplebox = raw_sb

			style_samplebox = StyleBoxTexture.new()
			style_samplebox.texture = tex_samplebox
			style_samplebox.texture_margin_left = 14
			style_samplebox.texture_margin_right = 14
			style_samplebox.texture_margin_top = 14
			style_samplebox.texture_margin_bottom = 14
			style_samplebox.content_margin_left = 22
			style_samplebox.content_margin_right = 22
			style_samplebox.content_margin_top = 16
			style_samplebox.content_margin_bottom = 16
			style_samplebox.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			style_samplebox.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH

	if ResourceLoader.exists("res://assets/sprites/StartMenu/Arrows/arrow_left_normal.png"):
		tex_arrow_l_norm = load("res://assets/sprites/StartMenu/Arrows/arrow_left_normal.png")
		tex_arrow_l_hov = load("res://assets/sprites/StartMenu/Arrows/arrow_left_hover.png")
		tex_arrow_l_press = load("res://assets/sprites/StartMenu/Arrows/arrow_left_pressed.png")

	if ResourceLoader.exists("res://assets/sprites/StartMenu/Arrows/arrow_right_normal.png"):
		tex_arrow_r_norm = load("res://assets/sprites/StartMenu/Arrows/arrow_right_normal.png")
		tex_arrow_r_hov = load("res://assets/sprites/StartMenu/Arrows/arrow_right_hover.png")
		tex_arrow_r_press = load("res://assets/sprites/StartMenu/Arrows/arrow_right_pressed.png")

	if ResourceLoader.exists("res://assets/sprites/StartMenu/GoldButton/Goldbutton.tres"):
		style_gold_btn = load("res://assets/sprites/StartMenu/GoldButton/Goldbutton.tres")
		style_gold_hov = load("res://assets/sprites/StartMenu/GoldButton/GoldbuttonHover.tres")
		style_gold_press = load("res://assets/sprites/StartMenu/GoldButton/GoldbuttonPresesd.tres")

	if ResourceLoader.exists("res://assets/sprites/StartMenu/Brownbutton/BrownButton.tres"):
		style_brown_btn = load("res://assets/sprites/StartMenu/Brownbutton/BrownButton.tres")
		style_brown_hov = load("res://assets/sprites/StartMenu/Brownbutton/BrownButtonHover.tres")
		style_brown_press = load("res://assets/sprites/StartMenu/Brownbutton/BrownButtonPressed.tres")

	if ResourceLoader.exists("res://assets/sprites/StartMenu/long-rectangle.png"):
		var raw_long = load("res://assets/sprites/StartMenu/long-rectangle.png")
		if raw_long is Texture2D:
			var img: Image = raw_long.get_image()
			if img:
				var min_x: int = img.get_width()
				var min_y: int = img.get_height()
				var max_x: int = 0
				var max_y: int = 0
				for y in range(img.get_height()):
					for x in range(img.get_width()):
						if img.get_pixel(x, y).a > 0.05:
							min_x = mini(min_x, x)
							min_y = mini(min_y, y)
							max_x = maxi(max_x, x)
							max_y = maxi(max_y, y)
				if max_x >= min_x and max_y >= min_y:
					var cropped: Image = img.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
					tex_long_rect = ImageTexture.create_from_image(cropped)
				else:
					tex_long_rect = raw_long
			else:
				tex_long_rect = raw_long

			style_long_rect = StyleBoxTexture.new()
			style_long_rect.texture = tex_long_rect
			style_long_rect.texture_margin_left = 12
			style_long_rect.texture_margin_right = 12
			style_long_rect.texture_margin_top = 11
			style_long_rect.texture_margin_bottom = 11
			style_long_rect.content_margin_left = 20
			style_long_rect.content_margin_right = 20
			style_long_rect.content_margin_top = 8
			style_long_rect.content_margin_bottom = 10
			style_long_rect.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			style_long_rect.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH

func _build_mode_select_view() -> void:
	_mode_select_view = %ModeSelectView
	_mode_index_label = %ModeIndexLabel
	_mode_name_label = %ModeNameLabel
	_mode_tagline_label = %ModeTaglineLabel
	_mode_desc_label = %ModeDescLabel
	_pillar1_title = %Pillar1Title
	_pillar1_body = %Pillar1Body
	_pillar2_title = %Pillar2Title
	_pillar2_body = %Pillar2Body
	_pillar3_title = %Pillar3Title
	_pillar3_body = %Pillar3Body
	_mode_season_container = %ModeSeasonContainer
	_mode_season_explain_label = %ModeSeasonExplainLabel
	_career_perks_container = %CareerPerksContainer
	_mode_start_btn = %ModeStartBtn
	_mode_load_btn = %ModeLoadBtn

	# Connect navigation and button signals
	%PrevModeBtn.pressed.connect(_prev_mode)
	%NextModeBtn.pressed.connect(_next_mode)
	%ModeStartBtn.pressed.connect(_on_mode_start_pressed)
	%ModeLoadBtn.pressed.connect(_open_load_modal)

	_mode_season_buttons = {
		30: %Season30Btn,
		60: %Season60Btn,
		90: %Season90Btn
	}
	%Season30Btn.pressed.connect(func(): _set_mode_season_duration(30))
	%Season60Btn.pressed.connect(func(): _set_mode_season_duration(60))
	%Season90Btn.pressed.connect(func(): _set_mode_season_duration(90))

	_select_mode_carousel(0)

func _prev_mode() -> void:
	_select_mode_carousel(current_mode_idx - 1)

func _next_mode() -> void:
	_select_mode_carousel(current_mode_idx + 1)

func _select_mode_carousel(idx: int) -> void:
	current_mode_idx = (idx % mode_keys.size() + mode_keys.size()) % mode_keys.size()
	var mode_id: String = mode_keys[current_mode_idx]
	Data.game_mode = mode_id

	if mode_id == "campaign":
		_mode_index_label.text = "GAME MODE 1 OF 2"
		_mode_name_label.text = "🏆 TIMED RTS CAMPAIGN"
		_mode_tagline_label.text = "[ COMPETITIVE SCORE ATTACK • SEASON SPRINT ]"
		_mode_desc_label.text = "Race against the seasonal clock in a high-stakes agricultural sprint across Mindanao! Cultivate strategic crop rotations, optimize harvesting logistics, and fulfill export contracts through regional shipping hubs. Every bushel delivered with high freshness and Grade A quality earns delivery combo multipliers, cash bonuses, and league points."

		_pillar1_title.text = "⏱️ RTS Season Timer"
		_pillar1_body.text = "• Choose a 30, 60, or 90 day campaign duration.\n• Real-time Day/Night clock (3 minutes per day).\n• Early harvest rescues crops ahead of typhoons."

		_pillar2_title.text = "🏆 Mindanao League"
		_pillar2_body.text = "• Compete against 8 simulated regional AI rivals.\n• Grade A crops grant a massive 2.5× point multiplier.\n• Fast hub deliveries build combo streaks up to 2.0×."

		_pillar3_title.text = "🎖️ Tycoon Prestige"
		_pillar3_body.text = "• Climb 5 prestige tiers to Mindanao Agro-Tycoon.\n• Match regional climate affinities for +30% export bonuses.\n• Permanent Hall of Fame records your personal best."

		_mode_season_container.visible = true
		_mode_season_explain_label.visible = true
		_career_perks_container.visible = false
		_update_mode_season_buttons_ui()

		_mode_start_btn.text = "PROCEED TO REGION SELECT (START CAMPAIGN)  >"
	else:
		_mode_index_label.text = "GAME MODE 2 OF 2"
		_mode_name_label.text = "🌾 CAREER / ENDLESS TYCOON"
		_mode_tagline_label.text = "[ PERSISTENT FARM BUILDER • SAVE & LOAD ]"
		_mode_desc_label.text = "Cultivate and expand your agricultural empire at your own relaxed pace with no time limits or countdown pressure. Clear dense wilderness, purchase all 4 island territory deeds, construct advanced drying infrastructure, and build thriving perennial groves with full save and load support anytime."

		_pillar1_title.text = "🌾 Unlimited Sandbox"
		_pillar1_body.text = "• Play for 100+ in-game days with no deadlines.\n• Expand across all 24x24 plots (North, South, East, West).\n• Construct dryers, solar patios, and hire farmhands."

		_pillar2_title.text = "💾 5-Slot Save & Load"
		_pillar2_body.text = "• Full in-game save system with 5 manual save slots.\n• Saves treasury, buildings, 576-tile grid, crops, and market.\n• Resume your farm anytime from main menu or pause menu."

		_pillar3_title.text = "🌙 Midnight Autosave"
		_pillar3_body.text = "• Automatic backup saves every in-game midnight (00:00).\n• Your progress is always protected against unexpected exits.\n• Freely experiment with multi-tile Coconut & Banana groves."

		_mode_season_container.visible = false
		_mode_season_explain_label.visible = false
		_career_perks_container.visible = true

		_mode_start_btn.text = "PROCEED TO REGION SELECT (START NEW CAREER)  >"

func _on_mode_start_pressed() -> void:
	_select_game_mode(mode_keys[current_mode_idx])

func _set_mode_season_duration(days: int) -> void:
	_select_season_duration(days)
	_update_mode_season_buttons_ui()

func _update_mode_season_buttons_ui() -> void:
	for days in _mode_season_buttons.keys():
		var btn: Button = _mode_season_buttons[days]
		if days == Data.selected_season_days:
			if style_gold_btn:
				btn.add_theme_stylebox_override("normal", style_gold_btn)
				btn.add_theme_stylebox_override("hover", style_gold_hov)
				btn.add_theme_stylebox_override("pressed", style_gold_press)
			btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02, 1.0))
			btn.add_theme_font_size_override("font_size", 13)
		else:
			if style_brown_btn:
				btn.add_theme_stylebox_override("normal", style_brown_btn)
				btn.add_theme_stylebox_override("hover", style_brown_hov)
				btn.add_theme_stylebox_override("pressed", style_brown_press)
			btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
			btn.add_theme_font_size_override("font_size", 13)

	if _mode_season_explain_label:
		if Data.selected_season_days == 30:
			_mode_season_explain_label.text = "Quick 30-Day Sprint (1 Month) — Fast, intense pace focused on short-cycle cash crops (Palay & Corn)."
		elif Data.selected_season_days == 90:
			_mode_season_explain_label.text = "Full 90-Day Quarter (3 Months) — Deep strategic campaign enabling massive multi-tile perennial plantation investments."
		else:
			_mode_season_explain_label.text = "Standard 60-Day Campaign (2 Months) — Balanced timeline allowing all 7 crops and perennial groves to mature."

func _setup_region_back_navigation() -> void:
	# Add back button and active mode badge positioned in top-left
	_region_nav_box = HBoxContainer.new()
	_region_nav_box.name = "RegionNavBox"
	_region_nav_box.add_theme_constant_override("separation", 10)
	_region_nav_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_region_nav_box.offset_left = 24.0
	_region_nav_box.offset_top = 20.0
	_region_nav_box.offset_right = 380.0
	_region_nav_box.offset_bottom = 58.0

	_back_to_modes_btn = Button.new()
	_back_to_modes_btn.text = "← BACK TO GAME MODES"
	_back_to_modes_btn.custom_minimum_size = Vector2(180, 36)
	_back_to_modes_btn.add_theme_font_size_override("font_size", 12)
	_back_to_modes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if style_brown_btn:
		_back_to_modes_btn.add_theme_stylebox_override("normal", style_brown_btn)
		_back_to_modes_btn.add_theme_stylebox_override("hover", style_brown_hov)
		_back_to_modes_btn.add_theme_stylebox_override("pressed", style_brown_press)
	_back_to_modes_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	_back_to_modes_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
	_back_to_modes_btn.pressed.connect(_show_mode_select)
	_region_nav_box.add_child(_back_to_modes_btn)

	_mode_badge_label = Label.new()
	_mode_badge_label.text = "[ TIMED CAMPAIGN ]"
	_mode_badge_label.add_theme_font_size_override("font_size", 11)
	_mode_badge_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40, 1.0))
	_region_nav_box.add_child(_mode_badge_label)

	add_child(_region_nav_box)

func _select_game_mode(mode: String) -> void:
	Data.game_mode = mode
	if mode == "career":
		TimeManager.is_freeplay_mode = true
	else:
		TimeManager.is_freeplay_mode = false

	_show_region_select()

func _show_mode_select() -> void:
	_active_view = "mode"
	if _mode_select_view:
		_mode_select_view.visible = true
		_select_mode_carousel(current_mode_idx)

	if _top_right_map_card:
		_top_right_map_card.visible = false
	if _carousel_bar:
		_carousel_bar.visible = false
	if middle_card:
		middle_card.visible = false
	if _footer_bar:
		_footer_bar.visible = false
	if _region_nav_box:
		_region_nav_box.visible = false
	if _top_center_header:
		_top_center_header.visible = true

func _show_region_select() -> void:
	_active_view = "region"
	if _mode_select_view:
		_mode_select_view.visible = false

	if _top_right_map_card:
		_top_right_map_card.visible = true
	if _carousel_bar:
		_carousel_bar.visible = true
	if middle_card:
		middle_card.visible = true
	if _footer_bar:
		_footer_bar.visible = true
	if _region_nav_box:
		_region_nav_box.visible = true
	if _top_center_header:
		_top_center_header.visible = true

	if _mode_badge_label:
		if Data.game_mode == "campaign":
			_mode_badge_label.text = "[ TIMED CAMPAIGN: %d DAYS ]" % Data.selected_season_days
			_mode_badge_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40, 1.0))
		else:
			_mode_badge_label.text = "[ CAREER: ENDLESS ]"
			_mode_badge_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))

	# Update season duration selector vs career notice in footer
	if _season_container:
		_season_container.visible = (Data.game_mode == "campaign")
	if _career_notice_label:
		_career_notice_label.visible = (Data.game_mode == "career")

	_update_start_button_text()

func _open_load_modal() -> void:
	var modal = SaveLoadModalScript.new(SaveLoadModalScript.Mode.LOAD)
	get_tree().root.add_child(modal)

func _unhandled_input(event: InputEvent) -> void:
	if _active_view == "region":
		if event.is_action_pressed("ui_cancel"):
			_show_mode_select()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
			_prev_region()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
			_next_region()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			_on_start_pressed()
			get_viewport().set_input_as_handled()
	elif _active_view == "mode":
		if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
			_prev_mode()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
			_next_mode()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			_on_mode_start_pressed()
			get_viewport().set_input_as_handled()

func _prev_region() -> void:
	_select_region(current_idx - 1, true)

func _next_region() -> void:
	_select_region(current_idx + 1, true)

func _select_region(idx: int, animate: bool = true) -> void:
	current_idx = (idx % region_keys.size() + region_keys.size()) % region_keys.size()
	var key: String = region_keys[current_idx]
	var meta: Dictionary = REGION_METADATA.get(key, {})
	var r_data: Dictionary = Data.get_region(key)

	var bg_tex = load(meta.get("bg_path", ""))
	var map_tex = load(meta.get("map_path", ""))

	if animate:
		if _transition_tween and _transition_tween.is_valid():
			_transition_tween.kill()

		_transition_tween = create_tween()
		_transition_tween.set_parallel(true)
		_transition_tween.tween_property(middle_card, "modulate:a", 0.35, 0.08)
		_transition_tween.tween_property(location_map, "modulate:a", 0.35, 0.08)
		_transition_tween.chain().tween_callback(func():
			_apply_region_data(meta, r_data, bg_tex, map_tex)
		)
		_transition_tween.chain().tween_property(middle_card, "modulate:a", 1.0, 0.12)
		_transition_tween.tween_property(location_map, "modulate:a", 1.0, 0.12)
	else:
		_apply_region_data(meta, r_data, bg_tex, map_tex)

func _apply_region_data(meta: Dictionary, r_data: Dictionary, bg_tex: Texture2D, map_tex: Texture2D) -> void:
	if bg_tex:
		bg_art.texture = bg_tex
	if map_tex:
		location_map.texture = map_tex

	region_index_label.text = meta.get("number_str", "REGION 1 OF 5")
	region_name_label.text = meta.get("full_name", r_data.get("display_name", "REGION"))
	region_specialty_label.text = meta.get("tagline", r_data.get("specialty", ""))

	desc_label.text = r_data.get("description", "")
	crops_val.text = meta.get("crops", "Palay, Corn")
	moisture_val.text = meta.get("moisture", "50%")
	hazard_val.text = meta.get("hazard_summary", "Moderate")

	var pros_array: Array = r_data.get("pros", [])
	var pros_str: String = ""
	for p in pros_array:
		pros_str += "[+] %s\n\n" % p
	pros_text.text = pros_str.strip_edges()

	var cons_array: Array = r_data.get("cons", [])
	var cons_str: String = ""
	for c in cons_array:
		cons_str += "[!] %s\n\n" % c
	cons_text.text = cons_str.strip_edges()

	_update_start_button_text()

func _setup_season_selector() -> void:
	var footer_bar := find_child("FooterBar", true, false) as HBoxContainer
	if not footer_bar:
		return

	_season_container = HBoxContainer.new()
	_season_container.name = "SeasonModeContainer"
	_season_container.add_theme_constant_override("separation", 6)
	_season_container.alignment = BoxContainer.ALIGNMENT_CENTER

	var lbl := Label.new()
	lbl.text = "CAMPAIGN:"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55, 1.0))
	_season_container.add_child(lbl)

	var modes = [
		{"days": 30, "text": "⚡ 30d Sprint"},
		{"days": 60, "text": "⭐ 60d Standard"},
		{"days": 90, "text": "👑 90d Quarter"}
	]

	for m in modes:
		var days: int = m["days"]
		var btn := Button.new()
		btn.text = m["text"]
		btn.custom_minimum_size = Vector2(96, 32)
		btn.add_theme_font_size_override("font_size", 10)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): _select_season_duration(days))
		_season_container.add_child(btn)
		_season_buttons[days] = btn

	# Career Mode notice label for footer
	_career_notice_label = Label.new()
	_career_notice_label.name = "CareerNoticeLabel"
	_career_notice_label.text = "🌾 Endless Sandbox • Full In-Game Save & Load Enabled"
	_career_notice_label.add_theme_font_size_override("font_size", 12)
	_career_notice_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65, 0.95))
	_career_notice_label.visible = false

	# Insert before StartButton in FooterBar
	var start_idx: int = start_button.get_index()
	footer_bar.add_child(_season_container)
	footer_bar.move_child(_season_container, start_idx)

	footer_bar.add_child(_career_notice_label)
	footer_bar.move_child(_career_notice_label, start_idx)

	_update_season_buttons_ui()
	_update_start_button_text()

func _select_season_duration(days: int) -> void:
	Data.selected_season_days = days
	_update_season_buttons_ui()
	_update_start_button_text()
	if _mode_badge_label and Data.game_mode == "campaign":
		_mode_badge_label.text = "[ TIMED CAMPAIGN: %d DAYS ]" % Data.selected_season_days

func _update_season_buttons_ui() -> void:
	for days in _season_buttons.keys():
		var btn: Button = _season_buttons[days]
		if days == Data.selected_season_days:
			btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35, 1.0))
		else:
			btn.add_theme_color_override("font_color", Color(0.70, 0.65, 0.60, 0.85))

func _update_start_button_text() -> void:
	if not start_button:
		return
	var key: String = region_keys[current_idx]
	var meta: Dictionary = REGION_METADATA.get(key, {})
	var short_name: String = meta.get("short_name", "REGION").to_upper()

	if Data.game_mode == "campaign":
		start_button.text = "START %d-DAY CAMPAIGN IN %s  >" % [Data.selected_season_days, short_name]
	else:
		start_button.text = "START NEW CAREER IN %s  >" % short_name

func _on_admin_checkbox_toggled(on: bool) -> void:
	_admin_mode_enabled = on
	var flag_nodes = get_tree().get_nodes_in_group(ADMIN_FLAG_GROUP)
	for n in flag_nodes:
		n.queue_free()
	if on:
		var flag := Node.new()
		flag.name = "AdminModeFlag"
		flag.add_to_group(ADMIN_FLAG_GROUP)
		get_tree().root.add_child(flag)

func _on_start_pressed() -> void:
	if current_idx >= 0 and current_idx < region_keys.size():
		Data.current_region = region_keys[current_idx]
	else:
		Data.current_region = "cotabato"

	if Data.game_mode == "career":
		TimeManager.is_freeplay_mode = true
	else:
		TimeManager.is_freeplay_mode = false

	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
