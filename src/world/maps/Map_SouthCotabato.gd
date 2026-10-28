# Map_SouthCotabato.gd
# South Cotabato Highlands — Mount Matutum Volcanic Plateau & Lake Sebu
# Environmental identity:
#   - Dark volcanic basalt stone ground in the plaza and surrounding highland terrain
#   - Crystal-blue alpine crater lake on the eastern boundary (Lake Sebu / Lake Holon)
#   - Dramatic volcanic rock outcroppings in the out-of-bounds highland terrain
#   - Mountain mist haze rising from the lake surface toward the highland forests
#   - Cool rocky shoreline with mossy volcanic boulders
#   - Surallah Tri-People Monument + T'boli K'noon on elevated volcanic basalt terrace

class_name MapSouthCotabato
extends "res://src/world/RegionalMapBase.gd"

const _AMB_LAYER_Z: int = -7

func _init() -> void:
	super()
	region_key = "south_cotabato"
	# Dark volcanic basalt slate with antique bronze T'boli accents
	plaza_pavement_color = Color(0.20, 0.22, 0.22, 0.95)
	plaza_border_color = Color(0.58, 0.44, 0.22, 0.88)

func _build_regional_content() -> void:
	_build_highland_environment()

	# 1. Primary Monument: Surallah Cultural Tri-People Monument
	add_monument(
		Vector2(-2.8, 3.2),
		"surallah_tri_people",
		"Surallah Cultural Tri-People Monument",
		"Cultural Heritage Landmark • South Cotabato",
		"Towering cultural masterpiece by Kublai Millan celebrating the harmonious brotherhood of Christian Settlers, Indigenous T'boli & Bla-an, and Muslim Maguindanaon under Mount Matutum.",
		"res://assets/sprites/monuments/surallah_tri_people_monument.png",
		"res://assets/sprites/monuments/surallah_tri_people_monument_FLIPPED.png",
		false,
		Vector2(1.7, 1.7),
		Vector2(70.0, 35.0)
	)

	# 2. Secondary Monument: T'boli K'noon Cultural Landmark
	add_monument(
		Vector2(-2.2, 7.8),
		"tboli_knoon",
		"T'boli K'noon Cultural Landmark",
		"Indigenous Heritage • Lake Sebu / T'boli",
		"Dedicated to the heritage of the Lake Sebu Dreamweavers and the indigenous sacred crafts and brassware of the T'boli people.",
		"res://assets/sprites/monuments/T_boli_Knoon_Monument.png",
		"res://assets/sprites/monuments/T_boli_Knoon_Monument_FLIPPED.png",
		false,
		Vector2(1.7, 1.7),
		Vector2(48.0, 24.0)
	)

