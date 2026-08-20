class_name ThemeFactory
extends RefCounted

const BACKGROUND := Color("18231c")
const SURFACE := Color("243229")
const SURFACE_RAISED := Color("2d3b30")
const BRASS := Color("b89a5b")
const BRASS_BRIGHT := Color("d1b56f")
const TEXT := Color("e8e1d2")
const MUTED_TEXT := Color("b9b2a2")
const UI_FONT := preload("res://game_assets/ui/fonts/ui_cjk.ttf")


static func create() -> Theme:
	var result := Theme.new()
	var font := _ui_font()
	result.default_font = font
	for type_name in ["Label", "Button", "LineEdit", "RichTextLabel"]:
		result.set_font("font", type_name, font)
		result.set_color("font_color", type_name, TEXT)
		result.set_color("font_outline_color", type_name, Color("101610"))
	result.set_color("font_disabled_color", "Button", Color("777a70"))
	result.set_color("font_hover_color", "Button", Color("fff4da"))
	result.set_color("font_pressed_color", "Button", Color("fff4da"))
	result.set_font("normal_font", "RichTextLabel", font)
	result.set_color("default_color", "RichTextLabel", TEXT)
	result.set_color("font_placeholder_color", "LineEdit", MUTED_TEXT)
	result.set_font_size("font_size", "Label", 16)
	result.set_font_size("font_size", "Button", 16)
	result.set_font_size("normal_font_size", "RichTextLabel", 15)
	result.set_constant("outline_size", "Label", 1)
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 10)
	result.set_stylebox("panel", "PanelContainer", _box(SURFACE, BRASS, 1, 4))
	result.set_stylebox("normal", "Button", _box(SURFACE_RAISED, BRASS, 1, 4, 10))
	result.set_stylebox("hover", "Button", _box(Color("3d4c3c"), BRASS_BRIGHT, 1, 4, 10))
	result.set_stylebox("pressed", "Button", _box(Color("1a241c"), Color("e2c36a"), 2, 4, 10))
	result.set_stylebox("disabled", "Button", _box(Color("202820"), Color("596257"), 1, 4, 10))
	result.set_stylebox("normal", "LineEdit", _box(Color("151e18"), Color("6f765f"), 1, 3, 8))
	result.set_stylebox("focus", "LineEdit", _box(Color("151e18"), BRASS_BRIGHT, 2, 3, 8))
	return result


static func _ui_font() -> Font:
	var font := FontVariation.new()
	if ThemeDB.fallback_font != null:
		font.base_font = ThemeDB.fallback_font
		font.fallbacks = [UI_FONT]
	else:
		font.base_font = UI_FONT
	return font


static func _box(fill: Color, border: Color, width: int, radius: int, padding: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	box.content_margin_left = padding
	box.content_margin_top = padding
	box.content_margin_right = padding
	box.content_margin_bottom = padding
	return box
