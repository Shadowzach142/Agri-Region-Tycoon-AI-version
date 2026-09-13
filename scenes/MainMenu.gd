# MainMenu.gd
# Handles region selection, displays rich regional profiles (pros & cons), and transitions to MainGame.tscn.

extends Control

@onready var region_selector: OptionButton = $VBoxContainer/RegionSelector
@onready var region_title: Label = $VBoxContainer/ProfileCard/Margin/VBox/RegionTitle
@onready var desc_label: Label = $VBoxContainer/ProfileCard/Margin/VBox/DescLabel
@onready var pros_text: Label = $VBoxContainer/ProfileCard/Margin/VBox/Details/ProsBox/ProsText
@onready var cons_text: Label = $VBoxContainer/ProfileCard/Margin/VBox/Details/ConsBox/ConsText
@onready var start_button: Button = $VBoxContainer/StartButton

var region_keys: Array = [
	"cotabato",
	"south_cotabato",
	"sarangani",
	"sultan_kudarat",
	"general_santos"
]

func _ready() -> void:
	region_selector.clear()
	for i in range(region_keys.size()):
		var r_data = Data.get_region(region_keys[i])
		region_selector.add_item(r_data.get("display_name", region_keys[i]), i)
	
	region_selector.select(0)
	region_selector.item_selected.connect(_on_region_selected)
	start_button.pressed.connect(_on_start_pressed)
	_update_region_profile(0)

func _on_region_selected(idx: int) -> void:
	_update_region_profile(idx)

func _update_region_profile(idx: int) -> void:
	if idx < 0 or idx >= region_keys.size():
		return

	var r_data: Dictionary = Data.get_region(region_keys[idx])
	
	region_title.text = "📍 %s — %s" % [
		r_data.get("display_name", "Region"),
		r_data.get("specialty", "")
	]
	
	desc_label.text = r_data.get("description", "")
	
	# Format Pros
	var pros_array: Array = r_data.get("pros", [])
	var pros_str: String = ""
	for p in pros_array:
		pros_str += "  ✔  %s\n" % p
	pros_text.text = pros_str.strip_edges()

	# Format Cons
	var cons_array: Array = r_data.get("cons", [])
	var cons_str: String = ""
	for c in cons_array:
		cons_str += "  ⚠  %s\n" % c
	cons_text.text = cons_str.strip_edges()

func _on_start_pressed() -> void:
	var idx: int = region_selector.get_selected()
	if idx >= 0 and idx < region_keys.size():
		Data.current_region = region_keys[idx]
	else:
		Data.current_region = "cotabato"
	
	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
