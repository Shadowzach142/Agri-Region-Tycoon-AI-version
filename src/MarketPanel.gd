# MarketPanel.gd
# Regional Marketplace, Logistics Hubs, Distance Fuel Costs, and ROT/Spoilage Mechanics.

extends PanelContainer

@onready var close_btn: Button = $VBox/Header/CloseBtn
@onready var price_list: VBoxContainer = $VBox/Content/PricesSection/PriceList
@onready var forecast_list: VBoxContainer = $VBox/Content/ForecastSection/ForecastList
@onready var storage_list: ItemList = $VBox/Content/LogisticsSection/StorageList
@onready var hub_selector: OptionButton = $VBox/Content/LogisticsSection/HubSelector
@onready var hub_details_label: Label = $VBox/Content/LogisticsSection/HubDetailsLabel
@onready var sell_btn: Button = $VBox/Content/LogisticsSection/SellBtn
@onready var status_msg: Label = $VBox/Content/LogisticsSection/StatusMsg

var hub_keys: Array = [
	"local_biyahero",
	"tacurong",
	"koronadal",
	"gensan_port"
]

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	sell_btn.pressed.connect(_on_sell_pressed)
	hub_selector.item_selected.connect(_on_hub_selected)
	
	MarketManager.inventory_changed.connect(refresh_inventory)
	MarketManager.price_updated.connect(_on_price_updated)
	MarketManager.sale_completed.connect(_on_sale_completed)
	WeatherManager.weather_changed.connect(_on_weather_changed)

	_setup_hubs()
	refresh_prices()
	refresh_forecast()
	refresh_inventory()
	_update_hub_details(0)

func _setup_hubs() -> void:
	hub_selector.clear()
	for i in range(hub_keys.size()):
		var h_data = Data.get_market_hub(hub_keys[i])
		hub_selector.add_item(
			"%s (%d km) — ₱%d Fuel" % [
				h_data.get("display_name", hub_keys[i]),
				int(h_data.get("distance_km", 0)),
				int(h_data.get("fuel_cost", 0))
			],
			i
		)
	hub_selector.select(0)

func _on_hub_selected(idx: int) -> void:
	_update_hub_details(idx)

func _update_hub_details(idx: int) -> void:
	if idx < 0 or idx >= hub_keys.size():
		return
	var h_data = Data.get_market_hub(hub_keys[idx])
	var has_cold: bool = BuildingManager.has_cold_storage()
	var rot_info: String = "%.0f%% Road Rot Decay" % h_data.get("rot_risk_percent", 0.0)
	if has_cold:
		rot_info = "❄️ 0% Rot (Cold Chain Protected)"

	hub_details_label.text = "Distance: %d km | Fuel Fee: ₱%d | Price: %.0f%% | Transit Rot Risk: %s\n%s" % [
		int(h_data.get("distance_km", 0)),
		int(h_data.get("fuel_cost", 0)),
		float(h_data.get("price_multiplier", 1.0)) * 100.0,
		rot_info,
		h_data.get("description", "")
	]

func refresh_prices() -> void:
	for child in price_list.get_children():
		child.queue_free()

	for crop_name in Data.CROPS.keys():
		var crop_data = Data.get_crop(crop_name)
		var base_p = crop_data.get("base_price", 100)
		var current_p = MarketManager.calculate_unit_price(crop_name, "Grade A", 100.0, "local_biyahero")
		
		var row: HBoxContainer = HBoxContainer.new()
		var name_lbl: Label = Label.new()
		name_lbl.text = "%s %s" % [crop_data.get("icon", "🌱"), crop_data.get("display_name", crop_name)]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var price_lbl: Label = Label.new()
		price_lbl.text = "₱%.0f/u (Base: ₱%d)" % [current_p, base_p]
		row.add_child(price_lbl)

		price_list.add_child(row)

