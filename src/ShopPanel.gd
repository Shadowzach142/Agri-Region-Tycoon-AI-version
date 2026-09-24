# ShopPanel.gd
# Agri-Tech, Infrastructure, Machinery, Labor Hiring, and Bulk Equipment Shop.
# Includes prominent "!" info indicators with hover tooltips and interactive detail cards.

extends PanelContainer

signal item_purchased(item_name: String, cost: int)
signal worker_spawn_requested()

@onready var close_btn: Button = $VBox/Header/CloseBtn
@onready var cash_label: Label = $VBox/Header/CashLabel
@onready var status_label: Label = $VBox/StatusLabel

# Containers for shop items
@onready var tech_container: VBoxContainer = $VBox/TabContainer/Machinery/VBox
@onready var building_container: VBoxContainer = $VBox/TabContainer/Infrastructure/VBox
@onready var labor_container: VBoxContainer = $VBox/TabContainer/Labor/VBox

# Interactive Info Card for "!" clicks
@onready var item_info_card: PanelContainer = $VBox/ItemInfoCard
@onready var info_title_lbl: Label = $VBox/ItemInfoCard/HBox/TextVBox/InfoTitle
@onready var info_desc_lbl: Label = $VBox/ItemInfoCard/HBox/TextVBox/InfoDesc
@onready var info_close_btn: Button = $VBox/ItemInfoCard/HBox/InfoCloseBtn

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	if info_close_btn:
		info_close_btn.pressed.connect(func(): item_info_card.visible = false)
	
	EconomyManager.cash_changed.connect(_on_cash_changed)
	_on_cash_changed(EconomyManager.cash)

	_populate_shop()

func _on_cash_changed(amount: int) -> void:
	if cash_label:
		cash_label.text = "Funds: 💰 ₱%d" % amount

func show_info(title: String, desc: String) -> void:
	if item_info_card and info_title_lbl and info_desc_lbl:
		info_title_lbl.text = "ℹ️ " + title
		info_desc_lbl.text = desc
		item_info_card.visible = true

func _create_info_btn(title: String, desc: String) -> Button:
	var btn: Button = Button.new()
	btn.text = "!"
	btn.custom_minimum_size = Vector2(28, 28)
	btn.tooltip_text = "%s\n%s" % [title, desc]
	
	# Clean amber badge style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.17, 0.06, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.78, 0.22, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func(): show_info(title, desc))
	return btn

func _populate_shop() -> void:
	_populate_tech()
	_populate_buildings()
	_populate_labor()

func _populate_tech() -> void:
	for child in tech_container.get_children():
		child.queue_free()

	for tech_key in Data.TECH.keys():
		var t_data: Dictionary = Data.get_tech(tech_key)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_lbl: Label = Label.new()
		name_lbl.text = "⚡ %s" % t_data.get("display_name", tech_key)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var desc: String = t_data.get("description", "Technology enhancement for your farm.")
		var info_btn = _create_info_btn(t_data.get("display_name", tech_key), desc)
		row.add_child(info_btn)

		var cost: int = int(t_data.get("cost", 500))
		var cost_lbl: Label = Label.new()
		cost_lbl.text = "₱%d" % cost
		cost_lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(cost_lbl)

		var buy_btn: Button = Button.new()
		buy_btn.custom_minimum_size = Vector2(95, 30)
		if BuildingManager.has_tech(tech_key):
			buy_btn.text = "Owned ✔"
			buy_btn.disabled = true
		else:
			buy_btn.text = "Purchase"
			buy_btn.pressed.connect(func(): _buy_tech(tech_key, cost, buy_btn))
		row.add_child(buy_btn)

		tech_container.add_child(row)

