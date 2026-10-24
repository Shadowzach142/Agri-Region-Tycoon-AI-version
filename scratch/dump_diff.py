import subprocess

out = subprocess.check_output(['git', 'diff', 'HEAD', 'scenes/MainMenu.tscn'])
text = out.decode('utf-8', errors='replace')
with open('scratch/mainmenu_diff.txt', 'w', encoding='utf-8') as f:
    f.write(text)

print("Saved mainmenu_diff.txt, lines:", len(text.splitlines()))
