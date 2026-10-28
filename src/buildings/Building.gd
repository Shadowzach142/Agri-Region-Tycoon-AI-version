# Building.gd
# Placed interactive farm infrastructure building (Clash of Clans / Warcraft RTS style).
# Occupies a multi-tile footprint on the FarmGrid.
# Features:
#   - Construction timer & scaffold visuals
#   - Upgrade system (Level 1 -> 2 -> 3)
#   - Detailed procedural visuals per building type
#   - Real-time overhead construction progress bar

class_name Building
extends Node2D

signal state_changed(building: Node)
signal clicked(building: Node)
signal demolished(building: Node)

enum BuildingState { CONSTRUCTING, ACTIVE, UPGRADING }

# ---------------------------------------------------------------------------
# State & Metadata
# ---------------------------------------------------------------------------
var building_type: String = "bahay_kubo"
var grid_pos: Vector2i    = Vector2i.ZERO
var footprint: Vector2i   = Vector2i(2, 2)
var level: int            = 1
var max_level: int        = 3
var state: int            = BuildingState.CONSTRUCTING

var progress_timer: float = 0.0
var duration: float       = 15.0

# Per-facility storage routing & usage
var assigned_crops: Array = []  # Empty array = accepts ALL crops
var used_storage: int = 0       # Units currently held in this specific facility

# UI nodes
var progress_bar: ProgressBar = null
var progress_label: Label     = null
var level_label: Label        = null
var storage_fill_box: VBoxContainer = null
var storage_fill_label: Label       = null
var storage_fill_bar: ProgressBar   = null

const TEX_KUBO: Texture2D            = preload("res://assets/sprites/buildings/KUBO.png")
const TEX_KUBO_FLIPPED: Texture2D    = preload("res://assets/sprites/buildings/KUBO_FLIPPED.png")
const TEX_DRYER: Texture2D           = preload("res://assets/sprites/buildings/DRYER.PNG")
const TEX_DRYER_FLIPPED: Texture2D   = preload("res://assets/sprites/buildings/DRYER_FLIPPED.PNG")
const TEX_COLD_STORAGE: Texture2D    = preload("res://assets/sprites/buildings/Cold_Storage.png")
const TEX_COLD_STORAGE_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Cold_Storage_FLIPPED.png")
const TEX_DRONE_STATION: Texture2D   = preload("res://assets/sprites/buildings/Drone_Station.png")
const TEX_DRONE_STATION_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Drone_Station_FLIPPED.png")
const TEX_WATER_STATION: Texture2D   = preload("res://assets/sprites/buildings/Water_Station.png")
const TEX_WATER_STATION_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Water_Station_FLIPPED.png")
const TEX_WEATHER_STATION: Texture2D = preload("res://assets/sprites/buildings/Weather_Station.png")
const TEX_WEATHER_STATION_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Weather_Station_FLIPPED.png")

const TEX_SILO_0: Texture2D          = preload("res://assets/sprites/buildings/Silo/SILO-0.PNG")
const TEX_SILO_0_FLIPPED: Texture2D  = preload("res://assets/sprites/buildings/Silo/SILO-0_FLIPPED.PNG")
const TEX_SILO_25: Texture2D         = preload("res://assets/sprites/buildings/Silo/SILO-25.PNG")
const TEX_SILO_25_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Silo/SILO-25_FLIPPED.PNG")
const TEX_SILO_50: Texture2D         = preload("res://assets/sprites/buildings/Silo/SILO-50.PNG")
const TEX_SILO_50_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Silo/SILO-50_FLIPPED.PNG")
const TEX_SILO_75: Texture2D         = preload("res://assets/sprites/buildings/Silo/SILO-75.PNG")
const TEX_SILO_75_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Silo/SILO-75_FLIPPED.PNG")
const TEX_SILO_100: Texture2D        = preload("res://assets/sprites/buildings/Silo/SILO-100.PNG")
const TEX_SILO_100_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Silo/SILO-100_FLIPPED.PNG")

const TEX_BYAHERO: Texture2D         = preload("res://assets/sprites/buildings/byahero.png")
const TEX_BYAHERO_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/byahero_FLIPPED.png")
const TEX_TACURONG: Texture2D        = preload("res://assets/sprites/buildings/Tacurong-Grain-mill.png")
const TEX_TACURONG_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Tacurong-Grain-mill_FLIPPED.png")
const TEX_KORONADAL: Texture2D       = preload("res://assets/sprites/buildings/Koronadal-Wholesale.png")
const TEX_KORONADAL_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Koronadal-Wholesale_FLIPPED.png")
const TEX_GENSAN: Texture2D          = preload("res://assets/sprites/buildings/Gensan-seaport.png")
const TEX_GENSAN_FLIPPED: Texture2D  = preload("res://assets/sprites/buildings/Gensan-seaport_FLIPPED.png")

const TEX_RICE_MILL: Texture2D       = preload("res://assets/sprites/buildings/Kiskisan_Rice_Mill.png")
const TEX_RICE_MILL_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Kiskisan_Rice_Mill_FLIPPED.png")
const TEX_SUGAR_MILL: Texture2D      = preload("res://assets/sprites/buildings/Trapiche_Sugar_Central.png")
const TEX_SUGAR_MILL_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Trapiche_Sugar_Central_FLIPPED.png")
const TEX_COPRA_DRYER: Texture2D     = preload("res://assets/sprites/buildings/Tapahan_Copra_Dryer.png")
const TEX_COPRA_DRYER_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Tapahan_Copra_Dryer_FLIPPED.png")
const TEX_COFFEE_ROASTERY: Texture2D = preload("res://assets/sprites/buildings/Artisan_Coffee_Roastery.png")
const TEX_COFFEE_ROASTERY_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Artisan_Coffee_Roastery_FLIPPED.png")

const TEX_SPRINKLERS: Texture2D      = preload("res://assets/sprites/Machine/Sprinklers.png")
const SPRINKLER_FRAMES: Array[Dictionary] = [
	{"region": Rect2(11, 20, 46, 44), "stem": Vector2(12.0, 43.0)}, # Frame 0: Idle tripod & brass nozzle
	{"region": Rect2(70, 12, 67, 53), "stem": Vector2(28.5, 51.0)}, # Frame 1: Active rotary spray angle 1
	{"region": Rect2(137, 3, 81, 74), "stem": Vector2(38.0, 60.0)}, # Frame 2: Active rotary spray angle 2
	{"region": Rect2(225, 3, 88, 74), "stem": Vector2(44.0, 60.0)}, # Frame 3: Active rotary spray angle 3
	{"region": Rect2(325, 3, 83, 74), "stem": Vector2(40.0, 60.0)}, # Frame 4: Active rotary spray angle 4
]

const DECORATION_FITS: Dictionary = {
	"flower_bougainvillea_orange": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_Bougainvillea_boxed_orange.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_Bougainvillea_boxed_orange_FLIPPED.png"),
		"scale": 1.5,
		"center_offset": Vector2(32.5, 48.0),
		"roof_apex_y": -42.0,
		"scaffold_h": 32.0
	},
	"flower_bougainvillea_pink": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_Bougainvillea_boxed_pink.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_Bougainvillea_boxed_pink_FLIPPED.png"),
		"scale": 1.5,
		"center_offset": Vector2(32.0, 48.0),
		"roof_apex_y": -42.0,
		"scaffold_h": 32.0
	},
	"flower_bougainvillea_white": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_Bougainvillea_boxed_white.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_Bougainvillea_boxed_white_FLIPPED.png"),
		"scale": 1.5,
		"center_offset": Vector2(34.0, 44.0),
		"roof_apex_y": -42.0,
		"scaffold_h": 32.0
	},
	"flower_bougainvillea_potted": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_Bougainvillea_potted_pink.png"),
		"flip_tex": null,
		"scale": 1.5,
		"center_offset": Vector2(22.0, 52.0),
		"roof_apex_y": -45.0,
		"scaffold_h": 35.0
	},
	"flower_gumamela_colorful": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_gumamela_colorful.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_gumamela_colorful_FLIPPEDl.png"),
		"scale": 1.4,
		"center_offset": Vector2(24.5, 66.0),
		"roof_apex_y": -50.0,
		"scaffold_h": 40.0
	},
	"flower_gumamela_red": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_gumamela_red.png"),
		"flip_tex": null,
		"scale": 1.4,
		"center_offset": Vector2(30.0, 58.0),
		"roof_apex_y": -48.0,
		"scaffold_h": 38.0
	},
	"flower_gumamela_pink": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_gumamela_pink.png"),
		"flip_tex": null,
		"scale": 1.4,
		"center_offset": Vector2(27.5, 53.0),
		"roof_apex_y": -45.0,
		"scaffold_h": 35.0
	},
	"flower_gumamela_yellow": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_gumamela_yellow.png"),
		"flip_tex": null,
		"scale": 1.4,
		"center_offset": Vector2(27.0, 56.0),
		"roof_apex_y": -46.0,
		"scaffold_h": 36.0
	},
	"flower_santan_box_red": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_santan_bush_box_red.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_santan_bush_box_red_FLIPPED.png"),
		"scale": 1.4,
		"center_offset": Vector2(32.5, 40.0),
		"roof_apex_y": -38.0,
		"scaffold_h": 30.0
	},
	"flower_santan_box_orange": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_santan_bush_box_orange.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_santan_bush_box_orange_FLIPPED.png"),
		"scale": 1.4,
		"center_offset": Vector2(39.0, 44.0),
		"roof_apex_y": -38.0,
		"scaffold_h": 30.0
	},
	"flower_santan_box_yellow": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_santan_bush_box_yellow.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_santan_bush_box_yellow_FLIPPED.png"),
		"scale": 1.4,
		"center_offset": Vector2(34.5, 48.0),
		"roof_apex_y": -38.0,
		"scaffold_h": 30.0
	},
	"flower_santan_round_red": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_santan_bush_round_red.png"),
		"flip_tex": null,
		"scale": 2.2,
		"center_offset": Vector2(16.0, 24.0),
		"roof_apex_y": -34.0,
		"scaffold_h": 26.0
	},
	"flower_santan_round_yellow": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_santan_bush_round_yellow.png"),
		"flip_tex": null,
		"scale": 2.2,
		"center_offset": Vector2(16.0, 24.0),
		"roof_apex_y": -34.0,
		"scaffold_h": 26.0
	},
	"flower_orchids_hanged": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_orchids_hanged.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_orchids_hanged_FLIPPED.png"),
		"scale": 1.4,
		"center_offset": Vector2(36.0, 64.0),
		"roof_apex_y": -52.0,
		"scaffold_h": 42.0
	},
	"flower_orchids_tree": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_orchids_tree.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_orchids_tree_FLIPPED.png"),
		"scale": 1.4,
		"center_offset": Vector2(21.5, 60.0),
		"roof_apex_y": -50.0,
		"scaffold_h": 40.0
	},
	"flower_pandakaki_bush": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_pandakaki_bush.png"),
		"flip_tex": null,
		"scale": 1.6,
		"center_offset": Vector2(22.5, 36.0),
		"roof_apex_y": -35.0,
		"scaffold_h": 28.0
	},
	"flower_pandakaki_potted": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_pandakaki_potted.png"),
		"flip_tex": null,
		"scale": 1.8,
		"center_offset": Vector2(16.0, 32.0),
		"roof_apex_y": -36.0,
		"scaffold_h": 28.0
	},
	"flower_yellow_bell": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_yellow_bell.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flower_yellow_bell_FLIPPED.png"),
		"scale": 1.4,
		"center_offset": Vector2(32.0, 47.0),
		"roof_apex_y": -42.0,
		"scaffold_h": 34.0
	},
	"flowers_in_tires": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flowers_in_tires.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flowers/flowers_in_tires_FLIPPED.png"),
		"scale": 1.5,
		"center_offset": Vector2(33.0, 36.0),
		"roof_apex_y": -32.0,
		"scaffold_h": 25.0
	},
	"flower_daisy_colorful": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_daisy_colorful.png"),
		"flip_tex": null,
		"scale": 1.5,
		"center_offset": Vector2(28.0, 26.0),
		"roof_apex_y": -28.0,
		"scaffold_h": 22.0
	},
	"flower_daisy_fallen": {
		"norm_tex": preload("res://assets/sprites/Decorations/flowers/flower_daisy_fallen.png"),
		"flip_tex": null,
		"scale": 2.0,
		"center_offset": Vector2(15.5, 14.0),
		"roof_apex_y": -18.0,
		"scaffold_h": 15.0
	},
	"flower_pots": {
		"norm_tex": preload("res://assets/sprites/Decorations/flower_pots.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/flower_pots_FLIPPED.png"),
		"scale": 1.0,
		"center_offset": Vector2(41.0, 86.0),
		"roof_apex_y": -65.0,
		"scaffold_h": 50.0
	},
	"balut_stall": {
		"norm_tex": preload("res://assets/sprites/Decorations/balut_stall.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/balut_stall_FLIPPED.png"),
		"scale": 1.0,
		"center_offset": Vector2(40.0, 78.0),
		"roof_apex_y": -78.0,
		"scaffold_h": 60.0
	},
	"buko_stall": {
		"norm_tex": preload("res://assets/sprites/Decorations/buko_Stall.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/buko_Stall_FLIPPED.png"),
		"scale": 1.0,
		"center_offset": Vector2(40.0, 78.0),
		"roof_apex_y": -78.0,
		"scaffold_h": 60.0
	},
	"bbq_stand": {
		"norm_tex": preload("res://assets/sprites/Decorations/bbq_stand.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/bbq_stand_FLIPPED.png"),
		"scale": 1.1,
		"center_offset": Vector2(31.0, 68.0),
		"roof_apex_y": -68.0,
		"scaffold_h": 52.0
	},
	"bbq_stand_multiple": {
		"norm_tex": preload("res://assets/sprites/Decorations/bbq_stand_multiple.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/bbq_stand_multiple_FLIPPED.png"),
		"scale": 1.1,
		"center_offset": Vector2(38.0, 64.0),
		"roof_apex_y": -64.0,
		"scaffold_h": 50.0
	},
	"tricycle": {
		"norm_tex": preload("res://assets/sprites/Decorations/tricycle.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/tricycle_FLIPPED.png"),
		"scale": 1.1,
		"center_offset": Vector2(38.0, 48.0),
		"roof_apex_y": -50.0,
		"scaffold_h": 40.0
	},
	"karaoke_on_wheels": {
		"norm_tex": preload("res://assets/sprites/Decorations/karaoke_on_wheels.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/karaoke_on_wheels_FLIPPED.png"),
		"scale": 1.0,
		"center_offset": Vector2(48.0, 80.0),
		"roof_apex_y": -78.0,
		"scaffold_h": 60.0
	},
	"parol_stand": {
		"norm_tex": preload("res://assets/sprites/Decorations/parol_stand.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/parol_stand_FLIPPED.png"),
		"scale": 1.0,
		"center_offset": Vector2(41.5, 78.0),
		"roof_apex_y": -78.0,
		"scaffold_h": 60.0
	},
	"toy_store": {
		"norm_tex": preload("res://assets/sprites/Decorations/toy_store.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/toy_store_FLIPPED.png"),
		"scale": 1.0,
		"center_offset": Vector2(40.0, 80.0),
		"roof_apex_y": -80.0,
		"scaffold_h": 62.0
	},
	"fiesta_entrance": {
		"norm_tex": preload("res://assets/sprites/Decorations/fiesta_entrance.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/fiesta_entrance_FLIPPED.png"),
		"scale": 1.0,
		"center_offset": Vector2(41.0, 84.0),
		"roof_apex_y": -84.0,
		"scaffold_h": 65.0
	},
	"fiesta_drums": {
		"norm_tex": preload("res://assets/sprites/Decorations/fiesta_drums.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/fiesta_drums_FLIPPED.png"),
		"scale": 1.0,
		"center_offset": Vector2(49.0, 66.0),
		"roof_apex_y": -66.0,
		"scaffold_h": 50.0
	},
	"post_board": {
		"norm_tex": preload("res://assets/sprites/Decorations/post_board.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/post_board_FLIPPED.png"),
		"scale": 1.1,
		"center_offset": Vector2(33.0, 68.0),
		"roof_apex_y": -68.0,
		"scaffold_h": 52.0
	},
	"fiesta_stage": {
		"norm_tex": preload("res://assets/sprites/Decorations/fiesta_stage.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/fiesta_stage_FLIPPED.png"),
		"scale": 1.8,
		"center_offset": Vector2(44.0, 72.0),
		"roof_apex_y": -110.0,
		"scaffold_h": 85.0
	},
	"basketball_court": {
		"norm_tex": preload("res://assets/sprites/Decorations/basketball_court.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/basketball_court_FLIPPED.png"),
		"scale": 1.8,
		"center_offset": Vector2(39.0, 84.0),
		"roof_apex_y": -120.0,
		"scaffold_h": 90.0
	},
	"checkpoint": {
		"norm_tex": preload("res://assets/sprites/Decorations/checkpoint.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/checkpoint_FLIPPED.png"),
		"scale": 1.7,
		"center_offset": Vector2(48.0, 76.0),
		"roof_apex_y": -110.0,
		"scaffold_h": 85.0
	},
	"tambayan_kubo": {
		"norm_tex": preload("res://assets/sprites/Decorations/tambayan_kubo.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/tambayan_kubo_FLIPPED.png"),
		"scale": 1.8,
		"center_offset": Vector2(45.0, 76.0),
		"roof_apex_y": -115.0,
		"scaffold_h": 90.0
	},
	"tambayan": {
		"norm_tex": preload("res://assets/sprites/Decorations/tambayan.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/tambayan_FLIPPED.png"),
		"scale": 1.8,
		"center_offset": Vector2(40.0, 76.0),
		"roof_apex_y": -115.0,
		"scaffold_h": 90.0
	},
	"table_set": {
		"norm_tex": preload("res://assets/sprites/Decorations/table_set.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/table_set_FLIPPED.png"),
		"scale": 1.6,
		"center_offset": Vector2(56.0, 52.0),
		"roof_apex_y": -80.0,
		"scaffold_h": 60.0
	},
	"tambayan_chairs": {
		"norm_tex": preload("res://assets/sprites/Decorations/tambayan_chairs.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/tambayan_chairs_FLIPPED.png"),
		"scale": 1.1,
		"center_offset": Vector2(36.5, 60.0),
		"roof_apex_y": -60.0,
		"scaffold_h": 48.0
	},
	"bench_blue": {
		"norm_tex": preload("res://assets/sprites/Decorations/bench_blue.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/bench_blue_FLIPPED.png"),
		"scale": 1.2,
		"center_offset": Vector2(27.0, 50.0),
		"roof_apex_y": -50.0,
		"scaffold_h": 40.0
	},
	"bench_red": {
		"norm_tex": preload("res://assets/sprites/Decorations/bench_red.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/bench_red_FLIPPED.png"),
		"scale": 1.2,
		"center_offset": Vector2(27.0, 50.0),
		"roof_apex_y": -50.0,
		"scaffold_h": 40.0
	},
	"wooden_seat": {
		"norm_tex": preload("res://assets/sprites/Decorations/wooden_seat.png"),
		"flip_tex": preload("res://assets/sprites/Decorations/wooden_seat_FLIPPED.png"),
		"scale": 1.2,
		"center_offset": Vector2(32.0, 50.0),
		"roof_apex_y": -50.0,
		"scaffold_h": 40.0
	},
}

var art_sprite: Sprite2D = null
var is_flipped: bool = false:
	set(val):
		if is_flipped != val:
			is_flipped = val
			_update_flipped_visuals()

func set_flipped(val: bool) -> void:
	self.is_flipped = val

func toggle_flip() -> void:
	self.is_flipped = not is_flipped

func _update_flipped_visuals() -> void:
	var fit := get_art_fit(building_type, is_flipped)
	if not fit.is_empty() and art_sprite != null and is_instance_valid(art_sprite):
		art_sprite.texture = fit["texture"]
		var sc: float = float(fit.get("scale", 1.0))
		art_sprite.scale = Vector2(sc, sc)
		var coff: Vector2 = fit.get("center_offset", Vector2.ZERO)
		art_sprite.position = -coff * sc
		if Data.get_building(building_type).get("is_decoration", false):
			var has_dedicated_flip: bool = fit.get("has_dedicated_flip", false)
			art_sprite.flip_h = is_flipped if not has_dedicated_flip else false
	_update_art_sprite_state()
	queue_redraw()

