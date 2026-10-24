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

var admin_checkbox: CheckBox = null
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

# Mode Explanations for Hover Card
const MODE_EXPLANATIONS: Dictionary = {
	"campaign": {
		"title": "🏆 TIMED RTS CAMPAIGN",
		"tagline": "[ COMPETITIVE RTS SCORE ATTACK • 30–90 DAYS ]",
		"sentences": [
			"Compete against 8 regional AI rivals in a timed score-attack race across Mindanao markets.",
			"Choose a 30, 60, or 90 day RTS season clock to harvest crops, manage disaster risks, and earn maximum profits.",
			"Climb through 5 agro-tycoon prestige tiers to secure a permanent spot in the Hall of Fame."
		],
		"tip": "👉 Click to choose region & start campaign"
	},
	"career": {
		"title": "🌾 CAREER / ENDLESS TYCOON",
		"tagline": "[ RELAXED PERSISTENT SANDBOX • SAVE & LOAD ]",
		"sentences": [
			"Build and manage your agricultural enterprise at your own relaxed pace with no time limits or pressure.",
			"Cultivate perennial groves across an expandable 24×24 grid with safe midnight autosaves and 5 flexible save slots.",
			"Unlock autonomous drone fleets and agro-industrial processing facilities to create a lasting farming empire."
		],
		"tip": "👉 Click to choose region & start new career"
	},
	"saves": {
		"title": "💾 SAVED EXPEDITIONS",
		"tagline": "[ IN-GAME SAVE & LOAD MANAGEMENT ]",
		"sentences": [
			"Access up to 5 manual save slots or resume your ongoing agricultural career.",
			"Daily midnight autosaves keep your farm grid, treasury, and crop harvests secure.",
			"Load previous tycoon playthroughs anytime or back up your homestead before expanding."
		],
		"tip": "👉 Click to browse and load previous playthroughs"
	},
	"hall_of_fame": {
		"title": "🎖️ TYCOON HALL OF FAME",
		"tagline": "[ REGIONAL LEADERBOARDS & RECORDS ]",
		"sentences": [
			"View your highest score-attack campaign records and career achievements.",
			"Track personal best rankings across all 5 SOCCSKSARGEN agricultural territories.",
			"Review your prestige titles from Bronze Planter to Master Hacienda Tycoon."
		],
		"tip": "👉 Click to inspect regional records"
	}
}

# Mode Hover Card
var _mode_hover_card: PanelContainer = null
var _hover_title_label: Label = null
var _hover_tagline_label: Label = null
var _hover_desc_label: Label = null
var _hover_tip_label: Label = null
var _hover_card_tween: Tween = null
var _current_hovered_mode: String = ""

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

var _mode_season_container: Control = null
var _mode_season_buttons: Dictionary = {}
var _mode_season_explain_label: Label = null
var _career_perks_container: Control = null

var _mode_start_btn: Button = null
var _mode_load_btn: Button = null
var _mode_leaderboard_btn: Button = null

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
var style_wood_btn: StyleBox = null
var style_wood_hov: StyleBox = null
var style_wood_press: StyleBox = null
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

