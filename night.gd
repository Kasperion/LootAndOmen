extends RefCounted

const Journey := preload("res://journey.gd")

enum Phase { PLAYER, ENEMY, BUILD, VICTORY, DEFEAT }

const SIZE := Vector2i(15, 11)
const FIRE := Vector2i(7, 5)
const LIGHT_RADIUS := 4
const DARK_DAMAGE := 1
const ENEMY_MOVE := 3
const ENEMY_RANGE := 1
const MAX_AP := 3
const MAX_FIRE_HP := 18
const SPAWNS := [
	[Vector2i(0, 2), Vector2i(14, 8)],
	[Vector2i(0, 2), Vector2i(14, 8), Vector2i(0, 8)],
	[Vector2i(0, 2), Vector2i(14, 8), Vector2i(0, 8), Vector2i(14, 2)],
]
const ROCKS := [Vector2i(2, 4), Vector2i(3, 4), Vector2i(3, 5), Vector2i(11, 5),
	Vector2i(11, 6), Vector2i(12, 6), Vector2i(6, 1), Vector2i(8, 9)]
const STONEFORD_ROCKS := [Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2),
	Vector2i(9, 4), Vector2i(10, 4), Vector2i(10, 5), Vector2i(10, 6), Vector2i(11, 6),
	Vector2i(3, 8), Vector2i(4, 8)]
const STONEFORD_SPAWNS := [
	[Vector2i(0, 5), Vector2i(14, 3)],
	[Vector2i(0, 5), Vector2i(14, 3), Vector2i(13, 10)],
	[Vector2i(0, 5), Vector2i(14, 3), Vector2i(13, 10), Vector2i(1, 0)],
]
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const BUILD_COST := {"Wall": 2, "Trap": 1, "Ballista": 3}

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
	var pinned := false
	var damage: int

	func _init(start: Vector2i, health: int, hit: int = 2) -> void:
		tile = start
		hp = health
		damage = hit

var phase := Phase.PLAYER
var wave := 0
var turn := 1
var journey: Journey
var ranger: Hero
var knight: Hero
var heroes: Array[Hero] = []
var fire_hp := MAX_FIRE_HP
var kills := 0
var loot: Dictionary = {}
var rocks: Array
var spawns: Array
var supplies := 0
var enemies: Array[Enemy] = []
var defenses: Dictionary = {}
var message := ""

func _init(run: Journey = null) -> void:
	journey = run if run != null else Journey.new()
	ranger = Hero.new(journey.ranger, FIRE + Vector2i.DOWN)
	knight = Hero.new(journey.knight, FIRE + Vector2i.UP)
	heroes.assign([ranger, knight])
	rocks = ROCKS if journey.site == 0 else STONEFORD_ROCKS
	spawns = SPAWNS if journey.site == 0 else STONEFORD_SPAWNS

func start_wave() -> void:
	if wave >= spawns.size() or (wave > 0 and phase != Phase.BUILD):
		return
	wave += 1
	turn = 1
	phase = Phase.PLAYER
	reset_actions()
	for tile: Vector2i in spawns[wave - 1]:
		enemies.append(Enemy.new(tile, 3 if wave == 3 else 2, 3 if wave == 3 else 2))
	message = "Wave %d approaches. Keep the fire alive." % wave

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
	return gap >= int(hero.character.weapon().min) and gap <= attack_range(hero)

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
	return distance(FIRE, tile) <= LIGHT_RADIUS

func on_board(tile: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, SIZE).has_point(tile)

func enemy_at(tile: Vector2i) -> Enemy:
	for enemy: Enemy in enemies:
		if enemy.tile == tile:
			return enemy
	return null

func is_wall(tile: Vector2i) -> bool:
	return defenses.has(tile) and defenses[tile].kind == "Wall"

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
			if reach.has(next) or not on_board(next) or next == FIRE or next in rocks:
				continue
			if is_wall(next) or enemy_at(next) != null or hero_at(next) != null:
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
	var attack_name := "Sword strike" if hero == knight else ("Pinning Shot" if pin else "Bow shot")
	message = "%s dealt %d damage." % [attack_name, damage]
	if enemy.hp <= 0:
		message += " %s earned 4 XP." % hero.title
	finish_wave_if_clear()
	return true

