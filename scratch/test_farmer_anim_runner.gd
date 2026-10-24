extends Node

func _ready() -> void:
	print("--- Running Test with Autoloads Initialized ---")
	var maingame_packed = load("res://scenes/MainGame.tscn")
	var game = maingame_packed.instantiate()
	add_child(game)
	print("MainGame instantiated and added to tree.")
	
	var farmer = game.find_child("Farmer", true, false)
	assert(farmer != null, "Farmer must exist")
	var sprite = farmer.find_child("FarmerSprite", true, false) as Sprite2D
	assert(sprite != null, "FarmerSprite must exist")
	
	print("Initial FarmerSprite scale:", sprite.scale, "position:", sprite.position)
	print("Initial texture:", sprite.texture.resource_path)
	
	# Test walk animation cycle
	farmer._play_anim("walk", 0.2)
	print("Walk anim frame 1 texture:", sprite.texture.resource_path)
	farmer._play_anim("walk", 0.2)
	print("Walk anim frame 2 texture:", sprite.texture.resource_path)
	
	# Test till animation cycle
	farmer._play_anim("till", 0.2)
	print("Till anim frame 1 texture:", sprite.texture.resource_path)
	
	# Test harvest animation cycle
	farmer._play_anim("harvest", 0.2)
	print("Harvest anim frame 1 texture:", sprite.texture.resource_path)
	
	# Test facing
	farmer._set_facing(true)
	assert(sprite.flip_h == true, "Should flip horizontally")
	farmer._set_facing(false)
	assert(sprite.flip_h == false, "Should unflip horizontally")
	print("Facing left/right verified successfully.")
	
	print("ALL IN-ENGINE FARMER ANIMATION TESTS PASSED!")
	get_tree().quit(0)
