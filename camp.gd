extends Node2D

const Night := preload("res://night.gd")
const Journey := preload("res://journey.gd")
enum Day { NIGHT, DAWN, MERCHANT, DUSK, COMPLETE }
const CELL := 46
const BOARD := Vector2(32, 135)
const INK := Color("#101923")
const PAPER := Color("#ece0c1")
const MUTED := Color("#abb5bc")
const GOLD := Color("#f0b76d")
const TEAL := Color("#6bdbc0")
const RED := Color("#f18878")

var journey := Journey.new()
var night := Night.new(journey)
var day := Day.NIGHT
var dawn_loot: Array[String] = []
var day_message := ""
var pin_selected := false
var intent_tile := Vector2i(-1, -1)
var intent_path: Array[Vector2i] = []
var intent_target := Vector2i(-1, -1)
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
	make_button("restart", "Restart Journey", Vector2(760, 589), 328, restart)
	make_button("brace", "Brace  [1 AP]", Vector2(760, 470), 152, brace)
	make_button("pin", "Pinning Shot", Vector2(924, 470), 164, toggle_pin)
	for i in 3:
		make_button("upgrade%d" % i, "", Vector2(760, 350 + 56 * i), 328, choose_upgrade.bind(i))
	for i in 8:
		make_button("equip%d" % i, "Equip", Vector2(475, 200 + 45 * i), 95, equip.bind(i))
		make_button("sell%d" % i, "Sell", Vector2(580, 200 + 45 * i), 115, sell.bind(i))
	make_button("buy_bow", "Buy War Bow  [8g]", Vector2(760, 365), 328, buy.bind("war_bow"))
	make_button("buy_armor", "Buy Hide Armor  [7g]", Vector2(760, 423), 328, buy.bind("hide_armor"))
	restart()

