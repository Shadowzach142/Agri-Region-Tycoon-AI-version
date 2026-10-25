# MarketChart.gd
# Custom CanvasItem stock chart rendering 7-day price fluctuations,
# base price benchmarks, area shading, and dynamic rising/falling visual trends.

class_name MarketChart
extends Control

var crop_key: String = ""
var crop_name: String = ""
var price_data: Array = []
var base_price: float = 100.0

const COLOR_UP_LINE   := Color(0.28, 0.94, 0.45, 1.0)
const COLOR_UP_FILL   := Color(0.28, 0.94, 0.45, 0.18)
const COLOR_DOWN_LINE := Color(1.00, 0.38, 0.38, 1.0)
const COLOR_DOWN_FILL := Color(1.00, 0.38, 0.38, 0.18)
const COLOR_GRID      := Color(1.00, 1.00, 1.00, 0.08)
const COLOR_BASE_LINE := Color(0.95, 0.75, 0.30, 0.45)
const COLOR_MUTED_TXT := Color(0.92, 0.96, 0.92, 1.0)

func _ready() -> void:
	custom_minimum_size = Vector2(460, 180)

## Feed new dataset to the chart and trigger immediate redraw
func set_chart_data(c_key: String, c_name: String, history: Array, base_p: float) -> void:
	crop_key = c_key
	crop_name = c_name
	price_data = history.duplicate()
	base_price = maxf(base_p, 1.0)
	queue_redraw()

func _draw() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return

	var full_rect := Rect2(Vector2.ZERO, size)

	# 1. Dark sleek chart container background
	draw_rect(full_rect, Color(0.06, 0.09, 0.06, 0.95), true)
	draw_rect(full_rect, Color(0.24, 0.34, 0.22, 0.85), false, 1.5)

	# 2. Graph plot region boundaries
	var pad_left: float   = 52.0
	var pad_right: float  = 28.0
	var pad_top: float    = 24.0
	var pad_bottom: float = 26.0

	var gr := Rect2(pad_left, pad_top, maxf(size.x - pad_left - pad_right, 40.0), maxf(size.y - pad_top - pad_bottom, 30.0))

	if price_data.is_empty():
		draw_string(font, Vector2(size.x * 0.35, size.y * 0.5), "No price history available", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, COLOR_MUTED_TXT)
		return

	# 3. Determine price range (min/max with 15% headroom)
	var min_val: float = base_price
	var max_val: float = base_price
	for p in price_data:
		var v: float = float(p)
		if v < min_val: min_val = v
		if v > max_val: max_val = v

	var spread: float = maxf(max_val - min_val, 12.0)
	var y_min: float  = maxf(min_val - spread * 0.18, 5.0)
	var y_max: float  = max_val + spread * 0.18
	var y_range: float = maxf(y_max - y_min, 1.0)

	# Helper to map price to Y-coordinate
	var to_y = func(val: float) -> float:
		return gr.position.y + gr.size.y * (1.0 - clampf((val - y_min) / y_range, 0.0, 1.0))

	# 4. Subtle horizontal grid lines & price tags
	var grid_levels := [y_max - spread * 0.08, (y_min + y_max) * 0.5, y_min + spread * 0.08]
	for val in grid_levels:
		var gy: float = to_y.call(val)
		draw_line(Vector2(gr.position.x, gy), Vector2(gr.end.x, gy), COLOR_GRID, 1.0)
		draw_string(font, Vector2(6, gy + 4), "₱%d" % int(round(val)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_MUTED_TXT)

	# 5. Base Price Benchmark dashed guideline
	var base_y: float = to_y.call(base_price)
	var x_step: float = 6.0
	var cx: float = gr.position.x
	while cx < gr.end.x:
		draw_line(Vector2(cx, base_y), Vector2(minf(cx + 3.5, gr.end.x), base_y), COLOR_BASE_LINE, 1.2)
		cx += x_step

	var base_txt: String = "Base ₱%d" % int(base_price)
	draw_string(font, Vector2(gr.end.x - 62, base_y - 4), base_txt, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(1.0, 0.88, 0.45, 1.0))

	# 6. Plot data points & polyline
	var n: int = price_data.size()
	var points: PackedVector2Array = []
	for i in range(n):
		var px: float = gr.position.x + (float(i) / float(maxi(n - 1, 1))) * gr.size.x
		var py: float = to_y.call(float(price_data[i]))
		points.append(Vector2(px, py))

	var is_rising: bool = true
	if n >= 2:
		is_rising = float(price_data[-1]) >= float(price_data[-2])

	var line_col: Color = COLOR_UP_LINE if is_rising else COLOR_DOWN_LINE
	var fill_col: Color = COLOR_UP_FILL if is_rising else COLOR_DOWN_FILL

	# Shaded area polygon under line
	if points.size() >= 2:
		var poly: PackedVector2Array = []
		poly.append(Vector2(points[0].x, gr.end.y))
		for pt in points:
			poly.append(pt)
		poly.append(Vector2(points[-1].x, gr.end.y))
		draw_colored_polygon(poly, fill_col)

		draw_polyline(points, line_col, 2.5, true)

	# 7. Draw dots at data points
	for i in range(points.size()):
		var pt := points[i]
		if i == points.size() - 1:
			# Today's active glowing point
			draw_circle(pt, 6.0, line_col)
			draw_circle(pt, 3.5, Color.WHITE)
			draw_circle(pt, 1.5, Color(0.1, 0.1, 0.1))

			# Active price tag pill above point
			var curr_val: int = int(round(float(price_data[i])))
			var tag_str := "₱%d" % curr_val
			var tag_pos := pt + Vector2(-18, -14 if pt.y > gr.position.y + 25 else 20)
			var tag_bg := Rect2(tag_pos.x - 8, tag_pos.y - 12, 52, 18)
			draw_rect(tag_bg, Color(0.10, 0.14, 0.10, 0.95), true)
			draw_rect(tag_bg, line_col, false, 1.0)
			draw_string(font, tag_pos + Vector2(2, 2), tag_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, line_col)
		else:
			draw_circle(pt, 3.0, line_col)
			draw_circle(pt, 1.5, Color(0.08, 0.10, 0.08))

	# 8. X-Axis Day labels
	var day_names := ["D-6", "D-5", "D-4", "D-3", "D-2", "Yest", "Today"]
	var start_idx: int = maxi(0, day_names.size() - n)
	for i in range(n):
		var lbl_idx: int = start_idx + i
		var lbl: String = day_names[lbl_idx] if lbl_idx < day_names.size() else "D+%d" % i
		var lx: float = points[i].x
		var col: Color = Color(1.0, 0.92, 0.50) if i == n - 1 else COLOR_MUTED_TXT
		draw_string(font, Vector2(lx - 16, gr.end.y + 18), lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, col)
