FANTASY VILLAGE & ADVENTURERS — MOVING VILLAGE RELEASE 0.8.0
HappyHustle

6 PixelLab Pro characters, eight standing views each. All six have four-direction idle/walk clips: 48 clips and 288 timed frames combined.
32 furniture and prop sprites, native 32x32 small objects and 64x64 furniture.
16 connectable grass/path corner tiles at 32x32, with corner masks and original sheet.
80 building pieces on padded 52x101 canvases, including doors, stairs and roofs.
Building floor surface: 32x28 visible pixels at the generated camera angle.
3 furnished example scenes at 512x352: Village Square, Tavern, Forge Workshop.

Source character PNGs: 48x48. Registered turnaround atlas: 64x64 cells.
Read per-view pivots in each turnaround.json, and prop pivots in manifest.json.
Use nearest-neighbor filtering. Do not resample source pixels for import.

source/ contains three editable Aseprite documents with one layer per environment asset.
Characters and individual environment assets are flattened RGBA PNGs, not body-part layers.
Building pieces are stamped individually; they are not an 80-tile Wang set.
Terrain masks use NW bit3, NE bit2, SW bit1, SE bit0; 1=grass, 0=path.
Scenes are visual arrangements without collision, navigation or player controls.
No engine import kit or engine playtest is included.

Standing artwork: PixelLab Pro. All six characters use PixelLab skeleton-guided V3 motion with reviewed exact PixelLab cleanup. Source images were not resampled.
Commercial and non-commercial project use; credit optional. See LICENSE.txt.

KNIGHT ANIMATIONS
8 clips, 48 timed frames. See art/characters/knight/animations/animation.json.
80x80 cells, foot pivot (40,70). Native generated motion and reviewed exact PixelLab cleanup.

MAGE ANIMATIONS
8 clips, 48 timed frames. See art/characters/mage/animations/animation.json.
80x80 cells, foot pivot (40,70). Native PixelLab motion with reviewed exact cleanup.

RANGER ANIMATIONS
8 clips, 48 timed frames. See art/characters/ranger/animations/animation.json.
80x80 cells, foot pivot (40,70). Native PixelLab motion with reviewed exact cleanup.

ROGUE ANIMATIONS
8 clips, 48 timed frames. See art/characters/rogue/animations/animation.json.
80x80 cells, foot pivot (40,70). Native PixelLab motion with reviewed exact cleanup.

CLERIC ANIMATIONS
8 clips, 48 timed frames. See art/characters/cleric/animations/animation.json.
80x80 cells, foot pivot (40,70). Native PixelLab motion with reviewed exact cleanup.

BLACKSMITH ANIMATIONS
8 clips, 48 timed frames. See art/characters/blacksmith/animations/animation.json.
80x80 cells, foot pivot (40,70). Native PixelLab motion with reviewed exact cleanup.

MOVING VILLAGE SHOWCASE
Open examples/village/index.html to see all six characters walking and idling together.
Self-contained browser demo, 10.4-second loop, pause, speed, timeline and optional name labels.
Staged visual paths; no collision, navigation or player controls.
