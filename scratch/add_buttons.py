with open('scenes/MainMenu.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

# Fix ModeLoadBtn duplicate styles and add ModeLeaderboardBtn
old_load = '''[node name="ModeLoadBtn" type="Button" parent="ModeSelectView/CenterContainer/BillboardPanel/BillboardVBox/ModeActionHBox" unique_id=1395168891]
unique_name_in_owner = true
custom_minimum_size = Vector2(230, 48)
layout_mode = 2
mouse_default_cursor_shape = 2
theme_override_colors/font_color = Color(0.96, 0.92, 0.84, 1)
theme_override_colors/font_hover_color = Color(1, 0.95, 0.6, 1)
theme_override_font_sizes/font_size = 16
theme_override_styles/normal = ExtResource("20_wood_btn")
theme_override_styles/hover = ExtResource("21_wood_hov")
theme_override_styles/pressed = ExtResource("22_wood_press")
theme_override_styles/pressed = ExtResource("19_brown_press")
theme_override_styles/hover = ExtResource("18_brown_hov")
text = "📂 LOAD SAVED GAME"'''

new_load = '''[node name="ModeLoadBtn" type="Button" parent="ModeSelectView/CenterContainer/BillboardPanel/BillboardVBox/ModeActionHBox" unique_id=1395168891]
unique_name_in_owner = true
custom_minimum_size = Vector2(210, 48)
layout_mode = 2
mouse_default_cursor_shape = 2
theme_override_colors/font_color = Color(0.96, 0.92, 0.84, 1)
theme_override_colors/font_hover_color = Color(1, 0.95, 0.6, 1)
theme_override_font_sizes/font_size = 16
theme_override_styles/normal = ExtResource("20_wood_btn")
theme_override_styles/hover = ExtResource("21_wood_hov")
theme_override_styles/pressed = ExtResource("22_wood_press")
text = "💾 LOAD SAVED GAME"

[node name="ModeLeaderboardBtn" type="Button" parent="ModeSelectView/CenterContainer/BillboardPanel/BillboardVBox/ModeActionHBox" unique_id=987123456]
unique_name_in_owner = true
custom_minimum_size = Vector2(190, 48)
layout_mode = 2
mouse_default_cursor_shape = 2
theme_override_colors/font_color = Color(0.96, 0.92, 0.84, 1)
theme_override_colors/font_hover_color = Color(1, 0.95, 0.6, 1)
theme_override_font_sizes/font_size = 15
theme_override_styles/normal = ExtResource("20_wood_btn")
theme_override_styles/hover = ExtResource("21_wood_hov")
theme_override_styles/pressed = ExtResource("22_wood_press")
text = "🏆 HALL OF FAME"'''

if old_load in text:
    text = text.replace(old_load, new_load)
else:
    print("WARNING: old_load block not exact match, let's search")

with open('scenes/MainMenu.tscn', 'w', encoding='utf-8') as f:
    f.write(text)

print("Saved scenes/MainMenu.tscn with clean ModeLoadBtn and ModeLeaderboardBtn")
