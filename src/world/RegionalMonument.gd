# RegionalMonument.gd
# Interactive 2.5D Regional Monument Landmark Node.
# Features:
#   - Authentic Philippine regional monument sprite with nearest-neighbor pixel art filter
#   - Paved isometric stone plinth with 3D depth and soft drop shadow
#   - Interactive hover tooltip card with rich historical lore and cultural significance
#   - Interactive click celebrating the landmark with audio chime, bounce animation, and Chronicle log

class_name RegionalMonument
extends Node2D

signal clicked(monument_name: String)

@export var monument_id: String = ""
@export var monument_title: String = "Regional Monument"
@export var monument_subtitle: String = "Historical Landmark"
@export_multiline var monument_lore: String = "A cherished historical monument celebrating regional culture and heritage."
@export var monument_texture: Texture2D = null
@export var monument_texture_flipped: Texture2D = null
@export var is_flipped: bool = false
@export var sprite_scale: Vector2 = Vector2(1.8, 1.8)
@export var pedestal_radius: Vector2 = Vector2(56.0, 28.0)
@export var pedestal_color: Color = Color(0.38, 0.34, 0.30, 0.95)

var sprite_node: Sprite2D = null
var hover_btn: Button = null
var tooltip_card: PanelContainer = null
var _tween: Tween = null

func _init() -> void:
	z_index = 10
	y_sort_enabled = true

func _ready() -> void:
	_create_pedestal()
	_create_sprite()
	_create_interaction()
	_create_tooltip_card()

func _create_pedestal() -> void:
	# 1. Soft isometric shadow
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.z_index = -2
	var s_rx: float = pedestal_radius.x * 1.15
	var s_ry: float = pedestal_radius.y * 1.15
	shadow.polygon = PackedVector2Array([
		Vector2(0, -s_ry),
		Vector2(s_rx, 0),
		Vector2(0, s_ry),
		Vector2(-s_rx, 0)
	])
	shadow.color = Color(0.08, 0.12, 0.08, 0.40)
	add_child(shadow)

	# 2. 3D Isometric Stone Plinth Depth Slab
	var slab := Polygon2D.new()
	slab.name = "PlinthSlab"
	slab.z_index = -1
	var rx: float = pedestal_radius.x
	var ry: float = pedestal_radius.y
	slab.polygon = PackedVector2Array([
		Vector2(-rx, 0),
		Vector2(0, ry),
		Vector2(rx, 0),
		Vector2(rx, 10),
		Vector2(0, ry + 10),
		Vector2(-rx, 10)
	])
	slab.color = Color(0.24, 0.22, 0.20, 0.95)
	add_child(slab)

	# 3. Top Stone Plinth Surface
	var top_plinth := Polygon2D.new()
	top_plinth.name = "PlinthTop"
	top_plinth.z_index = -1
	top_plinth.polygon = PackedVector2Array([
		Vector2(0, -ry),
		Vector2(rx, 0),
		Vector2(0, ry),
		Vector2(-rx, 0)
	])
	top_plinth.color = pedestal_color
	add_child(top_plinth)

	# 4. Stone border seam
	var border := Line2D.new()
	border.name = "PlinthBorder"
	border.z_index = -1
	border.width = 1.5
	border.default_color = Color(0.55, 0.50, 0.42, 0.85)
	border.closed = true
	border.add_point(Vector2(0, -ry))
	border.add_point(Vector2(rx, 0))
	border.add_point(Vector2(0, ry))
	border.add_point(Vector2(-rx, 0))
	add_child(border)

func _create_sprite() -> void:
	sprite_node = Sprite2D.new()
	sprite_node.name = "MonumentSprite"
	sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var tex: Texture2D = monument_texture
	if is_flipped and monument_texture_flipped:
		tex = monument_texture_flipped
	sprite_node.texture = tex
	sprite_node.scale = sprite_scale

	if tex:
		var tsz := tex.get_size()
		# Align bottom base of statue to top of stone pedestal
		sprite_node.offset = Vector2(0, -tsz.y * 0.46)

	add_child(sprite_node)

