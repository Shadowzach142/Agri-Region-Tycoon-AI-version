# ShopPanel.gd
# Agri-Tech, Infrastructure, Machinery, Labor Hiring, and Bulk Seeds Shop.

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

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	EconomyManager.cash_changed.connect(_on_cash_changed)
	_on_cash_changed(EconomyManager.cash)

	_populate_shop()

func _on_cash_changed(amount: int) -> void:
	if cash_label:
		cash_label.text = "Funds: 💰 ₱%d" % amount

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
		row.add_theme_constant_override("separation", 12)

		var name_lbl: Label = Label.new()
		name_lbl.text = "⚡ %s" % t_data.get("display_name", tech_key)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var cost: int = int(t_data.get("cost", 500))
		var cost_lbl: Label = Label.new()
		cost_lbl.text = "₱%d" % cost
		cost_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(cost_lbl)

		var buy_btn: Button = Button.new()
		buy_btn.custom_minimum_size = Vector2(100, 32)
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
		row.add_theme_constant_override("separation", 12)

		var name_lbl: Label = Label.new()
		var perk: String = ""
		if b_data.get("halts_spoilage", false):
			perk = " [Halts ROT completely!]"
		elif b_data.get("storage_limit", 0) > 0:
			perk = " [+%d Storage]" % b_data.get("storage_limit", 0)
		elif b_data.get("worker_capacity", 0) > 0:
			perk = " [+%d Worker Cap]" % b_data.get("worker_capacity", 0)

		name_lbl.text = "🏛️ %s%s" % [b_data.get("display_name", b_key), perk]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var cost: int = int(b_data.get("cost", 400))
		var cost_lbl: Label = Label.new()
		cost_lbl.text = "₱%d" % cost
		cost_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(cost_lbl)

		var buy_btn: Button = Button.new()
		buy_btn.custom_minimum_size = Vector2(100, 32)
		buy_btn.text = "Construct"
		buy_btn.pressed.connect(func(): _buy_building(b_key, cost))
		row.add_child(buy_btn)

		building_container.add_child(row)

func _populate_labor() -> void:
	for child in labor_container.get_children():
		child.queue_free()

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info_lbl: Label = Label.new()
	info_lbl.text = "🧑‍🌾 Hire Extra Farm Worker (Workers: %d / %d Housing Capacity)" % [
		BuildingManager.active_workers,
		BuildingManager.worker_capacity
	]
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_lbl)

	var cost_lbl: Label = Label.new()
	cost_lbl.text = "₱200"
	cost_lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(cost_lbl)

	var hire_btn: Button = Button.new()
	hire_btn.custom_minimum_size = Vector2(100, 32)
	hire_btn.text = "Hire Worker"
	hire_btn.disabled = (BuildingManager.active_workers >= BuildingManager.worker_capacity)
	hire_btn.pressed.connect(_hire_worker)
	row.add_child(hire_btn)

	labor_container.add_child(row)

	var tip_lbl: Label = Label.new()
	tip_lbl.text = "Tip: Build Bahay Kubo (Farm Shacks) in the Infrastructure tab to expand housing capacity!"
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
	if BuildingManager.buy_building(b_key):
		status_label.text = "Constructed %s! Storage & capacity expanded." % b_key.capitalize()
		status_label.modulate = Color(0.4, 1.0, 0.4)
		_populate_labor() # Update worker cap display
		item_purchased.emit(b_key, cost)
	else:
		status_label.text = "Insufficient funds for %s!" % b_key.capitalize()
		status_label.modulate = Color(1.0, 0.3, 0.3)

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
	visible = false