func _populate_buildings() -> void:
	for child in building_container.get_children():
		child.queue_free()

	for b_key in Data.BUILDINGS.keys():
		var b_data: Dictionary = Data.get_building(b_key)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_lbl: Label = Label.new()
		var perk: String = ""
		if b_data.get("halts_spoilage", false):
			perk = " [Halts ROT]"
		elif b_data.get("storage_limit", 0) > 0:
			perk = " [+%d Cap]" % b_data.get("storage_limit", 0)
		elif b_data.get("worker_capacity", 0) > 0:
			perk = " [+%d Worker]" % b_data.get("worker_capacity", 0)

		name_lbl.text = "🏛️ %s%s" % [b_data.get("display_name", b_key), perk]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var desc: String = b_data.get("description", "Farm infrastructure facility.")
		var info_btn = _create_info_btn(b_data.get("display_name", b_key), desc)
		row.add_child(info_btn)

		var cost: int = int(b_data.get("cost", 400))
		var cost_lbl: Label = Label.new()
		cost_lbl.text = "₱%d" % cost
		cost_lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(cost_lbl)

		var buy_btn: Button = Button.new()
		buy_btn.custom_minimum_size = Vector2(95, 30)
		buy_btn.text = "Construct"
		buy_btn.pressed.connect(func(): _buy_building(b_key, cost))
		row.add_child(buy_btn)

		building_container.add_child(row)

func _populate_labor() -> void:
	for child in labor_container.get_children():
		child.queue_free()

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var info_lbl: Label = Label.new()
	info_lbl.text = "🧑‍🌾 Hire Extra Farm Worker (Workers: %d / %d Cap)" % [
		BuildingManager.active_workers,
		BuildingManager.worker_capacity
	]
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_lbl)

	var labor_desc: String = "Hires an additional autonomous farm worker. Farmers automatically navigate to queued tasks (Plowing, Planting, Watering, Pest Spraying, and Harvesting) and deposit harvested produce into storage. Daily wage: ₱15."
	var info_btn = _create_info_btn("Autonomous Farm Laborer", labor_desc)
	row.add_child(info_btn)

	var cost_lbl: Label = Label.new()
	cost_lbl.text = "₱200"
	cost_lbl.custom_minimum_size = Vector2(70, 0)
	row.add_child(cost_lbl)

	var hire_btn: Button = Button.new()
	hire_btn.custom_minimum_size = Vector2(95, 30)
	hire_btn.text = "Hire Worker"
	hire_btn.disabled = (BuildingManager.active_workers >= BuildingManager.worker_capacity)
	hire_btn.pressed.connect(_hire_worker)
	row.add_child(hire_btn)

	labor_container.add_child(row)

	var tip_lbl: Label = Label.new()
	tip_lbl.text = "Tip: Build Bahay Kubo (Farm Shacks) in Infrastructure to expand housing capacity!"
	tip_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.65))
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labor_container.add_child(tip_lbl)

func _buy_tech(tech_key: String, cost: int, btn: Button) -> void:
	if BuildingManager.buy_tech(tech_key):
		btn.text = "Owned ✔"
		btn.disabled = true
		status_label.text = "Successfully unlocked %s!" % tech_key.capitalize()
		status_label.modulate = Color(0.4, 1.0, 0.4)
		item_purchased.emit(tech_key, cost)
	else:
		status_label.text = "Insufficient funds for %s!" % tech_key.capitalize()
		status_label.modulate = Color(1.0, 0.3, 0.3)

func _buy_building(b_key: String, cost: int) -> void:
	# Verify funds before entering placement mode
	if EconomyManager.cash < cost:
		status_label.text = "Insufficient funds for %s! (₱%d required)" % [b_key.capitalize(), cost]
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	# Find FarmGrid and enter placement mode
	var farm_grid: Node = get_tree().root.find_child("FarmGrid", true, false)
	if farm_grid == null:
		status_label.text = "Cannot place building — FarmGrid not found!"
		status_label.modulate = Color(1.0, 0.3, 0.3)
		return

	# Close shop so the player can see the grid
	visible = false

	# Start CoC-style ghost placement
	farm_grid.start_building_placement(b_key)

func _hire_worker() -> void:
	if BuildingManager.hire_worker():
		status_label.text = "Hired an additional autonomous farmer worker!"
		status_label.modulate = Color(0.4, 1.0, 0.4)
		_populate_labor()
		worker_spawn_requested.emit()
	else:
		status_label.text = "Cannot hire! Build Bahay Kubo to increase worker housing capacity."
		status_label.modulate = Color(1.0, 0.3, 0.3)

func _on_close_pressed() -> void:
	if item_info_card:
		item_info_card.visible = false
	visible = false
