# TrailerModal.gd
# Fullscreen 105-second (1m 45s) Factorio-style Cinematic Game Trailer for Agri-Region Tycoon.
# Uses a live SubViewport running the ACTUAL in-game FarmGrid, Farmer workers, FarmDrones,
# Buildings, Crop sprites, Decorations, and Regional Map assets with slow, unhurried camera work.

class_name TrailerModal
extends CanvasLayer

signal closed()

const TOTAL_DURATION: float = 105.0

const CHAPTERS: Array[Dictionary] = [
	{"id": 0, "start": 0.0,  "end": 20.0,  "title": "I. TARGET: MINDANAO",     "subtitle": "From Orbit to the Philippines — Region XII (SOCCSKSARGEN)"},
	{"id": 1, "start": 20.0, "end": 44.0,  "title": "II. HUMBLE BEGINNINGS",   "subtitle": "One Farmer, One Homestead, and Manual Labor"},
	{"id": 2, "start": 44.0, "end": 70.0,  "title": "III. EXPANDING THE ESTATE", "subtitle": "Irrigation Networks, Multi-Crop Fields & Worker Squads"},
	{"id": 3, "start": 70.0, "end": 94.0,  "title": "IV. FULL AUTOMATION",     "subtitle": "Autonomous Drone Fleets, Processing Mills & Fiesta Plaza"},
	{"id": 4, "start": 94.0, "end": 105.0, "title": "V. AGRI-REGION TYCOON",   "subtitle": "Five Distinct Provinces. One Agricultural Empire."}
]

const FarmerMovementScript = preload("res://src/farmer/FarmerMovement.gd")

var _pixel_font: FontFile = null

# Safe autoload accessors (works both in full game and standalone --script tests)
func _au() -> Node: return get_node_or_null("/root/AudioManager")
func _da() -> Node: return get_node_or_null("/root/Data")
func _ec() -> Node: return get_node_or_null("/root/EconomyManager")
func _ti() -> Node: return get_node_or_null("/root/TimeManager")
func _bm() -> Node: return get_node_or_null("/root/BuildingManager")
func _tm() -> Node: return get_node_or_null("/root/TaskManager")
func _mm() -> Node: return get_node_or_null("/root/MarketManager")

# Playback state
var _elapsed: float = 0.0
var _is_playing: bool = true
var _playback_speed: float = 1.0
var _active_chapter_idx: int = -1

# Saved autoload state for clean restoration when closing trailer
var _saved_game_mode: String = "campaign"
var _saved_region: String = "cotabato"
var _saved_cash: int = 250
var _saved_speed_scale: float = 1.0
var _saved_hour: int = 8
var _saved_muted: bool = false

# UI Nodes
var _root_ctrl: Control = null
var _viewport_holder: SubViewportContainer = null
var _sub_viewport: SubViewport = null
var _world_root: Node2D = null
var _game_camera: Camera2D = null
var _farm_grid: Node2D = null
var _weather_fx: Node2D = null
var _farmers: Array[CharacterBody2D] = []

# Intro & Finale Overlays (rendered above SubViewport when in Chapter I or V)
var _intro_canvas: Control = null
var _cut_fade_rect: ColorRect = null
var _chapter_pill_btns: Array[Button] = []
var _chapter_badge_lbl: Label = null
var _subtitle_lbl: Label = null
var _caption_main_lbl: Label = null
var _caption_sub_lbl: Label = null
var _time_lbl: Label = null
var _play_pause_btn: Button = null
var _speed_btn: Button = null
var _progress_bar: ProgressBar = null
var _finale_cta_box: HBoxContainer = null

# Cached textures for Intro (Chapter I) & Finale (Chapter V)
var _globe_frames: Array[ImageTexture] = []
var _tex_ph_map: Texture2D = null
var _tex_cotabato_loc: Texture2D = null
var _region_bg_textures: Dictionary = {}
var _region_monument_textures: Dictionary = {}

# Real gameplay choreography flags
var _scene2_choreo_step: int = 0
var _scene2_crop_timer: float = 0.0
var _worker_loop_timer: float = 0.0

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/font/quill_and_antler/quill-and-antler.ttf"):
		_pixel_font = load("res://assets/font/quill_and_antler/quill-and-antler.ttf")

	_save_autoload_state()
	_load_trailer_textures()
	_generate_pixel_globe_frames()
	_build_ui()
	_setup_real_gameplay_world()
	_sync_timeline(0.0, true)

	if _au():
		_au().play_ui("click")

func _save_autoload_state() -> void:
	if _da():
		_saved_game_mode = _da().game_mode
		_saved_region = _da().current_region
	if _ec():
		_saved_cash = _ec().cash
	if _ti():
		_saved_speed_scale = _ti().get_speed_scale()
		_saved_hour = _ti().current_hour
	if _au():
		_saved_muted = _au().is_muted

func _restore_autoload_state() -> void:
	if _au():
		_au().stop_build_loop()
		_au().is_muted = true

	if is_instance_valid(_farm_grid):
		for modal_prop in ["building_card_popup", "weather_app_modal", "land_modal", "early_harvest_modal"]:
			var m = _farm_grid.get(modal_prop)
			if is_instance_valid(m) and m.get_parent() == null:
				m.free()

	if _tm():
		_tm().cancel_all_tasks()
		_tm().selected_farmers.clear()

	if _bm():
		_bm().placed_buildings.clear()
		_bm().purchased_buildings.clear()
		_bm().unlocked_techs.clear()
		_bm().active_drones = 0
		_bm().recalculate_bonuses()

	if _mm():
		_mm().stored_inventory.clear()

	if _da():
		_da().game_mode = _saved_game_mode
		_da().current_region = _saved_region
	if _ec():
		_ec().cash = _saved_cash
	if _ti():
		_ti().current_hour = _saved_hour
		_ti().set_speed_scale(_saved_speed_scale)

	if _au():
		_au().is_muted = _saved_muted

func _load_trailer_textures() -> void:
	var ph_path := "res://assets/Regions Art/Cotabto/ph_transparent.png"
	if ResourceLoader.exists(ph_path):
		_tex_ph_map = load(ph_path)
	var loc_path := "res://assets/Regions Art/Cotabto/cotabato location.png"
	if ResourceLoader.exists(loc_path):
		_tex_cotabato_loc = load(loc_path)

	var bg_paths := {
		"cotabato": "res://assets/Regions Art/Cotabto/Cotabato BG.png",
		"south_cotabato": "res://assets/Regions Art/South Cotabato/South Cotabato BG.png",
		"sarangani": "res://assets/Regions Art/Sarangani/Sarangani BG.png",
		"sultan_kudarat": "res://assets/Regions Art/Sulat Kudarat/Sultan Kudarat BG.png",
		"general_santos": "res://assets/Regions Art/Genaral Santos/General Santos.png",
	}
	for k in bg_paths.keys():
		var p: String = bg_paths[k]
		if ResourceLoader.exists(p):
			_region_bg_textures[k] = load(p)

	var mon_paths := {
		"cotabato": "res://assets/sprites/Field/Obstacles/Monuments/Cotabato/bangkapayapaan_monument.png",
		"south_cotabato": "res://assets/sprites/Field/Obstacles/Monuments/South Cotabato/surallah_tri_people_monument.png",
		"sarangani": "res://assets/sprites/Field/Obstacles/Monuments/Sarangani/maitum_anthropomorphic_replicas.png",
		"sultan_kudarat": "res://assets/sprites/Field/Obstacles/Monuments/Sultan Kudarat/Sultan_Kudarat_Monument.png",
		"general_santos": "res://assets/sprites/Field/Obstacles/Monuments/General Santos/gen_paulino_santos_monument.png",
	}
	for k in mon_paths.keys():
		var p: String = mon_paths[k]
		if ResourceLoader.exists(p):
			_region_monument_textures[k] = load(p)

