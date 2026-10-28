# RegionalStreamOverlay.gd
# Renders organic, living natural water features in the out-of-bounds landscape:
#   - Cotabato: Winding Pulangi tributary river stream with alluvial banks
#   - South Cotabato: Cascading mountain brook with stony alpine banks
#   - Sultan Kudarat: Agricultural irrigation canal network feeding the valley
#   - Sarangani: Coastal tide pools and shell shoals in the sand
#   - General Santos: Stone-lined seaport drainage canal & water channel

class_name RegionalStreamOverlay
extends Node2D

@export var region_key: String = ""

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
	queue_redraw()

func _get_iso_pt(gx: float, gy: float) -> Vector2:
	return Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (gx + gy + 1.0) * FarmerMovement.HALF_H
	)

func _draw() -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var reg := region_key
	if reg == "":
		var data_node = get_tree().root.get_node_or_null("Data") if is_inside_tree() else null
		if data_node and "current_region" in data_node:
			reg = data_node.current_region
		else:
			reg = "cotabato"

	match reg:
		"cotabato":
			_draw_cotabato_river_stream(t)
		"south_cotabato":
			_draw_south_cotabato_mountain_brook(t)
		"sultan_kudarat":
			_draw_sultan_kudarat_irrigation_canal(t)
		"sarangani":
			_draw_sarangani_tide_pools(t)
		"general_santos":
			_draw_gensan_drainage_canal(t)

## Cotabato: Meandering Pulangi tributary stream through NW periphery
func _draw_cotabato_river_stream(t: float) -> void:
	var pts := PackedVector2Array()
	# Curves along the northwestern wilderness from (-8, 14) to (-2, -5) to (14, -7)
	for i in range(24):
		var frac: float = float(i) / 23.0
		var gx: float = lerpf(-7.5, 12.0, frac) + sin(frac * 4.0 + 0.5) * 2.2
		var gy: float = lerpf(12.0, -6.5, frac) + cos(frac * 3.5) * 1.8
		pts.append(_get_iso_pt(gx, gy))

	if pts.size() >= 2:
		# Muddy riverbank base
		draw_polyline(pts, Color(0.24, 0.20, 0.14, 0.95), 26.0)
		# Moist alluvial mud margin
		draw_polyline(pts, Color(0.18, 0.30, 0.22, 0.90), 18.0)
		# Deep river water channel
		draw_polyline(pts, Color(0.08, 0.32, 0.36, 0.95), 12.0)
		# Flowing water highlights
		var wave_alpha: float = 0.55 + 0.25 * sin(t * 2.0)
		draw_polyline(pts, Color(0.35, 0.72, 0.68, wave_alpha), 5.0)

		# Animated flow ripplets
		for i in range(6):
			var idx: int = (int(t * 4.0) + i * 4) % pts.size()
			var p: Vector2 = pts[idx]
			draw_circle(p + Vector2(sin(t + float(i)) * 3.0, 0), 2.2, Color(0.85, 0.96, 0.94, 0.60))

## South Cotabato: Cascading mountain brook with stony alpine bed
func _draw_south_cotabato_mountain_brook(t: float) -> void:
	var pts := PackedVector2Array()
	# Mountain stream cascading down the northern slope
	for i in range(18):
		var frac: float = float(i) / 17.0
		var gx: float = lerpf(5.0, 22.0, frac) + sin(frac * 5.0) * 1.5
		var gy: float = lerpf(-7.5, -3.5, frac) + cos(frac * 4.0) * 1.0
		pts.append(_get_iso_pt(gx, gy))

	if pts.size() >= 2:
		# Volcanic stone creekbed
		draw_polyline(pts, Color(0.20, 0.22, 0.25, 0.95), 20.0)
		# Mountain moss edges
		draw_polyline(pts, Color(0.15, 0.35, 0.25, 0.85), 14.0)
		# Crystal alpine water
		draw_polyline(pts, Color(0.10, 0.35, 0.55, 0.95), 8.0)
		# Fast-moving bubbly white foam crest
		var foam_alpha: float = 0.60 + 0.30 * sin(t * 3.5)
		draw_polyline(pts, Color(0.85, 0.94, 1.0, foam_alpha), 3.0)

## Sultan Kudarat: Straight agricultural irrigation canal network
func _draw_sultan_kudarat_irrigation_canal(t: float) -> void:
	# Canal segment along northern farm border
	var pts_n := PackedVector2Array([
		_get_iso_pt(-2.5, -2.5),
		_get_iso_pt(15.0, -2.5),
		_get_iso_pt(31.0, -2.5)
	])
	# Canal segment along southern farm border
	var pts_s := PackedVector2Array([
		_get_iso_pt(-2.5, 33.5),
		_get_iso_pt(16.0, 33.5),
		_get_iso_pt(31.0, 33.5)
	])

	for pts in [pts_n, pts_s]:
		# Excavated earth embankments
		draw_polyline(pts, Color(0.40, 0.30, 0.18, 0.95), 16.0)
		# Canal stone/clay lining
		draw_polyline(pts, Color(0.32, 0.26, 0.18, 0.90), 10.0)
		# Flowing irrigation water
		draw_polyline(pts, Color(0.15, 0.40, 0.42, 0.95), 6.0)
		var flow_a: float = 0.50 + 0.20 * sin(t * 1.8)
		draw_polyline(pts, Color(0.45, 0.75, 0.72, flow_a), 2.5)

## Sarangani: Coastal tide pools and shell shoals along the beach dunes
func _draw_sarangani_tide_pools(t: float) -> void:
	var pool_centers: Array[Vector2] = [
		Vector2(28.0, -3.0),
		Vector2(30.0, -5.0),
		Vector2(28.5, 34.0),
		Vector2(30.5, 35.5)
	]
	for pc in pool_centers:
		var pt := _get_iso_pt(pc.x, pc.y)
		# Wet sand depression
		draw_circle(pt, 16.0, Color(0.70, 0.62, 0.46, 0.85))
		# Clear turquoise tide pool water
		var r_wave: float = 12.0 + sin(t * 1.2 + pc.x) * 1.2
		draw_circle(pt, r_wave, Color(0.12, 0.55, 0.65, 0.80))
		draw_circle(pt + Vector2(-2, -2), 4.0, Color(0.85, 0.98, 1.0, 0.50))

## General Santos: Heavy stone-lined drainage culvert
func _draw_gensan_drainage_canal(t: float) -> void:
	var pts := PackedVector2Array([
		_get_iso_pt(-2.5, -2.5),
		_get_iso_pt(14.0, -2.5),
		_get_iso_pt(31.0, -2.5)
	])
	# Concrete culvert channel
	draw_polyline(pts, Color(0.28, 0.30, 0.32, 0.98), 16.0)
	draw_polyline(pts, Color(0.42, 0.44, 0.46, 0.95), 10.0)
	# Channel water
	draw_polyline(pts, Color(0.10, 0.22, 0.32, 0.92), 5.0)
	var wake: float = 0.40 + 0.20 * sin(t * 1.5)
	draw_polyline(pts, Color(0.35, 0.55, 0.70, wake), 2.0)

