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
var _saved_soundtrack: String = "countryside_morning"

# Trailer Dedicated Audio Players & Procedural SFX
var _trailer_bgm_player: AudioStreamPlayer = null
var _trailer_sfx_players: Array[AudioStreamPlayer] = []
var _trailer_sfx_idx: int = 0
var _trailer_streams: Dictionary = {}
var _triggered_cues: Dictionary = {}
var _last_caption_text: String = ""

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
var _top_bar: PanelContainer = null
var _caption_panel: PanelContainer = null
var _bot_bar: PanelContainer = null
var _clean_recording_mode: bool = false
var _saved_window_mode: int = -1
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
const GLOBE_VP_W: int = 160
const GLOBE_VP_H: int = 90
const PH_BM_W: int = 180
const PH_BM_H: int = 240

var _globe_img: Image = null
var _globe_tex: ImageTexture = null
var _last_globe_step: int = -9999
var _ph_bitmap: PackedByteArray = PackedByteArray()
var _cloud_tex: ImageTexture = null
var _cloud_puffs: Array[Dictionary] = []
var _tex_game_logo: Texture2D = null
var _corner_logo_watermark: TextureRect = null
var _tex_ph_map: Texture2D = null
var _tex_cotabato_loc: Texture2D = null
var _region_bg_textures: Dictionary = {}
var _region_monument_textures: Dictionary = {}

# Real gameplay choreography flags
var _scene2_choreo_step: int = 0
var _scene2_tasks_started: bool = false
var _scene2_crop_timer: float = 0.0
var _worker_loop_timer: float = 0.0

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/font/quill_and_antler/quill-and-antler.ttf"):
		_pixel_font = load("res://assets/font/quill_and_antler/quill-and-antler.ttf")

	_save_autoload_state()
	if _au():
		_au().trailer_mode_active = true
	_load_trailer_textures()
	_init_continuous_pixel_globe()
	_generate_pixel_clouds()
	_init_trailer_audio()
	_build_ui()
	_setup_real_gameplay_world()
	_sync_timeline(0.0, true)

	if _au():
		_au().play_ui("click")
	_start_trailer_bgm()

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
		if _au().has_method("get_current_soundtrack"):
			_saved_soundtrack = _au().get_current_soundtrack()

func _restore_autoload_state() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _saved_window_mode != -1:
			DisplayServer.window_set_mode(_saved_window_mode as DisplayServer.WindowMode)
			_saved_window_mode = -1

	if _trailer_bgm_player:
		_trailer_bgm_player.stop()
		_trailer_bgm_player.stream = null
	for p in _trailer_sfx_players:
		if p:
			p.stop()
			p.stream = null
	_trailer_streams.clear()

	if _au():
		_au().trailer_mode_active = false
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
		if not _saved_muted and not _saved_soundtrack.is_empty() and _au().has_method("play_soundtrack"):
			_au().play_soundtrack(_saved_soundtrack, 0.8)

func _load_trailer_textures() -> void:
	var logo_path := "res://assets/sprites/StartMenu/game_logo.png"
	if ResourceLoader.exists(logo_path):
		_tex_game_logo = load(logo_path)
	if _tex_game_logo == null:
		var l_img := Image.new()
		if l_img.load(ProjectSettings.globalize_path(logo_path)) == OK:
			_tex_game_logo = ImageTexture.create_from_image(l_img)

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

func _init_continuous_pixel_globe() -> void:
	_globe_img = Image.create(GLOBE_VP_W, GLOBE_VP_H, false, Image.FORMAT_RGBA8)
	_globe_tex = ImageTexture.create_from_image(_globe_img)
	_last_globe_step = -9999

	# Bake a 180x240 pixel-art geographic lookup bitmap for the Philippines (4.6°N..19.0°N, 116.8°E..126.8°E)
	# Directly samples ph_transparent.png so the pixel-art globe has 100% authentic island shapes at every zoom level!
	_ph_bitmap.resize(PH_BM_W * PH_BM_H)
	_ph_bitmap.fill(0)

	var src_img: Image = _tex_ph_map.get_image() if _tex_ph_map != null else null
	if src_img != null and src_img.is_compressed():
		src_img.decompress()

	var min_x: int = 0
	var min_y: int = 0
	var max_x: int = 1
	var max_y: int = 1
	var has_valid_src: bool = false

	if src_img != null and src_img.get_width() > 16 and src_img.get_height() > 16:
		var sw: int = src_img.get_width()
		var sh: int = src_img.get_height()
		min_x = sw
		min_y = sh
		max_x = 0
		max_y = 0
		for sy in range(0, sh, 2):
			for sx in range(0, sw, 2):
				if src_img.get_pixel(sx, sy).a > 0.25:
					if sx < min_x: min_x = sx
					if sx > max_x: max_x = sx
					if sy < min_y: min_y = sy
					if sy > max_y: max_y = sy
		if max_x > min_x + 10 and max_y > min_y + 10:
			has_valid_src = true

	# Pass 1: Raw land mask (code 3 = lowland land)
	for by in range(PH_BM_H):
		var v: float = float(by) / float(PH_BM_H - 1)
		var lat: float = lerpf(19.0, 4.6, v)
		for bx in range(PH_BM_W):
			var u: float = float(bx) / float(PH_BM_W - 1)
			var lon: float = lerpf(116.8, 126.8, u)
			var is_land: bool = false
			if has_valid_src:
				var sx: int = clampi(int(lerpf(float(min_x), float(max_x), u)), 0, src_img.get_width() - 1)
				var sy: int = clampi(int(lerpf(float(min_y), float(max_y), v)), 0, src_img.get_height() - 1)
				is_land = src_img.get_pixel(sx, sy).a > 0.30
			else:
				is_land = _is_philippines_pixel(lat, lon)
			if is_land:
				_ph_bitmap[by * PH_BM_W + bx] = 3

	# Pass 2: Coastlines (code 2), Shallow Coral Reefs (code 1), Highland Interiors (code 4),
	# Region XII / Cotabato Basin (code 5 & golden border code 6), and Pulangi River / Lakes (code 7)
	var refined := _ph_bitmap.duplicate()
	for by in range(1, PH_BM_H - 1):
		var v: float = float(by) / float(PH_BM_H - 1)
		var lat: float = lerpf(19.0, 4.6, v)
		for bx in range(1, PH_BM_W - 1):
			var u: float = float(bx) / float(PH_BM_W - 1)
			var lon: float = lerpf(116.8, 126.8, u)
			var idx: int = by * PH_BM_W + bx
			var cur: int = _ph_bitmap[idx]

			if cur == 0:
				# Ocean pixel: check if within 2 cells of land for shallow coastal turquoise reef (code 1)
				var near_land: bool = false
				for dy in range(-2, 3):
					var ny: int = clampi(by + dy, 0, PH_BM_H - 1)
					for dx in range(-2, 3):
						var nx: int = clampi(bx + dx, 0, PH_BM_W - 1)
						if _ph_bitmap[ny * PH_BM_W + nx] >= 3:
							near_land = true
							break
					if near_land:
						break
				if near_land:
					refined[idx] = 1
			else:
				# Land pixel: check if adjacent to ocean for crisp pixel coastline (code 2)
				var adj_water: bool = (
					_ph_bitmap[(by - 1) * PH_BM_W + bx] == 0 or
					_ph_bitmap[(by + 1) * PH_BM_W + bx] == 0 or
					_ph_bitmap[by * PH_BM_W + (bx - 1)] == 0 or
					_ph_bitmap[by * PH_BM_W + (bx + 1)] == 0
				)
				if adj_water:
					refined[idx] = 2
				else:
					# Check if inside Mindanao's Pulangi / Rio Grande River or Lake Buluan / Lake Sebu (code 7)
					var is_river: bool = false
					if lon >= 124.08 and lon <= 125.12 and absf((lat - 7.12) - (lon - 124.15) * 0.42 - sin(lon * 14.0) * 0.04) < 0.065:
						is_river = true
					elif Vector2(lon - 124.82, lat - 6.66).length() < 0.095 or Vector2(lon - 124.70, lat - 6.23).length() < 0.085:
						is_river = true

					if is_river:
						refined[idx] = 7
					else:
						# Check if inside Region XII / Cotabato Basin highlight on Mindanao (lat 6.05..7.65N, lon 124.02..125.22E)
						var in_reg12: bool = (lat >= 6.05 and lat <= 7.65 and lon >= 124.02 and lon <= 125.22)
						if in_reg12:
							var on_reg_edge: bool = (
								absf(lat - 6.05) < 0.09 or absf(lat - 7.65) < 0.09 or
								absf(lon - 124.02) < 0.09 or absf(lon - 125.22) < 0.09
							)
							refined[idx] = 6 if on_reg_edge else 5
						else:
							# Interior mountain ridge vs emerald lowland
							var elev_noise: float = sin(lat * 3.8) * cos(lon * 4.1)
							refined[idx] = 4 if elev_noise > 0.18 else 3
	_ph_bitmap = refined

