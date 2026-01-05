class_name GridMasker
extends RefCounted

static func apply_shape_mask(astars: Dictionary, grid_data: Dictionary, cell_size: Vector2i):
	if grid_data["shape"] != NavConstants.GridShape.PLUS:
		return
		
	var center_chunk = grid_data["center"]
	var radius = grid_data["radius"]
	# Use any astar reference to get region
	var r = astars[NavConstants.LAYER_LAND].region
	
	var start_chunk_x = floor(r.position.x * cell_size.x / float(NavConstants.CHUNK_SIZE))
	var start_chunk_y = floor(r.position.y * cell_size.y / float(NavConstants.CHUNK_SIZE))
	var end_chunk_x = floor(r.end.x * cell_size.x / float(NavConstants.CHUNK_SIZE))
	var end_chunk_y = floor(r.end.y * cell_size.y / float(NavConstants.CHUNK_SIZE))

	for cx in range(start_chunk_x, end_chunk_x + 1):
		for cy in range(start_chunk_y, end_chunk_y + 1):
			var dist = abs(cx - center_chunk.x) + abs(cy - center_chunk.y)
			if dist > radius:
				_set_chunk_solid(astars, cx, cy, cell_size)

static func _set_chunk_solid(astars: Dictionary, chunk_x: int, chunk_y: int, cell_size: Vector2i):
	var chunk_start_px = Vector2i(chunk_x, chunk_y) * NavConstants.CHUNK_SIZE
	var chunk_rect = Rect2i(chunk_start_px, Vector2i(NavConstants.CHUNK_SIZE, NavConstants.CHUNK_SIZE))
	
	# Assume all layers align
	var astar_ref = astars[NavConstants.LAYER_LAND]
	var region_rect_px = Rect2i(astar_ref.region.position * cell_size, astar_ref.region.size * cell_size)
	var intersection = chunk_rect.intersection(region_rect_px)
	
	if intersection.size == Vector2i.ZERO:
		return

	var start_cell = intersection.position / cell_size
	var end_cell = (intersection.position + intersection.size) / cell_size
	var rect = Rect2i(start_cell, end_cell - start_cell)

	for layer in astars:
		astars[layer].fill_solid_region(rect, true)
