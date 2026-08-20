class_name Main
extends Control

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const ContentValidatorScript = preload("res://scripts/content/content_validator.gd")
const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const ContentErrorViewScene = preload("res://scenes/ui/content_error_view.tscn")
const GameActionScript = preload("res://scripts/core/game_action.gd")
const MatchControllerScript = preload("res://scripts/core/match_controller.gd")
const AIPlayerScript = preload("res://scripts/ai/ai_player.gd")
const OnboardingStoreScript = preload("res://scripts/ui/onboarding_store.gd")
const HowToPlayScene = preload("res://scenes/ui/how_to_play_view.tscn")
const SettingsDialogScene = preload("res://scenes/ui/settings_dialog.tscn")
const LocaleScript = preload("res://scripts/ui/locale.gd")

const VALID_SCREENS := ["title", "deck_builder", "mulligan", "match", "result"]
const SCREEN_PATHS := {
	"title": "res://scenes/ui/title_view.tscn",
	"deck_builder": "res://scenes/ui/deck_builder_view.tscn",
	"mulligan": "res://scenes/ui/mulligan_view.tscn",
	"match": "res://scenes/ui/match_view.tscn",
	"result": "res://scenes/ui/result_view.tscn",
}
const CONTENT_PATHS := [
	"res://data/cards.json",
	"res://data/abilities.json",
	"res://data/decks.json",
	"res://data/rules.json",
]

@onready var screen_host: Control = %ScreenHost

var current_screen: Control
var catalog: ContentCatalog
var selected_deck_id := "us-starter"
var selected_player_deck: Dictionary = {}
var difficulty := "standard"
var controller: MatchController
var ai: AIPlayer
var screen_factory: Callable
var _match_rng := RandomNumberGenerator.new()
var _mulligan_submitted := false
var _mulligan_action_submitter: Callable
var _match_submission_active := false
var _match_generation := 0
var _terminal_events: Array = []
var onboarding_store = OnboardingStoreScript.new()
var animation_mode := "on"
var animation_preferences_path := "user://match-preferences.cfg"


func _ready() -> void:
	theme = ThemeFactory.create()
	_install_sfx()
	_load_animation_mode()
	_match_rng.randomize()
	_present_boot_load(true)
	_validate_and_start()
	_present_boot_load(false)


func _install_sfx() -> void:
	if has_node("SfxPlayer"):
		return
	var sfx := SfxPlayer.new()
	sfx.name = "SfxPlayer"
	add_child(sfx)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _handle_back():
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not _handle_back():
			get_tree().quit()


func _handle_back() -> bool:
	var settings = get_node_or_null("SettingsDialog")
	if settings != null and bool(settings.visible):
		settings.close()
		return true
	var how_to = get_node_or_null("HowToPlayView")
	if how_to != null:
		how_to._on_close()
		return true
	if current_screen != null and current_screen.has_method("handle_back"):
		return bool(current_screen.handle_back())
	return false


