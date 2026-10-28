# Map_Cotabato.gd
# Cotabato Basin — Central Floodplains & Rio Grande de Mindanao
# Environmental identity:
#   - Rich emerald-green alluvial floodplain extending west to the horizon
#   - Winding Pulangi River canal on eastern border (animated freshwater current)
#   - Natural river levee embankment separating farm from waterway
#   - Muddy alluvial silt banks with standing floodwater reflections
#   - Bangka ng Kapayapaan monument on a smoothed river-stone terrace
#   - Low-lying delta wetland feeling: flooded ground, dark rich soil, paddy field memory

class_name MapCotabato
extends "res://src/world/RegionalMapBase.gd"

const _AMB_LAYER_Z: int = -7 # Between terrain (-8) and trail (-5)

func _init() -> void:
	super()
	region_key = "cotabato"
	# River-smoothed cobblestone & dark alluvial silt
	plaza_pavement_color = Color(0.28, 0.26, 0.21, 0.95)
	plaza_border_color = Color(0.44, 0.38, 0.28, 0.85)

func _build_regional_content() -> void:
	_build_floodplain_environment()

	# Bangka ng Kapayapaan Monument (River Peace Landmark)
	add_monument(
		Vector2(-2.5, 4.5),
		"bangkapayapaan",
		"Bangka ng Kapayapaan Monument",
		"Historical River Peace Landmark • Cotabato Basin",
		"A sculpted traditional river boat symbolizing unity, peace, and resilience among the Bangsamoro, Indigenous, and Settler communities along the Rio Grande de Mindanao.",
		"res://assets/sprites/monuments/bangkapayapaan_monument.png",
		"res://assets/sprites/monuments/bangkapayapaan_monument_FLIPPED.png",
		false,
		Vector2(1.8, 1.8),
		Vector2(62.0, 31.0)
	)

