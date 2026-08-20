class_name MulliganViewModel
extends Control

signal confirm_requested(selected_instance_ids: Array[String])
signal back_requested

const LocaleScript = preload("res://scripts/ui/locale.gd")
const CardViewScene = preload("res://scenes/ui/card_view.tscn")

var _hand_ids: Array[String] = []
var _selected: Dictionary = {}
var _locked := false
var _rendered_result := false


func _init(instance_ids: Array[String] = []) -> void:
	_hand_ids = instance_ids.duplicate()


func initialize(_main, payload: Dictionary) -> void:
	var snapshot: Dictionary = payload.get("snapshot", {})
	var players: Dictionary = snapshot.get("players", {})
	var player: Dictionary = players.get("player", {})
	var hand: Array = player.get("hand", [])
	_hand_ids.clear()
	_selected.clear()
	_locked = false
	_rendered_result = false
	%ConfirmButton.disabled = false
	%StatusLabel.text = ""
	%DifficultyLabel.text = LocaleScript.difficulty(str(payload.get("difficulty", "standard")))
	if has_node("%TitleLabel"):
		%TitleLabel.text = LocaleScript.ui("mulligan.title")
		%TitleLabel.add_theme_color_override("font_color", Color("f2dd9a"))
	if has_node("%HelpLabel"):
		%HelpLabel.text = LocaleScript.ui("mulligan.help")
	if has_node("%ConfirmButton"):
		%ConfirmButton.text = LocaleScript.ui("mulligan.confirm")
		%ConfirmButton.add_theme_stylebox_override("normal", BattlefieldChrome.plaque(Color(0.28, 0.22, 0.10, 0.96), Color("e2c36a"), 2, 5, 10))
	if has_node("%BackButton"):
		%BackButton.text = LocaleScript.ui("mulligan.back")
		if not %BackButton.pressed.is_connected(_on_back_pressed):
			%BackButton.pressed.connect(_on_back_pressed)
	_clear_hand()
	for card_value in hand:
		var card: Dictionary = card_value
		var instance_id := str(card.get("instance_id", ""))
		_hand_ids.append(instance_id)
		var view = CardViewScene.instantiate()
		view.toggle_mode = true
		view.card_pressed.connect(_on_card_pressed)
		%HandRow.add_child(view)
		view.bind(card, "hand")


func toggle(instance_id: String) -> void:
	if _locked or instance_id not in _hand_ids:
		return
	if _selected.has(instance_id):
		_selected.erase(instance_id)
	else:
		_selected[instance_id] = true


func selected_ids() -> Array[String]:
	var ordered: Array[String] = []
	for instance_id in _hand_ids:
		if _selected.has(instance_id):
			ordered.append(instance_id)
	return ordered


func lock() -> void:
	_locked = true
	if is_node_ready():
		%ConfirmButton.disabled = true
		for card in %HandRow.get_children():
			card.disabled = true


func recover_from_error(message: String) -> void:
	_locked = false
	%ConfirmButton.disabled = false
	%StatusLabel.text = message
	for card in %HandRow.get_children():
		card.disabled = false


func render_result(snapshot: Dictionary, events: Array) -> void:
	_rendered_result = true
	var players: Dictionary = snapshot.get("players", {})
	var player: Dictionary = players.get("player", {})
	var hand: Array = player.get("hand", [])
	_clear_hand()
	for card_value in hand:
		var view = CardViewScene.instantiate()
		view.disabled = true
		%HandRow.add_child(view)
		view.bind(card_value, "hand")
	%StatusLabel.text = LocaleScript.ui("mulligan.ready") % _replacement_count(events)


func has_rendered_result() -> bool:
	return _rendered_result


func _on_card_pressed(instance_id: String) -> void:
	toggle(instance_id)
	for card in %HandRow.get_children():
		if str(card.card_data.get("instance_id", "")) == instance_id:
			card.button_pressed = _selected.has(instance_id)
			card.position.y = -12.0 if card.button_pressed else 0.0
			card.add_theme_stylebox_override("pressed", _selected_card_style() if card.button_pressed else card.get_theme_stylebox("normal"))
			break


func handle_back() -> bool:
	if _locked:
		return true
	_on_back_pressed()
	return true


func _on_back_pressed() -> void:
	if _locked:
		return
	back_requested.emit()


func _on_confirm_pressed() -> void:
	if _locked:
		return
	lock()
	confirm_requested.emit(selected_ids())


func _selected_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b231e")
	style.border_color = Color("d7b557")
	style.set_border_width_all(4)
	style.set_corner_radius_all(4)
	return style


func _replacement_count(events: Array) -> int:
	var count := 0
	for event_value in events:
		if event_value is Dictionary and str(event_value.get("type", "")) == "card_returned" \
			and str(event_value.get("player_id", "")) == "player":
			count += 1
	return count


func _clear_hand() -> void:
	for child in %HandRow.get_children():
		%HandRow.remove_child(child)
		child.queue_free()