func _toggle_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func show_screen(screen_name: String, payload: Dictionary = {}) -> void:
	assert(screen_name in VALID_SCREENS, "unknown screen: %s" % screen_name)
	_clear_screen()
	var scene_path: String = SCREEN_PATHS[screen_name]
	if screen_factory.is_valid():
		current_screen = screen_factory.call(scene_path)
	elif not ResourceLoader.exists(scene_path):
		current_screen = _pending_screen(screen_name)
	else:
		var packed_scene: PackedScene = load(scene_path)
		current_screen = packed_scene.instantiate()
	if current_screen == null:
		current_screen = _pending_screen(screen_name)
	screen_host.add_child(current_screen)
	if current_screen.has_method("initialize"):
		if screen_name == "match" and not payload.has("onboarding"):
			payload["onboarding"] = onboarding_store.load()
		current_screen.initialize(self, payload)
	if screen_name == "match" and current_screen.has_method("set_animation_mode"):
		current_screen.set_animation_mode(animation_mode)
	if screen_name == "title":
		if current_screen.has_signal("start_requested"):
			current_screen.start_requested.connect(_on_title_start)
		if current_screen.has_signal("how_to_play_requested"):
			current_screen.how_to_play_requested.connect(show_how_to_play)
		if current_screen.has_signal("deck_editor_requested"):
			current_screen.deck_editor_requested.connect(_on_deck_builder_requested)
		if current_screen.has_signal("settings_requested"):
			current_screen.settings_requested.connect(show_settings)
	if screen_name == "deck_builder":
		if current_screen.has_signal("play_requested"):
			current_screen.play_requested.connect(_on_play_requested)
		if current_screen.has_signal("home_requested"):
			current_screen.home_requested.connect(_on_home_requested)
	if screen_name == "mulligan":
		if current_screen.has_signal("confirm_requested"):
			current_screen.confirm_requested.connect(_on_mulligan_confirmed)
		if current_screen.has_signal("back_requested"):
			current_screen.back_requested.connect(_on_home_requested)
	if screen_name == "match" and current_screen.has_signal("action_requested"):
		current_screen.action_requested.connect(submit_player_action)
		if current_screen.has_signal("how_to_play_requested"):
			current_screen.how_to_play_requested.connect(show_how_to_play)
		if current_screen.has_signal("settings_requested"):
			current_screen.settings_requested.connect(show_settings)
		_refresh_match_view()
		call_deferred("start_match_turn_flow")
		if bool(payload.get("auto_how_to_play", false)) and not bool(onboarding_store.load().get("how_to_play_seen", false)):
			call_deferred("show_how_to_play")
	if screen_name == "result":
		if current_screen.has_signal("rematch_requested"):
			current_screen.rematch_requested.connect(_on_rematch_requested)
		if current_screen.has_signal("deck_builder_requested"):
			current_screen.deck_builder_requested.connect(_on_home_requested)
		if current_screen.has_signal("home_requested"):
			current_screen.home_requested.connect(_on_home_requested)


func _on_title_start() -> void:
	_start_selected_match()


func _start_selected_match() -> void:
	var deck := selected_player_deck.duplicate(true)
	if deck.is_empty() and catalog != null and catalog.decks_by_id.has(selected_deck_id):
		deck = (catalog.decks_by_id[selected_deck_id] as Dictionary).duplicate(true)
	if deck.is_empty() and catalog != null and catalog.decks_by_id.has("us-starter"):
		deck = (catalog.decks_by_id["us-starter"] as Dictionary).duplicate(true)
		selected_deck_id = "us-starter"
	start_mulligan(deck, difficulty)


func show_how_to_play() -> void:
	if get_node_or_null("HowToPlayView") != null:
		return
	var overlay = HowToPlayScene.instantiate()
	overlay.name = "HowToPlayView"
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.closed.connect(_on_how_to_play_closed)


func show_settings(context: Dictionary = {}) -> void:
	var overlay = get_node_or_null("SettingsDialog")
	if overlay == null:
		overlay = SettingsDialogScene.instantiate()
		overlay.name = "SettingsDialog"
		add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.animation_mode_changed.connect(set_animation_mode)
		overlay.concede_requested.connect(_on_settings_concede)
		overlay.exit_requested.connect(_on_settings_exit)
	var options := context.duplicate(true)
	if current_screen != null and current_screen.has_method("can_concede"):
		options["can_concede"] = current_screen.can_concede()
	else:
		options["can_concede"] = false
	overlay.present(animation_mode, options)


func _on_settings_concede() -> void:
	if current_screen != null and current_screen.has_method("_on_concede_pressed"):
		current_screen._on_concede_pressed()


func _on_settings_exit() -> void:
	get_tree().quit()


func _on_how_to_play_closed() -> void:
	onboarding_store.complete("how_to_play_seen")


