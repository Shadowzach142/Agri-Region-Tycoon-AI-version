p = r'c:\Users\ADMIN\Documents\agri-region-ai-version\src\buildings\Building.gd'
with open(p, 'r', encoding='utf-8') as f:
    txt = f.read()

# 1. Add TEX_CLIMATE_SILO preloads
old1 = '''const TEX_SILO_100: Texture2D        = preload("res://assets/sprites/buildings/Silo/SILO-100.PNG")
const TEX_SILO_100_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Silo/SILO-100_FLIPPED.PNG")'''

new1 = old1 + '''

const TEX_CLIMATE_SILO_0: Texture2D          = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-0.PNG")
const TEX_CLIMATE_SILO_0_FLIPPED: Texture2D  = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-0_FLIPPED.PNG")
const TEX_CLIMATE_SILO_25: Texture2D         = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-25.PNG")
const TEX_CLIMATE_SILO_25_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-25_FLIPPED.PNG")
const TEX_CLIMATE_SILO_50: Texture2D         = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-50.PNG")
const TEX_CLIMATE_SILO_50_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-50_FLIPPED.PNG")
const TEX_CLIMATE_SILO_75: Texture2D         = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-75.PNG")
const TEX_CLIMATE_SILO_75_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-75_FLIPPED.PNG")
const TEX_CLIMATE_SILO_100: Texture2D        = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-100.PNG")
const TEX_CLIMATE_SILO_100_FLIPPED: Texture2D = preload("res://assets/sprites/buildings/Silo/CLIMATE-SILO-100_FLIPPED.PNG")'''
assert old1 in txt, 'old1 not found'
txt = txt.replace(old1, new1, 1)

# 2. Separate bodega and climate_silo in get_placement_preview
old2 = '''\t\t"bodega", "climate_silo":
\t\t\treturn {
\t\t\t\t"texture": TEX_SILO_100_FLIPPED if flipped else TEX_SILO_100,
\t\t\t\t"scale": 2.5,
\t\t\t\t"center_offset": Vector2(24.0, 47.2)
\t\t\t}'''
new2 = '''\t\t"bodega":
\t\t\treturn {
\t\t\t\t"texture": TEX_SILO_100_FLIPPED if flipped else TEX_SILO_100,
\t\t\t\t"scale": 2.5,
\t\t\t\t"center_offset": Vector2(24.0, 47.2)
\t\t\t}
\t\t"climate_silo":
\t\t\treturn {
\t\t\t\t"texture": TEX_CLIMATE_SILO_100_FLIPPED if flipped else TEX_CLIMATE_SILO_100,
\t\t\t\t"scale": 2.5,
\t\t\t\t"center_offset": Vector2(24.0, 47.2)
\t\t\t}'''
assert old2 in txt, 'old2 not found'
txt = txt.replace(old2, new2, 1)

# 3. Add _get_climate_silo_texture()
old3 = '''\t\telse:
\t\t\treturn TEX_SILO_100

func _ready() -> void:'''
new3 = '''\t\telse:
\t\t\treturn TEX_SILO_100

func _get_climate_silo_texture() -> Texture2D:
\tvar ratio: float = 0.0
\tvar cap: int = get_storage_capacity()
\tif cap > 0:
\t\tratio = clampf(float(used_storage) / float(cap), 0.0, 1.0)
\telif BuildingManager.total_storage_capacity > 0:
\t\tratio = clampf(float(BuildingManager.used_storage) / float(BuildingManager.total_storage_capacity), 0.0, 1.0)
\tif is_flipped:
\t\tif ratio < 0.125:
\t\t\treturn TEX_CLIMATE_SILO_0_FLIPPED
\t\telif ratio < 0.375:
\t\t\treturn TEX_CLIMATE_SILO_25_FLIPPED
\t\telif ratio < 0.625:
\t\t\treturn TEX_CLIMATE_SILO_50_FLIPPED
\t\telif ratio < 0.875:
\t\t\treturn TEX_CLIMATE_SILO_75_FLIPPED
\t\telse:
\t\t\treturn TEX_CLIMATE_SILO_100_FLIPPED
\telse:
\t\tif ratio < 0.125:
\t\t\treturn TEX_CLIMATE_SILO_0
\t\telif ratio < 0.375:
\t\t\treturn TEX_CLIMATE_SILO_25
\t\telif ratio < 0.625:
\t\t\treturn TEX_CLIMATE_SILO_50
\t\telif ratio < 0.875:
\t\t\treturn TEX_CLIMATE_SILO_75
\t\telse:
\t\t\treturn TEX_CLIMATE_SILO_100

func _ready() -> void:'''
assert old3 in txt, 'old3 not found'
txt = txt.replace(old3, new3, 1)

