extends Node

func _ready() -> void:
	print("--- BEGIN AUTOMATED TEST: FARMER VISUAL VARIANTS ---")

	var FarmerScript: GDScript = load("res://src/farmer/Farmer.gd")
	assert(FarmerScript != null, "Farmer.gd must load successfully")

	# 1. Constant assertions
	print("[Check 1] NUM_VARIANTS: ", FarmerScript.NUM_VARIANTS)
	assert(FarmerScript.NUM_VARIANTS == 8, "NUM_VARIANTS must be 8")
	assert(FarmerScript.VARIANT_NAMES.size() == 8, "VARIANT_NAMES size must be 8")
	assert(FarmerScript.VARIANT_DIRS.size() == 8, "VARIANT_DIRS size must be 8")

	# 2. Check frame integrity for every variant
	for v in range(FarmerScript.NUM_VARIANTS):
		var frames: Dictionary = FarmerScript.get_frames_for_variant(v)
		assert(frames.has("idle"), "Variant %d must have 'idle'" % v)
		assert(frames.has("walk"), "Variant %d must have 'walk'" % v)
		assert(frames.has("till"), "Variant %d must have 'till'" % v)
		assert(frames.has("harvest"), "Variant %d must have 'harvest'" % v)

		assert(frames["idle"].size() == 1, "Variant %d idle must have 1 frame" % v)
		assert(frames["walk"].size() == 4, "Variant %d walk must have 4 frames" % v)
		assert(frames["till"].size() == 4, "Variant %d till must have 4 frames" % v)
		assert(frames["harvest"].size() == 4, "Variant %d harvest must have 4 frames" % v)

		# Check all textures are valid
		for anim_key in ["idle", "walk", "till", "harvest"]:
			for f_idx in range(frames[anim_key].size()):
				var tex = frames[anim_key][f_idx]
				assert(tex != null, "Texture for variant %d anim %s[%d] must not be null" % [v, anim_key, f_idx])
				assert(tex is Texture2D, "Texture for variant %d anim %s[%d] must be Texture2D" % [v, anim_key, f_idx])
		print("  -> Variant %d (%s) frames verified OK" % [v, FarmerScript.VARIANT_NAMES[v]])

	# 3. Test instance creation and auto-assignment based on worker_id
	var farmers: Array = []
	for w_idx in range(1, 9):
		var f = CharacterBody2D.new()
		f.set_script(FarmerScript)
		f.name = "Farmer" if w_idx == 1 else "Farmer_%d" % w_idx
		var sp = Sprite2D.new()
		sp.name = "FarmerSprite"
		f.add_child(sp)
		var lb = Label.new()
		lb.name = "FarmerLabel"
		f.add_child(lb)
		add_child(f)
		farmers.append(f)

	await get_tree().process_frame

	for i in range(farmers.size()):
		var f = farmers[i]
		var expected_variant = i % FarmerScript.NUM_VARIANTS
		print("[Check 3.%d] %s: variant_id=%d (%s), expected=%d" % [
			i + 1, f.worker_name, f.variant_id, f.get_variant_name(), expected_variant
		])
		assert(f.variant_id == expected_variant, "%s must have variant_id %d" % [f.worker_name, expected_variant])
		assert(f.sprite.texture != null, "%s sprite texture must not be null" % f.worker_name)

	# 4. Test cycling and manual set_variant
	var worker1 = farmers[0]
	worker1.cycle_variant()
	assert(worker1.variant_id == 1, "worker1 cycle_variant must advance to variant 1")
	worker1.set_variant(5)
	assert(worker1.variant_id == 5, "worker1 set_variant(5) must set variant 5")
	assert(worker1.get_variant_name() == "Tropical Teal", "Variant 5 name must be Tropical Teal")

	# Test wrap-around
	worker1.set_variant(7)
	worker1.cycle_variant()
	assert(worker1.variant_id == 0, "worker1 cycle_variant from 7 must wrap around to 0")

	# 5. Test animation frame cycling with variant
	worker1.set_variant(3) # Indigo Violet
	worker1._play_anim("walk", 0.0)
	var expected_walk_0 = FarmerScript.get_frames_for_variant(3)["walk"][0]
	assert(worker1.sprite.texture == expected_walk_0, "Walking frame 0 must match variant 3 walk 0")

	worker1._play_anim("till", 0.0)
	var expected_till_0 = FarmerScript.get_frames_for_variant(3)["till"][0]
	assert(worker1.sprite.texture == expected_till_0, "Till frame 0 must match variant 3 till 0")

	worker1._play_anim("harvest", 0.0)
	var expected_harv_0 = FarmerScript.get_frames_for_variant(3)["harvest"][0]
	assert(worker1.sprite.texture == expected_harv_0, "Harvest frame 0 must match variant 3 harvest 0")

	# 6. Test Key C shortcut
	worker1.is_selected = true
	var key_ev = InputEventKey.new()
	key_ev.keycode = KEY_C
	key_ev.pressed = true
	worker1._unhandled_input(key_ev)
	assert(worker1.variant_id == 4, "Pressing C while selected must cycle variant to 4")

	# Cleanup test nodes
	for f in farmers:
		f.queue_free()

	print("--- ALL FARMER VISUAL VARIANT CHECKS PASSED (100%) ---")
	get_tree().quit(0)
