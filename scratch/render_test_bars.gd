@tool
extends SceneTree

func _init():
	var style_inner = load("res://assets/sprites/hud/Inner-container/InnerBarBg.tres") as StyleBoxTexture
	# Set content margin so bar is placed precisely in the inner well
	style_inner.content_margin_left = 10.0
	style_inner.content_margin_right = 10.0
	style_inner.content_margin_top = 7.0
	style_inner.content_margin_bottom = 7.0
	ResourceSaver.save(style_inner, "res://assets/sprites/hud/Inner-container/InnerBarBg.tres")
	print("Saved InnerBarBg with content margins: 10, 7, 10, 7")
	quit(0)
