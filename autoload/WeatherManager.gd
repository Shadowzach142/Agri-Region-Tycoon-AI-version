# WeatherManager.gd
# Handles climate state, temperature, rainfall, and regional hazard forecasts.
# Emits weather_changed and disaster_warning signals.

extends Node

signal weather_changed(temperature: float, humidity: float)
signal disaster_warning(hazard_type: String, countdown_seconds: float)
signal disaster_struck(hazard_type: String)
signal disaster_cleared(hazard_type: String)

enum Climate {NORMAL, EL_NINO, LA_NINA}

var current_climate: int = Climate.NORMAL
var temperature: float = 28.0  # Ambient temperature in Celsius
var humidity: float = 0.65     # Soil/air humidity ratio 0.0 - 1.0
var rainfall_mm: float = 5.0   # Daily rainfall in mm
var rain_chance: float = 0.20  # Precipitation probability for today (0.0 to 1.0)
var condition: String = "partly_cloudy"
var condition_title: String = "Partly Cloudy & Fair"

func _get_time_mgr() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/TimeManager")
	var loop = Engine.get_main_loop()
	if loop and "root" in loop and loop.root:
		return loop.root.get_node_or_null("TimeManager")
	return null

func _get_building_mgr() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/BuildingManager")
	var loop = Engine.get_main_loop()
	if loop and "root" in loop and loop.root:
		return loop.root.get_node_or_null("BuildingManager")
	return null

func _get_data_mgr() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Data")
	var loop = Engine.get_main_loop()
	if loop and "root" in loop and loop.root:
		return loop.root.get_node_or_null("Data")
	return null

## Returns effective real-time ambient temperature accounting for day/night cooling
func get_effective_temperature() -> float:
	var tm := _get_time_mgr()
	if tm:
		if tm.has_method("is_night") and tm.is_night():
			return temperature - 6.0
		elif (tm.has_method("is_dusk") and tm.is_dusk()) or (tm.has_method("is_dawn") and tm.is_dawn()):
			return temperature - 2.5
		else:
			return temperature + 1.5
	return temperature

## Returns effective real-time air humidity accounting for night dew/moisture rise
func get_effective_humidity() -> float:
	var tm := _get_time_mgr()
	if tm:
		if tm.has_method("is_night") and tm.is_night():
			return clampf(humidity + 0.18, 0.20, 0.98)
		elif (tm.has_method("is_dusk") and tm.is_dusk()) or (tm.has_method("is_dawn") and tm.is_dawn()):
			return clampf(humidity + 0.08, 0.20, 0.95)
	return humidity

# Disaster state & reaction countdown
var incoming_disaster: String = ""
var disaster_countdown: float = 0.0
var active_disaster: String = ""
var disaster_duration: float = 0.0

# Rolling pipeline of upcoming true weather days (at least 7 to 10 days ahead)
var weather_queue: Array = []

# Forecast presented to the player (Array of Dictionaries)
var forecast: Array = []

# Synoptic weather front tracking for multi-day realism and persistence
var _current_front_type: String = "normal"  # "normal", "rain_system", "dry_system"
var _front_remaining_days: int = 0
var _last_target_day: int = 0

func _ready() -> void:
	if weather_queue.is_empty():
		init_fresh_queue(1)
	_generate_forecast()
	weather_changed.emit(temperature, humidity)
	var bm := _get_building_mgr()
	if bm and bm.has_signal("weather_station_updated"):
		bm.weather_station_updated.connect(func(_lvl): _generate_forecast())

func _process(delta: float) -> void:
	var tm := _get_time_mgr()
	var scale: float = tm.get_speed_scale() if tm and tm.has_method("get_speed_scale") else 1.0
	if scale <= 0.0:
		return

	var dt: float = delta * scale

	# 1. Incoming disaster countdown
	if incoming_disaster != "":
		disaster_countdown -= dt
		if disaster_countdown <= 0.0:
			var hazard: String = incoming_disaster
			incoming_disaster = ""
			disaster_countdown = 0.0
			_strike_disaster(hazard)

	# 2. Active disaster storm duration
	if active_disaster != "":
		disaster_duration -= dt
		if disaster_duration <= 0.0:
			var finished: String = active_disaster
			active_disaster = ""
			disaster_cleared.emit(finished)

