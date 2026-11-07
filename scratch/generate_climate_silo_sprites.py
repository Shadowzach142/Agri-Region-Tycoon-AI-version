"""
generate_climate_silo_sprites.py
Generates 48x64 low-resolution pixel-art sprites for the Climate-Controlled Silo
(CLIMATE-SILO-0.PNG, 25, 50, 75, 100 + _FLIPPED.PNG) directly referencing
the original Silo sprites (SILO-0.PNG .. SILO-100.PNG) to preserve the exact
pixel-low-resolution art style, silhouette, dithering, and dynamic grain fill gauge.
"""

import os
from PIL import Image, ImageOps

SILO_DIR = r"c:\Users\ADMIN\Documents\agri-region-ai-version\assets\sprites\buildings\Silo"

def is_inside_gauge_window(x: int, y: int) -> bool:
    if y == 20:
        return 21 <= x <= 26
    elif 21 <= y <= 35:
        return 20 <= x <= 27
    elif 36 <= y <= 54:
        return 21 <= x <= 26
    elif y == 55:
        return 22 <= x <= 25
    elif y == 56:
        return 23 <= x <= 24
    return False

def transform_pixel_to_climate(r: int, g: int, b: int, a: int, x: int, y: int, is_empty_gauge: bool = False):
    if a == 0:
        return (0, 0, 0, 0)

    # 1. Inside the central sight-glass window (tapered shape)
    if is_inside_gauge_window(x, y):
        # White frame pixels that touch the inner boundary
        if g > 150 and (r - b) <= 40:
            return (min(255, int(r * 0.94 + 8)), min(255, int(g * 0.98 + 5)), 255, a)
        # Golden-yellow grain pixels (all grain highlights & shadows have g > 100 and r - b > 40)
        if g > 100 and (r - b) > 40 and not is_empty_gauge:
            # Subtle cool airtight glass reflection along the left inner edge of the window
            left_edge = 20 if (21 <= y <= 35) else (21 if (y == 20 or 36 <= y <= 54) else 22)
            if x == left_edge:
                return (min(255, int(r * 0.88 + 22)), min(255, int(g * 0.94 + 16)), min(255, int(b + 42)), a)
            return (r, g, b, a)
        # Empty interior of the sight-glass (deep cryo-navy / dark slate interior)
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        nr = max(14, min(52, int(lum * 0.38) + 10))
        ng = max(30, min(82, int(lum * 0.65) + 22))
        nb = max(48, min(112, int(lum * 0.95) + 38))
        # Subtle horizontal level tick marks on the glass
        if x in (21, 22) and y in (26, 33, 40, 47):
            nr = min(255, nr + 38)
            ng = min(255, ng + 58)
            nb = min(255, nb + 72)
        return (nr, ng, nb, a)

    # 2. Conical Roof region (y <= 19 and not red body)
    is_red_body = (r > 105 and g < 65 and b < 65 and r > g * 2.0)
    if y <= 19 and not is_red_body:
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        # Original roof hatch is light neutral grey (abs(r-g)<12 and lum > 115)
        if abs(r - g) < 12 and abs(g - b) < 12 and lum > 115:
            # High-tech cryo-vent / solar louver panel (icy cyan-silver)
            if y % 2 == 0 and 12 <= x <= 20:
                return (52, 88, 112, a)
            return (min(255, int(lum * 0.85 + 25)), min(255, int(lum * 1.02 + 30)), min(255, int(lum * 1.12 + 42)), a)
        else:
            # Brushed titanium / cool slate dome roof (preserving exact pixel shading & ridge highlight)
            nr = max(35, min(165, int(lum * 0.78 + 14)))
            ng = max(48, min(185, int(lum * 0.92 + 24)))
            nb = max(62, min(208, int(lum * 1.08 + 38)))
            return (nr, ng, nb, a)

    # 3. Stone / Concrete Base Foundation (y >= 52 and not red body and not grey strut)
    if y >= 52 and not is_red_body:
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        # Cool industrial slate concrete base
        nr = max(45, min(215, int(lum * 0.86 + 8)))
        ng = max(55, min(225, int(lum * 0.94 + 14)))
        nb = max(68, min(240, int(lum * 1.04 + 24)))
        return (nr, ng, nb, a)

    # 4. White horizontal bands & sight-glass outer frame
    if g > 150 and (r - b) <= 45:
        # Crisp arctic white / chrome band
        return (min(255, int(r * 0.94 + 8)), min(255, int(g * 0.98 + 5)), 255, a)

    # 5. Grey vertical steel support struts at lower flanks
    if abs(r - g) < 25 and abs(g - b) < 25:
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        # Cool galvanized steel-blue strut
        nr = max(40, min(195, int(lum * 0.82 + 6)))
        ng = max(52, min(210, int(lum * 0.95 + 14)))
        nb = max(68, min(230, int(lum * 1.10 + 26)))
        return (nr, ng, nb, a)

    # 6. Main Cylindrical Body (was crimson red: high R, low G, low B)
    # Map red channel intensity -> rich industrial cryo-teal / arctic steel-blue
    # preserving every single pixel of dithering, bevels, and cylindrical shading!
    intensity = r / 255.0
    secondary = (g + b) * 0.5 / 255.0
    nr = int(max(14, min(145, 12 + intensity * 62 + secondary * 95)))
    ng = int(max(45, min(215, 28 + intensity * 138 + secondary * 75)))
    nb = int(max(75, min(248, 48 + intensity * 182 + secondary * 55)))
    return (nr, ng, nb, a)


