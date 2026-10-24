extends Node2D

func _ready() -> void:
	# Add some stored inventory so Bodega has crops
	MarketManager.stored_inventory.clear()
	MarketManager.add_harvest_to_storage("palay", 30, "A", 97.0)
	
	var mg_scene = load("res://scenes/MainGame.tscn")
	var mg = mg_scene.instantiate()
	add_child(mg)
	
	var sell_panel = mg.find_child("SellPanel", true, false)
	sell_panel.visible = true
	sell_panel.selected_hub_idx = -1
	sell_panel._refresh_view()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var vp = get_viewport()
	var img = vp.get_texture().get_image()
	
	var global_pos = sell_panel.global_position
	var size = sell_panel.size
	print("SellPanel global_pos:", global_pos, "size:", size)
	
	var rect = Rect2i(int(global_pos.x) - 10, int(global_pos.y) - 10, int(size.x) + 20, int(size.y) + 20)
	var cropped = img.get_region(rect)
	cropped.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/capture_sell_panel_unselected.png")
	
	# Now select Tacurong Grain Mill (idx 1)
	sell_panel.selected_hub_idx = 1
	sell_panel._refresh_view()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	img = vp.get_texture().get_image()
	cropped = img.get_region(rect)
	cropped.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/capture_sell_panel_selected.png")
	print("Saved capture_sell_panel_selected.png successfully!")
	get_tree().quit(0)
