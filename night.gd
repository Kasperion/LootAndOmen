extends RefCounted

const Journey := preload("res://journey.gd")

enum Phase { PLAYER, ENEMY, BUILD, VICTORY, DEFEAT }

const SIZE := Vector2i(21, 15)
const FIRE := Vector2i(10, 7)
const LIGHT_RADIUS := 4
const DARK_DAMAGE := 1
const ENEMY_MOVE := 3
const NO_TILE := Vector2i(-1, -1)
const SIGHT := 9
const CREATURES := {
	"husk": ["Hollow", 3, 2, 3, 1],
	"skitter": ["Skitter", 2, 2, 4, 1],
	"brute": ["Graveback", 6, 4, 2, 1],
	"boss": ["The Hollow Maw", 15, 5, 2, 2],
}
const WAVE_CREATURES := [
	["husk", "skitter", "husk", "husk"],
	["brute", "husk", "skitter", "husk", "brute"],
	["husk", "skitter", "brute", "brute", "skitter", "boss"],
]
const MAX_AP := 3
const MAX_FIRE_HP := 18
const SPAWNS := [
	[Vector2i(2, 4), Vector2i(18, 10), Vector2i(6, 12), Vector2i(14, 2)],
	[Vector2i(2, 4), Vector2i(18, 10), Vector2i(6, 12), Vector2i(14, 2), Vector2i(17, 4)],
	[Vector2i(2, 4), Vector2i(18, 10), Vector2i(6, 12), Vector2i(14, 2), Vector2i(17, 4), Vector2i(1, 7)],
]
const ROCKS := [Vector2i(5, 6), Vector2i(6, 6), Vector2i(6, 7), Vector2i(14, 7),
	Vector2i(14, 8), Vector2i(15, 8), Vector2i(9, 3), Vector2i(11, 11), Vector2i(16, 12)]
const STONEFORD_ROCKS := [Vector2i(6, 3), Vector2i(7, 3), Vector2i(7, 4),
	Vector2i(12, 6), Vector2i(13, 6), Vector2i(13, 7), Vector2i(13, 8), Vector2i(14, 8),
	Vector2i(6, 10), Vector2i(7, 10), Vector2i(17, 3)]
const STONEFORD_SPAWNS := [
	[Vector2i(2, 7), Vector2i(18, 5), Vector2i(16, 12), Vector2i(7, 1)],
	[Vector2i(2, 7), Vector2i(18, 5), Vector2i(16, 12), Vector2i(7, 1), Vector2i(12, 13)],
	[Vector2i(2, 7), Vector2i(18, 5), Vector2i(16, 12), Vector2i(7, 1), Vector2i(12, 13), Vector2i(17, 7)],
]
const PINE_TREES := [Vector2i(2, 1), Vector2i(3, 2), Vector2i(8, 2), Vector2i(11, 3),
	Vector2i(16, 1), Vector2i(18, 3), Vector2i(3, 6), Vector2i(4, 11), Vector2i(8, 11),
	Vector2i(13, 11), Vector2i(18, 13), Vector2i(5, 1), Vector2i(1, 12), Vector2i(19, 1)]
const FORD_TREES := [Vector2i(2, 2), Vector2i(4, 4), Vector2i(8, 3), Vector2i(12, 4),
	Vector2i(17, 1), Vector2i(17, 9), Vector2i(4, 10), Vector2i(8, 12), Vector2i(12, 11),
	Vector2i(15, 10), Vector2i(19, 12), Vector2i(1, 3)]
const PINE_CLIFFS := [Vector2i(0, 10), Vector2i(0, 11), Vector2i(0, 12), Vector2i(0, 13), Vector2i(0, 14),
	Vector2i(1, 13), Vector2i(1, 14), Vector2i(2, 14), Vector2i(3, 14), Vector2i(4, 14),
	Vector2i(17, 0), Vector2i(18, 0), Vector2i(19, 0), Vector2i(20, 0), Vector2i(20, 1)]
const FORD_CLIFFS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 1), Vector2i(19, 13), Vector2i(20, 13),
	Vector2i(17, 14), Vector2i(18, 14), Vector2i(19, 14), Vector2i(20, 14), Vector2i(20, 12)]
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const BUILD_COST := {"Wall": 2, "Trap": 1, "Ballista": 3}
const STRUCTURE_HP := {"Wall": 5, "Ballista": 4}
const MAX_STRUCTURE_LEVEL := 3
const FIX_COST := 1