func can_prepare(hero: Hero) -> bool:
	return phase == Phase.PLAYER and hero.hp > 0 and hero.ap > 0 and not hero.prepared \
		and (hero == knight or hero.attacks > 0)

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
		and in_weapon_range(ranger, enemy.tile)

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
	if tile in rocks or defenses.has(tile):
		return false
	supplies -= BUILD_COST[kind]
	defenses[tile] = {"kind": kind, "hp": 3}
	message = "%s placed." % kind
	return true

func finish_wave_if_clear() -> bool:
	if phase not in [Phase.PLAYER, Phase.ENEMY] or not enemies.is_empty():
		return false
	for hero: Hero in heroes:
		hero.character.xp += 6
	if wave == spawns.size():
		phase = Phase.VICTORY
		message = "The caravan lives to see dawn. Both heroes gained 6 XP."
	else:
		phase = Phase.BUILD
		supplies += 4
		message = "Wave cleared. Both heroes gained 6 XP. The camp gained 4 supplies."
	return true

func finish_if_lost() -> bool:
	if fire_hp > 0 and (ranger.hp > 0 or knight.hp > 0):
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

func enemy_path(enemy: Enemy) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [enemy.tile]
	var previous := {enemy.tile: enemy.tile}
	var index := 0
	var closest := enemy.tile
	while index < frontier.size():
		var tile := frontier[index]
		index += 1
		if distance(tile, FIRE) < distance(closest, FIRE):
			closest = tile
		if distance(tile, FIRE) <= ENEMY_RANGE:
			closest = tile
			break
		for step: Vector2i in DIRECTIONS:
			var next := tile + step
			if previous.has(next) or not on_board(next) or next == FIRE or hero_at(next) != null:
				continue
			if next in rocks or enemy_at(next) != null:
				continue
			previous[next] = tile
			frontier.append(next)
	var path: Array[Vector2i] = []
	while closest != enemy.tile:
		path.push_front(closest)
		closest = previous[closest]
	return path

func enemy_movement(enemy: Enemy) -> int:
	return 1 if enemy.pinned else ENEMY_MOVE

func step_enemy(enemy: Enemy, tile: Vector2i) -> bool:
	if is_wall(tile):
		defenses[tile].hp -= 1
		if defenses[tile].hp <= 0:
			defenses.erase(tile)
		message = "A creature struck a wall."
		return false
	enemy.tile = tile
	if defenses.has(tile) and defenses[tile].kind == "Trap":
		defenses.erase(tile)
		damage_enemy(enemy, 3)
		message = "A creature triggered a trap."
	return enemies.has(enemy)

func enemy_target(from: Vector2i) -> Vector2i:
	# Knight intercepts a melee attack when both heroes are adjacent.
	for hero: Hero in [knight, ranger]:
		if hero.hp > 0 and distance(from, hero.tile) <= ENEMY_RANGE:
			return hero.tile
	if distance(from, FIRE) <= ENEMY_RANGE:
		return FIRE
	return Vector2i(-1, -1)

func attack_enemy_target(enemy: Enemy) -> Vector2i:
	var target := enemy_target(enemy.tile)
	var hero := hero_at(target)
	if hero != null:
		var reduction := hero.character.shield_guard()
		if hero == knight and hero.prepared:
			reduction += 1 + hero.character.rank_of("guard")
			hero.prepared = false
		var damage := maxi(0, enemy.damage - reduction)
		hero.hp = maxi(0, hero.hp - damage)
		message = "%s blocked the hit." % hero.title if damage == 0 else "%s took %d melee damage." % [hero.title, damage]
	elif target == FIRE:
		fire_hp = maxi(0, fire_hp - 2)
		message = "A creature struck the campfire."
	return target

func ballista_target(tile: Vector2i) -> Enemy:
	var closest: Enemy
	for enemy: Enemy in enemies:
		if distance(tile, enemy.tile) <= 4 and (closest == null or distance(tile, enemy.tile) < distance(tile, closest.tile)):
			closest = enemy
	return closest

func next_turn() -> void:
	if phase == Phase.ENEMY and not finish_if_lost() and not finish_wave_if_clear():
		turn += 1
		phase = Phase.PLAYER
		reset_actions()
