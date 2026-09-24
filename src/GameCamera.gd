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
@export var min_zoom: float           = 0.55
@export var max_zoom: float           = 1.60
@export var zoom_step: float          = 0.12
@export var zoom_smoothness: float    = 14.0

# World boundary limits (clamped camera center)
@export var limit_min: Vector2        = Vector2(-250, -200)
@export var limit_max: Vector2        = Vector2(1050, 1000)

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
	# Center camera on the farm grid by default (farm is 768x768 at 1.0 scale)
	var farm = get_parent().get_node_or_null("FarmGrid")
	if farm:
		var farm_center: Vector2 = farm.position + Vector2(384, 384) * farm.scale
		position = farm_center
	else:
		position = Vector2(384, 384)

	target_position = position
	target_zoom     = zoom

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

	# Clamp target position to world boundaries
	target_position.x = clampf(target_position.x, limit_min.x, limit_max.x)
	target_position.y = clampf(target_position.y, limit_min.y, limit_max.y)

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
		target_position = drag_start_cam - delta_mouse
		target_position.x = clampf(target_position.x, limit_min.x, limit_max.x)
		target_position.y = clampf(target_position.y, limit_min.y, limit_max.y)
		get_viewport().set_input_as_handled()

func _adjust_zoom(factor: float) -> void:
	var new_val: float = clampf(target_zoom.x * factor, min_zoom, max_zoom)
	target_zoom = Vector2(new_val, new_val)

func _is_typing_or_menu_open() -> bool:
	if hud_layer:
		var market = hud_layer.get_node_or_null("Control/MarketPanel")
		if market and market.visible:
			return true
		var shop = hud_layer.get_node_or_null("Control/ShopPanel")
		if shop and shop.visible:
			return true
	var admin = get_parent().get_node_or_null("AdminPanel")
	if admin and admin.visible:
		return true
	return false