func _render_continuous_pixel_globe(t: float) -> void:
	# Quantize to 24 FPS pixel-art steps so it runs ultra-fast while looking silky smooth
	var step_idx: int = int(floor(t * 24.0))
	if step_idx == _last_globe_step and _globe_tex != null:
		return
	_last_globe_step = step_idx

	# 1. Continuous 3D Spherical Camera Trajectory (0.0s -> 18.0s):
	#    - 0.0s..6.2s: Globe spins in space from -58° lon to 122.0°E, 12.2°N (Philippines), radius 35 -> 48
	#    - 6.2s..12.2s: Globe zooms continuously into the Philippine Archipelago (radius 48 -> 240) while panning down to Mindanao (7.5°N, 124.3°E)
	#    - 12.2s..18.0s: Globe zooms continuously into Mindanao & the Cotabato Basin (7.18°N, 124.38°E, radius 240 -> 1150)
	var u_spin: float = smoothstep(0.0, 6.4, t)
	var u_pan_mindanao: float = smoothstep(7.2, 13.0, t)
	var u_pan_cotabato: float = smoothstep(12.2, 16.8, t)

	var center_lon: float = lerpf(-58.0, 122.0, u_spin)
	center_lon = lerpf(center_lon, 124.30, u_pan_mindanao)
	center_lon = lerpf(center_lon, 124.38, u_pan_cotabato)

	var center_lat: float = lerpf(4.0, 12.2, smoothstep(1.2, 6.4, t))
	center_lat = lerpf(center_lat, 7.55, u_pan_mindanao)
	center_lat = lerpf(center_lat, 7.15, u_pan_cotabato)

	var radius: float = 35.0
	if t < 5.2:
		radius = lerpf(35.0, 46.0, smoothstep(0.0, 5.2, t))
	else:
		# Unbroken exponential zoom on the pixel-art sphere from 46px (full globe) -> 1,150px (Cotabato Valley closeup)
		var u_z: float = clampf((t - 5.2) / 12.8, 0.0, 1.0)
		radius = 46.0 * pow(25.0, pow(u_z, 1.48))

	var half_w: float = float(GLOBE_VP_W) * 0.5
	var half_h: float = float(GLOBE_VP_H) * 0.5
	var inv_r: float = 1.0 / radius
	var clat_rad: float = deg_to_rad(center_lat)
	var sin_clat: float = sin(clat_rad)
	var cos_clat: float = cos(clat_rad)

	_globe_img.fill(Color(0, 0, 0, 0))

	for py in range(GLOBE_VP_H):
		var dy: float = (float(py) - half_h) * inv_r
		var dy2: float = dy * dy
		if dy2 > 1.08:
			continue
		for px in range(GLOBE_VP_W):
			var dx: float = (float(px) - half_w) * inv_r
			var d2: float = dx * dx + dy2
			if d2 > 1.06:
				continue
			if d2 > 1.0:
				# Crisp pixel-art atmosphere rim around the globe when visible in space
				_globe_img.set_pixel(px, py, Color(0.30, 0.72, 0.98, 0.55))
				continue

			var dz: float = sqrt(maxf(0.0, 1.0 - d2))
			# True 3D spherical rotation around center_lat and center_lon
			var ny: float = -dy
			var sin_lat: float = clampf(ny * cos_clat + dz * sin_clat, -1.0, 1.0)
			var lat: float = rad_to_deg(asin(sin_lat))
			var cos_lon_z: float = dz * cos_clat - ny * sin_clat
			var lon: float = center_lon + rad_to_deg(atan2(dx, cos_lon_z))
			while lon > 180.0:
				lon -= 360.0
			while lon < -180.0:
				lon += 360.0

			# Quantized 4-band pixel-art spherical sunlight
			var light: float = clampf(dz * 0.86 + (-dx * 0.22) + (-dy * 0.18), 0.26, 1.0)
			light = floor(light * 4.0) / 4.0
			var dark_f: float = (1.0 - light) * 0.68

			var col: Color
			# Check if inside the high-detail Philippines spherical bounding box (4.6..19.0N, 116.8..126.8E)
			if lat >= 4.6 and lat <= 19.0 and lon >= 116.8 and lon <= 126.8:
				var bx: int = clampi(int(((lon - 116.8) / 10.0) * float(PH_BM_W - 1)), 0, PH_BM_W - 1)
				var by: int = clampi(int(((19.0 - lat) / 14.4) * float(PH_BM_H - 1)), 0, PH_BM_H - 1)
				var code: int = _ph_bitmap[by * PH_BM_W + bx]
				match code:
					1: # Shallow coastal coral reef water
						col = Color(0.14, 0.46, 0.74, 1.0).darkened(dark_f * 0.7)
					2: # Crisp dark pixel coastline edge
						col = Color(0.16, 0.44, 0.22, 1.0).darkened(dark_f * 0.6)
					3: # Lush emerald Philippine lowland
						col = Color(0.38, 0.86, 0.34, 1.0).darkened(dark_f * 0.65)
					4: # Deep tropical highland forest spine
						col = Color(0.24, 0.66, 0.28, 1.0).darkened(dark_f * 0.65)
					5: # Region XII / Cotabato Basin fertile valley highlight
						col = Color(0.52, 0.94, 0.38, 1.0).darkened(dark_f * 0.5)
					6: # Golden pixel border around Region XII / Cotabato
						col = Color(0.98, 0.84, 0.28, 1.0)
					7: # Pulangi / Rio Grande de Mindanao River & Lakes
						col = Color(0.22, 0.74, 0.92, 1.0)
					_: # Deep Philippine Sea / South China Sea
						col = Color(0.08, 0.28, 0.56, 1.0).darkened(dark_f * 0.75)
			else:
				if _is_world_land_pixel(lat, lon):
					col = Color(0.24, 0.60, 0.30, 1.0).darkened(dark_f)
				else:
					col = Color(0.08, 0.28, 0.56, 1.0).darkened(dark_f * 0.75)

			# Subtle pixel-art latitude/longitude grid lines (adaptive spacing as we zoom in)
			var grid_step: float = 30.0 if radius < 110.0 else (10.0 if radius < 320.0 else 2.0)
			var grid_thick: float = 42.0 / radius
			if absf(fmod(absf(lat), grid_step)) < grid_thick or absf(fmod(absf(lon), grid_step)) < grid_thick:
				col = col.lightened(0.07)

			_globe_img.set_pixel(px, py, col)

	_globe_tex.update(_globe_img)

