extends Node

func _ready() -> void:
	print("========================================")
	print("TESTING NEW ICONS INTEGRATION (Axe, Chem, Duck, Truck)")
	print("========================================")

	# 1. Texture Dimensions & Loading Check
	print("\n--- 1. Testing Texture Asset Loading & Dimensions ---")
	var icon_paths := {
		"Axe (Obstacle Clear)": "res://assets/icons/Tools/Axe.png",
		"Chem (Chemical Spray)": "res://assets/icons/Tools/Chem.png",
		"Duck (Biological IPM)": "res://assets/icons/Tools/duck.png",
		"Truck (Market Shipping)": "res://assets/icons/HUD/Truck.png"
	}

	for name_key in icon_paths:
		var path: String = icon_paths[name_key]
		assert(ResourceLoader.exists(path), "Texture file not found at: %s" % path)
		var tex: Texture2D = load(path)
		assert(tex != null, "Failed to load texture at: %s" % path)
		var sz: Vector2 = tex.get_size()
		print("✔ %s: %s (%dx%d px)" % [name_key, path, int(sz.x), int(sz.y)])
		assert(int(sz.x) == 32 and int(sz.y) == 32, "Texture %s must be 32x32, got %dx%d" % [path, int(sz.x), int(sz.y)])

	# 2. PlantHotbar TOOL_ICONS Mapping
	print("\n--- 2. Testing PlantHotbar TOOL_ICONS API ---")
	var PlantHotbarScript = preload("res://src/ui/PlantHotbar.gd")
	assert("clear" in PlantHotbarScript.TOOL_ICONS, "TOOL_ICONS missing 'clear'")
	assert("spray_chemical" in PlantHotbarScript.TOOL_ICONS, "TOOL_ICONS missing 'spray_chemical'")
	assert("spray_biological" in PlantHotbarScript.TOOL_ICONS, "TOOL_ICONS missing 'spray_biological'")

	var axe_tex = PlantHotbarScript.get_tool_sprite_texture("clear")
	assert(axe_tex != null and axe_tex.resource_path == "res://assets/icons/Tools/Axe.png", "get_tool_sprite_texture('clear') must return Axe.png")
	var chem_tex = PlantHotbarScript.get_tool_sprite_texture("spray_chemical")
	assert(chem_tex != null and chem_tex.resource_path == "res://assets/icons/Tools/Chem.png", "get_tool_sprite_texture('spray_chemical') must return Chem.png")
	var duck_tex = PlantHotbarScript.get_tool_sprite_texture("spray_biological")
	assert(duck_tex != null and duck_tex.resource_path == "res://assets/icons/Tools/duck.png", "get_tool_sprite_texture('spray_biological') must return duck.png")
	print("✔ PlantHotbar TOOL_ICONS correctly maps clear, spray_chemical, and spray_biological")

	# 3. PlantHotbar Runtime Node Inspection
	print("\n--- 3. Testing Hotbar Slot Display, Flyout Drawer & Hover Card ---")
	var hotbar = PlantHotbarScript.new()
	add_child(hotbar)

	# Verify Category Slots Display
	# Tools with "clear" active
	hotbar.selected_category_items["tools"] = "clear"
	hotbar._update_category_slots_display()
	var tools_icon_box = hotbar.category_icons.get("tools", null)
	assert(tools_icon_box != null, "Tools IconContainer not found")
	var tools_tr = tools_icon_box.get_children().back() as TextureRect
	assert(tools_tr != null and tools_tr.texture != null, "Tools slot must display TextureRect")
	assert(tools_tr.texture.resource_path == "res://assets/icons/Tools/Axe.png", "Tools slot must render Axe.png for 'clear', got: %s" % (tools_tr.texture.resource_path if tools_tr.texture else "null"))
	print("✔ Category slot 'tools' (clear) renders Axe.png TextureRect")

	# Treatments with "spray_chemical" active
	hotbar.selected_category_items["treatments"] = "spray_chemical"
	hotbar._update_category_slots_display()
	var treat_icon_box = hotbar.category_icons.get("treatments", null)
	assert(treat_icon_box != null, "Treatments IconContainer not found")
	var treat_tr = treat_icon_box.get_children().back() as TextureRect
	assert(treat_tr != null and treat_tr.texture != null, "Treatments slot must display TextureRect")
	assert(treat_tr.texture.resource_path == "res://assets/icons/Tools/Chem.png", "Treatments slot must render Chem.png for 'spray_chemical', got: %s" % (treat_tr.texture.resource_path if treat_tr.texture else "null"))
	print("✔ Category slot 'treatments' (spray_chemical) renders Chem.png TextureRect")

	# Treatments with "spray_biological" active
	hotbar.selected_category_items["treatments"] = "spray_biological"
	hotbar._update_category_slots_display()
	treat_icon_box = hotbar.category_icons.get("treatments", null)
	treat_tr = treat_icon_box.get_children().back() as TextureRect
	assert(treat_tr != null and treat_tr.texture != null, "Treatments slot must display TextureRect")
	assert(treat_tr.texture.resource_path == "res://assets/icons/Tools/duck.png", "Treatments slot must render duck.png for 'spray_biological', got: %s" % (treat_tr.texture.resource_path if treat_tr.texture else "null"))
	print("✔ Category slot 'treatments' (spray_biological) renders duck.png TextureRect")

	# Flyout Drawer for treatments
	hotbar._open_flyout_for_category("treatments")
	assert(hotbar.flyout_item_buttons.has("spray_chemical"), "Flyout drawer missing spray_chemical button")
	assert(hotbar.flyout_item_buttons.has("spray_biological"), "Flyout drawer missing spray_biological button")
	var chem_btn = hotbar.flyout_item_buttons["spray_chemical"]
	var chem_btn_tr = chem_btn.find_child("CenterContainer", true, false).get_child(0) as TextureRect
	assert(chem_btn_tr != null and chem_btn_tr.texture != null and chem_btn_tr.texture.resource_path == "res://assets/icons/Tools/Chem.png", "Flyout button for spray_chemical must have Chem.png TextureRect")
	var duck_btn = hotbar.flyout_item_buttons["spray_biological"]
	var duck_btn_tr = duck_btn.find_child("CenterContainer", true, false).get_child(0) as TextureRect
	assert(duck_btn_tr != null and duck_btn_tr.texture != null and duck_btn_tr.texture.resource_path == "res://assets/icons/Tools/duck.png", "Flyout button for spray_biological must have duck.png TextureRect")
	print("✔ Flyout drawer for treatments correctly renders Chem.png and duck.png buttons")

	# Hover Card for tools and treatments
	hotbar._populate_hover_card("clear")
	assert(hotbar.card_texture.visible == true, "card_texture must be visible for 'clear'")
	assert(hotbar.card_icon.visible == false, "card_icon must be hidden when card_texture is active")
	assert(hotbar.card_texture.texture.resource_path == "res://assets/icons/Tools/Axe.png", "card_texture must be Axe.png for 'clear'")

	hotbar._populate_hover_card("spray_biological")
	assert(hotbar.card_texture.visible == true, "card_texture must be visible for 'spray_biological'")
	assert(hotbar.card_texture.texture.resource_path == "res://assets/icons/Tools/duck.png", "card_texture must be duck.png for 'spray_biological'")
	print("✔ Tool/treatment hover cards render crisp sprite textures instead of plain emojis")

	# 4. MainGame CommandCorner SellButton Inspection
	print("\n--- 4. Testing MainGame CommandCorner SellButton Icon ---")
	var main_scene = load("res://scenes/MainGame.tscn").instantiate()
	add_child(main_scene)

	var sell_btn: Button = main_scene.find_child("SellButton", true, false)
	assert(sell_btn != null, "SellButton not found in MainGame scene")
	assert(sell_btn.icon != null, "SellButton icon must not be null")
	print("SellButton icon resource path: %s" % sell_btn.icon.resource_path)
	assert(sell_btn.icon.resource_path == "res://assets/icons/HUD/Truck.png", "SellButton icon must be Truck.png")
	print("✔ CommandCorner SellButton icon is successfully updated to Truck.png (res://assets/icons/HUD/Truck.png)")

	print("\n========================================")
	print("ALL NEW ICON INTEGRATION TESTS PASSED 100%!")
	print("========================================")
	get_tree().quit(0)
