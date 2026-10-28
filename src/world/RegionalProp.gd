# RegionalProp.gd
# Interactive 2.5D Regional Cultural Decoration & Prop Node.
# Represents authentic Philippine provincial features (buko stalls, basketball courts,
# tricycles, fiesta arches, checkpoints, boulders, etc.) with nearest-neighbor pixel art,
# contact shadows, hover tooltips, and click feedback.

class_name RegionalProp
extends Node2D

@export var prop_name: String = "Cultural Prop"
@export var prop_category: String = "Regional Cultural Element"
@export_multiline var prop_description: String = "A distinctive cultural feature reflecting local daily life and heritage."
@export var prop_texture: Texture2D = null
@export var prop_texture_flipped: Texture2D = null
@export var is_flipped: bool = false
@export var prop_scale: Vector2 = Vector2(1.5, 1.5)
@export var shadow_radius: Vector2 = Vector2(36.0, 18.0)
@export var sound_name: String = "click"

var sprite_node: Sprite2D = null
var hover_btn: Button = null
var tooltip_card: PanelContainer = null
var _tween: Tween = null

func _init() -> void:
	z_index = 10
	y_sort_enabled = true

func _ready() -> void:
	_create_shadow()
	_create_sprite()
	_create_interaction()
	_create_tooltip()

func _create_shadow() -> void:
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.z_index = -1
	var rx: float = shadow_radius.x
	var ry: float = shadow_radius.y
	shadow.polygon = PackedVector2Array([
		Vector2(0, -ry),
		Vector2(rx, 0),
		Vector2(0, ry),
		Vector2(-rx, 0)
	])
	shadow.color = Color(0.06, 0.10, 0.06, 0.35)
	add_child(shadow)

func _create_sprite() -> void:
	sprite_node = Sprite2D.new()
	sprite_node.name = "PropSprite"
	sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var tex: Texture2D = prop_texture
	if is_flipped and prop_texture_flipped:
		tex = prop_texture_flipped
	sprite_node.texture = tex
	sprite_node.scale = prop_scale

	if tex:
		var tsz := tex.get_size()
		# Align bottom contact point to ground shadow
		sprite_node.offset = Vector2(0, -tsz.y * 0.44)

	add_child(sprite_node)

func _create_interaction() -> void:
	hover_btn = Button.new()
	hover_btn.name = "HoverArea"
	hover_btn.flat = true
	hover_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var h_w: float = shadow_radius.x * 2.2
	var h_h: float = shadow_radius.y * 2.0 + 50.0
	hover_btn.custom_minimum_size = Vector2(h_w, h_h)
	hover_btn.position = Vector2(-h_w * 0.5, -h_h + shadow_radius.y)

	var empty_sb := StyleBoxEmpty.new()
	hover_btn.add_theme_stylebox_override("normal", empty_sb)
	hover_btn.add_theme_stylebox_override("hover", empty_sb)
	hover_btn.add_theme_stylebox_override("pressed", empty_sb)
	hover_btn.add_theme_stylebox_override("focus", empty_sb)

	hover_btn.mouse_entered.connect(_on_mouse_entered)
	hover_btn.mouse_exited.connect(_on_mouse_exited)
	hover_btn.pressed.connect(_on_clicked)
	add_child(hover_btn)

func _create_tooltip() -> void:
	tooltip_card = PanelContainer.new()
	tooltip_card.name = "TooltipCard"
	tooltip_card.visible = false
	tooltip_card.z_index = 240
	tooltip_card.z_as_relative = false
	tooltip_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.13, 0.95)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.70, 0.85, 0.65, 0.85)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	tooltip_card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	tooltip_card.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = prop_name
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = prop_description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(180, 0)
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.80))
	vbox.add_child(desc_lbl)

	tooltip_card.position = Vector2(-95, -120)
	add_child(tooltip_card)

func _on_mouse_entered() -> void:
	if tooltip_card:
		tooltip_card.visible = true
	if sprite_node:
		var t := create_tween()
		t.tween_property(sprite_node, "modulate", Color(1.15, 1.15, 1.12, 1.0), 0.15)

func _on_mouse_exited() -> void:
	if tooltip_card:
		tooltip_card.visible = false
	if sprite_node:
		var t := create_tween()
		t.tween_property(sprite_node, "modulate", Color.WHITE, 0.15)

func _on_clicked() -> void:
	var audio_mgr = get_tree().root.get_node_or_null("AudioManager") if is_inside_tree() else null
	if audio_mgr and audio_mgr.has_method("play_ui"):
		audio_mgr.play_ui(sound_name)
	if sprite_node:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(sprite_node, "scale", prop_scale * 1.12, 0.10)
		_tween.tween_property(sprite_node, "scale", prop_scale, 0.20)
