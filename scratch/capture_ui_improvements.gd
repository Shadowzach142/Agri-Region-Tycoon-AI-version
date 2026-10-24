extends Node

const ARTIFACT_DIR = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852"

func _ready() -> void:
	print("--- Running capture_ui_improvements ---")
	var main_scene = load("res://scenes/MainGame.tscn")
	var main = main_scene.instantiate()
	add_child(main)
	
	for _i in range(5):
		await get_tree().process_frame
	
	# -----------------------------------------------------------------------
	# 1. Capture Top-Right HUD Bar (Component 2)
	# -----------------------------------------------------------------------
	var cash_lbl = main.find_child("CashLabel", true, false) as Label
	var points_lbl = main.find_child("PointsLabel", true, false) as Label
	var worker_lbl = main.find_child("WorkerLabel", true, false) as Label
	var storage_lbl = main.find_child("StorageLabel", true, false) as Label
	var storage_bar = main.find_child("StorageBar", true, false) as ProgressBar
	
	if cash_lbl: cash_lbl.text = "₱250"
	if points_lbl: points_lbl.text = "🏆 0 pts (Best: 18,500)"
	if worker_lbl: worker_lbl.text = "1/1 (⚡ 1)"
	if storage_lbl: storage_lbl.text = "0/200"
	if storage_bar:
		storage_bar.max_value = 200
		storage_bar.value = 45
	
	for _i in range(3):
		await get_tree().process_frame
	
	var viewport = get_viewport()
	var tex = viewport.get_texture()
	var img = tex.get_image()
	if img:
		var tr_crop = img.get_region(Rect2i(650, 0, 625, 60))
		tr_crop.save_png(ARTIFACT_DIR + "/capture_top_right_hud.png")
		print("Saved capture_top_right_hud.png")
	
	# -----------------------------------------------------------------------
	# 2. Capture Crop Hover Tooltip Card (Component 3)
	# -----------------------------------------------------------------------
	var farmer = main.find_child("Farmer", true, false)
	if farmer:
		TaskManager.select_farmer(farmer)
	
	for _i in range(3):
		await get_tree().process_frame
	
	var hotbar = main.find_child("PlantHotbar", true, false)
	if hotbar:
		# Open flyout and show hover card for palay
		hotbar._open_flyout_for_category("seeds")
		hotbar._populate_crop_hover("palay")
		hotbar.hover_card.visible = true
		
		for _i in range(5):
			await get_tree().process_frame
		
		var img2 = viewport.get_texture().get_image()
		if img2:
			var card_global_pos = hotbar.hover_card.global_position
			var card_size = hotbar.hover_card.size
			print("Hover card global pos: ", card_global_pos, " size: ", card_size)
			var pad = 16
			var r_x = maxi(int(card_global_pos.x) - pad, 0)
			var r_y = maxi(int(card_global_pos.y) - pad, 0)
			var r_w = mini(int(card_size.x) + pad * 2, 1280 - r_x)
			var r_h = mini(int(card_size.y) + pad * 2, 720 - r_y)
			var card_crop = img2.get_region(Rect2i(r_x, r_y, r_w, r_h))
			card_crop.save_png(ARTIFACT_DIR + "/capture_crop_hover.png")
			print("Saved capture_crop_hover.png")
		
		hotbar.hover_card.visible = false
		hotbar._close_flyout()
	
	# -----------------------------------------------------------------------
	# 3. Capture Shop Info Card (Component 1)
	# -----------------------------------------------------------------------
	var shop_panel = main.find_child("ShopPanel", true, false)
	if shop_panel:
		shop_panel.visible = true
		if shop_panel.has_method("refresh"):
			shop_panel.refresh()
		shop_panel.show_info(
			"Autonomous Precision Drone",
			"Automated farm drone. Automatically plows, plants, and harvests in assigned zones. Requires Drone Hangar & pilot capacity."
		)
		
		for _i in range(5):
			await get_tree().process_frame
		
		var img3 = viewport.get_texture().get_image()
		var info_card = shop_panel.find_child("ItemInfoCard", true, false)
		if info_card and img3:
			var ic_pos = info_card.global_position
			var ic_size = info_card.size
			print("ItemInfoCard global pos: ", ic_pos, " size: ", ic_size)
			var pad_ic = 16
			var ic_x = maxi(int(ic_pos.x) - pad_ic, 0)
			var ic_y = maxi(int(ic_pos.y) - pad_ic, 0)
			var ic_w = mini(int(ic_size.x) + pad_ic * 2, 1280 - ic_x)
			var ic_h = mini(int(ic_size.y) + pad_ic * 2, 720 - ic_y)
			var ic_crop = img3.get_region(Rect2i(ic_x, ic_y, ic_w, ic_h))
			ic_crop.save_png(ARTIFACT_DIR + "/capture_shop_info_card.png")
			print("Saved capture_shop_info_card.png")
	
	print("--- All captures completed successfully ---")
	get_tree().quit(0)