func _generate_pixel_globe_frames() -> void:
	# Pre-renders 24 crisp nearest-neighbor pixel-art frames of Earth rotating toward SE Asia / Philippines
	var size: int = 120
	var half: float = float(size) * 0.5
	var radius: float = 52.0
	var num_frames: int = 24
	for f in range(num_frames):
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var rot_lon: float = lerpf(-75.0, 122.0, float(f) / float(num_frames - 1))
		for py in range(size):
			for px in range(size):
				var dx: float = (float(px) - half) / radius
				var dy: float = (float(py) - half) / radius
				var d2: float = dx * dx + dy * dy
				if d2 > 1.08:
					continue
				if d2 > 1.0:
					# Outer atmosphere pixel rim
					img.set_pixel(px, py, Color(0.28, 0.68, 0.96, 0.45))
					continue
				var dz: float = sqrt(maxf(0.0, 1.0 - d2))
				var lat: float = rad_to_deg(asin(clampf(-dy, -1.0, 1.0)))
				var lon: float = rot_lon + rad_to_deg(atan2(dx, dz))
				while lon > 180.0:
					lon -= 360.0
				while lon < -180.0:
					lon += 360.0

				var is_land: bool = _is_world_land_pixel(lat, lon)
				var is_ph: bool = (lat >= 5.0 and lat <= 19.0 and lon >= 118.0 and lon <= 127.0)
				var light: float = clampf(dz * 0.85 + (-dx * 0.25) + (-dy * 0.20), 0.22, 1.0)
				# Quantize lighting into 4 retro pixel-art bands
				light = floor(light * 4.0) / 4.0

				var col: Color
				if is_ph:
					col = Color(0.45, 0.92, 0.36, 1.0).darkened(1.0 - light)
				elif is_land:
					col = Color(0.24, 0.62, 0.30, 1.0).darkened(1.0 - light)
				else:
					col = Color(0.08, 0.28, 0.56, 1.0).darkened((1.0 - light) * 0.75)

				# Subtle latitude/longitude grid lines every 30 deg
				if absf(fmod(absf(lat), 30.0)) < 1.4 or absf(fmod(absf(lon), 30.0)) < 1.4:
					col = col.lightened(0.08)

				img.set_pixel(px, py, col)
		_globe_frames.append(ImageTexture.create_from_image(img))

func _is_world_land_pixel(lat: float, lon: float) -> bool:
	# Simplified pixel continent masks so the rotating pixel globe has recognizable continents + Philippines
	# Philippines archipelago
	if lat >= 5.2 and lat <= 18.8 and lon >= 119.5 and lon <= 126.6:
		return true
	# Eurasia
	if lat >= 18.0 and lat <= 70.0 and lon >= 0.0 and lon <= 145.0:
		if lat < 25.0 and (lon < 70.0 or (lon > 90.0 and lon < 98.0)):
			return false
		return true
	# SE Asia / Maritime continent (Borneo, Sulawesi, Sumatra, Java)
	if lat >= -9.0 and lat <= 18.0 and lon >= 96.0 and lon <= 140.0:
		var n: float = sin(lat * 0.45) * cos(lon * 0.38)
		return n > 0.15
	# Australia
	if lat >= -38.0 and lat <= -12.0 and lon >= 114.0 and lon <= 153.0:
		return true
	# Africa
	if lat >= -34.0 and lat <= 35.0 and lon >= -16.0 and lon <= 50.0:
		if lat < 0.0 and lon < 10.0:
			return false
		return true
	# Americas
	if lat >= -52.0 and lat <= 68.0 and lon >= -130.0 and lon <= -35.0:
		if lat > 10.0 and lon > -65.0:
			return false
		if lat <= 10.0 and lon < -82.0:
			return false
		return true
	return false

