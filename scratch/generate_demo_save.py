"""
generate_demo_save.py
Generates a demo save file (slot_1.json) for Agri-Region Tycoon that reflects
the "Chapter III — Regional Expansion" state shown in the trailer:
  - Cotabato Basin, Career mode, Day 38
  - 3 land parcels unlocked (homestead + east_meadows + south_plains)
  - Good cash: ₱18,750
  - Score: 42,800 pts (Master Tycoon tier)
  - Workers: 5 active, drone fleet active
  - Mix of crops at various stages, some perennials regrowing
  - Buildings: bahay_kubo ×2, bodega, cold_storage, solar_dryer,
               bayanihan_center, tacurong_mill, drone_station, drone_pad ×2,
               water_tower, weather_station, rice_mill
  - Market inventory: mix of palay, sugarcane, yellow_corn in storage
  - Price history: 7-day data for all 7 crops

Save lands in the Godot user:// saves directory.
"""

import json
import os
import time
import math
import random

random.seed(42)

GRID_W = 32
GRID_H = 32

# ---------------------------------------------------------------------------
# Tile State enum (matches FarmTile.gd TileState)
# ---------------------------------------------------------------------------
EMPTY      = 0
PLOWED     = 1
PLANTED    = 2
GROWING    = 3
READY      = 4  # HARVESTABLE
OBSTACLE   = 7
BUILDING   = 8

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def empty_tile(x, y):
    return {
        "s": EMPTY, "m": 55.0, "c": "", "g": 0.0, "h": 1.0,
        "q": 0, "y": 100, "f": 100.0, "p": "", "o": "",
        "fe": 1.0, "w": 0, "rg": False, "mr": False, "mp": [-1, -1]
    }

def plowed_tile(moisture=62.0, fertility=1.1):
    return {
        "s": PLOWED, "m": moisture, "c": "", "g": 0.0, "h": 1.0,
        "q": 0, "y": 100, "f": 100.0, "p": "", "o": "",
        "fe": fertility, "w": 0, "rg": False, "mr": False, "mp": [-1, -1]
    }

def crop_tile(crop, progress, health=1.0, quality=2, moisture=68.0,
              yield_qty=100, freshness=100.0, fertility=1.15,
              is_ready=False, is_regrowing=False,
              is_root=True, root_pos=None):
    state = READY if is_ready else (GROWING if progress >= 0.0 else PLANTED)
    if is_regrowing:
        state = GROWING  # regrowing perennials use GROWING
    return {
        "s": state,
        "m": moisture,
        "c": crop,
        "g": progress,
        "h": health,
        "q": quality,
        "y": yield_qty,
        "f": freshness,
        "p": "",
        "o": "",
        "fe": fertility,
        "w": 0,
        "rg": is_regrowing,
        "mr": is_root,
        "mp": root_pos if root_pos else [-1, -1]
    }

