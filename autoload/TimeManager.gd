# TimeManager.gd
# Manages in-game continuous 24-hour cycle (60 real seconds = 1 day at 1x).
# Midnight triggers daily payroll deductions, crop growth ticks, and climate updates.

extends Node

signal hour_changed(hour: int)
signal day_changed(day: int)
signal midnight_tick(day: int)

enum Speed {PAUSE = 0, ONE_X = 1, TWO_X = 2, THREE_X = 3}

const DAY_SECONDS: float = 60.0
const DAILY_WORKER_WAGE: int = 15

var _speed_scale: float = 1.0
var _elapsed: float = 0.0

var current_hour: int = 0
var current_day: int = 1

func _ready() -> void:
	set_process(true)

func set_speed_scale(value: float) -> void:
	_speed_scale = clampf(value, 0.0, 3.0)

func get_speed_scale() -> float:
	return _speed_scale

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

func set_speed_mode(mode: int) -> void:
	match mode:
		Speed.PAUSE: set_speed_scale(0.0)
		Speed.ONE_X: set_speed_scale(1.0)
		Speed.TWO_X: set_speed_scale(2.0)
		Speed.THREE_X: set_speed_scale(3.0)
