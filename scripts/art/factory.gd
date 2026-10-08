extends IsoArt

signal station_selected(index: int)
const STATION_SCENE := preload("res://scenes/station.tscn")
const POSITIONS := [Vector2(2.15, 3.5), Vector2(4.65, 2.5), Vector2(7.55, 3.3), Vector2(7.65, 6.1)]
var machines: Array[Node2D] = []
var selected := -1
var time := 0.0
var interactive := false

func _ready() -> void:
	for i in range(4):
		var machine := STATION_SCENE.instantiate()
		machine.index = i
		machine.position = iso(POSITIONS[i].x, POSITIONS[i].y)
		machine.z_index = int(POSITIONS[i].x + POSITIONS[i].y) + 1
		add_child(machine)
		machines.append(machine)

func _process(delta: float) -> void:
	if not Game.reduced_motion:
		time += delta
	var mouse := get_local_mouse_position()
	for machine in machines:
		machine.hovered = interactive and Rect2(machine.position - Vector2(90, 140), Vector2(180, 180)).has_point(mouse)
	queue_redraw()

func fit_to(rect: Rect2) -> void:
	# Entire artwork including walls fits the viewport without cropping.
	var factor := minf(rect.size.x / 1210.0, rect.size.y / 760.0)
	scale = Vector2.ONE * factor
	position = rect.position + Vector2(rect.size.x * 0.5 - 64.0 * factor, (rect.size.y - 750.0 * factor) * 0.5 + 146.0 * factor)

func select(index: int) -> void:
	selected = index
	for i in range(machines.size()):
		machines[i].selected = i == index

func _unhandled_input(event: InputEvent) -> void:
	if not interactive:
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		for i in range(machines.size() - 1, -1, -1):
			if Rect2(machines[i].position - Vector2(90, 140), Vector2(180, 180)).has_point(point):
				station_selected.emit(i)
				get_viewport().set_input_as_handled()
				return