# ---------------------------------------------------------------------------
# Build 32x32 tile grid
# The trailer shows:
#   - Top-left homestead (0-15,0-15): dense mixed crops
#   - East meadows (16-31,0-15): more crops + buildings
#   - South plains (0-15,16-31): expansion parcels with palay rows
#   - Highland plateau (16-31,16-31): locked (empty, obstacles)
# ---------------------------------------------------------------------------
def build_tiles():
    tiles = [[empty_tile(x, y) for y in range(GRID_H)] for x in range(GRID_W)]

    # --- HOMESTEAD (0-15, 0-15) ---
    # Row 0-1: Plowed, ready for planting
    for x in range(0, 14):
        for y in range(0, 2):
            tiles[x][y] = plowed_tile(64.0, 1.1)

    # Row 2-3: Palay nearing harvest (progress ~0.92)
    for x in range(0, 14):
        for y in range(2, 4):
            tiles[x][y] = crop_tile("palay", 0.92, health=0.95, quality=2,
                                    moisture=72.0, yield_qty=108, freshness=100.0)

    # Row 4-5: Yellow corn mid-growth (0.55)
    for x in range(0, 12):
        for y in range(4, 6):
            tiles[x][y] = crop_tile("yellow_corn", 0.55, health=1.0, quality=2,
                                    moisture=48.0, yield_qty=100)

    # Row 6-7: Sugarcane early-mid (0.38)
    for x in range(0, 12):
        for y in range(6, 8):
            tiles[x][y] = crop_tile("sugarcane", 0.38, health=1.0, quality=2,
                                    moisture=65.0, yield_qty=120)

    # Row 8-9: Pineapple late-stage (0.82)
    for x in range(0, 10):
        for y in range(8, 10):
            tiles[x][y] = crop_tile("pineapple", 0.82, health=0.9, quality=3,
                                    moisture=52.0, yield_qty=100, freshness=98.0)

    # Row 10-11: Arabica coffee regrowing perennial (0.5 progress, regrowing)
    for x in range(0, 8):
        for y in range(10, 12):
            tiles[x][y] = crop_tile("arabica_coffee", 0.50, health=0.95, quality=2,
                                    moisture=58.0, yield_qty=100, is_regrowing=True)

    # 2x2 Banana groves at (0,12), (4,12), (8,12) - perennial regrowing
    for bx in [0, 4, 8]:
        by = 12
        root_pos = [bx, by]
        tiles[bx][by]     = crop_tile("banana", 0.62, health=1.0, quality=2,
                                       moisture=72.0, yield_qty=400,
                                       is_regrowing=True, is_root=True, root_pos=[-1,-1])
        tiles[bx][by]["mr"] = True
        for (dx, dy) in [(1,0),(0,1),(1,1)]:
            tiles[bx+dx][by+dy] = crop_tile("banana", 0.62, health=1.0, quality=2,
                                              moisture=72.0, yield_qty=0,
                                              is_regrowing=True, is_root=False,
                                              root_pos=root_pos)
            tiles[bx+dx][by+dy]["mr"] = False

    # 2x2 Coconut grove at (0,14) - early growth
    cx, cy = 0, 14
    tiles[cx][cy] = crop_tile("coconut", 0.35, health=1.0, quality=2,
                               moisture=62.0, yield_qty=400,
                               is_root=True)
    tiles[cx][cy]["mr"] = True
    for (dx,dy) in [(1,0),(0,1),(1,1)]:
        tiles[cx+dx][cy+dy] = crop_tile("coconut", 0.35, health=1.0, quality=2,
                                         moisture=62.0, yield_qty=0,
                                         is_root=False, root_pos=[cx, cy])
        tiles[cx+dx][cy+dy]["mr"] = False

    # Palay READY to harvest strip (row 0-1, x=0-7)
    for x in range(0, 8):
        tiles[x][0] = crop_tile("palay", 1.0, health=0.98, quality=3,
                                 moisture=74.0, yield_qty=112, freshness=100.0,
                                 is_ready=True)

    # --- EAST MEADOWS (16-31, 0-15): Expansion zone ---
    # Palay paddies across east meadows
    for x in range(16, 30):
        for y in range(0, 6):
            progress = 0.4 + (x - 16) * 0.04
            tiles[x][y] = crop_tile("palay", min(progress, 0.88), health=1.0, quality=2,
                                    moisture=76.0, yield_qty=100)

    # Sugarcane in east meadows middle
    for x in range(16, 28):
        for y in range(6, 10):
            tiles[x][y] = crop_tile("sugarcane", 0.62, health=0.95, quality=2,
                                    moisture=66.0, yield_qty=120)

    # Banana groves in east meadows
    for bx in [16, 20, 24]:
        by = 10
        tiles[bx][by]["mr"] = True
        tiles[bx][by] = crop_tile("banana", 1.0, health=1.0, quality=3,
                                   moisture=75.0, yield_qty=400,
                                   is_ready=True, is_root=True)
        tiles[bx][by]["mr"] = True
        for (dx,dy) in [(1,0),(0,1),(1,1)]:
            if bx+dx < GRID_W and by+dy < GRID_H:
                tiles[bx+dx][by+dy] = crop_tile("banana", 1.0, health=1.0, quality=3,
                                                  moisture=75.0, yield_qty=0,
                                                  is_ready=True, is_root=False,
                                                  root_pos=[bx, by])

    # Arabica coffee strip in east meadows
    for x in range(16, 26):
        for y in range(12, 14):
            tiles[x][y] = crop_tile("arabica_coffee", 0.75, health=1.0, quality=3,
                                    moisture=62.0, yield_qty=100)

    # --- SOUTH PLAINS (0-15, 16-31): Expansion zone ---
    # Dense palay rows
    for x in range(0, 14):
        for y in range(16, 22):
            tiles[x][y] = crop_tile("palay", 0.28, health=1.0, quality=2,
                                    moisture=70.0, yield_qty=100)

    # Yellow corn south
    for x in range(0, 12):
        for y in range(22, 26):
            tiles[x][y] = crop_tile("yellow_corn", 0.72, health=0.95, quality=2,
                                    moisture=44.0, yield_qty=100)

    # Plowed plots for next season
    for x in range(0, 14):
        for y in range(26, 28):
            tiles[x][y] = plowed_tile(60.0, 1.05)

    # Coconut grove south expansion
    for bx in [0, 4]:
        by = 28
        tiles[bx][by] = crop_tile("coconut", 0.18, health=1.0, quality=2,
                                   moisture=58.0, yield_qty=400,
                                   is_root=True)
        tiles[bx][by]["mr"] = True
        for (dx,dy) in [(1,0),(0,1),(1,1)]:
            if bx+dx < GRID_W and by+dy < GRID_H:
                tiles[bx+dx][by+dy] = crop_tile("coconut", 0.18, health=1.0, quality=2,
                                                  moisture=58.0, yield_qty=0,
                                                  is_root=False, root_pos=[bx, by])

    # Highland plateau (16-31, 16-31) stays mostly empty/obstacle (locked parcel)
    for x in range(16, 32):
        for y in range(16, 32):
            tiles[x][y] = empty_tile(x, y)

    return tiles

