extends Node
## Coarse deterministic A* grid for AI. World coordinates are converted to 200-unit cells.
const CELL_SIZE := Vector2i(200, 200)
const GRID_REGION := Rect2i(0, 0, 130, 70)
var grid := AStarGrid2D.new()
var configured := false

func configure(obstacles: Array[Rect2]) -> void:
	grid.region = GRID_REGION
	grid.cell_size = CELL_SIZE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for obstacle: Rect2 in obstacles:
		var first := world_to_cell(obstacle.position)
		var last := world_to_cell(obstacle.end)
		for x: int in range(first.x, last.x + 1):
			for y: int in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				if grid.is_in_boundsv(cell): grid.set_point_solid(cell, true)
	configured = true

func next_point(from: Vector2, target: Vector2) -> Vector2:
	if not configured: return target
	var start := world_to_cell(from)
	var end := world_to_cell(target)
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(end): return target
	var path: Array[Vector2i] = grid.get_id_path(start, end, true)
	if path.size() < 2: return target
	return cell_to_world(path[1])

func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / float(CELL_SIZE.x)), floori(position.y / float(CELL_SIZE.y)))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x * CELL_SIZE.x + CELL_SIZE.x / 2), float(cell.y * CELL_SIZE.y + CELL_SIZE.y / 2))
