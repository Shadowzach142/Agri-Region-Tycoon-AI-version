with open('scenes/MainMenu.tscn', 'r', encoding='utf-8') as f:
    lines = f.readlines()

output = []
current_node = ""

for i, line in enumerate(lines):
    if line.startswith('[node name='):
        current_node = line
        output.append(line)
        # If this is SeasonLabel, ensure unique_name_in_owner = true
        if 'name="SeasonLabel"' in line:
            output.append('unique_name_in_owner = true\n')
        continue
    
    # If SeasonLabel had no unique_name_in_owner, we just added it above, skip any duplicate
    if 'name="SeasonLabel"' in current_node and 'unique_name_in_owner' in line:
        continue

    # Update font sizes based on current node
    if 'theme_override_font_sizes/font_size =' in line:
        if 'name="ModeTaglineLabel"' in current_node:
            output.append('theme_override_font_sizes/font_size = 14\n')
            continue
        elif 'name="ModeDescLabel"' in current_node:
            output.append('theme_override_font_sizes/font_size = 16\n')
            continue
        elif 'name="Pillar1Title"' in current_node or 'name="Pillar2Title"' in current_node or 'name="Pillar3Title"' in current_node:
            output.append('theme_override_font_sizes/font_size = 17\n')
            continue
        elif 'name="Pillar1Body"' in current_node or 'name="Pillar2Body"' in current_node or 'name="Pillar3Body"' in current_node:
            output.append('theme_override_font_sizes/font_size = 15\n')
            continue
        elif 'name="SeasonLabel"' in current_node:
            output.append('theme_override_font_sizes/font_size = 14\n')
            continue
        elif 'name="Season30Btn"' in current_node or 'name="Season60Btn"' in current_node or 'name="Season90Btn"' in current_node:
            output.append('theme_override_font_sizes/font_size = 14\n')
            continue
        elif 'name="ModeStartBtn"' in current_node:
            output.append('theme_override_font_sizes/font_size = 17\n')
            continue
        elif 'name="ModeLoadBtn"' in current_node:
            output.append('theme_override_font_sizes/font_size = 16\n')
            continue
        elif 'name="DossierHeader"' in current_node:
            output.append('theme_override_font_sizes/font_size = 18\n')
            continue
        elif 'name="DescLabel"' in current_node and 'MiddleCard' in current_node:
            output.append('theme_override_font_sizes/font_size = 16\n')
            continue
        elif 'name="MoistureTitle"' in current_node or 'name="CropsTitle"' in current_node or 'name="HazardTitle"' in current_node:
            output.append('theme_override_font_sizes/font_size = 13\n')
            continue
        elif 'name="MoistureVal"' in current_node or 'name="CropsVal"' in current_node or 'name="HazardVal"' in current_node:
            output.append('theme_override_font_sizes/font_size = 16\n')
            continue
        elif 'name="ProsHeader"' in current_node or 'name="ConsHeader"' in current_node:
            output.append('theme_override_font_sizes/font_size = 16\n')
            continue
        elif 'name="ProsText"' in current_node or 'name="ConsText"' in current_node:
            output.append('theme_override_font_sizes/font_size = 15\n')
            continue
        elif 'name="RegionNameLabel"' in current_node:
            output.append('theme_override_font_sizes/font_size = 21\n')
            continue
        elif 'name="RegionSpecialtyLabel"' in current_node:
            output.append('theme_override_font_sizes/font_size = 14\n')
            continue
        elif 'name="StartButton"' in current_node:
            output.append('theme_override_font_sizes/font_size = 17\n')
            continue

    output.append(line)

with open('scenes/MainMenu.tscn', 'w', encoding='utf-8') as f:
    f.writelines(output)

print("Properly replaced node font sizes and unique names in scenes/MainMenu.tscn")
