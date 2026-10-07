@tool
extends SceneTree

func _init() -> void:
	var crops = {
		"palay": {"folder": "Rice", "prefix": "RICE-P", "max": 5},
		"yellow_corn": {"folder": "Corn", "prefix": "CORN-P", "max": 5},
		"sugarcane": {"folder": "Sugarcane", "prefix": "SUGARCANE-P", "max": 5},
		"pineapple": {"folder": "Pineapple", "prefix": "PINEAPPLE-P", "max": 5},
		"arabica_coffee": {"folder": "Coffee", "prefix": "COFFEE-P", "max": 5},
		"banana": {"folder": "Banana", "prefix": "BANANA-P", "max": 6},
		"coconut": {"folder": "Coconut", "prefix": "COCONUT-P", "max": 5}
	}
	
	var total_loaded = 0
	var total_expected = 0
	for crop_key in crops:
		var info = crops[crop_key]
		for s in range(1, info["max"] + 1):
			total_expected += 1
			var path = "res://assets/sprites/Field/Crops/%s/%s%d.png" % [info["folder"], info["prefix"], s]
			if not ResourceLoader.exists(path):
				print("MISSING: ", path)
				quit(1)
				return
			var tex = load(path) as Texture2D
			if not tex:
				print("FAILED TO LOAD: ", path)
				quit(1)
				return
			total_loaded += 1
			print("OK: %s (Stage %d) -> %dx%d" % [crop_key, s, tex.get_width(), tex.get_height()])
			
	print("SUCCESS: All %d/%d crop stage textures loaded perfectly!" % [total_loaded, total_expected])
	quit(0)
