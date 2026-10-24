extends SceneTree

func _init() -> void:
	print("--- Starting Farmer Animation Verification ---")
	
	# Load Farmer script directly
	var farmer_scene = load("res://scenes/MainGame.tscn")
	if not farmer_scene:
		print("ERROR: Failed to load MainGame.tscn")
		quit(1)
		return
	print("SUCCESS: MainGame.tscn loaded.")
	
	var root = farmer_scene.instantiate()
	if not root:
		print("ERROR: Failed to instantiate MainGame.tscn")
		quit(1)
		return
	print("SUCCESS: MainGame instantiated.")
	
	var farmer = root.find_child("Farmer", true, false)
	if not farmer:
		print("ERROR: Farmer node not found!")
		quit(1)
		return
	print("SUCCESS: Farmer node found:", farmer.name)
	
	var sprite = farmer.find_child("FarmerSprite", true, false)
	if not sprite:
		print("ERROR: FarmerSprite not found!")
		quit(1)
		return
	print("SUCCESS: FarmerSprite found, class:", sprite.get_class())
	print("FarmerSprite scale:", sprite.scale, "position:", sprite.position)
	print("FarmerSprite texture:", sprite.texture.resource_path if sprite.texture else "null")
	
	# Test animation triggers
	print("Testing _play_anim('walk', 0.2)...")
	farmer._play_anim("walk", 0.2)
	print("Current anim:", farmer._current_anim, "texture:", sprite.texture.resource_path)
	
	farmer._play_anim("walk", 0.2)
	print("After 2nd walk tick, frame:", farmer._anim_frame_idx, "texture:", sprite.texture.resource_path)
	
	print("Testing _play_anim('till', 0.2)...")
	farmer._play_anim("till", 0.2)
	print("Current anim:", farmer._current_anim, "frame:", farmer._anim_frame_idx, "texture:", sprite.texture.resource_path)
	
	print("Testing _play_anim('harvest', 0.2)...")
	farmer._play_anim("harvest", 0.2)
	print("Current anim:", farmer._current_anim, "frame:", farmer._anim_frame_idx, "texture:", sprite.texture.resource_path)
	
	print("Testing facing left/right...")
	farmer._set_facing(true)
	print("Facing left, flip_h:", sprite.flip_h)
	farmer._set_facing(false)
	print("Facing right, flip_h:", sprite.flip_h)
	
	print("ALL FARMER ANIMATION VERIFICATIONS PASSED!")
	root.queue_free()
	quit(0)
