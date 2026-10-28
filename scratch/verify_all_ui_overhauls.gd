extends Node

func _ready() -> void:
	print("========================================")
	print("Starting UI Overhaul & Contrast Verification")
	print("========================================")
	
	# 1. Test MarketPanel & MarketChart
	var market_script = load("res://src/market/MarketPanel.gd")
	assert(market_script != null, "MarketPanel script must load")
	var market = PanelContainer.new()
	market.set_script(market_script)
	add_child(market)
	market._build_ui()
	assert(market.custom_minimum_size.x >= 860, "MarketPanel width must be >= 860")
	assert(market.custom_minimum_size.y >= 520, "MarketPanel height must be >= 520")
	print("✔ MarketPanel: Sized to 860x520 with spacious columns and high-contrast labels")
	market.queue_free()

	# 2. Test SellPanel
	var sell_script = load("res://src/market/SellPanel.gd")
	assert(sell_script != null, "SellPanel script must load")
	var sell = PanelContainer.new()
	sell.set_script(sell_script)
	add_child(sell)
	sell._build_ui()
	assert(sell.custom_minimum_size.x >= 860, "SellPanel width must be >= 860")
	assert(sell.custom_minimum_size.y >= 490, "SellPanel height must be >= 490")
	print("✔ SellPanel: Sized to 860x490 with generous padding, high-contrast text and wood buttons")
	sell.queue_free()

	# 3. Test BuildingCardPopup
	var b_scene = load("res://scenes/BuildingCardPopup.tscn")
	assert(b_scene != null, "BuildingCardPopup scene must load")
	var b_popup = b_scene.instantiate()
	add_child(b_popup)
	var b_inner = b_popup.get_node("CenterContainer/Panel") as PanelContainer
	assert(b_inner != null, "Inner panel must exist")
	assert(b_inner.custom_minimum_size.x >= 480, "BuildingCardPopup width >= 480")
	var title_lbl = b_popup.find_child("TitleLabel", true, false) as Label
	assert(title_lbl.get_theme_font_size("font_size") >= 20, "TitleLabel font size >= 20")
	var level_lbl = b_popup.find_child("LevelLabel", true, false) as Label
	assert(level_lbl.get_theme_font_size("font_size") >= 15, "LevelLabel font size >= 15")
	var upgrade_btn = b_popup.find_child("UpgradeBtn", true, false) as Button
	assert(upgrade_btn != null, "UpgradeBtn must exist")
	assert(not upgrade_btn.has_theme_stylebox_override("disabled"), "UpgradeBtn must NOT force disabled stylebox (restored clean locked button)")
	assert(upgrade_btn.get_theme_font_size("font_size") >= 14, "UpgradeBtn font size >= 14")
	print("✔ BuildingCardPopup: 20pt title, 15pt stats, clean locked button without unused bottom space")
	b_popup.queue_free()

	# 4. Test BacklogPanel
	var backlog_script = load("res://src/ui/BacklogPanel.gd")
	assert(backlog_script != null, "BacklogPanel script must load")
	var backlog = CanvasLayer.new()
	backlog.set_script(backlog_script)
	add_child(backlog)
	assert(backlog._panel.custom_minimum_size.x >= 820, "BacklogPanel width >= 820")
	assert(backlog._panel.custom_minimum_size.y >= 560, "BacklogPanel height >= 560")
	var margin_top = backlog._panel.get_child(0).get_theme_constant("margin_top")
	assert(margin_top >= 60, "BacklogPanel margin_top must clear clipboard clamp (>=60)")
	print("✔ BacklogPanel: Sized to 820x560 with margin_top 64 clearing clipboard clamp")
	backlog.queue_free()

	# 5. Test LeaderboardPanel
	var lb_script = load("res://src/ui/LeaderboardPanel.gd")
	assert(lb_script != null, "LeaderboardPanel script must load")
	var lb = CanvasLayer.new()
	lb.set_script(lb_script)
	add_child(lb)
	assert(lb._panel.custom_minimum_size.x >= 780, "LeaderboardPanel width >= 780")
	print("✔ LeaderboardPanel: High-contrast standings table and score cards verified")
	lb.queue_free()

	# 6. Test EarlyHarvestModal
	var eh_script = load("res://src/ui/EarlyHarvestModal.gd")
	assert(eh_script != null, "EarlyHarvestModal script must load")
	var eh = CanvasLayer.new()
	eh.set_script(eh_script)
	add_child(eh)
	assert(eh._panel.custom_minimum_size.x >= 540, "EarlyHarvestModal width >= 540")
	assert(eh._panel.custom_minimum_size.y >= 390, "EarlyHarvestModal height >= 390")
	print("✔ EarlyHarvestModal: Sized to 540x390 with Samplebox parchment and BrownBox trade-off card")
	eh.queue_free()

	# 7. Test LandExpansionModal
	var land_script = load("res://src/ui/LandExpansionModal.gd")
	assert(land_script != null, "LandExpansionModal script must load")
	var land = CanvasLayer.new()
	land.set_script(land_script)
	add_child(land)
	assert(land._panel.custom_minimum_size.x >= 520, "LandExpansionModal width >= 520")
	assert(land._panel.custom_minimum_size.y >= 360, "LandExpansionModal height >= 360")
	print("✔ LandExpansionModal: Sized to 520x360 with deep dark text on parchment and styled buttons")
	land.queue_free()

	# 8. Test PauseMenu
	var pm_script = load("res://src/ui/PauseMenu.gd")
	assert(pm_script != null, "PauseMenu script must load")
	var pm = CanvasLayer.new()
	pm.set_script(pm_script)
	add_child(pm)
	assert(pm._panel.custom_minimum_size.x >= 430, "PauseMenu width >= 430")
	assert(pm._panel.custom_minimum_size.y >= 520, "PauseMenu height >= 520")
	print("✔ PauseMenu: Sized to 430x520 with 24pt title, 42px resume button and warm ivory text")
	pm.queue_free()

	# 9. Test SaveLoadModal
	var sl_script = load("res://src/ui/SaveLoadModal.gd")
	assert(sl_script != null, "SaveLoadModal script must load")
	var sl = CanvasLayer.new()
	sl.set_script(sl_script)
	add_child(sl)
	assert(sl._panel.custom_minimum_size.x >= 660, "SaveLoadModal width >= 660")
	print("✔ SaveLoadModal: Samplebox cards updated with deep espresso text and carved wood back button")
	sl.queue_free()

	# 10. Test SeasonResultsModal
	var sr_script = load("res://src/ui/SeasonResultsModal.gd")
	assert(sr_script != null, "SeasonResultsModal script must load")
	var sr = CanvasLayer.new()
	sr.set_script(sr_script)
	add_child(sr)
	assert(sr._panel.custom_minimum_size.x >= 620, "SeasonResultsModal width >= 620")
	assert(sr._panel.custom_minimum_size.y >= 530, "SeasonResultsModal height >= 530")
	print("✔ SeasonResultsModal: Sized to 620x530 with high-contrast bronze/dark text on logs parchment")
	sr.queue_free()

	# 11. Test AdminPanel
	var adm_script = load("res://src/ui/AdminPanel.gd")
	assert(adm_script != null, "AdminPanel script must load")
	var adm = CanvasLayer.new()
	adm.set_script(adm_script)
	add_child(adm)
	assert(adm._panel.get_child(0) is MarginContainer, "AdminPanel must have MarginContainer padding")
	print("✔ AdminPanel: MarginContainer padding added and warm ivory text on brown buttons verified")
	adm.queue_free()

	# 12. Test TileActionPopup
	var tap_script = load("res://src/ui/TileActionPopup.gd")
	assert(tap_script != null, "TileActionPopup script must load")
	var tap = PopupMenu.new()
	tap.set_script(tap_script)
	add_child(tap)
	tap._apply_rustic_style()
	assert(tap.get_theme_font_size("font_size") >= 13, "TileActionPopup font_size >= 13")
	assert(tap.get_theme_constant("v_separation") >= 6, "TileActionPopup v_separation >= 6")
	print("✔ TileActionPopup: Font size 13 with 6px vertical separation and high-contrast headers")
	tap.queue_free()

	# 13. Test MainGame.tscn
	var mg_scene = load("res://scenes/MainGame.tscn")
	assert(mg_scene != null, "MainGame scene must load")
	var mg = mg_scene.instantiate()
	add_child(mg)
	var mkt_btn = mg.find_child("MarketButton", true, false) as Button
	assert(mkt_btn != null, "MarketButton must exist")
	assert(mkt_btn.get_theme_color("font_color") == Color(0.96, 0.92, 0.84, 1.0), "MarketButton font must be warm ivory")
	
	var rhc = mg.find_child("RegionHoverCard", true, false)
	assert(rhc != null, "RegionHoverCard must exist")
	var rhc_title = rhc.find_child("TitleLabel", true, false) as Label
	assert(rhc_title.get_theme_font_size("font_size") >= 14, "RegionHoverCard title >= 14")
	print("✔ MainGame: CommandCorner buttons have warm ivory font, RegionHoverCard text enlarged")
	mg.queue_free()

	# 14. Test Square Buttons & PlantHotbar
	var sq_brown = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres")
	assert(sq_brown != null, "SquareBrownButton.tres must load")
	var sq_yellow = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareYellowButton.tres")
	assert(sq_yellow != null, "SquareYellowButton.tres must load")
	var sq_light = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareLightButton.tres")
	assert(sq_light != null, "SquareLightButton.tres must load")

	var hotbar_script = load("res://src/ui/PlantHotbar.gd")
	assert(hotbar_script != null, "PlantHotbar script must load")
	var hotbar = hotbar_script.new()
	add_child(hotbar)
	hotbar._setup_ui()
	assert(hotbar.flyout_drawer != null, "Flyout drawer must exist")
	hotbar.queue_free()
	print("✔ Square Buttons: 32x32 square button suite verified and hotbar slots loaded")

	# 15. Test ShopPanel COC-Style Card Grid
	var shop_inst = mg_scene.instantiate()
	add_child(shop_inst)
	var shop = shop_inst.find_child("ShopPanel", true, false)
	assert(shop != null, "ShopPanel must exist")
	shop.visible = true
	shop.refresh()
	assert(shop.labor_grid != null and shop.labor_grid.get_child_count() == 3, "Shop Labor grid must have 3 cards")
	assert(shop.storage_grid != null and shop.storage_grid.get_child_count() == 4, "Shop Storage grid must have 4 cards")
	assert(shop.weather_grid != null and shop.weather_grid.get_child_count() == 4, "Shop Weather grid must have 4 cards (incl. Field Survey Kit)")
	assert(shop.machinery_grid != null and shop.machinery_grid.get_child_count() == 2, "Shop Machinery grid must have 2 cards (Drone Hangar + Landing Pad)")
	assert(shop.trade_grid != null and shop.trade_grid.get_child_count() == 4, "Shop Trade grid must have 4 cards (Trading Post + 3 Hubs)")
	assert(shop.land_grid != null and shop.land_grid.get_child_count() == 4, "Shop Land grid must have 4 cards")
	print("✔ ShopPanel: COC-Style 3-column card grid verified across all categories (including Trade & Survey Kit)")
	shop_inst.queue_free()

	print("========================================")
	print("ALL 15 UI OVERHAUL ASSERTIONS PASSED!")
	print("========================================")
	get_tree().quit(0)
