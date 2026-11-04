extends Node2D

const Night := preload("res://night.gd")
const CELL := 46
const BOARD := Vector2(32, 135)
const INK := Color("#101923")
const PAPER := Color("#ece0c1")
const MUTED := Color("#abb5bc")
const GOLD := Color("#f0b76d")
const TEAL := Color("#6bdbc0")
const RED := Color("#f18878")

var night := Night.new()
var selected_build := "Wall"
var buttons: Dictionary = {}
var reach: Dictionary = {}
var busy := false
var clock := 0.0
var motion_actor: Variant
var motion_from := Vector2.ZERO
var motion_to := Vector2.ZERO
var motion_progress := 1.0
var arrow_progress := 1.0
var arrow_from := Vector2.ZERO
var arrow_to := Vector2.ZERO
var arrow_color := GOLD
var hit_position := Vector2.ZERO
var hit_until := 0.0

func _ready() -> void:
	make_button("Wall", "Wall  [2]", Vector2(760, 470), 98, choose_build.bind("Wall"))
	make_button("Trap", "Trap  [1]", Vector2(868, 470), 98, choose_build.bind("Trap"))
	make_button("Ballista", "Ballista  [3]", Vector2(976, 470), 112, choose_build.bind("Ballista"))
	make_button("advance", "End Turn", Vector2(760, 531), 328, advance)
	make_button("restart", "Restart Night", Vector2(760, 589), 328, restart)
	restart()

