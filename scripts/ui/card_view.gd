class_name CardView
extends Button

signal card_pressed(instance_id: String)
signal card_drag_started(instance_id: String)
signal card_dropped(instance_id: String, target: Variant)

const LocaleScript = preload("res://scripts/ui/locale.gd")

const MODE_SIZES := {
	"catalog": Vector2(180, 252),
	"hand": Vector2(116, 162),
	"battlefield": Vector2(108, 118),
	"hidden": Vector2(116, 162),
}

const RARITY_PIP_COLORS := {
	"Standard": Color("9aa06b"),
	"Limited": Color("6fa3c4"),
	"Special": Color("b084c9"),
	"Elite": Color("e3c35c"),
}

var card_data: Dictionary = {}
var mode := "catalog"
var action_state := "normal"
var _base_tooltip := ""
var _hover_active := false
var _rest_position := Vector2.ZERO
var _hover_tween: Tween
var _legal_pulse: Tween


func _ready() -> void:
	pressed.connect(_on_pressed)


func bind(data: Dictionary, display_mode: String) -> void:
	assert(MODE_SIZES.has(display_mode), "Unsupported card display mode: %s" % display_mode)
	_reset_hover()
	rotation_degrees = 0.0
	mode = display_mode
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = MODE_SIZES[mode]
	size = custom_minimum_size
	_apply_mode_layout()

	var hidden := mode == "hidden" or bool(data.get("hidden", false))
	card_data = {"hidden": true} if hidden else data.duplicate(true)
	get_node("CardBack").visible = hidden
	get_node("Frame").visible = not hidden
	_base_tooltip = "" if hidden else str(data.get("description", ""))
	tooltip_text = _base_tooltip
	_apply_back_tint(data)
	if hidden:
		_clear_face()
		return

	get_node("Frame/Title").text = str(data.get("title", ""))
	_fit_title(str(data.get("title", "")))
	get_node("Frame/Type").text = _type_mark(data)
	get_node("Frame/Costs/Deployment").text = str(data.get("deployment_cost", ""))
	get_node("Frame/Costs/Operation").text = str(data.get("operation_cost", ""))
	get_node("Frame/Description").text = str(data.get("description", ""))
	get_node("Frame/Keywords").text = "  ".join(data.get("keywords", []))
	get_node("Frame/Stats/Attack").text = str(data.get("attack", ""))
	get_node("Frame/Stats/Defense").text = str(data.get("defense", ""))
	get_node("Frame/Artwork").texture = _load_art(str(data.get("image_path", "")))
	_base_tooltip = _inspect_text(data)
	tooltip_text = _base_tooltip
	_apply_semantic_accents(data)
	set_action_state("normal")


func set_action_state(state: String, reason: String = "") -> void:
	assert(state in ["normal", "legal", "selected", "unavailable"], "Unsupported card action state: %s" % state)
	action_state = state
	tooltip_text = _base_tooltip if reason.is_empty() else "%s\n%s" % [reason, _base_tooltip]
	_stop_legal_pulse()
	if card_data.get("hidden", false):
		return
	var border := Color("a88f58")
	var owner := str(card_data.get("owner_id", ""))
	var nation := str(card_data.get("nation", ""))
	if owner == "player" or nation == "UnitedStates":
		border = Color("7899ad")
	elif owner == "opponent" or nation == "SovietUnion":
		border = Color("a96d5e")
	match state:
		"legal":
			border = Color("e1c45a")
		"selected":
			border = Color("fff0a0")
		"unavailable":
			border = Color("59615d")
	var glow := state in ["legal", "selected"]
	add_theme_stylebox_override("normal", _card_style(Color("171d1a") if state == "unavailable" else Color("1b241e"), border, 4 if glow else 2))
	add_theme_stylebox_override("hover", _card_style(Color("202824"), border.lightened(0.12), 5 if glow else 3))
	self_modulate = Color(0.68, 0.68, 0.68, 1.0) if state == "unavailable" else Color.WHITE
	if state == "legal":
		_start_legal_pulse()


func _on_pressed() -> void:
	card_pressed.emit(_instance_id())