func _is_philippines_pixel(lat: float, lon: float) -> bool:
	# Recognizable pixel silhouette of Luzon, Visayas, Palawan, and Mindanao for smooth zoom-in
	if lat < 5.2 or lat > 18.8 or lon < 117.2 or lon > 126.6:
		return false
	# Luzon (13.0..18.5N, 119.8..124.2E)
	if lat >= 13.0 and lat <= 18.5 and lon >= 119.8 and lon <= 122.6:
		return true
	if lat >= 12.8 and lat <= 14.5 and lon >= 122.2 and lon <= 124.3:
		return true
	# Visayas cluster (9.5..12.6N, 121.8..125.5E)
	if lat >= 9.5 and lat <= 12.5 and lon >= 121.8 and lon <= 125.4:
		return sin(lat * 2.2) + cos(lon * 2.4) > -0.25
	# Palawan diagonal (8.5..11.5N, 117.5..119.8E)
	if lat >= 8.5 and lat <= 11.5 and absf((lon - 117.5) - (lat - 8.5) * 0.75) < 0.65:
		return true
	# Mindanao (5.5..9.8N, 121.8..126.4E)
	if lat >= 5.6 and lat <= 9.6 and lon >= 123.5 and lon <= 126.3:
		return true
	if lat >= 6.8 and lat <= 8.6 and lon >= 121.8 and lon <= 123.8:
		return true
	return false

func _generate_pixel_clouds() -> void:
	# Generates a crisp nearest-neighbor pixel-art cumulus cloud sprite & radial cloud canopy puffs
	var w: int = 96
	var h: int = 56
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var blobs: Array[Vector3] = [
		Vector3(48, 28, 22),
		Vector3(28, 32, 17),
		Vector3(68, 32, 17),
		Vector3(16, 37, 12),
		Vector3(80, 37, 12),
		Vector3(38, 20, 15),
		Vector3(58, 21, 14)
	]
	for py in range(h):
		for px in range(w):
			var max_v: float = 0.0
			for b in blobs:
				var dx: float = (float(px) - b.x) / b.z
				var dy: float = (float(py) - b.y) / (b.z * 0.82)
				var d2: float = dx * dx + dy * dy
				if d2 < 1.0:
					max_v = maxf(max_v, 1.0 - d2)
			if max_v <= 0.0:
				continue
			# Pixel-art 3-tone cumulus shading (bright sunlit top, warm cream mid, cool misty blue-grey base)
			var col: Color
			if py < 22 and max_v > 0.35:
				col = Color(0.99, 0.99, 1.00, 0.96)
			elif py < 34:
				col = Color(0.93, 0.96, 0.99, 0.94)
			elif py < 42:
				col = Color(0.82, 0.88, 0.95, 0.90)
			else:
				col = Color(0.70, 0.78, 0.88, 0.84)
			img.set_pixel(px, py, col)
	_cloud_tex = ImageTexture.create_from_image(img)

	_cloud_puffs.clear()
	# 24 cloud puffs arranged in 3 concentric altitude rings so they envelop the screen and part outward cleanly
	for i in range(24):
		var ring: int = i / 8 # 0 = inner core, 1 = mid canopy, 2 = outer rim
		var angle: float = (float(i % 8) / 8.0) * TAU + float(ring) * 0.42
		var base_dist: float = 45.0 if ring == 0 else (165.0 if ring == 1 else 310.0)
		var dir := Vector2(cos(angle), sin(angle) * 0.68)
		_cloud_puffs.append({
			"dir": dir,
			"base_dist": base_dist,
			"part_speed": 460.0 + float(ring) * 210.0 + float((i * 37) % 90),
			"base_scale": 3.4 if ring == 0 else (2.9 if ring == 1 else 2.5),
			"delay": float(ring) * 0.22 + float(i % 4) * 0.08
		})

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
# TRAILER CINEMATIC AUDIO ENGINE (Custom Trailer BGM + Camera/Cloud/Text SFX)
# =============================================================================
func _init_trailer_audio() -> void:
	# Stop peaceful menu music so the driving Factorio-style trailer score takes over
	if _au() and _au().has_method("stop_soundtrack"):
		_au().stop_soundtrack(0.25)

	_trailer_bgm_player = AudioStreamPlayer.new()
	_trailer_bgm_player.name = "TrailerBGMPlayer"
	_trailer_bgm_player.bus = "Master"
	_trailer_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_trailer_bgm_player)

	for i in range(6):
		var sp := AudioStreamPlayer.new()
		sp.name = "TrailerSFX_%d" % i
		sp.bus = "Master"
		sp.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(sp)
		_trailer_sfx_players.append(sp)

	_trailer_streams["bgm"] = _build_trailer_bgm_stream()
	_trailer_streams["camera_zoom"] = _build_sfx_camera_zoom()
	_trailer_streams["reticle_lock"] = _build_sfx_reticle_lock()
	_trailer_streams["cloud_whoosh"] = _build_sfx_cloud_whoosh()
	_trailer_streams["text_appear"] = _build_sfx_text_appear()
	_trailer_streams["card_appear"] = _build_sfx_card_appear()
	_trailer_streams["title_impact"] = _build_sfx_title_impact()

func _start_trailer_bgm() -> void:
	if _trailer_bgm_player == null or not _trailer_streams.has("bgm"):
		return
	if _au() and (_au().is_muted or _au().is_music_muted):
		return
	_trailer_bgm_player.stream = _trailer_streams["bgm"]
	var vol_lin: float = 0.55
	if _au():
		vol_lin = clampf(_au().music_volume * _au().master_volume, 0.05, 1.0)
	_trailer_bgm_player.volume_db = clampf(linear_to_db(vol_lin) - 7.5, -40.0, -5.0)
	_trailer_bgm_player.play()

func _play_trailer_sfx(cue_name: String, pitch: float = 1.0, vol_offset_db: float = 0.0) -> void:
	if _au() and _au().is_muted:
		return
	if not _trailer_streams.has(cue_name) or _trailer_sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = _trailer_sfx_players[_trailer_sfx_idx % _trailer_sfx_players.size()]
	_trailer_sfx_idx += 1
	p.stop()
	p.stream = _trailer_streams[cue_name]
	p.pitch_scale = pitch
	var sfx_lin: float = 0.85
	if _au():
		sfx_lin = clampf(_au().sfx_volume * _au().master_volume, 0.05, 1.0)
	p.volume_db = clampf(linear_to_db(sfx_lin) + vol_offset_db, -45.0, 2.0)
	p.play()

