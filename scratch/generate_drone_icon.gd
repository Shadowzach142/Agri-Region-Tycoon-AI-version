extends Node

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(32, 32)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var drawer := DroneDrawNode.new()
	vp.add_child(drawer)

	await get_tree().process_frame
	await get_tree().process_frame

	var img: Image = vp.get_texture().get_image()
	var path: String = "res://assets/icons/HUD/Drone.png"
	var global_path: String = ProjectSettings.globalize_path(path)
	img.save_png(global_path)
	print("✔ Saved 32x32 Drone icon to: %s" % global_path)
	get_tree().quit(0)

class DroneDrawNode extends Node2D:
	func _draw() -> void:
		# Draw drone art centered at (16, 17) with scale 1.0, level 2, rotor phase 0.7
		FarmDrone.draw_drone_art(self, Vector2(16.0, 17.0), 1.0, 2, 0.7, 0.0)
