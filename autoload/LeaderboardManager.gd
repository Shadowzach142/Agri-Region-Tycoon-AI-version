# LeaderboardManager.gd
# Personal Run High Score & Performance Scoring Engine.
# The player competes against themselves to achieve the highest score in each run.
#
# Points are calculated from:
# 1. Number of crops sold (volume)
# 2. Harvest quality (Grade A = 2.5x, Grade B = 1.5x, Grade C = 0.8x, plus freshness)
# 3. Market hub destination (Local = 1.0x, Tacurong = 1.35x, Koronadal = 1.75x, Gensan Port = 2.5x)
# 4. Regional specialty bonus (+25% for home region specialty crops)
# 5. Quality streak multiplier (up to 1.5x for shipping consecutive Grade A/B harvests)
#
# Personal Leaderboard:
# Stores and tracks your Top 10 Best Runs locally on this machine (user://personal_leaderboard.json)

extends Node

signal points_changed(total_points: int, points_added: int, reason: String)
signal new_personal_best(new_score: int, old_score: int)
signal run_recorded(entry: Dictionary)

const SAVE_PATH: String = "user://personal_leaderboard.json"

# Base points per crop unit based on crop value and growth cycle
const BASE_CROP_POINTS = {
	"palay": 10,
	"yellow_corn": 15,
	"sugarcane": 18,
	"pineapple": 25,
	"banana": 30,
	"arabica_coffee": 35,
	"coconut": 60,
	"milled_rice": 25,
	"rice_bran": 10,
	"muscovado_sugar": 35,
	"molasses": 15,
	"vco": 55,
	"copra_meal": 15,
	"roasted_coffee": 75,
}

# Quality grade multipliers
const GRADE_MULTIPLIERS = {
	"A": 2.5,
	"B": 1.5,
	"C": 0.8
}

# Destination / Selling Hub multipliers (longer distance & higher logistic risk = much more points)
const HUB_MULTIPLIERS = {
	"local_biyahero": 1.0,
	"tacurong": 1.35,
	"koronadal": 1.75,
	"gensan_port": 2.5
}

# Regional specialty affinity (home region gets +25% points)
const REGION_SPECIALTIES = {
	"cotabato": ["palay", "sugarcane"],
	"south_cotabato": ["arabica_coffee", "yellow_corn", "pineapple"],
	"sarangani": ["coconut", "banana"],
	"sultan_kudarat": ["palay", "sugarcane", "yellow_corn"],
	"general_santos": ["banana", "yellow_corn", "pineapple"]
}

# Current Run State
var current_points: int = 0
var personal_best: int = 0
var current_combo: int = 0
var max_combo: int = 0

# Current Run Statistics
var run_deliveries: int = 0
var run_units_sold: int = 0
var run_grade_a: int = 0
var run_grade_b: int = 0
var run_grade_c: int = 0
var highest_single_sale_pts: int = 0
var crop_sales_volume: Dictionary = {} # crop -> int
var hub_deliveries: Dictionary = {}    # hub -> int

var _personal_runs: Array = []
var _is_new_best_notified: bool = false

func _ready() -> void:
	_personal_runs = load_personal_leaderboard()
	_update_personal_best_from_records()

func _update_personal_best_from_records() -> void:
	personal_best = 0
	for r in _personal_runs:
		var s: int = int(r.get("score", 0))
		if s > personal_best:
			personal_best = s