const REGION_VISUAL_FACTORS = {
	"cotabato": {
		"pros": [
			{"icon": "res://assets/icons/Topleft/water-drop.png", "text": "• High natural moisture (65%) feeds rich wetland soils"},
			{"icon": "res://assets/icons/Plants/Rice.png", "text": "• Accelerated Palay (Rice) growth with bumper harvests"},
			{"icon": "res://assets/icons/Tempreture/Just-Right.png", "text": "• River basin naturally shelters crops from heat damage"}
		],
		"cons": [
			{"icon": "res://assets/icons/Disaster/Wave.png", "text": "• 15% Flash flood hazard during heavy monsoon downpours"},
			{"icon": "res://assets/icons/Disaster/Warning.png", "text": "• Golden apple snails attack tender young seedlings"},
			{"icon": "res://assets/icons/Topleft/Rain.png", "text": "• Over-saturated waterlogging spoils unharvested plots"}
		]
	},
	"south_cotabato": {
		"pros": [
			{"icon": "res://assets/icons/Plants/coffee.png", "text": "• Rich volcanic soil produces premium Arabica coffee"},
			{"icon": "res://assets/icons/Plants/Corn.png", "text": "• High-altitude yellow corn commands premium prices"},
			{"icon": "res://assets/icons/Tempreture/Cold .png", "text": "• Cool mountain air slows down harvested crop spoilage"}
		],
		"cons": [
			{"icon": "res://assets/icons/Disaster/Warning.png", "text": "• Steep terrain creates 12% landslide risk in rainy spells"},
			{"icon": "res://assets/icons/Topleft/Rain.png", "text": "• Frequent mountain rains delay plowing and planting"},
			{"icon": "res://assets/icons/HUD/Market.png", "text": "• Winding highland roads increase freight and trip costs"}
		]
	},
	"sarangani": {
		"pros": [
			{"icon": "res://assets/icons/Plants/Coconut.png", "text": "• Sandy coastal soil supports expansive 2×2 Coconut groves"},
			{"icon": "res://assets/icons/Plants/Banana.png", "text": "• High market demand for export-quality Cavendish bananas"},
			{"icon": "res://assets/icons/Tempreture/Sunny.png", "text": "• Constant coastal sunshine speeds up solar crop drying"}
		],
		"cons": [
			{"icon": "res://assets/icons/Tempreture/Fire.png", "text": "• 14% El Nino drought hazard causes severe arid heat"},
			{"icon": "res://assets/icons/Topleft/water-drop.png", "text": "• Porous sandy soil loses moisture fast without irrigation"},
			{"icon": "res://assets/icons/Disaster/Warning.png", "text": "• Dry foliage attracts aggressive leaf-chewing pest swarms"}
		]
	},
	"sultan_kudarat": {
		"pros": [
			{"icon": "res://assets/icons/Plants/Corn.png", "text": "• Wide open valley corridor is ideal for corn & grain fields"},
			{"icon": "res://assets/icons/Plants/Rice.png", "text": "• High fertility permits efficient multi-crop rotations"},
			{"icon": "res://assets/icons/HUD/Market.png", "text": "• Direct highway connectivity lowers transit costs to hubs"}
		],
		"cons": [
			{"icon": "res://assets/icons/Disaster/Warning.png", "text": "• Humid valley conditions spawn armyworms and black bugs"},
			{"icon": "res://assets/icons/Disaster/Wave.png", "text": "• Low flatland basins face 9% flash flood runoff hazard"},
			{"icon": "res://assets/icons/Tempreture/Fire.png", "text": "• Sudden dry spells cause rapid drop in soil moisture"}
		]
	},
	"general_santos": {
		"pros": [
			{"icon": "res://assets/icons/HUD/Market.png", "text": "• International seaport delivers +30% export revenue bonus"},
			{"icon": "res://assets/icons/Plants/Banana.png", "text": "• Prime trade hub for high-yield commercial fruit shipments"},
			{"icon": "res://assets/icons/HUD/Build.png", "text": "• Advanced industrial logistics speed up farm construction"}
		],
		"cons": [
			{"icon": "res://assets/icons/HUD/Market.png", "text": "• Higher urban wage rates and commercial shipping fees"},
			{"icon": "res://assets/icons/Tempreture/Fire.png", "text": "• City heat island increases water evaporation by 10%"},
			{"icon": "res://assets/icons/Disaster/Warning.png", "text": "• Strict international export standards reject Grade C crops"}
		]
	}
}

var _pro_icons: Array = []
var _pro_labels: Array = []
var _con_icons: Array = []
var _con_labels: Array = []
var _side_campaign_btn: Button = null
var _side_career_btn: Button = null
var _region_season_box: Control = null

var _transition_tween: Tween = null