func trigger_disaster(hazard_type: String, countdown: float = -1.0) -> void:
	if incoming_disaster != "" or active_disaster != "":
		return # Disaster already processing
	if countdown <= 0.0:
		var bm := _get_building_mgr()
		countdown = bm.get_disaster_warning_time() if bm and bm.has_method("get_disaster_warning_time") else 5.0
	incoming_disaster = hazard_type
	disaster_countdown = countdown
	disaster_warning.emit(hazard_type, countdown)

func _strike_disaster(hazard: String) -> void:
	active_disaster = hazard
	disaster_duration = 10.0 # Active visual impact duration
	disaster_struck.emit(hazard)

## Called when a new day starts in TimeManager
func on_day_passed(day: int) -> void:
	_update_climate_for_day(day)
	_generate_forecast()
	weather_changed.emit(temperature, humidity)

func _update_climate_for_day(day: int) -> void:
	_ensure_weather_queue()
	if weather_queue.size() > 0:
		var today_entry: Dictionary = weather_queue.pop_front()
		_apply_day_entry(today_entry)
		if today_entry.get("will_disaster_strike", false) and day > 1:
			var hazard_type: String = str(today_entry.get("hazard", ""))
			if hazard_type != "" and hazard_type != "clear":
				var bm := _get_building_mgr()
				var warn_time: float = bm.get_disaster_warning_time() if bm and bm.has_method("get_disaster_warning_time") else 5.0
				trigger_disaster(hazard_type, warn_time)
	_push_next_day()

func _apply_day_entry(entry: Dictionary) -> void:
	current_climate = int(entry.get("climate", Climate.NORMAL))
	temperature = float(entry.get("temperature", 28.0))
	humidity = float(entry.get("humidity", 0.65))
	rainfall_mm = float(entry.get("rainfall_mm", 5.0))
	rain_chance = float(entry.get("rain_chance", 0.20))
	condition = str(entry.get("condition", "partly_cloudy"))
	condition_title = str(entry.get("condition_title", "Partly Cloudy & Fair"))

func _ensure_weather_queue() -> void:
	var tm := _get_time_mgr()
	var current_day_idx: int = tm.current_day if tm and "current_day" in tm else 1

	if _last_target_day < current_day_idx:
		_last_target_day = current_day_idx

	while weather_queue.size() < 10:
		_push_next_day()

func _push_next_day() -> void:
	_last_target_day += 1
	var new_day: Dictionary = _generate_upcoming_day(_last_target_day)
	weather_queue.append(new_day)

