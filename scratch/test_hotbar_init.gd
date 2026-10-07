@tool
extends SceneTree

func _init():
    var vp = SubViewport.new()
    vp.size = Vector2i(1280, 720)
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(vp)

    var bg = ColorRect.new()
    bg.size = Vector2(1280, 720)
    bg.color = Color(0.12, 0.16, 0.12, 1.0)
    vp.add_child(bg)

    var hotbar_script = load('res://src/ui/PlantHotbar.gd')
    var hotbar = hotbar_script.new()
    hotbar.name = 'PlantHotbar'
    vp.add_child(hotbar)

    # Force visible
    hotbar.visible = true

    print('Hotbar created successfully!')
    quit(0)