func _ready() -> void:
	if location_map:
		location_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Cache visual pro and con row nodes
	_pro_icons.clear()
	_pro_labels.clear()
	_con_icons.clear()
	_con_labels.clear()
	for i in range(1, 4):
		var p_icon = find_child("ProIcon%d" % i, true, false) as TextureRect
		var p_label = find_child("ProLabel%d" % i, true, false) as Label
		if p_icon: _pro_icons.append(p_icon)
		if p_label: _pro_labels.append(p_label)
		var c_icon = find_child("ConIcon%d" % i, true, false) as TextureRect
		var c_label = find_child("ConLabel%d" % i, true, false) as Label
		if c_icon: _con_icons.append(c_icon)
		if c_label: _con_labels.append(c_label)

	_top_center_header = find_child("TopCenterHeader", true, false) as VBoxContainer
	if not _top_center_header:
		_top_center_header = find_child("TopLeftHeader", true, false) as VBoxContainer

	_top_right_map_card = find_child("TopRightMapCard", true, false) as PanelContainer
	_carousel_bar = find_child("CarouselBar", true, false) as HBoxContainer
	_footer_bar = find_child("FooterBar", true, false) as HBoxContainer
	_region_season_box = find_child("RegionSeasonBox", true, false) as Control

	# Connect navigation signals
	prev_btn.pressed.connect(_prev_region)
	next_btn.pressed.connect(_next_region)
	start_button.pressed.connect(_on_start_pressed)
	admin_checkbox = find_child("AdminCheckbox", true, false) as CheckBox
	if admin_checkbox:
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
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
		style_wood_btn = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres")
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres"):
		style_wood_hov = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres")
	if ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonPressed.tres"):
		style_wood_press = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonPressed.tres")

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
	_mode_select_view = find_child("ModeSelectView", true, false) as Control
	_mode_index_label = find_child("ModeIndexLabel", true, false) as Label
	_mode_name_label = find_child("ModeNameLabel", true, false) as Label
	_mode_tagline_label = find_child("ModeTaglineLabel", true, false) as Label
	_mode_desc_label = find_child("ModeDescLabel", true, false) as Label
	_pillar1_title = find_child("Pillar1Title", true, false) as Label
	_pillar1_body = find_child("Pillar1Body", true, false) as Label
	_pillar2_title = find_child("Pillar2Title", true, false) as Label
	_pillar2_body = find_child("Pillar2Body", true, false) as Label
	_pillar3_title = find_child("Pillar3Title", true, false) as Label
	_pillar3_body = find_child("Pillar3Body", true, false) as Label
	_mode_season_container = find_child("ModeSeasonContainer", true, false) as Control
	_mode_season_explain_label = find_child("ModeSeasonExplainLabel", true, false) as Label
	_career_perks_container = find_child("CareerPerksContainer", true, false) as Control
	_mode_start_btn = find_child("ModeStartBtn", true, false) as Button
	_mode_load_btn = find_child("ModeLoadBtn", true, false) as Button

	# Mode Hover Card
	_mode_hover_card = find_child("ModeHoverCard", true, false) as PanelContainer
	_hover_title_label = find_child("HoverTitleLabel", true, false) as Label
	_hover_tagline_label = find_child("HoverTaglineLabel", true, false) as Label
	_hover_desc_label = find_child("HoverDescLabel", true, false) as Label
	_hover_tip_label = find_child("HoverTipLabel", true, false) as Label
	if _mode_hover_card:
		_mode_hover_card.visible = false
		_mode_hover_card.modulate.a = 0.0

	# Connect navigation and button signals
	var prev_btn = find_child("PrevModeBtn", true, false) as TextureButton
	if prev_btn:
		prev_btn.pressed.connect(_prev_mode)
	var next_btn = find_child("NextModeBtn", true, false) as TextureButton
	if next_btn:
		next_btn.pressed.connect(_next_mode)
	if _mode_start_btn:
		_mode_start_btn.pressed.connect(func():
			_hide_mode_hover_card_immediate()
			_select_game_mode("campaign")
		)
	if _mode_load_btn:
		_mode_load_btn.tooltip_text = " ".join(MODE_EXPLANATIONS["saves"]["sentences"])
		_mode_load_btn.mouse_entered.connect(func(): _on_mode_button_hovered("saves", _mode_load_btn))
		_mode_load_btn.mouse_exited.connect(func(): _on_mode_button_unhovered("saves"))
		_mode_load_btn.pressed.connect(func():
			_hide_mode_hover_card_immediate()
			_open_load_modal()
		)

	_side_campaign_btn = find_child("SideCampaignBtn", true, false) as Button
	if _side_campaign_btn:
		_side_campaign_btn.tooltip_text = " ".join(MODE_EXPLANATIONS["campaign"]["sentences"])
		_side_campaign_btn.mouse_entered.connect(func(): _on_mode_button_hovered("campaign", _side_campaign_btn))
		_side_campaign_btn.mouse_exited.connect(func(): _on_mode_button_unhovered("campaign"))
		_side_campaign_btn.pressed.connect(func():
			_hide_mode_hover_card_immediate()
			_select_game_mode("campaign")
		)

	_side_career_btn = find_child("SideCareerBtn", true, false) as Button
	if _side_career_btn:
		_side_career_btn.tooltip_text = " ".join(MODE_EXPLANATIONS["career"]["sentences"])
		_side_career_btn.mouse_entered.connect(func(): _on_mode_button_hovered("career", _side_career_btn))
		_side_career_btn.mouse_exited.connect(func(): _on_mode_button_unhovered("career"))
		_side_career_btn.pressed.connect(func():
			_hide_mode_hover_card_immediate()
			_select_game_mode("career")
		)

	# The single admin debug checkbox is located on the main menu left panel
	if admin_checkbox:
		admin_checkbox.tooltip_text = "Press backtick (`) in-game to toggle developer console (add cash, speed crops, test weather)."

	_mode_leaderboard_btn = find_child("ModeLeaderboardBtn", true, false) as Button
	if _mode_leaderboard_btn:
		_mode_leaderboard_btn.tooltip_text = " ".join(MODE_EXPLANATIONS["hall_of_fame"]["sentences"])
		_mode_leaderboard_btn.mouse_entered.connect(func(): _on_mode_button_hovered("hall_of_fame", _mode_leaderboard_btn))
		_mode_leaderboard_btn.mouse_exited.connect(func(): _on_mode_button_unhovered("hall_of_fame"))
		_mode_leaderboard_btn.pressed.connect(func():
			_hide_mode_hover_card_immediate()
			_open_leaderboard_modal()
		)

	var s30 = find_child("Season30Btn", true, false) as Button
	var s60 = find_child("Season60Btn", true, false) as Button
	var s90 = find_child("Season90Btn", true, false) as Button
	_mode_season_buttons = {}
	if s30:
		_mode_season_buttons[30] = s30
		s30.pressed.connect(func(): _set_mode_season_duration(30))
	if s60:
		_mode_season_buttons[60] = s60
		s60.pressed.connect(func(): _set_mode_season_duration(60))
	if s90:
		_mode_season_buttons[90] = s90
		s90.pressed.connect(func(): _set_mode_season_duration(90))

	_select_mode_carousel(0)

