# OutOfBoundsTerrain.gd
# Generates continuous isometric terrain beneath the out-of-bounds forest,
# ensuring the farm island's turf blends seamlessly into the perimeter.
# Dynamically adapts to provide distinct terrain materials, textures, color tints,
# and natural regional water streams for all 5 regions:
#   - Cotabato: Lush alluvial floodplain grass & winding tributary river stream
#   - South Cotabato: Cool alpine moss turf & cascading mountain brook with volcanic boulders
#   - Sarangani: Warm sunlit coastal sand dunes & seashell banks
#   - Sultan Kudarat: Rich granary prairie loam & agricultural irrigation canals
#   - General Santos: Compacted urban port gravel, hardened earth & stone aqueducts

class_name OutOfBoundsTerrain
extends Node2D

const TEX_NGRASS: Array[Texture2D] = [
	preload("res://assets/sprites/ground/NGRASS/NGRASS-01.png"),
	preload("res://assets/sprites/ground/NGRASS/NGRASS-02.png"),
	preload("res://assets/sprites/ground/NGRASS/NGRASS-03.png"),
	preload("res://assets/sprites/ground/NGRASS/NGRASS-04.png"),
	preload("res://assets/sprites/ground/NGRASS/NGRASS-05.png"),
]

const TEX_WGRASS: Array[Texture2D] = [
	preload("res://assets/sprites/ground/WGRASS/WGRASS-01.png"),
	preload("res://assets/sprites/ground/WGRASS/WGRASS-02.png"),
	preload("res://assets/sprites/ground/WGRASS/wGRASS-03.png"),
	preload("res://assets/sprites/ground/WGRASS/wGRASS-04.png"),
	preload("res://assets/sprites/ground/WGRASS/wGRASS-05.png"),
]

const TEX_SOIL: Array[Texture2D] = [
	preload("res://assets/sprites/ground/BARE SOIL/BARE-SOIL-01.png"),
	preload("res://assets/sprites/ground/BARE SOIL/BARE-SOIL-02.png"),
	preload("res://assets/sprites/ground/BARE SOIL/BARE-SOIL-03.png"),
	preload("res://assets/sprites/ground/BARE SOIL/BARE-SOIL-04.png"),
	preload("res://assets/sprites/ground/BARE SOIL/BARE-SOIL-05.png"),
]

const TEX_SAND: Array[Texture2D] = [
	preload("res://assets/sprites/ground/SAND/Sand-01.png"),
	preload("res://assets/sprites/ground/SAND/Sand-02.png"),
	preload("res://assets/sprites/ground/SAND/Sand-03.png"),
	preload("res://assets/sprites/ground/SAND/WSand-01.png"),
	preload("res://assets/sprites/ground/SAND/WSand-02.png"),
	preload("res://assets/sprites/ground/SAND/WSand-03.png"),
]

const TEX_WALK: Array[Texture2D] = [
	preload("res://assets/sprites/ground/BARE SOIL/WALK-SOIL-01.png"),
	preload("res://assets/sprites/ground/BARE SOIL/WALK-SOIL-02.png"),
	preload("res://assets/sprites/ground/BARE SOIL/WALK-SOIL-03.png"),
	preload("res://assets/sprites/ground/BARE SOIL/WALK-SOIL-04.png"),
	preload("res://assets/sprites/ground/BARE SOIL/WALK-SOIL-05.png"),
]

const TEX_BOULDER_1: Texture2D = preload("res://assets/sprites/obstacles/OBSTACLE_Boulder-Trio.png")
const TEX_BOULDER_2: Texture2D = preload("res://assets/sprites/obstacles/OBSTACLE_Boulder-Oval.png")
const TEX_BOULDER_3: Texture2D = preload("res://assets/sprites/obstacles/OBSTACLE_Boulder-kinda-round..png")

@export var region_key: String = ""

var _stream_canvas: Node2D = null

func _init() -> void:
	z_index = -8
	z_as_relative = false

func _ready() -> void:
	name = "OutOfBoundsTerrain"
	_resolve_region()
	_generate_terrain()
	_generate_regional_natural_features()

func _resolve_region() -> String:
	if region_key != "":
		return region_key
	var data_node = get_tree().root.get_node_or_null("Data") if is_inside_tree() else null
	if data_node and "current_region" in data_node:
		region_key = data_node.current_region
	else:
		region_key = "cotabato"
	return region_key

