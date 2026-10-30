# Cosmos: Odyssey '2000 (Godot 4 version)

Godot 4 remake of the web game in `Cosmos-Odyssey-2000/`. Same rules, same events, same numbers.
Built and tested on Godot 4.3 (standard build, not .NET). It should open in 4.3, 4.4 and 4.5.

## Run
1. Open Godot 4, press **Import**, pick `project.godot`, then press **F5**.
2. Everything is built in code. There are no images or sounds to import.

## Controls
- Menus: click, or press the number shown on the option. **Enter** continues.
- Free camera at stops: drag with the left mouse button, mouse wheel to zoom.
- Asteroid fields: arrow keys / WASD, or hold the left mouse button and drag.
- **F11** toggles fullscreen. The **Sound** button (bottom right) turns the drone and beeps on.
- Crew screen has a **Quick start** button (Pilot + Engineer + Medic) for fast demos.

## Files
- `scripts/data.gd` stops, routes, crew, subsystems (from data.js)
- `scripts/state.gd` mission rules, damage, repair, re-entry, score (from state.js)
- `scripts/events.gd` malfunctions, solar flare, power drop (from events.js)
- `scripts/world.gd` Solar System scene, routes, labels (from world.js)
- `scripts/ship.gd` spacecraft that scorches and bends as it is damaged (from ship.js)
- `scripts/corridor.gd` hand-flown asteroid field (from corridor.js)
- `scripts/ui.gd` all menus and HUD
- `scripts/main.gd` game flow (from main.js)
- `shaders/` planet, disk, ring, glow shaders

## Automated test options (optional)
Run from a terminal: `godot --headless --path . -- --bot=smart --speed=25`
Bots: `smart`, `lazy`, `random`, `dumb`. It prints a `RESULT {...}` line at the end.

## Export for the demo (Windows)
1. Editor menu: Project > Export. Click "Manage Export Templates" and download the templates once.
2. Select the "Windows Desktop" preset and click Export Project. Untick "Export With Debug".
3. Test the .exe on the demo laptop, offline.

## Differences from the web version
- Saturn moved from 165 to 120 degrees on its orbit. In the web version it sat exactly behind the comet.
- Menus accept number keys. Fullscreen on F11.
