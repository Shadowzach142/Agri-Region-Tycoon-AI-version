# AutoBoothController.gd
# Autonomous Booth / Kiosk Idle AI Controller for Agri-Region Tycoon.
# Features:
#   - Endless Showcase Mode running at comfortable 2× game speed + accelerated crop
#     maturation so booth visitors see constant, dynamic farming & tycoon action.
#   - Purchases Territory Deeds (`east_meadows`, `south_plains`, `highland_plateau`) to
#     expand the farm across the entire 32×32 island!
#   - Progressively builds & upgrades farm infrastructure across the homestead and
#     newly purchased territories (Bahay Kubos, Drone Command Hangar Lv.3, 4 Drone Landing
#     Pads, Irrigation Tower + Field Sprinklers, Climate Silo, Cold Storage, Solar Dryer,
#     PAGASA Weather Station, Biyahero Trading Post, Tacurong Mill Depot, Kiskisan Rice Mill,
#     Trapiche Sugar Central, Copra Dryer, Coffee Roastery, and Fiesta Decor).
#   - Commissions & deploys 4 autonomous FarmDrone units across all unlocked territories.
#   - Hires up to 5 human Farmer workers working alongside the drones.
#   - Plants all 7 crop varieties, including 2×2 Banana & Coconut perennial plantations!
#   - Less Sensitive Exit: Ignores mouse movement/table vibrations! Only stops auto-playing
#     when a visitor deliberately clicks (Left/Right Mouse Button) or presses a keyboard key.
#   - Automatically resumes playing by itself after 60 seconds (1 minute) of inactivity.

class_name AutoBoothController
extends CanvasLayer

const IDLE_TIMEOUT_SECONDS: float = 60.0
const AI_DECISION_INTERVAL: float = 0.65
const PROGRESSION_INTERVAL: float = 3.0
const CAMERA_PAN_INTERVAL: float  = 5.5

const STYLE_BROWN_BOX: StyleBox   = preload("res://assets/sprites/hud/TopRight/BrownBox.tres")
const STYLE_GOLD_BTN: StyleBox    = preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres")
const STYLE_GOLD_HOVER: StyleBox  = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres")
const STYLE_GOLD_PRESS: StyleBox  = preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres")

const FarmerMovementScript        = preload("res://src/farmer/FarmerMovement.gd")

# Safe autoload accessors
func _au() -> Node: return get_node_or_null("/root/AudioManager")
func _da() -> Node: return get_node_or_null("/root/Data")
func _ec() -> Node: return get_node_or_null("/root/EconomyManager")
func _ti() -> Node: return get_node_or_null("/root/TimeManager")
func _bm() -> Node: return get_node_or_null("/root/BuildingManager")
func _tm() -> Node: return get_node_or_null("/root/TaskManager")
func _mm() -> Node: return get_node_or_null("/root/MarketManager")

var is_auto_playing: bool = true
var _idle_seconds: float = 0.0
var _ai_timer: float = 0.35
var _prog_timer: float = 1.2
var _cam_timer: float = 2.0
var _crop_cycle_idx: int = 0
var _prog_stage: int = 0
var _startup_grace_timer: float = 2.5 # Ignore initial scene-load clicks/keys for 2.5s

# Scene references
var _farm_grid: Node2D = null
var _game_camera: Camera2D = null
var _hud: CanvasLayer = null

# UI Banner Nodes
var _status_panel: PanelContainer = null
var _status_label: Label = null
var _resume_now_btn: Button = null

const ROTATION_CROPS: Array[String] = [
	"palay",
	"yellow_corn",
	"sugarcane",
	"pineapple",
	"arabica_coffee"
]

const GROVE_SLOTS: Array[Dictionary] = [
	{"pos": Vector2i(11, 3), "crop": "banana"},
	{"pos": Vector2i(11, 6), "crop": "coconut"},
	{"pos": Vector2i(11, 9), "crop": "banana"},
	# East Meadows (unlocked in stage 4)
	{"pos": Vector2i(23, 3), "crop": "coconut"},
	{"pos": Vector2i(23, 6), "crop": "banana"},
	{"pos": Vector2i(23, 9), "crop": "coconut"},
	# South Plains (unlocked in stage 8)
	{"pos": Vector2i(10, 18), "crop": "banana"},
	{"pos": Vector2i(10, 21), "crop": "coconut"}
]

func _ready() -> void:
	layer = 185
	process_mode = Node.PROCESS_MODE_ALWAYS

	_discover_nodes()
	_build_ui()
	_unlock_all_showcase_crops()
	_enter_auto_play()

func _discover_nodes() -> void:
	var root := get_tree().root
	_farm_grid = root.find_child("FarmGrid", true, false) as Node2D
	_game_camera = root.find_child("GameCamera", true, false) as Camera2D
	_hud = root.find_child("HUDLayer", true, false) as CanvasLayer

func _unlock_all_showcase_crops() -> void:
	if not _bm():
		return
	for crop_id in ["palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"]:
		if not _bm().unlocked_crops.has(crop_id):
			_bm().unlocked_crops.append(crop_id)
			_bm().crop_unlocked.emit(crop_id)

