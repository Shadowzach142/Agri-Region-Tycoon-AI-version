# SaveLoadModal.gd
# Universal Save & Load modal for Agri-Region Tycoon.
# Can be opened in MODE_SAVE (from in-game PauseMenu) or MODE_LOAD (from MainMenu or PauseMenu).
# Displays 5 manual save slots + 1 autosave slot with detailed farm status previews.

class_name SaveLoadModal
extends CanvasLayer

signal closed()
signal save_action_completed(slot_idx: int)
signal load_action_completed(slot_idx: int)

enum Mode { SAVE, LOAD }
var current_mode: Mode = Mode.LOAD

var _dim: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _slots_vbox: VBoxContainer
var _status_notice: Label

func _init(mode: Mode = Mode.LOAD) -> void:
	current_mode = mode
	layer = 230
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build_ui()
	_refresh_slots()
	SaveManager.slots_updated.connect(_refresh_slots)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func set_mode(mode: Mode) -> void:
	current_mode = mode
	if _title_label:
		_title_label.text = "💾 SAVE YOUR FARM" if current_mode == Mode.SAVE else "📂 LOAD SAVED FARM"
	if _subtitle_label:
		_subtitle_label.text = "Select a slot to record your current farm progress" if current_mode == Mode.SAVE else "Select a saved farm file to resume your agribusiness"
	_refresh_slots()

func _build_ui() -> void:
	# 1. Dim background
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.04, 0.02, 0.85)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	# 2. Central Panel Container
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Big-Rectangle-Box/BigPlainBox.tres"))
	_panel.custom_minimum_size = Vector2(660, 520)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# Header HBox (Title + Close Button)
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(title_vbox)

	_title_label = Label.new()
	_title_label.text = "💾 SAVE YOUR FARM" if current_mode == Mode.SAVE else "📂 LOAD SAVED FARM"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	title_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Select a slot to record your current farm progress" if current_mode == Mode.SAVE else "Select a saved farm file to resume your agribusiness"
	_subtitle_label.add_theme_font_size_override("font_size", 11)
	_subtitle_label.add_theme_color_override("font_color", Color(0.42, 0.32, 0.20, 0.9))
	title_vbox.add_child(_subtitle_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 26)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	close_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	close_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	close_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	close_btn.pressed.connect(_on_close_pressed)
	header_hbox.add_child(close_btn)

	var sep1 := HSeparator.new()
	main_vbox.add_child(sep1)

	# Status Notice
	_status_notice = Label.new()
	_status_notice.text = ""
	_status_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_notice.add_theme_font_size_override("font_size", 12)
	_status_notice.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5, 1.0))
	main_vbox.add_child(_status_notice)

	# ScrollContainer with Slot entries
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	_slots_vbox = VBoxContainer.new()
	_slots_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_slots_vbox)

	var sep2 := HSeparator.new()
	main_vbox.add_child(sep2)

	# Footer buttons
	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_END
	footer_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(footer_hbox)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(104, 36)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	back_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	back_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	back_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	back_btn.pressed.connect(_on_close_pressed)
	footer_hbox.add_child(back_btn)

func _refresh_slots() -> void:
	if not _slots_vbox:
		return

	for c in _slots_vbox.get_children():
		c.queue_free()

	# Slots 1 to 5 (manual saves)
	for i in range(1, SaveManager.MAX_SLOTS + 1):
		_create_slot_card(i)

	# Slot 0 (Autosave - only in load mode or display)
	if SaveManager.has_save(SaveManager.AUTOSAVE_SLOT):
		var sep := HSeparator.new()
		sep.modulate = Color(0.65, 0.55, 0.45, 0.40)
		_slots_vbox.add_child(sep)
		_create_slot_card(SaveManager.AUTOSAVE_SLOT)

