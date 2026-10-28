# Map_GeneralSantos.gd
# General Santos City — Agro-Industrial Seaport Hub & Sarangani Bay Gateway
# Environmental identity:
#   - Heavy industrial port: dressed granite pavers, concrete tarmac, stone seawall embankment
#   - Urban GenSan city block grid above the farm (streets, building footprints)
#   - Port authority compound with perimeter wall and container yard on the west
#   - Makar Wharf access road slicing NW-to-coast with worn asphalt center stripe
#   - Container marshalling yard south of the farm
#   - Urban stone drainage culverts running north along western edge
#   - Port authority floodlight zones near the seawall
#   - SW gravel yard: compacted ballast rock typical of industrial port staging areas
#   - General Paulino Santos Monument on a dressed granite civic square
#   - Strictly clean cultural presentation: NO decorative props, ONLY the founder memorial monument

class_name MapGeneralSantos
extends "res://src/world/RegionalMapBase.gd"

const _AMB_LAYER_Z: int = -7

func _init() -> void:
	super()
	region_key = "general_santos"
	# Modern dressed granite pavers and maritime stone
	plaza_pavement_color = Color(0.34, 0.36, 0.38, 0.95)
	plaza_border_color = Color(0.55, 0.58, 0.62, 0.90)

func _build_regional_content() -> void:
	_build_port_environment()

	# 1. General Paulino Santos Monument (Founder Memorial Landmark)
	add_monument(
		Vector2(-2.5, 4.5),
		"gen_paulino_santos",
		"General Paulino Santos Monument",
		"Founder Memorial Landmark • Plaza Heneral Santos",
		"Memorial monument honoring Major General Paulino Santos, pioneer military engineer and administrator who led the 1939 settlement that founded modern General Santos City.",
		"res://assets/sprites/monuments/gen_paulino_santos_monument.png",
		"res://assets/sprites/monuments/gen_paulino_santos_monument_FLIPPED.png",
		false,
		Vector2(1.8, 1.8),
		Vector2(56.0, 28.0)
	)

