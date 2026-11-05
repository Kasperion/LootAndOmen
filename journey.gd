class_name LootJourney
extends RefCounted

const CAMPS := ["Pine Hollow", "Stoneford"]
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color("#ffffff"), Color("#92ce78"), Color("#80baf6"),
	Color("#c59af4"), Color("#ff8057")]
const LEGENDARY_CHANCE := 0.05
const AFFIXES := {
	"keen": ["Keen", {"damage": 1}, {"damage": 2}],
	"farshot": ["Farshot", {"max": 1}, {"max": 2}],
	"stout": ["Stout", {"health": 2}, {"health": 4}],
	"warded": ["Warded", {"guard": 1}, {"guard": 1, "health": 2}],
}
const SLOT_AFFIXES := {
	"bow": ["keen", "farshot"], "mace": ["keen"], "sword": ["keen"],
	"armor": ["stout", "warded"],
}
const SHOP := ["war_bow", "longbow", "iron_sword", "trail_charm"]
const GEAR := {
	"pilgrim_mace": {"name": "Pilgrim Mace", "slot": "mace", "min": 1, "max": 1, "damage": 3, "price": 0},
	"hunting_bow": {"name": "Hunting Bow", "slot": "bow", "min": 2, "max": 5, "damage": 2, "price": 0},
	"war_bow": {"name": "War Bow", "slot": "bow", "min": 2, "max": 6, "damage": 3, "price": 8},
	"longbow": {"name": "Longbow", "slot": "bow", "min": 2, "max": 7, "damage": 2, "price": 7},
	"travel_coat": {"name": "Travel Coat", "slot": "armor", "health": 0, "price": 0},
	"quilted_coat": {"name": "Quilted Coat", "slot": "armor", "health": 2, "price": 3},
	"short_sword": {"name": "Short Sword", "slot": "sword", "min": 1, "max": 1, "damage": 5, "price": 0},
	"iron_sword": {"name": "Iron Sword", "slot": "sword", "min": 1, "max": 1, "damage": 6, "price": 8},
	"ringmail": {"name": "Ringmail", "slot": "armor", "guard": 1, "price": 0},
	"trail_charm": {"name": "Trail Charm", "slot": "trinket", "movement": 1, "price": 6,
		"effect": "+1 movement each turn"},
	"ember_charm": {"name": "Ember Charm", "slot": "trinket", "wave_heal": 2, "price": 6,
		"effect": "Recover 2 HP on wave clear", "rarity": Rarity.RARE},
}
const UPGRADES := {
	"heal": ["Merciful Light", "+1 HP restored by Heal", 3],
	"range": ["Bow Range", "+1 maximum bow range, up to 10 total", 3],
	"move": ["Trail Runner", "+1 movement each turn", 3],
	"pin": ["Pinning Shot", "Unlock a bow attack that slows an enemy", 1],
	"health": ["Hardy", "+2 maximum and current HP", 3],
	"damage": ["Weapon Mastery", "+1 damage on weapon attacks", 3],
	"guard": ["Parry Drill", "+1 damage reduction when using Parry", 3],
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
		weapon_slot = String(slots.keys()[0])
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
		return LootJourney.item_data(equipment[weapon_slot])

	func max_range() -> int:
		return mini(10, int(weapon().max) + rank_of("range"))

	func max_health() -> int:
		var armor := LootJourney.item_data(equipment.get("armor", ""))
		return base_hp + rank_of("health") * 2 + armor.get("health", 0)

	func armor_guard() -> int:
		var armor := LootJourney.item_data(equipment.get("armor", ""))
		return armor.get("guard", 0)

	func trinket() -> Dictionary:
		return LootJourney.item_data(equipment.get("trinket", ""))

var ranger := Character.new("Ranger", 12, {"bow": "hunting_bow", "armor": "travel_coat", "trinket": ""},
	["range", "move", "pin", "damage", "health"])
var knight := Character.new("Knight", 18, {"sword": "short_sword", "armor": "ringmail", "trinket": ""},
	["damage", "guard", "health", "move"])
var priest := Character.new("Priest", 14, {"mace": "pilgrim_mace", "armor": "travel_coat", "trinket": ""},
	["heal", "health", "move", "damage"])
var site := 0
var gold := 4
var inventory: Array[String] = []
var stock: Array[String] = []
var daylight := false
var trading := false

func _init() -> void:
	stock.assign(SHOP)

static func upgrade_name(id: String, rank: int) -> String:
	var info: Array = UPGRADES[id]
	return info[0] if info[2] == 1 else "%s %s" % [info[0], ROMAN[rank - 1]]

static func roll_loot(base_id: String, boss: bool) -> String:
	if GEAR[base_id].slot == "trinket":
		return base_id
	var roll := randf()
	if boss and roll < LEGENDARY_CHANCE:
		return base_id + ":mawforged"
	var rarity := Rarity.UNCOMMON
	if boss:
		rarity = Rarity.EPIC if randf() < 0.25 else Rarity.RARE
	elif roll < 0.05:
		rarity = Rarity.EPIC
	elif roll < 0.25:
		rarity = Rarity.RARE
	if rarity == Rarity.UNCOMMON:
		return base_id
	var pool: Array = SLOT_AFFIXES[GEAR[base_id].slot]
	return "%s:%s:%d" % [base_id, pool.pick_random(), rarity]

static func item_data(id: String) -> Dictionary:
	var parts := id.split(":")
	if not GEAR.has(parts[0]):
		return {}
	var item: Dictionary = GEAR[parts[0]].duplicate()
	item["base_id"] = parts[0]
	item["rarity"] = item.get("rarity", Rarity.UNCOMMON if item.price > 0 else Rarity.COMMON)
	if parts.size() == 1:
		return item
	var bonus: Dictionary
	if parts[1] == "mawforged":
		item.rarity = Rarity.LEGENDARY
		item.name = "Mawforged " + item.name
		bonus = {"damage": 2, "kill_heal": 1} if item.has("damage") else {"health": 4, "guard": 1}
	else:
		item.rarity = int(parts[2])
		var affix: Array = AFFIXES[parts[1]]
		item.name = "%s %s" % [affix[0], item.name]
		bonus = affix[2 if item.rarity == Rarity.EPIC else 1]
	item.price += (item.rarity - Rarity.UNCOMMON) * 2
	for stat: String in bonus:
		item[stat] = item.get(stat, 0) + bonus[stat]
	return item

static func item_stats(id: String) -> String:
	var item := item_data(id)
	if item.has("effect"):
		return item.effect
	if item.has("damage"):
		var range_text := str(item.min) if item.min == item.max else "%d–%d" % [item.min, mini(10, item.max)]
		var detail := "%d dmg  •  %s range" % [item.damage, range_text]
		if item.has("kill_heal"):
			detail += "  •  +1 HP/kill"
		return detail
	var health: int = item.get("health", 0)
	if item.has("guard"):
		var detail := "%d melee guard" % item.guard
		if health > 0:
			detail += "  •  +%d max HP" % health
		return detail
	return "+%d max HP" % health

static func item_tooltip(id: String) -> String:
	var item := item_data(id)
	return "%s • %s\n%s" % [RARITY_NAMES[item.rarity], item.name, item_stats(id)]

func collect_loot(items: Array[String]) -> void:
	inventory.append_array(items)
	gold += 4

func can_equip(character: Character, index: int) -> bool:
	if not daylight or index < 0 or index >= inventory.size():
		return false
	var id := inventory[index]
	var slot: String = item_data(id).slot
	return character.equipment.has(slot) and character.equipment[slot] != id

func equip(character: Character, index: int) -> bool:
	if not can_equip(character, index):
		return false
	var id := inventory[index]
	var slot: String = item_data(id).slot
	var previous: String = character.equipment[slot]
	if previous.is_empty():
		inventory.remove_at(index)
	else:
		inventory[index] = previous
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
	return maxi(1, int(item_data(id).price) >> 1)
