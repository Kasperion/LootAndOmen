# Loot and Omen

A top-down, turn-based caravan defense game for solo play or cooperative parties. Travel across the land by day. When night falls, make camp and keep the fire alive as creatures emerge from the encroaching darkness.

## Play the caravan prototype

Open the repository’s `project.godot` in Godot 4 and press **F5**. This single-player build follows the caravan from Pine Hollow to Stoneford.

- Click a portrait in **Party**, click a living hero on the map, or press **1**, **2**, or **3** to switch heroes and inspect their equipment. Click highlighted tiles to move. Scroll to zoom, drag the field to pan, and press **F11** to toggle fullscreen. Each hero starts with 3 movement tiles per turn, which can be split before, between, or after attacks.
- Click a creature within the selected hero’s weapon range to attack. Attacks, Heal, and Revive work across edges or corners. Two blocking tiles seal a diagonal corner. Bows require at least 2 tiles of range. The Ranger starts with 3 action points and can shoot twice per turn. Each shot spends 1 action point and 1 bow attack.
- **Ranger — Overwatch:** Spend 1 action point and one bow attack to fire once when a creature moves within bow range during the enemy phase.
- **Knight — Defend:** The equipped shield and armor passively reduce melee damage. Spend 1 action point on Defend to reduce the next melee hit by an additional point, plus any Shield Drill ranks. The Knight starts with 18 HP, 3 movement, 3 AP, and one adjacent sword strike per turn.
- **Priest — Heal and Revival:** Starts with 14 HP, 3 movement, 3 AP, a Travel Coat, and one adjacent Pilgrim Mace strike per turn. Spend 1 AP to restore 3 HP to yourself or an adjacent living ally. Merciful Light adds 1 HP per rank, up to rank III.
- Click an adjacent downed ally or use **Revive** to return them at 1 HP. It costs 2 AP for the Ranger or Knight and 1 AP for the Priest. Revived heroes regain their action and movement budgets on the next turn.
- Hover over an enemy to preview its approach and possible target. The heroes share a turn and spend their own budgets.
- Press **Space** or click **End Turn**. Ending a turn outside the circular firelight costs 1 HP.
- The hero who lands the killing blow earns 4 XP. Every party member earns 6 XP for a cleared wave. Traps and ballistae do not award individual kill XP. Each hero chooses their own upgrades at a wave break or before dawn. Most upgrades have three ranks, and effective bow range caps at ten tiles including equipment. If unlocked, toggle **Pinning Shot** and click a creature to fire a slowing shot.
- Build walls, traps, or ballistae on free lit tiles between waves. Click an existing wall or ballista during preparation to open its on-map **Upgrade**, **Repair**, and **Destroy** controls. Ballista upgrades increase range and damage, and wall upgrades increase maximum HP. Repair costs 1 supply and restores full HP. Destroy returns half the build and upgrade cost, rounded down. Adjacent wall segments join automatically.
- Each cleared wave awards 4 supplies. Unspent supplies carry into the next wave and travel with the caravan to the next campsite.
- Open **Menu** in the upper-right or press **Esc** for audio settings, restart, or exit. Settings save locally and include master volume, effects, night ambience, and a separate music toggle.
- Survive the night and select **Break Camp at Dawn** to collect loot marked by bags. Select a portrait during the day to equip compatible gear from the caravan stash. Swapped-out gear returns to the stash. Buy or sell at the roadside trader, and select **Set Up Camp at Dusk** to start the next defense.

### Base weapon stats

| Weapon | Range (tiles) | Damage |
| --- | ---: | ---: |
| Hunting Bow | 2–5 | 2 |
| War Bow | 2–6 | 3 |
| Longbow | 2–7 | 2 |
| Short Sword | 1 | 5 |
| Iron Sword | 1 | 6 |
| Pilgrim Mace | 1 | 3 |

Night maps and waves are defined in `night.gd`. Gear, upgrades, and starting merchant stock are defined in `journey.gd`.

## The caravan journey

1. **Travel.** Lead the caravan across the land and stop to make camp before nightfall.
2. **Defend the fire.** At the start of the night, the first wave spawns in the darkness, far enough away that players can see it approaching and get into position. The campfire is the objective and the source of safety. Characters who venture into the darkness take damage each turn they remain there. If the fire goes out, the defense fails.
3. **Build between waves.** Spend supplies on walls, gates, traps, and ballistae. Choose where to spend them based on the terrain, the approaches to camp, and how the previous wave went.
4. **Survive the night.** Keep the campfire alive through the waves so the caravan can continue its journey.

Hollows, fast Skitters, and hard-hitting Gravebacks attack in larger waves. The Hollow Maw takes up four tiles and joins the final wave at each campsite.

## Grid combat

The camera looks down onto a visible tile grid around the camp. Map layout, spawn locations, terrain, and campfire placement should be adjustable for playtesting.

- **Player phase:** Spend movement and action points in either order. Attacks and active abilities spend action points. Items are planned. The same core rules apply in solo and co-op.
- **Enemy phase:** Monsters pursue visible heroes or the campfire. They stop to strike as soon as they reach an adjacent target. They prefer an open path to the fire, and breach a defense when no route is open. Defend the fire by intercepting them before they reach it.
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
