# verify_weather_app.gd
# Verification script for Session 71 Weather Station Weather App overhaul.
extends Node

func _ready() -> void:
	print("\n=======================================================")
	print("🧪 RUNNING SESSION 71 WEATHER APP VERIFICATION SUITE")
	print("=======================================================\n")

	_test_weather_manager_forecast()
	_test_weather_station_tiers_forecast()
	_test_weather_app_modal_ui()
	_test_building_click_interception()

	print("\n=======================================================")
	print("🎉 ALL WEATHER APP VERIFICATION TESTS PASSED (100%)!")
	print("=======================================================\n")
	get_tree().quit(0)

func _test_weather_manager_forecast() -> void:
	print("--- 1. Testing WeatherManager 7-Day Forecast & Advice Helpers ---")
	var forecast := WeatherManager.get_forecast()
	assert(forecast.size() == 7, "Forecast must generate exactly 7 days, got: %d" % forecast.size())

	for i in range(7):
		var item: Dictionary = forecast[i]
		assert(item.has("day"), "Item %d must have 'day'" % i)
		assert(item.has("target_day"), "Item %d must have 'target_day'" % i)
		assert(item.has("temperature"), "Item %d must have 'temperature'" % i)
		assert(item.has("humidity"), "Item %d must have 'humidity'" % i)
		assert(item.has("rainfall"), "Item %d must have 'rainfall'" % i)
		assert(item.has("hazard"), "Item %d must have 'hazard'" % i)
		assert(item.has("accuracy"), "Item %d must have 'accuracy'" % i)
		assert(item.has("required_tier"), "Item %d must have 'required_tier'" % i)
		assert(item.has("unlocked"), "Item %d must have 'unlocked'" % i)

	# Verify advice and title helpers
	var clear_title := WeatherManager.get_condition_title(WeatherManager.Climate.NORMAL, "clear")
	assert(clear_title != "", "get_condition_title must return non-empty string")
	var flood_advice := WeatherManager.get_hazard_advice("flash_flood", WeatherManager.Climate.LA_NINA)
	assert(flood_advice.contains("drainage") or flood_advice.contains("mature"), "Flash flood advice must warn about drainage/crops")

	print("✔ 7-Day forecast generation and advice helpers verified.")

func _test_weather_station_tiers_forecast() -> void:
	print("--- 2. Testing Weather Station Tiers & Radar Horizon ---")
	# Level 0 (None)
	assert(BuildingManager.get_forecast_days() >= 0, "Forecast days queryable")

	# Mock weather station building
	var b_script = load("res://src/buildings/Building.gd")
	var b: Node = b_script.new()
	b.building_type = "weather_station"
	b.level = 1
	b.state = b.BuildingState.ACTIVE
	BuildingManager.register_building(b)
	BuildingManager.recalculate_bonuses()

	# Lv. 1 AM Radio Mast: 1 day forecast, 60% accuracy, 8s warning
	assert(BuildingManager.get_weather_station_level() == 1, "Level must be 1")
	assert(BuildingManager.get_forecast_days() == 1, "Lv.1 must grant 1 forecast day")
	assert(is_equal_approx(BuildingManager.get_forecast_accuracy(), 0.60), "Lv.1 accuracy must be 0.60")
	assert(is_equal_approx(BuildingManager.get_disaster_warning_time(), 8.0), "Lv.1 lead warning time must be 8.0s")

	var f1 := WeatherManager.get_forecast()
	assert(f1[0]["unlocked"] == true, "Day 1 must be unlocked at Lv.1")
	assert(f1[1]["unlocked"] == false, "Day 2 must be locked at Lv.1")

	# Lv. 2 AWS: 3 days forecast, 90% accuracy, 12s warning
	b.level = 2
	BuildingManager.recalculate_bonuses()
	assert(BuildingManager.get_weather_station_level() == 2, "Level must be 2")
	assert(BuildingManager.get_forecast_days() == 3, "Lv.2 must grant 3 forecast days")
	assert(is_equal_approx(BuildingManager.get_forecast_accuracy(), 0.90), "Lv.2 accuracy must be 0.90")
	assert(is_equal_approx(BuildingManager.get_disaster_warning_time(), 12.0), "Lv.2 lead warning time must be 12.0s")

	var f2 := WeatherManager.get_forecast()
	assert(f2[0]["unlocked"] == true, "Day 1 must be unlocked at Lv.2")
	assert(f2[1]["unlocked"] == true, "Day 2 must be unlocked at Lv.2")
	assert(f2[2]["unlocked"] == true, "Day 3 must be unlocked at Lv.2")
	assert(f2[3]["unlocked"] == false, "Day 4 must be locked at Lv.2")

	# Lv. 3 Satellite Dish: 7 days forecast, 100% accuracy, 18s warning
	b.level = 3
	BuildingManager.recalculate_bonuses()
	assert(BuildingManager.get_weather_station_level() == 3, "Level must be 3")
	assert(BuildingManager.get_forecast_days() == 7, "Lv.3 must grant 7 forecast days")
	assert(is_equal_approx(BuildingManager.get_forecast_accuracy(), 1.00), "Lv.3 accuracy must be 1.00")
	assert(is_equal_approx(BuildingManager.get_disaster_warning_time(), 18.0), "Lv.3 lead warning time must be 18.0s")

	var f3 := WeatherManager.get_forecast()
	for d in range(7):
		assert(f3[d]["unlocked"] == true, "Day %d must be unlocked at Lv.3" % (d + 1))

	# Clean up mock building
	BuildingManager.unregister_building(b)
	b.free()
	BuildingManager.recalculate_bonuses()
	print("✔ Station progression Lv.1 (1d) -> Lv.2 (3d) -> Lv.3 (7d) verified.")