func _prev_mode() -> void:
	_select_mode_carousel(current_mode_idx - 1)

func _next_mode() -> void:
	_select_mode_carousel(current_mode_idx + 1)

func _select_mode_carousel(idx: int) -> void:
	current_mode_idx = (idx % mode_keys.size() + mode_keys.size()) % mode_keys.size()
	var mode_id: String = mode_keys[current_mode_idx]
	Data.game_mode = mode_id

	# Update side button styles based on active mode
	if _side_campaign_btn and _side_career_btn:
		if mode_id == "campaign":
			if style_gold_btn:
				_side_campaign_btn.add_theme_stylebox_override("normal", style_gold_btn)
				_side_campaign_btn.add_theme_stylebox_override("hover", style_gold_hov)
				_side_campaign_btn.add_theme_stylebox_override("pressed", style_gold_press)
			_side_campaign_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
			_side_campaign_btn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02, 1.0))

			if style_wood_btn:
				_side_career_btn.add_theme_stylebox_override("normal", style_wood_btn)
				_side_career_btn.add_theme_stylebox_override("hover", style_wood_hov)
				_side_career_btn.add_theme_stylebox_override("pressed", style_wood_press)
			_side_career_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
			_side_career_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
		else:
			if style_wood_btn:
				_side_campaign_btn.add_theme_stylebox_override("normal", style_wood_btn)
				_side_campaign_btn.add_theme_stylebox_override("hover", style_wood_hov)
				_side_campaign_btn.add_theme_stylebox_override("pressed", style_wood_press)
			_side_campaign_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
			_side_campaign_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))

			if style_gold_btn:
				_side_career_btn.add_theme_stylebox_override("normal", style_gold_btn)
				_side_career_btn.add_theme_stylebox_override("hover", style_gold_hov)
				_side_career_btn.add_theme_stylebox_override("pressed", style_gold_press)
			_side_career_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
			_side_career_btn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02, 1.0))

	if mode_id == "campaign":
		if _mode_index_label: _mode_index_label.text = "GAME MODE 1 OF 2"
		if _mode_name_label: _mode_name_label.text = "🏆 TIMED RTS CAMPAIGN"
		if _mode_tagline_label: _mode_tagline_label.text = "[ COMPETITIVE SCORE ATTACK • 30–90 DAYS ]"
		if _mode_desc_label: _mode_desc_label.text = "Race against the seasonal clock in a high-stakes agricultural sprint across Mindanao! Cultivate strategic crop rotations, optimize harvesting logistics, and fulfill export contracts through regional shipping hubs."

		if _pillar1_title: _pillar1_title.text = "⏱️ Season Timer"
		if _pillar1_body: _pillar1_body.text = "• Choose 30, 60, or 90 days.\n• Day/Night clock (3 min/day).\n• Early harvest before typhoons."

		if _pillar2_title: _pillar2_title.text = "🏆 Rival League"
		if _pillar2_body: _pillar2_body.text = "• Compete against 8 AI rivals.\n• Grade A crops give 2.5× points.\n• Fast deliveries build combos."

		if _pillar3_title: _pillar3_title.text = "🎖️ Tycoon Prestige"
		if _pillar3_body: _pillar3_body.text = "• Climb 5 prestige tiers.\n• Regional bonuses up to +30%.\n• Saved in Hall of Fame."

		if _mode_season_container: _mode_season_container.visible = true
		if _mode_season_explain_label: _mode_season_explain_label.visible = true
		if _career_perks_container: _career_perks_container.visible = false
		_update_mode_season_buttons_ui()

		if _mode_start_btn: _mode_start_btn.text = "PROCEED TO REGIONS  >"
	else:
		if _mode_index_label: _mode_index_label.text = "GAME MODE 2 OF 2"
		if _mode_name_label: _mode_name_label.text = "🌾 CAREER / ENDLESS TYCOON"
		if _mode_tagline_label: _mode_tagline_label.text = "[ RELAXED ENDLESS SANDBOX • SAVE & LOAD ]"
		if _mode_desc_label: _mode_desc_label.text = "Cultivate and expand your agricultural empire at your own relaxed pace with no time limits or countdown pressure. Clear dense wilderness, purchase all 4 island territory deeds, construct advanced drying infrastructure, and build thriving perennial groves with full save and load support anytime."

		if _pillar1_title: _pillar1_title.text = "🌾 Unlimited Sandbox"
		if _pillar1_body: _pillar1_body.text = "• Play for 100+ days with no deadlines.\n• Expand across all 24x24 plots.\n• Build dryers, silos, and hire workers."

		if _pillar2_title: _pillar2_title.text = "💾 5 Save Slots"
		if _pillar2_body: _pillar2_body.text = "• In-game save and load anytime.\n• Saves money, buildings, tiles, and market.\n• Resume farm from menu or pause screen."

		if _pillar3_title: _pillar3_title.text = "🌙 Auto-Saves"
		if _pillar3_body: _pillar3_body.text = "• Game automatically saves every midnight.\n• Safe against accidental closures.\n• Grow multi-tile Banana & Coconut groves."

		if _mode_season_container: _mode_season_container.visible = false
		if _mode_season_explain_label: _mode_season_explain_label.visible = false
		if _career_perks_container: _career_perks_container.visible = true

		if _mode_start_btn: _mode_start_btn.text = "PROCEED TO REGIONS  >"

