import os
from PIL import Image

ground_path = 'assets/sprites/ground/BARE SOIL/BARE-SOIL-01.png'
ground = Image.open(ground_path).convert('RGBA')

crop_path = 'assets/sprites/Field/Crops/Rice/RICE-P3.PNG'
crop = Image.open(crop_path).convert('RGBA')

farmer_path = 'assets/sprites/farmer/idle.png'
farmer = Image.open(farmer_path).convert('RGBA')

till_farmer_path = 'assets/sprites/farmer/till_1.png'
till_farmer = Image.open(till_farmer_path).convert('RGBA')

# Canvas: 480 x 320
canvas = Image.new('RGBA', (480, 320), (32, 44, 38, 255))

ox, oy = 240, 60

for gy in range(3):
    for gx in range(3):
        sx = ox + (gx - gy) * 64 - 64
        sy = oy + (gx + gy) * 32
        canvas.paste(ground, (sx, sy), ground)
        
        # Tile (1, 1) has crop
        if gx == 1 and gy == 1:
            cw, ch = crop.size
            crop_x = sx + 64 - cw // 2
            crop_y = sy + 48 - ch
            canvas.paste(crop, (crop_x, crop_y), crop)
        
        # Tile (1, 0) has tilling farmer
        if gx == 1 and gy == 0:
            fw, fh = till_farmer.size
            farmer_2x = till_farmer.resize((fw * 2, fh * 2), Image.Resampling.NEAREST)
            fx = sx + 64 - farmer_2x.width // 2
            fy = sy + 44 - farmer_2x.height
            canvas.paste(farmer_2x, (fx, fy), farmer_2x)
            
        # Tile (2, 1) has idle farmer
        if gx == 2 and gy == 1:
            fw, fh = farmer.size
            farmer_2x = farmer.resize((fw * 2, fh * 2), Image.Resampling.NEAREST)
            fx = sx + 64 - farmer_2x.width // 2
            fy = sy + 44 - farmer_2x.height
            canvas.paste(farmer_2x, (fx, fy), farmer_2x)

out_path = r'C:\Users\ADMIN\.gemini\antigravity-ide\brain\bf1aec29-35f3-4398-8b83-35e7fecd62b4\pawn_in_farm_world_preview.png'
canvas.save(out_path)
print('Saved world preview:', out_path)
