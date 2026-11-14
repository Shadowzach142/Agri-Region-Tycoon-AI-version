# MultiplayerSpectateView.gd
# Renders a live spectated rival player's or AI's isometric farm when clicking
# any rival row in the toggleable Multiplayer Live Leaderboard.
# Instantiates the rival's authentic RegionalMap (Cotabato, South Cotabato,
# Sarangani, Sultan Kudarat, or General Santos) and draws the 32x32 4x-scaled
# isometric ground tiles, crops, buildings, and colored rival farmers while
# keeping the local player's farm simulation running live in the background.

class_name MultiplayerSpectateView
extends Node2D

const GRID_SIZE: int = 32

const FONT_MAIN: FontFile = preload("res://assets/font/quill_and_antler/quill-and-antler.ttf")
const FARMER_SCRIPT: GDScript = preload("res://src/farmer/Farmer.gd")
const FARMER_MOVEMENT_SCRIPT: GDScript = preload("res://src/farmer/FarmerMovement.gd")
const FARM_TILE_SCRIPT: GDScript = preload("res://src/core/FarmTile.gd")
const TILE_RENDERER_SCRIPT: GDScript = preload("res://src/core/TileRenderer.gd")
const GROUND_SPRITES_PATH: String = "res://assets/sprites/ground/ground_tile_sprites.tres"
const TEX_BROWN_BTN: Texture2D = preload("res://assets/sprites/hud/TopBar/Button/brown-button.png")

const BUILDING_SPRITES: Dictionary = {
	"bahay_kubo": "res://assets/sprites/buildings/KUBO.png",
	"bodega": "res://assets/sprites/buildings/Silo/SILO-50.PNG",
	"climate_silo": "res://assets/sprites/buildings/Silo/CLIMATE-SILO-50.PNG",
	"solar_dryer": "res://assets/sprites/buildings/DRYER.PNG",
	"cold_storage": "res://assets/sprites/buildings/Cold_Storage.png",
	"drone_station": "res://assets/sprites/buildings/Drone_Station.png",
	"drone_pad": "res://assets/sprites/buildings/Drone_Station.png",
	"water_tower": "res://assets/sprites/buildings/Water_Station.png",
	"weather_station": "res://assets/sprites/buildings/Weather_Station.png",
	"rice_mill": "res://assets/sprites/buildings/Kiskisan_Rice_Mill.png",
	"sugar_mill": "res://assets/sprites/buildings/Trapiche_Sugar_Central.png",
	"copra_dryer": "res://assets/sprites/buildings/Tapahan_Copra_Dryer.png",
	"coffee_roastery": "res://assets/sprites/buildings/Artisan_Coffee_Roastery.png",
}

var _spectate_slot_id: String = ""
var _is_spectating: bool = false
var _loaded_region_key: String = ""
var _tile_renderer: TileRenderer = null
var _ground_sprites_res: Resource = null
var _scratch_tile: Resource = null
var _crop_tex_cache: Dictionary = {}
var _building_tex_cache: Dictionary = {}
var _farmer_frames_cache: Dictionary = {}
var _interp_farmers: Dictionary = {}  # farmer_key -> { pos, target, anim, frame, flip, name }
var _interp_drones: Dictionary = {}   # drone_key -> { pos, target, level, active }
var _anim_clock: float = 0.0
var _objects_redraw_accum: float = 0.0
var _last_ground_sig: String = ""
const SPECTATE_OBJECTS_INTERVAL: float = 0.04

var _regional_map_holder: Node2D = null
var _regional_map_node: Node = null
var _ground_layer: Node2D = null
var _objects_layer: Node2D = null

var _banner_layer: CanvasLayer = null
var _banner_panel: PanelContainer = null


func _ready() -> void:
	name = "MultiplayerSpectateView"
	z_index = 0
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tile_renderer = TILE_RENDERER_SCRIPT.new()
	_scratch_tile = FARM_TILE_SCRIPT.new()
	if ResourceLoader.exists(GROUND_SPRITES_PATH):
		_ground_sprites_res = load(GROUND_SPRITES_PATH)
	_preload_building_textures()
	_build_world_layers()
	_build_spectate_pill()

	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp:
		if mp.has_signal("spectate_changed") and not mp.spectate_changed.is_connected(_on_spectate_changed):
			mp.spectate_changed.connect(_on_spectate_changed)
		if mp.has_signal("snapshots_updated") and not mp.snapshots_updated.is_connected(_on_snapshots_updated):
			mp.snapshots_updated.connect(_on_snapshots_updated)