func _build_ui() -> void:
	var root_ctrl := Control.new()
	root_ctrl.name = "AutoBoothRoot"
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	_status_panel = PanelContainer.new()
	_status_panel.name = "AutoBoothBanner"
	_status_panel.add_theme_stylebox_override("panel", STYLE_BROWN_BOX)
	_status_panel.custom_minimum_size = Vector2(340, 28)
	_status_panel.position = Vector2(465.0, 50.0)
	_status_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(_status_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_status_panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	_status_label = Label.new()
	_status_label.text = "🤖 AUTO SHOWCASE (2×): Click Mouse or Press Any Key to Play!"
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50, 1.0))
	hbox.add_child(_status_label)

	_resume_now_btn = Button.new()
	_resume_now_btn.text = "🤖 Auto Now"
	_resume_now_btn.custom_minimum_size = Vector2(86, 22)
	_resume_now_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_resume_now_btn.add_theme_font_size_override("font_size", 11)
	_resume_now_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
	_resume_now_btn.add_theme_stylebox_override("normal", STYLE_GOLD_BTN)
	_resume_now_btn.add_theme_stylebox_override("hover", STYLE_GOLD_HOVER)
	_resume_now_btn.add_theme_stylebox_override("pressed", STYLE_GOLD_PRESS)
	_resume_now_btn.visible = false
	_resume_now_btn.pressed.connect(func():
		_startup_grace_timer = 1.0
		_enter_auto_play()
	)
	hbox.add_child(_resume_now_btn)

# ---------------------------------------------------------------------------
# Input Detection — Less Sensitive!
# Ignores mouse movement & scroll bumps while Auto Mode is running; only
# exits Auto Mode on deliberate Left/Right Mouse Click or Keyboard Key press.
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if _startup_grace_timer > 0.0:
		return

	# While already in Manual Control, any mouse movement or input keeps the player's
	# session alive so the 60s idle timer never interrupts an active player.
	if not is_auto_playing:
		if event is InputEventMouseMotion and event.relative.length_squared() > 25.0:
			_idle_seconds = 0.0
		elif (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			_idle_seconds = 0.0
		return

	# While Auto Mode IS playing, require a deliberate click or key press to exit!
	var deliberate_action: bool = false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if _resume_now_btn and _resume_now_btn.visible and _resume_now_btn.get_global_rect().has_point(event.global_position):
				return
			deliberate_action = true
	elif event is InputEventKey and event.pressed and not event.echo:
		deliberate_action = true
	elif event is InputEventScreenTouch and event.pressed:
		deliberate_action = true
	elif event is InputEventJoypadButton and event.pressed:
		deliberate_action = true

	if deliberate_action:
		_idle_seconds = 0.0
		_pause_auto_for_player()

func _enter_auto_play() -> void:
	is_auto_playing = true
	_idle_seconds = 0.0
	_ai_timer = 0.2
	_prog_timer = 0.8
	_cam_timer = 1.0

	if _ti():
		# Run at smooth 2x speed so booth visitors see lively, readable tycoon action
		if _ti().has_method("set_speed_mode"):
			_ti().set_speed_mode(2) # TWO_X
		elif _ti().has_method("set_speed_scale"):
			_ti().set_speed_scale(2.0)
		if _hud and _hud.has_method("_update_speed_buttons_visual"):
			_hud._update_speed_buttons_visual()

	_update_banner_ui()

func _pause_auto_for_player() -> void:
	is_auto_playing = false
	_idle_seconds = 0.0

	# Set comfortable 1x speed when a player clicks or presses a key to take control
	if _ti():
		if _ti().has_method("set_speed_mode"):
			_ti().set_speed_mode(1) # ONE_X
		elif _ti().has_method("set_speed_scale"):
			_ti().set_speed_scale(1.0)
		if _hud and _hud.has_method("_update_speed_buttons_visual"):
			_hud._update_speed_buttons_visual()

	_update_banner_ui()

func _update_banner_ui() -> void:
	if not _status_label or not _status_panel:
		return
	if is_auto_playing:
		_status_label.text = "🤖 AUTO SHOWCASE (2×): Click Mouse or Press Any Key to Take Control!"
		_status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65, 1.0))
		if _resume_now_btn:
			_resume_now_btn.visible = false
	else:
		var rem: int = maxi(1, int(ceil(IDLE_TIMEOUT_SECONDS - _idle_seconds)))
		_status_label.text = "🕹️ MANUAL CONTROL — Auto-Play resumes after %ds idle" % rem
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50, 1.0))
		if _resume_now_btn:
			_resume_now_btn.visible = true

	var vp_w: float = get_viewport().get_visible_rect().size.x if get_viewport() else 1280.0
	_status_panel.reset_size()
	var target_x: float = clampf((vp_w - _status_panel.size.x) * 0.5, 460.0, vp_w - 190.0 - _status_panel.size.x)
	_status_panel.position = Vector2(target_x, 50.0)