func make_button(key: String, label: String, position_at: Vector2, width: int, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.position = position_at
	button.size = Vector2(width, 44)
	button.add_theme_font_size_override("font_size", 17)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	add_child(button)
	buttons[key] = button

func restart() -> void:
	journey = Journey.new()
	day = Day.NIGHT
	begin_night()

func begin_night() -> void:
	night = Night.new(journey)
	selected_build = "Wall"
	pin_selected = false
	hit_until = 0.0
	night.start_wave()
	refresh()

func pending_upgrades() -> Array[String]:
	if day == Day.NIGHT and night.phase in [Night.Phase.BUILD, Night.Phase.VICTORY]:
		return journey.level_choices()
	return []

func refresh() -> void:
	reach = night.ranger_reach()
	update_intent(tile_at(get_local_mouse_position()))
	for button: Button in buttons.values():
		button.hide()
	buttons.advance.show()
	buttons.restart.show()
	buttons.restart.disabled = busy
	buttons.advance.disabled = busy
	if day != Day.NIGHT:
		refresh_day()
		return

	var upgrades := pending_upgrades()
	if not upgrades.is_empty():
		buttons.advance.hide()
		for i in upgrades.size():
			var info: Array = Journey.UPGRADES[upgrades[i]]
			var button: Button = buttons["upgrade%d" % i]
			button.text = "%s\n%s" % [info[0], info[1]]
			button.show()
		return

	var building := night.phase == Night.Phase.BUILD
	for kind: String in Night.BUILD_COST:
		var button: Button = buttons[kind]
		button.visible = building
		button.disabled = night.supplies < Night.BUILD_COST[kind]
		button.modulate = GOLD if kind == selected_build else Color.WHITE
	buttons.brace.visible = night.phase == Night.Phase.PLAYER
	buttons.brace.disabled = busy or night.ap == 0 or night.braced
	buttons.pin.visible = night.phase == Night.Phase.PLAYER and journey.has_pin
	buttons.pin.disabled = busy or night.ap == 0 or night.attacks == 0
	buttons.pin.modulate = GOLD if pin_selected else Color.WHITE
	if building:
		buttons.advance.text = "Start Next Wave"
	elif night.phase == Night.Phase.VICTORY:
		buttons.advance.text = "Break Camp at Dawn"
	else:
		buttons.advance.text = "End Turn  [Space]"
		buttons.advance.disabled = busy or night.phase != Night.Phase.PLAYER

func refresh_day() -> void:
	buttons.advance.text = ["", "Follow the Road", "Continue to Stoneford",
		"Set Up Camp at Dusk", "Journey Complete"][day]
	if day == Day.DAWN and journey.site == 1:
		buttons.advance.text = "Finish the Journey"
	buttons.advance.disabled = day == Day.COMPLETE
	for i in journey.inventory.size():
		var id := journey.inventory[i]
		var equip_button: Button = buttons["equip%d" % i]
		equip_button.text = "Equipped" if journey.is_equipped(id) else "Equip"
		equip_button.disabled = journey.is_equipped(id)
		equip_button.show()
		if journey.can_sell(i):
			var sell_button: Button = buttons["sell%d" % i]
			sell_button.text = "Sell  [%dg]" % journey.sell_price(id)
			sell_button.show()
	for id: String in ["war_bow", "hide_armor"]:
		var button: Button = buttons.buy_bow if id == "war_bow" else buttons.buy_armor
		button.visible = day == Day.MERCHANT and id in journey.stock
		button.disabled = journey.gold < Journey.GEAR[id][6]

func choose_upgrade(index: int) -> void:
	var choices := pending_upgrades()
	if index >= choices.size():
		return
	var previous_health := journey.max_health()
	if journey.upgrade(choices[index]):
		night.ranger_hp += journey.max_health() - previous_health
		night.message = "Learned %s." % Journey.UPGRADES[choices[index]][0]
	refresh()

func brace() -> void:
	if not busy and night.brace():
		refresh()

func toggle_pin() -> void:
	pin_selected = not pin_selected
	refresh()

func equip(index: int) -> void:
	if journey.equip(index):
		day_message = "Equipped %s." % Journey.GEAR[journey.inventory[index]][0]
		refresh()

func buy(id: String) -> void:
	if journey.buy(id):
		day_message = "Bought %s. Equip it before dusk." % Journey.GEAR[id][0]
		refresh()

func sell(index: int) -> void:
	if journey.can_sell(index):
		var id := journey.inventory[index]
		if journey.sell(index):
			day_message = "Sold %s." % Journey.GEAR[id][0]
			refresh()

func advance_day() -> void:
	match day:
		Day.DAWN:
			if journey.site == 0:
				day = Day.MERCHANT
				journey.trading = true
				day_message = "The caravan reaches a roadside trader."
			else:
				day = Day.COMPLETE
				day_message = "Both nights survived. The caravan travels onward."
		Day.MERCHANT:
			journey.trading = false
			day = Day.DUSK
			day_message = "The road reaches Stoneford as the light fades."
		Day.DUSK:
			journey.daylight = false
			journey.site += 1
			day = Day.NIGHT
			begin_night()
	refresh()

func choose_build(kind: String) -> void:
	selected_build = kind
	refresh()

func _process(delta: float) -> void:
	clock += delta
	var hovered := tile_at(get_local_mouse_position())
	if hovered != intent_tile:
		update_intent(hovered)
	queue_redraw()

func update_intent(tile: Vector2i) -> void:
	intent_tile = tile
	intent_path.clear()
	intent_target = Vector2i(-1, -1)
	if day != Day.NIGHT or busy or night.phase != Night.Phase.PLAYER:
		return
	var enemy := night.enemy_at(tile)
	if enemy == null:
		return
	var route := night.enemy_path(enemy)
	var destination := enemy.tile
	for i in mini(route.size(), night.enemy_movement(enemy)):
		var step := route[i]
		intent_path.append(step)
		if night.is_wall(step):
			intent_target = step
			return
		if night.defenses.has(step) and night.defenses[step].kind == "Trap" and enemy.hp <= 3:
			return
		destination = step
	if night.distance(destination, night.ranger) <= Night.ENEMY_RANGE:
		intent_target = night.ranger
	elif night.distance(destination, Night.FIRE) <= Night.ENEMY_RANGE:
		intent_target = Night.FIRE

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if not event.echo:
			advance()

func _unhandled_input(event: InputEvent) -> void:
	if busy or day != Day.NIGHT or not pending_upgrades().is_empty():
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
		if not night.can_shoot(tile, pin_selected):
			night.message = "A shot needs 1 AP, a bow attack, and a target within %d tiles." % journey.bow_range()
			return
		busy = true
		refresh()
		await projectile(center(night.ranger), center(tile), GOLD)
		night.shoot(tile, pin_selected)
		pin_selected = false
	elif tile != night.ranger:
		var old := night.ranger
		var path := night.move_ranger(tile)
		if path.is_empty():
			night.message = "Choose a teal tile within your remaining movement."
			return
		busy = true
		refresh()
		for step: Vector2i in path:
			await move_piece("ranger", old, step, 0.12)
			old = step
	busy = false
	refresh()

func advance() -> void:
	if busy or not pending_upgrades().is_empty():
		return
	if day != Day.NIGHT:
		advance_day()
		return
	if night.phase == Night.Phase.VICTORY:
		dawn_loot = night.collect_loot()
		day = Day.DAWN
		day_message = "The creatures retreat as the sun rises."
		refresh()
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
			var steps := night.enemy_movement(enemy)
			enemy.pinned = false
			for i in range(mini(steps, route.size())):
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
	pin_selected = false
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
	draw_rect(Rect2(0, 0, 1120, 700), Color("#0e1720") if day == Day.NIGHT else Color("#302b24"))
	draw_rect(Rect2(32, 108, 1056, 1), Color("#544c43"))
	label_at(Vector2(32, 53), "LOOT AND OMEN", 36, PAPER)
	if day != Day.NIGHT:
		draw_day()
		return
	label_at(Vector2(34, 82), "NIGHT %d  /  %s" % [journey.site + 1, Journey.CAMPS[journey.site]], 15, GOLD)
	label_at(Vector2(785, 75), "WAVE %d / %d     TURN %02d" % [night.wave, night.spawns.size(), night.turn], 20)
	draw_board()
	draw_sidebar()
	draw_effects()

func draw_board() -> void:
	var hovered := tile_at(get_local_mouse_position())
	for y in Night.SIZE.y:
		for x in Night.SIZE.x:
			var tile := Vector2i(x, y)
			draw_ground(tile, hovered)
	for tile: Vector2i in night.loot:
		var at := center(tile) + Vector2(13, -13)
		polygon(at, [Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)], GOLD)
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
	if journey.site == 1:
		shade = Color("#4b4642") if lit else Color("#232638")
	draw_rect(rect, shade.lightened(grain * 0.005))
	draw_rect(rect, Color("#766754") if lit else Color("#273947"), false, 1.0)
	for mark in 3:
		var offset := Vector2(5 + posmod(tile.x * 13 + mark * 12 + tile.y * 7, 35),
			5 + posmod(tile.y * 13 + mark * 7 + tile.x * 9, 34))
		draw_line(rect.position + offset, rect.position + offset + Vector2(3, -2),
			Color("#817263") if lit else Color("#31424a"), 1.0)
	if tile in night.rocks:
		var at := center(tile)
		polygon(at, [Vector2(-17, 11), Vector2(-14, -6), Vector2(-5, -14),
			Vector2(10, -12), Vector2(17, 6), Vector2(10, 12)], Color("#566168"))
		draw_line(at + Vector2(-12, 5), at + Vector2(-4, -9), Color("#849096"), 2)
	if not busy and tile != night.ranger and reach.has(tile):
		draw_rect(rect.grow(-2), Color(0.34, 0.86, 0.72, 0.16))
		draw_rect(rect.grow(-3), Color(0.34, 0.86, 0.72, 0.45), false, 1.0)
	if tile in intent_path:
		draw_rect(rect.grow(-5), GOLD, false, 2)
	if tile == intent_target:
		draw_rect(rect.grow(-4), RED, false, 3)
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
	label_at(Vector2(760, 163), "RANGER  /  LEVEL %d  /  XP %d of %d" % [journey.level, journey.xp, journey.xp_goal()], 17, GOLD)
	label_at(Vector2(760, 196), "Campfire  %d/%d     Ranger  %d/%d" % [night.fire_hp, Night.MAX_FIRE_HP, night.ranger_hp, journey.max_health()], 19)
	label_at(Vector2(760, 228), "Move  %d/%d     Actions  %d/%d" % [night.movement, Night.RANGER_MOVE + journey.move_bonus, night.ap, Night.MAX_AP], 19)
	label_at(Vector2(760, 260), "Bow attacks  %d/%d     Range  %d" % [night.attacks, Night.MAX_ATTACKS, journey.bow_range()], 19)
	label_at(Vector2(760, 292), "Supplies  %d" % night.supplies, 19)
	draw_line(Vector2(760, 309), Vector2(1072, 309), Color("#43515b"))
	if not pending_upgrades().is_empty():
		label_at(Vector2(760, 337), "LEVEL UP   /   CHOOSE ONE", 18, GOLD)
	else:
		match night.phase:
			Night.Phase.VICTORY:
				label_at(Vector2(760, 359), "DAWN BREAKS", 25, GOLD)
				label_at(Vector2(760, 390), "The caravan survived the night.", 16, MUTED)
			Night.Phase.DEFEAT:
				label_at(Vector2(760, 359), "THE DARKNESS WINS", 23, RED)
				label_at(Vector2(760, 390), "Restart to try another defense.", 16, MUTED)
			Night.Phase.BUILD:
				label_at(Vector2(760, 350), "BETWEEN WAVES", 21, GOLD)
				label_at(Vector2(760, 378), "Select a defense, then a free lit tile.", 16, MUTED)
				label_at(Vector2(760, 404), "Wall blocks. Trap triggers once.", 16, MUTED)
				label_at(Vector2(760, 430), "Ballista fires each enemy phase.", 16, MUTED)
			_:
				label_at(Vector2(760, 350), "HOLD THE FIRE", 21, GOLD)
				label_at(Vector2(760, 378), "Click teal to move, or a foe to shoot.", 16, MUTED)
				label_at(Vector2(760, 404), "Hover foes for a route and target preview.", 16, MUTED)
				label_at(Vector2(760, 430), "Stay in the light when you end the turn.", 16, MUTED)
	label_at(Vector2(32, 670), night.message, 17, PAPER)