# =============================================================================
# UI & SUBVIEWPORT CONSTRUCTION
# =============================================================================
func _build_ui() -> void:
	_root_ctrl = Control.new()
	_root_ctrl.name = "TrailerRoot"
	_root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_ctrl)

	var bg_black := ColorRect.new()
	bg_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_black.color = Color(0.03, 0.05, 0.04, 1.0)
	_root_ctrl.add_child(bg_black)

	# 1. Live Gameplay SubViewportContainer (fills screen behind letterbox bars)
	_viewport_holder = SubViewportContainer.new()
	_viewport_holder.name = "GameplayViewportHolder"
	_viewport_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_holder.stretch = true
	_viewport_holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_viewport_holder)

	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "GameplaySubViewport"
	_sub_viewport.size = Vector2i(1280, 720)
	_sub_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_sub_viewport.handle_input_locally = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_holder.add_child(_sub_viewport)

	# 2. Custom Canvas for Chapter I (Orbit -> PH -> Mindanao) and Chapter V (5 Regions & Finale)
	_intro_canvas = Control.new()
	_intro_canvas.name = "IntroAndFinaleCanvas"
	_intro_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_intro_canvas.draw.connect(_draw_intro_and_finale)
	_root_ctrl.add_child(_intro_canvas)

	# 3. Clean Fade-Through-Black Cut Overlay (prevents jarring jumps between acts)
	_cut_fade_rect = ColorRect.new()
	_cut_fade_rect.name = "CutFadeOverlay"
	_cut_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cut_fade_rect.color = Color(0.02, 0.03, 0.03, 0.0)
	_cut_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_cut_fade_rect)

	# 4. Top Letterbox Bar (70px)
	var top_bar := PanelContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_bottom = 68.0
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color(0.04, 0.06, 0.05, 0.94)
	top_sb.border_width_bottom = 2
	top_sb.border_color = Color(0.78, 0.62, 0.24, 0.70)
	top_sb.content_margin_left = 22
	top_sb.content_margin_right = 22
	top_sb.content_margin_top = 10
	top_sb.content_margin_bottom = 10
	top_bar.add_theme_stylebox_override("panel", top_sb)
	_root_ctrl.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_bar.add_child(top_hbox)

	var rec_badge := Label.new()
	rec_badge.text = "🎬 OFFICIAL GAMEPLAY TRAILER"
	if _pixel_font:
		rec_badge.add_theme_font_override("font", _pixel_font)
	rec_badge.add_theme_font_size_override("font_size", 16)
	rec_badge.add_theme_color_override("font_color", Color(0.96, 0.78, 0.30))
	top_hbox.add_child(rec_badge)

	var sep1 := VSeparator.new()
	top_hbox.add_child(sep1)

	_chapter_badge_lbl = Label.new()
	_chapter_badge_lbl.text = "I. TARGET: MINDANAO"
	if _pixel_font:
		_chapter_badge_lbl.add_theme_font_override("font", _pixel_font)
	_chapter_badge_lbl.add_theme_font_size_override("font_size", 18)
	_chapter_badge_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	top_hbox.add_child(_chapter_badge_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.text = "— From Orbit to the Philippines"
	_subtitle_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _pixel_font:
		_subtitle_lbl.add_theme_font_override("font", _pixel_font)
	_subtitle_lbl.add_theme_font_size_override("font_size", 14)
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.74))
	top_hbox.add_child(_subtitle_lbl)

	var close_btn := _make_button("✕ SKIP / RETURN TO MENU (ESC)", Color(0.42, 0.16, 0.14), Color(0.88, 0.42, 0.36))
	close_btn.pressed.connect(_close_trailer)
	top_hbox.add_child(close_btn)

	# 5. Cinematic Caption Box (Lower-third above bottom letterbox bar)
	var caption_panel := PanelContainer.new()
	caption_panel.anchor_left = 0.12
	caption_panel.anchor_right = 0.88
	caption_panel.anchor_top = 1.0
	caption_panel.anchor_bottom = 1.0
	caption_panel.offset_top = -170.0
	caption_panel.offset_bottom = -98.0
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap_sb := StyleBoxFlat.new()
	cap_sb.bg_color = Color(0.04, 0.07, 0.05, 0.82)
	cap_sb.border_width_left = 3
	cap_sb.border_width_right = 3
	cap_sb.border_width_top = 1
	cap_sb.border_width_bottom = 1
	cap_sb.border_color = Color(0.86, 0.68, 0.24, 0.85)
	cap_sb.set_corner_radius_all(6)
	cap_sb.content_margin_left = 20
	cap_sb.content_margin_right = 20
	cap_sb.content_margin_top = 8
	cap_sb.content_margin_bottom = 8
	caption_panel.add_theme_stylebox_override("panel", cap_sb)
	_root_ctrl.add_child(caption_panel)

	var cap_vbox := VBoxContainer.new()
	cap_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cap_vbox.add_theme_constant_override("separation", 3)
	caption_panel.add_child(cap_vbox)

	_caption_main_lbl = Label.new()
	_caption_main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font:
		_caption_main_lbl.add_theme_font_override("font", _pixel_font)
	_caption_main_lbl.add_theme_font_size_override("font_size", 20)
	_caption_main_lbl.add_theme_color_override("font_color", Color(0.99, 0.94, 0.78))
	_caption_main_lbl.add_theme_constant_override("outline_size", 3)
	_caption_main_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	cap_vbox.add_child(_caption_main_lbl)

	_caption_sub_lbl = Label.new()
	_caption_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font:
		_caption_sub_lbl.add_theme_font_override("font", _pixel_font)
	_caption_sub_lbl.add_theme_font_size_override("font_size", 14)
	_caption_sub_lbl.add_theme_color_override("font_color", Color(0.80, 0.88, 0.80))
	cap_vbox.add_child(_caption_sub_lbl)

	# 6. Finale CTA Buttons (Shown at end of Chapter V)
	_finale_cta_box = HBoxContainer.new()
	_finale_cta_box.visible = false
	_finale_cta_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_finale_cta_box.add_theme_constant_override("separation", 20)
	_finale_cta_box.anchor_left = 0.25
	_finale_cta_box.anchor_right = 0.75
	_finale_cta_box.anchor_top = 0.70
	_finale_cta_box.anchor_bottom = 0.78
	_root_ctrl.add_child(_finale_cta_box)

	var replay_btn := _make_button("🔄 REPLAY TRAILER", Color(0.16, 0.30, 0.22), Color(0.45, 0.82, 0.56))
	replay_btn.custom_minimum_size = Vector2(210, 46)
	replay_btn.pressed.connect(func():
		if _au():
			_au().play_ui("click")
		_jump_to_time(0.0)
		_is_playing = true
		_update_control_buttons()
	)
	_finale_cta_box.add_child(replay_btn)

	var play_now_btn := _make_button("🌾 PLAY AGRI-REGION TYCOON", Color(0.44, 0.30, 0.08), Color(0.96, 0.78, 0.28))
	play_now_btn.custom_minimum_size = Vector2(260, 46)
	play_now_btn.pressed.connect(_close_trailer)
	_finale_cta_box.add_child(play_now_btn)

	# 7. Bottom Letterbox Controls & Chapter Timeline Bar (88px)
	var bot_bar := PanelContainer.new()
	bot_bar.anchor_left = 0.0
	bot_bar.anchor_top = 1.0
	bot_bar.anchor_right = 1.0
	bot_bar.anchor_bottom = 1.0
	bot_bar.offset_top = -88.0
	var bot_sb := StyleBoxFlat.new()
	bot_sb.bg_color = Color(0.04, 0.06, 0.05, 0.95)
	bot_sb.border_width_top = 2
	bot_sb.border_color = Color(0.78, 0.62, 0.24, 0.70)
	bot_sb.content_margin_left = 20
	bot_sb.content_margin_right = 20
	bot_sb.content_margin_top = 8
	bot_sb.content_margin_bottom = 8
	bot_bar.add_theme_stylebox_override("panel", bot_sb)
	_root_ctrl.add_child(bot_bar)

	var bot_vbox := VBoxContainer.new()
	bot_vbox.add_theme_constant_override("separation", 8)
	bot_bar.add_child(bot_vbox)

	# Progress bar row
	var prog_hbox := HBoxContainer.new()
	prog_hbox.add_theme_constant_override("separation", 12)
	bot_vbox.add_child(prog_hbox)

	_play_pause_btn = _make_button("⏸ PAUSE", Color(0.18, 0.26, 0.20), Color(0.55, 0.78, 0.58))
	_play_pause_btn.custom_minimum_size = Vector2(105, 30)
	_play_pause_btn.pressed.connect(_toggle_play_pause)
	prog_hbox.add_child(_play_pause_btn)

	_speed_btn = _make_button("1.0× SPEED", Color(0.22, 0.20, 0.14), Color(0.78, 0.64, 0.28))
	_speed_btn.custom_minimum_size = Vector2(105, 30)
	_speed_btn.pressed.connect(_cycle_speed)
	prog_hbox.add_child(_speed_btn)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = TOTAL_DURATION
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.custom_minimum_size = Vector2(0, 18)
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.12, 0.16, 0.13, 1.0)
	pb_bg.set_corner_radius_all(4)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.92, 0.72, 0.22, 1.0)
	pb_fill.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("background", pb_bg)
	_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	prog_hbox.add_child(_progress_bar)

	_time_lbl = Label.new()
	_time_lbl.text = "00:00 / 01:45"
	if _pixel_font:
		_time_lbl.add_theme_font_override("font", _pixel_font)
	_time_lbl.add_theme_font_size_override("font_size", 15)
	_time_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.76))
	prog_hbox.add_child(_time_lbl)

	# Chapter selector pills row
	var chap_hbox := HBoxContainer.new()
	chap_hbox.add_theme_constant_override("separation", 8)
	bot_vbox.add_child(chap_hbox)

	for i in range(CHAPTERS.size()):
		var ch: Dictionary = CHAPTERS[i]
		var cbtn := _make_button(str(ch["title"]), Color(0.12, 0.16, 0.14), Color(0.38, 0.46, 0.40))
		cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cbtn.custom_minimum_size = Vector2(0, 28)
		var start_t: float = float(ch["start"])
		cbtn.pressed.connect(func():
			if _au():
				_au().play_ui("click")
			_jump_to_time(start_t)
		)
		chap_hbox.add_child(cbtn)
		_chapter_pill_btns.append(cbtn)

