extends Node2D

const Night := preload("res://night.gd")
const Journey := preload("res://journey.gd")
const BoardArt := preload("res://board_art.gd")
const TERRAIN := [preload("res://art/pine.svg"), preload("res://art/stoneford.svg")]
enum Day { NIGHT, DAWN, MERCHANT, DUSK, COMPLETE }
const PORTRAITS := [preload("res://art/ranger.svg"), preload("res://art/knight.svg")]
const SHOP := ["war_bow", "longbow", "iron_sword", "reinforced_shield"]
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
var active: Night.Hero
var night_shade: ImageTexture
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
	night_shade = BoardArt.new().make_night_shade(Night.SIZE, Night.FIRE, CELL, Night.LIGHT_RADIUS)
	make_button("Wall", "Wall  [2]", Vector2(760, 470), 98, choose_build.bind("Wall"))
	make_button("Trap", "Trap  [1]", Vector2(868, 470), 98, choose_build.bind("Trap"))
	make_button("Ballista", "Ballista  [3]", Vector2(976, 470), 112, choose_build.bind("Ballista"))
	make_button("advance", "End Turn", Vector2(760, 531), 328, advance)
	make_button("restart", "Restart Journey", Vector2(760, 589), 328, restart)
	for i in 2:
		make_button("hero%d" % i, "", Vector2(754, 163 + i * 65), 323, select_hero.bind(i))
		var card: Button = buttons["hero%d" % i]
		card.flat = true
		card.size.y = 60
		card.tooltip_text = "Select %s and view their details." % night.heroes[i].title
	make_button("special", "", Vector2(760, 470), 152, prepare_special)
	make_button("pin", "Pinning Shot", Vector2(924, 470), 164, toggle_pin)
	for i in 3:
		make_button("upgrade%d" % i, "", Vector2(760, 350 + 56 * i), 328, choose_upgrade.bind(i))
	for i in 8:
		make_button("equip%d" % i, "Equip", Vector2(475, 200 + 45 * i), 95, equip.bind(i))
		make_button("sell%d" % i, "Sell", Vector2(580, 200 + 45 * i), 115, sell.bind(i))
	for i in SHOP.size():
		var id: String = SHOP[i]
		var item: Dictionary = Journey.GEAR[id]
		make_button("buy_" + id, "%s [%dg]" % [item.name, item.price],
			Vector2(754 + (i % 2) * 165, 429 + (i / 2) * 46), 158, buy.bind(id))
		buttons["buy_" + id].tooltip_text = Journey.item_stats(id)
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
	active = night.ranger
	selected_build = "Wall"
	pin_selected = false
	hit_until = 0.0
	night.start_wave()
	refresh()

func hero_to_upgrade() -> Night.Hero:
	if day == Day.NIGHT and night.phase in [Night.Phase.BUILD, Night.Phase.VICTORY]:
		for hero: Night.Hero in night.heroes:
			if not hero.character.level_choices().is_empty():
				return hero
	return null

func pending_upgrades() -> Array[String]:
	var hero := hero_to_upgrade()
	if hero == null:
		return []
	return hero.character.level_choices()