# ---------------------------------------------------------------------------
# Buildings — placed on valid parcel tiles
# Avoid crop areas, use edges and building zones
# ---------------------------------------------------------------------------
def build_buildings():
    buildings = []

    def add_building(btype, gx, gy, fp, level=1, state=1):  # 1 = ACTIVE
        buildings.append({
            "type": btype,
            "grid_pos": [gx, gy],
            "footprint": [fp[0], fp[1]],
            "level": level,
            "state": state,
            "progress_timer": 0.0,
            "duration": 0.0,
            "assigned_crops": [],
            "used_storage": 0,
            "is_flipped": False
        })

    # Homestead zone buildings (placed in non-crop areas)
    # Bahay Kubo x2 (2×2 each) — workers housing
    add_building("bahay_kubo",  12, 0,  [2, 2], level=2)
    add_building("bahay_kubo",  12, 2,  [2, 2], level=1)
    # Solar Dryer (3×3)
    add_building("solar_dryer", 12, 6,  [3, 3], level=2)
    # Bayanihan Center (2×2)
    add_building("bayanihan_center", 12, 10, [2, 2], level=1)
    # Water Tower (2×2)
    add_building("water_tower", 12, 12, [2, 2], level=2)
    # Bodega (2×2)
    add_building("bodega",      12, 14, [2, 2], level=2)
    # Drone Station (2×2)
    add_building("drone_station", 14, 0, [2, 2], level=3)
    # Drone Pads x2 (2×2 each)
    add_building("drone_pad",   14, 2, [2, 2], level=1)
    add_building("drone_pad",   14, 4, [2, 2], level=1)

    # East Meadows buildings
    # Weather Station (3×3)
    add_building("weather_station", 28, 0, [3, 3], level=2)
    # Cold Storage (3×3)
    add_building("cold_storage", 28, 4, [3, 3], level=1)
    # Tacurong Mill (4×4) — trade hub
    add_building("tacurong_mill", 27, 11, [4, 4], level=1)

    # South Plains buildings
    # Rice Mill (3×3)
    add_building("rice_mill",    12, 16, [3, 3], level=1)
    # Climate Silo (3×3)
    add_building("climate_silo", 12, 20, [3, 3], level=1)

    return buildings

