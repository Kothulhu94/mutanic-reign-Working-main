extends Area2D
class_name ClickAndFade

signal actor_entered(actor: Node)
signal actor_exited(actor: Node)
signal hub_clicked()

# Whitelist of actor scenes that should vanish while inside
@export var actor_scene_paths: Array[String] = [
	"res://Actors/Bus.tscn",
	"res://Actors/NPC.tscn" # add more as needed
]

var _prev_visible: Dictionary = {}
var _bus_inside: bool = false
var _bus_node: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	input_event.connect(_on_input_event)

	# Check for bodies already overlapping at startup
	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _on_body_entered(body: Node) -> void:
	var p := body.get_scene_file_path()
	if actor_scene_paths.has(p):
		_prev_visible[body] = (body as CanvasItem).visible if body is CanvasItem else true
		if body is CanvasItem:
			(body as CanvasItem).visible = false

		# Track if this is the Bus
		if p == "res://Actors/Bus.tscn":
			_bus_inside = true
			_bus_node = body

		emit_signal("actor_entered", body)

func _on_body_exited(body: Node) -> void:
	if _prev_visible.has(body):
		if body is CanvasItem:
			(body as CanvasItem).visible = _prev_visible[body]
		_prev_visible.erase(body)

		# Track if Bus exited
		if body == _bus_node:
			_bus_inside = false
			_bus_node = null

		emit_signal("actor_exited", body)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Detect clicks on the hub area
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			hub_clicked.emit()

## Returns true if the Bus is currently inside this area
func is_bus_inside() -> bool:
	return _bus_inside

## Returns the Bus node if it's inside, null otherwise
func get_bus_node() -> Node:
	return _bus_node if _bus_inside else null