func _on_play_requested(deck_id: String, selected_difficulty: String) -> void:
	selected_deck_id = deck_id
	difficulty = selected_difficulty
	selected_player_deck = {}
	if current_screen != null and current_screen.has_method("selected_deck"):
		selected_player_deck = (current_screen.selected_deck() as Dictionary).duplicate(true)
	start_mulligan(selected_player_deck, difficulty)


func start_mulligan(player_deck: Dictionary, selected_difficulty: String, seed: int = 0) -> void:
	if catalog == null or not player_deck.has("cards") or not (player_deck.cards is Array):
		return
	var opponent_deck := _shipped_opponent_deck(str(player_deck.get("id", "")))
	if opponent_deck.is_empty():
		return
	var match_seed := seed if seed != 0 else int(_match_rng.randi())
	difficulty = selected_difficulty
	selected_player_deck = player_deck.duplicate(true)
	controller = MatchControllerScript.create(
		catalog.cards_by_id,
		(player_deck.cards as Array).duplicate(),
		(opponent_deck.cards as Array).duplicate(),
		match_seed,
	)
	ai = AIPlayerScript.create(difficulty, match_seed)
	_terminal_events.clear()
	var started = controller.submit_action(GameActionScript.create("start_match", "system"))
	if not started.accepted or controller.state.phase != "mulligan":
		controller = null
		ai = null
		return
	_mulligan_submitted = false
	show_screen("mulligan", {
		"catalog": catalog,
		"deck_id": str(player_deck.get("id", "")),
		"difficulty": difficulty,
		"player_deck": player_deck.duplicate(true),
		"snapshot": controller.state.snapshot_for("player"),
	})


func ai_mulligan_selection(snapshot: Dictionary) -> Array[String]:
	var players: Dictionary = snapshot.get("players", {})
	var opponent: Dictionary = players.get("opponent", {})
	var hand: Array = opponent.get("hand", [])
	var seen_definitions := {}
	var selected: Array[String] = []
	for card_value in hand:
		if not (card_value is Dictionary):
			continue
		var card: Dictionary = card_value
		var definition_id := str(card.get("definition_id", ""))
		var duplicate := seen_definitions.has(definition_id)
		seen_definitions[definition_id] = true
		var unaffordable := int(card.get("deployment_cost", 0)) > 3
		if duplicate or unaffordable:
			selected.append(str(card.get("instance_id", "")))
	return selected


func set_mulligan_action_submitter(submitter: Callable) -> void:
	_mulligan_action_submitter = submitter


func _on_mulligan_confirmed(selected_ids: Array[String]) -> void:
	if _mulligan_submitted or controller == null or ai == null or controller.state.phase != "mulligan":
		return
	var selection_error := _validate_mulligan_selection(selected_ids)
	if not selection_error.is_empty():
		_recover_mulligan(selection_error)
		return
	_mulligan_submitted = true
	var candidate: MatchController = _fresh_started_controller()
	if candidate == null:
		_recover_mulligan("Could not prepare the match. Confirm your hand again.")
		return
	var rendered_events: Array = []
	var no_targets: Array[String] = []
	var ai_ids := ai_mulligan_selection(candidate.state.snapshot_for("opponent"))
	var steps := [
		["mulligan", "player", selected_ids],
		["mulligan", "opponent", ai_ids],
		["confirm_mulligan", "player", no_targets],
		["confirm_mulligan", "opponent", no_targets],
	]
	for step_index in range(steps.size()):
		var step: Array = steps[step_index]
		var targets: Array[String] = step[2]
		var action = GameActionScript.create(str(step[0]), str(step[1]), "", targets, {}, candidate.state.sequence)
		var result = _mulligan_action_submitter.call(candidate, action, step_index) \
			if _mulligan_action_submitter.is_valid() else candidate.submit_action(action)
		if not result.accepted:
			_recover_mulligan(result.message if not result.message.is_empty() else "Confirm your opening hand again.")
			return
		rendered_events.append_array(result.events)
	if candidate.state.phase != "action":
		_recover_mulligan("Match setup did not complete. Confirm your hand again.")
		return
	controller = candidate
	if current_screen != null and current_screen.has_method("render_result"):
		current_screen.render_result(controller.state.snapshot_for("player"), rendered_events)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	show_screen("match", {
		"controller": controller,
		"ai": ai,
		"difficulty": difficulty,
		"events": rendered_events,
		"snapshot": controller.state.snapshot_for("player"),
		"auto_how_to_play": true,
	})