func make_button(key: String, label: String, position_at: Vector2, width: int, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.position = position_at
	button.size = Vector2(width, 44)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(action)
	add_child(button)
	buttons[key] = button

func restart() -> void:
	night = Night.new()
	selected_build = "Wall"
	hit_until = 0.0
	night.start_wave()
	refresh()

func refresh() -> void:
	reach = night.ranger_reach()
	var building := night.phase == Night.Phase.BUILD
	for kind: String in Night.BUILD_COST:
		var button: Button = buttons[kind]
		button.visible = building
		button.disabled = busy or night.supplies < Night.BUILD_COST[kind]
		button.modulate = GOLD if kind == selected_build else Color.WHITE
	var advance_button: Button = buttons.advance
	advance_button.text = "Start Next Wave" if building else "End Turn  [Space]"
	advance_button.disabled = busy or not (building or night.phase == Night.Phase.PLAYER)
	buttons.restart.disabled = busy
	queue_redraw()

func choose_build(kind: String) -> void:
	selected_build = kind
	refresh()

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if not event.echo:
			advance()

func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var tile := tile_at(get_global_transform_with_canvas().affine_inverse() * event.position)
	if not night.on_board(tile):
		return
	match night.phase:
		Night.Phase.BUILD:
			if not night.build(selected_build, tile):
				night.message = "Choose a free lit tile and an affordable defense."
			refresh()
		Night.Phase.PLAYER:
			play_at(tile)

func play_at(tile: Vector2i) -> void:
	var enemy := night.enemy_at(tile)
	if enemy != null:
		if night.phase != Night.Phase.PLAYER or night.ap == 0 or night.distance(night.ranger, tile) > Night.RANGER_RANGE:
			night.message = "That shot needs 1 action point and a target within 5 tiles."
			return
		busy = true
		refresh()
		await projectile(center(night.ranger), center(tile), GOLD)
		night.shoot(tile)
	elif tile != night.ranger:
		var old := night.ranger
		if not night.move_ranger(tile):
			night.message = "Move once before shooting. Choose a teal tile."
			return
		busy = true
		refresh()
		await move_piece("ranger", old, tile, 0.22)
	busy = false
	refresh()

func advance() -> void:
	if busy:
		return
	if night.phase == Night.Phase.BUILD:
		night.start_wave()
		refresh()
		return
	if not night.begin_enemy_phase():
		return
	busy = true
	refresh()
	if night.phase != Night.Phase.DEFEAT:
		await resolve_ballistae()
		for enemy: Night.Enemy in night.enemies.duplicate():
			if night.phase == Night.Phase.DEFEAT:
				break
			var route := night.enemy_path(enemy)
			var stopped := false
			for i in range(mini(Night.ENEMY_MOVE, route.size())):
				var old := enemy.tile
				var next := route[i]
				if night.is_wall(next):
					flash(center(next))
					night.step_enemy(enemy, next)
					stopped = true
					await get_tree().create_timer(0.13).timeout
					break
				await move_piece(enemy, old, next, 0.11)
				if not night.step_enemy(enemy, next):
					flash(center(next))
					stopped = true
					break
			if not stopped:
				var target := night.attack_enemy_target(enemy)
				if night.on_board(target):
					flash(center(target))
					night.finish_if_lost()
					await get_tree().create_timer(0.14).timeout
	night.next_turn()
	busy = false
	refresh()

func resolve_ballistae() -> void:
	for tile: Vector2i in night.defenses:
		if night.defenses[tile].kind != "Ballista":
			continue
		var target := night.ballista_target(tile)
		if target == null:
			continue
		await projectile(center(tile), center(target.tile), TEAL)
		night.damage_enemy(target, 2)
		night.message = "A ballista dealt 2 damage."

func move_piece(actor: Variant, from: Vector2i, to: Vector2i, duration: float) -> void:
	motion_actor = actor
	motion_from = center(from)
	motion_to = center(to)
	motion_progress = 0.0
	await create_tween().tween_property(self, "motion_progress", 1.0, duration).finished
	motion_actor = null

func projectile(from: Vector2, to: Vector2, color: Color) -> void:
	arrow_from = from
	arrow_to = to
	arrow_color = color
	arrow_progress = 0.0
	await create_tween().tween_property(self, "arrow_progress", 1.0, 0.20).finished
	flash(to)

func flash(at: Vector2) -> void:
	hit_position = at
	hit_until = clock + 0.23

func tile_at(local_position: Vector2) -> Vector2i:
	var point := (local_position - BOARD) / CELL
	return Vector2i(floori(point.x), floori(point.y))

func center(tile: Vector2i) -> Vector2:
	return BOARD + Vector2(tile) * CELL + Vector2.ONE * CELL * 0.5

func tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(BOARD + Vector2(tile) * CELL, Vector2.ONE * CELL)

func label_at(at: Vector2, value: String, size: int, color: Color = PAPER) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1120, 700), Color("#0e1720"))
	draw_rect(Rect2(32, 108, 1056, 1), Color("#544c43"))
	label_at(Vector2(32, 53), "LOOT AND OMEN", 36, PAPER)
	label_at(Vector2(34, 82), "CARAVAN DEFENSE   /   THE FIRST NIGHT", 15, GOLD)
	label_at(Vector2(785, 75), "WAVE %d / %d     TURN %02d" % [night.wave, Night.SPAWNS.size(), night.turn], 20)
	draw_board()
	draw_sidebar()
	draw_effects()

func draw_board() -> void:
	var hovered := tile_at(get_local_mouse_position())
	for y in Night.SIZE.y:
		for x in Night.SIZE.x:
			var tile := Vector2i(x, y)
			draw_ground(tile, hovered)
	for tile: Vector2i in night.defenses:
		draw_defense(center(tile), night.defenses[tile].kind)
	draw_fire(center(Night.FIRE))
	for enemy: Night.Enemy in night.enemies:
		var at := motion_from.lerp(motion_to, motion_progress) if motion_actor is Night.Enemy and motion_actor == enemy else center(enemy.tile)
		draw_enemy(at, enemy.hp)
	var ranger_at := motion_from.lerp(motion_to, motion_progress) if motion_actor is String else center(night.ranger)
	draw_ranger(ranger_at)

