extends Node

func _ready() -> void:
	print("--- Testing hover card sizing fix ---")
	
	# Create a PanelContainer simulating hover_card with width 340
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 28)
	var title = Label.new()
	title.text = "Palay (Rice)"
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)
	vbox.add_child(header)
	
	# Spacer
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(sp)
	
	# Content
	var type_lbl = Label.new()
	type_lbl.text = "Annual Cultivated Crop"
	type_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(type_lbl)
	
	var stats_lbl = Label.new()
	stats_lbl.text = "Growth: 15d Cycle • Yield: 100 • Base: ₱100"
	stats_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(stats_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(290, 0) # Width constraint so Godot calculates wrapped height properly!
	desc_lbl.text = "Thrives in wetland paddies (70-90% moisture). Halts growth if moisture < 30%. Excessive waterlogging (>95%) rots roots."
	desc_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc_lbl)
	
	var reg_lbl = Label.new()
	reg_lbl.text = "📍 Region: Cotabato Basin"
	reg_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(reg_lbl)
	
	var buff_lbl = Label.new()
	buff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buff_lbl.custom_minimum_size = Vector2(290, 0)
	buff_lbl.text = "✨ Specialty: +20% Market Value in Cotabato Basin!"
	buff_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(buff_lbl)
	
	var debuff_lbl = Label.new()
	debuff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debuff_lbl.custom_minimum_size = Vector2(290, 0)
	debuff_lbl.text = "⚠️ Moisture Deficit: Regional (65%) is below ideal (70%)."
	debuff_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(debuff_lbl)
	
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Panel calculated size: ", panel.size)
	print("Panel combined min size: ", panel.get_combined_minimum_size())
	for c in vbox.get_children():
		print("  item: ", c.get_class(), " size: ", c.size, " min: ", c.get_combined_minimum_size())
	
	get_tree().quit()
