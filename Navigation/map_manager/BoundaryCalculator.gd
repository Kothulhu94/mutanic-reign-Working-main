class_name BoundaryCalculator
extends RefCounted

var _map_manager: Node2D
var _cell_size: Vector2i

func _init(map_manager: Node2D, cell_size: Vector2i):
	_map_manager = map_manager
	_cell_size = cell_size

func global_to_map(global_pos: Vector2) -> Vector2i:
	return Vector2i(_map_manager.to_local(global_pos)) / _cell_size

func get_nav_boundary_exit(start_pos: Vector2, target_pos: Vector2, active_grids: Dictionary) -> Vector2:
	var start_cell = global_to_map(start_pos)
	var current_grid = null
	
	for key in active_grids:
		var grid_data = active_grids[key]
		var a = grid_data["astars"][NavConstants.LAYER_LAND] # Default to Land for boundary checks
		if a.region.has_point(start_cell):
			if not a.is_point_solid(start_cell):
				current_grid = grid_data
				break
	
	if current_grid == null:
		return start_pos
		
	var center_chunk = current_grid["center"]
	var radius = current_grid["radius"]
	var shape = current_grid["shape"]
	
	var world_center = (Vector2(center_chunk) * float(NavConstants.CHUNK_SIZE)) + (Vector2(NavConstants.CHUNK_SIZE, NavConstants.CHUNK_SIZE) / 2.0)
	var extent = float(radius) * float(NavConstants.CHUNK_SIZE) + (float(NavConstants.CHUNK_SIZE) / 2.0)
	
	var relative_end = target_pos - world_center
	var relative_start = start_pos - world_center
	var dir = (relative_end - relative_start).normalized()
	var hit_point = target_pos
	
	if shape == NavConstants.GridShape.SQUARE:
		var t_min = - INF
		var t_max = INF
		var b_min = Vector2(-extent, -extent)
		var b_max = Vector2(extent, extent)
		
		# Check X slab
		if abs(dir.x) < 0.0001:
			if relative_start.x < b_min.x or relative_start.x > b_max.x:
				return start_pos # Outside
		else:
			var t1 = (b_min.x - relative_start.x) / dir.x
			var t2 = (b_max.x - relative_start.x) / dir.x
			t_min = max(t_min, min(t1, t2))
			t_max = min(t_max, max(t1, t2))
			
		# Check Y slab
		if abs(dir.y) < 0.0001:
			if relative_start.y < b_min.y or relative_start.y > b_max.y:
				return start_pos # Outside
		else:
			var t1 = (b_min.y - relative_start.y) / dir.y
			var t2 = (b_max.y - relative_start.y) / dir.y
			t_min = max(t_min, min(t1, t2))
			t_max = min(t_max, max(t1, t2))
			
		if t_max >= t_min and t_max > 0:
			var t_hit = max(t_min, t_max)
			hit_point = world_center + relative_start + dir * t_hit
			
	elif shape == NavConstants.GridShape.PLUS:
		# Simplified Plus
		var lines = [
			[Vector2(extent, 0), Vector2(0, extent)],
			[Vector2(0, extent), Vector2(-extent, 0)],
			[Vector2(-extent, 0), Vector2(0, -extent)],
			[Vector2(0, -extent), Vector2(extent, 0)]
		]
		
		var best_t = INF
		
		for line in lines:
			var p1 = line[0]
			var p2 = line[1]
			var intersection = Geometry2D.segment_intersects_segment(relative_start, relative_end, p1, p2)
			if intersection != null:
				var dist = relative_start.distance_to(intersection)
				if dist < best_t:
					best_t = dist
					hit_point = world_center + intersection
	
	var safety_margin = (start_pos - hit_point).normalized() * (_cell_size.x * 3.0)
	return hit_point + safety_margin

func get_nav_boundary_entry(target_pos: Vector2, from_pos: Vector2, active_grids: Dictionary) -> Vector2:
	# 1. Find grid containing target_pos
	var target_cell = global_to_map(target_pos)
	var target_grid = null
	
	for key in active_grids:
		var grid_data = active_grids[key]
		# Use LAND for boundary entry logic
		if grid_data["astars"][NavConstants.LAYER_LAND].region.has_point(target_cell):
			target_grid = grid_data
			break
			
	if target_grid == null:
		return target_pos
		
	# 2. Calculate intersection of line (from_pos -> target_pos) with that grid's bounds
	var center_chunk = target_grid["center"]
	var radius = target_grid["radius"]
	var shape = target_grid["shape"]
	
	var world_center = (Vector2(center_chunk) * float(NavConstants.CHUNK_SIZE)) + (Vector2(NavConstants.CHUNK_SIZE, NavConstants.CHUNK_SIZE) / 2.0)
	var extent = float(radius) * float(NavConstants.CHUNK_SIZE) + (float(NavConstants.CHUNK_SIZE) / 2.0)
	
	var relative_start = from_pos - world_center
	var relative_end = target_pos - world_center
	var dir = (relative_end - relative_start).normalized()
	
	var hit_point = target_pos # Fallback
	
	if shape == NavConstants.GridShape.SQUARE:
		var t_min = -1e20
		var t_max = 1e20
		var b_min = Vector2(-extent, -extent)
		var b_max = Vector2(extent, extent)
		
		if abs(dir.x) > 0.0001:
			var t1 = (b_min.x - relative_start.x) / dir.x
			var t2 = (b_max.x - relative_start.x) / dir.x
			var t_near = min(t1, t2)
			var t_far = max(t1, t2)
			t_min = max(t_min, t_near)
			t_max = min(t_max, t_far)
			
		if abs(dir.y) > 0.0001:
			var t1 = (b_min.y - relative_start.y) / dir.y
			var t2 = (b_max.y - relative_start.y) / dir.y
			var t_near = min(t1, t2)
			var t_far = max(t1, t2)
			t_min = max(t_min, t_near)
			t_max = min(t_max, t_far)
			
		if t_max >= t_min:
			if t_min > 0:
				hit_point = world_center + relative_start + dir * t_min
			else:
				hit_point = from_pos
				
	elif shape == NavConstants.GridShape.PLUS:
		var lines = [
			[Vector2(extent, 0), Vector2(0, extent)],
			[Vector2(0, extent), Vector2(-extent, 0)],
			[Vector2(-extent, 0), Vector2(0, -extent)],
			[Vector2(0, -extent), Vector2(extent, 0)]
		]
		
		var best_t = INF
		
		for line in lines:
			var p1 = line[0]
			var p2 = line[1]
			var intersection = Geometry2D.segment_intersects_segment(relative_start, relative_end, p1, p2)
			if intersection != null:
				var dist = relative_start.distance_to(intersection)
				if dist < best_t:
					best_t = dist
					hit_point = world_center + intersection
	
	var safety_margin = dir * (_cell_size.x * 2.0)
	return hit_point + safety_margin