func draw_ground(tile: Vector2i, hovered: Vector2i) -> void:
	var lit := night.is_lit(tile)
	var rect := tile_rect(tile)
	var grain := posmod(tile.x * 31 + tile.y * 17, 11)
	var shade := Color("#454137") if lit else Color("#172632")
	draw_rect(rect, shade.lightened(grain * 0.005))
	draw_rect(rect, Color("#766754") if lit else Color("#273947"), false, 1.0)
	for mark in 3:
		var offset := Vector2(5 + posmod(tile.x * 13 + mark * 12 + tile.y * 7, 35),
			5 + posmod(tile.y * 13 + mark * 7 + tile.x * 9, 34))
		draw_line(rect.position + offset, rect.position + offset + Vector2(3, -2),
			Color("#817263") if lit else Color("#31424a"), 1.0)
	if tile in Night.ROCKS:
		var at := center(tile)
		polygon(at, [Vector2(-17, 11), Vector2(-14, -6), Vector2(-5, -14),
			Vector2(10, -12), Vector2(17, 6), Vector2(10, 12)], Color("#566168"))
		draw_line(at + Vector2(-12, 5), at + Vector2(-4, -9), Color("#849096"), 2)
	if not busy and tile != night.ranger and reach.has(tile):
		draw_rect(rect.grow(-2), Color(0.34, 0.86, 0.72, 0.16))
		draw_rect(rect.grow(-3), Color(0.34, 0.86, 0.72, 0.45), false, 1.0)
	if tile == hovered:
		draw_rect(rect.grow(-2), PAPER, false, 2.0)

func polygon(at: Vector2, points: Array, color: Color) -> void:
	var vertices := PackedVector2Array()
	for point: Vector2 in points:
		vertices.append(at + point)
	draw_colored_polygon(vertices, color)

func draw_fire(at: Vector2) -> void:
	if night.fire_hp == 0:
		draw_circle(at, 15, Color("#222026"))
		draw_arc(at, 15, 0, TAU, 20, Color("#70695e"), 3, true)
		return
	for i in range(3, 0, -1):
		draw_circle(at, 10.0 + i * 7.0, Color(1.0, 0.57, 0.23, 0.06))
	draw_circle(at, 15, Color("#222026"))
	draw_arc(at, 15, 0, TAU, 20, Color("#ad9170"), 3, true)
	var sway := sin(clock * 8.0) * 3.0
	polygon(at, [Vector2(-10, 7), Vector2(-9, -4), Vector2(-4, 0),
		Vector2(sway, -15), Vector2(8, -4), Vector2(11, 6)], Color("#ed843c"))
	polygon(at, [Vector2(-5, 7), Vector2(sway, -8), Vector2(5, 0), Vector2(6, 7)], Color("#ffe0a0"))
	for i in 3:
		var rise := fposmod(clock * 18.0 + i * 9.0, 28.0)
		draw_circle(at + Vector2(sin(rise * 0.23 + i) * 6, -5 - rise), 1.5,
			Color(1.0, 0.75, 0.4, 1.0 - rise / 29.0))

func draw_ranger(at: Vector2) -> void:
	draw_circle(at, 18, Color("#122b29"))
	draw_arc(at, 17, 0, TAU, 24, TEAL, 1.6, true)
	var body := at + Vector2(0, sin(clock * 5.0) * 1.2)
	polygon(body, [Vector2(-10, 11), Vector2(-7, -4), Vector2(-2, -11), Vector2(6, -7),
		Vector2(10, 10), Vector2(0, 7)], Color("#4e9c80"))
	draw_circle(body + Vector2(0, -6), 4, Color("#d7b592"))
	draw_arc(body + Vector2(7, 2), 9, -1.0, 1.0, 12, GOLD, 2, true)
	draw_line(body + Vector2(12, -5), body + Vector2(12, 9), PAPER, 1, true)

func draw_enemy(at: Vector2, hp: int) -> void:
	draw_circle(at, 16, Color("#301e29"))
	draw_arc(at, 16, 0, TAU, 24, RED, 1.1, true)
	var body := at + Vector2(0, sin(clock * 7.0 + at.x) * 1.5)
	polygon(body, [Vector2(-13, 10), Vector2(-10, -6), Vector2(-6, -12), Vector2(0, -8),
		Vector2(7, -12), Vector2(10, -4), Vector2(13, 9), Vector2(5, 6), Vector2(-5, 8)], Color("#93616a"))
	draw_line(body + Vector2(-5, -3), body + Vector2(4, -2), Color("#ffe1a0"), 2, true)
	for i in hp:
		draw_rect(Rect2(at + Vector2(-hp * 3 + i * 6, 18), Vector2(4, 3)), RED)