func refresh() -> void:
	if active.hp <= 0 and day == Day.NIGHT and night.phase == Night.Phase.PLAYER:
		for hero: Night.Hero in night.heroes:
			if hero.hp > 0:
				active = hero
				pin_selected = false
				break
	var leveling := hero_to_upgrade()
	if leveling != null:
		active = leveling
	reach = night.reach_for(active)
	update_intent(tile_at(get_local_mouse_position()))
	for button: Button in buttons.values():
		button.hide()
	buttons.advance.show()
	buttons.restart.show()
	buttons.restart.disabled = busy
	for i in 2:
		var card: Button = buttons["hero%d" % i]
		card.show()
		card.disabled = busy or leveling != null
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
			button.text = "%s\n%s" % [Journey.upgrade_name(upgrades[i], active.character.rank_of(upgrades[i]) + 1), info[1]]
			button.show()
		return

	var building := night.phase == Night.Phase.BUILD
	for kind: String in Night.BUILD_COST:
		var button: Button = buttons[kind]
		button.visible = building
		button.disabled = night.supplies < Night.BUILD_COST[kind]
		button.modulate = GOLD if kind == selected_build else Color.WHITE
	buttons.special.visible = night.phase == Night.Phase.PLAYER
	buttons.special.disabled = busy or not night.can_prepare(active)
	if active == night.ranger:
		buttons.special.text = "Overwatch Ready" if active.prepared else "Overwatch [1 AP]"
		buttons.special.tooltip_text = "Spend 1 AP and one bow attack. Fire once at a creature that moves within bow range this enemy phase."
	else:
		buttons.special.text = "Defend Ready" if active.prepared else "Defend [1 AP]"
		buttons.special.tooltip_text = "Spend 1 AP to reduce the next melee hit against the Knight by an additional %d." % (1 + active.character.rank_of("guard"))
	buttons.pin.visible = night.phase == Night.Phase.PLAYER and active == night.ranger and active.character.rank_of("pin") > 0
	buttons.pin.disabled = busy or active.ap == 0 or active.attacks == 0
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
		equip_button.text = "Equip"
		equip_button.disabled = not journey.can_equip(active.character, i)
		var equipped: String = active.character.equipment.get(Journey.GEAR[id].slot, "")
		if not equip_button.disabled:
			equip_button.tooltip_text = "%s: %s\nEquipped %s: %s" % [
				Journey.GEAR[id].name, Journey.item_stats(id), Journey.GEAR[equipped].name, Journey.item_stats(equipped)]
		else:
			equip_button.tooltip_text = "The %s cannot use this item or already has one equipped." % active.title
		equip_button.show()
		if journey.can_sell(i):
			var sell_button: Button = buttons["sell%d" % i]
			sell_button.text = "Sell  [%dg]" % journey.sell_price(id)
			sell_button.show()
	for id: String in SHOP:
		var button: Button = buttons["buy_" + id]
		button.visible = day == Day.MERCHANT and id in journey.stock
		button.disabled = journey.gold < Journey.GEAR[id].price

func choose_upgrade(index: int) -> void:
	var hero := hero_to_upgrade()
	if hero == null:
		return
	var choices := hero.character.level_choices()
	if index < 0 or index >= choices.size():
		return
	var previous_health := night.max_health(hero)
	var id := choices[index]
	if hero.character.upgrade(id):
		if hero.hp > 0:
			hero.hp += night.max_health(hero) - previous_health
		night.message = "%s learned %s." % [hero.title, Journey.upgrade_name(id, hero.character.rank_of(id))]
	refresh()

func select_hero(index: int) -> void:
	if busy or hero_to_upgrade() != null:
		return
	active = night.heroes[index]
	pin_selected = false
	refresh()

func prepare_special() -> void:
	if not busy and night.prepare(active):
		refresh()

func toggle_pin() -> void:
	pin_selected = not pin_selected
	refresh()

func equip(index: int) -> void:
	if journey.can_equip(active.character, index):
		var id := journey.inventory[index]
		journey.equip(active.character, index)
		day_message = "%s equipped %s." % [active.title, Journey.GEAR[id].name]
		refresh()

func buy(id: String) -> void:
	if journey.buy(id):
		day_message = "Bought %s. Equip it before dusk." % Journey.GEAR[id].name
		refresh()

func sell(index: int) -> void:
	if journey.can_sell(index):
		var id := journey.inventory[index]
		if journey.sell(index):
			day_message = "Sold %s." % Journey.GEAR[id].name
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
	intent_target = night.enemy_target(destination)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			get_viewport().set_input_as_handled()
			advance()
		KEY_1, KEY_2:
			if not busy:
				get_viewport().set_input_as_handled()
				select_hero(0 if event.keycode == KEY_1 else 1)

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
	var ally := night.hero_at(tile)
	if ally != null:
		select_hero(night.heroes.find(ally))
		return
	var enemy := night.enemy_at(tile)
	if enemy != null:
		if not night.can_attack(active, tile, pin_selected):
			night.message = "Attack needs 1 AP, an attack remaining, and a target at range %s." % weapon_range(active)
			return
		busy = true
		refresh()
		if active == night.ranger:
			await projectile(center(active.tile), center(tile), GOLD)
		else:
			flash(center(tile))
			await get_tree().create_timer(0.13).timeout
		night.attack(active, tile, pin_selected)
		pin_selected = false
	else:
		var old := active.tile
		var path := night.move_hero(active, tile)
		if path.is_empty():
			night.message = "Choose a highlighted tile within your remaining movement."
			return
		busy = true
		refresh()
		for step: Vector2i in path:
			await move_piece(active, old, step, 0.12)
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
				if night.can_overwatch(enemy):
					await projectile(center(night.ranger.tile), center(enemy.tile), TEAL)
					night.fire_overwatch(enemy)
					if not night.enemies.has(enemy):
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
	label_at(Vector2(752, 52), "FIRE %d/%d   •   SUPPLIES %d" % [night.fire_hp, Night.MAX_FIRE_HP, night.supplies], 20, GOLD)
	label_at(Vector2(752, 80), "WAVE %d/%d   •   TURN %02d" % [night.wave, night.spawns.size(), night.turn], 16, MUTED)
	draw_board()
	draw_sidebar()
	draw_effects()