## Draw the alluvial floodplain landscape: river levee embankment, paddy strips, mud banks
func _build_floodplain_environment() -> void:
	var env := Node2D.new()
	env.name = "FloodplainEnv"
	env.z_index = _AMB_LAYER_Z
	env.z_as_relative = false
	env.set_script(null) # plain Node2D, use child Polygon2D nodes

	# === FULL PERIMETER GROUND TINTING ===
	# NW quadrant — deep alluvial green-brown floodplain loam
	var nw_ground := Polygon2D.new()
	nw_ground.color = Color(0.18, 0.24, 0.14, 0.60)
	nw_ground.polygon = PackedVector2Array([
		get_pt(-9.0, -9.0), get_pt(-0.5, -9.0),
		get_pt(-0.5, 42.0), get_pt(-9.0, 42.0)
	])
	env.add_child(nw_ground)

	# NE band (above the farm) — overcast floodplain sky reflection
	var ne_ground := Polygon2D.new()
	ne_ground.color = Color(0.16, 0.26, 0.16, 0.55)
	ne_ground.polygon = PackedVector2Array([
		get_pt(-0.5, -9.0), get_pt(32.0, -9.0),
		get_pt(32.0, -0.5), get_pt(-0.5, -0.5)
	])
	env.add_child(ne_ground)

	# SW band (below the farm) — waterlogged lowland, darker silt-rich
	var sw_ground := Polygon2D.new()
	sw_ground.color = Color(0.14, 0.22, 0.13, 0.58)
	sw_ground.polygon = PackedVector2Array([
		get_pt(-0.5, 32.0), get_pt(32.0, 32.0),
		get_pt(32.0, 42.0), get_pt(-0.5, 42.0)
	])
	env.add_child(sw_ground)

	# === NORTH TERRAIN DETAILS ===
	# Flooded paddy terraces above farm — waterlogged bunds visible
	for bx in range(0, 32, 6):
		var n_bund := Polygon2D.new()
		n_bund.color = Color(0.20, 0.32, 0.18, 0.50)
		n_bund.polygon = PackedVector2Array([
			get_pt(float(bx), -9.0), get_pt(float(bx) + 4.5, -9.0),
			get_pt(float(bx) + 4.5, -0.5), get_pt(float(bx), -0.5)
		])
		env.add_child(n_bund)
		var n_water := Polygon2D.new()
		n_water.color = Color(0.12, 0.30, 0.38, 0.38)
		n_water.polygon = PackedVector2Array([
			get_pt(float(bx) + 0.6, -8.0), get_pt(float(bx) + 3.8, -8.0),
			get_pt(float(bx) + 3.8, -1.2), get_pt(float(bx) + 0.6, -1.2)
		])
		env.add_child(n_water)

	# Pulangi river oxbow on NE corner (river curves around the northern headland)
	var oxbow := Polygon2D.new()
	oxbow.color = Color(0.16, 0.38, 0.44, 0.60)
	oxbow.polygon = PackedVector2Array([
		get_pt(20.0, -9.0), get_pt(32.0, -9.0),
		get_pt(32.0, -2.0), get_pt(20.0, -2.0)
	])
	env.add_child(oxbow)

	# Oxbow silt bank
	var oxbow_silt := Polygon2D.new()
	oxbow_silt.color = Color(0.30, 0.24, 0.16, 0.70)
	oxbow_silt.polygon = PackedVector2Array([
		get_pt(20.0, -2.0), get_pt(32.0, -2.0),
		get_pt(32.0, -0.8), get_pt(20.0, -0.8)
	])
	env.add_child(oxbow_silt)

	# === WEST TERRAIN DETAILS ===
	# Meander bends of feeder streams cutting through NW forest
	for meander_y in range(0, 30, 8):
		var meander := Line2D.new()
		meander.width = 6.0
		meander.default_color = Color(0.14, 0.32, 0.40, 0.65)
		meander.add_point(get_pt(-9.0, float(meander_y)))
		meander.add_point(get_pt(-6.5, float(meander_y) + 1.5))
		meander.add_point(get_pt(-4.5, float(meander_y) + 1.0))
		meander.add_point(get_pt(-2.0, float(meander_y) + 2.5))
		meander.add_point(get_pt(-0.8, float(meander_y) + 2.0))
		env.add_child(meander)
		# Mud bank edge
		var mud_edge := Line2D.new()
		mud_edge.width = 10.0
		mud_edge.default_color = Color(0.26, 0.20, 0.14, 0.45)
		mud_edge.add_point(get_pt(-9.0, float(meander_y)))
		mud_edge.add_point(get_pt(-6.5, float(meander_y) + 1.5))
		mud_edge.add_point(get_pt(-4.5, float(meander_y) + 1.0))
		mud_edge.add_point(get_pt(-2.0, float(meander_y) + 2.5))
		mud_edge.add_point(get_pt(-0.8, float(meander_y) + 2.0))
		env.add_child(mud_edge)

	# === SOUTH TERRAIN DETAILS ===
	# Expansive rice plain below farm — wide flat lowland paddy stretching south
	var s_paddy := Polygon2D.new()
	s_paddy.color = Color(0.16, 0.28, 0.16, 0.55)
	s_paddy.polygon = PackedVector2Array([
		get_pt(2.0, 33.0), get_pt(26.0, 33.0),
		get_pt(26.0, 42.0), get_pt(2.0, 42.0)
	])
	env.add_child(s_paddy)

	# Flooded paddy bunds south — running across the bottom
	for sy in range(33, 42, 2):
		var s_bund := Line2D.new()
		s_bund.width = 3.0
		s_bund.default_color = Color(0.24, 0.18, 0.12, 0.55)
		s_bund.add_point(get_pt(2.0, float(sy)))
		s_bund.add_point(get_pt(26.0, float(sy)))
		env.add_child(s_bund)

	# Waterway cuts south (Pulangi distributaries)
	for river_x in [5.0, 13.0, 21.0]:
		var dist := Line2D.new()
		dist.width = 8.0
		dist.default_color = Color(0.14, 0.34, 0.42, 0.60)
		dist.add_point(get_pt(river_x, 32.0))
		dist.add_point(get_pt(river_x + 1.0, 36.0))
		dist.add_point(get_pt(river_x + 0.5, 42.0))
		env.add_child(dist)

	# --- 1. River Levee Embankment — wide dark berm from gx 26 to 32 ---
	# Now extends from gx=26 all the way to the water at gx=32
	var levee_base := Polygon2D.new()
	levee_base.color = Color(0.16, 0.20, 0.12, 0.80)
	levee_base.polygon = PackedVector2Array([
		get_pt(26.0, -1.0), get_pt(32.0, -1.0),
		get_pt(32.0, 33.0), get_pt(26.0, 33.0)
	])
	env.add_child(levee_base)

	# Inner levee face (dark wet soil of the raised bund)
	var levee := Polygon2D.new()
	levee.color = Color(0.22, 0.18, 0.13, 0.92)
	levee.polygon = PackedVector2Array([
		get_pt(28.0, -1.0), get_pt(30.5, -1.0),
		get_pt(30.5, 33.0), get_pt(28.0, 33.0)
	])
	env.add_child(levee)

	# Muddy silt crest of levee
	var silt := Polygon2D.new()
	silt.color = Color(0.34, 0.26, 0.17, 0.88)
	silt.polygon = PackedVector2Array([
		get_pt(28.5, -0.5), get_pt(30.0, -0.5),
		get_pt(30.0, 32.5), get_pt(28.5, 32.5)
	])
	env.add_child(silt)

	# Waterline silt (dark wet mud right at the river's edge, gx 30.5-32)
	var waterline := Polygon2D.new()
	waterline.color = Color(0.14, 0.18, 0.14, 0.92)
	waterline.polygon = PackedVector2Array([
		get_pt(30.5, -0.5), get_pt(32.0, -0.5),
		get_pt(32.0, 32.5), get_pt(30.5, 32.5)
	])
	env.add_child(waterline)

	# Exposed mud-bank streaks (organic river silt lines on the levee face)
	for streak_y in range(0, 32, 5):
		var streak := Line2D.new()
		streak.width = 4.0
		streak.default_color = Color(0.28, 0.22, 0.14, 0.70)
		streak.add_point(get_pt(29.0, float(streak_y)))
		streak.add_point(get_pt(31.5, float(streak_y) + 1.5))
		streak.add_point(get_pt(31.8, float(streak_y) + 2.5))
		env.add_child(streak)

	# Mooring stake posts driven into the levee bank
	for post_y in range(2, 30, 6):
		var stake := Polygon2D.new()
		stake.color = Color(0.30, 0.22, 0.14, 0.90)
		stake.polygon = PackedVector2Array([
			get_pt(31.4, float(post_y) - 0.1),
			get_pt(31.6, float(post_y) - 0.1),
			get_pt(31.6, float(post_y) + 0.1),
			get_pt(31.4, float(post_y) + 0.1)
		])
		env.add_child(stake)

	# --- 2. Paddy Field Memory on eastern terrain ---
	for strip_y in range(0, 32, 4):
		var bund := Polygon2D.new()
		bund.color = Color(0.20, 0.28, 0.18, 0.35)
		bund.polygon = PackedVector2Array([
			get_pt(0.0, float(strip_y)),
			get_pt(28.5, float(strip_y)),
			get_pt(28.5, float(strip_y) + 0.4),
			get_pt(0.0, float(strip_y) + 0.4)
		])
		env.add_child(bund)

	# --- 3. Floodwater Puddle Reflections ---
	var puddle_positions: Array[Vector2] = [
		Vector2(8.0, 25.0), Vector2(14.0, 28.0), Vector2(5.0, 30.0), Vector2(20.0, 31.0),
		Vector2(-3.0, 8.0), Vector2(-5.0, 16.0), Vector2(-2.0, 22.0),
		Vector2(10.0, 36.0), Vector2(18.0, 38.0), Vector2(4.0, 39.0)
	]
	for pp in puddle_positions:
		var puddle := Polygon2D.new()
		puddle.color = Color(0.14, 0.35, 0.42, 0.55)
		puddle.polygon = PackedVector2Array([
			get_pt(pp.x - 1.0, pp.y), get_pt(pp.x, pp.y - 0.4),
			get_pt(pp.x + 1.0, pp.y), get_pt(pp.x, pp.y + 0.4)
		])
		env.add_child(puddle)

	# --- 4. Dark Alluvial Soil Band (deeper NW) ---
	var dark_soil := Polygon2D.new()
	dark_soil.color = Color(0.16, 0.22, 0.14, 0.45)
	dark_soil.polygon = PackedVector2Array([
		get_pt(-9.0, 20.0), get_pt(-0.5, 20.0),
		get_pt(-0.5, 40.0), get_pt(-9.0, 40.0)
	])
	env.add_child(dark_soil)

	# --- 5. River Mist ---
	var mist := Polygon2D.new()
	mist.color = Color(0.75, 0.88, 0.85, 0.18)
	mist.polygon = PackedVector2Array([
		get_pt(27.0, -2.0), get_pt(32.0, -2.0),
		get_pt(32.0, 34.0), get_pt(27.0, 34.0)
	])
	env.add_child(mist)

	# Wide river mist also rising from north oxbow
	var n_mist := Polygon2D.new()
	n_mist.color = Color(0.72, 0.85, 0.82, 0.14)
	n_mist.polygon = PackedVector2Array([
		get_pt(18.0, -9.0), get_pt(32.0, -9.0),
		get_pt(32.0, -0.5), get_pt(18.0, -0.5)
	])
	env.add_child(n_mist)

	add_child(env)
