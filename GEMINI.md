# Agri-Region Tycoon — AI Context File
> **Purpose**: This file is the SINGLE SOURCE OF TRUTH for any AI session. Read this first and **do NOT individually re-read files** unless you need a specific line number. Update this file at the end of every session
> **Last Updated**: 2026-10-25 (Session 115 — Revert Original Buildings to Classic 2.0x Scale & Calibrate Newly Added Buildings to Snugly Fit Within Tiles)

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
│   │   ├── DragSelectOverlay.gd           ← Marquee box draw
│   │   ├── FarmHeatmapOverlay.gd          ← class_name FarmHeatmapOverlay (z=195, Soil & Farm Diagnostic Heatmap & Sprinkler Blueprint)
│   │   ├── SeaWater.gd                    ← class_name SeaWater (z=-40, animated eastern tropical ocean, surf & navigation buoys)
│   │   ├── OutOfBoundsForest.gd           ← class_name OutOfBoundsForest (CoC-style multi-layered perimeter canopy & bushes)
│   │   ├── OutOfBoundsTerrain.gd          ← class_name OutOfBoundsTerrain (z=-8, continuous NGRASS ground tiles under forest)
│   │   ├── OutOfBoundsDirtTrail.gd        ← class_name OutOfBoundsDirtTrail (z=-5, authentic organic dirt perimeter trail)
│   │   └── OutOfBoundsFogOfWar.gd         ← class_name OutOfBoundsFogOfWar (z=22, multi-band isometric gradient fog & drifting mist)
│   ├── farmer/                            ← Worker character system
│   │   ├── Farmer.gd                      ← Worker CharacterBody2D (32×32 retro pixel animations: walk, till, harvest, idle)
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
│   │   ├── WeatherAppModal.gd             ← Dedicated Weather App & PAGASA forecast telemetry dashboard
│   │   ├── HeatmapLegendBar.gd            ← class_name HeatmapLegendBar (Interactive Diagnostic Heatmap HUD Control Bar & Live Hover Telemetry)
│   │   └── PauseMenu.gd                   ← ESC pause overlay (spawned dynamically)
│   └── market/                            ← Economy & trade UI
│       ├── MarketChart.gd                 ← 7-day stock line chart custom Control
│       ├── MarketPanel.gd                 ← Regional commodity market dashboard (all 7 crops)
│       ├── SellPanel.gd                   ← Bodega sales desk (group by crop, buyer select)
│       └── ShopPanel.gd                   ← Agri-Shop (buildings, machinery, workers, land)
└── assets/
    ├── sprites/
    │   ├── farmer/                        ← ★ 32×32 RETRO PIXEL FARMER SPRITES (idle, walk_0..3, till_0..3, harvest_0..3)
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
func play_building(event_name: String) -> void # place, complete, loop, cancel, demolish, invalid
func play_economy(event_name: String) -> void  # earn, spend, insufficient, market_sell, new_day
func play_disaster(event_name: String) -> void # flood, drought, landslide, warning, cleared, spread
func play_tech(event_name: String) -> void      # unlock, hire, pause
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
func get_biyahero_price_bonus() -> float           # 0.08 if bayanihan_center owned, else 0.0
func is_hub_unlocked(hub_id: String) -> bool       # checks requires_building requirement against placed_buildings
func has_heatmap() -> bool                         # checks has_tech("field_survey_kit")
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

### Trade Hubs (Data.MARKET_HUBS)
| Hub ID | Name | Role | Base Mult | Effective Mult | Transit Rot | Fuel | Prerequisite |
|--------|------|------|-----------|----------------|-------------|------|--------------|
| `middleman` | Local Biyahero | Farmgate | 0.72× | 0.80× (with Post) | 0% | ₱0 | None (starts unlocked) |
| `tacurong` | Tacurong Grain Mill | Commercial Mill | 1.05× | 1.11× (with Depot) | 2% (was 3%) | ₱12 (was ₱15) | `tacurong_mill` |
| `koronadal` | Koronadal City Market | Wholesale Depot | 1.20× | 1.28× (with Depot) | 4% (was 6%) | ₱26 (was ₱35) | `koronadal_wholesale` |
| `gensan` | General Santos Port | International Gateway | 1.55× | 1.67× (with Seaport) | 6% (was 12%) | ₱56 (was ₱80) | `gensan_seaport` (`requires_shore`) |

### Buildings & Infrastructure (Data.BUILDINGS)
- `bayanihan_center`: "Biyahero Trading Post" (2×2 footprint, ₱350, unique). Buff: +8% payout markup (72% → 80%) on all sales to the local Biyahero middleman. No worker speed modifiers, directives, or levels. Uses `byahero.png`.
- `tacurong_mill`: "Tacurong Grain Mill Depot" (3×3 footprint, ₱1,500, unique, 1:1 tile ratio scale 1.714×). Unlocks Tacurong commercial sell hub with +6% payout (1.05× → 1.11×), -30% road rot, and -20% transit fuel. Uses `Tacurong-Grain-mill.png`.
- `koronadal_wholesale`: "Koronadal Wholesale Depot" (4×4 footprint, ₱2,800, unique, 1:1 tile ratio scale 1.736×). Unlocks Koronadal wholesale hub with +8% payout (1.20× → 1.28×), -30% road rot, and -25% transit fuel. Uses `Koronadal-Wholesale.png`.
- `gensan_seaport`: "General Santos Seaport Terminal" (4×4 footprint, ₱4,500, unique, 1:1 tile ratio scale 1.684×, `requires_shore: true`). Unlocks GenSan international export gateway with +12% payout (1.55× → 1.67×), -50% transit rot, and -30% transit fuel. Must be placed touching the eastern coastline (`start_pos.x + 4 == 24`) in unlocked coastal territory (`east_meadows`), with its container freighter berthed in the animated ocean water. Uses `Gensan-seaport.png`.

### Agri-Tech Unlocks (Data.TECH)
- `field_survey_kit`: "Field Survey Kit" (₱400, Agri-Shop Weather tab). Handheld optical surveyor and soil testing kit that unlocks the Diagnostic Heatmap & Sprinkler Blueprint HUD scanner (Hotkey `F` and CommandCorner button).

---

## 5. FarmGrid.gd — Key State & API