# ---------------------------------------------------------------------------
# Main Loop: Idle Timer + Autonomous Farm AI + Tycoon Builder + Camera Director
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _startup_grace_timer > 0.0:
		_startup_grace_timer -= delta

	if not is_auto_playing:
		_idle_seconds += delta
		_update_banner_ui()
		if _idle_seconds >= IDLE_TIMEOUT_SECONDS:
			if get_tree().paused:
				var pm = get_tree().root.find_child("PauseMenu", true, false)
				if pm and pm.has_method("hide_menu"):
					pm.hide_menu()
				else:
					get_tree().paused = false
			_enter_auto_play()
		return

	# Auto-playing is active!
	if get_tree().paused:
		get_tree().paused = false

	# Keep game speed at 2x during Auto Mode
	if _ti() and _ti().get_speed_scale() != 2.0:
		if _ti().has_method("set_speed_mode"):
			_ti().set_speed_mode(2)
		elif _ti().has_method("set_speed_scale"):
			_ti().set_speed_scale(2.0)
		if _hud and _hud.has_method("_update_speed_buttons_visual"):
			_hud._update_speed_buttons_visual()

	_prog_timer -= delta
	if _prog_timer <= 0.0:
		_prog_timer = PROGRESSION_INTERVAL
		_run_progression_step()

	_ai_timer -= delta
	if _ai_timer <= 0.0:
		_ai_timer = AI_DECISION_INTERVAL
		_run_ai_tick()

	_cam_timer -= delta
	if _cam_timer <= 0.0:
		_cam_timer = CAMERA_PAN_INTERVAL
		_run_camera_director()

# ---------------------------------------------------------------------------
# Progressive Tycoon Infrastructure Builder, Land Acquisition & Drone Fleet
# ---------------------------------------------------------------------------
func _run_progression_step() -> void:
	if not _farm_grid or not ("tiles" in _farm_grid) or _farm_grid.tiles.is_empty():
		return

	# Ensure generous showcase capital so land deeds, buildings, seeds, and drones never stall
	if _ec() and _ec().cash < 4500:
		_ec().add_cash(5000)

	_unlock_all_showcase_crops()

	match _prog_stage:
		0:
			# Upgrade starter Bahay Kubo to Lv.3 & build a second Bahay Kubo at (4, 0)
			var kubo = _bm().get_building_of_type("bahay_kubo") if _bm() else null
			if is_instance_valid(kubo):
				kubo.level = 3
			var k2 := _place_instant_building(Vector2i(4, 0), "bahay_kubo", 2)
			if k2:
				_farm_grid.show_floating_text(Vector2i(4, 0), "🏡 Built Worker Housing (Lv.2)!", Color(0.45, 1.0, 0.55))
			if _bm():
				_bm().recalculate_bonuses()
			_hire_workers_up_to(3)
			_prog_stage += 1

		1:
			# Build Drone Command Hangar (Lv.3) at (6, 0) + First Drone Landing Pad at (8, 0)
			var hangar := _place_instant_building(Vector2i(6, 0), "drone_station", 3)
			var pad1 := _place_instant_building(Vector2i(8, 0), "drone_pad", 1)
			if hangar or pad1:
				_farm_grid.show_floating_text(Vector2i(6, 0), "🛸 Built Drone Command Hangar Lv.3!", Color(0.40, 0.90, 1.0))
			_sync_and_deploy_drones()
			_prog_stage += 1

		2:
			# Build Irrigation Pump & Tower (Lv.3) at (10, 0) + Rotary Sprinklers in the field
			var tower := _place_instant_building(Vector2i(10, 0), "water_tower", 3)
			_place_instant_building(Vector2i(5, 5), "sprinkler", 1)
			_place_instant_building(Vector2i(5, 9), "sprinkler", 1)
			if tower:
				_farm_grid.show_floating_text(Vector2i(10, 0), "🚰 Built Irrigation Tower & Sprinklers!", Color(0.35, 0.85, 1.0))
			_prog_stage += 1

		3:
			# Build Second Drone Landing Pad at (12, 0) + Biyahero Trading Post at (14, 0) + Climate Silo at (0, 2)
			_place_instant_building(Vector2i(12, 0), "drone_pad", 1)
			_place_instant_building(Vector2i(14, 0), "bayanihan_center", 1)
			var silo := _place_instant_building(Vector2i(0, 2), "climate_silo", 2)
			if silo:
				_farm_grid.show_floating_text(Vector2i(0, 2), "❄️ Built Climate-Controlled Silo!", Color(0.55, 0.95, 1.0))
			_hire_workers_up_to(4)
			_sync_and_deploy_drones()
			_ensure_2x2_groves_planted()
			_prog_stage += 1

		4:
			# PURCHASE TERRITORY #1: East Meadows (Rect2i(16, 0, 16, 16))!
			if _auto_purchase_parcel("east_meadows"):
				_pan_camera_to_grid(Vector2i(20, 5))
			_prog_stage += 1

		5:
			# Expand into East Meadows: Build Drone Pad #3 at (16, 0), Bahay Kubo #3 at (18, 0),
			# Copra Dryer (3x3) at (26, 0), and Sprinkler at (20, 5)
			_place_instant_building(Vector2i(16, 0), "drone_pad", 1)
			_place_instant_building(Vector2i(18, 0), "bahay_kubo", 2)
			var copra := _place_instant_building(Vector2i(26, 0), "copra_dryer", 2)
			_place_instant_building(Vector2i(20, 5), "sprinkler", 1)
			if copra:
				_farm_grid.show_floating_text(Vector2i(26, 0), "🔥 Built Tapahan Copra Dryer in East Territory!", Color(1.0, 0.85, 0.35))
			if _bm():
				_bm().recalculate_bonuses()
			_hire_workers_up_to(5)
			_sync_and_deploy_drones()
			_ensure_2x2_groves_planted()
			_prog_stage += 1

		6:
			# Build Solar Dryer (3x3) at (0, 5) + PAGASA Weather Station (3x3, Lv.3) at (0, 8) + Rice Mill (3x3) at (0, 11)
			_place_instant_building(Vector2i(0, 5), "solar_dryer", 2)
			_place_instant_building(Vector2i(0, 8), "weather_station", 3)
			var mill := _place_instant_building(Vector2i(0, 11), "rice_mill", 2)
			if mill:
				_farm_grid.show_floating_text(Vector2i(0, 11), "🏭 Built Kiskisan Rice Mill & PAGASA Station!", Color(1.0, 0.90, 0.40))
			_prog_stage += 1

		7:
			# PURCHASE TERRITORY #2: South Plains (Rect2i(0, 16, 16, 16))!
			if _auto_purchase_parcel("south_plains"):
				_pan_camera_to_grid(Vector2i(6, 20))
			_prog_stage += 1

		8:
			# Expand into South Plains: Build Drone Pad #4 at (14, 2), Cold Storage (3x3) at (0, 16),
			# Artisan Coffee Roastery (3x3) at (0, 19), Trapiche Sugar Central (4x4) at (0, 22), and Sprinkler at (6, 20)
			_place_instant_building(Vector2i(14, 2), "drone_pad", 1)
			_place_instant_building(Vector2i(0, 16), "cold_storage", 2)
			_place_instant_building(Vector2i(0, 19), "coffee_roastery", 2)
			var sugar := _place_instant_building(Vector2i(0, 22), "sugar_mill", 2)
			_place_instant_building(Vector2i(6, 20), "sprinkler", 1)
			if sugar:
				_farm_grid.show_floating_text(Vector2i(0, 22), "⚙️ Built Sugar Central & Coffee Roastery!", Color(1.0, 0.85, 0.40))
			_sync_and_deploy_drones()
			_ensure_2x2_groves_planted()
			_prog_stage += 1

		9:
			# PURCHASE TERRITORY #3: Highland Plateau / Southeast Estate (Rect2i(16, 16, 16, 16))!
			if _auto_purchase_parcel("highland_plateau"):
				_pan_camera_to_grid(Vector2i(20, 20))
			# Build Tacurong Grain Mill Depot (4x4) at (16, 16) + Fiesta Flowers
			var depot := _place_instant_building(Vector2i(16, 16), "tacurong_mill", 1)
			if depot:
				_farm_grid.show_floating_text(Vector2i(16, 16), "🏭 Built Tacurong Wholesale Depot!", Color(0.55, 1.0, 0.65))
			_place_instant_building(Vector2i(0, 14), "flower_bougainvillea_pink", 1)
			_place_instant_building(Vector2i(1, 14), "flower_gumamela_colorful", 1)
			_place_instant_building(Vector2i(2, 14), "flower_santan_box_yellow", 1)
			_prog_stage += 1

		_:
			# Ongoing maintenance: ensure all parcels are unlocked, 5 workers active, 4 drones deployed, and 2x2 groves healthy
			for pid in ["east_meadows", "south_plains", "highland_plateau"]:
				if ("unlocked_parcels" in _farm_grid) and not _farm_grid.unlocked_parcels.has(pid):
					_auto_purchase_parcel(pid)
			_hire_workers_up_to(5)
			_sync_and_deploy_drones()
			_ensure_2x2_groves_planted()

