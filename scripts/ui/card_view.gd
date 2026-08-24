class_name CardView
extends Button

signal card_pressed(instance_id: String)
signal card_drag_started(instance_id: String)
signal card_dropped(instance_id: String, target: Variant)
signal inspected(data: Dictionary)

const LocaleScript = preload("res://scripts/ui/locale.gd")
const ThemeFactoryScript = preload("res://scripts/ui/theme_factory.gd")
const BattlefieldChromeScript = preload("res://scripts/ui/battlefield_chrome.gd")
const CardPrintSpecScript = preload("res://scripts/ui/card_print_spec.gd")
const ART_VIGNETTE_SHADER := preload("res://shaders/card_art_vignette.gdshader")
const GLINT_SHADER := preload("res://shaders/card_metal_glint.gdshader")
const METAL_SHADER := preload("res://shaders/card_metal_surface.gdshader")

const MODE_SIZES := {
	"catalog": Vector2(180, 252),
	"hand": Vector2(116, 162),
	"battlefield": Vector2(80, 112),
	"hidden": Vector2(116, 162),
}

const RARITY_GLINT_INTENSITY := {
	"Standard": 0.28,
	"Limited": 0.36,
	"Special": 0.46,
	"Elite": 0.58,
}

const RARITY_PIP_COLORS := {
	"Standard": Color("8a9098"),
	"Limited": Color("9aacbc"),
	"Special": Color("b0a0c0"),
	"Elite": Color("d4c890"),
}