func draw_board() -> void:
	var hovered := tile_at(get_local_mouse_position())
	var board_rect := Rect2(BOARD, Vector2(Night.SIZE) * CELL)
	draw_rect(board_rect.grow(3), Color("#5d5141"), false, 2)
	draw_texture_rect(TERRAIN[journey.site], board_rect, false)
	for tile: Vector2i in night.rocks:
		draw_rock(center(tile), posmod(tile.x * 5 + tile.y * 11, 6))
	if night.fire_hp > 0:
		draw_texture_rect(night_shade, board_rect, false)
	else:
		draw_rect(board_rect, Color(0.025, 0.044, 0.08, 0.76))
	for y in Night.SIZE.y:
		for x in Night.SIZE.x:
			draw_tile_overlay(Vector2i(x, y), hovered)
	for tile: Vector2i in night.loot:
		var at := center(tile) + Vector2(13, -13)
		polygon(at, [Vector2(-3, -5), Vector2(3, -5), Vector2(6, 1), Vector2(5, 6),
			Vector2(-5, 6), Vector2(-6, 1)], Color("#d5a15e"))
		draw_line(at + Vector2(-4, -2), at + Vector2(4, -2), Color("#483325"), 2, true)
		draw_line(at + Vector2(-2, -6), at + Vector2(2, -6), GOLD, 2, true)
	for tile: Vector2i in night.defenses:
		draw_defense(center(tile), night.defenses[tile].kind)
	draw_fire(center(Night.FIRE))
	for enemy: Night.Enemy in night.enemies:
		var at := motion_from.lerp(motion_to, motion_progress) if motion_actor is Night.Enemy and motion_actor == enemy else center(enemy.tile)
		draw_enemy(at, enemy.hp)
	for hero: Night.Hero in night.heroes:
		if hero.hp <= 0:
			continue
		var at := motion_from.lerp(motion_to, motion_progress) if motion_actor == hero else center(hero.tile)
		if hero == night.ranger:
			draw_ranger(at)
		else:
			draw_knight(at)
		if hero == active:
			draw_arc(at, 20, 0, TAU, 24, TEAL, 2, true)
		if hero.prepared:
			draw_circle(at + Vector2(15, -15), 4, GOLD)

func draw_rock(at: Vector2, variation: int) -> void:
	var x := float(variation) - 2.0
	draw_circle(at + Vector2(2, 4), 17, Color(0.10, 0.11, 0.10, 0.52))
	polygon(at, [Vector2(-18, 8), Vector2(-14, -8), Vector2(-4, -15 - x),
		Vector2(10, -12), Vector2(18, 3 + x), Vector2(12, 12), Vector2(-7, 14)], Color("#3f4946"))
	polygon(at, [Vector2(-15, 2), Vector2(-11, -7), Vector2(-4, -15 - x),
		Vector2(10, -12), Vector2(13, -2), Vector2(1, 4), Vector2(-7, -1)], Color("#929287"))
	polygon(at, [Vector2(-15, 2), Vector2(-7, -1), Vector2(1, 4), Vector2(-1, 10),
		Vector2(-11, 10)], Color("#6b715d"))
	draw_polyline(PackedVector2Array([at + Vector2(-11, -7), at + Vector2(-3, -8 - x),
		at + Vector2(2, -4), at + Vector2(7, -6)]), Color("#60695d"), 1.5, true)
	draw_line(at + Vector2(-15, 1), at + Vector2(-11, -7), Color("#b2aa89"), 1, true)