func _preload_building_textures() -> void:
	for btype in BUILDING_SPRITES.keys():
		var path: String = str(BUILDING_SPRITES[btype])
		if ResourceLoader.exists(path):
			_building_tex_cache[btype] = load(path)


func _build_world_layers() -> void:
	# 1. Holds the rival's authentic RegionalMap (SeaWater -40, OutOfBoundsTerrain -8, DirtTrail -5, Forest/Monuments +10, Fog +22)
	_regional_map_holder = Node2D.new()
	_regional_map_holder.name = "SpectateRegionalMapHolder"
	_regional_map_holder.z_index = 0
	_regional_map_holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_regional_map_holder)

	# 2. Ground tiles layer (Z=0, draws 128x128 4x-scaled isometric tiles cleanly back-to-front)
	_ground_layer = Node2D.new()
	_ground_layer.name = "SpectateGroundLayer"
	_ground_layer.z_index = 0
	_ground_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground_layer.draw.connect(_on_draw_ground)
	add_child(_ground_layer)

	# 3. Standing objects layer (Z=10, Y-sorted with RegionalMap MonumentsLayer & TreesLayer)
	_objects_layer = Node2D.new()
	_objects_layer.name = "SpectateObjectsLayer"
	_objects_layer.z_index = 10
	_objects_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_objects_layer.draw.connect(_on_draw_objects)
	add_child(_objects_layer)


