# PlayerCamera.gd — Godot 4.5
extends Camera2D
class_name PlayerCamera

# --- World / chunk config ---
# Matched to MapLoader (1024) and MapScenery (6x)
const BASE_MAP_SIZE: float = 8196.0
const BASE_CHUNK_SIZE: float = 1024.0
const WORLD_SCALE: float = 6.0

const MAP_SIZE: float = BASE_MAP_SIZE * WORLD_SCALE
const CHUNK_SIZE: float = BASE_CHUNK_SIZE * WORLD_SCALE # 1024 * 6 = 6144

# Max View Width = 3 * CHUNK_SIZE
const MAX_SIGHT_WIDTH: float = 3.0 * CHUNK_SIZE

# Pan Radius: Allow panning around the loaded 5x5 grid (Radius 2)
# We allow going up to 2.0 chunks away from the player
const MAX_PAN_RADIUS: float = 2.0 * CHUNK_SIZE

# --- Player lookup ---
const BUS_SCENE_PATH: String = "res://Actors/Bus.tscn"

# --- Input Map action ---
const ACTION_DRAG: String = "cam_drag"

# --- Camera feel ---
@export var keyboard_pan_speed: float = 1350.0 # Reduced by ~66% (was 4000.0)
@export var mouse_pan_sensitivity: float = 1.0
@export var move_snap_threshold: float = 10.0

# Zoom Settings
@export var max_zoom_in: float = 2.0
@export var zoom_speed: float = 0.1

var _player: CharacterBody2D = null
var _pan_offset: Vector2 = Vector2.ZERO
var _dragging_mmb: bool = false
var _key_pan_active: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _target_zoom: float = 0.15 # Start reasonably zoomed out given massive world

# State for snapping
var _should_snap: bool = true

func _ready() -> void:
	_resolve_player()

	limit_left = 0
	limit_top = 0
	limit_right = int(MAP_SIZE)
	limit_bottom = int(MAP_SIZE)
	limit_smoothed = false

	# Initial zoom calculation
	_recalc_zoom_constraints()
	# Fallback safety if target zoom is way off
	if _target_zoom <= 0.0001: _target_zoom = 0.1
	zoom = Vector2(_target_zoom, _target_zoom)
	
	_last_mouse_pos = get_viewport().get_mouse_position()

func _process(delta: float) -> void:
	if _player == null:
		_resolve_player()
		
	# Smooth Zoom Interpolation
	var current_z = zoom.x
	if not is_equal_approx(current_z, _target_zoom):
		var new_z = lerp(current_z, _target_zoom, 10.0 * delta)
		zoom = Vector2(new_z, new_z)

	# --- MMB Drag ---
	var was_dragging: bool = _dragging_mmb
	_dragging_mmb = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	if _dragging_mmb and not was_dragging:
		_last_mouse_pos = get_viewport().get_mouse_position()
	
	if _dragging_mmb:
		_should_snap = false # User is manually panning
		
		var cur: Vector2 = get_viewport().get_mouse_position()
		var rel: Vector2 = _last_mouse_pos - cur
		_last_mouse_pos = cur
		
		# Adjust pan offset by relative movement / zoom
		_pan_offset += rel / zoom.x
		_clamp_pan_offset()
		
	# --- Keyboard Pan ---
	var dir: Vector2 = Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	_key_pan_active = dir.length() > 0.0
	if _key_pan_active:
		_should_snap = false # User is manually panning
		
		# Use zoom to make pan speed consistent on screen
		var z_factor = 1.0 / zoom.x
		_pan_offset += dir.normalized() * keyboard_pan_speed * z_factor * delta
		_clamp_pan_offset()

	# --- Snap logic ---
	# Only snap if explicitly requested (e.g. by new move command)
	if _should_snap and not _is_panning_active():
		_pan_offset = _pan_offset.lerp(Vector2.ZERO, 5.0 * delta)
		# If close enough, just zero it to stop processing
		if _pan_offset.length_squared() < 10.0:
			_pan_offset = Vector2.ZERO

	# --- Apply Position ---
	if _player != null:
		global_position = _player.global_position + _pan_offset

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_change_zoom(1.0 + zoom_speed)
				MOUSE_BUTTON_WHEEL_DOWN:
					_change_zoom(1.0 / (1.0 + zoom_speed))

# Public API called by Overworld/Input to reset camera
func snap_to_player() -> void:
	_should_snap = true

func _change_zoom(factor: float) -> void:
	var vp_width = float(get_viewport_rect().size.x)
	var min_zoom_limit = vp_width / MAX_SIGHT_WIDTH
	_target_zoom = clamp(_target_zoom * factor, min_zoom_limit, max_zoom_in)

func _recalc_zoom_constraints():
	var vp_width = float(get_viewport_rect().size.x)
	var min_zoom_limit = vp_width / MAX_SIGHT_WIDTH
	_target_zoom = clamp(_target_zoom, min_zoom_limit, max_zoom_in)

func _clamp_pan_offset() -> void:
	if _pan_offset.length() > MAX_PAN_RADIUS:
		_pan_offset = _pan_offset.normalized() * MAX_PAN_RADIUS

# --- Helpers ---
func _resolve_player() -> void:
	var root: Node = get_tree().root
	var candidates: Array[Node] = root.find_children("*", "CharacterBody2D", true, false)
	for n: Node in candidates:
		var path: String = n.get_scene_file_path()
		if path == BUS_SCENE_PATH:
			_player = n as CharacterBody2D
			return

func _is_player_moving() -> bool:
	if _player == null:
		return false
	return _player.velocity.length() > move_snap_threshold

func _is_panning_active() -> bool:
	return _dragging_mmb or _key_pan_active
