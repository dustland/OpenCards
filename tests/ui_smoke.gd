extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const LocaleScript = preload("res://scripts/ui/locale.gd")
const GameAction = preload("res://scripts/core/game_action.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 720)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = viewport_size
		await process_frame
		await _run_complete_flow(viewport_size)
	await process_frame
	await process_frame
	if not _failed:
		print("UI smoke passed at 1280x720 and 1024x720")
	quit(1 if _failed else 0)


func _run_complete_flow(viewport_size: Vector2i) -> void:
	var app = MainScene.instantiate()
	root.add_child(app)
	await _frames(3)
	_check(app.current_screen != null, "Title is instantiated")
	_check_controls(app.current_screen, viewport_size, ["%StartButton", "%HowToPlayButton", "%DeckEditorButton", "%SettingsButton"])

	var complete_deck: Dictionary = app.catalog.decks_by_id["us-starter"].duplicate(true)
	app.selected_deck_id = str(complete_deck.get("id", ""))
	app.selected_player_deck = complete_deck.duplicate(true)
	app.start_mulligan(complete_deck, "easy", 440)
	await _frames(2)
	_check_controls(app.current_screen, viewport_size, ["%HandRow", "%DifficultyLabel", "%StatusLabel", "%ConfirmButton"])
	app.current_screen.confirm_requested.emit([] as Array[String])
	await _frames(5)
	_check(app.controller != null and app.controller.state.phase == "action", "Mulligan reaches Match")
	_check_controls(app.current_screen, viewport_size, ["%OpponentHQ", "%OpponentSupport", "%Frontline", "%PlayerHQ", "%PlayerSupport", "%CreditLabel", "%EndTurnButton", "%HandScroll", "%TimelinePanel"])
	_check_rendered_perspective(app.current_screen, app.controller)

	_check(app.controller.state.active_player_id == "player", "controlled fixture reaches player turn")
	var opponent = app.controller.state.players.opponent
	while not opponent.deck.is_empty():
		var exhausted_card = opponent.deck.pop_back()
		exhausted_card.zone = "discard"
		opponent.discard.append(exhausted_card)
	opponent.headquarters.current_defense = 1
	opponent.fatigue = 1
	var end_turn = GameAction.create("end_turn", "player", "", [], {}, app.controller.state.sequence)
	await app.submit_player_action(end_turn)
	await _frames(2)
	_check_controls(app.current_screen, viewport_size, ["%OutcomeLabel", "%WinnerLabel", "%ReasonLabel", "%TurnsLabel", "%RematchButton", "%DeckBuilderButton"])
	var result_payload: Dictionary = app.current_screen.result_payload
	_check(result_payload.winner_id == "player", "accepted fatal fatigue routes player winner")
	_check(result_payload.reason == "fatigue", "accepted fatal fatigue routes exact reason")
	_check(result_payload.turns == app.controller.state.turn, "Result routes authoritative turn count")
	_check(result_payload.seed == app.controller.state.seed, "Result routes authoritative seed")
	_check(not (result_payload.get("replay_log", {}) as Dictionary).is_empty(), "Result retains replay data")
	var replay_actions: Array = result_payload.replay_log.get("actions", [])
	_check(not replay_actions.is_empty() and str(replay_actions.back().action.type) == "end_turn", "terminal route follows an accepted recorded GameAction")
	var old_seed: int = app.controller.state.seed
	app._match_rng.seed = 991
	app.current_screen.rematch_requested.emit()
	await _frames(2)
	_check(app.controller.state.seed != old_seed, "Rematch uses a fresh deterministic seed")
	_check(app.selected_player_deck == complete_deck and app.difficulty == "easy", "Rematch preserves complete deck and difficulty")
	_check_controls(app.current_screen, viewport_size, ["%HandRow", "%ConfirmButton"])

	app.show_screen("result", {"winner_id": "", "reason": "draw", "turns": 0, "seed": app.controller.state.seed, "replay_log": {}})
	await _frames(1)
	app.current_screen.deck_builder_requested.emit()
	await _frames(2)
	_check_controls(app.current_screen, viewport_size, ["%StartButton", "%HowToPlayButton", "%DeckEditorButton", "%SettingsButton"])
	_check(app.selected_deck_id == str(complete_deck.id) and app.difficulty == "easy", "Home return preserves preference")
	app.queue_free()
	await _frames(3)


func _check_controls(screen: Control, viewport_size: Vector2i, paths: Array[String]) -> void:
	_check(screen.size == Vector2(viewport_size), "%s fills %s" % [screen.name, viewport_size])
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	var controls: Array[Control] = []
	for path in paths:
		_check(screen.has_node(path), "%s exposes %s" % [screen.name, path])
		if not screen.has_node(path):
			continue
		var control := screen.get_node(path) as Control
		controls.append(control)
		_check(control.is_visible_in_tree(), "%s is visible" % path)
		_check(bounds.encloses(control.get_global_rect()), "%s stays inside %s" % [path, viewport_size])
	for index in range(controls.size()):
		for other_index in range(index + 1, controls.size()):
			var first := controls[index]
			var second := controls[other_index]
			if first.is_ancestor_of(second) or second.is_ancestor_of(first):
				continue
			_check(not first.get_global_rect().intersects(second.get_global_rect()), "%s and %s do not overlap" % [paths[index], paths[other_index]])


func _check_rendered_perspective(view: Control, match_controller) -> void:
	var private_values: Array[String] = []
	for card in match_controller.state.players.opponent.hand:
		private_values.append(str(card.instance_id))
		private_values.append(str(card.definition_id))
		private_values.append(str(card.title))
	var rendered_hand: Array = view.snapshot.get("players", {}).get("opponent", {}).get("hand", [])
	_check(rendered_hand.size() == match_controller.state.players.opponent.hand.size(), "rendered hidden hand count is exact")
	_check("%s %d" % [LocaleScript.ui("status.hand"), rendered_hand.size()] in view.get_node("%OpponentLabel").text, "visible opponent hand count is exact")
	for card_value in rendered_hand:
		_check(card_value == {"hidden": true}, "rendered hidden card contains no private identity")
	var rendered_text := _node_text(view)
	for private_value in private_values:
		if not private_value.is_empty():
			_check(private_value not in rendered_text, "rendered MatchView omits opponent private value")


func _node_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button or node is LineEdit:
		result += str(node.text) + "\n"
	for child in node.get_children():
		result += _node_text(child)
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("UI smoke: %s" % message)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