func _make_wav_from_pcm(pcm: PackedByteArray, mix_rate: int = 22050, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = pcm
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = pcm.size() / 2
	return wav

func _build_trailer_bgm_stream() -> AudioStreamWAV:
	# 16-second seamless loop (32 beats @ 120 BPM) — Upbeat Factorio/Tycoon Industrial-Synth Chiptune Anthem in D Dorian / D Minor
	var rate: int = 22050
	var dur: float = 16.0
	var total_samples: int = int(dur * float(rate))
	var pcm := PackedByteArray()
	pcm.resize(total_samples * 2)

	var bass_freqs: Array[float] = [
		73.42, 73.42, 87.31, 98.00,   # D2, D2, F2, G2
		110.00, 110.00, 98.00, 87.31, # A2, A2, G2, F2
		58.27, 58.27, 65.41, 73.42,   # Bb1, Bb1, C2, D2
		87.31, 98.00, 110.00, 73.42   # F2, G2, A2, D2
	]
	var arp_notes: Array[float] = [
		293.66, 349.23, 440.00, 587.33, # D4, F4, A4, D5
		293.66, 440.00, 523.25, 659.25, # D4, A4, C5, E5
		349.23, 440.00, 587.33, 698.46, # F4, A4, D5, F5
		392.00, 493.88, 587.33, 659.25  # G4, B4, D5, E5
	]
	var lead_melody: Array[float] = [
		587.33, 0.0, 659.25, 698.46, 880.00, 0.0, 698.46, 659.25,
		587.33, 523.25, 440.00, 0.0, 523.25, 587.33, 659.25, 0.0,
		698.46, 0.0, 880.00, 783.99, 698.46, 659.25, 587.33, 0.0,
		523.25, 587.33, 659.25, 523.25, 440.00, 0.0, 293.66, 0.0
	]

	var bass_phase: float = 0.0
	var arp_phase: float = 0.0
	var lead_phase: float = 0.0
	var pad_phase1: float = 0.0
	var pad_phase2: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(rate)
		var beat_f: float = t * 2.0 # 120 BPM = 2 beats/sec
		var beat_idx: int = int(beat_f)
		var beat_frac: float = fmod(beat_f, 1.0)
		var step16_f: float = t * 8.0 # 16th notes (8 per sec)
		var step16_idx: int = int(step16_f)
		var step16_frac: float = fmod(step16_f, 1.0)

		# 1. Driving Kick + Snare + Hi-Hat percussion
		var drum: float = 0.0
		if beat_idx % 2 == 0:
			if beat_frac < 0.18:
				var k_env: float = exp(-beat_frac * 26.0)
				var k_freq: float = lerpf(135.0, 42.0, minf(1.0, beat_frac * 9.0))
				drum += sin(beat_frac * k_freq * TAU) * k_env * 0.42
		else:
			if beat_frac < 0.22:
				var s_env: float = exp(-beat_frac * 22.0)
				var noise: float = sin(float(i) * 1.73) * cos(float(i) * 3.19)
				drum += (noise * 0.7 + sin(beat_frac * 185.0 * TAU) * 0.3) * s_env * 0.28

		if step16_frac < 0.09:
			var h_env: float = exp(-step16_frac * 45.0)
			var h_noise: float = sin(float(i) * 2.91) * sin(float(i) * 5.13)
			drum += h_noise * h_env * (0.11 if (step16_idx % 2 == 1) else 0.06)

		# 2. Pulsing Industrial Synth Bass (8th-note groove)
		var b_freq: float = bass_freqs[(beat_idx / 2) % bass_freqs.size()]
		if (step16_idx % 2) == 1:
			b_freq *= 2.0 # Octave bass bounce
		bass_phase = fmod(bass_phase + b_freq / float(rate), 1.0)
		var bass_env: float = exp(-fmod(t * 4.0, 1.0) * 3.5)
		var bass_wave: float = (1.0 if bass_phase < 0.5 else -1.0) * 0.5 + sin(bass_phase * TAU) * 0.5
		var bass: float = bass_wave * bass_env * 0.26

		# 3. Factorio-style 16th-note Arpeggiator
		var bar_group: int = (beat_idx / 4) % 4
		var a_freq: float = arp_notes[bar_group * 4 + (step16_idx % 4)]
		arp_phase = fmod(arp_phase + a_freq / float(rate), 1.0)
		var arp_env: float = exp(-step16_frac * 4.8)
		var arp_wave: float = (1.0 if arp_phase < 0.25 else -0.6) # 25% pulse wave
		var arp: float = arp_wave * arp_env * 0.16

		# 4. Heroic Chiptune Lead Melody
		var l_freq: float = lead_melody[beat_idx % lead_melody.size()]
		var lead: float = 0.0
		if l_freq > 10.0:
			var vibrato: float = 1.0 + sin(t * 28.0) * 0.004
			lead_phase = fmod(lead_phase + (l_freq * vibrato) / float(rate), 1.0)
			var l_env: float = minf(1.0, beat_frac * 18.0) * exp(-beat_frac * 2.4)
			var sq: float = 1.0 if lead_phase < 0.5 else -1.0
			lead = (sq * 0.6 + sin(lead_phase * TAU) * 0.4) * l_env * 0.22

		# 5. Warm Fifth Drone Pad (D3 + A3)
		pad_phase1 = fmod(pad_phase1 + 146.83 / float(rate), 1.0)
		pad_phase2 = fmod(pad_phase2 + 220.00 / float(rate), 1.0)
		var pad: float = (sin(pad_phase1 * TAU) + sin(pad_phase2 * TAU)) * 0.08

		var sample: float = clampf((drum + bass + arp + lead + pad) * 0.88, -0.98, 0.98)
		pcm.encode_s16(i * 2, int(sample * 32000.0))

	return _make_wav_from_pcm(pcm, rate, true)

func _build_sfx_camera_zoom() -> AudioStreamWAV:
	# Smooth futuristic camera lens servo / orbital zoom sweep (0.65s)
	var rate: int = 22050
	var total: int = int(0.65 * float(rate))
	var pcm := PackedByteArray()
	pcm.resize(total * 2)
	var phase: float = 0.0
	for i in range(total):
		var u: float = float(i) / float(total)
		var env: float = sin(u * PI) * exp(-u * 1.4)
		var freq: float = lerpf(160.0, 520.0, pow(u, 1.3))
		phase = fmod(phase + freq / float(rate), 1.0)
		var air: float = sin(float(i) * 1.37) * cos(float(i) * 2.83) * 0.22
		var tone: float = sin(phase * TAU) * 0.65 + sin(phase * TAU * 2.0) * 0.25
		var s: float = clampf((tone + air) * env * 0.42, -0.95, 0.95)
		pcm.encode_s16(i * 2, int(s * 32000.0))
	return _make_wav_from_pcm(pcm, rate, false)

func _build_sfx_reticle_lock() -> AudioStreamWAV:
	# Crisp orbital satellite telemetry double-beep on target lock (0.28s)
	var rate: int = 22050
	var total: int = int(0.28 * float(rate))
	var pcm := PackedByteArray()
	pcm.resize(total * 2)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var freq: float = 1174.66 if t < 0.11 else 1567.98 # D6 -> G6
		var local_t: float = t if t < 0.11 else (t - 0.11)
		var env: float = exp(-local_t * 24.0)
		phase = fmod(phase + freq / float(rate), 1.0)
		var s: float = (sin(phase * TAU) * 0.75 + (0.25 if phase < 0.5 else -0.25)) * env * 0.36
		pcm.encode_s16(i * 2, int(clampf(s, -0.95, 0.95) * 32000.0))
	return _make_wav_from_pcm(pcm, rate, false)

func _build_sfx_cloud_whoosh() -> AudioStreamWAV:
	# Lush atmospheric wind rush as the camera dives through & parts the cumulus clouds (1.8s)
	var rate: int = 22050
	var total: int = int(1.80 * float(rate))
	var pcm := PackedByteArray()
	pcm.resize(total * 2)
	var lp1: float = 0.0
	var lp2: float = 0.0
	var phase: float = 0.0
	for i in range(total):
		var u: float = float(i) / float(total)
		var env: float = sin(pow(u, 0.75) * PI)
		var raw_noise: float = sin(float(i) * 1.618) * cos(float(i) * 2.718) + sin(float(i) * 4.123) * 0.5
		var cutoff: float = lerpf(0.06, 0.28, sin(u * PI))
		lp1 += cutoff * (raw_noise - lp1)
		lp2 += cutoff * (lp1 - lp2)
		var sub_freq: float = lerpf(210.0, 95.0, u)
		phase = fmod(phase + sub_freq / float(rate), 1.0)
		var s: float = (lp2 * 0.78 + sin(phase * TAU) * 0.22) * env * 0.52
		pcm.encode_s16(i * 2, int(clampf(s, -0.95, 0.95) * 32000.0))
	return _make_wav_from_pcm(pcm, rate, false)

func _build_sfx_text_appear() -> AudioStreamWAV:
	# Subtle warm lower-third caption / text reveal chime (0.18s)
	var rate: int = 22050
	var total: int = int(0.18 * float(rate))
	var pcm := PackedByteArray()
	pcm.resize(total * 2)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var freq: float = lerpf(587.33, 880.00, minf(1.0, t * 14.0)) # D5 -> A5
		var env: float = exp(-t * 22.0)
		phase = fmod(phase + freq / float(rate), 1.0)
		var s: float = sin(phase * TAU) * env * 0.28
		pcm.encode_s16(i * 2, int(clampf(s, -0.95, 0.95) * 32000.0))
	return _make_wav_from_pcm(pcm, rate, false)

func _build_sfx_card_appear() -> AudioStreamWAV:
	# Crisp card slide + chime when each of the 5 Regional Pillars appears in the finale (0.24s)
	var rate: int = 22050
	var total: int = int(0.24 * float(rate))
	var pcm := PackedByteArray()
	pcm.resize(total * 2)
	var phase: float = 0.0
	for i in range(total):
		var u: float = float(i) / float(total)
		var env: float = exp(-u * 6.5)
		var freq: float = lerpf(320.0, 660.0, pow(u, 0.6))
		phase = fmod(phase + freq / float(rate), 1.0)
		var swish: float = sin(float(i) * 2.13) * cos(float(i) * 3.71) * exp(-u * 10.0) * 0.35
		var s: float = (sin(phase * TAU) * 0.65 + swish) * env * 0.38
		pcm.encode_s16(i * 2, int(clampf(s, -0.95, 0.95) * 32000.0))
	return _make_wav_from_pcm(pcm, rate, false)

func _build_sfx_title_impact() -> AudioStreamWAV:
	# Grand cinematic chord & warm sub-impact when AGRI-REGION TYCOON title card appears (1.3s)
	var rate: int = 22050
	var total: int = int(1.30 * float(rate))
	var pcm := PackedByteArray()
	pcm.resize(total * 2)
	var p1: float = 0.0
	var p2: float = 0.0
	var p3: float = 0.0
	var p4: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var env: float = minf(1.0, t * 25.0) * exp(-t * 2.2)
		p1 = fmod(p1 + 146.83 / float(rate), 1.0) # D3
		p2 = fmod(p2 + 220.00 / float(rate), 1.0) # A3
		p3 = fmod(p3 + 293.66 / float(rate), 1.0) # D4
		p4 = fmod(p4 + 370.00 / float(rate), 1.0) # F#4 (Picardy major lift)
		var chord: float = (sin(p1 * TAU) * 0.35 + sin(p2 * TAU) * 0.25 + sin(p3 * TAU) * 0.22 + sin(p4 * TAU) * 0.18)
		var boom: float = sin(t * 75.0 * TAU) * exp(-t * 9.0) * 0.35
		var s: float = (chord * env + boom) * 0.48
		pcm.encode_s16(i * 2, int(clampf(s, -0.95, 0.95) * 32000.0))
	return _make_wav_from_pcm(pcm, rate, false)

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
	_top_bar = top_bar
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
	top_hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_hbox)

	if _tex_game_logo != null:
		var top_logo := TextureRect.new()
		top_logo.texture = _tex_game_logo
		top_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		top_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		top_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top_logo.custom_minimum_size = Vector2(88, 46)
		top_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_hbox.add_child(top_logo)

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

	var clean_rec_btn := _make_button("🎥 RECORD CLEAN (R)", Color(0.14, 0.28, 0.20), Color(0.42, 0.86, 0.56))
	clean_rec_btn.tooltip_text = "Restart from 00:00 in Full-Screen Clean Mode (hides all UI & cursor for recording)"
	clean_rec_btn.pressed.connect(_start_clean_recording_from_beginning)
	top_hbox.add_child(clean_rec_btn)

	var fullscreen_btn := _make_button("👁 FULLSCREEN NO-UI (H)", Color(0.20, 0.24, 0.32), Color(0.55, 0.72, 0.94))
	fullscreen_btn.tooltip_text = "Hide all UI layouts and enter Full-Screen Viewing Mode (press H, F, or ESC to restore)"
	fullscreen_btn.pressed.connect(func():
		if _au():
			_au().play_ui("click")
		_set_clean_recording_mode(true)
	)
	top_hbox.add_child(fullscreen_btn)

	var close_btn := _make_button("✕ SKIP (ESC)", Color(0.42, 0.16, 0.14), Color(0.88, 0.42, 0.36))
	close_btn.pressed.connect(_close_trailer)
	top_hbox.add_child(close_btn)

	# 4b. Official Game Logo Corner Watermark (top-right during Chapters I–IV)
	if _tex_game_logo != null:
		_corner_logo_watermark = TextureRect.new()
		_corner_logo_watermark.name = "CornerLogoWatermark"
		_corner_logo_watermark.texture = _tex_game_logo
		_corner_logo_watermark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_corner_logo_watermark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_corner_logo_watermark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_corner_logo_watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_corner_logo_watermark.anchor_left = 1.0
		_corner_logo_watermark.anchor_right = 1.0
		_corner_logo_watermark.anchor_top = 0.0
		_corner_logo_watermark.anchor_bottom = 0.0
		_corner_logo_watermark.offset_left = -210.0
		_corner_logo_watermark.offset_right = -18.0
		_corner_logo_watermark.offset_top = 76.0
		_corner_logo_watermark.offset_bottom = 185.0
		_corner_logo_watermark.modulate = Color(1.0, 1.0, 1.0, 0.92)
		_root_ctrl.add_child(_corner_logo_watermark)

	# 5. Cinematic Caption Box (Lower-third above bottom letterbox bar)
	var caption_panel := PanelContainer.new()
	_caption_panel = caption_panel
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
	_bot_bar = bot_bar
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

