class_name BattlefieldChrome
extends RefCounted

const FELT_SHADER := preload("res://shaders/felt_surface.gdshader")
const PAPER_SHADER := preload("res://shaders/paper_surface.gdshader")
const METAL_SHADER := preload("res://shaders/metal_surface.gdshader")
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


static func metal_material(grain := 0.12, sheen := 0.18) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = METAL_SHADER
	material.set_shader_parameter("grain", grain)
	material.set_shader_parameter("brush", 0.14)
	material.set_shader_parameter("sheen", sheen)
	return material


static func vignette_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = VIGNETTE_SHADER
	return material


static func plaque(fill: Color, border: Color, width := 1, radius := 4, padding := 6, shadow := 0) -> StyleBoxFlat:
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
	if shadow > 0:
		box.border_width_bottom = maxi(width + 1, box.border_width_bottom)
		box.shadow_color = Color(0.02, 0.01, 0.00, 0.48)
		box.shadow_size = shadow
		box.shadow_offset = Vector2(0, 2)
	return box


static func nameplate(fill: Color, border: Color) -> StyleBoxFlat:
	var box := plaque(fill, border, 1, 3, 6, 3)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


static func slot_pad(zone: String, highlighted: bool) -> StyleBoxFlat:
	var style := plaque(Color(0.08, 0.08, 0.07, 0.22), Color(0.42, 0.38, 0.28, 0.0), 0, 6, 0)
	match zone:
		"frontline":
			style.bg_color = Color(0.10, 0.08, 0.05, 0.24)
		"opponent_support":
			style.bg_color = Color(0.14, 0.07, 0.06, 0.22)
		_:
			style.bg_color = Color(0.07, 0.11, 0.13, 0.22)
	if highlighted:
		style.bg_color = Color(0.28, 0.22, 0.08, 0.32)
		style.border_color = Color("f0cf55")
		style.set_border_width_all(3)
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
	var under := Color(0.05, 0.04, 0.02, clampf(color.a + 0.28, 0.0, 1.0))
	for polyline in corners:
		canvas.draw_polyline(polyline, under, width + 1.6, true)
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
	draw_frontline(canvas, rect, [], [])


static func draw_frontline(canvas: CanvasItem, rect: Rect2, highlighted_slots: Array = [], column_centers: Array = []) -> void:
	var mid_y := rect.position.y + rect.size.y * 0.5
	var left := rect.position.x + 18.0
	var right := rect.end.x - 18.0
	canvas.draw_rect(Rect2(rect.position.x, mid_y - 2.0, rect.size.x, 5.0), Color(0.06, 0.05, 0.03, 0.28), true)
	canvas.draw_line(Vector2(left, mid_y + 1.0), Vector2(right, mid_y + 1.0), Color(0.10, 0.08, 0.05, 0.70), 2.0)
	canvas.draw_line(Vector2(left, mid_y), Vector2(right, mid_y), Color(0.86, 0.72, 0.40, 0.92), 1.6)
	for index in highlighted_slots:
		if index < 0 or index >= column_centers.size():
			continue
		var x: float = float(column_centers[index]) - rect.position.x
		var tick := PackedVector2Array([
			Vector2(x, mid_y - 7.0),
			Vector2(x + 5.0, mid_y),
			Vector2(x, mid_y + 7.0),
			Vector2(x - 5.0, mid_y),
		])
		canvas.draw_colored_polygon(tick, Color(0.96, 0.84, 0.42, 0.88))


static func draw_slot_pad(canvas: CanvasItem, rect: Rect2, zone: String, highlighted: bool) -> void:
	var fill := Color(0.06, 0.05, 0.04, 0.42)
	var well := Color(0.03, 0.03, 0.02, 0.38)
	var edge := Color(0.82, 0.70, 0.40, 0.78)
	match zone:
		"frontline":
			fill = Color(0.10, 0.07, 0.04, 0.44)
			well = Color(0.04, 0.03, 0.02, 0.40)
			edge = Color(0.88, 0.74, 0.42, 0.82)
		"opponent_support":
			fill = Color(0.12, 0.05, 0.04, 0.40)
			well = Color(0.06, 0.03, 0.02, 0.36)
			edge = Color(0.80, 0.54, 0.44, 0.70)
		_:
			fill = Color(0.05, 0.09, 0.11, 0.40)
			well = Color(0.03, 0.05, 0.06, 0.36)
			edge = Color(0.56, 0.70, 0.76, 0.70)
	if highlighted:
		fill = Color(0.30, 0.24, 0.08, 0.40)
		well = Color(0.18, 0.14, 0.05, 0.28)
		edge = Color(0.98, 0.86, 0.44, 0.96)
	var tray := rect.grow(-2.0)
	canvas.draw_rect(tray.grow(1.0), Color(0.02, 0.02, 0.01, 0.35), true)
	canvas.draw_rect(tray, fill, true)
	canvas.draw_rect(tray.grow(-5.0), well, true)
	draw_corner_brackets(canvas, tray.grow(-3.0), edge, 13.0, 2.0)
	draw_rivets(canvas, tray, Color(edge.r, edge.g, edge.b, edge.a * 0.85), 6.0)
	if highlighted:
		draw_stitches(canvas, tray.grow(-1.0), Color(0.96, 0.84, 0.42, 0.62))