func _on_mode_start_pressed() -> void:
	_select_game_mode(mode_keys[current_mode_idx])

func _set_mode_season_duration(days: int) -> void:
	_select_season_duration(days)
	_update_mode_season_buttons_ui()
	_update_start_button_text()
	if _mode_badge_label and Data.game_mode == "campaign":
		_mode_badge_label.text = "[ TIMED CAMPAIGN: %d DAYS ]" % Data.selected_season_days

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
			btn.add_theme_font_size_override("font_size", 14)
		else:
			var inactive_style = style_wood_btn if style_wood_btn else style_brown_btn
			var inactive_hov = style_wood_hov if style_wood_hov else style_brown_hov
			var inactive_press = style_wood_press if style_wood_press else style_brown_press
			if inactive_style:
				btn.add_theme_stylebox_override("normal", inactive_style)
				btn.add_theme_stylebox_override("hover", inactive_hov)
				btn.add_theme_stylebox_override("pressed", inactive_press)
			btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
			btn.add_theme_font_size_override("font_size", 14)

	if _mode_season_explain_label:
		if Data.selected_season_days == 30:
			_mode_season_explain_label.text = "Quick 30-Day Sprint (1 Month) — Fast, intense pace focused on short-cycle cash crops (Palay & Corn)."
		elif Data.selected_season_days == 90:
			_mode_season_explain_label.text = "Full 90-Day Quarter (3 Months) — Deep strategic campaign enabling massive multi-tile perennial plantation investments."
		else:
			_mode_season_explain_label.text = "Standard 60-Day Campaign (2 Months) — Balanced timeline allowing all 7 crops and perennial groves to mature."

