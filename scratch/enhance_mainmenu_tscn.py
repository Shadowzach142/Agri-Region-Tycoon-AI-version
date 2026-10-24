with open('scenes/MainMenu.tscn', 'r', encoding='utf-8') as f:
    tscn = f.read()

import re

# 1. Update RegionHeaderBox size and separation
tscn = re.sub(
    r'(\[node name="RegionHeaderBox" type="PanelContainer"[^\]]+\]\ncustom_minimum_size = Vector2\()[^\)]+(\))',
    r'\g<1>620, 60\g<2>',
    tscn
)
tscn = re.sub(
    r'(\[node name="HeaderVBox" type="VBoxContainer"[^\]]+\]\nlayout_mode = 2\ntheme_override_constants/separation = )\d+',
    r'\g<1>0',
    tscn
)

# 2. Update RegionNameLabel colors on parchment
old_reg_name = re.search(r'\[node name="RegionNameLabel"[^\]]+\].*?text = "COTABATO BASIN"', tscn, re.DOTALL)
if old_reg_name:
    new_reg_name = '''[node name="RegionNameLabel" type="Label" parent="CarouselBar/RegionHeaderBox/HeaderVBox" unique_id=490318587]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_color = Color(0.24, 0.14, 0.08, 1)
theme_override_colors/font_shadow_color = Color(0.96, 0.9, 0.8, 0.8)
theme_override_constants/shadow_offset_x = 1
theme_override_constants/shadow_offset_y = 1
theme_override_font_sizes/font_size = 21
text = "COTABATO BASIN"'''
    tscn = tscn.replace(old_reg_name.group(0), new_reg_name)

# 3. Update RegionSpecialtyLabel colors on parchment
old_reg_spec = re.search(r'\[node name="RegionSpecialtyLabel"[^\]]+\].*?text = "Rice Paddies & Wetland Agriculture"', tscn, re.DOTALL)
if old_reg_spec:
    new_reg_spec = '''[node name="RegionSpecialtyLabel" type="Label" parent="CarouselBar/RegionHeaderBox/HeaderVBox" unique_id=512660938]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_color = Color(0.4, 0.26, 0.15, 1)
theme_override_colors/font_shadow_color = Color(0.96, 0.9, 0.8, 0.8)
theme_override_constants/shadow_offset_x = 1
theme_override_constants/shadow_offset_y = 1
theme_override_font_sizes/font_size = 14
text = "Rice Paddies & Wetland Agriculture"'''
    tscn = tscn.replace(old_reg_spec.group(0), new_reg_spec)

# 4. MiddleCard typography colors
old_dossier = re.search(r'\[node name="DossierHeader"[^\]]+\].*?text = "REGIONAL PROFILE & BRIEFING"', tscn, re.DOTALL)
if old_dossier:
    new_dossier = '''[node name="DossierHeader" type="Label" parent="MiddleCard/CardMargin/CardVBox" unique_id=1571284071]
layout_mode = 2
theme_override_colors/font_color = Color(0.24, 0.14, 0.08, 1)
theme_override_colors/font_shadow_color = Color(0.96, 0.9, 0.8, 0.8)
theme_override_constants/shadow_offset_x = 1
theme_override_constants/shadow_offset_y = 1
theme_override_font_sizes/font_size = 18
text = "REGIONAL PROFILE & BRIEFING"'''
    tscn = tscn.replace(old_dossier.group(0), new_dossier)

old_desc = re.search(r'\[node name="DescLabel"[^\]]+\].*?autowrap_mode = \d+', tscn, re.DOTALL)
if old_desc:
    new_desc = '''[node name="DescLabel" type="Label" parent="MiddleCard/CardMargin/CardVBox" unique_id=1593344193]
unique_name_in_owner = true
custom_minimum_size = Vector2(800, 36)
layout_mode = 2
theme_override_colors/font_color = Color(0.2, 0.12, 0.06, 1)
theme_override_constants/line_spacing = 3
theme_override_font_sizes/font_size = 16
text = "The fertile rice bowl of Central Mindanao, fed by the Pulangi river basin with rich alluvial soils for continuous cultivation."
autowrap_mode = 3'''
    tscn = tscn.replace(old_desc.group(0), new_desc)

