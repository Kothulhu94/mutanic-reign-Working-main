@tool
class_name Chunker
extends Node2D
##
## Chunker.gd — slice a large map texture into Sprite2D tiles (Godot 4.5)
## Attach to a Node2D (e.g., "Chunker") in your Overworld scene.

func _ready() -> void:
	if Engine.is_editor_hint():
		print("Chunker tool script loaded.")


# ---- Inputs ----
@export var texture: Texture2D
@export var chunk_size: Vector2i = Vector2i(512, 512)
@export var top_left_world: Vector2 = Vector2.ZERO # top-left world position

# Navigation settings for all chunks
@export var nav_layers: int = 1
@export var nav_travel_cost: float = 1.0
@export var nav_enter_cost: float = 0.0
@export var nav_use_edge_connections: bool = true
@export var nav_prefill_rect: bool = true # prefill each region as a full rect

# PNG baker settings
@export var target_folder: String = "res://chunks"
@export var file_prefix: String = "chunk"

# One-shot actions (editor buttons)
var _gen := false
@export var generate_chunks: bool:
	get:
		return _gen
	set(value):
		if value:
			_generate()
		_gen = false

var _bake := false
@export var bake_pngs: bool:
	get:
		return _bake
	set(value):
		if value:
			_bake_images()
		_bake = false

var _repoint := false
@export var repoint_to_pngs: bool:
	get:
		return _repoint
	set(value):
		if value:
			_repoint_textures()
		_repoint = false

var _regen_res := false
@export var regenerate_resources: bool:
	get:
		return _regen_res
	set(value):
		if value:
			_regenerate_resources()
		_regen_res = false

# ---- Helpers ----
func _clear_children() -> void:
	for child in get_children():
		child.queue_free()

# ---- Generation ----
func _generate() -> void:
	if texture == null:
		push_warning("Chunker: assign 'texture' first.")
		return

	_clear_children()

	var img_w: int = texture.get_width()
	var img_h: int = texture.get_height()
	var cols: int = int(ceil(float(img_w) / float(chunk_size.x)))
	var rows: int = int(ceil(float(img_h) / float(chunk_size.y)))
	var scene_owner := owner if owner != null else self

	for y in range(rows):
		for x in range(cols):
			var rpos := Vector2i(x * chunk_size.x, y * chunk_size.y)
			var rsize := Vector2i(
				min(chunk_size.x, img_w - rpos.x),
				min(chunk_size.y, img_h - rpos.y)
			)

			# ---- Sprite chunk ----
			var at := AtlasTexture.new()
			at.atlas = texture
			at.region = Rect2(Vector2(rpos), Vector2(rsize))

			var sprite := Sprite2D.new()
			sprite.name = "Sprite_%d_%d" % [x, y]
			sprite.centered = false
			sprite.texture = at
			sprite.position = top_left_world + Vector2(rpos)
			sprite.z_index = 0
			add_child(sprite)
			sprite.owner = scene_owner

			# ---- Navigation per chunk (child of the sprite; local (0,0)-(w,h)) ----
			var region := NavigationRegion2D.new()
			region.name = "Nav_%d_%d" % [x, y]
			region.navigation_layers = nav_layers
			region.travel_cost = nav_travel_cost
			region.enter_cost = nav_enter_cost
			region.use_edge_connections = nav_use_edge_connections
			region.enabled = true
			region.position = Vector2.ZERO
			sprite.add_child(region)
			region.owner = scene_owner

			if nav_prefill_rect:
				# Build a rectangular nav polygon with four editable corner points.
				var navpoly := NavigationPolygon.new()
				navpoly.resource_local_to_scene = true # keep unique + editable in this scene
				navpoly.agent_radius = 0.0 # remove auto offset
				navpoly.add_outline(PackedVector2Array([
					Vector2(0, 0),
					Vector2(rsize.x, 0),
					Vector2(rsize.x, rsize.y),
					Vector2(0, rsize.y)
				]))
				# Triangulate but keep the outline (editor shows white diamond handles).
				navpoly.make_polygons_from_outlines()
				region.navigation_polygon = navpoly

	print("Chunker: generated %dx%d = %d chunks" % [cols, rows, cols * rows])

