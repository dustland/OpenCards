class_name HowToPlayView
extends Control

signal closed

const LocaleScript = preload("res://scripts/ui/locale.gd")

const STEPS := [
	["how_to.1.title", "how_to.1.body"],
	["how_to.2.title", "how_to.2.body"],
	["how_to.3.title", "how_to.3.body"],
	["how_to.4.title", "how_to.4.body"],
	["how_to.5.title", "how_to.5.body"],
	["how_to.6.title", "how_to.6.body"],
]


func _ready() -> void:
	%CloseButton.pressed.connect(_on_close)
	_style_chrome()
	_bind_copy()


func initialize(_router = null, _payload: Dictionary = {}) -> void:
	_bind_copy()


func _bind_copy() -> void:
	%TitleLabel.text = LocaleScript.ui("how_to.title")
	%CloseButton.text = LocaleScript.ui("how_to.close")
	for index in range(STEPS.size()):
		var row: Array = STEPS[index]
		var heading: Label = %Steps.get_child(index).get_node("Heading")
		var body: Label = %Steps.get_child(index).get_node("Body")
		heading.text = LocaleScript.ui(str(row[0]))
		body.text = LocaleScript.ui(str(row[1]))
	if has_node("%CardDeployLabel"):
		%CardDeployLabel.text = LocaleScript.ui("how_to.card.deploy")
		%CardOperateLabel.text = LocaleScript.ui("how_to.card.operate")
		%CardAttackLabel.text = LocaleScript.ui("how_to.card.attack")
		%CardDefenseLabel.text = LocaleScript.ui("how_to.card.defense")


func _style_chrome() -> void:
	var panel := get_node_or_null("Center/Panel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", BattlefieldChrome.plaque(Color(0.08, 0.09, 0.07, 0.94), Color(0.78, 0.66, 0.38, 0.92), 2, 8, 26))
	%TitleLabel.add_theme_color_override("font_color", Color("f2dd9a"))
	%CloseButton.add_theme_stylebox_override("normal", BattlefieldChrome.plaque(Color(0.28, 0.22, 0.10, 0.96), Color("e2c36a"), 2, 5, 10))
	for index in range(%Steps.get_child_count()):
		var heading := %Steps.get_child(index).get_node_or_null("Heading") as Label
		if heading != null:
			heading.add_theme_color_override("font_color", Color("e8d39a"))


func _on_close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