func _build_spectate_pill() -> void:
	_banner_layer = CanvasLayer.new()
	_banner_layer.name = "SpectateBannerLayer"
	_banner_layer.layer = 64
	_banner_layer.visible = false
	add_child(_banner_layer)

	# Compact minimalist floating pill: just "Spectating" + "Return to Farm"
	_banner_panel = PanelContainer.new()
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_right = 0.5
	_banner_panel.anchor_top = 0.0
	_banner_panel.anchor_bottom = 0.0
	_banner_panel.offset_left = -124.0
	_banner_panel.offset_right = 124.0
	_banner_panel.offset_top = 56.0
	_banner_panel.offset_bottom = 96.0
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.08, 0.06, 0.92)
	st.border_color = Color(0.82, 0.66, 0.32, 0.92)
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	_banner_panel.add_theme_stylebox_override("panel", st)
	_banner_layer.add_child(_banner_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_panel.add_child(hbox)

	var lbl := Label.new()
	lbl.text = "👁️ Spectating"
	lbl.add_theme_font_override("font", FONT_MAIN)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	hbox.add_child(lbl)

	var back_btn := Button.new()
	back_btn.text = "Return to Farm"
	back_btn.custom_minimum_size = Vector2(118, 28)
	back_btn.tooltip_text = "Return to your farm [ESC]"
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.add_theme_font_override("font", FONT_MAIN)
	back_btn.add_theme_font_size_override("font_size", 12)
	back_btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	var btn_sb := StyleBoxTexture.new()
	btn_sb.texture = TEX_BROWN_BTN
	btn_sb.texture_margin_left = 10
	btn_sb.texture_margin_right = 10
	btn_sb.texture_margin_top = 6
	btn_sb.texture_margin_bottom = 6
	btn_sb.content_margin_left = 8
	btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 3
	btn_sb.content_margin_bottom = 3
	back_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_hover := btn_sb.duplicate()
	btn_hover.modulate_color = Color(1.16, 1.12, 1.04)
	back_btn.add_theme_stylebox_override("hover", btn_hover)
	back_btn.add_theme_stylebox_override("pressed", btn_sb)
	back_btn.pressed.connect(_on_return_pressed)
	hbox.add_child(back_btn)


func _on_return_pressed() -> void:
	var mp = get_node_or_null("/root/MultiplayerManager")
	if mp:
		mp.stop_spectating()


func _input(event: InputEvent) -> void:
	if not _is_spectating:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_return_pressed()
		get_viewport().set_input_as_handled()


func _on_spectate_changed(slot_id: String) -> void:
	var mp = get_node_or_null("/root/MultiplayerManager")
	var my_id: String = str(mp.my_slot_id) if mp else ""
	_spectate_slot_id = slot_id
	var should_spectate := (slot_id != "" and slot_id != my_id)

	if should_spectate != _is_spectating:
		_is_spectating = should_spectate
		_apply_spectate_visibility(_is_spectating)
		if _is_spectating:
			_interp_farmers.clear()
			_interp_drones.clear()
			_last_ground_sig = ""
			var cam := get_tree().root.find_child("GameCamera", true, false)
			if cam and cam.has_method("center_on_homestead"):
				cam.center_on_homestead()
	else:
		_last_ground_sig = ""

	visible = _is_spectating
	if _regional_map_holder:
		_regional_map_holder.process_mode = Node.PROCESS_MODE_INHERIT if _is_spectating else Node.PROCESS_MODE_DISABLED
	if _banner_layer:
		_banner_layer.visible = _is_spectating

	if _is_spectating and mp:
		var snap: Dictionary = mp.snapshots.get(_spectate_slot_id, {})
		var target_reg: String = str(snap.get("region", "cotabato"))
		_ensure_regional_map_loaded(target_reg)

	_refresh_targets()
	_queue_layer_redraws()


func _ensure_regional_map_loaded(target_reg: String) -> void:
	if target_reg.is_empty():
		target_reg = "cotabato"
	if _loaded_region_key == target_reg and _regional_map_node and is_instance_valid(_regional_map_node):
		return

	if _regional_map_node and is_instance_valid(_regional_map_node):
		_regional_map_holder.remove_child(_regional_map_node)
		_regional_map_node.queue_free()
		_regional_map_node = null

	_loaded_region_key = target_reg
	var data_mgr = get_node_or_null("/root/Data")
	var map_path: String = "res://scenes/maps/Map_Cotabato.tscn"
	if data_mgr and data_mgr.has_method("get_region_map_path"):
		map_path = str(data_mgr.get_region_map_path(target_reg))

	if ResourceLoader.exists(map_path):
		var map_scene: PackedScene = load(map_path) as PackedScene
		if map_scene:
			# Temporarily expose rival region to Data.current_region during _ready() so all regional water/terrain/streams initialize accurately
			var saved_reg: String = str(data_mgr.get("current_region")) if data_mgr else "cotabato"
			if data_mgr:
				data_mgr.set("current_region", target_reg)
			var inst: Node = map_scene.instantiate()
			if "region_key" in inst:
				inst.region_key = target_reg
			_regional_map_holder.add_child(inst)
			_regional_map_node = inst
			if data_mgr:
				data_mgr.set("current_region", saved_reg)


func _on_snapshots_updated() -> void:
	if not _is_spectating:
		return
	_refresh_targets()
	_queue_layer_redraws()


func _compute_ground_sig(snap: Dictionary) -> String:
	if snap.is_empty():
		return ""
	var reg := str(snap.get("region", "cotabato"))
	var parcels := ",".join(PackedStringArray(snap.get("unlocked_parcels", ["homestead"])))
	var tiles: Array = snap.get("tiles", [])
	var ground_sum: int = 0
	for r in tiles:
		if r is Array and r.size() >= 3:
			var st := int(r[2])
			# Only ground-layer visual state (EMPTY=0, PLOWED=1, FLOODED=6, OBSTACLE=7, BUILDING=8, LOCKED=9; crop states share tilled ground)
			var gst: int = st if st in [0, 1, 6, 7, 8, 9] else 2
			ground_sum = ground_sum * 31 + int(r[0]) * 97 + int(r[1]) * 13 + gst
	return "%s|%s|%d|%d" % [reg, parcels, tiles.size(), ground_sum]

func _queue_layer_redraws() -> void:
	var mp = get_node_or_null("/root/MultiplayerManager")
	var snap: Dictionary = mp.snapshots.get(_spectate_slot_id, {}) if mp else {}
	var gsig := _compute_ground_sig(snap)
	if _ground_layer and gsig != _last_ground_sig:
		_last_ground_sig = gsig
		_ground_layer.queue_redraw()
	if _objects_layer:
		_objects_layer.queue_redraw()


func _apply_spectate_visibility(active: bool) -> void:
	var fg := get_tree().root.find_child("FarmGrid", true, false)
	if fg:
		fg.visible = not active
		if "is_spectating" in fg:
			fg.is_spectating = active
	for f in get_tree().get_nodes_in_group("farmers"):
		if is_instance_valid(f):
			f.visible = not active
	var hm := get_tree().root.find_child("FarmHeatmapOverlay", true, false)
	if hm:
		hm.visible = not active


func _refresh_targets() -> void:
	if not _is_spectating:
		return
	var mp = get_node_or_null("/root/MultiplayerManager")
	if not mp:
		return
	var snap: Dictionary = mp.snapshots.get(_spectate_slot_id, {})
	if snap.is_empty():
		return

	var farmers_arr: Array = snap.get("farmers", [])
	var seen_keys: Dictionary = {}
	for i in range(farmers_arr.size()):
		var f: Dictionary = farmers_arr[i]
		var fkey := str(f.get("id", i + 1))
		seen_keys[fkey] = true
		var tgt := Vector2(float(f.get("x", 768.0)), float(f.get("y", 320.0)))
		if not _interp_farmers.has(fkey):
			_interp_farmers[fkey] = {
				"pos": tgt,
				"target": tgt,
				"anim": str(f.get("anim", "idle")),
				"frame": int(f.get("frame", 0)),
				"flip": bool(f.get("flip", false)),
				"name": str(f.get("name", "Worker %d" % (i + 1))),
			}
		else:
			var entry: Dictionary = _interp_farmers[fkey]
			entry["target"] = tgt
			entry["anim"] = str(f.get("anim", "idle"))
			entry["frame"] = int(f.get("frame", 0))
			entry["flip"] = bool(f.get("flip", false))
			entry["name"] = str(f.get("name", "Worker %d" % (i + 1)))

	for existing_key in _interp_farmers.keys():
		if not seen_keys.has(existing_key):
			_interp_farmers.erase(existing_key)

	var drones_arr: Array = snap.get("drones", [])
	var seen_drones: Dictionary = {}
	for i in range(drones_arr.size()):
		var d: Dictionary = drones_arr[i]
		var dkey := str(d.get("id", i + 1))
		seen_drones[dkey] = true
		var dtgt := Vector2(float(d.get("x", 768.0)), float(d.get("y", 260.0)))
		if not _interp_drones.has(dkey):
			_interp_drones[dkey] = {
				"pos": dtgt,
				"target": dtgt,
				"level": int(d.get("level", 1)),
				"active": bool(d.get("active", true))
			}
		else:
			var de: Dictionary = _interp_drones[dkey]
			de["target"] = dtgt
			de["level"] = int(d.get("level", 1))
			de["active"] = bool(d.get("active", true))

	for dk in _interp_drones.keys():
		if not seen_drones.has(dk):
			_interp_drones.erase(dk)


func _process(delta: float) -> void:
	if not _is_spectating:
		return
	_anim_clock += delta
	var lerp_w := minf(1.0, delta * 9.0)
	for fkey in _interp_farmers.keys():
		var entry: Dictionary = _interp_farmers[fkey]
		var cur: Vector2 = entry["pos"]
		var tgt: Vector2 = entry["target"]
		entry["pos"] = cur.lerp(tgt, lerp_w)
	for dkey in _interp_drones.keys():
		var dentry: Dictionary = _interp_drones[dkey]
		dentry["pos"] = (dentry["pos"] as Vector2).lerp(dentry["target"] as Vector2, lerp_w)
	_objects_redraw_accum += delta
	if _objects_redraw_accum >= SPECTATE_OBJECTS_INTERVAL and _objects_layer:
		_objects_redraw_accum = 0.0
		_objects_layer.queue_redraw()


func _get_farmer_frames(color_idx: int) -> Dictionary:
	if not _farmer_frames_cache.has(color_idx):
		_farmer_frames_cache[color_idx] = FARMER_SCRIPT.get_frames_for_variant(color_idx)
	return _farmer_frames_cache[color_idx]


func _get_crop_texture(crop_type: String, growth_prog: float, state: int) -> Texture2D:
	if crop_type == "":
		return null
	var stage: int = 1
	if crop_type == "banana":
		if state == 4 or growth_prog >= 1.0:
			stage = 4
		elif growth_prog >= 0.65:
			stage = 3
		elif growth_prog >= 0.25:
			stage = 2
		else:
			stage = 1
	else:
		if state == 4 or growth_prog >= 1.0:
			stage = 3
		elif growth_prog >= 0.30:
			stage = 2
		else:
			stage = 1
	if state == 5:
		stage = 5 if crop_type == "banana" else 4
	elif state == 6:
		stage = 6 if crop_type == "banana" else 5

	var key := "%s_%d" % [crop_type, stage]
	if not _crop_tex_cache.has(key):
		_crop_tex_cache[key] = _tile_renderer.get_crop_stage_texture(crop_type, stage) if _tile_renderer else null
	return _crop_tex_cache[key]


func _on_draw_ground() -> void:
	if not _is_spectating or _ground_layer == null:
		return
	var mp = get_node_or_null("/root/MultiplayerManager")
	if not mp:
		return
	var snap: Dictionary = mp.snapshots.get(_spectate_slot_id, {})
	if snap.is_empty():
		return

	var data_mgr = get_node_or_null("/root/Data")
	var rival_reg: String = str(snap.get("region", "cotabato"))
	var unlocked_list: Array = snap.get("unlocked_parcels", ["homestead"])

	var tile_map: Dictionary = {}
	for row in snap.get("tiles", []):
		if row is Array and row.size() >= 6:
			tile_map[Vector2i(int(row[0]), int(row[1]))] = row

	# Temporarily set current_region so GroundTileSprites.is_beach_tile() matches rival's region (e.g. Sarangani beach coast)
	var saved_reg: String = str(data_mgr.get("current_region")) if data_mgr else "cotabato"
	if data_mgr:
		data_mgr.set("current_region", rival_reg)

	if _scratch_tile == null:
		_scratch_tile = FARM_TILE_SCRIPT.new()
	var scratch_tile: Resource = _scratch_tile

	# Draw 32x32 island in strict isometric back-to-front order (x + y ascending)
	for diag in range(0, (GRID_SIZE - 1) * 2 + 1):
		var x_start := maxi(0, diag - (GRID_SIZE - 1))
		var x_end := mini(GRID_SIZE - 1, diag)
		for x in range(x_start, x_end + 1):
			var y := diag - x
			var gp := Vector2i(x, y)
			var is_unlocked := false
			if data_mgr and data_mgr.has_method("get_parcel_for_tile"):
				var parcel: Dictionary = data_mgr.get_parcel_for_tile(gp, rival_reg)
				if parcel.is_empty() or bool(parcel.get("unlocked_by_default", false)) or str(parcel.get("id", "")) in unlocked_list:
					is_unlocked = true
			else:
				is_unlocked = (x < 16 and y < 16)

			var tdata: Array = tile_map.get(gp, [])
			var st: int = int(tdata[2]) if not tdata.is_empty() else (0 if is_unlocked else 9)
			if not is_unlocked and tdata.is_empty():
				st = 9

			scratch_tile.state = st
			scratch_tile.crop_type = str(tdata[3]) if not tdata.is_empty() else ""
			scratch_tile.soil_moisture = 55.0

			var center: Vector2 = FARMER_MOVEMENT_SCRIPT.grid_to_pixel_center(gp, null)
			var tex: Texture2D = null
			if _ground_sprites_res and _ground_sprites_res.has_method("get_texture"):
				tex = _ground_sprites_res.get_texture(scratch_tile, gp)

			var tint := Color.WHITE
			if st == 9:
				if tex and "sand" in tex.resource_path.to_lower():
					tint = Color(0.85, 0.82, 0.74, 1.0)
				else:
					tint = Color(0.58, 0.66, 0.54, 1.0)
			elif st == 6:
				tint = Color(0.45, 0.68, 0.92, 0.95)
			elif st == 5:
				tint = Color(0.85, 0.45, 0.40, 1.0)

			if tex:
				# Match FarmGrid Sprite2D exact 4x scale (32x32 source -> 128x128 centered at tile center)
				var spr_sz: Vector2 = tex.get_size() * 4.0
				var off_y: float = -2.0 if ("bare" in tex.resource_path.to_lower()) else 0.0
				_ground_layer.draw_texture_rect(
					tex,
					Rect2(center.x - spr_sz.x * 0.5, center.y - spr_sz.y * 0.5 + off_y, spr_sz.x, spr_sz.y),
					false,
					tint
				)
			else:
				var pts: PackedVector2Array = FARMER_MOVEMENT_SCRIPT.get_tile_diamond_local(gp)
				var col := Color(0.28, 0.45, 0.24) if is_unlocked else Color(0.20, 0.30, 0.18)
				_ground_layer.draw_colored_polygon(pts, col)

			if is_unlocked and st != 8:
				var pts_b: PackedVector2Array = FARMER_MOVEMENT_SCRIPT.get_tile_diamond_local(gp)
				_ground_layer.draw_polyline(
					PackedVector2Array([pts_b[0], pts_b[1], pts_b[2], pts_b[3], pts_b[0]]),
					Color(0.18, 0.28, 0.14, 0.18),
					1.0
				)

	if data_mgr:
		data_mgr.set("current_region", saved_reg)


func _on_draw_objects() -> void:
	if not _is_spectating or _objects_layer == null:
		return
	var mp = get_node_or_null("/root/MultiplayerManager")
	if not mp:
		return
	var snap: Dictionary = mp.snapshots.get(_spectate_slot_id, {})
	if snap.is_empty():
		return

	var color_idx := posmod(int(snap.get("color_idx", 0)), mp.FARMER_COLORS.size())
	var fcolor: Color = mp.FARMER_COLORS[color_idx]

	var draw_items: Array = []

	for row in snap.get("tiles", []):
		if not (row is Array) or row.size() < 6:
			continue
		var gp := Vector2i(int(row[0]), int(row[1]))
		var st := int(row[2])
		var crop := str(row[3])
		var prog := float(row[4])
		var obs := str(row[5])
		var center: Vector2 = FARMER_MOVEMENT_SCRIPT.grid_to_pixel_center(gp, null)
		if st == 7 and obs != "":
			draw_items.append({"sort_y": center.y, "kind": "obstacle", "pos": center, "obs": obs})
		elif crop != "" and st in [2, 3, 4, 5, 6]:
			draw_items.append({"sort_y": center.y, "kind": "crop", "pos": center, "crop": crop, "prog": prog, "state": st})

	for b in snap.get("buildings", []):
		if not (b is Dictionary):
			continue
		var gx := int(b.get("gx", 0))
		var gy := int(b.get("gy", 0))
		var origin_c: Vector2 = FARMER_MOVEMENT_SCRIPT.grid_to_pixel_center(Vector2i(gx, gy), null)
		# Center 2x2 footprint visually in isometric world space (+32px Y down to midpoint of 2x2 diamond)
		var bpos := origin_c + Vector2(0.0, 32.0)
		draw_items.append({
			"sort_y": bpos.y + 8.0,
			"kind": "building",
			"pos": bpos,
			"btype": str(b.get("type", "bahay_kubo")),
			"lvl": int(b.get("lvl", 1))
		})

	for fkey in _interp_farmers.keys():
		var fe: Dictionary = _interp_farmers[fkey]
		var fpos: Vector2 = fe["pos"]
		draw_items.append({
			"sort_y": fpos.y + 6.0,
			"kind": "farmer",
			"pos": fpos,
			"anim": str(fe["anim"]),
			"frame": int(fe["frame"]),
			"flip": bool(fe["flip"]),
			"name": str(fe["name"]),
			"color_idx": color_idx,
			"fcolor": fcolor
		})

	draw_items.sort_custom(func(a, b): return float(a["sort_y"]) < float(b["sort_y"]))

	for item in draw_items:
		var kind := str(item["kind"])
		var pos: Vector2 = item["pos"]
		match kind:
			"obstacle":
				_objects_layer.draw_circle(pos + Vector2(0, -6), 14.0, Color(0.32, 0.34, 0.30, 0.85))
			"crop":
				var ctex := _get_crop_texture(str(item["crop"]), float(item["prog"]), int(item["state"]))
				if ctex:
					var w: float = float(ctex.get_width()) * 3.2
					var h: float = float(ctex.get_height()) * 3.2
					_objects_layer.draw_texture_rect(ctex, Rect2(pos.x - w * 0.5, pos.y - h + 14.0, w, h), false)
				else:
					_objects_layer.draw_circle(pos + Vector2(0, -8), 10.0, Color(0.45, 0.80, 0.35))
			"building":
				var btype := str(item["btype"])
				var btex: Texture2D = _building_tex_cache.get(btype, null)
				if btex:
					var bw := 124.0
					var bh := bw * (float(btex.get_height()) / maxf(1.0, float(btex.get_width())))
					_objects_layer.draw_texture_rect(btex, Rect2(pos.x - bw * 0.5, pos.y - bh + 28.0, bw, bh), false)
				else:
					_objects_layer.draw_rect(Rect2(pos.x - 28, pos.y - 44, 56, 44), Color(0.48, 0.35, 0.22))
			"farmer":
				var frames_dict := _get_farmer_frames(int(item["color_idx"]))
				var anim_name := str(item["anim"])
				var anim_arr: Array = frames_dict.get(anim_name, frames_dict.get("idle", []))
				if anim_arr.is_empty():
					anim_arr = frames_dict.get("idle", [])
				var fc: Color = item["fcolor"]
				_objects_layer.draw_circle(pos + Vector2(0, 4), 16.0, Color(fc.r, fc.g, fc.b, 0.32))
				_objects_layer.draw_arc(pos + Vector2(0, 4), 16.0, 0.0, TAU, 20, fc, 2.0)

				if not anim_arr.is_empty():
					var fidx := int(item["frame"])
					if anim_name in ["walk", "till", "harvest"]:
						fidx = (fidx + int(_anim_clock * 5.0)) % anim_arr.size()
					else:
						fidx = posmod(fidx, anim_arr.size())
					var ftex: Texture2D = anim_arr[fidx]
					if ftex:
						var fw := 64.0
						var fh := 64.0
						if bool(item["flip"]):
							_objects_layer.draw_texture_rect(ftex, Rect2(pos.x + fw * 0.5, pos.y - fh + 10.0, -fw, fh), false)
						else:
							_objects_layer.draw_texture_rect(ftex, Rect2(pos.x - fw * 0.5, pos.y - fh + 10.0, fw, fh), false)

				_objects_layer.draw_string(FONT_MAIN, pos + Vector2(-42, -58), str(item["name"]), HORIZONTAL_ALIGNMENT_CENTER, 84.0, 11, Color(1.0, 0.96, 0.85))

	# Draw hovering Agricultural Drones cleanly above crops/farmers
	for dkey in _interp_drones.keys():
		var d: Dictionary = _interp_drones[dkey]
		var dpos: Vector2 = d["pos"]
		var bob_y: float = sin(_anim_clock * 4.5 + float(dkey.hash() % 7)) * 4.0
		var body_pos := dpos + Vector2(0.0, -34.0 + bob_y)
		# Ground shadow
		_objects_layer.draw_circle(dpos + Vector2(0, 2), 9.0, Color(0.0, 0.0, 0.0, 0.25))
		# Quadcopter arms & rotors
		var rotor_r: float = 5.5 if int(int(_anim_clock * 20.0) % 2) == 0 else 3.5
		for off in [Vector2(-10, -5), Vector2(10, -5), Vector2(-10, 5), Vector2(10, 5)]:
			_objects_layer.draw_line(body_pos, body_pos + off, Color(0.22, 0.26, 0.30), 2.0)
			_objects_layer.draw_circle(body_pos + off, rotor_r, Color(0.55, 0.90, 1.0, 0.65))
		# Core fuselage tinted with team/player color
		_objects_layer.draw_rect(Rect2(body_pos.x - 6, body_pos.y - 4, 12, 8), fcolor)
		_objects_layer.draw_rect(Rect2(body_pos.x - 4, body_pos.y - 2, 8, 4), Color(0.90, 0.98, 1.0))
