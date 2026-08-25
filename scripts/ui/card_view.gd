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
const ROLE_MARK_PATHS := {
	"strike": "res://game_assets/ui/role_bullet.png",
	"hold": "res://game_assets/ui/role_shield.png",
	"effect": "res://game_assets/ui/role_cross.png",
}
const STOCK := Color(0.76, 0.72, 0.63)
const STOCK_INK := Color(0.22, 0.21, 0.19)
const CHARCOAL := Color(0.18, 0.19, 0.21, 0.96)
const ROLE_PALETTES := {
	"strike": {
		"fill": STOCK,
		"border": Color(0.86, 0.52, 0.34),
		"plate": CHARCOAL,
		"strip": Color(0.88, 0.48, 0.30),
	},
	"hold": {
		"fill": STOCK,
		"border": Color(0.58, 0.72, 0.80),
		"plate": CHARCOAL,
		"strip": Color(0.56, 0.72, 0.80),
	},
	"effect": {
		"fill": STOCK,
		"border": Color(0.88, 0.74, 0.42),
		"plate": CHARCOAL,
		"strip": Color(0.90, 0.76, 0.40),
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
		_apply_metal_finish()
		return

	get_node("Frame/Title").text = str(data.get("title", "")).to_upper()
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
	_apply_metal_finish()
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
			fill = fill.darkened(0.16)
			border = Color(0.40, 0.38, 0.34)
	var glow := state in ["legal", "selected"]
	add_theme_stylebox_override("normal", _card_style(fill if state != "unavailable" else Color(0.42, 0.40, 0.36), border, 3 if glow else 2))
	add_theme_stylebox_override("hover", _card_style(fill.lightened(0.08), border.lightened(0.12), 5 if glow else 3))
	self_modulate = Color(0.68, 0.68, 0.68, 1.0) if state == "unavailable" else Color.WHITE
	if state == "legal":
		_start_legal_pulse()


func _get_tooltip(_at_position: Vector2) -> String:
	return tooltip_text if native_tooltip else ""


func _make_custom_tooltip(for_text: String) -> Object:
	if not native_tooltip or for_text.strip_edges().is_empty():
		return null
	return make_tooltip_sheet(for_text, card_data)


static func make_tooltip_sheet(for_text: String, data: Dictionary = {}) -> Control:
	var sheet := VBoxContainer.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_theme_constant_override("separation", 6)
	sheet.custom_minimum_size = Vector2(360, 0)
	var reason := ""
	var copy := inspect_copy(data) if not data.is_empty() and not bool(data.get("hidden", false)) else ""
	if not copy.is_empty() and for_text.ends_with(copy) and for_text != copy:
		reason = for_text.substr(0, for_text.length() - copy.length()).strip_edges()
	if not reason.is_empty():
		sheet.add_child(_tooltip_line(reason, 12, Color("e8c36a"), false))
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	header.add_child(_tooltip_portrait(data))
	var facts := VBoxContainer.new()
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	facts.add_theme_constant_override("separation", 4)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := str(data.get("title", "")).strip_edges()
	if not title.is_empty():
		facts.add_child(_tooltip_line(title, 16, Color(0.96, 0.89, 0.68), true))
	if not data.is_empty():
		var identity := inspect_identity_line(data)
		if not identity.is_empty():
			var meta_row := HBoxContainer.new()
			meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			meta_row.add_theme_constant_override("separation", 6)
			var mark := TextureRect.new()
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.custom_minimum_size = Vector2(14, 14)
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.texture = role_mark_texture(card_role(data))
			mark.modulate = (role_palette(data)["strip"] as Color).lightened(0.12)
			meta_row.add_child(mark)
			var meta_label := _tooltip_line(identity, 11, Color(0.80, 0.72, 0.52), false)
			meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			meta_row.add_child(meta_label)
			facts.add_child(meta_row)
		var stats := inspect_stats_line(data)
		if not stats.is_empty():
			facts.add_child(_tooltip_line(stats, 12, Color(0.92, 0.84, 0.62), false))
		var where := inspect_zone_line(data)
		if not where.is_empty():
			facts.add_child(_tooltip_line(where, 11, Color(0.76, 0.70, 0.54), false))
	header.add_child(facts)
	sheet.add_child(header)
	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(0.72, 0.58, 0.32, 0.70)
	sheet.add_child(rule)
	if not data.is_empty():
		var range_line := inspect_range_line(data)
		if not range_line.is_empty():
			sheet.add_child(_tooltip_line(range_line, 12, Color(0.90, 0.84, 0.70), false))
	var body := inspect_body(data) if not data.is_empty() else ""
	if body.is_empty():
		body = for_text if copy.is_empty() else ""
	if not body.is_empty():
		sheet.add_child(_tooltip_line(body, 12, Color(0.90, 0.84, 0.70), false))
	return sheet


static func _tooltip_portrait(data: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(86, 120)
	var plate := StyleBoxFlat.new()
	var border: Color = role_palette(data)["border"] if not data.is_empty() else Color(0.78, 0.64, 0.36)
	plate.bg_color = STOCK
	plate.border_color = border
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(4)
	plate.content_margin_left = 2
	plate.content_margin_top = 2
	plate.content_margin_right = 2
	plate.content_margin_bottom = 2
	frame.add_theme_stylebox_override("panel", plate)
	var art := TextureRect.new()
	art.name = "InspectArt"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(80, 112)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = inspect_art(data)
	art.material = null
	frame.material = BattlefieldChrome.paper_material(0.08)
	frame.add_child(art)
	return frame


static func inspect_art(data: Dictionary) -> Texture2D:
	var path := str(data.get("image_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	if not path.is_empty() and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return _fallback_art_texture()


static func _fallback_art_texture() -> Texture2D:
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


static func _tooltip_line(text: String, font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(248, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.82))
	label.add_theme_constant_override("outline_size", 2)
	if bold:
		label.add_theme_font_override("font", ThemeFactoryScript.stamped(1))
	else:
		label.add_theme_font_override("font", ThemeFactoryScript.stacked())
	return label


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
	var mark := get_node_or_null("Frame/RoleMark") as TextureRect
	if mark != null:
		mark.texture = null
		mark.visible = false


func _apply_back_tint(data: Dictionary) -> void:
	var tint := Color.WHITE
	var owner := str(data.get("owner_id", ""))
	var nation := str(data.get("nation", ""))
	if owner == "player" or nation == "UnitedStates":
		tint = Color(0.74, 0.84, 0.96)
	elif owner == "opponent" or nation == "SovietUnion":
		tint = Color(0.98, 0.78, 0.72)
	get_node("CardBack/BackTexture").self_modulate = tint
	get_node("CardBack").material = BattlefieldChrome.metal_material(0.08, 0.08)
	get_node("CardBack/BackTexture").material = BattlefieldChrome.metal_material(0.05, 0.05)


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
	var role_mark := get_node("Frame/RoleMark") as Control
	frame.clip_contents = false
	artwork.visible = mode != "hidden"
	title.visible = mode != "hidden"
	type.visible = mode == "catalog"
	role_mark.visible = mode != "hidden"
	costs.visible = mode in ["catalog", "hand"]
	stats.visible = mode != "hidden"
	description.visible = mode == "catalog"
	keywords.visible = mode == "catalog"
	title_banner.visible = mode != "hidden"
	artwork_trim.visible = mode != "hidden"
	rarity_pip.visible = mode == "catalog"
	category_strip.visible = false
	get_node("Frame/Costs/Deployment").visible = mode != "battlefield"
	get_node("Frame/Costs/Operation").visible = mode != "battlefield"
	var pip := 20.0 if mode == "battlefield" else 24.0 if mode == "catalog" else 22.0
	var pip_font := 11 if mode == "battlefield" else 14 if mode == "catalog" else 12
	_style_pip(get_node("Frame/Stats/Attack"), pip, pip_font)
	_style_pip(get_node("Frame/Stats/Defense"), pip, pip_font)
	stats.add_theme_constant_override("separation", 2)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	var gap := get_node_or_null("Frame/Stats/Gap") as Control
	if gap != null:
		gap.visible = true
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	match mode:
		"catalog":
			title.add_theme_font_size_override("font_size", 13)
			type.add_theme_font_size_override("font_size", 9)
			type.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_set_rect(costs, 4, 4, 36, 36)
			_layout_cost_plaque(32.0, 15, 9)
			_set_rect(title_banner, 36, 4, 168, 32)
			_set_rect(title, 40, 6, 112, 30)
			_set_rect(type, 112, 6, 146, 30)
			_set_rect(role_mark, 148, 8, 166, 28)
			_set_rect(artwork, 5, 34, 167, 168)
			_set_rect(artwork_trim, 5, 34, 167, 168)
			_set_rect(stats, 8, 140, 164, 168)
			_set_rect(keywords, 8, 172, 164, 192)
			_set_rect(description, 8, 192, 164, 236)
			_set_rect(rarity_pip, 80, 236, 92, 242)
		"hand":
			_set_rect(costs, 2, 2, 26, 26)
			_layout_cost_plaque(24.0, 13, 8)
			_set_rect(title_banner, 26, 3, 90, 24)
			_set_rect(title, 28, 4, 74, 23)
			_set_rect(role_mark, 90, 4, 106, 22)
			_set_rect(type, 90, 4, 106, 22)
			_set_rect(artwork, 3, 24, 105, 150)
			_set_rect(artwork_trim, 3, 24, 105, 150)
			_set_rect(stats, 4, 124, 104, 150)
			_set_rect(keywords, 56, 16, 104, 28)
		"battlefield":
			type.add_theme_font_size_override("font_size", 8)
			_set_rect(title_banner, 2, 2, 70, 18)
			_set_rect(title, 4, 2, 54, 18)
			_set_rect(role_mark, 54, 3, 68, 17)
			_set_rect(artwork, 2, 18, 70, 104)
			_set_rect(artwork_trim, 2, 18, 70, 104)
			_set_rect(stats, 2, 82, 70, 104)
			_set_rect(type, 16, 70, 56, 82)
			_set_rect(costs, 2, 2, 20, 20)
	costs.clip_contents = false
	stats.clip_contents = false
	role_mark.clip_contents = false
	role_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_nameplate(title, title_banner, type, description, keywords)


func _style_nameplate(title: Label, banner: Control, type: Label, description: Control, keywords: Control) -> void:
	title.add_theme_font_override("font", ThemeFactoryScript.stamped(1))
	title.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92, 0.98))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.55))
	title.add_theme_constant_override("outline_size", 1)
	type.add_theme_font_override("font", ThemeFactoryScript.stacked())
	type.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78, 0.92))
	type.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.40))
	type.add_theme_constant_override("outline_size", 1)
	if description is Label:
		var body := description as Label
		body.add_theme_font_override("font", ThemeFactoryScript.stacked())
		body.add_theme_color_override("font_color", STOCK_INK)
		body.add_theme_font_size_override("font_size", 11)
		if mode == "catalog":
			body.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	if keywords is Label:
		var chips := keywords as Label
		chips.add_theme_font_override("font", ThemeFactoryScript.stamped(1))
		chips.add_theme_color_override("font_color", STOCK_INK)


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
	var rarity := str(data.get("rarity", ""))
	var pip := get_node("Frame/RarityPip") as ColorRect
	pip.color = RARITY_PIP_COLORS.get(rarity, Color("9aa06b"))
	var plate := _stamped_plate(CHARCOAL, Color(0.10, 0.10, 0.11, 0.90))
	plate.border_width_top = 0
	plate.border_width_bottom = 1
	get_node("Frame/TitleBanner").add_theme_stylebox_override("panel", plate)
	get_node("Frame/Type").add_theme_color_override("font_color", (palette["strip"] as Color).lightened(0.18))
	_bind_role_mark(data)
	_style_metal_window(Color(0.16, 0.15, 0.13))
	add_theme_stylebox_override("normal", _card_style(STOCK, palette["border"] as Color, 2))
	add_theme_stylebox_override("hover", _card_style(STOCK.lightened(0.04), (palette["border"] as Color).lightened(0.10), 2))
	add_theme_stylebox_override("pressed", _card_style(STOCK.darkened(0.06), (palette["border"] as Color).lightened(0.06), 2))


