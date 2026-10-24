extends Node

func _ready() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var mm = load("res://scenes/MainMenu.tscn").instantiate()
	vp.add_child(mm)

	mm._show_region_select()

	for r_idx in range(5):
		mm._select_region(r_idx, false)
		for f in range(4):
			await get_tree().process_frame

		# Verify all 3 pro icons and 3 con icons exist and are loaded
		for i in range(1, 4):
			var p_icon = mm.find_child("ProIcon%d" % i, true, false) as TextureRect
			var p_label = mm.find_child("ProLabel%d" % i, true, false) as Label
			assert(p_icon != null and p_icon.texture != null, "ProIcon%d must have texture in region %d" % [i, r_idx])
			assert(p_label != null and p_label.text.begins_with("•"), "ProLabel%d must have bullet text in region %d" % [i, r_idx])

			var c_icon = mm.find_child("ConIcon%d" % i, true, false) as TextureRect
			var c_label = mm.find_child("ConLabel%d" % i, true, false) as Label
			assert(c_icon != null and c_icon.texture != null, "ConIcon%d must have texture in region %d" % [i, r_idx])
			assert(c_label != null and c_label.text.begins_with("•"), "ConLabel%d must have bullet text in region %d" % [i, r_idx])

		print("✔ Verified visual icons & text for Region %d: %s" % [r_idx + 1, mm.region_name_label.text])

		if r_idx == 1:
			var tex = vp.get_texture()
			if tex:
				var img = tex.get_image()
				if img:
					img.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/region_south_cotabato.png")
		elif r_idx == 4:
			var tex = vp.get_texture()
			if tex:
				var img = tex.get_image()
				if img:
					img.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/region_gen_santos.png")

	print("\nALL 5 REGIONS VISUAL ICONS & TYPOGRAPHY VERIFIED!")
	get_tree().quit(0)
