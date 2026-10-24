extends Node2D

func _ready() -> void:
	print("--- Testing Outline Shader on Crop Sprite ---")
	var maingame = load("res://scenes/MainGame.tscn").instantiate()
	add_child(maingame)

	var farm_grid = maingame.find_child("FarmGrid", true, false)
	var camera = maingame.find_child("GameCamera", true, false)

	# Plant rice at (5, 5)
	var t: FarmTile = farm_grid.tiles[5][5]
	t.state = FarmTile.TileState.GROWING
	t.crop_type = "palay"
	t.growth_progress = 0.5
	farm_grid.renderer.update_tile(Vector2i(5, 5), farm_grid.tiles)

	var overlay = farm_grid.tile_overlays[5][5] as Node2D
	var crop_spr = overlay.find_child("CropSprite", true, false) as Sprite2D
	assert(crop_spr != null, "CropSprite must exist")

	# Create shader
	var shader_code = """
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.35, 1.0, 0.45, 1.0);
uniform float outline_width : hint_range(0.0, 5.0) = 1.0;
uniform bool is_highlighted = true;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (!is_highlighted) {
		COLOR = col;
	} else {
		if (col.a < 0.1) {
			COLOR = vec4(0.0);
		} else {
			vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
			float min_a = 1.0;
			min_a = min(min_a, texture(TEXTURE, UV + vec2(ps.x, 0.0)).a);
			min_a = min(min_a, texture(TEXTURE, UV - vec2(ps.x, 0.0)).a);
			min_a = min(min_a, texture(TEXTURE, UV + vec2(0.0, ps.y)).a);
			min_a = min(min_a, texture(TEXTURE, UV - vec2(0.0, ps.y)).a);

			if (min_a < 0.2) {
				// Outer edge of the sprite: crisp solid highlight contour!
				COLOR = vec4(outline_color.rgb, col.a);
			} else {
				// Body of the sprite: brightened and softly tinted with highlight color
				COLOR = vec4(mix(col.rgb, outline_color.rgb, 0.35) * 1.30, col.a);
			}
		}
	}
}
"""
	var shader := Shader.new()
	shader.code = shader_code

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("outline_color", Color(0.35, 1.0, 0.45, 1.0))
	mat.set_shader_parameter("outline_width", 1.0)
	mat.set_shader_parameter("is_highlighted", true)

	crop_spr.material = mat

	# Center camera on the rice tile (5, 5)
	if camera:
		camera.global_position = FarmerMovement.grid_to_pixel_center(Vector2i(5, 5), farm_grid)
		camera.zoom = Vector2(2.5, 2.5)

	for _i in range(5):
		await get_tree().process_frame

	var viewport = get_viewport()
	var tex = viewport.get_texture()
	var img = tex.get_image()

	var w = viewport.size.x
	var h = viewport.size.y
	var crop_rect = Rect2i(int(w / 2 - 200), int(h / 2 - 150), 400, 300)
	var cropped = img.get_region(crop_rect)

	var path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/crop_shader_highlight_test.png"
	cropped.save_png(path)
	print("Saved crop shader highlight test to: ", path)
	get_tree().quit(0)
