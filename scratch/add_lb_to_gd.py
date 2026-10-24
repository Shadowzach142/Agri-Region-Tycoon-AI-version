with open('scenes/MainMenu.gd', 'r', encoding='utf-8') as f:
    code = f.read()

# Add _mode_leaderboard_btn variable
if 'var _mode_leaderboard_btn: Button = null' not in code:
    code = code.replace('var _mode_load_btn: Button = null',
                        'var _mode_load_btn: Button = null\nvar _mode_leaderboard_btn: Button = null')

# Connect _mode_leaderboard_btn in _build_mode_select_view
if '_mode_leaderboard_btn = find_child("ModeLeaderboardBtn"' not in code:
    connect_chunk = '''\t_mode_leaderboard_btn = find_child("ModeLeaderboardBtn", true, false) as Button
\tif _mode_leaderboard_btn:
\t\t_mode_leaderboard_btn.pressed.connect(_open_leaderboard_modal)
'''
    code = code.replace('%ModeLoadBtn.pressed.connect(_open_load_modal)\n',
                        '%ModeLoadBtn.pressed.connect(_open_load_modal)\n' + connect_chunk)

# Add _open_leaderboard_modal function
if 'func _open_leaderboard_modal' not in code:
    lb_func = '''func _open_leaderboard_modal() -> void:
\tvar lb_cls = load("res://src/ui/LeaderboardPanel.gd")
\tif lb_cls:
\t\tvar lb = lb_cls.new()
\t\tadd_child(lb)

'''
    code = code.replace('func _open_load_modal() -> void:', lb_func + 'func _open_load_modal() -> void:')

with open('scenes/MainMenu.gd', 'w', encoding='utf-8') as f:
    f.write(code)

print("Added Leaderboard modal support to MainMenu.gd")
