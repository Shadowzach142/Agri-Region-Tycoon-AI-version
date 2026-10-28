# test_parse_regional_scripts.gd
# Headless GDScript parse-check. Loads all regional scripts and verifies they compile.
# Does NOT instantiate scene nodes (avoids _ready() timing issues).
extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("🔍 PARSE & COMPILE CHECK — Unique Regional Environments")
	print("==================================================================")

	var errors: int = 0
	var scripts_to_check: Array[String] = [
		"res://src/world/SeaWater.gd",
		"res://src/world/OutOfBoundsTerrain.gd",
		"res://src/world/OutOfBoundsDirtTrail.gd",
		"res://src/world/OutOfBoundsForest.gd",
		"res://src/world/RegionalStreamOverlay.gd",
		"res://src/world/RegionalMapBase.gd",
		"res://src/world/maps/Map_Cotabato.gd",
		"res://src/world/maps/Map_SouthCotabato.gd",
		"res://src/world/maps/Map_Sarangani.gd",
		"res://src/world/maps/Map_SultanKudarat.gd",
		"res://src/world/maps/Map_GeneralSantos.gd",
		"res://src/world/RegionalMonument.gd",
		"res://src/world/RegionalProp.gd",
		"res://src/ui/TrailerModal.gd",
	]

	for path in scripts_to_check:
		if not ResourceLoader.exists(path):
			print("❌ MISSING: %s" % path)
			errors += 1
			continue
		var s = load(path)
		if s == null:
			print("❌ COMPILE ERROR: %s" % path)
			errors += 1
		else:
			print("✅ OK: %s" % path)

	# Check map scene files
	var scenes_to_check: Array[String] = [
		"res://scenes/maps/Map_Cotabato.tscn",
		"res://scenes/maps/Map_SouthCotabato.tscn",
		"res://scenes/maps/Map_Sarangani.tscn",
		"res://scenes/maps/Map_SultanKudarat.tscn",
		"res://scenes/maps/Map_GeneralSantos.tscn",
	]
	print("")
	print("--- Checking Scene Files ---")
	for path in scenes_to_check:
		if not ResourceLoader.exists(path):
			print("❌ MISSING SCENE: %s" % path)
			errors += 1
		else:
			print("✅ SCENE OK: %s" % path)

	# Check monument texture files
	print("")
	print("--- Checking Monument Textures ---")
	var monuments: Array[String] = [
		"res://assets/sprites/monuments/bangkapayapaan_monument.png",
		"res://assets/sprites/monuments/bangkapayapaan_monument_FLIPPED.png",
		"res://assets/sprites/monuments/surallah_tri_people_monument.png",
		"res://assets/sprites/monuments/surallah_tri_people_monument_FLIPPED.png",
		"res://assets/sprites/monuments/T_boli_Knoon_Monument.png",
		"res://assets/sprites/monuments/T_boli_Knoon_Monument_FLIPPED.png",
		"res://assets/sprites/monuments/maitum_anthropomorphic_replicas.png",
		"res://assets/sprites/monuments/maitum_anthropomorphic_replicas_FLIPPED.png",
		"res://assets/sprites/monuments/Sultan_Kudarat_Monument.png",
		"res://assets/sprites/monuments/Sultan_Kudarat_Monument_FLIPPED.png",
		"res://assets/sprites/monuments/gen_paulino_santos_monument.png",
		"res://assets/sprites/monuments/gen_paulino_santos_monument_FLIPPED.png",
	]
	for path in monuments:
		if not ResourceLoader.exists(path):
			print("❌ MISSING TEXTURE: %s" % path)
			errors += 1
		else:
			print("✅ TEXTURE OK: %s" % path.get_file())

	# Verify Data.gd has_coast = true for all 5 regions
	print("")
	print("--- Checking Data.gd has_coast = true for all regions ---")
	var data_script = load("res://autoload/Data.gd")
	if data_script:
		var data_node = data_script.new()
		root.add_child(data_node)
		var regions_to_check: Array[String] = ["cotabato", "south_cotabato", "sarangani", "sultan_kudarat", "general_santos"]
		for reg in regions_to_check:
			var reg_data: Dictionary = data_node.REGIONS.get(reg, {})
			var has_coast: bool = reg_data.get("has_coast", false)
			var water_body: String = reg_data.get("water_body", "MISSING")
			if not has_coast:
				print("❌ Region %s has_coast=false — all regions MUST have water!" % reg)
				errors += 1
			elif water_body == "MISSING":
				print("⚠️  Region %s has_coast=true but no water_body label!" % reg)
			else:
				print("✅ %s: has_coast=true, water_body='%s'" % [reg, water_body])
		data_node.queue_free()
	else:
		print("❌ Could not load Data.gd!")
		errors += 1

	print("")
	print("==================================================================")
	if errors == 0:
		print("🎉 ALL CHECKS PASSED! (%d scripts, %d scenes, %d textures)" % [scripts_to_check.size(), scenes_to_check.size(), monuments.size()])
	else:
		print("❌ %d ERROR(S) FOUND — fix before running!" % errors)
	print("==================================================================")
	quit(0 if errors == 0 else 1)

