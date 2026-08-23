class_name CardView
extends Button

signal card_pressed(instance_id: String)
signal card_drag_started(instance_id: String)
signal card_dropped(instance_id: String, target: Variant)
signal inspected(data: Dictionary)

const LocaleScript = preload("res://scripts/ui/locale.gd")
const ThemeFactoryScript = preload("res://scripts/ui/theme_factory.gd")

const MODE_SIZES := {
	"catalog": Vector2(180, 252),
	"hand": Vector2(116, 162),
	"battlefield": Vector2(80, 112),
	"hidden": Vector2(116, 162),
}

const RARITY_PIP_COLORS := {
	"Standard": Color("9aa06b"),
	"Limited": Color("6fa3c4"),
	"Special": Color("b084c9"),
	"Elite": Color("e3c35c"),
}

const ROLE_STRIKE := "strike"
const ROLE_HOLD := "hold"
const ROLE_EFFECT := "effect"
const ROLE_PALETTES := {
	"strike": {
		"fill": Color(0.16, 0.08, 0.06),
		"border": Color(0.80, 0.42, 0.28),
		"plate": Color(0.38, 0.14, 0.09, 0.78),
		"strip": Color(0.84, 0.40, 0.24),
	},
	"hold": {
		"fill": Color(0.07, 0.10, 0.12),
		"border": Color(0.40, 0.60, 0.70),
		"plate": Color(0.10, 0.16, 0.20, 0.78),
		"strip": Color(0.44, 0.64, 0.74),
	},
	"effect": {
		"fill": Color(0.13, 0.10, 0.05),
		"border": Color(0.80, 0.66, 0.32),
		"plate": Color(0.28, 0.21, 0.08, 0.78),
		"strip": Color(0.88, 0.72, 0.36),
	},
}

var card_data: Dictionary = {}
var mode := "catalog"
var action_state := "normal"
var native_tooltip := true
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
	scale = Vector2.ONE
	mode = display_mode
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = MODE_SIZES[mode]
	size = custom_minimum_size
	pivot_offset = size * 0.5
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
	get_node("Frame/Description").text = LocaleScript.card_blurb(data)
	get_node("Frame/Keywords").text = "  ".join(data.get("keywords", []))
	get_node("Frame/Stats/Attack").text = str(data.get("attack", ""))
	get_node("Frame/Stats/Defense").text = str(data.get("defense", ""))
	get_node("Frame/Artwork").texture = _load_art(str(data.get("image_path", "")))
	_base_tooltip = inspect_copy(data)
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
	var palette: Dictionary = role_palette(card_data)
	var fill: Color = palette["fill"]
	var border: Color = palette["border"]
	match state:
		"legal":
			border = Color("e1c45a")
		"selected":
			border = Color("fff0a0")
		"unavailable":
			fill = fill.darkened(0.18)
			border = Color(0.36, 0.36, 0.34)
	var glow := state in ["legal", "selected"]
	add_theme_stylebox_override("normal", _card_style(fill if state != "unavailable" else Color("171616"), border, 4 if glow else 2))
	add_theme_stylebox_override("hover", _card_style(fill.lightened(0.08), border.lightened(0.12), 5 if glow else 3))
	self_modulate = Color(0.68, 0.68, 0.68, 1.0) if state == "unavailable" else Color.WHITE
	if state == "legal":
		_start_legal_pulse()


func _make_custom_tooltip(_for_text: String) -> Object:
	if native_tooltip:
		return null
	var dummy := Control.new()
	dummy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dummy


func _on_pressed() -> void:
	card_pressed.emit(_instance_id())


func _get_drag_data(_at_position: Vector2) -> Variant:
	var instance_id := _instance_id()
	card_drag_started.emit(instance_id)
	if is_inside_tree():
		var preview := duplicate() as Control
		preview.rotation_degrees = 0.0
		preview.scale = Vector2(0.92, 0.92)
		preview.modulate.a = 0.92
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_drag_preview(preview)
	return {"instance_id": instance_id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and not str(data.get("instance_id", "")).is_empty()):
		return false
	if has_meta("can_receive_drop"):
		return bool(get_meta("can_receive_drop"))
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		card_dropped.emit(str(data.get("instance_id")), _instance_id())