func _reset_scene2_manual_patch(start_tasks_immediately: bool = false) -> void:
	# Resets (2..4, 2..4) to fresh unplowed grass and positions Farmer_1 at (2, 2) ready for the aerial cloud zoom-in
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

	_scene2_tasks_started = false
	if start_tasks_immediately:
		_start_scene2_farmer_tasks()

	# Assign continuous real field tasks to Farmers 2..7 in the Heartland so they are actively working when the camera pans out
	_assign_heartland_squad_tasks()

func _start_scene2_farmer_tasks() -> void:
	if _scene2_tasks_started or _farmers.is_empty():
		return
	_scene2_tasks_started = true
	var f1: CharacterBody2D = _farmers[0]
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
	_rebuild_triggered_cues_up_to(_elapsed)
	if _elapsed < 44.0:
		_scene2_choreo_step = 0
		_reset_scene2_manual_patch(_elapsed >= 21.8)
	_sync_timeline(0.0, true)

func _sync_timeline(dt: float, force_jump: bool) -> void:
	_progress_bar.value = _elapsed
	_time_lbl.text = "%s / %s" % [_format_seconds(_elapsed), _format_seconds(TOTAL_DURATION)]
	_finale_cta_box.visible = (_elapsed >= 98.0) and not _clean_recording_mode

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

	# Update camera, live gameplay choreography, captions, clean cuts, and timed trailer SFX cues
	_update_camera_and_gameplay(dt)
	_update_captions(force_jump)
	_update_cut_fade()
	if not force_jump and _is_playing:
		_update_trailer_sfx_cues()

	# Keep _intro_canvas visible through 23.2s so the parting clouds draw over the live SubViewport as we zoom into the farmer!
	_intro_canvas.visible = (_elapsed < 23.2 or _elapsed >= 94.0)
	if _intro_canvas.visible:
		_intro_canvas.queue_redraw()
	if _corner_logo_watermark:
		_corner_logo_watermark.visible = (_elapsed < 94.0)

