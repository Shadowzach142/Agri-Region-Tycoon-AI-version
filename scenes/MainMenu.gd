# MainMenu.gd
# Handles region selection, displays rich regional profiles (pros & cons), and transitions to MainGame.tscn.
# Also contains the Admin Mode unlock toggle for gameplay testing.

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

# Persisted flag — read by MainGame when it starts up
var _admin_mode_enabled: bool = false

# A global singleton-style flag for the lifetime of the process
# (autoloads aren't easy to add on the fly so we use a Node group trick)
const ADMIN_FLAG_GROUP: String = "admin_mode_enabled"

func _ready() -> void:
	region_selector.clear()
	for i in range(region_keys.size()):
		var r_data = Data.get_region(region_keys[i])
		region_selector.add_item(r_data.get("display_name", region_keys[i]), i)

	region_selector.select(0)
	region_selector.item_selected.connect(_on_region_selected)
	start_button.pressed.connect(_on_start_pressed)
	_update_region_profile(0)
	_inject_admin_toggle()

# ---------------------------------------------------------------------------
# Admin Mode toggle — injected into the VBoxContainer at the bottom
# ---------------------------------------------------------------------------
func _inject_admin_toggle() -> void:
	var vbox: VBoxContainer = $VBoxContainer

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var admin_row := HBoxContainer.new()
	admin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(admin_row)

	var chk := CheckBox.new()
	chk.text       = "🛠️  Enable Admin / Debug Panel  (press  `  in-game to open)"
	chk.button_pressed = false
	chk.toggled.connect(func(on: bool) -> void:
		_admin_mode_enabled = on
		# Also update flag node in scene tree so MainGame can detect it
		var flag_nodes = get_tree().get_nodes_in_group(ADMIN_FLAG_GROUP)
		for n in flag_nodes:
			n.queue_free()
		if on:
			var flag := Node.new()
			flag.name = "AdminModeFlag"
			flag.add_to_group(ADMIN_FLAG_GROUP)
			get_tree().root.add_child(flag)
	)
	admin_row.add_child(chk)

	var warn := Label.new()
	warn.text = "⚠ For testing only — not intended for normal gameplay"
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_color_override("font_color", Color(1, 0.75, 0.3, 0.9))
	warn.add_theme_font_size_override("font_size", 11)
	vbox.add_child(warn)

# ---------------------------------------------------------------------------
# Region profile
# ---------------------------------------------------------------------------
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

	var pros_array: Array = r_data.get("pros", [])
	var pros_str: String = ""
	for p in pros_array:
		pros_str += "  ✔  %s\n" % p
	pros_text.text = pros_str.strip_edges()

	var cons_array: Array = r_data.get("cons", [])
	var cons_str: String = ""
	for c in cons_array:
		cons_str += "  ⚠  %s\n" % c
	cons_text.text = cons_str.strip_edges()

# ---------------------------------------------------------------------------
# Start game
# ---------------------------------------------------------------------------
func _on_start_pressed() -> void:
	var idx: int = region_selector.get_selected()
	if idx >= 0 and idx < region_keys.size():
		Data.current_region = region_keys[idx]
	else:
		Data.current_region = "cotabato"

	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
