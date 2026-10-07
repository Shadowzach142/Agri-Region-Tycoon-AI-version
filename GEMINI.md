# Agri-Region Tycoon — AI Context File
> **Purpose**: This file is the SINGLE SOURCE OF TRUTH for any AI session. Read this first and **do NOT individually re-read files** unless you need a specific line number. Update this file at the end of every session
> **Last Updated**: 2026-10-07 (Session 65 — Integration of Custom Pixel-Art Building Sprites & Dynamic Silo Fill Levels)

---

## 1. Project Overview

| Setting | Value |
|---------|-------|
| **Engine** | Godot 4.7.2 (GL Compatibility, D3D12 on Windows) |
| **Resolution** | 1280×720, `canvas_items` stretch, `expand` aspect |
| **Pixel Art** | `default_texture_filter=0` (nearest-neighbor — NEVER change) |
| **Texture per node** | `texture_filter = 1` on every Sprite2D/TextureRect in `.tscn` |
| **Font** | `res://assets/font/quill_and_antler/quill-and-antler.ttf` (Quill & Antler pixel font) |
| **Entry** | `res://scenes/MainMenu.tscn` → `res://scenes/MainGame.tscn` |
| **Theme** | Philippine farm tycoon, isometric 24×24 grid (12×12 homestead + buyable 12×12 parcels) |
| **Godot exe** | `C:\Users\ADMIN\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` |

---

## 2. Canonical File Map

```
agri-region-ai-version/
├── GEMINI.md                              ← YOU ARE HERE — read this, not individual files
├── project.godot
├── autoload/                              ← Singletons registered in project.godot
│   ├── AudioManager.gd                    ← Polyphonic sound pool, pitch jitter, UI/Farmer/Building SFX
│   ├── Data.gd                            ← REGIONS, CROPS, PESTS, BUILDINGS, LAND_PARCELS dicts
│   ├── TimeManager.gd                     ← Day/hour ticks + speed modes
│   ├── EconomyManager.gd                  ← cash: int, add_cash(), deduct_cash() → bool
│   ├── TaskManager.gd                     ← task_queue, selected_farmers, add_task(), has_task_at()
│   ├── WeatherManager.gd                  ← climate, disaster countdown/strike/clear signals
│   ├── PestManager.gd                     ← pest spawning & treatment
│   ├── MarketManager.gd                   ← stored_inventory, add_harvest_to_storage(), sell_batch()
│   ├── BuildingManager.gd                 ← placed_buildings, register_building(), has_tech(), has_cold_storage()
│   ├── LogManager.gd                      ← log_event(category, msg, icon, color, details?)
│   └── LeaderboardManager.gd              ← End-game PvE points, rival rankings, streaks, Hall of Fame
├── scenes/
│   ├── MainMenu.tscn / MainMenu.gd
│   ├── MainGame.tscn                      ← Root scene (see §4 for full hierarchy)
│   └── MainGame.gd                        ← Spawns PauseMenu + BacklogPanel + LeaderboardPanel + optional AdminPanel
├── src/
│   ├── core/                              ← Farm simulation engine
│   │   ├── FarmTile.gd                    ← class_name FarmTile (TileState enum, QualityGrade enum, multi-tile root)
│   │   ├── FarmGrid.gd                    ← 24×24 isometric grid, parcels, input, 2×2 multi-tile planting & harvesting
│   │   ├── TileRenderer.gd                ← 2.5D visual updates, 2×2 coconut grove & sugarcane procedural rendering
│   │   ├── TileAgronomySystem.gd          ← Crop growth/harvest math, quality grading
│   │   ├── GroundTileSprites.gd           ← Resource: maps TileState → PNG texture (see §Ground Sprites)
│   │   └── Utils.gd                       ← Autoload singleton: format_number(), Grade enum
│   ├── world/                             ← World/environment systems
│   │   ├── WeatherEffects.gd              ← Rain/drought/night particle effects + CanvasModulate
│   │   ├── GameCamera.gd                  ← WASD + drag camera
│   │   └── DragSelectOverlay.gd           ← Marquee box draw
│   ├── farmer/                            ← Worker character system
│   │   ├── Farmer.gd                      ← Worker CharacterBody2D (variable harvest duration per crop)
│   │   ├── FarmerMovement.gd              ← Isometric pathfinding
│   │   └── FarmerStateMachine.gd          ← Worker AI states
│   ├── drone/                             ← Autonomous precision agriculture
│   │   └── FarmDrone.gd                   ← class_name FarmDrone (patrol, auto plow/plant/harvest, zone overlay)
│   ├── buildings/                         ← Building placement & management
│   │   ├── Building.gd                    ← Placed building node (class_name Building)
│   │   ├── BuildingCardPopup.gd           ← Building info popup
│   │   └── BuildingPlacementOverlay.gd    ← Ghost preview while placing
│   ├── ui/                                ← HUD and all overlay panels
│   │   ├── HUD.gd                         ← Dynamic node-discovery HUD (see §5)
│   │   ├── PlantHotbar.gd                 ← Minecraft-style minimalist square hotbar & snappy hover tooltips (no background, square boxes, flyout selector)
│   │   ├── TileInfoPanel.gd               ← Bottom-left tile inspector (2×2 grove & perennial indicators)
│   │   ├── TileActionPopup.gd             ← Right-click context menu (decluttered active seed + hotbar opener)
│   │   ├── EarlyHarvestModal.gd           ← Tactical early harvest confirmation popup (explaining premature yield penalties vs disaster rescue)
│   │   ├── LandExpansionModal.gd          ← Territory Deed purchase modal
│   │   ├── AdminPanel.gd                  ← Debug panel (backtick key)
│   │   ├── BacklogPanel.gd                ← Farm Chronicle log panel (spawned dynamically)
│   │   ├── LeaderboardPanel.gd            ← PvE Regional League standings & Hall of Fame modal (J/T key)
│   │   └── PauseMenu.gd                   ← ESC pause overlay (spawned dynamically)
│   └── market/                            ← Economy & trade UI
│       ├── MarketChart.gd                 ← 7-day stock line chart custom Control
│       ├── MarketPanel.gd                 ← Regional commodity market dashboard (all 7 crops)
│       ├── SellPanel.gd                   ← Bodega sales desk (group by crop, buyer select)
│       └── ShopPanel.gd                   ← Agri-Shop (buildings, machinery, workers, land)
└── assets/
    ├── sprites/
    │   ├── crops/                         ← ★ CUSTOM CROP SPRITES (README.md guide, 1×1 & 2×2 specs)
    │   ├── buildings/                     ← ★ CUSTOM BUILDING SPRITES (KUBO.png, DRYER-BARE.PNG)
    │   ├── ground/                        ← ★ CUSTOM GROUND SPRITES (see §Ground Sprites)
    │   │   ├── README.md                  ← Artist guide: tile sizes, slot names, fallback rules
    │   │   ├── ground_tile_sprites.tres   ← Resource linking PNGs
    │   │   └── ground_*.png               ← 128×64px RGBA PNGs
    │   ├── hud/                           ← HUD frame & button NinePatch sprites
    │   │   ├── TopBar/                    ← Disaster-box.png, hud-upper mid.png, Button (brown-button, yellow-button)
    │   │   └── Buttons/                   ← Brownbutton, GoldButton, Lightbutton, Arrows
    │   └── obstacles/                     ← Obstacle sprite sheets
    ├── icons/
    │   ├── Farmer icon.png
    │   ├── Sun.png
    │   └── Moon.png
    └── font/
        └── quill_and_antler/              ← Quill & Antler pixel font (TTF)
```

---

## 3. Autoloads — Signals & Key API

### AudioManager
```gdscript
signal sfx_played(sound_name: String)

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var ui_volume: float = 0.85
var is_muted: bool = false

func play_sfx(sound_name: String, pitch_jitter: float = 0.06, volume_offset_db: float = 0.0) -> void
func play_ui(sound_name: String) -> void       # click, hover, error, pause, tile_select
func play_farmer(action_name: String) -> void  # assign, chop, harvest, plant, plow, select, spray, water
func play_building(event_name: String) -> void # place, complete, loop
func register_active_construction() -> void
func unregister_active_construction() -> void
func start_build_loop() -> void
func stop_build_loop() -> void
```

### EconomyManager
```gdscript
signal cash_changed(amount: int)
var cash: int = 250   # Starting cash
func add_cash(amount: int) -> void
func deduct_cash(amount: int) -> bool  # returns false if insufficient
```

### TimeManager
```gdscript
signal day_changed(day: int)
signal hour_changed(hour: int)
signal period_changed(period_name: String, is_night: bool)
signal season_ended(target_days: int, final_score: int)

var is_freeplay_mode: bool = false
const DAY_SECONDS: float = 180.0  # 3 minutes per 24-hr day at 1x (7.5s per in-game hour)
const STARTING_HOUR: int = 7     # 07:00 AM bright morning daylight
func get_speed_scale() -> float  # 0 = paused, 1x/2x/3x
func get_ambient_color() -> Color
func is_night() -> bool
func is_dusk() -> bool
func is_dawn() -> bool
func get_time_period_name() -> String
func enable_freeplay() -> void
```

### WeatherManager
```gdscript
signal weather_changed(temperature: float, humidity: float)
signal disaster_warning(hazard_type: String, countdown_seconds: float)
signal disaster_struck(hazard_type: String)
signal disaster_cleared(hazard_type: String)

var incoming_disaster: String = ""
var disaster_countdown: float = 0.0    # counts DOWN from 5.0 seconds
var active_disaster: String = ""

func trigger_disaster(hazard_type: String, countdown: float = 5.0) -> void
```

### BuildingManager
```gdscript
signal building_placed(building: Node)
signal building_purchased(building_type: String)
signal worker_hired(total_workers: int)
signal worker_capacity_changed(total_capacity: int, active_workers: int)
signal storage_updated(total_capacity: int, used_capacity: int)
signal tech_unlocked(tech_id: String)
signal sprinklers_updated(active_count: int, capacity: int)

var placed_buildings: Array = []
var total_storage_capacity: int = 200
var worker_capacity: int = 1

func register_building(building: Node) -> void
func unregister_building(building: Node) -> void
func get_building_at_tile(pos: Vector2i) -> Node   # null if empty
func is_tile_occupied_by_building(pos: Vector2i) -> bool
func recalculate_bonuses() -> void
func has_tech(tech_id: String) -> bool
func buy_tech(tech_id: String) -> bool
func get_drone_level() -> int                      # 0=none, 1=plow, 2=plant, 3=harvest
func has_cold_storage() -> bool
func get_sprinkler_capacity() -> int               # 0 without tower, 6 at Lv.1, 16 at Lv.2, 999 at Lv.3
func get_active_sprinkler_count() -> int
func can_place_sprinkler() -> bool
func get_sprinkler_radius() -> int                 # 1 = 3x3 diamond (Lv.1), 2 = 5x5 diamond (Lv.2+)
func is_tile_covered_by_sprinkler(pos: Vector2i) -> bool
func get_covering_sprinkler(pos: Vector2i) -> Node
func get_worker_speed_multiplier() -> float        # 1.0 baseline, 1.8x kuliglig, 3.5x combine
```

### MarketManager
```gdscript
signal inventory_changed()
signal price_updated(crop: String, price: float)
signal sale_completed(crop: String, revenue: int, net_profit: int, hub_name: String, rot_loss: float)

var stored_inventory: Array = []  # [{id, crop, quantity, grade, freshness, is_cold_storage}]
var price_history: Dictionary = {} # crop -> Array[float] of last 7 daily prices

func add_harvest_to_storage(crop: String, quantity: int, grade: String, freshness: float) -> void
func process_hourly_spoilage() -> void
func get_benchmark_price(crop: String) -> float
func get_price_history(crop: String) -> Array
func get_price_change(crop: String) -> Dictionary # { current, previous, diff, percent, is_up }
func get_stored_units_for_crop(crop: String) -> int
func sell_stored_batch(batch_index: int, hub_id: String) -> bool
```

### TaskManager
```gdscript
signal selection_changed(selected_workers: Array)
var task_queue: Array = []
var selected_farmers: Array = []

func add_task(task: Dictionary) -> void  # {type, position, crop_type?}
func has_task_at(pos: Vector2i, type: String = "") -> bool
func get_next_task_for_farmer(farmer_pos: Vector2i) -> Dictionary
func get_selected_farmers() -> Array
func get_task_count() -> int
```

### LogManager
```gdscript
signal log_added(entry: Dictionary)
signal logs_cleared()
func log_event(category: String, message: String, icon: String, color: Color, details: String = "") -> void
```

### LeaderboardManager
```gdscript
signal points_changed(total_points: int, points_added: int, reason: String)
signal new_personal_best(new_score: int, old_score: int)
signal run_recorded(entry: Dictionary)

var current_points: int = 0
var personal_best: int = 0
var current_combo: int = 0

func calculate_sale_points(crop_name: String, quantity: int, grade: String, arrival_freshness: float, hub_id: String) -> Dictionary
func record_sale(crop_name: String, quantity: int, grade: String, arrival_freshness: float, hub_id: String) -> int
func get_combo_multiplier() -> float
func get_tycoon_tier(score: int) -> Dictionary
func get_personal_best() -> int
func get_personal_leaderboard() -> Array
func save_current_run(title: String = "") -> Dictionary
func load_personal_leaderboard() -> Array
func reset_current_run() -> void
```

### SaveManager
```gdscript
signal save_completed(slot_index: int, success: bool, message: String)
signal load_completed(slot_index: int, success: bool, message: String)
signal slots_updated()

const SAVE_DIR: String = "user://saves/"
const MAX_SLOTS: int = 5
const AUTOSAVE_SLOT: int = 0

func has_save(slot_index: int) -> bool
func get_slot_meta(slot_index: int) -> Dictionary
func get_all_slots_meta() -> Dictionary
func save_game(slot_index: int, slot_name: String = "") -> bool
func load_game(slot_index: int) -> bool
func delete_slot(slot_index: int) -> bool
func has_pending_save_data() -> bool
func apply_pending_save(farm_grid: Node) -> void
```

---

## 4. Data.gd — Static Data Reference

### Regions (Data.REGIONS)
| Key | Display Name | Hazard Focus |
|-----|-------------|--------------|
| `cotabato` | Cotabato Basin | flash_flood 15%, landslide 3%, drought 6% |
| `south_cotabato` | South Cotabato Highlands | flash_flood 8%, landslide 12%, drought 5% |
| `sarangani` | Sarangani Littoral Coast | flash_flood 5%, landslide 2%, drought 14% |
| `sultan_kudarat` | Sultan Kudarat Valley | flash_flood 9%, landslide 3%, drought 8% |
| `general_santos` | General Santos City | flash_flood 6%, landslide 2%, drought 10% |

`Data.current_region` (default: `"cotabato"`) set by MainMenu.