func _generate_upcoming_day(target_day: int) -> Dictionary:
	var dm := _get_data_mgr()
	var cur_reg: String = dm.current_region if dm and "current_region" in dm else "cotabato"
	var region_data: Dictionary = dm.get_region(cur_reg) if dm and dm.has_method("get_region") else {}
	var hazards: Dictionary = region_data.get("hazards", {})
	var flood_p: float = hazards.get("flash_flood", 0.10)
	var drought_p: float = hazards.get("el_nino_drought", 0.08)
	var slide_p: float = hazards.get("landslide", 0.03)

	# Transition synoptic weather front when previous front completes
	if _front_remaining_days <= 0:
		var rain_sys_p: float = clampf((flood_p + slide_p) * 1.5, 0.12, 0.38)
		var dry_sys_p: float = clampf(drought_p * 1.6, 0.08, 0.30)
		var r: float = randf()

		if r < rain_sys_p:
			_current_front_type = "rain_system"
			_front_remaining_days = randi_range(1, 3) # Monsoons/ITCZ troughs last 1–3 days
		elif r < (rain_sys_p + dry_sys_p):
			_current_front_type = "dry_system"
			_front_remaining_days = randi_range(2, 3) # Dry spells last 2–3 days
		else:
			_current_front_type = "normal"
			_front_remaining_days = randi_range(2, 4) # Fair tropical conditions last 2–4 days

	_front_remaining_days -= 1

	var clim: int = Climate.NORMAL
	var temp: float = 28.0
	var hum: float = 0.65
	var rain: float = 5.0
	var chance: float = 0.20
	var haz: String = "clear"
	var will_strike: bool = false
	var cond: String = "partly_cloudy"

	match _current_front_type:
		"rain_system":
			# Rain front has natural variation: peak downpour vs trailing showers
			if randf() < 0.45:
				clim = Climate.LA_NINA
				chance = randf_range(0.75, 0.95)
				rain = randf_range(40.0, 95.0)
				temp = randf_range(23.0, 26.5)
				hum = randf_range(0.80, 0.98)
				if randf() < (flood_p * 1.5):
					haz = "flash_flood"
					will_strike = true
				elif randf() < (slide_p * 2.0):
					haz = "landslide"
					will_strike = true
				cond = "heavy_rain"
			else:
				clim = Climate.NORMAL
				chance = randf_range(0.50, 0.72)
				rain = randf_range(14.0, 32.0)
				temp = randf_range(25.0, 28.0)
				hum = randf_range(0.70, 0.86)
				cond = "showers"

		"dry_system":
			# Dry front: severe heatwave vs warm dry spell
			if randf() < 0.50:
				clim = Climate.EL_NINO
				chance = randf_range(0.02, 0.10)
				rain = 0.0
				temp = randf_range(34.0, 39.0)
				hum = randf_range(0.18, 0.38)
				if randf() < (drought_p * 1.5):
					haz = "el_nino_drought"
					will_strike = true
				cond = "heatwave"
			else:
				clim = Climate.NORMAL
				chance = randf_range(0.08, 0.20)
				rain = 0.0
				temp = randf_range(31.5, 34.5)
				hum = randf_range(0.35, 0.50)
				cond = "hot_dry"

		_: # "normal"
			var sub_r: float = randf()
			if sub_r < 0.40:
				clim = Climate.NORMAL
				chance = randf_range(0.08, 0.22)
				rain = randf_range(0.0, 3.0)
				temp = randf_range(28.5, 32.0)
				hum = randf_range(0.50, 0.68)
				cond = "sunny"
			elif sub_r < 0.75:
				clim = Climate.NORMAL
				chance = randf_range(0.20, 0.38)
				rain = randf_range(1.0, 6.0)
				temp = randf_range(27.0, 30.5)
				hum = randf_range(0.55, 0.72)
				cond = "partly_cloudy"
			else:
				clim = Climate.NORMAL
				chance = randf_range(0.40, 0.58)
				rain = randf_range(6.0, 18.0)
				temp = randf_range(26.0, 29.5)
				hum = randf_range(0.65, 0.80)
				cond = "showers"

	var title_str: String = get_condition_title(clim, haz, rain, chance)

	return {
		"target_day": target_day,
		"climate": clim,
		"temperature": temp,
		"humidity": hum,
		"rainfall_mm": rain,
		"rain_chance": chance,
		"hazard": haz,
		"will_disaster_strike": will_strike,
		"condition": cond,
		"condition_title": title_str
	}

func _generate_forecast() -> void:
	forecast.clear()
	var bm := _get_building_mgr()
	var active_days: int = bm.get_forecast_days() if bm and bm.has_method("get_forecast_days") else 0
	var station_acc: float = bm.get_forecast_accuracy() if bm and bm.has_method("get_forecast_accuracy") else 0.35

	# Generate full 7-day outlook from authoritative rolling weather queue
	for i in range(1, 8):
		if i - 1 >= weather_queue.size():
			_push_next_day()

		var true_day: Dictionary = weather_queue[i - 1]
		var req_tier: int = 1
		if i > 3:
			req_tier = 3
		elif i > 1:
			req_tier = 2

		var is_unlocked: bool = (i <= active_days)
		var accuracy: float = station_acc if is_unlocked else 0.35

		var f_temp: float = float(true_day.get("temperature", 28.0))
		var f_hum: float = float(true_day.get("humidity", 0.65))
		var f_rain: float = float(true_day.get("rainfall_mm", 5.0))
		var f_chance: float = float(true_day.get("rain_chance", 0.20))
		var f_haz: String = str(true_day.get("hazard", "clear"))
		var f_clim: int = int(true_day.get("climate", Climate.NORMAL))
		var f_cond: String = str(true_day.get("condition", "partly_cloudy"))

		# Telemetry Noise Calibrated by Station Accuracy
		if accuracy < 1.0:
			var err: float = 1.0 - accuracy
			f_temp += randf_range(-err * 4.5, err * 4.5)
			f_hum = clampf(f_hum + randf_range(-err * 0.14, err * 0.14), 0.15, 0.98)
			f_chance = clampf(f_chance + randf_range(-err * 0.22, err * 0.22), 0.02, 0.98)
			f_rain = maxf(0.0, f_rain + randf_range(-err * 12.0, err * 12.0))

			if f_haz != "clear" and randf() > accuracy:
				f_haz = "clear" # Radar missed low-probability hazard
			elif f_haz == "clear" and randf() < (err * 0.08):
				f_haz = "flash_flood" if f_clim == Climate.LA_NINA else "el_nino_drought" # False positive ghost echo

		var title_str: String = get_condition_title(f_clim, f_haz, f_rain, f_chance)

		forecast.append({
			"day": i,
			"target_day": true_day.get("target_day", i + 1),
			"temperature": f_temp,
			"humidity": f_hum,
			"rainfall": f_rain,
			"rain_chance": f_chance,
			"hazard": f_haz,
			"climate": f_clim,
			"condition": f_cond,
			"condition_title": title_str,
			"accuracy": accuracy,
			"required_tier": req_tier,
			"unlocked": is_unlocked
		})