func _make_button(text: String, bg_col: Color, border_col: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _pixel_font:
		btn.add_theme_font_override("font", _pixel_font)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4

	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = bg_col.lightened(0.16)
	sb_hover.border_color = border_col.lightened(0.22)

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	return btn

# =============================================================================
# REAL IN-GAME GAMEPLAY WORLD SETUP (Inside SubViewport)
# =============================================================================
func _setup_real_gameplay_world() -> void:
	if _da() == null or _ec() == null or _bm() == null:
		return

	# Mute SFX during instant synchronous world population so placing 45 buildings doesn't spam build audio
	if _au():
		_au().is_muted = true

	# Configure sandbox mode so all 32x32 parcels are unlocked and buildings place instantaneously
	_da().game_mode = "sandbox"
	_da().current_region = "cotabato"
	_ec().cash = 9999999
	if _ti():
		_ti().current_hour = 9
		_ti().set_speed_scale(1.0)

	if _tm():
		_tm().cancel_all_tasks()
		_tm().selected_farmers.clear()
	if _bm():
		_bm().placed_buildings.clear()
		_bm().purchased_buildings.clear()
		_bm().unlocked_techs.clear()
		_bm().active_drones = 0

	# Create Y-sorted root Node2D matching MainGame.tscn
	_world_root = Node2D.new()
	_world_root.name = "MainGameTrailerWorld"
	_world_root.y_sort_enabled = true
	_sub_viewport.add_child(_world_root)

	# Deep background matching MainGame.tscn
	var world_bg := ColorRect.new()
	world_bg.z_index = -100
	world_bg.offset_left = -8000.0
	world_bg.offset_top = -6000.0
	world_bg.offset_right = 10000.0
	world_bg.offset_bottom = 8000.0
	world_bg.color = Color(0.06, 0.11, 0.07, 1.0)
	world_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_root.add_child(world_bg)

	# Camera2D inside SubViewport
	_game_camera = Camera2D.new()
	_game_camera.name = "TrailerCamera"
	_game_camera.enabled = true
	_game_camera.position = FarmerMovementScript.grid_to_pixel_center(Vector2i(3, 3), null)
	_game_camera.zoom = Vector2(1.55, 1.55)
	_world_root.add_child(_game_camera)

	# Real FarmGrid (spawns SeaWater, RegionalMap, OutOfBoundsTerrain, OutOfBoundsForest, TileRenderer, etc.)
	_farm_grid = Node2D.new()
	_farm_grid.name = "FarmGrid"
	_farm_grid.set_script(load("res://src/core/FarmGrid.gd"))
	_farm_grid.set_process_unhandled_input(false)
	_world_root.add_child(_farm_grid)

	# Clear random natural obstacles across the 32x32 grid so our showcase farm layout is clean
	for x in range(32):
		for y in range(32):
			var tile: FarmTile = _farm_grid.get_tile(Vector2i(x, y))
			if tile and tile.state == FarmTile.TileState.OBSTACLE:
				tile.state = FarmTile.TileState.EMPTY
				tile.obstacle_type = ""
				_farm_grid.renderer.update_tile(Vector2i(x, y), _farm_grid.tiles)

	# Populate Zone A (Northwest Homestead 0..7, 0..7): Humble manual farm
	_populate_zone_a_homestead()

	# Populate Zone B (Mid-Island Heartland 8..18, 4..18): Irrigated multi-crop estate
	_populate_zone_b_heartland()

	# Populate Zone C (South & East Megafarm 8..30, 18..30): Drones, Processing Mills, Export Port & Fiesta Plaza
	_populate_zone_c_megafarm_and_fiesta()

	# Spawn 7 Real Farmer Workers (siblings of FarmGrid under _world_root)
	_spawn_real_farmers()

	# WeatherEffects node
	_weather_fx = Node2D.new()
	_weather_fx.name = "WeatherEffects"
	_weather_fx.set_script(load("res://src/world/WeatherEffects.gd"))
	_world_root.add_child(_weather_fx)

	if _au():
		_au().stop_build_loop()
		_au().is_muted = _saved_muted

func _place_showcase_building(pos: Vector2i, b_type: String, target_level: int = 1) -> void:
	if _ec():
		_ec().cash = 9999999
	if _farm_grid.place_building(pos, b_type) and target_level > 1 and _bm():
		var b: Node2D = _bm().get_building_at_tile(pos)
		if b != null:
			b.set("level", target_level)
			b.queue_redraw()
			_bm().recalculate_bonuses()

func _plant_showcase_crop(pos: Vector2i, crop_key: String, progress: float, harvestable: bool = false) -> void:
	var c_data: Dictionary = _da().get_crop(crop_key) if _da() else {}
	var fp: Vector2i = c_data.get("footprint", Vector2i(1, 1))
	for dx in range(fp.x):
		for dy in range(fp.y):
			var p := Vector2i(pos.x + dx, pos.y + dy)
			var t: FarmTile = _farm_grid.get_tile(p)
			if t and t.state == FarmTile.TileState.EMPTY:
				_farm_grid.plow_tile(p)
	if _ec():
		_ec().cash = 9999999
	if _farm_grid.plant_crop(pos, crop_key):
		var root_tile: FarmTile = _farm_grid.get_tile(pos)
		if root_tile:
			root_tile.soil_moisture = 68.0
			root_tile.health = 1.0
			root_tile.growth_progress = progress
			if harvestable:
				root_tile.state = FarmTile.TileState.HARVESTABLE
				root_tile.growth_progress = 1.0
				root_tile.quality = FarmTile.QualityGrade.A
			if fp.x > 1 or fp.y > 1:
				_farm_grid._sync_multi_tile_children(pos)
			for dx in range(fp.x):
				for dy in range(fp.y):
					_farm_grid.renderer.update_tile(Vector2i(pos.x + dx, pos.y + dy), _farm_grid.tiles)

func _populate_zone_a_homestead() -> void:
	# Zone A (0..7, 0..7): Traditional Bahay Kubo + Bodega + manual Palay patch
	_place_showcase_building(Vector2i(0, 0), "bahay_kubo", 1)
	_place_showcase_building(Vector2i(0, 3), "bodega", 1)
	_place_showcase_building(Vector2i(2, 0), "compost_bin", 1)
	_place_showcase_building(Vector2i(4, 0), "rainwater_tank", 1)

	# A couple of already-sprouting manual plots at (2..4, 5..6) while (2..4, 2..4) is left as raw grass for Farmer_1 to plow & plant live!
	_plant_showcase_crop(Vector2i(2, 5), "palay", 0.45, false)
	_plant_showcase_crop(Vector2i(3, 5), "palay", 0.45, false)
	_plant_showcase_crop(Vector2i(4, 5), "palay", 0.80, false)
	_plant_showcase_crop(Vector2i(5, 5), "yellow_corn", 0.55, false)
	_plant_showcase_crop(Vector2i(5, 6), "yellow_corn", 0.85, false)

func _populate_zone_b_heartland() -> void:
	# Zone B (8..19, 3..17): Water Tower Lv.3, Weather Station Lv.3, Climate Silo, Cold Storage, Solar Dryer, Sprinklers & All 7 Crops
	_place_showcase_building(Vector2i(9, 3), "water_tower", 3)
	_place_showcase_building(Vector2i(11, 3), "weather_station", 3)
	_place_showcase_building(Vector2i(13, 3), "solar_dryer", 2)
	_place_showcase_building(Vector2i(15, 3), "climate_silo", 2)
	_place_showcase_building(Vector2i(18, 3), "cold_storage", 2)
	_place_showcase_building(Vector2i(21, 3), "nipa_quarters", 2)
	_place_showcase_building(Vector2i(23, 3), "agri_shed", 2)

	# Place real Sprinklers across the heartland fields
	var sprinkler_positions: Array[Vector2i] = [
		Vector2i(10, 8), Vector2i(14, 8), Vector2i(18, 8),
		Vector2i(10, 13), Vector2i(14, 13), Vector2i(18, 13)
	]
	for sp in sprinkler_positions:
		_place_showcase_building(sp, "sprinkler", 1)

	# Plant lush rows of Palay, Yellow Corn, Sugarcane, Pineapple, and Arabica Coffee around the sprinklers
	for x in range(8, 21):
		for y in range(6, 16):
			if _bm() and _bm().is_tile_occupied_by_building(Vector2i(x, y)):
				continue
			var crop_key := "palay"
			if y in [6, 7]:
				crop_key = "palay" if (x < 14) else "yellow_corn"
			elif y in [8, 9]:
				crop_key = "sugarcane" if (x < 14) else "pineapple"
			elif y in [10, 11]:
				crop_key = "arabica_coffee" if (x < 14) else "palay"
			elif y in [12, 13]:
				crop_key = "yellow_corn" if (x < 14) else "sugarcane"
			else:
				crop_key = "pineapple" if (x < 14) else "arabica_coffee"

			var is_mature: bool = ((x + y) % 3 != 0)
			var prog: float = 1.0 if is_mature else 0.65
			_plant_showcase_crop(Vector2i(x, y), crop_key, prog, is_mature)

	# Plant 2x2 Cavendish Banana & 2x2 Tall Coconut Palm Groves along the eastern side of the Heartland (22..29, 6..15)
	var banana_roots: Array[Vector2i] = [
		Vector2i(22, 6), Vector2i(24, 6), Vector2i(26, 6),
		Vector2i(22, 8), Vector2i(24, 8), Vector2i(26, 8)
	]
	for br in banana_roots:
		_plant_showcase_crop(br, "banana", 1.0, true)

	var coconut_roots: Array[Vector2i] = [
		Vector2i(22, 11), Vector2i(24, 11), Vector2i(26, 11), Vector2i(28, 11),
		Vector2i(22, 13), Vector2i(24, 13), Vector2i(26, 13), Vector2i(28, 13)
	]
	for cr in coconut_roots:
		_plant_showcase_crop(cr, "coconut", 1.0, true)

func _populate_zone_c_megafarm_and_fiesta() -> void:
	# 1. Drone Fleet Infrastructure (Lv.3 so all 6 autonomous drones can fly & work simultaneously)
	_place_showcase_building(Vector2i(8, 18), "drone_station", 3)
	_place_showcase_building(Vector2i(11, 18), "drone_pad", 3)
	_place_showcase_building(Vector2i(13, 18), "drone_pad", 3)
	_place_showcase_building(Vector2i(15, 18), "drone_pad", 3)

	# 2. Industrial Processing Mills & Regional Trade Depots
	_place_showcase_building(Vector2i(18, 17), "rice_mill", 2)
	_place_showcase_building(Vector2i(21, 17), "sugar_mill", 2)
	_place_showcase_building(Vector2i(24, 17), "coffee_roastery", 2)
	_place_showcase_building(Vector2i(27, 17), "copra_dryer", 2)

	_place_showcase_building(Vector2i(22, 20), "bayanihan_center", 1)
	_place_showcase_building(Vector2i(25, 20), "tacurong_mill", 1)
	_place_showcase_building(Vector2i(25, 24), "koronadal_wholesale", 1)
	_place_showcase_building(Vector2i(29, 21), "gensan_seaport", 1)

	# 3. Automated Drone Crop Sectors (8..19, 20..27) — Mix of harvestable, growing, and plowed tiles for real Drone work
	var drone_sectors: Array[Dictionary] = [
		{"rect": Rect2i(8, 20, 4, 4), "crop": "palay"},
		{"rect": Rect2i(12, 20, 4, 4), "crop": "yellow_corn"},
		{"rect": Rect2i(16, 20, 4, 4), "crop": "pineapple"},
		{"rect": Rect2i(8, 24, 4, 4), "crop": "sugarcane"},
		{"rect": Rect2i(12, 24, 4, 4), "crop": "arabica_coffee"},
		{"rect": Rect2i(16, 24, 4, 4), "crop": "palay"}
	]
	for sec in drone_sectors:
		var r: Rect2i = sec["rect"]
		var c_key: String = sec["crop"]
		for gx in range(r.position.x, r.end.x):
			for gy in range(r.position.y, r.end.y):
				var p := Vector2i(gx, gy)
				if _bm() and _bm().is_tile_occupied_by_building(p):
					continue
				var mode: int = (gx + gy) % 3
				if mode == 0:
					_plant_showcase_crop(p, c_key, 1.0, true)
				elif mode == 1:
					_plant_showcase_crop(p, c_key, 0.55, false)
				else:
					_farm_grid.plow_tile(p)

	# Activate and deploy 6 Real FarmDrones over the 6 sectors!
	if _bm():
		_bm().active_drones = 6
	_farm_grid._sync_drones()
	for i in range(mini(_farm_grid.drones.size(), drone_sectors.size())):
		var drone: Node2D = _farm_grid.drones[i]
		var sec: Dictionary = drone_sectors[i]
		var r: Rect2i = sec["rect"]
		var zone_tiles: Array = []
		for gx in range(r.position.x, r.end.x):
			for gy in range(r.position.y, r.end.y):
				zone_tiles.append(Vector2i(gx, gy))
		drone.deploy(zone_tiles, str(sec["crop"]))

	# 4. Philippine Fiesta & Cultural Plaza Decorations (2..23, 28..31)
	_place_showcase_building(Vector2i(8, 28), "fiesta_entrance", 1)
	_place_showcase_building(Vector2i(10, 28), "fiesta_stage", 1)
	_place_showcase_building(Vector2i(13, 28), "fiesta_drums", 1)
	_place_showcase_building(Vector2i(15, 28), "basketball_court", 1)
	_place_showcase_building(Vector2i(19, 28), "tambayan_kubo", 1)
	_place_showcase_building(Vector2i(21, 28), "karaoke_on_wheels", 1)
	_place_showcase_building(Vector2i(22, 28), "tricycle", 1)
	_place_showcase_building(Vector2i(23, 28), "bbq_stand_multiple", 1)
	_place_showcase_building(Vector2i(20, 30), "buko_stall", 1)
	_place_showcase_building(Vector2i(21, 30), "balut_stall", 1)
	_place_showcase_building(Vector2i(22, 30), "parol_stand", 1)
	_place_showcase_building(Vector2i(23, 30), "table_set", 1)
	_place_showcase_building(Vector2i(18, 30), "bench_blue", 1)
	_place_showcase_building(Vector2i(19, 30), "bench_red", 1)

	# Flower borders framing the plaza & avenue
	var flower_keys: Array[String] = [
		"flower_bougainvillea_pink", "flower_bougainvillea_orange",
		"flower_gumamela_colorful", "flower_santan_box_red", "flower_yellow_bell"
	]
	for idx in range(10):
		var fx: int = 8 + idx
		var f_key: String = flower_keys[idx % flower_keys.size()]
		_place_showcase_building(Vector2i(fx, 31), f_key, 1)

func _spawn_real_farmers() -> void:
	_farmers.clear()
	var farmer_script: Script = load("res://src/farmer/Farmer.gd")
	var spawn_coords: Array[Vector2i] = [
		Vector2i(2, 2),   # Farmer_1: Protagonist farmer in Zone A (Homestead manual labor)
		Vector2i(9, 7),   # Farmer_2: Heartland Palay & Corn worker
		Vector2i(13, 9),  # Farmer_3: Heartland Sugarcane & Pineapple worker
		Vector2i(17, 11), # Farmer_4: Heartland Coffee worker
		Vector2i(21, 7),  # Farmer_5: Banana grove worker
		Vector2i(21, 12), # Farmer_6: Coconut grove worker
		Vector2i(19, 25)  # Farmer_7: Megafarm / Fiesta plaza worker
	]
	for i in range(spawn_coords.size()):
		var f := CharacterBody2D.new()
		f.name = "Farmer_%d" % (i + 1)
		f.set_script(farmer_script)

		var spr := Sprite2D.new()
		spr.name = "FarmerSprite"
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(0, -20)
		spr.scale = Vector2(2, 2)
		f.add_child(spr)

		var lbl := Label.new()
		lbl.name = "FarmerLabel"
		lbl.text = "[Ready]"
		if _pixel_font:
			lbl.add_theme_font_override("font", _pixel_font)
		f.add_child(lbl)

		f.position = FarmerMovementScript.grid_to_pixel_center(spawn_coords[i], _farm_grid)
		_world_root.add_child(f)
		_farmers.append(f)

func _reset_scene2_manual_patch() -> void:
	# Resets (2..4, 2..4) to fresh unplowed grass and queues real manual plow -> plant -> water tasks on Farmer_1
	if _farm_grid == null or _farmers.is_empty():
		return
	var f1: CharacterBody2D = _farmers[0]
	f1.clear_assigned_tasks()
	f1.position = FarmerMovementScript.grid_to_pixel_center(Vector2i(2, 2), _farm_grid)
	f1.is_selected = true
	f1.queue_redraw()

	var patch_tiles: Array[Vector2i] = [
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)
	]
	for pt in patch_tiles:
		var t: FarmTile = _farm_grid.get_tile(pt)
		if t:
			t.reset()
			_farm_grid.renderer.update_tile(pt, _farm_grid.tiles)

	# Queue real Plow -> Plant -> Water tasks on the front row so the viewer watches Farmer_1 do real work slowly
	for pt in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]:
		f1.assign_task({"type": "plow", "position": pt})
	for pt in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]:
		f1.assign_task({"type": "plant", "position": pt, "crop_type": "palay"})
	for pt in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]:
		f1.assign_task({"type": "water", "position": pt, "amount": 30.0})
	for pt in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]:
		f1.assign_task({"type": "plow", "position": pt})
		f1.assign_task({"type": "plant", "position": pt, "crop_type": "yellow_corn"})

	# Assign continuous real field tasks to Farmers 2..7 in the Heartland so they are actively working when the camera pans out
	_assign_heartland_squad_tasks()

