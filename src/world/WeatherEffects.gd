# WeatherEffects.gd
# Dynamic weather visual presentation system.
# Emits real-time visual weather particles:
#   - Angled falling raindrops and isometric ground splashes during rain, storms, and floods
#   - Scorched sun glare and horizontal arid windblown dust during drought and El Niño
# Automatically synchronizes with WeatherManager.

class_name WeatherEffects
extends Node2D

var _rain_particles: CPUParticles2D = null
var _splash_particles: CPUParticles2D = null
var _dust_particles: CPUParticles2D = null
var _fireflies_particles: CPUParticles2D = null
var _canvas_modulate: CanvasModulate = null
var _sky_tint: ColorRect = null

var _drought_pulse_timer: float = 0.0
var _is_drought_active: bool = false
var _is_rain_active: bool = false

var _atmos_layer: CanvasLayer = null

func _ready() -> void:
	z_index = 85 # Render above tiles and farmer, below HUD
	_create_day_night_modulate()
	_create_atmosphere_canvas_layer()
	_create_procedural_particles()

	# Connect signals from WeatherManager & TimeManager
	WeatherManager.weather_changed.connect(_on_weather_changed)
	WeatherManager.disaster_warning.connect(_on_disaster_warning)
	WeatherManager.disaster_struck.connect(_on_disaster_struck)
	WeatherManager.disaster_cleared.connect(_on_disaster_cleared)
	TimeManager.period_changed.connect(func(_p, _n): _evaluate_weather_visuals())
	TimeManager.hour_changed.connect(func(_h): _evaluate_weather_visuals())

	# Initial weather evaluation
	_evaluate_weather_visuals()

func _process(delta: float) -> void:
	# 1. Update continuous 24-hr day/night atmospheric canvas modulate
	if _canvas_modulate:
		var amb: Color = TimeManager.get_ambient_color()
		if WeatherManager.incoming_disaster == "flash_flood" or WeatherManager.active_disaster == "flash_flood":
			amb = amb.lerp(Color(0.25, 0.32, 0.42), 0.40)
		_canvas_modulate.color = amb

	# 2. Subtle heatwave pulsing during drought
	if _is_drought_active and _sky_tint:
		_drought_pulse_timer += delta * 1.5
		var pulse: float = 0.10 + sin(_drought_pulse_timer) * 0.03
		_sky_tint.color = Color(1.0, 0.62, 0.18, pulse)

func _create_atmosphere_canvas_layer() -> void:
	# Dedicated Screen-space CanvasLayer (layer 2: above world layer 0, below HUDLayer at layer 10)
	# Guarantees atmosphere tint, rain, and dust always cover 100% of the viewport seamlessly
	# with zero rectangular edge seams or cutoffs during camera zoom and pan.
	_atmos_layer = CanvasLayer.new()
	_atmos_layer.name = "AtmosphereLayer"
	_atmos_layer.layer = 2
	add_child(_atmos_layer)

	_sky_tint = ColorRect.new()
	_sky_tint.name = "SkyAtmosphereTint"
	_sky_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky_tint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sky_tint.grow_vertical = Control.GROW_DIRECTION_BOTH
	_sky_tint.color = Color(0, 0, 0, 0)
	_sky_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atmos_layer.add_child(_sky_tint)

