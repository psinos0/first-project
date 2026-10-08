extends IsoArt
## Original animated machine artwork. The visual scene never owns economy state.

var index := 0
var time := 0.0
var selected := false
var hovered := false

func _process(delta: float) -> void:
	if not Game.reduced_motion:
		time += delta
	queue_redraw()

func _draw() -> void:
	var active := Game.playing and Game.stage == index and not Game.transferring
	shadow(Vector2(0, 20), Vector2(86, 34))
	if selected or hovered or active:
		var tint := Color("f2c774") if selected or hovered else Color("81bd97")
		tint.a = 0.55
		line([iso(-0.95, -0.85), iso(0.95, -0.85), iso(0.95, 0.85), iso(-0.95, 0.85), iso(-0.95, -0.85)], tint, 3.0)
	match index:
		0: _prep(active)
		1: _dryer(active)
		2: _pack(active)
		3: _delivery(active)
	if index < 3:
		# Embedded status light and three dimensional name plaque.
		var lamp := iso(0.72, 0.8, 57)
		if active:
			for r in [10, 7]:
				draw_circle(lamp, r, Color(0.55, 0.91, 0.65, 0.08))
		draw_circle(lamp, 3, Color("b9efac") if active else Color("638877"))
		var badge := iso(-0.2, 0.86, 37)
		draw_style_box(_badge_style(), Rect2(badge - Vector2(19, 11), Vector2(38, 21)))
		draw_string(ThemeDB.fallback_font, badge + Vector2(-10, 4), "%02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CREAM)

func _badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.set_corner_radius_all(4)
	return style

func _feet() -> void:
	for p in [Vector2(-0.65, -0.5), Vector2(0.65, -0.5), Vector2(-0.65, 0.6), Vector2(0.65, 0.6)]:
		box(p.x, p.y, 0.14, 0.14, 23, INK)

func _prep(active: bool) -> void:
	_feet()
	box(-0.85, -0.65, 1.7, 1.4, 40, GREEN, 18)
	box(-0.89, -0.69, 1.78, 1.48, 9, CREAM, 58)
	box(-0.74, -0.45, 0.85, 0.7, 4, Color("bd884f"), 67)
	for i in range(5):
		var carrot := iso(-0.57 + i * 0.13, -0.16, 73)
		line([carrot, carrot + Vector2(12, 6)], Color("e39754"), 5.0)
		line([carrot, carrot - Vector2(3, 5)], Color("538a57"), 3.0)
	var bowl := iso(0.38, 0.30, 70)
	cylinder(bowl, Vector2(24, 12), 14, Color("d9ddd0"))
	ellipse(bowl - Vector2(0, 14), Vector2(19, 9), Color("94704b"))
	for i in range(7):
		var a := float(i) * 2.4 + (time * 3 if active else 0.0)
		draw_circle(bowl + Vector2(cos(a) * 12, sin(a) * 5 - 15), 3, Color("e8b264"))
	box(0.38, -0.55, 0.34, 0.32, 34, Color("d2d9c8"), 66)
	box(0.13, -0.54, 0.65, 0.31, 13, GREEN, 100)
	var arm := iso(0.22, -0.33, 104)
	var target := bowl - Vector2(0, 17)
	if active:
		target.x += sin(time * 12.0) * 5
	line([arm, target], Color("d1d6c7"), 5.0)
	box(-0.7, 0.79, 0.55, 0.035, 20, Color("285746"), 26)
	line([iso(-0.58, 0.85, 37), iso(-0.27, 0.85, 37)], BRASS, 3)
	var towels := iso(-0.85, 0.26, 40)
	polygon([towels, towels + Vector2(17, 8), towels + Vector2(17, 28), towels + Vector2(0, 20)], Color("e8dcb9"))

func _dryer(active: bool) -> void:
	_feet()
	box(-0.72, -0.60, 1.45, 1.22, 106, Color("bd8050"), 16)
	box(-0.75, -0.63, 1.51, 1.28, 7, Color("ebbc78"), 122)
	# Tall inset glass door, framed in brass; trays visible through dark glass.
	var a := iso(-0.58, 0.635, 108)
	var b := iso(0.58, 0.635, 108)
	var c := iso(0.58, 0.635, 31)
	var d := iso(-0.58, 0.635, 31)
	polygon([a, b, c, d], Color("344b44"))
	line([a, b, c, d, a], Color("edbc77"), 4)
	for j in range(4):
		var left := iso(-0.48, 0.655, 43 + j * 16)
		var right := iso(0.45, 0.655, 43 + j * 16)
		draw_line(left, right, Color("889582"), 3, true)
		for i in range(5):
			var item := left.lerp(right, float(i + 1) / 6.0) - Vector2(0, 4)
			ellipse(item, Vector2(4, 2), Color("e8a662") if active else Color("b79562"))
	polygon([a + Vector2(9, 7), a + Vector2(21, 13), d + Vector2(21, -10), d + Vector2(9, -16)], Color(0.8, 0.91, 0.8, 0.08))
	line([iso(0.62, 0.69, 65), iso(0.62, 0.69, 84)], CREAM, 4)
	var gauge := iso(-0.28, 0.64, 117)
	draw_circle(gauge, 7, CREAM)
	draw_circle(gauge, 5, INK)
	draw_line(gauge, gauge + Vector2(3, -3 if active else 2), BRASS, 1.5)
	for i in range(5):
		line([iso(0.75, -0.34 + i * 0.13, 94), iso(0.75, -0.34 + i * 0.13, 53)], Color("8b5a3d"), 2)
	var chimney := iso(0.12, -0.27, 129)
	cylinder(chimney, Vector2(12, 6), 22, Color("54685b"))
	if active and not Game.reduced_motion:
		for i in range(4):
			var phase := fmod(time * 0.55 + i * 0.25, 1.0)
			ellipse(chimney + Vector2(sin(phase * 5) * 8, -24 - phase * 50), Vector2(8 + phase * 12, 5 + phase * 7), Color(0.96, 0.88, 0.68, (1.0 - phase) * 0.25))

func _pack(active: bool) -> void:
	_feet()
	box(-0.89, -0.65, 1.78, 1.3, 40, GREEN, 18)
	box(-0.94, -0.70, 1.88, 1.4, 8, Color("c8d0bb"), 58)
	box(-0.65, -0.40, 1.3, 0.66, 7, INK, 66)
	for i in range(9):
		var x := -0.60 + fmod(i * 0.15 + (time * 0.20 if active else 0.0), 1.28)
		line([iso(x, -0.36, 74), iso(x, 0.2, 74)], Color("738e7c"), 3)
	box(-0.48, -0.45, 0.10, 0.72, 54, Color("a3bb9f"), 74)
	box(0.39, -0.45, 0.10, 0.72, 54, Color("a3bb9f"), 74)
	box(-0.48, -0.45, 0.97, 0.12, 13, GREEN, 121)
	var press := 94.0 + (sin(time * 7) * 5 if active else 0.0)
	box(-0.20, -0.3, 0.50, 0.18, 9, BRASS, press)
	cylinder(iso(-0.65, 0.41, 71), Vector2(15, 8), 24, Color("eee3c1"))
	ellipse(iso(-0.65, 0.41, 95), Vector2(6, 3), Color("bba976"))
	bag(iso(0.45, 0.32, 77), 0.85)
	bag(iso(0.06, 0.04, 77), 0.65)
	var panel := iso(-0.50, 0.67, 44)
	polygon([panel, panel + Vector2(25, 12), panel + Vector2(25, 27), panel + Vector2(0, 15)], INK)
	draw_circle(panel + Vector2(7, 11), 3, Color("eab76c"))
	draw_circle(panel + Vector2(16, 16), 3, Color("8dbb8e"))

func _delivery(active: bool) -> void:
	box(-0.9, -0.6, 1.8, 1.3, 10, Color("8d6747"), 5)
	for i in range(6):
		line([iso(-0.83 + i * 0.3, -0.57, 16), iso(-0.83 + i * 0.3, 0.66, 16)], Color("b68c5b"), 3)
	box(-0.7, -0.41, 0.70, 0.67, 38, Color("cb9d63"), 16)
	box(-0.10, 0.13, 0.72, 0.50, 29, Color("d8ac71"), 16)
	box(0.12, -0.42, 0.63, 0.55, 31, Color("b7905b"), 16)
	for p in [Vector2(-0.35, -0.08), Vector2(0.3, 0.30)]:
		var label := iso(p.x, p.y + 0.3, 36)
		polygon([label, label + Vector2(17, 8), label + Vector2(17, 19), label + Vector2(0, 11)], CREAM)
		line([label + Vector2(4, 6), label + Vector2(13, 10)], GREEN, 2)
	var post := iso(-0.9, -0.59)
	line([post, post - Vector2(0, 108)], INK, 5)
	draw_style_box(_badge_style(), Rect2(post - Vector2(41, 114), Vector2(84, 26)))
	draw_string(ThemeDB.fallback_font, post - Vector2(31, 96), tr("DISPATCH"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)
	if active:
		for i in range(3):
			var phase := fmod(time + i * 0.3, 1.0)
			draw_circle(iso(0.1, 0.1, 70) + Vector2(i * 13 - 13, -phase * 25), 4, Color(1.0, 0.8, 0.4, 1.0 - phase))
