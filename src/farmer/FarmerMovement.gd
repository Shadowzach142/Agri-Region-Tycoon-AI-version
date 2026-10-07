# FarmerMovement.gd
# Pure math helpers for Farmer movement: grid<->pixel conversion and wander target picking.
# Extracted from Farmer.gd. All methods are static — no instance needed.
#
# Usage:
#   var pixel := FarmerMovement.grid_to_pixel_center(grid_pos, farm_grid)
#   var grid  := FarmerMovement.pixel_to_grid(global_pos, farm_grid)
#   var wander_px := FarmerMovement.random_wander_pixel(grid_pos, radius, farm_grid)

# Standard 2:1 Isometric Projection:
#   ISO_TILE_WIDTH  = 128 px
#   ISO_TILE_HEIGHT = 64 px
#   HALF_W          = 64 px
#   HALF_H          = 32 px
#   ORIGIN_OFFSET   = Vector2(768, 64)  (centers 12x12 farm island)

class_name FarmerMovement
extends RefCounted

const ISO_TILE_WIDTH:  int   = 128
const ISO_TILE_HEIGHT: int   = 64
const HALF_W:          float = 64.0
const HALF_H:          float = 32.0
const ORIGIN_OFFSET:   Vector2 = Vector2(768.0, 64.0)

# Backward-compatibility alias
const TILE_PIXEL_SIZE: int   = 64

# ---------------------------------------------------------------------------
# Convert a grid coordinate to the world-space pixel center of that tile
# ---------------------------------------------------------------------------
static func grid_to_pixel_center(gpos: Vector2i, farm_grid: Node2D) -> Vector2:
	var local_center := Vector2(
		ORIGIN_OFFSET.x + (float(gpos.x) - float(gpos.y)) * HALF_W,
		ORIGIN_OFFSET.y + (float(gpos.x) + float(gpos.y) + 1.0) * HALF_H
	)
	return farm_grid.to_global(local_center) if farm_grid else local_center

# ---------------------------------------------------------------------------
# Convert a world-space pixel position to a grid coordinate
# ---------------------------------------------------------------------------
static func pixel_to_grid(pixel: Vector2, farm_grid: Node2D) -> Vector2i:
	var local_p: Vector2 = farm_grid.to_local(pixel) if farm_grid else pixel
	var u: float = (local_p.x - ORIGIN_OFFSET.x) / HALF_W
	var v: float = (local_p.y - ORIGIN_OFFSET.y) / HALF_H
	var fx: float = (v + u) / 2.0
	var fy: float = (v - u) / 2.0
	return Vector2i(int(floor(fx)), int(floor(fy)))

# ---------------------------------------------------------------------------
# Return the 4 vertices of a tile's isometric diamond in local space
# (Top, Right, Bottom, Left)
# ---------------------------------------------------------------------------
static func get_tile_diamond_local(gpos: Vector2i) -> PackedVector2Array:
	var cx: float = ORIGIN_OFFSET.x + (float(gpos.x) - float(gpos.y)) * HALF_W
	var cy: float = ORIGIN_OFFSET.y + (float(gpos.x) + float(gpos.y) + 1.0) * HALF_H
	return PackedVector2Array([
		Vector2(cx, cy - HALF_H),
		Vector2(cx + HALF_W, cy),
		Vector2(cx, cy + HALF_H),
		Vector2(cx - HALF_W, cy)
	])

# ---------------------------------------------------------------------------
# Return the 4 vertices of a multi-tile footprint diamond in local space
# (Top, Right, Bottom, Left)
# ---------------------------------------------------------------------------
static func get_footprint_polygon_local(start_gpos: Vector2i, fp: Vector2i) -> PackedVector2Array:
	var top_v := Vector2(
		ORIGIN_OFFSET.x + (float(start_gpos.x) - float(start_gpos.y)) * HALF_W,
		ORIGIN_OFFSET.y + (float(start_gpos.x) + float(start_gpos.y)) * HALF_H
	)
	var right_v := Vector2(
		ORIGIN_OFFSET.x + (float(start_gpos.x + fp.x) - float(start_gpos.y)) * HALF_W,
		ORIGIN_OFFSET.y + (float(start_gpos.x + fp.x) + float(start_gpos.y)) * HALF_H
	)
	var bottom_v := Vector2(
		ORIGIN_OFFSET.x + (float(start_gpos.x + fp.x) - float(start_gpos.y + fp.y)) * HALF_W,
		ORIGIN_OFFSET.y + (float(start_gpos.x + fp.x) + float(start_gpos.y + fp.y)) * HALF_H
	)
	var left_v := Vector2(
		ORIGIN_OFFSET.x + (float(start_gpos.x) - float(start_gpos.y + fp.y)) * HALF_W,
		ORIGIN_OFFSET.y + (float(start_gpos.x) + float(start_gpos.y + fp.y)) * HALF_H
	)
	return PackedVector2Array([top_v, right_v, bottom_v, left_v])

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