```gdscript
const GRID_SIZE: Vector2i = Vector2i(24, 24)
var unlocked_parcels: Array[String] = ["homestead"]  # starts with homestead only
var tiles: Array = []     # tiles[x][y] → FarmTile
var sea_water: SeaWater   # instantiated at z=-40 along eastern coastline (x >= 24)

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
| 65 | Integration of Custom Pixel-Art Building Sprites, Dynamic Silo Fill Levels & 3×3 Weather Station Compound: 1) Discovered and integrated 9 new pixel-art sprites across 5 buildings into `src/buildings/Building.gd`: `Cold Storage.png` (96×80 px, scaled 2× to 192×160 on 3×3 footprint), `Drone Station.png` (80×128 px, scaled 2× to 160×256 on 2×2 footprint with blinking red aircraft warning beacon and night helipad lighting), `Water Station.png` (64×144 px, scaled 2× to 128×288 on 2×2 footprint with night illumination), `Weather Station.png` (112×128 px, scaled 2× to 224×256 on upgraded 3×3 compound footprint per user request to comfortably accommodate its expansive mast, guy-wires, and telemetry sensors), and `Silo/SILO-0.PNG` through `SILO-100.PNG` (48×64 px, scaled 2× to 96×128 on 2×2 footprint) featuring dynamic 5-tier storage fill gauge (0%, 25%, 50%, 75%, 100%) reacting in real-time to `BuildingManager.storage_updated` and stored farm inventory; 2) Updated `Data.BUILDINGS["weather_station"]` `grid_size = Vector2i(3, 3)`; 3) Exempted buildings with authentic pixel-art isometric ground bases from the procedural dark slab foundation; 4) Adjusted overhead UI badge positions (`roof_apex_y`) to comfortably clear taller towers, antennas, and roofs; 5) Scaled construction scaffold overlay (`scaffold_h`) for tall structures; 6) Verified all 7 building types, dynamic silo fill stages, UI assertions, and gameplay regression suites in Godot 4.7.2 headless | src/buildings/Building.gd, autoload/Data.gd, assets/sprites/buildings/*, GEMINI.md |
| 66 | Integration of InnerBox2x 9-Slice Container StyleBox & Pixel-Art Tool Icons: 1) Analyzed new user asset `res://assets/sprites/hud/Big-Rectangle-Box/Inner-box-2x.png` (247×64 px, 2× scale counterpart to 144×32 `HUD-dark brown.png`); 2) Created dedicated 9-slice resource `InnerBox2x.tres` with pixel-perfect margins `(20, 18, 20, 18)` and content padding `(16, 12, 16, 14)`; 3) Replaced stretched 144px inner boxes across wide dialogs and cards: `ShopPanel` (`ItemInfoCard` spanning ~720px width), `SellPanel` (`_contract_box` contract summary card), `EarlyHarvestModal` (`details_card` trade-offs card), `LeaderboardPanel` (`live_banner` live performance header), and `PlantHotbar` (`flyout_drawer` 8-slot drawer); 4) Integrated custom pixel-art tool textures from `res://assets/icons/Tools/` (`Pick.png`, `watering.png`, `Basket.png`) for Plow & Hoe, Watering Can, and Harvest Basket in `PlantHotbar.gd`; 5) Added startup verification in `MainMenu.gd` and confirmed 100% test pass across `scratch/run_verify_ui.tscn` (13/13 UI assertions) and hotbar tools test suite in Godot 4.7.2 headless | assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres, scenes/MainGame.tscn, src/market/ShopPanel.gd, src/market/SellPanel.gd, src/ui/EarlyHarvestModal.gd, src/ui/LeaderboardPanel.gd, src/ui/PlantHotbar.gd, scenes/MainMenu.gd, GEMINI.md |
| 67 | Integration of Dedicated 32×32 Square Buttons Across HUD & Modals: 1) Sliced and generated 9 new dedicated 9-slice `StyleBoxTexture` resources in `res://assets/sprites/hud/Buttons/Squarebutton/`: `SquareBrownButton.tres`, `SquareBrownButtonHover.tres`, `SquareBrownButtonPressed.tres`, `SquareYellowButton.tres`, `SquareYellowButtonHover.tres`, `SquareYellowButtonPressed.tres`, `SquareLightButton.tres`, `SquareLightButtonHover.tres`, `SquareLightButtonPressed.tres` using the user's authentic 32×32 pixel art textures with dedicated pressed states; 2) Eliminated stretched rectangular button artifacts (previously forcing 144×32 `BrownButton.tres` into 30×30 boxes) across all dialog close buttons: `MarketPanel.gd` (`_close_btn`), `SellPanel.gd` (`_close_btn`), `EarlyHarvestModal.gd` (`_close_btn`), `LandExpansionModal.gd` (`_close_btn`), `SaveLoadModal.gd` (`close_btn` & `del_btn` delete slot button), `BuildingCardPopup.tscn` (`CloseBtn`), and `ShopPanel` in `MainGame.tscn` (`CloseBtn` & `InfoCloseBtn`); 3) Upgraded `_create_info_btn()` ("!") in `ShopPanel.gd` to native 30×30 square button; 4) Upgraded `PlantHotbar.gd` drawer minimize button (`min_btn`), hotbar slot button normal/hover textures (`tex_dark_box` -> `brown-button.png`, `tex_light_box` -> `Light-button.png`); 5) Expanded `scratch/run_verify_ui.tscn` test suite to 14/14 automated checks passing 100% in Godot 4.7.2 headless | assets/sprites/hud/Buttons/Squarebutton/*, src/market/MarketPanel.gd, src/market/SellPanel.gd, src/ui/EarlyHarvestModal.gd, src/ui/LandExpansionModal.gd, src/ui/SaveLoadModal.gd, scenes/BuildingCardPopup.tscn, scenes/MainGame.tscn, src/market/ShopPanel.gd, src/ui/PlantHotbar.gd, scenes/MainMenu.gd, GEMINI.md |
| 68 | Main Menu Mode Select Typography Enlargement & De-Cluttering: 1) Eliminated walls of text and repetitive essays across the Mode Select Billboard in `scenes/MainMenu.gd`, `scenes/MainMenu.tscn`, and `scenes/StartMenu.tscn`; 2) Streamlined mode descriptions to single punchy sentences: Campaign ("Compete against 8 regional AI rivals to earn the highest tycoon score before the season ends!") and Career ("Build and expand your agricultural empire at your own relaxed pace with zero deadlines or pressure."); 3) Trimmed feature pillars from 3 dense paragraphs down to 2 crisp, high-impact bullet points per column; 4) Significantly enlarged typography across the board: Mode Taglines 14pt (was 11pt), Mode Description 16pt (was 12pt), Pillar Titles 17pt (was 14pt), Pillar Bullets 15pt (was 12pt), Season Duration Buttons & Label 14pt (was 11–12pt), Season Explainer 14pt (was 11pt), Career Perks Badges 14pt (was 12pt), and Primary Start/Load Buttons 16pt (was 14pt); 5) Increased Season and Action button sizes (`185×36` and `400×46`/`220×46`) to comfortably house larger fonts with generous breathing room; 6) Verified 100% pass across all 14 UI regression tests and newly created `run_test_main_menu.tscn` in Godot 4.7.2 headless | scenes/MainMenu.gd, scenes/MainMenu.tscn, scenes/StartMenu.tscn, GEMINI.md |
| 69 | Region Select Screen Typography Enlargement, Text De-Cluttering & Dead Space Elimination: 1) Streamlined regional descriptions, advantages (pros), and hazards (cons) across all 5 regions in Data.gd from wordy paragraphs down to punchy, informative points with clean unicode bullets (•); 2) Upgraded RegionHeaderBox in CarouselBar to use carved wooden plaque (LongRectangle.tres, 600×54 px), enlarging RegionNameLabel to 21pt (was 19pt) and RegionSpecialtyLabel to 14pt (was 12pt); 3) Tightened MiddleCard bounds from 480px down to 345px height (offset_bottom changed from 275 to 150), completely eliminating ~200px of empty black void and revealing the scenic background art; 4) Enlarged typography across the entire Dossier: DossierHeader 17pt (was 14pt), DescLabel 16pt (was 13pt), Specs titles 13pt (was 11pt) and values 16pt (was 13pt), Advantages/Hazards headers 16pt (was 13pt) and bullets 15pt (was 12pt); 5) Enlarged navigation and action buttons: Back to Game Modes button 14pt (210×40 px), Mode Badge 14pt, Map card titles 13pt, Start Button 16pt (420×46 px); 6) Verified 100% pass across all 5 regions and all 14 UI regression tests in Godot 4.7.2 headless | autoload/Data.gd, scenes/MainMenu.gd, scenes/MainMenu.tscn, GEMINI.md |
| 70 | Clash of Clans-Style Visual Card Grid Shop Overhaul: 1) Replaced text-heavy catalog list rows in ShopPanel with a modern, minimalistic 3-column card grid showcasing prominent pixel-art sprites for all 16 items across all 5 categories (Housing & Labor, Storage, Weather & Irrigation, Machinery & Fleet, Land Parcels); 2) Designed ShopSpritePreview featuring authentic building textures (KUBO.png, Silo, Bilaran dryer, Cold Storage, Weather Station, Water Station, Drone Station, Farmer icon, Grass parcel) on soft isometric shadow pedestals with subtle radial spotlight glows; 3) Implemented custom procedural 2.5D artwork for Machine Depot (apron, shed wall, gantry crane, red tractor), Rotary Sprinkler (anchor pad, galvanized riser, brass head, spray arc with water droplets), and Precision Drone (quadcopter body, motors, rotors); 4) Re-architected card layout: Header (bold 14pt title + [i] info trigger) -> Center (94px sprite showcase) -> Meta strip (12pt build time/size + green perks/status) -> Bottom (36px gold/disabled action button); 5) Expanded ShopPanel footprint to 850×520 px, eliminating text squishing and clutter; 6) Expanded UI verification test suite to 15/15 passing assertions in Godot 4.7.2 headless | src/market/ShopPanel.gd, scenes/MainGame.tscn, scratch/verify_all_ui_overhauls.gd, GEMINI.md |
| 71 | Dedicated PAGASA Agri-Weather App & Meteorological Forecast Dashboard: 1) Created dedicated `WeatherAppModal` (`src/ui/WeatherAppModal.gd`, 880×560 px canvas layer dialog) styled with BigPlainBox, Samplebox, and BrownBox pixel-art frames; 2) Intercepted weather station left-clicks in `FarmGrid.gd` (`_on_building_clicked`) and HUD weather capsule clicks in `HUD.gd` (`_open_weather_app_from_hud`) to open the Weather App instead of the generic building card; 3) Current Conditions Hero Card: displays real-time ambient & effective temperature (°C), weather condition headline, feels-like temperature, daylight/night cycle period, live disaster countdowns/strikes, and 4 agronomic vitals chips (Relative Humidity, Daily Rainfall, Radar Accuracy %, Emergency Warning Lead Time); 4) Multi-Day Forecast Horizon Strip: renders a clean 7-day horizontal prediction outlook with weather icons, expected temps, moisture %, rainfall estimates, hazard alert pills (Flood, Drought, Landslide, Clear), and actionable crop advice; 5) Station Upgrade Progression Range: AM Radio Mast Lv.1 unlocks Day 1 (60% accuracy, 8s warning), AWS Lv.2 unlocks Days 1–3 (90% accuracy, 12s warning), Satellite Uplink Dish Lv.3 unlocks full 7-day outlook (100% precision, 18s warning), with locked days displaying tier requirements; 6) Station Management Integration: embedded station upgrade and demolish actions with real-time construction/calibration progress bars; 7) Verified 100% test pass in `scratch/run_verify_weather_app.tscn` and `scratch/run_verify_ui.tscn` (15/15 checks) | src/ui/WeatherAppModal.gd, autoload/WeatherManager.gd, autoload/BuildingManager.gd, src/core/FarmGrid.gd, src/ui/HUD.gd, GEMINI.md |
| 72 | Elimination of 9-Slice Repeating Seam Lines & Internal Corner Notches Across BrownBox and InnerBox2x StyleBoxes: 1) Diagnosed the root cause of the repeating vertical lines and dark rivet notches seen inside `BrownBox.tres` (`HUD-dark brown.png`): Godot's `axis_stretch_horizontal = 1` and `axis_stretch_vertical = 1` forced tiling mode across wide containers (>144px), while under-specified 10px margins clipped 3-4px of the border bevel shadow into the center tile; 2) Adjusted `BrownBox.tres` texture margins from 10.0 to 14.0 px and switched stretch modes to `axis_stretch_horizontal = 0` / `axis_stretch_vertical = 0` (STRETCH mode), stretching the pure uniform `(112, 69, 44)` center color seamlessly; 3) Adjusted `InnerBox2x.tres` (`Inner-box-2x.png`) margins from 20/18 to 22/20 px with `axis_stretch = 0`; 4) Updated button StyleBox textures (`BrownButton` and `GoldButton`) to `axis_stretch = 0` to prevent seam artifacts on wide buttons; 5) Verified 100% test pass in `scratch/run_verify_ui.tscn` (15/15 checks) and `scratch/run_verify_weather_app.tscn` in Godot 4.7.2 headless | assets/sprites/hud/TopRight/BrownBox.tres, assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres, assets/sprites/hud/Buttons/*, GEMINI.md |
| 73 | Calibration of Updated Building Sprites (Cold Storage, Drone Station, Water Station, Weather Station): 1) Discovered all 4 updated building textures were upgraded to unified 208×212 px pixel-art canvases with integrated isometric ground base diamonds (~204 px wide); 2) Removed legacy 2x scale multipliers in `src/buildings/Building.gd` that caused 416×424 px oversized rendering and terrain sinking; 3) Calibrated draw rects with sub-pixel ground alignment: Cold Storage `Rect2(-104, -150, 208, 212)` on 3×3 footprint, Water Station `Rect2(-104, -160, 208, 212)` on 2×2 footprint, Drone Station `Rect2(-104, -154, 208, 212)` on 2×2 footprint, Weather Station `Rect2(-104, -148, 208, 212)` on 3×3 compound; 4) Re-anchored interactive & atmospheric visuals; 5) Re-anchored overhead UI badges and scaffolding heights; 6) Verified 100% test pass in Godot 4.7.2 headless | src/buildings/Building.gd, assets/sprites/buildings/*, GEMINI.md |
| 74 | Pixel-Perfect Scaling & Footprint Diamond Calibration of 2×2 and 3×3 Building Sprites: 1) Calibrated and scaled each building sprite so its base compound/pavement diamond fits within tile boundaries; 2) Tested on 208×212 updated sprites | src/buildings/Building.gd, GEMINI.md |
| 75 | Reversion to Original Buildings from OLD BUILDINGS Folder: 1) Per user instruction ("Its not working, in the folders there is the old buildings just use those again like before"), restored the original 4 building sprite PNGs from `assets/sprites/buildings/OLD BUILDINGS/` into `assets/sprites/buildings/`: `Cold Storage.png` (96×80 px), `Drone Station.png` (80×128 px), `Water Station.png` (64×144 px), and `Weather Station.png` (112×128 px); 2) Fully reverted rendering, scaling, draw rects, interactive lights/beacons, overhead UI `roof_apex_y`, and scaffolding heights in `src/buildings/Building.gd` back to original proven 2× scaling configuration from commit `1d2edb3`: Cold Storage `Rect2(-cs_w * 0.5, -104.0, cs_w, cs_h)` (192×160 px), Water Station `Rect2(-ws_w * 0.5, -252.0, ws_w, ws_h)` (128×288 px), Drone Station `Rect2(-ds_w * 0.5, -216.0, ds_w, ds_h)` (160×256 px), Weather Station `Rect2(-wea_w * 0.5, -194.0, wea_w, wea_h)` (224×256 px); 3) Verified 100% pass across all test suites in Godot 4.7.2 headless | src/buildings/Building.gd, assets/sprites/buildings/*, GEMINI.md |
| 76 | HUD Clipboard Inspector Layout, Symmetry, Inner Border Bars & Large Fonts Overhaul: 1) Symmetrical Clipboard & Margin Alignment: eliminated asymmetrical margins (`Clipboard.tres` previously 42px left and 61px right; now symmetrical 40px left & right); introduced `MarginContainer` (`margin_left=36, margin_right=36, margin_top=58, margin_bottom=20`) clearing the top metal clamp (54px) with generous breathing room and uniform 16:9 480×270 dimensions matching `Clipboard.png` aspect ratio; 2) Centered PlantBox: corrected `PlantBox.tres` content margin bug (`content_margin_right` was 96.0px, which shoved icons 84px to the far left; now symmetrical 12px on all 4 sides), perfectly centering thumbnails (`PortraitIcon` and `PortraitTexture` 64×64); 3) Authentic Inner Border for Gauges: created `InnerBarBg.tres` using authentic `res://assets/sprites/hud/Inner-container/HUD-dark brown.png` (32px inner border container); applied to `GrowthBar`, `HealthBar`, and `MoistureBar` backgrounds; upgraded bar height to 22px with polished fills (golden amber growth `Color(0.85, 0.65, 0.20)`, emerald health, water blue moisture); 4) Large Legible Fonts Across Entire Panel: upgraded all fo| 78 | Standing Crop Foliage Occlusion Transparency & Worker Character Visibility: 1) Solved the issue where standing crop sprites (up to 256–384px tall) in tile `Overlay` completely hid farmer workers on the same tile or walking through the field; 2) Implemented real-time dynamic Foliage Occlusion Transparency (`_update_foliage_occlusion`) in `FarmGrid.gd`: checks active workers every frame against nearby candidate standing crops, 2×2 multi-tile canopies, and tree obstacles within horizontal ($dx \le 52$–$88$ px) and vertical ($dy \le 180$–$240$ px) bounds; smoothly fades occluding tile `Overlay.modulate.a` down to `0.35` see-through glass foliage (restoring to `1.0` when workers leave); 3) Established clear 2.5D visual layer hierarchy: GroundLayer at Z=0, standing crop and foliage overlays at Z=10, Farmer workers, vehicles (Kuliglig & Combine Harvester), and shadows at Z=12 (rendering workers in front of field crops), and standing Buildings at Z=14 (naturally occluding workers who walk behind them); 4) Upgraded `FarmerLabel` Z-index to 15, ensuring worker status tags ("🌾 Harvesting...", "💧 Watering...", "🧑‍🌾 Ready") remain 100% visible and legible above all foliage; 5) Enabled `y_sort_enabled = true` on `tile_roots` and `overlay` nodes in `FarmGrid.gd`, and reset overlay alpha to 1.0 when plots are cleared in `TileRenderer.gd`; 6) Automated Verification: created `scratch/run_test_crop_farmer_overlap.tscn` verifying occlusion detection, 0.35 alpha fade, 1.0 alpha restoration, and Z-index layering across 1×1 crops and 2×2 coconut groves (100% pass), and confirmed 0 regressions across all 15 tests in `run_verify_ui.tscn`, all 7 tests in `run_test_runner.tscn`, and `run_verify_tile_panel.tscn` in Godot 4.7.2 headless | src/core/FarmGrid.gd, src/farmer/Farmer.gd, src/buildings/Building.gd, src/ui/HUD.gd, src/core/TileRenderer.gd, scenes/MainGame.tscn, scratch/test_crop_farmer_overlap.gd, scratch/run_test_crop_farmer_overlap.tscn, GEMINI.md |
| 79 | Value-Added Processing & Agro-Industrial Milling Automation: 1) Data Models & Commodities: Added `PROCESSED_GOODS` to `Data.gd` registering 7 value-added commodities (`milled_rice`, `rice_bran`, `muscovado_sugar`, `molasses`, `vco`, `copra_meal`, `roasted_coffee`) with base prices, icons, descriptions, and `is_processed: true`; updated `get_crop()` and added `get_commodity()` / `is_processed_good()`; updated `LeaderboardManager.gd` `BASE_CROP_POINTS` for processed goods; 2) Facilities & Industrial Recipes: Added 4 agro-industrial processing facilities to `Data.BUILDINGS` (`rice_mill` ₱1,400, `sugar_mill` ₱1,800, `copra_dryer` ₱2,200, `coffee_roastery` ₱2,600) with input/output recipes and category `"processing"`; 3) Late-Game Progression Gating: Enforced progression gate via `BuildingManager.get_processing_prerequisites()` requiring both a purchased territory deed (`unlocked_parcels.size() > 1`) and upgraded warehouse infrastructure (storage capacity $\ge 400$ or cold storage), displaying clear locked badges and prerequisite tips in shop; 4) Automated Milling Pipeline: Connected `BuildingManager` to `TimeManager.hour_changed` triggering an automated batch run every 4 in-game hours; `MarketManager.consume_crop_quantity()` consumes aging raw crops (lowest freshness first) and `add_processed_to_storage()` produces shelf-stable output batches with 0% spoilage; records Chronicle log events and plays completion SFX; 5) Shelf-Stable Storage & Transit Protection: Processed goods are 100% immune to storage decay in `process_hourly_spoilage()` and enjoy 0% road rot transit decay when selling across all provincial hubs in `sell_stored_batch()` and `sell_all_of_crop()`; 6) 2.5D Vernacular Artwork: Designed procedural isometric artwork in `Building.gd` for all 4 facilities (Kiskisan millhouse with vibrating shaker, hopper, and burlap sacks; Trapiche brick central with smoking chimney, iron crushing gears, cane chute, boiling cauldrons, and muscovado sugar blocks; Tapahan fieldstone kiln with flickering charcoal fire, bamboo drying grate, coconut halves, and screw oil press; and Artisan Roastery with red volcanic brick oven, rotating cast-iron drum, cooling agitation tray, and exhaust flue); 7) Shop & Trade UI: Added dedicated 5th tab `Processing` in `ShopPanel.gd` with Clash of Clans-style cards, live prerequisite checks, and procedural sprite showcases; updated `BuildingCardPopup.gd` with live batch recipe statistics; integrated shelf-stable indicators in `SellPanel.gd`; 8) Automated Verification: Created `scratch/run_test_processing.tscn` passing 100% across data models, inventory consumption, milling automation, spoilage immunity, and sales; confirmed 100% pass with 0 regressions in `scratch/run_verify_ui.tscn` (all 15 tests) | autoload/Data.gd, autoload/MarketManager.gd, autoload/BuildingManager.gd, autoload/LeaderboardManager.gd, src/buildings/Building.gd, src/buildings/BuildingCardPopup.gd, src/market/ShopPanel.gd, src/market/SellPanel.gd, src/core/FarmGrid.gd, scratch/test_processing_system.gd, scratch/run_test_processing.tscn, GEMINI.md |
| 80 | Start Menu Side Wings & Center Stage Billboard Redesign with Snappy Transition Animations: 1) Three-Wing Start Menu Layout: Restructured `ModeSelectView` in `scenes/MainMenu.tscn` and `scenes/StartMenu.tscn` into a 3-wing horizontal layout (`StartMenuHBox` 1220×616 px) featuring `LeftUtilityWing` (`🌾 FARM DESK`: Saved Games, Settings, Multiplayer, Debug Panel), `CenterStage` (`BillboardPanel` with `BigRectangleLogs.tres`), and `RightUtilityWing` (`🏆 RECORDS`: Hall of Fame, Chronicle, Farm Guide, Personal Best card); 2) Interactive Center Stage & Mode Tabs: Replaced carousel with direct tab buttons (`🏆 TIMED CAMPAIGN` and `🌾 CAREER TYCOON`) featuring gold active state, 18pt punchy mode descriptions, 16pt taglines, and a dedicated `PillarsCard` (`Samplebox1.tres`) with 18pt titles and 16pt bullets; clicking tabs triggers a snappy pop-up bounce animation (`_select_mode_carousel`); 3) De-cluttered & Synchronized Typography: Eliminated walls of text and dead voids; constrained `MiddleCard` height in Region Selection to 325px (well below 360px limit) with `Samplebox1.tres` warm parchment matching `TopRightMapCard`, crisp 18pt dossier headers, 17pt stats, and 16pt bullets; 4) Smooth Screen Transition Animations: Implemented snappy Tween transitions between Start Menu and Region Selection (`_show_region_select` and `_show_mode_select`) with horizontal slide (-80px to 0) and fade (0.0 to 1.0 in 0.25s), keeping immediate visibility updates for zero-lag test compatibility; 5) Humorous Barangay Dial-Up Multiplayer & Utility Modals: Implemented humorous dial-up failure dialog (Mang Jose's carabao severed the fiber optic line in the rice paddies), working Settings & Audio modal (Master/SFX volume sliders, mute toggle, admin toggle), and Tycoon Guide modal attached cleanly via `add_child()`; 6) Verification: Verified 100% pass on `scratch/run_test_main_menu.tscn`, `scenes/MainMenu.tscn --test-menu`, and all 15 UI regression assertions in `scratch/run_verify_ui.tscn` in Godot 4.7.2 | scenes/MainMenu.tscn, scenes/MainMenu.gd, scenes/StartMenu.tscn, scratch/run_test_main_menu.tscn, scratch/capture_menu_views.gd, scratch/capture_modals.gd, GEMINI.md |
| 81 | Minimalist Start Menu with Prominent Left Stack & Direct Mode Selection: 1) Minimalist Start Menu: Removed the cluttered middle billboard and wings per user feedback ("minimalistic look less to see put the important buttons almost to the left side, remove the middle part just makeit look less make the more important bttons bigger"), showcasing the panoramic Philippine mountain background unobstructed; 2) Prominent Left-Side Stack: Built `LeftMenuVBox` at `offset_left = 60, offset_top = 88, width = 350` housing enlarged, high-contrast primary buttons: `🏆 TIMED CAMPAIGN` (350×60 px, 18pt font, gold button), `🌾 CAREER TYCOON` (350×60 px, 18pt font), `💾 SAVED GAMES` (350×50 px, 16pt font), clean separator line, and secondary utility buttons (42px height, 15pt font) for Settings, Multiplayer, Hall of Fame, Chronicle, Farm Guide, and Debug Panel; 3) Direct Snappy Mode Progression: Clicking `🏆 TIMED CAMPAIGN` or `🌾 CAREER TYCOON` directly selects the mode and smoothly transitions via horizontal slide and fade into the Region Select screen without intermediate popup clutter; 4) Region View Header Cleansing: Hid `TopCenterHeader` in Region Select view so `← BACK TO MAIN MENU` (210×40 px) and active mode badge (`[ TIMED CAMPAIGN: 60 DAYS ]` / `[ CAREER: ENDLESS ]`) sit cleanly in the top-left corner with zero text overlap; 5) Compatibility & Scene Synchronization: Preserved all test query nodes (`%ModeDescLabel`, `%Pillar1Title`, `%ModeStartBtn`, etc.) inside `ModePopupModal` (`visible = false`), and synced identical layout to standalone `scenes/StartMenu.tscn`; 6) Verification: Verified 100% pass on `scratch/run_test_main_menu.tscn`, `scenes/MainMenu.tscn --test-menu`, and all 15 UI regression assertions in `scratch/run_verify_ui.tscn` in Godot 4.7.2 headless | scenes/MainMenu.tscn, scenes/MainMenu.gd, scenes/StartMenu.tscn, GEMINI.md |
| 82 | Mode Hover Explanations: 3-Sentence Dynamic Parchment Cards & Tooltips: 1) Strict 3-Sentence Mode Explanations: Added concise, simple 3-sentence descriptions per mode (Campaign: 8 AI rivals in timed Mindanao score attack, 30/60/90 day season RTS clock, climb 5 prestige tiers for Hall of Fame; Career: manage enterprise at relaxed pace with zero deadlines, cultivate perennial groves across 24×24 grid with midnight autosaves and 5 slots, unlock drone fleets and agro-industrial processing; Saves: access 5 manual slots or resume ongoing career, midnight autosaves protect farm and treasury, load previous playthroughs or backup homestead); 2) Dynamic ModeHoverCard UI: Created `ModeHoverCard` (500×220 px) in `scenes/MainMenu.tscn` and `scenes/StartMenu.tscn` using authentic `Samplebox1.tres` parchment with `mouse_filter = 2` (IGNORE) so it never blocks mouse movement; 3) Responsive Alignment & Tween Transitions: Aligns dynamically to `x = 430.0` right beside whichever button is hovered, smoothly tweening vertically and fading in (0.12s) when moving between Campaign, Career, and Saved Games; immediately fades and hides upon mouse exit, mode button click, or modal dialog invocation (`_hide_mode_hover_card_immediate()`); 4) Accessible Tooltip Parity: Assigned identical 3-sentence strings to Godot button `tooltip_text` on `SideCampaignBtn`, `SideCareerBtn`, and `SideSavesBtn` as a standard engine fallback; 5) Verification: Confirmed 100% pass across `scratch/run_test_main_menu.tscn`, `scenes/MainMenu.tscn --test-menu`, and all 15 UI regression assertions in `scratch/run_verify_ui.tscn` in Godot 4.7.2 | scenes/MainMenu.tscn, scenes/MainMenu.gd, scenes/StartMenu.tscn, GEMINI.md |
| 83 | HUD Pixel-Art Icon Buttons, Live Storage Fill-Up Bars & Smart Crop Routing: 1) Replaced text buttons on bottom-right HUD (`CommandCorner`) with 44×44 square pixel-art buttons (`SquareBrownButton`, `SquareYellowButton`) featuring custom 32×32 pixel art icons (`res://assets/icons/HUD/Market.png`, `res://assets/icons/HUD/Basket.png`, `res://assets/icons/HUD/Build.png`) and responsive tooltips; 2) Live Storage Progress Bars: enabled `StorageBar` in top-right HUD `StorageCapsule` with dynamic color-coding (<70% green, 70–90% amber, >=90% red) and added in-world overhead storage fill meters (`storage_fill_box` with label and progress bar) above active storage buildings (`bodega`, `cold_storage`, `climate_silo`); 3) Smart Crop Routing & Facility Filters: added `assigned_crops` filter to storage buildings (`Building.gd`) with quick presets (`All Crops`, `Grains Only`, `Perishables Only`) and individual crop toggle buttons in `BuildingCardPopup`; 4) Integrated routing with labor and automation: `Farmer.gd` workers deposit harvested crops into the designated, non-full storage facility accepting that crop; `FarmDrone.gd` checks per-crop storage availability before harvesting; `FarmGrid.gd` guards manual tile harvesting against crop-specific storage limits; 5) Fully serialized and restored `assigned_crops` and `used_storage` in `SaveManager.gd`; 6) Automated Verification: created `scratch/run_test_storage.tscn` (100% pass) and verified zero regressions across UI assertions (15/15), processing system, and tile inspection tests in Godot 4.7.2 headless | scenes/MainGame.tscn, src/ui/HUD.gd, src/buildings/Building.gd, autoload/BuildingManager.gd, autoload/MarketManager.gd, scenes/BuildingCardPopup.tscn, src/buildings/BuildingCardPopup.gd, src/farmer/Farmer.gd, src/drone/FarmDrone.gd, src/core/FarmGrid.gd, autoload/SaveManager.gd, scratch/test_storage_routing_and_bars.gd, scratch/run_test_storage.tscn, GEMINI.md |
| 84 | QoL Simulation Hotkeys, Stale Building Tile Flood Immunity & Lush Grass Regrowth: 1) Stale Building Tile Protection & Flood Immunity: diagnosed and fixed the issue where building tiles got flooded or waterlogged during rain and flash floods. Tiles under buildings are now completely stale/static (`tile.state == BUILDING` or `building_ref != null` are guarded in `TileAgronomySystem.gd` `process_hour`/`process_day` and `FarmGrid.gd` `_process_flash_flood_impact`, `_process_drought_impact`, `_process_landslide_impact`, `_on_weather_changed`); `place_building()` completely resets crop, moisture, and waterlogging counters on occupied plots; 2) Grass Regrowth Under Done Buildings: updated `GroundTileSprites.gd` so while a building is actively constructing (`BuildingState.CONSTRUCTING`) it shows compacted earth (`WALK-SOIL`), but the moment construction completes (`BuildingState.ACTIVE`), the ground tiles under the building smoothly regrow to lush green grass (`normal_grass_variants` / `NGRASS`); `complete_construction()` in `Building.gd` sets moisture to 60.0 and refreshes tile renderers; `_on_building_demolished()` resets plots to `EMPTY` and 60.0 moisture for instant green grass; 3) Uncultivated Plowed Land Regrowth: uncultivated plowed plots left empty for 3 days automatically revert back to wild grass (`EMPTY`); 4) Interactive Tile Hover Reticle: added isometric cursor highlight diamond (`hover_indicator` in `FarmGrid.gd`) dynamically outlining the tile under mouse with green highlight for harvest-ready crops, amber for obstacles, red for locked, and warm gold for plowable/plantable land; 5) Prominent Parcel Boundaries: rendered dynamic golden boundary perimeter lines with shadow depth, locked boundary lines, and rustic corner survey pegs with red ribbons around unlocked parcels (`_update_parcel_boundaries()`); 6) Simulation Hotkeys & Worker Navigation: added `Space` (Pause/Play toggle), `1`/`2`/`3` (Speed mode), `Tab` (cycle idle workers + pan camera), `H`/`Home` (center camera on Homestead), `V` (`harvest_all_ready_crops()` batch harvest); added idle worker counter badge (`⚡X`) and click-to-cycle to `WorkerCapsule`; 7) Automated Verification: created `scratch/run_test_qol.tscn` passing 100% across all QoL, stale building flood immunity, and grass regrowth checks | src/core/FarmGrid.gd, src/core/TileAgronomySystem.gd, src/core/GroundTileSprites.gd, src/buildings/Building.gd, src/farmer/Farmer.gd, src/world/GameCamera.gd, src/ui/HUD.gd, scratch/test_qol_features.gd, scratch/run_test_qol.tscn, GEMINI.md |
| 85 | Crop Visual Polishing & Dark Square Shadow Removal: 1) Diagnosed and eliminated the artificial dark diamond/square polygon shadow (`shadow` with color `Color(0.08, 0.12, 0.06, 0.35)`) that was drawn on top of the soil bed for every custom crop in `TileRenderer.gd` (`_draw_custom_crop_sprite`); 2) Cleaned up `_apply_fill_color` for `PLANTED`, `GROWING`, and `HARVESTABLE` tiles in `TileRenderer.gd`: ensured that when procedural fallback is active, `sprite` (`GroundSprite`) is properly passed to `_apply_sprite_or_color` rather than `null` (which previously caused Polygon2D textures without UVs to render as pitch-black holes); 3) Verified that all 7 crops (1×1 Palay, Yellow Corn, Sugarcane, Pineapple, Coffee, as well as 2×2 Banana and Coconut groves) now render cleanly and naturally on their beds without harsh geometric dark square artifacts; 4) Confirmed 100% pass across all automated test suites (`run_test_qol.tscn`, `run_verify_ui.tscn` 15/15 assertions, `run_test_storage.tscn`, and `run_test_processing.tscn`) in Godot 4.7.2 headless | src/core/TileRenderer.gd, GEMINI.md |
| 87 | Temperature Sprites Integration & Carved Wooden Button 9-Slice Suite: 1) Temperature Sprites Integration: Embedded the user's authentic pixel-art temperature sprites from `assets/icons/Tempreture/` (`Cold .png` <23°C/cool, `Just-Right.png` 23–29°C/optimal, `Sunny.png` 29–34°C/warm, `Fire.png` >=34°C/scorching heat/El Niño); 2) HUD RegionWeatherBox Symmetry & Modernization: Upgraded `RegionWeatherBox` in `HUD.gd` and `MainGame.tscn` with symmetrical `WeatherRow` and `HumidityRow` HBox containers; embedded `WeatherIcon` (TextureRect) displaying real-time temperature sprites and `HumidityIcon` displaying `water-drop.png`, replacing plain text emojis with crisp nearest-neighbor pixel art icons; 3) PAGASA WeatherApp Integration: Updated `WeatherAppModal.gd` `_get_weather_icon()` to use `Wave.png` for flood hazards, `Fire.png` for drought/heatwaves, `Sunny.png`, `Just-Right.png`, and `Cold.png` across daily forecast cards, and added static helper `get_temperature_icon(temp, climate)`; 4) Carved Wooden Button 9-Slice Suite: Sliced and generated 4 new `StyleBoxTexture` resources in `assets/sprites/hud/Buttons/WoodenButton/` and `DarkWoodenButton/`: `WoodenButton.tres`, `WoodenButtonHover.tres` (1.15x brightness), `WoodenButtonPressed.tres` (using `Dark-Wooden-button.png`), and `DarkWoodenButton.tres` with calibrated 9-patch margins `(10, 6, 10, 9)` and content margins `(12, 4, 12, 7)`; 5) Button Upgrades: Applied `WoodenButton` suite to HUD `BacklogButton` (`BACKLOG (L)`) with warm ivory typography, and upgraded `BayanihanModal.gd` buttons (`_apply_btn` with Goldbutton, `cancel_btn` with WoodenButton, and `_close_btn` with SquareBrownButton); 6) Automated Verification: Created `scratch/run_test_temperature_and_buttons.tscn` passing 100%, and verified 0 regressions across all 15 UI overhaul assertions, WeatherApp suite, Bayanihan suite, storage routing, and agro-industrial processing tests in Godot 4.7.2 headless | assets/icons/Tempreture/*, assets/sprites/hud/Buttons/WoodenButton/*, assets/sprites/hud/Buttons/DarkWoodenButton/*, src/ui/HUD.gd, scenes/MainGame.tscn, src/ui/WeatherAppModal.gd, src/ui/BayanihanModal.gd, scratch/test_temperature_and_buttons.gd, scratch/run_test_temperature_and_buttons.tscn, GEMINI.md |
| 88 | BuildingCardPopup Layout Overhaul, Framed Logistics Sub-Card & Symmetrical Crop Routing Desk: 1) Eliminated Stretched 7th Crop Button & Cramped Layout: Replaced `HFlowContainer` with a structured 4-column `GridContainer` (`CropButtonsGrid`), expanding popup width from 490px to 560px for balanced breathing room; 2) Framed Storage Sub-Card (`StorageSubCard`): Wrapped storage meter and crop dispatch inside an authentic `BrownBox.tres` inset panel, giving facility routing its own dedicated visual hierarchy rather than floating loosely in the main dialog; 3) Symmetrical 4×2 Grid with 8th Action Button: Configured a balanced 8-slot matrix featuring full crop titles ("🌾 Rice", "🌽 Corn", "🎋 Sugarcane", "🍍 Pineapple", "☕ Coffee", "🍌 Banana", "🥥 Coconut") plus an 8th utility action ("🚫 Deselect All" with soft rose accent), keeping every button at a uniform 112×32px; 4) Dynamic Preset Highlighting: Updated `PresetHBox` (`All Crops`, `Grains Only`, `Perishables`) to dynamically illuminate the currently active preset with `Goldbutton.tres` and deep espresso text; 5) Typography & Double Bullet Cleansing: Removed redundant leading bullet points (`• `) before icons across all building stats lines in `_format_stats()`; 6) High-Contrast Storage Meter: Enlarged `FillProgressBar` to 18px with inset border and dynamic color thresholds (<70% emerald green, 70–90% amber, >=90% coral) with mint readout text; 7) Clean Dark Wooden Upgrade Button: Replaced Godot's flat-grey default disabled button fallback with `DarkWoodenButton.tres` and warm ivory text with interactive error audio feedback when funds are insufficient; 8) Automated Verification: Tested with 100% pass across `run_test_storage.tscn`, `run_verify_ui.tscn` (15/15 checks), `run_test_bayanihan.tscn`, `run_test_processing.tscn`, and `run_verify_weather_app.tscn` in Godot 4.7.2 headless | scenes/BuildingCardPopup.tscn, src/buildings/BuildingCardPopup.gd, GEMINI.md |
| 89 | Split-Card Landscape UI Overhaul Across All Building Types: 1) Widescreen Split-Card Architecture: Expanded `BuildingCardPopup` modal from 560px to 850px (`custom_minimum_size = Vector2(850, 0)`), splitting dialog into a prominent Left/Center Bigger Box (`FeatureBox`, stretch ratio 1.45, ~490px) and a focused Right Smaller Box (`SideBox`, stretch ratio 0.95, ~310px); 2) Center Bigger Box — Dedicated Operations & Live Feature Workstation: Custom operational cards dynamically adapted across all 14 building types: Storage facilities feature live storage fill progress bar (<70% green, 70-90% amber, >=90% coral), sub-zero cold storage banner, 4x2 uniform crop routing desk with preset pills, and storage logistics intelligence card; Agro-Industrial mills feature 4h batch cycle intervals, shelf-stable commodity immunity, input consumption with live farm stock counters and mini progress bar (Ready vs Needs Harvest), output commodity lists with prices, and total revenue potential per batch; Irrigation displays equipment tier, live active/capacity sprinkler gauge bar, soil evaporation shield (-10%/-25%/-35%), and flood drainage stats; Sprinklers display spray geometry and morning schedule; Drone Hangar displays flight automation tiers (Plow/Seed/Harvest), pilot operator ratio, and autonomous parcel scanning; Bayanihan Center features teamwork speed boost (+35%/+75%/+120%) and an interactive Goldbutton `[ 📋 Open Parcel Directives Menu ]`; PAGASA Weather Station features radar tier, emergency warning lead time, and an interactive Goldbutton `[ 🌦️ Open Full 7-Day Weather App ]`; Solar Dryer features sun-curing price multipliers (+25%/+40%/+55%); Bahay Kubo features workforce accommodations and living amenities; 3) Right Smaller Box — Facility Explanation & Upgrades Desk: Displays level stars, high-contrast status badge (Active `#73eb8c`, Constructing `#f2bf59`, Upgrading `#73ccff`), concise 1-sentence building role summary, active level perks, next tier bonuses preview with cost & build time (or Max Tier Reached), full-width Goldbutton/DarkWooden upgrade button with error audio feedback, and full-width demolish button; 4) Automated Verification: Verified 100% pass across `run_verify_ui.tscn` (all 15 assertions), `run_test_storage.tscn`, `run_test_processing.tscn`, `run_test_bayanihan.tscn`, `run_verify_weather_app.tscn`, and `run_test_temperature_and_buttons.tscn` in Godot 4.7.2 | scenes/BuildingCardPopup.tscn, src/buildings/BuildingCardPopup.gd, scratch/test_render_building_cards.gd, GEMINI.md |
| 90 | Bayanihan System Demystification, Premature Field Post Fix & Building Card Access: 1) Eliminated Premature Signpost Spawning: Fixed `FarmGrid._create_bayanihan_field_posts()` which previously spawned wooden survey posts on unlocked parcels from Day 1 second 0 before players bought the building; field posts now strictly require `BuildingManager.has_bayanihan_center()` to exist; connected `BuildingManager.bayanihan_updated` to dynamically erect directive boards when the Bayanihan Cooperative Post is built/active and cleanly remove them if demolished; 2) Restored Bayanihan Center Building Card Access: Removed click hijacking in `FarmGrid._on_building_clicked()` which previously bypassed `BuildingCardPopup` and forced open `bayanihan_modal`, allowing players to inspect the full split-card building UI, view level stars, upgrade tiers, check stats, and demolish; 3) Enhanced Bayanihan Center Building Card UI: Upgraded `BuildingCardPopup._populate_bayanihan_features()` with 3 comprehensive cards: Card 1 (Solidarity Synergy & Labor Pool with active worker counts and global speed multiplier: +35% Lv.1, +75% Lv.2, +120% Lv.3), Card 2 (Communal Directive Boards & Automated Workflow explaining Auto-Cycle, Harvest-Only, Water-Only, and Manual orders), and Card 3 (Live Parcel Directives Status showing all unlocked parcels' active directives with gold action button `[ 📋 Configure Parcel Directives ]`); 4) Upgraded Bayanihan Directive Modal: Added parcel switcher tabs (`_parcel_tabs_hbox`) in `BayanihanModal.gd` allowing instantaneous parcel switching between Homestead and expanded territories directly from the modal; updated descriptions with clear agronomic details and fixed string formatting escapes; 5) Verification: Confirmed 100% pass across `run_test_bayanihan.tscn` and `run_verify_ui.tscn` (15/15 assertions) with zero regressions | src/core/FarmGrid.gd, src/buildings/BuildingCardPopup.gd, src/ui/BayanihanModal.gd, GEMINI.md |
| 91 | Removal of Redundant Bayanihan Parcel Directives & Dedicated Focus on Drone Automation: 1) Eliminated Parcel Directive Conflict: Addressed user finding that autonomous parcel auto-cycling in Bayanihan invalidated and duplicated the Drone System; removed all parcel directive background processors, timers, and autonomous worker loops from `FarmGrid.gd`; 2) Removed Wooden Field Posts & Right-Click Clutter: Deleted field post spawning/updates across `_init_grid` and `unlock_parcel` in `FarmGrid.gd`, and removed `ActionId.PARCEL_DIRECTIVES` ("🤝 Bayanihan Directives...") from `TileActionPopup.gd`; 3) Refocused Bayanihan Center on Cultural Solidarity Speed Multipliers: Redesigned `bayanihan_center` ("Bayanihan Cooperative Post", ₱500) strictly around human labor coordination, giving active human workers a massive speed bonus (+35% Lv.1, +75% Lv.2, +120% Lv.3) across all manual player assignments and drag selections; 4) Promoted Drone Station as Exclusive Autonomous Tech: Redesigned `BuildingCardPopup._populate_drone_features()` with 3 comprehensive cards: Flight Automation Capability (Lv.1 Plow, Lv.2 Seeder, Lv.3 Full Agricultural Loop with flood/obstacle flight immunity), Fleet Operations & Solar Power (pilot operator ratio & charging pads), and Hotbar Remote Deployment Guide with an interactive action button `[ 🛸 Equip Drone Remote in Hotbar ]` for instant Hotbar Slot 4 remote selection; 5) Verification: Tested and verified 100% pass across `run_test_bayanihan.tscn`, `run_verify_ui.tscn` (all 15 assertions), `run_test_storage.tscn`, and `run_render_building_cards.tscn` in Godot 4.7.2 | src/core/FarmGrid.gd, src/ui/TileActionPopup.gd, src/buildings/BuildingCardPopup.gd, autoload/Data.gd, GEMINI.md |
| 92 | Start Menu & Region Select Screen Overhaul — Balanced Start Menu & Unified Widescreen Dossier: 1) Balanced & Functional Start Menu Layout: Restructured `scenes/MainMenu.tscn` and `scenes/StartMenu.tscn` to keep primary modes on the left (350px width `LeftMenuVBox`: `🏆 TIMED CAMPAIGN`, `🌾 CAREER TYCOON`, `💾 SAVED GAMES` with dynamic gold active states and 18pt typography), moved secondary utilities to an elegant 1160px horizontal bottom toolbar (`BottomUtilityDock` at Y=590–646: Settings, Multiplayer, Hall of Fame, Chronicle, Guide, Debug, and High Score PB Card), and installed a permanent 790×474px Hero Card on the right (`ModeHoverCard`); 2) Dynamic Mode Hero Card: Features mode title, tagline, rich 3-sentence description, 4 feature pillars encased in a carved wooden panel (`HeroPillarsCard`) with 16pt titles and 14pt bullets with 4px line spacing, an expanding vertical spacer anchoring the bottom row to the card baseline, actionable green hint text, and a prominent 320×48px golden CTA button (`HeroActionBtn`) that dynamically updates text and navigates directly; hover transitions dynamically preview hovered modes and restore selected modes; 3) Unified Widescreen Dossier Region Select Screen: Repositioned `TopRightMapCard` from isolated top-right (1104, 16) into the left side of the expedition dossier (offset_left=60, offset_right=320, 260×340 px), adding province subtitle ("SOCCSKSARGEN (REGION 12)"); aligned `CarouselBar` (720px width at Y=70–126) and `MiddleCard` (880×340 px at Y=140–480) on the exact same baseline as the map card to form a cohesive 2-panel expedition folder; enlarged `StartButton` to 440×48px (17pt font); 4) Smooth Synchronous Slide Transitions: Updated `_show_region_select` and `_show_mode_select` in `scenes/MainMenu.gd` so both the map card and middle card slide synchronously with the carousel bar from offset +90px to baseline; 5) Full Verification: Verified 100% pass across `scratch/run_test_main_menu.tscn`, `scenes/MainMenu.tscn --test-menu`, and all 15 UI regression assertions in `scratch/run_verify_ui.tscn` in Godot 4.7.2 | scenes/MainMenu.tscn, scenes/MainMenu.gd, scenes/StartMenu.tscn, scratch/capture_menu_views.gd, GEMINI.md |
| 93 | Menu Layout Reversion, Sleek High-Contrast Styling & WoodenButton/GoldButton Integration: 1) Reverted Overcrowded Edge-to-Edge Layouts: Addressed user finding that edge-to-edge compact layouts felt crowded; restored the open, scenic previous iteration layouts across both screens leaving mountains visible on both sides; 2) Start Menu Centered Billboard: Restored `BillboardPanel` (1040×540 px) centered on screen with `Big-Rectangle-logs.png` frame; enlarged typography with high-contrast espresso/mahogany text (17pt titles, 14pt taglines, 16pt description); added 3-pillar card in `Samplebox1.tres` with 17pt titles and 15pt bullets; 3) Authentic Button Integration: Integrated user's new `WoodenButton.tres` / `WoodenButtonHover.tres` / `WoodenButtonPressed.tres` (`Wooden-button.png`) across both screens: Start Menu features prominent 420×48px `Goldbutton.tres` CTA button (`PROCEED TO REGION SELECT (START CAMPAIGN) >`), 210×48px `WoodenButton.tres` (`💾 LOAD SAVED GAME`), 190×48px `WoodenButton.tres` (`🏆 HALL OF FAME`), and dynamic gold/wooden season duration buttons (`30d Sprint`, `60d Standard`, `90d Quarter`); Region Select features 200×40px `WoodenButton.tres` in top-left (`< GAME MODES`) and 440×48px `Goldbutton.tres` in bottom-right (`START 60-DAY CAMPAIGN IN COTABATO BASIN >`); 4) Region Select Centered Layout & Contrast Polish: Centered `MiddleCard` (880×345 px, height <= 360 px) in `Samplebox1.tres` with clean unicode bullets (`•`) for advantages and climate risks; restored `TopRightMapCard` (156×232 px) floating in top-right corner; enlarged `RegionHeaderBox` to 620×60 px on `LongRectangle.tres` with high-contrast 21pt mahogany title and 14pt brown tagline; 5) Full Verification: Verified 100% pass across `scratch/run_test_main_menu.tscn`, `scenes/MainMenu.tscn --test-menu`, and all 15 UI overhaul regression checks in `scratch/run_verify_ui.tscn`; captured GPU screenshots on RTX 5050 Laptop GPU | scenes/MainMenu.tscn, scenes/MainMenu.gd, scenes/StartMenu.tscn, GEMINI.md |
| 94 | Side-Button Start Screen Restoration, Understandable Big Typography & Visual Pros/Cons Icon Rows: 1) Side-Button Start Menu Restoration: Moved ALL interactive buttons to the left sidebar (`LeftMenuPanel` 296×580 px at x=32..328) housing `SideCampaignBtn` (256×46 px in gold), `ModeSeasonContainer` (compact season duration buttons `30d`, `60d`, `90d` with dynamic gold highlights), `SideCareerBtn` (256×46 px in wood), `ModeStartBtn` (256×48 px in gold: `PROCEED TO REGIONS >`), `ModeLoadBtn` (256×44 px in wood), `ModeLeaderboardBtn` (256×42 px in wood), and debug checkbox; 2) Decluttered Briefing Scroll Card (`ModeCard`): Transformed `ModeCard` (770×572 px at x=370..1140) into an uncluttered briefing scroll leaving 140px open mountain vista on the right; displays large 22pt title, 14pt taglines, 16pt descriptions, a 3-pillar feature breakdown card (17pt titles, 15pt bullets), and season duration/career perks summaries without button clutter; 3) Visual Pros & Cons Icon Rows: Enhanced the Region Select Dossier (`MiddleCard`) by replacing plain text bullets with authentic 28×28 pixel-art icons from `assets/icons/` next to each advantage and climate hazard across all 5 regions (Water drop `water-drop.png`, Palay `Rice.png`, Corn `Corn.png`, Coffee `coffee.png`, Banana `Banana.png`, Coconut `Coconut.png`, Wave `Wave.png`, Hazard Warning `Warning.png`, Sun `Sunny.png`, Cold `Cold .png`, Fire `Fire.png`, Port Market `Market.png`, Construction `Build.png`, Rain `Rain.png`), while keeping `%ProsText` and `%ConsText` for 100% test assertion compatibility; 4) Big, Understandable Typography Across Both Screens: Replaced dense text walls with punchy, everyday explanations across mode descriptions, season lengths, and regional dossier briefings with 15–22pt high-contrast typography; removed muddy black text shadows on parchment; 5) Automated Verification: Confirmed 100% pass across `scratch/run_test_main_menu.tscn`, `scenes/MainMenu.tscn --test-menu`, `scratch/run_test_regions_icons.tscn` (all 5 regions' visual icons verified), and `scratch/run_verify_ui.tscn` (all 15 UI assertions passed) | scenes/MainMenu.tscn, scenes/MainMenu.gd, scenes/StartMenu.tscn, scratch/test_regions_icons.gd, scratch/run_test_regions_icons.tscn, GEMINI.md |
| 95 | Start Menu Simplification — Middle Scroll Removal & Dynamic Hover Mode Definition Cards: 1) Middle Scroll Removal: Per user request ("simplify, remove the middle thing. have the side button when hovered the gamemode it just shows the deifiniiton same as abefore"), completely eliminated the persistent middle scroll card (`ModeCard`) from view on the Start Menu, leaving the panoramic Philippine mountain landscape (>950px of scenic art) 100% open, unobstructed, and minimalist; 2) Dynamic Hover Definition Cards (`ModeHoverCard`): Re-implemented the lightweight 520×240px parchment hover card (`Samplebox1.tres`) with `mouse_filter = 2` (IGNORE) positioned dynamically beside hovered buttons (`x = 355 px`); 3) Smooth Tactile Tween Gliding: When hovering `SideCampaignBtn`, `SideCareerBtn`, `ModeLoadBtn`, or `ModeLeaderboardBtn`, `ModeHoverCard` smoothly slides vertically and fades in (0.12s) to align beside the hovered button, displaying the mode title (20pt bold mahogany), tagline (14pt), crisp 3-sentence bulleted definition (16pt high contrast, `Color(0.20, 0.12, 0.06)`), and actionable green tip; immediately fades out and vanishes upon mouse exit; 4) Preserved Backward Compatibility: Retained `%ModeDescLabel`, `%ModeTaglineLabel`, `%Pillar1Title`, `%Pillar1Body`, `%ModeStartBtn`, and `%ModeLoadBtn` node paths for 100% automated test compliance; 5) Automated & Visual Verification: Confirmed 100% pass on `scratch/run_test_main_menu.tscn`, `scenes/MainMenu.tscn --test-menu`, and `scratch/run_verify_ui.tscn` (all 15 assertions passed); captured GPU screenshots confirming completely open mountain vista on idle and smooth hover definition cards | scenes/MainMenu.tscn, scenes/MainMenu.gd, scenes/StartMenu.tscn, scratch/capture_menu_views.gd, GEMINI.md |
| 97 | Option A 32×32 Retro Pixel Farmer Sprites & Full In-Game Animation System Integration: 1) Eliminated all white/beige halo artifacts across all 16 frames of Option A 32×32 faceless peach pawn sprite sheet using color keying and alpha thresholding; 2) Extracted individual frames into `assets/sprites/farmer/` (`idle.png`, `walk_0..3.png`, `till_0..3.png`, `harvest_0..3.png`); 3) Updated `Farmer.gd` to load and animate 32×32 textures with nearest-neighbor scaling (2.0x), directional flipping, and nighttime lantern; 4) Updated starter farmer in `MainGame.tscn` and runtime worker spawning in `HUD.gd`; 5) Verified 100% test pass in Godot 4.7.2 headless | assets/sprites/farmer/*, src/farmer/Farmer.gd, scenes/MainGame.tscn, src/ui/HUD.gd, GEMINI.md |
| 98 | UI Ergonomics, Container Overflow Elimination & Readable Typography Overhaul: 1) Diagnosed and resolved UI legibility and overflow issues across three distinct components highlighted by user screenshots: Shop Info Card (`ItemInfoCard`), Top-Right HUD Bar (`RightCluster`), and Crop Tooltip Card (`CropHoverCard`); 2) Top-Right HUD Overhaul: Fixed `BrownBox.tres` content margins from 8px to 14px horizontal and 6px vertical so content is inset from 14px/8px wooden bevels; expanded `RightCluster` width from 440px to 580px (`offset_left = -580.0`); enlarged all capsule labels to 14-15px (`WorkerLabel` 14pt, `StorageLabel` 14pt, `CashLabel` 15pt bold gold, `PointsLabel` 14pt); widened `StorageBar` to 56×10px with 8px spacing; 3) Shop Item Info Card: Set `ItemInfoCard` `custom_minimum_size = Vector2(0, 78)`; adjusted `InnerBox2x.tres` content margins to 22px horizontal and 14px vertical; set `InfoTitle` to 16pt gold and `InfoDesc` to 14pt with 3px line spacing; shortened verbose descriptions for drone and farm worker into punchy, easy-to-scan 2-sentence summaries; 4) Crop Hover Card Overflow Elimination: Root cause was Godot's `AUTOWRAP_WORD_SMART` calculating minimum label height at 1px width, generating an astronomical 3645px min height that clamped the panel to 140px while text overflowed through the bottom border; fixed by setting `custom_minimum_size = Vector2(296, 0)` on wrapping labels and `custom_minimum_size = Vector2(340, 0)` on `CropHoverCard` (reducing min height to a clean 171px with zero overflow); set bottom content margin to 16px; bumped fonts from tiny 9pt to 11–14pt (`card_title` 14pt, `card_price` 13pt, `card_type` 11pt, body labels 12pt); shortened crop descriptions in `Data.gd` and streamlined regional affinity lines in `PlantHotbar.gd`; 5) Automated & Visual Verification: Ran GPU-rendered screenshots (`capture_top_right_hud.png`, `capture_crop_hover.png`, `capture_shop_info_card.png`) confirming pristine visual appeal, zero container overflows, and 100% pass across all 15 UI overhaul unit tests | assets/sprites/hud/TopRight/BrownBox.tres, assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres, scenes/MainGame.tscn, src/market/ShopPanel.gd, src/ui/PlantHotbar.gd, autoload/Data.gd, GEMINI.md |
| 99 | Bodega Trade Desk 2-Column Split, PAGASA Weather App Telemetry Polish & DisasterBox Layout Overhaul: 1) Solved user feedback regarding unorganized screens and lack of visual focus across three components: Bodega Sales Desk (`SellPanel.gd`), PAGASA Agri-Weather App (`WeatherAppModal.gd`), and HUD Disaster Box (`DisasterBox`); 2) Bodega Sales Desk 2-Column Overhaul: Eliminated 150px of empty dead space at the bottom by creating a balanced 2-column trade desk (Left Column: 4 full-width buyer buttons with distance, fuel fee, and rate multiplier tags in high-contrast deep espresso text on wood; Right Column: dedicated Bill of Lading / Dispatch Invoice panel with line-by-line itemization of gross revenue, fuel expense, spoilage transit risk, glowing green Net Profit in 20pt bold, and prominent full-width `Confirm & Dispatch Shipment` button right inside the invoice); 3) Disaster Box Parchment Centering & Overflow Fix: Recalibrated `TitleLabel` (Y=18..36) and `SubLabel` (Y=37..54) in `MainGame.tscn` to sit completely within parchment pixel bounds (`y in [19, 58]`); disabled clipping and shortened climate strings in `HUD.gd` (`☀️ EL NIÑO: Severe heatwave • Irrigate crops`), eliminating the letter "D" clipping on the ragged left border; 4) PAGASA Weather App Ergonomics: Replaced heavy `InnerBox2x.tres` 22px wooden frames on the 4 vital chips with sleek rounded telemetry pills (`_make_chip_style()`); transformed 7 heavy locked cards into soft, subtle radar slots with neat golden tier badges (`AWS Lv.2` / `Satellite Lv.3`); condensed run-on Agronomy Guide bar from 168 characters into a scannable bulleted line with crop icons (`💡 AGRONOMY TIPS: 🌾 Palay: 70–90% moist • 🌽 Corn: 30–60%...`); shortened subtitle and Almanac mode footer labels; 5) Automated Verification: Confirmed 100% pass on `scratch/run_verify_ui.tscn` (15/15 assertions) and `scratch/run_verify_weather_app.tscn`, and captured GPU-rendered proofs across all three updated components | scenes/MainGame.tscn, src/ui/HUD.gd, src/market/SellPanel.gd, src/ui/WeatherAppModal.gd, GEMINI.md |
| 100 | Complete Right-Click Feature Removal & Direct Hotbar Input Consolidation: 1) Removed Legacy Right-Click Context Menu: Per user request ("remove the right click feature"), completely disabled and decoupled the right-click action popup menu (`TileActionPopup`); 2) Input Handling Update in `FarmGrid.gd`: In `_unhandled_input`, right-clicking now cleanly deselects workers (`TaskManager.deselect_all_farmers()`), clears tile selection, hides popups, and marks the input as handled without starting marquee drag; 3) `_finish_drag` Decoupling: Removed all `MOUSE_BUTTON_RIGHT` branches and popup menu invocations from marquee drag and single tile clicks; 4) Safety Guarding in `TileActionPopup.gd`: Added early `hide(); return` in `open_for_tile()` and `open_for_batch()` so popups never open under any circumstances while keeping the node/script intact for automated test assertion compatibility; 5) HUD & Inspector Polish: Updated batch inspection tooltip in `TileInfoPanel.gd` from `"Right-Click for Batch Actions"` to `"Select Tool & Left-Click/Drag"`; 6) Automated Verification: Created and ran `scratch/run_test_right_click.tscn` verifying right clicks cleanly deselect without opening menus and left-click hotbar farming functions 100% intact; verified all 15 UI overhaul tests passed in `run_verify_ui.tscn` | src/core/FarmGrid.gd, src/ui/TileActionPopup.gd, src/ui/TileInfoPanel.gd, scratch/test_right_click_removal.gd, scratch/run_test_right_click.tscn, GEMINI.md |
| 101 | Minimalist Farmer Overhead Nameplates & Head Overlap Elimination: 1) Streamlined Overhead Text: Per user request ("Change the overhead text for the farmer. Make it less lengthy. simpleetc"), removed redundant and lengthy prefixes (`"Worker 1: "`, `" 🤝"`, `"⭐ "`, `"..."`) across all farmer overhead tags in `Farmer.gd` and `FarmerStateMachine.gd`; 2) Concise Status Vocabulary: Simplified states to punchy single words: `Ready`, `Moving`, `Plowing`, `Planting`, `Watering`, `Spraying`, `Harvesting`, `Chopping`, `Storing` (with clean ` (+N)` suffix for queued tasks); 3) Resolved Head & Hat Overlap: Fixed label position in `Farmer.gd`, `MainGame.tscn`, and `HUD.gd` from `offset_top = -36.0` (which sliced through the 32×32 retro farmer's straw hat and face) to `offset_top = -64.0, offset_bottom = -46.0`, floating cleanly 12px above the hat; 4) Polished Typography & Outline: Added 13pt font with `outline_size = 3` and espresso outline `Color(0.10, 0.08, 0.05, 0.95)` ensuring razor-sharp legibility over all grass, mud, water, and crop tiles; 5) Verification: Captured close-up GPU screenshots (`farmer_overhead_ready.png`), confirmed 100% test pass on `run_test_crop_farmer_overlap.tscn`, `run_verify_ui.tscn`, and `run_test_right_click.tscn` in Godot 4.7.2 | src/farmer/Farmer.gd, src/farmer/FarmerStateMachine.gd, scenes/MainGame.tscn, src/ui/HUD.gd, GEMINI.md |
| 102 | Crop Sprite Shader Highlighting & Ground Tile Diamond Suppression: 1) Diagnosed and resolved user request ("I want the sprtie to be higlighted not the tile") where hovering, selecting, or tasking crops drew flat neon-green or golden isometric diamond wireframes across the dirt; 2) Implemented pixel-perfect CanvasItem edge-contour ShaderMaterial on crop sprites (both 1×1 `CropSprite` and 2×2 `CropSprite2x2`) with inner alpha contour detection, glowing outline color, and interior brightness boost; 3) Integrated intelligent soil filter (`filter_soil = true` on 1×1 crops) in `CROP_OUTLINE_SHADER_CODE` preserving natural brown dirt mounds at the base of rice, corn, cane, pineapple, and coffee while highlighting only the standing plant stalks/leaves, with 2×2 coconut and banana palms highlighting canopy and trunk; 4) Suppressed ground tile diamond outlines across `DragSelectOverlay.gd` (`_draw_tool_hover`, `_draw_task_highlights`, `selected_tiles`, and cursor hover) and `FarmGrid.gd` (`hover_indicator` and `selection_indicator`) whenever the targeted tile or footprint contains crops; 5) Preserved ground diamond indicator on uncultivated grass, plowed mud, and obstacles where no crop sprite exists so tilling and planting remain intuitive; 6) Decoupled `hovered_grid_pos` in `FarmGrid._update_hover_cursor()` to prevent input race conditions; 7) Automated Verification: Created `scratch/run_test_sprite_highlight_verification.tscn` passing 100% across tool hover, empty tile hover, 2×2 multi-tile crop hover, selection, and deselect; verified 100% pass with 0 regressions on `run_test_right_click.tscn`, `run_test_crop_farmer_overlap.tscn`, and `run_verify_ui.tscn` (all 15 assertions) | src/world/DragSelectOverlay.gd, src/core/FarmGrid.gd, GEMINI.md |
| 103 | Debug Removal from Screens & In-Game Pause Menu Integration: 1) Per user request ("Remove the debug for the bothscreen put it into the menu"), removed the unsightly developer debug checkbox (`ModeAdminBox` / `AdminCheckbox`: "Enable Debug Panel (` key)") from the start screen left menu in `scenes/MainMenu.tscn` and `scenes/StartMenu.tscn`, keeping both pre-game screens completely clean, uncluttered, and professional; 2) Removed on-screen yellow admin mode banner (`_show_admin_hint`) in `scenes/MainGame.gd`, eliminating all debug overlays from the gameplay screen; 3) Integrated dedicated `🛠️ Debug Console (`)` button in the in-game Pause Menu (`src/ui/PauseMenu.gd`) using authentic brown button styling with warm ivory typography, positioned right between Farm Chronicle and Main Menu; 4) Clicking `🛠️ Debug Console (`)` in PauseMenu smoothly closes the menu and opens `AdminPanel`; 5) Added dedicated `✕` close button, ESC key listener, and `open()`, `close()`, and `toggle()` API to `AdminPanel.gd` with `process_mode = PROCESS_MODE_ALWAYS`; 6) Maintained instant backtick (`) shortcut in-game; 7) Automated Verification: Created `scratch/run_test_debug_menu_integration.tscn` passing 100% across all 8 checks, and confirmed 0 regressions on `MainMenu.tscn --test-menu`, `run_test_main_menu.tscn`, `run_test_right_click.tscn`, `run_test_sprite_highlight_verification.tscn`, and `run_verify_ui.tscn` (15/15 checks) | scenes/MainMenu.tscn, scenes/StartMenu.tscn, scenes/MainMenu.gd, scenes/MainGame.gd, src/ui/PauseMenu.gd, src/ui/AdminPanel.gd, scratch/test_debug_menu_integration.gd, scratch/run_test_debug_menu_integration.tscn, GEMINI.md |
| 104 | 8 Farmer Visual Color Variants & Individual Palette Customization: 1) Created 8 distinct visual color palettes and variants for the 32×32 retro pixel farmer character: Variant 0 (Classic Denim Blue / bright straw hat / peach peon skin), Variant 1 (Ruby Red flannel dungarees / cream straw hat / warm golden skin), Variant 2 (Forest Green dungarees / golden straw hat / peach skin), Variant 3 (Indigo Violet dungarees / toasted straw hat / rich bronze tan skin), Variant 4 (Harvest Amber & Ochre overalls / bleached straw hat / sun-warmed skin), Variant 5 (Tropical Teal / golden straw hat / island tan skin), Variant 6 (Coral Rose overalls / light straw hat / fair skin), and Variant 7 (Rugged Khaki Earth dungarees / rustic straw hat / deep sun tan skin); 2) Asset Generation: Generated 168 variant frames across all 8 palettes in `assets/sprites/farmer/variants/variant_0..7/` covering `idle`, `walk_0..3`, `till_0..3`, `harvest_0..3`, and directional idles with nearest-neighbor pixel fidelity, preserving authentic wooden tools, steel blades, and golden rice sheaves; 3) Core Architecture in `Farmer.gd`: Added `NUM_VARIANTS = 8`, `VARIANT_NAMES`, `VARIANT_DIRS`, `variant_id` export setter, and `get_frames_for_variant()` with memory caching; auto-assigns variants based on worker ID (`(worker_id - 1) % 8`); added `set_variant()`, `cycle_variant()`, and `KEY_C` hotkey ("Press C while a worker is selected to cycle outfit colors"); 4) Dynamic Worker Hiring in `HUD.gd`: Updated `_on_worker_spawn_requested()` so newly hired workers automatically receive their distinct colorway and initial idle frame; 5) Automated Verification: Created `scratch/run_test_farmer_variants.tscn` passing 100% across frame integrity, auto-assignment, cycling, and hotkeys; captured in-engine GPU showcase screenshots (`farmer_variants_ingame_showcase.png`); verified 100% pass across regression suites (`run_verify_ui.tscn` 15/15 assertions, `run_test_right_click.tscn`, and `run_test_crop_farmer_overlap.tscn`) in Godot 4.7.2 | assets/sprites/farmer/variants/*, src/farmer/Farmer.gd, src/ui/HUD.gd, scratch/test_farmer_variants.gd, scratch/run_test_farmer_variants.tscn, scratch/render_farmer_variants_showcase.gd, GEMINI.md |
| 105 | New Pixel-Art Icons Integration (Axe, Chem, Duck, Truck): 1) Located, converted, and downscaled 4 user-selected vector/flat icons from Downloads into crisp 32×32 pixel assets with nearest-neighbor texture filtering: `assets/icons/Tools/Axe.png` (🪓 Obstacle Clearing / Felling timber & rocks), `assets/icons/Tools/Chem.png` (🧪 Chemical Insecticide Spray / Rapid pest knockdown), `assets/icons/Tools/duck.png` (🦆 Biological IPM Management / Organic duck & Trichoderma biocontrol), and `assets/icons/HUD/Truck.png` (🚚 Bodega Shipping & Dispatch); 2) PlantHotbar Integration: Expanded `TOOL_ICONS` mapping to include `clear`, `spray_chemical`, and `spray_biological`; updated `_setup_flyout_drawer()` and `_update_category_slots_display()` in `PlantHotbar.gd` to render authentic pixel-art `TextureRect` icons for both `tools` and `treatments` categories; updated `_populate_tool_or_treatment_hover()` to display the high-res sprite texture in the hover card header (`card_texture`) when hovering tools/treatments; 3) HUD Command Corner & Bodega Dispatch: Replaced `SellButton` basket icon in `MainGame.tscn` with `Texture_hud_truck` (`uid="uid://dsx67117krgbx"`), establishing clear visual intuition (Basket = harvesting crops in field; Truck = dispatching commercial shipments to regional hubs); updated `SellPanel.gd` dispatch invoice action button (`_sell_action_btn`) with `Truck.png` and nearest-neighbor filtering; 4) Automated Verification & GPU Capture: Created `scratch/test_new_icons_integration.gd` and `scratch/run_test_new_icons.tscn` passing 100% across texture loading, dimension asserts, hotbar slot displays, flyout drawer rendering, hover cards, and CommandCorner buttons; captured in-game screenshot `new_icons_in_game.png` showcasing all 4 new icons active in HUD, Hotbar, and Flyout drawer simultaneously; verified 100% pass across all regression test suites (`run_verify_ui.tscn` 15/15 assertions, `run_test_right_click.tscn`, and `run_test_crop_farmer_overlap.tscn`) in Godot 4.7.2 | assets/icons/Tools/Axe.png, assets/icons/Tools/Chem.png, assets/icons/Tools/duck.png, assets/icons/HUD/Truck.png, src/ui/PlantHotbar.gd, scenes/MainGame.tscn, src/market/SellPanel.gd, scratch/test_new_icons_integration.gd, scratch/run_test_new_icons.tscn, scratch/capture_icons_in_game.gd, scratch/run_capture_icons.tscn, GEMINI.md |
| 106 | Autonomous Drone Decoupling, Dedicated Command Deck & Expanded Automation Suite: 1) Complete Farmer Independence: Decoupled autonomous drones 100% from human workers; removed hotbar-gated activation and farmer auto-selection in `FarmGrid._finish_drag()`; drones can now be deployed, commanded, zoned, and recalled with zero human farmers selected; 2) Dedicated Drone Command Deck (`DroneCommandDeck.gd`): Added standalone workstation panel (Hotkey `U`, HUD CommandCorner button, world click on flying drone or hangar) featuring live fleet telemetry, 3 action buttons (`🎯 Designate Zone`, `🌐 Auto-Patrol Entire Farm (1-Click)`, `🏠 Return & Dock`), independent 7-crop selector with costs, 6 interactive directive toggles, live zone health diagnostics, and "No Hangar Built" prompt with direct Agri-Shop shortcut; 3) Expanded Automation Directives: Encompassed the full agricultural lifecycle with 6 toggleable directives: `auto_plow` (tills untilled/receded dirt), `auto_plant` (sows designated seed), `auto_water` (hydrates thirsty crops <50% moisture), `auto_spray` (emergency biocontrol/chemical pest curing), `auto_harvest` (reaps mature produce to Bodega), and `auto_clear` (excavates timber/rocks); 4) Intelligent Priority Engine: Rebuilt `FarmDrone._scan_for_job()` with strict hierarchical priority tiers (Tier 0: Emergency pest blight curing, Tier 1: Ripe harvest, Tier 2: Soil hydration, Tier 3: Seeding, Tier 4: Ground plowing, Tier 5: Debris clearing); 5) Visual Polish & Custom Drone Icon: Created custom 32×32 pixel art quadcopter icon `assets/icons/HUD/Drone.png` (`uid="uid://uxv4nps41qvj"`) in CommandCorner; added cyan holographic whole-farm patrol boundary; added blue hydration stream and green biocontrol mist work visuals; 6) Verification: Created `scratch/test_drone_independence.gd` & `scratch/run_test_drone_independence.tscn` passing 13/13 unit tests 100%; verified 0 regressions across `run_verify_ui.tscn` (15/15 checks) and `run_test_new_icons.tscn`; captured in-engine screenshots `drone_deck_capture.png` and `drone_working_capture.png` | src/drone/FarmDrone.gd, src/ui/DroneCommandDeck.gd, src/core/FarmGrid.gd, src/world/DragSelectOverlay.gd, src/ui/HUD.gd, scenes/MainGame.tscn, src/buildings/BuildingCardPopup.gd, src/ui/PlantHotbar.gd, assets/icons/HUD/Drone.png, GEMINI.md |
| 107 | Soil & Farm Diagnostic Heatmap, Sprinkler Blueprint Network & QoL Telemetry HUD Bar: 1) Interactive Diagnostic Heatmap (`FarmHeatmapOverlay.gd`): Implemented a full-grid, real-time toggleable diagnostic overlay (z_index=195) with smooth alpha tweening, sine-wave pulsing, and 4 specialized modes: `UNIFIED` (Tactical overview of moisture, ripe harvests, pest alerts, and irrigation), `MOISTURE` (Soil hydration gradient: parched <30% crimson/orange, low 35-50% amber, optimal 50-80% cyan, saturated >80% deep blue, flooded navy), `HEALTH` (Crop vigor, mature harvest readiness golden pulse, and blight alerts), and `IRRIGATION` (Sprinkler network coverage & dry gap identification); 2) Sprinkler Blueprint Network: Visualizes active sprinkler spray fields with glowing cyan diamond blueprint polygons, circular water nozzles, and identifying dry coverage gaps across the entire 24×24 farm; 3) Interactive Diagnostic Control Bar (`HeatmapLegendBar.gd`): Added authentic wooden HUD panel positioned at top-center under speed buttons (`offset_top = 106.0`) with 1-click mode switching buttons with active gold state, quick close button, visual color-coded guide chips, and live hover telemetry readout showing exact tile coordinates, crop type, moisture %, health %, sprinkler coverage status, and agronomic condition; 4) HUD Integration & Hotkey [F]: Added custom 32×32 pixel art radar/topographic scanner icon `assets/icons/HUD/Heatmap.png` (UID `uid://cncwutop8xbi4`) as 5th button in bottom-right `CommandCorner` (`offset_top = -252.0`); mapped hotkey `KEY_F` and ESC key to toggle and close cleanly; 5) Verification & In-Game Capture: Created `scratch/test_heatmap_overlay.gd` & `scratch/run_test_heatmap.tscn` passing all 9 diagnostic checks 100%; verified 0 regressions across `run_verify_ui.tscn` (15/15 checks) and `run_test_drone_independence.tscn`; captured GPU-rendered in-game screenshot `diagnostic_heatmap_showcase.png` | src/world/FarmHeatmapOverlay.gd, src/ui/HeatmapLegendBar.gd, src/core/FarmGrid.gd, src/ui/HUD.gd, scenes/MainGame.tscn, assets/icons/HUD/Heatmap.png, scratch/test_heatmap_overlay.gd, scratch/run_test_heatmap.tscn, scratch/capture_heatmap.gd, GEMINI.md |
| 108 | Trade Hub Infrastructure, Coastal Seaport, Eastern Sea & Field Survey Kit Tech Gate: 1) Commercial Trade Hub Buildings: Added 4 distinct trade buildings in `Data.BUILDINGS` with authentic pixel-art artwork (`byahero.png`, `Tacurong-Grain-mill.png`, `Koronadal-Wholesale.png`, `Gensan-seaport.png`); `bayanihan_center` ("Biyahero Trading Post", 2×2, ₱350, unique) provides a clean one-time +8% markup buff on local middleman sales (72% → 80%) with neutral 1.0× worker speed; `tacurong_mill` ("Tacurong Grain Mill Depot", 3×3, ₱1,500, unique) unlocks Tacurong sell hub with +6% payout (1.05× → 1.11×), -30% transit rot, -20% fuel; `koronadal_wholesale` ("Koronadal Wholesale Depot", 4×4, ₱2,800, unique) unlocks Koronadal city market with +8% payout (1.20× → 1.28×), -30% rot, -25% fuel; `gensan_seaport` ("General Santos Seaport Terminal", 4×4, ₱4,500, unique, `requires_shore: true`) unlocks GenSan export hub with +12% payout (1.55× → 1.67×), -50% rot, -30% fuel; 2) Exact Footprint Tile Ratios: Sized all building sprites to exact 1:1 isometric diamond ratios (2×2: 256px diamond, 3×3: 384px diamond, 4×4: 512px diamond) with Linear filtering for pixel-perfect edge rendering; added prominent "📐 N×M" tile ratio badges in Agri-Shop cards and in the placement ghost preview; 3) Eastern Tropical Ocean & Coastal Shoreline Constraint: Implemented `SeaWater.gd` (z_index=-40) rendering animated tropical ocean water, shoreline foam, wave ripples, and navigation buoys along the eastern edge of the 24×24 map; restricted General Santos Seaport placement to touch the eastern coastline (`start_pos.x + 4 == 24`) on unlocked territory (`east_meadows`), positioning its container freighter directly in coastal water; 4) Purchasable Diagnostic Heatmap Tech Gate: Gated the Soil Diagnostic Heatmap behind the "Field Survey Kit" tech in Agri-Shop Weather tab (`Data.TECH["field_survey_kit"]`, ₱400); hotkey [F] and HUD radar button are locked and dimmed until purchased; 5) Agri-Shop & Bodega Sales Desk Polish: Added dedicated "Trade" tab in `ShopPanel.gd` with 4 trade cards and footprint ratio tags; updated `SellPanel.gd` to display locked status and required buildings for provincial hubs; 6) Automated Verification & GPU Visual Showcase: Created `scratch/test_trade_hubs.gd` and `scratch/run_test_trade_hubs.tscn` passing 9/9 tests 100%; verified 0 regressions across `run_test_bayanihan.tscn`, `run_test_heatmap.tscn`, `run_verify_ui.tscn` (15/15 checks), and `run_test_drone_independence.tscn`; captured in-engine GPU showcase screenshot `trade_hubs_coastal_showcase.png` | autoload/Data.gd, autoload/BuildingManager.gd, autoload/MarketManager.gd, src/buildings/Building.gd, src/world/SeaWater.gd, src/core/FarmGrid.gd, src/buildings/BuildingPlacementOverlay.gd, src/market/ShopPanel.gd, src/market/SellPanel.gd, src/buildings/BuildingCardPopup.gd, src/ui/HUD.gd, src/ui/TileInfoPanel.gd, scratch/test_trade_hubs.gd, scratch/run_test_trade_hubs.tscn, GEMINI.md |
| 109 | Complete 33-Track Sound Library & Multi-System Audio Implementation: 1) Sound Library Integration: Integrated all 17 newly provided audio files into `res://sounds/` across 4 categories (Buildings: `cancel.wav`, `demolish.wav`, `invalid.wav`; Economy: `earn.wav`, `insufficient.wav`, `market_sell.wav`, `new_day.wav`, `spend.wav`; Pests & Disasters: `cleared.wav`, `drought.wav`, `flood.wav`, `landslide.wav`, `spawn.wav`, `spread.ogg`; Time & Tech: `hire_worker.wav`, `tech_unlock.wav`, `time_pause.wav`), expanding total active game sound effects to 33; 2) Extended Semantic Audio API: Added `AudioManager.play_economy()`, `AudioManager.play_disaster()`, and `AudioManager.play_tech()`, and expanded `AudioManager.play_building()` and `AudioManager.play_ui()` with rate limiting / `MIN_INTERVAL` safeguards; 3) Event & Gameplay Signal Bindings: Wired `TimeManager.day_changed` to `new_day`, `MarketManager.sale_completed` to `market_sell`, `WeatherManager.disaster_warning`/`struck`/`cleared` to hazard cues (flood, drought, landslide), `PestManager.pest_spawned`/`cleared`/`spread` to pest audio, `BuildingManager.worker_hired` to `hire_worker`, and `BuildingManager.tech_unlocked`/`FarmGrid.unlock_parcel` to `tech_unlock`; 4) Tactile Economy & Building Feedback: Connected `EconomyManager.add_cash` to `earn.wav`, `deduct_cash` to `spend.wav` or `insufficient.wav`, `Building.demolish` to `demolish.wav`, `FarmGrid.cancel_building_placement` to `cancel.wav`, and invalid placement attempts to `invalid.wav`; 5) Automated Verification: Created `scratch/test_audio_system.gd` & `scratch/run_test_audio.tscn` verifying 100% of all 33 sound streams, semantic APIs, and signal bindings; confirmed 0 regressions on `run_test_trade_hubs.tscn`, `run_verify_ui.tscn`, `run_test_heatmap.tscn`, `run_test_drone_independence.tscn`, and `run_test_bayanihan.tscn` | autoload/AudioManager.gd, autoload/EconomyManager.gd, autoload/MarketManager.gd, autoload/PestManager.gd, src/buildings/Building.gd, src/core/FarmGrid.gd, scratch/test_audio_system.gd, scratch/run_test_audio.tscn, GEMINI.md |
| 110 | Agri-Shop High-Visibility Category Navigation & Arrow Icon Overhaul: 1) Solved Category Arrow Low Visibility: Replaced tiny, faint default 16×16 grey Godot TabBar decrement/increment chevrons with high-contrast, luminous golden pixel-art arrows with crisp espresso outlines and rich highlights; 2) Dual-Layer Arrow Asset Suite: Crafted dedicated 24×24 TabBar theme icon textures (`assets/sprites/hud/Buttons/Arrows/tab_arrow_*.png`) and overhauled 44×44 / 36×32 button textures (`assets/sprites/hud/Buttons/Arrows/arrow_*.png` and `assets/sprites/StartMenu/Arrows/arrow_*.png`) with normal, hover, and pressed states; 3) Prominent Dedicated Category Navigation Bar (`CategoryNavBar`): Inserted a prominent navigation bar directly above `TabContainer` in `ShopPanel.gd` featuring large 36×32 Left (`◄`) and Right (`►`) TextureButtons, breadcrumb pill (`Category 1 of 7: Title` in `InnerBarBg.tres`), hover sound effects, and tooltips; 4) Keyboard Shortcuts & Automatic Tab Scrolling: Added `Q`/`E` and Left/Right Arrow key listeners for instant category cycling, and integrated `tab_bar.ensure_tab_visible()` so switching categories automatically centers and focuses the active tab; 5) Verification: Confirmed 100% pass across headless test suites including `run_test_trade_hubs.tscn`, `run_test_audio.tscn`, and in-game shop navigation runner `run_test_maingame_shop_nav.tscn` | assets/sprites/hud/Buttons/Arrows/*, assets/sprites/StartMenu/Arrows/*, src/market/ShopPanel.gd, GEMINI.md |
| 111 | HUD DisasterBox Text Centering & Signboard Overlap Resolution: 1) Diagnosed Wooden Signboard Overlap: Root cause was fixed absolute offsets (`offset_top = 18.0, offset_bottom = 36.0`) on `TitleLabel` placing text inside the top wooden beam of `Disaster-box.png` (y in [16, 25]), cutting off the sun/hazard icon and title glyphs, while `SubLabel` had asymmetrical bottom padding; 2) Centered Container Hierarchy (`scenes/MainGame.tscn`): Encapsulated `TitleLabel` and `SubLabel` inside a centered `VBoxContainer` (`layout_mode = 1`, `alignment = BoxContainer.ALIGNMENT_CENTER`, `separation = 0`) spanning `offset_top = 27.0` to `offset_bottom = 54.0` with 22px horizontal inset; 3) Pixel-Perfect Parchment Alignment: Positioned the text block precisely inside the 27px safe parchment bounds (y in [26, 53]), ensuring 2px of breathing space from both top and bottom wooden borders across all phenomena (El Niño, La Niña, and emergency hazard countdowns/strikes); 4) Verification: Rendered and verified GPU captures (`disaster_box_centered_native.png`), and confirmed 100% pass on UI regression suite (`run_verify_ui.tscn` all 15 assertions passed) and audio suite (`run_test_audio.tscn`) in Godot 4.7.2 | scenes/MainGame.tscn, GEMINI.md |
| 112 | Out-of-Bounds Clash of Clans Foliage & Perimeter Dirt Trails System: 1) Out-of-Bounds Foliage Architecture (`src/world/OutOfBoundsForest.gd`): Implemented dedicated world foliage generator utilizing newly provided pixel art sprites in `assets/sprites/OutofBounds/` (`TREE-UP-1.png` 208×160 large dense canopy, `TREE-UP-2.png` 144×112 medium cluster, `TREE-UP-3.png` 96×80 small shrub) to frame the 24×24 farm island with lush, multi-layered forest boundaries inspired by Clash of Clans; 2) Frontline Snug Bush Perimeter & Deep Canopy Wall: Structured 3 distinct foliage depth zones: Zone 0 (snug frontline edge with alternating small bushes `TREE-UP-3` and medium shrubs `TREE-UP-2` spaced every 0.8–1.2 tiles), Zone 1 (mid-layer dense clusters stepped every ~1.6 tiles), and Zone 2 (deep impenetrable canopy roof using large 208×160 trees stretching outward past camera boundaries); 3) Organic Perimeter Dirt Trail (`src/world/OutOfBoundsDirtTrail.gd`): Created authentic multi-layer dirt trail (z_index=-5) running right along the tree line across the 3 landward borders (NW, NE, SW) featuring soft earthy underlay (28px), packed dirt base (16px), worn foot track (8px), natural sin/cos organic waviness, and scattered pebble stipples; 4) Coastal Headland Framing: Extended northern and southern forest belts eastward above and below Sarangani Bay (`SeaWater.gd`), wrapping the coastline in natural tropical headlands overlooking the sea; 5) Accurate Isometric Depth Sorting: Positioned forest canopy at z_index=10 with nearest-neighbor texture filtering, deterministic positioning seed (20261024), random horizontal flips, and natural foliage scale/tint jitter; 6) In-Game Verification & Testing: Resolved Godot typed GDScript parse warnings by explicitly preloading scripts and typing lambda returns; verified 100% pass across all test suites (`run_verify_ui.tscn` 15/15 assertions, `run_test_trade_hubs.tscn` 9/9 checks, `run_test_audio.tscn`); captured in-engine GPU screenshots across all four corners, coastline bay, and full 0.38x island overview | src/world/OutOfBoundsForest.gd, src/world/OutOfBoundsDirtTrail.gd, src/core/FarmGrid.gd, assets/sprites/OutofBounds/*, GEMINI.md |
| 113 | Out-of-Bounds Fog of War, Seamless Grass Underlay & Viewport Camera Clamping: 1) Seamless Out-of-Bounds Grass Underlay (`src/world/OutOfBoundsTerrain.gd`): Procedurally generated continuous `NGRASS` isometric ground tiles (scaled 4× nearest-neighbor at z_index=-8) from gx=-9..32, gy=-9..32 under the forest, perimeter trail, and ocean headlands, completely eliminating black/void ground gaps beneath trees; 2) Atmospheric Fog of War (`src/world/OutOfBoundsFogOfWar.gd`): Implemented multi-band isometric Gouraud-shaded gradient rings across 5 concentric depth steps (alpha 0.0 at tree line -> 0.35 mid-canopy -> 0.75 deep canopy -> 1.0 outer abyss) with 24 animated sinusoidal drifting mist wisps along the perimeter, dissolving the outer forest canopy into the wilderness; 3) Deep Multi-Layer Canopy: Extended tree generation depth steps from d=6.8 to d=9.8 tiles into the periphery across all borders; 4) Viewport-Aware Camera Clamping (`src/world/GameCamera.gd`): Replaced fixed-point center clamping with dynamic viewport half-size bounding box clamping (`_clamp_to_world_bounds`), and updated `min_zoom = 0.58`, mathematically guaranteeing camera viewport edges can never pan or zoom past visible sprites or into void space; 5) Locked Parcel & Bottom Tile Blending (`TileRenderer.gd`, `FarmGrid.gd`): Replaced harsh near-black locked tile modulate (`Color(0.18, 0.23, 0.16)`) with soft wilderness grass green (`Color(0.58, 0.66, 0.54)`) and added a subtle atmospheric mist veil (`Color(0.08, 0.14, 0.09, 0.18)`), eliminating the black void on unbought southern and eastern land so the starting homestead seamlessly blends with surrounding territory; 6) Verification: Captured GPU-rendered in-engine screenshots confirming pristine visual blending and zero void leaks at any zoom/pan; 100% test pass on UI suite (15/15 checks), trade hubs (9/9 checks), and audio system (33 streams) | src/world/OutOfBoundsTerrain.gd, src/world/OutOfBoundsFogOfWar.gd, src/world/OutOfBoundsForest.gd, src/world/GameCamera.gd, src/core/TileRenderer.gd, src/core/FarmGrid.gd, scenes/MainGame.tscn, GEMINI.md |

---

## 21. Known Issues / TODO

- [x] Sound system not implemented — RESOLVED: Complete AudioManager singleton integrated with 16 sound cues across farmers, buildings, and UI (Session 43)
- [x] Crop growth visuals are emoji labels — RESOLVED: Multi-stage pixel art sprites (P1–P5/P6) integrated across all 7 crops with growth and withering stages
- [ ] Worker AI pathfinding occasionally clips tile corners on isometric grid
- [x] Parcel borders (visual indicator of locked vs. unlocked land) could be more prominent — RESOLVED: Dynamic golden border lines, shadow depth, survey pegs with red ribbons, and locked perimeter borders rendered dynamically in FarmGrid.gd (Session 84)
- [x] Building sizing and pixel ratios disparate across structures — RESOLVED: Unified 1:1 isometric footprint diamond alignment across all 15 buildings with authentic nearest-neighbor pixel-art scaling (4.0× standard, calibrated industrial ratios) and crystal-clear shop card showcases (Session 114)

---

### Session 114 Summary (Complete Unified Building Sizing, 1:1 Diamond Ratio, Nearest-Neighbor Pixel Art & Shop Showcase Overhaul)
- **Root Cause Identified**:
  1. Standard 1 pixel-art buildings (`KUBO.png` 64×96, `SILO-*.PNG` 48×64, `Cold Storage.png` 96×80, `Water Station.png` 64×144, `Drone Station.png` 80×128, `Weather Station.png` 112×128) were drawn at 32px per tile base art. In `Building.gd` they were previously drawn inside `_draw()` via `draw_texture_rect` at `2.0×` scale, making them half-scale (128px wide on a 256px 2×2 tile footprint), appearing as tiny miniatures floating in oversized footprint diamonds.
  2. Heavy industrial facilities (`tacurong_mill`, `koronadal_wholesale`, `gensan_seaport`) had `art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR` with non-integer scaling, creating blurry edges that clashed with sharp pixel-art tiles and crops.
  3. Processing facilities (`rice_mill`, `sugar_mill`, `copra_dryer`, `coffee_roastery`) had authentic PNG sprites (`Kiskisan_Rice_Mill.png`, `Trapiche_Sugar_Central.png`, `Tapahan_Copra_Dryer.png`, `Artisan_Coffee_Roastery.png`) in `assets/sprites/buildings/`, but were bypassed with `null` texture in `ShopPanel.gd` and rendered via procedural code.
- **Architectural Solutions Implemented**:
  1. **Expanded `Building.get_art_fit()` to All 15 Buildings**: Every building sprite sits squarely on its exact isometric diamond (`2×2: 256×128px`, `3×3: 384×192px`, `4×4: 512×256px`, `2×3 / 3×2: 320×160px`) with calibrated `scale`, `center_offset`, `roof_apex_y`, and `scaffold_h`.
  2. **Nearest-Neighbor Texture Filtering**: Standardized `CanvasItem.TEXTURE_FILTER_NEAREST` across `Building.gd`, `BuildingPlacementOverlay.gd`, and `ShopSpritePreview` in `ShopPanel.gd`, eliminating all bilinear blur.
  3. **Real-Time Silo Dynamic Fill Integration**: `bodega` and `climate_silo` update `art_sprite.texture` dynamically via `_get_silo_texture()` in `_update_art_sprite_state()` whenever storage capacity or inventory changes.
  4. **Ghost Placement Overlay Across All Buildings**: `BuildingPlacementOverlay.gd` now renders nearest-neighbor ghost previews for all 15 buildings during placement.
  5. **Shop Showcase Overhaul**: Preloaded authentic textures in `ShopPanel.gd` for all processing buildings, presenting crisp pixel-art previews on pedestals across all shop categories.
  6. **Data Model Synchronization**: Updated `copra_dryer` grid size in `autoload/Data.gd` to `Vector2i(3, 2)` matching its 224×112px 2:1 sprite aspect ratio.
- **Verification**: Tested and confirmed 100% pass across all test suites (`run_verify_ui.tscn` 15/15 assertions, `run_test_trade_hubs.tscn`, `run_test_audio.tscn` 33 streams) and verified in-engine day/night GPU captures (`all_15_buildings_ingame_overview.png`, `shop_milling_cards.png`).

---

### Session 115 Summary (Revert Original Buildings to Classic 2.0x Scale & Calibrate Newly Added Buildings to Fit Within Tiles)
- **User Clarification Addressed**:
  - The user reported: *"Alll the buildings are no giants rever it back as it was before, i meant fix the newly added buikdings to fit within the tiles"*.
  - In Session 114, standard buildings (`bahay_kubo`, `bodega`, `cold_storage`, `water_tower`, `drone_station`, `weather_station`) were inadvertently scaled to 4.0×, turning them into giants that crowded the screen.
  - The original buildings were designed to occupy ~38–62% of their footprint diamonds (e.g. `bahay_kubo` at 2.0× is 128px wide on a 256px diamond; `cold_storage` at 2.0× is 192px wide on a 384px diamond).
  - The newly added buildings (`bayanihan_center`, `tacurong_mill`, `koronadal_wholesale`, `gensan_seaport`, and processing facilities `rice_mill`, `sugar_mill`, `copra_dryer`, `coffee_roastery`) previously had oversized scales (1.7–2.8×) that spilled over their footprint diamonds.
- **Architectural Implementation**:
  1. **Full Reversion of Original Buildings**:
     - Removed `bahay_kubo`, `bodega`, `cold_storage`, `water_tower`, `drone_station`, `weather_station`, `climate_silo`, and `solar_dryer` from `Building.get_art_fit()`.
     - In `Building._draw()`, restored direct dispatching to their original `_draw_*` methods at proven 2.0× scale (`_draw_bahay_kubo`, `_draw_bodega`, `_draw_cold_storage`, `_draw_water_tower`, `_draw_drone_station`, `_draw_weather_station`, `_draw_solar_dryer`, `_draw_silo`).
     - Maintained all contact shadows, night window/lantern glows, AC fans, and warning beacons.
  2. **Calibrated Tile Sizing for Newly Added Buildings**:
     - Configured `get_art_fit()` strictly for the 8 newly added buildings, scaling them to ~50–56% of their footprint diamond width so they sit comfortably inside their respective tiles:
       - `bayanihan_center` (2×2, 96×80): `scale: 1.35` -> 130×108px (50.6% diamond width, matching `bahay_kubo` 128px)
       - `tacurong_mill` (3×3, 240×144): `scale: 0.85` -> 204×122px (53.1% diamond width, matching `cold_storage` 192px)
       - `koronadal_wholesale` (4×4, 240×128): `scale: 1.15` -> 276×147px (53.9% diamond width on 512px diamond)
       - `gensan_seaport` (4×4, 272×160): `scale: 1.00` -> 272×160px (53.1% diamond width on 512px diamond)
       - `rice_mill` (2×2, 144×128): `scale: 0.90` -> 130×115px (50.6% diamond width)
       - `sugar_mill` (3×2, 176×128): `scale: 0.95` -> 167×122px (52.2% diamond width on 320px diamond)
       - `copra_dryer` (3×2, 224×112): `scale: 0.80` -> 179×90px (55.9% diamond width on 320px diamond)
       - `coffee_roastery` (2×2, 176×128): `scale: 0.75` -> 132×96px (51.6% diamond width)
  3. **Visual Verification**:
     - Verified all 17 buildings in-engine with GPU captures on actual farm grid (`farm_grid_all_buildings_capture.png`), confirming harmonious proportions, crisp nearest-neighbor pixel art, and clean tile borders.
  4. **Regression Tests**:
     - All 15 UI assertions in `run_verify_ui.tscn` passed 100%.
     - All 9 trade hub checks in `run_test_trade_hubs.tscn` passed 100%.
     - All 33 audio streams and semantic audio checks in `run_test_audio.tscn` passed 100%.
     - All agro-industrial processing tests in `run_test_processing.tscn` passed 100%.
     - Dedicated verification script `run_test_all_buildings_fit.tscn` passed 17/17 buildings.

