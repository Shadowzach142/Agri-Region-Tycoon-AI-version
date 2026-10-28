# test_unique_regional_environments.gd
extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("🧪 VERIFYING UNIQUE REGIONAL MAPS, MONUMENTS & WATER SYSTEMS")
	print("==================================================================")

	var data_script = preload("res://autoload/Data.gd")
	var data_node = data_script.new()
	data_node.name = "Data"
	root.add_child(data_node)

	var regions: Array[String] = ["cotabato", "south_cotabato", "sarangani", "sultan_kudarat", "general_santos"]
	var total_errors: int = 0

	for reg in regions:
		print("\n--- Testing Region: %s ---" % reg)
		data_node.current_region = reg

		# 1. Verify Data.gd settings
		var reg_data: Dictionary = data_node.REGIONS.get(reg, {})
		if not reg_data.get("has_coast", false):
			print("❌ Error: Region %s does not have has_coast=true!" % reg)
			total_errors += 1
		else:
			print("✅ Data.REGIONS[%s] has water boundary: %s" % [reg, reg_data.get("water_body", "Yes")])

		# 2. Verify Map Scene loading and instantiation
		var map_path: String = data_node.get_region_map_path(reg)
		if not ResourceLoader.exists(map_path):
			print("❌ Error: Map scene %s not found!" % map_path)
			total_errors += 1
			continue

		var map_scene = load(map_path) as PackedScene
		if not map_scene:
			print("❌ Error: Failed to load map scene %s!" % map_path)
			total_errors += 1
			continue

		var map_inst = map_scene.instantiate()
		root.add_child(map_inst)

		# Wait one frame for _ready
		# 3. Check props layer: MUST BE ZERO PROPS
		var props_layer: Node2D = map_inst.get_node_or_null("PropsLayer")
		if props_layer:
			var prop_count := props_layer.get_child_count()
			if prop_count > 0:
				print("❌ Error: Region %s has %d props! Directives require ZERO decorative props!" % [reg, prop_count])
				total_errors += 1
			else:
				print("✅ Region %s has 0 decorative props (clean presentation)." % reg)
		else:
			print("⚠️ Note: PropsLayer not found on %s" % reg)

		# 4. Check monuments layer: MUST HAVE REGIONAL MONUMENT(S)
		var mon_layer: Node2D = map_inst.get_node_or_null("MonumentsLayer")
		if not mon_layer:
			print("❌ Error: MonumentsLayer missing in %s!" % reg)
			total_errors += 1
		else:
			var mon_count := mon_layer.get_child_count()
			var expected_mon_count := 2 if reg == "south_cotabato" else 1
			if mon_count != expected_mon_count:
				print("❌ Error: Region %s expected %d monuments, got %d!" % [reg, expected_mon_count, mon_count])
				total_errors += 1
			else:
				print("✅ Region %s has correct %d monument(s):" % [reg, mon_count])
				for child in mon_layer.get_children():
					print("   - %s (%s, texture: %s)" % [child.name, child.monument_title, child.monument_texture != null])

		# 5. Check Water node
		var water_node: Node2D = map_inst.get_node_or_null("SeaWater")
		if not water_node:
			print("❌ Error: Eastern water node missing in %s!" % reg)
			total_errors += 1
		else:
			print("✅ Region %s has eastern water node present (COAST_X=%s)." % [reg, water_node.COAST_X])

		# 6. Check Forest & Terrain & Stream
		var forest_node: Node2D = map_inst.get_node_or_null("OutOfBoundsForest")
		if not forest_node:
			print("❌ Error: OutOfBoundsForest missing in %s!" % reg)
			total_errors += 1
		else:
			var terrain_node: Node2D = forest_node.get_node_or_null("OutOfBoundsTerrain")
			var trail_node: Node2D = forest_node.get_node_or_null("OutOfBoundsDirtTrail")
			var stream_node: Node2D = terrain_node.get_node_or_null("RegionalStreamCanvas") if terrain_node else null
			if terrain_node and trail_node and stream_node:
				print("✅ Region %s has OutOfBoundsTerrain, OutOfBoundsDirtTrail, and RegionalStreamOverlay." % reg)
			else:
				print("❌ Error in sub-nodes for %s (terrain: %s, trail: %s, stream: %s)" % [reg, terrain_node != null, trail_node != null, stream_node != null])
				total_errors += 1

		# 7. Check Sultan Kudarat Monument specifics
		if reg == "sultan_kudarat":
			var sk_mon = mon_layer.get_node_or_null("Monument_sultan_kudarat_statue")
			if sk_mon and sk_mon.monument_texture:
				var t_sz = sk_mon.monument_texture.get_size()
				if t_sz == Vector2(72, 96):
					print("✅ Sultan Kudarat Monument has verified 72x96 reworked sprite.")
				else:
					print("⚠️ Sultan Kudarat Monument sprite size: %s" % t_sz)

		# Clean up
		map_inst.queue_free()

	print("\n==================================================================")
	if total_errors == 0:
		print("🎉 ALL 5 REGIONS VERIFIED SUCCESSFULLY! 0 ERRORS!")
	else:
		print("❌ TEST FAILED WITH %d ERRORS!" % total_errors)
	print("==================================================================")

	quit(0 if total_errors == 0 else 1)