func refresh_forecast() -> void:
	for child in forecast_list.get_children():
		child.queue_free()

	var max_days: int = 1
	var tech_status: String = "📻 Basic AM Radio (60% Accuracy)"
	if BuildingManager.has_tech("iot_soil_sensor"):
		max_days = 7
		tech_status = "🛰️ Satellite IoT (100% Accuracy)"
	elif BuildingManager.has_tech("aws_station"):
		max_days = 3
		tech_status = "📡 AWS Station (90% Accuracy)"
	elif BuildingManager.has_tech("radio_tower"):
		max_days = 1
		tech_status = "📻 AM Radio Tower (60% Accuracy)"
	else:
		tech_status = "📻 Uncalibrated (Buy AM Radio in Shop)"

	var header_lbl: Label = Label.new()
	header_lbl.text = tech_status
	header_lbl.add_theme_font_size_override("font_size", 10)
	header_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	forecast_list.add_child(header_lbl)

	var forecast_data = WeatherManager.get_forecast()
	for i in range(mini(max_days, forecast_data.size())):
		var f = forecast_data[i]
		var day_idx: int = f.get("day", i + 1)
		var temp: float = f.get("temperature", 28.0)
		var hum: float = f.get("humidity", 0.6) * 100.0
		var hazard: String = f.get("hazard", "clear")

		var row: HBoxContainer = HBoxContainer.new()
		var day_lbl: Label = Label.new()
		day_lbl.text = "Day +%d: %.1f°C | %.0f%% Hum" % [day_idx, temp, hum]
		day_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(day_lbl)

		var hazard_lbl: Label = Label.new()
		if hazard == "clear":
			hazard_lbl.text = "☀️ Fair Weather"
			hazard_lbl.modulate = Color(0.6, 0.9, 0.6)
		elif hazard == "flash_flood":
			hazard_lbl.text = "🌊 Flash Flood"
			hazard_lbl.modulate = Color(0.3, 0.6, 1.0)
		elif hazard == "el_nino_drought":
			hazard_lbl.text = "☀️ Severe Drought"
			hazard_lbl.modulate = Color(1.0, 0.4, 0.2)
		row.add_child(hazard_lbl)

		forecast_list.add_child(row)

func refresh_inventory() -> void:
	storage_list.clear()
	var batches = MarketManager.stored_inventory

	if batches.is_empty():
		storage_list.add_item("(No harvested crops in storage. Harvest tiles to store yield.)")
		sell_btn.disabled = true
		return

	sell_btn.disabled = false
	var has_cold: bool = BuildingManager.has_cold_storage()

	for i in range(batches.size()):
		var b = batches[i]
		var crop_data = Data.get_crop(b.crop)
		var storage_type: String = "Cold Storage ❄️" if (b.get("is_cold_storage", false) or has_cold) else "Bodega"
		
		var rot_tag: String = ""
		if b.freshness <= 0.0:
			rot_tag = " [💀 TOTAL ROT - RUINED]"
		elif b.freshness < 25.0:
			rot_tag = " [⚠️ ROTTING - 65% LOSS]"

		var item_text: String = "%s %s (x%d) | %s | Fresh: %.0f%%%s [%s]" % [
			crop_data.get("icon", "🌾"),
			crop_data.get("display_name", b.crop),
			b.quantity,
			b.grade,
			b.freshness,
			rot_tag,
			storage_type
		]
		storage_list.add_item(item_text)

func _on_sell_pressed() -> void:
	var selected_items = storage_list.get_selected_items()
	if selected_items.is_empty():
		status_msg.text = "Select a crop batch above to ship & sell!"
		status_msg.modulate = Color(1.0, 0.8, 0.2)
		return

	var batch_idx: int = selected_items[0]
	var hub_idx: int = hub_selector.get_selected()
	if hub_idx < 0 or hub_idx >= hub_keys.size():
		hub_idx = 0
	var hub_id: String = hub_keys[hub_idx]

	var success: bool = MarketManager.sell_stored_batch(batch_idx, hub_id)
	if not success:
		status_msg.text = "Sale failed! Not enough funds to cover transit fuel expenses."
		status_msg.modulate = Color(1.0, 0.3, 0.3)

func _on_sale_completed(crop: String, gross_rev: int, net_profit: int, hub_name: String, rot_loss: float) -> void:
	var rot_text: String = ""
	if rot_loss > 0.0:
		rot_text = " (Road Rot Decay: -%.0f%%)" % rot_loss
	status_msg.text = "Dispatched %s to %s! Gross: ₱%d | Net Profit: +₱%d%s" % [
		crop.capitalize(),
		hub_name,
		gross_rev,
		net_profit,
		rot_text
	]
	status_msg.modulate = Color(0.4, 1.0, 0.4)
	refresh_prices()

func _on_price_updated(_c: String, _p: float) -> void:
	refresh_prices()

func _on_weather_changed(_t: float, _h: float) -> void:
	refresh_forecast()
	refresh_prices()

func _on_close_pressed() -> void:
	visible = false
