# Utils.gd
# Common utility definitions: enums, grade multipliers, and helper functions.

class_name Utils
extends RefCounted

# Quality grade enum for readability.
enum Grade {A, B, C}

# Mapping grade enum to string and multiplier.
const GRADE_INFO = {
	Grade.A: {"name": "Grade A", "multiplier": 1.0},
	Grade.B: {"name": "Grade B", "multiplier": 0.7},
	Grade.C: {"name": "Grade C", "multiplier": 0.4},
}

# Convert grade enum to display string.
static func grade_to_string(grade: int) -> String:
	return GRADE_INFO.get(grade, {"name": "Unknown"}).name

# Get multiplier for grade.
static func grade_multiplier(grade: int) -> float:
	return GRADE_INFO.get(grade, {"multiplier": 0.5}).multiplier

# Helper to clamp a value between min and max.
static func clamp_value(value: float, min_val: float, max_val: float) -> float:
	return clamp(value, min_val, max_val)

## Format an integer with comma thousands separators (e.g. 1234567 -> "1,234,567")
static func format_number(val: int) -> String:
	var s: String      = str(val)
	var result: String = ""
	var count: int     = 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result
	return result