func draw_tile_overlay(tile: Vector2i, hovered: Vector2i) -> void:
	var rect := tile_rect(tile)
	var grid_color := Color(0.94, 0.78, 0.54, 0.26) if night.is_lit(tile) else Color(0.64, 0.72, 0.79, 0.14)
	draw_line(rect.position, rect.position + Vector2(CELL, 0), grid_color)
	draw_line(rect.position, rect.position + Vector2(0, CELL), grid_color)
	if not busy and tile != active.tile and reach.has(tile):
		draw_rect(rect.grow(-2), Color(0.34, 0.86, 0.72, 0.16))
		draw_rect(rect.grow(-3), Color(0.34, 0.86, 0.72, 0.45), false, 1.0)
	if tile in intent_path:
		draw_rect(rect.grow(-5), GOLD, false, 2)
	if tile == intent_target:
		draw_rect(rect.grow(-4), RED, false, 3)
	if tile == hovered:
		draw_rect(rect.grow(-2), PAPER, false, 2.0)
		var text_color := GOLD if night.is_lit(tile) else MUTED
		var light_status := "FIRELIGHT" if night.is_lit(tile) else "DARKNESS"
		label_at(Vector2(601, 123), light_status, 13, text_color)
		if night.phase == Night.Phase.PLAYER and not busy and night.enemy_at(tile) != null:
			var gap := night.distance(active.tile, tile)
			var valid := night.in_weapon_range(active, tile)
			var target_text := "%d tiles  •  %d damage" % [gap, night.attack_damage(active)] if valid else "%d tiles  •  Out of weapon range" % gap
			label_at(Vector2(34, 123), target_text, 13, TEAL if valid else RED)

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
	draw_arc(at, 16, 0, TAU, 24, Color("#517e70"), 1.2, true)
	var body := at + Vector2(0, sin(clock * 5.0) * 1.2)
	polygon(body, [Vector2(-10, 11), Vector2(-7, -4), Vector2(-2, -11), Vector2(6, -7),
		Vector2(10, 10), Vector2(0, 7)], Color("#4e9c80"))
	draw_circle(body + Vector2(0, -6), 4, Color("#d7b592"))
	draw_arc(body + Vector2(7, 2), 9, -1.0, 1.0, 12, GOLD, 2, true)
	draw_line(body + Vector2(12, -5), body + Vector2(12, 9), PAPER, 1, true)

func draw_knight(at: Vector2) -> void:
	draw_circle(at, 17, Color("#292d3d"))
	var body := at + Vector2(0, sin(clock * 4.0) * 1.1)
	polygon(body, [Vector2(-11, 10), Vector2(-8, -6), Vector2(7, -6), Vector2(11, 10)], Color("#8093a5"))
	draw_circle(body + Vector2(0, -8), 6, Color("#bcc2bc"))
	draw_line(body + Vector2(-4, -8), body + Vector2(4, -8), INK, 2, true)
	polygon(body, [Vector2(-11, -2), Vector2(-3, -2), Vector2(-3, 8),
		Vector2(-7, 12), Vector2(-11, 8)], Color("#b26c56"))
	draw_line(body + Vector2(9, 8), body + Vector2(13, -10), PAPER, 2, true)

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

func weapon_range(hero: Night.Hero) -> String:
	var minimum: int = hero.character.weapon().min
	var maximum := night.attack_range(hero)
	return str(maximum) if minimum == maximum else "%d–%d" % [minimum, maximum]

func draw_party() -> void:
	draw_rect(Rect2(743, 135, 345, 382), Color("#18242e"))
	label_at(Vector2(756, 154), "PARTY", 15, GOLD)
	for i in night.heroes.size():
		var hero := night.heroes[i]
		var row := Rect2(754, 163 + i * 65, 323, 60)
		draw_rect(row, Color("#263d3b") if active == hero else Color("#222d36"))
		draw_rect(row, TEAL if active == hero else Color("#40515c"), false, 1)
		draw_texture_rect(PORTRAITS[i], Rect2(row.position + Vector2(5, 5), Vector2(50, 50)), false)
		var hp := night.max_health(hero) if day != Day.NIGHT else hero.hp
		var hp_ratio := float(hp) / night.max_health(hero)
		label_at(row.position + Vector2(64, 22), "%d  %s   Lv. %d" % [i + 1, hero.title, hero.character.level], 17)
		label_at(row.position + Vector2(233, 22), "%d/%d HP" % [hp, night.max_health(hero)], 14, PAPER)
		draw_rect(Rect2(row.position + Vector2(64, 30), Vector2(249, 3)), Color("#101923"))
		draw_rect(Rect2(row.position + Vector2(64, 30), Vector2(249 * hp_ratio, 3)), TEAL if hp_ratio > 0.35 else RED)
		var move := hero.movement if day == Day.NIGHT else night.movement_limit(hero)
		var ap := hero.ap if day == Day.NIGHT else Night.MAX_AP
		var status := "Move %d   •   AP %d" % [move, ap] if hp > 0 else "Downed"
		label_at(row.position + Vector2(64, 51), status, 15, MUTED)
		if hero.prepared and day == Day.NIGHT:
			label_at(row.position + Vector2(229, 51), "Ready", 14, GOLD)

