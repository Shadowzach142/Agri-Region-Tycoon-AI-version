# Agri-Region Tycoon — Agent Rules

## ALWAYS READ FIRST
Before making any changes to this project, read `GEMINI.md` at the repository root. It contains the full architecture, file map, signal reference, HUD patterns, sprite rules, testing commands, and all known gotchas. Reading it first saves you from needing to individually inspect every file.

## Absolute Rules (Never Break)

1. **Never create PNG/SVG/art files** — User provides all sprites manually.
2. **Never push to GitHub** unless the user explicitly says "push" or "commit and push".
3. **Never change `default_texture_filter=0`** in project.godot.
4. **Never rename** `GoldbuttonPresesd.tres` or `HUD-brown button .png` (intentional typos).
5. **Never hardcode `get_node()` paths** in `HUD.gd` — always use `find_child(name, true, false)`.
6. **Never put buttons inside RightCluster HBoxContainer** unless they are stat capsules — use standalone `layout_mode=0` nodes for action buttons.
7. **Never duplicate `unique_id=` values** when editing `.tscn` files.

## Code Style

- GDScript 4 — typed where possible: `var x: int = 0`, `func foo() -> void:`
- All new HUD references follow the discovery pattern in §5 of GEMINI.md
- All farm actions fire `LogManager.log_event(category, message, icon, color)` — see §9 of GEMINI.md for the exact category/color table
- New CanvasLayer overlays: assign a unique `layer` value, set `process_mode = Node.PROCESS_MODE_ALWAYS`, and add to a group for easy lookup

## Testing

After any GDScript change, always run the headless parse check from GEMINI.md §11:
```powershell
& "C:\Users\ADMIN\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "c:\Users\ADMIN\Documents\agri-region-ai-version" --scene res://scenes/MainGame.tscn --quit-after 50
```
Exit code 0 = pass. If exit code ≠ 0, fix errors before reporting done.

For visual screenshots, NEVER use `extends SceneTree` scripts via `-s` flag — autoloads won't register. Instead create a `Node2D` scene + attach the test script and use `--scene res://test.tscn`.

## File Organization Rules

- Autoloads (singletons) → `autoload/`
- Scenes (`.tscn`) + their root scripts (`.gd`) → `scenes/`
- All other gameplay scripts → `src/`
- Sprites/textures → `Sprites/` (user-managed)
- Icons → `Icons/`
- Scratch/temp test files → create in project root, delete after use

## GEMINI.md Maintenance

After any significant change, add a row to the "Commit History Summary" table in GEMINI.md (§14) and update any affected sections. Keep GEMINI.md as the single source of truth.
