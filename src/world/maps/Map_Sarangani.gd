# Map_Sarangani.gd
# Sarangani Littoral Coast — Tropical Beach & Coral Shelf
# Environmental identity:
#   - Golden sandy beach on the eastern side of the farm (transitions from grass to sand to sea)
#   - Turquoise shallow coral reef shelf visible at the shoreline
#   - Coconut frond shadows and warm sun-bleached sand dune patches
#   - Clear open sky feel — very bright, high-contrast tropical coastal atmosphere
#   - Ayub Cave archaeological site feeling: ancient, sacred, sunbaked limestone
#   - Maitum Anthropomorphic Jars Monument on coral limestone sanctuary terrace

class_name MapSarangani
extends "res://src/world/RegionalMapBase.gd"

const _AMB_LAYER_Z: int = -7

func _init() -> void:
	super()
	region_key = "sarangani"
	# Sun-bleached coral limestone and coastal sandstone
	plaza_pavement_color = Color(0.72, 0.68, 0.58, 0.95)
	plaza_border_color = Color(0.88, 0.82, 0.66, 0.88)

func _build_regional_content() -> void:
	_build_coastal_environment()

	# Maitum Anthropomorphic Jars Replicas Monument
	add_monument(
		Vector2(-2.5, 4.5),
		"maitum_jars",
		"Maitum Anthropomorphic Jars Replicas",
		"National Cultural Treasure • Sarangani Littoral Coast",
		"Replicas of the 2,000-year-old anthropomorphic earthenware burial vessels discovered in Ayub Cave, Maitum, Sarangani — declared National Cultural Treasures of the Philippines.",
		"res://assets/sprites/monuments/maitum_anthropomorphic_replicas.png",
		"res://assets/sprites/monuments/maitum_anthropomorphic_replicas_FLIPPED.png",
		false,
		Vector2(1.8, 1.8),
		Vector2(62.0, 31.0)
	)