## Draw highland volcanic environment: rocky outcroppings, lake shoreline, mountain mist
func _build_highland_environment() -> void:
	var env := Node2D.new()
	env.name = "HighlandEnv"
	env.z_index = _AMB_LAYER_Z
	env.z_as_relative = false

	# === FULL PERIMETER GROUND TINTING ===
	# NW quadrant — dark cool alpine forest floor
	var nw_ground := Polygon2D.new()
	nw_ground.color = Color(0.12, 0.18, 0.17, 0.65)
	nw_ground.polygon = PackedVector2Array([
		get_pt(-9.0, -9.0), get_pt(-0.5, -9.0),
		get_pt(-0.5, 42.0), get_pt(-9.0, 42.0)
	])
	env.add_child(nw_ground)

	# SW band (below farm) — mossy dark volcanic floor
	var sw_ground := Polygon2D.new()
	sw_ground.color = Color(0.11, 0.17, 0.16, 0.62)
	sw_ground.polygon = PackedVector2Array([
		get_pt(-0.5, 32.0), get_pt(32.0, 32.0),
		get_pt(32.0, 42.0), get_pt(-0.5, 42.0)
	])
	env.add_child(sw_ground)

	# === NORTH — Volcanic Plateau Rim ===
	# Dark basalt plateau stretching above the farm — Mount Matutum's foothills
	var n_plateau := Polygon2D.new()
	n_plateau.color = Color(0.13, 0.15, 0.18, 0.75)
	n_plateau.polygon = PackedVector2Array([
		get_pt(-0.5, -9.0), get_pt(32.0, -9.0),
		get_pt(32.0, -0.5), get_pt(-0.5, -0.5)
	])
	env.add_child(n_plateau)

	# Volcanic ridge crack lines across the north plateau
	for ridge_x in range(0, 28, 7):
		var crack := Line2D.new()
		crack.width = 3.0
		crack.default_color = Color(0.08, 0.10, 0.13, 0.70)
		crack.add_point(get_pt(float(ridge_x), -9.0))
		crack.add_point(get_pt(float(ridge_x) + 2.0, -5.0))
		crack.add_point(get_pt(float(ridge_x) + 1.0, -1.5))
		crack.add_point(get_pt(float(ridge_x) + 3.0, -0.5))
		env.add_child(crack)

	# Cooling lava vent discoloration patches — dark orange-brown staining
	for vent_x in [4.0, 12.0, 22.0]:
		var vent := Polygon2D.new()
		vent.color = Color(0.28, 0.18, 0.10, 0.55)
		vent.polygon = PackedVector2Array([
			get_pt(vent_x - 1.5, -8.0), get_pt(vent_x + 1.5, -8.0),
			get_pt(vent_x + 2.0, -3.0), get_pt(vent_x - 2.0, -3.0)
		])
		env.add_child(vent)

	# === WEST — Volcanic Cliff Face ===
	# Exposed basalt cliff on the western border
	var w_cliff := Polygon2D.new()
	w_cliff.color = Color(0.14, 0.16, 0.20, 0.80)
	w_cliff.polygon = PackedVector2Array([
		get_pt(-8.5, -0.5), get_pt(-0.5, -0.5),
		get_pt(-0.5, 32.0), get_pt(-8.5, 32.0)
	])
	env.add_child(w_cliff)

	# Cliff strata lines — horizontal sedimentary layers on the cliff face
	for strata_y in range(2, 30, 5):
		var strata := Line2D.new()
		strata.width = 2.5
		strata.default_color = Color(0.28, 0.32, 0.36, 0.55)
		strata.add_point(get_pt(-8.0, float(strata_y)))
		strata.add_point(get_pt(-0.8, float(strata_y)))
		env.add_child(strata)

	# Cliff face highlight (lighter basalt exposed face)
	var cliff_face := Polygon2D.new()
	cliff_face.color = Color(0.22, 0.26, 0.30, 0.50)
	cliff_face.polygon = PackedVector2Array([
		get_pt(-3.5, 0.0), get_pt(-0.5, 0.0),
		get_pt(-0.5, 32.0), get_pt(-3.5, 32.0)
	])
	env.add_child(cliff_face)

	# === SOUTH — Mossy Highland Bog ===
	# Waterlogged mossy bog below the farm, cool and dark
	var s_bog := Polygon2D.new()
	s_bog.color = Color(0.10, 0.18, 0.14, 0.65)
	s_bog.polygon = PackedVector2Array([
		get_pt(2.0, 33.0), get_pt(28.0, 33.0),
		get_pt(28.0, 42.0), get_pt(2.0, 42.0)
	])
	env.add_child(s_bog)

	# Bog water pools (dark standing water between moss mats)
	var bog_pools: Array[Vector2] = [
		Vector2(5.0, 35.0), Vector2(12.0, 37.0), Vector2(20.0, 34.5), Vector2(8.0, 39.5)
	]
	for bp in bog_pools:
		var pool := Polygon2D.new()
		pool.color = Color(0.10, 0.22, 0.28, 0.65)
		pool.polygon = PackedVector2Array([
			get_pt(bp.x - 1.5, bp.y), get_pt(bp.x, bp.y - 0.5),
			get_pt(bp.x + 1.5, bp.y), get_pt(bp.x, bp.y + 0.5)
		])
		env.add_child(pool)

	# Bog reed lines (dark thin vertical strokes)
	for reed_x in range(3, 27, 3):
		var reed := Line2D.new()
		reed.width = 1.5
		reed.default_color = Color(0.14, 0.22, 0.16, 0.50)
		reed.add_point(get_pt(float(reed_x), 33.5))
		reed.add_point(get_pt(float(reed_x) + 0.5, 41.5))
		env.add_child(reed)

	# --- 1. Volcanic Stone Ground Band (NE plateau) ---
	var lava_base := Polygon2D.new()
	lava_base.color = Color(0.16, 0.18, 0.20, 0.80)
	lava_base.polygon = PackedVector2Array([
		get_pt(-9.0, -9.0), get_pt(32.0, -9.0),
		get_pt(32.0, -0.5), get_pt(-9.0, -0.5)
	])
	env.add_child(lava_base)

	# --- 2. Volcanic Basalt Rocky Outcroppings ---
	var rock_patches: Array[Array] = [
		[Vector2(-3.5, 12.0), 1.5, 0.7],
		[Vector2(-5.0, 24.0), 2.0, 0.8],
		[Vector2(-7.0, 5.0), 1.8, 0.7],
		[Vector2(15.0, -4.5), 2.5, 0.9],
		[Vector2(25.0, -5.0), 2.0, 0.8],
		[Vector2(8.0, 33.5), 2.2, 0.85],
		[Vector2(22.0, 34.0), 1.8, 0.75],
		[Vector2(-6.0, 35.0), 2.0, 0.78],
		[Vector2(-4.0, 40.0), 1.6, 0.72],
		[Vector2(3.0, -6.5), 1.8, 0.80],
	]
	for patch in rock_patches:
		var center: Vector2 = patch[0]
		var rx: float = patch[1]
		var ry_scale: float = patch[2]
		var rock := Polygon2D.new()
		rock.color = Color(0.18, 0.20, 0.24, 0.90)
		rock.polygon = PackedVector2Array([
			get_pt(center.x - rx, center.y),
			get_pt(center.x - rx * 0.5, center.y - rx * ry_scale * 0.5),
			get_pt(center.x, center.y - rx * ry_scale),
			get_pt(center.x + rx * 0.5, center.y - rx * ry_scale * 0.4),
			get_pt(center.x + rx, center.y),
			get_pt(center.x + rx * 0.4, center.y + rx * ry_scale * 0.35),
			get_pt(center.x - rx * 0.4, center.y + rx * ry_scale * 0.3),
		])
		env.add_child(rock)
		var rock_hi := Polygon2D.new()
		rock_hi.color = Color(0.34, 0.38, 0.42, 0.65)
		rock_hi.polygon = PackedVector2Array([
			get_pt(center.x - rx * 0.6, center.y - rx * ry_scale * 0.2),
			get_pt(center.x, center.y - rx * ry_scale * 0.9),
			get_pt(center.x + rx * 0.4, center.y - rx * ry_scale * 0.3),
			get_pt(center.x, center.y + rx * ry_scale * 0.1),
		])
		env.add_child(rock_hi)

	# --- 3. Lake Sebu Rocky Shoreline — expanded to cover gx 25..32 fully ---
	# Wide rocky transition from highland turf to alpine crater lake
	var shore_base := Polygon2D.new()
	shore_base.color = Color(0.16, 0.20, 0.22, 0.88)
	shore_base.polygon = PackedVector2Array([
		get_pt(25.0, -1.0), get_pt(32.0, -1.0),
		get_pt(32.0, 33.0), get_pt(25.0, 33.0)
	])
	env.add_child(shore_base)

	# Rocky shoreline rubble (broken lava rocks on the lake margin)
	var shore_rubble := Polygon2D.new()
	shore_rubble.color = Color(0.24, 0.28, 0.32, 0.85)
	shore_rubble.polygon = PackedVector2Array([
		get_pt(27.0, -0.5), get_pt(32.0, -0.5),
		get_pt(32.0, 32.5), get_pt(27.0, 32.5)
	])
	env.add_child(shore_rubble)

	# Dark wet stone immediately at the waterline (gx 30..32)
	var wet_stone := Polygon2D.new()
	wet_stone.color = Color(0.14, 0.17, 0.22, 0.92)
	wet_stone.polygon = PackedVector2Array([
		get_pt(30.0, -0.5), get_pt(32.0, -0.5),
		get_pt(32.0, 32.5), get_pt(30.0, 32.5)
	])
	env.add_child(wet_stone)

	# Boulder scatter across the shore (irregular volcanic rock shapes)
	var boulder_pts: Array[Array] = [
		[Vector2(26.5, 4.0), 1.2],  [Vector2(28.0, 9.0), 0.9],
		[Vector2(27.5, 15.0), 1.4], [Vector2(29.0, 21.0), 1.0],
		[Vector2(26.8, 27.0), 1.3], [Vector2(28.5, 2.0), 0.8],
		[Vector2(30.5, 6.0), 0.7],  [Vector2(31.0, 18.0), 0.6],
	]
	for bpt in boulder_pts:
		var bc: Vector2 = bpt[0]
		var br: float = bpt[1]
		var b := Polygon2D.new()
		b.color = Color(0.20, 0.23, 0.28, 0.90)
		b.polygon = PackedVector2Array([
			get_pt(bc.x - br, bc.y),
			get_pt(bc.x - br * 0.4, bc.y - br * 0.7),
			get_pt(bc.x + br * 0.5, bc.y - br * 0.6),
			get_pt(bc.x + br, bc.y + br * 0.2),
			get_pt(bc.x + br * 0.2, bc.y + br * 0.5),
			get_pt(bc.x - br * 0.5, bc.y + br * 0.3),
		])
		env.add_child(b)
		# Basalt highlight on boulders
		var bh := Polygon2D.new()
		bh.color = Color(0.38, 0.42, 0.48, 0.60)
		bh.polygon = PackedVector2Array([
			get_pt(bc.x - br * 0.3, bc.y - br * 0.5),
			get_pt(bc.x + br * 0.4, bc.y - br * 0.4),
			get_pt(bc.x + br * 0.2, bc.y),
			get_pt(bc.x - br * 0.2, bc.y - br * 0.1),
		])
		env.add_child(bh)

	# Algae-tinted waterline fringe (green moss on wet rocks closest to water)
	var algae := Polygon2D.new()
	algae.color = Color(0.16, 0.28, 0.22, 0.55)
	algae.polygon = PackedVector2Array([
		get_pt(30.8, 0.0), get_pt(32.0, 0.0),
		get_pt(32.0, 32.0), get_pt(30.8, 32.0)
	])
	env.add_child(algae)

	# --- 4. Mountain Mist ---
	var mist_low := Polygon2D.new()
	mist_low.color = Color(0.72, 0.82, 0.88, 0.22)
	mist_low.polygon = PackedVector2Array([
		get_pt(24.0, -1.0), get_pt(32.0, -1.0),
		get_pt(32.0, 33.0), get_pt(24.0, 33.0)
	])
	env.add_child(mist_low)

	# High mountain mist on north plateau
	var n_mist := Polygon2D.new()
	n_mist.color = Color(0.68, 0.78, 0.86, 0.18)
	n_mist.polygon = PackedVector2Array([
		get_pt(0.0, -9.0), get_pt(32.0, -9.0),
		get_pt(32.0, -0.5), get_pt(0.0, -0.5)
	])
	env.add_child(n_mist)

	# --- 5. Deep volcanic moss carpet (SW terrain) ---
	var moss := Polygon2D.new()
	moss.color = Color(0.12, 0.22, 0.15, 0.50)
	moss.polygon = PackedVector2Array([
		get_pt(-9.0, 15.0), get_pt(-0.5, 15.0),
		get_pt(-0.5, 42.0), get_pt(-9.0, 42.0)
	])
	env.add_child(moss)

	add_child(env)
