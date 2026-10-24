with open('scenes/MainMenu.gd', 'r', encoding='utf-8') as f:
    code = f.read()

# Add style_wood variables
if 'var style_wood_btn: StyleBox = null' not in code:
    code = code.replace('var style_gold_press: StyleBox = null',
                        'var style_gold_press: StyleBox = null\nvar style_wood_btn: StyleBox = null\nvar style_wood_hov: StyleBox = null\nvar style_wood_press: StyleBox = null')

# Load wooden button in _load_startmenu_resources
wood_loader = '''\tif ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres"):
\t\tstyle_wood_btn = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres")
\tif ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres"):
\t\tstyle_wood_hov = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres")
\tif ResourceLoader.exists("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonPressed.tres"):
\t\tstyle_wood_press = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonPressed.tres")
'''
if 'res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres' not in code:
    code = code.replace('\t\tstyle_gold_press = load("res://assets/sprites/StartMenu/GoldButton/GoldbuttonPresesd.tres")\n',
                        '\t\tstyle_gold_press = load("res://assets/sprites/StartMenu/GoldButton/GoldbuttonPresesd.tres")\n' + wood_loader)

# Replace pros/cons formatting in _apply_region_data
old_pros = '''\tvar pros_array: Array = r_data.get("pros", [])
\tvar pros_str: String = ""
\tfor p in pros_array:
\t\tpros_str += "[+] %s\\n\\n" % p
\tpros_text.text = pros_str.strip_edges()

\tvar cons_array: Array = r_data.get("cons", [])
\tvar cons_str: String = ""
\tfor c in cons_array:
\t\tcons_str += "[!] %s\\n\\n" % c
\tcons_text.text = cons_str.strip_edges()'''

new_pros = '''\tvar pros_array: Array = r_data.get("pros", [])
\tvar pros_str: String = ""
\tfor p in pros_array:
\t\tpros_str += "• %s\\n" % p
\tpros_text.text = pros_str.strip_edges()

\tvar cons_array: Array = r_data.get("cons", [])
\tvar cons_str: String = ""
\tfor c in cons_array:
\t\tcons_str += "• %s\\n" % c
\tcons_text.text = cons_str.strip_edges()'''

if old_pros in code:
    code = code.replace(old_pros, new_pros)

# Replace _setup_region_back_navigation with WoodenButton styling
old_nav = '''\t_back_to_modes_btn = Button.new()
\t_back_to_modes_btn.text = "← BACK TO GAME MODES"
\t_back_to_modes_btn.custom_minimum_size = Vector2(180, 36)
\t_back_to_modes_btn.add_theme_font_size_override("font_size", 12)
\t_back_to_modes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
\tif style_brown_btn:
\t\t_back_to_modes_btn.add_theme_stylebox_override("normal", style_brown_btn)
\t\t_back_to_modes_btn.add_theme_stylebox_override("hover", style_brown_hov)
\t\t_back_to_modes_btn.add_theme_stylebox_override("pressed", style_brown_press)
\t_back_to_modes_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
\t_back_to_modes_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
\t_back_to_modes_btn.pressed.connect(_show_mode_select)
\t_region_nav_box.add_child(_back_to_modes_btn)

\t_mode_badge_label = Label.new()
\t_mode_badge_label.text = "[ TIMED CAMPAIGN ]"
\t_mode_badge_label.add_theme_font_size_override("font_size", 11)'''

new_nav = '''\t_back_to_modes_btn = Button.new()
\t_back_to_modes_btn.text = "<  GAME MODES"
\t_back_to_modes_btn.custom_minimum_size = Vector2(190, 38)
\t_back_to_modes_btn.add_theme_font_size_override("font_size", 14)
\t_back_to_modes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
\tif style_wood_btn:
\t\t_back_to_modes_btn.add_theme_stylebox_override("normal", style_wood_btn)
\t\t_back_to_modes_btn.add_theme_stylebox_override("hover", style_wood_hov)
\t\t_back_to_modes_btn.add_theme_stylebox_override("pressed", style_wood_press)
\telif style_brown_btn:
\t\t_back_to_modes_btn.add_theme_stylebox_override("normal", style_brown_btn)
\t\t_back_to_modes_btn.add_theme_stylebox_override("hover", style_brown_hov)
\t\t_back_to_modes_btn.add_theme_stylebox_override("pressed", style_brown_press)
\t_back_to_modes_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
\t_back_to_modes_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
\t_back_to_modes_btn.pressed.connect(_show_mode_select)
\t_region_nav_box.add_child(_back_to_modes_btn)

\t_mode_badge_label = Label.new()
\t_mode_badge_label.text = "[ TIMED CAMPAIGN ]"
\t_mode_badge_label.add_theme_font_size_override("font_size", 13)'''

if old_nav in code:
    code = code.replace(old_nav, new_nav)

# Update _update_mode_season_buttons_ui font sizes and wooden styles
old_season_ui = '''\tfor days in _mode_season_buttons.keys():
\t\tvar btn: Button = _mode_season_buttons[days]
\t\tif days == Data.selected_season_days:
\t\t\tif style_gold_btn:
\t\t\t\tbtn.add_theme_stylebox_override("normal", style_gold_btn)
\t\t\t\tbtn.add_theme_stylebox_override("hover", style_gold_hov)
\t\t\t\tbtn.add_theme_stylebox_override("pressed", style_gold_press)
\t\t\tbtn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
\t\t\tbtn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02, 1.0))
\t\t\tbtn.add_theme_font_size_override("font_size", 13)
\t\telse:
\t\t\tif style_brown_btn:
\t\t\t\tbtn.add_theme_stylebox_override("normal", style_brown_btn)
\t\t\t\tbtn.add_theme_stylebox_override("hover", style_brown_hov)
\t\t\t\tbtn.add_theme_stylebox_override("pressed", style_brown_press)
\t\t\tbtn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
\t\t\tbtn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
\t\t\tbtn.add_theme_font_size_override("font_size", 13)'''

new_season_ui = '''\tfor days in _mode_season_buttons.keys():
\t\tvar btn: Button = _mode_season_buttons[days]
\t\tif days == Data.selected_season_days:
\t\t\tif style_gold_btn:
\t\t\t\tbtn.add_theme_stylebox_override("normal", style_gold_btn)
\t\t\t\tbtn.add_theme_stylebox_override("hover", style_gold_hov)
\t\t\t\tbtn.add_theme_stylebox_override("pressed", style_gold_press)
\t\t\tbtn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
\t\t\tbtn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02, 1.0))
\t\t\tbtn.add_theme_font_size_override("font_size", 14)
\t\telse:
\t\t\tvar inactive_style = style_wood_btn if style_wood_btn else style_brown_btn
\t\t\tvar inactive_hov = style_wood_hov if style_wood_hov else style_brown_hov
\t\t\tvar inactive_press = style_wood_press if style_wood_press else style_brown_press
\t\t\tif inactive_style:
\t\t\t\tbtn.add_theme_stylebox_override("normal", inactive_style)
\t\t\t\tbtn.add_theme_stylebox_override("hover", inactive_hov)
\t\t\t\tbtn.add_theme_stylebox_override("pressed", inactive_press)
\t\t\tbtn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1.0))
\t\t\tbtn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
\t\t\tbtn.add_theme_font_size_override("font_size", 14)'''

if old_season_ui in code:
    code = code.replace(old_season_ui, new_season_ui)

with open('scenes/MainMenu.gd', 'w', encoding='utf-8') as f:
    f.write(code)

print("Updated scenes/MainMenu.gd successfully")
