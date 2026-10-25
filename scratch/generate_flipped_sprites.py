import os
from PIL import Image, ImageOps

bdir = "assets/sprites/buildings"

targets = [
    ("Water_Station.png", "Water_Station_FLIPPED.png"),
    ("KUBO.png", "KUBO_FLIPPED.png"),
    ("DRYER.PNG", "DRYER_FLIPPED.PNG"),
    ("Silo/SILO-0.PNG", "Silo/SILO-0_FLIPPED.PNG"),
    ("Silo/SILO-25.PNG", "Silo/SILO-25_FLIPPED.PNG"),
    ("Silo/SILO-50.PNG", "Silo/SILO-50_FLIPPED.PNG"),
    ("Silo/SILO-75.PNG", "Silo/SILO-75_FLIPPED.PNG"),
    ("Silo/SILO-100.PNG", "Silo/SILO-100_FLIPPED.PNG"),
]

for src, dst in targets:
    src_path = os.path.join(bdir, src)
    dst_path = os.path.join(bdir, dst)
    if not os.path.exists(src_path):
        print(f"Error: {src_path} does not exist!")
        continue
    img = Image.open(src_path)
    mirrored = ImageOps.mirror(img)
    mirrored.save(dst_path)
    print(f"Generated {dst_path} (size: {mirrored.size})")

print("Done generating flipped sprites.")
