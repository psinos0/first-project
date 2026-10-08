class_name FactoryCamera
extends Node3D
## Strategic desktop/mobile camera: bounded pan, smooth orbit/zoom and tap-vs-drag threshold.

signal world_tapped(screen_position: Vector2)

@export var min_distance := 12.0
@export var max_distance := 40.0
@export var pan_bounds := Vector2(8.0, 5.0)
var target := Vector3(0.0, 0.8, 0.0)
var target_yaw := 0.72
var target_pitch := -0.72
var target_distance := 32.0
var _yaw := target_yaw
var _pitch := target_pitch
var _distance := target_distance
var _drag_origin := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _dragging := false
var _drag_distance := 0.0
var _touches: Dictionary = {}
var _pinch_distance := 0.0
var camera: Camera3D

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "StrategicCamera"
	camera.fov = 42.0
	camera.near = 0.15
	camera.far = 120.0
	add_child(camera)
	_update_transform(1.0)

func _process(delta: float) -> void:
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if keyboard.length_squared() > 0.0:
		_pan(keyboard * delta * _distance * 0.75)
	if Input.is_key_pressed(KEY_Q):
		target_yaw += delta * 0.9
	if Input.is_key_pressed(KEY_E):
		target_yaw -= delta * 0.9
	_update_transform(delta)

func _update_transform(delta: float) -> void:
	var blend := 1.0 - exp(-delta * 8.0)
	_yaw = lerp_angle(_yaw, target_yaw, blend)
	_pitch = lerpf(_pitch, target_pitch, blend)
	_distance = lerpf(_distance, target_distance, blend)
	var offset := Vector3(0.0, 0.0, _distance)
	offset = offset.rotated(Vector3.RIGHT, _pitch)
	offset = offset.rotated(Vector3.UP, _yaw)
	global_position = target + offset
	look_at(target, Vector3.UP)

func focus(point: Vector3, distance: float = 15.0) -> void:
	target.x = clampf(point.x, -pan_bounds.x, pan_bounds.x)
	target.z = clampf(point.z, -pan_bounds.y, pan_bounds.y)
	target_distance = clampf(distance, min_distance, max_distance)

func overview() -> void:
	target = Vector3(0.0, 0.8, 0.0)
	target_yaw = 0.72
	target_pitch = -0.72
	target_distance = 32.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance = maxf(min_distance, target_distance - 1.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance = minf(max_distance, target_distance + 1.4)
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_origin = event.position
				_last_pointer = event.position
				_dragging = true
				_drag_distance = 0.0
			else:
				if event.button_index == MOUSE_BUTTON_LEFT and _drag_distance < 9.0:
					world_tapped.emit(event.position)
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.position - _last_pointer
		_last_pointer = event.position
		_drag_distance += delta.length()
		_pan(-delta * 0.012 * (_distance / 18.0))
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_drag_origin = event.position
			_last_pointer = event.position
			_drag_distance = 0.0
		else:
			if _touches.size() == 1 and _drag_distance < 12.0:
				world_tapped.emit(event.position)
			_touches.erase(event.index)
			_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_drag_distance += event.relative.length()
			_pan(-event.relative * 0.013 * (_distance / 18.0))
		elif _touches.size() == 2:
			var points: Array = _touches.values()
			var separation: float = Vector2(points[0]).distance_to(Vector2(points[1]))
			if _pinch_distance > 0.0:
				target_distance = clampf(target_distance - (separation - _pinch_distance) * 0.018, min_distance, max_distance)
			_pinch_distance = separation

func _pan(screen_delta: Vector2) -> void:
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var forward := Vector3(sin(_yaw), 0.0, cos(_yaw))
	target += right * screen_delta.x + forward * screen_delta.y
	target.x = clampf(target.x, -pan_bounds.x, pan_bounds.x)
	target.z = clampf(target.z, -pan_bounds.y, pan_bounds.y)
