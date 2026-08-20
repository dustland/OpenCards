class_name SettingsDialog
extends Control

signal closed
signal animation_mode_changed(mode: String)
signal concede_requested
signal exit_requested

const LocaleScript = preload("res://scripts/ui/locale.gd")

var animation_mode := "on"


func _ready() -> void:
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close)
	%FullMotionButton.pressed.connect(_set_motion.bind("on"))
	%ReducedMotionButton.pressed.connect(_set_motion.bind("reduced"))
	%ConcedeButton.pressed.connect(_on_concede_pressed)
	%ExitButton.pressed.connect(_on_exit_pressed)
	_style_chrome()
	_bind_copy()


func present(mode: String, options: Dictionary = {}) -> void:
	animation_mode = mode if mode in ["on", "reduced"] else "on"
	%ConcedeButton.visible = bool(options.get("can_concede", false))
	visible = true
	_bind_copy()
	_refresh_motion()
	move_to_front()


func close() -> void:
	visible = false
	closed.emit()


func _set_motion(mode: String) -> void:
	if animation_mode == mode:
		return
	animation_mode = mode
	_refresh_motion()
	animation_mode_changed.emit(animation_mode)


func _on_concede_pressed() -> void:
	if not %ConcedeButton.visible:
		return
	close()
	concede_requested.emit()


func _on_exit_pressed() -> void:
	close()
	exit_requested.emit()


func _bind_copy() -> void:
	%TitleLabel.text = LocaleScript.ui("settings.title")
	%MotionLabel.text = LocaleScript.ui("settings.motion")
	%MotionHint.text = LocaleScript.ui("settings.motion_hint")
	%FullMotionButton.text = LocaleScript.ui("settings.motion_full")
	%ReducedMotionButton.text = LocaleScript.ui("settings.motion_reduced")
	%ConcedeButton.text = LocaleScript.ui("match.concede")
	%ExitButton.text = LocaleScript.ui("settings.exit")
	%CloseButton.text = LocaleScript.ui("settings.close")


func _refresh_motion() -> void:
	_paint_choice(%FullMotionButton, animation_mode == "on")
	_paint_choice(%ReducedMotionButton, animation_mode == "reduced")


func _paint_choice(button: Button, selected: bool) -> void:
	if selected:
		button.add_theme_stylebox_override("normal", BattlefieldChrome.plaque(Color(0.30, 0.23, 0.10, 0.96), Color("e8c96a"), 2, 4, 10))
		button.add_theme_color_override("font_color", Color("fff6dc"))
	else:
		button.add_theme_stylebox_override("normal", BattlefieldChrome.plaque(Color(0.10, 0.10, 0.08, 0.72), Color(0.62, 0.54, 0.34, 0.55), 1, 4, 10))
		button.add_theme_color_override("font_color", Color(0.78, 0.72, 0.56, 0.92))
	button.add_theme_stylebox_override("hover", BattlefieldChrome.plaque(Color(0.36, 0.28, 0.12, 0.96), Color("ffe08a"), 2, 4, 10))
	button.add_theme_stylebox_override("pressed", BattlefieldChrome.plaque(Color(0.20, 0.16, 0.07, 0.98), Color("c4a45a"), 2, 4, 10))


func _style_chrome() -> void:
	var panel := get_node_or_null("Center/Panel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", BattlefieldChrome.plaque(Color(0.08, 0.09, 0.07, 0.96), Color(0.78, 0.66, 0.38, 0.92), 2, 8, 26))
	%TitleLabel.add_theme_color_override("font_color", Color("f2dd9a"))
	%MotionLabel.add_theme_color_override("font_color", Color("e8d39a"))
	%MotionHint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.56, 0.92))
	%CloseButton.add_theme_stylebox_override("normal", BattlefieldChrome.plaque(Color(0.28, 0.22, 0.10, 0.96), Color("e2c36a"), 2, 5, 10))
	%ExitButton.add_theme_stylebox_override("normal", BattlefieldChrome.plaque(Color(0.12, 0.11, 0.08, 0.92), Color(0.70, 0.58, 0.36, 0.80), 1, 5, 10))
	%ExitButton.add_theme_color_override("font_color", Color(0.90, 0.82, 0.66, 0.96))
	%ConcedeButton.add_theme_stylebox_override("normal", BattlefieldChrome.plaque(Color(0.22, 0.10, 0.08, 0.94), Color(0.72, 0.38, 0.28, 0.90), 1, 5, 10))
	%ConcedeButton.add_theme_color_override("font_color", Color(0.94, 0.78, 0.70, 0.96))
	_refresh_motion()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		close()
		get_viewport().set_input_as_handled()