class Hero:
	var title: String
	var character: Journey.Character
	var tile: Vector2i
	var hp: int
	var movement: int
	var ap: int
	var attacks: int
	var prepared := false

	func _init(member: Journey.Character, start: Vector2i) -> void:
		character = member
		title = member.title
		tile = start
		hp = member.max_health()

class Enemy:
	var tile: Vector2i
	var hp: int
	var max_hp: int
	var pinned := false
	var damage: int
	var kind: String
	var speed: int
	var size: int

	func _init(start: Vector2i, health: int, hit: int = 2, creature: String = "husk",
			move: int = ENEMY_MOVE, footprint: int = 1) -> void:
		tile = start
		hp = health
		max_hp = health
		damage = hit
		kind = creature
		speed = move
		size = footprint

var phase := Phase.PLAYER
var wave := 0
var turn := 1
var journey: Journey
var ranger: Hero
var knight: Hero
var priest: Hero
var heroes: Array[Hero] = []
var fire_hp := MAX_FIRE_HP
var kills := 0
var loot: Dictionary = {}
var rocks: Array
var trees: Array
var cliffs: Array
var spawns: Array
var supplies := 0
var enemies: Array[Enemy] = []
var defenses: Dictionary = {}
var message := ""

func _init(run: Journey = null) -> void:
	journey = run if run != null else Journey.new()
	ranger = Hero.new(journey.ranger, FIRE + Vector2i.DOWN)
	knight = Hero.new(journey.knight, FIRE + Vector2i.UP)
	priest = Hero.new(journey.priest, FIRE + Vector2i.LEFT)
	heroes.assign([ranger, knight, priest])
	rocks = ROCKS if journey.site == 0 else STONEFORD_ROCKS
	trees = PINE_TREES if journey.site == 0 else FORD_TREES
	cliffs = PINE_CLIFFS if journey.site == 0 else FORD_CLIFFS
	spawns = SPAWNS if journey.site == 0 else STONEFORD_SPAWNS

func start_wave() -> void:
	if wave >= spawns.size() or (wave > 0 and phase != Phase.BUILD):
		return
	wave += 1
	turn = 1
	phase = Phase.PLAYER
	reset_actions()
	for i in spawns[wave - 1].size():
		var kind: String = WAVE_CREATURES[wave - 1][i]
		var stats: Array = CREATURES[kind]
		var health: int = stats[1] + (journey.site * 3 if kind == "boss" else 0)
		enemies.append(Enemy.new(spawns[wave - 1][i], health, stats[2], kind, stats[3], stats[4]))
	message = "The Hollow Maw has arrived." if wave == spawns.size() else "Wave %d approaches. Keep the fire alive." % wave

func reset_actions() -> void:
	for hero: Hero in heroes:
		hero.ap = MAX_AP
		hero.movement = movement_limit(hero)
		hero.attacks = attack_limit(hero)
		hero.prepared = false

func max_health(hero: Hero) -> int:
	return hero.character.max_health()

func movement_limit(hero: Hero) -> int:
	return 3 + hero.character.rank_of("move")

func attack_limit(hero: Hero) -> int:
	return 2 if hero == ranger else 1

func attack_range(hero: Hero) -> int:
	return hero.character.max_range()

func in_weapon_range(hero: Hero, tile: Vector2i) -> bool:
	var gap := distance(hero.tile, tile)
	return gap >= int(hero.character.weapon().min) and gap <= attack_range(hero) and has_sight(hero.tile, tile)

func attack_damage(hero: Hero) -> int:
	return int(hero.character.weapon().damage) + hero.character.rank_of("damage")

func hero_at(tile: Vector2i) -> Hero:
	for hero: Hero in heroes:
		if hero.hp > 0 and hero.tile == tile:
			return hero
	return null

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func is_lit(tile: Vector2i) -> bool:
	return fire_hp > 0 and FIRE.distance_squared_to(tile) <= LIGHT_RADIUS * LIGHT_RADIUS

func on_board(tile: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, SIZE).has_point(tile)