func _card_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.border_width_bottom = width + 1
	style.set_corner_radius_all(5)
	style.set_expand_margin_all(1.0 if width >= 3 else 0.0)
	style.shadow_color = Color(0.05, 0.04, 0.03, 0.40)
	style.shadow_size = 3 if width >= 3 else 2
	style.anti_aliasing = true
	return style


func _stamped_plate(fill: Color, border: Color) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = fill
	plate.border_color = border
	plate.border_width_top = 1
	plate.border_width_bottom = 2
	plate.set_corner_radius_all(2)
	plate.content_margin_left = 4
	plate.content_margin_right = 4
	plate.content_margin_top = 2
	plate.content_margin_bottom = 2
	plate.anti_aliasing = true
	return plate


func _style_metal_window(border: Color) -> void:
	var frame := get_node_or_null("Frame") as Panel
	if frame != null:
		frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var inner := get_node_or_null("Frame/FrameInner") as Panel
	if inner != null:
		inner.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var trim := get_node_or_null("Frame/ArtworkTrim") as Panel
	if trim != null:
		var lip := StyleBoxFlat.new()
		lip.bg_color = Color(0, 0, 0, 0)
		lip.border_color = border
		lip.set_border_width_all(1)
		lip.set_corner_radius_all(1)
		lip.anti_aliasing = true
		trim.add_theme_stylebox_override("panel", lip)


