# FarmerMovement.gd
# Pure math helpers for Farmer movement: grid<->pixel conversion and wander target picking.
# Extracted from Farmer.gd. All methods are static — no instance needed.
#
# Usage:
#   var pixel := FarmerMovement.grid_to_pixel_center(grid_pos, farm_grid)
#   var grid  := FarmerMovement.pixel_to_grid(global_pos, farm_grid)
#   var wander_px := FarmerMovement.random_wander_pixel(grid_pos, radius, farm_grid)

class_name FarmerMovement
extends RefCounted

const TILE_PIXEL_SIZE: int = 64

# ---------------------------------------------------------------------------
# Convert a grid coordinate to the world-space pixel center of that tile
# ---------------------------------------------------------------------------
static func grid_to_pixel_center(gpos: Vector2i, farm_grid: Node2D) -> Vector2:
	var local_center := Vector2(
		gpos.x * TILE_PIXEL_SIZE + TILE_PIXEL_SIZE / 2.0,
		gpos.y * TILE_PIXEL_SIZE + TILE_PIXEL_SIZE / 2.0
	)
	return farm_grid.to_global(local_center) if farm_grid else local_center

# ---------------------------------------------------------------------------
# Convert a world-space pixel position to a grid coordinate
# ---------------------------------------------------------------------------
static func pixel_to_grid(pixel: Vector2, farm_grid: Node2D) -> Vector2i:
	var local_p: Vector2 = farm_grid.to_local(pixel) if farm_grid else pixel
	return Vector2i(
		int(floor(local_p.x / float(TILE_PIXEL_SIZE))),
		int(floor(local_p.y / float(TILE_PIXEL_SIZE)))
	)

# ---------------------------------------------------------------------------
# Pick a random nearby wander destination, returned as a world-space pixel
# ---------------------------------------------------------------------------
static func random_wander_pixel(current_gpos: Vector2i, radius: int, farm_grid: Node2D) -> Vector2:
	var offset := Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
	return grid_to_pixel_center(current_gpos + offset, farm_grid)

# ---------------------------------------------------------------------------
# Step an entity toward a pixel target. Returns true when arrived.
# Caller should set global_position = target_pixel on arrival.
# ---------------------------------------------------------------------------
static func step_toward(entity: CharacterBody2D, target_pixel: Vector2, move_speed: float, delta: float) -> bool:
	var dir: Vector2  = target_pixel - entity.global_position
	var dist: float   = dir.length()
	var step: float   = move_speed * delta

	if dist <= step or dist < 4.0:
		entity.global_position = target_pixel
		return true  # Arrived

	entity.velocity        = dir.normalized() * move_speed
	entity.global_position += entity.velocity * delta
	return false  # Still moving