func _auto_purchase_parcel(parcel_id: String) -> bool:
	if not _farm_grid or not _farm_grid.has_method("unlock_parcel"):
		return false
	if ("unlocked_parcels" in _farm_grid) and _farm_grid.unlocked_parcels.has(parcel_id):
		return false
	var p_data: Dictionary = _da().get_parcel(parcel_id) if _da() else {}
	var cost: int = int(p_data.get("cost", 2500))
	if _ec() and _ec().cash < cost + 1500:
		_ec().add_cash(cost + 2000)
	var ok: bool = _farm_grid.unlock_parcel(parcel_id)
	if ok:
		var p_name: String = str(p_data.get("name", parcel_id.capitalize()))
		var rect: Rect2i = p_data.get("rect", Rect2i(16, 0, 16, 16))
		_farm_grid.show_floating_text(rect.position + Vector2i(4, 4), "🗺️ Auto-Purchased Land: %s!" % p_name, Color(0.35, 1.0, 0.55))
	return ok

func _pan_camera_to_grid(grid_pos: Vector2i) -> void:
	if not _game_camera or not _farm_grid:
		return
	var world_p: Vector2 = FarmerMovementScript.grid_to_pixel_center(grid_pos, _farm_grid)
	if _game_camera.has_method("pan_to"):
		_game_camera.pan_to(world_p)

func _place_instant_building(start_pos: Vector2i, b_type: String, target_level: int = 1) -> Node:
	if not _farm_grid or not _bm() or not _da():
		return null
	if _bm().is_unique_building(b_type) and _bm().owns_building(b_type):
		var existing = _bm().get_building_of_type(b_type)
		if is_instance_valid(existing):
			existing.level = maxi(existing.level, target_level)
			existing.state = 1 # Building.BuildingState.ACTIVE
			_bm().recalculate_bonuses()
		return existing

	var b_data: Dictionary = _da().get_building(b_type)
	if b_data.is_empty():
		return null
	var fp: Vector2i = b_data.get("grid_size", Vector2i(2, 2))

	# Clear any obstacles or crops on the target footprint first
	for dx in range(fp.x):
		for dy in range(fp.y):
			var tp := Vector2i(start_pos.x + dx, start_pos.y + dy)
			if not _farm_grid._is_valid(tp) or not _farm_grid.is_tile_unlocked(tp):
				return null
			var t: FarmTile = _farm_grid.tiles[tp.x][tp.y]
			if t.building_ref != null:
				return null # Already occupied by another building

	var building = _farm_grid._spawn_starter_building(start_pos, b_type)
	if is_instance_valid(building):
		building.level = target_level
		building.state = 1 # Building.BuildingState.ACTIVE
		_bm().recalculate_bonuses()
		if _farm_grid.renderer:
			for dx in range(fp.x):
				for dy in range(fp.y):
					_farm_grid.renderer.update_tile(Vector2i(start_pos.x + dx, start_pos.y + dy), _farm_grid.tiles)
	return building

