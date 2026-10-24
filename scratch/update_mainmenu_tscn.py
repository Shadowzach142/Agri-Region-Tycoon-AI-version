import re

# 1. Update scenes/MainMenu.tscn
with open('scenes/MainMenu.tscn', 'r', encoding='utf-8') as f:
    tscn = f.read()

# Add WoodenButton resources if not present
if 'res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres' not in tscn:
    ext_chunk = '''[ext_resource type="StyleBox" path="res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres" id="20_wood_btn"]
[ext_resource type="StyleBox" path="res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres" id="21_wood_hov"]
[ext_resource type="StyleBox" path="res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonPressed.tres" id="22_wood_press"]
'''
    tscn = tscn.replace('[ext_resource type="StyleBox" path="res://assets/sprites/StartMenu/Brownbutton/BrownButtonPressed.tres" id="19_brown_press"]\n',
                         '[ext_resource type="StyleBox" path="res://assets/sprites/StartMenu/Brownbutton/BrownButtonPressed.tres" id="19_brown_press"]\n' + ext_chunk)

# Ensure TopCenterHeader is centered
tscn = re.sub(
    r'\[node name="TopCenterHeader" type="VBoxContainer" parent="\." unique_id=\d+\]\nlayout_mode = 1\nanchors_preset = 5\nanchor_left = 0\.5\nanchor_right = 0\.5\noffset_left = [^\n]+\noffset_top = [^\n]+\noffset_right = [^\n]+\noffset_bottom = [^\n]+',
    '[node name="TopCenterHeader" type="VBoxContainer" parent="." unique_id=35587538]\nlayout_mode = 1\nanchors_preset = 5\nanchor_left = 0.5\nanchor_right = 0.5\noffset_left = -380.0\noffset_top = 12.0\noffset_right = 380.0\noffset_bottom = 68.0',
    tscn
)

# Update TopRightMapCard to samplebox and top right position
top_right_old = re.search(r'\[node name="TopRightMapCard" type="PanelContainer" parent="\." unique_id=\d+\].*?theme_override_styles/panel = [^\n]+', tscn, re.DOTALL)
if top_right_old:
    top_right_new = '''[node name="TopRightMapCard" type="PanelContainer" parent="." unique_id=404249075]
visible = false
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -180.0
offset_top = 16.0
offset_right = -24.0
offset_bottom = 248.0
grow_horizontal = 0
theme_override_styles/panel = ExtResource("17_samplebox")'''
    tscn = tscn.replace(top_right_old.group(0), top_right_new)

# Update CarouselBar
carousel_old = re.search(r'\[node name="CarouselBar" type="HBoxContainer" parent="\." unique_id=\d+\].*?alignment = 1', tscn, re.DOTALL)
if carousel_old:
    carousel_new = '''[node name="CarouselBar" type="HBoxContainer" parent="." unique_id=39444495]
visible = false
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -340.0
offset_top = 80.0
offset_right = 340.0
offset_bottom = 134.0
grow_horizontal = 2
theme_override_constants/separation = 16
alignment = 1'''
    tscn = tscn.replace(carousel_old.group(0), carousel_new)

# Update RegionHeaderBox size and style
reg_header_old = re.search(r'\[node name="RegionHeaderBox" type="PanelContainer" parent="CarouselBar" unique_id=\d+\].*?theme_override_styles/panel = [^\n]+', tscn, re.DOTALL)
if reg_header_old:
    reg_header_new = '''[node name="RegionHeaderBox" type="PanelContainer" parent="CarouselBar" unique_id=356809650]
custom_minimum_size = Vector2(600, 54)
layout_mode = 2
size_flags_vertical = 4
theme_override_styles/panel = ExtResource("16_long_rect")'''
    tscn = tscn.replace(reg_header_old.group(0), reg_header_new)

# Update MiddleCard layout and font sizes
middle_card_old = re.search(r'\[node name="MiddleCard" type="PanelContainer" parent="\." unique_id=\d+\].*?theme_override_styles/panel = [^\n]+', tscn, re.DOTALL)
if middle_card_old:
    middle_card_new = '''[node name="MiddleCard" type="PanelContainer" parent="." unique_id=897025023]
visible = false
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -440.0
offset_top = -205.0
offset_right = 440.0
offset_bottom = 140.0
grow_horizontal = 2
grow_vertical = 2
theme_override_styles/panel = ExtResource("17_samplebox")'''
    tscn = tscn.replace(middle_card_old.group(0), middle_card_new)