static func get_art_fit(b_type: String, flipped: bool = false) -> Dictionary:
	if DECORATION_FITS.has(b_type):
		var d: Dictionary = DECORATION_FITS[b_type]
		var flip_tex = d.get("flip_tex", null)
		var tex: Texture2D = flip_tex if (flipped and flip_tex != null) else d.get("norm_tex", null)
		var has_dedicated_flip: bool = (flip_tex != null)
		return {
			"texture": tex,
			"scale": float(d.get("scale", 1.0)),
			"center_offset": d.get("center_offset", Vector2.ZERO),
			"has_slab": false,
			"has_dedicated_flip": has_dedicated_flip,
			"roof_apex_y": float(d.get("roof_apex_y", -40.0)),
			"scaffold_h": float(d.get("scaffold_h", 30.0))
		}

	match b_type:
		"bayanihan_center":
			return {
				"texture": TEX_BYAHERO_FLIPPED if flipped else TEX_BYAHERO,
				"scale": 2.0,
				"center_offset": Vector2(32.0, 38.0),
				"has_slab": false,
				"roof_apex_y": -76.0,
				"scaffold_h": 65.0
			}
		"tacurong_mill":
			return {
				"texture": TEX_TACURONG_FLIPPED if flipped else TEX_TACURONG,
				"scale": 2.7,
				"center_offset": Vector2(88.0 if flipped else 76.0, 64.0),
				"has_slab": true,
				"roof_apex_y": -174.0,
				"scaffold_h": 125.0
			}
		"koronadal_wholesale":
			return {
				"texture": TEX_KORONADAL_FLIPPED if flipped else TEX_KORONADAL,
				"scale": 2.5,
				"center_offset": Vector2(88.0, 66.0),
				"has_slab": true,
				"roof_apex_y": -166.0,
				"scaffold_h": 120.0
			}
		"gensan_seaport":
			return {
				"texture": TEX_GENSAN_FLIPPED if flipped else TEX_GENSAN,
				"scale": 2.4,
				"center_offset": Vector2(92.0 if flipped else 84.0, 82.0),
				"has_slab": true,
				"roof_apex_y": -198.0,
				"scaffold_h": 135.0
			}
		"rice_mill":
			return {
				"texture": TEX_RICE_MILL_FLIPPED if flipped else TEX_RICE_MILL,
				"scale": 3.4,
				"center_offset": Vector2(46.0, 54.0),
				"has_slab": true,
				"roof_apex_y": -184.0,
				"scaffold_h": 130.0
			}
		"sugar_mill":
			return {
				"texture": TEX_SUGAR_MILL_FLIPPED if flipped else TEX_SUGAR_MILL,
				"scale": 3.5,
				"center_offset": Vector2(55.0, 53.0),
				"has_slab": true,
				"roof_apex_y": -186.0,
				"scaffold_h": 135.0
			}
		"copra_dryer":
			return {
				"texture": TEX_COPRA_DRYER_FLIPPED if flipped else TEX_COPRA_DRYER,
				"scale": 2.0,
				"center_offset": Vector2(64.0, 50.0),
				"has_slab": true,
				"roof_apex_y": -100.0,
				"scaffold_h": 70.0
			}
		"coffee_roastery":
			return {
				"texture": TEX_COFFEE_ROASTERY_FLIPPED if flipped else TEX_COFFEE_ROASTERY,
				"scale": 3.3,
				"center_offset": Vector2(53.0, 53.5),
				"has_slab": true,
				"roof_apex_y": -178.0,
				"scaffold_h": 125.0
			}

	return {}

## Returns ghost placement preview dictionary for ALL buildings
static func get_placement_preview(b_type: String, flipped: bool = false) -> Dictionary:
	var art := get_art_fit(b_type, flipped)
	if not art.is_empty():
		return art
	match b_type:
		"bahay_kubo":
			return {
				"texture": TEX_KUBO_FLIPPED if flipped else TEX_KUBO,
				"scale": 2.0,
				"center_offset": Vector2(32.0, 78.0)
			}
		"solar_dryer":
			return {
				"texture": TEX_DRYER_FLIPPED if flipped else TEX_DRYER,
				"scale": 2.0,
				"center_offset": Vector2(88.0, 56.0)
			}
		"cold_storage":
			return {
				"texture": TEX_COLD_STORAGE_FLIPPED if flipped else TEX_COLD_STORAGE,
				"scale": 2.5,
				"center_offset": Vector2(64.0, 67.2)
			}
		"drone_station":
			return {
				"texture": TEX_DRONE_STATION_FLIPPED if flipped else TEX_DRONE_STATION,
				"scale": 2.0,
				"center_offset": Vector2(40.5, 108.0)
			}
		"weather_station":
			return {
				"texture": TEX_WEATHER_STATION_FLIPPED if flipped else TEX_WEATHER_STATION,
				"scale": 2.0,
				"center_offset": Vector2(56.0, 81.0)
			}
		"water_tower":
			return {
				"texture": TEX_WATER_STATION_FLIPPED if flipped else TEX_WATER_STATION,
				"scale": 2.0,
				"center_offset": Vector2(40.0, 94.0)
			}
		"bodega", "climate_silo":
			return {
				"texture": TEX_SILO_100_FLIPPED if flipped else TEX_SILO_100,
				"scale": 2.5,
				"center_offset": Vector2(24.0, 47.2)
			}
	return {}

func is_storage_building() -> bool:
	return int(Data.get_building(building_type).get("storage_limit", 0)) > 0

func get_storage_capacity() -> int:
	var base := int(Data.get_building(building_type).get("storage_limit", 0))
	return int(base * (1.0 + (level - 1) * 1.0))

func has_space(qty: int = 1) -> bool:
	return (used_storage + qty) <= get_storage_capacity()

func accepts_crop(crop_name: String) -> bool:
	if assigned_crops.is_empty():
		return true
	return assigned_crops.has(crop_name)

func can_store_crop(crop_name: String, qty: int = 1) -> bool:
	return accepts_crop(crop_name) and has_space(qty)

func _get_silo_texture() -> Texture2D:
	var ratio: float = 0.0
	var cap: int = get_storage_capacity()
	if cap > 0:
		ratio = clampf(float(used_storage) / float(cap), 0.0, 1.0)
	elif BuildingManager.total_storage_capacity > 0:
		ratio = clampf(float(BuildingManager.used_storage) / float(BuildingManager.total_storage_capacity), 0.0, 1.0)
	if is_flipped:
		if ratio < 0.125:
			return TEX_SILO_0_FLIPPED
		elif ratio < 0.375:
			return TEX_SILO_25_FLIPPED
		elif ratio < 0.625:
			return TEX_SILO_50_FLIPPED
		elif ratio < 0.875:
			return TEX_SILO_75_FLIPPED
		else:
			return TEX_SILO_100_FLIPPED
	else:
		if ratio < 0.125:
			return TEX_SILO_0
		elif ratio < 0.375:
			return TEX_SILO_25
		elif ratio < 0.625:
			return TEX_SILO_50
		elif ratio < 0.875:
			return TEX_SILO_75
		else:
			return TEX_SILO_100

func _ready() -> void:
	z_index = 10  # Match tile root layer (Z=10) so Godot y_sort_enabled sorts crops, workers, and buildings by Y position
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var b_data: Dictionary = Data.get_building(building_type)
	if not b_data.is_empty():
		footprint = b_data.get("grid_size", Vector2i(2, 2))
		max_level = int(b_data.get("max_level", 3))

	# Compute center of the isometric footprint
	var pts := FarmerMovement.get_footprint_polygon_local(grid_pos, footprint)
	var center := (pts[0] + pts[2]) * 0.5
	position = center

	# Set up authentic high-resolution building art sprite if available
	var fit: Dictionary = get_art_fit(building_type, is_flipped)
	if not fit.is_empty():
		art_sprite = Sprite2D.new()
		art_sprite.name = "ArtSprite"
		art_sprite.texture = fit["texture"]
		art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sc: float = float(fit.get("scale", 1.0))
		art_sprite.scale = Vector2(sc, sc)
		art_sprite.centered = false
		var coff: Vector2 = fit.get("center_offset", Vector2.ZERO)
		art_sprite.position = -coff * sc
		if Data.get_building(building_type).get("is_decoration", false):
			var has_dedicated_flip: bool = fit.get("has_dedicated_flip", false)
			art_sprite.flip_h = is_flipped if not has_dedicated_flip else false
			state = BuildingState.ACTIVE
		art_sprite.show_behind_parent = true
		add_child(art_sprite)

	_setup_ui()
	_update_art_sprite_state()
	TimeManager.period_changed.connect(func(_p, _n): queue_redraw())
	TimeManager.hour_changed.connect(func(_h): queue_redraw())
	if BuildingManager.has_signal("storage_updated"):
		BuildingManager.storage_updated.connect(func(_t, _u): _update_art_sprite_state(); queue_redraw())
	queue_redraw()

func _get_footprint_diamond_pts() -> Array[Vector2]:
	var pts := FarmerMovement.get_footprint_polygon_local(grid_pos, footprint)
	var center := (pts[0] + pts[2]) * 0.5
	return [pts[0] - center, pts[1] - center, pts[2] - center, pts[3] - center]

func _setup_ui() -> void:
	if Data.get_building(building_type).get("is_decoration", false):
		return
	var d_pts := _get_footprint_diamond_pts()
	var roof_apex_y: float = -92.0
	var fit: Dictionary = get_art_fit(building_type)
	if not fit.is_empty():
		roof_apex_y = float(fit.get("roof_apex_y", -92.0))
	elif building_type == "bodega":
		roof_apex_y = -120.0
	elif building_type == "drone_station":
		roof_apex_y = -210.0
	elif building_type == "weather_station":
		roof_apex_y = -198.0
	elif building_type == "water_tower":
		roof_apex_y = -240.0
	elif building_type == "machine_garage":
		roof_apex_y = -72.0
	elif building_type == "cold_storage":
		roof_apex_y = -170.0
	elif building_type == "climate_silo":
		roof_apex_y = -120.0
	elif building_type == "sprinkler":
		roof_apex_y = -28.0
	elif building_type == "rice_mill":
		roof_apex_y = -184.0
	elif building_type == "sugar_mill":
		roof_apex_y = -186.0
	elif building_type == "copra_dryer":
		roof_apex_y = -100.0
	elif building_type == "coffee_roastery":
		roof_apex_y = -178.0

	# Level indicator badge centered above building roof
	level_label = Label.new()
	level_label.position = Vector2(-50, roof_apex_y - 20)
	level_label.size = Vector2(100, 20)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	add_child(level_label)

	# Overhead Construction/Upgrade Progress Bar
	var pbox := VBoxContainer.new()
	pbox.name = "ProgressBox"
	pbox.position = Vector2(-75, roof_apex_y - 48)
	pbox.custom_minimum_size = Vector2(150, 24)
	pbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(pbox)

	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 10)
	progress_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	pbox.add_child(progress_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(150, 8)
	progress_bar.max_value = 100.0
	progress_bar.show_percentage = false
	pbox.add_child(progress_bar)

	# Overhead Storage Fill Bar
	if is_storage_building():
		storage_fill_box = VBoxContainer.new()
		storage_fill_box.name = "StorageFillBox"
		storage_fill_box.position = Vector2(-45, roof_apex_y - 44)
		storage_fill_box.custom_minimum_size = Vector2(90, 20)
		storage_fill_box.alignment = BoxContainer.ALIGNMENT_CENTER
		storage_fill_box.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(storage_fill_box)

		storage_fill_label = Label.new()
		storage_fill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		storage_fill_label.add_theme_font_size_override("font_size", 9)
		storage_fill_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
		storage_fill_label.text = "📦 0/200"
		storage_fill_box.add_child(storage_fill_label)

		storage_fill_bar = ProgressBar.new()
		storage_fill_bar.custom_minimum_size = Vector2(80, 5)
		storage_fill_bar.max_value = get_storage_capacity()
		storage_fill_bar.value = 0.0
		storage_fill_bar.show_percentage = false

		var sb_bg := StyleBoxFlat.new()
		sb_bg.bg_color = Color(0.10, 0.08, 0.06, 0.90)
		sb_bg.border_width_left = 1
		sb_bg.border_width_right = 1
		sb_bg.border_width_top = 1
		sb_bg.border_width_bottom = 1
		sb_bg.border_color = Color(0.35, 0.24, 0.15, 1.0)
		sb_bg.corner_radius_top_left = 2
		sb_bg.corner_radius_top_right = 2
		sb_bg.corner_radius_bottom_left = 2
		sb_bg.corner_radius_bottom_right = 2
		storage_fill_bar.add_theme_stylebox_override("background", sb_bg)

		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = Color(0.35, 0.85, 0.35)
		sb_fill.corner_radius_top_left = 2
		sb_fill.corner_radius_top_right = 2
		sb_fill.corner_radius_bottom_left = 2
		sb_fill.corner_radius_bottom_right = 2
		storage_fill_bar.add_theme_stylebox_override("fill", sb_fill)

		storage_fill_box.add_child(storage_fill_bar)

	_update_ui_state()

func update_storage_display() -> void:
	if not is_storage_building():
		if storage_fill_box:
			storage_fill_box.visible = false
		return

	if storage_fill_box:
		storage_fill_box.visible = (state == BuildingState.ACTIVE)

	if storage_fill_bar and storage_fill_label and state == BuildingState.ACTIVE:
		var cap: int = get_storage_capacity()
		storage_fill_bar.max_value = max(1, cap)
		storage_fill_bar.value = used_storage

		var ratio: float = clampf(float(used_storage) / float(max(1, cap)), 0.0, 1.0)
		var fill_color: Color = Color(0.35, 0.85, 0.35)
		if ratio >= 0.90:
			fill_color = Color(0.95, 0.30, 0.25)
		elif ratio >= 0.70:
			fill_color = Color(1.0, 0.75, 0.25)

		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = fill_color
		sb_fill.corner_radius_top_left = 2
		sb_fill.corner_radius_top_right = 2
		sb_fill.corner_radius_bottom_left = 2
		sb_fill.corner_radius_bottom_right = 2
		storage_fill_bar.add_theme_stylebox_override("fill", sb_fill)

		var icon: String = "📦"
		if building_type == "cold_storage":
			icon = "❄️"
		elif building_type == "climate_silo":
			icon = "🗼"
		if used_storage >= cap and cap > 0:
			storage_fill_label.text = "⚠️ FULL %s %d/%d" % [icon, used_storage, cap]
			storage_fill_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			storage_fill_label.text = "%s %d/%d" % [icon, used_storage, cap]
			storage_fill_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
		var filter_str: String = "All crops"
		if assigned_crops.size() > 0:
			var names: Array[String] = []
			for c in assigned_crops:
				names.append(Data.get_crop(c).get("display_name", c).split("(")[0].strip_edges())
			filter_str = ", ".join(names)
		storage_fill_box.tooltip_text = "%s Storage: %d / %d units (%.0f%% full)\nAccepted: %s" % [
			Data.get_building(building_type).get("display_name", building_type.capitalize()),
			used_storage,
			cap,
			ratio * 100.0,
			filter_str
		]

	queue_redraw()

func _process(delta: float) -> void:
	if building_type in ["drone_station", "weather_station", "water_tower", "machine_garage", "sprinkler", "rice_mill", "sugar_mill", "copra_dryer", "coffee_roastery"] and state == BuildingState.ACTIVE:
		queue_redraw()

	var speed_scale: float = TimeManager.get_speed_scale()
	if speed_scale <= 0.0:
		return

	var dt: float = delta * speed_scale

	if state == BuildingState.CONSTRUCTING:
		progress_timer += dt
		_update_progress_display("🔨 Building...")
		if progress_timer >= duration:
			complete_construction()

	elif state == BuildingState.UPGRADING:
		progress_timer += dt
		_update_progress_display("⬆️ Upgrading...")
		if progress_timer >= duration:
			complete_upgrade()

func _update_progress_display(prefix: String) -> void:
	if progress_bar and progress_label:
		var pct: float = clampf((progress_timer / max(0.1, duration)) * 100.0, 0.0, 100.0)
		progress_bar.value = pct
		var remain: int = int(ceil(max(0.0, duration - progress_timer)))
		progress_label.text = "%s %ds (%.0f%%)" % [prefix, remain, pct]

func _update_ui_state() -> void:
	var stars: String = ""
	for i in range(level):
		stars += "⭐"
	if level_label:
		level_label.text = "%s Lv.%d" % [stars, level]
		level_label.visible = (state == BuildingState.ACTIVE)

	var pbox = get_node_or_null("ProgressBox")
	if pbox:
		pbox.visible = (state != BuildingState.ACTIVE)

	update_storage_display()
	_update_art_sprite_state()
	queue_redraw()

func _update_art_sprite_state() -> void:
	if art_sprite and is_instance_valid(art_sprite):
		if building_type == "bodega" or building_type == "climate_silo":
			art_sprite.texture = _get_silo_texture()
		if state == BuildingState.CONSTRUCTING or state == BuildingState.UPGRADING:
			if building_type == "climate_silo":
				art_sprite.modulate = Color(0.85, 0.95, 1.15, 0.45)
			else:
				art_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
		else:
			if building_type == "climate_silo":
				art_sprite.modulate = Color(0.85, 0.95, 1.15, 1.0)
			else:
				art_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func complete_construction() -> void:
	state          = BuildingState.ACTIVE
	progress_timer = 0.0
	_update_ui_state()
	BuildingManager.recalculate_bonuses()

	# Regrow tiles under the building to lush green grass
	var farm_grid = get_parent()
	if farm_grid and "tiles" in farm_grid:
		for dx in range(footprint.x):
			for dy in range(footprint.y):
				var tp := Vector2i(grid_pos.x + dx, grid_pos.y + dy)
				if farm_grid.has_method("_is_valid") and farm_grid._is_valid(tp):
					var t: FarmTile = farm_grid.tiles[tp.x][tp.y]
					t.soil_moisture = 60.0
					if farm_grid.renderer:
						farm_grid.renderer.update_tile(tp, farm_grid.tiles)

	var b_data := Data.get_building(building_type)
	var b_name: String = str(b_data.get("name", building_type.capitalize()))
	LogManager.log_event("buildings", "Construction finished: %s (Lv. 1) at (%d, %d)." % [b_name, grid_pos.x, grid_pos.y], "🏛️", Color(0.35, 0.8, 1.0, 1.0))
	state_changed.emit(self)
	AudioManager.play_building("complete")
	AudioManager.unregister_active_construction()

func start_upgrade(up_cost: int, up_duration: float) -> bool:
	if state != BuildingState.ACTIVE or level >= max_level:
		return false
	if not EconomyManager.deduct_cash(up_cost):
		return false

	if up_duration <= 0.0:
		complete_upgrade()
		return true

	state          = BuildingState.UPGRADING
	duration       = up_duration
	progress_timer = 0.0
	_update_ui_state()
	var b_data := Data.get_building(building_type)
	var b_name: String = str(b_data.get("name", building_type.capitalize()))
	LogManager.log_event("buildings", "Started upgrade on %s to Lv. %d (₱%d)." % [b_name, level + 1, up_cost], "⬆️", Color(0.7, 0.85, 1.0, 1.0))
	state_changed.emit(self)
	AudioManager.register_active_construction()
	return true

func complete_upgrade() -> void:
	level          += 1
	state          = BuildingState.ACTIVE
	progress_timer = 0.0
	_update_ui_state()
	BuildingManager.recalculate_bonuses()
	var b_data := Data.get_building(building_type)
	var b_name: String = str(b_data.get("name", building_type.capitalize()))
	LogManager.log_event("buildings", "Upgrade completed: %s upgraded to Lv. %d at (%d, %d)." % [b_name, level, grid_pos.x, grid_pos.y], "⭐", Color(1.0, 0.85, 0.3, 1.0))
	state_changed.emit(self)
	AudioManager.play_building("complete")
	AudioManager.unregister_active_construction()

func demolish() -> void:
	if state == BuildingState.CONSTRUCTING or state == BuildingState.UPGRADING:
		AudioManager.unregister_active_construction()
	AudioManager.play_building("demolish")
	var b_data := Data.get_building(building_type)
	var base_cost: int = int(b_data.get("cost", 200))
	var refund: int = int(base_cost * 0.5 * level)
	EconomyManager.add_cash(refund, false)
	var b_name: String = str(b_data.get("name", building_type.capitalize()))
	LogManager.log_event("demolish", "Demolished %s (Lv. %d) for +₱%d refund." % [b_name, level, refund], "💥", Color(0.9, 0.4, 0.3, 1.0))
	demolished.emit(self)
	queue_free()

# ---------------------------------------------------------------------------
# Rendering: Procedural 2.5D Isometric RTS / Clash of Clans Architecture
# ---------------------------------------------------------------------------
func _draw() -> void:
	var d_pts := _get_footprint_diamond_pts()
	var top    := d_pts[0]
	var right  := d_pts[1]
	var bottom := d_pts[2]
	var left   := d_pts[3]

	# 1. Foundation Platform (Isometric Base Slab)
	# Only drawn for heavy industrial facilities without built-in pixel-art bases; Bahay Kubo, Silo, Bilaran dryer, Cold Storage, Drone Station, Water Tower, Weather Station, and new trade hubs have authentic pixel-art terrain bases!
	var fit: Dictionary = get_art_fit(building_type)
	if fit.is_empty() and building_type != "bodega" and building_type != "bahay_kubo" and building_type != "solar_dryer" and building_type != "drone_station" and building_type != "drone_pad" and building_type != "water_tower" and building_type != "sprinkler" and building_type != "cold_storage" and building_type != "weather_station":
		draw_colored_polygon(PackedVector2Array(d_pts), Color(0.25, 0.21, 0.17, 0.95))
		var slab_depth: float = 8.0
		draw_colored_polygon(PackedVector2Array([left, bottom, bottom + Vector2(0, slab_depth), left + Vector2(0, slab_depth)]), Color(0.18, 0.14, 0.10, 0.95))
		draw_colored_polygon(PackedVector2Array([bottom, right, right + Vector2(0, slab_depth), bottom + Vector2(0, slab_depth)]), Color(0.22, 0.18, 0.13, 0.95))
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(0.12, 0.10, 0.08, 1.0), 2.0)

	# 2. Draw 2.5D building-specific artwork
	match building_type:
		"bahay_kubo":
			_draw_bahay_kubo(top, right, bottom, left)
		"bodega":
			_draw_bodega(top, right, bottom, left)
		"cold_storage":
			_draw_cold_storage(top, right, bottom, left)
		"solar_dryer":
			_draw_solar_dryer(top, right, bottom, left)
		"machine_garage":
			_draw_bayanihan_center(top, right, bottom, left)
		"climate_silo":
			_draw_silo(top, right, bottom, left)
		"drone_station":
			_draw_drone_station(top, right, bottom, left)
		"drone_pad":
			_draw_drone_pad(top, right, bottom, left)
		"weather_station":
			_draw_weather_station(top, right, bottom, left)
		"water_tower":
			_draw_water_tower(top, right, bottom, left)
		"sprinkler":
			_draw_sprinkler(top, right, bottom, left)
		_:
			if not fit.is_empty():
				_draw_art_building(top, right, bottom, left)
			else:
				_draw_default_building(top, right, bottom, left)

	# 3. Construction Scaffold Overlay (if constructing or upgrading)
	if state == BuildingState.CONSTRUCTING or state == BuildingState.UPGRADING:
		_draw_scaffold_overlay(top, right, bottom, left)

