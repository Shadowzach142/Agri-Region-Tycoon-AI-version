with open('scenes/MainGame.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

lines = text.splitlines()
for idx, l in enumerate(lines):
    if l.startswith('[node name="Farmer"'):
        for k in range(idx, min(idx + 35, len(lines))):
            print(lines[k])
        break
