# FarmTile.gd
# Resource representing a single farm tile's state and parameters.

class_name FarmTile
extends Resource

enum TileState {EMPTY, PLOWED, PLANTED, GROWING, HARVESTABLE, INFECTED, FLOODED}
enum QualityGrade {A, B, C}

# Basic properties
var state: int = TileState.EMPTY
var soil_moisture: float = 50.0  # 0 - 100%
var heat_index: float = 28.0     # Celsius
var crop_type: String = ""
var growth_progress: float = 0.0  # 0.0 - 1.0
var health: float = 1.0           # 0.0 - 1.0
var quality: int = QualityGrade.A
var yield_quantity: int = 100
var freshness: float = 100.0
var days_without_water: int = 0
var days_overwatered: int = 0
var hours_waterlogged: int = 0
var soil_fertility: float = 1.0
var pest_type: String = ""

func reset() -> void:
	state = TileState.EMPTY
	crop_type = ""
	growth_progress = 0.0
	health = 1.0
	quality = QualityGrade.A
	yield_quantity = 100
	freshness = 100.0
	days_without_water = 0
	days_overwatered = 0
	hours_waterlogged = 0
	pest_type = ""