# ---- PNG Baking ----
func _ensure_folder() -> void:
	var abs_path := ProjectSettings.globalize_path(target_folder)
	DirAccess.make_dir_recursive_absolute(abs_path)

func _bake_images() -> void:
	if texture == null:
		push_warning("Chunker: assign 'texture' first.")
		return

	_ensure_folder()
	var image := texture.get_image()
	var img_w: int = texture.get_width()
	var img_h: int = texture.get_height()
	var cols: int = int(ceil(float(img_w) / float(chunk_size.x)))
	var rows: int = int(ceil(float(img_h) / float(chunk_size.y)))

	for y in range(rows):
		for x in range(cols):
			var rpos := Vector2i(x * chunk_size.x, y * chunk_size.y)
			var rsize := Vector2i(
				min(chunk_size.x, img_w - rpos.x),
				min(chunk_size.y, img_h - rpos.y)
			)
			var sub := image.get_region(Rect2i(rpos, rsize))
			if sub.get_format() != Image.FORMAT_RGBA8:
				sub.convert(Image.FORMAT_RGBA8)
			var file_path := "%s/%s_%d_%d.png" % [target_folder, file_prefix, x, y]
			var err := sub.save_png(file_path)
			if err != OK:
				push_error("Chunker: save_png failed for %s" % file_path)
	print("Chunker: baked PNGs to %s" % target_folder)

# ---- Repoint Sprites to AtlasTextures (OPTIMIZED) ----
func _repoint_textures() -> void:
	# Walk Sprite children and point them at AtlasTexture resources for memory optimization.
	# AtlasTextures reference the compressed atlas, avoiding loading 256 separate textures into VRAM.
	var atlas_folder := "res://resources/map_chunks"
	
	for n in get_children():
		if n is Sprite2D and n.name.begins_with("Sprite_"):
			var parts := n.name.split("_")
			if parts.size() >= 3:
				var cx := parts[1].to_int()
				var cy := parts[2].to_int()
				
				# Try AtlasTexture first (memory-optimized path)
				var atlas_path := "%s/chunk_%d_%d.tres" % [atlas_folder, cx, cy]
				if ResourceLoader.exists(atlas_path):
					n.texture = load(atlas_path)
					continue
				
				# Fallback to PNG if .tres not found (backwards compatibility)
				var png_path := "%s/%s_%d_%d.png" % [target_folder, file_prefix, cx, cy]
				if ResourceLoader.exists(png_path):
					n.texture = load(png_path)
	
	print("Chunker: repointed sprites to AtlasTextures (memory optimized).")

func _regenerate_resources() -> void:
	if texture == null:
		push_warning("Chunker: assign 'texture' first.")
		return

	var atlas_folder := "res://resources/map_chunks"
	if not DirAccess.dir_exists_absolute(atlas_folder):
		DirAccess.make_dir_recursive_absolute(atlas_folder)

	var img_w: int = texture.get_width()
	var img_h: int = texture.get_height()
	var cols: int = int(ceil(float(img_w) / float(chunk_size.x)))
	var rows: int = int(ceil(float(img_h) / float(chunk_size.y)))

	print("Chunker: Regenerating %d AtlasTexture resources..." % [cols * rows])

	for y in range(rows):
		for x in range(cols):
			var rpos := Vector2i(x * chunk_size.x, y * chunk_size.y)
			var rsize := Vector2i(
				min(chunk_size.x, img_w - rpos.x),
				min(chunk_size.y, img_h - rpos.y)
			)

			var at := AtlasTexture.new()
			at.atlas = texture
			at.region = Rect2(Vector2(rpos), Vector2(rsize))

			var save_path := "%s/chunk_%d_%d.tres" % [atlas_folder, x, y]
			var err := ResourceSaver.save(at, save_path)
			if err != OK:
				push_error("Chunker: Failed to save %s" % save_path)
	
	print("Chunker: Done regenerating resources.")
