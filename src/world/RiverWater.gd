# RiverWater.gd
# Renders the animated freshwater river canal representing the Rio Grande de Mindanao / Pulangi River Basin.
# Flows along the southern riverbank perimeter with animated freshwater ripples,
# creating an authentic river delta environment for Cotabato.

class_name RiverWater
extends Node2D

var _river_textures: Array[Texture2D] = []

func _init() -> void:
	z_index = -40
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_textures()

func _load_textures() -> void:
	for i in range(1, 6):
		var path := "res://assets/sprites/water/water_%02d.png" % i
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_river_textures.append(tex)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001

	# Helper to get isometric world point
	var get_pt = func(gx: float, gy: float) -> Vector2:
		return Vector2(
			FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
			FarmerMovement.ORIGIN_OFFSET.y + (gx + gy + 1.0) * FarmerMovement.HALF_H
		)

	# 1. Broad River Basin Waterway Polygon along the south-western flank
	# (gy from 32.5 out to 42.0, gx from -8.0 to 34.0)
	var river_poly := PackedVector2Array([
		get_pt.call(-8.0, 32.5),
		get_pt.call(34.0, 32.5),
		get_pt.call(34.0, 42.0),
		get_pt.call(-8.0, 42.0)
	])
	draw_colored_polygon(river_poly, Color(0.10, 0.32, 0.40, 0.98))

	# 2. Shallow Riverbank Shelf (alluvial silt & clear fresh water)
	var bank_poly := PackedVector2Array([
		get_pt.call(-8.0, 32.5),
		get_pt.call(34.0, 32.5),
		get_pt.call(34.0, 35.0),
		get_pt.call(-8.0, 35.0)
	])
	draw_colored_polygon(bank_poly, Color(0.16, 0.44, 0.52, 0.85))

	# 3. Animated River Surface Tiles
	if not _river_textures.is_empty():
		for gy in range(33, 41):
			for gx in range(-6, 33):
				var pos_px: Vector2 = get_pt.call(float(gx), float(gy))
				var flow: float = sin(t * 1.2 + float(gx) * 0.45 - float(gy) * 0.25)
				var frame_idx: int = int(abs(flow) * float(_river_textures.size())) % _river_textures.size()
				var tex: Texture2D = _river_textures[frame_idx]
				if tex:
					var rect := Rect2(pos_px - Vector2(64, 32), Vector2(128, 64))
					draw_texture_rect(tex, rect, false, Color(0.85, 0.95, 1.0, 0.70))

	# 4. Gentle River Current Foam Streaks
	for i in range(12):
		var rx: float = float(i * 3 - 6) + sin(t * 0.6 + float(i)) * 2.0
		var ry: float = 33.2 + float(i % 5) * 1.4
		var p_start: Vector2 = get_pt.call(rx, ry)
		var p_end: Vector2 = get_pt.call(rx + 1.8, ry + 0.3)
		draw_line(p_start, p_end, Color(0.80, 0.95, 0.98, 0.45), 2.0)