func enemy_at(tile: Vector2i) -> Enemy:
	for enemy: Enemy in enemies:
		if Rect2i(enemy.tile, Vector2i.ONE * enemy.size).has_point(tile):
			return enemy
	return null

func is_structure(tile: Vector2i) -> bool:
	return defenses.has(tile) and STRUCTURE_HP.has(defenses[tile].kind)

func is_terrain_blocked(tile: Vector2i) -> bool:
	return tile in rocks or tile in trees or tile in cliffs

func structure_max_hp(piece: Dictionary) -> int:
	return STRUCTURE_HP[piece.kind] + (piece.level - 1) * 3 if piece.kind == "Wall" else STRUCTURE_HP[piece.kind]

func ballista_range(piece: Dictionary) -> int:
	return 3 + piece.level

func ballista_damage(piece: Dictionary) -> int:
	return 1 + piece.level

func wall_links(tile: Vector2i) -> Array[Vector2i]:
	var links: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		var neighbor := tile + direction
		if defenses.has(neighbor) and defenses[neighbor].kind == "Wall":
			links.append(direction)
	return links

func salvage_value(piece: Dictionary) -> int:
	return int(BUILD_COST[piece.kind] * piece.level) >> 1

func can_manage(tile: Vector2i, action: String) -> bool:
	if phase != Phase.BUILD or not is_structure(tile):
		return false
	var piece: Dictionary = defenses[tile]
	match action:
		"Upgrade": return piece.level < MAX_STRUCTURE_LEVEL and supplies >= BUILD_COST[piece.kind]
		"Repair": return piece.hp < structure_max_hp(piece) and supplies >= FIX_COST
		"Destroy": return true
	return false

func manage(tile: Vector2i, action: String) -> bool:
	if not can_manage(tile, action):
		return false
	var piece: Dictionary = defenses[tile]
	match action:
		"Upgrade":
			var previous_max := structure_max_hp(piece)
			supplies -= BUILD_COST[piece.kind]
			piece.level += 1
			piece.hp += structure_max_hp(piece) - previous_max
			message = "%s upgraded to level %d." % [piece.kind, piece.level]
		"Repair":
			supplies -= FIX_COST
			piece.hp = structure_max_hp(piece)
			message = "%s repaired." % piece.kind
		"Destroy":
			var refund := salvage_value(piece)
			supplies += refund
			defenses.erase(tile)
			message = "%s dismantled. Recovered %d supplies." % [piece.kind, refund]
	return true

func reach_for(hero: Hero) -> Dictionary:
	if phase != Phase.PLAYER or hero.hp <= 0 or hero.movement == 0:
		return {}
	var reach := {hero.tile: 0}
	var frontier: Array[Vector2i] = [hero.tile]
	var index := 0
	while index < frontier.size():
		var tile := frontier[index]
		index += 1
		if reach[tile] == hero.movement:
			continue
		for step: Vector2i in DIRECTIONS:
			var next := tile + step
			if reach.has(next) or not on_board(next) or next == FIRE or is_terrain_blocked(next):
				continue
			if is_structure(next) or enemy_at(next) != null or hero_at(next) != null:
				continue
			reach[next] = reach[tile] + 1
			frontier.append(next)
	return reach

func move_hero(hero: Hero, tile: Vector2i) -> Array[Vector2i]:
	var reach := reach_for(hero)
	var path: Array[Vector2i] = []
	if tile == hero.tile or not reach.has(tile):
		return path
	var cursor := tile
	while cursor != hero.tile:
		path.push_front(cursor)
		for step: Vector2i in DIRECTIONS:
			var previous := cursor + step
			if reach.get(previous, -1) == reach[cursor] - 1:
				cursor = previous
				break
	hero.movement -= path.size()
	hero.tile = tile
	message = "%s moved." % hero.title if is_lit(tile) else "Darkness deals damage if you end your turn here."
	return path

func can_attack(hero: Hero, tile: Vector2i, pin: bool = false) -> bool:
	return phase == Phase.PLAYER and hero.hp > 0 and hero.ap > 0 and hero.attacks > 0 \
		and enemy_at(tile) != null and in_weapon_range(hero, tile) \
		and (not pin or (hero == ranger and hero.character.rank_of("pin") > 0))