func _validate_mulligan_selection(selected_ids: Array[String]) -> String:
	var hand_ids := {}
	for card in controller.state.players.player.hand:
		hand_ids[card.instance_id] = true
	var seen := {}
	for instance_id in selected_ids:
		if seen.has(instance_id):
			return "Select each opening card only once."
		if not hand_ids.has(instance_id):
			return "One selected card is no longer in your opening hand. Choose again."
		seen[instance_id] = true
	return ""


func _fresh_started_controller() -> MatchController:
	var candidate: MatchController = MatchControllerScript.create(
		controller.card_definitions,
		(controller.initial_deck_ids.player as Array).duplicate(),
		(controller.initial_deck_ids.opponent as Array).duplicate(),
		controller.state.seed,
	)
	var started = candidate.submit_action(GameActionScript.create("start_match", "system"))
	return candidate if started.accepted and candidate.state.phase == "mulligan" else null


func _recover_mulligan(message: String) -> void:
	_mulligan_submitted = false
	if current_screen != null and current_screen.has_method("recover_from_error"):
		current_screen.recover_from_error(message)


func submit_player_action(action: GameAction) -> void:
	if _match_submission_active or controller == null or current_screen == null:
		return
	if controller.state.phase != "action" or controller.state.active_player_id != "player":
		return
	_match_submission_active = true
	_match_generation += 1
	var generation := _match_generation
	current_screen.set_input_locked(true)
	var before_snapshot := controller.state.snapshot_for("player")
	var result = controller.submit_action(action)
	if result.accepted:
		var milestone := onboarding_milestone_for(action)
		if not milestone.is_empty():
			onboarding_store.complete(milestone)
	if result.accepted:
		await _animate_match_result(result, before_snapshot, controller.state.snapshot_for("player"), generation)
	else:
		_render_match_result(result)
	if result.accepted and not _route_match_result_if_complete():
		await _drive_ai_turn(generation)
	if generation == _match_generation and current_screen != null and current_screen.has_method("set_input_locked"):
		_refresh_match_view()
		current_screen.set_input_locked(false)
	_match_submission_active = false


func start_match_turn_flow() -> void:
	if _match_submission_active or controller == null or ai == null or current_screen == null:
		return
	if controller.state.phase != "action" or controller.state.active_player_id != "opponent":
		return
	_match_submission_active = true
	_match_generation += 1
	var generation := _match_generation
	if current_screen.has_method("set_input_locked"):
		current_screen.set_input_locked(true)
	await _drive_ai_turn(generation)
	if generation == _match_generation and current_screen != null and current_screen.has_method("set_input_locked"):
		_refresh_match_view()
		current_screen.set_input_locked(false)
	_match_submission_active = false


