extends SceneTree

func _init():
	var img = Image.load_from_file("C:/Users/ADMIN/.gemini/antigravity-ide/brain/2d912a7e-1d60-4cc4-ac48-537a84772546/.user_uploaded/media_1790730708990.png")
	var crop = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	# Center around x=360, y=330
	crop.blit_rect(img, Rect2i(310, 280, 100, 100), Vector2i.ZERO)
	crop.save_png("res://scratch/crop_bottom.png")
	print("Saved scratch/crop_bottom.png")
	quit()