func _hire_workers_up_to(target_count: int) -> void:
	if not _bm():
		return
	while _bm().active_workers < target_count and _bm().active_workers < _bm().worker_capacity:
		_bm().active_workers += 1
		_bm().worker_hired.emit(_bm().active_workers)
		_bm().worker_capacity_changed.emit(_bm().worker_capacity, _bm().active_workers)
		if _hud and _hud.has_method("_on_worker_spawn_requested"):
			_hud._on_worker_spawn_requested()
		if _farm_grid:
			_farm_grid.show_floating_text(Vector2i(1, 1), "👷 Auto-Hired Farmer #%d!" % _bm().active_workers, Color(0.45, 1.0, 0.55))

func _sync_and_deploy_drones() -> void:
	if not _farm_grid or not _farm_grid.has_method("_sync_drones"):
		return
	var hangar = _bm().get_drone_hangar() if _bm() else null
	if is_instance_valid(hangar):
		hangar.level = 3
	if _bm():
		_bm().recalculate_bonuses()
	_farm_grid._sync_drones()

	if not ("drones" in _farm_grid):
		return

	var drone_zones: Array[Dictionary] = [
		{"rect": Rect2i(3, 2, 4, 4), "crop": "palay"},
		{"rect": Rect2i(7, 2, 4, 4), "crop": "pineapple"},
		{"rect": Rect2i(17, 3, 5, 5), "crop": "sugarcane"},
		{"rect": Rect2i(4, 17, 5, 5), "crop": "arabica_coffee"}
	]

	for i in range(_farm_grid.drones.size()):
		var d = _farm_grid.drones[i]
		if not is_instance_valid(d):
			continue
		var cfg: Dictionary = drone_zones[i % drone_zones.size()]
		var r: Rect2i = cfg["rect"]
		# If the target parcel isn't unlocked yet, fallback to homestead sector (3, 6, 4, 4)
		if not _farm_grid.is_tile_unlocked(r.position):
			r = Rect2i(3, 6, 4, 4)
		if d.zone.is_empty() or (d.zone_rect.position == Vector2i(3, 6) and _farm_grid.is_tile_unlocked(cfg["rect"].position) and i >= 2):
			var zone_tiles: Array = []
			for gx in range(r.position.x, r.end.x):
				for gy in range(r.position.y, r.end.y):
					var p := Vector2i(gx, gy)
					if _farm_grid._is_valid(p) and _farm_grid.is_tile_unlocked(p) and _farm_grid.tiles[p.x][p.y].building_ref == null:
						if _farm_grid.tiles[p.x][p.y].state == FarmTile.TileState.OBSTACLE:
							_farm_grid.tiles[p.x][p.y].reset()
							_farm_grid.renderer.update_tile(p, _farm_grid.tiles)
						zone_tiles.append(p)
			if not zone_tiles.is_empty():
				if d.has_method("set_directive_mode"):
					d.set_directive_mode("auto_loop")
				if d.has_method("deploy"):
					d.deploy(zone_tiles, str(cfg["crop"]))

func _ensure_2x2_groves_planted() -> void:
	if not _farm_grid:
		return
	for slot in GROVE_SLOTS:
		var root_pos: Vector2i = slot["pos"]
		var crop_name: String = slot["crop"]
		if not _farm_grid._is_valid(root_pos) or not _farm_grid.is_tile_unlocked(root_pos):
			continue
		var root_t: FarmTile = _farm_grid.tiles[root_pos.x][root_pos.y]
		if root_t.crop_type != "" or root_t.building_ref != null:
			continue
		# Ensure all 4 tiles of the 2x2 footprint are unlocked, cleared of obstacles, and plowed
		var can_plant_2x2: bool = true
		for dx in range(2):
			for dy in range(2):
				var p := root_pos + Vector2i(dx, dy)
				if not _farm_grid._is_valid(p) or not _farm_grid.is_tile_unlocked(p):
					can_plant_2x2 = false
					break
				var t: FarmTile = _farm_grid.tiles[p.x][p.y]
				if t.building_ref != null:
					can_plant_2x2 = false
					break
				if t.state != FarmTile.TileState.PLOWED:
					if t.state == FarmTile.TileState.OBSTACLE:
						t.reset()
					_farm_grid.plow_tile(p)
		if can_plant_2x2:
			_farm_grid.plant_crop(root_pos, crop_name)

