extends RefCounted

const CAMPS := ["Pine Hollow", "Stoneford"]
const GEAR := {
	"hunting_bow": {"name": "Hunting Bow", "slot": "bow", "min": 2, "max": 5, "damage": 2, "price": 0},
	"war_bow": {"name": "War Bow", "slot": "bow", "min": 2, "max": 6, "damage": 3, "price": 8},
	"longbow": {"name": "Longbow", "slot": "bow", "min": 2, "max": 7, "damage": 2, "price": 7},
	"travel_coat": {"name": "Travel Coat", "slot": "armor", "health": 0, "price": 0},
	"quilted_coat": {"name": "Quilted Coat", "slot": "armor", "health": 2, "price": 3},
	"short_sword": {"name": "Short Sword", "slot": "sword", "min": 1, "max": 1, "damage": 5, "price": 0},
	"iron_sword": {"name": "Iron Sword", "slot": "sword", "min": 1, "max": 1, "damage": 6, "price": 8},
	"militia_shield": {"name": "Militia Shield", "slot": "shield", "guard": 1, "price": 0},
	"ringmail": {"name": "Ringmail", "slot": "armor", "guard": 1, "price": 0},
	"reinforced_shield": {"name": "Reinforced Shield", "slot": "shield", "guard": 2, "price": 7},
}
const UPGRADES := {
	"range": ["Bow Range", "+1 maximum bow range, up to 8 total", 3],
	"move": ["Trail Runner", "+1 movement each turn", 3],
	"pin": ["Pinning Shot", "Unlock a bow attack that slows a survivor", 1],
	"health": ["Hardy", "+2 maximum and current HP", 3],
	"damage": ["Weapon Mastery", "+1 damage on weapon attacks", 3],
	"guard": ["Shield Drill", "+1 damage reduction when using Defend", 3],
}
const ROMAN := ["I", "II", "III"]

class Character:
	var title: String
	var level := 1
	var xp := 0
	var ranks: Dictionary = {}
	var equipment: Dictionary
	var weapon_slot: String
	var upgrades: Array[String]
	var base_hp: int

	func _init(hero_name: String, health: int, slots: Dictionary, options: Array[String]) -> void:
		title = hero_name
		base_hp = health
		equipment = slots
		weapon_slot = "bow" if slots.has("bow") else "sword"
		upgrades = options

	func xp_goal() -> int:
		return 12 + (level - 1) * 8

	func rank_of(id: String) -> int:
		return ranks.get(id, 0)

	func level_choices() -> Array[String]:
		var choices: Array[String] = []
		if xp < xp_goal():
			return choices
		for offset in upgrades.size():
			var id := upgrades[(offset + level - 1) % upgrades.size()]
			if rank_of(id) < UPGRADES[id][2]:
				choices.append(id)
				if choices.size() == 3:
					break
		return choices

	func upgrade(id: String) -> bool:
		if id not in level_choices():
			return false
		xp -= xp_goal()
		level += 1
		ranks[id] = rank_of(id) + 1
		return true

	func weapon() -> Dictionary:
		return GEAR[equipment[weapon_slot]]

	func max_range() -> int:
		return mini(8, int(weapon().max) + rank_of("range"))

	func max_health() -> int:
		var armor: Dictionary = GEAR.get(equipment.get("armor", ""), {})
		return base_hp + rank_of("health") * 2 + armor.get("health", 0)

	func armor_guard() -> int:
		var armor: Dictionary = GEAR.get(equipment.get("armor", ""), {})
		return armor.get("guard", 0)

	func shield_guard() -> int:
		var shield: Dictionary = GEAR.get(equipment.get("shield", ""), {})
		return shield.get("guard", 0)

var ranger := Character.new("Ranger", 12, {"bow": "hunting_bow", "armor": "travel_coat"},
	["range", "move", "pin", "damage", "health"])
var knight := Character.new("Knight", 18, {"sword": "short_sword", "shield": "militia_shield", "armor": "ringmail"},
	["damage", "guard", "health", "move"])
var site := 0
var gold := 4
var inventory: Array[String] = []
var stock: Array[String] = ["war_bow", "longbow", "iron_sword", "reinforced_shield"]
var daylight := false
var trading := false

static func upgrade_name(id: String, rank: int) -> String:
	var info: Array = UPGRADES[id]
	return info[0] if info[2] == 1 else "%s %s" % [info[0], ROMAN[rank - 1]]

static func item_stats(id: String) -> String:
	var item: Dictionary = GEAR[id]
	if item.has("damage"):
		var range_text := str(item.min) if item.min == item.max else "%d–%d" % [item.min, item.max]
		return "%d damage  •  %s range" % [item.damage, range_text]
	if item.has("guard"):
		return "%d melee damage reduction" % item.guard
	return "+%d maximum HP" % item.health

func collect_loot(items: Array[String]) -> void:
	inventory.append_array(items)
	gold += 4

func can_equip(character: Character, index: int) -> bool:
	if not daylight or index < 0 or index >= inventory.size():
		return false
	var id := inventory[index]
	var slot: String = GEAR[id].slot
	return character.equipment.has(slot) and character.equipment[slot] != id

func equip(character: Character, index: int) -> bool:
	if not can_equip(character, index):
		return false
	var id := inventory[index]
	var slot: String = GEAR[id].slot
	inventory[index] = character.equipment[slot]
	character.equipment[slot] = id
	return true

func buy(id: String) -> bool:
	if not trading or id not in stock or gold < GEAR[id].price:
		return false
	gold -= GEAR[id].price
	stock.erase(id)
	inventory.append(id)
	return true

func can_sell(index: int) -> bool:
	return trading and index >= 0 and index < inventory.size()

func sell(index: int) -> bool:
	if not can_sell(index):
		return false
	gold += sell_price(inventory[index])
	inventory.remove_at(index)
	return true

func sell_price(id: String) -> int:
	return maxi(1, int(GEAR[id].price) >> 1)