func _apply_metal_finish() -> void:
	material = BattlefieldChrome.paper_material(0.10)
	var banner := get_node_or_null("Frame/TitleBanner") as Control
	if banner != null:
		banner.material = null
	var art := get_node_or_null("Frame/Artwork") as Control
	if art != null:
		art.material = null
	var op_badge := get_node_or_null("Frame/Costs/Operation/BadgeOp") as CanvasItem
	if op_badge != null:
		op_badge.visible = false
	for path in ["Frame/Costs/Deployment/BadgeCost", "Frame/Stats/Attack/BadgeAttack", "Frame/Stats/Defense/BadgeDefense"]:
		var badge := get_node_or_null(path) as Control
		if badge != null:
			badge.material = null


func _layout_cost_plaque(size: float, deploy_font: int, operate_font: int) -> void:
	var deploy := get_node("Frame/Costs/Deployment") as Label
	var operate := get_node("Frame/Costs/Operation") as Label
	_style_pip(deploy, size, deploy_font)
	deploy.position = Vector2.ZERO
	deploy.size = Vector2(size, size)
	var small := maxf(10.0, size * 0.42)
	_style_pip(operate, small, operate_font)
	operate.position = Vector2(size - small - 1.0, size - small)
	operate.size = Vector2(small, small)
	var op_badge := get_node_or_null("Frame/Costs/Operation/BadgeOp") as CanvasItem
	if op_badge != null:
		op_badge.visible = false


