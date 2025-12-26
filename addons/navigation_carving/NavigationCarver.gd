class_name NavigationCarver

## Carves a circular hole in a NavigationRegion2D
## Carves a circular hole in a NavigationRegion2D
## Carves a circular hole in a NavigationRegion2D
## Carves a circular hole in a NavigationRegion2D
static func carve_circle(
	nav_region: NavigationRegion2D,
	world_position: Vector2,
	radius: float
) -> bool:
	if nav_region == null or nav_region.navigation_polygon == null:
		print("[NavigationCarver] Invalid nav_region or navigation_polygon")
		return false
	
	var nav_poly: NavigationPolygon = nav_region.navigation_polygon
	var local_pos := nav_region.to_local(world_position)
	var circle_poly := _create_circle_polygon(local_pos, radius)
	
	# 1. Classify existing outlines into Solids and Voids
	var solids: Array[PackedVector2Array] = []
	var voids: Array[PackedVector2Array] = []
	_classify_outlines(nav_poly, solids, voids)
	
	# 2. Add the new hole to the voids list
	voids.append(circle_poly)
	
	# 3. Merge all voids into a set of disjoint polygons
	# This handles overlapping holes (existing or new)
	var merged_voids := _merge_all_polygons(voids)
	
	# 4. Process Voids against Solids
	# If a void is fully inside a solid, keep it as a separate hole outline.
	# If a void intersects the edge, clip the solid (modify the solid).
	
	var final_solids: Array[PackedVector2Array] = solids
	var final_holes: Array[PackedVector2Array] = []
	
	for void_poly in merged_voids:
		var next_pass_solids: Array[PackedVector2Array] = []
		var void_consumed := false
		
		for solid in final_solids:
			if _is_poly_inside_poly(void_poly, solid):
				# Void is fully inside this solid
				# Keep it as a separate hole outline
				final_holes.append(void_poly)
				next_pass_solids.append(solid)
				void_consumed = true
			elif _polys_intersect(void_poly, solid):
				# Void intersects the edge (bay/inlet) or splits the solid
				# Clip it from the solid
				var clipped := Geometry2D.clip_polygons(solid, void_poly)
				next_pass_solids.append_array(clipped)
				void_consumed = true
			else:
				# No interaction
				next_pass_solids.append(solid)
		
		final_solids = next_pass_solids
		
		# If void wasn't inside or intersecting any solid, it's outside (ignore)
	
	# 5. Validate and Sort results
	# Ensure correct winding order (Clockwise for all in Godot NavPoly)
	for i in range(final_solids.size()):
		if not Geometry2D.is_polygon_clockwise(final_solids[i]):
			final_solids[i].reverse()
			
	for i in range(final_holes.size()):
		if not Geometry2D.is_polygon_clockwise(final_holes[i]):
			final_holes[i].reverse()
	
	# Sort solids by area (largest first)
	final_solids.sort_custom(func(a, b): return _get_area(a) > _get_area(b))
	
	# 6. Rebuild NavigationPolygon
	nav_poly.clear()
	
	# Create source geometry data for baking
	var source_geometry := NavigationMeshSourceGeometryData2D.new()
	
	# Add solids
	for solid in final_solids:
		if solid.size() >= 3:
			nav_poly.add_outline(solid) # Store for future retrieval
			source_geometry.add_traversable_outline(solid)
		
	# Add holes
	for hole in final_holes:
		if hole.size() >= 3:
			nav_poly.add_outline(hole) # Store for future retrieval
			source_geometry.add_obstruction_outline(hole)
	
	nav_poly.agent_radius = 0.0
	
	# Bake using NavigationServer2D (replaces deprecated make_polygons_from_outlines)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geometry)
	
	nav_region.navigation_polygon = nav_poly
	print("[NavigationCarver] Successfully carved hole at ", world_position)
	return true

static func _classify_outlines(nav_poly: NavigationPolygon, solids: Array, voids: Array) -> void:
	var outlines: Array[PackedVector2Array] = []
	for i in range(nav_poly.get_outline_count()):
		outlines.append(nav_poly.get_outline(i))
	
	# A simple heuristic: 
	# If a polygon is inside another, it's a hole (void).
	# If it's not inside any other, it's a solid.
	# This supports nested islands, but not holes-inside-holes (which NavPoly doesn't support well anyway).
	
	for i in range(outlines.size()):
		var poly_a := outlines[i]
		var is_inside_another := false
		
		for j in range(outlines.size()):
			if i == j: continue
			var poly_b := outlines[j]
			if Geometry2D.is_point_in_polygon(poly_a[0], poly_b):
				# Quick check: if first point is inside, assume whole poly is inside
				# (Valid for non-intersecting outlines)
				is_inside_another = true
				break
		
		if is_inside_another:
			voids.append(poly_a)
		else:
			solids.append(poly_a)

static func _merge_all_polygons(polys: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	if polys.is_empty():
		return []
		
	var merged: Array[PackedVector2Array] = []
	
	# Iteratively merge
	for p in polys:
		if merged.is_empty():
			merged.append(p)
			continue
			
		var current_poly := p
		var did_merge := true
		
		while did_merge:
			did_merge = false
			var new_merged: Array[PackedVector2Array] = []
			
			# Check current_poly against all in merged
			var intersected := false
			for i in range(merged.size()):
				var m := merged[i]
				var union_result := Geometry2D.merge_polygons(current_poly, m)
				
				if union_result.size() == 1:
					# Successfully merged into one
					current_poly = union_result[0]
					intersected = true
					did_merge = true
					# We consumed 'm', so don't add it to new_merged
				else:
					# Disjoint or complex merge (failed to unify)
					# Keep 'm'
					new_merged.append(m)
			
			if intersected:
				merged = new_merged
				# Loop again to see if the new current_poly overlaps others
			else:
				# No intersection with any existing
				merged.append(current_poly)
				break
				
	return merged

static func _create_circle_polygon(center: Vector2, radius: float, segments: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	var step := TAU / segments
	for i in range(segments):
		var angle := i * step
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _get_area(poly: PackedVector2Array) -> float:
	# Shoelace formula
	var area := 0.0
	for i in range(poly.size()):
		var j := (i + 1) % poly.size()
		area += poly[i].x * poly[j].y
		area -= poly[j].x * poly[i].y
	return abs(area) / 2.0

static func _is_poly_inside_poly(inner: PackedVector2Array, outer: PackedVector2Array) -> bool:
	for point in inner:
		if not Geometry2D.is_point_in_polygon(point, outer):
			return false
	return true

static func _polys_intersect(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var result := Geometry2D.intersect_polygons(a, b)
	return result.size() > 0