# CardMargin
card_margin_old = re.search(r'\[node name="CardMargin" type="MarginContainer" parent="MiddleCard" unique_id=\d+\].*?theme_override_constants/margin_bottom = \d+', tscn, re.DOTALL)
if card_margin_old:
    card_margin_new = '''[node name="CardMargin" type="MarginContainer" parent="MiddleCard" unique_id=144168972]
layout_mode = 2
theme_override_constants/margin_left = 22
theme_override_constants/margin_top = 14
theme_override_constants/margin_right = 22
theme_override_constants/margin_bottom = 14'''
    tscn = tscn.replace(card_margin_old.group(0), card_margin_new)

# MiddleCard typography updates
tscn = re.sub(r'(\[node name="DossierHeader"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>18', tscn)
tscn = re.sub(r'(\[node name="DescLabel"[^\]]+\]\nunique_name_in_owner = true\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>16', tscn)
tscn = re.sub(r'(\[node name="MoistureTitle"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>13', tscn)
tscn = re.sub(r'(\[node name="MoistureVal"[^\]]+\]\nunique_name_in_owner = true\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>16', tscn)
tscn = re.sub(r'(\[node name="CropsTitle"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>13', tscn)
tscn = re.sub(r'(\[node name="CropsVal"[^\]]+\]\nunique_name_in_owner = true\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>16', tscn)
tscn = re.sub(r'(\[node name="HazardTitle"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>13', tscn)
tscn = re.sub(r'(\[node name="HazardVal"[^\]]+\]\nunique_name_in_owner = true\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>16', tscn)
tscn = re.sub(r'(\[node name="ProsHeader"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>16', tscn)
tscn = re.sub(r'(\[node name="ProsText"[^\]]+\]\nunique_name_in_owner = true\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>15', tscn)
tscn = re.sub(r'(\[node name="ConsHeader"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>16', tscn)
tscn = re.sub(r'(\[node name="ConsText"[^\]]+\]\nunique_name_in_owner = true\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>15', tscn)

# CarouselBar label font sizes
tscn = re.sub(r'(\[node name="RegionNameLabel"[^\]]+\]\nunique_name_in_owner = true\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>21', tscn)
tscn = re.sub(r'(\[node name="RegionSpecialtyLabel"[^\]]+\]\nunique_name_in_owner = true\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>14', tscn)

# FooterBar and StartButton
tscn = re.sub(
    r'(\[node name="StartButton" type="Button" parent="FooterBar" unique_id=\d+\]\nunique_name_in_owner = true\ncustom_minimum_size = Vector2\()[^\)]+(\)\nlayout_mode = 2\nmouse_default_cursor_shape = 2\n.*?theme_override_font_sizes/font_size = )\d+',
    r'\g<1>440, 48\g<2>17',
    tscn
)

# Start Menu (BillboardPanel) updates
tscn = re.sub(r'(\[node name="BillboardPanel" type="PanelContainer"[^\]]+\]\ncustom_minimum_size = Vector2\()[^\)]+(\))', r'\g<1>1040, 540\g<2>', tscn)
tscn = re.sub(r'(\[node name="TopNotice"[^\]]+\]\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>17', tscn)
tscn = re.sub(r'(\[node name="ModeTaglineLabel"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>14', tscn)
tscn = re.sub(r'(\[node name="ModeDescLabel"[^\]]+\]\nunique_name_in_owner = true\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>16', tscn)

# Ensure DescLabel custom_minimum_size in Billboard is 840x36
tscn = re.sub(r'(\[node name="ModeDescLabel"[^\]]+\]\nunique_name_in_owner = true\ncustom_minimum_size = Vector2\()[^\)]+(\))', r'\g<1>840, 36\g<2>', tscn)

# ModePlaque size in Billboard
tscn = re.sub(r'(\[node name="ModePlaque" type="PanelContainer"[^\]]+\]\ncustom_minimum_size = Vector2\()[^\)]+(\))', r'\g<1>540, 52\g<2>', tscn)
tscn = re.sub(r'(\[node name="ModeNameLabel"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>20', tscn)

# Pillars font sizes
tscn = re.sub(r'(\[node name="Pillar1Title"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>17', tscn)
tscn = re.sub(r'(\[node name="Pillar1Body"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>15', tscn)
tscn = re.sub(r'(\[node name="Pillar2Title"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>17', tscn)
tscn = re.sub(r'(\[node name="Pillar2Body"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>15', tscn)
tscn = re.sub(r'(\[node name="Pillar3Title"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>17', tscn)
tscn = re.sub(r'(\[node name="Pillar3Body"[^\]]+\]\nunique_name_in_owner = true\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = )\d+', r'\g<1>15', tscn)