func _on_mode_button_hovered(mode_id: String, source_button: Button) -> void:
	if not _mode_hover_card or not is_instance_valid(_mode_hover_card):
		return
	if _mode_select_view and not _mode_select_view.visible:
		return
	if not MODE_EXPLANATIONS.has(mode_id):
		return

	_current_hovered_mode = mode_id
	var data: Dictionary = MODE_EXPLANATIONS[mode_id]

	if _hover_title_label:
		_hover_title_label.text = data.get("title", "")
	if _hover_tagline_label:
		_hover_tagline_label.text = data.get("tagline", "")
	if _hover_desc_label:
		var sentences: Array = data.get("sentences", [])
		var lines: Array = []
		for s in sentences:
			lines.append("• " + str(s))
		_hover_desc_label.text = "\n".join(lines)
	if _hover_tip_label:
		_hover_tip_label.text = data.get("tip", "")

	# Compute target Y position aligned with button
	var btn_global_y: float = 120.0
	if source_button and is_instance_valid(source_button):
		btn_global_y = source_button.global_position.y
	var target_y: float = clampf(btn_global_y - 14.0, 70.0, 430.0)

	if _hover_card_tween and _hover_card_tween.is_valid():
		_hover_card_tween.kill()

	_hover_card_tween = create_tween().set_parallel(true)
	if not _mode_hover_card.visible or _mode_hover_card.modulate.a < 0.05:
		_mode_hover_card.position.x = 345.0
		_mode_hover_card.position.y = target_y + 4.0
		_mode_hover_card.modulate.a = 0.0
		_mode_hover_card.visible = true
		_hover_card_tween.tween_property(_mode_hover_card, "position:x", 355.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hover_card_tween.tween_property(_mode_hover_card, "position:y", target_y, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hover_card_tween.tween_property(_mode_hover_card, "modulate:a", 1.0, 0.12)
	else:
		_hover_card_tween.tween_property(_mode_hover_card, "position:y", target_y, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hover_card_tween.tween_property(_mode_hover_card, "position:x", 355.0, 0.10)
		_hover_card_tween.tween_property(_mode_hover_card, "modulate:a", 1.0, 0.08)

func _on_mode_button_unhovered(mode_id: String) -> void:
	if _current_hovered_mode != mode_id:
		return
	_current_hovered_mode = ""

	if not _mode_hover_card or not is_instance_valid(_mode_hover_card):
		return

	if _hover_card_tween and _hover_card_tween.is_valid():
		_hover_card_tween.kill()

	_hover_card_tween = create_tween().set_parallel(true)
	_hover_card_tween.tween_property(_mode_hover_card, "modulate:a", 0.0, 0.12)
	_hover_card_tween.tween_property(_mode_hover_card, "position:x", 345.0, 0.12)
	_hover_card_tween.chain().tween_callback(func():
		if _current_hovered_mode == "" and _mode_hover_card and is_instance_valid(_mode_hover_card):
			_mode_hover_card.visible = false
	)

func _hide_mode_hover_card_immediate() -> void:
	_current_hovered_mode = ""
	if _hover_card_tween and _hover_card_tween.is_valid():
		_hover_card_tween.kill()
	if _mode_hover_card and is_instance_valid(_mode_hover_card):
		_mode_hover_card.visible = false
		_mode_hover_card.modulate.a = 0.0

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
	_back_to_modes_btn.text = "<  GAME MODES"
	_back_to_modes_btn.custom_minimum_size = Vector2(190, 38)
	_back_to_modes_btn.add_theme_font_size_override("font_size", 14)
	_back_to_modes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if style_wood_btn:
		_back_to_modes_btn.add_theme_stylebox_override("normal", style_wood_btn)
		_back_to_modes_btn.add_theme_stylebox_override("hover", style_wood_hov)
		_back_to_modes_btn.add_theme_stylebox_override("pressed", style_wood_press)
	elif style_brown_btn:
		_back_to_modes_btn.add_theme_stylebox_override("normal", style_brown_btn)
		_back_to_modes_btn.add_theme_stylebox_override("hover", style_brown_hov)
		_back_to_modes_btn.add_theme_stylebox_override("pressed", style_brown_press)
	_back_to_modes_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
	_back_to_modes_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
	_back_to_modes_btn.pressed.connect(_show_mode_select)
	_region_nav_box.add_child(_back_to_modes_btn)

	_mode_badge_label = Label.new()
	_mode_badge_label.text = "[ TIMED CAMPAIGN ]"
	_mode_badge_label.add_theme_font_size_override("font_size", 13)
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
	_hide_mode_hover_card_immediate()
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
	_hide_mode_hover_card_immediate()
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

	if _region_season_box:
		_region_season_box.visible = (Data.game_mode == "campaign")
		if Data.game_mode == "campaign":
			_update_mode_season_buttons_ui()

	if _mode_badge_label:
		if Data.game_mode == "campaign":
			_mode_badge_label.text = "[ TIMED CAMPAIGN: %d DAYS ]" % Data.selected_season_days
			_mode_badge_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40, 1.0))
		else:
			_mode_badge_label.text = "[ CAREER: ENDLESS ]"
			_mode_badge_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))

	# Update clean status notice in footer
	if _career_notice_label:
		if Data.game_mode == "campaign":
			_career_notice_label.visible = false
		else:
			_career_notice_label.text = "🌾 Endless Sandbox • Full Save & Load Enabled"
			_career_notice_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65, 0.95))
			_career_notice_label.visible = true

	_update_start_button_text()

