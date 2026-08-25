class_name TitleView
extends Control

signal start_requested
signal how_to_play_requested
signal deck_editor_requested
signal settings_requested

const LocaleScript = preload("res://scripts/ui/locale.gd")
const ThemeFactoryScript = preload("res://scripts/ui/theme_factory.gd")


func _ready() -> void:
	%StartButton.pressed.connect(func() -> void: start_requested.emit())
	%HowToPlayButton.pressed.connect(func() -> void: how_to_play_requested.emit())
	%DeckEditorButton.pressed.connect(func() -> void: deck_editor_requested.emit())
	%SettingsButton.pressed.connect(func() -> void: settings_requested.emit())
	resized.connect(_place_dock)
	initialize(null, {})
	_style_chrome()
	_place_dock()
	_play_enter()


func initialize(_router, _payload: Dictionary = {}) -> void:
	%EyebrowLabel.text = LocaleScript.ui("app.eyebrow")
	%TitleLabel.text = LocaleScript.ui("app.title")
	%SubtitleLabel.text = LocaleScript.ui("app.subtitle")
	%StartButton.text = LocaleScript.ui("title.start")
	%HowToPlayButton.text = LocaleScript.ui("title.how_to_play")
	%DeckEditorButton.text = LocaleScript.ui("title.decks")
	%SettingsButton.text = LocaleScript.ui("title.settings")
	_style_chrome()
	_place_dock()


func _style_chrome() -> void:
	var compact := size.x > 0.0 and size.x <= 1000.0
	%EyebrowLabel.add_theme_font_override("font", _tracked_font(5))
	%EyebrowLabel.add_theme_font_size_override("font_size", 12)
	%EyebrowLabel.add_theme_color_override("font_color", Color(0.90, 0.72, 0.38, 0.94))
	%EyebrowLabel.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.88))
	%EyebrowLabel.add_theme_constant_override("outline_size", 4)
	%TitleLabel.visible = true
	%TitleLabel.add_theme_font_override("font", _tracked_font(3))
	%TitleLabel.add_theme_font_size_override("font_size", 44 if compact else 56)
	%TitleLabel.add_theme_color_override("font_color", Color(0.97, 0.90, 0.68, 1))
	%TitleLabel.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.90))
	%TitleLabel.add_theme_constant_override("outline_size", 8)
	%SubtitleLabel.add_theme_font_override("font", _tracked_font(2))
	%SubtitleLabel.add_theme_font_size_override("font_size", 15 if compact else 17)
	%SubtitleLabel.add_theme_color_override("font_color", Color(0.90, 0.82, 0.66, 0.94))
	%SubtitleLabel.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.80))
	%SubtitleLabel.add_theme_constant_override("outline_size", 4)
	%StartButton.custom_minimum_size = Vector2(240 if compact else 280, 48 if compact else 52)
	var start := BattlefieldChrome.plaque(Color(0.42, 0.22, 0.08, 0.96), Color("f0c36a"), 2, 3, 14)
	%StartButton.add_theme_stylebox_override("normal", start)
	%StartButton.add_theme_stylebox_override("hover", BattlefieldChrome.plaque(Color(0.54, 0.28, 0.10, 0.98), Color("ffe08a"), 2, 3, 14))
	%StartButton.add_theme_stylebox_override("pressed", BattlefieldChrome.plaque(Color(0.26, 0.14, 0.06, 0.98), Color("c4a45a"), 2, 3, 14))
	%StartButton.add_theme_font_override("font", _tracked_font(2))
	%StartButton.add_theme_font_size_override("font_size", 18)
	%StartButton.add_theme_color_override("font_color", Color("fff4dc"))
	var quiet := StyleBoxEmpty.new()
	quiet.content_margin_left = 2
	quiet.content_margin_right = 2
	quiet.content_margin_top = 6
	quiet.content_margin_bottom = 6
	var quiet_hover := BattlefieldChrome.plaque(Color(0.10, 0.08, 0.05, 0.55), Color(0.86, 0.70, 0.38, 0.55), 1, 2, 8)
	for button in [%HowToPlayButton, %DeckEditorButton, %SettingsButton]:
		button.add_theme_stylebox_override("normal", quiet)
		button.add_theme_stylebox_override("hover", quiet_hover)
		button.add_theme_stylebox_override("pressed", quiet_hover)
		button.add_theme_font_override("font", _tracked_font(2))
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color(0.86, 0.78, 0.60, 0.94))
		button.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.80))
		button.add_theme_constant_override("outline_size", 3)


func _place_dock() -> void:
	if not is_node_ready() or not has_node("%Dock"):
		return
	var compact := size.x > 0.0 and size.x <= 1000.0
	var dock := %Dock as Control
	var width := 420.0 if compact else 520.0
	var height := 268.0 if compact else 292.0
	var left := 28.0 if compact else 48.0
	var bottom := 28.0 if compact else 36.0
	dock.offset_left = left
	dock.offset_right = left + width
	dock.offset_top = -height - bottom
	dock.offset_bottom = -bottom


func _tracked_font(spacing: int) -> Font:
	return ThemeFactoryScript.stacked(spacing, 0.05)


func _play_enter() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var dock := get_node_or_null("%Dock") as Control
	if dock == null:
		return
	dock.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(dock, "modulate:a", 1.0, 0.42)


func handle_back() -> bool:
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		start_requested.emit()
		get_viewport().set_input_as_handled()