# ---------------------------------------------------------------------------
# Autonomous Farm AI Decision Engine + Showcase Growth Accelerator
# ---------------------------------------------------------------------------
func _run_ai_tick() -> void:
	if not _farm_grid or not ("tiles" in _farm_grid) or _farm_grid.tiles.is_empty():
		return

	# 1. Keep booth treasury healthy so the farm never stalls
	if _ec() and _ec().cash < 2000:
		_ec().add_cash(3000)

	# 2. Ensure all workers are selected to receive batch tasks
	var farmers := get_tree().get_nodes_in_group("farmers")
	if _tm() and _tm().get_selected_farmers().size() < farmers.size():
		for f in farmers:
			if is_instance_valid(f):
				_tm().select_farmer(f, true)

	# 3. Accelerate crop growth across all unlocked parcels during Auto Mode
	_accelerate_showcase_crops()

	# 4. Strategic Bodega / Market Logistics:
	#    - First, purge any 0% rotten batches so they never clog storage or stall selling
	#    - Second, evaluate each stored batch across all unlocked trade hubs (`preview_crop_sale` / unit math)
	#      and pick the hub that yields the HIGHEST positive net profit after road rot and fuel!
	#    - If a distant hub's road rot would ruin a low-freshness batch (0 gross), fall back to
	#      0-rot `local_biyahero` (instant pickup) or discard if completely spoiled.
	_run_strategic_market_sales()

	# Don't overload the task queue if workers already have tasks queued
	if _tm() and _tm().get_task_count() >= maxi(12, farmers.size() * 4):
		return

	# 5. Strategic Agronomy & Field Triage across all unlocked territories:
	#    - Detect incoming disasters (`WeatherManager.incoming_disaster`) for emergency early-harvest salvage
	#    - Detect flooded, dead, or rotten crops on the field (`FLOODED`, `health <= 0.18`, `freshness <= 0.0`)
	#      and immediately dispatch workers to clear/re-plow them so plots never stay stuck with dead crops!
	var wm = get_node_or_null("/root/WeatherManager")
	var emergency_salvage: bool = (wm != null and str(wm.incoming_disaster) in ["flash_flood", "landslide"])

	var rotten_field_list: Array[Vector2i] = []
	var harvest_list: Array[Vector2i] = []
	var spray_list: Array[Vector2i] = []
	var water_list: Array[Vector2i] = []
	var plant_list: Array[Vector2i] = []
	var plow_list: Array[Vector2i] = []
	var clear_list: Array[Vector2i] = []

	var field_rects: Array[Rect2i] = [
		Rect2i(3, 2, 8, 11),   # Homestead crop block
		Rect2i(17, 3, 6, 9),   # East Meadows crop block
		Rect2i(4, 17, 6, 8),   # South Plains crop block
		Rect2i(18, 21, 6, 6)   # Highland Plateau crop block
	]

	for rect in field_rects:
		if not _farm_grid.is_tile_unlocked(rect.position):
			continue
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var pos := Vector2i(x, y)
				if not _farm_grid._is_valid(pos) or not _farm_grid.is_tile_unlocked(pos):
					continue
				var tile: FarmTile = _farm_grid.tiles[x][y]
				if tile == null or tile.building_ref != null:
					continue
				if tile.multi_tile_root_pos != Vector2i(-1, -1) and not tile.is_multi_tile_root:
					continue
				if _tm() and _tm().has_task_at(pos):
					continue

				if tile.state == FarmTile.TileState.OBSTACLE:
					clear_list.append(pos)
				elif tile.crop_type != "" and (tile.state == FarmTile.TileState.FLOODED or tile.health <= 0.18 or tile.freshness <= 0.0):
					# Rotten / drowned / withered crop on the field -> collect & re-plow immediately!
					rotten_field_list.append(pos)
				elif tile.state == FarmTile.TileState.HARVESTABLE or (tile.crop_type != "" and tile.growth_progress >= 1.0):
					harvest_list.append(pos)
				elif emergency_salvage and tile.crop_type != "" and tile.growth_progress >= 0.65:
					# Incoming flood/landslide -> emergency salvage harvest before disaster strikes!
					harvest_list.append(pos)
				elif tile.crop_type != "":
					if tile.pest_type != "" or tile.state == FarmTile.TileState.INFECTED:
						spray_list.append(pos)
					else:
						var c_data: Dictionary = _da().get_crop(tile.crop_type) if _da() else {}
						var w_min: float = float(c_data.get("water_min", 45.0))
						if tile.soil_moisture < w_min + 10.0:
							water_list.append(pos)
				elif tile.state == FarmTile.TileState.PLOWED and tile.crop_type == "":
					plant_list.append(pos)
				elif tile.state == FarmTile.TileState.EMPTY or tile.state == FarmTile.TileState.FLOODED:
					plow_list.append(pos)

	# Also check 2x2 groves for rotten/flooded state, pests, thirst, or harvest readiness
	for slot in GROVE_SLOTS:
		var gpos: Vector2i = slot["pos"]
		if _farm_grid._is_valid(gpos) and _farm_grid.is_tile_unlocked(gpos):
			var gt: FarmTile = _farm_grid.tiles[gpos.x][gpos.y]
			if gt == null or (_tm() and _tm().has_task_at(gpos)):
				continue
			if gt.crop_type != "" and (gt.state == FarmTile.TileState.FLOODED or gt.health <= 0.18 or gt.freshness <= 0.0):
				rotten_field_list.append(gpos)
			elif gt.state == FarmTile.TileState.HARVESTABLE or (gt.crop_type != "" and gt.growth_progress >= 1.0):
				harvest_list.append(gpos)
			elif gt.crop_type != "" and (gt.pest_type != "" or gt.state == FarmTile.TileState.INFECTED):
				spray_list.append(gpos)
			elif gt.crop_type != "" and gt.soil_moisture < 50.0:
				water_list.append(gpos)

	# Priority 0: Clear & re-plow rotten, flooded, or dead crops so they never stall the field!
	if not rotten_field_list.is_empty():
		var targets := rotten_field_list.slice(0, 4)
		_farm_grid._on_batch_action_selected("plow", targets, {})
		_farm_grid.show_floating_text(targets[0], "🧹 Clearing Rotten/Flooded Crop!", Color(1.0, 0.75, 0.35))
		return

	if not clear_list.is_empty():
		var pos: Vector2i = clear_list[0]
		_farm_grid._on_action_popup_selected("clear", pos, {"cost": 50})
		return

	if not harvest_list.is_empty():
		var targets := harvest_list.slice(0, 4)
		_farm_grid._on_batch_action_selected("harvest", targets, {"early_confirmed": true})
		return

	if not spray_list.is_empty():
		var targets := spray_list.slice(0, 3)
		_farm_grid._on_batch_action_selected("spray_pest", targets, {"method": "biological", "cost": 45})
		return

	if not water_list.is_empty():
		var targets := water_list.slice(0, 4)
		_farm_grid._on_batch_action_selected("water", targets, {"amount": 25.0})
		return

	if not plant_list.is_empty():
		for pos in plant_list.slice(0, 4):
			var chosen_crop: String = _pick_strategic_crop()
			_farm_grid._on_action_popup_selected("plant", pos, {"crop_type": chosen_crop})
		return

	if not plow_list.is_empty():
		var targets := plow_list.slice(0, 5)
		_farm_grid._on_batch_action_selected("plow", targets, {})
		return