func _generate_terrain() -> void:
	var reg := _resolve_region()

	for gx in range(-9, 42):
		for gy in range(-9, 42):
			# Skip farm grid area (0..31, 0..31)
			if gx >= 0 and gx < 32 and gy >= 0 and gy < 32:
				continue
			# Skip eastern water body (gx >= 29 and gy >= -3 and gy < 35) in all regions
			if gx >= 29 and gy >= -3 and gy < 35:
				continue

			var pos_px: Vector2 = FarmerMovement.grid_to_pixel_center(Vector2i(gx, gy), null)
			var spr := Sprite2D.new()
			var hash_val: int = abs((gx * 73856093) ^ (gy * 19349663))

			# Select ground material texture & regional base tint
			var tex: Texture2D = null
			var base_tint: Color = Color.WHITE

			match reg:
				"cotabato":
					# Floodplain wet grass mixed with alluvial silt
					if hash_val % 10 < 7:
						tex = TEX_WGRASS[hash_val % TEX_WGRASS.size()]
					else:
						tex = TEX_SOIL[hash_val % TEX_SOIL.size()]
					base_tint = Color(0.86, 0.94, 0.86, 1.0) # Nutrient-rich alluvial green

				"south_cotabato":
					# Alpine mountain turf with cool volcanic moss
					tex = TEX_NGRASS[hash_val % TEX_NGRASS.size()]
					base_tint = Color(0.78, 0.88, 0.82, 1.0) # Cool highland slate green

				"sarangani":
					# Coastal sand dunes and sun-bleached grass
					if gx >= 26 or (gx + gy > 36) or (hash_val % 10 < 6):
						tex = TEX_SAND[hash_val % TEX_SAND.size()]
					else:
						tex = TEX_NGRASS[hash_val % TEX_NGRASS.size()]
					base_tint = Color(1.04, 1.01, 0.92, 1.0) # Sunlit warm coastal sand

				"sultan_kudarat":
					# Sun-baked agricultural prairie loam & golden savanna grass
					if hash_val % 10 < 5:
						tex = TEX_SOIL[hash_val % TEX_SOIL.size()]
					else:
						tex = TEX_NGRASS[hash_val % TEX_NGRASS.size()]
					base_tint = Color(0.96, 0.91, 0.76, 1.0) # Golden granary amber

				"general_santos":
					# Compacted port earth, gravel & industrial slate
					if hash_val % 10 < 6:
						tex = TEX_WALK[hash_val % TEX_WALK.size()]
					else:
						tex = TEX_NGRASS[hash_val % TEX_NGRASS.size()]
					base_tint = Color(0.86, 0.88, 0.90, 1.0) # Compacted maritime gravel

				_:
					tex = TEX_NGRASS[hash_val % TEX_NGRASS.size()]
					base_tint = Color(0.90, 0.94, 0.90, 1.0)

			spr.texture = tex
			spr.scale = Vector2(4.0, 4.0)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.centered = true
			spr.position = pos_px

			# Atmospheric canopy shade depth
			var dist_out: float = max(
				max(0.0 - float(gx), float(gx) - 31.0),
				max(0.0 - float(gy), float(gy) - 31.0)
			)
			var shade: float = clampf(1.0 - (dist_out * 0.022), 0.78, 1.0)
			spr.modulate = Color(base_tint.r * shade, base_tint.g * shade, base_tint.b * shade, 1.0)

			add_child(spr)

## Spawns natural regional features (river streams, mountain brooks, boulders, irrigation canals)
func _generate_regional_natural_features() -> void:
	var reg := _resolve_region()

	# Create a dedicated dynamic canvas for animated regional streams
	_stream_canvas = Node2D.new()
	_stream_canvas.name = "RegionalStreamCanvas"
	_stream_canvas.z_index = -6
	_stream_canvas.z_as_relative = false
	add_child(_stream_canvas)

	# Connect redraw processing for animated water flow
	var stream_script = load("res://src/world/RegionalStreamOverlay.gd")
	if stream_script:
		_stream_canvas.set_script(stream_script)
		if "region_key" in _stream_canvas:
			_stream_canvas.region_key = reg

	# Place natural geological formations for South Cotabato (volcanic boulders)
	if reg == "south_cotabato":
		var boulder_positions: Array[Vector2] = [
			Vector2(-4.5, -3.5),
			Vector2(-2.5, -6.0),
			Vector2(-6.0, 12.0),
			Vector2(-5.0, 18.0),
			Vector2(-4.0, 24.0),
			Vector2(12.0, -5.5),
			Vector2(20.0, -4.5),
			Vector2(14.0, 34.5),
			Vector2(22.0, 33.5)
		]
		for i in range(boulder_positions.size()):
			var bp: Vector2 = boulder_positions[i]
			var spr := Sprite2D.new()
			var b_tex: Texture2D = TEX_BOULDER_1 if (i % 3 == 0) else (TEX_BOULDER_2 if (i % 3 == 1) else TEX_BOULDER_3)
			spr.texture = b_tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.scale = Vector2(1.2, 1.2)
			spr.position = Vector2(
				FarmerMovement.ORIGIN_OFFSET.x + (bp.x - bp.y) * FarmerMovement.HALF_W,
				FarmerMovement.ORIGIN_OFFSET.y + (bp.x + bp.y + 1.0) * FarmerMovement.HALF_H
			)
			spr.modulate = Color(0.85, 0.90, 0.88, 1.0)
			add_child(spr)
