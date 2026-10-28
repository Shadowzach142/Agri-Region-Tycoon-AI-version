# OutOfBoundsFogOfWar.gd
# Renders atmospheric Fog of War and perimeter mist surrounding the out-of-bounds forest.
# Smoothly dissolves outer canopy layers into a moody, deep wilderness fog,
# completely concealing sprite edges and creating an authentic Clash of Clans frontier feel.

class_name OutOfBoundsFogOfWar
extends Node2D

const FOG_COLOR: Color = Color(0.06, 0.11, 0.07) # Deep dark jungle fog
const MIST_COLOR: Color = Color(0.25, 0.38, 0.28, 0.22) # Soft drifting canopy mist

var _time: float = 0.0
var _mist_particles: Array[Dictionary] = []

func _init() -> void:
	z_index = 22
	z_as_relative = false

func _ready() -> void:
	name = "OutOfBoundsFogOfWar"
	_init_mist_particles()

func _init_mist_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321
	
	# Spawn 24 gentle drifting mist wisps along the forest perimeter
	for i in range(24):
		var side: int = i % 3 # 0: NW, 1: NE, 2: SW
		var gx: float = 0.0
		var gy: float = 0.0
		var t: float = rng.randf_range(-1.0, 33.0)
		
		if side == 0: # NW border
			gx = rng.randf_range(-5.5, -2.5)
			gy = t
		elif side == 1: # NE border
			gx = t
			gy = rng.randf_range(-5.5, -2.5)
		else: # SW border
			gx = t
			gy = 32.0 + rng.randf_range(2.5, 5.5)
			
		var pos_px: Vector2 = Vector2(
			FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
			FarmerMovement.ORIGIN_OFFSET.y + (gx + gy + 1.0) * FarmerMovement.HALF_H
		)
		
		_mist_particles.append({
			"base_pos": pos_px,
			"radius": rng.randf_range(70.0, 130.0),
			"speed": rng.randf_range(0.3, 0.7),
			"phase": rng.randf_range(0.0, TAU),
			"alpha_mult": rng.randf_range(0.6, 1.0)
		})

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var get_pt := func(gx: float, gy: float) -> Vector2:
		return Vector2(
			FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
			FarmerMovement.ORIGIN_OFFSET.y + (gx + gy + 1.0) * FarmerMovement.HALF_H
		)

	# -----------------------------------------------------------------------
	# 1. Concentric Isometric Gradient Rings for Landward Borders (NW, NE, SW)
	# -----------------------------------------------------------------------
	# We draw smooth multi-band gradient quads around the perimeter:
	# Bands:
	#   Band 0: margin 1.0 tiles out (alpha = 0.0) -> margin 3.2 tiles out (alpha = 0.35)
	#   Band 1: margin 3.2 tiles out (alpha = 0.35) -> margin 5.5 tiles out (alpha = 0.75)
	#   Band 2: margin 5.5 tiles out (alpha = 0.75) -> margin 8.5 tiles out (alpha = 0.96)
	#   Band 3: margin 8.5 tiles out (alpha = 0.96) -> margin 18.0 tiles out (alpha = 1.0)

	var margins: Array[float] = [1.2, 3.2, 5.5, 8.5, 18.0]
	var alphas: Array[float] = [0.0, 0.35, 0.75, 0.96, 1.0]

	for b in range(margins.size() - 1):
		var m_in: float = margins[b]
		var m_out: float = margins[b + 1]
		var a_in: float = alphas[b]
		var a_out: float = alphas[b + 1]
		
		var col_in := Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, a_in)
		var col_out := Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, a_out)

		# Quad A: North-West Border (-m to gy, gy from -m to 32+m)
		var p1_in: Vector2 = get_pt.call(-m_in, -m_in)
		var p2_in: Vector2 = get_pt.call(-m_in, 32.0 + m_in)
		var p2_out: Vector2 = get_pt.call(-m_out, 32.0 + m_out)
		var p1_out: Vector2 = get_pt.call(-m_out, -m_out)
		_draw_gradient_quad(p1_in, p2_in, p2_out, p1_out, col_in, col_in, col_out, col_out)

		# Quad B: North-East Border (gx from -m to 32, gy = -m)
		var q1_in: Vector2 = get_pt.call(-m_in, -m_in)
		var q2_in: Vector2 = get_pt.call(32.0 + m_in, -m_in)
		var q2_out: Vector2 = get_pt.call(32.0 + m_out, -m_out)
		var q1_out: Vector2 = get_pt.call(-m_out, -m_out)
		_draw_gradient_quad(q1_in, q2_in, q2_out, q1_out, col_in, col_in, col_out, col_out)

		# Quad C: South-West Border (gx from -m to 32, gy = 32+m)
		var r1_in: Vector2 = get_pt.call(-m_in, 32.0 + m_in)
		var r2_in: Vector2 = get_pt.call(32.0 + m_in, 32.0 + m_in)
		var r2_out: Vector2 = get_pt.call(32.0 + m_out, 32.0 + m_out)
		var r1_out: Vector2 = get_pt.call(-m_out, 32.0 + m_out)
		_draw_gradient_quad(r1_in, r2_in, r2_out, r1_out, col_in, col_in, col_out, col_out)

		# Quad D: North Headland to Ocean transition (gx >= 32, gy <= -m)
		var nh1_in: Vector2 = get_pt.call(32.0, -m_in)
		var nh2_in: Vector2 = get_pt.call(40.0 + m_in, -m_in)
		var nh2_out: Vector2 = get_pt.call(40.0 + m_out, -m_out)
		var nh1_out: Vector2 = get_pt.call(32.0, -m_out)
		_draw_gradient_quad(nh1_in, nh2_in, nh2_out, nh1_out, col_in, col_in, col_out, col_out)

		# Quad E: South Headland to Ocean transition (gx >= 32, gy >= 32+m)
		var sh1_in: Vector2 = get_pt.call(32.0, 32.0 + m_in)
		var sh2_in: Vector2 = get_pt.call(40.0 + m_in, 32.0 + m_in)
		var sh2_out: Vector2 = get_pt.call(40.0 + m_out, 32.0 + m_out)
		var sh1_out: Vector2 = get_pt.call(32.0, 32.0 + m_out)
		_draw_gradient_quad(sh1_in, sh2_in, sh2_out, sh1_out, col_in, col_in, col_out, col_out)

	# -----------------------------------------------------------------------
	# 2. Animated Drifting Mist Wisps
	# -----------------------------------------------------------------------
	for m in _mist_particles:
		var drift_offset := Vector2(
			sin(_time * m.speed + m.phase) * 24.0,
			cos(_time * m.speed * 0.7 + m.phase) * 12.0
		)
		var pulse_alpha: float = (0.75 + 0.25 * sin(_time * m.speed * 1.2 + m.phase)) * m.alpha_mult
		var mist_col := Color(MIST_COLOR.r, MIST_COLOR.g, MIST_COLOR.b, MIST_COLOR.a * pulse_alpha)
		
		# Draw soft multi-ring mist puff
		var center: Vector2 = m.base_pos + drift_offset
		draw_circle(center, m.radius, mist_col)
		draw_circle(center, m.radius * 0.6, Color(mist_col.r, mist_col.g, mist_col.b, mist_col.a * 1.4))

func _draw_gradient_quad(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2,
		c1: Color, c2: Color, c3: Color, c4: Color) -> void:
	# Draw two triangles forming the quad with Gouraud vertex color shading
	var pts1 := PackedVector2Array([p1, p2, p3])
	var cols1 := PackedColorArray([c1, c2, c3])
	draw_polygon(pts1, cols1)

	var pts2 := PackedVector2Array([p1, p3, p4])
	var cols2 := PackedColorArray([c1, c3, c4])
	draw_polygon(pts2, cols2)