func draw_defense(at: Vector2, kind: String) -> void:
	match kind:
		"Wall":
			for x in range(-12, 13, 6):
				polygon(at + Vector2(x, 0), [Vector2(-3, 10), Vector2(-3, -6), Vector2(0, -11),
					Vector2(3, -6), Vector2(3, 10)], Color("#b3845c"))
			draw_line(at + Vector2(-15, 4), at + Vector2(15, 4), INK, 2)
		"Trap":
			draw_arc(at, 10, 0, TAU, 16, GOLD, 2, true)
			draw_line(at + Vector2(-9, 8), at + Vector2(9, -8), GOLD, 2, true)
		"Ballista":
			draw_line(at + Vector2(-9, 12), at + Vector2(9, 12), GOLD, 3, true)
			draw_line(at + Vector2(0, 12), at + Vector2(0, -13), GOLD, 3, true)
			draw_arc(at + Vector2(0, 1), 12, PI, TAU, 18, TEAL, 2, true)

func draw_sidebar() -> void:
	draw_rect(Rect2(743, 135, 345, 382), Color("#18242e"))
	label_at(Vector2(760, 165), "THE CAMP", 17, GOLD)
	label_at(Vector2(760, 199), "Campfire     %d / %d" % [night.fire_hp, Night.MAX_FIRE_HP], 21)
	label_at(Vector2(760, 234), "Ranger        %d / %d" % [night.ranger_hp, Night.MAX_RANGER_HP], 21)
	label_at(Vector2(760, 269), "Actions       %d / %d" % [night.ap, Night.MAX_AP], 21)
	label_at(Vector2(760, 304), "Supplies     %d" % night.supplies, 21)
	draw_line(Vector2(760, 322), Vector2(1072, 322), Color("#43515b"))
	match night.phase:
		Night.Phase.VICTORY:
			label_at(Vector2(760, 359), "DAWN BREAKS", 25, GOLD)
			label_at(Vector2(760, 390), "The caravan survived all three waves.", 16, MUTED)
		Night.Phase.DEFEAT:
			label_at(Vector2(760, 359), "THE DARKNESS WINS", 23, RED)
			label_at(Vector2(760, 390), "Restart to try another defense.", 16, MUTED)
		Night.Phase.BUILD:
			label_at(Vector2(760, 359), "BETWEEN WAVES", 21, GOLD)
			label_at(Vector2(760, 387), "Select a defense, then a free lit tile.", 16, MUTED)
			label_at(Vector2(760, 413), "Wall blocks. Trap triggers once.", 16, MUTED)
			label_at(Vector2(760, 438), "Ballista fires each enemy phase.", 16, MUTED)
		_:
			label_at(Vector2(760, 359), "HOLD THE FIRE", 21, GOLD)
			label_at(Vector2(760, 387), "Click a teal tile to move up to 3.", 16, MUTED)
			label_at(Vector2(760, 413), "Click a foe within 5 tiles to shoot.", 16, MUTED)
			label_at(Vector2(760, 439), "End your turn in the light to stay safe.", 16, MUTED)
	label_at(Vector2(32, 670), night.message, 17, PAPER)

func draw_effects() -> void:
	if arrow_progress < 1.0:
		var tip := arrow_from.lerp(arrow_to, arrow_progress)
		var tail := arrow_from.lerp(arrow_to, maxf(0.0, arrow_progress - 0.15))
		draw_line(tail, tip, arrow_color, 3, true)
	if hit_until > clock:
		var remaining := (hit_until - clock) / 0.23
		draw_arc(hit_position, lerpf(24, 8, remaining), 0, TAU, 24,
			Color(1.0, 0.79, 0.48, remaining), 2.5, true)