func _assign_heartland_squad_tasks() -> void:
	if _farmers.size() < 7 or _farm_grid == null:
		return
	var worker_zones: Array[Rect2i] = [
		Rect2i(8, 6, 4, 4),
		Rect2i(12, 8, 4, 4),
		Rect2i(16, 10, 4, 4),
		Rect2i(22, 6, 4, 4),
		Rect2i(22, 11, 4, 4),
		Rect2i(12, 20, 4, 4)
	]
	for idx in range(1, _farmers.size()):
		var worker: CharacterBody2D = _farmers[idx]
		if not worker.assigned_tasks.is_empty():
			continue
		var r: Rect2i = worker_zones[(idx - 1) % worker_zones.size()]
		for gx in range(r.position.x, r.end.x):
			for gy in range(r.position.y, r.end.y):
				var p := Vector2i(gx, gy)
				var tile: FarmTile = _farm_grid.get_tile(p)
				if tile == null:
					continue
				if tile.state == FarmTile.TileState.HARVESTABLE:
					worker.assign_task({"type": "harvest", "position": p})
				elif tile.state == FarmTile.TileState.GROWING:
					worker.assign_task({"type": "water", "position": p, "amount": 25.0})
				elif tile.state == FarmTile.TileState.EMPTY and (_bm() == null or not _bm().is_tile_occupied_by_building(p)):
					worker.assign_task({"type": "plow", "position": p})
					worker.assign_task({"type": "plant", "position": p, "crop_type": "palay"})

