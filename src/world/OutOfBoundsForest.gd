# OutOfBoundsForest.gd
# Procedural Out-of-Bounds Forest, Seamless Grass Terrain & Fog of War (Clash of Clans style).
# Frames the 24x24 farm island with lush grass underlay, dense multi-layered canopy trees,
# organic dirt trails, and moody perimeter fog of war.

class_name OutOfBoundsForest
extends Node2D

const TEX_TREE_1: Texture2D = preload("res://assets/sprites/OutofBounds/TREE-UP-1.png") # 208x160 Large Canopy
const TEX_TREE_2: Texture2D = preload("res://assets/sprites/OutofBounds/TREE-UP-2.png") # 144x112 Medium Bush/Tree
const TEX_TREE_3: Texture2D = preload("res://assets/sprites/OutofBounds/TREE-UP-3.png") # 96x80 Small Shrub

const OutOfBoundsTerrainScript: GDScript = preload("res://src/world/OutOfBoundsTerrain.gd")
const OutOfBoundsDirtTrailScript: GDScript = preload("res://src/world/OutOfBoundsDirtTrail.gd")
const OutOfBoundsFogOfWarScript: GDScript = preload("res://src/world/OutOfBoundsFogOfWar.gd")

var terrain_node: Node2D = null
var dirt_trail_node: Node2D = null
var trees_layer: Node2D = null
var fog_of_war_node: Node2D = null

func _ready() -> void:
	name = "OutOfBoundsForest"
	y_sort_enabled = true

	# 1. Seamless Out-of-Bounds Grass Terrain (Z=-8, pixel-perfect NGRASS diamonds under forest)
	terrain_node = OutOfBoundsTerrainScript.new()
	add_child(terrain_node)

	# 2. Natural Dirt Perimeter Trail (Z=-5, drawn under grass edges and trees)
	dirt_trail_node = OutOfBoundsDirtTrailScript.new()
	add_child(dirt_trail_node)

	# 3. Forest Canopy Layer (Z=10, Y-sorted with crops, buildings, and workers)
	trees_layer = Node2D.new()
	trees_layer.name = "TreesLayer"
	trees_layer.z_index = 10
	trees_layer.y_sort_enabled = true
	add_child(trees_layer)

	_build_forest()

	# 4. Atmospheric Fog of War & Canopy Mist (Z=22, dissolves outer forest layers into jungle mist)
	fog_of_war_node = OutOfBoundsFogOfWarScript.new()
	add_child(fog_of_war_node)