func attack(hero: Hero, tile: Vector2i, pin: bool = false) -> bool:
	if not can_attack(hero, tile, pin):
		return false
	var enemy := enemy_at(tile)
	hero.ap -= 1
	hero.attacks -= 1
	var damage := attack_damage(hero)
	enemy.pinned = enemy.pinned or pin
	damage_enemy(enemy, damage, hero)
	var attack_name := "Pinning Shot" if pin else {"Knight": "Sword strike", "Priest": "Mace strike", "Ranger": "Bow shot"}[hero.title] as String
	message = "%s dealt %d damage." % [attack_name, damage]
	if enemy.hp <= 0:
		message += " %s earned 4 XP." % hero.title
	finish_wave_if_clear()
	return true

func fallen_at(tile: Vector2i) -> Hero:
	for hero: Hero in heroes:
		if hero.hp == 0 and hero.tile == tile:
			return hero
	return null

func revive_cost(hero: Hero) -> int:
	return 1 if hero == priest else 2

func can_revive(hero: Hero, target: Hero) -> bool:
	return phase == Phase.PLAYER and hero.hp > 0 and target != null and target.hp == 0 \
		and distance(hero.tile, target.tile) == 1 and hero.ap >= revive_cost(hero) \
		and hero_at(target.tile) == null and enemy_at(target.tile) == null and not is_structure(target.tile)

func revive(hero: Hero, target: Hero) -> bool:
	if not can_revive(hero, target):
		return false
	hero.ap -= revive_cost(hero)
	target.hp = 1
	target.ap = 0
	target.movement = 0
	target.attacks = 0
	target.prepared = false
	message = "%s revived %s at 1 HP." % [hero.title, target.title]
	return true

func heal_power() -> int:
	return 3 + priest.character.rank_of("heal")

func can_heal(target: Hero) -> bool:
	return phase == Phase.PLAYER and priest.hp > 0 and priest.ap > 0 and target != null \
		and target.hp > 0 and target.hp < max_health(target) and distance(priest.tile, target.tile) <= 1

func heal(target: Hero) -> bool:
	if not can_heal(target):
		return false
	var restored := mini(heal_power(), max_health(target) - target.hp)
	priest.ap -= 1
	target.hp += restored
	message = "The Priest restored %d HP to %s." % [restored, target.title]
	return true

func can_prepare(hero: Hero) -> bool:
	return phase == Phase.PLAYER and hero.hp > 0 and hero.ap > 0 and not hero.prepared \
		and (hero == knight or (hero == ranger and hero.attacks > 0))

func prepare(hero: Hero) -> bool:
	if not can_prepare(hero):
		return false
	hero.ap -= 1
	hero.prepared = true
	if hero == ranger:
		hero.attacks -= 1
		message = "Overwatch armed. Fires once when a creature moves within bow range."
	else:
		message = "Defend ready. Extra shield reduction applies to the next melee hit."
	return true

func can_overwatch(enemy: Enemy) -> bool:
	return ranger.hp > 0 and ranger.prepared and enemies.has(enemy) \
		and on_board(overwatch_tile(enemy))

func overwatch_tile(enemy: Enemy) -> Vector2i:
	for tile: Vector2i in footprint_at(enemy.tile, enemy.size):
		if in_weapon_range(ranger, tile):
			return tile
	return NO_TILE

func fire_overwatch(enemy: Enemy) -> void:
	if not can_overwatch(enemy):
		return
	ranger.prepared = false
	var damage := attack_damage(ranger)
	damage_enemy(enemy, damage, ranger)
	message = "Overwatch dealt %d damage." % damage
	if enemy.hp <= 0:
		message += " Ranger earned 4 XP."

func damage_enemy(enemy: Enemy, amount: int, killer: Hero = null) -> void:
	enemy.hp -= amount
	if enemy.hp <= 0:
		enemies.erase(enemy)
		kills += 1
		if killer != null:
			killer.character.xp += 4
		if kills == 1 or kills == 4:
			var items := [["longbow", "quilted_coat"], ["iron_sword", "reinforced_shield"]]
			var id: String = items[journey.site][0 if kills == 1 else 1]
			if not loot.has(enemy.tile):
				loot[enemy.tile] = []
			loot[enemy.tile].append(id)