# Pros / Cons colors in MiddleCard
tscn = re.sub(r'(\[node name="ProsHeader"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.12, 0.42, 0.12, 1)', tscn)
tscn = re.sub(r'(\[node name="ProsText"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.20, 0.12, 0.06, 1)', tscn)
tscn = re.sub(r'(\[node name="ConsHeader"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.65, 0.18, 0.12, 1)', tscn)
tscn = re.sub(r'(\[node name="ConsText"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.20, 0.12, 0.06, 1)', tscn)

# Specs title and val colors in MiddleCard
tscn = re.sub(r'(\[node name="MoistureTitle"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.40, 0.26, 0.15, 1)', tscn)
tscn = re.sub(r'(\[node name="CropsTitle"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.40, 0.26, 0.15, 1)', tscn)
tscn = re.sub(r'(\[node name="HazardTitle"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.40, 0.26, 0.15, 1)', tscn)

tscn = re.sub(r'(\[node name="MoistureVal"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.20, 0.12, 0.06, 1)', tscn)
tscn = re.sub(r'(\[node name="CropsVal"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.20, 0.12, 0.06, 1)', tscn)
tscn = re.sub(r'(\[node name="HazardVal"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_colors/font_color = )[^\n]+', r'\g<1>Color(0.20, 0.12, 0.06, 1)', tscn)

# StartButton colors in FooterBar (Gold button with dark espresso text)
old_start_btn = re.search(r'\[node name="StartButton"[^\]]+\].*?text = [^\n]+', tscn, re.DOTALL)
if old_start_btn:
    new_start_btn = '''[node name="StartButton" type="Button" parent="FooterBar" unique_id=1125766979]
unique_name_in_owner = true
custom_minimum_size = Vector2(440, 48)
layout_mode = 2
mouse_default_cursor_shape = 2
theme_override_colors/font_color = Color(0.2, 0.12, 0.06, 1)
theme_override_colors/font_hover_color = Color(0.1, 0.05, 0.02, 1)
theme_override_font_sizes/font_size = 17
theme_override_styles/normal = ExtResource("12_gold_btn")
theme_override_styles/pressed = ExtResource("14_gold_press")
theme_override_styles/hover = ExtResource("13_gold_hov")
text = "START FARMING IN COTABATO BASIN  >"'''
    tscn = tscn.replace(old_start_btn.group(0), new_start_btn)

# ModeStartBtn in Billboard
old_mode_start = re.search(r'\[node name="ModeStartBtn"[^\]]+\].*?text = [^\n]+', tscn, re.DOTALL)
if old_mode_start:
    new_mode_start = '''[node name="ModeStartBtn" type="Button" parent="ModeSelectView/CenterContainer/BillboardPanel/BillboardVBox/ModeActionHBox" unique_id=222952614]
unique_name_in_owner = true
custom_minimum_size = Vector2(420, 48)
layout_mode = 2
mouse_default_cursor_shape = 2
theme_override_colors/font_color = Color(0.2, 0.12, 0.06, 1)
theme_override_colors/font_hover_color = Color(0.1, 0.05, 0.02, 1)
theme_override_font_sizes/font_size = 17
theme_override_styles/normal = ExtResource("12_gold_btn")
theme_override_styles/pressed = ExtResource("14_gold_press")
theme_override_styles/hover = ExtResource("13_gold_hov")
text = "PROCEED TO REGION SELECT (START CAMPAIGN)  >"'''
    tscn = tscn.replace(old_mode_start.group(0), new_mode_start)

# Add Hall of Fame button to ModeActionHBox if not present
if 'name="ModeLeaderboardBtn"' not in tscn:
    hof_button = '''[node name="ModeLeaderboardBtn" type="Button" parent="ModeSelectView/CenterContainer/BillboardPanel/BillboardVBox/ModeActionHBox" unique_id=987123456]
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
text = "🏆 HALL OF FAME"
'''
    tscn = tscn.replace('text = "LOAD SAVED GAME"\n', 'text = "LOAD SAVED GAME"\n\n' + hof_button)

with open('scenes/MainMenu.tscn', 'w', encoding='utf-8') as f:
    f.write(tscn)

print("Applied contrast and sleek button updates to MainMenu.tscn")