func draw_day() -> void:
	var titles := ["", "DAWN  /  BREAK CAMP", "DAY  /  ROADSIDE TRADER",
		"DUSK  /  MAKE CAMP", "DAY  /  JOURNEY COMPLETE"]
	label_at(Vector2(34, 82), titles[day], 16, GOLD)
	label_at(Vector2(785, 75), "DAYLIGHT  /  SAFE TO EQUIP", 18, GOLD)
	draw_rect(Rect2(32, 135, 690, 498), Color("#202b30"))
	draw_rect(Rect2(743, 135, 345, 382), Color("#282c2b"))
	label_at(Vector2(51, 169), "CARAVAN INVENTORY", 20, GOLD)
	label_at(Vector2(491, 169), "%d gold" % journey.gold, 20, GOLD)
	for i in journey.inventory.size():
		var item: Array = Journey.GEAR[journey.inventory[i]]
		var y := 200 + 45 * i
		draw_line(Vector2(51, y), Vector2(459, y), Color("#43515b"))
		label_at(Vector2(51, y + 22), "%s  /  %s" % [item[0], item[2]], 17)
	label_at(Vector2(51, 597), "Bow range %d    Shot damage %d    Max HP %d" % [
		journey.bow_range(), journey.shot_damage(), journey.max_health()], 18, TEAL)
	label_at(Vector2(760, 166), "THE CARAVAN ROAD", 20, GOLD)
	var stops := ["Pine Hollow", "Roadside trader", "Stoneford"]
	var current := journey.site * 2 if day == Day.DAWN else (1 if day == Day.MERCHANT else 2)
	for i in stops.size():
		var at := Vector2(775, 208 + i * 44)
		if i < stops.size() - 1:
			draw_line(at, at + Vector2(0, 44), Color("#70695e"), 2)
		draw_circle(at, 7 if i == current else 4, GOLD if i == current else MUTED)
		label_at(at + Vector2(17, 6), stops[i], 17, GOLD if i == current else PAPER)
	if day == Day.MERCHANT:
		label_at(Vector2(760, 334), "War Bow +1 damage    Hide Armor +4 HP", 16, MUTED)
		label_at(Vector2(760, 488), "Sell unequipped gear from your inventory.", 15, MUTED)
	elif day == Day.DAWN:
		label_at(Vector2(760, 334), "SALVAGED AT DAWN", 17, GOLD)
		for i in dawn_loot.size():
			label_at(Vector2(760, 365 + i * 24), Journey.GEAR[dawn_loot[i]][0], 17)
		label_at(Vector2(760, 427), "Recovered 4 gold. Restored HP by dusk.", 15, MUTED)
	elif day == Day.DUSK:
		label_at(Vector2(760, 351), "The Ranger rests before nightfall.", 16, MUTED)
		label_at(Vector2(760, 381), "New ground. New approaches.", 16, MUTED)
	label_at(Vector2(32, 670), day_message, 17, PAPER)

func draw_effects() -> void:
	if arrow_progress < 1.0:
		var tip := arrow_from.lerp(arrow_to, arrow_progress)
		var tail := arrow_from.lerp(arrow_to, maxf(0.0, arrow_progress - 0.15))
		draw_line(tail, tip, arrow_color, 3, true)
	if hit_until > clock:
		var remaining := (hit_until - clock) / 0.23
		draw_arc(hit_position, lerpf(24, 8, remaining), 0, TAU, 24,
			Color(1.0, 0.79, 0.48, remaining), 2.5, true)