func get_forecast() -> Array:
	return forecast.duplicate(true)

func get_unlocked_forecast() -> Array:
	var res: Array = []
	for f in forecast:
		if f.get("unlocked", false):
			res.append(f)
	return res

func get_condition_title(climate: int, hazard: String, rain: float = -1.0, rain_chance: float = -1.0) -> String:
	if hazard == "flash_flood":
		return "Flash Flood Torrent"
	elif hazard == "el_nino_drought":
		return "Severe Heatwave & Drought"
	elif hazard == "landslide":
		return "Heavy Monsoon & Landslide"

	if rain >= 35.0 or (rain_chance >= 0.70 and rain >= 20.0):
		return "Monsoon Torrential Rain"
	elif rain >= 12.0 or rain_chance >= 0.50:
		return "Scattered Rain Showers"
	elif rain >= 4.0 or rain_chance >= 0.30:
		return "Passing Light Showers"

	match climate:
		Climate.LA_NINA:
			return "Monsoon Overcast"
		Climate.EL_NINO:
			return "Hot & Arid Dry Spell"
		_:
			if rain_chance >= 0.20:
				return "Partly Cloudy & Fair"
			else:
				return "Clear & Sunny Sky"

func get_hazard_display_name(hazard: String) -> String:
	match hazard:
		"flash_flood": return "Flash Flood"
		"el_nino_drought": return "El Niño Drought"
		"landslide": return "Landslide"
		_: return "Clear"

func get_hazard_advice(hazard: String, climate: int) -> String:
	match hazard:
		"flash_flood":
			return "Harvest mature plots early & clear drainage canals!"
		"el_nino_drought":
			return "Engage sprinklers & water pumps to combat soil dryness."
		"landslide":
			return "Inspect sloped plots; avoid waterlogging boundary tiles."
		_:
			match climate:
				Climate.LA_NINA:
					return "High rainfall; optimal for Palay paddies."
				Climate.EL_NINO:
					return "Low rainfall; monitor moisture for corn & pineapple."
				_:
					return "Favorable conditions for planting and field work."

func get_saved_weather_queue() -> Array:
	return weather_queue.duplicate(true)

func load_weather_queue(saved_queue: Array) -> void:
	weather_queue.clear()
	for item in saved_queue:
		if item is Dictionary:
			weather_queue.append(item.duplicate(true))
	if not weather_queue.is_empty():
		_last_target_day = int(weather_queue.back().get("target_day", 1))
	_ensure_weather_queue()
	_generate_forecast()

func init_fresh_queue(starting_target_day: int = 1) -> void:
	weather_queue.clear()
	_front_remaining_days = 0
	_current_front_type = "normal"
	_last_target_day = starting_target_day - 1
	while weather_queue.size() < 10:
		_push_next_day()
	if starting_target_day == 1 and weather_queue.size() > 0:
		var today_entry: Dictionary = weather_queue.pop_front()
		_apply_day_entry(today_entry)
		_push_next_day()
	_generate_forecast()