func _get_drag_data(_at_position: Vector2) -> Variant:
	var instance_id := _instance_id()
	card_drag_started.emit(instance_id)
	if is_inside_tree():
		var preview := Label.new()
		preview.text = str(card_data.get("title", "Card"))
		set_drag_preview(preview)
	return {"instance_id": instance_id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and not str(data.get("instance_id", "")).is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		card_dropped.emit(str(data.get("instance_id")), _instance_id())


func _instance_id() -> String:
	return str(card_data.get("instance_id", ""))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_set_hover_lift(true)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_set_hover_lift(false)
	elif what == NOTIFICATION_PREDELETE and _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()


func _reset_hover() -> void:
	_hover_active = false
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	z_index = 0
	scale = Vector2.ONE


# Hand cards lift and raise above neighbours on hover for readability.
func _set_hover_lift(lift: bool) -> void:
	if lift == _hover_active:
		return
	if lift and (mode != "hand" or not is_inside_tree()):
		return
	_hover_active = lift
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	pivot_offset = size * 0.5
	_hover_tween = create_tween()
	if lift:
		_rest_position = position
		z_index = 16
		_hover_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_parallel(true)
		_hover_tween.tween_property(self, "position:y", _rest_position.y - 20.0, 0.10)
		_hover_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.10)
	else:
		_hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_parallel(true)
		_hover_tween.tween_property(self, "position:y", _rest_position.y, 0.08)
		_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.08)
		_hover_tween.chain().tween_callback(func() -> void: z_index = 0)


func _clear_face() -> void:
	for path in ["Frame/Title", "Frame/Type", "Frame/Costs/Deployment", "Frame/Costs/Operation", "Frame/Description", "Frame/Keywords", "Frame/Stats/Attack", "Frame/Stats/Defense"]:
		get_node(path).text = ""
	get_node("Frame/Artwork").texture = _fallback_art()


func _apply_back_tint(data: Dictionary) -> void:
	var tint := Color.WHITE
	var owner := str(data.get("owner_id", ""))
	var nation := str(data.get("nation", ""))
	if owner == "player" or nation == "UnitedStates":
		tint = Color(0.74, 0.84, 0.96)
	elif owner == "opponent" or nation == "SovietUnion":
		tint = Color(0.98, 0.78, 0.72)
	get_node("CardBack/BackTexture").self_modulate = tint


func _apply_mode_layout() -> void:
	var frame := get_node("Frame") as Control
	var artwork := get_node("Frame/Artwork") as Control
	var title := get_node("Frame/Title") as Label
	var type := get_node("Frame/Type") as Label
	var costs := get_node("Frame/Costs") as Control
	var description := get_node("Frame/Description") as Control
	var keywords := get_node("Frame/Keywords") as Control
	var stats := get_node("Frame/Stats") as Control
	var category_strip := get_node("Frame/CategoryStrip") as Control
	var title_banner := get_node("Frame/TitleBanner") as Control
	var artwork_trim := get_node("Frame/ArtworkTrim") as Control
	var rarity_pip := get_node("Frame/RarityPip") as Control
	frame.clip_contents = true
	artwork.visible = mode != "hidden"
	title.visible = mode != "hidden"
	type.visible = mode != "hidden"
	costs.visible = mode != "hidden"
	stats.visible = mode != "hidden"
	description.visible = mode == "catalog"
	keywords.visible = mode == "catalog"
	title_banner.visible = mode != "hidden"
	artwork_trim.visible = mode != "hidden"
	rarity_pip.visible = mode == "catalog"

	match mode:
		"catalog":
			title.add_theme_font_size_override("font_size", 13)
			type.add_theme_font_size_override("font_size", 13)
			_set_rect(title, 5, 3, 137, 27)
			_set_rect(type, 141, 3, 167, 27)
			_set_rect(title_banner, 2, 1, 170, 29)
			_set_rect(costs, 123, 31, 165, 52)
			_set_rect(artwork, 5, 54, 167, 126)
			_set_rect(artwork_trim, 5, 54, 167, 126)
			_set_rect(description, 6, 130, 166, 188)
			_set_rect(keywords, 6, 192, 166, 211)
			_set_rect(stats, 106, 216, 166, 237)
			_set_rect(category_strip, 0, 0, 3, 244)
			_set_rect(rarity_pip, 156, 3, 168, 9)
		"hand":
			type.visible = true
			keywords.visible = true
			type.add_theme_font_size_override("font_size", 8)
			keywords.add_theme_font_size_override("font_size", 8)
			_set_rect(title, 4, 2, 104, 16)
			_set_rect(type, 4, 16, 54, 28)
			_set_rect(keywords, 56, 16, 104, 28)
			_set_rect(title_banner, 2, 1, 102, 29)
			_set_rect(artwork, 4, 30, 104, 112)
			_set_rect(artwork_trim, 4, 30, 104, 112)
			_set_rect(costs, 4, 114, 46, 133)
			_set_rect(stats, 44, 128, 104, 149)
			_set_rect(category_strip, 0, 0, 3, 154)
		"battlefield":
			type.visible = true
			type.add_theme_font_size_override("font_size", 8)
			get_node("Frame/Costs/Deployment").visible = false
			costs.add_theme_constant_override("separation", 2)
			stats.add_theme_constant_override("separation", 3)
			_set_rect(title, 4, 2, 62, 35)
			_set_rect(type, 64, 2, 96, 35)
			_set_rect(title_banner, 2, 1, 94, 34)
			_set_rect(artwork, 4, 38, 96, 79)
			_set_rect(artwork_trim, 4, 38, 96, 79)
			_set_rect(costs, 3, 84, 24, 105)
			_set_rect(stats, 51, 84, 96, 105)
			_set_rect(category_strip, 0, 0, 3, 110)