## Draw industrial seaport landscape: full perimeter coverage + port infrastructure
func _build_port_environment() -> void:
	var env := Node2D.new()
	env.name = "PortEnv"
	env.z_index = _AMB_LAYER_Z
	env.z_as_relative = false

	# === FULL PERIMETER GROUND TINTING ===
	# NW quadrant — compacted grey industrial earth
	var nw_ground := Polygon2D.new()
	nw_ground.color = Color(0.34, 0.34, 0.36, 0.62)
	nw_ground.polygon = PackedVector2Array([
		get_pt(-9.0, -9.0), get_pt(-0.5, -9.0),
		get_pt(-0.5, 42.0), get_pt(-9.0, 42.0)
	])
	env.add_child(nw_ground)

	# SW band (below farm) — port staging ground
	var sw_ground := Polygon2D.new()
	sw_ground.color = Color(0.32, 0.32, 0.34, 0.60)
	sw_ground.polygon = PackedVector2Array([
		get_pt(-0.5, 32.0), get_pt(32.0, 32.0),
		get_pt(32.0, 42.0), get_pt(-0.5, 42.0)
	])
	env.add_child(sw_ground)

	# === NORTH — Urban GenSan City Blocks ===
	# Dense urban grid above the farm — city blocks, streets, concrete rooftops
	var n_city := Polygon2D.new()
	n_city.color = Color(0.36, 0.36, 0.38, 0.70)
	n_city.polygon = PackedVector2Array([
		get_pt(-0.5, -9.0), get_pt(32.0, -9.0),
		get_pt(32.0, -0.5), get_pt(-0.5, -0.5)
	])
	env.add_child(n_city)

	# City block street grid — dark street lines running N-S
	for blk_x in range(0, 30, 5):
		var blk_line := Line2D.new()
		blk_line.width = 5.0
		blk_line.default_color = Color(0.22, 0.22, 0.24, 0.65)
		blk_line.add_point(get_pt(float(blk_x), -9.0))
		blk_line.add_point(get_pt(float(blk_x), -0.5))
		env.add_child(blk_line)

	# Cross streets running E-W
	for blk_y in range(-8, -1, 2):
		var cross := Line2D.new()
		cross.width = 4.0
		cross.default_color = Color(0.22, 0.22, 0.24, 0.55)
		cross.add_point(get_pt(0.0, float(blk_y)))
		cross.add_point(get_pt(30.0, float(blk_y)))
		env.add_child(cross)

	# Building footprint blocks (lighter rooftop rectangles on city grid)
	var bldg_defs: Array[Array] = [
		[Vector2(1.0, -7.5), Vector2(4.0, -3.0)],
		[Vector2(6.0, -8.0), Vector2(9.5, -3.5)],
		[Vector2(11.0, -7.0), Vector2(14.0, -3.0)],
		[Vector2(16.0, -8.0), Vector2(19.5, -4.0)],
		[Vector2(21.0, -7.5), Vector2(24.5, -3.5)],
		[Vector2(26.0, -8.5), Vector2(29.5, -3.0)],
	]
	for bldg in bldg_defs:
		var b := Polygon2D.new()
		b.color = Color(0.48, 0.48, 0.50, 0.55)
		b.polygon = PackedVector2Array([
			get_pt(bldg[0].x, bldg[0].y), get_pt(bldg[1].x, bldg[0].y),
			get_pt(bldg[1].x, bldg[1].y), get_pt(bldg[0].x, bldg[1].y)
		])
		env.add_child(b)

	# === WEST — Port Authority Compound Boundary ===
	# Concrete perimeter compound with security wall and container yard
	var w_compound := Polygon2D.new()
	w_compound.color = Color(0.40, 0.40, 0.42, 0.72)
	w_compound.polygon = PackedVector2Array([
		get_pt(-8.5, 0.0), get_pt(-0.5, 0.0),
		get_pt(-0.5, 32.0), get_pt(-8.5, 32.0)
	])
	env.add_child(w_compound)

	# Perimeter wall cap line
	var wall_cap := Line2D.new()
	wall_cap.width = 5.0
	wall_cap.default_color = Color(0.28, 0.28, 0.30, 0.75)
	for wy in range(0, 32):
		wall_cap.add_point(get_pt(-0.6, float(wy)))
	env.add_child(wall_cap)

	# Security fence posts (regularly spaced)
	for fence_y in range(1, 31, 3):
		var post := Polygon2D.new()
		post.color = Color(0.55, 0.55, 0.56, 0.80)
		post.polygon = PackedVector2Array([
			get_pt(-0.8, float(fence_y) - 0.08),
			get_pt(-0.5, float(fence_y) - 0.08),
			get_pt(-0.5, float(fence_y) + 0.08),
			get_pt(-0.8, float(fence_y) + 0.08)
		])
		env.add_child(post)

	# Container yard bay lines
	for bay_y in range(3, 30, 5):
		var bay := Line2D.new()
		bay.width = 2.0
		bay.default_color = Color(0.26, 0.26, 0.28, 0.55)
		bay.add_point(get_pt(-7.5, float(bay_y)))
		bay.add_point(get_pt(-1.2, float(bay_y)))
		env.add_child(bay)

	# === SOUTH — Container Marshalling Yard ===
	# Industrial container yard south of the farm
	var s_yard := Polygon2D.new()
	s_yard.color = Color(0.36, 0.36, 0.38, 0.68)
	s_yard.polygon = PackedVector2Array([
		get_pt(0.0, 33.0), get_pt(30.0, 33.0),
		get_pt(30.0, 42.0), get_pt(0.0, 42.0)
	])
	env.add_child(s_yard)

	# Truck lane markings
	for lane_x in range(2, 28, 4):
		var lane := Line2D.new()
		lane.width = 2.0
		lane.default_color = Color(0.52, 0.52, 0.50, 0.40)
		lane.add_point(get_pt(float(lane_x), 33.5))
		lane.add_point(get_pt(float(lane_x), 41.5))
		env.add_child(lane)

	# Stacked container block outlines
	var container_rows: Array[Vector2] = [
		Vector2(1.0, 35.0), Vector2(7.0, 35.0), Vector2(13.0, 35.0),
		Vector2(19.0, 35.0), Vector2(25.0, 35.0),
		Vector2(1.0, 38.5), Vector2(7.0, 38.5), Vector2(13.0, 38.5),
	]
	for cr in container_rows:
		var container := Polygon2D.new()
		container.color = Color(0.44, 0.44, 0.46, 0.55)
		container.polygon = PackedVector2Array([
			get_pt(cr.x, cr.y), get_pt(cr.x + 4.5, cr.y),
			get_pt(cr.x + 4.5, cr.y + 2.0), get_pt(cr.x, cr.y + 2.0)
		])
		env.add_child(container)
		var c_top := Line2D.new()
		c_top.width = 1.5
		c_top.default_color = Color(0.30, 0.30, 0.32, 0.60)
		c_top.closed = true
		c_top.add_point(get_pt(cr.x, cr.y))
		c_top.add_point(get_pt(cr.x + 4.5, cr.y))
		c_top.add_point(get_pt(cr.x + 4.5, cr.y + 2.0))
		c_top.add_point(get_pt(cr.x, cr.y + 2.0))
		env.add_child(c_top)

	# --- 1. Industrial Concrete Tarmac (eastern port staging ground) ---
	var tarmac := Polygon2D.new()
	tarmac.color = Color(0.38, 0.38, 0.40, 0.72)
	tarmac.polygon = PackedVector2Array([
		get_pt(18.0, -0.5), get_pt(32.0, -0.5),
		get_pt(32.0, 32.5), get_pt(18.0, 32.5)
	])
	env.add_child(tarmac)

	# Tarmac joint lines (expansion cracks every ~3 tiles)
	for strip_y in range(0, 33, 3):
		var joint := Line2D.new()
		joint.width = 2.0
		joint.default_color = Color(0.28, 0.28, 0.30, 0.55)
		joint.add_point(get_pt(18.0, float(strip_y)))
		joint.add_point(get_pt(31.0, float(strip_y)))
		env.add_child(joint)

	# --- 2. Stone Seawall Embankment ---
	var seawall := Polygon2D.new()
	seawall.color = Color(0.28, 0.30, 0.34, 0.95)
	seawall.polygon = PackedVector2Array([
		get_pt(29.0, -0.5), get_pt(32.0, -0.5),
		get_pt(32.0, 32.5), get_pt(29.0, 32.5)
	])
	env.add_child(seawall)

	# Seawall capstone
	var capstone := Line2D.new()
	capstone.width = 7.0
	capstone.default_color = Color(0.50, 0.52, 0.56, 0.88)
	for y in range(-1, 33):
		capstone.add_point(get_pt(29.0, float(y)))
	env.add_child(capstone)

	# Seawall anchor bolts
	for bolt_y in range(1, 32, 4):
		var bolt := Line2D.new()
		bolt.width = 1.5
		bolt.default_color = Color(0.62, 0.60, 0.55, 0.70)
		bolt.add_point(get_pt(29.2, float(bolt_y) - 0.4))
		bolt.add_point(get_pt(29.2, float(bolt_y) + 0.4))
		env.add_child(bolt)

	# --- 3. Makar Wharf Access Road ---
	var road := Polygon2D.new()
	road.color = Color(0.30, 0.30, 0.32, 0.90)
	road.polygon = PackedVector2Array([
		get_pt(-4.0, -4.0), get_pt(-2.5, -4.0),
		get_pt(29.5, 10.0), get_pt(29.5, 12.5)
	])
	env.add_child(road)

	var stripe := Line2D.new()
	stripe.width = 2.0
	stripe.default_color = Color(0.80, 0.76, 0.58, 0.55)
	stripe.add_point(get_pt(-4.0, -4.0))
	stripe.add_point(get_pt(-2.5, -4.0))
	stripe.add_point(get_pt(29.5, 11.2))
	env.add_child(stripe)

	var shoulder_a := Line2D.new()
	shoulder_a.width = 1.5
	shoulder_a.default_color = Color(0.88, 0.88, 0.82, 0.40)
	shoulder_a.add_point(get_pt(-4.0, -4.0))
	shoulder_a.add_point(get_pt(29.5, 10.0))
	env.add_child(shoulder_a)

	var shoulder_b := Line2D.new()
	shoulder_b.width = 1.5
	shoulder_b.default_color = Color(0.88, 0.88, 0.82, 0.40)
	shoulder_b.add_point(get_pt(-2.5, -4.0))
	shoulder_b.add_point(get_pt(29.5, 12.5))
	env.add_child(shoulder_b)

	# --- 4. Stone Drainage Culverts ---
	var culvert := Line2D.new()
	culvert.width = 8.0
	culvert.default_color = Color(0.20, 0.22, 0.26, 0.85)
	for y in range(-4, 33):
		culvert.add_point(get_pt(-3.0, float(y)))
	env.add_child(culvert)

	var culvert_edge := Line2D.new()
	culvert_edge.width = 12.0
	culvert_edge.default_color = Color(0.40, 0.40, 0.42, 0.60)
	for y in range(-4, 33):
		culvert_edge.add_point(get_pt(-3.0, float(y)))
	env.add_child(culvert_edge)

	var culvert_e := Line2D.new()
	culvert_e.width = 6.0
	culvert_e.default_color = Color(0.18, 0.20, 0.24, 0.80)
	for y in range(-1, 33):
		culvert_e.add_point(get_pt(28.8, float(y)))
	env.add_child(culvert_e)

	# --- 5. Port Floodlight Zones ---
	var floodlight_positions: Array[Vector2] = [
		Vector2(27.0, 4.0), Vector2(27.0, 12.0),
		Vector2(27.0, 20.0), Vector2(27.0, 28.0),
	]
	for fl_pos in floodlight_positions:
		var pad := Polygon2D.new()
		pad.color = Color(0.52, 0.54, 0.58, 0.40)
		var pad_pts := PackedVector2Array()
		for seg in range(12):
			var ang := TAU * seg / 12.0
			pad_pts.append(get_pt(fl_pos.x + cos(ang) * 1.6, fl_pos.y + sin(ang) * 0.8))
		pad.polygon = pad_pts
		env.add_child(pad)
		var post := Polygon2D.new()
		post.color = Color(0.22, 0.22, 0.24, 0.95)
		post.polygon = PackedVector2Array([
			get_pt(fl_pos.x - 0.15, fl_pos.y - 0.15),
			get_pt(fl_pos.x + 0.15, fl_pos.y - 0.15),
			get_pt(fl_pos.x + 0.15, fl_pos.y + 0.15),
			get_pt(fl_pos.x - 0.15, fl_pos.y + 0.15)
		])
		env.add_child(post)

	# --- 6. SW Ballast Gravel Yard ---
	var gravel_yard := Polygon2D.new()
	gravel_yard.color = Color(0.44, 0.43, 0.40, 0.65)
	gravel_yard.polygon = PackedVector2Array([
		get_pt(-9.0, 0.0), get_pt(-3.5, 0.0),
		get_pt(-3.5, 42.0), get_pt(-9.0, 42.0)
	])
	env.add_child(gravel_yard)

	var gravel_s := Polygon2D.new()
	gravel_s.color = Color(0.42, 0.41, 0.38, 0.60)
	gravel_s.polygon = PackedVector2Array([
		get_pt(-3.5, 33.0), get_pt(28.5, 33.0),
		get_pt(28.5, 42.0), get_pt(-3.5, 42.0)
	])
	env.add_child(gravel_s)

	for scratch_y in range(34, 42):
		if int(scratch_y) % 2 == 0:
			var scratch := Line2D.new()
			scratch.width = 1.5
			scratch.default_color = Color(0.52, 0.52, 0.48, 0.28)
			scratch.add_point(get_pt(-8.0, float(scratch_y)))
			scratch.add_point(get_pt(-3.8, float(scratch_y)))
			env.add_child(scratch)

	add_child(env)
