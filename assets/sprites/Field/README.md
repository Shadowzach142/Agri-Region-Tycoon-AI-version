# Custom Crop Sprites Guide

Drop custom pixel-art crop sprites here to automatically override the default emoji font on farm plots!

## File Naming Convention
Drop your transparent RGBA PNG files in this directory matching the crop key:
- `pineapple.png` — Smooth Cayenne Pineapple
- `sugarcane.png` — Sugarcane (Tupi / Sultan Kudarat variety)
- `palay.png` — Palay (Rice)
- `yellow_corn.png` — Yellow Corn
- `arabica_coffee.png` — Arabica Coffee
- `banana.png` — Cavendish Banana
- `coconut.png` — Coconut Palm (2×2 Multi-Tile Grove Tree)

## Recommended Specs
- **1×1 Crops**: 32×32 px up to 64×64 px (drawn with an upright 2.5D elevation perspective)
- **2×2 Crops (Coconut)**: 64×64 px up to 128×128 px (centered over the 2×2 diamond grove)
- **Format**: PNG with transparent background
- **Texture Filter**: Nearest-Neighbor (pixel art friendly)
- **Automatic Fallback**: If a PNG file is not found, the game automatically uses the procedural 2.5D renderer or pixel font emoji (`🎋`, `🍍`, `🌾`, `🌽`, etc.).