const ROLE_STRIKE := "strike"
const ROLE_HOLD := "hold"
const ROLE_EFFECT := "effect"
const ROLE_PALETTES := {
	"strike": {
		"fill": Color(0.038, 0.038, 0.040),
		"border": Color(0.82, 0.76, 0.68),
		"plate": Color(0.025, 0.026, 0.028, 0.88),
		"strip": Color(0.62, 0.56, 0.50),
	},
	"hold": {
		"fill": Color(0.036, 0.039, 0.044),
		"border": Color(0.68, 0.76, 0.84),
		"plate": Color(0.024, 0.026, 0.030, 0.88),
		"strip": Color(0.50, 0.58, 0.66),
	},
	"effect": {
		"fill": Color(0.040, 0.039, 0.036),
		"border": Color(0.84, 0.80, 0.66),
		"plate": Color(0.028, 0.027, 0.024, 0.88),
		"strip": Color(0.66, 0.62, 0.52),
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
var _art_sheen_texture: GradientTexture2D
var _frame_polish_ready := false


func _ready() -> void:
	pressed.connect(_on_pressed)
	_ensure_frame_polish()


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
	_ensure_frame_polish()
	_apply_mode_layout()

	var hidden := mode == "hidden" or bool(data.get("hidden", false))
	card_data = {"hidden": true} if hidden else data.duplicate(true)
	get_node("CardBack").visible = hidden
	get_node("Frame").visible = not hidden
	_set_collectible_overlays_visible(not hidden)
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
			border = Color("c8d0dc")
		"selected":
			border = Color("eef2f8")
		"unavailable":
			fill = fill.darkened(0.12)
			border = Color(0.32, 0.34, 0.36)
	var glow := state in ["legal", "selected"]
	add_theme_stylebox_override("normal", _card_style(fill if state != "unavailable" else Color("171616"), border, 4 if glow else 0))
	add_theme_stylebox_override("hover", _card_style(fill.lightened(0.08), border.lightened(0.12), 5 if glow else 0))
	self_modulate = Color(0.68, 0.68, 0.68, 1.0) if state == "unavailable" else Color.WHITE
	_apply_glint_state(state, palette)
	if state == "legal":
		_start_legal_pulse()


func _set_collectible_overlays_visible(show_overlays: bool) -> void:
	get_node("FrameOverlay").visible = show_overlays
	get_node("FoilOverlay").visible = show_overlays


func _apply_glint_state(state: String, palette: Dictionary) -> void:
	var glint := get_node("FoilOverlay") as TextureRect
	var material := glint.material as ShaderMaterial
	if material == null:
		return
	var rarity := str(card_data.get("rarity", "Standard"))
	var base := float(RARITY_GLINT_INTENSITY.get(rarity, 0.28))
	match state:
		"legal":
			base *= 1.35
		"selected":
			base *= 1.55
		"unavailable":
			base *= 0.25
	material.set_shader_parameter("intensity", base)
	var tint: Color = palette["border"] as Color
	material.set_shader_parameter("tint_color", tint.lerp(Color("eef2f8"), 0.35))


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
	var owner := str(data.get("owner_id", ""))
	var nation := str(data.get("nation", ""))
	get_node("CardBack/BackTexture").self_modulate = Color(0.92, 0.94, 0.98) if owner == "player" or nation == "UnitedStates" else Color(0.98, 0.94, 0.92)
	var back_panel := StyleBoxFlat.new()
	back_panel.bg_color = Color(0.04, 0.042, 0.046, 1)
	back_panel.border_color = Color(0.55, 0.58, 0.62, 0.85)
	back_panel.set_border_width_all(3)
	back_panel.border_width_bottom = 5
	back_panel.set_corner_radius_all(6)
	back_panel.shadow_color = Color(0.01, 0.01, 0.005, 0.45)
	back_panel.shadow_size = 3
	back_panel.shadow_offset = Vector2(0, 2)
	back_panel.anti_aliasing = true
	get_node("CardBack").add_theme_stylebox_override("panel", back_panel)


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
	var category_glow := get_node_or_null("Frame/CategoryStripGlow") as Control
	var title_banner := get_node("Frame/TitleBanner") as Control
	var artwork_trim := get_node("Frame/ArtworkTrim") as Control
	var artwork_vignette := get_node("Frame/ArtworkVignette") as Control
	var artwork_sheen := get_node("Frame/ArtworkSheen") as Control
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
	artwork_vignette.visible = mode != "hidden"
	artwork_sheen.visible = mode != "hidden"
	rarity_pip.visible = mode == "catalog"
	if category_glow != null:
		category_glow.visible = mode != "hidden"
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
			_set_rect(artwork_vignette, 5, 30, 167, 128)
			_set_rect(artwork_sheen, 5, 30, 167, 128)
			_set_rect(artwork_trim, 5, 30, 167, 128)
			_set_rect(costs, 5, 31, 53, 55)
			_set_rect(stats, 119, 31, 167, 55)
			_set_rect(description, 6, 132, 166, 190)
			_set_rect(keywords, 6, 194, 166, 220)
			_set_rect(category_strip, 0, 0, 4, 244)
			if category_glow != null:
				_set_rect(category_glow, 4, 1, 7, 243)
			_set_rect(rarity_pip, 156, 3, 168, 9)
		"hand":
			_set_rect(artwork, 3, 2, 105, 150)
			_set_rect(artwork_vignette, 3, 2, 105, 150)
			_set_rect(artwork_sheen, 3, 2, 105, 150)
			_set_rect(artwork_trim, 3, 2, 105, 150)
			_set_rect(costs, 2, 2, 50, 26)
			_set_rect(stats, 58, 2, 106, 26)
			type.add_theme_font_size_override("font_size", 8)
			type.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_set_rect(title, 4, 27, 66, 43)
			_set_rect(title_banner, 3, 26, 105, 44)
			_set_rect(type, 66, 27, 104, 43)
			_set_rect(keywords, 56, 16, 104, 28)
			_set_rect(category_strip, 0, 0, 4, 154)
			if category_glow != null:
				_set_rect(category_glow, 4, 1, 7, 153)
		"battlefield":
			type.add_theme_font_size_override("font_size", 8)
			stats.alignment = BoxContainer.ALIGNMENT_BEGIN
			_set_rect(artwork, 2, 2, 70, 102)
			_set_rect(artwork_vignette, 2, 2, 70, 102)
			_set_rect(artwork_sheen, 2, 2, 70, 102)
			_set_rect(artwork_trim, 2, 2, 70, 102)
			_set_rect(stats, 2, 2, 70, 24)
			_set_rect(title, 3, 25, 69, 40)
			_set_rect(title_banner, 2, 24, 70, 41)
			_set_rect(type, 3, 88, 69, 102)
			_set_rect(costs, 3, 81, 23, 104)
			_set_rect(category_strip, 0, 0, 4, 104)
			if category_glow != null:
				_set_rect(category_glow, 4, 1, 7, 103)
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
	title.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92, 0.98))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.025, 0.75))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_shadow_color", Color(0.01, 0.01, 0.015, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	type.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72, 0.92))
	type.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.025, 0.70))
	type.add_theme_constant_override("outline_size", 1)
	if description is Label:
		var body := description as Label
		body.add_theme_color_override("font_color", Color(0.58, 0.62, 0.68, 0.94))
		body.add_theme_font_size_override("font_size", 11)
		if mode == "catalog":
			body.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	if keywords is Label:
		(keywords as Label).add_theme_color_override("font_color", Color(0.52, 0.56, 0.62, 0.90))


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
	var strip: Color = palette["strip"]
	get_node("Frame/CategoryStrip").color = strip
	var glow := get_node_or_null("Frame/CategoryStripGlow") as ColorRect
	if glow != null:
		glow.color = Color(strip.r, strip.g, strip.b, 0.12)
	_style_rarity_pip(str(data.get("rarity", "")))
	var plate := StyleBoxFlat.new()
	plate.bg_color = palette["plate"]
	plate.border_color = (palette["border"] as Color).lightened(0.08)
	plate.border_color.a = 0.35
	plate.border_width_bottom = 1
	plate.border_width_top = 1
	plate.set_corner_radius_all(2)
	plate.anti_aliasing = true
	plate.shadow_color = Color(0.02, 0.02, 0.01, 0.35)
	plate.shadow_size = 1
	get_node("Frame/TitleBanner").add_theme_stylebox_override("panel", plate)
	get_node("Frame/Type").add_theme_color_override("font_color", (palette["strip"] as Color).lightened(0.12))
	_apply_inner_frame(palette)
	_style_artwork_trim(palette)
	_apply_glint_accent(data, palette)
	add_theme_stylebox_override("normal", _card_style(palette["fill"] as Color, palette["border"] as Color, 0))
	add_theme_stylebox_override("hover", _card_style((palette["fill"] as Color).lightened(0.08), (palette["border"] as Color).lightened(0.12), 0))
	add_theme_stylebox_override("pressed", _card_style((palette["fill"] as Color).darkened(0.08), (palette["border"] as Color).lightened(0.08), 0))


