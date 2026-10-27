# capture_sandbox.gd
extends Node2D

func _ready() -> void:
	var menu_scene = load("res://scenes/MainMenu.tscn")
	var menu = menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	# Select sandbox mode
	menu._select_mode_carousel(2)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var img_menu = get_viewport().get_texture().get_image()
	img_menu.save_png("res://scratch/sandbox_menu.png")
	print("✔ Saved res://scratch/sandbox_menu.png")

	menu._select_game_mode("sandbox")
	await get_tree().process_frame
	await get_tree().process_frame

	var img_region = get_viewport().get_texture().get_image()
	img_region.save_png("res://scratch/sandbox_region.png")
	print("✔ Saved res://scratch/sandbox_region.png")

	menu.queue_free()
	await get_tree().process_frame

	# Launch MainGame in sandbox
	Data.game_mode = "sandbox"
	Data.current_region = "cotabato"
	var game_scene = load("res://scenes/MainGame.tscn")
	var game = game_scene.instantiate()
	add_child(game)
	for i in range(10):
		await get_tree().process_frame

	var img_game = get_viewport().get_texture().get_image()
	img_game.save_png("res://scratch/sandbox_gameplay.png")
	print("✔ Saved res://scratch/sandbox_gameplay.png")

	get_tree().quit(0)