# =============================================================================
# PROCESS LOOP & TIMELINE CHOREOGRAPHY
# =============================================================================
func _process(delta: float) -> void:
	if _is_playing:
		var prev_t: float = _elapsed
		_elapsed = minf(TOTAL_DURATION, _elapsed + delta * _playback_speed)
		_sync_timeline(delta * _playback_speed, false)
		if _elapsed >= TOTAL_DURATION and prev_t < TOTAL_DURATION:
			_is_playing = false
			_update_control_buttons()
	else:
		_sync_timeline(0.0, false)

func _jump_to_time(target_time: float) -> void:
	_elapsed = clampf(target_time, 0.0, TOTAL_DURATION)
	if _elapsed >= 19.0 and _elapsed < 44.0:
		_scene2_choreo_step = 0
	_sync_timeline(0.0, true)

func _sync_timeline(dt: float, force_jump: bool) -> void:
	_progress_bar.value = _elapsed
	_time_lbl.text = "%s / %s" % [_format_seconds(_elapsed), _format_seconds(TOTAL_DURATION)]
	_finale_cta_box.visible = (_elapsed >= 98.0)

	# Determine active chapter
	var chap_idx: int = 0
	for i in range(CHAPTERS.size()):
		if _elapsed >= float(CHAPTERS[i]["start"]) and _elapsed <= float(CHAPTERS[i]["end"]):
			chap_idx = i
			break
	if chap_idx != _active_chapter_idx or force_jump:
		_active_chapter_idx = chap_idx
		_on_chapter_entered(chap_idx)

	# Update chapter header & pill highlights
	var ch: Dictionary = CHAPTERS[_active_chapter_idx]
	_chapter_badge_lbl.text = str(ch["title"])
	_subtitle_lbl.text = "— " + str(ch["subtitle"])
	for i in range(_chapter_pill_btns.size()):
		var btn: Button = _chapter_pill_btns[i]
		btn.modulate = Color(1.0, 0.92, 0.55) if i == _active_chapter_idx else Color(0.75, 0.80, 0.76)

	# Keep TimeManager speed synchronized with trailer playback speed so real farmers & drones animate at matching speed
	if _ti():
		_ti().set_speed_scale(_playback_speed if _is_playing else 0.0)

	# Update camera, live gameplay choreography, captions, and clean cuts
	_update_camera_and_gameplay(dt)
	_update_captions()
	_update_cut_fade()

	# Redraw custom canvas if in Chapter I (Intro) or Chapter V (Finale)
	_intro_canvas.visible = (_elapsed < 20.0 or _elapsed >= 94.0)
	if _intro_canvas.visible:
		_intro_canvas.queue_redraw()

func _on_chapter_entered(chap_idx: int) -> void:
	if chap_idx == 1:
		# Entering Scene 2 (Humble Beginnings): Reset manual patch so Farmer_1 plows, plants & waters right before our eyes
		if _bm():
			_bm().unlocked_techs.clear()
			_bm().recalculate_bonuses()
		_reset_scene2_manual_patch()
	elif chap_idx == 2 or chap_idx == 3:
		# Entering Scene 3 or 4: Unlock Kuliglig speed boost so squad workers move briskly across the estate
		if _bm():
			if not _bm().unlocked_techs.has("kuliglig"):
				_bm().unlocked_techs.append("kuliglig")
			_bm().recalculate_bonuses()
		if not _farmers.is_empty():
			_farmers[0].is_selected = false
			_farmers[0].queue_redraw()
		_assign_heartland_squad_tasks()

func _update_camera_and_gameplay(dt: float) -> void:
	if _game_camera == null or _farm_grid == null:
		return

	# Periodically replenish tasks for Heartland workers and keep Drone zones stocked with harvestable/plowed crops
	_worker_loop_timer += dt
	if _worker_loop_timer >= 4.0:
		_worker_loop_timer = 0.0
		_assign_heartland_squad_tasks()
		_refresh_drone_showcase_tiles()

	# In Scene 2 (20s..44s), gently accelerate crop growth on (2..4, 2..3) once planted so the viewer sees Palay grow live!
	if _elapsed >= 20.0 and _elapsed < 44.0 and dt > 0.0:
		_scene2_crop_timer += dt
		if _scene2_crop_timer >= 0.45:
			_scene2_crop_timer = 0.0
			for gx in range(2, 5):
				for gy in range(2, 4):
					var p := Vector2i(gx, gy)
					var t: FarmTile = _farm_grid.get_tile(p)
					if t and t.state == FarmTile.TileState.GROWING:
						t.growth_progress = minf(1.0, t.growth_progress + 0.08)
						if t.growth_progress >= 1.0:
							t.state = FarmTile.TileState.HARVESTABLE
						_farm_grid.renderer.update_tile(p, _farm_grid.tiles)

	# Slow, unhurried Factorio-style Camera Choreography across Acts II, III, and IV
	if _elapsed >= 20.0 and _elapsed < 44.0:
		# ACT II (20s -> 44s, 24 full seconds): Close-up on Homestead (3, 2) -> (4, 3), very gentle drift
		var u: float = smoothstep(20.0, 44.0, _elapsed)
		var p_start: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(2, 2), _farm_grid)
		var p_end: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(4, 3), _farm_grid)
		_game_camera.position = p_start.lerp(p_end, u)
		var z: float = lerpf(1.62, 1.42, u)
		_game_camera.zoom = Vector2(z, z)

	elif _elapsed >= 44.0 and _elapsed < 70.0:
		# ACT III (44s -> 70s, 26 full seconds): Slow Factorio pull-back & glide across Irrigated Heartland & 2x2 Groves
		var u: float = smoothstep(44.0, 70.0, _elapsed)
		var p_start: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(5, 4), _farm_grid)
		var p_mid: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(14, 9), _farm_grid)
		var p_end: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(17, 13), _farm_grid)
		if u < 0.5:
			_game_camera.position = p_start.lerp(p_mid, smoothstep(0.0, 0.5, u))
		else:
			_game_camera.position = p_mid.lerp(p_end, smoothstep(0.5, 1.0, u))
		var z: float = lerpf(1.40, 0.92, u)
		_game_camera.zoom = Vector2(z, z)

	elif _elapsed >= 70.0 and _elapsed < 94.0:
		# ACT IV (70s -> 94s, 24 full seconds): Slow glide across Autonomous Drone Sectors, Processing Mills, Port & Fiesta Plaza
		var u: float = smoothstep(70.0, 94.0, _elapsed)
		var p_start: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(14, 19), _farm_grid)
		var p_mid: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(20, 22), _farm_grid)
		var p_end: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(18, 27), _farm_grid)
		if u < 0.55:
			_game_camera.position = p_start.lerp(p_mid, smoothstep(0.0, 0.55, u))
		else:
			_game_camera.position = p_mid.lerp(p_end, smoothstep(0.55, 1.0, u))
		var z: float = lerpf(0.92, 0.78, u)
		_game_camera.zoom = Vector2(z, z)

func _refresh_drone_showcase_tiles() -> void:
	# Ensures the drone zones always have a lively mix of harvestable crops and plowed soil for drones to work on
	if _farm_grid == null:
		return
	for gx in range(8, 20):
		for gy in range(20, 28):
			var p := Vector2i(gx, gy)
			var t: FarmTile = _farm_grid.get_tile(p)
			if t and t.state == FarmTile.TileState.GROWING and t.growth_progress < 0.85:
				t.growth_progress = minf(1.0, t.growth_progress + 0.35)
				if t.growth_progress >= 1.0:
					t.state = FarmTile.TileState.HARVESTABLE
				_farm_grid.renderer.update_tile(p, _farm_grid.tiles)

