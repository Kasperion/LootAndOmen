extends RefCounted

const CAMPS := ["Pine Hollow", "Stoneford"]
const GEAR := {
	"hunting_bow": ["Hunting Bow", "bow", "Standard bow", 0, 0, 0, 0],
	"travel_coat": ["Travel Coat", "armor", "Standard armor", 0, 0, 0, 0],
	"scout_bow": ["Scout Bow", "bow", "+1 bow range", 1, 0, 0, 3],
	"quilted_coat": ["Quilted Coat", "armor", "+2 max HP", 0, 0, 2, 3],
	"war_bow": ["War Bow", "bow", "+1 shot damage", 0, 1, 0, 8],
	"hide_armor": ["Hide Armor", "armor", "+4 max HP", 0, 0, 4, 7],
}
const UPGRADES := {
	"range": ["Bow Range", "+1 bow range, up to 8 total", 3],
	"move": ["Trail Runner", "+1 Ranger movement per turn", 3],
	"pin": ["Pinning Shot", "Unlock a bow attack that slows a survivor", 1],
	"health": ["Hardy", "+2 Ranger maximum and current HP", 3],
	"damage": ["Heavy Draw", "+1 damage on Ranger bow attacks", 3],
	"knight_health": ["Shield Veteran", "+2 Knight maximum and current HP", 3],
	"knight_damage": ["Sword Mastery", "+1 Knight sword damage", 3],
}
const LEVEL_OFFERS := [
	["range", "move", "pin", "knight_health", "damage", "knight_damage", "health"],
	["knight_health", "damage", "knight_damage", "health", "move", "range", "pin"],
	["range", "health", "knight_damage", "pin", "move", "knight_health", "damage"],
]
const ROMAN := ["I", "II", "III"]

var site := 0
var level := 1
var xp := 0
var ranks: Dictionary = {}
var gold := 4
var inventory: Array[String] = ["hunting_bow", "travel_coat"]
var equipment := {"bow": "hunting_bow", "armor": "travel_coat"}
var stock: Array[String] = ["war_bow", "hide_armor"]
var daylight := false
var trading := false

func xp_goal() -> int:
	return 12 + (level - 1) * 8

func rank_of(id: String) -> int:
	return ranks.get(id, 0)

func level_choices() -> Array[String]:
	var choices: Array[String] = []
	if xp < xp_goal():
		return choices
	for id: String in LEVEL_OFFERS[(level - 1) % LEVEL_OFFERS.size()]:
		if rank_of(id) < UPGRADES[id][2]:
			choices.append(id)
			if choices.size() == 3:
				break
	return choices

func upgrade_name(id: String, rank: int) -> String:
	var info: Array = UPGRADES[id]
	return info[0] if info[2] == 1 else "%s %s" % [info[0], ROMAN[rank - 1]]

func upgrade(id: String) -> bool:
	if id not in level_choices():
		return false
	xp -= xp_goal()
	level += 1
	ranks[id] = rank_of(id) + 1
	return true

func bow_range() -> int:
	return mini(8, 5 + rank_of("range") + GEAR[equipment.bow][3])

func shot_damage() -> int:
	return 2 + rank_of("damage") + GEAR[equipment.bow][4]

func max_health() -> int:
	return 12 + rank_of("health") * 2 + GEAR[equipment.armor][5]

func collect_loot(items: Array[String]) -> void:
	inventory.append_array(items)
	gold += 4

func equip(index: int) -> bool:
	if not daylight or index < 0 or index >= inventory.size():
		return false
	var id := inventory[index]
	equipment[GEAR[id][1]] = id
	return true

func is_equipped(id: String) -> bool:
	return equipment[GEAR[id][1]] == id

func buy(id: String) -> bool:
	if not trading or id not in stock or gold < GEAR[id][6]:
		return false
	gold -= GEAR[id][6]
	stock.erase(id)
	inventory.append(id)
	return true

func can_sell(index: int) -> bool:
	if not trading or index < 0 or index >= inventory.size():
		return false
	var id := inventory[index]
	return not is_equipped(id) or inventory.count(id) > 1

func sell(index: int) -> bool:
	if not can_sell(index):
		return false
	var id := inventory[index]
	gold += sell_price(id)
	inventory.remove_at(index)
	return true

func sell_price(id: String) -> int:
	return maxi(1, int(GEAR[id][6]) / 2)
