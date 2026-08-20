class_name ResultView
extends Control

signal rematch_requested
signal deck_builder_requested
signal home_requested

const LocaleScript = preload("res://scripts/ui/locale.gd")

var result_payload: Dictionary = {}


func _ready() -> void:
	%RematchButton.pressed.connect(func() -> void: rematch_requested.emit())
	%DeckBuilderButton.pressed.connect(func() -> void:
		home_requested.emit()
		deck_builder_requested.emit()
	)
	resized.connect(queue_redraw)
	_style_chrome()


func initialize(_router, payload: Dictionary) -> void:
	result_payload = payload.duplicate(true)
	var winner_id := str(payload.get("winner_id", ""))
	%OutcomeLabel.text = LocaleScript.ui("result.victory") if winner_id == "player" else (LocaleScript.ui("result.defeat") if winner_id == "opponent" else LocaleScript.ui("result.draw"))
	%WinnerLabel.text = _winner_text(winner_id)
	%ReasonLabel.text = _reason_text(str(payload.get("reason", "unknown")))
	var turns := int(payload.get("turns", 0))
	%TurnsLabel.text = LocaleScript.ui("result.turn" if turns == 1 else "result.turns") % turns
	%SeedLabel.visible = false
	%RematchButton.text = LocaleScript.ui("result.rematch")
	%DeckBuilderButton.text = LocaleScript.ui("result.home")
	_style_chrome()
	SfxPlayer.play_event("match_ended", {"winner_id": winner_id})


func _style_chrome() -> void:
	var panel := get_node_or_null("Center/Panel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", BattlefieldChrome.plaque(Color(0.08, 0.09, 0.07, 0.88), Color(0.78, 0.66, 0.38, 0.90), 2, 8, 8))
	%OutcomeLabel.add_theme_color_override("font_color", Color("f2dd9a"))
	%OutcomeLabel.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03, 0.8))
	%OutcomeLabel.add_theme_constant_override("outline_size", 4)
	%WinnerLabel.add_theme_color_override("font_color", Color(0.88, 0.82, 0.66, 0.95))
	%ReasonLabel.add_theme_color_override("font_color", Color(0.72, 0.68, 0.54, 0.9))
	var primary := BattlefieldChrome.plaque(Color(0.28, 0.22, 0.10, 0.96), Color("e2c36a"), 2, 5, 10)
	%RematchButton.add_theme_stylebox_override("normal", primary)
	%DeckBuilderButton.add_theme_stylebox_override("normal", BattlefieldChrome.plaque(Color(0.14, 0.15, 0.12, 0.86), Color(0.62, 0.54, 0.34, 0.75), 1, 4, 10))
	queue_redraw()


func _draw() -> void:
	var panel := get_node_or_null("Center/Panel") as Control
	if panel == null:
		return
	var world := panel.get_global_rect()
	var rect := Rect2(get_global_transform().affine_inverse() * world.position, world.size)
	BattlefieldChrome.draw_corner_brackets(self, rect.grow(6.0), Color(0.86, 0.74, 0.42, 0.50), 16.0, 1.5)
	BattlefieldChrome.draw_rivets(self, rect.grow(2.0), Color(0.82, 0.70, 0.40, 0.75), 10.0)


func _winner_text(winner_id: String) -> String:
	match winner_id:
		"player": return LocaleScript.ui("result.player_wins")
		"opponent": return LocaleScript.ui("result.opponent_wins")
		_: return LocaleScript.ui("result.no_winner")


func _reason_text(reason: String) -> String:
	var key := "reason.%s" % reason
	return LocaleScript.ui(key) if LocaleScript.STRINGS.has(key) else reason.replace("_", " ").capitalize()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		rematch_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()


func handle_back() -> bool:
	home_requested.emit()
	deck_builder_requested.emit()
	return true
