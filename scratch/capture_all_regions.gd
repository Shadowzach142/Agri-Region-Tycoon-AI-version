extends Node

func _ready() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var mm = load("res://scenes/MainMenu.tscn").instantiate()
	vp.add_child(mm)

	mm._show_region_select()

	var regions = ["cotabato", "south_cotabato", "sarangani", "sultan_kudarat", "general_santos"]
	for idx in range(regions.size()):
		mm._select_region(idx, false)
		for f in range(6):
			await get_tree().process_frame
		var img = vp.get_texture().get_image()
		if img:
			var path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/region_%s.png" % regions[idx]
			img.save_png(path)
			print("✔ Captured %s" % path)

	get_tree().quit(0)
