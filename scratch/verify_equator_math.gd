@tool
extends SceneTree

func _init() -> void:
	# Bare1.png in GroundSprite
	var bare_offset_y := -2.0 * 4.0 # -8 screen px
	var bare_equator := 18.0
	var bare_img_center := 16.0
	var bare_screen_equator := (bare_equator - bare_img_center) * 4.0 + bare_offset_y
	print("Bare1 screen equator: ", bare_screen_equator) # Should be 0.0

	# RICE-P1 in CropSprite with old formula (14.0 - 16.0 = -2.0)
	var old_crop_offset_y := (14.0 - 16.0) * 4.0 # -8 screen px
	var rice_equator := 20.0
	var rice_img_center := 16.0
	var old_rice_screen_equator := (rice_equator - rice_img_center) * 4.0 + old_crop_offset_y
	print("OLD Rice screen equator: ", old_rice_screen_equator) # Was +8.0 (8 px too low!)

	# RICE-P1 with new formula (12.0 - 16.0 = -4.0)
	var new_crop_offset_y := (12.0 - 16.0) * 4.0 # -16 screen px
	var new_rice_screen_equator := (rice_equator - rice_img_center) * 4.0 + new_crop_offset_y
	print("NEW Rice screen equator: ", new_rice_screen_equator) # Is 0.0 (PERFECT!)

	# 64-high crop (RICE-P3, CORN-P3, SUGARCANE-P3)
	var tall_equator := 52.0
	var tall_img_center := 32.0
	var new_tall_offset_y := (12.0 - 32.0) * 4.0 # -80 screen px
	var new_tall_screen_equator := (tall_equator - tall_img_center) * 4.0 + new_tall_offset_y
	print("NEW Tall 64h crop screen equator: ", new_tall_screen_equator) # Is 0.0 (PERFECT!)

	quit(0)