func _drive_ai_turn(generation: int) -> void:
	var actions_this_turn := 0
	var last_sequence := controller.state.sequence
	var last_toggle_id := ""
	while generation == _match_generation and controller != null \
			and controller.state.phase == "action" and controller.state.active_player_id == "opponent":
		if actions_this_turn >= 64:
			controller.abort_invalid("ai_action_limit", {"limit": 64})
			_route_match_result_if_complete()
			return
		var action = ai.choose_action(controller, "opponent")
		if action != null and action.type == "toggle_countermeasure" and action.source_id == last_toggle_id:
			var legal_end_turn = controller.legal_actions("opponent").filter(func(candidate) -> bool: return candidate.type == "end_turn")
			action = legal_end_turn[0] if not legal_end_turn.is_empty() else GameActionScript.create("end_turn", "opponent")
		if action == null or action.type.is_empty():
			var legal_end_turn = controller.legal_actions("opponent").filter(func(candidate) -> bool: return candidate.type == "end_turn")
			if legal_end_turn.is_empty():
				controller.abort_invalid("ai_deadlock", {"sequence": controller.state.sequence})
				_route_match_result_if_complete()
				return
			action = legal_end_turn[0]
		var before_snapshot := controller.state.snapshot_for("player")
		var result = controller.submit_action(action)
		if result.accepted:
			await _animate_match_result(result, before_snapshot, controller.state.snapshot_for("player"), generation)
		else:
			_render_match_result(result)
		if not result.accepted:
			controller.abort_invalid("ai_rejected_action", {"reason_code": result.reason_code})
			_route_match_result_if_complete()
			return
		if controller.state.sequence <= last_sequence:
			controller.abort_invalid("ai_stale_sequence", {"sequence": controller.state.sequence})
			_route_match_result_if_complete()
			return
		last_sequence = controller.state.sequence
		last_toggle_id = action.source_id if action.type == "toggle_countermeasure" else ""
		actions_this_turn += 1
		if _route_match_result_if_complete():
			return
		await Engine.get_main_loop().process_frame


func _render_match_result(result: ActionResult) -> void:
	if current_screen == null:
		return
	if result.accepted:
		_terminal_events = result.events.duplicate(true)
		current_screen.render_events(result.events)
	else:
		current_screen.show_rejection(result.reason_code, result.message)
	current_screen.render_snapshot(controller.state.snapshot_for("player"))

func _animate_match_result(result: ActionResult, before_snapshot: Dictionary, after_snapshot: Dictionary, generation: int) -> void:
	if current_screen == null or generation != _match_generation:
		return
	_terminal_events = result.events.duplicate(true)
	if current_screen.has_method("play_motion"):
		await current_screen.play_motion(result.events, before_snapshot, after_snapshot)
	if current_screen == null or generation != _match_generation:
		return
	current_screen.render_events(result.events)
	current_screen.render_snapshot(after_snapshot)


func _refresh_match_view() -> void:
	if current_screen == null or controller == null or not current_screen.has_method("set_legal_actions"):
		return
	current_screen.render_snapshot(controller.state.snapshot_for("player"))
	current_screen.set_legal_actions(controller.legal_actions("player"))
	if current_screen.has_method("set_onboarding_state"):
		current_screen.set_onboarding_state(onboarding_store.load())


static func onboarding_milestone_for(action: GameAction) -> String:
	match action.type:
		"deploy_unit":
			return "deployed_unit"
		"move_unit":
			return "moved_to_frontline" if str(action.payload.get("zone", "")) == "frontline" else ""
		"attack_unit", "attack_hq":
			return "completed_attack"
	return ""


func set_animation_mode(mode: String) -> void:
	if mode not in ["on", "reduced"]:
		return
	animation_mode = mode
	var config := ConfigFile.new()
	config.set_value("match", "animation_mode", animation_mode)
	config.save(animation_preferences_path)
	if current_screen != null and current_screen.has_method("set_animation_mode"):
		current_screen.set_animation_mode(animation_mode)


func _load_animation_mode() -> void:
	var config := ConfigFile.new()
	if config.load(animation_preferences_path) == OK:
		var stored := str(config.get_value("match", "animation_mode", "on"))
		animation_mode = stored if stored in ["on", "reduced"] else "on"


func _route_match_result_if_complete() -> bool:
	if controller == null or (controller.state.phase not in ["complete", "invalid"] and controller.state.winner_id.is_empty()):
		return false
	_match_generation += 1
	var payload := {
		"winner_id": controller.state.winner_id,
		"reason": terminal_reason(
			controller.state.phase,
			controller.state.winner_id,
			_terminal_events,
			controller.replay_log.terminal_result if controller.replay_log != null else {},
		),
		"turns": controller.state.turn,
		"seed": controller.state.seed,
		"replay_log": controller.replay_log.to_dict() if controller.replay_log != null else {},
	}
	show_screen("result", payload)
	return true


