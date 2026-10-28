# Map_SultanKudarat.gd
# Sultan Kudarat Valley — Tacurong Corridor & Isulan Agricultural Heartland
# Environmental identity:
#   - Vast open golden-amber agricultural prairie stretching to the horizon
#   - Straight irrigation canal network feeding the valley's sugarcane & corn fields
#   - Wide leveled agricultural highway embankments (granary road network)
#   - Buluan Lake wetlands on the eastern border with calm silt-tinted water & bamboo traps
#   - Open sky with warm golden light — a sense of breadth and agricultural scale
#   - Sultan Muhammad Dipatuan Kudarat on an imperial golden Capitol marble dais

class_name MapSultanKudarat
extends "res://src/world/RegionalMapBase.gd"

const _AMB_LAYER_Z: int = -7

func _init() -> void:
	super()
	region_key = "sultan_kudarat"
	# Imperial golden Capitol marble with gilded ceremonial borders
	plaza_pavement_color = Color(0.56, 0.48, 0.30, 0.95)
	plaza_border_color = Color(0.90, 0.75, 0.28, 0.92)

func _build_regional_content() -> void:
	_build_granary_valley_environment()

	# Grand Sultan Muhammad Dipatuan Kudarat Monument
	add_monument(
		Vector2(-2.5, 4.5),
		"sultan_kudarat_statue",
		"Sultan Muhammad Dipatuan Kudarat Monument",
		"Provincial Capitol Hero Landmark • Isulan, Sultan Kudarat",
		"Monument to the 17th-century Sultan of Maguindanao, a fearless warrior, statesman, and hero who defended Mindanao's sovereignty and unified the diverse peoples of Central Mindanao.",
		"res://assets/sprites/monuments/Sultan_Kudarat_Monument.png",
		"res://assets/sprites/monuments/Sultan_Kudarat_Monument_FLIPPED.png",
		false,
		Vector2(1.8, 1.8),
		Vector2(56.0, 28.0)
	)

