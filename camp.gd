extends Node2D

const Night := preload("res://night.gd")
const Journey := preload("res://journey.gd")
const CampAudio := preload("res://camp_audio.gd")
const BoardArt := preload("res://board_art.gd")
const TERRAIN := [preload("res://art/pine.svg"), preload("res://art/stoneford.svg")]
enum Day { NIGHT, DAWN, MERCHANT, DUSK, COMPLETE, ROAD }
const TRAVEL_DURATION := 7.0
const STASH_PAGE_SIZE := 7
const ITEM_ATLAS := preload("res://art/heavy_ink/items.svg")
enum Menu { CLOSED, MAIN, SETTINGS, RESTART }
const SHOP := ["war_bow", "longbow", "iron_sword", "reinforced_shield"]
const CELL := 58
const BOARD := Vector2.ZERO
const VIEW := Vector2(1280, 720)
const SPRITES := {
	"merchant": preload("res://art/heavy_ink/merchant.webp"),
	"road": preload("res://art/heavy_ink/road.webp"),
	"wagon": preload("res://art/heavy_ink/wagon.png"),
	"horse_0": preload("res://art/heavy_ink/horse_0.png"),
	"horse_1": preload("res://art/heavy_ink/horse_1.png"),
	"horse_2": preload("res://art/heavy_ink/horse_2.png"),
	"fire_0": preload("res://art/heavy_ink/fire_0.png"),
	"fire_1": preload("res://art/heavy_ink/fire_1.png"),
	"fire_2": preload("res://art/heavy_ink/fire_2.png"),
	"loot_bag": preload("res://art/heavy_ink/loot_bag.png"),
	"priest_cast_low": preload("res://art/heavy_ink/priest_cast_low.png"),
	"priest_cast_high": preload("res://art/heavy_ink/priest_cast_high.png"),
	"knight_guard": preload("res://art/heavy_ink/knight_guard.png"),
	"ranger_watch": preload("res://art/heavy_ink/ranger_watch.png"),
	"stake_1": preload("res://art/heavy_ink/stake_1.png"),
	"stake_2": preload("res://art/heavy_ink/stake_2.png"),
	"stake_3": preload("res://art/heavy_ink/stake_3.png"),
	"stake_4": preload("res://art/heavy_ink/stake_4.png"),
	"husk": preload("res://art/heavy_ink/husk.png"),
	"skitter": preload("res://art/heavy_ink/skitter.png"),
	"brute": preload("res://art/heavy_ink/brute.png"),
	"boss": preload("res://art/heavy_ink/boss.png"),
	"ranger": preload("res://art/heavy_ink/ranger.png"),
	"knight": preload("res://art/heavy_ink/knight.png"),
	"priest": preload("res://art/heavy_ink/priest.png"),
	"rock": preload("res://art/heavy_ink/rock.png"),
	"tree": preload("res://art/heavy_ink/tree.png"),
	"rock_split": preload("res://art/heavy_ink/rock_split.svg"),
	"rock_slab": preload("res://art/heavy_ink/rock_slab.svg"),
	"dirt": preload("res://art/heavy_ink/dirt.png"),
	"grass": preload("res://art/heavy_ink/grass.png"),
	"trail": preload("res://art/heavy_ink/trail.png"),
	"embers": preload("res://art/heavy_ink/embers.png"),
	"campfire": preload("res://art/heavy_ink/campfire.png"),
	"wheel": preload("res://art/heavy_ink/wheel.png"),
	"ballista_1": preload("res://art/heavy_ink/ballista_1.png"),
	"ballista_2": preload("res://art/heavy_ink/ballista_2.png"),
	"ballista_3": preload("res://art/heavy_ink/ballista_3.png"),
}
const HEAL_ICON := preload("res://art/heavy_ink/heal.svg")
const HUD := Color(0.071, 0.107, 0.13, 0.88)
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
var travel_elapsed := 0.0
var stash_page := 0
var dusk_equipment := false
var menu := Menu.CLOSED
var audio := CampAudio.new()
var sliders: Dictionary = {}
var inspected_defense := Night.NO_TILE
var camera_zoom := 1.05
var camera_offset := Vector2.ZERO
var pointer_button := 0
var pointer_origin := Vector2.ZERO
var pointer_last := Vector2.ZERO
var dragging := false
var attack_actor: Variant
var firing_tile := Night.NO_TILE
var animation_frames: Dictionary = {}
var outlines: Dictionary = {}
var damaged_tile := Night.NO_TILE
var fallen_defenses: Dictionary = {}
var attack_offset := Vector2.ZERO
var attack_progress := 0.0
var hit_actor: Night.Enemy
var dawn_loot: Array[String] = []
var day_message := ""
var pin_selected := false
var heal_selected := false
var ready_at: Dictionary = {}
var shield_impact_until := 0.0
var heal_cast_until := 0.0
var blessing_tile := Night.NO_TILE
var blessing_until := 0.0
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
	for key in ["ranger", "knight", "priest", "husk", "skitter", "brute", "boss"]:
		var frames: Array[Texture2D] = []
		for pose in ["walk_a", "walk_b", "attack", "hit", "down"]:
			var path := "res://art/heavy_ink/%s_%s.png" % [key, pose]
			frames.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
		animation_frames[key] = frames
	add_child(audio)
	night_shade = BoardArt.new().make_night_shade(Night.SIZE, Night.FIRE, CELL, Night.LIGHT_RADIUS)
	make_button("Wall", "Wall  [2]", Vector2(935, 470), 152, choose_build.bind("Wall"))
	make_button("Ballista", "Ballista  [3]", Vector2(1099, 470), 164, choose_build.bind("Ballista"))
	make_button("advance", "End Turn", Vector2(935, 646), 328, advance)
	make_button("menu", "Menu", Vector2(1157, 3), 106, toggle_menu)
	buttons.menu.size.y = 36
	make_button("settings", "Settings", Vector2(935, 114), 328, set_menu.bind(Menu.SETTINGS))
	make_button("restart", "Restart Journey", Vector2(935, 169), 328, set_menu.bind(Menu.RESTART))
	make_button("exit", "Exit Game", Vector2(935, 224), 328, exit_game)
	make_button("back", "Back", Vector2(935, 452), 328, set_menu.bind(Menu.MAIN))
	make_button("restart_confirm", "Restart Journey", Vector2(935, 170), 328, restart)
	make_button("music", "Music", Vector2(935, 344), 328, toggle_music)
	make_button("fullscreen", "Fullscreen", Vector2(935, 398), 328, toggle_fullscreen)
	for i in 3:
		var key: String = ["master", "sfx", "ambience_level"][i]
		var slider := HSlider.new()
		slider.position = Vector2(935, 142 + i * 65)
		slider.size.x = 328
		slider.max_value = 100
		slider.step = 1
		slider.value_changed.connect(change_volume.bind(key))
		add_child(slider)
		sliders[key] = slider
	for i in 3:
		var action: String = ["Upgrade", "Repair", "Destroy"][i]
		make_button("manage_" + action, action, Vector2(935 + i * 110, 425), 104, manage_defense.bind(action))
	make_button("defense_close", "×", Vector2.ZERO, 29, close_defense)
	buttons.defense_close.size = Vector2(29, 29)
	for i in 3:
		make_button("hero%d" % i, "", Vector2(929, 74 + i * 65), 323, select_hero.bind(i))
		var card: Button = buttons["hero%d" % i]
		card.flat = true
		card.size.y = 60
		card.tooltip_text = "Select %s and view their details." % night.heroes[i].title
	make_button("special", "", Vector2(935, 470), 152, prepare_special)
	make_button("revive", "", Vector2(1099, 470), 164, revive_nearby)
	make_button("pin", "Pinning Shot", Vector2(1099, 470), 164, toggle_pin)
	for i in 3:
		make_button("upgrade%d" % i, "", Vector2(932, 341 + 62 * i), 318, choose_upgrade.bind(i))
		var choice: Button = buttons["upgrade%d" % i]
		choice.size.y = 54
		choice.add_theme_font_size_override("font_size", 15)
	for i in STASH_PAGE_SIZE:
		make_button("equip%d" % i, "Equip", Vector2(695, 258 + 49 * i), 80, equip_visible.bind(i))
		make_button("sell%d" % i, "Sell", Vector2(784, 258 + 49 * i), 102, sell_visible.bind(i))
	make_button("dusk_equipment", "Manage Equipment", Vector2(935, 590), 328, toggle_dusk_equipment)
	make_button("stash_prev", "Previous", Vector2(451, 611), 100, page_stash.bind(-1))
	make_button("stash_next", "Next", Vector2(786, 611), 100, page_stash.bind(1))
	for i in SHOP.size():
		var id: String = SHOP[i]
		var item: Dictionary = Journey.GEAR[id]
		make_button("buy_" + id, "Buy [%dg]" % item.price,
			Vector2(322, 258 + i * 49), 101, buy.bind(id))
		buttons["buy_" + id].tooltip_text = Journey.item_tooltip(id)
	restart()