func collect_loot() -> Array[String]:
	var items: Array[String] = []
	if phase != Phase.VICTORY or journey.daylight:
		return items
	for pile: Array in loot.values():
		for id: String in pile:
			items.append(id)
	journey.collect_loot(items)
	journey.daylight = true
	loot.clear()
	return items

func build(kind: String, tile: Vector2i) -> bool:
	if phase != Phase.BUILD or not BUILD_COST.has(kind) or supplies < BUILD_COST[kind]:
		return false
	if not on_board(tile) or not is_lit(tile) or tile == FIRE or hero_at(tile) != null:
		return false
	if is_terrain_blocked(tile) or defenses.has(tile):
		return false
	supplies -= BUILD_COST[kind]
	var piece := {"kind": kind, "level": 1}
	if STRUCTURE_HP.has(kind):
		piece.hp = structure_max_hp(piece)
	defenses[tile] = piece
	message = "%s placed." % kind
	return true

func finish_wave_if_clear() -> bool:
	if phase not in [Phase.PLAYER, Phase.ENEMY] or not enemies.is_empty():
		return false
	for hero: Hero in heroes:
		hero.character.xp += 6
	supplies += 4
	if wave == spawns.size():
		phase = Phase.VICTORY
		message = "Dawn breaks. The party gained 6 XP and the camp gained 4 supplies."
	else:
		phase = Phase.BUILD
		message = "Wave cleared. The party gained 6 XP. The camp gained 4 supplies."
	return true

func finish_if_lost() -> bool:
	if fire_hp > 0:
		for hero: Hero in heroes:
			if hero.hp > 0:
				return false
	phase = Phase.DEFEAT
	message = "The fire went out." if fire_hp <= 0 else "The party fell."
	return true

func begin_enemy_phase() -> bool:
	if phase != Phase.PLAYER:
		return false
	phase = Phase.ENEMY
	var hurt: PackedStringArray = []
	for hero: Hero in heroes:
		if hero.hp > 0 and not is_lit(hero.tile):
			hero.hp = maxi(0, hero.hp - DARK_DAMAGE)
			hurt.append(hero.title)
	message = "Darkness hurt %s." % " and ".join(hurt) if not hurt.is_empty() else "The creatures are moving."
	finish_if_lost()
	return true