func _run_strategic_market_sales() -> void:
	if not _mm():
		return
	if _mm().has_method("discard_ruined_batches"):
		_mm().discard_ruined_batches()
	if _mm().stored_inventory.is_empty():
		return

	# Hold raw millable crops (palay, sugarcane, coconut, arabica_coffee) briefly if an active mill can process them
	# AND storage isn't getting full (< 65% capacity) AND freshness is still high (>= 75%).
	var st_status: Dictionary = _bm().get_storage_status() if _bm() else {"capacity": 1000, "used": 0}
	var storage_ratio: float = float(st_status.get("used", 0)) / maxf(float(st_status.get("capacity", 1000)), 1.0)

	var sell_idx: int = -1
	for i in range(_mm().stored_inventory.size()):
		var b: Dictionary = _mm().stored_inventory[i]
		var c_name: String = str(b.get("crop", ""))
		var fresh: float = float(b.get("freshness", 100.0))
		if fresh <= 0.0:
			continue
		var can_mill: bool = false
		if storage_ratio < 0.65 and fresh >= 75.0 and _bm():
			if c_name == "palay" and _bm().has_building("rice_mill"):
				can_mill = true
			elif c_name == "sugarcane" and _bm().has_building("sugar_mill"):
				can_mill = true
			elif c_name == "coconut" and _bm().has_building("copra_dryer"):
				can_mill = true
			elif c_name == "arabica_coffee" and _bm().has_building("coffee_roastery"):
				can_mill = true
		if not can_mill:
			sell_idx = i
			break

	# If all batches are waiting for milling but storage is >= 65% full, sell the oldest batch anyway
	if sell_idx == -1 and storage_ratio >= 0.65:
		sell_idx = 0
	if sell_idx == -1:
		return

	var batch_info: Dictionary = _mm().stored_inventory[sell_idx]
	var crop_sold: String = str(batch_info.get("crop", "palay"))
	var qty_sold: int = int(batch_info.get("quantity", 100))
	var batch_fresh: float = float(batch_info.get("freshness", 100.0))

	# Evaluate all unlocked hubs to pick the one with the highest net profit that won't rot the batch in transit!
	var best_hub: String = "local_biyahero"
	var best_net: int = -999999
	var candidate_hubs: Array[String] = ["local_biyahero", "tacurong", "koronadal", "gensan_port"]
	for h_id in candidate_hubs:
		if _bm() and _bm().has_method("is_hub_unlocked") and not _bm().is_hub_unlocked(h_id):
			continue
		var h_data: Dictionary = _da().get_market_hub(h_id) if _da() else {}
		var road_rot: float = float(h_data.get("rot_risk_percent", 0.0))
		if (_bm() and _bm().has_cold_storage()) or bool(batch_info.get("is_cold_storage", false)) or bool(batch_info.get("is_processed", false)):
			road_rot = 0.0
		var arrival_f: float = maxf(batch_fresh - road_rot, 0.0)
		if arrival_f <= 0.0:
			continue # Skip hubs where road transit would ruin the batch!
		var unit_p: float = _mm().calculate_unit_price(crop_sold, str(batch_info.get("grade", "Grade A")), arrival_f, h_id)
		var est_net: int = int(unit_p * float(qty_sold)) - int(h_data.get("fuel_cost", 0))
		if est_net > best_net:
			best_net = est_net
			best_hub = h_id

	if _mm().sell_stored_batch(sell_idx, best_hub):
		_farm_grid.show_floating_text(Vector2i(2, 1), "🚛 Auto-Sold %d %s!" % [qty_sold, crop_sold.capitalize()], Color(1.0, 0.90, 0.35))
	else:
		# Fallback: if selling to best_hub failed (e.g. ruined or fuel), sell to 0-rot local_biyahero or discard
		if not _mm().sell_stored_batch(sell_idx, "local_biyahero"):
			_mm().stored_inventory.remove_at(sell_idx)
			_mm().inventory_changed.emit()

