# GameCamera.gd
# WoW / RTS-style full-screen camera navigation.
# Features:
#   - Side-of-screen edge scrolling (pan camera by moving mouse to viewport edges)
#   - Mouse drag panning (Middle-mouse drag or Right-mouse drag)
#   - Keyboard pan (WASD or Arrow Keys)
#   - Smooth mouse wheel zoom (0.55x to 1.6x)
#   - Clamped boundaries around the farm world
#   - Automatically pauses edge-scrolling when full modal menus are open

class_name GameCamera
extends Camera2D

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
@export var edge_scroll_enabled: bool = true
@export var edge_margin: float        = 28.0   # Pixels from screen edge to trigger pan
@export var pan_speed: float          = 620.0  # Pixels per second at 1.0 zoom
@export var keyboard_speed: float     = 620.0
@export var drag_speed: float         = 1.0

# Zoom settings
@export var min_zoom: float           = 0.58
@export var max_zoom: float           = 1.80
@export var zoom_step: float          = 0.12
@export var zoom_smoothness: float    = 14.0

# World boundary limits (outer visible bounds that viewport edges must never cross)
@export var world_bounds_min: Vector2 = Vector2(-950, -220)
@export var world_bounds_max: Vector2 = Vector2(2500, 1880)

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
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_cam: Vector2   = Vector2.ZERO
var drag_button_used: int     = -1

@onready var hud_layer: CanvasLayer = get_parent().get_node_or_null("HUDLayer")

func _ready() -> void:
	enabled = true
	# Center camera on the 2.5D isometric farm island (homestead center is (768, 480))
	var farm = get_parent().get_node_or_null("FarmGrid")
	if farm:
		position = farm.position + Vector2(768.0, 480.0)
	else:
		position = Vector2(768.0, 480.0)

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
		pan_to(farm.position + Vector2(768.0, 480.0))
	else:
		pan_to(Vector2(768.0, 480.0))

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

	# 2. Side-of-Screen Edge Scrolling (WoW / RTS style)
	if edge_scroll_enabled and not is_dragging and not _is_typing_or_menu_open():
		var vp := get_viewport()
		if vp:
			var vp_size := vp.get_visible_rect().size
			var mouse_pos := vp.get_mouse_position()

			# Only trigger if the mouse is inside the game window
			if mouse_pos.x >= 0 and mouse_pos.x <= vp_size.x and mouse_pos.y >= 0 and mouse_pos.y <= vp_size.y:
				# Left edge
				if mouse_pos.x < edge_margin:
					var factor: float = clampf((edge_margin - mouse_pos.x) / edge_margin, 0.2, 1.0)
					move_dir.x -= factor
				# Right edge
				elif mouse_pos.x > vp_size.x - edge_margin:
					var factor: float = clampf((mouse_pos.x - (vp_size.x - edge_margin)) / edge_margin, 0.2, 1.0)
					move_dir.x += factor

				# Top edge
				if mouse_pos.y < edge_margin:
					var factor: float = clampf((edge_margin - mouse_pos.y) / edge_margin, 0.2, 1.0)
					move_dir.y -= factor
				# Bottom edge
				elif mouse_pos.y > vp_size.y - edge_margin:
					var factor: float = clampf((mouse_pos.y - (vp_size.y - edge_margin)) / edge_margin, 0.2, 1.0)
					move_dir.y += factor

	if move_dir != Vector2.ZERO:
		var speed: float = pan_speed / max(0.2, zoom.x)
		target_position += move_dir.normalized() * speed * delta

	# Clamp target position dynamically so viewport edges NEVER exceed world sprite bounds
	target_position = _clamp_to_world_bounds(target_position, target_zoom.x)

	# Smoothly interpolate position and zoom
	position = position.lerp(target_position, 12.0 * delta)
	zoom     = zoom.lerp(target_zoom, zoom_smoothness * delta)

func _unhandled_input(event: InputEvent) -> void:
	# Middle-mouse drag panning
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				is_dragging = true
				drag_start_mouse = mb.global_position
				drag_start_cam   = target_position
				drag_button_used = MOUSE_BUTTON_MIDDLE
				get_viewport().set_input_as_handled()
			else:
				is_dragging = false
				drag_button_used = -1

		# Mouse Wheel Zoom
		elif mb.pressed and not _is_typing_or_menu_open():
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_adjust_zoom(1.0 + zoom_step)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_zoom(1.0 - zoom_step)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_dragging:
		var mm := event as InputEventMouseMotion
		var delta_mouse: Vector2 = (mm.global_position - drag_start_mouse) / zoom.x
		target_position = _clamp_to_world_bounds(drag_start_cam - delta_mouse, target_zoom.x)
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