func _style_pip(label: Label, size: float, font_size: int) -> void:
	label.custom_minimum_size = Vector2(size, size)
	label.clip_contents = false
	label.add_theme_font_override("font", ThemeFactoryScript.stamped(1))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.94, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 0.55))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	for child in label.get_children():
		if child is TextureRect:
			(child as TextureRect).self_modulate = Color.WHITE


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


func _bind_role_mark(data: Dictionary) -> void:
	var mark := get_node_or_null("Frame/RoleMark") as TextureRect
	if mark == null:
		return
	var role := card_role(data)
	mark.texture = role_mark_texture(role)
	mark.modulate = (role_palette(data)["strip"] as Color).lightened(0.16)
	mark.visible = mode != "hidden" and mark.texture != null


func _type_mark(data: Dictionary) -> String:
	if mode == "catalog":
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


static func role_mark_texture(role: String) -> Texture2D:
	var path: String = str(ROLE_MARK_PATHS.get(role, ""))
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null


static func inspect_nation_name(data: Dictionary) -> String:
	var nation := str(data.get("nation", ""))
	if nation.is_empty():
		var definition_id := str(data.get("definition_id", data.get("id", "")))
		if definition_id.begins_with("us-"):
			nation = "UnitedStates"
		elif definition_id.begins_with("su-"):
			nation = "SovietUnion"
	if nation.is_empty():
		return ""
	return LocaleScript.nation(nation)


