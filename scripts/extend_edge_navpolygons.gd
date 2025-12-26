@tool
extends EditorScript

## Extends navigation polygons on the bottom row and rightmost column to reach map edges.
## This script will modify navigation polygons in chunks at y=15 and x=15 to extend
## to the full 512 or 320 pixel boundaries where needed.

func _run():
	var root = get_scene()
	var chunker = root.get_node_or_null("Chunker")
	
	if not chunker:
		print("ERROR: Chunker node not found!")
		return
	
	var modified_count = 0
	
	# Process bottom row (y = 15, rows 0-15)
	for x in range(16):
		var sprite_name = "Sprite_%d_15" % x
		var sprite = chunker.get_node_or_null(sprite_name)
		if sprite:
			var nav_name = "Nav_%d_15" % x
			var nav_region = sprite.get_node_or_null(nav_name)
			if nav_region and nav_region is NavigationRegion2D:
				if extend_navigation_polygon(nav_region, x, 15):
					modified_count += 1
					print("Extended %s/%s" % [sprite_name, nav_name])
	
	# Process rightmost column (x = 15, rows 0-14) - row 15 already processed above
	for y in range(15):
		var sprite_name = "Sprite_15_%d" % y
		var sprite = chunker.get_node_or_null(sprite_name)
		if sprite:
			var nav_name = "Nav_15_%d" % y
			var nav_region = sprite.get_node_or_null(nav_name)
			if nav_region and nav_region is NavigationRegion2D:
				if extend_navigation_polygon(nav_region, 15, y):
					modified_count += 1
					print("Extended %s/%s" % [sprite_name, nav_name])
	
	print("Complete! Extended %d navigation polygons." % modified_count)
	print("Please save the scene to persist changes.")

func extend_navigation_polygon(nav_region: NavigationRegion2D, chunk_x: int, _chunk_y: int) -> bool:
	var nav_poly = nav_region.navigation_polygon
	if not nav_poly:
		return false
	
	# Check if this is a custom polygon (has more than one outline - river areas have holes)
	# We want to preserve those
	var outlines = nav_poly.get_outline_count()
	if outlines > 1:
		print("  Skipping custom polygon with %d outlines (preserving river/custom areas)" % outlines)
		return false
	
	if outlines == 0:
		return false
	
	# Get the current outline
	var outline = nav_poly.get_outline(0)
	if outline.size() != 4:
		# Not a simple rectangle, might be custom
		print("  Skipping non-rectangular polygon with %d vertices" % outline.size())
		return false
	
	# Check if it's a standard rect (0,0), (w,0), (w,h), (0,h)
	var is_standard_rect = (
		outline[0].is_equal_approx(Vector2(0, 0)) and
		outline[1].x > 0 and outline[1].y == 0 and
		outline[2].x > 0 and outline[2].y > 0 and
		outline[3].x == 0 and outline[3].y > 0
	)
	
	if not is_standard_rect:
		print("  Skipping non-standard rectangle")
		return false
	
	var modified = false
	var new_outline = PackedVector2Array()
	
	# Determine the target size
	var target_width = 512.0
	var target_height = 512.0
	
	# Column 15 uses 320 width (8192 total map width = 16*512, last chunk at 7680, size 320 to reach 8000)
	if chunk_x == 15:
		target_width = 320.0
	
	# Create new outline
	new_outline.append(Vector2(0, 0))
	new_outline.append(Vector2(target_width, 0))
	new_outline.append(Vector2(target_width, target_height))
	new_outline.append(Vector2(0, target_height))
	
	# Check if modification is needed
	if not outline[2].is_equal_approx(Vector2(target_width, target_height)):
		nav_poly.clear_outlines()
		nav_poly.add_outline(new_outline)
		nav_poly.make_polygons_from_outlines()
		modified = true
		print("  Modified to size: %.0fx%.0f" % [target_width, target_height])
	
	return modified
