# WeatherManager.gd
# Handles climate state, temperature, rainfall, and regional hazard forecasts.
# Emits weather_changed and disaster_warning signals.

extends Node

signal weather_changed(temperature: float, humidity: float)
signal disaster_warning(hazard_type: String)

enum Climate {NORMAL, EL_NINO, LA_NINA}

var current_climate: int = Climate.NORMAL
var temperature: float = 28.0  # Ambient temperature in Celsius
var humidity: float = 0.65     # Soil/air humidity ratio 0.0 - 1.0
var rainfall_mm: float = 5.0   # Daily rainfall

# Forecast: Array of Dictionaries [{day, temperature, humidity, hazard, rainfall}]
var forecast: Array = []

func _ready() -> void:
	_update_climate_for_day(1)
	_generate_forecast()
	weather_changed.emit(temperature, humidity)

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
	for i in range(1, 4):
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

		forecast.append({
			"day": i,
			"temperature": f_temp,
			"humidity": f_hum,
			"hazard": hazard,
		})

func _check_for_disaster(_day: int) -> void:
	var region_data: Dictionary = Data.get_region(Data.current_region)
	var hazards: Dictionary = region_data.get("hazards", {})
	
	match current_climate:
		Climate.EL_NINO:
			if randf() < hazards.get("el_nino_drought", 0.10):
				disaster_warning.emit("el_nino_drought")
		Climate.LA_NINA:
			if randf() < hazards.get("flash_flood", 0.12):
				disaster_warning.emit("flash_flood")
			elif randf() < hazards.get("landslide", 0.05):
				disaster_warning.emit("landslide")
		_:
			pass

func get_forecast() -> Array:
	return forecast.duplicate(true)