func _open_leaderboard_modal() -> void:
	var lb_cls = load("res://src/ui/LeaderboardPanel.gd")
	if lb_cls:
		var lb = lb_cls.new()
		add_child(lb)

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
		pros_str += "• %s\n" % p
	pros_text.text = pros_str.strip_edges()

	var cons_array: Array = r_data.get("cons", [])
	var cons_str: String = ""
	for c in cons_array:
		cons_str += "• %s\n" % c
	cons_text.text = cons_str.strip_edges()

	# Populate visual pro and con rows with pixel-art icons and clear text
	var key: String = region_keys[current_idx]
	var factors: Dictionary = REGION_VISUAL_FACTORS.get(key, {})
	var visual_pros: Array = factors.get("pros", [])
	for i in range(mini(_pro_icons.size(), visual_pros.size())):
		var item: Dictionary = visual_pros[i]
		var icon_path: String = item.get("icon", "")
		if ResourceLoader.exists(icon_path):
			_pro_icons[i].texture = load(icon_path)
		_pro_labels[i].text = item.get("text", "")

	var visual_cons: Array = factors.get("cons", [])
	for i in range(mini(_con_icons.size(), visual_cons.size())):
		var item: Dictionary = visual_cons[i]
		var icon_path: String = item.get("icon", "")
		if ResourceLoader.exists(icon_path):
			_con_icons[i].texture = load(icon_path)
		_con_labels[i].text = item.get("text", "")

	_update_start_button_text()

func _setup_season_selector() -> void:
	var footer_bar := find_child("FooterBar", true, false) as HBoxContainer
	if not footer_bar:
		return

	# Clean status notice label for footer in Region Select
	_career_notice_label = Label.new()
	_career_notice_label.name = "CareerNoticeLabel"
	_career_notice_label.text = "🌾 Endless Sandbox • Full Save & Load Enabled"
	_career_notice_label.add_theme_font_size_override("font_size", 14)
	_career_notice_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65, 0.95))
	_career_notice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_career_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_career_notice_label.visible = false

	# Insert before RegionSeasonBox in FooterBar
	var insert_idx: int = _region_season_box.get_index() if _region_season_box else start_button.get_index()
	footer_bar.add_child(_career_notice_label)
	footer_bar.move_child(_career_notice_label, insert_idx)

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
	if admin_checkbox and admin_checkbox.button_pressed != on:
		admin_checkbox.set_pressed_no_signal(on)
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