### Crops (Data.CROPS) — Rebalanced Agronomy & Multi-Tile Systems
| Key | Display | Footprint | Type | Growth | Regrowth | Moisture | Seed Cost | Base Price | Yield | Harvest Speed |
|-----|---------|-----------|------|--------|----------|----------|-----------|------------|-------|---------------|
| `palay` | Palay (Rice) | 1×1 | Annual | 15d | — | 70–90% | ₱25 | ₱100 | 100 | 1.0s |
| `yellow_corn` | Yellow Corn | 1×1 | Annual | 25d | — | 30–60% | ₱30 | ₱120 | 100 | 1.1s |
| `sugarcane` | Sugar Cane | 1×1 | Annual | 28d | — | 50–80% | ₱30 | ₱95 | 120 | 1.4s |
| `pineapple` | Smooth Cayenne Pineapple | 1×1 | Annual | 35d | — | 35–65% | ₱40 | ₱160 | 100 | 1.3s |
| `arabica_coffee` | Arabica Coffee | 1×1 | Perennial | 40d | 14d | 35–70% | ₱50 | ₱200 | 100 | 1.3s |
| `banana` | Cavendish Banana | 2×2 | Perennial | 50d | 18d | 55–85% | ₱140 (₱35×4) | ₱90 | 400 | 2.2s |
| `coconut` | Tall Coconut Palm | 2×2 | Perennial | 50d | 16d | 40–75% | ₱160 (₱40×4) | ₱80 | 400 | 2.4s |

**Perennial Agronomy**: Harvesting annual crops (`palay`, `yellow_corn`, `sugarcane`, `pineapple`) resets the tile to `EMPTY`. Harvesting perennial plants (`arabica_coffee`, `banana`, `coconut`) leaves the plant standing in `GROWING` state at `1.0 - (regrowth_days / growth_days)` progress without requiring seed re-purchase or re-planting.

**2×2 Multi-Tile Crops**: Coconut Palm occupies a 2×2 diamond (4 plots). The root plot `(x, y)` manages state, agronomy, and visuals, syncing to child plots `(x+1, y)`, `(x, y+1)`, `(x+1, y+1)`. Harvesting any plot in the grove harvests the entire grove and deposits 400 units into storage.

### Crop Stage Sprites & Withering System (`assets/sprites/Field/Crops/`)
Pixel-art sprite sequences for all 7 crops rendered in 2.5D isometric perspective (scaled 4× with nearest-neighbor filtering, soft drop shadows, and automatic baseline alignment to the tile diamond):

| Crop Key | Subdirectory | File Prefix | Growth Stages | Withering Stages |
|---|---|---|---|---|
| `palay` | `Rice/` | `RICE-P` | P1 (Seedling), P2 (Vegetative), P3 (Harvestable) | P4 (Pest/Stress), P5 (Flooded/Dead) |
| `yellow_corn` | `Corn/` | `CORN-P` | P1 (Seedling), P2 (Vegetative), P3 (Harvestable) | P4 (Pest/Stress), P5 (Flooded/Dead) |
| `sugarcane` | `Sugarcane/` | `SUGARCANE-P` | P1 (Sprouts), P2 (Stalks), P3 (Harvestable) | P4 (Pest/Stress), P5 (Flooded/Dead) |
| `pineapple` | `Pineapple/` | `PINEAPPLE-P` | P1 (Crown/Shoot), P2 (Vegetative), P3 (Harvestable) | P4 (Pest/Stress), P5 (Flooded/Dead) |
| `arabica_coffee` | `Coffee/` | `COFFEE-P` | P1 (Seedling), P2 (Bush), P3 (Harvestable) | P4 (Pest/Stress), P5 (Flooded/Dead) |
| `banana` | `Banana/` | `BANANA-P` | P1 (Shoot), P2 (Young), P3 (Flowering), P4 (Mature Bunch) | P5 (Pest/Stress), P6 (Dead Stalk) |
| `coconut` | `Coconut/` | `COCONUT-P` | P1 (Nut Sprout), P2 (Young Palm), P3 (Mature 2×2 Tree) | P4 (Pest/Stress), P5 (Barren/Dead) |

**Stage Determination Rules**:
- **Banana**: Stages 1–4 are growth stages (`growth_progress` thresholds: <0.25 → P1, 0.25..0.65 → P2, 0.65..1.0 → P3, >=1.0 → P4). Stages 5–6 are withering stages (P5 = pest infestation or stress health < 0.40; P6 = flooded or terminal health <= 0.18).
- **General Crops**: Stages 1–3 are growth stages (<0.30 → P1, 0.30..1.0 → P2, >=1.0 → P3). Stages 4–5 are withering stages (P4 = pest infestation or stress health < 0.40; P5 = flooded or terminal health <= 0.18).
- **HUD & Hotbar Icons**: Use the mature growth stage (P3 for general crops, P4 for Banana) rendered in `PlantHotbar.gd` (`CROP_ICONS`).

### Game Modes (Data.GAME_MODES)
- `campaign`: "TIMED PVE CAMPAIGN" — Competitive 30d/60d/90d score attack with RTS season countdown, leaderboard rankings, and prestige tiers.
- `career`: "CAREER / ENDLESS TYCOON" — Persistent sandbox builder with unlimited days, midnight autosaves, and full in-game save/load across 5 slots.

### Campaign Duration Modes (Data.SEASON_MODES)
- `30`: 30 Days (Quick Sprint / 1 Month)
- `60`: 60 Days (Standard Campaign / 2 Months) — **Default**
- `90`: 90 Days (Full Quarter / 3 Months)
Controlled via `Data.selected_season_days` configured on MainMenu.

### Pests (Data.PESTS)
| Key | Trigger | Treatment |
|-----|---------|-----------|
| `kuhol` | moisture > 80 | ₱30 |
| `armyworm` | moisture < 35 | ₱40 |
| `fusarium_wilt` | humidity high | ₱45 |
| `rice_black_bug` | late season | ₱35 |

### Land Parcels (Data.LAND_PARCELS) — Array of Dicts
```gdscript
# Each parcel: {id, name, cost, rect: Rect2i, description}
# "homestead" → Rect2i(0, 0, 10, 10)  ← always unlocked (starting parcel)
# Additional parcels: north, south, east, west quadrants of the 20×20 grid
```
API:
```gdscript
func get_parcel(id: String) -> Dictionary
func get_parcel_for_tile(pos: Vector2i) -> Dictionary   # {} if not found
```

---

## 5. FarmGrid.gd — Key State & API

```gdscript
const GRID_SIZE: Vector2i = Vector2i(20, 20)
var unlocked_parcels: Array[String] = ["homestead"]  # starts with homestead only
var tiles: Array = []     # tiles[x][y] → FarmTile

func is_tile_unlocked(pos: Vector2i) -> bool
# Returns true if pos belongs to any parcel in unlocked_parcels AND tile.state != LOCKED
# (Always check this before ANY farm action on a tile)

func unlock_parcel(parcel_id: String) -> void   # called after purchasing a deed
func _get_drag_rect_tiles(...) -> Array          # only returns unlocked tiles
func _on_action_popup_selected(...)              # guards: if not is_tile_unlocked → return
func _on_batch_action_selected(...)              # guards: if not is_tile_unlocked → continue
func clear_obstacle(pos)                         # respects parcel lock; LOCKED tiles → stay LOCKED
func _process_landslide_impact()                 # skips locked tiles
func _process_flood_impact()                     # operates on all tiles (floods bypass lock)
func _process_drought_impact()                   # operates on all tiles
func _process_heatwave_impact()                  # operates on all tiles
```

### Isometric Conversion
```gdscript
# Origin: Vector2(640, 160)
# Tile: 64px wide, 32px tall (2:1 isometric)
grid_to_screen(x, y) = origin + Vector2((x - y) * 32, (x + y) * 16)
screen_to_grid(pos)  = inverse
# Uses FarmerMovement.pixel_to_grid(global_pos, farm_grid_node)
```

---

## 6. FarmTile.gd — Class Reference

```gdscript
class_name FarmTile
enum TileState {EMPTY, PLOWED, PLANTED, GROWING, HARVESTABLE, INFECTED, FLOODED, OBSTACLE, BUILDING, LOCKED}
enum QualityGrade {A, B, C}

var state: int             # TileState
var soil_moisture: float   # 0–100
var heat_index: float      # Celsius
var crop_type: String      # "" if empty
var obstacle_type: String  # "tree" | "pine" | "trunk" | "rock"
var building_ref: Node     # reference to occupying Building node (or null)
var growth_progress: float # 0.0–1.0
var health: float          # 0.0–1.0
var quality: int           # QualityGrade
var yield_quantity: int    # 100 default
var freshness: float       # 100.0
var pest_type: String      # "" if none
var soil_fertility: float  # 1.0 default

func reset() -> void       # resets all fields, does NOT set state (caller must set state after)
```

---

## 7. MainGame.tscn — Scene Hierarchy

```
MainGame (Node2D)
├── WorldBackground (ColorRect, z=-100)
├── FarmBorderPath (ColorRect, z=-50, invisible)
├── GameCamera (Camera2D) [script=GameCamera.gd]
├── FarmGrid (Node2D, y_sort=true) [script=FarmGrid.gd]
├── Farmer (CharacterBody2D) [script=Farmer.gd]
├── TileActionPopup (PopupMenu) [script=TileActionPopup.gd]
└── HUDLayer (CanvasLayer) [script=HUD.gd]
    └── Control (full rect, mouse_filter=IGNORE)
        ├── RegionWeatherBox (Control, size=227×123, draggable, texture=Region-climate-humidity.png)
        │   ├── Background (TextureRect, nearest-neighbor, texture_filter=1)
        │   ├── RegionCapsule (Control, top scrollbar) → RegionLabel (font_size=14, hover card trigger)
        │   ├── WeatherLabel (bottom-left parchment, climate & temp)
        │   ├── HumidityLabel (bottom-right parchment, relative humidity)
        │   └── DisasterLabel (bottom margin, emergency countdown)
        ├── DayNightBox (Control, size=224×87, draggable, right side of region name box at offset=(226, -2), texture=DaynNight-Time.png)
        │   ├── Background (TextureRect, nearest-neighbor, texture_filter=1)
        │   ├── DayLabel (left parchment box, day cycle progress)
        │   └── TimeRow (HBox, right parchment box)
        │       ├── TimeIcon (TextureRect, Sun.png / Moon.png, texture_filter=1)
        │       └── TimeLabel (font_size=11, current time)
        ├── SpeedPanel (PanelContainer, style=HudUpperMid.tres, centered top)
        │   └── SpeedBar (HBox)
        │       ├── PauseButton (style=TopBarButtonBrown/Yellow)
        │       ├── Speed1xButton (style=TopBarButtonBrown/Yellow)
        │       ├── Speed2xButton (style=TopBarButtonBrown/Yellow)
        │       └── Speed3xButton (style=TopBarButtonBrown/Yellow)
        ├── DisasterBox (Control, size=224×87, texture=Disaster-box.png, centered top below SpeedBar)
        │   ├── Background (TextureRect, nearest-neighbor, texture_filter=1)
        │   ├── TitleLabel (warning title & live countdown)
        │   └── SubLabel (tactical disaster advice, smooth tween fade in/out)
        ├── RightCluster (HBox, layout_mode=0, top-right)
        │   ├── WorkerCapsule (PanelContainer, style=BrownBox.tres)
        │   │   └── HBox → TextureRect(farmer icon, texture_filter=1), WorkerLabel
        │   ├── StorageCapsule (PanelContainer, style=BrownBox.tres)
        │   │   └── HBox → StorageLabel, StorageBar(hidden ProgressBar)
        │   ├── CashCapsule (PanelContainer, style=BrownBox.tres)
        │   │   └── HBox → CashLabel
        │   ├── TaskCapsule (PanelContainer, style=BrownBox.tres, hidden)
        │   │   └── TaskLabel
        │   └── SettingsButton (Button, style=TopBarButtonBrown.tres, text="⚙️") → opens PauseMenu
        ├── BacklogButton (Button, style=BrownButton.tres, layout_mode=0 STANDALONE)
        │   └── offset: left=1060, top=560, right=1268, bottom=604
        │   └── text: "📜 BACKLOG (L)" — opens BacklogPanel
        ├── RegionHoverCard (PanelContainer, hidden)
        │   └── VBox → TitleLabel, DescLabel, ProsLabel, ConsLabel
        ├── TileInfoPanel (PanelContainer, style=Clipboard.tres, size=474×266, bottom-left)
        │   [script=TileInfoPanel.gd]
        ├── CommandCorner (VBox, layout_mode=0, bottom-right)
        │   ├── MarketButton (style=BrownButton.tres) → "📈 COMMODITY MARKET"
        │   ├── SellButton (style=Goldbutton.tres) → "🚚 SELL HARVEST"
        │   └── ShopButton (style=BrownButton.tres) → "🏪 AGRI SHOP"
        ├── MarketPanel (PanelContainer, centered, hidden) [script=MarketPanel.gd]
        ├── SellPanel (PanelContainer, centered, hidden) [script=SellPanel.gd]
        └── ShopPanel (PanelContainer, centered, hidden) [script=ShopPanel.gd]
```

**CanvasLayer overlays** (spawned dynamically by MainGame.gd, NOT in tscn):
| Node | Layer | Group | Key |
|------|-------|-------|-----|
| `PauseMenu` | 200 | — | process_mode=ALWAYS |
| `BacklogPanel` | 210 | `"backlog_panel"` | process_mode=ALWAYS |
| `AdminPanel` | 199 | `"admin_mode_enabled"` | backtick key |

---

## 8. HUD.gd — Dynamic Node Discovery & Draggable HUD (CRITICAL)

HUD uses `find_child(name, true, false)` — NEVER hardcode `get_node()` paths.

**Node names that must match exactly in the tscn:**
```
RegionWeatherBox, DayNightBox, DisasterBox, RegionCapsule, RegionLabel, WeatherLabel, HumidityLabel
DayLabel, TimeIcon, TimeLabel, DisasterLabel
PauseButton, Speed1xButton, Speed2xButton, Speed3xButton
WorkerLabel, StorageLabel, StorageBar, CashLabel, TaskLabel
RegionHoverCard, TitleLabel, DescLabel, ProsLabel, ConsLabel
MarketButton, ShopButton, SettingsButton, BacklogButton (or LogButton)
MarketPanel, ShopPanel, TileInfoPanel
```

**To add a new HUD element:**
1. Add `var my_node: NodeType = null` at top of HUD.gd
2. Discover in `_discover_nodes()`: `my_node = find_child("ExactNodeName", true, false)`
3. Connect signals in `_ready()` after discovery