func _create_interaction() -> void:
	hover_btn = Button.new()
	hover_btn.name = "InteractionArea"
	hover_btn.flat = true
	hover_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var h_w: float = pedestal_radius.x * 2.2
	var h_h: float = pedestal_radius.y * 2.0 + 90.0
	hover_btn.custom_minimum_size = Vector2(h_w, h_h)
	hover_btn.position = Vector2(-h_w * 0.5, -h_h + pedestal_radius.y)

	var empty_sb := StyleBoxEmpty.new()
	hover_btn.add_theme_stylebox_override("normal", empty_sb)
	hover_btn.add_theme_stylebox_override("hover", empty_sb)
	hover_btn.add_theme_stylebox_override("pressed", empty_sb)
	hover_btn.add_theme_stylebox_override("focus", empty_sb)

	hover_btn.mouse_entered.connect(_on_mouse_entered)
	hover_btn.mouse_exited.connect(_on_mouse_exited)
	hover_btn.pressed.connect(_on_clicked)
	add_child(hover_btn)

func _create_tooltip_card() -> void:
	tooltip_card = PanelContainer.new()
	tooltip_card.name = "TooltipCard"
	tooltip_card.visible = false
	tooltip_card.z_index = 250
	tooltip_card.z_as_relative = false
	tooltip_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.13, 0.96)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.90, 0.78, 0.35, 0.95)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	tooltip_card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	tooltip_card.add_child(vbox)

	# 1. Header category
	var header := Label.new()
	header.text = "🏛️ REGIONAL HERITAGE MONUMENT"
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(header)

	# 2. Monument title
	var title_lbl := Label.new()
	title_lbl.text = monument_title
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(title_lbl)

	# 3. Subtitle / Location
	var sub_lbl := Label.new()
	sub_lbl.text = monument_subtitle
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.45, 0.90, 0.75))
	vbox.add_child(sub_lbl)

	# Divider line
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.85, 0.75, 0.35, 0.40)
	vbox.add_child(div)

	# 4. Historical Lore blurb
	var lore_lbl := Label.new()
	lore_lbl.text = monument_lore
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_lbl.custom_minimum_size = Vector2(250, 0)
	lore_lbl.add_theme_font_size_override("font_size", 10)
	lore_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	vbox.add_child(lore_lbl)

	# 5. Interaction hint
	var hint_lbl := Label.new()
	hint_lbl.text = "✨ Click to celebrate landmark & record in Chronicle"
	hint_lbl.add_theme_font_size_override("font_size", 9)
	hint_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	vbox.add_child(hint_lbl)

	# Position card nicely centered above monument
	tooltip_card.position = Vector2(-135, -230)
	add_child(tooltip_card)

func _on_mouse_entered() -> void:
	if tooltip_card:
		tooltip_card.visible = true
	if sprite_node:
		var t := create_tween()
		t.tween_property(sprite_node, "modulate", Color(1.20, 1.20, 1.15, 1.0), 0.15)

func _on_mouse_exited() -> void:
	if tooltip_card:
		tooltip_card.visible = false
	if sprite_node:
		var t := create_tween()
		t.tween_property(sprite_node, "modulate", Color.WHITE, 0.20)

func _on_clicked() -> void:
	var audio_mgr = get_tree().root.get_node_or_null("AudioManager") if is_inside_tree() else null
	if audio_mgr and audio_mgr.has_method("play_ui"):
		audio_mgr.play_ui("tile_select")

	if sprite_node:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(sprite_node, "scale", sprite_scale * 1.15, 0.12)
		_tween.tween_property(sprite_node, "scale", sprite_scale, 0.25)

	var log_mgr = get_tree().root.get_node_or_null("LogManager") if is_inside_tree() else null
	if log_mgr and log_mgr.has_method("log_event"):
		log_mgr.log_event(
			"system",
			"🏛️ Celebrated Landmark: %s (%s)" % [monument_title, monument_subtitle],
			"🏛️",
			Color(1.0, 0.85, 0.30),
			monument_lore
		)
	clicked.emit(monument_title)
