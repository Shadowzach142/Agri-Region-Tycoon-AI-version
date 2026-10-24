extends Node

func _ready() -> void:
	print("========================================")
	print("Starting MainMenu & Region Select Verification")
	print("========================================")

	var scene_res = load("res://scenes/MainMenu.tscn")
	if not scene_res:
		printerr("FAIL: Could not load MainMenu.tscn")
		get_tree().quit(1)
		return

	var main_menu = scene_res.instantiate()
	add_child(main_menu)

	var mode_view = main_menu.get_node("%ModeSelectView")
	assert(mode_view != null, "ModeSelectView must exist")
	assert(mode_view.visible == true, "ModeSelectView should be visible on start")

	var desc_label = main_menu.get_node("%ModeDescLabel")
	var tagline_label = main_menu.get_node("%ModeTaglineLabel")
	var pillar1_title = main_menu.get_node("%Pillar1Title")
	var pillar1_body = main_menu.get_node("%Pillar1Body")
	var season_label = main_menu.get_node("%SeasonLabel")
	var season30_btn = main_menu.get_node("%Season30Btn")
	var start_btn = main_menu.get_node("%ModeStartBtn")
	var load_btn = main_menu.get_node("%ModeLoadBtn")

	print("1. Mode Select UI Checks:")
	assert(tagline_label.get_theme_font_size("font_size") >= 14, "Tagline font size should be >= 14")
	assert(desc_label.get_theme_font_size("font_size") >= 16, "Desc font size should be >= 16")
	assert(pillar1_title.get_theme_font_size("font_size") >= 17, "Pillar title font size should be >= 17")
	assert(pillar1_body.get_theme_font_size("font_size") >= 15, "Pillar body font size should be >= 15")
	assert(season30_btn.get_theme_font_size("font_size") >= 14, "Season button font size should be >= 14")
	assert(start_btn.get_theme_font_size("font_size") >= 16, "Start button font size should be >= 16")
	assert(load_btn.get_theme_font_size("font_size") >= 16, "Load button font size should be >= 16")
	print("  ✔ Mode Select typography verified")

	# Switch to Region Select
	start_btn.emit_signal("pressed")
	print("\n2. Region Select UI Checks:")
	var middle_card = main_menu.get_node("MiddleCard")
	assert(middle_card != null and middle_card.visible == true, "MiddleCard must be visible in region select")

	var dossier_header = middle_card.find_child("DossierHeader", true, false) as Label
	var reg_desc = main_menu.get_node("%DescLabel")
	var moisture_title = middle_card.find_child("MoistureTitle", true, false) as Label
	var moisture_val = main_menu.get_node("%MoistureVal")
	var crops_title = middle_card.find_child("CropsTitle", true, false) as Label
	var crops_val = main_menu.get_node("%CropsVal")
	var hazard_title = middle_card.find_child("HazardTitle", true, false) as Label
	var hazard_val = main_menu.get_node("%HazardVal")
	var pros_header = middle_card.find_child("ProsHeader", true, false) as Label
	var pros_text = main_menu.get_node("%ProsText")
	var cons_header = middle_card.find_child("ConsHeader", true, false) as Label
	var cons_text = main_menu.get_node("%ConsText")

	var reg_name = main_menu.get_node("%RegionNameLabel")
	var reg_spec = main_menu.get_node("%RegionSpecialtyLabel")
	var game_start_btn = main_menu.get_node("%StartButton")

	print("  DossierHeader font size: %d, text: %s" % [dossier_header.get_theme_font_size("font_size"), dossier_header.text])
	print("  RegDesc font size: %d, text: %s" % [reg_desc.get_theme_font_size("font_size"), reg_desc.text])
	print("  Moisture Title/Val: %d / %d" % [moisture_title.get_theme_font_size("font_size"), moisture_val.get_theme_font_size("font_size")])
	print("  Crops Title/Val: %d / %d" % [crops_title.get_theme_font_size("font_size"), crops_val.get_theme_font_size("font_size")])
	print("  Hazard Title/Val: %d / %d" % [hazard_title.get_theme_font_size("font_size"), hazard_val.get_theme_font_size("font_size")])
	print("  Pros Header/Text: %d / %d" % [pros_header.get_theme_font_size("font_size"), pros_text.get_theme_font_size("font_size")])
	print("  Cons Header/Text: %d / %d" % [cons_header.get_theme_font_size("font_size"), cons_text.get_theme_font_size("font_size")])
	print("  Region Name/Spec: %d / %d" % [reg_name.get_theme_font_size("font_size"), reg_spec.get_theme_font_size("font_size")])
	print("  Start Button font size: %d" % [game_start_btn.get_theme_font_size("font_size")])

	assert(dossier_header.get_theme_font_size("font_size") >= 17, "DossierHeader font size must be >= 17")
	assert(reg_desc.get_theme_font_size("font_size") >= 16, "RegDesc font size must be >= 16")
	assert(moisture_title.get_theme_font_size("font_size") >= 13, "Moisture title must be >= 13")
	assert(moisture_val.get_theme_font_size("font_size") >= 16, "Moisture val must be >= 16")
	assert(crops_title.get_theme_font_size("font_size") >= 13, "Crops title must be >= 13")
	assert(crops_val.get_theme_font_size("font_size") >= 16, "Crops val must be >= 16")
	assert(hazard_title.get_theme_font_size("font_size") >= 13, "Hazard title must be >= 13")
	assert(hazard_val.get_theme_font_size("font_size") >= 16, "Hazard val must be >= 16")
	assert(pros_header.get_theme_font_size("font_size") >= 16, "Pros header must be >= 16")
	assert(pros_text.get_theme_font_size("font_size") >= 15, "Pros text must be >= 15")
	assert(cons_header.get_theme_font_size("font_size") >= 16, "Cons header must be >= 16")
	assert(cons_text.get_theme_font_size("font_size") >= 15, "Cons text must be >= 15")
	assert(reg_name.get_theme_font_size("font_size") >= 20, "Region name must be >= 20")
	assert(reg_spec.get_theme_font_size("font_size") >= 14, "Region spec must be >= 14")
	assert(game_start_btn.get_theme_font_size("font_size") >= 16, "Game start btn must be >= 16")

	# Check MiddleCard height bounds (should be compact ~345px, not 480px)
	var card_h = middle_card.offset_bottom - middle_card.offset_top
	print("  MiddleCard height: %d px" % card_h)
	assert(card_h <= 360, "MiddleCard height must be <= 360px to prevent dead space void")

	# Verify bullet points across all 5 regions
	for i in range(5):
		main_menu._select_region(i, false)
		assert(pros_text.text.begins_with("•"), "Pros text should use clean bullet points")
		assert(cons_text.text.begins_with("•"), "Cons text should use clean bullet points")
		assert(not "[+] [+]" in pros_text.text, "No double prefixes in pros")
		assert(not "[!] [!]" in cons_text.text, "No double prefixes in cons")
		print("  ✔ Region %d (%s) verified: %s" % [i + 1, reg_name.text, reg_spec.text])

	print("\n========================================")
	print("ALL MAIN MENU & REGION SELECT CHECKS PASSED!")
	print("========================================")
	main_menu.queue_free()
	get_tree().quit(0)
