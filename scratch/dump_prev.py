import subprocess

out = subprocess.check_output(['git', 'show', 'HEAD:scenes/MainMenu.tscn'])
text = out.decode('utf-8', errors='replace')
with open('scratch/prev_mainmenu_tscn.txt', 'w', encoding='utf-8') as f:
    f.write(text)

print("Saved prev_mainmenu_tscn.txt, total lines:", len(text.splitlines()))
