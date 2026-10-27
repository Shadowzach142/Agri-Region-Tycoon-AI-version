extends Node

func _ready() -> void:
	print("--- Testing Obstacle and Tile Overlay Sprite Loading ---")
	
	var obs_paths = [
		"res://assets/sprites/obstacles/OBSTACLE_Old-Tree-Stump..png",
		"res://assets/sprites/obstacles/OBSTACLE_Boulder-Oval.png",
		"res://assets/sprites/obstacles/OBSTACLE_Boulder-kinda-round..png",
		"res://assets/sprites/obstacles/OBSTACLE_Boulder-Trio.png"
	]
	
	for path in obs_paths:
		assert(ResourceLoader.exists(path), "File must exist: " + path)
		var tex = load(path) as Texture2D
		assert(tex != null, "Failed to load texture: " + path)
		print("Loaded obstacle: %s (size: %s)" % [path.get_file(), str(tex.get_size())])
		
	var overlay_paths = [
		"res://assets/sprites/TILE OVERLAYS/TO-ARMY-WORM.png",
		"res://assets/sprites/TILE OVERLAYS/TO-KUHOL-SNAIL.png",
		"res://assets/sprites/TILE OVERLAYS/TO-RICE-BLACKBUG.png",
		"res://assets/sprites/TILE OVERLAYS/TO-Wilt-Spores.png"
	]
	
	for path in overlay_paths:
		assert(ResourceLoader.exists(path), "File must exist: " + path)
		var tex = load(path) as Texture2D
		assert(tex != null, "Failed to load texture: " + path)
		print("Loaded overlay: %s (size: %s)" % [path.get_file(), str(tex.get_size())])
		
	print("All 8 textures loaded successfully!")
	get_tree().quit(0)