## Draw agricultural valley landscape: open fields, irrigation canals, granary roads, lake shore
func _build_granary_valley_environment() -> void:
	var env := Node2D.new()
	env.name = "GranaryValleyEnv"
	env.z_index = _AMB_LAYER_Z
	env.z_as_relative = false

	# === FULL PERIMETER GROUND TINTING ===
	# NW quadrant — golden-amber savanna loam
	var nw_ground := Polygon2D.new()
	nw_ground.color = Color(0.52, 0.42, 0.20, 0.60)
	nw_ground.polygon = PackedVector2Array([
		get_pt(-9.0, -9.0), get_pt(-0.5, -9.0),
		get_pt(-0.5, 42.0), get_pt(-9.0, 42.0)
	])
	env.add_child(nw_ground)

	# SW band (below farm) — dry harvest stubble plains
	var sw_ground := Polygon2D.new()
	sw_ground.color = Color(0.50, 0.40, 0.18, 0.58)
	sw_ground.polygon = PackedVector2Array([
		get_pt(-0.5, 32.0), get_pt(32.0, 32.0),
		get_pt(32.0, 42.0), get_pt(-0.5, 42.0)
	])
	env.add_child(sw_ground)

	# === NORTH — Corn & Sugarcane Cultivation Plateau ===
	# Vast cultivated plateau above the farm — crop field geometry
	var n_plateau := Polygon2D.new()
	n_plateau.color = Color(0.54, 0.44, 0.22, 0.65)
	n_plateau.polygon = PackedVector2Array([
		get_pt(-0.5, -9.0), get_pt(32.0, -9.0),
		get_pt(32.0, -0.5), get_pt(-0.5, -0.5)
	])
	env.add_child(n_plateau)

	# Agricultural row-crop furrows running across the north plateau
	for furrow_x in range(0, 30, 4):
		var furrow := Line2D.new()
		furrow.width = 2.0
		furrow.default_color = Color(0.36, 0.28, 0.12, 0.55)
		furrow.add_point(get_pt(float(furrow_x), -9.0))
		furrow.add_point(get_pt(float(furrow_x), -0.5))
		env.add_child(furrow)

	# Irrigation spur off the north canal into fields above
	var n_spur := Line2D.new()
	n_spur.width = 7.0
	n_spur.default_color = Color(0.20, 0.36, 0.38, 0.80)
	n_spur.add_point(get_pt(8.0, -0.5))
	n_spur.add_point(get_pt(8.0, -4.0))
	n_spur.add_point(get_pt(20.0, -4.0))
	n_spur.add_point(get_pt(20.0, -9.0))
	env.add_child(n_spur)

	# Harvest windrows — golden straw rows drying in sun above farm
	for windrow_x in range(2, 28, 6):
		var windrow := Polygon2D.new()
		windrow.color = Color(0.72, 0.60, 0.28, 0.45)
		windrow.polygon = PackedVector2Array([
			get_pt(float(windrow_x), -8.0), get_pt(float(windrow_x) + 3.5, -8.0),
			get_pt(float(windrow_x) + 3.5, -6.5), get_pt(float(windrow_x), -6.5)
		])
		env.add_child(windrow)

	# === WEST — Barangay Farm Road (spine of the valley settlements) ===
	# Packed earth barangay road runs south down the western margin
	var w_road := Polygon2D.new()
	w_road.color = Color(0.44, 0.34, 0.16, 0.80)
	w_road.polygon = PackedVector2Array([
		get_pt(-4.0, 0.0), get_pt(-1.5, 0.0),
		get_pt(-1.5, 32.0), get_pt(-4.0, 32.0)
	])
	env.add_child(w_road)

	# Road wheel ruts (deep compacted tracks from agricultural vehicles)
	var rut_a := Line2D.new()
	rut_a.width = 2.0
	rut_a.default_color = Color(0.32, 0.24, 0.10, 0.60)
	for ry in range(0, 32):
		rut_a.add_point(get_pt(-3.2, float(ry)))
	env.add_child(rut_a)
	var rut_b := Line2D.new()
	rut_b.width = 2.0
	rut_b.default_color = Color(0.32, 0.24, 0.10, 0.60)
	for ry in range(0, 32):
		rut_b.add_point(get_pt(-2.3, float(ry)))
	env.add_child(rut_b)

	# Roadside grass verge (thin strip of surviving green beside the road)
	var verge := Polygon2D.new()
	verge.color = Color(0.38, 0.42, 0.20, 0.50)
	verge.polygon = PackedVector2Array([
		get_pt(-5.5, 0.0), get_pt(-4.2, 0.0),
		get_pt(-4.2, 32.0), get_pt(-5.5, 32.0)
	])
	env.add_child(verge)

	# === SOUTH — Post-Harvest Plain ===
	# Wide open post-harvest plain below the farm — burnt stubble and loose soil
	var s_plain := Polygon2D.new()
	s_plain.color = Color(0.48, 0.38, 0.18, 0.62)
	s_plain.polygon = PackedVector2Array([
		get_pt(2.0, 33.0), get_pt(28.0, 33.0),
		get_pt(28.0, 42.0), get_pt(2.0, 42.0)
	])
	env.add_child(s_plain)

	# Burn scar patches (dark scorched earth from sugarcane harvesting fires)
	var burn_patches: Array[Vector2] = [
		Vector2(5.0, 35.0), Vector2(14.0, 37.0), Vector2(22.0, 34.5), Vector2(9.0, 40.0)
	]
	for bp in burn_patches:
		var burn := Polygon2D.new()
		burn.color = Color(0.20, 0.16, 0.10, 0.70)
		burn.polygon = PackedVector2Array([
			get_pt(bp.x - 2.5, bp.y), get_pt(bp.x, bp.y - 1.0),
			get_pt(bp.x + 2.5, bp.y), get_pt(bp.x, bp.y + 1.0)
		])
		env.add_child(burn)

	# Irrigation tail-end channels (small distribution channels into the southern plain)
	for tc_x in [4.0, 12.0, 20.0]:
		var tail := Line2D.new()
		tail.width = 5.0
		tail.default_color = Color(0.20, 0.36, 0.38, 0.70)
		tail.add_point(get_pt(tc_x, 32.0))
		tail.add_point(get_pt(tc_x + 0.5, 37.0))
		tail.add_point(get_pt(tc_x - 0.5, 42.0))
		env.add_child(tail)

	# --- 1. Open Granary Prairie ---
	var prairie := Polygon2D.new()
	prairie.color = Color(0.55, 0.46, 0.25, 0.45)
	prairie.polygon = PackedVector2Array([
		get_pt(-9.0, -9.0), get_pt(0.0, -9.0),
		get_pt(0.0, 42.0), get_pt(-9.0, 42.0)
	])
	env.add_child(prairie)

	# SE prairie (wide open sky feel below the farm)
	var prairie_se := Polygon2D.new()
	prairie_se.color = Color(0.52, 0.44, 0.22, 0.40)
	prairie_se.polygon = PackedVector2Array([
		get_pt(0.0, 33.0), get_pt(30.0, 33.0),
		get_pt(30.0, 42.0), get_pt(0.0, 42.0)
	])
	env.add_child(prairie_se)

	# --- 2. Agricultural Irrigation Canals ---
	# North canal
	var canal_n := Line2D.new()
	canal_n.width = 10.0
	canal_n.default_color = Color(0.20, 0.36, 0.38, 0.88)
	for x in range(-9, 32):
		canal_n.add_point(get_pt(float(x), -2.5))
	env.add_child(canal_n)
	var canal_n_edge := Line2D.new()
	canal_n_edge.width = 14.0
	canal_n_edge.default_color = Color(0.38, 0.30, 0.18, 0.75)
	for x in range(-9, 32):
		canal_n_edge.add_point(get_pt(float(x), -2.5))
	env.add_child(canal_n_edge)

	# South canal
	var canal_s := Line2D.new()
	canal_s.width = 10.0
	canal_s.default_color = Color(0.20, 0.36, 0.38, 0.88)
	for x in range(-9, 32):
		canal_s.add_point(get_pt(float(x), 33.5))
	env.add_child(canal_s)

	# West canal (NW border vertical)
	var canal_w := Line2D.new()
	canal_w.width = 8.0
	canal_w.default_color = Color(0.20, 0.36, 0.38, 0.85)
	for y in range(-9, 33):
		canal_w.add_point(get_pt(-2.5, float(y)))
	env.add_child(canal_w)

	# --- 3. Agricultural Highway Road ---
	var hwy := Polygon2D.new()
	hwy.color = Color(0.48, 0.38, 0.22, 0.88)
	hwy.polygon = PackedVector2Array([
		get_pt(-4.0, -4.0), get_pt(-2.5, -4.0),
		get_pt(30.0, 5.0), get_pt(30.0, 7.0),
	])
	env.add_child(hwy)

	# Road center line
	var hwy_center := Line2D.new()
	hwy_center.width = 3.0
	hwy_center.default_color = Color(0.70, 0.58, 0.36, 0.70)
	hwy_center.add_point(get_pt(-4.0, -4.0))
	hwy_center.add_point(get_pt(-3.0, -3.8))
	hwy_center.add_point(get_pt(30.0, 6.0))
	env.add_child(hwy_center)

	# --- 4. Buluan Lake Wetland Shore — expanded to cover gx 24..32 fully ---
	# Wide wetland transition zone from agricultural fields to Buluan Lake
	var wetland_base := Polygon2D.new()
	wetland_base.color = Color(0.20, 0.26, 0.18, 0.80)
	wetland_base.polygon = PackedVector2Array([
		get_pt(24.0, -0.5), get_pt(32.0, -0.5),
		get_pt(32.0, 32.5), get_pt(24.0, 32.5)
	])
	env.add_child(wetland_base)

	# Marsh shore — darker silt-rich sediment layer
	var marsh_shore := Polygon2D.new()
	marsh_shore.color = Color(0.22, 0.28, 0.18, 0.88)
	marsh_shore.polygon = PackedVector2Array([
		get_pt(26.5, -0.5), get_pt(32.0, -0.5),
		get_pt(32.0, 32.5), get_pt(26.5, 32.5)
	])
	env.add_child(marsh_shore)

	# Marshy reed-bed fringe (dense silty waterline, gx 29..32)
	var reed_bed := Polygon2D.new()
	reed_bed.color = Color(0.16, 0.24, 0.16, 0.88)
	reed_bed.polygon = PackedVector2Array([
		get_pt(29.0, 0.0), get_pt(32.0, 0.0),
		get_pt(32.0, 32.0), get_pt(29.0, 32.0)
	])
	env.add_child(reed_bed)

	# Waterline mud (dark anaerobic mud right at the lake margin, gx 31..32)
	var waterline_mud := Polygon2D.new()
	waterline_mud.color = Color(0.12, 0.18, 0.12, 0.92)
	waterline_mud.polygon = PackedVector2Array([
		get_pt(31.0, 0.0), get_pt(32.0, 0.0),
		get_pt(32.0, 32.0), get_pt(31.0, 32.0)
	])
	env.add_child(waterline_mud)

	# Reed stem lines (thin marks of emergent wetland grass)
	for ry in range(0, 32, 2):
		var reed := Line2D.new()
		reed.width = 2.0
		reed.default_color = Color(0.26, 0.36, 0.22, 0.65)
		reed.add_point(get_pt(29.5 + sin(float(ry) * 1.3) * 1.5, float(ry)))
		reed.add_point(get_pt(30.0 + cos(float(ry) * 0.9) * 1.0, float(ry) + 0.8))
		env.add_child(reed)

	# Bamboo baklad fish traps (diagonal stake clusters in the shallow water zone)
	for trap_y in range(3, 30, 7):
		var trap := Line2D.new()
		trap.width = 3.0
		trap.default_color = Color(0.38, 0.28, 0.16, 0.80)
		trap.add_point(get_pt(30.8, float(trap_y)))
		trap.add_point(get_pt(31.5, float(trap_y) + 1.0))
		trap.add_point(get_pt(31.8, float(trap_y) + 2.0))
		env.add_child(trap)
		var trap_cross := Line2D.new()
		trap_cross.width = 2.5
		trap_cross.default_color = Color(0.38, 0.28, 0.16, 0.75)
		trap_cross.add_point(get_pt(31.5, float(trap_y)))
		trap_cross.add_point(get_pt(30.8, float(trap_y) + 1.5))
		env.add_child(trap_cross)

	# --- 5. Golden Sky Glow ---
	var sky := Polygon2D.new()
	sky.color = Color(0.96, 0.90, 0.65, 0.15)
	sky.polygon = PackedVector2Array([
		get_pt(0.0, -9.0), get_pt(34.0, -9.0),
		get_pt(34.0, -0.5), get_pt(0.0, -0.5)
	])
	env.add_child(sky)

	# --- 6. Dried Grass Stubble Lines ---
	for strip_y in range(33, 42, 2):
		var stubble := Polygon2D.new()
		stubble.color = Color(0.60, 0.50, 0.28, 0.30)
		stubble.polygon = PackedVector2Array([
			get_pt(0.0, float(strip_y)),
			get_pt(28.0, float(strip_y)),
			get_pt(28.0, float(strip_y) + 0.6),
			get_pt(0.0, float(strip_y) + 0.6)
		])
		env.add_child(stubble)

	add_child(env)