func draw_loadout() -> void:
	var character := active.character
	label_at(Vector2(756, 312), "%s   •   XP %d / %d" % [active.title, character.xp, character.xp_goal()], 17, TEAL)
	label_at(Vector2(756, 337), "%d damage   •   Range %s" % [night.attack_damage(active), weapon_range(active)], 17)
	var y := 365
	for slot: String in character.equipment:
		var id: String = character.equipment[slot]
		label_at(Vector2(756, y), "%s  /  %s" % [slot.capitalize(), Journey.GEAR[id].name], 16, PAPER)
		y += 23
	if character.shield_guard() > 0:
		label_at(Vector2(756, 413), "Shield −%d melee   •   Defend −%d extra" % [
			character.shield_guard(), 1 + character.rank_of("guard")], 14, MUTED)

func draw_sidebar() -> void:
	draw_party()
	if not pending_upgrades().is_empty():
		label_at(Vector2(756, 323), "%s LEVEL UP   /   CHOOSE ONE" % active.title.to_upper(), 18, GOLD)
	else:
		draw_loadout()
		match night.phase:
			Night.Phase.VICTORY:
				label_at(Vector2(756, 468), "DAWN BREAKS", 21, GOLD)
			Night.Phase.DEFEAT:
				label_at(Vector2(756, 468), "THE DARKNESS WINS", 21, RED)
			Night.Phase.BUILD:
				label_at(Vector2(756, 446), "Build on a free tile in firelight.", 16, GOLD)
			_:
				label_at(Vector2(756, 445), "Attacks %d/%d   •   Hover a foe for intent." % [
					active.attacks, night.attack_limit(active)], 15, MUTED)
	label_at(Vector2(32, 670), night.message, 17, PAPER)

func draw_day() -> void:
	var titles := ["", "DAWN  /  BREAK CAMP", "DAY  /  ROADSIDE TRADER",
		"DUSK  /  MAKE CAMP", "DAY  /  JOURNEY COMPLETE"]
	label_at(Vector2(34, 82), titles[day], 16, GOLD)
	label_at(Vector2(765, 75), "DAYLIGHT  /  SAFE TO EQUIP", 18, GOLD)
	draw_rect(Rect2(32, 135, 690, 498), Color("#202b30"))
	draw_party()
	draw_loadout()
	label_at(Vector2(51, 169), "CARAVAN STASH", 20, GOLD)
	label_at(Vector2(491, 169), "%d gold" % journey.gold, 20, GOLD)
	for i in journey.inventory.size():
		var id := journey.inventory[i]
		var y := 200 + 45 * i
		draw_line(Vector2(51, y), Vector2(459, y), Color("#43515b"))
		label_at(Vector2(51, y + 18), Journey.GEAR[id].name, 17)
		label_at(Vector2(51, y + 36), Journey.item_stats(id), 14, MUTED)
	if journey.inventory.is_empty():
		label_at(Vector2(51, 225), "The stash is empty. Equipped gear is shown in Party.", 16, MUTED)
	label_at(Vector2(51, 588), "Pine Hollow   →   Roadside trader   →   Stoneford", 18, GOLD)
	var route := ["", "Breaking camp at %s" % Journey.CAMPS[journey.site], "Trading on the road", "Arriving at Stoneford", "Both nights survived"]
	label_at(Vector2(51, 612), route[day], 15, MUTED)
	if day == Day.DAWN and not dawn_loot.is_empty():
		label_at(Vector2(756, 449), "Salvaged %d items and 4 gold." % dawn_loot.size(), 16, GOLD)
	elif day == Day.DUSK:
		label_at(Vector2(756, 449), "Both heroes recover before nightfall.", 16, GOLD)
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