# ---------------------------------------------------------------------------
# Procedural Forest Generation
# ---------------------------------------------------------------------------
func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261024 # Deterministic seed for consistent, beautiful layout

	var add_tree := func(gx: float, gy: float, tex: Texture2D, custom_jitter: float = 7.0) -> void:
		var base_pos := Vector2(
			FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
			FarmerMovement.ORIGIN_OFFSET.y + (gx + gy + 1.0) * FarmerMovement.HALF_H
		)
		base_pos += Vector2(
			rng.randf_range(-custom_jitter, custom_jitter),
			rng.randf_range(-custom_jitter * 0.45, custom_jitter * 0.45)
		)

		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tsz := tex.get_size()
		# Base contact is ~92% down the sprite height
		spr.offset = Vector2(0, -tsz.y * 0.42)
		spr.position = base_pos
		spr.flip_h = rng.randf() > 0.5
		var sc := rng.randf_range(0.96, 1.05)
		spr.scale = Vector2(sc, sc)

		# Rich tropical foliage tint variation
		var tint := rng.randf_range(0.94, 1.02)
		spr.modulate = Color(tint * 0.97, tint, tint * 0.95, 1.0)
		trees_layer.add_child(spr)

	# Depth layers: extended from d=1.8 out to d=9.8 tiles into the periphery
	var depth_steps: Array[float] = [1.8, 2.8, 3.8, 4.8, 5.8, 6.8, 7.8, 8.8, 9.8]

	# -----------------------------------------------------------------------
	# 1. NORTH-WEST BORDER (gx < 0, gy from -9 to 28)
	# -----------------------------------------------------------------------
	# Frontline edge bushes & small clusters (gx = -0.7 to -1.3)
	for y in range(-6, 28):
		var tex: Texture2D = TEX_TREE_3 if rng.randf() < 0.6 else TEX_TREE_2
		add_tree.call(-0.9 + rng.randf_range(-0.15, 0.15), float(y) + rng.randf_range(-0.25, 0.25), tex, 6.0)
		if rng.randf() < 0.45:
			add_tree.call(-1.35 + rng.randf_range(-0.15, 0.15), float(y) + 0.5, TEX_TREE_3, 5.0)

	# Mid & Deep NW layers
	for d in depth_steps:
		var step: float = 1.6 if d <= 3.8 else 2.0
		var y_curr: float = -d - 4.5
		while y_curr <= 27.5 + d:
			var tex: Texture2D = TEX_TREE_1 if (d >= 2.8 or rng.randf() < 0.6) else TEX_TREE_2
			add_tree.call(-d + rng.randf_range(-0.3, 0.3), y_curr + rng.randf_range(-0.3, 0.3), tex, 9.0)
			y_curr += step

	# -----------------------------------------------------------------------
	# 2. NORTH-EAST BORDER (gy < 0, gx from -9 to 30)
	# -----------------------------------------------------------------------
	# Frontline edge bushes (gy = -0.7 to -1.3)
	for x in range(-6, 27):
		var tex: Texture2D = TEX_TREE_3 if rng.randf() < 0.6 else TEX_TREE_2
		add_tree.call(float(x) + rng.randf_range(-0.25, 0.25), -0.9 + rng.randf_range(-0.15, 0.15), tex, 6.0)
		if rng.randf() < 0.45:
			add_tree.call(float(x) + 0.5, -1.35 + rng.randf_range(-0.15, 0.15), TEX_TREE_3, 5.0)

	# Mid & Deep NE layers
	for d in depth_steps:
		var step: float = 1.6 if d <= 3.8 else 2.0
		var x_curr: float = -d - 4.5
		while x_curr <= 28.5 + d:
			var tex: Texture2D = TEX_TREE_1 if (d >= 2.8 or rng.randf() < 0.6) else TEX_TREE_2
			add_tree.call(x_curr + rng.randf_range(-0.3, 0.3), -d + rng.randf_range(-0.3, 0.3), tex, 9.0)
			x_curr += step

	# -----------------------------------------------------------------------
	# 3. SOUTH-WEST BORDER (gy >= 24, gx from -9 to 26)
	# -----------------------------------------------------------------------
	# Frontline edge bushes (gy = 24.5 to 25.1)
	for x in range(-6, 26):
		var tex: Texture2D = TEX_TREE_3 if rng.randf() < 0.6 else TEX_TREE_2
		add_tree.call(float(x) + rng.randf_range(-0.25, 0.25), 24.65 + rng.randf_range(-0.15, 0.15), tex, 6.0)
		if rng.randf() < 0.45:
			add_tree.call(float(x) + 0.5, 25.15 + rng.randf_range(-0.15, 0.15), TEX_TREE_3, 5.0)

	# Mid & Deep SW layers
	for d in depth_steps:
		var step: float = 1.6 if d <= 3.8 else 2.0
		var x_curr: float = -d - 4.5
		while x_curr <= 26.5 + d * 0.5:
			var tex: Texture2D = TEX_TREE_1 if (d >= 2.8 or rng.randf() < 0.6) else TEX_TREE_2
			add_tree.call(x_curr + rng.randf_range(-0.3, 0.3), 24.0 + d + rng.randf_range(-0.3, 0.3), tex, 9.0)
			x_curr += step

	# -----------------------------------------------------------------------
	# 4. COASTAL HEADLANDS (Framing the eastern sea at (24, 0) and (24, 24))
	# -----------------------------------------------------------------------
	# North Headland overlooking bay (gx in [24, 33], gy in [-9, -0.5])
	for gx in range(24, 34):
		for gy in range(-9, 0):
			var tex: Texture2D = TEX_TREE_1 if rng.randf() < 0.65 else TEX_TREE_2
			add_tree.call(float(gx) + rng.randf_range(-0.3, 0.3), float(gy) + rng.randf_range(-0.3, 0.3), tex, 8.0)

	# South Headland overlooking bay (gx in [24, 33], gy in [24, 33])
	for gx in range(24, 34):
		for gy in range(24, 34):
			var tex: Texture2D = TEX_TREE_1 if rng.randf() < 0.65 else TEX_TREE_2
			add_tree.call(float(gx) + rng.randf_range(-0.3, 0.3), float(gy) + rng.randf_range(-0.3, 0.3), tex, 8.0)