# 4. Update _update_art_sprite_state()
old4 = '''func _update_art_sprite_state() -> void:
\tif art_sprite and is_instance_valid(art_sprite):
\t\tif building_type == "bodega" or building_type == "climate_silo":
\t\t\tart_sprite.texture = _get_silo_texture()
\t\tif state == BuildingState.CONSTRUCTING or state == BuildingState.UPGRADING:
\t\t\tif building_type == "climate_silo":
\t\t\t\tart_sprite.modulate = Color(0.85, 0.95, 1.15, 0.45)
\t\t\telse:
\t\t\t\tart_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
\t\telse:
\t\t\tif building_type == "climate_silo":
\t\t\t\tart_sprite.modulate = Color(0.85, 0.95, 1.15, 1.0)
\t\t\telse:
\t\t\t\tart_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)'''
new4 = '''func _update_art_sprite_state() -> void:
\tif art_sprite and is_instance_valid(art_sprite):
\t\tif building_type == "bodega":
\t\t\tart_sprite.texture = _get_silo_texture()
\t\telif building_type == "climate_silo":
\t\t\tart_sprite.texture = _get_climate_silo_texture()
\t\tif state == BuildingState.CONSTRUCTING or state == BuildingState.UPGRADING:
\t\t\tart_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
\t\telse:
\t\t\tart_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)'''
assert old4 in txt, 'old4 not found'
txt = txt.replace(old4, new4, 1)

# 5. Exclude climate_silo from foundation slab
old5 = 'building_type != "bodega" and building_type != "bahay_kubo"'
new5 = 'building_type != "bodega" and building_type != "climate_silo" and building_type != "bahay_kubo"'
assert old5 in txt, 'old5 not found'
txt = txt.replace(old5, new5, 1)

# 6. Update _draw_silo() to draw the pixel-art Climate-Controlled Silo sprite
old6 = '''func _draw_silo(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
\tvar silo_w: float = 46.0
\tvar silo_h: float = 75.0'''
new6 = '''func _draw_silo(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
\tvar tex := _get_climate_silo_texture()
\tif tex != null:
\t\t# Pixel-art Climate-Controlled Silo sprite (48x64 at 2.5x scale = 120x160)
\t\tvar silo_w_px: float = float(tex.get_width()) * 2.5
\t\tvar silo_h_px: float = float(tex.get_height()) * 2.5
\t\tvar silo_rect := Rect2(-silo_w_px * 0.5, -118.0, silo_w_px, silo_h_px)
\t\tdraw_texture_rect(tex, silo_rect, false)

\t\t# Night cryo-thermostat & work light glow
\t\tvar fs: float = -1.0 if is_flipped else 1.0
\t\tif TimeManager.is_night():
\t\t\tvar lamp_p := Vector2(-21.0 * fs, -42.0)
\t\t\tdraw_circle(lamp_p, 12.0, Color(0.25, 0.90, 1.0, 0.22))
\t\t\tdraw_circle(lamp_p, 4.5, Color(0.45, 0.95, 1.0, 0.50))
\t\t\tdraw_circle(lamp_p, 1.5, Color(0.85, 1.0, 1.0, 0.95))

\t\t# Level indicators
\t\tif level >= 2:
\t\t\tdraw_circle(Vector2(22.0 * fs, -102.0), 2.5, Color(0.95, 0.85, 0.3, 0.9))
\t\tif level >= 3:
\t\t\tdraw_circle(Vector2(-22.0 * fs, -102.0), 2.5, Color(0.95, 0.85, 0.3, 0.9))
\t\treturn

\tvar silo_w: float = 46.0
\tvar silo_h: float = 75.0'''
assert old6 in txt, 'old6 not found'
txt = txt.replace(old6, new6, 1)

with open(p, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(txt)
print('Building.gd updated successfully!')

