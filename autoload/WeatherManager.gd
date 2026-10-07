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
var rainfall_mm: float = 5.0   # Daily rainfall

## Returns effective real-time ambient temperature accounting for day/night cooling
func get_effective_temperature() -> float:
	if TimeManager.is_night():
		return temperature - 6.0
	elif TimeManager.is_dusk() or TimeManager.is_dawn():
		return temperature - 2.5
	else:
		return temperature + 1.5

## Returns effective real-time air humidity accounting for night dew/moisture rise
func get_effective_humidity() -> float:
	if TimeManager.is_night():
		return clampf(humidity + 0.18, 0.20, 0.98)
	elif TimeManager.is_dusk() or TimeManager.is_dawn():
		return clampf(humidity + 0.08, 0.20, 0.95)
	else:
		return humidity

# Disaster state & reaction countdown
var incoming_disaster: String = ""
var disaster_countdown: float = 0.0
var active_disaster: String = ""
var disaster_duration: float = 0.0

# Forecast: Array of Dictionaries [{day, temperature, humidity, hazard, rainfall}]
var forecast: Array = []

func _ready() -> void:
	_update_climate_for_day(1)
	_generate_forecast()
	weather_changed.emit(temperature, humidity)
	if BuildingManager.has_signal("weather_station_updated"):
		BuildingManager.weather_station_updated.connect(func(_lvl): _generate_forecast())

func _process(delta: float) -> void:
	var scale: float = TimeManager.get_speed_scale()
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
		countdown = BuildingManager.get_disaster_warning_time()
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
	# Only evaluate disasters after initial setup day
	if day > 1:
		_check_for_disaster(day)

func _update_climate_for_day(_day: int) -> void:
	var region_data: Dictionary = Data.get_region(Data.current_region)
	var hazards: Dictionary = region_data.get("hazards", {})
	var el_nino_chance: float = hazards.get("el_nino_drought", 0.08)
	var la_nina_chance: float = hazards.get("flash_flood", 0.10)

	var roll: float = randf()
	if roll < el_nino_chance:
		current_climate = Climate.EL_NINO
		temperature = randf_range(33.0, 39.0)
		humidity = clampf(humidity - randf_range(0.15, 0.30), 0.15, 0.45)
		rainfall_mm = 0.0
	elif roll < (el_nino_chance + la_nina_chance):
		current_climate = Climate.LA_NINA
		temperature = randf_range(23.0, 27.0)
		humidity = clampf(humidity + randf_range(0.20, 0.35), 0.75, 0.98)
		rainfall_mm = randf_range(40.0, 120.0)
	else:
		current_climate = Climate.NORMAL
		temperature = randf_range(27.0, 31.0)
		humidity = clampf(humidity + randf_range(-0.05, 0.05), 0.50, 0.70)
		rainfall_mm = randf_range(2.0, 15.0)

func _generate_forecast() -> void:
	forecast.clear()
	var days: int = BuildingManager.get_forecast_days()
	if days <= 0:
		days = 1 # Baseline almanac
	var accuracy: float = BuildingManager.get_forecast_accuracy()
	var error_factor: float = (1.0 - accuracy) * 8.0

	for i in range(1, days + 1):
		var f_temp: float = temperature
		var f_hum: float = humidity
		var hazard: String = "clear"
		match current_climate:
			Climate.EL_NINO:
				f_temp += randf_range(-0.5, 2.0)
				f_hum = clampf(f_hum - 0.05, 0.10, 0.40)
				hazard = "el_nino_drought"
			Climate.LA_NINA:
				f_temp += randf_range(-1.5, 1.0)
				f_hum = clampf(f_hum + 0.08, 0.70, 1.0)
				hazard = "flash_flood"
			Climate.NORMAL:
				f_temp += randf_range(-1.0, 1.0)
				f_hum = clampf(f_hum + randf_range(-0.03, 0.03), 0.45, 0.75)
				hazard = "clear"

		if error_factor > 0.01:
			f_temp += randf_range(-error_factor, error_factor)
			f_hum = clampf(f_hum + randf_range(-error_factor * 0.02, error_factor * 0.02), 0.15, 0.95)
			if randf() > accuracy and hazard != "clear":
				hazard = "clear"

		forecast.append({
			"day": i,
			"temperature": f_temp,
			"humidity": f_hum,
			"hazard": hazard,
			"accuracy": accuracy
		})

func _check_for_disaster(_day: int) -> void:
	var region_data: Dictionary = Data.get_region(Data.current_region)
	var hazards: Dictionary = region_data.get("hazards", {})
	var warning_time: float = BuildingManager.get_disaster_warning_time()

	match current_climate:
		Climate.EL_NINO:
			if randf() < hazards.get("el_nino_drought", 0.10):
				trigger_disaster("el_nino_drought", warning_time)
		Climate.LA_NINA:
			if randf() < hazards.get("flash_flood", 0.12):
				trigger_disaster("flash_flood", warning_time)
			elif randf() < hazards.get("landslide", 0.05):
				trigger_disaster("landslide", warning_time)
		_:
			pass

func get_forecast() -> Array:
	return forecast.duplicate(true)