func _update_cut_fade() -> void:
	# Clean fade-through-black transitions between major camera cuts:
	# - Cut 1: 19.2s -> 20.8s (Regional Locator Map -> Close-up Homestead Gameplay)
	# - Cut 2: 69.3s -> 70.7s (Heartland -> Drone Fleet & Fiesta Plaza)
	# - Cut 3: 93.3s -> 94.7s (Gameplay -> 5 Regions & Grand Finale)
	var alpha: float = 0.0
	var cut_times: Array[float] = [20.0, 70.0, 94.0]
	for ct in cut_times:
		var dist: float = absf(_elapsed - ct)
		if dist < 0.85:
			alpha = maxf(alpha, 1.0 - (dist / 0.85))
	_cut_fade_rect.color = Color(0.02, 0.03, 0.03, clampf(alpha, 0.0, 1.0))

func _update_captions() -> void:
	if _elapsed < 7.5:
		_caption_main_lbl.text = "SOUTHEAST ASIA — THE PHILIPPINE ARCHIPELAGO"
		_caption_sub_lbl.text = "Scanning tropical agricultural basins from low-Earth orbit..."
	elif _elapsed < 14.0:
		_caption_main_lbl.text = "LOCKING TARGET: MINDANAO — REGION XII (SOCCSKSARGEN)"
		_caption_sub_lbl.text = "Five diverse provinces of volcanic highlands, river basins, and coastal ports."
	elif _elapsed < 20.0:
		_caption_main_lbl.text = "COTABATO BASIN — THE HEART OF MINDANAO AGRICULTURE"
		_caption_sub_lbl.text = "Touchdown on your starting 16×16 homestead parcel."
	elif _elapsed < 32.0:
		_caption_main_lbl.text = "EVERY EMPIRE BEGINS WITH ONE FARMER AND ONE PLOT"
		_caption_sub_lbl.text = "Direct your worker to till the soil, sow Palay seeds, and hand-water each tile."
	elif _elapsed < 44.0:
		_caption_main_lbl.text = "NURTURE YOUR FIRST HARVEST FROM SEEDLING TO GOLD"
		_caption_sub_lbl.text = "Manage soil moisture, crop health, and Primera quality grading in real time."
	elif _elapsed < 57.0:
		_caption_main_lbl.text = "SCALE UP: IRRIGATION NETWORKS & MULTI-CROP AGRONOMY"
		_caption_sub_lbl.text = "Build Water Towers, Weather Stations, and Sprinklers across 7 signature Philippine crops."
	elif _elapsed < 70.0:
		_caption_main_lbl.text = "HIRE WORKER SQUADS & CULTIVATE 2×2 PERENNIAL GROVES"
		_caption_sub_lbl.text = "Harvest Cavendish Bananas, Tall Coconut Palms, Arabica Coffee, Pineapple & Sugarcane."
	elif _elapsed < 82.0:
		_caption_main_lbl.text = "PRECISION AGRICULTURE: AUTONOMOUS DRONE FLEETS"
		_caption_sub_lbl.text = "Deploy 6 programmable Farm Drones to plow, plant, water, spray, and harvest automatically."
	elif _elapsed < 94.0:
		_caption_main_lbl.text = "INDUSTRIAL PROCESSING, EXPORT PORTS & FIESTA CULTURE"
		_caption_sub_lbl.text = "Operate Rice & Sugar Mills, ship from GenSan Seaport, and celebrate with a full Fiesta Plaza."
	else:
		_caption_main_lbl.text = "AGRI-REGION TYCOON — BUILD MINDANAO'S GREATEST FARM"
		_caption_sub_lbl.text = "Cotabato • South Cotabato • Sarangani • Sultan Kudarat • General Santos City"

# =============================================================================
# CHAPTER I (ORBIT -> PH -> MINDANAO) & CHAPTER V (5 REGIONS FINALE) DRAWING
# =============================================================================
func _draw_intro_and_finale() -> void:
	var vp_size: Vector2 = _intro_canvas.size
	var center: Vector2 = vp_size * 0.5

	if _elapsed < 20.0:
		_draw_chapter_1_intro(vp_size, center)
	elif _elapsed >= 94.0:
		_draw_chapter_5_finale(vp_size, center)

func _draw_chapter_1_intro(vp_size: Vector2, center: Vector2) -> void:
	# Deep space background
	_intro_canvas.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.02, 0.04, 0.07, 1.0))

	# Crisp pixel stars
	for i in range(70):
		var sx: float = fmod(float(i * 197 + 43), vp_size.x)
		var sy: float = fmod(float(i * 131 + 89), vp_size.y)
		var tw: float = 0.45 + 0.45 * sin(_elapsed * 1.8 + float(i))
		_intro_canvas.draw_rect(Rect2(Vector2(sx, sy), Vector2(2, 2)), Color(0.85, 0.92, 1.0, tw))

	# Phase 1A (0.0s -> 9.0s): Slow rotating pixel-art globe zooming in
	if _elapsed < 10.5 and not _globe_frames.is_empty():
		var u_globe: float = clampf(_elapsed / 8.5, 0.0, 1.0)
		var frame_idx: int = clampi(int(u_globe * float(_globe_frames.size() - 1)), 0, _globe_frames.size() - 1)
		var g_tex: ImageTexture = _globe_frames[frame_idx]
		var g_scale: float = lerpf(2.4, 4.2, smoothstep(0.0, 10.0, _elapsed))
		var g_size: Vector2 = Vector2(120.0, 120.0) * g_scale
		var g_alpha: float = 1.0 - smoothstep(8.2, 10.5, _elapsed)
		_intro_canvas.draw_texture_rect(g_tex, Rect2(center - g_size * 0.5, g_size), false, Color(1, 1, 1, g_alpha))

		# Tactical orbital reticle locking onto the Philippines once rotation reaches SE Asia (t > 5.0s)
		if _elapsed > 4.8:
			var lock_a: float = clampf((_elapsed - 4.8) / 1.5, 0.0, 1.0) * g_alpha
			var ph_pos: Vector2 = center + Vector2(22.0, -18.0) * (g_scale / 3.0)
			_draw_tactical_reticle(ph_pos, 34.0, Color(0.98, 0.82, 0.25, lock_a), "PHILIPPINES [12°N 122°E]")

	# Phase 1B (8.2s -> 15.2s): Official Philippine Archipelago Map zooming slowly into Mindanao
	if _elapsed >= 8.2 and _elapsed < 15.8 and _tex_ph_map != null:
		var ph_alpha: float = smoothstep(8.2, 10.2, _elapsed) * (1.0 - smoothstep(13.8, 15.8, _elapsed))
		var u_zoom: float = smoothstep(8.5, 15.0, _elapsed)
		var tex_s: Vector2 = _tex_ph_map.get_size()
		var scale_f: float = lerpf(0.85, 1.95, u_zoom) * (vp_size.y / maxf(tex_s.y, 1.0))
		var draw_s: Vector2 = tex_s * scale_f
		# Pan focus gently down toward Mindanao (bottom third of archipelago)
		var pan_offset: Vector2 = Vector2(-draw_s.x * 0.08 * u_zoom, -draw_s.y * 0.24 * u_zoom)
		var rect_pos: Vector2 = center - draw_s * 0.5 + pan_offset
		_intro_canvas.draw_texture_rect(_tex_ph_map, Rect2(rect_pos, draw_s), false, Color(1, 1, 1, ph_alpha))

		var mindanao_pt: Vector2 = rect_pos + Vector2(draw_s.x * 0.62, draw_s.y * 0.78)
		_draw_tactical_reticle(mindanao_pt, 46.0, Color(0.40, 0.96, 0.52, ph_alpha), "MINDANAO — REGION XII")

	# Phase 1C (13.8s -> 20.0s): Official Regional Background + Cotabato Mindanao Locator Map
	if _elapsed >= 13.8:
		var reg_alpha: float = smoothstep(13.8, 15.6, _elapsed)
		var bg_tex: Texture2D = _region_bg_textures.get("cotabato", null)
		if bg_tex != null:
			var u_bg: float = smoothstep(14.0, 20.0, _elapsed)
			var b_scale: float = lerpf(1.02, 1.16, u_bg)
			var b_size: Vector2 = vp_size * b_scale
			_intro_canvas.draw_texture_rect(bg_tex, Rect2(center - b_size * 0.5, b_size), false, Color(0.85, 0.90, 0.86, reg_alpha))

		if _tex_cotabato_loc != null:
			var loc_s: Vector2 = _tex_cotabato_loc.get_size()
			var target_h: float = vp_size.y * 0.54
			var l_scale: float = target_h / maxf(loc_s.y, 1.0)
			var draw_loc: Vector2 = loc_s * l_scale
			var loc_rect := Rect2(center - draw_loc * 0.5 + Vector2(0, -18), draw_loc)
			_intro_canvas.draw_rect(loc_rect.grow(10.0), Color(0.04, 0.08, 0.06, 0.78 * reg_alpha))
			_intro_canvas.draw_rect(loc_rect.grow(10.0), Color(0.86, 0.68, 0.24, 0.90 * reg_alpha), false, 2.0)
			_intro_canvas.draw_texture_rect(_tex_cotabato_loc, loc_rect, false, Color(1, 1, 1, reg_alpha))

