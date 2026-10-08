class_name IsoArt
extends Node2D
## Shared vector-art primitives, in local isometric coordinates.

const INK := Color("21443b")
const CREAM := Color("f3dfb4")
const GREEN := Color("3e7e68")
const BRASS := Color("d6a15a")

func iso(x: float, y: float, height: float = 0.0) -> Vector2:
	return Vector2((x - y) * 64.0, (x + y) * 32.0 - height)

func polygon(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func line(points: Array, color: Color, width: float = 1.0) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)

func box(x: float, y: float, width: float, depth: float, height: float,
		color: Color, bottom: float = 0.0) -> void:
	var a := iso(x, y, bottom)
	var b := iso(x + width, y, bottom)
	var c := iso(x + width, y + depth, bottom)
	var d := iso(x, y + depth, bottom)
	var lift := Vector2(0, height)
	polygon([d, c, c - lift, d - lift], color.darkened(0.18))
	polygon([c, b, b - lift, c - lift], color.darkened(0.32))
	polygon([a - lift, b - lift, c - lift, d - lift], color.lightened(0.15))
	line([a - lift, b - lift, c - lift, d - lift, a - lift], color.lightened(0.28), 1.0)

func ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

func cylinder(center: Vector2, radius: Vector2, height: float, color: Color) -> void:
	draw_rect(Rect2(center - Vector2(radius.x, height), Vector2(radius.x * 2, height)), color.darkened(0.15))
	ellipse(center, radius, color.darkened(0.2))
	ellipse(center - Vector2(0, height), radius, color.lightened(0.15))

func shadow(center: Vector2, radius: Vector2) -> void:
	for i in range(4, 0, -1):
		ellipse(center + Vector2(6, 7), radius + Vector2(i * 3, i * 1.5), Color(0.08, 0.17, 0.13, 0.03 + (4 - i) * 0.015))

func plant(at: Vector2, size: float = 1.0) -> void:
	shadow(at, Vector2(18, 9) * size)
	cylinder(at, Vector2(14, 7) * size, 21 * size, Color("bd7755"))
	ellipse(at - Vector2(0, 21) * size, Vector2(11, 5) * size, Color("4d4633"))
	for i in range(6):
		var angle := float(i) * 1.1
		var tip := at + Vector2(sin(angle) * 21, -32 - absf(cos(angle)) * 23) * size
		line([at - Vector2(0, 22) * size, tip], Color("547a48"), 2.0 * size)
		ellipse(tip, Vector2(8, 13) * size, Color("79a568") if i % 2 == 0 else Color("4c8061"))

func bag(at: Vector2, size: float = 1.0) -> void:
	var points := [at + Vector2(-12, 0) * size, at + Vector2(13, 0) * size,
		at + Vector2(10, -29) * size, at + Vector2(-9, -29) * size]
	polygon(points, Color("e8b866"))
	polygon([points[1], points[2], at + Vector2(5, -29) * size, at + Vector2(7, 0) * size], Color("ca944e"))
	draw_line(at + Vector2(-8, -26) * size, at + Vector2(9, -26) * size, Color("fff1c3"), 2.0 * size)
	draw_rect(Rect2(at + Vector2(-8, -20) * size, Vector2(15, 12) * size), GREEN)
	ellipse(at + Vector2(0, -14) * size, Vector2(3, 4) * size, CREAM)
