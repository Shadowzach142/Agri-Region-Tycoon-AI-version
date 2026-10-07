# Ground Sprites & Procedural Generation — Agri-Region Tycoon

This folder holds all isometric ground tile textures and resources.
The farm ground utilizes a **state-aware procedural generation system**:
1. **Light Grass as Natural Base**: All dry and normal-moisture natural terrain across the island starts uniformly with **Light Grass** variants, providing a cohesive, harmonious starting look.
2. **Dark Grass as Wet Grass**: When soil moisture exceeds 70% (rain, monsoons, watering, or flooding), grass plots dynamically transition into **Dark Grass** variants, visually representing saturated wet turf.
3. **High-Entropy Organic Variant Distribution**: Each tile coordinate `(x, y)` deterministically evaluates an organic variant (1 to 4) using a 32-bit SplitMix spatial hash combined with a randomized per-run `world_seed` (~30% clean base, ~25% tuft 1, ~25% tuft 2, ~20% clovers/accents).
4. **Deep Wilderness Shading on Locked Parcels**: Unbought territory tiles are modulated with `Color(0.18, 0.23, 0.16, 1.0)` (~20% luminance), creating a clear, dramatic contrast between the sunlit active homestead and the dark wild expanse.

---

## Directory Structure

```
assets/sprites/ground/
├── ground_tile_sprites.tres     ← Resource binding the textures to GroundTileSprites.gd
├── GROUND-Light-Grass/          ← Light meadow grass biome
│   ├── LightGrass1.png          ← Clean base
│   ├── LightGrass2.png          ← Grass blade tuft
│   ├── LightGrass3.png          ← Micro-tufts
│   └── LightGrass4.png          ← Clover / flower patch
├── GROUND-Dark-Grass/           ← Rich highland dark grass biome
│   ├── DarkGrass1.png           ← Clean base
│   ├── DarkGrass2.png           ← Tall blade accent
│   ├── DarkGrass3.png           ← Dual blade tufts
│   └── DarkGrass4.png           ← Wide cluster accent
└── GROUND-Bare/                 ← Tilled agricultural & bare earth
	├── Bare1.png                ← Clean loam soil
	├── Bare2.png                ← Pebble accent
	├── Bare3.png                ← Micro-clod detail
	└── Bare4.png                ← Stone / furrow accent
```

---

## State Mapping & Rendering

| Tile State | Assigned Sprite Pool | Procedural Behavior |
|------------|----------------------|---------------------|
| `EMPTY` | `LightGrass` (dry) / `DarkGrass` (wet) | Starts clean Light Grass; darkens to Dark Grass when moisture > 70%. |
| `LOCKED` | `LightGrass` / `DarkGrass` | Deep wilderness dark shading (`Color(0.18, 0.23, 0.16)`) at ~20% brightness. |
| `OBSTACLE` | `LightGrass` (dry) / `DarkGrass` (wet) | Natural turf under trees, stumps, and boulders. |
| `PLOWED` | `Bare` (1..4) | Deterministic soil variant selection (pebbles, furrows). |
| `PLANTED` | `Bare` (1..4) | Seedling bed earth. |
| `GROWING` | `Bare` (1..4) | Crop row soil. |
| `HARVESTABLE` | `Bare` (1..4) | Harvest-ready bed earth. |
| `BUILDING` | `Bare` (1..4) | Packed earth foundation under structures. |
| `FLOODED` | `DarkGrass` + water tint | Saturated dark grass with blue water modulate. |
| `INFECTED` | Procedural pest tint | Reddish blight modulate overlay. |

---

## Technical Specifications
- **Canvas size**: 32 × 32 px (2:1 isometric diamond centered in 32px box, drawn with `scale = Vector2(2, 2)` to fill 64×32 grid tiles).
- **Bare Soil Alignment**: `Bare1..4.png` diamond faces sit 2px lower in canvas than grass; `TileRenderer.gd` automatically applies `offset = Vector2(0, -2)` to keep isometric depth lines seamless.
- **Auto-fallback**: If `ground_tile_sprites.tres` has empty arrays, `GroundTileSprites.gd` automatically scans and loads all textures from the 3 subfolders at runtime. If PNGs are absent, `TileRenderer.gd` falls back to procedural polygon colors.