func _draw_bahay_kubo(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var tex := TEX_KUBO_FLIPPED if is_flipped else TEX_KUBO
	if tex != null:
		var fs: float = -1.0 if is_flipped else 1.0
		# Pixel-art Bahay Kubo sprite (64x96 at 2x scale = 128x192)
		var kubo_w: float = float(tex.get_width()) * 2.0
		var kubo_h: float = float(tex.get_height()) * 2.0
		var kubo_rect := Rect2(-kubo_w * 0.5, -156.0, kubo_w, kubo_h)
		draw_texture_rect(tex, kubo_rect, false)

		# Warm nighttime Capiz window & gasera porch lantern glow
		if TimeManager.is_night():
			var win_pos := Vector2(-12.0 * fs, -82.0)
			draw_circle(win_pos, 16.0, Color(1.0, 0.85, 0.35, 0.25))
			draw_circle(win_pos, 8.0, Color(1.0, 0.92, 0.45, 0.45))
			var porch_pos := Vector2(0.0, -60.0)
			draw_circle(porch_pos, 14.0, Color(1.0, 0.80, 0.25, 0.20))
			draw_circle(porch_pos, 6.0, Color(1.0, 0.95, 0.50, 0.45))
			draw_circle(porch_pos, 2.5, Color(1.0, 0.98, 0.80, 0.95))

		# Level upgrade indicators
		if level >= 2:
			draw_circle(Vector2(20.0 * fs, -58.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-20.0 * fs, -58.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var stilt_h: float = 24.0
	var wall_h: float  = 30.0

	# Bamboo stilts
	var stilt_col := Color(0.48, 0.34, 0.18)
	var pts_base := [top * 0.7, right * 0.7, bottom * 0.7, left * 0.7]
	for p in pts_base:
		draw_line(p, p + Vector2(0, -stilt_h), stilt_col, 4.0)

	# Woven sawali bamboo walls
	var floor_top    := top * 0.7 + Vector2(0, -stilt_h)
	var floor_right  := right * 0.7 + Vector2(0, -stilt_h)
	var floor_bottom := bottom * 0.7 + Vector2(0, -stilt_h)
	var floor_left   := left * 0.7 + Vector2(0, -stilt_h)

	var wall_left_pts := PackedVector2Array([
		floor_left, floor_bottom, floor_bottom + Vector2(0, -wall_h), floor_left + Vector2(0, -wall_h)
	])
	draw_colored_polygon(wall_left_pts, Color(0.72, 0.58, 0.32))
	draw_polyline(wall_left_pts, Color(0.40, 0.28, 0.12), 1.5)

	var wall_right_pts := PackedVector2Array([
		floor_bottom, floor_right, floor_right + Vector2(0, -wall_h), floor_bottom + Vector2(0, -wall_h)
	])
	draw_colored_polygon(wall_right_pts, Color(0.60, 0.48, 0.24))
	draw_polyline(wall_right_pts, Color(0.35, 0.24, 0.10), 1.5)

	# Thatched Nipa Palm Roof (3D Gable Pitch)
	var roof_apex := Vector2(0, -stilt_h - wall_h - 32.0)
	var eave_left := floor_left + Vector2(-8, -wall_h + 4)
	var eave_right := floor_right + Vector2(8, -wall_h + 4)
	var eave_front := floor_bottom + Vector2(0, -wall_h + 8)

	var roof_front_left := PackedVector2Array([roof_apex, eave_front, eave_left])
	draw_colored_polygon(roof_front_left, Color(0.85, 0.70, 0.30))
	draw_polyline(roof_front_left, Color(0.48, 0.36, 0.12), 2.0)

	var roof_front_right := PackedVector2Array([roof_apex, eave_right, eave_front])
	draw_colored_polygon(roof_front_right, Color(0.74, 0.58, 0.22))
	draw_polyline(roof_front_right, Color(0.42, 0.30, 0.10), 2.0)

	# Capiz-shell window on front-left woven bamboo wall
	var win_center: Vector2 = (floor_left + floor_bottom) * 0.5 + Vector2(0, -wall_h * 0.5)
	var win_w: float = 12.0
	var win_h: float = 10.0
	var win_rect := Rect2(win_center.x - win_w * 0.5, win_center.y - win_h * 0.5, win_w, win_h)
	var is_night: bool = TimeManager.is_night()

	if is_night:
		# Warm glowing window lamplight in the dark
		draw_circle(win_center, 18.0, Color(1.0, 0.80, 0.25, 0.22))
		draw_circle(win_center, 10.0, Color(1.0, 0.90, 0.40, 0.45))
		draw_rect(win_rect, Color(1.0, 0.92, 0.45, 0.95))
		draw_rect(win_rect, Color(0.45, 0.30, 0.12, 1.0), false, 1.5)
		draw_line(Vector2(win_rect.position.x + win_w * 0.5, win_rect.position.y), Vector2(win_rect.position.x + win_w * 0.5, win_rect.end.y), Color(0.45, 0.30, 0.12), 1.0)
		draw_line(Vector2(win_rect.position.x, win_rect.position.y + win_h * 0.5), Vector2(win_rect.end.x, win_rect.position.y + win_h * 0.5), Color(0.45, 0.30, 0.12), 1.0)
	else:
		# Translucent natural Capiz oyster shell window
		draw_rect(win_rect, Color(0.88, 0.85, 0.76, 0.92))
		draw_rect(win_rect, Color(0.40, 0.28, 0.12, 1.0), false, 1.2)
		draw_line(Vector2(win_rect.position.x + win_w * 0.5, win_rect.position.y), Vector2(win_rect.position.x + win_w * 0.5, win_rect.end.y), Color(0.40, 0.28, 0.12), 1.0)
		draw_line(Vector2(win_rect.position.x, win_rect.position.y + win_h * 0.5), Vector2(win_rect.end.x, win_rect.position.y + win_h * 0.5), Color(0.40, 0.28, 0.12), 1.0)

	# Porch hanging gasera lantern on front eave
	var lantern_pos := eave_front + Vector2(0, 4)
	if is_night:
		draw_circle(lantern_pos, 14.0, Color(1.0, 0.80, 0.25, 0.20))
		draw_circle(lantern_pos, 6.0, Color(1.0, 0.92, 0.50, 0.40))
		draw_circle(lantern_pos, 2.5, Color(1.0, 0.98, 0.75, 0.95))
		draw_rect(Rect2(lantern_pos.x - 2, lantern_pos.y - 1, 4, 4), Color(0.30, 0.22, 0.12, 0.90))
		draw_line(lantern_pos + Vector2(0, -5), lantern_pos + Vector2(0, -1), Color(0.4, 0.3, 0.2), 1.0)

	# Thatch straw texture lines
	draw_line(roof_apex, (eave_left + eave_front) * 0.5, Color(0.60, 0.46, 0.16), 1.5)
	draw_line(roof_apex, (eave_right + eave_front) * 0.5, Color(0.55, 0.40, 0.14), 1.5)

func _draw_bodega(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var tex := _get_silo_texture()
	if tex != null:
		# Pixel-art Silo sprite (48x64 at 2.5x scale = 120x160)
		var silo_w: float = float(tex.get_width()) * 2.5
		var silo_h: float = float(tex.get_height()) * 2.5
		var silo_rect := Rect2(-silo_w * 0.5, -118.0, silo_w, silo_h)
		draw_texture_rect(tex, silo_rect, false)

		# Night work light on intake / base
		if TimeManager.is_night():
			var lamp_p := Vector2(0.0, -62.0)
			draw_circle(lamp_p, 14.0, Color(1.0, 0.80, 0.30, 0.22))
			draw_circle(lamp_p, 5.0, Color(1.0, 0.90, 0.50, 0.50))
			draw_circle(lamp_p, 1.5, Color(1.0, 0.98, 0.80, 0.95))

		# Level indicators
		var fs: float = -1.0 if is_flipped else 1.0
		if level >= 2:
			draw_circle(Vector2(22.0 * fs, -102.0), 2.5, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-22.0 * fs, -102.0), 2.5, Color(0.95, 0.85, 0.3, 0.9))
		return

	# 1. Compact Agricultural Gravel Pad & Concrete Curbing (2x2 Footprint)
	var pad_scale: float = 0.90
	var p_top: Vector2    = top * pad_scale
	var p_right: Vector2  = right * pad_scale
	var p_bottom: Vector2 = bottom * pad_scale
	var p_left: Vector2   = left * pad_scale

	# Low-profile concrete foundation edge curb (3.0px drop)
	var curb_h: float = 3.0
	var curb_left := PackedVector2Array([
		p_left, p_bottom, p_bottom + Vector2(0, curb_h), p_left + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_left, Color(0.38, 0.36, 0.32))

	var curb_right := PackedVector2Array([
		p_bottom, p_right, p_right + Vector2(0, curb_h), p_bottom + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_right, Color(0.46, 0.44, 0.39))

	# Clean compacted gravel / crushed limestone yard
	var pad := PackedVector2Array([p_top, p_right, p_bottom, p_left])
	draw_colored_polygon(pad, Color(0.72, 0.70, 0.65))
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), Color(0.46, 0.43, 0.38), 1.5)

	# Equipment & grain cart wheel tracks
	var track_col := Color(0.58, 0.55, 0.49, 0.45)
	draw_line(p_bottom * 0.72 + Vector2(-8, 0), (p_bottom + p_right) * 0.36, track_col, 1.2)
	draw_line(p_bottom * 0.72 + Vector2(6, 0), (p_bottom + p_right) * 0.36 + Vector2(5, 2), track_col, 1.2)

	# 2. Compact Grain Bins in a neat straight row along the isometric axis (2x2 layout)
	# Silo height is low-profile (14-15px cylinder + 7-7.5px cone = ~21-22px total height)
	match level:
		1:
			# Level 1: 2 small cone bins side-by-side
			_draw_single_grain_silo(-13.0, -6.5, 12.0, 15.0, 7.5, true, true)
			_draw_single_grain_silo(11.0, 5.5, 12.0, 15.0, 7.5, true, true)
			_draw_grain_auger(Vector2(11.0, 5.5 - 15.0 - 7.5), Vector2(28.0, 14.0))

		2:
			# Level 2: 3 small cone bins in a neat row + catwalk
			_draw_single_grain_silo(-20.0, -10.0, 10.5, 15.0, 7.5, true, true)
			_draw_single_grain_silo(0.0, 0.0, 10.5, 15.0, 7.5, true, true)
			_draw_single_grain_silo(20.0, 10.0, 10.5, 15.0, 7.5, true, true)

			# Small roof catwalk
			var p1 := Vector2(-20.0, -10.0 - 15.0 - 4.0)
			var p2 := Vector2(20.0, 10.0 - 15.0 - 4.0)
			draw_line(p1, p2, Color(0.35, 0.38, 0.44), 2.0)
			draw_line(p1 + Vector2(0, -3), p2 + Vector2(0, -3), Color(0.48, 0.52, 0.58), 1.0)

			_draw_grain_auger(Vector2(20.0, 10.0 - 15.0 - 7.5), Vector2(36.0, 18.0))

		_:
			# Level 3: 4 small cone bins in a neat straight row
			_draw_single_grain_silo(-27.0, -13.5, 9.5, 14.0, 7.0, true, true)
			_draw_single_grain_silo(-9.0, -4.5, 9.5, 14.0, 7.0, true, true)
			_draw_single_grain_silo(9.0, 4.5, 9.5, 14.0, 7.0, true, true)
			_draw_single_grain_silo(27.0, 13.5, 9.5, 14.0, 7.0, true, true)

			# Catwalk connecting all 4 bins
			var p1 := Vector2(-27.0, -13.5 - 14.0 - 4.0)
			var p2 := Vector2(27.0, 13.5 - 14.0 - 4.0)
			draw_line(p1, p2, Color(0.35, 0.38, 0.44), 2.0)
			draw_line(p1 + Vector2(0, -3), p2 + Vector2(0, -3), Color(0.48, 0.52, 0.58), 1.0)

			_draw_grain_auger(Vector2(27.0, 13.5 - 14.0 - 7.0), Vector2(42.0, 21.0))

func _draw_single_grain_silo(cx: float, cy: float, rx: float = 16.0, height: float = 18.0, cone_h: float = 9.0, has_ladder: bool = true, has_spout: bool = true) -> void:
	var ry: float = rx * 0.5  # 2:1 isometric vertical foreshortening

	# 1. Base Concrete Foundation Ring
	var base_ring: PackedVector2Array = []
	for a in range(12):
		var th: float = float(a) / 12.0 * TAU
		base_ring.append(Vector2(cx + (rx + 2.0) * cos(th), cy + (ry + 1.0) * sin(th)))
	draw_colored_polygon(base_ring, Color(0.50, 0.48, 0.44))
	draw_polyline(base_ring, Color(0.32, 0.30, 0.28), 1.0)

	# 2. Corrugated Galvanized Steel Cylinder Body
	const NUM_SEGS: int = 6
	var rim_pts: PackedVector2Array = []

	for i in range(NUM_SEGS):
		var a1: float = PI * (float(i) / float(NUM_SEGS))
		var a2: float = PI * (float(i + 1) / float(NUM_SEGS))
		var x1: float = cx - rx * cos(a1)
		var y1: float = cy + ry * sin(a1)
		var x2: float = cx - rx * cos(a2)
		var y2: float = cy + ry * sin(a2)

		if i == 0:
			rim_pts.append(Vector2(x1, y1 - height))
		rim_pts.append(Vector2(x2, y2 - height))

		# Panel shading: light comes from top-right in RTS isometric
		var t: float = float(i) / float(NUM_SEGS - 1)
		var panel_col: Color = Color(0.56, 0.60, 0.65).lerp(Color(0.88, 0.91, 0.95), t)

		var quad := PackedVector2Array([
			Vector2(x1, y1),
			Vector2(x2, y2),
			Vector2(x2, y2 - height),
			Vector2(x1, y1 - height)
		])
		draw_colored_polygon(quad, panel_col)

		# Vertical panel seam
		draw_line(Vector2(x1, y1), Vector2(x1, y1 - height), Color(0.38, 0.42, 0.48, 0.5), 1.0)
		if i == NUM_SEGS - 1:
			draw_line(Vector2(x2, y2), Vector2(x2, y2 - height), Color(0.38, 0.42, 0.48, 0.5), 1.0)

	# Horizontal Corrugation Ring Lines across the cylinder
	for frac in [0.35, 0.70]:
		var ridge_pts: PackedVector2Array = []
		for k in range(NUM_SEGS + 1):
			var ak: float = PI * (float(k) / float(NUM_SEGS))
			ridge_pts.append(Vector2(cx - rx * cos(ak), cy + ry * sin(ak) - height * frac))
		draw_polyline(ridge_pts, Color(0.40, 0.44, 0.50, 0.45), 1.0)

	# 3. Conical Roof ("Cone Thing")
	var apex := Vector2(cx, cy - height - cone_h)

	for i in range(NUM_SEGS):
		var a1: float = PI * (float(i) / float(NUM_SEGS))
		var a2: float = PI * (float(i + 1) / float(NUM_SEGS))
		var x1: float = cx - rx * cos(a1)
		var y1: float = cy + ry * sin(a1)
		var x2: float = cx - rx * cos(a2)
		var y2: float = cy + ry * sin(a2)

		var t: float = float(i) / float(NUM_SEGS - 1)
		var cone_col: Color = Color(0.62, 0.66, 0.72).lerp(Color(0.92, 0.94, 0.97), t)

		var tri := PackedVector2Array([
			apex,
			Vector2(x1, y1 - height),
			Vector2(x2, y2 - height)
		])
		draw_colored_polygon(tri, cone_col)

		# Radiating roof seam ribs
		draw_line(apex, Vector2(x1, y1 - height), Color(0.42, 0.46, 0.52, 0.6), 1.0)
		if i == NUM_SEGS - 1:
			draw_line(apex, Vector2(x2, y2 - height), Color(0.42, 0.46, 0.52, 0.6), 1.0)

	# Crisp roof eave rim
	draw_polyline(rim_pts, Color(0.32, 0.35, 0.40), 1.2)

	# Silo Apex Cap & Vent
	draw_circle(apex, 3.0, Color(0.38, 0.42, 0.48))
	draw_circle(apex + Vector2(1, -1), 1.2, Color(0.95, 0.96, 0.98))

	# 4. Access Inspection Ladder (Front-Left Face)
	if has_ladder:
		var lx: float = cx - rx * cos(PI * 0.28)
		var ly: float = cy + ry * sin(PI * 0.28)
		draw_line(Vector2(lx - 2.0, ly), Vector2(lx - 2.0, ly - height), Color(0.28, 0.30, 0.35), 1.0)
		draw_line(Vector2(lx + 2.0, ly), Vector2(lx + 2.0, ly - height), Color(0.28, 0.30, 0.35), 1.0)
		for y_step in range(3, int(height), 4):
			draw_line(Vector2(lx - 2.0, ly - float(y_step)), Vector2(lx + 2.0, ly - float(y_step)), Color(0.22, 0.24, 0.28), 1.0)
		draw_line(Vector2(lx, ly - height), Vector2(lx, ly - height - 5), Color(0.28, 0.30, 0.35), 1.0)

	# 5. Base Discharge Chute & Gate
	if has_spout:
		var spout_rect := Rect2(cx - 3.5, cy + ry - 5.0, 7.0, 5.0)
		draw_rect(spout_rect, Color(0.30, 0.33, 0.38), true)
		draw_rect(spout_rect, Color(0.18, 0.20, 0.24), false, 1.0)
		draw_circle(Vector2(cx, cy + ry - 2.5), 1.5, Color(0.85, 0.25, 0.20))

func _draw_grain_auger(apex_target: Vector2, ground_source: Vector2) -> void:
	var hx := ground_source.x
	var hy := ground_source.y

	# Transport wheels
	draw_circle(Vector2(hx - 6, hy + 2), 3.0, Color(0.18, 0.18, 0.20))
	draw_circle(Vector2(hx - 6, hy + 2), 1.2, Color(0.70, 0.70, 0.70))
	draw_circle(Vector2(hx + 6, hy + 2), 3.0, Color(0.18, 0.18, 0.20))
	draw_circle(Vector2(hx + 6, hy + 2), 1.2, Color(0.70, 0.70, 0.70))
	draw_line(Vector2(hx - 6, hy + 2), Vector2(hx + 6, hy + 2), Color(0.35, 0.35, 0.38), 1.5)

	# Red intake hopper bin
	var hopper_poly := PackedVector2Array([
		Vector2(hx - 6, hy + 1),
		Vector2(hx + 6, hy + 1),
		Vector2(hx + 8, hy - 6),
		Vector2(hx - 8, hy - 6)
	])
	draw_colored_polygon(hopper_poly, Color(0.85, 0.22, 0.18))
	draw_polyline(hopper_poly, Color(0.50, 0.12, 0.10), 1.0)

	# Scissor Lift A-Frame Support Truss (Farm Red)
	var mid_pipe: Vector2 = ground_source.lerp(apex_target, 0.48)
	draw_line(mid_pipe, Vector2(hx - 4, hy + 1), Color(0.78, 0.20, 0.15), 1.5)
	draw_line(mid_pipe, Vector2(hx + 4, hy + 1), Color(0.78, 0.20, 0.15), 1.5)

	# Compact Yellow Grain Auger Tube
	var intake_p := Vector2(hx, hy - 3)
	var discharge_p := apex_target + Vector2(2, 2)

	draw_line(intake_p, discharge_p, Color(0.28, 0.22, 0.05), 4.0)
	draw_line(intake_p, discharge_p, Color(0.95, 0.76, 0.12), 2.5)
	draw_line(intake_p + Vector2(0, -1), discharge_p + Vector2(0, -1), Color(1.0, 0.92, 0.45), 1.0)

	# Discharge head spout collar
	draw_circle(discharge_p, 3.0, Color(0.25, 0.28, 0.32))
	draw_circle(discharge_p, 1.5, Color(0.90, 0.75, 0.15))

	# Amber security work light on intake hopper at night
	if TimeManager.is_night():
		var lamp_p := Vector2(hx, hy - 4)
		draw_circle(lamp_p, 14.0, Color(1.0, 0.75, 0.20, 0.22))
		draw_circle(lamp_p, 6.0, Color(1.0, 0.88, 0.40, 0.45))
		draw_circle(lamp_p, 2.0, Color(1.0, 0.98, 0.75, 0.95))

func _draw_cold_storage(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var tex := TEX_COLD_STORAGE_FLIPPED if is_flipped else TEX_COLD_STORAGE
	if tex != null:
		var fs: float = -1.0 if is_flipped else 1.0
		# Pixel-art Cold Storage sprite (128x96 at 2.5x scale = 320x240)
		var cs_w: float = float(tex.get_width()) * 2.5
		var cs_h: float = float(tex.get_height()) * 2.5
		var cs_rect := Rect2(-cs_w * 0.5, -168.0, cs_w, cs_h)
		draw_texture_rect(tex, cs_rect, false)

		# Night AC & entrance security lights
		if TimeManager.is_night():
			var lamp_p := Vector2(-28.0 * fs, -40.0)
			draw_circle(lamp_p, 16.0, Color(0.40, 0.85, 1.0, 0.25))
			draw_circle(lamp_p, 6.0, Color(0.60, 0.92, 1.0, 0.50))
			draw_circle(lamp_p, 2.0, Color(0.95, 0.98, 1.0, 0.95))

		# Level indicators
		if level >= 2:
			draw_circle(Vector2(40.0 * fs, -98.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-40.0 * fs, -98.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var wall_h: float = 46.0

	# Insulated refrigeration walls (clean cooling blue/white)
	var w_left := PackedVector2Array([
		left * 0.85, bottom * 0.85, bottom * 0.85 + Vector2(0, -wall_h), left * 0.85 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_left, Color(0.82, 0.90, 0.96))
	draw_polyline(w_left, Color(0.40, 0.60, 0.78), 2.0)

	var w_right := PackedVector2Array([
		bottom * 0.85, right * 0.85, right * 0.85 + Vector2(0, -wall_h), bottom * 0.85 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_right, Color(0.68, 0.78, 0.86))
	draw_polyline(w_right, Color(0.35, 0.50, 0.68), 2.0)

	# Heavy airtight cold-vault door with rotary wheel
	var door_p := (left * 0.85 + bottom * 0.85) * 0.5
	var d_pts := PackedVector2Array([
		door_p + Vector2(-15, 0), door_p + Vector2(15, 0),
		door_p + Vector2(15, -28), door_p + Vector2(-15, -28)
	])
	draw_colored_polygon(d_pts, Color(0.38, 0.48, 0.60))
	draw_polyline(d_pts, Color(0.20, 0.32, 0.46), 2.0)
	draw_circle(door_p + Vector2(0, -14), 4.5, Color(0.88, 0.94, 1.0))

	# Insulated Cooling Roof & AC fans
	var roof_pts := PackedVector2Array([
		top * 0.85 + Vector2(0, -wall_h),
		right * 0.85 + Vector2(0, -wall_h),
		bottom * 0.85 + Vector2(0, -wall_h),
		left * 0.85 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(roof_pts, Color(0.28, 0.48, 0.72))
	draw_polyline(roof_pts, Color(0.18, 0.32, 0.52), 2.0)
	# Dual condenser fan circles on roof
	draw_circle(Vector2(-16, -wall_h - 6), 7.0, Color(0.20, 0.35, 0.50))
	draw_circle(Vector2(16, -wall_h - 6), 7.0, Color(0.20, 0.35, 0.50))

func _draw_solar_dryer(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var tex := TEX_DRYER_FLIPPED if is_flipped else TEX_DRYER
	if tex != null:
		var fs: float = -1.0 if is_flipped else 1.0
		# Pixel-art Solar Dryer (Bilaran) concrete pavement (176x112)
		var dryer_w: float = float(tex.get_width()) * 2.0
		var dryer_h: float = float(tex.get_height()) * 2.0
		var dryer_rect: Rect2
		if footprint.y == 3 and footprint.x == 3:
			dryer_rect = Rect2(-176.0, -112.0, dryer_w, dryer_h)
		elif footprint.y == 3 or footprint.x == 3:
			dryer_rect = Rect2(-194.0 if is_flipped else -158.0, -104.0, dryer_w, dryer_h)
		else:
			var s_w := (right.x - left.x)
			var s_h := s_w * (112.0 / 176.0)
			dryer_rect = Rect2(-s_w * 0.5, -s_h * 0.5, s_w, s_h)
		draw_texture_rect(tex, dryer_rect, false)

		# Golden sun-drying palay grain patches spread on the concrete
		var mat1 := PackedVector2Array([Vector2(-45 * fs, -12), Vector2(15 * fs, -42), Vector2(55 * fs, -22), Vector2(-5 * fs, 8)])
		draw_colored_polygon(mat1, Color(0.92, 0.80, 0.25, 0.92))
		draw_polyline(PackedVector2Array([mat1[0], mat1[1], mat1[2], mat1[3], mat1[0]]), Color(0.72, 0.58, 0.15, 0.85), 1.0)

		if level >= 2:
			var mat2 := PackedVector2Array([Vector2(30 * fs, 0), Vector2(85 * fs, -28), Vector2(120 * fs, -10), Vector2(65 * fs, 18)])
			draw_colored_polygon(mat2, Color(0.95, 0.84, 0.30, 0.92))
			draw_polyline(PackedVector2Array([mat2[0], mat2[1], mat2[2], mat2[3], mat2[0]]), Color(0.74, 0.60, 0.18, 0.85), 1.0)

		if level >= 3:
			var mat3 := PackedVector2Array([Vector2(-110 * fs, 10), Vector2(-70 * fs, -10), Vector2(-40 * fs, 5), Vector2(-80 * fs, 25)])
			draw_colored_polygon(mat3, Color(0.28, 0.65, 0.88, 0.90))
		return

	# Polished concrete drying pavement (Bilaran)
	var pad := PackedVector2Array([top * 0.9, right * 0.9, bottom * 0.9, left * 0.9])
	draw_colored_polygon(pad, Color(0.74, 0.72, 0.68))
	draw_polyline(PackedVector2Array([top * 0.9, right * 0.9, bottom * 0.9, left * 0.9, top * 0.9]), Color(0.48, 0.45, 0.40), 2.0)

	# Golden sun-drying palay grain patches
	var mat1 := PackedVector2Array([top * 0.6, (top + right) * 0.35, bottom * 0.1, left * 0.5])
	draw_colored_polygon(mat1, Color(0.92, 0.80, 0.25, 0.95))

	var mat2 := PackedVector2Array([bottom * 0.2, right * 0.65, bottom * 0.75, (bottom + left) * 0.4])
	draw_colored_polygon(mat2, Color(0.92, 0.80, 0.25, 0.95))

func _draw_art_building(_top: Vector2, _right: Vector2, _bottom: Vector2, _left: Vector2) -> void:
	# 1. Nighttime lighting
	if TimeManager.is_night():
		var fs: float = -1.0 if is_flipped else 1.0
		match building_type:
			"bayanihan_center":
				draw_circle(Vector2(0.0, -18.0), 16.0, Color(1.0, 0.85, 0.40, 0.25))
				draw_circle(Vector2(0.0, -18.0), 6.0, Color(1.0, 0.92, 0.55, 0.50))
			"tacurong_mill":
				draw_circle(Vector2(-32.0 * fs, -42.0), 24.0, Color(1.0, 0.85, 0.35, 0.22))
				draw_circle(Vector2(-32.0 * fs, -42.0), 8.0, Color(1.0, 0.90, 0.50, 0.50))
				draw_circle(Vector2(64.0 * fs, -32.0), 18.0, Color(1.0, 0.85, 0.35, 0.20))
			"koronadal_wholesale":
				draw_circle(Vector2(-20.0 * fs, -40.0), 24.0, Color(1.0, 0.85, 0.35, 0.22))
				draw_circle(Vector2(-20.0 * fs, -40.0), 8.0, Color(1.0, 0.90, 0.50, 0.50))
				draw_circle(Vector2(85.0 * fs, -30.0), 20.0, Color(1.0, 0.85, 0.35, 0.20))
			"gensan_seaport":
				draw_circle(Vector2(70.0 * fs, -22.0), 22.0, Color(1.0, 0.90, 0.40, 0.25))
				draw_circle(Vector2(70.0 * fs, -22.0), 8.0, Color(1.0, 0.95, 0.60, 0.55))
				draw_circle(Vector2(-58.0 * fs, -46.0), 18.0, Color(0.40, 0.80, 1.0, 0.22))
			"rice_mill":
				draw_circle(Vector2(0.0, -36.0), 22.0, Color(1.0, 0.85, 0.35, 0.25))
				draw_circle(Vector2(0.0, -36.0), 8.0, Color(1.0, 0.90, 0.50, 0.55))
			"sugar_mill":
				draw_circle(Vector2(-16.0 * fs, -42.0), 24.0, Color(1.0, 0.60, 0.20, 0.25))
				draw_circle(Vector2(-16.0 * fs, -42.0), 9.0, Color(1.0, 0.75, 0.30, 0.55))
			"copra_dryer":
				draw_circle(Vector2(-20.0 * fs, -18.0), 18.0, Color(1.0, 0.50, 0.15, 0.25))
				draw_circle(Vector2(-20.0 * fs, -18.0), 6.0, Color(1.0, 0.70, 0.25, 0.55))
			"coffee_roastery":
				draw_circle(Vector2(-15.0 * fs, -36.0), 22.0, Color(1.0, 0.55, 0.20, 0.25))
				draw_circle(Vector2(-15.0 * fs, -36.0), 8.0, Color(1.0, 0.75, 0.30, 0.55))

func _draw_bayanihan_center(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var post_h: float = 44.0
	var t: float = float(Time.get_ticks_msec()) * 0.001

	# 1. Soft Isometric Ground Shadow beneath the 2x2 pavilion
	var shadow_poly := PackedVector2Array([
		top * 0.95 + Vector2(0, 4),
		right * 0.95 + Vector2(6, 4),
		bottom * 0.95 + Vector2(0, 6),
		left * 0.95 + Vector2(-6, 4)
	])
	draw_colored_polygon(shadow_poly, Color(0.06, 0.10, 0.05, 0.30))

	# 2. Packed Earth & Raised Bamboo Slatted Platform (Kawayan Deck)
	var deck_elev: float = -8.0
	var deck_pts := PackedVector2Array([
		top * 0.82 + Vector2(0, deck_elev),
		right * 0.82 + Vector2(0, deck_elev),
		bottom * 0.82 + Vector2(0, deck_elev),
		left * 0.82 + Vector2(0, deck_elev)
	])
	# Deck edge foundation skirting
	var skirt_pts := PackedVector2Array([
		left * 0.82 + Vector2(0, deck_elev),
		bottom * 0.82 + Vector2(0, deck_elev),
		bottom * 0.82,
		left * 0.82
	])
	draw_colored_polygon(skirt_pts, Color(0.38, 0.28, 0.18))
	var skirt_right := PackedVector2Array([
		bottom * 0.82 + Vector2(0, deck_elev),
		right * 0.82 + Vector2(0, deck_elev),
		right * 0.82,
		bottom * 0.82
	])
	draw_colored_polygon(skirt_right, Color(0.32, 0.22, 0.14))

	# Polished bamboo slat deck surface
	draw_colored_polygon(deck_pts, Color(0.72, 0.58, 0.34))
	draw_polyline(deck_pts, Color(0.42, 0.30, 0.16), 1.5)

	# Bamboo slat floor texture lines
	for i in range(1, 7):
		var f: float = float(i) / 7.0
		var p1 := (left * 0.82 + Vector2(0, deck_elev)).lerp(top * 0.82 + Vector2(0, deck_elev), f)
		var p2 := (bottom * 0.82 + Vector2(0, deck_elev)).lerp(right * 0.82 + Vector2(0, deck_elev), f)
		draw_line(p1, p2, Color(0.55, 0.42, 0.24, 0.5), 1.0)

	# 3. Four Heavy Bamboo / Molave Corner Timber Posts
	var p_top := top * 0.75 + Vector2(0, deck_elev)
	var p_right := right * 0.75 + Vector2(0, deck_elev)
	var p_bottom := bottom * 0.75 + Vector2(0, deck_elev)
	var p_left := left * 0.75 + Vector2(0, deck_elev)

	# Rear posts drawn first
	for pt: Vector2 in [p_top, p_right, p_left]:
		draw_line(pt, pt + Vector2(0, -post_h), Color(0.46, 0.34, 0.20), 4.0)
		draw_line(pt, pt + Vector2(0, -post_h), Color(0.68, 0.52, 0.30), 2.0)
		# Bamboo node rings
		for n in range(3):
			var ny: float = -post_h * (float(n + 1) / 4.0)
			draw_line(pt + Vector2(-2, ny), pt + Vector2(2, ny), Color(0.32, 0.22, 0.12), 1.5)

	# 4. Communal Chalkboard / Directive Bulletin Board (Mounted on rear wall)
	var board_center := (p_top + p_right) * 0.5 + Vector2(-2, -post_h * 0.45)
	var b_w: float = 24.0
	var b_h: float = 16.0
	# Wooden frame
	draw_rect(Rect2(board_center.x - b_w * 0.5 - 2, board_center.y - b_h * 0.5 - 2, b_w + 4, b_h + 4), Color(0.40, 0.28, 0.16))
	# Chalkboard slate
	draw_rect(Rect2(board_center.x - b_w * 0.5, board_center.y - b_h * 0.5, b_w, b_h), Color(0.18, 0.26, 0.20))
	# Chalk scribbles / directive icons
	draw_line(board_center + Vector2(-9, -4), board_center + Vector2(9, -4), Color(1.0, 1.0, 1.0, 0.8), 1.2) # Header line
	draw_line(board_center + Vector2(-8, 0), board_center + Vector2(4, 0), Color(0.95, 0.88, 0.50, 0.75), 1.0)
	draw_line(board_center + Vector2(-8, 3), board_center + Vector2(6, 3), Color(0.70, 0.90, 0.75, 0.75), 1.0)
	# Handshake chalk emblem
	draw_circle(board_center + Vector2(5, -4), 1.5, Color(1.0, 0.90, 0.40))

	# 5. Earthen Water Jar (Palayok / Banga) on Left Deck Corner
	var jar_pos := p_left + Vector2(8, 2)
	draw_circle(jar_pos, 5.0, Color(0.65, 0.34, 0.18)) # Clay belly
	draw_circle(jar_pos + Vector2(0, -3), 3.0, Color(0.75, 0.42, 0.24)) # Jar neck
	draw_circle(jar_pos + Vector2(0, -4), 2.0, Color(0.45, 0.20, 0.10)) # Opening
	draw_line(jar_pos + Vector2(2, -4), jar_pos + Vector2(7, -8), Color(0.85, 0.75, 0.50), 1.2) # Coconut shell ladle handle

	# 6. Woven Rice Sacks (Kaban) Stacked on Right Deck Corner
	var sack_pos := p_right + Vector2(-10, 4)
	draw_colored_polygon(PackedVector2Array([
		sack_pos + Vector2(-6, 2), sack_pos + Vector2(6, 2),
		sack_pos + Vector2(4, -5), sack_pos + Vector2(-4, -5)
	]), Color(0.82, 0.74, 0.58))
	draw_line(sack_pos + Vector2(-5, 0), sack_pos + Vector2(5, 0), Color(0.20, 0.45, 0.80), 1.2) # Blue twine stripe

	# Front post drawn after interior items
	draw_line(p_bottom, p_bottom + Vector2(0, -post_h), Color(0.46, 0.34, 0.20), 4.0)
	draw_line(p_bottom, p_bottom + Vector2(0, -post_h), Color(0.68, 0.52, 0.30), 2.0)
	for n in range(3):
		var ny: float = -post_h * (float(n + 1) / 4.0)
		draw_line(p_bottom + Vector2(-2, ny), p_bottom + Vector2(2, ny), Color(0.32, 0.22, 0.12), 1.5)

	# 7. Level 2 & 3 Enhancements: Bamboo bench & dried corn/palay harvest garlands
	if level >= 2:
		# Bamboo resting bench across front-left
		var bench_poly := PackedVector2Array([
			Vector2(-24, -12), Vector2(-10, -5), Vector2(-12, -2), Vector2(-26, -9)
		])
		draw_colored_polygon(bench_poly, Color(0.78, 0.64, 0.38))
		draw_polyline(bench_poly, Color(0.45, 0.32, 0.16), 1.2)
		# Hanging bundles of golden grain from rafters
		for gx in [-16, 0, 14]:
			var gp := Vector2(gx, -post_h + 8)
			draw_line(gp, gp + Vector2(0, 8), Color(0.92, 0.78, 0.20), 2.0)
			draw_circle(gp + Vector2(0, 9), 2.0, Color(0.85, 0.68, 0.15))

	if level >= 3:
		# Brass calling bell on front rafter beam
		var bell_pos := Vector2(0, -post_h + 4)
		draw_line(bell_pos, bell_pos + Vector2(0, 6), Color(0.30, 0.25, 0.20), 1.5)
		draw_circle(bell_pos + Vector2(0, 7), 3.5, Color(0.92, 0.78, 0.22)) # Shiny brass gong
		draw_circle(bell_pos + Vector2(0, 7), 1.5, Color(1.0, 0.95, 0.60))

	# 8. Thatched Nipa / Cogon Grass Pavilion Roof (Pyramidal / Hip Roof)
	var apex := Vector2(0, -post_h - 26.0)
	var e_top := top * 0.95 + Vector2(0, -post_h)
	var e_right := right * 0.95 + Vector2(0, -post_h)
	var e_bottom := bottom * 0.95 + Vector2(0, -post_h)
	var e_left := left * 0.95 + Vector2(0, -post_h)

	# Roof left facet
	var r_left := PackedVector2Array([apex, e_left, e_bottom])
	draw_colored_polygon(r_left, Color(0.68, 0.54, 0.28))
	draw_polyline(r_left, Color(0.38, 0.26, 0.12), 1.5)

	# Roof right facet
	var r_right := PackedVector2Array([apex, e_bottom, e_right])
	draw_colored_polygon(r_right, Color(0.76, 0.62, 0.34))
	draw_polyline(r_right, Color(0.42, 0.30, 0.14), 1.5)

	# Thatch tier layering lines
	for k in range(1, 4):
		var f: float = float(k) / 4.0
		var tl1 := apex.lerp(e_left, f)
		var tl2 := apex.lerp(e_bottom, f)
		var tr1 := apex.lerp(e_bottom, f)
		var tr2 := apex.lerp(e_right, f)
		draw_line(tl1, tl2, Color(0.82, 0.68, 0.38, 0.65), 1.5)
		draw_line(tr1, tr2, Color(0.86, 0.74, 0.42, 0.65), 1.5)

	# Overhanging thatch fringe (cogon grass tassels along eaves)
	for i in range(12):
		var f: float = float(i) / 11.0
		var pt_l := e_left.lerp(e_bottom, f)
		draw_line(pt_l, pt_l + Vector2(0, 3.5), Color(0.55, 0.40, 0.20), 1.2)
		var pt_r := e_bottom.lerp(e_right, f)
		draw_line(pt_r, pt_r + Vector2(0, 3.5), Color(0.60, 0.45, 0.22), 1.2)

	# Ridge finial cap on apex
	draw_circle(apex, 3.5, Color(0.52, 0.38, 0.20))
	draw_line(apex + Vector2(-6, 2), apex + Vector2(6, 2), Color(0.40, 0.28, 0.14), 2.0)

	# 9. Festive Banderitas (Philippine Fiesta Bunting Flags along front eaves)
	var flag_colors: Array[Color] = [
		Color(0.92, 0.22, 0.18), # Red
		Color(0.96, 0.82, 0.18), # Gold
		Color(0.20, 0.65, 0.30), # Green
		Color(0.18, 0.50, 0.90), # Blue
		Color(0.98, 0.98, 0.98), # White
	]
	var string_p1 := e_left + Vector2(0, 1)
	var string_p2 := e_bottom + Vector2(0, 1)
	var string_p3 := e_right + Vector2(0, 1)
	draw_line(string_p1, string_p2, Color(0.85, 0.80, 0.70, 0.8), 1.0)
	draw_line(string_p2, string_p3, Color(0.85, 0.80, 0.70, 0.8), 1.0)

	for i in range(7):
		var f: float = float(i) / 6.0
		var pos_a := string_p1.lerp(string_p2, f)
		var sway: float = sin(t * 3.0 + f * 4.0) * 1.5
		var col: Color = flag_colors[i % flag_colors.size()]
		var tri := PackedVector2Array([
			pos_a + Vector2(-2, 0), pos_a + Vector2(2, 0),
			pos_a + Vector2(0, 4.5 + sway)
		])
		draw_colored_polygon(tri, col)

		var pos_b := string_p2.lerp(string_p3, f)
		var col_b: Color = flag_colors[(i + 2) % flag_colors.size()]
		var tri_b := PackedVector2Array([
			pos_b + Vector2(-2, 0), pos_b + Vector2(2, 0),
			pos_b + Vector2(0, 4.5 - sway)
		])
		draw_colored_polygon(tri_b, col_b)

	# 10. Night Lighting: Warm Kerosene Gasera Lanterns hanging from rafters
	if TimeManager.is_night():
		var l_pos1 := (e_left + e_bottom) * 0.5 + Vector2(4, 2)
		draw_circle(l_pos1, 26.0, Color(1.0, 0.85, 0.40, 0.22))
		draw_circle(l_pos1, 8.0, Color(1.0, 0.92, 0.55, 0.50))
		draw_circle(l_pos1, 2.5, Color(1.0, 1.0, 0.85, 0.95))
		draw_line(l_pos1 + Vector2(0, -6), l_pos1, Color(0.35, 0.25, 0.15), 1.2) # Chain

		var l_pos2 := (e_bottom + e_right) * 0.5 + Vector2(-4, 2)
		draw_circle(l_pos2, 26.0, Color(1.0, 0.85, 0.40, 0.22))
		draw_circle(l_pos2, 8.0, Color(1.0, 0.92, 0.55, 0.50))
		draw_circle(l_pos2, 2.5, Color(1.0, 1.0, 0.85, 0.95))
		draw_line(l_pos2 + Vector2(0, -6), l_pos2, Color(0.35, 0.25, 0.15), 1.2)

func _draw_water_tower(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var tex := TEX_WATER_STATION_FLIPPED if is_flipped else TEX_WATER_STATION
	if tex != null:
		var fs: float = -1.0 if is_flipped else 1.0
		# Pixel-art Water Station sprite (80x112 at 2x scale = 160x224)
		var ws_w: float = float(tex.get_width()) * 2.0
		var ws_h: float = float(tex.get_height()) * 2.0
		var ws_rect := Rect2(-ws_w * 0.5, -188.0, ws_w, ws_h)
		draw_texture_rect(tex, ws_rect, false)

		# Night safety light
		if TimeManager.is_night():
			var lamp_p := Vector2(0.0, -100.0)
			draw_circle(lamp_p, 16.0, Color(0.40, 0.75, 1.0, 0.22))
			draw_circle(lamp_p, 5.0, Color(0.60, 0.90, 1.0, 0.50))
			draw_circle(lamp_p, 1.8, Color(0.95, 0.98, 1.0, 0.95))

		# Level indicators
		if level >= 2:
			draw_circle(Vector2(22.0 * fs, -165.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-22.0 * fs, -165.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var s: float = 0.88
	var p_top := top * s
	var p_right := right * s
	var p_bottom := bottom * s
	var p_left := left * s

	var t: float = float(Time.get_ticks_msec()) * 0.001

	# 1. Reinforced stone/concrete diamond base pad
	var pad_h: float = 6.0
	var pad_left := PackedVector2Array([
		p_left, p_bottom, p_bottom + Vector2(0, pad_h), p_left + Vector2(0, pad_h)
	])
	draw_colored_polygon(pad_left, Color(0.28, 0.30, 0.34))
	draw_polyline(pad_left, Color(0.18, 0.20, 0.22), 1.5)

	var pad_right := PackedVector2Array([
		p_bottom, p_right, p_right + Vector2(0, pad_h), p_bottom + Vector2(0, pad_h)
	])
	draw_colored_polygon(pad_right, Color(0.36, 0.38, 0.42))
	draw_polyline(pad_right, Color(0.22, 0.24, 0.26), 1.5)

	var pad_top := PackedVector2Array([p_top, p_right, p_bottom, p_left])
	draw_colored_polygon(pad_top, Color(0.48, 0.50, 0.54))
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), Color(0.25, 0.28, 0.30), 1.5)

	# Catchment drain channel on pad perimeter
	draw_polyline(PackedVector2Array([
		p_top * 0.85, p_right * 0.85, p_bottom * 0.85, p_left * 0.85, p_top * 0.85
	]), Color(0.20, 0.25, 0.30, 0.8), 1.5)

	if level == 1:
		# =======================================================================
		# TIER 1: GROUNDWATER DEEP WELL PUMP (BOMBA NG TUBIG)
		# =======================================================================
		var basin_center := Vector2(8, 6)
		var basin_w: float = 16.0
		draw_set_transform(basin_center, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, basin_w + 3.0, Color(0.30, 0.32, 0.35))
		draw_circle(Vector2.ZERO, basin_w, Color(0.18, 0.42, 0.65, 0.90))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Animated water ripples in catch basin
		var ripple_phase: float = fmod(t * 1.5, 1.0)
		draw_set_transform(basin_center, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, (basin_w - 2.0) * ripple_phase, 0.0, TAU, 16, Color(0.60, 0.85, 1.0, 0.70 * (1.0 - ripple_phase)), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Wellhead borehole casing flange (dark cast iron)
		var well_p := Vector2(-12, -4)
		draw_circle(well_p + Vector2(0, 3), 9.0, Color(0.18, 0.20, 0.22))
		draw_circle(well_p + Vector2(0, 3), 6.5, Color(0.10, 0.12, 0.14))

		# Vertical suction column rising from wellhead
		draw_line(well_p + Vector2(0, 3), well_p + Vector2(0, -22), Color(0.25, 0.28, 0.32), 6.0)
		draw_line(well_p + Vector2(-1, 3), well_p + Vector2(-1, -22), Color(0.45, 0.50, 0.56), 2.0)

		# Reciprocating pump arm and cylinder
		var pump_top := well_p + Vector2(0, -22)
		draw_circle(pump_top, 5.0, Color(0.20, 0.24, 0.28))
		var arm_angle: float = sin(t * 6.0) * 0.22
		var arm_end := pump_top + Vector2(cos(arm_angle) * 16.0, sin(arm_angle) * 8.0 - 4.0)
		draw_line(pump_top, arm_end, Color(0.35, 0.40, 0.46), 3.0)
		draw_circle(arm_end, 3.0, Color(0.75, 0.25, 0.20))

		# Red Yanmar/Kubota utility single-cylinder diesel motor
		var eng_p := Vector2(-28, -2)
		var eng_body := PackedVector2Array([
			eng_p + Vector2(-8, 4), eng_p + Vector2(12, 4),
			eng_p + Vector2(12, -14), eng_p + Vector2(-8, -14)
		])
		draw_colored_polygon(eng_body, Color(0.78, 0.22, 0.18))
		draw_polyline(eng_body, Color(0.42, 0.10, 0.08), 1.5)

		# Spinning flywheel & drive belt
		var fly_p := eng_p + Vector2(14, -5)
		draw_circle(fly_p, 6.0, Color(0.25, 0.28, 0.32))
		draw_circle(fly_p, 4.0, Color(0.55, 0.60, 0.66))
		var spoke_rot: float = t * 12.0
		draw_line(fly_p, fly_p + Vector2(cos(spoke_rot) * 5.0, sin(spoke_rot) * 5.0), Color(0.18, 0.20, 0.22), 1.5)
		draw_line(fly_p, pump_top + Vector2(2, 6), Color(0.15, 0.15, 0.15), 1.5)

		# Exhaust pipe & puffing diesel smoke
		var exh_p := eng_p + Vector2(-4, -14)
		draw_line(exh_p, exh_p + Vector2(0, -12), Color(0.30, 0.30, 0.32), 2.5)
		var smoke_t: float = fmod(t * 2.0, 1.0)
		var smoke_p := exh_p + Vector2(-2.0 - smoke_t * 6.0, -14.0 - smoke_t * 14.0)
		draw_circle(smoke_p, 2.0 + smoke_t * 4.0, Color(0.60, 0.62, 0.65, 0.50 * (1.0 - smoke_t)))

		# Arching discharge pipe pouring into basin
		var pipe_pts := PackedVector2Array([
			pump_top + Vector2(3, 4),
			pump_top + Vector2(16, 8),
			basin_center + Vector2(0, -6)
		])
		draw_polyline(pipe_pts, Color(0.22, 0.45, 0.70), 3.5)
		draw_line(basin_center + Vector2(0, -6), basin_center + Vector2(0, -1), Color(0.45, 0.80, 1.0, 0.85), 2.5)

	elif level == 2:
		# =======================================================================
		# TIER 2: ELEVATED WATER TOWER (TANGKE NG TUBIG)
		# =======================================================================
		var tower_h: float = 58.0
		var tank_w: float = 34.0
		var tank_h: float = 36.0
		var tank_y: float = -tower_h

		# 4 Heavy wooden/steel trestle stanchion legs
		var leg_col := Color(0.38, 0.28, 0.18)
		var brace_col := Color(0.50, 0.38, 0.25)
		var foot_pts := [Vector2(-24, 6), Vector2(0, 14), Vector2(24, 6), Vector2(0, -6)]
		var top_pts := [Vector2(-16, tank_y + 10), Vector2(0, tank_y + 16), Vector2(16, tank_y + 10), Vector2(0, tank_y + 2)]

		for i in range(4):
			draw_line(foot_pts[i], top_pts[i], leg_col, 3.5)
			draw_circle(foot_pts[i], 3.5, Color(0.28, 0.30, 0.34))

		# Diagonal X-bracing between legs
		draw_line(foot_pts[0], top_pts[1], brace_col, 1.5)
		draw_line(foot_pts[1], top_pts[0], brace_col, 1.5)
		draw_line(foot_pts[1], top_pts[2], brace_col, 1.5)
		draw_line(foot_pts[2], top_pts[1], brace_col, 1.5)
		draw_line(foot_pts[0], top_pts[3], brace_col, 1.2)
		draw_line(foot_pts[2], top_pts[3], brace_col, 1.2)

		# Central vertical high-pressure downspout pipe
		draw_line(Vector2(0, 4), Vector2(0, tank_y + 8), Color(0.24, 0.38, 0.52), 4.5)
		draw_line(Vector2(0, 4), Vector2(0, tank_y + 8), Color(0.40, 0.60, 0.78), 2.0)
		draw_circle(Vector2(0, -12), 4.0, Color(0.85, 0.68, 0.15))
		draw_circle(Vector2(0, -12), 2.0, Color(0.40, 0.30, 0.08))

		# Service ladder up left leg
		for step in range(5):
			var sy: float = lerpf(0.0, tank_y + 8, float(step + 1) / 6.0)
			var lx: float = lerpf(-24.0, -16.0, float(step + 1) / 6.0)
			draw_line(Vector2(lx - 2, sy), Vector2(lx + 4, sy), Color(0.20, 0.22, 0.25), 1.5)

		# Wooden stave cylindrical water cistern tank body
		var tank_rect := PackedVector2Array([
			Vector2(-tank_w * 0.5, tank_y),
			Vector2(tank_w * 0.5, tank_y),
			Vector2(tank_w * 0.5, tank_y - tank_h),
			Vector2(-tank_w * 0.5, tank_y - tank_h)
		])
		draw_colored_polygon(tank_rect, Color(0.55, 0.40, 0.26))
		draw_polyline(tank_rect, Color(0.28, 0.18, 0.10), 2.0)

		# Vertical timber staves
		for x in range(int(-tank_w * 0.5 + 5), int(tank_w * 0.5), 6):
			draw_line(Vector2(x, tank_y), Vector2(x, tank_y - tank_h), Color(0.42, 0.30, 0.18), 1.2)

		# Black iron reinforcement barrel hoops
		var hoop_ys := [tank_y - 4, tank_y - 16, tank_y - 28, tank_y - tank_h + 2]
		for hy in hoop_ys:
			draw_line(Vector2(-tank_w * 0.5 - 1, hy), Vector2(tank_w * 0.5 + 1, hy), Color(0.18, 0.18, 0.20), 2.5)

		# Water level sight-glass tube on front
		var tube_x: float = 6.0
		draw_line(Vector2(tube_x, tank_y - 4), Vector2(tube_x, tank_y - tank_h + 4), Color(0.20, 0.20, 0.20), 3.0)
		draw_line(Vector2(tube_x, tank_y - 4), Vector2(tube_x, tank_y - tank_h + 4), Color(0.60, 0.85, 1.0, 0.70), 1.5)
		var bobber_y: float = tank_y - 18 + sin(t * 2.0) * 3.0
		draw_circle(Vector2(tube_x, bobber_y), 2.0, Color(0.95, 0.25, 0.20))

		# Conical galvanized tin roof with finial
		var roof_peak := Vector2(0, tank_y - tank_h - 18.0)
		var roof_pts := PackedVector2Array([
			roof_peak,
			Vector2(tank_w * 0.5 + 3, tank_y - tank_h),
			Vector2(-tank_w * 0.5 - 3, tank_y - tank_h)
		])
		draw_colored_polygon(roof_pts, Color(0.68, 0.72, 0.78))
		draw_polyline(roof_pts, Color(0.38, 0.42, 0.48), 2.0)
		draw_circle(roof_peak, 3.5, Color(0.92, 0.78, 0.20))

	elif level >= 3:
		# =======================================================================
		# TIER 3: SOLAR-POWERED PRESSURIZED DRIP NETWORK
		# =======================================================================
		var tower_h: float = 64.0
		var tank_w: float = 38.0
		var tank_h: float = 38.0
		var tank_y: float = -tower_h

		var steel_col := Color(0.48, 0.54, 0.60)
		var foot_pts: Array[Vector2] = [Vector2(-26, 6), Vector2(0, 16), Vector2(26, 6), Vector2(0, -6)]
		var top_pts: Array[Vector2] = [Vector2(-18, tank_y + 10), Vector2(0, tank_y + 18), Vector2(18, tank_y + 10), Vector2(0, tank_y + 2)]

		for i in range(4):
			draw_line(foot_pts[i], top_pts[i], steel_col, 4.0)
			draw_circle(foot_pts[i], 4.0, Color(0.24, 0.26, 0.30))

		# Double steel X-braces
		for i in range(3):
			var pA: Vector2 = foot_pts[i]
			var pB: Vector2 = foot_pts[(i + 1) % 4]
			var tA: Vector2 = top_pts[i]
			var tB: Vector2 = top_pts[(i + 1) % 4]
			draw_line(pA, tB, Color(0.60, 0.66, 0.72), 1.5)
			draw_line(pB, tA, Color(0.60, 0.66, 0.72), 1.5)

		# Ground booster pump station & dual inline filtration canisters
		var pump1_p := Vector2(-12, 6)
		draw_rect(Rect2(pump1_p.x - 5, pump1_p.y - 7, 10, 14), Color(0.18, 0.42, 0.72))
		draw_rect(Rect2(pump1_p.x - 5, pump1_p.y - 7, 10, 14), Color(0.10, 0.22, 0.40), false, 1.2)
		var pump2_p := Vector2(12, 6)
		draw_rect(Rect2(pump2_p.x - 5, pump2_p.y - 7, 10, 14), Color(0.18, 0.42, 0.72))
		draw_rect(Rect2(pump2_p.x - 5, pump2_p.y - 7, 10, 14), Color(0.10, 0.22, 0.40), false, 1.2)

		# Pressurized manifold pipe running down
		draw_line(Vector2(0, 6), Vector2(0, tank_y + 8), Color(0.15, 0.35, 0.65), 5.5)
		draw_line(Vector2(0, 6), Vector2(0, tank_y + 8), Color(0.35, 0.70, 0.95), 2.5)

		# Glistening cyan water flow pulses travelling down the main line
		var flow_pos: float = fmod(t * 3.0, 1.0)
		var flow_y: float = lerpf(tank_y + 8, 6.0, flow_pos)
		draw_circle(Vector2(0, flow_y), 3.0, Color(0.60, 0.95, 1.0, 0.90))

		# Modern high-capacity cylindrical stainless steel water cistern
		var tank_rect := PackedVector2Array([
			Vector2(-tank_w * 0.5, tank_y),
			Vector2(tank_w * 0.5, tank_y),
			Vector2(tank_w * 0.5, tank_y - tank_h),
			Vector2(-tank_w * 0.5, tank_y - tank_h)
		])
		draw_colored_polygon(tank_rect, Color(0.85, 0.90, 0.95))
		draw_polyline(tank_rect, Color(0.40, 0.48, 0.56), 2.0)

		# Hydro-blue municipal utility paint stripe around middle
		var stripe_rect := PackedVector2Array([
			Vector2(-tank_w * 0.5 + 1, tank_y - 12),
			Vector2(tank_w * 0.5 - 1, tank_y - 12),
			Vector2(tank_w * 0.5 - 1, tank_y - 24),
			Vector2(-tank_w * 0.5 + 1, tank_y - 24)
		])
		draw_colored_polygon(stripe_rect, Color(0.18, 0.52, 0.88))

		# Digital LED flow / telemetry display on tank front
		var screen_p := Vector2(0, tank_y - 18)
		draw_rect(Rect2(screen_p.x - 7, screen_p.y - 4, 14, 8), Color(0.10, 0.12, 0.15))
		var led_pulse: float = 0.5 + 0.5 * sin(t * 6.0)
		draw_circle(screen_p + Vector2(-3, 0), 1.5, Color(0.20, 0.95, 0.35))
		draw_circle(screen_p + Vector2(3, 0), 1.5, Color(0.20, 0.80, 1.0, 0.5 + led_pulse * 0.5))

		# Photovoltaic Solar Panel Array atop the cistern
		var sol_y: float = tank_y - tank_h
		var sol_pts := PackedVector2Array([
			Vector2(-tank_w * 0.5 - 4, sol_y + 2),
			Vector2(tank_w * 0.5 + 4, sol_y + 2),
			Vector2(tank_w * 0.5 + 2, sol_y - 16),
			Vector2(-tank_w * 0.5 - 2, sol_y - 16)
		])
		draw_colored_polygon(sol_pts, Color(0.12, 0.22, 0.42))
		draw_polyline(sol_pts, Color(0.70, 0.75, 0.82), 2.0)

		# Solar panel cell grid lines
		draw_line(Vector2(0, sol_y + 2), Vector2(0, sol_y - 16), Color(0.40, 0.55, 0.75), 1.2)
		draw_line(Vector2(-tank_w * 0.5, sol_y - 7), Vector2(tank_w * 0.5, sol_y - 7), Color(0.40, 0.55, 0.75), 1.2)

		# Night illuminators
		if TimeManager.is_night():
			var lamp_p := Vector2(0, tank_y + 2)
			draw_circle(lamp_p, 16.0, Color(0.35, 0.75, 1.0, 0.22))
			draw_circle(lamp_p, 6.0, Color(0.50, 0.90, 1.0, 0.50))
			draw_circle(lamp_p, 2.0, Color(0.90, 0.98, 1.0, 0.95))

func _draw_silo(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var silo_w: float = 46.0
	var silo_h: float = 75.0

	# 2.5D Cylindrical steel silo body
	var body := PackedVector2Array([
		Vector2(-silo_w, 0), Vector2(silo_w, 0),
		Vector2(silo_w, -silo_h), Vector2(-silo_w, -silo_h)
	])
	draw_colored_polygon(body, Color(0.76, 0.80, 0.86))
	draw_polyline(body, Color(0.42, 0.46, 0.52), 2.0)

	# Horizontal steel reinforcement rings
	for y in range(int(-silo_h + 15), 0, 16):
		draw_line(Vector2(-silo_w, y), Vector2(silo_w, y), Color(0.55, 0.60, 0.68), 2.0)

	# Conical Silo Steel Dome Roof
	var dome_peak := Vector2(0, -silo_h - 32.0)
	var dome_pts := PackedVector2Array([dome_peak, Vector2(silo_w + 4, -silo_h), Vector2(-silo_w - 4, -silo_h)])
	draw_colored_polygon(dome_pts, Color(0.62, 0.66, 0.74))
	draw_polyline(dome_pts, Color(0.38, 0.42, 0.48), 2.0)
	draw_circle(dome_peak, 4.0, Color(0.85, 0.90, 0.95))

func _draw_drone_station(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var tex := TEX_DRONE_STATION_FLIPPED if is_flipped else TEX_DRONE_STATION
	if tex != null:
		var fs: float = -1.0 if is_flipped else 1.0
		# Pixel-art Drone Station sprite (81x128 at 2x scale = 162x256)
		var ds_w: float = float(tex.get_width()) * 2.0
		var ds_h: float = float(tex.get_height()) * 2.0
		var ds_rect := Rect2(-ds_w * 0.5, -216.0, ds_w, ds_h)
		draw_texture_rect(tex, ds_rect, false)

		# Blinking red aircraft warning beacon at the antenna mast tip
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var mast_tip := Vector2(-39.0 * fs, -204.0)
		var blink: float = 0.5 + 0.5 * sin(t * 5.0)
		draw_circle(mast_tip, 3.5, Color(1.0, 0.20, 0.20, 0.95))
		draw_circle(mast_tip, 7.0, Color(1.0, 0.20, 0.20, 0.35 * blink))

		# Night helipad lighting
		if TimeManager.is_night():
			var h_lights := [Vector2(-36, -8), Vector2(0, 10), Vector2(36, -8), Vector2(0, -26)]
			for lp in h_lights:
				draw_circle(Vector2(lp.x * fs, lp.y), 5.0, Color(0.30, 0.85, 1.0, 0.30))
				draw_circle(Vector2(lp.x * fs, lp.y), 1.8, Color(0.70, 0.95, 1.0, 0.90))

		# Level indicators
		if level >= 2:
			draw_circle(Vector2(24.0 * fs, -112.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-24.0 * fs, -112.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var s: float = 0.92
	var p_top := top * s
	var p_right := right * s
	var p_bottom := bottom * s
	var p_left := left * s

	# 1. Reinforced concrete foundation curb
	var curb_h: float = 4.0
	var curb_left := PackedVector2Array([
		p_left, p_bottom, p_bottom + Vector2(0, curb_h), p_left + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_left, Color(0.24, 0.26, 0.30))

	var curb_right := PackedVector2Array([
		p_bottom, p_right, p_right + Vector2(0, curb_h), p_bottom + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_right, Color(0.32, 0.35, 0.40))

	# 2. Modern dark tarmac landing pad
	var pad := PackedVector2Array([p_top, p_right, p_bottom, p_left])
	draw_colored_polygon(pad, Color(0.18, 0.20, 0.24))
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), Color(0.10, 0.12, 0.15), 1.5)

	# 3. Yellow/black perimeter hazard warning chevrons
	var caution_gold := Color(0.95, 0.78, 0.20, 0.85)
	var caution_dark := Color(0.12, 0.12, 0.15, 0.85)
	for i in range(8):
		var t1: float = float(i) / 8.0
		var t2: float = float(i + 0.5) / 8.0
		var col: Color = caution_gold if (i % 2 == 0) else caution_dark
		draw_line(p_left.lerp(p_bottom, t1), p_left.lerp(p_bottom, t2), col, 2.5)
		draw_line(p_bottom.lerp(p_right, t1), p_bottom.lerp(p_right, t2), col, 2.5)

	# 4. Central circular landing target with glowing cyan ring and 'H' / crosshair
	var pad_center := (p_top + p_bottom) * 0.5 + Vector2(0, -2.0)
	draw_set_transform(pad_center, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 20.0, Color(0.10, 0.14, 0.18, 0.95))
	draw_arc(Vector2.ZERO, 18.0, 0, TAU, 24, Color(0.30, 0.85, 1.0, 0.90), 2.0)
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 16, Color(0.30, 0.85, 1.0, 0.45), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Letter 'H' inside the helipad target ring
	var h_col := Color(0.95, 0.98, 1.0, 0.95)
	draw_line(pad_center + Vector2(-6, -6), pad_center + Vector2(-6, 6), h_col, 2.0)
	draw_line(pad_center + Vector2(6, -6), pad_center + Vector2(6, 6), h_col, 2.0)
	draw_line(pad_center + Vector2(-6, 0), pad_center + Vector2(6, 0), h_col, 2.0)

	# 5. Back Command Wall & Battery Recharging Bays
	var wall_base_l := p_left.lerp(p_top, 0.25)
	var wall_base_r := p_top.lerp(p_right, 0.75)
	var wall_h: float = 24.0
	var wall_top_l := wall_base_l + Vector2(0, -wall_h)
	var wall_top_r := wall_base_r + Vector2(0, -wall_h)

	var back_wall := PackedVector2Array([wall_base_l, wall_base_r, wall_top_r, wall_top_l])
	draw_colored_polygon(back_wall, Color(0.25, 0.28, 0.35))
	draw_polyline(back_wall, Color(0.12, 0.14, 0.18), 1.5)

	# Battery charging dock slots with green indicator LEDs
	var num_bays: int = clampi(level, 1, 3)
	for b in range(num_bays):
		var frac: float = float(b + 1) / float(num_bays + 1)
		var bay_pos := wall_base_l.lerp(wall_base_r, frac) + Vector2(0, -wall_h * 0.4)
		draw_rect(Rect2(bay_pos.x - 4, bay_pos.y - 6, 8, 10), Color(0.12, 0.14, 0.18))
		draw_rect(Rect2(bay_pos.x - 3, bay_pos.y - 5, 6, 8), Color(0.20, 0.75, 0.35)) # Green battery LED

	# 6. Radio Telemetry Antenna Mast on the back-left
	var mast_base := wall_top_l + Vector2(4, 0)
	var mast_tip := mast_base + Vector2(0, -32.0)
	draw_line(mast_base, mast_tip, Color(0.70, 0.75, 0.82), 2.0)
	draw_line(mast_tip + Vector2(-6, 8), mast_tip + Vector2(6, 8), Color(0.70, 0.75, 0.82), 1.5)
	draw_line(mast_tip + Vector2(-4, 14), mast_tip + Vector2(4, 14), Color(0.70, 0.75, 0.82), 1.5)

	# Blinking red aircraft warning beacon at the tip
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var blink: float = 0.5 + 0.5 * sin(t * 5.0)
	draw_circle(mast_tip, 3.5, Color(1.0, 0.20, 0.20, 0.95))
	draw_circle(mast_tip, 7.0, Color(1.0, 0.20, 0.20, 0.35 * blink))

	# 7. Level-specific attachments
	if level >= 2:
		# Seed hopper dispensing terminal on the right side
		var hopper_pos := wall_top_r + Vector2(-4, 2)
		var hopper_poly := PackedVector2Array([
			hopper_pos + Vector2(-8, -12), hopper_pos + Vector2(8, -12),
			hopper_pos + Vector2(4, 0), hopper_pos + Vector2(-4, 0)
		])
		draw_colored_polygon(hopper_poly, Color(0.85, 0.72, 0.30)) # Amber seed hopper
		draw_polyline(hopper_poly, Color(0.35, 0.25, 0.10), 1.2)

	if level >= 3:
		# High-gain communications dish & automated maintenance arm
		var dish_center := mast_tip + Vector2(14, 4)
		draw_arc(dish_center, 9.0, -PI * 0.6, PI * 0.4, 12, Color(0.88, 0.92, 0.98), 2.5)
		draw_line(mast_tip + Vector2(2, 6), dish_center, Color(0.50, 0.55, 0.62), 1.5)
		draw_circle(dish_center, 2.5, Color(0.35, 0.85, 1.0)) # Telemetry uplink light

func _draw_drone_pad(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var s: float = 0.94
	var p_top := top * s
	var p_right := right * s
	var p_bottom := bottom * s
	var p_left := left * s

	# 1. Reinforced concrete foundation curb with bevel depth
	var curb_h: float = 5.0
	var curb_left := PackedVector2Array([
		p_left, p_bottom, p_bottom + Vector2(0, curb_h), p_left + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_left, Color(0.22, 0.24, 0.28))

	var curb_right := PackedVector2Array([
		p_bottom, p_right, p_right + Vector2(0, curb_h), p_bottom + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_right, Color(0.30, 0.33, 0.38))

	# 2. Modern brushed dark tarmac landing surface
	var pad := PackedVector2Array([p_top, p_right, p_bottom, p_left])
	draw_colored_polygon(pad, Color(0.16, 0.18, 0.22))
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), Color(0.08, 0.10, 0.12), 1.5)

	# 3. Perimeter yellow/black hazard safety chevrons
	var caution_gold := Color(0.95, 0.78, 0.20, 0.85)
	var caution_dark := Color(0.12, 0.12, 0.15, 0.85)
	for i in range(8):
		var t1: float = float(i) / 8.0
		var t2: float = float(i + 0.5) / 8.0
		var col: Color = caution_gold if (i % 2 == 0) else caution_dark
		draw_line(p_left.lerp(p_bottom, t1), p_left.lerp(p_bottom, t2), col, 2.0)
		draw_line(p_bottom.lerp(p_right, t1), p_bottom.lerp(p_right, t2), col, 2.0)

	# 4. Docking bays and helipad targets based on Level (1..3 drones capacity)
	var center := (p_top + p_bottom) * 0.5
	var fs: float = -1.0 if is_flipped else 1.0

	if level == 1:
		# Single central landing circle with target crosshair & recharge node
		draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 18.0, Color(0.10, 0.13, 0.17, 0.95))
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 24, Color(0.30, 0.85, 1.0, 0.90), 2.0)
		draw_arc(Vector2.ZERO, 8.0, 0, TAU, 16, Color(0.30, 0.85, 1.0, 0.40), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Central letter 'H'
		var h_col := Color(0.92, 0.96, 1.0, 0.95)
		draw_line(center + Vector2(-5, -5), center + Vector2(-5, 5), h_col, 2.0)
		draw_line(center + Vector2(5, -5), center + Vector2(5, 5), h_col, 2.0)
		draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), h_col, 2.0)

		# Solar induction charge node at top corner
		var charger_pos := p_top.lerp(center, 0.4)
		draw_circle(charger_pos, 3.5, Color(0.25, 0.75, 0.35))
		draw_circle(charger_pos, 1.8, Color(0.60, 1.0, 0.65))

	elif level == 2:
		# Dual landing bays (Bay 1 & Bay 2)
		var b1 := center + Vector2(-16.0 * fs, 0.0)
		var b2 := center + Vector2(16.0 * fs, 0.0)

		for bp in [b1, b2]:
			draw_set_transform(bp, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 13.0, Color(0.10, 0.13, 0.17, 0.95))
			draw_arc(Vector2.ZERO, 11.5, 0, TAU, 20, Color(0.95, 0.80, 0.25, 0.90), 1.8)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

			# Mini 'H'
			var h_col := Color(0.95, 0.90, 0.70, 0.95)
			draw_line(bp + Vector2(-4, -4), bp + Vector2(-4, 4), h_col, 1.5)
			draw_line(bp + Vector2(4, -4), bp + Vector2(4, 4), h_col, 1.5)
			draw_line(bp + Vector2(-4, 0), bp + Vector2(4, 0), h_col, 1.5)

		# Center divider stripe
		draw_line(p_top.lerp(center, 0.2), p_bottom.lerp(center, 0.2), Color(0.95, 0.80, 0.25, 0.7), 1.5)

		# Dual charging status LEDs
		draw_circle(b1 + Vector2(0, -10), 2.5, Color(0.3, 0.9, 0.4))
		draw_circle(b2 + Vector2(0, -10), 2.5, Color(0.3, 0.9, 0.4))

	else:
		# Triple landing bays (Bay 1, Bay 2, Bay 3) for Lv.3
		var b1 := center + Vector2(0.0, -9.0)
		var b2 := center + Vector2(-18.0 * fs, 3.0)
		var b3 := center + Vector2(18.0 * fs, 3.0)

		for bp in [b1, b2, b3]:
			draw_set_transform(bp, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 11.0, Color(0.08, 0.11, 0.15, 0.95))
			draw_arc(Vector2.ZERO, 9.5, 0, TAU, 18, Color(0.35, 0.90, 1.0, 0.95), 1.8)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

			var h_col := Color(0.90, 0.96, 1.0, 0.95)
			draw_line(bp + Vector2(-3, -3), bp + Vector2(-3, 3), h_col, 1.4)
			draw_line(bp + Vector2(3, -3), bp + Vector2(3, 3), h_col, 1.4)
			draw_line(bp + Vector2(-3, 0), bp + Vector2(3, 0), h_col, 1.4)

		# High-tech runway guide lines
		draw_line(p_left.lerp(center, 0.3), b2, Color(0.35, 0.85, 1.0, 0.6), 1.2)
		draw_line(p_right.lerp(center, 0.3), b3, Color(0.35, 0.85, 1.0, 0.6), 1.2)

		# Solar recharge panel along back curb
		var sp_l := p_left.lerp(p_top, 0.4) + Vector2(0, -4)
		var sp_r := p_top.lerp(p_right, 0.6) + Vector2(0, -4)
		draw_line(sp_l, sp_r, Color(0.15, 0.35, 0.65), 3.0)
		draw_line(sp_l, sp_r, Color(0.40, 0.70, 0.95), 1.0)

	# 5. Night runway edge beacon lights
	if TimeManager.is_night():
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var pulse: float = 0.6 + 0.4 * sin(t * 3.5)
		var corner_lights := [p_top, p_right, p_bottom, p_left]
		for cl in corner_lights:
			draw_circle(cl, 4.5, Color(0.20, 0.90, 0.40, 0.35 * pulse))
			draw_circle(cl, 2.0, Color(0.70, 1.0, 0.80, 0.95))

func _draw_weather_station(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var tex := TEX_WEATHER_STATION_FLIPPED if is_flipped else TEX_WEATHER_STATION
	if tex != null:
		var fs: float = -1.0 if is_flipped else 1.0
		# Pixel-art Weather Station sprite (112x112 at 2x scale = 224x224)
		var wea_w: float = float(tex.get_width()) * 2.0
		var wea_h: float = float(tex.get_height()) * 2.0
		var wea_rect := Rect2(-wea_w * 0.5, -162.0, wea_w, wea_h)
		draw_texture_rect(tex, wea_rect, false)

		# Blinking red aircraft warning beacon at tower mast tip
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var mast_tip := Vector2(4.0 * fs, -160.0)
		var blink: float = 0.5 + 0.5 * sin(t * 5.0)
		draw_circle(mast_tip, 3.5, Color(1.0, 0.20, 0.20, 0.95))
		draw_circle(mast_tip, 7.0, Color(1.0, 0.20, 0.20, 0.35 * blink))

		# Night cabinet lantern
		if TimeManager.is_night():
			var cab_lamp := Vector2(28.0 * fs, -42.0)
			draw_circle(cab_lamp, 14.0, Color(1.0, 0.85, 0.35, 0.22))
			draw_circle(cab_lamp, 4.5, Color(1.0, 0.92, 0.50, 0.50))
			draw_circle(cab_lamp, 1.5, Color(1.0, 0.98, 0.85, 0.95))

		# Level indicators
		if level >= 2:
			draw_circle(Vector2(30.0 * fs, -90.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-30.0 * fs, -90.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var s: float = 0.88
	var p_top := top * s
	var p_right := right * s
	var p_bottom := bottom * s
	var p_left := left * s

	# 1. Reinforced concrete foundation curb
	var curb_h: float = 5.0
	var curb_left := PackedVector2Array([
		p_left, p_bottom, p_bottom + Vector2(0, curb_h), p_left + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_left, Color(0.24, 0.26, 0.30))

	var curb_right := PackedVector2Array([
		p_bottom, p_right, p_right + Vector2(0, curb_h), p_bottom + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_right, Color(0.32, 0.35, 0.40))

	# 2. Modern concrete foundation slab
	var pad := PackedVector2Array([p_top, p_right, p_bottom, p_left])
	draw_colored_polygon(pad, Color(0.42, 0.45, 0.50))
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), Color(0.20, 0.22, 0.26), 1.5)

	# Expansion joint lines on slab
	draw_line((p_top + p_left) * 0.5, (p_right + p_bottom) * 0.5, Color(0.34, 0.37, 0.42), 1.0)
	draw_line((p_top + p_right) * 0.5, (p_left + p_bottom) * 0.5, Color(0.34, 0.37, 0.42), 1.0)

	# 3. Ground Telemetry Cabinet (Rear-Left Corner)
	var cab_pos := p_left.lerp(p_top, 0.6) + Vector2(6, -2)
	var cab_w: float = 14.0
	var cab_h: float = 16.0
	var cab_d: float = 8.0
	var cab_front := PackedVector2Array([
		cab_pos + Vector2(0, 0),
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5),
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5 - cab_h),
		cab_pos + Vector2(0, -cab_h)
	])
	var cab_side := PackedVector2Array([
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5),
		cab_pos + Vector2(cab_w, 0),
		cab_pos + Vector2(cab_w, -cab_h),
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5 - cab_h)
	])
	var cab_top := PackedVector2Array([
		cab_pos + Vector2(0, -cab_h),
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5 - cab_h),
		cab_pos + Vector2(cab_w, -cab_h),
		cab_pos + Vector2(cab_w * 0.5, -cab_d * 0.5 - cab_h)
	])
	draw_colored_polygon(cab_front, Color(0.70, 0.74, 0.80))
	draw_colored_polygon(cab_side, Color(0.55, 0.59, 0.65))
	draw_colored_polygon(cab_top, Color(0.82, 0.86, 0.92))
	draw_polyline(cab_front, Color(0.20, 0.22, 0.26), 1.0)
	draw_polyline(cab_side, Color(0.20, 0.22, 0.26), 1.0)

	# Cabinet status LEDs
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	draw_circle(cab_pos + Vector2(3, -11), 1.2, Color(0.20, 0.85, 0.35)) # Green power
	var led_blink: float = 0.5 + 0.5 * sin(t * 6.0)
	draw_circle(cab_pos + Vector2(5.5, -10), 1.2, Color(0.20, 0.75, 1.0, 0.5 + led_blink * 0.5)) # Cyan telemetry
	if level >= 2:
		draw_circle(cab_pos + Vector2(4, -7), 1.0, Color(1.0, 0.75, 0.20)) # Amber sensor link

	# 4. Central Tower Base & Mast Structure
	var center_pt := (p_top + p_bottom) * 0.5
	var mast_base := center_pt + Vector2(2, -2)
	var mast_h: float = 58.0 if level == 1 else (64.0 if level == 2 else 72.0)
	var mast_tip := mast_base + Vector2(0, -mast_h)

	# Guy-wires from mast to platform corners
	var steel_wire := Color(0.40, 0.45, 0.52, 0.65)
	draw_line(mast_base + Vector2(0, -mast_h * 0.55), p_left + Vector2(4, 0), steel_wire, 1.0)
	draw_line(mast_base + Vector2(0, -mast_h * 0.55), p_right + Vector2(-4, 0), steel_wire, 1.0)
	draw_line(mast_base + Vector2(0, -mast_h * 0.85), p_bottom + Vector2(0, -2), steel_wire, 1.0)

	# Steel lattice triangular truss
	var steel_col := Color(0.68, 0.72, 0.78)
	var steel_shadow := Color(0.35, 0.38, 0.44)
	var leg_w: float = 5.0
	var num_rungs: int = int(mast_h / 8.0)

	# Left and right truss legs
	draw_line(mast_base + Vector2(-leg_w, 0), mast_tip, steel_col, 1.8)
	draw_line(mast_base + Vector2(leg_w, 0), mast_tip, steel_shadow, 1.8)
	draw_line(mast_base + Vector2(0, 2), mast_tip, steel_col, 1.2) # center spine

	# Diagonal cross rungs
	for r in range(num_rungs):
		var frac1: float = float(r) / float(num_rungs)
		var frac2: float = float(r + 1) / float(num_rungs)
		var y1: float = lerpf(mast_base.y, mast_tip.y, frac1)
		var y2: float = lerpf(mast_base.y, mast_tip.y, frac2)
		var w1: float = lerpf(leg_w, 1.0, frac1)
		var w2: float = lerpf(leg_w, 1.0, frac2)

		var p1_l := Vector2(mast_base.x - w1, y1)
		var p1_r := Vector2(mast_base.x + w1, y1)
		var p2_l := Vector2(mast_base.x - w2, y2)
		var p2_r := Vector2(mast_base.x + w2, y2)

		draw_line(p1_l, p1_r, steel_col, 1.0)
		draw_line(p1_l, p2_r, steel_col, 1.0)
		draw_line(p1_r, p2_l, steel_shadow, 0.8)

	# 5. Mast Tip Aircraft Warning Beacon
	var beacon_glow: float = 0.5 + 0.5 * sin(t * 5.0)
	draw_circle(mast_tip, 4.0, Color(1.0, 0.20, 0.20, 0.30 + beacon_glow * 0.40)) # Soft glow halo
	draw_circle(mast_tip, 2.5, Color(1.0, 0.20, 0.20, 0.95)) # Core LED

	# Top dipole T-crossbar
	draw_line(mast_tip + Vector2(-6, 2), mast_tip + Vector2(6, 2), steel_col, 1.5)
	draw_line(mast_tip + Vector2(0, -6), mast_tip, steel_col, 1.5)

	# ── LEVEL SPECIFIC EQUIPMENT ──────────────────────────────────────
	if level == 1:
		# AM Broadcast Waves (Faint expanding arcs)
		var wave_cycle: float = fmod(t * 1.5, 2.0) / 2.0
		var r_wave: float = 8.0 + wave_cycle * 22.0
		var alpha_wave: float = maxf(0.0, (1.0 - wave_cycle) * 0.6)
		draw_arc(mast_tip, r_wave, -PI * 0.8, -PI * 0.2, 12, Color(0.40, 0.85, 1.0, alpha_wave), 1.2)
		draw_arc(mast_tip, r_wave * 0.6, -PI * 0.8, -PI * 0.2, 12, Color(0.40, 0.85, 1.0, alpha_wave * 0.8), 1.0)

	elif level >= 2:
		# AWS Crossbar Boom at mid-mast
		var boom_y: float = mast_base.y - mast_h * 0.62
		var boom_l := Vector2(mast_base.x - 16, boom_y)
		var boom_r := Vector2(mast_base.x + 16, boom_y)
		draw_line(boom_l, boom_r, Color(0.80, 0.84, 0.90), 1.8)

		# Left side: Anemometer (3 spinning wind cups)
		var ane_center := boom_l + Vector2(0, -4)
		draw_line(boom_l, ane_center, Color(0.65, 0.70, 0.78), 1.5)
		var ane_rot: float = t * 14.0
		for c in range(3):
			var ang: float = ane_rot + float(c) * (TAU / 3.0)
			var cup_pos := ane_center + Vector2(cos(ang) * 6.0, sin(ang) * 2.5)
			draw_line(ane_center, cup_pos, Color(0.50, 0.55, 0.62), 1.0)
			draw_circle(cup_pos, 1.8, Color(0.85, 0.88, 0.92))

		# Right side: Wind Vane Arrow
		var vane_center := boom_r + Vector2(0, -4)
		draw_line(boom_r, vane_center, Color(0.65, 0.70, 0.78), 1.5)
		var vane_ang: float = sin(t * 0.8) * 0.35 - 0.4
		var v_head := vane_center + Vector2(cos(vane_ang) * 7.0, sin(vane_ang) * 3.0)
		var v_tail := vane_center - Vector2(cos(vane_ang) * 6.0, sin(vane_ang) * 2.5)
		draw_line(v_tail, v_head, Color(0.95, 0.85, 0.25), 1.5)
		draw_line(v_head, v_head + Vector2(-2, 2), Color(0.95, 0.85, 0.25), 1.5)
		# Vane tail fin
		draw_line(v_tail + Vector2(0, -3), v_tail + Vector2(0, 3), Color(0.90, 0.30, 0.25), 1.5)

		# Stevenson Screen (White Louvered Thermometer Box below boom)
		var stev_pos := Vector2(mast_base.x - 2, boom_y + 4)
		for l_idx in range(4):
			draw_rect(Rect2(stev_pos.x - 5, stev_pos.y + l_idx * 2.2, 10, 1.5), Color(0.92, 0.95, 0.98))

		# Photovoltaic Solar Panel on South-East mast leg
		var sol_center := mast_base + Vector2(11, -14)
		var sol_poly := PackedVector2Array([
			sol_center + Vector2(-6, -4),
			sol_center + Vector2(6, -8),
			sol_center + Vector2(8, 2),
			sol_center + Vector2(-4, 6)
		])
		draw_colored_polygon(sol_poly, Color(0.12, 0.25, 0.55)) # Dark solar blue
		draw_polyline(PackedVector2Array([sol_poly[0], sol_poly[1], sol_poly[2], sol_poly[3], sol_poly[0]]), Color(0.70, 0.75, 0.82), 1.2) # Aluminum frame
		draw_line((sol_poly[0] + sol_poly[1]) * 0.5, (sol_poly[2] + sol_poly[3]) * 0.5, Color(0.35, 0.50, 0.80, 0.8), 1.0)

		# Rain Gauge Funnel on Ground Right Pier
		var gauge_pos := p_right + Vector2(-8, -4)
		draw_rect(Rect2(gauge_pos.x - 3, gauge_pos.y - 7, 6, 8), Color(0.72, 0.76, 0.82))
		draw_colored_polygon(PackedVector2Array([
			gauge_pos + Vector2(-4, -7), gauge_pos + Vector2(4, -7), gauge_pos + Vector2(2, -4), gauge_pos + Vector2(-2, -4)
		]), Color(0.85, 0.88, 0.92))

	if level >= 3:
		# ── LEVEL 3: HIGH-GAIN PARABOLIC SATELLITE DISH ────────────────
		var dish_pivot := mast_base + Vector2(0, -mast_h * 0.40)
		draw_circle(dish_pivot, 3.5, Color(0.28, 0.32, 0.38)) # Gimbal bearing

		# 3D Parabolic Dish (Elliptical projection angled upward at 45°)
		var dish_center := dish_pivot + Vector2(7, -12)
		var dish_rx: float = 13.0

		# Back bracket & convex dish exterior
		draw_set_transform(dish_center + Vector2(-1, 1), -0.32, Vector2(1.0, 0.65))
		draw_circle(Vector2.ZERO, dish_rx, Color(0.40, 0.44, 0.50)) # Outer shadow rim
		draw_set_transform(dish_center, -0.32, Vector2(1.0, 0.65))
		draw_circle(Vector2.ZERO, dish_rx - 1.0, Color(0.92, 0.94, 0.97)) # White dish surface
		draw_circle(Vector2.ZERO, dish_rx * 0.6, Color(0.78, 0.82, 0.88)) # Center concave depression
		draw_arc(Vector2.ZERO, dish_rx - 1.0, 0, TAU, 24, Color(0.55, 0.60, 0.68), 1.2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Sub-reflector Feed Horn and tripod support arms
		var horn_pos := dish_center + Vector2(9, -8)
		draw_line(dish_center + Vector2(-6, -3), horn_pos, Color(0.30, 0.34, 0.40), 1.2)
		draw_line(dish_center + Vector2(4, 5), horn_pos, Color(0.30, 0.34, 0.40), 1.2)
		draw_line(dish_center + Vector2(6, -6), horn_pos, Color(0.30, 0.34, 0.40), 1.2)
		draw_circle(horn_pos, 2.2, Color(0.25, 0.28, 0.34))

		# Glowing Satellite Telemetry Uplink Beam Burst
		var pulse: float = 0.5 + 0.5 * sin(t * 8.0)
		draw_circle(horn_pos, 3.5, Color(0.20, 0.85, 1.0, 0.40 + pulse * 0.40))
		draw_circle(horn_pos, 1.5, Color(0.85, 0.98, 1.0, 0.95))

func _draw_sprinkler(_top: Vector2, _right: Vector2, _bottom: Vector2, _left: Vector2) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001

	if TEX_SPRINKLERS != null and not SPRINKLER_FRAMES.is_empty():
		# Determine frame: Frame 0 = idle tripod, Frames 1..4 = active rotating spray
		var frame_idx: int = 0
		if state == BuildingState.ACTIVE:
			var anim: int = int(t * 7.5) % 4
			frame_idx = 1 + anim

		# Draw the sprinkler sprite rock-solid at ground center (tripod base at Y=4)
		var f_info: Dictionary = SPRINKLER_FRAMES[frame_idx]
		var src_rect: Rect2 = f_info.region
		var stem: Vector2 = f_info.stem
		var dest_pos: Vector2 = Vector2(0, 4) - stem
		draw_texture_rect_region(TEX_SPRINKLERS, Rect2(dest_pos, src_rect.size), src_rect)
		return

	# 2. Black HDPE high-pressure feeder hose with brass compression fitting
	var hose_start := Vector2(-20, 10)
	var hose_end := Vector2(0, 0)
	draw_line(hose_start, hose_end, Color(0.12, 0.12, 0.14), 3.0)
	draw_line(hose_start, hose_end, Color(0.25, 0.26, 0.28), 1.2)
	draw_circle(hose_end + Vector2(-3, 1), 2.5, Color(0.85, 0.70, 0.22))

	# 3. Octagonal concrete anchor footing pad (small chamfered block)
	var pad_pts := PackedVector2Array([
		Vector2(-8, 0), Vector2(0, 4), Vector2(8, 0), Vector2(0, -4)
	])
	draw_colored_polygon(pad_pts, Color(0.38, 0.40, 0.44))
	draw_polyline(pad_pts, Color(0.20, 0.22, 0.25), 1.2)

	# Pad thickness
	var pad_front := PackedVector2Array([
		Vector2(-8, 0), Vector2(0, 4), Vector2(0, 7), Vector2(-8, 3)
	])
	draw_colored_polygon(pad_front, Color(0.26, 0.28, 0.32))
	var pad_side := PackedVector2Array([
		Vector2(0, 4), Vector2(8, 0), Vector2(8, 3), Vector2(0, 7)
	])
	draw_colored_polygon(pad_side, Color(0.32, 0.34, 0.38))

	# 4 Corner anchor bolts
	draw_circle(Vector2(-5, 0), 1.0, Color(0.85, 0.75, 0.30))
	draw_circle(Vector2(5, 0), 1.0, Color(0.85, 0.75, 0.30))
	draw_circle(Vector2(0, 2.5), 1.0, Color(0.85, 0.75, 0.30))
	draw_circle(Vector2(0, -2.5), 1.0, Color(0.85, 0.75, 0.30))

	# 4. Galvanized steel vertical riser pipe
	var riser_h: float = 18.0
	var riser_tip := Vector2(0, -riser_h)
	draw_line(Vector2(0, 0), riser_tip, Color(0.48, 0.52, 0.58), 3.5)
	draw_line(Vector2(-0.5, 0), riser_tip + Vector2(-0.5, 0), Color(0.75, 0.80, 0.88), 1.2)

	# 5. Brass impact rotary sprinkler head
	draw_circle(riser_tip, 3.2, Color(0.85, 0.70, 0.22))
	draw_circle(riser_tip, 1.8, Color(0.55, 0.42, 0.12))

	# Rotary oscillation
	var rot_speed: float = 4.2
	var head_angle: float = fmod(t * rot_speed, TAU)
	var dir := Vector2(cos(head_angle), sin(head_angle) * 0.5)

	# Brass nozzle barrel pointing along dir
	var nozzle_len: float = 7.0
	var nozzle_tip: Vector2 = riser_tip + dir * nozzle_len
	draw_line(riser_tip, nozzle_tip, Color(0.92, 0.78, 0.25), 2.4)
	draw_line(riser_tip, nozzle_tip, Color(0.60, 0.48, 0.15), 1.0)

	# Oscillating impact spring hammer arm (clicks back and forth)
	var hammer_kick: float = sin(t * 26.0) * 0.4
	var hammer_dir := dir.rotated(hammer_kick)
	var hammer_tip := riser_tip + hammer_dir * 5.0 + Vector2(0, -2)
	draw_line(riser_tip, hammer_tip, Color(0.70, 0.55, 0.18), 1.8)
	draw_circle(hammer_tip, 1.5, Color(0.85, 0.72, 0.28))

	# 6. Active water spray visuals
	if state == BuildingState.ACTIVE:
		# Rotating high-velocity water jet stream (gravity ballistic curve)
		var stream_pts := PackedVector2Array()
		stream_pts.append(nozzle_tip)
		var stream_len: float = 38.0
		for step in range(1, 6):
			var frac: float = float(step) / 5.0
			var arc_p: Vector2 = nozzle_tip + dir * (stream_len * frac) + Vector2(0, -frac * 4.0 + frac * frac * 12.0)
			stream_pts.append(arc_p)
		draw_polyline(stream_pts, Color(0.55, 0.88, 1.0, 0.75), 1.8)

		# Flying water droplets along the stream
		for d in range(4):
			var d_offset: float = fmod(t * 12.0 + float(d) * 0.25, 1.0)
			var d_pos: Vector2 = nozzle_tip + dir * (stream_len * d_offset) + Vector2(0, -d_offset * 4.0 + d_offset * d_offset * 12.0)
			draw_circle(d_pos, 1.6, Color(0.85, 0.96, 1.0, 0.90))

		# Water mist spray cone (fine glistening droplets fanning out)
		for m in range(6):
			var m_phase: float = fmod(t * 8.0 + float(m) * 0.16, 1.0)
			var m_spread: float = (float(m % 3) - 1.0) * 0.22
			var m_dir: Vector2 = dir.rotated(m_spread)
			var m_pos: Vector2 = nozzle_tip + m_dir * (28.0 * m_phase) + Vector2(0, 4.0 * m_phase)
			draw_circle(m_pos, 1.0, Color(0.65, 0.92, 1.0, 0.60 * (1.0 - m_phase)))

		# Ground impact ripple at spray landing spot
		var ground_splash: Vector2 = Vector2.ZERO + dir * 36.0
		draw_set_transform(ground_splash, 0.0, Vector2(1.0, 0.5))
		var rip_p: float = fmod(t * 3.0, 1.0)
		draw_arc(Vector2.ZERO, 3.0 + rip_p * 6.0, 0, TAU, 12, Color(0.55, 0.88, 1.0, 0.65 * (1.0 - rip_p)), 1.2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Ground droplet bounces
		var bounce_p := ground_splash + Vector2(sin(t * 14.0) * 2.0, -2.0 - absf(cos(t * 16.0)) * 3.0)
		draw_circle(bounce_p, 1.2, Color(0.75, 0.95, 1.0, 0.85))

		# Faint 360° ambient mist halo around the sprinkler
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 26.0, 0, TAU, 20, Color(0.45, 0.85, 1.0, 0.18 + 0.08 * sin(t * 3.0)), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------------------
# 4. Agro-Industrial Milling & Value-Added Facilities (2.5D Philippine Vernacular)
# ---------------------------------------------------------------------------
func _draw_rice_mill(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var vib: float = sin(t * 24.0) * 1.2 if state == BuildingState.ACTIVE else 0.0

	# Ground contact shadow
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.48))
	draw_circle(Vector2.ZERO, 58.0, Color(0.08, 0.06, 0.04, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Main Millhouse Body (Weathered timber framing & corrugated metal)
	var wall_h: float = 46.0
	var w_left := PackedVector2Array([
		left * 0.72, bottom * 0.72,
		bottom * 0.72 + Vector2(0, -wall_h),
		left * 0.72 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_left, Color(0.48, 0.42, 0.36))
	draw_polyline(w_left, Color(0.24, 0.20, 0.16), 1.5)

	var w_right := PackedVector2Array([
		bottom * 0.72, right * 0.72,
		right * 0.72 + Vector2(0, -wall_h),
		bottom * 0.72 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_right, Color(0.56, 0.50, 0.42))
	draw_polyline(w_right, Color(0.28, 0.24, 0.18), 1.5)

	# Gabled Galvanized Iron (Yero) Roof
	var apex_y: float = -wall_h - 26.0
	var roof_pts_left := PackedVector2Array([
		left * 0.82 + Vector2(0, -wall_h),
		bottom * 0.82 + Vector2(0, -wall_h),
		Vector2(0, apex_y),
		top * 0.4 + Vector2(0, apex_y + 12.0)
	])
	draw_colored_polygon(roof_pts_left, Color(0.58, 0.62, 0.66))
	draw_polyline(roof_pts_left, Color(0.32, 0.36, 0.40), 1.8)

	var roof_pts_right := PackedVector2Array([
		bottom * 0.82 + Vector2(0, -wall_h),
		right * 0.82 + Vector2(0, -wall_h),
		top * 0.4 + Vector2(0, apex_y + 12.0),
		Vector2(0, apex_y)
	])
	draw_colored_polygon(roof_pts_right, Color(0.68, 0.72, 0.76))
	draw_polyline(roof_pts_right, Color(0.38, 0.42, 0.46), 1.8)

	# Corrugated roof ridge lines
	for i in range(1, 5):
		var frac: float = float(i) / 5.0
		var p1 = (bottom * 0.82 + Vector2(0, -wall_h)).lerp(right * 0.82 + Vector2(0, -wall_h), frac)
		var p2 = Vector2(0, apex_y).lerp(top * 0.4 + Vector2(0, apex_y + 12.0), frac)
		draw_line(p1, p2, Color(0.52, 0.56, 0.60, 0.7), 1.0)

	# Rear/Side Paddy Intake Hopper Funnel (Pyramidal steel bin with golden palay)
	var hopper_center := left * 0.55 + Vector2(0, -32.0 + vib)
	var hopper_poly := PackedVector2Array([
		hopper_center + Vector2(-16, -14),
		hopper_center + Vector2(16, -14),
		hopper_center + Vector2(6, 10),
		hopper_center + Vector2(-6, 10)
	])
	draw_colored_polygon(hopper_poly, Color(0.32, 0.36, 0.40))
	draw_polyline(hopper_poly, Color(0.18, 0.22, 0.25), 1.5)
	# Golden unhusked palay inside the hopper
	draw_circle(hopper_center + Vector2(0, -10), 9.0, Color(0.92, 0.78, 0.28))

	# Polishing Huller Cylinder & Pulley Belt
	var huller_pos := Vector2(12.0, -22.0)
	draw_line(huller_pos + Vector2(-10, 0), huller_pos + Vector2(10, 0), Color(0.25, 0.26, 0.28), 7.0)
	draw_circle(huller_pos + Vector2(-10, 0), 4.5, Color(0.85, 0.65, 0.20))
	draw_circle(huller_pos + Vector2(10, 0), 5.5, Color(0.40, 0.42, 0.45))
	# Drive belt line
	draw_line(huller_pos + Vector2(-10, -3), huller_pos + Vector2(10, -4), Color(0.12, 0.12, 0.12), 1.8)

	# Front discharge chute & Wooden Collection Bin
	var bin_pos := bottom * 0.45 + Vector2(4.0, -8.0)
	var bin_box := PackedVector2Array([
		bin_pos + Vector2(-14, -6), bin_pos + Vector2(14, -6),
		bin_pos + Vector2(10, 10), bin_pos + Vector2(-10, 10)
	])
	draw_colored_polygon(bin_box, Color(0.42, 0.28, 0.16))
	draw_polyline(bin_box, Color(0.24, 0.16, 0.08), 1.5)
	# Polished White Rice pile overflowing the bin
	draw_circle(bin_pos + Vector2(0, -3), 7.5, Color(0.96, 0.98, 0.98))

	# Stacked Burlap Rice Sacks on front staging pallet
	var sack_base := bottom * 0.45 + Vector2(-22.0, -4.0)
	for s_idx in range(3):
		var s_off = Vector2(s_idx * 7.0 - 6.0, -s_idx * 4.0)
		var sack_poly := PackedVector2Array([
			sack_base + s_off + Vector2(-6, -4),
			sack_base + s_off + Vector2(6, -4),
			sack_base + s_off + Vector2(5, 5),
			sack_base + s_off + Vector2(-5, 5)
		])
		draw_colored_polygon(sack_poly, Color(0.82, 0.72, 0.52))
		draw_polyline(sack_poly, Color(0.55, 0.45, 0.30), 1.2)
		draw_circle(sack_base + s_off + Vector2(0, -4), 1.8, Color(0.35, 0.25, 0.15))

	# Night lantern glow over doorway
	if TimeManager.is_night():
		var lamp_pos := bottom * 0.35 + Vector2(0, -34.0)
		draw_circle(lamp_pos, 16.0, Color(1.0, 0.88, 0.40, 0.25))
		draw_circle(lamp_pos, 7.0, Color(1.0, 0.92, 0.55, 0.50))
		draw_circle(lamp_pos, 2.5, Color(1.0, 0.98, 0.85, 0.95))

func _draw_sugar_mill(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001

	# Ground contact shadow (large 3x2 oval)
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.46))
	draw_circle(Vector2.ZERO, 72.0, Color(0.08, 0.06, 0.04, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Masonry Brick Foundation Platform
	var slab_poly := PackedVector2Array([left * 0.9, bottom * 0.9, right * 0.9, top * 0.9])
	draw_colored_polygon(slab_poly, Color(0.52, 0.24, 0.18))
	draw_polyline(slab_poly, Color(0.30, 0.12, 0.08), 2.0)

	# 1. Industrial Brick Smokestack / Boiler Chimney (Left rear)
	var stack_base := left * 0.5 + Vector2(4.0, -14.0)
	var stack_h: float = 78.0
	var stack_poly := PackedVector2Array([
		stack_base + Vector2(-9, 0),
		stack_base + Vector2(9, 0),
		stack_base + Vector2(6, -stack_h),
		stack_base + Vector2(-6, -stack_h)
	])
	draw_colored_polygon(stack_poly, Color(0.56, 0.22, 0.16))
	draw_polyline(stack_poly, Color(0.32, 0.10, 0.06), 1.8)
	# Chimney crown iron ring
	draw_line(stack_base + Vector2(-7, -stack_h), stack_base + Vector2(7, -stack_h), Color(0.20, 0.20, 0.22), 3.0)

	# Animated Rising Steam/Smoke Plume from Chimney
	if state == BuildingState.ACTIVE:
		var c_top := stack_base + Vector2(0, -stack_h)
		for s in range(3):
			var phase: float = fmod(t * 1.2 + float(s) * 0.65, 2.0)
			var s_y: float = phase * 22.0
			var s_x: float = sin(phase * 4.0 + float(s)) * 5.0
			var s_alpha: float = (1.0 - phase / 2.0) * 0.45
			var s_rad: float = 4.0 + phase * 4.5
			draw_circle(c_top + Vector2(s_x, -s_y), s_rad, Color(0.92, 0.94, 0.96, s_alpha))

	# 2. Main Open-Air Crushing Shed & Terracotta Tile Roof
	var wall_h: float = 38.0
	var shed_l := PackedVector2Array([
		left * 0.2, bottom * 0.55,
		bottom * 0.55 + Vector2(0, -wall_h),
		left * 0.2 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(shed_l, Color(0.42, 0.34, 0.26))
	draw_polyline(shed_l, Color(0.22, 0.16, 0.12), 1.5)

	var roof_pts := PackedVector2Array([
		left * 0.35 + Vector2(0, -wall_h),
		bottom * 0.65 + Vector2(0, -wall_h),
		right * 0.35 + Vector2(0, -wall_h - 18.0),
		top * 0.15 + Vector2(0, -wall_h - 18.0)
	])
	draw_colored_polygon(roof_pts, Color(0.72, 0.38, 0.22)) # Spanish Terracotta Tile
	draw_polyline(roof_pts, Color(0.42, 0.18, 0.08), 2.0)

	# 3. Triple Iron Roller Cane Crusher Gears (Trapiche)
	var gear_c := Vector2(-8.0, -18.0)
	draw_circle(gear_c + Vector2(-7, 0), 7.0, Color(0.28, 0.30, 0.34))
	draw_circle(gear_c + Vector2(7, 0), 7.0, Color(0.32, 0.34, 0.38))
	draw_circle(gear_c + Vector2(0, -8), 7.0, Color(0.24, 0.26, 0.30))
	# Rotating gear tooth spokes
	var rot_a: float = t * 4.0 if state == BuildingState.ACTIVE else 0.0
	draw_line(gear_c + Vector2(cos(rot_a)*5, sin(rot_a)*5), gear_c - Vector2(cos(rot_a)*5, sin(rot_a)*5), Color(0.70, 0.72, 0.75), 1.8)

	# Sugarcane Stalk Feed Trough
	draw_line(gear_c + Vector2(-24, 6), gear_c + Vector2(-8, 2), Color(0.45, 0.68, 0.22), 4.0)
	draw_line(gear_c + Vector2(-22, 9), gear_c + Vector2(-6, 5), Color(0.55, 0.78, 0.26), 3.0)

	# 4. Boiling Cauldrons (Kawa) Array with dark amber cane syrup
	var kawa_c := right * 0.35 + Vector2(-6.0, -8.0)
	draw_circle(kawa_c, 9.0, Color(0.20, 0.20, 0.22)) # Cast iron rim
	draw_circle(kawa_c, 7.5, Color(0.72, 0.38, 0.12)) # Boiling amber syrup
	if state == BuildingState.ACTIVE:
		# Boiling bubbles
		draw_circle(kawa_c + Vector2(sin(t * 8.0) * 3, cos(t * 7.0) * 2), 2.0, Color(0.92, 0.60, 0.20, 0.8))

	# 5. Front Cooling Table with Solid Muscovado Sugar Blocks
	var table_c := bottom * 0.45 + Vector2(18.0, 2.0)
	var table_poly := PackedVector2Array([
		table_c + Vector2(-16, -6), table_c + Vector2(16, -6),
		table_c + Vector2(12, 6), table_c + Vector2(-12, 6)
	])
	draw_colored_polygon(table_poly, Color(0.48, 0.32, 0.18))
	draw_polyline(table_poly, Color(0.28, 0.18, 0.08), 1.2)
	# Dark rich muscovado blocks
	draw_rect(Rect2(table_c + Vector2(-10, -5), Vector2(7, 6)), Color(0.28, 0.14, 0.06))
	draw_rect(Rect2(table_c + Vector2(-1, -6), Vector2(7, 7)), Color(0.32, 0.16, 0.08))
	draw_rect(Rect2(table_c + Vector2(8, -5), Vector2(6, 6)), Color(0.25, 0.12, 0.05))

func _draw_copra_dryer(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var flame_scale: float = (sin(t * 12.0) * 0.25 + 0.85) if state == BuildingState.ACTIVE else 0.4

	# Ground contact shadow
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.48))
	draw_circle(Vector2.ZERO, 56.0, Color(0.08, 0.06, 0.04, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Traditional Tapahan Fieldstone & Clay Hearth Structure
	var hearth_h: float = 32.0
	var h_left := PackedVector2Array([
		left * 0.75, bottom * 0.75,
		bottom * 0.75 + Vector2(0, -hearth_h),
		left * 0.75 + Vector2(0, -hearth_h)
	])
	draw_colored_polygon(h_left, Color(0.45, 0.38, 0.32)) # Riverstone masonry
	draw_polyline(h_left, Color(0.22, 0.18, 0.15), 1.5)

	var h_right := PackedVector2Array([
		bottom * 0.75, right * 0.75,
		right * 0.75 + Vector2(0, -hearth_h),
		bottom * 0.75 + Vector2(0, -hearth_h)
	])
	draw_colored_polygon(h_right, Color(0.52, 0.45, 0.38))
	draw_polyline(h_right, Color(0.26, 0.22, 0.18), 1.5)

	# Arched Furnace Hearth Firemouth (Center front)
	var fire_mouth := bottom * 0.45 + Vector2(0, -8.0)
	draw_circle(fire_mouth, 12.0, Color(0.12, 0.08, 0.05))
	draw_rect(Rect2(fire_mouth + Vector2(-12, 0), Vector2(24, 10)), Color(0.12, 0.08, 0.05))

	# Glowing Coconut Shell Charcoal Fire & Dancing Embers
	draw_circle(fire_mouth + Vector2(0, 2), 8.0 * flame_scale, Color(1.0, 0.35, 0.05, 0.95))
	draw_circle(fire_mouth + Vector2(0, 1), 5.0 * flame_scale, Color(1.0, 0.85, 0.20, 0.95))
	draw_circle(fire_mouth + Vector2(0, 0), 2.5 * flame_scale, Color(1.0, 0.98, 0.80, 1.0))

	# Split-Bamboo Drying Grate Floor (Bila)
	var grate_y: float = -hearth_h
	var grate_poly := PackedVector2Array([
		left * 0.78 + Vector2(0, grate_y),
		bottom * 0.78 + Vector2(0, grate_y),
		right * 0.78 + Vector2(0, grate_y),
		top * 0.78 + Vector2(0, grate_y)
	])
	draw_colored_polygon(grate_poly, Color(0.68, 0.58, 0.42))
	draw_polyline(grate_poly, Color(0.38, 0.30, 0.20), 1.5)

	# Bamboo slat floor texture lines
	for i in range(-3, 4):
		var x_off: float = float(i) * 9.0
		draw_line(
			left * 0.7 + Vector2(x_off, grate_y),
			right * 0.7 + Vector2(x_off, grate_y),
			Color(0.50, 0.40, 0.28, 0.8), 1.2
		)

	# Drying Coconut Halves on the Grate (White meat visible inside brown shells)
	var nut_locs := [
		Vector2(-18, grate_y - 4), Vector2(-6, grate_y - 2), Vector2(8, grate_y - 5),
		Vector2(-12, grate_y + 4), Vector2(3, grate_y + 3), Vector2(16, grate_y + 1),
		Vector2(-4, grate_y - 8), Vector2(10, grate_y - 9)
	]
	for n_pos in nut_locs:
		draw_circle(n_pos, 4.2, Color(0.38, 0.22, 0.12)) # Outer husk
		draw_circle(n_pos, 2.8, Color(0.95, 0.96, 0.94)) # White copra meat

	# Heavy Screw Expeller Oil Press (Right side timber upright)
	var press_c := right * 0.6 + Vector2(-6.0, -28.0)
	draw_line(press_c + Vector2(0, 24), press_c + Vector2(0, -18), Color(0.35, 0.24, 0.15), 5.5)
	# Threaded iron spindle and T-handle
	draw_line(press_c + Vector2(0, -14), press_c + Vector2(0, 10), Color(0.65, 0.68, 0.72), 2.5)
	draw_line(press_c + Vector2(-10, -16), press_c + Vector2(10, -16), Color(0.20, 0.22, 0.25), 3.0)
	# Virgin Coconut Oil collection container below press
	var drum_c := right * 0.6 + Vector2(-6.0, 4.0)
	draw_rect(Rect2(drum_c + Vector2(-6, -8), Vector2(12, 12)), Color(0.32, 0.36, 0.40))
	draw_circle(drum_c + Vector2(0, -8), 6.0, Color(0.92, 0.98, 0.85)) # Crystal clear VCO

	# Light smoke wafting from drying coconuts
	if state == BuildingState.ACTIVE:
		for sm in range(2):
			var sm_phase: float = fmod(t * 0.9 + float(sm) * 0.8, 1.8)
			var sm_y: float = sm_phase * 24.0
			var sm_alpha: float = (1.0 - sm_phase / 1.8) * 0.35
			draw_circle(Vector2(sin(sm_phase * 3.0) * 8.0, grate_y - 12.0 - sm_y), 5.0 + sm_phase * 4.0, Color(0.95, 0.95, 0.95, sm_alpha))

func _draw_coffee_roastery(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001

	# Ground contact shadow
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.48))
	draw_circle(Vector2.ZERO, 56.0, Color(0.08, 0.06, 0.04, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Red Volcanic Brick Roastery Building Base
	var wall_h: float = 44.0
	var w_left := PackedVector2Array([
		left * 0.75, bottom * 0.75,
		bottom * 0.75 + Vector2(0, -wall_h),
		left * 0.75 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_left, Color(0.50, 0.22, 0.18))
	draw_polyline(w_left, Color(0.28, 0.10, 0.08), 1.5)

	var w_right := PackedVector2Array([
		bottom * 0.75, right * 0.75,
		right * 0.75 + Vector2(0, -wall_h),
		bottom * 0.75 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_right, Color(0.60, 0.28, 0.22))
	draw_polyline(w_right, Color(0.34, 0.14, 0.10), 1.5)

	# Slate Grey Pitched Industrial Roof
	var apex_y: float = -wall_h - 22.0
	var roof_l := PackedVector2Array([
		left * 0.8 + Vector2(0, -wall_h),
		bottom * 0.8 + Vector2(0, -wall_h),
		Vector2(0, apex_y),
		top * 0.4 + Vector2(0, apex_y + 10.0)
	])
	draw_colored_polygon(roof_l, Color(0.30, 0.34, 0.38))
	draw_polyline(roof_l, Color(0.16, 0.18, 0.22), 1.8)

	var roof_r := PackedVector2Array([
		bottom * 0.8 + Vector2(0, -wall_h),
		right * 0.8 + Vector2(0, -wall_h),
		top * 0.4 + Vector2(0, apex_y + 10.0),
		Vector2(0, apex_y)
	])
	draw_colored_polygon(roof_r, Color(0.38, 0.42, 0.46))
	draw_polyline(roof_r, Color(0.20, 0.22, 0.26), 1.8)

	# 1. Cast-Iron Rotating Drum Roaster (Mounted in front center aperture)
	var drum_c := Vector2(-10.0, -22.0)
	draw_circle(drum_c, 14.0, Color(0.20, 0.22, 0.24)) # Cast iron cylinder
	draw_circle(drum_c, 11.5, Color(0.28, 0.30, 0.34))
	# Copper accent bands & rotating crank axle
	draw_line(drum_c + Vector2(-14, 0), drum_c + Vector2(14, 0), Color(0.78, 0.48, 0.25), 2.2)
	var rot_d: float = t * 6.0 if state == BuildingState.ACTIVE else 0.0
	draw_line(drum_c, drum_c + Vector2(cos(rot_d) * 9, sin(rot_d) * 9), Color(0.92, 0.72, 0.35), 2.0)

	# Gas burner flame inspection sight glass (glowing warm orange)
	draw_circle(drum_c + Vector2(0, 7), 3.0, Color(1.0, 0.45, 0.10, 0.95))

	# 2. Circular Cooling Agitation Tray (Front staging area)
	var tray_c := bottom * 0.45 + Vector2(12.0, 0.0)
	draw_set_transform(tray_c, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 15.0, Color(0.65, 0.68, 0.72)) # Stainless steel rim
	draw_circle(Vector2.ZERO, 13.0, Color(0.24, 0.14, 0.08)) # Roasted dark brown coffee beans
	# Rotating cooling paddles
	var p_rot: float = t * 3.5 if state == BuildingState.ACTIVE else 0.0
	draw_line(Vector2(cos(p_rot)*11, sin(p_rot)*11), Vector2(-cos(p_rot)*11, -sin(p_rot)*11), Color(0.85, 0.88, 0.92), 1.8)
	draw_line(Vector2(cos(p_rot + 1.57)*11, sin(p_rot + 1.57)*11), Vector2(-cos(p_rot + 1.57)*11, -sin(p_rot + 1.57)*11), Color(0.85, 0.88, 0.92), 1.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 3. Exhaust Flue Chimney venting aromatic roaster smoke
	var flue_base := top * 0.3 + Vector2(-12.0, apex_y + 6.0)
	draw_line(flue_base, flue_base + Vector2(0, -22), Color(0.72, 0.75, 0.78), 3.5)
	draw_circle(flue_base + Vector2(0, -22), 2.5, Color(0.45, 0.48, 0.52))

	if state == BuildingState.ACTIVE:
		for c_sm in range(2):
			var c_phase: float = fmod(t * 1.4 + float(c_sm) * 0.7, 1.6)
			var c_y: float = c_phase * 22.0
			var c_alpha: float = (1.0 - c_phase / 1.6) * 0.40
			draw_circle(flue_base + Vector2(sin(c_phase * 3.0) * 4.0, -22.0 - c_y), 3.5 + c_phase * 3.0, Color(0.85, 0.80, 0.75, c_alpha))

	# 4. Stacks of Burlap Coffee Sacks
	var sack_pos := bottom * 0.45 + Vector2(-20.0, -2.0)
	draw_rect(Rect2(sack_pos + Vector2(-6, -8), Vector2(12, 10)), Color(0.78, 0.68, 0.48))
	draw_circle(sack_pos + Vector2(0, -8), 2.0, Color(0.35, 0.22, 0.12)) # Tie
	draw_rect(Rect2(sack_pos + Vector2(3, -6), Vector2(10, 9)), Color(0.72, 0.62, 0.42))

func _draw_default_building(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var w := PackedVector2Array([
		left * 0.8, bottom * 0.8, bottom * 0.8 + Vector2(0, -36), left * 0.8 + Vector2(0, -36)
	])
	draw_colored_polygon(w, Color(0.55, 0.45, 0.35))
	draw_polyline(w, Color(0.3, 0.2, 0.1), 2.0)

func _draw_scaffold_overlay(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	# 2.5D Isometric construction timber scaffolding
	var wood := Color(0.80, 0.58, 0.25, 0.95)
	var scaffold_h: float = 55.0
	var fit: Dictionary = get_art_fit(building_type)
	if not fit.is_empty():
		scaffold_h = float(fit.get("scaffold_h", 70.0))
	elif building_type in ["water_tower", "drone_station", "weather_station"]:
		scaffold_h = 75.0
	elif building_type == "cold_storage":
		scaffold_h = 65.0

	var p_top    := top + Vector2(0, -scaffold_h)
	var p_right  := right + Vector2(0, -scaffold_h)
	var p_bottom := bottom + Vector2(0, -scaffold_h)
	var p_left   := left + Vector2(0, -scaffold_h)

	# Corner vertical scaffold posts
	draw_line(top, p_top, wood, 3.0)
	draw_line(right, p_right, wood, 3.0)
	draw_line(bottom, p_bottom, wood, 3.0)
	draw_line(left, p_left, wood, 3.0)

	# Diagonal crossbeams
	draw_line(left, p_bottom, wood, 2.0)
	draw_line(bottom, p_left, wood, 2.0)
	draw_line(bottom, p_right, wood, 2.0)
	draw_line(right, p_bottom, wood, 2.0)

	# Top perimeter beam
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), wood, 2.5)
