class_name TitleView
extends Control

signal start_requested
signal how_to_play_requested
signal deck_editor_requested

const LocaleScript = preload("res://scripts/ui/locale.gd")


func _ready() -> void:
	%StartButton.pressed.connect(func() -> void: start_requested.emit())
	%HowToPlayButton.pressed.connect(func() -> void: how_to_play_requested.emit())
	%DeckEditorButton.pressed.connect(func() -> void: deck_editor_requested.emit())


func initialize(_router, _payload: Dictionary = {}) -> void:
	%TitleLabel.text = LocaleScript.ui("app.title")
	%SubtitleLabel.text = LocaleScript.ui("app.subtitle")
	%StartButton.text = LocaleScript.ui("title.start")
	%HowToPlayButton.text = LocaleScript.ui("title.how_to_play")
	%DeckEditorButton.text = LocaleScript.ui("title.decks")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		start_requested.emit()
		get_viewport().set_input_as_handled()