func _instance_id() -> String:
	return str(card_data.get("instance_id", ""))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_set_hover_lift(true)
		if not bool(card_data.get("hidden", false)):
			inspected.emit(card_data)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_set_hover_lift(false)
		inspected.emit({})
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
	frame.clip_contents = false
	artwork.visible = mode != "hidden"
	title.visible = mode != "hidden"
	type.visible = mode in ["catalog", "hand"]
	costs.visible = mode in ["catalog", "hand"]
	stats.visible = mode != "hidden"
	description.visible = mode == "catalog"
	keywords.visible = mode == "catalog"
	title_banner.visible = mode != "hidden"
	artwork_trim.visible = mode != "hidden"
	rarity_pip.visible = mode == "catalog"
	get_node("Frame/Costs/Deployment").visible = mode != "battlefield"
	get_node("Frame/Costs/Operation").visible = mode != "battlefield"
	var pip := 20.0 if mode == "battlefield" else 22.0
	var pip_font := 11 if mode == "battlefield" else 13 if mode == "catalog" else 12
	_style_pip(get_node("Frame/Costs/Deployment"), pip, pip_font)
	_style_pip(get_node("Frame/Costs/Operation"), pip, pip_font)
	_style_pip(get_node("Frame/Stats/Attack"), pip, pip_font)
	_style_pip(get_node("Frame/Stats/Defense"), pip, pip_font)
	costs.add_theme_constant_override("separation", 2)
	stats.add_theme_constant_override("separation", 2)
	stats.alignment = BoxContainer.ALIGNMENT_END
	var gap := get_node_or_null("Frame/Stats/Gap") as Control
	if gap != null:
		gap.visible = mode == "battlefield"
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	match mode:
		"catalog":
			title.add_theme_font_size_override("font_size", 13)
			type.add_theme_font_size_override("font_size", 11)
			type.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_set_rect(title, 5, 3, 116, 27)
			_set_rect(type, 118, 3, 167, 27)
			_set_rect(title_banner, 2, 1, 170, 29)
			_set_rect(artwork, 5, 30, 167, 128)
			_set_rect(artwork_trim, 5, 30, 167, 128)
			_set_rect(costs, 5, 31, 53, 55)
			_set_rect(stats, 119, 31, 167, 55)
			_set_rect(description, 6, 132, 166, 190)
			_set_rect(keywords, 6, 194, 166, 220)
			_set_rect(category_strip, 0, 0, 5, 244)
			_set_rect(rarity_pip, 156, 3, 168, 9)
		"hand":
			_set_rect(artwork, 3, 2, 105, 150)
			_set_rect(artwork_trim, 3, 2, 105, 150)
			_set_rect(costs, 2, 2, 50, 26)
			_set_rect(stats, 58, 2, 106, 26)
			type.add_theme_font_size_override("font_size", 8)
			type.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_set_rect(title, 4, 27, 66, 43)
			_set_rect(title_banner, 3, 26, 105, 44)
			_set_rect(type, 66, 27, 104, 43)
			_set_rect(keywords, 56, 16, 104, 28)
			_set_rect(category_strip, 0, 0, 5, 154)
		"battlefield":
			type.add_theme_font_size_override("font_size", 8)
			stats.alignment = BoxContainer.ALIGNMENT_BEGIN
			_set_rect(artwork, 2, 2, 70, 102)
			_set_rect(artwork_trim, 2, 2, 70, 102)
			_set_rect(stats, 2, 2, 70, 24)
			_set_rect(title, 3, 25, 69, 40)
			_set_rect(title_banner, 2, 24, 70, 41)
			_set_rect(type, 3, 88, 69, 102)
			_set_rect(costs, 3, 81, 23, 104)
			_set_rect(category_strip, 0, 0, 5, 104)
	costs.clip_contents = false
	stats.clip_contents = false
	_style_nameplate(title, title_banner, type, description, keywords)


