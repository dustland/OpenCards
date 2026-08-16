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
		deck_builder_requested.emit()
		get_viewport().set_input_as_handled()