def add_climate_hardware_details(img: Image.Image):
    """
    Adds crisp 1px low-resolution pixel-art climate-control hardware onto the 48x64 sprite:
      1. Apex atmospheric sensor / vent cap at (22..25, 0..1)
      2. Insulated cooling conduit pipe along right cylinder flank (x=33..34, y=19..37)
      3. Digital climate control thermostat box with glowing cyan/green LED at (x=13..17, y=29..34)
    """
    px = img.load()

    # 1. Apex vent cap at top of dome (y=0..1, x=22..25)
    px[23, 0] = (185, 225, 245, 255)
    px[24, 0] = (140, 185, 210, 255)
    px[22, 1] = (95, 130, 152, 255)
    px[23, 1] = (0, 240, 220, 255)   # tiny glowing cryo-sensor beacon pixel
    px[24, 1] = (170, 205, 225, 255)
    px[25, 1] = (80, 110, 132, 255)

    # 2. External insulated stainless cooling pipe on right side (x=33..34, y=19..37)
    for y in range(19, 38):
        if px[33, y][3] > 128 and px[34, y][3] > 128:
            if y in (22, 29, 35):
                # Pipe clamp bracket
                px[33, y] = (75, 102, 122, 255)
                px[34, y] = (55, 80, 98, 255)
            else:
                # Insulated chrome-blue pipe highlight + shadow
                px[33, y] = (195, 228, 245, 255)
                px[34, y] = (118, 162, 188, 255)

    # 3. Digital Thermostat & Chiller Control Box on left flank (x=13..17, y=29..34)
    box_x1, box_x2 = 13, 17
    box_y1, box_y2 = 29, 34
    for y in range(box_y1, box_y2 + 1):
        for x in range(box_x1, box_x2 + 1):
            if y in (box_y1, box_y2) or x in (box_x1, box_x2):
                px[x, y] = (42, 66, 84, 255)  # Dark steel housing border
            else:
                px[x, y] = (78, 112, 134, 255)  # Brushed steel panel
    # Glowing cyan/emerald climate status LEDs inside the thermostat box
    px[14, 30] = (40, 250, 220, 255)  # Bright cyan cold-status LED
    px[15, 30] = (40, 250, 220, 255)
    px[16, 30] = (45, 235, 115, 255)  # Green power LED
    # Mini louver vents at bottom of thermostat box
    px[14, 32] = (32, 52, 68, 255)
    px[15, 32] = (165, 215, 235, 255)
    px[16, 32] = (32, 52, 68, 255)
    px[14, 33] = (32, 52, 68, 255)
    px[15, 33] = (32, 52, 68, 255)
    px[16, 33] = (32, 52, 68, 255)


def build_all():
    im0_raw = Image.open(os.path.join(SILO_DIR, "SILO-0.PNG")).convert("RGBA")
    im25_raw = Image.open(os.path.join(SILO_DIR, "SILO-25.PNG")).convert("RGBA")

    # Fix 1px vertical shift on SILO-0 so all 5 levels align identically to (4, 1, 44, 63)
    im0_aligned = im25_raw.copy()
    for y in range(20, 57):
        for x in range(20, 28):
            if is_inside_gauge_window(x, y):
                im0_aligned.putpixel((x, y), im0_raw.getpixel((x, min(63, y + 1))))

    levels = {
        "0": im0_aligned,
        "25": im25_raw,
        "50": Image.open(os.path.join(SILO_DIR, "SILO-50.PNG")).convert("RGBA"),
        "75": Image.open(os.path.join(SILO_DIR, "SILO-75.PNG")).convert("RGBA"),
        "100": Image.open(os.path.join(SILO_DIR, "SILO-100.PNG")).convert("RGBA"),
    }

    generated = {}
    for lvl, src in levels.items():
        out = Image.new("RGBA", src.size, (0, 0, 0, 0))
        for y in range(src.height):
            for x in range(src.width):
                r, g, b, a = src.getpixel((x, y))
                out.putpixel((x, y), transform_pixel_to_climate(r, g, b, a, x, y, is_empty_gauge=(lvl == "0")))
        add_climate_hardware_details(out)

        out_path = os.path.join(SILO_DIR, f"CLIMATE-SILO-{lvl}.PNG")
        out.save(out_path)

        flip_out = ImageOps.mirror(out)
        flip_path = os.path.join(SILO_DIR, f"CLIMATE-SILO-{lvl}_FLIPPED.PNG")
        flip_out.save(flip_path)

        generated[lvl] = out
        print(f"Saved {out_path} and {flip_path} ({out.size})")

    # Build a 4x nearest-neighbor comparison sheet comparing SILO vs CLIMATE-SILO across all 5 levels
    scale = 4
    w, h = 48 * scale, 64 * scale
    pad = 12
    sheet_w = 5 * w + 6 * pad
    sheet_h = 2 * h + 3 * pad
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (28, 32, 38, 255))

    for i, lvl in enumerate(["0", "25", "50", "75", "100"]):
        orig = levels[lvl].resize((w, h), Image.Resampling.NEAREST)
        clim = generated[lvl].resize((w, h), Image.Resampling.NEAREST)
        x0 = pad + i * (w + pad)
        sheet.alpha_composite(orig, (x0, pad))
        sheet.alpha_composite(clim, (x0, pad * 2 + h))

    comp_path = r"c:\Users\ADMIN\Documents\agri-region-ai-version\scratch\climate_silo_comparison.png"
    sheet.save(comp_path)
    print(f"Comparison sheet saved to {comp_path}")

if __name__ == "__main__":
    build_all()
