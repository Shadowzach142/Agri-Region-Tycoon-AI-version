# OutOfBoundsTerrain.gd
# Generates continuous isometric grass tiles (NGRASS) beneath the out-of-bounds forest,
# ensuring the farm island's turf blends seamlessly into the perimeter without flat voids.

class_name OutOfBoundsTerrain
extends Node2D

const GRASS_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/ground/NGRASS/NGRASS-01.png"),
	preload("res://assets/sprites/ground/NGRASS/NGRASS-02.png"),
	preload("res://assets/sprites/ground/NGRASS/NGRASS-03.png"),
	preload("res://assets/sprites/ground/NGRASS/NGRASS-04.png"),
	preload("res://assets/sprites/ground/NGRASS/NGRASS-05.png"),
]

func _init() -> void:
	z_index = -8
	z_as_relative = false

func _ready() -> void:
	name = "OutOfBoundsTerrain"
	_generate_terrain()

func _generate_terrain() -> void:
	# Farm is 0 <= gx < 32 and 0 <= gy < 32.
	# We tile out-of-bounds terrain from gx = -9 to 41, gy = -9 to 41.
	# We skip inside the farm (handled by FarmGrid) and inside Sarangani Bay (handled by SeaWater).
	
	for gx in range(-9, 42):
		for gy in range(-9, 42):
			# Skip farm grid area
			if gx >= 0 and gx < 32 and gy >= 0 and gy < 32:
				continue
			# Skip eastern ocean (Sarangani Bay)
			if gx >= 32 and gy >= 0 and gy < 32:
				continue
				
			var pos_px: Vector2 = FarmerMovement.grid_to_pixel_center(Vector2i(gx, gy), null)
			
			var spr := Sprite2D.new()
			var tex_idx: int = abs((gx * 73856093) ^ (gy * 19349663)) % GRASS_TEXTURES.size()
			spr.texture = GRASS_TEXTURES[tex_idx]
			spr.scale = Vector2(4.0, 4.0)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.centered = true
			spr.position = pos_px
			
			# Subtle ambient forest shade under the deep canopy
			var dist_out: float = max(
				max(0.0 - float(gx), float(gx) - 31.0),
				max(0.0 - float(gy), float(gy) - 31.0)
			)
			var shade: float = clampf(1.0 - (dist_out * 0.025), 0.78, 1.0)
			spr.modulate = Color(shade * 0.95, shade, shade * 0.92, 1.0)
			
			add_child(spr)
