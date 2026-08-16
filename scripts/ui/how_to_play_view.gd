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
]


func _ready() -> void:
	%CloseButton.pressed.connect(_on_close)
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


func _on_close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