func _apply_glint_accent(data: Dictionary, palette: Dictionary) -> void:
	var glint := get_node("FoilOverlay") as TextureRect
	var material := glint.material as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = GLINT_SHADER
		glint.material = material
	var rarity := str(data.get("rarity", "Standard"))
	material.set_shader_parameter("intensity", RARITY_GLINT_INTENSITY.get(rarity, 0.28))
	material.set_shader_parameter("tint_color", palette["border"])


func _ensure_frame_polish() -> void:
	if _frame_polish_ready:
		return
	_frame_polish_ready = true
	var inner := get_node("Frame/FrameInner") as Panel
	var metal := ShaderMaterial.new()
	metal.shader = METAL_SHADER
	metal.set_shader_parameter("grain", 0.042)
	metal.set_shader_parameter("brush", 0.032)
	inner.material = metal
	var frame_overlay := get_node("FrameOverlay") as TextureRect
	if frame_overlay.texture == null and ResourceLoader.exists(CardPrintSpecScript.FRAME_TEXTURE):
		frame_overlay.texture = load(CardPrintSpecScript.FRAME_TEXTURE)
	var foil := get_node("FoilOverlay") as TextureRect
	if foil.texture == null and ResourceLoader.exists(CardPrintSpecScript.FOIL_MASK_TEXTURE):
		foil.texture = load(CardPrintSpecScript.FOIL_MASK_TEXTURE)
	var sheen := get_node("Frame/ArtworkSheen") as TextureRect
	sheen.texture = _artwork_sheen_texture()
	sheen.modulate = Color(1, 1, 1, 0.55)
	var vignette := get_node("Frame/ArtworkVignette") as ColorRect
	var material := ShaderMaterial.new()
	material.shader = ART_VIGNETTE_SHADER
	material.set_shader_parameter("strength", 0.52)
	vignette.material = material


