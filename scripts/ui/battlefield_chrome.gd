class_name BattlefieldChrome
extends RefCounted

const FELT_SHADER := preload("res://shaders/felt_surface.gdshader")
const PAPER_SHADER := preload("res://shaders/paper_surface.gdshader")
const VIGNETTE_SHADER := preload("res://shaders/battlefield_vignette.gdshader")


static func felt_material(grain := 0.07, weave := 0.035) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FELT_SHADER
	material.set_shader_parameter("grain", grain)
	material.set_shader_parameter("weave", weave)
	return material


static func paper_material(grain := 0.08) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PAPER_SHADER
	material.set_shader_parameter("grain", grain)
	return material


static func vignette_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = VIGNETTE_SHADER
	return material


static func plaque(fill: Color, border: Color, width := 1, radius := 4, padding := 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_top = padding
	box.content_margin_right = padding
	box.content_margin_bottom = padding
	box.anti_aliasing = true
	return box


static func slot_pad(zone: String, highlighted: bool) -> StyleBoxFlat:
	var style := plaque(Color(0.08, 0.08, 0.07, 0.06), Color(0.42, 0.38, 0.28, 0.0), 0, 5, 0)
	match zone:
		"frontline":
			style.bg_color = Color(0.10, 0.08, 0.05, 0.08)
		"opponent_support":
			style.bg_color = Color(0.12, 0.07, 0.06, 0.06)
		_:
			style.bg_color = Color(0.07, 0.10, 0.12, 0.06)
	if highlighted:
		style.bg_color = Color(0.28, 0.22, 0.08, 0.20)
		style.border_color = Color("f0cf55")
		style.set_border_width_all(2)
	return style


static func draw_corner_brackets(canvas: CanvasItem, rect: Rect2, color: Color, arm := 11.0, width := 1.7) -> void:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y
	var corners := [
		PackedVector2Array([Vector2(x0, y0 + arm), Vector2(x0, y0), Vector2(x0 + arm, y0)]),
		PackedVector2Array([Vector2(x1 - arm, y0), Vector2(x1, y0), Vector2(x1, y0 + arm)]),
		PackedVector2Array([Vector2(x0, y1 - arm), Vector2(x0, y1), Vector2(x0 + arm, y1)]),
		PackedVector2Array([Vector2(x1 - arm, y1), Vector2(x1, y1), Vector2(x1, y1 - arm)]),
	]
	for polyline in corners:
		canvas.draw_polyline(polyline, color, width, true)


static func draw_stitches(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var step := 11.0
	var inset := 3.5
	var x := rect.position.x + 8.0
	while x < rect.end.x - 8.0:
		canvas.draw_line(Vector2(x, rect.position.y + inset), Vector2(x + 4.0, rect.position.y + inset), color, 1.1)
		canvas.draw_line(Vector2(x, rect.end.y - inset), Vector2(x + 4.0, rect.end.y - inset), color, 1.1)
		x += step


static func draw_rivets(canvas: CanvasItem, rect: Rect2, color: Color, inset := 7.0) -> void:
	var points := [
		Vector2(rect.position.x + inset, rect.position.y + inset),
		Vector2(rect.end.x - inset, rect.position.y + inset),
		Vector2(rect.position.x + inset, rect.end.y - inset),
		Vector2(rect.end.x - inset, rect.end.y - inset),
	]
	for point in points:
		canvas.draw_circle(point, 2.3, color)
		canvas.draw_circle(point, 1.05, Color(0.16, 0.13, 0.08, 0.75))


static func draw_trench(canvas: CanvasItem, rect: Rect2) -> void:
	var mid_y := rect.position.y + rect.size.y * 0.5
	var left := rect.position.x + 6.0
	var right := rect.end.x - 6.0
	canvas.draw_rect(Rect2(rect.position.x, mid_y - 8.0, rect.size.x, 16.0), Color(0.10, 0.08, 0.05, 0.34), true)
	var points := PackedVector2Array()
	var x := left
	var crest := true
	while x <= right:
		points.append(Vector2(x, mid_y + (3.6 if crest else -3.6)))
		x += 7.0
		crest = not crest
	if points.size() >= 2:
		canvas.draw_polyline(points, Color(0.18, 0.14, 0.08, 0.55), 3.2, true)
		canvas.draw_polyline(points, Color(0.78, 0.66, 0.38, 0.72), 1.5, true)
	canvas.draw_line(Vector2(left, mid_y - 10.0), Vector2(right, mid_y - 10.0), Color(0.58, 0.50, 0.32, 0.28), 1.0)
	canvas.draw_line(Vector2(left, mid_y + 10.0), Vector2(right, mid_y + 10.0), Color(0.58, 0.50, 0.32, 0.28), 1.0)


static func draw_slot_pad(canvas: CanvasItem, rect: Rect2, zone: String, highlighted: bool) -> void:
	var fill := Color(0.06, 0.05, 0.04, 0.20)
	var edge := Color(0.78, 0.66, 0.38, 0.55)
	match zone:
		"frontline":
			fill = Color(0.08, 0.06, 0.04, 0.22)
			edge = Color(0.82, 0.70, 0.40, 0.62)
		"opponent_support":
			fill = Color(0.10, 0.05, 0.04, 0.18)
			edge = Color(0.74, 0.50, 0.42, 0.48)
		_:
			fill = Color(0.05, 0.08, 0.10, 0.18)
			edge = Color(0.52, 0.66, 0.72, 0.46)
	if highlighted:
		fill = Color(0.28, 0.22, 0.08, 0.22)
		edge = Color(0.96, 0.84, 0.42, 0.90)
	canvas.draw_rect(rect.grow(-3.0), fill, true)
	draw_corner_brackets(canvas, rect.grow(-4.0), edge, 10.0, 1.5)
	if highlighted:
		draw_stitches(canvas, rect.grow(-1.0), Color(0.94, 0.82, 0.40, 0.55))
