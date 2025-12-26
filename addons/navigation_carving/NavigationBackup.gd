class_name NavigationBackup

# Global storage for original navigation polygons
static var _backups: Dictionary = {} # nav_region_path -> NavigationPolygon

## Backup original navigation polygon before any modifications
static func backup_region(nav_region: NavigationRegion2D) -> void:
	if nav_region == null or nav_region.navigation_polygon == null:
		return
	
	var path := nav_region.get_path()
	if _backups.has(path):
		return # Already backed up
	
	# Deep copy the navigation polygon
	# We use duplicate(true) to copy sub-resources and avoid manual reconstruction
	# which can trigger validation errors on complex existing polygons
	var backup := nav_region.navigation_polygon.duplicate(true)
	_backups[path] = backup
	
	print("[NavigationBackup] Backed up ", path)

## Restore original navigation polygon
static func restore_region(nav_region: NavigationRegion2D) -> bool:
	if nav_region == null:
		return false
	
	var path := nav_region.get_path()
	if not _backups.has(path):
		print("[NavigationBackup] No backup found for ", path)
		return false
	
	# Restore from backup
	var backup: NavigationPolygon = _backups[path]
	var restored := NavigationPolygon.new()
	
	for i in range(backup.get_outline_count()):
		restored.add_outline(backup.get_outline(i).duplicate())
	
	restored.make_polygons_from_outlines()
	nav_region.navigation_polygon = restored
	
	print("[NavigationBackup] Restored ", path)
	return true
