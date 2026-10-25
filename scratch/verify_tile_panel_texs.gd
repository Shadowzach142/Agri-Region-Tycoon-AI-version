@tool
extends SceneTree

func _init():
	var paths = [
		"res://assets/sprites/ground/BARE SOIL/BARE-SOIL-01.png",
		"res://assets/sprites/ground/NGRASS/NGRASS-01.png",
		"res://assets/sprites/ground/WGRASS/WGRASS-01.png",
		"res://assets/sprites/ground/BARE SOIL/DROUGHT-SOIL-O1.png",
		"res://assets/sprites/buildings/KUBO.png",
		"res://assets/sprites/buildings/DRYER-BARE.PNG",
		"res://assets/sprites/buildings/Cold_Storage.png",
		"res://assets/sprites/buildings/Drone_Station.png",
		"res://assets/sprites/buildings/Water_Station.png",
		"res://assets/sprites/buildings/Weather_Station.png",
		"res://assets/sprites/buildings/Silo/SILO-0.PNG"
	]
	for p in paths:
		assert(ResourceLoader.exists(p), "Path should exist: " + p)
		var t = load(p)
		assert(t != null, "Texture should load: " + p)
		print("Loaded: ", p)
	print("ALL TEXTURES VERIFIED!")
	quit(0)
