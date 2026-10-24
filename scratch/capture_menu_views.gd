extends Node

func _ready() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var mm = load("res://scenes/MainMenu.tscn").instantiate()
	vp.add_child(mm)

	# 1. Capture Start Menu Idle view (no hover card, open mountain vista)
	mm._show_mode_select()
	mm._select_mode_carousel(0)
	mm._hide_mode_hover_card_immediate()
	for i in range(10):
		await get_tree().process_frame
	var img1 = vp.get_texture().get_image()
	if img1:
		img1.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/current_menu.png")
		print("✔ Captured current_menu.png (Idle Start Menu - Open Mountain Vista)")

	# 2. Capture Start Menu Hover Campaign view
	var camp_btn = mm.find_child("SideCampaignBtn", true, false) as Button
	if camp_btn:
		mm._on_mode_button_hovered("campaign", camp_btn)
	for i in range(14):
		await get_tree().process_frame
	var img2 = vp.get_texture().get_image()
	if img2:
		img2.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/campaign_hover_menu.png")
		print("✔ Captured campaign_hover_menu.png (Campaign Hover Definition)")

	# 3. Capture Start Menu Hover Career view
	var career_btn = mm.find_child("SideCareerBtn", true, false) as Button
	if career_btn:
		mm._on_mode_button_hovered("career", career_btn)
	for i in range(14):
		await get_tree().process_frame
	var img3 = vp.get_texture().get_image()
	if img3:
		img3.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/career_menu.png")
		print("✔ Captured career_menu.png (Career Hover Definition)")

	# 4. Capture Region Selection view
	mm._show_region_select()
	for i in range(10):
		await get_tree().process_frame
	var img4 = vp.get_texture().get_image()
	if img4:
		img4.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/region_screen.png")
		print("✔ Captured region_screen.png (Region Selection)")

	get_tree().quit(0)