func _artwork_sheen_texture() -> GradientTexture2D:
	if _art_sheen_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.92, 0.94, 0.98, 0.06))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_art_sheen_texture = GradientTexture2D.new()
		_art_sheen_texture.gradient = gradient
		_art_sheen_texture.width = 8
		_art_sheen_texture.height = 64
		_art_sheen_texture.fill_from = Vector2(0.5, 0.0)
		_art_sheen_texture.fill_to = Vector2(0.5, 1.0)
	return _art_sheen_texture


func _apply_inner_frame(palette: Dictionary) -> void:
	var inner := StyleBoxFlat.new()
	var fill: Color = palette["fill"]
	inner.bg_color = fill
	inner.bg_color.a = 0.98
	inner.border_color = (palette["border"] as Color).darkened(0.55)
	inner.border_color.a = 0.35
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(4)
	inner.shadow_color = Color(0.01, 0.01, 0.005, 0.28)
	inner.shadow_size = 2
	inner.shadow_offset = Vector2(0, 1)
	inner.anti_aliasing = true
	get_node("Frame/FrameInner").add_theme_stylebox_override("panel", inner)


func _style_artwork_trim(palette: Dictionary) -> void:
	var trim := StyleBoxFlat.new()
	trim.bg_color = Color(0, 0, 0, 0)
	var edge: Color = (palette["border"] as Color).darkened(0.45)
	edge.a = 0.55
	trim.border_color = edge
	trim.set_border_width_all(1)
	trim.border_width_top = 1
	trim.set_corner_radius_all(2)
	trim.anti_aliasing = true
	get_node("Frame/ArtworkTrim").add_theme_stylebox_override("panel", trim)


func _style_rarity_pip(rarity: String) -> void:
	var color: Color = RARITY_PIP_COLORS.get(rarity, Color("9aa06b"))
	var pip := StyleBoxFlat.new()
	pip.bg_color = color.darkened(0.55)
	pip.border_color = color.lightened(0.25)
	pip.set_border_width_all(1)
	pip.set_corner_radius_all(4)
	pip.shadow_color = Color(color.r, color.g, color.b, 0.55)
	pip.shadow_size = 2
	pip.anti_aliasing = true
	get_node("Frame/RarityPip").add_theme_stylebox_override("panel", pip)


func _card_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill.r, fill.g, fill.b, 0.0)
	style.border_color = border
	style.set_border_width_all(width)
	style.border_width_bottom = width + 1 if width > 0 else 0
	style.border_width_top = maxi(width - 1, 0)
	style.set_corner_radius_all(6)
	style.set_expand_margin_all(2.0 if width >= 4 else 0.0)
	style.shadow_color = Color(0.015, 0.012, 0.008, 0.45 if width >= 3 else 0.0)
	style.shadow_size = 6 if width >= 3 else 0
	style.shadow_offset = Vector2(0, 2)
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
	label.add_theme_color_override("font_color", Color("d8dce4"))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.025, 0.85))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.01, 0.015, 0.90))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)


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
	_legal_pulse.tween_property(self, "self_modulate", Color(1.12, 1.14, 1.18), 0.5)
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