func _create_procedural_particles() -> void:
	# 1. Procedural raindrop streak texture (2x10 pixel drop)
	var drop_img := Image.create(2, 10, false, Image.FORMAT_RGBA8)
	for y in range(10):
		var a: float = float(y + 1) / 10.0
		drop_img.set_pixel(0, y, Color(0.75, 0.90, 1.0, a * 0.85))
		drop_img.set_pixel(1, y, Color(0.75, 0.90, 1.0, a * 0.85))
	var drop_tex := ImageTexture.create_from_image(drop_img)

	# 2. Falling Raindrops (Screen Space on _atmos_layer — covers full viewport smoothly)
	_rain_particles = CPUParticles2D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.texture = drop_tex
	_rain_particles.amount = 260
	_rain_particles.lifetime = 0.85
	_rain_particles.preprocess = 0.5
	_rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain_particles.emission_rect_extents = Vector2(720, 15)
	_rain_particles.position = Vector2(640, -20)
	_rain_particles.direction = Vector2(-0.25, 1.0)
	_rain_particles.spread = 4.0
	_rain_particles.gravity = Vector2(0, 900)
	_rain_particles.initial_velocity_min = 550.0
	_rain_particles.initial_velocity_max = 750.0
	_rain_particles.scale_amount_min = 1.0
	_rain_particles.scale_amount_max = 1.4
	_rain_particles.emitting = false
	_atmos_layer.add_child(_rain_particles)

	# 3. Ground Splashes (World Space — covers the full 24x24 isometric island centered at (768, 832))
	_splash_particles = CPUParticles2D.new()
	_splash_particles.name = "RainSplashParticles"
	_splash_particles.amount = 160
	_splash_particles.lifetime = 0.3
	_splash_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_splash_particles.emission_rect_extents = Vector2(1500, 750)
	_splash_particles.position = Vector2(768, 832)
	_splash_particles.direction = Vector2(0, -1.0)
	_splash_particles.spread = 75.0
	_splash_particles.gravity = Vector2(0, 450)
	_splash_particles.initial_velocity_min = 30.0
	_splash_particles.initial_velocity_max = 65.0
	_splash_particles.scale_amount_min = 1.5
	_splash_particles.scale_amount_max = 2.5
	_splash_particles.color = Color(0.75, 0.90, 1.0, 0.65)
	_splash_particles.emitting = false
	add_child(_splash_particles)

	# 4. Windblown Arid Dust (Drought — Screen Space on _atmos_layer)
	_dust_particles = CPUParticles2D.new()
	_dust_particles.name = "DroughtDustParticles"
	_dust_particles.amount = 50
	_dust_particles.lifetime = 3.5
	_dust_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust_particles.emission_rect_extents = Vector2(15, 380)
	_dust_particles.position = Vector2(-20, 360)
	_dust_particles.direction = Vector2(1.0, 0.05)
	_dust_particles.spread = 12.0
	_dust_particles.gravity = Vector2(0, 10)
	_dust_particles.initial_velocity_min = 180.0
	_dust_particles.initial_velocity_max = 340.0
	_dust_particles.scale_amount_min = 2.0
	_dust_particles.scale_amount_max = 4.0
	_dust_particles.color = Color(0.84, 0.68, 0.42, 0.40)
	_dust_particles.emitting = false
	_atmos_layer.add_child(_dust_particles)

	# 5. Magical Night Fireflies (Alitaptap — World Space across the 24x24 farm island)
	_fireflies_particles = CPUParticles2D.new()
	_fireflies_particles.name = "NightFireflies"
	_fireflies_particles.amount = 55
	_fireflies_particles.lifetime = 4.5
	_fireflies_particles.preprocess = 2.0
	_fireflies_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fireflies_particles.emission_rect_extents = Vector2(1400, 700)
	_fireflies_particles.position = Vector2(768, 832)
	_fireflies_particles.direction = Vector2(0.3, -0.3)
	_fireflies_particles.spread = 180.0
	_fireflies_particles.gravity = Vector2(0, -4)
	_fireflies_particles.initial_velocity_min = 8.0
	_fireflies_particles.initial_velocity_max = 22.0
	_fireflies_particles.scale_amount_min = 2.5
	_fireflies_particles.scale_amount_max = 4.5
	_fireflies_particles.color = Color(0.85, 1.0, 0.35, 0.85)
	_fireflies_particles.emitting = false
	add_child(_fireflies_particles)

func _create_day_night_modulate() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "WorldDayNightModulate"
	_canvas_modulate.color = TimeManager.get_ambient_color()
	add_child(_canvas_modulate)

func _evaluate_weather_visuals() -> void:
	var climate: int = WeatherManager.current_climate
	var is_storm: bool = (WeatherManager.incoming_disaster == "flash_flood" or WeatherManager.active_disaster == "flash_flood")
	var is_drought: bool = (climate == WeatherManager.Climate.EL_NINO or WeatherManager.incoming_disaster == "el_nino_drought" or WeatherManager.active_disaster == "el_nino_drought")
	var is_rain: bool = (climate == WeatherManager.Climate.LA_NINA or WeatherManager.rainfall_mm > 15.0 or is_storm)

	_is_drought_active = is_drought
	_is_rain_active = is_rain

	# Rain particles
	if is_rain:
		_rain_particles.emitting = true
		_splash_particles.emitting = true
		if is_storm:
			_rain_particles.amount = 350
			_rain_particles.initial_velocity_min = 650.0
			_rain_particles.initial_velocity_max = 900.0
			_sky_tint.color = Color(0.10, 0.16, 0.28, 0.32) # Dark storm sky
		else:
			_rain_particles.amount = 180
			_rain_particles.initial_velocity_min = 500.0
			_rain_particles.initial_velocity_max = 680.0
			_sky_tint.color = Color(0.15, 0.22, 0.32, 0.16) # Overcast light rain
	else:
		_rain_particles.emitting = false
		_splash_particles.emitting = false

	# Drought dust
	if is_drought:
		_dust_particles.emitting = true
		_sky_tint.color = Color(1.0, 0.62, 0.18, 0.12)
	else:
		_dust_particles.emitting = false
		if not is_rain:
			_sky_tint.color = Color(0, 0, 0, 0)

	# Fireflies on clear tropical nights
	if _fireflies_particles:
		var show_fireflies: bool = TimeManager.is_night() and not is_rain and not is_storm
		_fireflies_particles.emitting = show_fireflies

func _on_weather_changed(_temp: float, _hum: float) -> void:
	_evaluate_weather_visuals()

func _on_disaster_warning(_hazard: String, _countdown: float) -> void:
	_evaluate_weather_visuals()

func _on_disaster_struck(_hazard: String) -> void:
	_evaluate_weather_visuals()

func _on_disaster_cleared(_hazard: String) -> void:
	_evaluate_weather_visuals()
