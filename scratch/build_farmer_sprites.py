import os
import numpy as np
from PIL import Image

os.makedirs('assets/sprites/farmer', exist_ok=True)

# Load the source generated sheet
src_path = r'C:\Users\ADMIN\.gemini\antigravity-ide\brain\bf1aec29-35f3-4398-8b83-35e7fecd62b4\faceless_32x32_pixel_pawn_sheet_1792250873233.jpg'
img = Image.open(src_path)
arr = np.array(img)

# Background color in raw image
bg = np.array([176, 183, 193])
dist = np.linalg.norm(arr.astype(float) - bg.astype(float), axis=2)
fg_mask = dist > 42

cols, rows = 8, 4
cw, ch = img.width // cols, img.height // rows

extracted_frames = []

for r in range(rows):
    row_f = []
    for c in range(cols):
        cell_arr = arr[r * ch : (r + 1) * ch, c * cw : (c + 1) * cw]
        cell_mask = fg_mask[r * ch : (r + 1) * ch, c * cw : (c + 1) * cw]
        
        rgba = np.zeros((ch, cw, 4), dtype=np.uint8)
        rgba[:, :, :3] = cell_arr
        rgba[:, :, 3] = np.where(cell_mask, 255, 0)
        
        cell_img = Image.fromarray(rgba, 'RGBA')
        bbox = cell_img.getbbox()
        if bbox:
            cropped = cell_img.crop(bbox)
            w, h = cropped.size
            # Uniform scale to fit in 28x28 inside a 32x32 tile
            target_h = 26
            scale = target_h / h
            nw = max(1, int(round(w * scale)))
            nh = target_h
            
            scaled = cropped.resize((nw, nh), Image.Resampling.NEAREST)
            s_arr = np.array(scaled)
            s_arr[:, :, 3] = np.where(s_arr[:, :, 3] > 128, 255, 0)
            clean = Image.fromarray(s_arr, 'RGBA')
            
            # Place in 32x32 frame with baseline at y=30 (leaving 2px at bottom)
            f32 = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
            px = (32 - nw) // 2
            py = 31 - nh
            f32.paste(clean, (px, py), clean)
            row_f.append(f32)
        else:
            row_f.append(None)
    extracted_frames.append(row_f)

# Save individual animation frames
# Row 0: Idle poses
idle_names = ['idle_front', 'idle_right_turn', 'idle_back', 'idle_left_turn', 'idle_front_2', 'idle_right_3', 'idle_back_2', 'idle_left_3']
for i, name in enumerate(idle_names):
    if extracted_frames[0][i]:
        extracted_frames[0][i].save(f'assets/sprites/farmer/{name}.png')

# Save primary idle.png
if extracted_frames[0][0]:
    extracted_frames[0][0].save('assets/sprites/farmer/idle.png')

# Row 1: Walk frames (take first 4 as walk loop)
walk_frames = []
for i in range(4):
    f = extracted_frames[1][i]
    if f:
        f.save(f'assets/sprites/farmer/walk_{i}.png')
        walk_frames.append(f)

# Row 2: Till / Plowing frames (take first 4 as till cycle)
till_frames = []
for i in range(4):
    f = extracted_frames[2][i]
    if f:
        f.save(f'assets/sprites/farmer/till_{i}.png')
        till_frames.append(f)

# Row 3: Harvest frames (take first 4 as harvest cycle)
harvest_frames = []
for i in range(4):
    f = extracted_frames[3][i]
    if f:
        f.save(f'assets/sprites/farmer/harvest_{i}.png')
        harvest_frames.append(f)

# Create 32x32 master sheet (8 cols x 4 rows = 256x128 pixels)
master_sheet = Image.new('RGBA', (32 * cols, 32 * rows), (0, 0, 0, 0))
for r in range(rows):
    for c in range(cols):
        f = extracted_frames[r][c]
        if f:
            master_sheet.paste(f, (c * 32, r * 32), f)

master_sheet.save('assets/sprites/farmer/farmer_sheet_32x32.png')

# Create animated GIFs at 4x scale for preview
def make_anim_gif(frames, out_name, duration=200):
    upscaled = [f.resize((128, 128), Image.Resampling.NEAREST) for f in frames]
    out_dir = r'C:\Users\ADMIN\.gemini\antigravity-ide\brain\bf1aec29-35f3-4398-8b83-35e7fecd62b4'
    path = os.path.join(out_dir, out_name)
    upscaled[0].save(
        path,
        save_all=True,
        append_images=upscaled[1:],
        duration=duration,
        loop=0,
        transparency=0,
        disposal=2
    )
    print(f'Saved animation: {path}')

if walk_frames:
    make_anim_gif(walk_frames, 'pawn_walk_animation.gif', 180)
if till_frames:
    make_anim_gif(till_frames, 'pawn_till_animation.gif', 220)
if harvest_frames:
    make_anim_gif(harvest_frames, 'pawn_harvest_animation.gif', 220)

print('All 32x32 farmer assets generated successfully!')
