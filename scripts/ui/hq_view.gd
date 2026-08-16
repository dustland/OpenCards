class_name HqView
extends Button

signal card_pressed(instance_id: String)
signal card_dropped(instance_id: String, target: Variant)

const EMBLEM_PATHS := {
	"us": "res://game_assets/ui/hq_us.png",
	"su": "res://game_assets/ui/hq_su.png",
}

var card_data: Dictionary = {}
var _flash_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(108, 118)
	clip_contents = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_style(false)
	_style_hp_badge()


static func emblem_key(nation: String) -> String:
	var normalized := nation.to_lower()
	if "soviet" in normalized or normalized == "su":
		return "su"
	return "us"


func bind_hq(data: Dictionary, nation: String, hq_defense: int) -> void:
	card_data = data.duplicate(true)
	var emblem: Texture2D = load(EMBLEM_PATHS[emblem_key(nation)])
	%Emblem.texture = emblem
	%HpLabel.text = str(hq_defense)
	%HpLabel.add_theme_font_size_override("font_size", 30 if hq_defense >= 10 else 34)


func set_highlight(highlighted: bool) -> void:
	_apply_style(highlighted)


func flash_damage() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	var original: Color = %Emblem.modulate
	%Emblem.modulate = Color("ff6a52")
	_flash_tween = create_tween()
	_flash_tween.tween_property(%Emblem, "modulate", original, 0.32)


func _pressed() -> void:
	card_pressed.emit(str(card_data.get("instance_id", "")))


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and not str(data.get("instance_id", "")).is_empty()):
		return false
	if has_meta("can_receive_drop"):
		return bool(get_meta("can_receive_drop"))
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		card_dropped.emit(str(data.get("instance_id")), str(card_data.get("instance_id", "")))


func _apply_style(highlighted: bool) -> void:
	var style := BattlefieldChrome.plaque(
		Color(0.07, 0.08, 0.06, 0.55) if not highlighted else Color(0.16, 0.14, 0.07, 0.72),
		Color("e9c458") if highlighted else Color(0.58, 0.50, 0.32, 0.85),
		3 if highlighted else 2,
		8,
		0
	)
	add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.border_color = Color("ffe08a") if highlighted else Color(0.78, 0.68, 0.42, 0.95)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("disabled", style)
	material = BattlefieldChrome.paper_material(0.10)
	queue_redraw()


func _style_hp_badge() -> void:
	if not has_node("%HpBadge"):
		return
	var badge := BattlefieldChrome.plaque(Color(0.18, 0.14, 0.07, 0.92), Color("c4a45a"), 2, 12, 2)
	badge.shadow_size = 3
	%HpBadge.add_theme_stylebox_override("panel", badge)


func _draw() -> void:
	BattlefieldChrome.draw_rivets(self, Rect2(Vector2.ZERO, size), Color(0.78, 0.66, 0.38, 0.88), 8.0)
	BattlefieldChrome.draw_corner_brackets(self, Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.72, 0.62, 0.38, 0.45), 12.0, 1.4)
