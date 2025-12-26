class_name PolygonBoolean

## Subtracts a circle from a polygon using simplified bridge method
static func subtract_circle_from_polygon(
	polygon: PackedVector2Array,
	circle_center: Vector2,
	circle_radius: float,
	segments: int = 16
) -> PackedVector2Array:
	# Convert circle to polygon
	var circle_poly := _circle_to_polygon(circle_center, circle_radius, segments)
	
	# Create bridge between outer polygon and hole
	return _create_polygon_with_hole(polygon, circle_poly)

static func _circle_to_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := (float(i) / float(segments)) * TAU
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	return points

static func _create_polygon_with_hole(
	outer: PackedVector2Array,
	hole: PackedVector2Array
) -> PackedVector2Array:
	# Find closest points between outer and hole for bridge
	var bridge_outer_idx := _find_closest_point(outer, hole[0])
	
	# Build new outline: outer -> bridge -> hole (reversed) -> bridge -> continue outer
	var result := PackedVector2Array()
	
	# Add outer vertices up to bridge point
	for i in range(outer.size()):
		result.append(outer[i])
		
		if i == bridge_outer_idx:
			# Add hole vertices in reverse (for correct winding order)
			for j in range(hole.size() - 1, -1, -1):
				result.append(hole[j])
			
			# Bridge back to outer
			result.append(outer[bridge_outer_idx])
	
	return result

static func _find_closest_point(polygon: PackedVector2Array, target: Vector2) -> int:
	var closest_idx := 0
	var closest_dist := INF
	
	for i in range(polygon.size()):
		var dist := polygon[i].distance_to(target)
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i
	
	return closest_idx
