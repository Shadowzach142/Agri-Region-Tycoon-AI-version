with open('scenes/MainMenu.gd', 'r', encoding='utf-8') as f:
    text = f.read()

import re

# Check pros bullets in _apply_region_data
m = re.search(r'func _apply_region_data.*?func ', text, re.DOTALL)
if m:
    print('--- _apply_region_data ---')
    print(m.group(0)[:600])

m2 = re.search(r'func _setup_region_back_navigation.*?func ', text, re.DOTALL)
if m2:
    print('--- _setup_region_back_navigation ---')
    print(m2.group(0))

m3 = re.search(r'func _update_mode_season_buttons_ui.*?func ', text, re.DOTALL)
if m3:
    print('--- _update_mode_season_buttons_ui ---')
    print(m3.group(0))
