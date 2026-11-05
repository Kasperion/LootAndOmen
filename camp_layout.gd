extends RefCounted

const SIDES := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const FEATURES := ["Ruined church", "Ruined home", "Cliff", "Ravine", "River"]
const TREE_COUNT := 18
const ROCK_COUNT := 13

var random := RandomNumberGenerator.new()
var blocked_side: Vector2i
var feature: int
var barrier: Rect2i
var wagon: Rect2i
var trees: Dictionary = {}
var rocks: Dictionary = {}
var approaches: Array[Vector2i] = []
var board_size: Vector2i

func _init(size: Vector2i, fire: Vector2i, map_seed: int) -> void:
	board_size = size
	random.seed = map_seed
	blocked_side = SIDES[random.randi_range(0, SIDES.size() - 1)]
	feature = random.randi_range(0, FEATURES.size() - 1)
	var across := Vector2i(-blocked_side.y, blocked_side.x)
	barrier = span(fire + blocked_side * 3 - across * 5, fire + blocked_side * 4 + across * 5)
	wagon = span(fire + blocked_side * 2 - across, fire + blocked_side * 2 + across)
	for side: Vector2i in SIDES:
		if side != blocked_side:
			approaches.append(side)

	var placed := 0
	for attempt in 1600:
		var tile := Vector2i(random.randi_range(1, size.x - 2), random.randi_range(1, size.y - 2))
		var offset := tile - fire
		# Leave broad paths on the open approaches for the two-tile boss.
		if absi(offset.x) <= 2 or absi(offset.y) <= 2:
			continue
		if barrier.grow(1).has_point(tile) or near_prop(tile):
			continue
		if placed < TREE_COUNT:
			trees[tile] = placed % 5
		else:
			rocks[tile] = (placed - TREE_COUNT) % 3
		placed += 1
		if placed == TREE_COUNT + ROCK_COUNT:
			break

func span(first: Vector2i, last: Vector2i) -> Rect2i:
	var low := first.min(last)
	return Rect2i(low, first.max(last) - low + Vector2i.ONE)

func near_prop(tile: Vector2i) -> bool:
	for y in range(-1, 2):
		for x in range(-1, 2):
			var neighbor := tile + Vector2i(x, y)
			if trees.has(neighbor) or rocks.has(neighbor):
				return true
	return false

func blocked(tile: Vector2i) -> bool:
	return barrier.has_point(tile) or wagon.has_point(tile) or rocks.has(tile) or trees.has(tile)

func angle() -> float:
	return SIDES.find(blocked_side) * PI * 0.5

func feature_label() -> String:
	return "%s  /  %s" % [FEATURES[feature], ["North", "East", "South", "West"][SIDES.find(blocked_side)]]

func entry_cells(side: Vector2i, footprint: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var last := board_size - Vector2i.ONE * footprint
	for depth in range(1, 4):
		if side.x != 0:
			var x := depth if side.x < 0 else last.x - depth
			for y in range(2, last.y - 1):
				add_entry(cells, Vector2i(x, y), last)
		else:
			var y := depth if side.y < 0 else last.y - depth
			for x in range(2, last.x - 1):
				add_entry(cells, Vector2i(x, y), last)
	return cells

func add_entry(cells: Array[Vector2i], tile: Vector2i, last: Vector2i) -> void:
	# Corner entrances on an open side still keep clear of the closed edge.
	var depth := tile if blocked_side.x < 0 or blocked_side.y < 0 else last - tile
	var edge_distance := depth.x if blocked_side.x != 0 else depth.y
	if edge_distance >= 4:
		cells.append(tile)