# ---------------------------------------------------------------------------
# Market inventory — various grades in storage
# ---------------------------------------------------------------------------
def build_inventory():
    inv = []
    # Freshly harvested palay
    inv.append({
        "id": "inv_palay_1",
        "crop": "palay",
        "quantity": 840,
        "grade": "A",
        "freshness": 92.0,
        "is_cold_storage": False
    })
    inv.append({
        "id": "inv_palay_2",
        "crop": "palay",
        "quantity": 520,
        "grade": "B",
        "freshness": 78.0,
        "is_cold_storage": False
    })
    # Sugarcane harvested
    inv.append({
        "id": "inv_cane_1",
        "crop": "sugarcane",
        "quantity": 480,
        "grade": "A",
        "freshness": 88.0,
        "is_cold_storage": True
    })
    # Yellow corn
    inv.append({
        "id": "inv_corn_1",
        "crop": "yellow_corn",
        "quantity": 320,
        "grade": "B",
        "freshness": 82.0,
        "is_cold_storage": False
    })
    # Coffee in cold storage
    inv.append({
        "id": "inv_coffee_1",
        "crop": "arabica_coffee",
        "quantity": 200,
        "grade": "A",
        "freshness": 96.0,
        "is_cold_storage": True
    })
    # Banana
    inv.append({
        "id": "inv_banana_1",
        "crop": "banana",
        "quantity": 800,
        "grade": "A",
        "freshness": 75.0,
        "is_cold_storage": True
    })
    return inv

# ---------------------------------------------------------------------------
# Price history (7 days for each of the 7 crops)
# ---------------------------------------------------------------------------
def build_price_history():
    base_prices = {
        "palay":         [98, 102, 99, 105, 103, 100, 104],
        "yellow_corn":   [118, 115, 122, 119, 117, 121, 123],
        "sugarcane":     [91,  95,  93,  97,  94,  96,  98],
        "pineapple":     [155, 162, 158, 165, 160, 163, 168],
        "arabica_coffee":[195, 202, 198, 205, 200, 208, 210],
        "banana":        [85,  88,  86,  90,  87,  89,  92],
        "coconut":       [76,  80,  78,  82,  79,  83,  85],
    }
    return {crop: prices for crop, prices in base_prices.items()}