## Draw coastal beach environment: sand dunes, coral shelf, beach grass, tidal marks
func _build_coastal_environment() -> void:
	var env := Node2D.new()
	env.name = "CoastalEnv"
	env.z_index = _AMB_LAYER_Z
	env.z_as_relative = false

	# === FULL PERIMETER GROUND TINTING ===
	# NW quadrant — warm sun-bleached sandy scrub
	var nw_ground := Polygon2D.new()
	nw_ground.color = Color(0.64, 0.58, 0.40, 0.58)
	nw_ground.polygon = PackedVector2Array([
		get_pt(-9.0, -9.0), get_pt(-0.5, -9.0),
		get_pt(-0.5, 42.0), get_pt(-9.0, 42.0)
	])
	env.add_child(nw_ground)

	# SW band (below farm) — golden coastal savanna
	var sw_ground := Polygon2D.new()
	sw_ground.color = Color(0.62, 0.56, 0.38, 0.55)
	sw_ground.polygon = PackedVector2Array([
		get_pt(-0.5, 32.0), get_pt(32.0, 32.0),
		get_pt(32.0, 42.0), get_pt(-0.5, 42.0)
	])
	env.add_child(sw_ground)

	# === NORTH — Limestone Headland & Reef Flat ===
	# Ancient exposed limestone karst above the farm — Ayub Cave coastal cliff feeling
	var n_limestone := Polygon2D.new()
	n_limestone.color = Color(0.78, 0.72, 0.58, 0.80)
	n_limestone.polygon = PackedVector2Array([
		get_pt(-0.5, -9.0), get_pt(32.0, -9.0),
		get_pt(32.0, -0.5), get_pt(-0.5, -0.5)
	])
	env.add_child(n_limestone)

	# Limestone karst surface cracks — horizontal fissure lines
	for fissure_x in range(0, 28, 5):
		var fissure := Line2D.new()
		fissure.width = 2.0
		fissure.default_color = Color(0.55, 0.48, 0.34, 0.65)
		fissure.add_point(get_pt(float(fissure_x), -8.0))
		fissure.add_point(get_pt(float(fissure_x) + 3.5, -5.5))
		fissure.add_point(get_pt(float(fissure_x) + 2.0, -2.0))
		fissure.add_point(get_pt(float(fissure_x) + 4.5, -0.8))
		env.add_child(fissure)

	# Reef flat pool at NE — shallow turquoise trapped water in limestone
	var reef_pool := Polygon2D.new()
	reef_pool.color = Color(0.24, 0.68, 0.72, 0.50)
	reef_pool.polygon = PackedVector2Array([
		get_pt(22.0, -8.5), get_pt(32.0, -8.5),
		get_pt(32.0, -1.0), get_pt(22.0, -1.0)
	])
	env.add_child(reef_pool)

	# Reef pool edge — bleached bone-white coral rim
	var reef_rim := Line2D.new()
	reef_rim.width = 4.0
	reef_rim.default_color = Color(0.92, 0.90, 0.82, 0.75)
	reef_rim.add_point(get_pt(22.0, -1.0))
	reef_rim.add_point(get_pt(32.0, -1.0))
	env.add_child(reef_rim)

	# === WEST — Scrub Coastal Vegetation Line ===
	# Low thorn scrub and salt-tolerant brush along the western cliffs
	var w_scrub := Polygon2D.new()
	w_scrub.color = Color(0.50, 0.46, 0.28, 0.55)
	w_scrub.polygon = PackedVector2Array([
		get_pt(-8.5, 0.0), get_pt(-0.5, 0.0),
		get_pt(-0.5, 32.0), get_pt(-8.5, 32.0)
	])
	env.add_child(w_scrub)

	# Coastal scrub patches — sun-scorched amber spots
	for scrub_y in range(2, 30, 5):
		var scrub := Polygon2D.new()
		scrub.color = Color(0.42, 0.36, 0.20, 0.55)
		scrub.polygon = PackedVector2Array([
			get_pt(-7.0 + sin(float(scrub_y)) * 1.5, float(scrub_y)),
			get_pt(-4.5 + sin(float(scrub_y)) * 1.0, float(scrub_y) - 0.8),
			get_pt(-2.0, float(scrub_y) + 0.3),
			get_pt(-4.0 + cos(float(scrub_y)) * 1.2, float(scrub_y) + 1.2)
		])
		env.add_child(scrub)

	# Dry limestone cliff face (western wall)
	var cliff := Polygon2D.new()
	cliff.color = Color(0.70, 0.64, 0.50, 0.60)
	cliff.polygon = PackedVector2Array([
		get_pt(-8.0, 0.0), get_pt(-5.5, 0.0),
		get_pt(-5.5, 32.0), get_pt(-8.0, 32.0)
	])
	env.add_child(cliff)

	# === SOUTH — Sandy Cove & Beach Continuation ===
	# Wide beach curving around the southern cove
	var s_beach := Polygon2D.new()
	s_beach.color = Color(0.86, 0.80, 0.62, 0.88)
	s_beach.polygon = PackedVector2Array([
		get_pt(2.0, 33.0), get_pt(30.0, 33.0),
		get_pt(30.0, 42.0), get_pt(2.0, 42.0)
	])
	env.add_child(s_beach)

	# Dry dune crest (lighter sand piled south of farm)
	var s_dune := Polygon2D.new()
	s_dune.color = Color(0.96, 0.92, 0.76, 0.75)
	s_dune.polygon = PackedVector2Array([
		get_pt(8.0, 33.5), get_pt(24.0, 33.5),
		get_pt(26.0, 37.0), get_pt(6.0, 37.0)
	])
	env.add_child(s_dune)

	# Tidal wash lines on south beach (undulating water marks)
	for wash_y in range(34, 41, 2):
		var wash := Line2D.new()
		wash.width = 2.0
		wash.default_color = Color(0.74, 0.66, 0.50, 0.55)
		for wx in range(2, 30, 2):
			wash.add_point(get_pt(float(wx), float(wash_y) + sin(float(wx) * 0.7) * 0.5))
		env.add_child(wash)

	# Cove rock outcrops (dark exposed limestone boulders at low tide)
	var cove_rocks: Array[Vector2] = [
		Vector2(4.0, 36.5), Vector2(11.0, 38.5), Vector2(22.0, 37.0), Vector2(27.0, 34.5)
	]
	for cr in cove_rocks:
		var rock := Polygon2D.new()
		rock.color = Color(0.50, 0.44, 0.34, 0.88)
		rock.polygon = PackedVector2Array([
			get_pt(cr.x - 1.2, cr.y), get_pt(cr.x, cr.y - 0.6),
			get_pt(cr.x + 1.2, cr.y), get_pt(cr.x, cr.y + 0.4)
		])
		env.add_child(rock)

	# --- 1. Wide Sandy Beach Strip (gx 24..31) ---
	var beach_deep := Polygon2D.new()
	beach_deep.color = Color(0.88, 0.82, 0.64, 0.90)
	beach_deep.polygon = PackedVector2Array([
		get_pt(24.0, -1.0), get_pt(32.0, -1.0),
		get_pt(32.0, 33.0), get_pt(24.0, 33.0)
	])
	env.add_child(beach_deep)

	# Bright dry sand top (dune crest strip)
	var dune_top := Polygon2D.new()
	dune_top.color = Color(0.96, 0.92, 0.78, 0.85)
	dune_top.polygon = PackedVector2Array([
		get_pt(26.5, -0.5), get_pt(30.0, -0.5),
		get_pt(30.0, 32.5), get_pt(26.5, 32.5)
	])
	env.add_child(dune_top)

	# Wet tidal sand (darker, closer to waterline)
	var wet_sand := Polygon2D.new()
	wet_sand.color = Color(0.70, 0.64, 0.50, 0.90)
	wet_sand.polygon = PackedVector2Array([
		get_pt(29.5, -0.5), get_pt(32.0, -0.5),
		get_pt(32.0, 32.5), get_pt(29.5, 32.5)
	])
	env.add_child(wet_sand)

	# --- 2. Coral Reef Shelf ---
	var reef := Polygon2D.new()
	reef.color = Color(0.20, 0.68, 0.75, 0.40)
	reef.polygon = PackedVector2Array([
		get_pt(30.5, 0.0), get_pt(32.0, 0.0),
		get_pt(32.0, 32.0), get_pt(30.5, 32.0)
	])
	env.add_child(reef)

	# --- 3. Beach Dune Undulation ---
	for ridge_y in range(0, 32, 6):
		var ridge := Line2D.new()
		ridge.width = 3.0
		ridge.default_color = Color(0.94, 0.90, 0.76, 0.55)
		ridge.add_point(get_pt(24.5, float(ridge_y)))
		ridge.add_point(get_pt(28.0, float(ridge_y) + 2.0))
		ridge.add_point(get_pt(30.0, float(ridge_y) + 1.5))
		env.add_child(ridge)

	# --- 4. Tidal High-Water Mark Line ---
	var tide_line := Line2D.new()
	tide_line.width = 2.0
	tide_line.default_color = Color(0.75, 0.68, 0.50, 0.70)
	for y in range(-1, 34):
		tide_line.add_point(get_pt(28.5 + sin(float(y) * 0.8) * 0.4, float(y)))
	env.add_child(tide_line)

	# --- 5. Bright Open Sky NE Horizon ---
	var sky_glow := Polygon2D.new()
	sky_glow.color = Color(1.04, 1.02, 0.92, 0.22)
	sky_glow.polygon = PackedVector2Array([
		get_pt(0.0, -9.0), get_pt(42.0, -9.0),
		get_pt(42.0, -0.5), get_pt(0.0, -0.5)
	])
	env.add_child(sky_glow)

	# --- 6. SW terrain — sun-scorched dry grass patches ---
	var dry_grass := Polygon2D.new()
	dry_grass.color = Color(0.50, 0.42, 0.22, 0.35)
	dry_grass.polygon = PackedVector2Array([
		get_pt(-9.0, 20.0), get_pt(-0.5, 20.0),
		get_pt(-0.5, 42.0), get_pt(-9.0, 42.0)
	])
	env.add_child(dry_grass)

	add_child(env)