**HUD.gd key vars (current):**
```gdscript
var region_label, weather_label, humidity_label, day_label, time_label, disaster_label: Label
var pause_btn, speed1_btn, speed2_btn, speed3_btn: Button
var worker_label, storage_label, cash_label, task_label: Label
var storage_bar: ProgressBar
var market_btn, shop_btn, settings_btn, log_btn: Button
var market_panel, shop_panel, tile_info_panel: Node
var _disaster_banner: PanelContainer   # dynamically created banner
var _is_counting_down: bool
var _disaster_countdown_remaining: float
```

---

## 9. TileInfoPanel.gd — Display Logic

- **Title**: `"Tile (%d, %d)"` (no 📍 prefix)
- **Quality strings**: `"Grade A"`, `"Grade B"`, `"Grade C"`
- **Pest label color**: `Color(1,1,1)` when healthy (not red)
- **PlantBox**: Uses `PlantBox.tres` (region_rect crops HUD-plantbox lower left.png to Rect2(9,6,137,127))
- **StatusBox**: PanelContainer wrapping Quality + Pest labels with warm parchment StyleBoxFlat

---

## 10. TileActionPopup.gd — Batch Safety

`open_for_batch` (as of Session 4):
1. Iterates `target_tiles`, skips any with `tile.state == FarmTile.TileState.LOCKED`
2. If zero unlocked tiles → early return (no popup shown)
3. Header shows `batch_tiles.size()` (locked tiles excluded from count)
4. Fallback "Plow Soil (All N Tiles)" only shows if `batch_empty_or_flooded.size() > 0`

`open_for_tile` (single tile):
- LOCKED state → shows parcel name/cost + "🔓 Unlock" option only
- `_on_action_popup_selected` guards: `if not is_tile_unlocked(tile_pos): return`

---

## 11. Building System

| Property | Detail |
|----------|--------|
| Footprint | `Vector2i(2,2)` default, defined per building in `Data.get_building()` |
| States | `CONSTRUCTING → ACTIVE → UPGRADING` |
| Levels | 1–3 (per building) |
| Construction | Real-time seconds scaled by TimeManager speed |
| Worker housing | Building with `"provides_worker_slot": true` (e.g., Bahay Kubo) |
| Storage | Building with `"storage_limit": N` adds to BuildingManager.total_storage_capacity |
| Registration | `BuildingManager.register_building(building)` on placement |
| **Starter Buildings** | **Bahay Kubo** at `(0, 0)` (Lv. 1, 1 worker slot) + **Grain Silo Compound** at `(2, 0)` (Lv. 1, 200 storage, 2×2 footprint, flush together along top-right edge with 0 unused space) |

**LogManager calls for building events:**
```gdscript
# complete_construction → "buildings", "🏛️", Color(0.35, 0.80, 1.00)
# start_upgrade        → "buildings", "⬆️", Color(0.70, 0.85, 1.00)
# complete_upgrade     → "buildings", "⭐", Color(1.00, 0.85, 0.30)
# demolish             → "buildings", "💥", Color(0.90, 0.40, 0.30)
```

---

## 12. Weather & Disaster System

### Flow
```
WeatherManager._check_for_disaster(day)
  → trigger_disaster("flash_flood", 5.0)
    → emits disaster_warning("flash_flood", 5.0)   ← HUD shows countdown banner
    → after 5 real seconds: _strike_disaster("flash_flood")
      → emits disaster_struck("flash_flood")       ← FarmGrid._process_flood_impact()
      → WeatherEffects plays rain particles
      → after 10s: disaster_cleared emitted
```

### Disaster Impact Functions (FarmGrid.gd)
| Function | Survival Chance | Bonus Techs |
|----------|----------------|-------------|
| `_process_flood_impact()` | 55% base | +20% drip_irrigation, +15% if moisture<80 |
| `_process_drought_impact()` | 65% base | +25% yellow_corn/coconut, +20% drip_irrigation |
| `_process_heatwave_impact()` | 70% base | varies |
| `_process_landslide_impact()` | N/A — deposits OBSTACLE tiles | skips LOCKED parcels |

