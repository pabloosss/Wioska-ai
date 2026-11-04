MEDIEVAL VILLAGE 2.5D - FREE STARTER - v1.2.0
Sidiq Pratomo / RetroForge

CONTENTS
58 sprite families in one top-down 3/4 view with down/right/up/left facings:
5 villagers, 5 animals, 12 crop growth stages and 36 buildings, props and nature
pieces. Also: 5 terrain families (grass, dirt, cobble, tilled soil and watered
tilled soil), 7 ground decals, 12 item icons and 4 action effects.
Frames, directions and resolutions are output variants, not extra designs.

NEW IN 1.2.0 - A SMALL FARM YOU CAN PLAY
Till, sow, water and harvest: wheat, carrot and strawberry in four growth
stages (sprout, young, mature, ripe), tilled soil tiles dry and watered with
all 16 connections, and a sowing decal for freshly planted squares.
The farmer now has seven actions: hoe, chop, sickle, sow, water and harvest,
plus idle and walk. Effects for soil, wood chips, cuttings and seeds play at
the impact frame. New villagers: merchant, child and elder. New animals: cow,
dog and cat. New farm buildings and props: barn, chicken coop, trough, hay
stack, bucket, baskets, sacks, firewood, notice board, chopping block,
scarecrow, tools, lamp post, apple tree and a tree trunk to chop.
Updated: farmer (straw hat, warmer colours), woman (smaller coif), smaller
hen, continuous thatch roof, stronger contact shadows on every sprite.

FIRST USE
Choose one resolution per map. 1x = 32 pixels per metre; 2x = 64.
A 2 m square terrain tile is 64x64 or 128x128 pixels. Scale is already baked
into every sprite. Use alpha blending and inspect at native size; nearest
filtering keeps detail sharp. These are pre-rendered sprites.

FILES AND PATHS
metadata.json indexes the pack. Each Sprites/<id>/metadata.json lists frame and
sheet paths, directions, pixel sizes, ground pivots and frame timing. All JSON
paths are relative to the package root.
Shadows/: separate contact PNGs, drawn below the sprite at the same ground point.
Terrain/: 4 bases per material; dirt, cobble and both tilled soils include all
16 NESW connection masks. Decals/: direction-free ground details, including
"seeded" for a freshly sown 1 m square.
Icons/: inventory icons (seeds, wheat, carrot, strawberry, apple, egg, milk,
wool, coin, hoe, watering can, sickle), one view, 1x and 2x.
Effects/: one-shot frame sequences and sheets; see ACTIONS AND EFFECTS.
Examples/: scene PNGs, GIFs, catalog pages and layout data. manifest.json lists
SHA-256 hashes of the other files.

PLACEMENT
Pivots are pixel offsets from the PNG upper-left to the ground origin. Draw at
the ground position minus the pivot; draw contacts first and sort sprites by
ground Y. Frames of one clip share canvas and pivot; facings may differ.
Static down is the default facing, right 90, up 180, left 270 degrees.
Crops: one sprite per 1 m planting square, so a 2 m tilled tile holds four.

TERRAIN
NESW bits: north 1, east 2, south 4, west 8. Add the connected neighbours of
the same material. Mask 0 is an isolated patch. Tilled soil rows run east-west;
use tilled_wet for watered squares. Road tiles include grass.

ANIMATION (frames / fps, every clip loops)
White hen: Idle 15/3.75, Walk 7/10, Eat 12/5
Farmer: Idle 8/4, Walk 12/15, Hoe 8/8, Chop 8/8, Sickle 8/8, Sow 8/8, Water 8/6, Harvest 8/6
Cream sheep: Idle 12/5, Walk 12/15, Eat 14/5
Village woman: Idle 8/4, Walk 12/15
Merchant: Idle 8/4, Walk 12/15
Village child: Idle 8/4, Walk 12/15
Village elder: Idle 8/4, Walk 12/15
Piebald cow: Idle 12/4, Walk 12/10, Eat 14/4
Brown dog: Idle 15/3.75, Walk 11/15, Eat 15/5
Ginger cat: Idle 15/3.75, Walk 12/15, Eat 15/5
Sheets run left to right without padding. Per-sheet FPS is authoritative.

ACTIONS AND EFFECTS
Hoe, chop and sickle hit on frame 3 (0-based) of 8; sow releases on frame 5.
Play the matching effect once from that frame, placed at the impact point:
FX_Soil_Burst under the hoe blade, FX_Wood_Chips at the chopped trunk,
FX_Grass_Cut at the cut stems, FX_Seed_Scatter in front of the sower.
Harvest is empty-handed so it fits any crop: remove the ripe crop on frame 3
and show the matching item icon. The tree trunk's notch faces the viewer in
the down facing.

SCOPE AND RIGHTS
2D artwork only: no game, engine project, collisions or 3D files. Buildings
are whole roofed sprites.
Commercial use and modification are allowed under LICENSE.txt; attribution
is optional. Do not redistribute the raw assets as another pack. Free does not
mean public domain. CREDITS.txt records ownership and provenance.

EXAMPLE SCENES
Seven scenes: six village scenes at 1x and 2x and a small farm at 2x. Each has
a finished image and a reusable ground image in Examples/Ground/. The layout
file lists placements and ordered contact/sprite draws: load the ground, then
draw the layers in order. Ground images already include terrain and decals.