func _style_nameplate(title: Label, banner: Control, type: Label, description: Control, keywords: Control) -> void:
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.05, 0.05, 0.04, 0.78 if mode == "catalog" else 0.62)
	plate.border_color = Color(0.55, 0.46, 0.28, 0.55)
	plate.border_width_bottom = 1
	plate.set_corner_radius_all(2)
	plate.anti_aliasing = true
	if banner is Panel:
		(banner as Panel).add_theme_stylebox_override("panel", plate)
	title.add_theme_color_override("font_color", Color(0.95, 0.89, 0.72, 0.98))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.88))
	title.add_theme_constant_override("outline_size", 3)
	type.add_theme_color_override("font_color", Color(0.86, 0.78, 0.58, 0.92))
	type.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.80))
	type.add_theme_constant_override("outline_size", 2)
	if description is Label:
		var body := description as Label
		body.add_theme_color_override("font_color", Color(0.80, 0.74, 0.62, 0.94))
		body.add_theme_font_size_override("font_size", 11)
		if mode == "catalog":
			var paper := StyleBoxFlat.new()
			paper.bg_color = Color(0.05, 0.04, 0.03, 0.72)
			paper.border_color = Color(0.42, 0.34, 0.20, 0.40)
			paper.border_width_top = 1
			paper.content_margin_left = 4
			paper.content_margin_right = 4
			paper.content_margin_top = 3
			paper.content_margin_bottom = 2
			paper.set_corner_radius_all(2)
			body.add_theme_stylebox_override("normal", paper)
	if keywords is Label:
		(keywords as Label).add_theme_color_override("font_color", Color(0.78, 0.68, 0.42, 0.90))


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
	var palette: Dictionary = role_palette(data)
	get_node("Frame/CategoryStrip").color = palette["strip"]
	var rarity := str(data.get("rarity", ""))
	var pip := get_node("Frame/RarityPip") as ColorRect
	pip.color = RARITY_PIP_COLORS.get(rarity, Color("9aa06b"))
	var plate := StyleBoxFlat.new()
	plate.bg_color = palette["plate"]
	plate.border_color = (palette["border"] as Color).darkened(0.15)
	plate.border_width_bottom = 1
	plate.set_corner_radius_all(2)
	plate.anti_aliasing = true
	get_node("Frame/TitleBanner").add_theme_stylebox_override("panel", plate)
	get_node("Frame/Type").add_theme_color_override("font_color", (palette["strip"] as Color).lightened(0.12))
	add_theme_stylebox_override("normal", _card_style(palette["fill"] as Color, palette["border"] as Color, 2))
	add_theme_stylebox_override("hover", _card_style((palette["fill"] as Color).lightened(0.08), (palette["border"] as Color).lightened(0.12), 3))
	add_theme_stylebox_override("pressed", _card_style((palette["fill"] as Color).darkened(0.08), (palette["border"] as Color).lightened(0.08), 3))


func _card_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.border_width_bottom = width + 1
	style.set_corner_radius_all(5)
	style.set_expand_margin_all(1.0 if width >= 4 else 0.0)
	style.shadow_color = Color(0.02, 0.02, 0.01, 0.45)
	style.shadow_size = 3 if width >= 3 else 1
	style.anti_aliasing = true
	return style


func _style_pip(label: Label, size: float, font_size: int) -> void:
	label.custom_minimum_size = Vector2(size, size)
	label.clip_contents = false
	var font := FontVariation.new()
	if ThemeFactoryScript.UI_FONT != null:
		font.base_font = ThemeFactoryScript.UI_FONT
	font.variation_embolden = 0.65
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f4ead2"))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 0.90))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.01, 0.70))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)


func _set_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.grow_horizontal = Control.GROW_DIRECTION_END
	control.grow_vertical = Control.GROW_DIRECTION_END
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	control.custom_minimum_size = Vector2(right - left, bottom - top)
	control.clip_contents = true
	control.position = Vector2(left, top)
	control.size = Vector2(right - left, bottom - top)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom


func _type_mark(data: Dictionary) -> String:
	if mode in ["catalog", "hand"]:
		return LocaleScript.ui("role.%s" % card_role(data))
	var kind := LocaleScript.card_kind(data)
	if not kind.is_empty():
		return kind.left(1)
	return str(data.get("category", "")).left(1).to_upper()