func _on_chapter_entered(chap_idx: int) -> void:
	if chap_idx == 0:
		if _bm():
			_bm().unlocked_techs.clear()
			_bm().recalculate_bonuses()
		_reset_scene2_manual_patch(false)
	elif chap_idx == 1:
		# Entering Scene 2 (Humble Beginnings): Ensure standard worker speed; if jumping directly past 21.8s, start tasks immediately
		if _bm():
			_bm().unlocked_techs.clear()
			_bm().recalculate_bonuses()
		if _elapsed >= 21.8 and not _scene2_tasks_started:
			_start_scene2_farmer_tasks()
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

	# Trigger Farmer_1's manual tasks right at 21.8s as the clouds part and the aerial camera zoom settles onto Farmer_1!
	if _elapsed >= 21.8 and _elapsed < 44.0 and not _scene2_tasks_started:
		_start_scene2_farmer_tasks()

	# In Scene 2 (22s..44s), gently accelerate crop growth on (2..4, 2..3) once planted so the viewer sees Palay grow live!
	if _elapsed >= 22.0 and _elapsed < 44.0 and dt > 0.0:
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

	# Slow, unhurried Factorio-style Camera Choreography across the Cloud Dive, Act II, Act III, and Act IV
	if _elapsed < 17.6:
		# Pre-position camera high above the island before the cloud break
		_game_camera.position = FarmerMovementScript.grid_to_pixel_center(Vector2i(10, 9), _farm_grid)
		_game_camera.zoom = Vector2(0.48, 0.48)

	elif _elapsed >= 17.6 and _elapsed < 23.6:
		# CLOUD BREAK & AERIAL ZOOM INTO THE FARMER (17.6s -> 23.6s, 6.0s smooth descent):
		# Zooms down through the parting clouds from high island altitude (0.48x) straight onto Farmer_1 at (2, 2) (1.64x)!
		var u_dive: float = smoothstep(17.6, 23.6, _elapsed)
		var u_eased: float = 1.0 - pow(1.0 - u_dive, 2.4)
		var p_sky: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(10, 9), _farm_grid)
		var p_farmer: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(2, 2), _farm_grid)
		_game_camera.position = p_sky.lerp(p_farmer, u_eased)
		var z: float = lerpf(0.48, 1.64, u_eased)
		_game_camera.zoom = Vector2(z, z)

	elif _elapsed >= 23.6 and _elapsed < 44.0:
		# ACT II (23.6s -> 44s): Close-up on Farmer_1 plowing, planting & watering at Homestead (2, 2) -> (4, 3)
		var u: float = smoothstep(23.6, 44.0, _elapsed)
		var p_start: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(2, 2), _farm_grid)
		var p_end: Vector2 = FarmerMovementScript.grid_to_pixel_center(Vector2i(4, 3), _farm_grid)
		_game_camera.position = p_start.lerp(p_end, u)
		var z: float = lerpf(1.64, 1.42, u)
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
	# Clean fade-through-black transitions only for later act cuts (70s and 94s).
	# The transition around 18s..23s uses the seamless Cloud Break & Aerial Zoom into the farmer!
	var alpha: float = 0.0
	var cut_times: Array[float] = [70.0, 94.0]
	for ct in cut_times:
		var dist: float = absf(_elapsed - ct)
		if dist < 0.85:
			alpha = maxf(alpha, 1.0 - (dist / 0.85))
	_cut_fade_rect.color = Color(0.02, 0.03, 0.03, clampf(alpha, 0.0, 1.0))