func footprint_at(origin: Vector2i, size: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = [origin]
	if size == 2:
		tiles.append_array([origin + Vector2i.RIGHT, origin + Vector2i.DOWN, origin + Vector2i.ONE])
	return tiles

func footprint_distance(origin: Vector2i, size: int, target: Vector2i) -> int:
	var nearest := target.clamp(origin, origin + Vector2i.ONE * (size - 1))
	return distance(nearest, target)

func sight_blocked(tile: Vector2i) -> bool:
	return is_terrain_blocked(tile) or is_structure(tile)

func has_sight(from: Vector2i, to: Vector2i) -> bool:
	var point := from
	var gap := (to - from).abs()
	var step := (to - from).sign()
	var error := gap.x - gap.y
	while point != to:
		var old := point
		var doubled := error * 2
		if doubled > -gap.y:
			error -= gap.y
			point.x += step.x
		if doubled < gap.x:
			error += gap.x
			point.y += step.y
		if old.x != point.x and old.y != point.y:
			if sight_blocked(Vector2i(old.x, point.y)) and sight_blocked(Vector2i(point.x, old.y)):
				return false
		if point != to and sight_blocked(point):
			return false
	return true

func enemy_goal(enemy: Enemy) -> Vector2i:
	var goal := FIRE
	var best := SIGHT + 1
	for hero: Hero in heroes:
		var gap := footprint_distance(enemy.tile, enemy.size, hero.tile)
		if hero.hp <= 0 or gap >= best:
			continue
		for tile: Vector2i in footprint_at(enemy.tile, enemy.size):
			if has_sight(tile, hero.tile):
				goal = hero.tile
				best = gap
				break
	return goal

func structure_in_step(enemy: Enemy, origin: Vector2i) -> Vector2i:
	for tile: Vector2i in footprint_at(origin, enemy.size):
		if is_structure(tile):
			return tile
	return NO_TILE

func can_enemy_enter(enemy: Enemy, origin: Vector2i, allow_structures: bool) -> bool:
	if not on_board(origin) or not on_board(origin + Vector2i.ONE * (enemy.size - 1)):
		return false
	for tile: Vector2i in footprint_at(origin, enemy.size):
		if tile == FIRE or hero_at(tile) != null or is_terrain_blocked(tile):
			return false
		if not allow_structures and is_structure(tile):
			return false
		var occupant := enemy_at(tile)
		if occupant != null and occupant != enemy:
			return false
	return true

func search_path(enemy: Enemy, goal: Vector2i, allow_structures: bool) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [enemy.tile]
	var previous := {enemy.tile: enemy.tile}
	var index := 0
	while index < frontier.size():
		var tile := frontier[index]
		index += 1
		if footprint_distance(tile, enemy.size, goal) == 1:
			var path: Array[Vector2i] = []
			while tile != enemy.tile:
				path.push_front(tile)
				tile = previous[tile]
			return path
		for direction: Vector2i in DIRECTIONS:
			var next := tile + direction
			if not previous.has(next) and can_enemy_enter(enemy, next, allow_structures):
				previous[next] = tile
				frontier.append(next)
	return []

func enemy_path(enemy: Enemy) -> Array[Vector2i]:
	if on_board(enemy_target(enemy, enemy.tile)):
		return []
	var goal := enemy_goal(enemy)
	var path := search_path(enemy, goal, false)
	if path.is_empty() and goal != FIRE:
		path = search_path(enemy, FIRE, false)
	if path.is_empty():
		path = search_path(enemy, FIRE, true)
	return path

func enemy_movement(enemy: Enemy) -> int:
	return 1 if enemy.pinned else enemy.speed

func step_enemy(enemy: Enemy, tile: Vector2i) -> bool:
	var obstruction := structure_in_step(enemy, tile)
	if on_board(obstruction):
		attack_enemy_target(enemy, obstruction)
		return false
	enemy.tile = tile
	for trap_tile: Vector2i in footprint_at(tile, enemy.size):
		if defenses.has(trap_tile) and defenses[trap_tile].kind == "Trap":
			defenses.erase(trap_tile)
			damage_enemy(enemy, 3)
			message = "A creature triggered a trap."
			if not enemies.has(enemy):
				return false
	return true

func enemy_target(enemy: Enemy, from: Vector2i) -> Vector2i:
	# The Knight intercepts when multiple heroes are adjacent.
	for hero: Hero in [knight, ranger, priest]:
		if hero.hp > 0 and footprint_distance(from, enemy.size, hero.tile) == 1:
			return hero.tile
	return FIRE if footprint_distance(from, enemy.size, FIRE) == 1 else NO_TILE

func attack_enemy_target(enemy: Enemy, target: Vector2i) -> void:
	var hero := hero_at(target)
	if hero != null:
		var reduction := hero.character.shield_guard() + hero.character.armor_guard()
		if hero == knight and hero.prepared:
			reduction += 1 + hero.character.rank_of("guard")
			hero.prepared = false
		var damage := maxi(0, enemy.damage - reduction)
		hero.hp = maxi(0, hero.hp - damage)
		message = "%s blocked the hit." % hero.title if damage == 0 else "%s took %d melee damage." % [hero.title, damage]
	elif target == FIRE:
		fire_hp = maxi(0, fire_hp - enemy.damage)
		message = "A creature struck the campfire for %d damage." % enemy.damage
	elif is_structure(target):
		var piece: Dictionary = defenses[target]
		piece.hp -= enemy.damage
		if piece.hp <= 0:
			defenses.erase(target)
			message = "A creature destroyed the %s." % piece.kind.to_lower()
		else:
			message = "A creature dealt %d damage to the %s." % [enemy.damage, piece.kind.to_lower()]

func ballista_target(tile: Vector2i) -> Vector2i:
	var closest := NO_TILE
	var best := ballista_range(defenses[tile]) + 1
	for enemy: Enemy in enemies:
		for cell: Vector2i in footprint_at(enemy.tile, enemy.size):
			var gap := distance(tile, cell)
			if gap < best and has_sight(tile, cell):
				closest = cell
				best = gap
	return closest

func next_turn() -> void:
	if phase == Phase.ENEMY and not finish_if_lost() and not finish_wave_if_clear():
		turn += 1
		phase = Phase.PLAYER
		reset_actions()