static func terminal_reason(phase: String, winner_id: String, events: Array, terminal_result: Dictionary) -> String:
	if phase == "invalid":
		return str(terminal_result.get("diagnostic", {}).get("code", "invalid"))
	if winner_id.is_empty():
		return "draw"
	var event_types: Array[String] = []
	for event_value in events:
		if event_value is Dictionary:
			event_types.append(str((event_value as Dictionary).get("type", "")))
	if "player_conceded" in event_types:
		return "concede"
	if "match_ended" in event_types:
		return "fatigue" if "fatigue_damage" in event_types else "headquarters_destroyed"
	return "match_complete"


func _on_rematch_requested() -> void:
	if selected_player_deck.is_empty():
		return
	start_mulligan(selected_player_deck.duplicate(true), difficulty, _next_match_seed())


func _next_match_seed() -> int:
	var previous_seed := controller.state.seed if controller != null else 0
	var next_seed := int(_match_rng.randi())
	while next_seed == 0 or next_seed == previous_seed:
		next_seed = int(_match_rng.randi())
	return next_seed


func _on_home_requested() -> void:
	controller = null
	ai = null
	_terminal_events.clear()
	show_screen("title", {"deck_id": selected_deck_id, "difficulty": difficulty})


func _on_deck_builder_requested() -> void:
	var player_deck := selected_player_deck.duplicate(true)
	controller = null
	ai = null
	_terminal_events.clear()
	show_screen("deck_builder", {
		"catalog": catalog,
		"deck_id": selected_deck_id,
		"difficulty": difficulty,
		"player_deck": player_deck,
	})


func _shipped_opponent_deck(player_deck_id: String) -> Dictionary:
	var preferred_id := "su-starter" if player_deck_id != "su-starter" else "us-starter"
	if catalog.decks_by_id.has(preferred_id):
		return (catalog.decks_by_id[preferred_id] as Dictionary).duplicate(true)
	for deck_value in catalog.decks:
		if deck_value is Dictionary and str(deck_value.get("id", "")) != player_deck_id:
			return (deck_value as Dictionary).duplicate(true)
	return {}


func _present_boot_load(visible: bool) -> void:
	if not has_node("%BootLoad"):
		return
	%BootLoad.visible = visible
	if visible and has_node("%LoadingLabel"):
		%LoadingLabel.text = LocaleScript.ui("title.loading")


func _validate_and_start() -> void:
	catalog = ContentCatalogScript.load_from_paths(
		CONTENT_PATHS[0], CONTENT_PATHS[1], CONTENT_PATHS[2], CONTENT_PATHS[3]
	)
	var diagnostics: Array[Dictionary] = ContentValidatorScript.validate(catalog)
	if not diagnostics.is_empty():
		_show_content_errors(diagnostics)
		return
	show_screen("title", {"catalog": catalog, "deck_id": selected_deck_id, "difficulty": difficulty})


func _show_content_errors(diagnostics: Array[Dictionary]) -> void:
	_clear_screen()
	current_screen = ContentErrorViewScene.instantiate()
	screen_host.add_child(current_screen)
	current_screen.initialize(diagnostics, _validate_and_start)


func _clear_screen() -> void:
	_match_generation += 1
	_match_submission_active = false
	if current_screen != null and is_instance_valid(current_screen):
		if current_screen.has_method("cancel_motion"):
			current_screen.cancel_motion()
		if current_screen.get_parent() == screen_host:
			screen_host.remove_child(current_screen)
		current_screen.queue_free()
	current_screen = null


func _pending_screen(screen_name: String) -> Control:
	var panel := CenterContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = screen_name.replace("_", " ").capitalize()
	label.add_theme_font_size_override("font_size", 24)
	panel.add_child(label)
	return panel