func _update_captions(force_jump: bool = false) -> void:
	var new_main: String = ""
	var new_sub: String = ""
	if _elapsed < 7.0:
		new_main = "SOUTHEAST ASIA — THE PHILIPPINE ARCHIPELAGO"
		new_sub = "Rotating in from low-Earth orbit toward the Western Pacific..."
	elif _elapsed < 12.8:
		new_main = "ZOOMING IN: THE PHILIPPINES → MINDANAO"
		new_sub = "Descending toward the fertile southern island of Mindanao."
	elif _elapsed < 17.5:
		new_main = "REGION XII — COTABATO AGRICULTURAL BASIN"
		new_sub = "Locking onto your starting province before diving through the cloud canopy."
	elif _elapsed < 23.2:
		new_main = "BREAKING THROUGH THE CLOUDS — YOUR HOMESTEAD AWAITS"
		new_sub = "Descending from the sky straight down to your first farmer on the field."
	elif _elapsed < 34.0:
		new_main = "EVERY EMPIRE BEGINS WITH ONE FARMER AND ONE PLOT"
		new_sub = "Direct your worker to till the soil, sow Palay seeds, and hand-water each tile."
	elif _elapsed < 44.0:
		new_main = "NURTURE YOUR FIRST HARVEST FROM SEEDLING TO GOLD"
		new_sub = "Manage soil moisture, crop health, and Primera quality grading in real time."
	elif _elapsed < 57.0:
		new_main = "SCALE UP: IRRIGATION NETWORKS & MULTI-CROP AGRONOMY"
		new_sub = "Build Water Towers, Weather Stations, and Sprinklers across 7 signature Philippine crops."
	elif _elapsed < 70.0:
		new_main = "HIRE WORKER SQUADS & CULTIVATE 2×2 PERENNIAL GROVES"
		new_sub = "Harvest Cavendish Bananas, Tall Coconut Palms, Arabica Coffee, Pineapple & Sugarcane."
	elif _elapsed < 82.0:
		new_main = "PRECISION AGRICULTURE: AUTONOMOUS DRONE FLEETS"
		new_sub = "Deploy 6 programmable Farm Drones to plow, plant, water, spray, and harvest automatically."
	elif _elapsed < 94.0:
		new_main = "INDUSTRIAL PROCESSING, EXPORT PORTS & FIESTA CULTURE"
		new_sub = "Operate Rice & Sugar Mills, ship from GenSan Seaport, and celebrate with a full Fiesta Plaza."
	else:
		new_main = "AGRI-REGION TYCOON — BUILD MINDANAO'S GREATEST FARM"
		new_sub = "Cotabato • South Cotabato • Sarangani • Sultan Kudarat • General Santos City"

	_caption_main_lbl.text = new_main
	_caption_sub_lbl.text = new_sub
	if new_main != _last_caption_text:
		if not _last_caption_text.is_empty() and not force_jump and _is_playing:
			_play_trailer_sfx("text_appear", 1.0, -3.5)
		_last_caption_text = new_main

const TRAILER_SFX_TIMELINE: Array[Dictionary] = [
	{"t": 0.4,  "id": "zoom_orbit",    "sfx": "camera_zoom",  "pitch": 0.85, "db": -2.0},
	{"t": 4.2,  "id": "lock_ph",       "sfx": "reticle_lock", "pitch": 1.00, "db": -2.0},
	{"t": 5.0,  "id": "zoom_ph",       "sfx": "camera_zoom",  "pitch": 0.95, "db": -1.5},
	{"t": 8.4,  "id": "lock_mindanao", "sfx": "reticle_lock", "pitch": 1.12, "db": -2.0},
	{"t": 10.2, "id": "zoom_mindanao", "sfx": "camera_zoom",  "pitch": 1.08, "db": -1.5},
	{"t": 12.6, "id": "lock_cotabato", "sfx": "reticle_lock", "pitch": 1.25, "db": -1.5},
	{"t": 15.5, "id": "clouds_in",     "sfx": "cloud_whoosh", "pitch": 0.92, "db": -1.0},
	{"t": 18.0, "id": "clouds_part",   "sfx": "cloud_whoosh", "pitch": 1.18, "db": 0.0},
	{"t": 18.8, "id": "zoom_farmer",   "sfx": "camera_zoom",  "pitch": 1.15, "db": -2.0},
	{"t": 44.2, "id": "zoom_act3",     "sfx": "camera_zoom",  "pitch": 0.82, "db": -2.0},
	{"t": 70.2, "id": "zoom_act4",     "sfx": "camera_zoom",  "pitch": 0.90, "db": -2.0},
	{"t": 94.2, "id": "card_1",        "sfx": "card_appear",  "pitch": 0.92, "db": -1.5},
	{"t": 94.55,"id": "card_2",        "sfx": "card_appear",  "pitch": 1.00, "db": -1.5},
	{"t": 94.9, "id": "card_3",        "sfx": "card_appear",  "pitch": 1.08, "db": -1.5},
	{"t": 95.25,"id": "card_4",        "sfx": "card_appear",  "pitch": 1.16, "db": -1.5},
	{"t": 95.6, "id": "card_5",        "sfx": "card_appear",  "pitch": 1.25, "db": -1.5},
	{"t": 96.2, "id": "title_banner",  "sfx": "title_impact", "pitch": 1.00, "db": 0.5}
]

func _rebuild_triggered_cues_up_to(t_now: float) -> void:
	_triggered_cues.clear()
	for cue in TRAILER_SFX_TIMELINE:
		if float(cue["t"]) < t_now - 0.05:
			_triggered_cues[str(cue["id"])] = true

func _update_trailer_sfx_cues() -> void:
	for cue in TRAILER_SFX_TIMELINE:
		var cid: String = str(cue["id"])
		if not _triggered_cues.has(cid) and _elapsed >= float(cue["t"]):
			_triggered_cues[cid] = true
			_play_trailer_sfx(str(cue["sfx"]), float(cue["pitch"]), float(cue["db"]))

# =============================================================================
# CHAPTER I (ORBIT -> PH -> REGION -> CLOUDS) & CHAPTER V (5 REGIONS FINALE)
# =============================================================================
func _draw_intro_and_finale() -> void:
	var vp_size: Vector2 = _intro_canvas.size
	var center: Vector2 = vp_size * 0.5

	if _elapsed < 23.2:
		_draw_chapter_1_intro(vp_size, center)
	elif _elapsed >= 94.0:
		_draw_chapter_5_finale(vp_size, center)

