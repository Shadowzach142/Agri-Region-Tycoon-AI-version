# RegionalMapBase.gd
# Base class for all regional map environments in Agri-Region Tycoon.
# Manages:
#   - Paved isometric civic plaza terrace along the northwest edge
#   - Forest overlay & regional water initialization
#   - Dynamic placement and registration of regional monuments & cultural props

class_name RegionalMapBase
extends Node2D

const OutOfBoundsForestScript = preload("res://src/world/OutOfBoundsForest.gd")
const SeaWaterScript = preload("res://src/world/SeaWater.gd")
const RegionalMonumentScript = preload("res://src/world/RegionalMonument.gd")
const RegionalPropScript = preload("res://src/world/RegionalProp.gd")

@export var region_key: String = "cotabato"
@export var plaza_pavement_color: Color = Color(0.38, 0.35, 0.30, 0.95)
@export var plaza_border_color: Color = Color(0.55, 0.48, 0.38, 0.85)

var forest_node: Node2D = null
var water_node: Node2D = null
var props_layer: Node2D = null
var monuments_layer: Node2D = null
var plaza_layer: Node2D = null

func _init() -> void:
	name = "RegionalMap"
	y_sort_enabled = true

func _ready() -> void:
	_setup_layers()
	_setup_water()
	_setup_forest()
	_build_plaza_terrace()
	_build_regional_content()

func _setup_layers() -> void:
	# Plaza pavement sits below standing props and trees (z_index = -3)
	plaza_layer = Node2D.new()
	plaza_layer.name = "PlazaLayer"
	plaza_layer.z_index = -3
	add_child(plaza_layer)

	# Monuments & props Y-sort with crops, buildings, and workers (z_index = 10)
	monuments_layer = Node2D.new()
	monuments_layer.name = "MonumentsLayer"
	monuments_layer.z_index = 10
	monuments_layer.y_sort_enabled = true
	add_child(monuments_layer)

	props_layer = Node2D.new()
	props_layer.name = "PropsLayer"
	props_layer.z_index = 10
	props_layer.y_sort_enabled = true
	add_child(props_layer)

func _setup_water() -> void:
	water_node = SeaWaterScript.new()
	water_node.name = "SeaWater"
	if "region_key" in water_node:
		water_node.region_key = region_key
	add_child(water_node)

func _setup_forest() -> void:
	forest_node = OutOfBoundsForestScript.new()
	forest_node.name = "OutOfBoundsForest"
	if "region_key" in forest_node:
		forest_node.region_key = region_key
	add_child(forest_node)

func get_pt(gx: float, gy: float) -> Vector2:
	return Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (gx + gy + 1.0) * FarmerMovement.HALF_H
	)

## Builds an authentic paved isometric stone terrace along the NW boundary (-4 <= gx <= -1, 0 <= gy <= 10)
func _build_plaza_terrace() -> void:
	# 1. Paved Plaza Base Polygon
	var p_nw: Vector2 = get_pt(-4.5, -0.5)
	var p_ne: Vector2 = get_pt(-0.8, -0.5)
	var p_se: Vector2 = get_pt(-0.8, 11.0)
	var p_sw: Vector2 = get_pt(-4.5, 11.0)

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([p_nw, p_ne, p_se, p_sw])
	poly.color = plaza_pavement_color
	plaza_layer.add_child(poly)

	# 2. Isometric stone pavers grid pattern across plaza
	for gx in range(-4, 0):
		for gy in range(0, 11):
			var center: Vector2 = get_pt(float(gx), float(gy))
			var paver := Polygon2D.new()
			paver.polygon = PackedVector2Array([
				center + Vector2(0, -30),
				center + Vector2(60, 0),
				center + Vector2(0, 30),
				center + Vector2(-60, 0)
			])
			# Subtle checkerboard shade
			var shade: float = 0.04 if ((gx + gy) % 2 == 0) else -0.04
			paver.color = Color(
				plaza_pavement_color.r + shade,
				plaza_pavement_color.g + shade,
				plaza_pavement_color.b + shade,
				0.90
			)
			plaza_layer.add_child(paver)

			# Paver border line
			var line := Line2D.new()
			line.width = 1.0
			line.default_color = plaza_border_color
			line.closed = true
			line.add_point(center + Vector2(0, -30))
			line.add_point(center + Vector2(60, 0))
			line.add_point(center + Vector2(0, 30))
			line.add_point(center + Vector2(-60, 0))
			plaza_layer.add_child(line)

	# 3. Outer curb border along the boundary touching the farm island
	var curb := Line2D.new()
	curb.width = 3.0
	curb.default_color = Color(0.22, 0.18, 0.14, 0.85)
	curb.add_point(get_pt(-0.7, -0.5))
	curb.add_point(get_pt(-0.7, 11.0))
	plaza_layer.add_child(curb)

## Virtual method to be overridden by subclasses to add regional monuments and props
func _build_regional_content() -> void:
	pass

## Helper to spawn an interactive regional monument
func add_monument(
	grid_pos: Vector2,
	id: String,
	title: String,
	subtitle: String,
	lore: String,
	tex_path: String,
	tex_flipped_path: String = "",
	flipped: bool = false,
	m_scale: Vector2 = Vector2(1.8, 1.8),
	p_radius: Vector2 = Vector2(56.0, 28.0)
) -> Node2D:
	var m = RegionalMonumentScript.new()
	m.name = "Monument_" + id
	m.monument_id = id
	m.monument_title = title
	m.monument_subtitle = subtitle
	m.monument_lore = lore
	m.is_flipped = flipped
	m.sprite_scale = m_scale
	m.pedestal_radius = p_radius

	if ResourceLoader.exists(tex_path):
		m.monument_texture = load(tex_path) as Texture2D
	if tex_flipped_path != "" and ResourceLoader.exists(tex_flipped_path):
		m.monument_texture_flipped = load(tex_flipped_path) as Texture2D

	var world_pos := Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (grid_pos.x - grid_pos.y) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (grid_pos.x + grid_pos.y + 1.0) * FarmerMovement.HALF_H
	)
	m.position = world_pos
	monuments_layer.add_child(m)
	return m

## Helper to spawn an interactive cultural prop
func add_prop(
	grid_pos: Vector2,
	prop_name: String,
	prop_category: String,
	prop_desc: String,
	tex_path: String,
	tex_flipped_path: String = "",
	flipped: bool = false,
	p_scale: Vector2 = Vector2(1.5, 1.5),
	s_radius: Vector2 = Vector2(36.0, 18.0),
	sound: String = "click"
) -> Node2D:
	var p = RegionalPropScript.new()
	p.name = "Prop_" + prop_name.replace(" ", "_")
	p.prop_name = prop_name
	p.prop_category = prop_category
	p.prop_description = prop_desc
	p.is_flipped = flipped
	p.prop_scale = p_scale
	p.shadow_radius = s_radius
	p.sound_name = sound

	if ResourceLoader.exists(tex_path):
		p.prop_texture = load(tex_path) as Texture2D
	if tex_flipped_path != "" and ResourceLoader.exists(tex_flipped_path):
		p.prop_texture_flipped = load(tex_flipped_path) as Texture2D

	var world_pos := Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (grid_pos.x - grid_pos.y) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (grid_pos.x + grid_pos.y + 1.0) * FarmerMovement.HALF_H
	)
	p.position = world_pos
	props_layer.add_child(p)
	return p
