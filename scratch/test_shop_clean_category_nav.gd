extends Node2D

func _ready() -> void:
	print("--- BEGIN TEST: CLEAN SHOP CATEGORY NAVIGATION ---")

	# Instantiate MainGame
	var main_game_scene = load("res://scenes/MainGame.tscn")
	var game = main_game_scene.instantiate()
	add_child(game)

	await get_tree().process_frame
	await get_tree().process_frame

	var shop: Control = game.find_child("ShopPanel", true, false)
	assert(shop != null, "FAIL: ShopPanel not found in MainGame")

	var tabs: TabContainer = shop.find_child("TabContainer", true, false)
	assert(tabs != null, "FAIL: TabContainer not found in ShopPanel")

	# 1. Assert tabs_visible is FALSE (bottom tab bar removed)
	assert(tabs.tabs_visible == false, "FAIL: tabs.tabs_visible should be FALSE, but was TRUE!")
	print("✓ Test 1 Passed: tabs.tabs_visible is FALSE (bottom tab strip removed)")

	# 2. Assert CategoryNavBar exists
	var nav_bar: HBoxContainer = shop.find_child("CategoryNavBar", true, false)
	assert(nav_bar != null, "FAIL: CategoryNavBar not found in ShopPanel")
	print("✓ Test 2 Passed: CategoryNavBar (top big part) is active")

	var prev_btn: TextureButton = nav_bar.find_child("PrevCategoryBtn", true, false)
	var next_btn: TextureButton = nav_bar.find_child("NextCategoryBtn", true, false)
	var pill: Control = nav_bar.find_child("CategoryPill", true, false)
	var title_lbl: Label = nav_bar.find_child("CategoryTitleLabel", true, false)

	assert(prev_btn != null, "FAIL: PrevCategoryBtn not found")
	assert(next_btn != null, "FAIL: NextCategoryBtn not found")
	assert(pill != null, "FAIL: CategoryPill not found")
	assert(title_lbl != null, "FAIL: CategoryTitleLabel not found")
	print("✓ Test 3 Passed: Large navigation buttons and breadcrumb pill exist")

	# 3. Test navigation
	shop.visible = true
	shop._sync_category_nav()
	var initial_title = title_lbl.text
	print("Initial category title: ", initial_title)

	# Click next button
	next_btn.pressed.emit()
	var second_title = title_lbl.text
	print("Second category title: ", second_title)
	assert(second_title != initial_title, "FAIL: Title should change on next category")
	print("✓ Test 4 Passed: Clicking next category updates category cleanly")

	# Click previous button
	prev_btn.pressed.emit()
	assert(title_lbl.text == initial_title, "FAIL: Previous button should return to initial category")
	print("✓ Test 5 Passed: Clicking previous category navigates backwards cleanly")

	# Navigate to Category 2 (Housing & Labor) to match user screenshot
	shop.open_to_tab("Labor")
	await get_tree().process_frame
	await get_tree().process_frame

	print("Current category: ", title_lbl.text)

	# Capture screenshot
	var img = get_viewport().get_texture().get_image()
	if img:
		var shot_path = "c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/shot_shop_clean_category_nav.png"
		img.save_png(shot_path)
		print("Saved screenshot to: ", shot_path)

	print("--- ALL 5 TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
