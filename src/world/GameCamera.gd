# GameCamera.gd
# Keyboard navigation & zoom.
# Features:
#   - Keyboard pan (WASD or Arrow Keys)
#   - Smooth mouse wheel zoom (0.58x to 1.8x)
#   - Clamped boundaries around the farm world
#   - Automatically pauses keyboard pan when full modal menus are open

class_name GameCamera
extends Camera2D

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
@export var edge_scroll_enabled: bool = false  # Disabled: camera uses pure WASD keyboard navigation
@export var pan_speed: float          = 620.0  # Pixels per second at 1.0 zoom
@export var keyboard_speed: float     = 620.0

# Zoom settings
@export var min_zoom: float           = 0.45
@export var max_zoom: float           = 1.80
@export var zoom_step: float          = 0.12
@export var zoom_smoothness: float    = 14.0

# World boundary limits (outer visible bounds that viewport edges must never cross)
@export var world_bounds_min: Vector2 = Vector2(-1550, -320)
@export var world_bounds_max: Vector2 = Vector2(3400, 2480)

# Backward compatibility aliases
var limit_min: Vector2:
	get: return world_bounds_min
	set(v): world_bounds_min = v
var limit_max: Vector2:
	get: return world_bounds_max
	set(v): world_bounds_max = v

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var target_position: Vector2 = Vector2.ZERO
var target_zoom: Vector2     = Vector2.ONE
var is_dragging: bool        = false

@onready var hud_layer: CanvasLayer = get_parent().get_node_or_null("HUDLayer")

func _ready() -> void:
	enabled = true
	# Center camera on the 2.5D isometric farm island (16x16 homestead center is (768, 576))
	var farm = get_parent().get_node_or_null("FarmGrid")
	if farm:
		position = farm.position + Vector2(768.0, 576.0)
	else:
		position = Vector2(768.0, 576.0)

	target_zoom     = zoom
	target_position = _clamp_to_world_bounds(position, target_zoom.x)
	position        = target_position

## Clamps camera position dynamically so viewport edges NEVER exceed world sprite bounds
func _clamp_to_world_bounds(pos: Vector2, cur_zoom: float) -> Vector2:
	var vp := get_viewport()
	var vp_size: Vector2 = vp.get_visible_rect().size if vp else Vector2(1280, 720)
	var z: float = max(0.1, cur_zoom)
	var half_vp: Vector2 = (vp_size * 0.5) / z

	var min_x: float = world_bounds_min.x + half_vp.x
	var max_x: float = world_bounds_max.x - half_vp.x
	var min_y: float = world_bounds_min.y + half_vp.y
	var max_y: float = world_bounds_max.y - half_vp.y

	var clamped := Vector2.ZERO
	if min_x > max_x:
		clamped.x = (world_bounds_min.x + world_bounds_max.x) * 0.5
	else:
		clamped.x = clampf(pos.x, min_x, max_x)

	if min_y > max_y:
		clamped.y = (world_bounds_min.y + world_bounds_max.y) * 0.5
	else:
		clamped.y = clampf(pos.y, min_y, max_y)

	return clamped

func pan_to(world_pos: Vector2) -> void:
	target_position = _clamp_to_world_bounds(world_pos, target_zoom.x)

func center_on_homestead() -> void:
	var farm = get_parent().get_node_or_null("FarmGrid")
	if farm:
		pan_to(farm.position + Vector2(768.0, 576.0))
	else:
		pan_to(Vector2(768.0, 576.0))

func _process(delta: float) -> void:
	var move_dir := Vector2.ZERO

	# 1. Keyboard WASD / Arrow Keys Pan
	if not _is_typing_or_menu_open():
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move_dir.y += 1.0

	if move_dir != Vector2.ZERO:
		var speed: float = pan_speed / max(0.2, zoom.x)
		target_position += move_dir.normalized() * speed * delta

	# Clamp target position dynamically so viewport edges NEVER exceed world sprite bounds
	target_position = _clamp_to_world_bounds(target_position, target_zoom.x)

	# Smoothly interpolate position and zoom
	position = position.lerp(target_position, 12.0 * delta)
	zoom     = zoom.lerp(target_zoom, zoom_smoothness * delta)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse Wheel Zoom
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and not _is_typing_or_menu_open():
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_adjust_zoom(1.0 + zoom_step)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_zoom(1.0 - zoom_step)
				get_viewport().set_input_as_handled()

func _adjust_zoom(factor: float) -> void:
	var new_val: float = clampf(target_zoom.x * factor, min_zoom, max_zoom)
	target_zoom = Vector2(new_val, new_val)
	target_position = _clamp_to_world_bounds(target_position, target_zoom.x)

func _is_typing_or_menu_open() -> bool:
	if hud_layer:
		var market = hud_layer.find_child("MarketPanel", true, false)
		if market and market.visible:
			return true
		var sell = hud_layer.find_child("SellPanel", true, false)
		if sell and sell.visible:
			return true
		var shop = hud_layer.find_child("ShopPanel", true, false)
		if shop and shop.visible:
			return true
	var admin = get_tree().root.find_child("AdminPanel", true, false)
	if admin and admin.visible:
		return true
	var pause = get_tree().root.find_child("PauseMenu", true, false)
	if pause and pause.visible:
		return true
	return false
