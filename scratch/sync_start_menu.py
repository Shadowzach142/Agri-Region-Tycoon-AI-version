with open('scenes/MainMenu.tscn', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('name="MainMenu"', 'name="StartMenu"', 1)
with open('scenes/StartMenu.tscn', 'w', encoding='utf-8') as f:
    f.write(content)
print("StartMenu.tscn synced successfully!")