func _draw_tactical_reticle(pos: Vector2, radius: float, col: Color, label_txt: String) -> void:
	_intro_canvas.draw_arc(pos, radius, 0.0, TAU, 32, col, 2.0)
	_intro_canvas.draw_line(pos + Vector2(-radius - 10, 0), pos + Vector2(-radius + 6, 0), col, 2.0)
	_intro_canvas.draw_line(pos + Vector2(radius - 6, 0), pos + Vector2(radius + 10, 0), col, 2.0)
	_intro_canvas.draw_line(pos + Vector2(0, -radius - 10), pos + Vector2(0, -radius + 6), col, 2.0)
	_intro_canvas.draw_line(pos + Vector2(0, radius - 6), pos + Vector2(0, radius + 10), col, 2.0)
	if _pixel_font and not label_txt.is_empty():
		_intro_canvas.draw_string(_pixel_font, pos + Vector2(radius + 12, 5), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)

func _draw_chapter_5_finale(vp_size: Vector2, center: Vector2) -> void:
	_intro_canvas.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.04, 0.07, 0.05, 1.0))

	# 5 Regional Pillars across the screen using actual Regional Background Art + Monuments
	var keys: Array[String] = ["cotabato", "south_cotabato", "sarangani", "sultan_kudarat", "general_santos"]
	var titles: Array[String] = ["COTABATO BASIN", "SOUTH COTABATO", "SARANGANI COAST", "SULTAN KUDARAT", "GENERAL SANTOS"]
	var margin_x: float = 36.0
	var gap: float = 12.0
	var card_w: float = (vp_size.x - margin_x * 2.0 - gap * 4.0) / 5.0
	var card_h: float = 250.0
	var card_y: float = 96.0

	for i in range(keys.size()):
		var k: String = keys[i]
		var card_appear: float = smoothstep(94.2 + float(i) * 0.35, 95.4 + float(i) * 0.35, _elapsed)
		if card_appear <= 0.01:
			continue
		var cx: float = margin_x + float(i) * (card_w + gap)
		var crect := Rect2(Vector2(cx, card_y + (1.0 - card_appear) * 24.0), Vector2(card_w, card_h))

		_intro_canvas.draw_rect(crect, Color(0.08, 0.13, 0.10, 0.95 * card_appear))
		var bg_t: Texture2D = _region_bg_textures.get(k, null)
		if bg_t != null:
			_intro_canvas.draw_texture_rect(bg_t, crect.grow(-3.0), false, Color(0.85, 0.85, 0.85, 0.65 * card_appear))

		var mon_t: Texture2D = _region_monument_textures.get(k, null)
		if mon_t != null:
			var ms: Vector2 = mon_t.get_size()
			var sc: float = minf((card_w * 0.72) / maxf(ms.x, 1.0), (card_h * 0.62) / maxf(ms.y, 1.0))
			var draw_ms: Vector2 = ms * sc
			var m_pos: Vector2 = crect.position + Vector2((card_w - draw_ms.x) * 0.5, card_h - draw_ms.y - 36.0)
			_intro_canvas.draw_texture_rect(mon_t, Rect2(m_pos, draw_ms), false, Color(1, 1, 1, card_appear))

		_intro_canvas.draw_rect(Rect2(crect.position.x, crect.end.y - 30.0, card_w, 30.0), Color(0.03, 0.05, 0.04, 0.92 * card_appear))
		_intro_canvas.draw_rect(crect, Color(0.86, 0.68, 0.24, 0.88 * card_appear), false, 2.0)
		if _pixel_font:
			_intro_canvas.draw_string(_pixel_font, Vector2(crect.position.x + 8.0, crect.end.y - 10.0), titles[i], HORIZONTAL_ALIGNMENT_LEFT, card_w - 16.0, 13, Color(0.98, 0.92, 0.74, card_appear))

	# Grand Title Card Banner in center-lower screen
	var title_a: float = smoothstep(96.0, 97.8, _elapsed)
	if title_a > 0.01 and _pixel_font:
		var banner_rect := Rect2(Vector2(center.x - 360.0, 368.0), Vector2(720.0, 118.0))
		_intro_canvas.draw_rect(banner_rect, Color(0.04, 0.08, 0.06, 0.94 * title_a))
		_intro_canvas.draw_rect(banner_rect, Color(0.95, 0.76, 0.26, 0.95 * title_a), false, 3.0)
		_intro_canvas.draw_string(_pixel_font, Vector2(banner_rect.position.x, banner_rect.position.y + 48.0), "AGRI-REGION TYCOON", HORIZONTAL_ALIGNMENT_CENTER, banner_rect.size.x, 36, Color(0.99, 0.88, 0.42, title_a))
		_intro_canvas.draw_string(_pixel_font, Vector2(banner_rect.position.x, banner_rect.position.y + 80.0), "SOW THE SEED  •  AUTOMATE THE HARVEST  •  MASTER THE MARKET", HORIZONTAL_ALIGNMENT_CENTER, banner_rect.size.x, 15, Color(0.84, 0.92, 0.84, title_a))
		_intro_canvas.draw_string(_pixel_font, Vector2(banner_rect.position.x, banner_rect.position.y + 104.0), "30/60/90-Day Timed Campaign  |  Endless Career Tycoon  |  Creative Sandbox", HORIZONTAL_ALIGNMENT_CENTER, banner_rect.size.x, 13, Color(0.68, 0.80, 0.70, title_a))

# =============================================================================
# CONTROLS & CLEANUP
# =============================================================================
func _toggle_play_pause() -> void:
	if _au():
		_au().play_ui("click")
	if _elapsed >= TOTAL_DURATION:
		_jump_to_time(0.0)
		_is_playing = true
	else:
		_is_playing = not _is_playing
	_update_control_buttons()

func _cycle_speed() -> void:
	if _au():
		_au().play_ui("click")
	if is_equal_approx(_playback_speed, 1.0):
		_playback_speed = 1.5
	elif is_equal_approx(_playback_speed, 1.5):
		_playback_speed = 2.0
	else:
		_playback_speed = 1.0
	_update_control_buttons()

func _update_control_buttons() -> void:
	if _play_pause_btn:
		_play_pause_btn.text = "⏸ PAUSE" if _is_playing else "▶ PLAY"
	if _speed_btn:
		_speed_btn.text = "%.1f× SPEED" % _playback_speed

func _format_seconds(sec: float) -> String:
	var total_s: int = maxi(0, int(floor(sec)))
	var m: int = total_s / 60
	var s: int = total_s % 60
	return "%02d:%02d" % [m, s]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_trailer()
		elif event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_toggle_play_pause()
		elif event.keycode == KEY_RIGHT:
			get_viewport().set_input_as_handled()
			_jump_to_time(_elapsed + 10.0)
		elif event.keycode == KEY_LEFT:
			get_viewport().set_input_as_handled()
			_jump_to_time(_elapsed - 10.0)

func _close_trailer() -> void:
	if _au():
		_au().play_ui("click")
	_restore_autoload_state()
	closed.emit()
	queue_free()

func _exit_tree() -> void:
	_restore_autoload_state()