## Calculates points earned from selling a crop batch
func calculate_sale_points(crop_name: String, quantity: int, grade: String, arrival_freshness: float, hub_id: String) -> Dictionary:
	if quantity <= 0 or arrival_freshness <= 0.0:
		return {
			"base_points": 0,
			"grade_multiplier": 0.0,
			"freshness_multiplier": 0.0,
			"hub_multiplier": 1.0,
			"region_multiplier": 1.0,
			"streak_multiplier": 1.0,
			"total_points": 0,
			"breakdown": "Ruined produce (0 pts)"
		}

	# 1. Base unit points * quantity
	var unit_pts: int = BASE_CROP_POINTS.get(crop_name, 15)
	var raw_base: int = unit_pts * quantity

	# 2. Quality multiplier (Grade A: 2.5x, B: 1.5x, C: 0.8x)
	var grade_mult: float = GRADE_MULTIPLIERS.get(grade, 1.0)

	# 3. Freshness factor (0.1 to 1.0)
	var fresh_mult: float = clampf(arrival_freshness / 100.0, 0.1, 1.0)

	# 4. Destination / Market Hub multiplier (Local: 1.0x, Tacurong: 1.35x, Koronadal: 1.75x, Gensan: 2.5x)
	var hub_mult: float = HUB_MULTIPLIERS.get(hub_id, 1.0)

	# 5. Regional specialty synergy (+25% if shipping active region's signature harvest)
	var specs: Array = REGION_SPECIALTIES.get(Data.current_region, [])
	var reg_mult: float = 1.25 if (crop_name in specs) else 1.0

	# 6. Quality streak multiplier (up to 1.5x for consistent high quality)
	var streak_mult: float = get_combo_multiplier()

	# 7. Pristine harvest bonus (+15% if arrival freshness >= 95%)
	var pristine_mult: float = 1.15 if (arrival_freshness >= 95.0) else 1.0

	var calculated: float = float(raw_base) * grade_mult * fresh_mult * hub_mult * reg_mult * streak_mult * pristine_mult
	var total_pts: int = maxi(int(roundf(calculated)), 1)

	var parts: Array[String] = []
	parts.append("%d base" % raw_base)
	parts.append("%.1fx Grade %s" % [grade_mult, grade])
	parts.append("%.0f%% Fresh" % arrival_freshness)
	parts.append("%.2fx %s" % [hub_mult, Data.get_market_hub(hub_id).get("display_name", hub_id).split("(")[0].strip_edges()])
	if reg_mult > 1.0:
		parts.append("+25% Region Specialty")
	if streak_mult > 1.0:
		parts.append("%.1fx Streak" % streak_mult)
	if pristine_mult > 1.0:
		parts.append("+15% Pristine")

	return {
		"base_points": raw_base,
		"grade_multiplier": grade_mult,
		"freshness_multiplier": fresh_mult,
		"hub_multiplier": hub_mult,
		"region_multiplier": reg_mult,
		"streak_multiplier": streak_mult,
		"total_points": total_pts,
		"breakdown": " • ".join(parts)
	}

## Records points from a completed sale in this run
func record_sale(crop_name: String, quantity: int, grade: String, arrival_freshness: float, hub_id: String) -> int:
	var pts_data: Dictionary = calculate_sale_points(crop_name, quantity, grade, arrival_freshness, hub_id)
	var earned: int = int(pts_data.get("total_points", 0))

	# Update quality streak:
	# Grade A or Grade B with >= 70% freshness continues streak
	# Ruined delivery or Grade C resets streak
	if arrival_freshness > 0.0 and (grade == "A" or (grade == "B" and arrival_freshness >= 70.0)):
		current_combo += 1
		max_combo = maxi(max_combo, current_combo)
	else:
		current_combo = 0

	# Update run statistics
	run_deliveries += 1
	run_units_sold += quantity
	if grade == "A":
		run_grade_a += quantity
	elif grade == "B":
		run_grade_b += quantity
	else:
		run_grade_c += quantity

	crop_sales_volume[crop_name] = int(crop_sales_volume.get(crop_name, 0)) + quantity
	hub_deliveries[hub_id] = int(hub_deliveries.get(hub_id, 0)) + 1
	highest_single_sale_pts = maxi(highest_single_sale_pts, earned)

	if earned > 0:
		current_points += earned
		var hub_name: String = Data.get_market_hub(hub_id).get("display_name", hub_id)
		var reason: String = "Sold %d %s (Grade %s) to %s" % [quantity, crop_name.capitalize(), grade, hub_name]
		points_changed.emit(current_points, earned, reason)

		# Log event in Chronicle
		var log_msg: String = "🏆 +%s Pts! %s (+%d Total: %s Pts)" % [
			Utils.format_number(earned),
			reason,
			earned,
			Utils.format_number(current_points)
		]
		LogManager.log_event("finance", log_msg, "🏆", Color(1.0, 0.85, 0.25), pts_data.get("breakdown", ""))

		# Check for new personal best
		if current_points > personal_best:
			if not _is_new_best_notified and personal_best > 0:
				_is_new_best_notified = true
				new_personal_best.emit(current_points, personal_best)
				LogManager.log_event("finance", "🎉 NEW PERSONAL RECORD! Current run (%s pts) surpassed your best of %s pts!" % [
					Utils.format_number(current_points),
					Utils.format_number(personal_best)
				], "⭐", Color(1.0, 0.95, 0.40))
			personal_best = current_points

	return earned

## Streak multiplier (up to 1.5x max)
func get_combo_multiplier() -> float:
	if current_combo <= 0:
		return 1.0
	return minf(1.0 + (float(current_combo) * 0.05), 1.50)

