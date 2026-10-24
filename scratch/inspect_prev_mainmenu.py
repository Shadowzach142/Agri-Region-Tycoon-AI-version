import subprocess

out = subprocess.check_output(['git', 'show', 'HEAD:scenes/MainMenu.tscn'])
text = out.decode('utf-8', errors='replace')
lines = text.splitlines()

for i, line in enumerate(lines):
    if 'TopRightMapCard' in line or 'MiddleCard' in line or 'CarouselBar' in line or 'FooterBar' in line or 'LeftMenuVBox' in line or 'ModeHoverCard' in line:
        print(f"{i}: {line}")
        for j in range(max(0, i-3), min(len(lines), i+15)):
            print(f"  {lines[j]}")
        print("="*40)