static func inspect_identity_line(data: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(LocaleScript.ui("role.%s" % card_role(data)))
	var title := str(data.get("title", "")).strip_edges()
	var kind := LocaleScript.card_kind(data)
	if not kind.is_empty() and kind != title and kind != parts[0]:
		parts.append(kind)
	var nation := inspect_nation_name(data)
	if not nation.is_empty():
		parts.append(nation)
	var rarity := str(data.get("rarity", "")).strip_edges()
	if not rarity.is_empty():
		parts.append(rarity)
	return "  ·  ".join(parts)


static func inspect_stats_line(data: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
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


static func inspect_zone_line(data: Dictionary) -> String:
	var zone := str(data.get("zone", ""))
	if LocaleScript.STRINGS.has("inspect.zone.%s" % zone):
		return LocaleScript.ui("inspect.zone.%s" % zone)
	if bool(data.get("countermeasure_active", false)):
		return LocaleScript.ui("inspect.armed")
	return ""


static func inspect_range_line(data: Dictionary) -> String:
	var category := str(data.get("category", ""))
	var unit_type := str(data.get("unit_type", ""))
	var key := ""
	if category == "Headquarters":
		key = "inspect.range.hq"
	elif category == "Order":
		key = "inspect.range.order"
	elif category == "Countermeasure":
		key = "inspect.range.countermeasure"
	elif LocaleScript.STRINGS.has("inspect.range.%s" % unit_type.to_lower()):
		key = "inspect.range.%s" % unit_type.to_lower()
	if key.is_empty():
		return ""
	var line := LocaleScript.ui(key)
	var blurb := LocaleScript.card_blurb(data)
	if line.is_empty() or line in blurb:
		return ""
	return line


static func inspect_meta_line(data: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var identity := inspect_identity_line(data)
	if not identity.is_empty():
		parts.append(identity)
	var stats := inspect_stats_line(data)
	if not stats.is_empty():
		parts.append(stats)
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
	if bool(data.get("countermeasure_active", false)):
		var armed := LocaleScript.ui("inspect.armed")
		if armed not in lines:
			lines.append(armed)
	return "\n".join(lines)


static func inspect_copy(data: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var title := str(data.get("title", "")).strip_edges()
	if not title.is_empty():
		lines.append(title)
	var identity := inspect_identity_line(data)
	if not identity.is_empty():
		lines.append(identity)
	var stats := inspect_stats_line(data)
	if not stats.is_empty():
		lines.append(stats)
	var where := inspect_zone_line(data)
	if not where.is_empty():
		lines.append(where)
	var range_line := inspect_range_line(data)
	if not range_line.is_empty():
		lines.append(range_line)
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
	return _fallback_art_texture()