func _draw() -> void:
	# Floating foundation and warm ceramic floor.
	for i in range(6, 0, -1):
		polygon([iso(-0.3, -0.3) + Vector2(0, i * 5), iso(10.3, -0.3) + Vector2(i * 3, i * 5), iso(10.3, 8.3) + Vector2(0, i * 5), iso(-0.3, 8.3) + Vector2(-i * 3, i * 5)], Color(0.01, 0.035, 0.025, 0.035))
	box(-0.18, -0.18, 10.36, 8.36, 23, Color("987c59"), -23)
	for x in range(10):
		for y in range(8):
			var shade := (x * 7 + y * 3) % 5
			var color := Color("dbc79e").lightened(float(shade) * 0.013)
			polygon([iso(x + 0.025, y + 0.025), iso(x + 0.975, y + 0.025), iso(x + 0.975, y + 0.975), iso(x + 0.025, y + 0.975)], color)
	# Rear walls; wainscot, window recesses, crown and hanging fixtures.
	box(-0.14, -0.14, 10.28, 0.14, 146, Color("a9bca0"))
	box(-0.14, 0, 0.14, 8.14, 146, Color("c8ccb0"))
	box(0, 0, 10, 0.05, 52, Color("577d66"))
	box(0, 0, 0.05, 8, 52, Color("74917a"))
	line([iso(0, 0, 53), iso(10, 0, 53)], Color("e5d8ae"), 4)
	line([iso(0, 0, 53), iso(0, 8, 53)], Color("e5d8ae"), 4)
	line([iso(0, 8, 146), iso(0, 0, 146), iso(10, 0, 146)], Color("e3ddbb"), 6)
	for x in [1.3, 4.4, 7.5]:
		_window(x)
	# Warm window light projected onto the floor.
	for x in [1.4, 4.5, 7.6]:
		polygon([iso(x, 0.4), iso(x + 1.5, 0.4), iso(x + 3.1, 3.5), iso(x + 1.6, 3.5)], Color(1.0, 0.9, 0.60, 0.07))
	# Wall shelf and hand-crafted jars.
	box(0.02, 1.1, 0.5, 2.05, 8, Color("9f734b"), 87)
	for i in range(6):
		var jar := iso(0.23, 1.27 + i * 0.31, 97)
		cylinder(jar, Vector2(7, 3.5), 13, Color("ddbf82") if i % 2 == 0 else Color("8c9d6a"))
		ellipse(jar - Vector2(0, 13), Vector2(8, 4), BRASS)
	# Utilities and decor away from machine silhouettes.
	box(0.3, 5.7, 0.65, 1.1, 57, Color("688976"))
	box(0.25, 5.65, 0.75, 1.2, 5, Color("e6d6ae"), 57)
	var sink := iso(0.65, 6.17, 64)
	ellipse(sink, Vector2(25, 12), Color("8a9b87"))
	ellipse(sink, Vector2(18, 8), Color("4d6f61"))
	line([sink + Vector2(-11, -8), sink + Vector2(-11, -27), sink + Vector2(0, -27), sink + Vector2(0, -18)], Color("d9ddc5"), 4)
	plant(iso(0.65, 7.45), 1.25)
	plant(iso(9.4, 0.75), 1.4)
	# Storage pallet, produce crates, sacks and broom.
	box(8.4, 0.35, 1.05, 0.95, 8, Color("a87c50"))
	box(8.5, 0.42, 0.80, 0.76, 30, Color("c49a61"), 8)
	box(8.48, 0.4, 0.85, 0.8, 5, Color("dfb77a"), 38)
	for i in range(6):
		var fruit := iso(8.65 + (i % 3) * 0.20, 0.60 + floorf(i / 3.0) * 0.27, 46)
		draw_circle(fruit, 6, Color("cd8951"))
		line([fruit, fruit - Vector2(3, 7)], GREEN, 2)
	for i in range(2):
		cylinder(iso(1.0 + i * 0.5, 0.7), Vector2(18, 10), 34, Color("d0b582"))
	# Hand-painted wall board: recipe, leaf motif and chalk strokes.
	var board := [iso(0.07, 3.7, 126), iso(0.07, 5.2, 126), iso(0.07, 5.2, 71), iso(0.07, 3.7, 71)]
	polygon(board, Color("254f42"))
	line(board + [board[0]], Color("c49a61"), 5)
	for i in range(4):
		line([iso(0.09, 3.88, 111 - i * 10), iso(0.09, 4.7 + i * 0.08, 111 - i * 10)], Color("aebd97"), 2)
	# Rug, ingredients trolley, stool and floor details add a lived-in feel.
	polygon([iso(1.0, 3.2), iso(3.1, 3.2), iso(3.1, 4.5), iso(1.0, 4.5)], Color("b4b188"))
	line([iso(1.1, 4.4), iso(3.0, 4.4)], Color("cdc59a"), 3)
	box(3.7, 0.40, 0.80, 0.65, 7, Color("ae8b56"), 22)
	box(3.7, 0.40, 0.80, 0.65, 7, CREAM, 57)
	for x in [3.73, 4.40]:
		for y in [0.43, 1.0]:
			line([iso(x, y, 7), iso(x, y, 58)], Color("627867"), 3)
			draw_circle(iso(x, y, 5), 5, INK)
	cylinder(iso(4.00, 0.74, 65), Vector2(13, 7), 17, Color("dcbb78"))
	plant(iso(4.3, 0.67, 65), 0.65)
	var stool := iso(1.3, 5.1)
	for offset in [-9, 9]:
		line([stool + Vector2(offset, 0), stool + Vector2(offset * 0.6, -27)], Color("6c7454"), 3)
	cylinder(stool - Vector2(0, 27), Vector2(19, 9), 5, Color("a98454"))
	for i in range(7):
		var fleck := iso(2.0 + i * 0.09, 4.8 + sin(i * 4.0) * 0.08)
		ellipse(fleck, Vector2(2, 1), Color("9a9c70"))
	# Station route painted on floor, with inset conveyor beds.
	for i in range(3):
		_conveyor(POSITIONS[i], POSITIONS[i + 1], i)
	# Floor marking at the shipment zone.
	line([iso(6.5, 5.0), iso(8.9, 5.0), iso(8.9, 6.7), iso(6.5, 6.7), iso(6.5, 5.0)], Color(0.49, 0.50, 0.32, 0.65), 2)
	# Pendant pools, cables, labels. The fixtures are drawn above the room, behind equipment.
	for p in [Vector2(2.3, 2.5), Vector2(6.2, 2.2)]:
		var lamp := iso(p.x, p.y, 196)
		line([lamp - Vector2(0, 32), lamp], Color("384e3d"), 2)
		polygon([lamp + Vector2(-21, 18), lamp + Vector2(-9, 0), lamp + Vector2(9, 0), lamp + Vector2(21, 18)], GREEN)
		ellipse(lamp + Vector2(0, 18), Vector2(21, 7), Color("f9d78c"))
		ellipse(lamp + Vector2(0, 22), Vector2(25, 9), Color(1.0, 0.86, 0.5, 0.13))
	# Slow floating dust in the warm window light, even before production starts.
	if not Game.reduced_motion:
		for i in range(12):
			var phase := fmod(time * 0.04 + i * 0.083, 1.0)
			var mote := iso(1.5 + i * 0.61, 1.2 + sin(i * 7.0) * 0.5, 25 + phase * 90)
			draw_circle(mote + Vector2(sin(time * 0.5 + i) * 4, 0), 1.2, Color(1.0, 0.93, 0.7, sin(phase * PI) * 0.4))

