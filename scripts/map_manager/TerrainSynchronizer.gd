class_name TerrainSynchronizer
extends RefCounted

static func sync_obstacles(astars: Dictionary, map_loader: Node, cell_size: Vector2i):
	if not map_loader or not "loaded_terrain_data" in map_loader:
		return
	
	var astar_ref = astars[NavConstants.LAYER_LAND]
	var r = astar_ref.region
	
	var start_chunk_x = floor(r.position.x * cell_size.x / float(NavConstants.CHUNK_SIZE))
	var start_chunk_y = floor(r.position.y * cell_size.y / float(NavConstants.CHUNK_SIZE))
	var end_chunk_x = floor(r.end.x * cell_size.x / float(NavConstants.CHUNK_SIZE))
	var end_chunk_y = floor(r.end.y * cell_size.y / float(NavConstants.CHUNK_SIZE))
	
	for cx in range(start_chunk_x, end_chunk_x + 1):
		for cy in range(start_chunk_y, end_chunk_y + 1):
			var chunk_coord = Vector2i(cx, cy)
			
			if not map_loader.loaded_terrain_data.has(chunk_coord):
				continue
				
			var img = map_loader.loaded_terrain_data[chunk_coord]
			if not img: continue
			
			var chunk_pixel_rect = Rect2i(cx * NavConstants.CHUNK_SIZE, cy * NavConstants.CHUNK_SIZE, NavConstants.CHUNK_SIZE, NavConstants.CHUNK_SIZE)
			var region_pixel_rect = Rect2i(r.position * cell_size, r.size * cell_size)
			var intersection = chunk_pixel_rect.intersection(region_pixel_rect)
			
			if intersection.size == Vector2i.ZERO:
				continue
			
			var ratio = img.get_width() / float(NavConstants.CHUNK_SIZE)
			var start_cell = intersection.position / cell_size
			var end_cell = (intersection.position + intersection.size) / cell_size
			
			for x in range(start_cell.x, end_cell.x):
				for y in range(start_cell.y, end_cell.y):
					var cell_pos = Vector2i(x, y)
					var world_px = cell_pos * cell_size + (cell_size / 2)
					var local_px = world_px - (Vector2i(cx, cy) * NavConstants.CHUNK_SIZE)
					
					var img_x = int(local_px.x * ratio)
					var img_y = int(local_px.y * ratio)
					
					img_x = clampi(img_x, 0, img.get_width() - 1)
					img_y = clampi(img_y, 0, img.get_height() - 1)
					
					var col = img.get_pixel(img_x, img_y)
					var terrain_id = int(round(col.r * 255.0))
					
					# Updated Terrain Checking with new IDs: 50, 100, 150
					
					# Optimization: Skip grass (0)
					if terrain_id < 10:
						continue # Grass (Walkable on all)
					
					if terrain_id >= 40 and terrain_id <= 60: # Sand (ID 50)
						if astars.has(NavConstants.LAYER_LAND): astars[NavConstants.LAYER_LAND].set_point_weight_scale(cell_pos, 1.25)
						if astars.has(NavConstants.LAYER_WATER): astars[NavConstants.LAYER_WATER].set_point_weight_scale(cell_pos, 1.25)
						if astars.has(NavConstants.LAYER_BUILDER): astars[NavConstants.LAYER_BUILDER].set_point_weight_scale(cell_pos, 1.25)
						
					elif terrain_id >= 90 and terrain_id <= 110: # Snow (ID 100)
						if astars.has(NavConstants.LAYER_LAND): astars[NavConstants.LAYER_LAND].set_point_weight_scale(cell_pos, 2.0)
						if astars.has(NavConstants.LAYER_WATER): astars[NavConstants.LAYER_WATER].set_point_weight_scale(cell_pos, 2.0)
						if astars.has(NavConstants.LAYER_BUILDER): astars[NavConstants.LAYER_BUILDER].set_point_weight_scale(cell_pos, 2.0)
						
					elif terrain_id >= 140 and terrain_id <= 160: # Water (ID 150)
						astars[NavConstants.LAYER_LAND].set_point_solid(cell_pos, true)
						# For Water Layer, it is walkable!
						if astars.has(NavConstants.LAYER_WATER):
							astars[NavConstants.LAYER_WATER].set_point_solid(cell_pos, false)
							astars[NavConstants.LAYER_WATER].set_point_weight_scale(cell_pos, 1.0)
							
						if astars.has(NavConstants.LAYER_BUILDER):
							astars[NavConstants.LAYER_BUILDER].set_point_solid(cell_pos, false)
							astars[NavConstants.LAYER_BUILDER].set_point_weight_scale(cell_pos, 12.0) # Very high cost to discourage unnecessary bridges
					
					# Catch old legacy values just in case (1, 2, 3)
					elif terrain_id == 1:
						if astars.has(NavConstants.LAYER_LAND): astars[NavConstants.LAYER_LAND].set_point_weight_scale(cell_pos, 1.25)
						if astars.has(NavConstants.LAYER_WATER): astars[NavConstants.LAYER_WATER].set_point_weight_scale(cell_pos, 1.25)
						if astars.has(NavConstants.LAYER_BUILDER): astars[NavConstants.LAYER_BUILDER].set_point_weight_scale(cell_pos, 1.25)
					elif terrain_id == 2:
						if astars.has(NavConstants.LAYER_LAND): astars[NavConstants.LAYER_LAND].set_point_weight_scale(cell_pos, 2.0)
						if astars.has(NavConstants.LAYER_WATER): astars[NavConstants.LAYER_WATER].set_point_weight_scale(cell_pos, 2.0)
						if astars.has(NavConstants.LAYER_BUILDER): astars[NavConstants.LAYER_BUILDER].set_point_weight_scale(cell_pos, 2.0)
					elif terrain_id == 3:
						if astars.has(NavConstants.LAYER_LAND): astars[NavConstants.LAYER_LAND].set_point_solid(cell_pos, true)
						if astars.has(NavConstants.LAYER_WATER):
							astars[NavConstants.LAYER_WATER].set_point_solid(cell_pos, false)
							astars[NavConstants.LAYER_WATER].set_point_weight_scale(cell_pos, 1.0)
						if astars.has(NavConstants.LAYER_BUILDER):
							astars[NavConstants.LAYER_BUILDER].set_point_solid(cell_pos, false)
							astars[NavConstants.LAYER_BUILDER].set_point_weight_scale(cell_pos, 2.0)
