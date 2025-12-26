# PlayerCamera.gd — Godot 4.5 (adds robust cam_drag / MMB drag)
extends Camera2D
class_name PlayerCamera

# --- World / chunk config ---
const BASE_MAP_SIZE: float   = 8196.0
const BASE_CHUNK_SIZE: float = 512.0
const WORLD_SCALE: float     = 6.0

const MAP_SIZE: float       = BASE_MAP_SIZE   * WORLD_SCALE      # 49_176
const CHUNK_SIZE: float     = BASE_CHUNK_SIZE * WORLD_SCALE      # 3_072
const MAX_PAN_RADIUS: float = CHUNK_SIZE * 1.5                   # 4_608

# --- Player lookup strictly by file path ---
const BUS_SCENE_PATH: String = "res://Actors/Bus.tscn"

# --- Input Map action for MMB drag ---
const ACTION_DRAG: String = "cam_drag"

# --- Camera feel ---
@export var keyboard_pan_speed: float = 1400.0
@export var mouse_pan_sensitivity: float = 4.0
@export var move_snap_threshold: float = 1.0

# Zoom rails (plus dynamic cap so you never see past 1.5 chunks to the edge)
@export var min_zoom_scalar: float = .01
@export var hard_max_zoom_scalar: float = 2.0

var _player: CharacterBody2D = null
var _pan_offset: Vector2 = Vector2.ZERO
var _dragging_mmb: bool = false
var _key_pan_active: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_resolve_player()

	limit_left = 0
	limit_top = 0
	limit_right = int(MAP_SIZE)
	limit_bottom = int(MAP_SIZE)
	limit_smoothed = false

	zoom = Vector2.ONE
	_last_mouse_pos = get_viewport().get_mouse_position()
	_clamp_zoom_to_view_radius()

func _process(delta: float) -> void:
	if _player == null:
		_resolve_player()

	# --- MMB drag: poll the action every frame and compute delta robustly
	var was_dragging: bool = _dragging_mmb
	_dragging_mmb = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	if _dragging_mmb and not was_dragging:
		_last_mouse_pos = get_viewport().get_mouse_position()  # avoid first-frame jump
	if _dragging_mmb:
		var cur: Vector2 = get_viewport().get_mouse_position()
		var rel: Vector2 = cur - _last_mouse_pos
		_last_mouse_pos = cur
		var gs: Vector2 = get_global_transform().get_scale().abs() # parent/world scale
		var z: Vector2 = zoom
		_pan_offset -= Vector2(rel.x * z.x / gs.x, rel.y * z.y / gs.y) * mouse_pan_sensitivity
		_clamp_pan_offset()

	# --- Keyboard pan (works whether the bus is moving or not)
	var dir: Vector2 = Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	_key_pan_active = dir.length() > 0.0
	if _key_pan_active:
		_pan_offset += dir.normalized() * keyboard_pan_speed * delta
		_clamp_pan_offset()

	# --- Snap logic:
	# If the bus is moving and there is NO active pan (no keys, not dragging), snap back.
	# NOTE: Only snap back if player is actively moving (velocity > threshold), not just drifting
	if _player != null and _is_player_moving() and not _is_panning_active():
		# Gradually lerp back instead of instant snap for smoother feel
		_pan_offset = _pan_offset.lerp(Vector2.ZERO, 5.0 * delta)

	# Follow bus + user pan offset
	if _player != null:
		global_position = _player.global_position + _pan_offset

	_clamp_zoom_to_view_radius()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_apply_zoom_step(1.0 / 0.9) # UP -> zoom OUT
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_apply_zoom_step(0.9)      # DOWN -> zoom IN

# --- Player resolution: ONLY by file path ---
func _resolve_player() -> void:
	var root: Node = get_tree().root
	var candidates: Array[Node] = root.find_children("*", "CharacterBody2D", true, false)
	for n: Node in candidates:
		var path: String = n.get_scene_file_path()
		if path == BUS_SCENE_PATH:
			_player = n as CharacterBody2D
			return

# --- Helpers ---
func _is_player_moving() -> bool:
	if _player == null:
		return false
	return _player.velocity.length() > move_snap_threshold

func _is_panning_active() -> bool:
	return _dragging_mmb or _key_pan_active

func _clamp_pan_offset() -> void:
	if _pan_offset.length() > MAX_PAN_RADIUS:
		_pan_offset = _pan_offset.normalized() * MAX_PAN_RADIUS

func _apply_zoom_step(factor: float) -> void:
	var z: float = clamp(zoom.x * factor, min_zoom_scalar, hard_max_zoom_scalar)
	zoom = Vector2(z, z)
	_clamp_zoom_to_view_radius()

func _clamp_zoom_to_view_radius() -> void:
	var vp_i: Vector2i = get_viewport_rect().size
	if vp_i.x <= 0 or vp_i.y <= 0:
		return
	var vp: Vector2 = Vector2(vp_i)
	var max_zoom_x: float = (MAX_PAN_RADIUS * 2.0) / vp.x
	var max_zoom_y: float = (MAX_PAN_RADIUS * 2.0) / vp.y
	var dynamic_max: float = min(max_zoom_x, max_zoom_y)
	var z: float = clamp(zoom.x, min_zoom_scalar, min(dynamic_max, hard_max_zoom_scalar))
	zoom = Vector2(z, z)