func _draw_chapter_1_intro(vp_size: Vector2, center: Vector2) -> void:
	# 1. UNBROKEN CONTINUOUS PIXEL-ART GLOBE ZOOM (0.0s -> 18.0s):
	#    Spins in space, locks onto the Philippines, and zooms continuously on the SAME pixel-art globe
	#    into the Philippine Archipelago -> Mindanao -> Region XII (Cotabato Basin) with ZERO map cuts!
	if _elapsed < 18.0:
		_intro_canvas.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.02, 0.04, 0.07, 1.0))

		# Crisp twinkling pixel stars in space around the globe
		for i in range(70):
			var sx: float = fmod(float(i * 197 + 43), vp_size.x)
			var sy: float = fmod(float(i * 131 + 89), vp_size.y)
			var tw: float = 0.45 + 0.45 * sin(_elapsed * 1.8 + float(i))
			_intro_canvas.draw_rect(Rect2(Vector2(sx, sy), Vector2(2, 2)), Color(0.85, 0.92, 1.0, tw))

		_render_continuous_pixel_globe(_elapsed)
		if _globe_tex != null:
			_intro_canvas.draw_texture_rect(_globe_tex, Rect2(Vector2.ZERO, vp_size), false, Color.WHITE)

		# Tactical orbital reticles as the continuous pixel-art globe zooms in
		if _elapsed >= 4.2 and _elapsed < 8.4:
			var lock_a: float = smoothstep(4.2, 5.2, _elapsed) * (1.0 - smoothstep(7.2, 8.4, _elapsed))
			if lock_a > 0.01:
				_draw_tactical_reticle(center, 44.0, Color(0.98, 0.82, 0.25, lock_a), "PHILIPPINES [12°N 122°E]")
		elif _elapsed >= 8.4 and _elapsed < 12.6:
			var min_a: float = smoothstep(8.4, 9.4, _elapsed) * (1.0 - smoothstep(11.6, 12.6, _elapsed))
			if min_a > 0.01:
				_draw_tactical_reticle(center, 52.0, Color(0.40, 0.96, 0.52, min_a), "MINDANAO — REGION XII")
		elif _elapsed >= 12.6 and _elapsed < 16.8:
			var cot_a: float = smoothstep(12.6, 13.5, _elapsed) * (1.0 - smoothstep(15.6, 16.8, _elapsed))
			if cot_a > 0.01:
				_draw_tactical_reticle(center, 58.0, Color(0.99, 0.86, 0.30, cot_a), "COTABATO BASIN — HOMESTEAD")

	# 2. STAGE 1D (15.4s -> 23.2s): Atmospheric Cloud Canopy & Parting Clouds over the Live Farmer Zoom-In!
	if _elapsed >= 15.4 and _elapsed < 23.2 and _cloud_tex != null:
		# Soft atmospheric mist veil that peaks at 17.6s..18.3s (seamless bridge from Pixel Globe to Live SubViewport)
		var veil_in: float = smoothstep(15.6, 17.7, _elapsed)
		var veil_out: float = 1.0 - smoothstep(18.2, 20.6, _elapsed)
		var veil_alpha: float = veil_in * veil_out
		if veil_alpha > 0.01:
			_intro_canvas.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.92, 0.96, 0.99, veil_alpha * 0.96))

		# Draw 24 layered pixel-art cumulus clouds rushing in and parting radially outward as we dive onto Farmer_1
		var base_csize: Vector2 = _cloud_tex.get_size()
		for puff in _cloud_puffs:
			var delay: float = float(puff["delay"])
			var t_local: float = _elapsed - (15.4 + delay)
			if t_local <= 0.0:
				continue
			var u_in: float = smoothstep(0.0, 2.0, t_local)
			var u_part: float = clampf((_elapsed - (17.8 + delay * 0.6)) / 4.2, 0.0, 1.0)
			var u_part_eased: float = pow(u_part, 1.55)

			var dir: Vector2 = puff["dir"]
			var dist: float = float(puff["base_dist"]) * (0.35 + 0.65 * u_in) + u_part_eased * float(puff["part_speed"])
			var p_scale: float = float(puff["base_scale"]) * lerpf(0.65, 2.35, smoothstep(0.0, 6.2, t_local))
			var draw_size: Vector2 = base_csize * p_scale
			var pos: Vector2 = center + dir * dist - draw_size * 0.5

			var c_alpha: float = u_in * (1.0 - smoothstep(0.55, 1.0, u_part))
			if c_alpha > 0.01:
				_intro_canvas.draw_texture_rect(_cloud_tex, Rect2(pos, draw_size), false, Color(1, 1, 1, c_alpha))

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
	var card_h: float = 196.0
	var card_y: float = 42.0 if _clean_recording_mode else 74.0

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
			var m_pos: Vector2 = crect.position + Vector2((card_w - draw_ms.x) * 0.5, card_h - draw_ms.y - 32.0)
			_intro_canvas.draw_texture_rect(mon_t, Rect2(m_pos, draw_ms), false, Color(1, 1, 1, card_appear))

		_intro_canvas.draw_rect(Rect2(crect.position.x, crect.end.y - 28.0, card_w, 28.0), Color(0.03, 0.05, 0.04, 0.92 * card_appear))
		_intro_canvas.draw_rect(crect, Color(0.86, 0.68, 0.24, 0.88 * card_appear), false, 2.0)
		if _pixel_font:
			_intro_canvas.draw_string(_pixel_font, Vector2(crect.position.x + 8.0, crect.end.y - 9.0), titles[i], HORIZONTAL_ALIGNMENT_LEFT, card_w - 16.0, 13, Color(0.98, 0.92, 0.74, card_appear))

	# Grand Official Wooden Pixel-Art Logo Showcase in center-lower screen
	var title_a: float = smoothstep(95.8, 97.4, _elapsed)
	if title_a > 0.01:
		if _tex_game_logo != null:
			var logo_scale: float = lerpf(0.86, 1.0, title_a)
			var base_w: float = 500.0 if _clean_recording_mode else 460.0
			var base_h: float = base_w * (537.0 / 946.0)
			var draw_w: float = base_w * logo_scale
			var draw_h: float = base_h * logo_scale
			var logo_center_y: float = 418.0 if _clean_recording_mode else 404.0
			var logo_rect := Rect2(Vector2(center.x - draw_w * 0.5, logo_center_y - draw_h * 0.5), Vector2(draw_w, draw_h))
			_intro_canvas.draw_texture_rect(_tex_game_logo, logo_rect, false, Color(1.0, 1.0, 1.0, title_a))
		elif _pixel_font:
			var banner_rect := Rect2(Vector2(center.x - 360.0, 368.0), Vector2(720.0, 118.0))
			_intro_canvas.draw_rect(banner_rect, Color(0.04, 0.08, 0.06, 0.94 * title_a))
			_intro_canvas.draw_rect(banner_rect, Color(0.95, 0.76, 0.26, 0.95 * title_a), false, 3.0)
			_intro_canvas.draw_string(_pixel_font, Vector2(banner_rect.position.x, banner_rect.position.y + 48.0), "AGRI-REGION TYCOON", HORIZONTAL_ALIGNMENT_CENTER, banner_rect.size.x, 36, Color(0.99, 0.88, 0.42, title_a))

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
	if _trailer_bgm_player:
		_trailer_bgm_player.stream_paused = not _is_playing
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

func _set_clean_recording_mode(enabled: bool) -> void:
	_clean_recording_mode = enabled
	if _top_bar:
		_top_bar.visible = not enabled
	if _bot_bar:
		_bot_bar.visible = not enabled
	if _caption_panel:
		_caption_panel.visible = true
		# In full-screen recording mode (bottom bar hidden), shift the lower-third caption box neatly toward the bottom edge
		if enabled:
			_caption_panel.offset_top = -100.0
			_caption_panel.offset_bottom = -28.0
		else:
			_caption_panel.offset_top = -170.0
			_caption_panel.offset_bottom = -98.0
	if _corner_logo_watermark:
		_corner_logo_watermark.offset_top = 18.0 if enabled else 76.0
		_corner_logo_watermark.offset_bottom = 127.0 if enabled else 185.0
	if _finale_cta_box:
		_finale_cta_box.visible = (_elapsed >= 98.0) and not enabled

	if DisplayServer.get_name() != "headless":
		if enabled:
			if _saved_window_mode == -1:
				_saved_window_mode = DisplayServer.window_get_mode()
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		else:
			if _saved_window_mode != -1:
				DisplayServer.window_set_mode(_saved_window_mode as DisplayServer.WindowMode)
				_saved_window_mode = -1
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if _intro_canvas and _intro_canvas.visible:
		_intro_canvas.queue_redraw()

func _start_clean_recording_from_beginning() -> void:
	if _au():
		_au().play_ui("click")
	_playback_speed = 1.0
	_is_playing = true
	_jump_to_time(0.0)
	if _trailer_bgm_player:
		_trailer_bgm_player.stream_paused = false
		_trailer_bgm_player.play(0.0)
	_update_control_buttons()
	_set_clean_recording_mode(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _clean_recording_mode:
				_set_clean_recording_mode(false)
			else:
				_close_trailer()
		elif event.keycode == KEY_H or event.keycode == KEY_F or event.keycode == KEY_F11:
			get_viewport().set_input_as_handled()
			_set_clean_recording_mode(not _clean_recording_mode)
		elif event.keycode == KEY_R:
			get_viewport().set_input_as_handled()
			_start_clean_recording_from_beginning()
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
