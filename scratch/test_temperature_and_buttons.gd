extends Node

func _ready() -> void:
	await get_tree().process_frame
	_run_tests()

func _run_tests() -> void:
	print("\n=======================================================")
	print("🧪 TESTING TEMPERATURE SPRITES & WOODEN BUTTON INTEGRATION")
	print("=======================================================")

	# 1. Texture Loading Tests
	print("\n--- 1. Testing Sprite Resource Loading ---")
	var cold_tex = load("res://assets/icons/Tempreture/Cold .png") as Texture2D
	var just_right_tex = load("res://assets/icons/Tempreture/Just-Right.png") as Texture2D
	var sunny_tex = load("res://assets/icons/Tempreture/Sunny.png") as Texture2D
	var fire_tex = load("res://assets/icons/Tempreture/Fire.png") as Texture2D
	var water_drop_tex = load("res://assets/icons/Topleft/water-drop.png") as Texture2D
	var wave_tex = load("res://assets/icons/Disaster/Wave.png") as Texture2D

	assert(cold_tex != null, "Cold .png must load")
	assert(just_right_tex != null, "Just-Right.png must load")
	assert(sunny_tex != null, "Sunny.png must load")
	assert(fire_tex != null, "Fire.png must load")
	assert(water_drop_tex != null, "water-drop.png must load")
	assert(wave_tex != null, "Wave.png must load")
	print("✔ All temperature, moisture, and flood disaster textures loaded successfully!")

	# 2. Wooden Button StyleBox Tests
	print("\n--- 2. Testing Wooden Button StyleBoxes ---")
	var wb = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres") as StyleBoxTexture
	var wb_hov = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres") as StyleBoxTexture
	var wb_prs = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonPressed.tres") as StyleBoxTexture
	var dwb = load("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres") as StyleBoxTexture

	assert(wb != null and wb.texture != null, "WoodenButton.tres must have valid texture")
	assert(wb_hov != null and wb_hov.texture != null, "WoodenButtonHover.tres must have valid texture")
	assert(wb_prs != null and wb_prs.texture != null, "WoodenButtonPressed.tres must have valid texture")
	assert(dwb != null and dwb.texture != null, "DarkWoodenButton.tres must have valid texture")

	assert(wb.texture_margin_left == 10.0, "WoodenButton margin_left must be 10.0")
	assert(wb_prs.texture.resource_path.contains("Dark-Wooden-button.png"), "Pressed style must use Dark-Wooden-button texture")
	print("✔ Wooden button stylebox textures and 9-slice margins verified!")

	# 3. WeatherAppModal Helpers Test
	print("\n--- 3. Testing WeatherAppModal Temperature Helpers ---")
	var w_modal = WeatherAppModal.new()
	assert(w_modal.has_method("get_temperature_icon"), "WeatherAppModal must have get_temperature_icon")
	assert(WeatherAppModal.get_temperature_icon(35.0) == fire_tex, "35°C must return fire texture")
	assert(WeatherAppModal.get_temperature_icon(30.0) == sunny_tex, "30°C must return sunny texture")
	assert(WeatherAppModal.get_temperature_icon(26.0) == just_right_tex, "26°C must return just right texture")
	assert(WeatherAppModal.get_temperature_icon(19.0) == cold_tex, "19°C must return cold texture")
	w_modal.free()
	print("✔ WeatherAppModal temperature icon thresholds verified!")

	# 4. MainGame Scene Hierarchy Test
	print("\n--- 4. Testing MainGame Scene Nodes & HUD Wiring ---")
	var main_scene = load("res://scenes/MainGame.tscn") as PackedScene
	assert(main_scene != null, "MainGame.tscn must compile")

	var instance = main_scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	var hud = instance.find_child("HUDLayer", true, false)
	assert(hud != null, "HUDLayer must be present")

	var w_row = instance.find_child("WeatherRow", true, false)
	assert(w_row != null, "WeatherRow must exist in RegionWeatherBox")

	var w_icon = instance.find_child("WeatherIcon", true, false) as TextureRect
	assert(w_icon != null, "WeatherIcon must exist in WeatherRow")

	var h_row = instance.find_child("HumidityRow", true, false)
	assert(h_row != null, "HumidityRow must exist in RegionWeatherBox")

	var h_icon = instance.find_child("HumidityIcon", true, false) as TextureRect
	assert(h_icon != null, "HumidityIcon must exist in HumidityRow")

	var backlog_btn = instance.find_child("BacklogButton", true, false) as Button
	assert(backlog_btn != null, "BacklogButton must exist")
	var n_style = backlog_btn.get_theme_stylebox("normal") as StyleBoxTexture
	assert(n_style != null and n_style.texture.resource_path.contains("Wooden-button.png"), "BacklogButton must use Wooden-button texture")

	# Test HUD reaction to weather change
	WeatherManager.current_climate = WeatherManager.Climate.NORMAL
	hud._on_weather_changed(22.0, 0.70)
	assert(w_icon.texture == cold_tex, "22°C must set cold texture on WeatherIcon")
	assert(h_icon.texture == water_drop_tex, "HumidityIcon must use water-drop texture")

	hud._on_weather_changed(36.0, 0.40)
	assert(w_icon.texture == fire_tex, "36°C must set fire texture on WeatherIcon")

	hud._on_weather_changed(27.0, 0.65)
	assert(w_icon.texture == just_right_tex, "27°C must set just_right texture on WeatherIcon")

	hud._on_weather_changed(31.0, 0.55)
	assert(w_icon.texture == sunny_tex, "31°C must set sunny texture on WeatherIcon")

	instance.queue_free()
	print("✔ MainGame HUD dynamic weather icon switching and wooden button verified!")

	# 5. BayanihanModal Button Styling Test
	print("\n--- 5. Testing BayanihanModal Button Styling ---")
	var b_modal = BayanihanModal.new()
	add_child(b_modal)
	assert(b_modal._close_btn != null, "Close button must be initialized")
	assert(b_modal._apply_btn != null, "Apply button must be initialized")
	var app_style = b_modal._apply_btn.get_theme_stylebox("normal")
	assert(app_style != null and app_style.resource_path.contains("Goldbutton.tres"), "Apply button must use Goldbutton")
	b_modal.queue_free()
	print("✔ BayanihanModal buttons styled correctly!")

	print("\n=======================================================")
	print("🎉 ALL TEMPERATURE SPRITE & BUTTON TESTS PASSED (100%)!")
	print("=======================================================\n")
	get_tree().quit()