func _create_slot_card(slot_idx: int) -> void:
	var meta: Dictionary = SaveManager.get_slot_meta(slot_idx)
	var has_data: bool = not meta.is_empty()

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# Left: Slot Badge
	var badge_box := PanelContainer.new()
	badge_box.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/TopRight/BrownBox.tres"))
	badge_box.custom_minimum_size = Vector2(76, 54)
	hbox.add_child(badge_box)

	var badge_lbl := Label.new()
	badge_lbl.text = "AUTOSAVE" if slot_idx == 0 else "SLOT %d" % slot_idx
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0) if has_data else Color(0.65, 0.60, 0.55, 0.8))
	badge_box.add_child(badge_lbl)

	# Middle: Info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	if has_data:
		var slot_title := Label.new()
		slot_title.text = meta.get("title", "Saved Farm")
		slot_title.add_theme_font_size_override("font_size", 15)
		slot_title.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
		info_vbox.add_child(slot_title)

		var details_line := Label.new()
		var m_title: String = meta.get("game_mode_title", "Farm")
		var day_num: int = meta.get("day", 1)
		var cash_num: int = meta.get("cash", 0)
		var pts_num: int = meta.get("points", 0)
		var date_str: String = meta.get("date", "")
		details_line.text = "[%s] Day %d • ₱%s • %d pts\nSaved: %s" % [
			m_title, day_num, Utils.format_number(cash_num), pts_num, date_str
		]
		details_line.add_theme_font_size_override("font_size", 12)
		details_line.add_theme_color_override("font_color", Color(0.32, 0.22, 0.12, 1.0))
		info_vbox.add_child(details_line)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "Empty Save Slot"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.48, 0.38, 0.28, 0.85))
		info_vbox.add_child(empty_lbl)

	# Right: Action Buttons
	var action_vbox := VBoxContainer.new()
	action_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(action_vbox)

	if current_mode == Mode.SAVE:
		if slot_idx != SaveManager.AUTOSAVE_SLOT:
			var save_btn := Button.new()
			save_btn.text = "💾 Overwrite" if has_data else "💾 Save Here"
			save_btn.custom_minimum_size = Vector2(110, 36)
			save_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			save_btn.add_theme_font_size_override("font_size", 13)
			save_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
			save_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
			save_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
			save_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
			save_btn.add_theme_color_override("font_hover_color", Color(0.10, 0.06, 0.02))
			save_btn.pressed.connect(func(): _execute_save(slot_idx))
			action_vbox.add_child(save_btn)
	else: # Mode.LOAD
		var load_btn := Button.new()
		load_btn.text = "📂 Load"
		load_btn.custom_minimum_size = Vector2(96, 36)
		load_btn.disabled = not has_data
		load_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has_data else Control.CURSOR_ARROW
		load_btn.add_theme_font_size_override("font_size", 13)
		if has_data:
			load_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
			load_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
			load_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
			load_btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06))
			load_btn.add_theme_color_override("font_hover_color", Color(0.10, 0.06, 0.02))
		else:
			load_btn.remove_theme_stylebox_override("normal")
			load_btn.remove_theme_stylebox_override("hover")
			load_btn.remove_theme_stylebox_override("pressed")
			load_btn.remove_theme_stylebox_override("disabled")
			load_btn.remove_theme_color_override("font_disabled_color")
			load_btn.remove_theme_color_override("font_color")
		load_btn.pressed.connect(func(): _execute_load(slot_idx))
		action_vbox.add_child(load_btn)

	if has_data and slot_idx != SaveManager.AUTOSAVE_SLOT:
		var del_btn := Button.new()
		del_btn.text = "🗑️"
		del_btn.custom_minimum_size = Vector2(36, 30)
		del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		del_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
		del_btn.add_theme_stylebox_override("hover", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
		del_btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
		del_btn.pressed.connect(func(): _execute_delete(slot_idx))
		action_vbox.add_child(del_btn)

	_slots_vbox.add_child(card)

func _execute_save(slot_idx: int) -> void:
	var success = SaveManager.save_game(slot_idx)
	if success:
		_show_notice("✅ Farm successfully saved to Slot %d!" % slot_idx, Color(0.3, 0.95, 0.4))
		save_action_completed.emit(slot_idx)
	else:
		_show_notice("❌ Failed to save game to Slot %d", Color(1.0, 0.4, 0.4))

func _execute_load(slot_idx: int) -> void:
	_show_notice("📂 Loading Slot %d..." % slot_idx, Color(0.4, 0.8, 1.0))
	load_action_completed.emit(slot_idx)
	SaveManager.load_game(slot_idx)
	queue_free()

func _execute_delete(slot_idx: int) -> void:
	if SaveManager.delete_slot(slot_idx):
		_show_notice("Deleted Slot %d" % slot_idx, Color(0.9, 0.6, 0.3))
		_refresh_slots()

func _show_notice(text: String, col: Color) -> void:
	if _status_notice:
		_status_notice.text = text
		_status_notice.add_theme_color_override("font_color", col)

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