### Important: Flood vs. Lock
- `_process_flood_impact()` and `_process_drought_impact()` affect **all tiles regardless of parcel lock** (floods don't care about property lines)
- `_process_landslide_impact()` **skips locked parcels** (debris only lands on owned land)
- `clear_obstacle(pos)` after clearing: sets EMPTY if unlocked, LOCKED if still in locked parcel

---

## 12b. Day/Night Cycle Architecture

### Time & Atmosphere Flow
- **Starting Time**: Game starts at **07:00 AM** in clear, radiant morning sunlight (`STARTING_HOUR = 7`), allowing players to immediately see and inspect their farm, crops, and buildings upon starting.
- **Continuous 24-hr Gradient**: `TimeManager.get_ambient_color()` interpolates across 24-hr `AMBIENT_KEYFRAMES` (00:00 luminous midnight blue `Color(0.32, 0.36, 0.60)` → 06:00 golden sunrise `Color(0.96, 0.85, 0.74)` → 07:15 radiant morning sunlight `Color(1.00, 0.98, 0.94)` → 12:00 midday `Color(1.0, 1.0, 1.0)` → 17:30 golden hour `Color(1.0, 0.78, 0.56)` → 18:45 purple dusk `Color(0.65, 0.52, 0.72)`).
- **World CanvasModulate**: `WeatherEffects._canvas_modulate` modulates CanvasLayer 0 (world tiles, trees, buildings, farmer) without dimming CanvasLayer 1 (HUD stays 100% crisp and readable).
- **Nocturnal Particles**: Fireflies (`NightFireflies`) emit across the farm on clear tropical nights.
- **Diurnal Temperatures**: `WeatherManager.get_effective_temperature()` (-6°C at night, -2.5°C at dusk/dawn) and `WeatherManager.get_effective_humidity()` (+18% relative humidity at night).

### Nocturnal Agronomy Mechanics (`TileAgronomySystem.gd`)
- **Evaporation Reduction**: Daytime solar evaporation drops by 80–85% at night (Normal: 0.08/hr vs 0.5/hr; El Niño: 0.35/hr vs 1.5/hr).
- **Dew Condensation**: When relative humidity >= 55%, unflooded soil gathers `+0.20` to `+0.45` moisture/hr from cooling night air.
- **Crop Dark-Cycle Rest**: Growing/planted crops in optimal moisture range without pests recover `+0.015` (1.5%) health/hr during night rest.
- **Nocturnal Pests (`PestManager.gd`)**: Rice Black Bug (*Scotinophara coarctata*) and Golden Apple Snail (*Kuhol*) spawn chance boosted from 0.35 to 0.55 at night.

### Overnight Freight Logistics (`MarketManager.gd` & `SellPanel.gd`)
- **Cool-Air Transit Preservation**: Hauling at night (`TimeManager.is_night()`) avoids daytime road heat, reducing transit rot decay by **40%** (`road_rot *= 0.60`).
- **Night Driver Hazard Surcharge**: Distant highway transit (`tacurong`, `koronadal`, `gensan_port`) adds a **₱25** overtime/hazard lighting fee.
- **Off-Hours Middleman Rate**: Local biyahero applies an off-hours predatory discount (payout multiplier drops from 0.72 to **0.62**).
- **Sell Panel Feedback**: Dynamic subheader banner `"🌙 OVERNIGHT FREIGHT"` and buyer card badges live-updating with night bonuses and driver fees.

### Visual World Touches
- **Bahay Kubo**: Capiz-shell windows light up with warm golden lantern glow; hanging porch gasera lantern emits ambient amber light.
- **Grain Silo**: Auger intake hopper displays an amber work light.
- **Farmer Worker**: Carries a handheld kerosene lantern (*gasera*) with a radial amber aura and brass cage.
- **HUD**: Displays celestial period icons (`🌅` Dawn, `☀️` Day, `🌇` Dusk, `🌙` Night) and displays diurnal effective cooling temperatures.

---

## 13. Land Expansion System

- Grid is **20×20** total. Homestead = top-left 10×10 (always unlocked).
- Additional parcels defined in `Data.LAND_PARCELS` with `Rect2i` bounds.
- Player buys via **Shop Panel → Land tab** or **right-clicking a LOCKED tile**.
- `FarmGrid.unlock_parcel(parcel_id)` → adds to `unlocked_parcels`, re-renders all tiles in that parcel.
- `FarmGrid.is_tile_unlocked(pos) → bool`:
  - Gets parcel via `Data.get_parcel_for_tile(pos)`
  - Returns `false` if parcel not in `unlocked_parcels`
  - Returns `false` if tile.state == LOCKED
  - Returns `true` otherwise

---

## 14. BacklogPanel / Farm Chronicle

| Property | Value |
|----------|-------|
| File | `src/BacklogPanel.gd` |
| Layer | 210 |
| Group | `"backlog_panel"` |
| Toggle | Press `L`, or click "📜 BACKLOG (L)" button |
| ESC | Closes before PauseMenu intercepts |
| Filters | All, 🌾 Crops, 💰 Finance, ⚠️ Hazards, 🏛️ Buildings, 🧑‍🌾 Workers |
| Search | Live keyword filter |

Access: `get_tree().get_first_node_in_group("backlog_panel")`

---

## 15. LogManager — Event Pattern

```gdscript
# Farm actions
LogManager.log_event("crops",     "🚜 Plowed ...",    "🚜", Color(0.72, 0.55, 0.35))
LogManager.log_event("crops",     "🌱 Planted ...",   "🌱", Color(0.45, 0.85, 0.40))
LogManager.log_event("crops",     "💧 Watered ...",   "💧", Color(0.40, 0.70, 0.95))
LogManager.log_event("crops",     "🌾 Harvested ...", "🌾", Color(0.95, 0.85, 0.30))
LogManager.log_event("hazards",   "🧴 Sprayed ...",   "🧴", Color(0.90, 0.75, 0.30))
LogManager.log_event("buildings", "🪓 Cleared ...",   "🪓", Color(0.70, 0.60, 0.45))
LogManager.log_event("buildings", "🏛️ Built ...",    "🏛️", Color(0.35, 0.80, 1.00))
LogManager.log_event("hazards",   "🌊 Flood ...",     "🌊", Color(0.35, 0.70, 1.00))
LogManager.log_event("hazards",   "🌪️ Landslide ..","🌪️", Color(0.80, 0.40, 0.30))
LogManager.log_event("hazards",   "🔥 Heatwave ...", "🔥", Color(1.00, 0.60, 0.20))
```

---

## 16. Ground Sprites & Procedural Generation Engine

### Architecture Overview
The ground sprite system renders authentic 32×32 pixel art tiles (`scale = Vector2(4, 4)` to match 128×64 isometric cells + 32px depth slab) driven by a **state-aware procedural generation engine**:

```
[ FarmTile State & Position (x, y) ]
               │
               ▼
┌──────────────────────────────────────────────┐
│       TileRenderer.gd (_apply_sprite)        │
│    Calls: GroundTileSprites.get_texture()    │
└──────────────────────┬───────────────────────┘
                       │
       ┌───────────────┴───────────────┐
       ▼                               ▼
[ Cultivated / Soil ]           [ Natural Turf / Wilderness ]
(PLOWED, PLANTED, GROWING,       (EMPTY, LOCKED, OBSTACLE)
 HARVESTABLE, BUILDING)                        │
       │                                       ▼
       ▼                        ┌──────────────────────────────┐
  [ Bare Soil ]                 │ Soil Moisture Evaluation     │
  (Loam variants 1..4)          │   Moisture > 70% -> WET      │
       │                        │   Moisture <= 70% -> DRY     │
       │                        └──────────────┬───────────────┘
       │                                       │
       │                         ┌─────────────┴─────────────┐
       │                         ▼                           ▼
       │                   [ Wet Grass ]              [ Light Grass ]
       │                  (DarkGrass 1..4)           (LightGrass 1..4)
       │                         │                           │
       └─────────────────────────┼───────────────────────────┘
                                 │
                                 ▼
              ┌──────────────────────────────────────┐
              │ High-Entropy Spatial Coordinate Hash │
              │  SplitMix hash(x, y, seed, salt)     │
              │  < 30: Clean Base (Var 1)            │
              │  30-54: Blade Tuft (Var 2)           │
              │  55-79: Double Blades (Var 3)        │
              │  80-99: Clover / Flower Accent (Var 4│
              └──────────────────┬───────────────────┘
                                 │
                                 ▼
                     Returns Texture2D (1 of 12)
```

### Sprite Directories (`assets/sprites/ground/`)
1. **`GROUND-Light-Grass/`**: `LightGrass1.png` to `LightGrass4.png` (warm meadow grass; default dry natural terrain).
2. **`GROUND-Dark-Grass/`**: `DarkGrass1.png` to `DarkGrass4.png` (wet grass; active when moisture > 70% or flood).
3. **`GROUND-Bare/`**: `Bare1.png` to `Bare4.png` (tilled soil; pebbles, soil clods, furrows).

### Key Rules & Alignment
- **Natural Turf Clean Base**: No dark grass clumps appear at game start. All dry/normal plots start with light meadow grass.
- **Wet Grass Dynamic Darkening**: As rain falls, storms strike, or irrigation raises soil moisture above 70%, grass automatically transitions into Dark Grass.
- **Deep Wilderness Shading**: LOCKED tiles are tinted with `Color(0.18, 0.23, 0.16, 1.0)` (~20% brightness), creating an unmistakable contrast between the lit 12×12 farm and dark unbought wilderness.
- **Vertical Seam Alignment**: `Bare1..4.png` diamond faces sit 2px lower in pixel art than grass. `TileRenderer.gd` applies `sprite.offset = Vector2(0, -2)` whenever displaying bare ground so isometric grid lines match seamlessly.
- **Auto-Discovery Fallback**: If the `.tres` has empty arrays, `GroundTileSprites.gd` scans and loads the folders automatically at startup. If PNGs are absent, falls back to procedural polygon colors.

---

## 17. End-Game Run Scoring Engine & Personal High Scores

### Overview
The end-game scoring system is designed as a run-against-yourself performance challenge. Players aim to achieve their highest possible score in each playthrough by maximizing crop yield volume, harvest quality, long-haul market logistics, and regional specialization.

### Scoring Formula
$$\text{Total Points} = \text{Base Points} \times \text{Grade Mult} \times \text{Freshness Mult} \times \text{Hub Mult} \times \text{Region Synergy} \times \text{Quality Streak} \times \text{Pristine Bonus}$$

- **Base Crop Points**: Palay: 10, Yellow Corn: 15, Cavendish Banana: 30, Arabica Coffee: 35, Coconut Palm: 60 per unit.
- **Quality Multiplier**: Grade A: 2.5x, Grade B: 1.5x, Grade C: 0.8x.
- **Freshness Multiplier**: $\max(0.1, \text{arrival\_freshness} / 100.0)$. Ruined produce (0% freshness) scores 0 pts.
- **Pristine Bonus**: Deliveries with $\ge 95\%$ arrival freshness gain a $+15\%$ crisp harvest bonus.
- **Market Hub Multiplier**:
  - `local_biyahero`: 1.0x (Instant local middleman, 0 fuel, zero road decay)
  - `tacurong`: 1.35x (Provincial grain mill, 45 km)
  - `koronadal`: 1.75x (Regional wholesale market, 68 km)
  - `gensan_port`: 2.50x (Deep-water export terminal, 135 km — high risk, massive point payoff!)
- **Regional Specialty Synergy**: $+25\%$ bonus points when selling home region's signature harvest (e.g., Cotabato Palay, Matutum Coffee/Corn, Sarangani Coconut/Banana).
- **Quality Streak**: Delivering consecutive Grade A/B harvests with $\ge 70\%$ freshness increases the streak multiplier by $+0.05\times$ per delivery up to $1.5\times$ max. Shipping ruined or Grade C produce resets the streak to $1.0\times$.

### Personal Records & Run Tracking
- **Current Run Live Card**: Compares your current score directly against your all-time Personal Best, showing real-time point gaps and "New Record" alerts.
- **Top 10 Personal Runs**: Saved locally in `user://personal_leaderboard.json` tracking rank, score, region, days survived, and harvest statistics.
- **Save Run Action**: Click "Record Current Run" in the records modal at any point to save your run into your top 10 hall of fame.

### Key Shortcuts & UI
- Hotkeys: `J` or `T` opens the Records modal; `Esc` closes.
- Top-Right HUD displays real-time points & personal best (`PointsCapsule` / `PointsLabel`).
- `LeaderboardButton` (`RECORDS (J)`) located in HUD top-right beneath Backlog button.

---

## 18. Testing Protocol

**Headless parse check** (no GPU, fast — use after ANY code edit):
```powershell
& "C:\Users\ADMIN\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "c:\Users\ADMIN\Documents\agri-region-ai-version" --scene res://scenes/MainGame.tscn --quit-after 50
# Exit code 0 = clean. Any GDScript parse error prints to stdout.
```

**Never run** `extends SceneTree` scripts with `--path` alone — autoloads won't register.  
**Screenshot capture** requires GPU — create a `Node2D` scene with inline script (see §19 gotchas).

---

## 19. Rules & Gotchas (MUST FOLLOW)

| # | Rule |
|---|------|
| 1 | **NEVER push to GitHub** unless explicitly requested |
| 2 | **NEVER create PNG/sprite art files** — user provides all PNGs manually |
| 3 | **NEVER hardcode `get_node()` paths** in HUD.gd — use `find_child()` |
| 4 | **`texture_filter = 1`** on every Sprite2D/TextureRect in `.tscn` files |
| 5 | **BrownBox.tres `content_margin_left`** must stay at `8.0` — 58+ causes stretching |
| 6 | **BacklogButton & LeaderboardButton** are standalone `layout_mode=0` under HUDLayer/Control, NOT inside RightCluster |
| 7 | **SettingsButton (⚙️)** → opens PauseMenu. **BacklogButton (📜)** → opens BacklogPanel. **LeaderboardButton (🏆)** → opens LeaderboardPanel. |
| 8 | **PauseMenu, BacklogPanel, LeaderboardPanel** spawned dynamically by MainGame.gd as CanvasLayers |
| 9 | **`GoldbuttonPresesd.tres`** — typo intentional, do NOT rename |
| 10 | **`HUD-brown button .png`** — trailing space intentional, do NOT rename |
| 11 | When editing `.tscn` files, `unique_id=` values must NEVER be duplicated |
| 12 | `default_texture_filter=0` is global; `texture_filter=1` on a node = nearest-neighbor override |
| 13 | **`->` in PowerShell output** appears as `-\u003e` — display escaping only, not a code bug |
| 14 | **FarmTile.reset()** clears all fields but does NOT set `state` — caller must set state after |
| 15 | **Disasters** affect ALL tiles regardless of parcel lock (except landslides which skip locked) |
| 16 | **TileInfoPanel title**: `"Tile (%d, %d)"` — no emoji prefix |
| 17 | Always run headless parse check after code changes before reporting "done" |
| 18 | **Never use Select-String in PowerShell with Get-Content piped** — it breaks on UTF-8 BOM. Use `view_file` tool instead. |
| 19 | **NEVER take or send screenshots** to the user. Do the work, describe what changed, and let the user test in-engine. No CaptureUI scenes, no screenshot tools. |
| 20 | **UI Typography & Contrast**: On parchment (`Samplebox`, `Shop Backgroud`, `BigPlainBox`), use Deep Mahogany (`Color(0.22, 0.14, 0.08)`) / Espresso (`Color(0.20, 0.12, 0.06)`) — NEVER white/yellow. On dark wood (`BrownBox`, `BrownButton`), use Warm Ivory (`Color(0.96, 0.92, 0.84)`) or Gold (`Color(1.0, 0.88, 0.45)`) — NEVER dark brown. On `Goldbutton.tres`, use Deep Espresso (`Color(0.20, 0.12, 0.06)`). |
| 21 | **Godot 4 Disabled Buttons**: Always override `disabled` style with `BrownButton.tres` and `font_disabled_color = Color(0.65, 0.60, 0.52)` to prevent falling back to engine flat-grey rectangles. |
| 22 | **Clipboard.tres Top Margin**: Metal clip extends 54px; containers using `Clipboard.tres` must set `margin_top >= 64` to prevent header clipping. |

---

## 20. Session History Summary

| Session | What Was Done | Key Files |
|---------|--------------|-----------|
| 1 | Isometric grid conversion | FarmGrid, FarmerMovement, TileRenderer, DragSelectOverlay, Building |
| 1 | Building system (CoC style) | Building.gd, BuildingManager, BuildingCardPopup, BuildingPlacementOverlay, ShopPanel |
| 1 | HUD redesign (dynamic discovery) | HUD.gd, MainGame.tscn |
| 2 | UI texture fix (no blur/stretch) | project.godot, all .tres files, MainGame.tscn |
| 2 | Backlog/Chronicle system | LogManager.gd, BacklogPanel.gd, FarmGrid.gd, Building.gd, HUD.gd, PauseMenu.gd, MainGame.gd |
| 3 | Weather & Disaster System (5s countdown, particles, survival%) | WeatherManager.gd, WeatherEffects.gd, TileAgronomySystem.gd, FarmGrid.gd, HUD.gd, TileRenderer.gd |
| 3 | Expandable Land (10×10 parcels) | Data.gd, FarmTile.gd, FarmGrid.gd, TileRenderer.gd, LandExpansionModal.gd, ShopPanel.gd, TileActionPopup.gd, TileInfoPanel.gd, GameCamera.gd, AdminPanel.gd, Farmer.gd |
| 4 | UI Rework — top-left (RegionWeatherBox) & bottom-left (TileInfoPanel) match reference | UpperLeft.tres, Clipboard.tres, PlantBox.tres, MainGame.tscn, TileInfoPanel.gd |
| 4 | Unbought soil bug fix — locked tiles can't be selected, planted on, or receive obstacles | FarmGrid.gd, TileActionPopup.gd |
| 5 | Separated Market & Sell into 2 distinct HUD buttons: `📈 COMMODITY MARKET` (stock charts & regional prices) + `🚚 SELL HARVEST` (crop-grouped sales desk with 1-click bulk selling & clear net payouts) | MarketManager.gd, MarketChart.gd, MarketPanel.gd, SellPanel.gd, HUD.gd, FarmGrid.gd, GameCamera.gd, MainGame.tscn |
| 6 | Starter farm infrastructure, corner compound & land expansion: placed Bahay Kubo at (0, 0) & Grain Bodega at (2, 0) stuck flush together in the top-right corner with 0 unused space; separated GroundLayer (Z=0) from Y-sorted standing objects (trees & buildings at Z=10); expanded starting homestead to 12×12 (144 plots) and island grid to 24×24; updated camera default zoom to 1.25x for larger, more readable plots | FarmGrid.gd, Building.gd, BuildingManager.gd, Farmer.gd, TileActionPopup.gd, GameCamera.gd, LandExpansionModal.gd, ShopPanel.gd, Data.gd, MainGame.tscn |
| 7 | Conical grain silos storage rework & economic rebalance: replaced oversized bodega warehouse with compact, low-profile Westeel-style corrugated silver grain bins (height reduced 60% from 78px to 27px, low-pitch cone tops, neat isometric row layout matching photo); 4×4 footprint; reduced storage capacity by 500 to 500 units; rebalanced starting cash to ₱250 so Kubo cannot be immediately upgraded without farming; dynamic parcel sizes in TileInfoPanel | Building.gd, Data.gd, BuildingManager.gd, EconomyManager.gd, TileInfoPanel.gd, MainGame.tscn, GEMINI.md |
| 8 | Grain Silo Compound 2×2 footprint conversion & visual tightening: resized footprint to 2×2 (4 plots, matching Bahay Kubo size), adjusted starter placement at (2, 0) flush with Kubo along y=0 edge, replaced full dark slab with a 0.90-scale compacted gravel yard with concrete curb and scaled low-profile Westeel-style silver bins, and updated worker deposit pathing | Data.gd, FarmGrid.gd, Building.gd, TileRenderer.gd, GEMINI.md |
| 11 | Project reorganization & Ground Sprite System: restructured 25 scripts into domain subfolders (src/core/, src/world/, src/farmer/, src/buildings/, src/ui/, src/market/); organized assets into assets/sprites/hud/, assets/sprites/ground/, assets/icons/, assets/font/; stripped brittle UIDs from .tres and scenes; created GroundTileSprites resource system allowing drop-in PNG terrain sprites with automatic procedural fallback | GroundTileSprites.gd, TileRenderer.gd, FarmGrid.gd, project.godot, GEMINI.md |
| 12 | Farmwide rendering & atmospheric screen-layer overhaul ("only certain area showing" fix): fixed visible rectangular weather cutoff box by moving _sky_tint, _rain_particles, and _dust_particles to a dedicated screen-space AtmosphereLayer (CanvasLayer 2, anchors full rect); expanded ground splashes & night fireflies in world space to cover full 24×24 island (3072×1536px); preserved unbought territory darkness with COLOR_LOCKED (Color(0.17, 0.24, 0.14, 0.95)) ensuring unbought land stays distinctly darker than cultivated homestead plots even when rain increases soil moisture above 75% (Color(0.24, 0.44, 0.18)); cleaned up locked tile texture (subtle wilderness weeds without noisy yellow dots); kept unbought land clean until purchased where procedural obstacles then spawn; updated WorldBackground to deep landscape tone; set HUDLayer to layer 10 | WeatherEffects.gd, TileRenderer.gd, FarmGrid.gd, MainGame.tscn, GEMINI.md |
| 13 | HUD Responsive Anchors & Hotkey System ("where is the shop popup"): fixed CommandCorner (Market, Sell, Shop buttons), RightCluster, BacklogButton, and TileInfoPanel having hardcoded top-left layout offsets that pushed buttons completely off-screen on windows <1280×720; converted all HUD edge containers to proper Godot anchors presets (PRESET_BOTTOM_RIGHT, PRESET_TOP_RIGHT, PRESET_BOTTOM_LEFT); added global keyboard shortcuts in HUD.gd (`B` or `P` for Agri-Shop, `M` for Commodity Market, `K` for Sell Harvest, `Esc` to dismiss modal panels) | MainGame.tscn, HUD.gd, GEMINI.md |
| 14 | Shop Graphics Integration & HUD Typography Polish: sliced custom carved-wood Shop background with exact 9-patch margins (26/22/26/22) in Shop Backgroud.tres; made TabContainer panel transparent (`StyleBoxEmpty`) so parchment texture shines through; converted TabBar children to responsive ScrollContainers with custom mahogany/gold tab buttons; added catalog-card styling to all shop items; cleaned up font tofu (`.notdef` square boxes) across HUD by removing missing emoji characters from button texts and status labels; stripped corrupt UTF-8 BOM headers from resource files | Shop Backgroud.tres, MainGame.tscn, ShopPanel.gd, HUD.gd, GEMINI.md |
| 15 | Region Selection Screen & Regional Map Assets: Implemented interactive region selection carousel in MainMenu.tscn & MainMenu.gd with pixel-art left/right arrow buttons; integrated region pixel art backgrounds as full atmospheric backdrops; generated missing general santos location.png (881×571 px) and created transparent Philippine archipelago locator maps (ph_transparent.png, 323×502 px, all outer water & foreign land removed) positioned in the top-right corner; removed left column panorama preview so background art sticks out; centered a semi-transparent dark-glass MiddleCard (78% opacity with carved gold border) focused on regional dossier, pros, and cons; fixed text contrast with 1px black drop-shadows and vibrant high-contrast typography; preserved Admin Mode toggle; dynamic Start button sets Data.current_region and launches MainGame.tscn | scenes/MainMenu.tscn, scenes/MainMenu.gd, assets/Regions Art/*/ph_transparent.png, assets/sprites/hud/Buttons/arrow_*.png, GEMINI.md |
| 16 | Ground Sprite System Implementation: Sized and aligned custom 32×32 pixel art ground tiles (`GROUND-Light-Grass.png`, `GROUND-Dark-Grass.png`, `GROUND-Bare.png`) into isometric terrain rendering pipeline; configured `ground_tile_sprites.tres` mapping; integrated `Sprite2D` nodes inside `GroundLayer` with 4× nearest-neighbor scaling (`Vector2(4, 4)` = 128×64 diamond + 32px 3D depth curb); enabled `y_sort_enabled = true` on `GroundLayer` for seamless front depth curb rendering; automated 2px vertical offset compensation on bare soil sprites (`offset = Vector2(0, -2)`) ensuring pixel-perfect diamond seams; suppressed procedural Line2D grass tufts, furrows, and weed vector clutter when custom sprites are active; preserved 100% procedural fallback for states without sprites (flooded, infected) | src/core/GroundTileSprites.gd, assets/sprites/ground/ground_tile_sprites.tres, src/core/FarmGrid.gd, src/core/TileRenderer.gd, GEMINI.md |
| 17 | End-Game PvE Leaderboard & Scoring Engine: Implemented complete PvE scoring engine factoring crop difficulty, harvest grade (Gr. A 2.5x), freshness, hub logistics (Gensan 2.5x), regional synergy (+30%), and export combo streaks (up to 2.0x); created simulated Mindanao Regional League with 8 agribusiness rivals that dynamically progress daily; added 6 Tycoon Prestige Tiers; built interactive 3-tab LeaderboardPanel (League Standings, Scoring Guide, persistent local Hall of Fame); integrated real-time HUD points capsule and LEADERBOARD (J) button; updated MarketManager and SellPanel with live point previews and delivery rewards | autoload/LeaderboardManager.gd, src/ui/LeaderboardPanel.gd, autoload/MarketManager.gd, src/market/SellPanel.gd, src/ui/HUD.gd, scenes/MainGame.tscn, scenes/MainGame.gd, project.godot, GEMINI.md |
| 18 | Procedural Ground Sprite System Polish (Wet Grass & Dark Wilderness): Removed starting dark grass clumps from initial state — all dry/normal plots now start with cohesive Light Grass variants; repurposed Dark Grass strictly as "wet grass" triggering when soil moisture > 70% (rain, monsoons, watering, flooding); replaced biased variant hashing with a 32-bit SplitMix spatial hash combined with randomized per-run world_seed (~30% base, ~25% tuft 1, ~25% tuft 2, ~20% accents); fixed "locked part of the map is very visible" by deepening locked parcel wilderness modulate from Color(0.68, 0.74, 0.65) (72% luminance) down to Color(0.18, 0.23, 0.16) (21% luminance), creating clear contrast between the player's 12×12 farm and dark unbought wilderness; verified clean execution in Godot 4.7.2 headless | src/core/GroundTileSprites.gd, src/core/TileRenderer.gd, src/core/FarmGrid.gd, assets/sprites/ground/README.md, GEMINI.md |
| 19 | Timed PvE Campaign Modes & Season Results Modal: Added fixed RTS-style season durations with interactive mode selector in MainMenu footer (30d Sprint, 60d Standard default, 90d Full Quarter); rebalanced crop growth days (Palay 15d, Corn 25d, Coffee 40d, Banana 50d, Coconut 55d) making all 5 regional specialties viable within campaign limits; connected Day/Time HUD countdown display ("Day: X/60 (Yd left)"); implemented auto-pausing SeasonResultsModal (Layer 220) triggering at season's end with Tycoon Prestige Tier badges (Mindanao Agro-Tycoon, Hacienda Master, Commercial Grower, Barangay Planter, Subsistence Farmer), comprehensive run statistics (crates exported, Grade A ratio, delivery count, max streak, treasury balance), and 3 action paths (View Hall of Fame, New Campaign, Continue Freeplay) | autoload/Data.gd, autoload/TimeManager.gd, autoload/LeaderboardManager.gd, src/ui/SeasonResultsModal.gd, src/ui/HUD.gd, scenes/MainMenu.gd, GEMINI.md |
| 20 | Game Mode Selection Screen & Save/Load System: Created dedicated Game Mode Selection screen before Region Selection with interactive mode cards: 1) Timed RTS Campaign (score attack sprint, 30d/60d/90d) and 2) Career / Endless Tycoon (persistent farm builder with full save/load support); built SaveManager autoload (user://saves/) handling comprehensive serialization (economy, time, weather, market inventory & prices, building placement & levels, 24×24 tile state array, farmer pos, leaderboard points); created SaveLoadModal (5 manual slots + 1 autosave slot with rich farm previews) accessible from Mode Select ("LOAD SAVED FARM"), bottom menu ("BROWSE ALL SAVED GAMES"), and PauseMenu ("💾 Save Farm", "📂 Load Farm"); added midnight autosave for Career mode; integrated smooth back navigation ("← BACK TO GAME MODES") in Region Selection | autoload/SaveManager.gd, src/ui/SaveLoadModal.gd, src/ui/PauseMenu.gd, scenes/MainMenu.gd, autoload/Data.gd, autoload/TimeManager.gd, src/core/FarmGrid.gd, project.godot, GEMINI.md |
| 21 | Sun & Moon HUD Integration: Sized and integrated custom pixel-art Sun.png and Moon.png into TimeRow inside RegionWeatherBox; added TimeIcon (TextureRect, 18×18px, nearest-neighbor texture_filter=1, KEEP_ASPECT_CENTERED) discovered dynamically by HUD.gd; connected hour_changed and period_changed to dynamically toggle Sun.png during day (05:00–18:59) and Moon.png during night (19:00–04:59); added period name tooltips; verified runtime cycle behavior and headless launch | scenes/MainGame.tscn, src/ui/HUD.gd, assets/icons/Sun.png, assets/icons/Moon.png, GEMINI.md |
| 22 | Storage UI Accumulation Sync & Starter Capacity Balance: Fixed storage UI stuck at 0/500 by implementing MarketManager.get_total_stored_units() and dynamic two-way sync with BuildingManager.used_storage across additions, sales, and save-loads; rebalanced starter Grain Silo capacity from 500 down to 200 units (tight early game holding ~2 plot harvests, upgrades to 400 at Lv. 2); added amber (>=85%) and red (>=100%) HUD color warnings; prevented crop loss by blocking harvesting and warning player when storage is at full capacity | autoload/MarketManager.gd, autoload/BuildingManager.gd, autoload/Data.gd, src/ui/HUD.gd, src/core/FarmGrid.gd, src/ui/TileActionPopup.gd, autoload/SaveManager.gd, scenes/MainGame.tscn, GEMINI.md |
| 23 | Bodega Sales Desk UI Redesign ("too much info yet so little" fix): Fixed unformatted format string bug (%d km • ₱%d Fuel ... Rot %.0f%%); replaced math-heavy text formula clutter and redundant summary boxes with 4 clean, distinct buyer decision cards (Local Middleman, Tacurong Grain Mill, Koronadal Wholesale, Gensan Seaport); added role badges ([Farmgate], [Bulk Mill], [Export Gateway]), unit rate breakdown (₱/unit), prominent bold Net Payout, and clean distance/fuel/spoilage tradeoff lines; streamlined dispatch strip and prominent primary action button; verified clean runtime execution | src/market/SellPanel.gd, GEMINI.md |
| 24 | Two-Step Shipping Selection & Compact Bodega Layout: Eliminated unused vertical space and button clipping by moving crop list to a sleek top horizontal selector bar and reducing modal height to 380px (centered at Y=[-190, 190], leaving 170px clearance on 720p screens); implemented 2-step selection workflow where destination cards display ONLY destination name, distance, and fuel/gas price before selection; selecting a destination dynamically reveals full contract breakdown (Net payout, rate/unit, points, spoilage risk, transit) and enables the prominent Confirm Sale button; verified full end-to-end flow with headless test | src/market/SellPanel.gd, scenes/MainGame.tscn, GEMINI.md |
| 25 | Pause Menu Centering & HUD Record Button Relocation: Fixed pause menu positioning bug where panel spawned offset at (640, 360) and clipped off the bottom of the screen; applied symmetrical offset centering (340×430px, centered at Y=[-215, 215] with 145px top/bottom margin) and 100% opaque background to prevent farm text bleed-through; removed LeaderboardButton (RECORDS (J)) from HUDLayer to declutter the gameplay HUD; added dedicated "🏆 Personal Records (J)" button to PauseMenu to access the leaderboard modal; verified full headless flow | src/ui/PauseMenu.gd, scenes/MainGame.tscn, GEMINI.md |
| 26 | Smooth Cayenne Pineapple Crop & Custom Sprite Hook: Added Pineapple (`pineapple`) matching real-world Mindanao agronomy (South Cotabato/Polomolok DOLE plantation, 35d growth, 35–65% moisture, CAM drought resilience up to 40°C, Phytophthora root rot on prolonged waterlogging, ₱40 seed, ₱160 base price, 25 base pts); integrated into Data.gd, LeaderboardManager.gd (South Cotabato & GenSan synergy), MarketManager.gd, MarketPanel.gd, SellPanel.gd, TileActionPopup.gd (single & batch planting), TileAgronomySystem.gd, AdminPanel.gd; built automated crop sprite loader in TileRenderer.gd that dynamically detects and renders custom PNGs (assets/sprites/crops/ or assets/icons/) with 2.5D scaling and ground shadow, with 100% graceful fallback to 🍍 emoji and procedural stalks; verified with in-engine test runner | autoload/Data.gd, autoload/LeaderboardManager.gd, src/market/MarketPanel.gd, src/ui/TileActionPopup.gd, src/core/TileAgronomySystem.gd, src/core/TileRenderer.gd, src/ui/AdminPanel.gd, assets/sprites/crops/README.md, GEMINI.md |
| 27 | Sugar Cane, 2×2 Multi-Tile Crops & Perennial Regrowth Agronomy: Added Sugar Cane (`sugarcane`, 28d growth, 120 yield, ₱30 seed, ₱95 base price, 1.4s harvest speed, Sultan Kudarat / Cotabato synergy); implemented multi-tile 2×2 crop footprint mechanics with Coconut Palm occupying a 2×2 diamond (4 plots, ₱160 seed cost, 400 yield, 2.4s harvest speed, unified watering, treatment & harvest from any plot in grove); implemented realistic Perennial Plant Agronomy: annual crops (Palay, Corn, Sugarcane, Pineapple) reset plot to EMPTY upon harvest, while perennial crops (Coconut Palm 16d regrowth, Arabica Coffee 14d regrowth, Cavendish Banana 18d regrowth) remain living in GROWING state at high progress without re-buying or replanting; implemented variable worker harvest duration scaling per crop; added procedural 2.5D rendering for tall segmented sugarcane stalks and 2×2 coconut grove palm trees (supporting custom sprite overrides in assets/sprites/crops/sugarcane.png & coconut.png); updated TileInfoPanel, TileActionPopup, AdminPanel, and MarketPanel; verified via automated in-engine test runner and headless parse checks | autoload/Data.gd, autoload/LeaderboardManager.gd, src/core/FarmTile.gd, src/core/FarmGrid.gd, src/core/TileRenderer.gd, src/farmer/Farmer.gd, src/ui/TileActionPopup.gd, src/ui/TileInfoPanel.gd, src/ui/AdminPanel.gd, src/market/MarketPanel.gd, assets/sprites/crops/README.md, GEMINI.md |
| 28 | Direct Tool/Plant Hotbar & Click-Drag Auto-Plow/Plant: Placed hotbar tray directly docked at HUD bottom (removed bottom toggle bar); added Farm Plow & Hoe (`⛏️`) to Slot 1 with 7 crops on Slots 2–8 (hotkeys 1–8); implemented intuitive click-drag farming in `FarmGrid.gd` (`_auto_apply_hotbar_action`): left-clicking or dragging across uncultivated/flooded land with Plow active automatically assigns plow tasks, while left-clicking or dragging across plowed land with a crop active automatically assigns planting tasks; right-click context menu preserved for maintenance (water, IPM spray, harvest, obstacle clearing); dynamic hover card displays stats and Mindanao regional buffs/debuffs; verified with automated headless test suite | src/ui/PlantHotbar.gd, src/core/FarmGrid.gd, src/ui/TileActionPopup.gd, src/ui/HUD.gd, scenes/MainGame.tscn, GEMINI.md |
| 29 | Tool/Plant Hover Overlay, Premature Auto-Planting Fix, & Footprint-Sized Tiling Cursor: Fixed premature auto-planting bug where switching slots in `PlantHotbar.gd` immediately queued planting on previously selected plots; hotbar slot selection now strictly holds the tool/crop without auto-dispatching onto the map; implemented dynamic isometric hover overlay in `DragSelectOverlay.gd` (`_draw_tool_hover`) that follows the mouse cursor with size strictly matching the active item's footprint (1×1 for Plow and standard crops, 2×2 for Coconut, NxM for larger crops); implemented real-time soil validity visualization: individual tiles and outer border render green on valid plowed soil, and red on unplowed soil, obstacles, buildings, or locked land; multi-tile planting enforces plowed soil across all footprint sub-tiles; left-click dragging and single clicks clear batch selection after task assignment; verified 100% headless pass in Godot 4.7.2 | src/ui/PlantHotbar.gd, src/core/FarmGrid.gd, src/world/DragSelectOverlay.gd, GEMINI.md |
| 30 | Farmer-Selection-Bound Hotbar & Click-to-Assign Workflow: Bound `PlantHotbar` visibility strictly to active farmer selection (`visible = false` when no farmer is selected, appears docked when a farmer is clicked in the world); re-clicking the selected farmer toggles selection off and hides the hotbar; added quick-dismiss `✕` button to the hotbar tray header; guarded keyboard shortcuts (1–8) and isometric hover overlays to only activate when a farmer is selected; restricted left-click and marquee-drag auto-action dispatching (`_auto_apply_hotbar_action`) so ground clicks without a selected farmer safely inspect tiles rather than dispatching tasks blindly; integrated right-click context menu auto-worker selection when opening hotbar via "Choose Seed from Hotbar..."; verified 100% pass across all 6 test assertions in Godot 4.7.2 headless | src/ui/PlantHotbar.gd, src/core/FarmGrid.gd, src/world/DragSelectOverlay.gd, src/ui/TileActionPopup.gd, autoload/TaskManager.gd, src/ui/HUD.gd, GEMINI.md |
| 31 | Persistent Green Tile Task Highlights for Plow & Planting: Implemented persistent emerald-green isometric diamond overlays with bright green borders on tiles with pending or active plow and planting tasks; highlights remain cleanly rendered on designated tiles while workers walk to and execute tasks, and vanish immediately upon task completion (revealing freshly plowed soil or planted seedlings); active tasks currently being worked display a brighter emerald border; multi-tile 2×2 Coconut groves properly project the green highlight across all 4 sub-plots; cancelling tasks cleans up highlights immediately; verified 100% pass across all 7 test checks in Godot 4.7.2 headless | autoload/TaskManager.gd, src/farmer/Farmer.gd, src/world/DragSelectOverlay.gd, src/core/FarmGrid.gd, GEMINI.md |
| 32 | Multi-Stage Pixel-Art Crop Sprites & Withering System: Integrated 36 authentic pixel-art crop stage sprites located across `assets/sprites/Field/Crops/` (Banana, Coconut, Coffee, Corn, Pineapple, Rice, Sugarcane) into `TileRenderer.gd` and `PlantHotbar.gd`; mapped stage logic strictly per specification: general crops feature Stages 1–3 for growth (P1 Seedling, P2 Vegetative, P3 Harvestable) and Stages 4–5 for withering/decay (P4 Pest/Stress/Overripe withering, P5 Terminal flooded/dead), while Banana features Stages 1–4 for growth (P1 Shoot, P2 Young stalk, P3 Flowering, P4 Mature fruit bunch) and Stages 5–6 for withering (P5 Pest/Stress withering, P6 Dead stalk); sprites rendered with native 4× pixel art scaling, grounded soft drop shadows, and automatic vertical alignment matching isometric diamond bases; updated PlantHotbar slot buttons and hover card to display mature pixel art sprites; tested and verified 100% pass across all stages in Godot 4.7.2 headless | src/core/TileRenderer.gd, src/ui/PlantHotbar.gd, assets/sprites/Field/Crops/*, GEMINI.md |
| 33 | 2×2 Multi-Tile Coconut Planting & Candidate Root Auto-Detection: Fixed bug where Coconut palms failed to plant despite being assigned to workers; root cause was `plant_crop()` calling `can_plant_crop()` which called `is_tile_plowed_and_ready()`, failing because `TaskManager.has_task_at()` returned true for the worker's own active plant task; added `ignore_pending_tasks: bool = false` to `is_tile_plowed_and_ready()` and `can_plant_crop()`, allowing `plant_crop()` to bypass self-task checking during task execution; enhanced single-click hotbar planting with candidate root auto-detection so clicking ANY sub-tile within a plowed 2×2 area automatically identifies the correct root and plants the coconut grove without requiring the player to guess the top-left root tile; added multi-tile plot validation in `TileActionPopup.gd` and `FarmGrid.gd` with immediate feedback; verified 100% pass across all 5 test scenarios in Godot 4.7.2 headless | src/core/FarmGrid.gd, GEMINI.md |
| 34 | 1×1 Crop Diamond Alignment & Double-Slab Elimination, Coconut & Banana 2×2 Multi-Tile Grove Centering at `Vector2(0, 32)`, and Sprite-Level Green/Red Highlighting: 1) Eliminated bottom overflow bug where 1×1 crops previously overshot the diamond bottom vertex by +12.0 screen pixels; aligned bottom tip flush to `y = +32.0` (`spr.offset = Vector2(0, 9.0 - tex_h / 2.0)`) with 0.0px overshoot across all 1×1 crops; suppressed duplicate `GroundSprite` rendering during `PLANTED`, `GROWING`, `HARVESTABLE`, `FLOODED`, and `INFECTED` when 1×1 stage textures are active; hid legacy procedural 38px dark depth slabs (`slab_left`, `slab_right`) in `FarmGrid.gd` that were poking out underneath pixel art; 2) Centered 2×2 multi-tile Coconut Palm and Cavendish Banana trees at `Vector2(0, 32)` (the exact isometric intersection of the 4 plots); converted Banana to a full 2×2 perennial plantation crop (4 plots, ₱140 seed, 400 yield, 2.2s harvest, 18d regrowth) with trunk base compensation across stages 1–6; 3) Implemented full crop sprite silhouette highlighting in `DragSelectOverlay.gd` (`_draw_crop_highlight`): crop sprites glow bright emerald green during valid tool hover and active worker tasks, crimson red during invalid hover (e.g. attempting to plant/plow over standing crops), and golden amber during tile selection | src/core/TileRenderer.gd, src/core/FarmGrid.gd, src/world/DragSelectOverlay.gd, autoload/Data.gd, src/ui/PlantHotbar.gd, GEMINI.md |
| 35 | 1×1 Crop Bottom Overflow Fix (Strict Zero-Overshoot Alignment): Fixed bottom overflow where row 31 (the 2-pixel-wide bottom tip of the 1×1 crop sprites) landed at `y = +32.0 to +36.0` on screen (protruding 4px / 8px zoomed below the bottom diamond vertex `(0, 32)` into the adjacent south tile); adjusted 1×1 crop sprite offset to `spr.offset = Vector2(0, 7.0 - tex_h / 2.0)` in `TileRenderer.gd`, ensuring the bottom row lands at `y = +24.0 to +28.0` (strictly within the bottom vertex of the diamond); verified mathematical zero-overshoot (`0.00 px`) across all 25 1×1 crop sprites and stages (Rice 1–5, Corn 1–5, Sugarcane 1–5, Pineapple 1–5, Coffee 1–5); synchronized `DragSelectOverlay.gd` highlight destination rect to `(7.0 - tex_h) * 4.0` for pixel-perfect green/red glowing silhouette outlines | src/core/TileRenderer.gd, src/world/DragSelectOverlay.gd, GEMINI.md |
| 36 | 1×1 Crop Ground Tile Integration & Shadow Elimination ("becomes the tile itself"): Transformed 1×1 field crops (Rice, Corn, Sugarcane, Pineapple, Coffee across all growth/withering stages P1–P5) to become the ground tile itself directly on `GroundSprite` in `GroundLayer` instead of a secondary `Sprite2D` floating over the soil; eliminated the artificial `Polygon2D` drop shadow and green border seam underneath crops; aligned 32h crop textures at offset `Vector2.ZERO` (identical to ground tiles) and 64h tall crop textures at `Vector2(0, -16.0)` ensuring the lower 32 rows sit flush with the terrain diamond and upper stalks extend upward in 2.5D space; synchronized `DragSelectOverlay.gd` highlight bounds to the `GroundSprite` frame; preserved 2×2 multi-tile Coconut and Banana grove canopy rendering in `Overlay` centered at `Vector2(0, 32)`; verified 0 errors in Godot 4.7.2 | src/core/TileRenderer.gd, src/world/DragSelectOverlay.gd, GEMINI.md |
| 37 | Clean Isometric Tile Diamond Highlights ("fix highlight green highlights entire sprite"): Removed `_draw_crop_highlight` from `DragSelectOverlay.gd` across box drag (`is_box_dragging`), tile selection (`selected_tiles`), task highlights (`_draw_task_highlights`), and tool hover (`_draw_tool_hover`); eliminated the 5-layer green texture overlay that painted over crop sprites, soil, and water; restored clean RTS-style isometric diamond fills and crisp polyline boundary outlines strictly on the terrain plane, leaving crop pixel art 100% natural, crisp, and visible; verified clean headless launch in Godot 4.7.2 | src/world/DragSelectOverlay.gd, GEMINI.md |
| 38 | Perennial Regrowth "No Crop" Sprite Stage & Ground Sprite Polish: 1) Fixed TileRenderer.gd parse error caused by GDScript slice syntax in `get_regrowth_texture()`, streamlining path resolution to load `BANANA-P3 no crop.png`, `COCONUT-P3 no crop.png`, and `COFFEE-P3 no crop.png`; 2) Integrated `is_regrowing` lifecycle on FarmTile, FarmGrid (multi-tile child sync in `_sync_multi_tile_children`), TileAgronomySystem (resets on `growth_progress >= 1.0`), and SaveManager (serialized via `rg`, `mr`, `mp`); 3) Verified all 5 ground tile sprite variant sets (NGRASS, WGRASS, BARE SOIL, DROUGHT SOIL, WALK SOIL) and eliminated Windows case-mismatch warnings; 4) Polished `DragSelectOverlay.gd` task and hover highlights by removing translucent polygon fills covering standing crop sprites | src/core/TileRenderer.gd, src/core/FarmTile.gd, src/core/FarmGrid.gd, src/core/TileAgronomySystem.gd, src/core/GroundTileSprites.gd, autoload/SaveManager.gd, src/world/DragSelectOverlay.gd, GEMINI.md |
| 39 | Top-Left HUD PNG Restructuring, Drag System & Dynamic Font Scaling: 1) Integrated custom HUD textures `Region-climate-humidity.png` (227×123) and `DaynNight-Time.png` (224×87) into separate modular top-level Controls; 2) Box 1 "Region-climate-humidity" places Region name on top scrollbar parchment (X:29..195, Y:16..41), climate/temperature on bottom-left parchment (X:29..112, Y:53..92), and humidity on bottom-right parchment (X:112..195, Y:53..92); 3) Box 2 "DaynNight-Time" splits into Day cycle progress on left parchment (X:26..107, Y:27..53) and Time + Sun/Moon icon on right parchment (X:119..199, Y:27..53); 4) Implemented runtime drag repositioning (Left-click drag anywhere on box or title bar), mouse-wheel dynamic font size scaling (+/- 1pt), double-click reset to default position/fonts, and console coordinate output for easy tuning; 5) Dynamic RegionHoverCard auto-aligns directly below RegionWeatherBox wherever it is moved | scenes/MainGame.tscn, src/ui/HUD.gd, scenes/MainMenu.tscn, GEMINI.md |
| 41 | Bahay Kubo & Solar Dryer Building Sprites, TopBar Disaster Box Smooth Fade & Tactile Buttons: 1) Replaced legacy procedural polygon buildings with authentic Philippine pixel-art building sprites (KUBO.png & DRYER-BARE.PNG); removed platform slab so structures rest naturally on soil with contact shadows; 2) Created dedicated top-center DisasterBox (224×87 px) from Disaster-box.png with smooth Tween fade in/out for active hazards and climate phenomena (La Niña / El Niño); 3) Upgraded HUD TopBar buttons with tactile pixel-art wooden/gold NinePatch textures | scenes/MainGame.tscn, src/buildings/Building.gd, src/ui/HUD.gd, GEMINI.md |
| 42 | Hopbar Box Sprites Integration for Hotbar Slots & Plant Icons: 1) Updated PlantHotbar.gd to load authentic 32×32 pixel-art box textures from `res://assets/sprites/hud/Hopbar/` (`small-dark-box.png` and `small-ligh-box.png`); 2) Integrated NinePatch box frames (`_create_box_frame`) for all primary hotbar category slots (Seeds, Tools, IPM), framing icons with clean beveled borders and dynamic active/hover lighting; 3) Framed all 7 plant icons in the Seeds flyout drawer with individual `ThumbBox` frames that illuminate on hover; 4) Framed crop preview icons in the floating hover card; 5) Integrated `portrait_texture` in TileInfoPanel's `PlantBox` so inspecting planted or harvestable crops renders authentic crop sprites inside the planter box; verified 5/5 automated test assertions | src/ui/PlantHotbar.gd, src/ui/TileInfoPanel.gd, GEMINI.md |
| 43 | Complete Audio & Sound Effects System Implementation: 1) Created `AudioManager.gd` singleton registered in `project.godot` managing all 16 WAV sound files across Farmer Actions, Buildings, and UI/HUD; 2) Implemented 16-channel polyphonic audio player pool with organic pitch jitter (+/- 5%) and throttle rate limiting; 3) Connected farmer action sound cues for task assignment (`assign`), plowing (`plow`), planting (`plant`), watering (`water`), pest spraying (`spray`), harvesting (`harvest`), obstacle clearing (`chop`), and worker selection (`select`); 4) Implemented building placement sound (`place`), construction/upgrade completion chime (`complete`), and looping construction ambient player (`build-loop`); 5) Wired HUD & UI sounds for tile selection (`tile select`), pausing (`pause`), insufficient funds / errors (`error`), and automatic dynamic button click (`click`) & hover (`hover`) hooks; verified 8/8 automated test assertions in Godot 4.7.2 | autoload/AudioManager.gd, project.godot, src/farmer/Farmer.gd, src/buildings/Building.gd, autoload/EconomyManager.gd, src/core/FarmGrid.gd, src/ui/HUD.gd, src/ui/PauseMenu.gd, GEMINI.md |
| 44 | Minecraft-Style Square Hotbar, Inside-Box Centering, Dedicated Plant Icons & Bottom-Right Price Tags: 1) Removed outer brown card background, border, header text, and close button, allowing hotbar to float cleanly at HUD bottom; 2) Replaced wide rectangular slot buttons with authentic Minecraft-style square boxes (`Vector2(46, 46)` using `small-dark-box.png` / `small-ligh-box.png`); 3) Fixed icon offset bug by nesting all button contents within a `CenterContainer` (`PRESET_FULL_RECT`), ensuring every icon sits strictly and symmetrically inside the box with uniform margins (no overflow/bottom-right shift); 4) Integrated dedicated 32×32 pixel-art plant icons from `res://assets/icons/Plants/` across all 7 crops (Rice, Corn, Sugarcane, Pineapple, Coffee, Banana, Coconut); 5) Added crisp bottom-right price tags (e.g. `₱25`, `₱140`, `₱30`) on both primary category slots and flyout drawer square buttons (styled like Minecraft stack numbers with dark shadow outlines); 6) Implemented snappy hover tooltips (0.25s delay) displaying item name, type/cost, description, stats, and regional affinity; 7) Replaced vertical flyout drawers with clean horizontal rows of square item boxes; verified 10/10 automated test assertions in Godot 4.7.2 | src/ui/PlantHotbar.gd, assets/icons/Plants/*, GEMINI.md |
| 45 | Worker Selection Long Banner Removal & Direct ESC Pause Menu Navigation: 1) Removed intrusive full-width top banner `_worker_banner` ("Selected: Worker 1 • Use bottom hotbar... Deselect [Esc]") from `src/ui/HUD.gd`, freeing up screen space while maintaining subtle selection state in `WorkerCapsule` (`1/1 (⭐1)`); 2) Removed ESC worker deselect interceptor from `src/core/FarmGrid.gd`, preventing farmer selection from consuming ESC key events; 3) Updated `src/ui/HUD.gd` `_unhandled_input` so pressing ESC immediately closes open sub-panels (Shop/Market/Sell) or directly toggles `PauseMenu` ("main menu" / pause screen with Save, Load, Settings, Main Menu, Resume) without worker selection interference; verified headless test suite with 4/4 passing assertions | src/ui/HUD.gd, src/core/FarmGrid.gd, GEMINI.md |
| 46 | Starting Homestead Land Obstacle Reduction: 1) Updated `_seed_natural_obstacles()` in `src/core/FarmGrid.gd` to generate exactly 1 tree and 1 rock across the starting 12×12 homestead parcel (down from 8–10 obstacles), leaving 142/144 plots open for farm layout and immediate expansion; 2) Verified procedural spacing constraints and compound clearance remain active; verified automated test assertion confirming exactly 1 tree and 1 rock spawn on new farm initialization | src/core/FarmGrid.gd, GEMINI.md |
| 47 | 2×2 Multi-Tile Whole-Tile Unification, Dark Crater Shadow Removal & "Not enough Money" Floating Text Popup: 1) Removed dark circular shadow polygon under 2×2 multi-tile crops (Coconut & Banana) in `TileRenderer.gd`, eliminating the dark "hole" in the middle of the 4 plots; 2) Unified 2×2 crop footprint selection and hover: selecting ANY sub-plot of a 2×2 crop selects the entire plant, expanding the selection diamond across all 4 plots (`FarmerMovement.get_footprint_polygon_local()`); 3) Updated `DragSelectOverlay.gd` so hovering over an existing 2×2 crop with watering can, harvest basket, or pest spray highlights the entire 2×2 diamond in green/red without internal cut lines; 4) Implemented floating text popup system in `FarmGrid.gd` (`show_floating_text` & `spawn_floating_text_at_world`): when trying to plant without enough cash (via hotbar click, drag, or context menu), a crisp pixel-art badge pops up above the target tile saying "Not enough Money" with pop-in/float-up animation, audio error buzzer (`AudioManager.play_ui("error")`), and Chronicle logging | src/core/TileRenderer.gd, src/core/FarmGrid.gd, src/world/DragSelectOverlay.gd, src/ui/TileActionPopup.gd, GEMINI.md |
| 48 | Early Harvest Restoration & Premature Harvest Confirmation Modal: 1) Restored early harvest capability across tool validation: updated `is_valid_tool_target()` in `FarmGrid.gd` for `"harvest"` so crops across `PLANTED`, `GROWING`, and `INFECTED` states with any growth progress are valid harvest targets; 2) Created `EarlyHarvestModal.gd` (CanvasLayer 180): styled in rich Philippine farm tycoon aesthetic with dark wood paneling, gold trim, and Quill & Antler typography; displays crop name & icon, live growth progress bar (%), premature yield penalty % comparison (e.g. 50/100 units, -50%), quality cap notice (Grade B/C only), and strategic tip on emergency salvaging ahead of incoming typhoons or floods; 3) Integrated storage warning if farm storage is full; 4) Provides two prominent action buttons: "🧺 Harvest Now (Salvage Yield)" and "❌ No, Wait for Ripe (Keep Growing)", plus ESC / backdrop click dismissal; 5) Fixed execution deadlock where confirmed early harvests re-intercepted themselves due to missing `early_confirmed: true` flag; 6) Added automatic worker selection on tool click/drag so actions always dispatch immediately; verified 100% end-to-end in Godot 4.7.2 across both hotbar tool and right-click context menu | src/ui/EarlyHarvestModal.gd, src/core/FarmGrid.gd, src/ui/TileActionPopup.gd, GEMINI.md |
| 49 | Pixel-Art Information Box Integration for Hotbar Hover Card: 1) Integrated custom pixel-art asset `information-box.png` (208×140) from `res://assets/sprites/hud/Hopbar/information-box.png` as the background texture for the hover card tooltip in `src/ui/PlantHotbar.gd`; 2) Configured NinePatch StyleBoxTexture with margins `(24, 47, 24, 16)` and content margins `(22, 10, 22, 14)` matching the outer wooden border and internal parchment boxes; 3) Implemented pixel-perfect two-tier layout: top parchment header row (28px height) cleanly houses the crop/tool icon, title (`card_title`), and price tag (`card_price`), while a 10px divider spacer bridges over the horizontal wooden dividing bar; 4) Bottom parchment section houses item type, vital agronomic stats, description, and regional climate buffs/debuffs; 5) Polished typography with high-contrast parchment colors (deep mahogany headers, rich brown price tags, dark charcoal descriptions, forest green buffs, and rust-red debuffs); verified 5/5 automated test assertions in Godot 4.7.2 | src/ui/PlantHotbar.gd, assets/sprites/hud/Hopbar/information-box.png, GEMINI.md |
| 50 | StartMenu Sprites Integration & Game Mode Arrow-Select Carousel: 1) Integrated custom pixel-art assets from `res://assets/sprites/StartMenu/` (`Big-Rectangle-logs.png`, `samplebox1.png`, `Arrows/`, `Brownbutton/`, `GoldButton/`); 2) Replaced cramped two-column layout with a top-level Arrow Selector Carousel (`prev_mode_btn` and `next_mode_btn` with normal, hover, pressed states framing a custom header card `_mode_name_label`); 3) Upgraded main mode view to an authentic wooden log billboard (980×540) using `Big-Rectangle-logs.png` with 824px wide parchment interior allowing spacious, highly legible typography; 4) Full-width showcase features rich narrative descriptions and 3 detailed feature pillars housed inside a `samplebox1.png` parchment card; 5) Embedded interactive Season Duration selector (30d Sprint, 60d Standard, 90d Quarter) with live descriptive text directly on the Campaign card; 6) Embedded sandbox perks bar for Career mode; 7) Styled primary start buttons with `GoldButton` and secondary load buttons with `Brownbutton`; 8) Connected keyboard navigation (A/D and Left/Right arrow keys to cycle modes, Enter to start); verified 9/9 automated test assertions in Godot 4.7.2 | scenes/MainMenu.tscn, scenes/MainMenu.gd, assets/sprites/StartMenu/*, GEMINI.md |
| 51 | StartMenu Layout Expansion & Typography Enlargement: 1) Expanded Billboard container dimensions to 1040×580 px and tuned `Big-Rectangle-logs.png` content margins (top: 38px, bottom: 32px, left: 86px, right: 82px) to prevent header text collision with top wooden logs; 2) Enlarged typography across all Game Mode elements: Notice Header (18pt deep mahogany), Mode Title (24pt gold with shadow), Tagline and index badges (13pt), Narrative Description (15pt with 4px line spacing), Pillar card titles (16pt), and Pillar bullet points (13pt with 6px line spacing); 3) Expanded 3-Pillar Card (`samplebox1.png`) to `SIZE_EXPAND_FILL` with 180px min height and 18px top padding, completely eliminating empty lower parchment voids; 4) Enlarged Season Duration buttons (175×36 px with 12pt font) and Career perks badges (13pt); 5) Improved button contrast: unselected season buttons now use high-contrast cream text (`Color(0.92, 0.88, 0.80)`) with dark drop shadow instead of faint gray; 6) Enlarged primary action buttons: Start Button (440×50 px, 15pt font) and Load Saved Game Button (240×50 px, 15pt font); verified clean headless launch in Godot 4.7.2 | scenes/MainMenu.gd, GEMINI.md |
| 52 | StartMenu Top Gamemode Plaque Sprite (`long-rectangle.png`) & Anti-Overflow Proportional Spacing: 1) Integrated custom sprite `res://assets/sprites/StartMenu/long-rectangle.png` to frame top header "CHOOSE GAME MODE"; 2) Implemented automated transparent-padding detection and standalone `ImageTexture` cropping to trim canvas overhang (191×47 px active area) with 9-slice StyleBoxTexture margins `(10, 10, 8, 8)`; 3) Fixed layout overflow and vertical collisions: billboard sized to 1000×520 px, centered with 32px clearance below top title and 100px bottom clearance; 4) Balanced internal vertical rhythm (6px separation, 42px top plaque, 46px carousel bar, 32px description, 140px expanding feature pillars, 48px season duration row, 44px primary action buttons); verified 100% test pass in Godot 4.7.2 | scenes/MainMenu.tscn, scenes/MainMenu.gd, GEMINI.md |
| 53 | Game Mode Name Plaque Assignment, Samplebox1 Bounding-Box Cropping & Balanced Vertical Centering: 1) Clarified plaque assignment: assigned `long-rectangle.png` (`style_long_rect`) to the active Game Mode Name (`_mode_name_label`: "🏆 TIMED RTS CAMPAIGN" / "🌾 CAREER / ENDLESS TYCOON") between the carousel arrows, while keeping the top billboard header ("🌾 CHOOSE GAME MODE 🌾") as clean parchment text without a box; 2) Implemented automated transparent-padding trimming for `samplebox1.png` (active area 247×126 px with 11px symmetric borders) into an `ImageTexture` to eliminate invisible top-padding offsets; 3) Configured `style_long_rect` margins (`texture_margin_top/bottom = 11`, `content_margin_top = 8`, `content_margin_bottom = 10`) for optical text centering inside the plaque; 4) Set `pillars_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER` with 146px card height, 14pt centered pillar titles, 12pt bullet text, and `line_spacing = 7`, eliminating empty bottom voids and top border collisions; verified pixel-perfect alignment across Campaign and Career modes | scenes/MainMenu.gd, GEMINI.md |
| 54 | Start Menu Visual Editor Integration & Standalone Scene (`StartMenu.tscn`): 1) Converted code-generated Start Menu (`ModeSelectView`) into full static node tree inside `scenes/MainMenu.tscn`, resolving the issue where only Region Select was visible in the Godot Editor 2D canvas; 2) Set Region Select nodes (`MiddleCard`, `CarouselBar`, `TopRightMapCard`, `FooterBar`) to `visible = false` and `ModeSelectView` to `visible = true` in the editor so the Start Menu billboard is immediately visible and editable in the 2D viewport; 3) Created standalone `scenes/StartMenu.tscn` for isolated visual editing; 4) Created dedicated `.tres` StyleBoxes with `axis_stretch = 0` (STRETCH) to eliminate 9-slice border tiling artifacts; 5) Increased ModePlaque height to 52px with 6px vertical padding for clean centered typography; verified 100% test pass in Godot 4.7.2 | scenes/MainMenu.tscn, scenes/MainMenu.gd, scenes/StartMenu.tscn, assets/sprites/StartMenu/*, GEMINI.md |
| 55 | Start Menu Button NinePatch & StyleBox Restoration: 1) Repaired `BrownButton.tres` which had previously pointed to `long-rectangle.png` with zero margins, restoring it to `HUD-brown button .png` with authentic 9-slice margins `(10, 6, 10, 9)` and content margins `(14, 4, 14, 7)`; 2) Corrected stretch modes across `BrownButtonHover.tres`, `BrownButtonPressed.tres`, `Goldbutton.tres`, `GoldbuttonHover.tres`, and `GoldbuttonPresesd.tres` from `axis_stretch = 1` (TILE) to `axis_stretch = 0` (STRETCH), eliminating horizontal border tiling seams; 3) Restored dynamic gold/brown stylebox swapping on season duration buttons in `MainMenu.gd` (`_update_mode_season_buttons_ui`), making the active season button glow with `Goldbutton.tres` and inactive buttons use `BrownButton.tres`; 4) Upgraded carousel arrow buttons (`PrevModeBtn` & `NextModeBtn`) with `stretch_mode = 5` (KEEP_CENTERED) and 36×36 min size; 5) Synced all button improvements into standalone `scenes/StartMenu.tscn`; verified 100% test pass in Godot 4.7.2 | scenes/MainMenu.tscn, scenes/MainMenu.gd, scenes/StartMenu.tscn, assets/sprites/StartMenu/Brownbutton/*, assets/sprites/StartMenu/GoldButton/*, GEMINI.md |
| 56 | Autonomous Precision Farm Drone & Hotbar Remote Control System (Phase 1 Machinery Visuals): 1) Added 3 progressive drone tech tiers in `Data.gd` (`farm_drone_1` ₱1200 auto-plow, `farm_drone_2` ₱2400 auto-plow+plant, `farm_drone_3` ₱4200 auto-plow+plant+harvest); 2) Enforced purchase prerequisites and unlocked tiers in `BuildingManager.gd` (`buy_tech`, `get_drone_level() -> int`); 3) Upgraded Agri-Shop Machinery tab (`ShopPanel.gd`) to show locked tier status and prerequisite hints; 4) Implemented `FarmDrone.gd` (`class_name FarmDrone extends Node2D`) with procedural pixel-art body, shadow, spinning rotors, downward work beam, floating status tag, and custom PNG override hook (`res://assets/sprites/drone/drone.png`); 5) Integrated `ZoneOverlay` rendering a pulsing cyan isometric boundary with corner pins and active job highlights; 6) Expanded `PlantHotbar.gd` with 4th slot ("DRONE", hotkey 4) dynamically visible when drone is owned, featuring drone icon, `drone_zone` remote tool, `drone_recall` instant standby, and comprehensive hover cards; 7) Integrated cyan marquee box styling in `DragSelectOverlay.gd` during drone zone designation; 8) Integrated autonomous patrol, priority scanning (harvest ripe -> plant selected seed -> plow), and multi-tile/perennial compatibility in `FarmGrid.gd`; verified 100% test pass and in-game capture | autoload/Data.gd, autoload/BuildingManager.gd, src/market/ShopPanel.gd, src/drone/FarmDrone.gd, src/core/FarmGrid.gd, src/ui/PlantHotbar.gd, src/world/DragSelectOverlay.gd, GEMINI.md |
| 57 | Drone Infrastructure Hangar, Labor Commissioning, Building Upgrades & Farmer Pilot Ratio: 1) Added `drone_station` ("Drone Command Hangar", 2×2 footprint, ₱800, build time 20s, max level 3) to `Data.BUILDINGS` with rich 2.5D concrete helipad, hazard stripes, cyan glowing "H" target, telemetry antenna mast with flashing beacon, charging dock LED status indicators, and Lv.2/Lv.3 upgrade visuals; 2) Integrated drone automation level directly with the Hangar building in `BuildingManager.gd`: upgrading the Hangar (`BuildingCardPopup.gd`) automatically upgrades the drone tier (Lv.1 Plow, Lv.2 Seeder, Lv.3 Harvester); 3) Transformed drones into mechanized labor units: added Drone Labor commissioning in Agri-Shop Labor tab (`ShopPanel.gd`, ₱350/drone), requiring an active Hangar and strictly capping total drones by available farmer pilots (`active_drones <= active_workers`); 4) Updated `FarmGrid.gd` to manage a dynamic fleet of autonomous drones (`drones: Array[FarmDrone]`), automatically synchronizing via `drone_commissioned` and avoiding job targeting conflicts via `is_tile_targeted_by_other_drone()`; 5) Updated `PlantHotbar.gd` slot visibility and hover cards to reflect fleet counts and farmer pilot capacity; 6) Persisted `active_drones` and `drone_station` across Save/Load in `SaveManager.gd`; verified with 8/8 automated test assertions in Godot 4.7.2 | autoload/Data.gd, autoload/BuildingManager.gd, src/buildings/Building.gd, src/buildings/BuildingCardPopup.gd, src/market/ShopPanel.gd, src/core/FarmGrid.gd, src/drone/FarmDrone.gd, src/ui/PlantHotbar.gd, autoload/SaveManager.gd, GEMINI.md |
| 58 | Phase 2 Step 1: Upgradable Weather Station Telemetry System (Radio Mast -> AWS -> Satellite Dish): 1) Added `weather_station` ("PAGASA Telemetry Station", 2×2 footprint, ₱450, build time 16s, max level 3) to `Data.BUILDINGS` with animated 2.5D pixel-art graphics; 2) Implemented Level 1 (AM Radio Mast with lattice tower, guy-wires, pulsing red aircraft warning beacon, and expanding cyan radio broadcast waves), Level 2 (Automated Weather Station / AWS with real-time spinning anemometer wind cups, aerodynamic wind vane arrow, louvred Stevenson screen, rain gauge funnel, and photovoltaic solar panel), and Level 3 (High-Gain Parabolic Satellite Uplink Dish with motorized gimbal, feed horn, and pulsing cyan telemetry beam); 3) Added query API to `BuildingManager.gd` (`get_weather_station_level()`, `get_forecast_accuracy()`, `get_forecast_days()`, `get_disaster_warning_time()`, `get_weather_station_tier_name()`); 4) Integrated with `WeatherManager.gd` so higher tier weather stations extend reliable forecast horizons (Lv.1 = 1 day, Lv.2 = 3 days, Lv.3 = 7 days), boost radar accuracy (60% -> 90% -> 100%), and expand emergency disaster lead warning times (5s baseline -> 8s Radio -> 12s AWS -> 18s Satellite); 5) Updated `ShopPanel.gd` with `[Weather Station]` perk badge, and `HUD.gd` (`RegionHoverCard` and `WeatherLabel`) to display live equipment telemetry status; verified 100% test pass in Godot 4.7.2 | autoload/Data.gd, autoload/BuildingManager.gd, autoload/WeatherManager.gd, src/buildings/Building.gd, src/buildings/BuildingCardPopup.gd, src/market/ShopPanel.gd, src/ui/HUD.gd, GEMINI.md |
| 59 | Phase 2 Machinery Buildings & Ground Units (Irrigation Infrastructure, Machine Depot, Visible Kuliglig & Combine Harvester): 1) Added `water_tower` ("Irrigation Pump & Tower", 2×2 footprint, ₱500, max level 3) to `Data.BUILDINGS` with 2.5D artwork: Lv.1 Well Pump (diesel motor, belt pulley, reciprocating pump arm, expanding water ripples), Lv.2 Elevated Cistern Tower (4 stanchion legs, wooden staves, iron hoops, sight tube with floating bobber, high-pressure downspout), Lv.3 Solar Drip Network (stainless steel tank, top-mounted solar PV array, dual booster pumps, LED flow monitor); 2) Connected irrigation to `TileAgronomySystem.gd` and `TileRenderer.gd`: renders polymer furrow drip lines with brass emitter nozzles on cultivated soil, auto-waters parched crops to optimal regional moisture targets, and provides 10%–35% evaporation reduction; 3) Added `machine_garage` ("Machine Shed & Depot", 3×2 footprint, ₱600, max level 3) with concrete mechanics apron, oil stains, yellow gantry crane with hoist hook, parked Kuliglig (Lv.1), parked Combine Harvester (Lv.2), and compressor/spares (Lv.3); 4) Dynamic Ground Vehicles in `Farmer.gd`: farmers visibly mount the **Kuliglig** (rotating cleated iron cage wheels, red Kubota diesel engine, puffing exhaust, handlebars, headlights) when plowing, and mount the **Combine Harvester** (rubber caterpillar tracks, green body, rotating yellow cutter reel, grain hopper, unloading auger) when harvesting, applying 1.8× and 3.5× task speed multipliers plus garage level speed bonuses; 5) Synced with `BuildingManager.gd`, `BuildingCardPopup.gd`, `ShopPanel.gd`, and `HUD.gd`; verified with 6/6 passing assertions in Godot 4.7.2 headless | autoload/Data.gd, autoload/BuildingManager.gd, src/core/TileAgronomySystem.gd, src/core/TileRenderer.gd, src/buildings/Building.gd, src/farmer/Farmer.gd, src/buildings/BuildingCardPopup.gd, src/market/ShopPanel.gd, src/ui/HUD.gd, GEMINI.md |
| 60 | Shop Reorganization by Function & One-Time Buildings: 1) Removed redundant Machinery & Tech tab (kuliglig/combine/drip/weather techs are now driven by upgrading buildings) and the catch-all Infrastructure tab; 2) ShopPanel now has 5 tabs: Housing & Labor (Bahay Kubo + worker hiring + drone commissioning), Storage (silos, cold storage, climate silo, solar dryer — repeatable), Weather & Irrigation (PAGASA station, Irrigation Pump & Tower), Machinery & Drones (Machine Shed, Drone Hangar), Land; 3) Added `shop_category` and `unique` flags to `Data.BUILDINGS`; unique buildings (weather_station, water_tower, machine_garage, drone_station) are one-time purchases — shop shows `Built ✔` + tier/level status and upgrades happen by clicking the building; 4) Added `BuildingManager.is_unique_building/get_building_of_type/owns_building` and duplicate-placement guards in `FarmGrid.start_building_placement/place_building`; 5) Tab titles set via `set_tab_title` (TabContainer ignores `_tab_title` meta at runtime) | autoload/Data.gd, autoload/BuildingManager.gd, src/market/ShopPanel.gd, src/core/FarmGrid.gd, src/drone/FarmDrone.gd, scenes/MainGame.tscn, GEMINI.md |
| 61 | Deployable Rotary Field Sprinklers & Water Tower Pressure Network: 1) Added deployable `sprinkler` (1×1 footprint, ₱120, repeatable, category: "weather", `is_sprinkler: true`) to `Data.BUILDINGS`; 2) Tied to Irrigation Pump & Tower: requires an active `water_tower` to deploy, and is strictly capped by water pressure capacity (Lv.1 = 6 sprinklers, Lv.2 = 16 sprinklers, Lv.3 = 999 unlimited sprinklers); 3) Upgrading Water Tower to Lv.2+ expands sprinkler spray radius from 1 (3×3 diamond, 8 surrounding plots) to 2 (5×5 diamond, 24 surrounding plots); 4) Implemented rich 2.5D procedural artwork in `Building.gd`: concrete anchor pad with corner bolts, HDPE feeder hose with brass compression fitting, galvanized steel riser pipe, rotating brass impact sprinkler head, oscillating spring-loaded impact hammer arm, dynamic 360° water jet ballistic stream, glistening spray mist cone, and animated ground ripples with bouncing splash droplets; 5) Updated `BuildingPlacementOverlay.gd` to render a glowing translucent cyan isometric coverage diamond showing exact spray area when placing sprinklers; 6) Integrated with `TileAgronomySystem.gd` & `FarmGrid.gd`: plots covered by active sprinklers auto-hydrate parched/growing crops up to target moisture, keep plowed soil fertile, and protect crops against El Niño drought and heat damage (`days_without_water = 0`); 7) Updated `ShopPanel.gd` and `BuildingCardPopup.gd` with live pressure limits (`X/Y`) and tier status; verified 100% pass across all unit tests in Godot 4.7.2 headless | autoload/Data.gd, autoload/BuildingManager.gd, src/buildings/Building.gd, src/buildings/BuildingPlacementOverlay.gd, src/buildings/BuildingCardPopup.gd, src/core/TileAgronomySystem.gd, src/core/FarmGrid.gd, src/market/ShopPanel.gd, GEMINI.md |
| 62 | Comprehensive UI Pixel Art Styling Overhaul & Box Texture Variant Mapping: 1) Sliced and registered new 9-slice `StyleBoxTexture` resources: `BigPlainBox.tres` (`Big-Plain-Box.png`, iron-bracketed dark wood frame with warm parchment interior) and `InformationBox.tres` (`information-box.png`, top header banner plate and expandable body); 2) Eliminated procedural flat grey boxes across all 12 game modals and containers, mapping diverse pixel-art box variants without repetitive monotony: `ShopPanel` (Shop Background + BrownBox Item Details + BrownButton `!` info triggers), `MarketPanel` (Shop Background + Samplebox news/regional matrix + BrownBox/GoldButton commodity cards), `SellPanel` (BigPlainBox + Samplebox empty banner + BrownBox contract card + GoldButton shipping hubs), `BuildingCardPopup` (InformationBox + BrownButton/GoldButton), `PauseMenu` (BigRectangleLogs + GoldButton resume + BrownButtons), `BacklogPanel` (Clipboard + BrownBox rows + GoldButton/BrownButton category tabs), `LeaderboardPanel` (BigPlainBox + BrownBox live score banner + Samplebox standings + gold/brown tabs), `EarlyHarvestModal` (Samplebox + BrownBox trade-offs card), `LandExpansionModal` (Samplebox + GoldButton/BrownButton deeds), `SaveLoadModal` (BigPlainBox + Samplebox slot cards + BrownBox badges), `SeasonResultsModal` (BigRectangleLogs + action buttons), `AdminPanel` (BigRectangleLogs + BrownButtons); 3) Upgraded in-game HUD popups: `RegionHoverCard` (`BrownBox.tres` with crisp gold/sage/coral text), `TileActionPopup` (right-click context menu styled with `BrownBox.tres`, warm typography, and dark caramel hover highlight), and `PlantHotbar` seed `flyout_drawer` (`BrownBox.tres` + BrownButton close); 4) Tested all 11 UI components in Godot 4.7.2 headless with 100% test pass and zero warnings | assets/sprites/hud/Big-Rectangle-Box/BigPlainBox.tres, assets/sprites/hud/Hopbar/InformationBox.tres, src/market/MarketPanel.gd, src/market/SellPanel.gd, scenes/BuildingCardPopup.tscn, src/buildings/BuildingCardPopup.gd, src/ui/PauseMenu.gd, src/ui/BacklogPanel.gd, src/ui/LeaderboardPanel.gd, src/ui/EarlyHarvestModal.gd, src/ui/LandExpansionModal.gd, src/ui/SaveLoadModal.gd, src/ui/SeasonResultsModal.gd, scenes/MainGame.tscn, src/ui/TileActionPopup.gd, src/ui/PlantHotbar.gd, src/ui/AdminPanel.gd, src/market/ShopPanel.gd, scenes/MainMenu.gd, GEMINI.md |
| 63 | Complete UI Readability, Contrast & Typography Standards Overhaul: 1) Audited and revamped all 13 dialogs and HUD panels to guarantee large, easily legible text with generous internal padding, zero clipping, and high contrast against pixel-art surfaces; 2) Enforced Universal Contrast Rules: Deep Mahogany/Espresso text (`Color(0.20-0.28, 0.12-0.18, 0.06-0.10)`) on parchment backgrounds (`Samplebox`, `Shop Backgroud`, `BigPlainBox`), warm ivory (`Color(0.96, 0.92, 0.84)`) and gold (`Color(1.0, 0.88, 0.45)`) on dark wood (`BrownBox`, `BrownButton`), and deep espresso on gold buttons (`Goldbutton`); 3) Sized and padded components: `MarketPanel` (860×520, 18pt title, 42px commodity rows, 26px table rows), `SellPanel` (860×490, 18pt title, 52px shipping cards, 44px sell button, Samplebox empty banner), `BuildingCardPopup` (460×360 on clean `Samplebox.tres` parchment, 18pt title, 38px demolish/upgrade buttons, removed clipping HSeparators), `BacklogPanel` (820×560, top margin 64px clearing clipboard metal clamp, 36px search bar, luminance contrast clamp for logs), `LeaderboardPanel` (11pt espresso headers, 12pt ivory rows), `EarlyHarvestModal` (540×390, 18pt title, 40px buttons, BrownBox trade-offs card), `LandExpansionModal` (520×360, 18pt title, 42px purchase button), `PauseMenu` (430×520, 24pt title, 42px resume button), `SaveLoadModal` (15pt slot titles, 36px buttons), `SeasonResultsModal` (620×530, 30pt bronze score, 40px buttons), `AdminPanel` (padded interior MarginContainer, 34px buttons), `TileActionPopup` (13pt items with 6px v-separation), `ShopPanel` (cards padded to 12×8px, 32px buy buttons); 4) Verified all 13 components in `scratch/verify_all_ui_overhauls.gd` and 7/7 gameplay regression tests with 100% success in Godot 4.7.2 headless | src/market/MarketPanel.gd, src/market/MarketChart.gd, src/market/SellPanel.gd, scenes/BuildingCardPopup.tscn, src/buildings/BuildingCardPopup.gd, src/ui/BacklogPanel.gd, src/ui/LeaderboardPanel.gd, src/ui/EarlyHarvestModal.gd, src/ui/LandExpansionModal.gd, src/ui/PauseMenu.gd, src/ui/SaveLoadModal.gd, src/market/ShopPanel.gd, scenes/MainGame.tscn, src/ui/TileInfoPanel.gd, src/ui/SeasonResultsModal.gd, src/ui/AdminPanel.gd, scenes/MainMenu.gd, src/ui/TileActionPopup.gd, GEMINI.md |
| 64 | Dead Space Elimination, Font Size Expansion & Clean Locked Button Revert: 1) Replaced fixed `custom_minimum_size.y = 360` with `Vector2(490, 0)` on `BuildingCardPopup`, allowing the container to dynamically hug its content with 22px padding, eliminating ~130px of dead parchment void below buttons; 2) Enlarged typography across BuildingCardPopup: Title 20pt, Level 15pt, Status 15pt, Current/Next Stats 15pt, Action Buttons 42px height (14pt); 3) Sized `ShopPanel` bounds to `780×460` (was 760×490), expanding fonts and card padding: Header Title 22pt, Funds 17pt, Close button 34×30 (15pt), Tabs 14pt, Tab blurb 14pt, Item Titles 15pt, Prices 15pt, Buy/Commission/Hire buttons 120–128×38px (14pt), Info buttons 32×32px (14pt), notes 13–14pt; 4) Reverted locked/disabled buttons back to Godot's clean default disabled state: stripped `theme_override_styles/disabled` and `font_disabled_color` across `BuildingCardPopup.gd`, `ShopPanel.gd`, `SellPanel.gd`, `LandExpansionModal.gd`, and `SaveLoadModal.gd`, eliminating muddy brown-grey button styles and restoring crisp, legible disabled appearance; 5) Verified 13/13 UI overhaul checks and 7/7 task highlight regression tests in Godot 4.7.2 headless | scenes/BuildingCardPopup.tscn, src/buildings/BuildingCardPopup.gd, scenes/MainGame.tscn, src/market/ShopPanel.gd, src/market/SellPanel.gd, src/ui/LandExpansionModal.gd, src/ui/SaveLoadModal.gd, scratch/verify_all_ui_overhauls.gd, GEMINI.md |
| 65 | Integration of Custom Pixel-Art Building Sprites & Dynamic Silo Fill Levels: 1) Discovered and integrated 9 new pixel-art sprites across 5 buildings into `src/buildings/Building.gd`: `Cold Storage.png` (96×80 px, scaled 2× to 192×160 on 3×3 footprint), `Drone Station.png` (80×128 px, scaled 2× to 160×256 on 2×2 footprint with blinking red aircraft warning beacon and night helipad lighting), `Water Station.png` (64×144 px, scaled 2× to 128×288 on 2×2 footprint with night illumination), `Weather Station.png` (112×128 px, scaled 2× to 224×256 on 2×2 footprint with animated aircraft beacon and night telemetry lamp), and `Silo/SILO-0.PNG` through `SILO-100.PNG` (48×64 px, scaled 2× to 96×128 on 2×2 footprint) featuring dynamic 5-tier storage fill gauge (0%, 25%, 50%, 75%, 100%) reacting in real-time to `BuildingManager.storage_updated` and stored farm inventory; 2) Exempted buildings with authentic pixel-art isometric ground bases from the procedural dark slab foundation; 3) Adjusted overhead UI badge positions (`roof_apex_y`) to comfortably clear taller towers, antennas, and roofs; 4) Scaled construction scaffold overlay (`scaffold_h`) for tall structures; 5) Verified all 7 building types, dynamic silo fill stages, UI assertions, and gameplay regression suites in Godot 4.7.2 headless | src/buildings/Building.gd, assets/sprites/buildings/*, GEMINI.md |


---

## 21. Known Issues / TODO

- [x] Sound system not implemented — RESOLVED: Complete AudioManager singleton integrated with 16 sound cues across farmers, buildings, and UI (Session 43)
- [x] Crop growth visuals are emoji labels — RESOLVED: Multi-stage pixel art sprites (P1–P5/P6) integrated across all 7 crops with growth and withering stages
- [ ] Worker AI pathfinding occasionally clips tile corners on isometric grid
- [ ] Parcel borders (visual indicator of locked vs. unlocked land) could be more prominent