func _window(x: float) -> void:
	var a := iso(x, 0.08, 127)
	var b := iso(x + 1.7, 0.08, 127)
	var c := iso(x + 1.7, 0.08, 66)
	var d := iso(x, 0.08, 66)
	polygon([a, b, c, d], Color("f1dca0"))
	polygon([a + Vector2(5, 6), b + Vector2(-4, 2), c + Vector2(-4, -5), d + Vector2(5, -3)], Color("b4cfb0"))
	polygon([a + Vector2(5, 6), b + Vector2(-4, 2), b + Vector2(-4, 24), a + Vector2(5, 28)], Color("dce4c3"))
	line([a, b, c, d, a], Color("e6d4a5"), 5)
	line([a.lerp(b, 0.5), d.lerp(c, 0.5)], Color("e6d4a5"), 4)
	line([a.lerp(d, 0.5), b.lerp(c, 0.5)], Color("e6d4a5"), 4)
	line([d - Vector2(4, 0), c + Vector2(5, 0)], Color("f3e2bb"), 7)

func _conveyor(from: Vector2, to: Vector2, route: int) -> void:
	var start := iso(from.x, from.y, 34)
	var end := iso(to.x, to.y, 34)
	var direction := (end - start).normalized()
	start += direction * 60
	end -= direction * 60
	var normal := Vector2(-direction.y, direction.x) * 13
	shadow((start + end) * 0.5 + Vector2(0, 30), Vector2(start.distance_to(end) * 0.45, 12))
	polygon([start + normal + Vector2(0, 9), end + normal + Vector2(0, 9), end - normal + Vector2(0, 9), start - normal + Vector2(0, 9)], Color("466a56"))
	polygon([start + normal, end + normal, end - normal, start - normal], Color("577766"))
	line([start + normal, end + normal], Color("acb99d"), 3)
	line([start - normal, end - normal], Color("acb99d"), 3)
	var moving := Game.stage == route + 1 and Game.transferring
	for i in range(9):
		var f := fmod(float(i) / 9.0 + (time * 0.35 if moving else 0.0), 1.0)
		var point := start.lerp(end, f)
		draw_line(point - normal * 0.8, point + normal * 0.8, Color("879981"), 2, true)
	for f in [0.2, 0.8]:
		var foot := start.lerp(end, f)
		line([foot, foot + Vector2(0, 30)], Color("466455"), 6)
	if moving:
		var parcel := start.lerp(end, Game.progress())
		if route == 2:
			bag(parcel - Vector2(0, 3), 0.65)
		else:
			ellipse(parcel - Vector2(0, 5), Vector2(13, 7), Color("dec791"))
			for j in range(4):
				draw_circle(parcel + Vector2(j * 5 - 8, -8), 3, Color("e8a159"))
