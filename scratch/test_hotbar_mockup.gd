@tool
extends SceneTree

func _init():
    var root = Control.new()
    root.size = Vector2(1280, 720)
    
    # Background color
    var bg = ColorRect.new()
    bg.size = Vector2(1280, 720)
    bg.color = Color(0.2, 0.25, 0.2, 1.0)
    root.add_child(bg)
    
    # Let us test loading the textures and building a mockup
    print('Testing mockup...')
    quit(0)
