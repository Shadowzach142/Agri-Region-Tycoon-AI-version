import re

with open('scratch/prev_mainmenu_tscn.txt', 'r', encoding='utf-8') as f:
    text = f.read()

nodes = re.findall(r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?', text)
for name, typ, parent in nodes[40:]:
    print(f"{parent or 'ROOT'} -> {name} ({typ})")
