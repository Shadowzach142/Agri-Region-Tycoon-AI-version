# TimeManager.gd
# Manages in-game continuous 24-hour cycle (180 real seconds = 1 day at 1x; 7.5s per hour).
# Midnight triggers daily payroll deductions, crop growth ticks, and climate updates.

extends Node

signal hour_changed(hour: int)
signal day_changed(day: int)
signal midnight_tick(day: int)
signal period_changed(period_name: String, is_night: bool)
signal season_ended(target_days: int, final_score: int)

enum Speed {PAUSE = 0, ONE_X = 1, TWO_X = 2, THREE_X = 3}

const DAY_SECONDS: float = 180.0 # 3.0 real minutes per day at 1x (7.5 real seconds per hour)
const DAILY_WORKER_WAGE: int = 15
const STARTING_HOUR: int = 7 # Start game in clear 07:00 AM morning daylight

var _speed_scale: float = 1.0
var _elapsed: float = (float(STARTING_HOUR) / 24.0) * DAY_SECONDS

var current_hour: int = STARTING_HOUR
var current_day: int = 1
var is_freeplay_mode: bool = false
var _was_night: bool = false

# 24-Hour continuous ambient color palette for dynamic lighting
const AMBIENT_KEYFRAMES: Array = [
	[0.00, Color(0.32, 0.36, 0.60)], # 00:00 Luminous tropical midnight blue
	[0.17, Color(0.35, 0.38, 0.62)], # 04:00 Pre-dawn cool blue
	[0.21, Color(0.58, 0.50, 0.70)], # 05:00 Twilight rose
	[0.25, Color(0.96, 0.85, 0.74)], # 06:00 Golden sunrise
	[0.30, Color(1.00, 0.98, 0.94)], # 07:15 Radiant morning sunlight
	[0.50, Color(1.00, 1.00, 1.00)], # 12:00 Bright midday sun
	[0.68, Color(1.00, 0.96, 0.90)], # 16:20 Late afternoon warmth
	[0.73, Color(1.00, 0.78, 0.56)], # 17:30 Golden hour sunset
	[0.78, Color(0.65, 0.52, 0.72)], # 18:45 Purple dusk
	[0.83, Color(0.38, 0.42, 0.65)], # 20:00 Moonlit indigo night
	[0.92, Color(0.34, 0.37, 0.62)], # 22:00 Deep night
	[1.00, Color(0.32, 0.36, 0.60)], # 24:00 Midnight wrap
]

func _ready() -> void:
	_elapsed = (float(current_hour) / 24.0) * DAY_SECONDS
	_was_night = is_night()
	set_process(true)

func set_speed_scale(value: float) -> void:
	_speed_scale = clampf(value, 0.0, 3.0)

func get_speed_scale() -> float:
	return _speed_scale

func get_day_progress() -> float:
	return clampf(_elapsed / DAY_SECONDS, 0.0, 1.0)

func is_night() -> bool:
	return current_hour >= 19 or current_hour < 5

func is_dusk() -> bool:
	return current_hour >= 17 and current_hour < 19

func is_dawn() -> bool:
	return current_hour >= 5 and current_hour < 7

func get_time_period_name() -> String:
	if current_hour >= 0 and current_hour < 5:
		return "Midnight"
	elif current_hour >= 5 and current_hour < 7:
		return "Dawn"
	elif current_hour >= 7 and current_hour < 12:
		return "Morning"
	elif current_hour >= 12 and current_hour < 17:
		return "Afternoon"
	elif current_hour >= 17 and current_hour < 19:
		return "Dusk"
	else:
		return "Night"

## Computes continuous smooth color interpolation for world lighting based on 24-hr elapsed time
func get_ambient_color() -> Color:
	var progress: float = get_day_progress()
	for i in range(AMBIENT_KEYFRAMES.size() - 1):
		var k1: Array = AMBIENT_KEYFRAMES[i]
		var k2: Array = AMBIENT_KEYFRAMES[i + 1]
		var t1: float = float(k1[0])
		var t2: float = float(k2[0])
		if progress >= t1 and progress <= t2:
			var factor: float = (progress - t1) / maxf(t2 - t1, 0.0001)
			return (k1[1] as Color).lerp(k2[1] as Color, factor)
	return AMBIENT_KEYFRAMES[0][1]

func _process(delta: float) -> void:
	if _speed_scale <= 0.0:
		return

	_elapsed += delta * _speed_scale

	while _elapsed >= DAY_SECONDS:
		_elapsed -= DAY_SECONDS
		_increment_day()

	var new_hour: int = int((_elapsed / DAY_SECONDS) * 24.0)
	if new_hour != current_hour:
		current_hour = new_hour
		# Process hourly spoilage in storage
		MarketManager.process_hourly_spoilage()
		hour_changed.emit(current_hour)

		var currently_night: bool = is_night()
		if currently_night != _was_night:
			_was_night = currently_night
			period_changed.emit(get_time_period_name(), currently_night)

func _increment_day() -> void:
	current_day += 1
	current_hour = 0
	
	# Midnight payroll deduction (15 pesos per active farmer)
	var payroll: int = DAILY_WORKER_WAGE * BuildingManager.active_workers
	EconomyManager.deduct_cash(payroll)
	
	# Refresh market commodity supply/demand and pricing
	MarketManager.refresh_daily_prices()

	# Advance climate and weather forecast
	WeatherManager.on_day_passed(current_day)
	
	# Trigger crop growth, health updates, and agronomy checks
	midnight_tick.emit(current_day)
	day_changed.emit(current_day)
	hour_changed.emit(0)

	# Check if campaign season duration has concluded
	if not is_freeplay_mode and current_day > Data.selected_season_days:
		set_speed_scale(0.0)
		season_ended.emit(Data.selected_season_days, LeaderboardManager.current_points)
	elif Data.game_mode == "career" or is_freeplay_mode:
		# Career / Endless Mode midnight autosave
		SaveManager.save_game(SaveManager.AUTOSAVE_SLOT, "Autosave - Day %d" % current_day)

func enable_freeplay() -> void:
	is_freeplay_mode = true
	set_speed_scale(1.0)
	day_changed.emit(current_day)

func set_speed_mode(mode: int) -> void:
	match mode:
		Speed.PAUSE: set_speed_scale(0.0)
		Speed.ONE_X: set_speed_scale(1.0)
		Speed.TWO_X: set_speed_scale(2.0)
		Speed.THREE_X: set_speed_scale(3.0)
