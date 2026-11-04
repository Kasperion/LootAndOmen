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
	"range": ["Long Draw", "+1 bow range"],
	"move": ["Trail Runner", "+1 movement each turn"],
	"pin": ["Pinning Shot", "Unlock a shot that slows a survivor"],
	"health": ["Hardy", "+2 maximum and current HP"],
	"damage": ["Heavy Draw", "+1 damage on every bow shot"],
}
const LEVEL_OFFERS := [["range", "move", "pin"], ["health", "damage", "move"],
	["range", "health", "pin"]]

var site := 0
var level := 1
var xp := 0
var range_bonus := 0
var move_bonus := 0
var health_bonus := 0
var damage_bonus := 0
var has_pin := false
var gold := 4
var inventory: Array[String] = ["hunting_bow", "travel_coat"]
var equipment := {"bow": "hunting_bow", "armor": "travel_coat"}
var stock: Array[String] = ["war_bow", "hide_armor"]
var daylight := false
var trading := false

func xp_goal() -> int:
	return 12 + (level - 1) * 8

func level_choices() -> Array[String]:
	var choices: Array[String] = []
	if xp < xp_goal():
		return choices
	for id: String in LEVEL_OFFERS[(level - 1) % LEVEL_OFFERS.size()]:
		choices.append("damage" if id == "pin" and has_pin else id)
	return choices

func upgrade(id: String) -> bool:
	if id not in level_choices():
		return false
	xp -= xp_goal()
	level += 1
	match id:
		"range": range_bonus += 1
		"move": move_bonus += 1
		"health": health_bonus += 2
		"damage": damage_bonus += 1
		"pin": has_pin = true
	return true

func bow_range() -> int:
	return 5 + range_bonus + GEAR[equipment.bow][3]

func shot_damage() -> int:
	return 2 + damage_bonus + GEAR[equipment.bow][4]

func max_health() -> int:
	return 12 + health_bonus + GEAR[equipment.armor][5]

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
