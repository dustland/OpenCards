class_name ThemeFactory
extends RefCounted

const BACKGROUND := Color("18231c")
const SURFACE := Color("243229")
const SURFACE_RAISED := Color("2d3b30")
const BRASS := Color("b89a5b")
const BRASS_BRIGHT := Color("d1b56f")
const TEXT := Color("e8e1d2")
const MUTED_TEXT := Color("b9b2a2")
const DISPLAY_FONT := preload("res://game_assets/ui/fonts/oswald_semibold.ttf")
const UI_FONT := preload("res://game_assets/ui/fonts/ui_cjk.ttf")


static func create() -> Theme:
	var result := Theme.new()
	var font := stacked()
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
	result.set_font("font", "TooltipLabel", font)
	result.set_font_size("font_size", "TooltipLabel", 13)
	result.set_color("font_color", "TooltipLabel", TEXT)
	result.set_color("font_shadow_color", "TooltipLabel", Color(0.04, 0.03, 0.02, 0.70))
	result.set_constant("shadow_offset_x", "TooltipLabel", 0)
	result.set_constant("shadow_offset_y", "TooltipLabel", 1)
	result.set_stylebox("panel", "TooltipPanel", _tooltip_plaque())
	return result


static func stacked(spacing := 0, embolden := 0.0) -> Font:
	var font := FontVariation.new()
	font.base_font = DISPLAY_FONT
	font.fallbacks = [UI_FONT]
	font.spacing_glyph = spacing
	font.variation_embolden = embolden
	return font


static func stamped(spacing := 1) -> Font:
	return stacked(spacing, 0.15)


static func _tooltip_plaque() -> StyleBoxFlat:
	var box := _box(Color(0.11, 0.09, 0.06, 0.97), Color(0.78, 0.64, 0.36, 0.92), 1, 5, 12)
	box.border_width_bottom = 2
	box.shadow_color = Color(0.02, 0.01, 0.00, 0.55)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	return box


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
