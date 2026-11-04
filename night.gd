extends RefCounted

enum Phase { PLAYER, ENEMY, BUILD, VICTORY, DEFEAT }

const SIZE := Vector2i(15, 11)
const FIRE := Vector2i(7, 5)
const LIGHT_RADIUS := 4
const DARK_DAMAGE := 1
const RANGER_MOVE := 3
const RANGER_RANGE := 5
const ENEMY_MOVE := 3
const ENEMY_RANGE := 1
const MAX_AP := 2
const MAX_RANGER_HP := 12
const MAX_FIRE_HP := 18
const SPAWNS := [
	[Vector2i(0, 2), Vector2i(14, 8)],
	[Vector2i(0, 2), Vector2i(14, 8), Vector2i(0, 8)],
	[Vector2i(0, 2), Vector2i(14, 8), Vector2i(0, 8), Vector2i(14, 2)],
]
const ROCKS := [Vector2i(2, 4), Vector2i(3, 4), Vector2i(3, 5), Vector2i(11, 5),
	Vector2i(11, 6), Vector2i(12, 6), Vector2i(6, 1), Vector2i(8, 9)]
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const BUILD_COST := {"Wall": 2, "Trap": 1, "Ballista": 3}

class Enemy:
	var tile: Vector2i
	var hp: int

	func _init(start: Vector2i, health: int) -> void:
		tile = start
		hp = health

var phase := Phase.PLAYER
var wave := 0
var turn := 1
var ranger := FIRE + Vector2i.DOWN
var ranger_hp := MAX_RANGER_HP
var fire_hp := MAX_FIRE_HP
var ap := MAX_AP
var moved := false
var supplies := 0
var enemies: Array[Enemy] = []
var defenses: Dictionary = {}
var message := ""

func start_wave() -> void:
	if wave >= SPAWNS.size() or (wave > 0 and phase != Phase.BUILD):
		return
	wave += 1
	turn = 1
	phase = Phase.PLAYER
	reset_actions()
	for tile: Vector2i in SPAWNS[wave - 1]:
		enemies.append(Enemy.new(tile, 3 if wave == 3 else 2))
	message = "Wave %d approaches. Keep the fire alive." % wave

func reset_actions() -> void:
	ap = MAX_AP
	moved = false

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

func ranger_reach() -> Dictionary:
	if phase != Phase.PLAYER or moved or ap < MAX_AP:
		return {}
	var reach := {ranger: 0}
	var frontier: Array[Vector2i] = [ranger]
	var index := 0
	while index < frontier.size():
		var tile := frontier[index]
		index += 1
		if reach[tile] == RANGER_MOVE:
			continue
		for step: Vector2i in DIRECTIONS:
			var next := tile + step
			if reach.has(next) or not on_board(next) or next == FIRE or next in ROCKS:
				continue
			if is_wall(next) or enemy_at(next) != null:
				continue
			reach[next] = reach[tile] + 1
			frontier.append(next)
	return reach

func move_ranger(tile: Vector2i) -> bool:
	if tile == ranger or not ranger_reach().has(tile):
		return false
	ranger = tile
	moved = true
	message = "Ranger moved." if is_lit(tile) else "In darkness. Return to the light next turn."
	return true

func shoot(tile: Vector2i) -> bool:
	var enemy := enemy_at(tile)
	if phase != Phase.PLAYER or enemy == null or ap == 0 or distance(ranger, tile) > RANGER_RANGE:
		return false
	ap -= 1
	damage_enemy(enemy, 2)
	message = "Bow shot dealt 2 damage."
	finish_wave_if_clear()
	return true

func damage_enemy(enemy: Enemy, amount: int) -> void:
	enemy.hp -= amount
	if enemy.hp <= 0:
		enemies.erase(enemy)

func build(kind: String, tile: Vector2i) -> bool:
	if phase != Phase.BUILD or not BUILD_COST.has(kind) or supplies < BUILD_COST[kind]:
		return false
	if not on_board(tile) or not is_lit(tile) or tile == FIRE or tile == ranger:
		return false
	if tile in ROCKS or defenses.has(tile):
		return false
	supplies -= BUILD_COST[kind]
	defenses[tile] = {"kind": kind, "hp": 3}
	message = "%s placed." % kind
	return true

func finish_wave_if_clear() -> bool:
	if not enemies.is_empty():
		return false
	if wave == SPAWNS.size():
		phase = Phase.VICTORY
		message = "The caravan lives to see dawn."
	else:
		phase = Phase.BUILD
		supplies += 4
		message = "Wave cleared. Gained 4 supplies. Build within the light."
	return true

func finish_if_lost() -> bool:
	if fire_hp > 0 and ranger_hp > 0:
		return false
	phase = Phase.DEFEAT
	message = "The fire went out." if fire_hp <= 0 else "The Ranger fell."
	return true

func begin_enemy_phase() -> bool:
	if phase != Phase.PLAYER:
		return false
	phase = Phase.ENEMY
	if not is_lit(ranger):
		ranger_hp = maxi(0, ranger_hp - DARK_DAMAGE)
		message = "Darkness dealt %d damage." % DARK_DAMAGE
	else:
		message = "The creatures are moving."
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
			if previous.has(next) or not on_board(next) or next == FIRE or next == ranger:
				continue
			if next in ROCKS or enemy_at(next) != null:
				continue
			previous[next] = tile
			frontier.append(next)
	var path: Array[Vector2i] = []
	while closest != enemy.tile:
		path.push_front(closest)
		closest = previous[closest]
	return path

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

func attack_enemy_target(enemy: Enemy) -> Vector2i:
	if distance(enemy.tile, ranger) <= ENEMY_RANGE:
		ranger_hp = maxi(0, ranger_hp - 1)
		message = "A creature hit the Ranger."
		return ranger
	if distance(enemy.tile, FIRE) <= ENEMY_RANGE:
		fire_hp = maxi(0, fire_hp - 2)
		message = "A creature struck the campfire."
		return FIRE
	return Vector2i(-1, -1)

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
