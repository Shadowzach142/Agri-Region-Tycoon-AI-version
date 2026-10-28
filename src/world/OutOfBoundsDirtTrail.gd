# OutOfBoundsDirtTrail.gd
# Renders the authentic perimeter trail bordering the farm island and tree line.
# Dynamically adapts to provide unique pathway materials, textures, and styling for all 5 regions:
#   - Cotabato: Damp alluvial river towpath with rich mud and puddle reflections
#   - South Cotabato: Crushed volcanic slate & mountain rock trail with sharp basalt pavers
#   - Sarangani: Coastal sandy dune trail with sun-bleached beach sand and shell flecks
#   - Sultan Kudarat: Broad packed-earth agricultural granary highway with wagon ruts
#   - General Santos: Paved stone promenade & seawall walkway with dressed granite pavers

class_name OutOfBoundsDirtTrail
extends Node2D

@export var region_key: String = ""

func _init() -> void:
	z_index = -5
	z_as_relative = false

func _resolve_region() -> String:
	if region_key != "":
		return region_key
	var data_node = get_tree().root.get_node_or_null("Data") if is_inside_tree() else null
	if data_node and "current_region" in data_node:
		region_key = data_node.current_region
	else:
		region_key = "cotabato"
	return region_key

func _get_iso_pt(gx: float, gy: float) -> Vector2:
	return Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (gx + gy + 1.0) * FarmerMovement.HALF_H
	)

func _draw() -> void:
	var reg := _resolve_region()

	# 1. North-West Trail: (0, 0) to (0, 32)
	var nw_points: PackedVector2Array = []
	for i in range(-2, 67):
		var t: float = float(i) * 0.5
		var base: Vector2 = _get_iso_pt(-0.5, t)
		var wobble: float = sin(t * 1.8) * 2.5
		nw_points.append(base + Vector2(-wobble, wobble * 0.5))

	# 2. North-East Trail: (0, 0) to (32, 0)
	var ne_points: PackedVector2Array = []
	for i in range(-2, 67):
		var t: float = float(i) * 0.5
		var base: Vector2 = _get_iso_pt(t, -0.5)
		var wobble: float = cos(t * 1.8) * 2.5
		ne_points.append(base + Vector2(wobble, wobble * 0.5))

	# 3. South-West Trail: (0, 32) to (32, 32)
	var sw_points: PackedVector2Array = []
	for i in range(-2, 67):
		var t: float = float(i) * 0.5
		var base: Vector2 = _get_iso_pt(t, 32.5)
		var wobble: float = sin(t * 1.8 + 1.0) * 2.5
		sw_points.append(base + Vector2(wobble, wobble * 0.5))

	# Regional Pathway Material Colors
	var col_outer: Color
	var col_mid: Color
	var col_center: Color
	var col_fleck_1: Color
	var col_fleck_2: Color
	var trail_width: float = 28.0

	match reg:
		"cotabato":
			# Damp alluvial river towpath: Dark fertile mud & river silt
			col_outer = Color(0.18, 0.24, 0.16, 0.75)
			col_mid = Color(0.34, 0.26, 0.18, 0.88)
			col_center = Color(0.48, 0.38, 0.24, 0.90)
			col_fleck_1 = Color(0.24, 0.18, 0.12, 0.85) # Wet mud clumps
			col_fleck_2 = Color(0.60, 0.50, 0.35, 0.70) # Silt patches
			trail_width = 30.0

		"south_cotabato":
			# Crushed mountain volcanic slate trail: Dark basalt stones & slate gravel
			col_outer = Color(0.18, 0.26, 0.20, 0.70)
			col_mid = Color(0.26, 0.28, 0.30, 0.90)
			col_center = Color(0.38, 0.42, 0.46, 0.92)
			col_fleck_1 = Color(0.16, 0.18, 0.20, 0.85) # Dark basalt flakes
			col_fleck_2 = Color(0.55, 0.60, 0.65, 0.75) # Grey slate stone chips
			trail_width = 26.0

		"sarangani":
			# Coastal sandy dune trail: Sun-bleached beach sand & shell flecks
			col_outer = Color(0.36, 0.38, 0.24, 0.65)
			col_mid = Color(0.78, 0.70, 0.52, 0.90)
			col_center = Color(0.88, 0.82, 0.66, 0.92)
			col_fleck_1 = Color(0.96, 0.94, 0.88, 0.85) # White seashell flecks
			col_fleck_2 = Color(0.65, 0.56, 0.40, 0.70) # Damp sand clumps
			trail_width = 28.0

		"sultan_kudarat":
			# Wide agricultural granary highway: Compacted golden clay & wagon ruts
			col_outer = Color(0.32, 0.30, 0.18, 0.70)
			col_mid = Color(0.54, 0.42, 0.24, 0.90)
			col_center = Color(0.68, 0.56, 0.34, 0.92)
			col_fleck_1 = Color(0.82, 0.72, 0.35, 0.80) # Golden straw flecks
			col_fleck_2 = Color(0.40, 0.28, 0.15, 0.80) # Dark furrow dirt
			trail_width = 34.0

		"general_santos":
			# Paved stone promenade & seawall walkway: Dressed granite pavers
			col_outer = Color(0.24, 0.26, 0.28, 0.75)
			col_mid = Color(0.40, 0.42, 0.45, 0.92)
			col_center = Color(0.54, 0.56, 0.60, 0.95)
			col_fleck_1 = Color(0.28, 0.30, 0.32, 0.85) # Stone paver seams
			col_fleck_2 = Color(0.70, 0.72, 0.75, 0.75) # Polished granite chips
			trail_width = 28.0

		_:
			col_outer = Color(0.26, 0.32, 0.18, 0.70)
			col_mid = Color(0.50, 0.40, 0.26, 0.85)
			col_center = Color(0.64, 0.53, 0.35, 0.90)
			col_fleck_1 = Color(0.72, 0.62, 0.45, 0.80)
			col_fleck_2 = Color(0.38, 0.28, 0.18, 0.70)

	# Draw layered pathways
	for pts in [nw_points, ne_points, sw_points]:
		if pts.size() >= 2:
			draw_polyline(pts, col_outer, trail_width, false)
			draw_polyline(pts, col_mid, trail_width * 0.58, false)
			draw_polyline(pts, col_center, trail_width * 0.28, false)

	# If GenSan: draw neat stone curb lines along the promenade edges
	if reg == "general_santos":
		for pts in [nw_points, ne_points, sw_points]:
			if pts.size() >= 2:
				draw_polyline(pts, Color(0.30, 0.32, 0.34, 0.80), 2.0, false)

	# Natural pebble, shell, or dirt flecks along the paths
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765

	for pts in [nw_points, ne_points, sw_points]:
		for p in pts:
			if rng.randf() < 0.40:
				var off := Vector2(rng.randf_range(-10, 10), rng.randf_range(-5, 5))
				var p_col: Color = col_fleck_1 if rng.randf() > 0.45 else col_fleck_2
				var sz: float = rng.randf_range(1.4, 2.8)
				draw_circle(p + off, sz, p_col)