func _pick_strategic_crop() -> String:
	# Choose crop strategically based on current weather climate + market price trends!
	var wm = get_node_or_null("/root/WeatherManager")
	var candidatos: Array[String] = []
	if wm != null:
		if wm.current_climate == wm.Climate.EL_NINO:
			# Drought / heatwave: prioritize heat & drought-resilient crops
			candidatos = ["yellow_corn", "pineapple", "sugarcane"]
		elif wm.current_climate == wm.Climate.LA_NINA:
			# Heavy monsoon rain: prioritize water-loving Palay & Sugarcane
			candidatos = ["palay", "sugarcane", "yellow_corn"]

	if candidatos.is_empty():
		candidatos = ROTATION_CROPS.duplicate()

	# 50% of the time pick the highest-priced crop in the current market, 50% rotate for farm diversity
	if _mm() and randf() < 0.55:
		var best_c: String = "palay"
		var best_score: float = -1.0
		for c in candidatos:
			if _bm() and _bm().has_method("is_crop_unlocked") and not _bm().is_crop_unlocked(c):
				continue
			var p: float = _mm().get_benchmark_price(c)
			if p > best_score:
				best_score = p
				best_c = c
		return best_c

	return _pick_unlocked_crop()

func _accelerate_showcase_crops() -> void:
	if not _farm_grid or not _farm_grid.renderer:
		return
	var max_x: int = _farm_grid.GRID_SIZE.x if ("GRID_SIZE" in _farm_grid) else 32
	var max_y: int = _farm_grid.GRID_SIZE.y if ("GRID_SIZE" in _farm_grid) else 32
	for x in range(max_x):
		for y in range(max_y):
			var pos := Vector2i(x, y)
			if not _farm_grid.is_tile_unlocked(pos):
				continue
			var tile: FarmTile = _farm_grid.tiles[x][y]
			if tile == null or tile.crop_type == "":
				continue
			if tile.multi_tile_root_pos != Vector2i(-1, -1) and not tile.is_multi_tile_root:
				continue
			if tile.state in [FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING]:
				var old_stage_prog: float = tile.growth_progress
				tile.growth_progress = minf(1.0, tile.growth_progress + 0.075)
				tile.soil_moisture = clampf(tile.soil_moisture, 55.0, 80.0)
				tile.health = 1.0
				if tile.growth_progress >= 1.0:
					tile.state = FarmTile.TileState.HARVESTABLE
					tile.is_regrowing = false
				elif tile.growth_progress > 0.05:
					tile.state = FarmTile.TileState.GROWING

				if tile.is_multi_tile_root:
					_farm_grid._sync_multi_tile_children(pos)
					for dx in range(2):
						for dy in range(2):
							_farm_grid.renderer.update_tile(pos + Vector2i(dx, dy), _farm_grid.tiles)
				elif int(old_stage_prog * 4.0) != int(tile.growth_progress * 4.0) or tile.state == FarmTile.TileState.HARVESTABLE:
					_farm_grid.renderer.update_tile(pos, _farm_grid.tiles)

func _pick_unlocked_crop() -> String:
	for _i in range(ROTATION_CROPS.size()):
		var candidate: String = ROTATION_CROPS[_crop_cycle_idx % ROTATION_CROPS.size()]
		_crop_cycle_idx += 1
		if not _bm() or not _bm().has_method("is_crop_unlocked") or _bm().is_crop_unlocked(candidate):
			return candidate
	return "palay"

func _run_camera_director() -> void:
	if not _game_camera or not _farm_grid:
		return

	# Cycle camera focus between active Drones, Farmers, and unlocked Territories
	var roll: float = randf()
	if ("drones" in _farm_grid) and not _farm_grid.drones.is_empty() and roll < 0.42:
		var d = _farm_grid.drones[randi() % _farm_grid.drones.size()]
		if is_instance_valid(d) and _game_camera.has_method("pan_to"):
			_game_camera.pan_to((d as Node2D).global_position)
			return

	var farmers := get_tree().get_nodes_in_group("farmers")
	if not farmers.is_empty() and roll < 0.80:
		var f = farmers[randi() % farmers.size()]
		if is_instance_valid(f) and _game_camera.has_method("pan_to"):
			_game_camera.pan_to((f as Node2D).global_position)
			return

	var candidate_Spots: Array[Vector2i] = [Vector2i(6, 5), Vector2i(10, 5)]
	if _farm_grid.is_tile_unlocked(Vector2i(18, 5)):
		candidate_Spots.append(Vector2i(20, 5))
	if _farm_grid.is_tile_unlocked(Vector2i(6, 18)):
		candidate_Spots.append(Vector2i(6, 20))
	if _farm_grid.is_tile_unlocked(Vector2i(18, 18)):
		candidate_Spots.append(Vector2i(20, 20))

	var focus_tile: Vector2i = candidate_Spots[randi() % candidate_Spots.size()]
	_pan_camera_to_grid(focus_tile)