# SeasonLabel - add unique_name_in_owner = true and font_size = 14
tscn = re.sub(
    r'\[node name="SeasonLabel" type="Label" parent="ModeSelectView/CenterContainer/BillboardPanel/BillboardVBox/ModeSeasonContainer" unique_id=\d+\]\nlayout_mode = 2\n.*?theme_override_font_sizes/font_size = \d+',
    '[node name="SeasonLabel" type="Label" parent="ModeSelectView/CenterContainer/BillboardPanel/BillboardVBox/ModeSeasonContainer" unique_id=1256146921]\nunique_name_in_owner = true\nlayout_mode = 2\ntheme_override_colors/font_color = Color(0.28, 0.18, 0.1, 1)\ntheme_override_font_sizes/font_size = 14',
    tscn
)

# Season buttons font size 14, size 185x38
tscn = re.sub(
    r'(\[node name="Season30Btn" type="Button"[^\]]+\]\nunique_name_in_owner = true\ncustom_minimum_size = Vector2\()[^\)]+(\)\nlayout_mode = 2\nmouse_default_cursor_shape = 2\ntheme_override_font_sizes/font_size = )\d+',
    r'\g<1>185, 38\g<2>14',
    tscn
)
tscn = re.sub(
    r'(\[node name="Season60Btn" type="Button"[^\]]+\]\nunique_name_in_owner = true\ncustom_minimum_size = Vector2\()[^\)]+(\)\nlayout_mode = 2\nmouse_default_cursor_shape = 2\ntheme_override_font_sizes/font_size = )\d+',
    r'\g<1>185, 38\g<2>14',
    tscn
)
tscn = re.sub(
    r'(\[node name="Season90Btn" type="Button"[^\]]+\]\nunique_name_in_owner = true\ncustom_minimum_size = Vector2\()[^\)]+(\)\nlayout_mode = 2\nmouse_default_cursor_shape = 2\ntheme_override_font_sizes/font_size = )\d+',
    r'\g<1>185, 38\g<2>14',
    tscn
)

# ModeStartBtn in Billboard: 440x48, 17pt font
tscn = re.sub(
    r'(\[node name="ModeStartBtn" type="Button"[^\]]+\]\nunique_name_in_owner = true\ncustom_minimum_size = Vector2\()[^\)]+(\)\nlayout_mode = 2\nmouse_default_cursor_shape = 2\n.*?theme_override_font_sizes/font_size = )\d+',
    r'\g<1>440, 48\g<2>17',
    tscn
)

# ModeLoadBtn in Billboard: 230x48, 16pt font, styled with WoodenButton
tscn = re.sub(
    r'(\[node name="ModeLoadBtn" type="Button"[^\]]+\]\nunique_name_in_owner = true\ncustom_minimum_size = Vector2\()[^\)]+(\)\nlayout_mode = 2\nmouse_default_cursor_shape = 2\n.*?theme_override_font_sizes/font_size = )\d+',
    r'\g<1>230, 48\g<2>16',
    tscn
)

# Set ModeLoadBtn styles to wooden button
mode_load_old = re.search(r'\[node name="ModeLoadBtn" type="Button" parent="ModeSelectView/CenterContainer/BillboardPanel/BillboardVBox/ModeActionHBox" unique_id=\d+\].*?theme_override_styles/normal = [^\n]+', tscn, re.DOTALL)
if mode_load_old:
    mode_load_new = '''[node name="ModeLoadBtn" type="Button" parent="ModeSelectView/CenterContainer/BillboardPanel/BillboardVBox/ModeActionHBox" unique_id=1395168891]
unique_name_in_owner = true
custom_minimum_size = Vector2(230, 48)
layout_mode = 2
mouse_default_cursor_shape = 2
theme_override_colors/font_color = Color(0.96, 0.92, 0.84, 1)
theme_override_colors/font_hover_color = Color(1, 0.95, 0.6, 1)
theme_override_font_sizes/font_size = 16
theme_override_styles/normal = ExtResource("20_wood_btn")
theme_override_styles/hover = ExtResource("21_wood_hov")
theme_override_styles/pressed = ExtResource("22_wood_press")'''
    tscn = tscn.replace(mode_load_old.group(0), mode_load_new)

# Save updated scenes/MainMenu.tscn
with open('scenes/MainMenu.tscn', 'w', encoding='utf-8') as f:
    f.write(tscn)

print("Updated scenes/MainMenu.tscn successfully")