func make_button(key: String, label: String, position_at: Vector2, width: int, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.position = position_at
	button.size = Vector2(width, 44)
	button.add_theme_font_size_override("font_size", 17)
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#28242a") if state == "normal" else Color("#3d3030")
		style.border_color = Color("#8b684a") if state == "normal" else GOLD
		if state == "disabled":
			style.bg_color = Color("#211e21")
			style.border_color = Color("#4e4140")
		style.set_border_width_all(1)
		style.border_width_bottom = 3
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	add_child(button)
	buttons[key] = button

func toggle_menu() -> void:
	set_menu(Menu.MAIN if menu == Menu.CLOSED else Menu.CLOSED)

func set_menu(value: Menu) -> void:
	if not busy:
		menu = value
		refresh()

func toggle_fullscreen() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	refresh()

func exit_game() -> void:
	get_tree().quit()

func change_volume(value: float, key: String) -> void:
	audio.set(key, value / 100.0)
	audio.apply_levels()
	audio.save_levels()
	queue_redraw()

func toggle_music() -> void:
	audio.music_enabled = not audio.music_enabled
	audio.apply_levels()
	audio.save_levels()
	refresh()

func restart() -> void:
	menu = Menu.CLOSED
	journey = Journey.new()
	day = Day.NIGHT
	stash_page = 0
	begin_night()

func begin_night(supplies: int = 0) -> void:
	night = Night.new(journey)
	night.supplies = supplies
	inspected_defense = Vector2i(-1, -1)
	active = night.ranger
	selected_build = "Wall"
	pin_selected = false
	hit_until = 0.0
	fallen_defenses.clear()
	blessing_until = 0.0
	heal_cast_until = 0.0
	shield_impact_until = 0.0
	ready_at.clear()
	heal_selected = false
	firing_tile = Night.NO_TILE
	damaged_tile = Night.NO_TILE
	night.start_wave()
	camera_zoom = 1.05
	camera_offset = VIEW * 0.5 - center(Night.FIRE) * camera_zoom
	pointer_button = 0
	hit_actor = null
	attack_actor = null
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
	audio.set_night(day == Day.NIGHT)
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
	update_intent(tile_at(screen_to_world(get_local_mouse_position())))
	for button: Button in buttons.values():
		button.hide()
	for slider: HSlider in sliders.values():
		slider.hide()
	buttons.menu.show()
	buttons.menu.disabled = busy
	buttons.menu.text = "Menu" if menu == Menu.CLOSED else "Close"
	if menu != Menu.CLOSED:
		refresh_menu()
		return
	buttons.advance.show()
	for i in 3:
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
		button.visible = building and not night.is_structure(inspected_defense)
		button.disabled = night.supplies < Night.BUILD_COST[kind]
		button.modulate = GOLD if kind == selected_build else Color.WHITE
	buttons.special.visible = night.phase == Night.Phase.PLAYER
	buttons.special.disabled = busy or not night.can_prepare(active)
	buttons.revive.visible = night.phase == Night.Phase.PLAYER and adjacent_fallen() != null
	buttons.revive.disabled = busy or not night.can_revive(active, adjacent_fallen())
	buttons.revive.text = "Revive [%d AP]" % night.revive_cost(active)
	buttons.special.icon = HEAL_ICON if active == night.priest else null
	if active == night.priest:
		buttons.special.text = "Choose Ally" if heal_selected else "Heal [1 AP]"
		buttons.special.tooltip_text = "Restore up to %d HP to yourself or an adjacent living ally." % night.heal_power()
		buttons.special.disabled = busy or active.ap <= 0 or active.hp <= 0
	elif active == night.ranger:
		buttons.special.text = "Overwatch Ready" if active.prepared else "Overwatch [1 AP]"
		buttons.special.tooltip_text = "Spend 1 AP and one bow attack. Fire once at a creature that moves within bow range this enemy phase."
	else:
		buttons.special.text = "Defend Ready" if active.prepared else "Defend [1 AP]"
		buttons.special.tooltip_text = "Spend 1 AP to reduce the next melee hit against the Knight by an additional %d." % (1 + active.character.rank_of("guard"))
	buttons.pin.position.y = 523 if buttons.revive.visible else 470
	buttons.pin.visible = night.phase == Night.Phase.PLAYER and active == night.ranger and active.character.rank_of("pin") > 0
	buttons.pin.disabled = busy or active.ap == 0 or active.attacks == 0
	buttons.pin.modulate = GOLD if pin_selected else Color.WHITE
	if building:
		buttons.advance.text = "Start Next Wave"
		if night.is_structure(inspected_defense):
			refresh_defense()
	elif night.phase == Night.Phase.VICTORY:
		buttons.advance.text = "Break Camp at Dawn"
	else:
		buttons.advance.text = "End Turn  [Space]"
		buttons.advance.disabled = busy or night.phase != Night.Phase.PLAYER

func refresh_menu() -> void:
	match menu:
		Menu.MAIN:
			for key: String in ["settings", "restart", "exit"]:
				buttons[key].show()
		Menu.SETTINGS:
			for key: String in sliders:
				var slider: HSlider = sliders[key]
				slider.set_value_no_signal(float(audio.get(key)) * 100.0)
				slider.show()
			buttons.music.text = "Music: On" if audio.music_enabled else "Music: Off"
			buttons.music.show()
			buttons.fullscreen.text = "Fullscreen: On" if get_window().mode == Window.MODE_FULLSCREEN else "Fullscreen: Off"
			buttons.fullscreen.show()
			buttons.back.show()
		Menu.RESTART:
			buttons.restart_confirm.show()
			buttons.back.show()

func refresh_defense() -> void:
	var piece: Dictionary = night.defenses[inspected_defense]
	for action: String in ["Upgrade", "Repair", "Destroy"]:
		var button: Button = buttons["manage_" + action]
		button.show()
		button.disabled = not night.can_manage(inspected_defense, action)
	buttons.manage_Upgrade.text = "Max Rank" if piece.level == Night.MAX_STRUCTURE_LEVEL else "Upgrade [%d]" % Night.BUILD_COST[piece.kind]
	buttons.manage_Repair.text = "Repair [%d]" % Night.FIX_COST
	buttons.manage_Destroy.text = "Destroy +%d" % night.salvage_value(piece)
	buttons.manage_Destroy.tooltip_text = "Dismantle and recover half of construction and upgrade supplies, rounded down."
	place_defense_popup()
	buttons.defense_close.show()

func defense_popup_position() -> Vector2:
	var at := world_to_screen(center(inspected_defense))
	var x := clampf(at.x - 163, 12, 572.0)
	var y := at.y - 146
	if y < 50:
		y = at.y + 35
	return Vector2(x, clampf(y, 47, VIEW.y - 127))

func place_defense_popup() -> void:
	var origin := defense_popup_position()
	for i in 3:
		var key: String = ["Upgrade", "Repair", "Destroy"][i]
		buttons["manage_" + key].position = origin + Vector2(8 + i * 108, 64)
	buttons.defense_close.position = origin + Vector2(291, 5)

func manage_defense(action: String) -> void:
	if night.manage(inspected_defense, action) and action == "Destroy":
		inspected_defense = Vector2i(-1, -1)
	refresh()

func close_defense() -> void:
	inspected_defense = Vector2i(-1, -1)
	refresh()

func stash_pages() -> int:
	return maxi(1, ceili(float(journey.inventory.size()) / STASH_PAGE_SIZE))

func page_stash(direction: int) -> void:
	stash_page = clampi(stash_page + direction, 0, stash_pages() - 1)
	refresh()

func equip_visible(row: int) -> void:
	equip(stash_page * STASH_PAGE_SIZE + row)

func sell_visible(row: int) -> void:
	sell(stash_page * STASH_PAGE_SIZE + row)

func toggle_dusk_equipment() -> void:
	dusk_equipment = not dusk_equipment
	refresh()

func refresh_day() -> void:
	buttons.dusk_equipment.visible = day == Day.DUSK
	buttons.dusk_equipment.text = "Return to Road" if dusk_equipment else "Manage Equipment"
	if day == Day.ROAD or (day == Day.DUSK and not dusk_equipment):
		for i in night.heroes.size():
			buttons["hero%d" % i].hide()
		buttons.advance.visible = day == Day.DUSK
		buttons.advance.text = "Set Up Camp at Dusk"
		return
	buttons.advance.text = ["", "Follow the Road", "Continue to Stoneford",
		"Set Up Camp at Dusk", "Journey Complete"][day]
	if day == Day.DAWN and journey.site == 1:
		buttons.advance.text = "Finish the Journey"
	buttons.advance.disabled = day == Day.COMPLETE
	stash_page = mini(stash_page, stash_pages() - 1)
	var first := stash_page * STASH_PAGE_SIZE
	for i in mini(STASH_PAGE_SIZE, journey.inventory.size() - first):
		var index := first + i
		var id := journey.inventory[index]
		var equip_button: Button = buttons["equip%d" % i]
		equip_button.disabled = not journey.can_equip(active.character, index)
		equip_button.tooltip_text = Journey.item_tooltip(id)
		equip_button.show()
		if journey.can_sell(index):
			var sell_button: Button = buttons["sell%d" % i]
			sell_button.text = "Sell [%dg]" % journey.sell_price(id)
			sell_button.show()
	buttons.stash_prev.visible = stash_pages() > 1
	buttons.stash_prev.disabled = stash_page == 0
	buttons.stash_next.visible = stash_pages() > 1
	buttons.stash_next.disabled = stash_page + 1 >= stash_pages()
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
	heal_selected = false
	pin_selected = false
	refresh()

func prepare_special() -> void:
	if busy:
		return
	if active == night.priest:
		heal_selected = not heal_selected
		refresh()
	elif night.prepare(active):
		ready_at[active] = clock
		refresh()

func adjacent_fallen() -> Night.Hero:
	var fallback: Night.Hero
	for hero: Night.Hero in night.heroes:
		if night.can_revive(active, hero):
			return hero
		if hero.hp == 0 and night.combat_distance(active.tile, hero.tile) == 1:
			fallback = hero
	return fallback

func revive_nearby() -> void:
	var target := adjacent_fallen()
	if not busy and night.revive(active, target):
		bless(target.tile)
		refresh()

func toggle_pin() -> void:
	pin_selected = not pin_selected
	refresh()

func equip(index: int) -> void:
	if journey.can_equip(active.character, index):
		var id := journey.inventory[index]
		journey.equip(active.character, index)
		day_message = "%s equipped %s." % [active.title, Journey.item_data(id).name]
		refresh()

func buy(id: String) -> void:
	if journey.buy(id):
		day_message = "Bought %s. Equip it before dusk." % Journey.GEAR[id].name
		refresh()

func sell(index: int) -> void:
	if journey.can_sell(index):
		var id := journey.inventory[index]
		if journey.sell(index):
			day_message = "Sold %s." % Journey.item_data(id).name
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
			day = Day.ROAD
			dusk_equipment = false
			travel_elapsed = 0.0
			day_message = "On the road to Stoneford."
		Day.DUSK:
			journey.daylight = false
			journey.site += 1
			day = Day.NIGHT
			begin_night(night.supplies)
	refresh()

func choose_build(kind: String) -> void:
	inspected_defense = Vector2i(-1, -1)
	selected_build = kind
	refresh()

func _process(delta: float) -> void:
	clock += delta
	if day == Day.ROAD and menu == Menu.CLOSED:
		travel_elapsed = minf(TRAVEL_DURATION, travel_elapsed + delta)
		if travel_elapsed >= TRAVEL_DURATION:
			day = Day.DUSK
			day_message = "The caravan reaches Stoneford as the light fades."
			refresh()
	var hovered := tile_at(screen_to_world(get_local_mouse_position()))
	if hovered != intent_tile:
		update_intent(hovered)
	queue_redraw()

func update_intent(tile: Vector2i) -> void:
	intent_tile = tile
	intent_path.clear()
	intent_target = Night.NO_TILE
	if day != Day.NIGHT or busy or menu != Menu.CLOSED or night.phase != Night.Phase.PLAYER:
		return
	var enemy := night.enemy_at(tile)
	if enemy == null:
		return
	intent_target = night.enemy_target(enemy, enemy.tile)
	if night.on_board(intent_target):
		return
	var route := night.enemy_path(enemy)
	for i in mini(route.size(), night.enemy_movement(enemy)):
		var step := route[i]
		var structure := night.structure_in_step(enemy, step)
		if night.on_board(structure):
			intent_target = structure
			return
		intent_path.append(step)
		intent_target = night.enemy_target(enemy, step)
		if night.on_board(intent_target):
			return

func world_to_screen(point: Vector2) -> Vector2:
	return camera_offset + point * camera_zoom

func screen_to_world(point: Vector2) -> Vector2:
	return (point - camera_offset) / camera_zoom

func limit_camera() -> void:
	var field := Vector2(Night.SIZE) * CELL * camera_zoom
	camera_offset.x = clampf(camera_offset.x, 180 - field.x, VIEW.x - 180)
	camera_offset.y = clampf(camera_offset.y, 145 - field.y, VIEW.y - 145)
	if night.is_structure(inspected_defense):
		place_defense_popup()

func pointer_allowed() -> bool:
	return day == Day.NIGHT and menu == Menu.CLOSED

func _input(event: InputEvent) -> void:
	if pointer_button != 0 and event is InputEventMouseMotion:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if dragging or point.distance_to(pointer_origin) > 7.0:
			dragging = true
			camera_offset += point - pointer_last
			limit_camera()
		pointer_last = point
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == pointer_button:
		var click := pointer_button == MOUSE_BUTTON_LEFT and not dragging and pointer_allowed() and not busy
		pointer_button = 0
		dragging = false
		get_viewport().set_input_as_handled()
		if click:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			board_click(tile_at(screen_to_world(point)))
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F11:
		get_viewport().set_input_as_handled()
		toggle_fullscreen()
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if menu != Menu.CLOSED:
			set_menu(Menu.CLOSED)
		elif night.is_structure(inspected_defense):
			close_defense()
		else:
			set_menu(Menu.MAIN)
		return
	if menu != Menu.CLOSED:
		return
	match event.keycode:
		KEY_SPACE:
			get_viewport().set_input_as_handled()
			advance()
		KEY_1, KEY_2, KEY_3:
			if not busy:
				get_viewport().set_input_as_handled()
				select_hero(event.keycode - KEY_1)

func _unhandled_input(event: InputEvent) -> void:
	if not pointer_allowed() or not (event is InputEventMouseButton and event.pressed):
		return
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var anchor := screen_to_world(point)
		var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
		camera_zoom = clampf(camera_zoom * factor, 0.60, 1.85)
		camera_offset = point - anchor * camera_zoom
		limit_camera()
		get_viewport().set_input_as_handled()
	elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		if event.button_index == MOUSE_BUTTON_LEFT and (Rect2(918, 52, 345, 470).has_point(point)
				or (night.is_structure(inspected_defense) and Rect2(defense_popup_position(), Vector2(328, 116)).has_point(point))):
			return
		pointer_button = event.button_index
		pointer_origin = point
		pointer_last = point
		dragging = false
		get_viewport().set_input_as_handled()

func board_click(tile: Vector2i) -> void:
	if not night.on_board(tile) or not pending_upgrades().is_empty():
		return
	match night.phase:
		Night.Phase.BUILD:
			if night.is_structure(tile):
				inspected_defense = tile
			elif night.is_structure(inspected_defense):
				inspected_defense = Night.NO_TILE
			elif not night.build(selected_build, tile):
				night.message = "Choose a free lit tile and an affordable defense."
			else:
				fallen_defenses.erase(tile)
			refresh()
		Night.Phase.PLAYER:
			play_at(tile)

func play_at(tile: Vector2i) -> void:
	var ally := night.hero_at(tile)
	if heal_selected and active == night.priest:
		if night.heal(ally):
			heal_cast_until = clock + 0.62
			bless(tile)
			heal_selected = false
		else:
			night.message = "Choose an injured living ally within 1 tile, or click Heal to cancel."
		refresh()
		return
	var fallen := night.fallen_at(tile)
	if fallen != null and ally == null:
		if night.revive(active, fallen):
			bless(tile)
		else:
			night.message = "Revive requires a free adjacent tile and %d AP." % night.revive_cost(active)
		refresh()
		return
	if ally != null:
		select_hero(night.heroes.find(ally))
		return
	var enemy := night.enemy_at(tile)
	if enemy != null:
		if not night.can_attack(active, tile, pin_selected):
			night.message = "Attack needs 1 AP, a remaining attack, clear sight, and range %s." % weapon_range(active)
			return
		busy = true
		refresh()
		if active == night.ranger:
			await hero_shot(active, tile, GOLD)
		else:
			audio.play_effect("sword")
			attack_actor = active
			attack_offset = (center(tile) - center(active.tile)).normalized() * 15.0
			await create_tween().tween_property(self, "attack_progress", 1.0, 0.12).finished
			flash(center(tile))
			await create_tween().tween_property(self, "attack_progress", 0.0, 0.10).finished
			attack_actor = null
		react_to_hit(enemy)
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
	if busy or menu != Menu.CLOSED or not pending_upgrades().is_empty():
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
		inspected_defense = Vector2i(-1, -1)
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
			await resolve_enemy(enemy)
	night.next_turn()
	heal_selected = false
	pin_selected = false
	busy = false
	refresh()

func resolve_enemy(enemy: Night.Enemy) -> void:
	var route := night.enemy_path(enemy)
	var steps := night.enemy_movement(enemy)
	enemy.pinned = false
	var target := night.enemy_target(enemy, enemy.tile)
	if night.on_board(target):
		await enemy_strike(enemy, target)
		return
	for i in mini(steps, route.size()):
		var next := route[i]
		target = night.structure_in_step(enemy, next)
		if night.on_board(target):
			await enemy_strike(enemy, target)
			return
		await move_piece(enemy, enemy.tile, next, 0.15)
		var previous_hp := enemy.hp
		var survived := night.step_enemy(enemy, next)
		if enemy.hp < previous_hp:
			react_to_hit(enemy)
		if not survived:
			return
		if night.can_overwatch(enemy):
			await hero_shot(night.ranger, night.overwatch_tile(enemy), TEAL)
			react_to_hit(enemy)
			night.fire_overwatch(enemy)
			if not night.enemies.has(enemy):
				return
		target = night.enemy_target(enemy, enemy.tile)
		if night.on_board(target):
			await enemy_strike(enemy, target)
			return

func enemy_strike(enemy: Night.Enemy, target: Vector2i) -> void:
	attack_actor = enemy
	attack_progress = 0.0
	attack_offset = (center(target) - enemy_center(enemy, enemy.tile)).normalized() * (16.0 if enemy.size == 2 else 12.0)
	await create_tween().tween_property(self, "attack_progress", 1.0, 0.16).finished
	var cue := "fire_hit" if target == Night.FIRE else ("wood_hit" if night.is_structure(target) else "ally_hit")
	audio.play_effect(cue)
	flash(center(target))
	var structure: Dictionary = night.defenses.get(target, {}).duplicate()
	damaged_tile = target
	if night.hero_at(target) == night.knight and night.knight.prepared:
		shield_impact_until = clock + 0.23
	night.attack_enemy_target(enemy, target)
	if not structure.is_empty() and not night.defenses.has(target):
		fallen_defenses[target] = structure.kind
	night.finish_if_lost()
	await create_tween().tween_property(self, "attack_progress", 0.0, 0.16).finished
	attack_actor = null

func resolve_ballistae() -> void:
	for tile: Vector2i in night.defenses:
		if night.defenses[tile].kind != "Ballista":
			continue
		var target := night.ballista_target(tile)
		if not night.on_board(target):
			continue
		firing_tile = tile
		await projectile(center(tile), center(target), TEAL)
		firing_tile = Night.NO_TILE
		var enemy := night.enemy_at(target)
		react_to_hit(enemy)
		var damage := night.ballista_damage(night.defenses[tile])
		night.damage_enemy(enemy, damage)
		night.message = "A ballista dealt %d damage." % damage

func react_to_hit(enemy: Night.Enemy) -> void:
	audio.play_effect("enemy_hit")
	flash(enemy_center(enemy, enemy.tile))
	hit_actor = enemy

func enemy_center(enemy: Night.Enemy, tile: Vector2i) -> Vector2:
	return center(tile) + Vector2.ONE * (enemy.size - 1) * CELL * 0.5

func move_piece(actor: Variant, from: Vector2i, to: Vector2i, duration: float) -> void:
	motion_actor = actor
	motion_from = center(from)
	motion_to = center(to)
	motion_progress = 0.0
	await create_tween().tween_property(self, "motion_progress", 1.0, duration).finished
	motion_actor = null

func hero_shot(hero: Night.Hero, target: Vector2i, color: Color) -> void:
	attack_actor = hero
	attack_offset = (center(hero.tile) - center(target)).normalized() * 6.0
	await projectile(center(hero.tile), center(target), color)
	attack_actor = null

func projectile(from: Vector2, to: Vector2, color: Color) -> void:
	audio.play_effect("bow")
	arrow_from = from
	arrow_to = to
	arrow_color = color
	arrow_progress = 0.0
	await create_tween().tween_property(self, "arrow_progress", 1.0, 0.20).finished
	flash(to)

func flash(at: Vector2) -> void:
	damaged_tile = Night.NO_TILE
	hit_actor = null
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
	draw_rect(Rect2(0, 0, 1280, 720), Color("#0e1720") if day == Day.NIGHT else Color("#302b24"))
	if day != Day.NIGHT:
		draw_day()
	else:
		draw_set_transform_matrix(board_transform())
		draw_board()
		draw_effects()
		draw_set_transform(Vector2.ZERO)
		draw_top_bar()
		draw_rect(Rect2(0, 686, 908, 34), HUD)
		draw_hover_tip()
		draw_sidebar()
		if night.is_structure(inspected_defense) and menu == Menu.CLOSED:
			draw_defense_popup()
	if menu != Menu.CLOSED:
		draw_game_menu()

func draw_top_bar() -> void:
	draw_rect(Rect2(0, 0, 1280, 43), Color("#19171c"))
	draw_line(Vector2(0, 42), Vector2(1280, 42), Color("#75533c"), 2)
	draw_hud_frame(Rect2(12, 5, 292, 32), Color("#2e2425"))
	label_at(Vector2(23, 27), Journey.CAMPS[journey.site].to_upper(), 18, GOLD)
	var labels := ["NIGHT %d" % (journey.site + 1), "WAVE %d/%d" % [night.wave, night.spawns.size()],
		"TURN %02d" % night.turn, "FIRE %d/%d" % [night.fire_hp, Night.MAX_FIRE_HP], "SUPPLIES %d" % night.supplies]
	for i in labels.size():
		var x := 316 + i * 126 if i < 3 else 887 + (i - 3) * 126
		draw_hud_frame(Rect2(x, 5, 118, 32), Color("#292328"))
		label_at(Vector2(x + 10, 26), labels[i], 15, PAPER if i < 3 else GOLD)

func draw_hover_tip() -> void:
	if night.phase != Night.Phase.PLAYER or busy or menu != Menu.CLOSED:
		return
	var tile := tile_at(screen_to_world(get_local_mouse_position()))
	var enemy := night.enemy_at(tile)
	if enemy == null:
		return
	var stats: Array = Night.CREATURES[enemy.kind]
	var gap := night.combat_distance(active.tile, tile)
	var valid := night.in_weapon_range(active, tile)
	var reason := "Clear shot"
	if gap < int(active.character.weapon().min):
		reason = "Too close"
	elif gap > night.attack_range(active):
		reason = "Out of range"
	elif not valid:
		reason = "Sight blocked"
	var status := "%d tiles • %s" % [gap, reason]
	label_at(Vector2(473, 27), "%s   %d HP   •   %s" % [stats[0], enemy.hp, status], 14, TEAL if valid else RED)

func draw_defense_popup() -> void:
	var origin := defense_popup_position()
	draw_rect(Rect2(origin, Vector2(328, 116)), Color("#1c292d"))
	draw_rect(Rect2(origin, Vector2(328, 116)), GOLD, false, 1)
	var piece: Dictionary = night.defenses[inspected_defense]
	label_at(origin + Vector2(12, 23), "%s  •  Rank %d  •  %d/%d HP" % [
		piece.kind, piece.level, piece.hp, night.structure_max_hp(piece)], 16, GOLD)
	var detail := "%d damage  •  %d range" % [night.ballista_damage(piece), night.ballista_range(piece)] if piece.kind == "Ballista" else "Adjacent walls link into one barricade."
	label_at(origin + Vector2(12, 48), detail, 14, MUTED)

func draw_game_menu() -> void:
	draw_rect(Rect2(918, 44, 352, 648), Color(0.067, 0.11, 0.14, 0.94))
	draw_rect(Rect2(918, 44, 352, 648), Color("#5a615e"), false, 1)
	match menu:
		Menu.MAIN:
			label_at(Vector2(935, 83), "GAME MENU", 21, GOLD)
		Menu.SETTINGS:
			label_at(Vector2(935, 83), "AUDIO SETTINGS", 21, GOLD)
			label_at(Vector2(935, 129), "Master volume   %d%%" % roundi(audio.master * 100.0), 17)
			label_at(Vector2(935, 194), "Sound effects   %d%%" % roundi(audio.sfx * 100.0), 17)
			label_at(Vector2(935, 259), "Night ambience   %d%%" % roundi(audio.ambience_level * 100.0), 17)
		Menu.RESTART:
			label_at(Vector2(935, 83), "RESTART JOURNEY?", 21, GOLD)
			label_at(Vector2(935, 125), "Current journey progress will be lost.", 16, MUTED)

func draw_cliff(tile: Vector2i) -> void:
	var origin := Vector2(tile) * CELL
	var south := tile + Vector2i.DOWN not in night.cliffs
	var top_height := CELL - 19 if south else CELL
	var right := float(CELL)
	var ledge := PackedVector2Array([origin + Vector2(0, top_height), origin + Vector2(13, top_height - 4),
		origin + Vector2(29, top_height + 1), origin + Vector2(45, top_height - 3),
		origin + Vector2(right, top_height)])
	var top := PackedVector2Array([origin, origin + Vector2(right, 0)])
	if south:
		for i in range(ledge.size() - 1, -1, -1):
			top.append(ledge[i])
	else:
		top.append(origin + Vector2(right, CELL))
		top.append(origin + Vector2(0, CELL))
	var rock := Color("#6c5c49")
	draw_colored_polygon(top, rock)
	var shade := Color("#4f4439")
	draw_colored_polygon(PackedVector2Array([origin + Vector2(0, 19), origin + Vector2(16, 14),
		origin + Vector2(27, 19), origin + Vector2(47, 13), origin + Vector2(right, 19),
		origin + Vector2(right, 25), origin + Vector2(44, 20), origin + Vector2(27, 25),
		origin + Vector2(13, 21), origin + Vector2(0, 25)]), shade)
	draw_polyline(PackedVector2Array([origin + Vector2(17, 11), origin + Vector2(25, 7),
		origin + Vector2(33, 9)]), Color("#9a8159"), 2.0, true)
	var edge := Color("#211a1c")
	if south:
		var face := ledge.duplicate()
		face.append(origin + Vector2(right, CELL))
		face.append(origin + Vector2(0, CELL))
		draw_colored_polygon(face, Color("#453a37"))
		draw_polyline(ledge, edge, 3.0, true)
		for i in [1, 2, 3]:
			var foot := Vector2(ledge[i].x - 5, origin.y + CELL)
			draw_line(ledge[i], foot, edge, 2.5, true)
			draw_line(ledge[i] + Vector2(4, 4), foot + Vector2(5, -3), Color("#77665a"), 2.0, true)
		draw_line(origin + Vector2(0, CELL), origin + Vector2(right, CELL), edge, 3.0)
	if tile + Vector2i.UP not in night.cliffs:
		draw_line(origin, origin + Vector2(right, 0), edge, 3.0)
	if tile + Vector2i.LEFT not in night.cliffs:
		draw_line(origin, origin + Vector2(0, CELL), edge, 3.0)
	if tile + Vector2i.RIGHT not in night.cliffs:
		draw_line(origin + Vector2(right, 0), origin + Vector2(right, CELL), edge, 3.0)

func draw_board() -> void:
	var hovered := tile_at(screen_to_world(get_local_mouse_position()))
	var board_rect := Rect2(BOARD, Vector2(Night.SIZE) * CELL)
	draw_rect(board_rect.grow(3), Color("#5d5141"), false, 2)
	draw_texture_rect(TERRAIN[journey.site], board_rect, false)
	for y in range(0, Night.SIZE.y, 3):
		for x in range(0, Night.SIZE.x, 3):
			var extent := Vector2(mini(3, Night.SIZE.x - x), mini(3, Night.SIZE.y - y)) * CELL
			var ground: String = "trail" if y == 6 else ("dirt" if (x + y) % 2 == 0 else "grass")
			draw_texture_rect(SPRITES[ground], Rect2(Vector2(x, y) * CELL, extent), false, Color(1, 1, 1, 0.20))
	draw_sprite("wheel", center(Night.FIRE) + Vector2(-42, -29), 24.0)
	for tile: Vector2i in night.cliffs:
		draw_cliff(tile)
	for tile: Vector2i in night.rocks:
		var variant := posmod(tile.x * 7 + tile.y * 11 + journey.site, 3)
		draw_sprite(["rock", "rock_split", "rock_slab"][variant], center(tile), 51.0)
	for tile: Vector2i in night.trees:
		draw_sprite("tree", center(tile), 60.0)
	if night.fire_hp > 0:
		draw_texture_rect(night_shade, board_rect, false)
	else:
		draw_rect(board_rect, Color(0.025, 0.044, 0.08, 0.76))
	var inspected_range := 0
	if night.is_structure(inspected_defense):
		var piece: Dictionary = night.defenses[inspected_defense]
		if piece.kind == "Ballista":
			inspected_range = night.ballista_range(piece)
	for y in Night.SIZE.y:
		for x in Night.SIZE.x:
			draw_tile_overlay(Vector2i(x, y), hovered, inspected_range)
	for tile: Vector2i in night.loot:
		draw_sprite("loot_bag", center(tile) + Vector2(11, 7), 26.0)
	for tile: Vector2i in fallen_defenses:
		if not night.defenses.has(tile):
			draw_rubble(center(tile), fallen_defenses[tile] == "Ballista")
	var defense_tiles := night.defenses.keys()
	defense_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for tile: Vector2i in defense_tiles:
		var piece: Dictionary = night.defenses[tile]
		if piece.kind == "Wall":
			draw_linked_wall(tile, center(tile), piece.level, 1.0, 0.0, true)
	for tile: Vector2i in defense_tiles:
		draw_defense(tile, night.defenses[tile])
		if tile == inspected_defense:
			draw_rect(tile_rect(tile).grow(-2), GOLD, false, 2)
	draw_fire(center(Night.FIRE))
	for enemy: Night.Enemy in night.enemies:
		var at := enemy_center(enemy, enemy.tile)
		if motion_actor == enemy:
			at = motion_from.lerp(motion_to, motion_progress) + Vector2.ONE * (enemy.size - 1) * CELL * 0.5
		draw_enemy(at, enemy)
	if hit_actor != null and hit_actor.hp <= 0 and hit_until > clock:
		draw_enemy(enemy_center(hit_actor, hit_actor.tile), hit_actor)
	for hero: Night.Hero in night.heroes:
		if hero.hp <= 0:
			draw_fallen(hero)
			continue
		var at := motion_from.lerp(motion_to, motion_progress) if motion_actor == hero else center(hero.tile)
		draw_unit(hero.title.to_lower(), at, 51.0, hero,
			damaged_tile == hero.tile and hit_position == center(hero.tile), false)
		if hero.prepared:
			draw_circle(at + Vector2(15, -15), 4, GOLD)

func draw_tile_overlay(tile: Vector2i, hovered: Vector2i, inspected_range: int) -> void:
	var rect := tile_rect(tile)
	var grid_color := Color(0.92, 0.78, 0.55, 0.20) if night.is_lit(tile) else Color(0.66, 0.74, 0.80, 0.13)
	draw_line(rect.position, rect.position + Vector2(5, 0), grid_color)
	draw_line(rect.position, rect.position + Vector2(0, 5), grid_color)
	if not busy and tile != active.tile and reach.has(tile):
		draw_rect(rect.grow(-2), Color(0.34, 0.86, 0.72, 0.16))
		draw_rect(rect.grow(-3), Color(0.34, 0.86, 0.72, 0.45), false, 1.0)
	if inspected_range > 0 and night.distance(tile, inspected_defense) <= inspected_range:
		draw_circle(rect.get_center(), 2.4, Color(0.94, 0.73, 0.36, 0.65))
	if tile in intent_path:
		draw_rect(rect.grow(-5), GOLD, false, 2)
	if tile == intent_target:
		draw_rect(rect.grow(-4), RED, false, 3)
	if tile == hovered:
		draw_rect(rect.grow(-2), PAPER, false, 2.0)
		var text_color := GOLD if night.is_lit(tile) else MUTED
		var light_status := "FIRELIGHT" if night.is_lit(tile) else "DARKNESS"
		label_at(rect.position + Vector2(3, CELL - 5), light_status, 9, text_color)

func polygon(at: Vector2, points: Array, color: Color) -> void:
	var vertices := PackedVector2Array()
	for point: Vector2 in points:
		vertices.append(at + point)
	draw_colored_polygon(vertices, color)

func sprite_rect(texture: Texture2D, at: Vector2, side: float) -> Rect2:
	var size := texture.get_size() * (side / maxf(texture.get_width(), texture.get_height()))
	return Rect2(at - size * 0.5, size)

func draw_sprite(key: String, at: Vector2, side: float, tint := Color.WHITE) -> void:
	var texture: Texture2D = SPRITES[key]
	draw_texture_rect(texture, sprite_rect(texture, at, side), false, tint)

func silhouette(texture: Texture2D) -> Texture2D:
	if not outlines.has(texture):
		var source := texture.get_image()
		source.decompress()
		var mask := Image.create_empty(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
		for y in source.get_height():
			for x in source.get_width():
				mask.set_pixel(x, y, Color(1, 1, 1, source.get_pixel(x, y).a))
		outlines[texture] = ImageTexture.create_from_image(mask)
	return outlines[texture]

func draw_fire(at: Vector2) -> void:
	if night.fire_hp == 0:
		draw_sprite("embers", at + Vector2(0, 4), 45.0)
		return
	var pulse := sin(clock * 13.0) * 2.0
	for i in range(3, 0, -1):
		draw_circle(at, 10.0 + i * 7.0 + pulse, Color(1.0, 0.57, 0.23, 0.045))
	var cycle := [0, 1, 2, 1]
	draw_sprite("fire_%d" % cycle[int(clock * 9.0) % cycle.size()], at + Vector2(0, -4), 53.0)
	for i in 5:
		var rise := fposmod(clock * 24.0 + i * 9.0, 40.0)
		var ember := at + Vector2(sin(rise * 0.18 + i) * 9, -9 - rise)
		draw_rect(Rect2(ember, Vector2(2, 2)), Color(1.0, 0.75, 0.4, 1.0 - rise / 41.0))

func draw_fallen(hero: Night.Hero) -> void:
	var at := center(hero.tile)
	polygon(at, [Vector2(-24, 10), Vector2(-16, 1), Vector2(-2, 5), Vector2(7, -2),
		Vector2(24, 8), Vector2(19, 15), Vector2(3, 18), Vector2(-11, 16)], Color("#491d23"))
	draw_circle(at + Vector2(24, 16), 2.0, Color("#632632"))
	var key := hero.title.to_lower()
	var texture: Texture2D = animation_frames[key][4]
	if texture != null:
		draw_texture_rect(texture, sprite_rect(texture, at, 53.0), false)

func board_transform() -> Transform2D:
	return Transform2D(0.0, Vector2.ONE * camera_zoom, 0.0, camera_offset)

func draw_unit(key: String, at: Vector2, side: float, actor: Variant, hit: bool, dead: bool) -> void:
	var pose := -1
	var offset := Vector2.ZERO
	var tint := Color.WHITE
	if motion_actor == actor:
		pose = 0 if motion_progress < 0.5 else 1
	if attack_actor == actor:
		pose = 2
		var strength := sin(arrow_progress * PI) if key == "ranger" else attack_progress
		offset = attack_offset * strength
	if hit and hit_until > clock:
		pose = 3
		var remaining := clampf((hit_until - clock) / 0.23, 0.0, 1.0)
		offset += Vector2(-4, -2) * remaining
		tint = Color.WHITE.lerp(Color("#ff9b88"), remaining)
		if dead:
			tint.a = remaining
	var texture: Texture2D = SPRITES[key]
	if pose >= 0 and animation_frames[key][pose] != null:
		texture = animation_frames[key][pose]
	if pose < 0 and actor is Night.Hero and actor.prepared:
		var age := clock - float(ready_at.get(actor, clock - 1.0))
		if age >= 0.08:
			texture = SPRITES["knight_guard" if key == "knight" else "ranger_watch"]
		offset.y -= sin(clampf(age / 0.22, 0.0, 1.0) * PI) * 3.0
	if key == "knight" and shield_impact_until > clock and hit:
		texture = SPRITES["knight_guard"]
	if key == "priest" and heal_cast_until > clock:
		texture = SPRITES["priest_cast_high" if heal_cast_until - clock < 0.44 else "priest_cast_low"]
	var rect := sprite_rect(texture, at + offset, side)
	# Keep the planted feet fixed while compensating for the extra padding in action art.
	var pose_fit := Vector2.ONE
	if texture == SPRITES.knight_guard:
		pose_fit = Vector2(1.31, 0.844)
	elif texture == SPRITES.ranger_watch:
		pose_fit = Vector2(1.23, 0.888)
	elif texture == SPRITES.priest_cast_low:
		pose_fit = Vector2(1.19, 0.894)
	elif texture == SPRITES.priest_cast_high:
		pose_fit = Vector2(1.15, 0.988)
	if pose_fit != Vector2.ONE:
		var foot := at.y + offset.y + side * 0.48
		rect.size *= pose_fit.x
		rect.position = Vector2(at.x + offset.x - rect.size.x * 0.5, foot - rect.size.y * pose_fit.y)
	if actor == active and not dead:
		var mask := silhouette(texture)
		for i in 12:
			var edge := Vector2.from_angle(TAU * i / 12.0) * 1.8
			draw_texture_rect(mask, Rect2(rect.position + edge, rect.size), false, TEAL)
	draw_texture_rect(texture, rect, false, tint)

func draw_enemy(at: Vector2, enemy: Night.Enemy) -> void:
	var side := float(CELL * enemy.size - 4)
	draw_unit(enemy.kind, at, side, enemy, hit_actor == enemy, enemy.hp <= 0)
	if enemy.hp <= 0:
		return
	var bar_width := side * 0.74
	draw_rect(Rect2(at + Vector2(-bar_width * 0.5, -side * 0.5), Vector2(bar_width, 5)), INK)
	draw_rect(Rect2(at + Vector2(-bar_width * 0.5 + 1, -side * 0.5 + 1),
		Vector2((bar_width - 2) * float(enemy.hp) / enemy.max_hp, 3)), RED)

func draw_defense(tile: Vector2i, piece: Dictionary) -> void:
	var at := center(tile)
	var hp_ratio := float(piece.hp) / night.structure_max_hp(piece)
	var impact := clampf((hit_until - clock) / 0.23, 0.0, 1.0) if damaged_tile == tile else 0.0
	match piece.kind:
		"Wall":
			draw_linked_wall(tile, at, piece.level, hp_ratio, impact)
		"Ballista":
			var recoil := Vector2(5, -4) * sin(arrow_progress * PI) if firing_tile == tile else Vector2.ZERO
			var tint := Color.WHITE.lerp(Color("#ff9b88"), impact)
			var carriage := at + recoil + Vector2(3, -2) * impact
			draw_sprite("ballista_%d" % piece.level, carriage, 53.0, tint)
			if firing_tile == tile:
				var snap := exp(-arrow_progress * 6.0) * cos(arrow_progress * 20.0)
				var string_center := Vector2(-4, 5) + Vector2(8, -7) * snap
				draw_polyline(PackedVector2Array([carriage + Vector2(-22, 4),
					carriage + string_center, carriage + Vector2(12, 15)]), Color("#c9a477"), 1.2, true)
			if hp_ratio <= 0.5:
				draw_rubble(at + Vector2(13, 12), true)
	if Night.STRUCTURE_HP.has(piece.kind) and (hp_ratio < 1.0 or tile == inspected_defense):
		draw_rect(Rect2(at + Vector2(-19, -25), Vector2(38, 5)), INK)
		draw_rect(Rect2(at + Vector2(-18, -24), Vector2(36 * hp_ratio, 3)), TEAL if hp_ratio > 0.4 else RED)

func draw_rubble(at: Vector2, metal: bool) -> void:
	var material := Color("#767878") if metal else Color("#856044")
	for i in 4:
		var chip := at + Vector2(i * 8 - 12, posmod(i * 9, 15) - 3)
		polygon(chip, [Vector2(-6, 4), Vector2(-3, -5), Vector2(5, -3), Vector2(7, 3)], INK)
		polygon(chip, [Vector2(-4, 2), Vector2(-2, -3), Vector2(4, -2), Vector2(5, 2)], material)

func draw_linked_wall(tile: Vector2i, at: Vector2, level: int, hp: float, impact: float, rails_only := false) -> void:
	var links := night.wall_links(tile)
	var connected := not links.is_empty()
	if not connected:
		links = [Vector2i.LEFT, Vector2i.RIGHT]
	var foundation := at + Vector2(0, 5)
	var span := CELL * 0.5 + 0.5 if connected else 20.0
	var rail_y := Vector2(0, -4)
	for direction in links:
		var end := foundation + Vector2(direction) * span
		if rails_only:
			draw_line(foundation + Vector2(3, 4), end + Vector2(3, 4), Color(0, 0, 0, 0.38), 17)
			draw_line(foundation, end, Color("#211815"), 15)
			draw_line(foundation, end, Color("#74523c"), 10)
			draw_line(foundation + rail_y, end + rail_y, Color("#b4865b"), 3)
			if level >= 2:
				draw_line(foundation + Vector2(0, 3), end + Vector2(0, 3), Color("#777c7d"), 3)
			continue
		# Every stake points up on screen, including the stakes on vertical runs.
		for i in 2:
			var foot := foundation.lerp(end, (i + 1) / 3.0)
			draw_wall_stake(foot, level, hp <= 0.5 and i == 1, impact)
	if rails_only:
		return
	draw_wall_stake(foundation, level, false, impact)
	if hp <= 0.5:
		draw_rubble(at + Vector2(1, 13), false)

func draw_wall_stake(at: Vector2, level: int, broken: bool, impact: float) -> void:
	var key := "stake_4" if broken else "stake_%d" % level
	draw_sprite(key, at + Vector2(0, -7 if not broken else -2), 27.0 if not broken else 18.0,
		Color.WHITE.lerp(Color("#f7a68b"), impact))


func weapon_range(hero: Night.Hero) -> String:
	var minimum: int = hero.character.weapon().min
	var maximum := night.attack_range(hero)
	return str(maximum) if minimum == maximum else "%d–%d" % [minimum, maximum]

func draw_hud_frame(rect: Rect2, fill: Color, border := Color("#8a7257")) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, border.darkened(0.35), false, 1.0)
	for x in [rect.position.x, rect.end.x]:
		for y in [rect.position.y, rect.end.y]:
			var corner := Vector2(x, y)
			var inside := (rect.get_center() - corner).sign()
			draw_line(corner, corner + Vector2(8 * inside.x, 0), border, 2)
			draw_line(corner, corner + Vector2(0, 8 * inside.y), border, 2)

func health_color(ratio: float) -> Color:
	if ratio <= 0.0:
		return Color("#100e12")
	if ratio <= 0.30:
		return Color("#d65b54")
	if ratio <= 0.65:
		return Color("#e4ba55")
	return Color("#78bf78")

func draw_counter(at: Vector2, value: int, color: Color, caption: String) -> void:
	draw_circle(at, 10, color.darkened(0.66), true, -1, true)
	draw_arc(at, 10, 0, TAU, 20, color, 1.4, true)
	var digits := str(value)
	var width := ThemeDB.fallback_font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	label_at(at + Vector2(-width * 0.5, 5), digits, 14)
	label_at(at + Vector2(15, 5), caption, 13, color)

func draw_party() -> void:
	draw_hud_frame(Rect2(918, 52, 345, 470), HUD)
	label_at(Vector2(931, 67), "PARTY", 15, GOLD)
	for i in night.heroes.size():
		var hero := night.heroes[i]
		var row := Rect2(929, 74 + i * 65, 323, 60)
		draw_hud_frame(row, Color("#263d3b") if active == hero else Color("#222d36"), TEAL if active == hero else Color("#8a7257"))
		draw_sprite(hero.title.to_lower(), row.position + Vector2(30, 30), 48.0)
		var hp := night.max_health(hero) if day != Day.NIGHT else hero.hp
		var hp_ratio := float(hp) / night.max_health(hero)
		label_at(row.position + Vector2(64, 22), "%d  %s   Lv. %d" % [i + 1, hero.title, hero.character.level], 17)
		label_at(row.position + Vector2(233, 22), "%d/%d HP" % [hp, night.max_health(hero)], 14, PAPER)
		draw_rect(Rect2(row.position + Vector2(64, 30), Vector2(249, 4)), Color("#100e12"))
		draw_rect(Rect2(row.position + Vector2(64, 30), Vector2(249 * hp_ratio, 4)), health_color(hp_ratio))
		var move := hero.movement if day == Day.NIGHT else night.movement_limit(hero)
		var ap := hero.ap if day == Day.NIGHT else Night.MAX_AP
		if hp > 0:
			draw_counter(row.position + Vector2(75, 46), move, Color("#76b8e8"), "MOVE")
			draw_counter(row.position + Vector2(158, 46), ap, Color("#eda65f"), "AP")
		else:
			label_at(row.position + Vector2(64, 51), "Downed", 15, MUTED)
		if hero.prepared and day == Day.NIGHT:
			label_at(row.position + Vector2(229, 51), "Ready", 14, GOLD)

func draw_loadout() -> void:
	var character := active.character
	label_at(Vector2(931, 312), "%s   •   XP %d / %d" % [active.title, character.xp, character.xp_goal()], 17, TEAL)
	label_at(Vector2(931, 337), "%d damage   •   Range %s" % [night.attack_damage(active), weapon_range(active)], 17)
	var y := 346
	var hovered_id := ""
	for slot: String in character.equipment:
		var id: String = character.equipment[slot]
		var rect := Rect2(930, y, 321, 25)
		draw_item_row(rect, id, slot.capitalize() + "  /  ")
		if rect.has_point(get_local_mouse_position()):
			hovered_id = id
		y += 27
	if not hovered_id.is_empty() and menu == Menu.CLOSED:
		var tooltip := Rect2(637, 346, 282, 55)
		draw_hud_frame(tooltip, Color("#221b21"), GOLD)
		var item := Journey.item_data(hovered_id)
		label_at(tooltip.position + Vector2(10, 20), "%s  /  %s" % [
			Journey.RARITY_NAMES[item.rarity], item.name], 14, Journey.RARITY_COLORS[item.rarity])
		label_at(tooltip.position + Vector2(10, 42), Journey.item_stats(hovered_id), 14)
	if active == night.priest:
		label_at(Vector2(931, 434), "Heal +%d HP   •   Revive 1 AP" % night.heal_power(), 14, MUTED)
	if character.shield_guard() > 0 or character.armor_guard() > 0:
		var protection := "Armor −%d" % character.armor_guard()
		if active == night.knight:
			protection = "Shield −%d   %s   Defend −%d extra" % [
				character.shield_guard(), protection, 1 + character.rank_of("guard")]
		label_at(Vector2(931, 447), protection, 14, MUTED)

func draw_sidebar() -> void:
	draw_party()
	if not pending_upgrades().is_empty():
		draw_hud_frame(Rect2(922, 284, 338, 250), Color("#201a23"))
		label_at(Vector2(938, 307), "LEVEL UP   /   %s" % active.title.to_upper(), 19, GOLD)
		label_at(Vector2(938, 328), "Choose one upgrade", 15, MUTED)
	else:
		draw_loadout()
		match night.phase:
			Night.Phase.VICTORY:
				label_at(Vector2(931, 468), "DAWN BREAKS", 21, GOLD)
			Night.Phase.DEFEAT:
				label_at(Vector2(931, 468), "THE DARKNESS WINS", 21, RED)
			Night.Phase.BUILD:
				label_at(Vector2(931, 446), "Build in firelight or click a defense to inspect.", 14, GOLD)
			_:
				label_at(Vector2(931, 456), "Attacks %d/%d   •   Hover a foe for intent." % [
					active.attacks, night.attack_limit(active)], 15, MUTED)
	label_at(Vector2(20, 708), night.message, 17, PAPER)

func draw_item_row(rect: Rect2, id: String, prefix := "", stats := false) -> void:
	draw_hud_frame(rect, Color("#242229"))
	if id.is_empty():
		label_at(rect.position + Vector2(33, 18), prefix + "Empty", 15, MUTED)
		return
	var item := Journey.item_data(id)
	var index := Journey.GEAR.keys().find(item.base_id)
	var icon_side := 21.0 if not stats else 32.0
	var icon := Rect2(rect.position + Vector2(4, (rect.size.y - icon_side) * 0.5), Vector2.ONE * icon_side)
	draw_texture_rect_region(ITEM_ATLAS, icon, Rect2(index * 48, 0, 48, 48))
	var text_x := 33 if not stats else 42
	var text_width := rect.size.x - text_x - 6.0
	var name_text: String = prefix + item.name
	var font := ThemeDB.fallback_font
	var name_width := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var name_size := mini(15, floori(15 * text_width / name_width))
	label_at(rect.position + Vector2(text_x, 18), name_text, name_size, Journey.RARITY_COLORS[item.rarity])
	if stats:
		var detail := Journey.item_stats(id)
		var detail_width := font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var detail_size := mini(13, floori(13 * text_width / detail_width))
		label_at(rect.position + Vector2(text_x, 35), detail, detail_size, MUTED)

func draw_day() -> void:
	if day == Day.ROAD or (day == Day.DUSK and not dusk_equipment):
		draw_road()
		return
	var titles := ["", "DAWN  /  BREAK CAMP", "DAY  /  ROADSIDE TRADER", "DUSK  /  MAKE CAMP", "DAY  /  JOURNEY COMPLETE"]
	label_at(Vector2(20, 27), titles[day], 16, GOLD)
	label_at(Vector2(920, 27), "DAYLIGHT  /  SAFE TO EQUIP", 16, GOLD)
	draw_hud_frame(Rect2(20, 48, 883, 615), HUD)
	if day == Day.MERCHANT:
		draw_texture_rect_region(SPRITES.merchant, Rect2(26, 54, 871, 160), Rect2(0, 25, 960, 176))
		label_at(Vector2(35, 242), "MERCHANT WARES", 19, GOLD)
		for i in SHOP.size():
			var id: String = SHOP[i]
			var y := 258 + i * 49
			if id in journey.stock:
				draw_item_row(Rect2(34, y, 281, 44), id, "", true)
			else:
				draw_item_row(Rect2(34, y, 281, 44), "", "Sold  /  ")
	else:
		label_at(Vector2(35, 90), "THE CARAVAN", 25, GOLD)
		label_at(Vector2(35, 125), "Pine Hollow   →   Roadside trader   →   Stoneford", 17)
		if day == Day.DAWN:
			label_at(Vector2(35, 154), "Salvaged %d items and 4 gold." % dawn_loot.size(), 16, MUTED)
	label_at(Vector2(451, 242), "CARAVAN STASH", 19, GOLD)
	label_at(Vector2(804, 242), "%d GOLD" % journey.gold, 16, GOLD)
	var first := stash_page * STASH_PAGE_SIZE
	for i in mini(STASH_PAGE_SIZE, journey.inventory.size() - first):
		draw_item_row(Rect2(451, 258 + i * 49, 236, 44), journey.inventory[first + i], "", true)
	if journey.inventory.is_empty():
		label_at(Vector2(451, 281), "The stash is empty.", 16, MUTED)
	if stash_pages() > 1:
		label_at(Vector2(643, 638), "%d / %d" % [stash_page + 1, stash_pages()], 16, GOLD)
	draw_party()
	draw_loadout()
	label_at(Vector2(20, 708), day_message, 17, PAPER)

func draw_road() -> void:
	var progress := clampf(travel_elapsed / TRAVEL_DURATION, 0.0, 1.0)
	var time := travel_elapsed
	draw_texture_rect(SPRITES.road, Rect2(-progress * 100, 0, 1380, 720), false)
	var sun := Vector2(890 - progress * 75, lerpf(110, 310, progress))
	draw_circle(sun, 41, Color(1, 0.55, 0.24, 0.16), true, -1, true)
	draw_circle(sun, 30, Color("#f5a567"), true, -1, true)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.13, 0.08, 0.21, 0.48 * progress))
	var wagon := Vector2(439 + progress * 116, 514)
	draw_sprite("wagon", wagon, 345.0)
	draw_wheel(wagon + Vector2(-93, 83), time, 28.0)
	draw_wheel(wagon + Vector2(18, 83), time, 28.0)
	var gait := [0, 1, 2, 1]
	var step: int = gait[int(time * 8.0) % gait.size()] if day == Day.ROAD else 0
	var horse := wagon + Vector2(248, 41)
	draw_sprite("horse_%d" % step, horse, 202.0)
	var hitch := wagon + Vector2(157, 55)
	var harness := horse + Vector2(-22, 1)
	draw_line(hitch, harness, Color("#241719"), 6.0, true)
	draw_line(hitch, harness, Color("#ae8455"), 2.0, true)
	draw_hud_frame(Rect2(22, 23, 415, 67), Color("#231d24"))
	label_at(Vector2(38, 49), "THE ROAD TO STONEFORD", 21, GOLD)
	label_at(Vector2(38, 73), "The sun is setting" if day == Day.ROAD else "Arrived at dusk", 16)
	draw_rect(Rect2(24, 674, 416, 8), Color("#211a22"))
	draw_rect(Rect2(24, 674, 416 * progress, 8), GOLD)
	label_at(Vector2(24, 709), day_message, 17)