## Returns player's personal all-time best score
func get_personal_best() -> int:
	return personal_best

## Returns where the current run would rank on your personal leaderboard (1 to 11)
func get_current_run_estimated_rank() -> int:
	var rank: int = 1
	for r in _personal_runs:
		if current_points < int(r.get("score", 0)):
			rank += 1
		else:
			break
	return rank

## Returns player's achievement tier based on points
func get_tycoon_tier(score: int) -> Dictionary:
	if score >= 35000:
		return {"title": "Mindanao Agro-Tycoon", "badge": "👑 SUPREME", "color": Color(1.0, 0.85, 0.20)}
	elif score >= 22000:
		return {"title": "Hacienda Master", "badge": "⭐ MASTER", "color": Color(0.95, 0.65, 0.20)}
	elif score >= 12000:
		return {"title": "Commercial Grower", "badge": "🌾 EXPERT", "color": Color(0.40, 0.85, 0.40)}
	elif score >= 6000:
		return {"title": "Barangay Planter", "badge": "🌱 VENDOR", "color": Color(0.35, 0.75, 1.00)}
	else:
		return {"title": "Subsistence Farmer", "badge": "🧑‍🌾 NOVICE", "color": Color(0.80, 0.75, 0.70)}

## Saves the current run into your personal high-scores list
func save_current_run(custom_run_title: String = "") -> Dictionary:
	var date_dict = Time.get_datetime_dict_from_system()
	var date_str: String = "%04d-%02d-%02d" % [date_dict["year"], date_dict["month"], date_dict["day"]]

	var reg_name: String = Data.REGIONS.get(Data.current_region, {}).get("display_name", Data.current_region).split("(")[0].strip_edges()
	var run_title: String = custom_run_title
	if run_title.is_empty():
		run_title = "%s (%dd Campaign)" % [reg_name, Data.selected_season_days]

	var entry: Dictionary = {
		"title": run_title,
		"region": Data.current_region,
		"region_display": reg_name,
		"score": current_points,
		"days_survived": TimeManager.current_day,
		"season_days": Data.selected_season_days,
		"units_sold": run_units_sold,
		"grade_a_units": run_grade_a,
		"deliveries": run_deliveries,
		"date": date_str
	}

	_personal_runs.append(entry)
	_personal_runs.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))

	# Keep top 10 runs
	if _personal_runs.size() > 10:
		_personal_runs.resize(10)

	_update_personal_best_from_records()
	_save_to_disk()
	run_recorded.emit(entry)
	return entry

## Reset current run points for a new game or fresh start
func reset_current_run() -> void:
	current_points = 0
	current_combo = 0
	max_combo = 0
	run_deliveries = 0
	run_units_sold = 0
	run_grade_a = 0
	run_grade_b = 0
	run_grade_c = 0
	highest_single_sale_pts = 0
	crop_sales_volume.clear()
	hub_deliveries.clear()
	_is_new_best_notified = false
	points_changed.emit(0, 0, "New Run Started")

## Returns the top 10 personal runs
func get_personal_leaderboard() -> Array:
	return _personal_runs

func load_personal_leaderboard() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return _generate_default_runs()

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return _generate_default_runs()

	var content: String = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(content)
	if err == OK and json.data is Array:
		return json.data
	return _generate_default_runs()

func _save_to_disk() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(_personal_runs, "\t")
		file.store_string(json_str)
		file.close()

func _generate_default_runs() -> Array:
	return [
		{
			"title": "Cotabato Basin Harvest Run",
			"region": "cotabato",
			"region_display": "Cotabato Basin",
			"score": 18500,
			"days_survived": 45,
			"units_sold": 1600,
			"grade_a_units": 900,
			"deliveries": 18,
			"date": "2026-09-20"
		},
		{
			"title": "South Cotabato Highland Run",
			"region": "south_cotabato",
			"region_display": "South Cotabato Highlands",
			"score": 12400,
			"days_survived": 35,
			"units_sold": 950,
			"grade_a_units": 600,
			"deliveries": 12,
			"date": "2026-09-18"
		},
		{
			"title": "Sarangani Coastal Palms Run",
			"region": "sarangani",
			"region_display": "Sarangani Littoral Coast",
			"score": 7800,
			"days_survived": 25,
			"units_sold": 600,
			"grade_a_units": 320,
			"deliveries": 8,
			"date": "2026-09-15"
		}
	]