static func card_role(data: Dictionary) -> String:
	var category := str(data.get("category", ""))
	if category in ["Order", "Countermeasure"]:
		return ROLE_EFFECT
	if category == "Headquarters":
		return ROLE_HOLD
	var keyword_names: Array[String] = []
	for keyword in data.get("keywords", []):
		keyword_names.append(str(keyword))
	if "Guard" in keyword_names:
		return ROLE_HOLD
	for strike_word in ["Blitz", "Fury", "Bypass Guard"]:
		if strike_word in keyword_names:
			return ROLE_STRIKE
	var unit_type := str(data.get("unit_type", ""))
	if unit_type in ["Tank", "Fighter", "Bomber", "Artillery"]:
		return ROLE_STRIKE
	if int(data.get("attack", 0)) > int(data.get("defense", 0)):
		return ROLE_STRIKE
	return ROLE_HOLD


static func role_palette(data: Dictionary) -> Dictionary:
	var role := card_role(data)
	if ROLE_PALETTES.has(role):
		return ROLE_PALETTES[role]
	return ROLE_PALETTES[ROLE_HOLD]


static func inspect_meta_line(data: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(LocaleScript.ui("role.%s" % card_role(data)))
	var title := str(data.get("title", "")).strip_edges()
	var kind := LocaleScript.card_kind(data)
	if not kind.is_empty() and kind != title:
		parts.append(kind)
	var category := str(data.get("category", ""))
	if category != "Headquarters":
		parts.append("%s %d" % [LocaleScript.ui("inspect.deploy"), int(data.get("deployment_cost", 0))])
		parts.append("%s %d" % [LocaleScript.ui("inspect.operate"), int(data.get("operation_cost", 0))])
	var attack := int(data.get("attack", 0))
	var defense := int(data.get("defense", 0))
	if category in ["Unit", "Headquarters"] or attack > 0 or defense > 0:
		parts.append("%s %d" % [LocaleScript.ui("inspect.attack"), attack])
		parts.append("%s %d" % [LocaleScript.ui("inspect.defense"), defense])
	return "  ·  ".join(parts)


static func inspect_body(data: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var blurb := LocaleScript.card_blurb(data)
	if not blurb.is_empty():
		lines.append(blurb)
	for keyword in data.get("keywords", []):
		var keyword_text := LocaleScript.keyword(str(keyword))
		if keyword_text != blurb and keyword_text not in lines:
			lines.append(keyword_text)
	return "\n".join(lines)


static func inspect_copy(data: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var title := str(data.get("title", "")).strip_edges()
	if not title.is_empty():
		lines.append(title)
	lines.append(LocaleScript.ui("role.%s" % card_role(data)))
	var kind := LocaleScript.card_kind(data)
	if not kind.is_empty() and kind != title:
		lines.append(kind)
	var category := str(data.get("category", ""))
	var deploy := int(data.get("deployment_cost", 0))
	var operate := int(data.get("operation_cost", 0))
	if category != "Headquarters":
		lines.append("%s %d  ·  %s %d" % [LocaleScript.ui("inspect.deploy"), deploy, LocaleScript.ui("inspect.operate"), operate])
	var attack := int(data.get("attack", 0))
	var defense := int(data.get("defense", 0))
	if category in ["Unit", "Headquarters"] or attack > 0 or defense > 0:
		lines.append("%s %d  ·  %s %d" % [LocaleScript.ui("inspect.attack"), attack, LocaleScript.ui("inspect.defense"), defense])
	var body := inspect_body(data)
	if not body.is_empty():
		lines.append(body)
	return "\n".join(lines)


func set_duty_caption(text: String) -> void:
	if mode != "battlefield":
		return
	var type := get_node("Frame/Type") as Label
	type.visible = not text.is_empty()
	type.text = text
	type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type.add_theme_font_size_override("font_size", 8)
	type.add_theme_color_override("font_color", Color(0.92, 0.84, 0.58, 0.95))
	type.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.86))
	type.add_theme_constant_override("outline_size", 3)


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