func draw_wheel(at: Vector2, time: float, radius: float) -> void:
	draw_circle(at, radius, Color("#211719"), true, -1, true)
	draw_circle(at, radius - 5, Color("#614132"), true, -1, true)
	for i in 8:
		var edge := Vector2.from_angle(i * TAU / 8.0 + time * 4.2) * (radius - 4)
		draw_line(at, at + edge, Color("#c18a57"), 2.5, true)
	draw_arc(at, radius - 1, 0, TAU, 32, Color("#84614a"), 2, true)
	draw_circle(at, 5, Color("#302229"), true, -1, true)

func bless(tile: Vector2i) -> void:
	blessing_tile = tile
	blessing_until = clock + 0.55

func draw_effects() -> void:
	if blessing_until > clock:
		var strength := (blessing_until - clock) / 0.55
		var at := center(blessing_tile) + Vector2(0, -8 - (1.0 - strength) * 20.0)
		var light := Color(1.0, 0.84, 0.54, strength)
		draw_line(at + Vector2(-6, 0), at + Vector2(6, 0), light, 2, true)
		draw_line(at + Vector2(0, -6), at + Vector2(0, 6), light, 2, true)
	if arrow_progress < 1.0:
		var tip := arrow_from.lerp(arrow_to, arrow_progress)
		var tail := arrow_from.lerp(arrow_to, maxf(0.0, arrow_progress - 0.15))
		draw_line(tail, tip, arrow_color, 3, true)
	if hit_until > clock:
		var remaining := (hit_until - clock) / 0.23
		draw_arc(hit_position, lerpf(24, 8, remaining), 0, TAU, 24,
			Color(1.0, 0.79, 0.48, remaining), 2.5, true)
