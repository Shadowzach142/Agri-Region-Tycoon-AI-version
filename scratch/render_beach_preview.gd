extends SceneTree

func _init() -> void:
	print("=== Simulating Beach Grid Visuals ===")
	var gts := GroundTileSprites.new()
	
	# Load sand textures
	var dry_sands = [
		Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/ground/SAND/Sand-01.png")),
		Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/ground/SAND/Sand-02.png")),
		Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/ground/SAND/Sand-03.png"))
	]
	var wet_sands = [
		Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/ground/SAND/WSand-01.png")),
		Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/ground/SAND/WSand-02.png")),
		Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/ground/SAND/WSand-03.png"))
	]
	var grass = Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/ground/NGRASS/NGRASS-01.png"))
	
	# Check count of beach tiles
	var beach_count := 0
	for y in range(24):
		for x in range(24):
			var pos := Vector2i(x, y)
			if _is_beach(pos):
				beach_count += 1
				
	print("Total beach tiles along the eastern coast: %d tiles (out of 576)" % beach_count)
	
	# Create isometric preview image of the eastern coast (x=20..23, y=0..12)
	# Each 32x32 tile diamond is 32 wide, 16 high in local diamond coordinates
	# Let's save a visual sample to scratch/beach_strip_preview.png
	quit(0)

func _is_beach(pos: Vector2i) -> bool:
	if pos.x == 23:
		return true
	if pos.x == 22:
		var wave: int = (pos.y * 7 + 3) % 11
		return wave < 7
	return false
