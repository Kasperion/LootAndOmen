# Loot and Omen

A top-down, turn-based caravan defense game for solo play or cooperative parties. Travel across the land by day. When night falls, make camp and keep the fire alive as creatures emerge from the encroaching darkness.

## Play the caravan prototype

Open the repository’s `project.godot` in Godot 4 and press **F5**. This single-player build follows the caravan from Pine Hollow to Stoneford.

- Click the Ranger or Knight, or press **1** or **2**, to switch heroes. Click highlighted tiles to move. The Ranger starts with 3 movement tiles per turn, which can be split before, between, or after attacks.
- Click a creature within bow range to shoot. The Ranger starts with 3 action points and can shoot twice per turn. Each shot spends 1 action point and 1 bow attack.
- **Ranger — Overwatch:** Spend 1 action point and one bow attack to fire once when a creature moves within bow range during the enemy phase.
- **Knight — Defend:** Spend 1 action point to block the next melee hit against the Knight this round. The Knight starts with 16 HP, 3 movement, 3 AP, and one adjacent sword strike per turn.
- Hover over an enemy to preview its approach and possible target. Both heroes share a turn but spend their own budgets.
- Press **Space** or click **End Turn**. Ending a turn outside the light costs 1 HP.
- Earn XP for kills and surviving waves. Choose one of three upgrades at a wave break or before dawn. Most upgrades have three ranks, and effective bow range caps at eight tiles including equipment. If unlocked, toggle **Pinning Shot** and click a creature to fire a slowing shot.
- Build walls, traps, or ballistae on free lit tiles between waves.
- Survive the night and select **Break Camp at Dawn** to collect loot marked by bags. Equip gear during the day, buy or sell at the roadside trader, and select **Set Up Camp at Dusk** to start the next defense.

Night maps and waves are defined in `night.gd`. Gear, upgrades, and starting merchant stock are defined in `journey.gd`.

## The caravan journey

1. **Travel.** Lead the caravan across the land and stop to make camp before nightfall.
2. **Defend the fire.** At the start of the night, the first wave spawns in the darkness, far enough away that players can see it approaching and get into position. The campfire is the objective and the source of safety. Characters who venture into the darkness take damage each turn they remain there. If the fire goes out, the defense fails.
3. **Build between waves.** Spend supplies on walls, gates, traps, and ballistae. Choose where to spend them based on the terrain, the approaches to camp, and how the previous wave went.
4. **Survive the night.** Keep the campfire alive through the waves so the caravan can continue its journey.

Creatures include mutated humans, twisted animals, and abominations. Their appearance and behavior can vary by region and wave.

## Grid combat

The camera looks down onto a visible tile grid around the camp. Map layout, spawn locations, terrain, and campfire placement should be adjustable for playtesting.

- **Player phase:** Spend movement and action points in either order. Attacks and active abilities spend action points. Items are planned. The same core rules apply in solo and co-op.
- **Enemy phase:** Monsters move up to their movement allowance, then attack a target within range. Defend the fire by intercepting them before they reach it.
- **Darkness:** Standing outside the campfire's safe area deals damage each turn. The board should clearly distinguish safe tiles from darkness. Keep incoming creatures readable so players can plan their approach.

### Starting combat values

| Unit | Attack range | Movement per turn |
| --- | ---: | ---: |
| Ranger with a bow | 5 tiles | 3 tiles |
| Knight with a sword | 1 tile | 3 tiles |
| Basic melee monster | 1 tile | Up to 3 tiles |

Action point budgets, damage, movement and range measurement, line of sight, light radius, darkness damage timing, and co-op planning rules are playtest decisions. Cards are an optional design idea. The starting combat loop uses character abilities and action points.

## Art and animation

Use an original, readable 2D style with strong silhouettes and a clear contrast between firelight and darkness. The proposed art direction is inked silhouettes and textured, illustrated terrain, with warm firelight and a moving shadow edge. Characters and monsters should animate during play. Start with idle, move, attack, hit, and death animations, plus the campfire, projectiles, and the encroaching darkness. Keep the grid, movement destinations, and attack ranges readable through the effects.

## Engine and release plan

Use **Godot 4 and GDScript**. Author adjustable maps with [TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html), animate sprites with [AnimatedSprite2D or AnimationPlayer](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html), and render the campfire using [2D lights](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html). Track lit and dark tiles in the turn rules so a flickering flame never changes which tiles deal damage. Keep rules separate from animation so solo and co-op can resolve the same actions.

Target a [Windows desktop export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html) first. Steam distribution uses [SteamPipe](https://partner.steamgames.com/doc/sdk/uploading). Validate the core turn loop locally, then test an online session early before expanding content.

## First playable milestone

Build one adjustable campsite with two approaches, one Ranger, one melee creature type, and one night of three short waves. Include tile movement, bow attacks, action points, darkness damage, campfire victory and defeat conditions, basic animations, and a between-wave spending phase. Use the first playtest to find out whether stepping into the dark for a better shot is an interesting trade and whether the defenses change where the Ranger wants to stand.