func _fit_title(value: String) -> void:
	var title := get_node("Frame/Title") as Label
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD
	var font_size := 13
	if mode == "hand":
		font_size = 9 if value.length() <= 16 else 8
	elif mode == "battlefield":
		font_size = 10
	title.add_theme_font_size_override("font_size", font_size)


func _apply_semantic_accents(data: Dictionary) -> void:
	var category := str(data.get("category", "Unit"))
	var category_colors := {
		"Unit": Color("8fa06f"),
		"Order": Color("c7a15e"),
		"Countermeasure": Color("8e88b0"),
		"Headquarters": Color("9aa398"),
	}
	var category_color: Color = category_colors.get(category, Color("8fa06f"))
	get_node("Frame/CategoryStrip").color = category_color
	var rarity := str(data.get("rarity", ""))
	var pip := get_node("Frame/RarityPip") as ColorRect
	pip.color = RARITY_PIP_COLORS.get(rarity, Color("9aa06b"))
	var owner := str(data.get("owner_id", ""))
	var nation := str(data.get("nation", ""))
	var border := Color("a88f58")
	if owner == "player" or nation == "UnitedStates":
		border = Color("7899ad")
	elif owner == "opponent" or nation == "SovietUnion":
		border = Color("a96d5e")
	add_theme_stylebox_override("normal", _card_style(Color("1b241e"), border, 2))
	add_theme_stylebox_override("hover", _card_style(Color("243029"), border.lightened(0.15), 3))
	add_theme_stylebox_override("pressed", _card_style(Color("151d18"), category_color.lightened(0.12), 3))


func _card_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.set_expand_margin_all(1.0 if width >= 4 else 0.0)
	return style


func _set_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	control.custom_minimum_size = Vector2.ZERO
	control.clip_contents = true
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom


func _type_mark(data: Dictionary) -> String:
	var unit_type := str(data.get("unit_type", ""))
	if mode == "hand" and not unit_type.is_empty():
		return unit_type
	if not unit_type.is_empty():
		return unit_type.left(1).to_upper()
	return str(data.get("category", "")).left(1).to_upper()


func _inspect_text(data: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		str(data.get("title", "")),
		str(data.get("unit_type", data.get("category", ""))),
		str(data.get("description", "")),
	])
	for keyword in data.get("keywords", []):
		lines.append(LocaleScript.keyword(str(keyword)))
	return "\n".join(lines)


func set_duty_caption(text: String) -> void:
	if mode != "battlefield":
		return
	var type := get_node("Frame/Type") as Label
	type.visible = not text.is_empty()
	type.text = text
	type.add_theme_font_size_override("font_size", 8)
	type.add_theme_color_override("font_color", Color("e8d9a4"))


func _start_legal_pulse() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	_stop_legal_pulse()
	_legal_pulse = create_tween().set_loops()
	_legal_pulse.tween_property(self, "self_modulate", Color(1.18, 1.1, 0.72), 0.5)
	_legal_pulse.tween_property(self, "self_modulate", Color.WHITE, 0.5)


func _stop_legal_pulse() -> void:
	if _legal_pulse != null and _legal_pulse.is_valid():
		_legal_pulse.kill()
	_legal_pulse = null


func _load_art(path: String) -> Texture2D:
	if not path.is_empty() and ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			return resource
	return _fallback_art()


func _fallback_art() -> Texture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("27352f"), Color("786f4b"), Color("38453b")])
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 180
	texture.height = 120
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture
