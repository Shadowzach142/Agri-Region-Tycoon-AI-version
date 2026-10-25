# OutOfBoundsDirtTrail.gd
# Renders the authentic natural dirt perimeter path bordering the forest tree line
# (inspired by the Clash of Clans village perimeter trail).

class_name OutOfBoundsDirtTrail
extends Node2D

func _init() -> void:
	z_index = -5
	z_as_relative = false

func _draw() -> void:
	# Calculate trail paths along the 3 land borders:
	# 1. North-West: (0, 0) to (0, 24)
	# 2. North-East: (0, 0) to (24, 0)
	# 3. South-West: (0, 24) to (24, 24)

	var get_pt = func(gx: float, gy: float) -> Vector2:
		return Vector2(
			FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
			FarmerMovement.ORIGIN_OFFSET.y + (gx + gy + 1.0) * FarmerMovement.HALF_H
		)

	# 1. NW Trail
	var nw_points: PackedVector2Array = []
	for i in range(-2, 51):
		var t: float = float(i) * 0.5
		var base: Vector2 = get_pt.call(-0.5, t)
		# subtle natural waviness
		var wobble: float = sin(t * 1.8) * 2.5
		nw_points.append(base + Vector2(-wobble, wobble * 0.5))

	# 2. NE Trail
	var ne_points: PackedVector2Array = []
	for i in range(-2, 51):
		var t: float = float(i) * 0.5
		var base: Vector2 = get_pt.call(t, -0.5)
		var wobble: float = cos(t * 1.8) * 2.5
		ne_points.append(base + Vector2(wobble, wobble * 0.5))

	# 3. SW Trail
	var sw_points: PackedVector2Array = []
	for i in range(-2, 51):
		var t: float = float(i) * 0.5
		var base: Vector2 = get_pt.call(t, 24.5)
		var wobble: float = sin(t * 1.8 + 1.0) * 2.5
		sw_points.append(base + Vector2(wobble, wobble * 0.5))

	# Layered rendering:
	# Outer earthy blend -> packed soil base -> worn center path
	var col_earth := Color(0.26, 0.32, 0.18, 0.70)
	var col_dirt := Color(0.50, 0.40, 0.26, 0.85)
	var col_worn := Color(0.64, 0.53, 0.35, 0.90)

	for pts in [nw_points, ne_points, sw_points]:
		if pts.size() >= 2:
			draw_polyline(pts, col_earth, 28.0, false)
			draw_polyline(pts, col_dirt, 16.0, false)
			draw_polyline(pts, col_worn, 8.0, false)

	# Subtle pebble & dirt flecks along the paths
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765
	var col_pebble := Color(0.72, 0.62, 0.45, 0.8)
	var col_dark_pebble := Color(0.38, 0.28, 0.18, 0.7)

	for pts in [nw_points, ne_points, sw_points]:
		for p in pts:
			if rng.randf() < 0.35:
				var off := Vector2(rng.randf_range(-8, 8), rng.randf_range(-4, 4))
				var p_col: Color = col_pebble if rng.randf() > 0.4 else col_dark_pebble
				draw_circle(p + off, rng.randf_range(1.2, 2.5), p_col)