# ---------------------------------------------------------------------------
# Assemble and write the save
# ---------------------------------------------------------------------------
def generate_save():
    now = time.time()
    tiles = build_tiles()
    buildings = build_buildings()
    for b in buildings:
        for dx in range(b['footprint'][0]):
            for dy in range(b['footprint'][1]):
                t = empty_tile(0, 0); t['s'] = BUILDING
                tiles[b['grid_pos'][0]+dx][b['grid_pos'][1]+dy] = t
    inventory = build_inventory()
    price_history = build_price_history()

    # Convert tiles to serializable list-of-lists
    tiles_serial = [[tiles[x][y] for y in range(GRID_H)] for x in range(GRID_W)]

    save_data = {
        "meta": {
            "title": "Cotabato Tycoon — Day 38 (Trailer Demo)",
            "date": "2026-10-30 01:30",
            "timestamp": now,
            "region_key": "cotabato",
            "region_display": "Cotabato Basin (Central Floodplains)",
            "game_mode": "career",
            "game_mode_title": "Career Tycoon",
            "season_days": 60,
            "day": 38,
            "hour": 9,
            "cash": 18750,
            "points": 42800
        },
        "economy": {
            "cash": 18750
        },
        "time": {
            "day": 38,
            "hour": 9,
            "elapsed_seconds": 37 * 180.0 + 9 * 7.5,  # 37 full days + 9 hours
            "is_freeplay_mode": True,
            "speed_scale": 1.0
        },
        "weather": {
            "climate": 0,          # 0 = normal
            "effective_temp": 30.5,
            "effective_hum": 68.0,
            "active_disaster": ""
        },
        "leaderboard": {
            "points": 42800,
            "combo": 4,
            "max_combo": 8,
            "run_units_sold": 6420,
            "run_grade_a": 3850,
            "run_deliveries": 47,
            "highest_single_sale_pts": 1250
        },
        "market": {
            "stored_inventory": inventory,
            "price_history": price_history
        },
        "building_manager": {
            "active_workers": 5,
            "worker_capacity": 5,
            "active_drones": 3,
            "unlocked_techs": [
                "field_survey_kit",
                "combine_harvester",
                "kuliglig_tractor"
            ],
            "unlocked_crops": [
                "palay", "yellow_corn", "sugarcane", "pineapple",
                "arabica_coffee", "banana", "coconut"
            ],
            "buildings": buildings
        },
        "farm_grid": {
            "unlocked_parcels": ["homestead", "east_meadows", "south_plains"],
            "world_seed": 13337,
            "tiles": tiles_serial
        },
        "farmer": {
            "pos": [320.0, 256.0]
        }
    }

    # Godot saves to user:// which on Windows maps to:
    # %APPDATA%\Godot\app_userdata\<project_name>\saves\
    # For Agri-Region Tycoon the project name is read from project.godot
    appdata = os.environ.get("APPDATA", "")
    project_name = "Agri-Region Tycoon"  # default guess, will also print the path

    candidates = [
        os.path.join(appdata, "Godot", "app_userdata", project_name, "saves"),
        os.path.join(appdata, "Godot", "app_userdata", "agri-region-ai-version", "saves"),
        os.path.join(appdata, "Godot", "app_userdata", "agri-region-tycoon", "saves"),
    ]

    # Also output alongside the script for inspection
    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_inspect = os.path.join(script_dir, "demo_save_slot1.json")
    with open(out_inspect, "w", encoding="utf-8") as f:
        json.dump(save_data, f, indent="\t", ensure_ascii=False)
    print(f"[OK] Inspection copy: {out_inspect}")

    written_any = False
    for save_dir in candidates:
        if os.path.isdir(save_dir) or os.path.isdir(os.path.dirname(save_dir)):
            os.makedirs(save_dir, exist_ok=True)
            out_path = os.path.join(save_dir, "slot_1.json")
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(save_data, f, indent="\t", ensure_ascii=False)
            print(f"[OK] Written to Godot user://saves/ → {out_path}")
            written_any = True
            break

    if not written_any:
        print("[WARN] Could not locate Godot user:// saves directory.")
        print("       Please copy demo_save_slot1.json manually to:")
        for c in candidates:
            print(f"         {c}\\slot_1.json")

    print(f"\nSave snapshot:")
    m = save_data["meta"]
    print(f"  Region   : {m['region_display']}")
    print(f"  Mode     : {m['game_mode_title']}")
    print(f"  Day/Hour : Day {m['day']}, {m['hour']}:00")
    print(f"  Cash     : PHP {m['cash']:,}")
    print(f"  Points   : {m['points']:,}")
    print(f"  Workers  : {save_data['building_manager']['active_workers']}")
    print(f"  Drones   : {save_data['building_manager']['active_drones']}")
    print(f"  Parcels  : {save_data['farm_grid']['unlocked_parcels']}")
    print(f"  Buildings: {len(buildings)}")
    print(f"  Inventory: {sum(i['quantity'] for i in inventory):,} units")

if __name__ == "__main__":
    generate_save()