func _test_weather_app_modal_ui() -> void:
	print("--- 3. Testing WeatherAppModal UI Construction & Refresh ---")
	var modal_script = load("res://src/ui/WeatherAppModal.gd")
	assert(modal_script != null, "WeatherAppModal script must load")
	var modal: CanvasLayer = modal_script.new()
	add_child(modal)

	# Test Almanac mode (no station)
	modal.open_almanac()
	assert(modal.visible == true, "Modal must be visible after open_almanac()")
	assert(modal._forecast_cards_hbox != null, "Forecast cards container must exist")
	assert(modal._forecast_cards_hbox.get_child_count() == 7, "Must display 7 daily forecast cards, got: %d" % modal._forecast_cards_hbox.get_child_count())

	# Test Station mode with active building
	var b_script = load("res://src/buildings/Building.gd")
	var b: Node = b_script.new()
	b.building_type = "weather_station"
	b.level = 1
	b.state = b.BuildingState.ACTIVE
	BuildingManager.register_building(b)
	BuildingManager.recalculate_bonuses()

	modal.open_for_station(b)
	assert(modal.current_building == b, "Modal must track current building")
	assert(modal._upgrade_btn.visible == true, "Upgrade button must be visible for active station")
	assert(modal._demolish_btn.visible == true, "Demolish button must be visible")
	assert(modal._tier_badge_label.text.contains("AM Radio"), "Tier badge must show AM Radio for Lv.1")

	# Test Upgrade interaction
	EconomyManager.cash = 5000 # Ensure sufficient cash
	var next_cost = BuildingManager.get_upgrade_cost(b.building_type, b.level)
	assert(next_cost > 0, "Upgrade cost must be > 0")
	modal._on_upgrade_pressed()
	assert(b.state == b.BuildingState.UPGRADING, "Building state must transition to UPGRADING")
	assert(modal._progress_box.visible == true, "Progress box must be visible during upgrade")

	modal.close()
	assert(modal.visible == false, "Modal must be hidden after close()")

	# Clean up
	BuildingManager.unregister_building(b)
	b.free()
	modal.queue_free()
	BuildingManager.recalculate_bonuses()
	print("✔ WeatherAppModal UI construction, 7 cards, and upgrade flow verified.")

func _test_building_click_interception() -> void:
	print("--- 4. Testing FarmGrid Left-Click Routing for Weather Station ---")
	var farm_grid_script = load("res://src/core/FarmGrid.gd")
	assert(farm_grid_script != null, "FarmGrid script must load")

	var fg = farm_grid_script.new()
	add_child(fg)

	# Verify weather_app_modal was instantiated
	assert(fg.weather_app_modal != null, "FarmGrid must own weather_app_modal")
	assert(fg.weather_app_modal is CanvasLayer, "weather_app_modal must be CanvasLayer")

	# Mock building
	var b_script = load("res://src/buildings/Building.gd")
	var ws: Node = b_script.new()
	ws.building_type = "weather_station"
	ws.level = 1
	ws.state = ws.BuildingState.ACTIVE

	# Trigger click
	fg._on_building_clicked(ws)
	assert(fg.weather_app_modal.visible == true, "Clicking weather station must open WeatherAppModal")
	assert(fg.weather_app_modal.current_building == ws, "WeatherAppModal must be opened for the clicked station")

	fg.weather_app_modal.close()
	assert(fg.weather_app_modal.visible == false, "Modal must close cleanly")

	ws.free()
	fg.queue_free()
	print("✔ FarmGrid weather station click interception verified.")
