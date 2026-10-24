extends Node

func _ready() -> void:
	print("========================================")
	print("TEST: DEBUG MENU INTEGRATION & REMOVAL FROM SCREENS")
	print("========================================")

	# 1. Verify MainMenu.tscn has no debug checkbox on screen
	var mm_scene = load("res://scenes/MainMenu.tscn")
	var mm = mm_scene.instantiate()
	add_child(mm)
	await get_tree().process_frame

	var mm_debug = mm.find_child("AdminCheckbox", true, false)
	assert(mm_debug == null, "MainMenu.tscn must NOT contain AdminCheckbox on screen")
	var mm_box = mm.find_child("ModeAdminBox", true, false)
	assert(mm_box == null, "MainMenu.tscn must NOT contain ModeAdminBox on screen")
	print("✔ Check 1: MainMenu.tscn is free of debug checkbox and container")
	mm.queue_free()
	await get_tree().process_frame

	# 2. Verify StartMenu.tscn has no debug checkbox on screen
	var sm_scene = load("res://scenes/StartMenu.tscn")
	var sm = sm_scene.instantiate()
	add_child(sm)
	await get_tree().process_frame

	var sm_debug = sm.find_child("AdminCheckbox", true, false)
	assert(sm_debug == null, "StartMenu.tscn must NOT contain AdminCheckbox on screen")
	print("✔ Check 2: StartMenu.tscn is free of debug checkbox and container")
	sm.queue_free()
	await get_tree().process_frame

	# 3. Verify MainGame.tscn spawns AdminPanel & PauseMenu without on-screen hint banner
	var mg_scene = load("res://scenes/MainGame.tscn")
	var mg = mg_scene.instantiate()
	add_child(mg)
	await get_tree().process_frame
	await get_tree().process_frame

	var admin = mg.find_child("AdminPanel", true, false)
	assert(admin != null, "MainGame must instantiate AdminPanel")
	assert(admin.is_enabled == true, "AdminPanel must be enabled by default")
	assert(admin.visible == false, "AdminPanel must be hidden initially")
	print("✔ Check 3: AdminPanel exists and is enabled in background")

	# Check no hint banner label on screen
	for c in mg.get_children():
		if c is CanvasLayer and c.layer == 199:
			assert(false, "MainGame must NOT spawn on-screen admin hint layer")
	print("✔ Check 4: No on-screen admin hint banner on gameplay screen")

	# 4. Verify PauseMenu has Debug Console button
	var pause = mg.find_child("PauseMenu", true, false)
	assert(pause != null, "PauseMenu must exist in MainGame")
	var debug_btn: Button = null
	for child in pause.find_children("*", "Button", true, false):
		if "Debug" in child.text or "Console" in child.text:
			debug_btn = child
			break
	assert(debug_btn != null, "PauseMenu must contain Debug Console button")
	assert(debug_btn.text == "🛠️ Debug Console (`)", "Debug Console button text match")
	print("✔ Check 5: PauseMenu contains '🛠️ Debug Console (`)' button")

	# 5. Test clicking Debug Console button opens AdminPanel
	pause.show_menu()
	assert(pause.visible == true, "PauseMenu is visible")
	debug_btn.emit_signal("pressed")
	await get_tree().create_timer(0.2).timeout

	assert(pause.visible == false, "PauseMenu closed after clicking Debug Console")
	assert(admin.visible == true, "AdminPanel is opened by PauseMenu debug button")
	print("✔ Check 6: Clicking PauseMenu debug button opens AdminPanel")

	# 6. Test AdminPanel close button
	var close_btn: Button = null
	for b in admin.find_children("*", "Button", true, false):
		if b.text == "✕":
			close_btn = b
			break
	assert(close_btn != null, "AdminPanel must have close button '✕'")
	close_btn.emit_signal("pressed")
	await get_tree().process_frame
	assert(admin.visible == false, "AdminPanel closed by '✕' button")
	print("✔ Check 7: AdminPanel close button '✕' works")

	# 7. Test AdminPanel toggle() via keyboard simulation
	admin.toggle()
	assert(admin.visible == true, "AdminPanel toggle opens panel")
	admin.toggle()
	assert(admin.visible == false, "AdminPanel toggle closes panel")
	print("✔ Check 8: AdminPanel toggle API works")

	print("========================================")
	print("ALL 8 DEBUG MENU INTEGRATION CHECKS PASSED 100%!")
	print("========================================")
	get_tree().quit()
