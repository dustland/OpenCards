const Main = preload("res://scripts/main.gd")
const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const MainScene = preload("res://scenes/main.tscn")
const ContentErrorViewScene = preload("res://scenes/ui/content_error_view.tscn")
const ActionBuilder = preload("res://scripts/ui/action_builder.gd")
const CardViewScene = preload("res://scenes/ui/card_view.tscn")
const ContentCatalog = preload("res://scripts/content/content_catalog.gd")
const DeckBuilderViewModel = preload("res://scripts/ui/deck_builder_view.gd")
const DeckBuilderScene = preload("res://scenes/ui/deck_builder_view.tscn")
const DeckStore = preload("res://scripts/ui/deck_store.gd")
const MulliganViewModel = preload("res://scripts/ui/mulligan_view.gd")
const MulliganScene = preload("res://scenes/ui/mulligan_view.tscn")
const ActionResult = preload("res://scripts/core/action_result.gd")
const MatchViewScript = preload("res://scripts/ui/match_view.gd")
const MatchViewScene = preload("res://scenes/ui/match_view.tscn")
const ResultViewScene = preload("res://scenes/ui/result_view.tscn")
const CardInstanceScript = preload("res://scripts/core/card_instance.gd")
const CoreCards = preload("res://tests/fixtures/core_cards.gd")
const AIPlayerScript = preload("res://scripts/ai/ai_player.gd")
const LocaleScript = preload("res://scripts/ui/locale.gd")
const HowToPlayScene = preload("res://scenes/ui/how_to_play_view.tscn")
const OnboardingStore = preload("res://scripts/ui/onboarding_store.gd")


class TestScreen:
	extends Control
	signal play_requested(deck_id: String, difficulty: String)

	var router: Main
	var payload: Dictionary
	var selected_definition: Dictionary = {}

	func initialize(main: Main, data: Dictionary) -> void:
		router = main
		payload = data.duplicate(true)

	func selected_deck() -> Dictionary:
		return selected_definition.duplicate(true)


static func run(t) -> void:
	_test_theme_and_screen_contract(t)
	_test_sfx_maps_match_events(t)
	await _test_how_to_play_covers_complete_rules(t)
	await _test_first_match_opens_how_to(t)
	_test_router_replaces_screen_and_initializes_payload(t)
	_test_main_routes_play_to_mulligan_fallback(t)
	_test_main_passes_selected_deck_to_mulligan(t)
	_test_missing_scene_uses_fallback(t)
	_test_content_errors_are_sorted_and_retryable(t)
	await _test_main_scene_exposes_screen_host(t)
	_test_action_builders(t)
	_test_card_view_modes_and_geometry(t)
	_test_card_inspect_lists_combat_and_ability(t)
	_test_card_tooltip_is_a_dossier(t)
	_test_card_roles_use_distinct_colors(t)
	_test_card_view_hidden_mode_redacts_data(t)
	_test_card_view_press_and_drag_share_instance_id(t)
	await _test_card_view_container_layout(t)
	_test_deck_builder_model(t)
	_test_deck_builder_reuses_existing_user_copy(t)
	_test_deck_builder_filters(t)
	_test_deck_store_round_trip_and_shipped_immutability(t)
	_test_deck_store_surfaces_corrupt_load(t)
	await _test_deck_builder_scene_contract(t)
	await _test_deck_builder_copy_selection_and_save_failure(t)
	_test_deck_builder_displays_corrupt_load_status(t)
	_test_mulligan_model_selection_and_lock(t)
	await _test_mulligan_scene_renders_and_confirms(t)
	await _test_mulligan_layout_is_responsive(t)
	await _test_main_completes_both_mulligans_and_routes(t)
	await run_task5(t)


static func run_task5(t) -> void:
	_test_match_selection_builds_only_legal_actions(t)
	_test_match_selection_filters_compound_candidates(t)
	_test_match_selection_cancels_and_reports_rejection(t)
	_test_public_cards_expose_only_safe_ownership(t)
	await _test_match_scene_contract_and_responsive_layout(t)
	await _test_match_hq_signals_lock_and_drop_parity(t)
	await _test_match_compound_signals_require_confirmation(t)
	await _test_main_rejection_recovers_fresh_actions(t)
	await _test_main_drives_opponent_first_without_reentrancy(t)
	_test_main_routes_terminal_payload(t)
	_test_match_label_reports_active_player_and_player_zones(t)
	await _test_match_concede_button_routes_concede_action(t)
	_test_deck_builder_falls_back_when_selected_deck_invalid(t)
	await _test_card_visual_badges_fan_hover_and_ghost(t)


static func run_task6(t) -> void:
	_test_public_card_art_is_safe(t)
	await _test_runtime_views_load_public_card_art(t)
	_test_terminal_reason_uses_authoritative_events(t)
	await _test_result_view_outcomes_and_layout(t)
	await _test_result_view_signals(t)
	await _test_main_rematch_preserves_complete_selection(t)
	_test_main_result_returns_to_builder_with_preferences(t)
	await _test_builder_merges_returned_session_deck(t)
	await _test_rendered_opponent_hand_is_private(t)
	await _test_keyboard_actions(t)
	_test_main_routes_complete_terminal_payload(t)


static func _test_public_card_art_is_safe(t) -> void:
	var definition := _ui_card("definition", "", "Unit")
	definition["id"] = "art-unit"
	definition["image_path"] = "res://game_assets/generated_cards/us-infantry.png"
	var card = CardInstanceScript.from_definition(definition, "player", "p-art")
	t.assert_eq(card.to_public_dict(true).get("image_path"), definition.image_path, "revealed public card exposes generated art path")
	t.assert_eq(card.to_public_dict(true).get("description"), str(definition.get("description", "")), "revealed public card exposes description")
	t.assert_true(not card.to_public_dict(false).has("image_path"), "hidden card exposes no art path")
	t.assert_true(not card.to_public_dict(false).has("description"), "hidden card exposes no description")


static func _test_runtime_views_load_public_card_art(t) -> void:
	var image_path := "res://game_assets/generated_cards/us-infantry.png"
	var card := _ui_card("p-art", "player", "Unit")
	card["title"] = "Rifle Platoon"
	card["image_path"] = image_path
	var snapshot := _match_snapshot()
	snapshot.players.player.hand = [card]
	snapshot.players.player.headquarters = card.merged({"instance_id": "p-hq-art", "category": "Headquarters"}, true)
	snapshot.players.opponent.headquarters = card.merged({"instance_id": "o-hq-art", "owner_id": "opponent", "category": "Headquarters"}, true)

	var mulligan = MulliganScene.instantiate()
	Engine.get_main_loop().root.add_child(mulligan)
	mulligan.initialize(null, {"snapshot": snapshot, "difficulty": "standard"})
	await Engine.get_main_loop().process_frame
	var mulligan_art = mulligan.get_node("%HandRow").get_child(0).get_node("Frame/Artwork")
	t.assert_eq(mulligan_art.texture.resource_path, image_path, "mulligan hand loads generated texture")
	mulligan.queue_free()
	await Engine.get_main_loop().process_frame

	var match_view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(match_view)
	match_view.render_snapshot(snapshot)
	await Engine.get_main_loop().process_frame
	var hand_art = match_view.get_node("%PlayerHand").get_child(0).get_node("Frame/Artwork")
	t.assert_eq(hand_art.texture.resource_path, image_path, "match player hand loads generated texture")
	t.assert_eq(match_view.get_node("%PlayerHQ/Emblem").texture.resource_path, "res://game_assets/ui/hq_us.png", "match player HQ renders the US emblem")
	t.assert_eq(match_view.get_node("%OpponentHQ/Emblem").texture.resource_path, "res://game_assets/ui/hq_su.png", "match opponent HQ renders the Soviet emblem")
	match_view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_terminal_reason_uses_authoritative_events(t) -> void:
	var ended := {"type": "match_ended", "winner_id": "player", "loser_id": "opponent"}
	t.assert_eq(Main.terminal_reason("complete", "player", [{"type": "fatigue_damage", "player_id": "opponent"}, ended], {}), "fatigue", "fatal draw is reported as fatigue")
	t.assert_eq(Main.terminal_reason("complete", "player", [{"type": "damage_dealt"}, ended], {}), "headquarters_destroyed", "combat lethal is reported as Headquarters destruction")
	t.assert_eq(Main.terminal_reason("complete", "", [{"type": "match_ended"}], {}), "draw", "winnerless completion is a draw")
	t.assert_eq(Main.terminal_reason("invalid", "", [], {"diagnostic": {"code": "ai_deadlock"}}), "ai_deadlock", "invalid terminal exposes authoritative diagnostic")
	t.assert_eq(Main.terminal_reason("complete", "player", [], {}), "match_complete", "unknown completed cause is not mislabeled")


static func _test_result_view_outcomes_and_layout(t) -> void:
	var cases := [
		["player", LocaleScript.ui("result.victory")],
		["opponent", LocaleScript.ui("result.defeat")],
		["", LocaleScript.ui("result.draw")],
	]
	for viewport_size in [Vector2(1280, 720), Vector2(1024, 720)]:
		for outcome in cases:
			var host := Control.new()
			host.size = viewport_size
			Engine.get_main_loop().root.add_child(host)
			var view = ResultViewScene.instantiate()
			host.add_child(view)
			view.initialize(null, {
				"winner_id": outcome[0], "reason": "headquarters_destroyed",
				"turns": 12, "seed": 77, "replay_log": {"actions": [1, 2]},
			})
			await Engine.get_main_loop().process_frame
			t.assert_eq(view.get_node("%OutcomeLabel").text, outcome[1], "result labels %s outcome" % outcome[1])
			t.assert_eq(view.get_node("%ReasonLabel").text, LocaleScript.ui("reason.headquarters_destroyed"), "result renders exact terminal reason")
			t.assert_eq(view.get_node("%TurnsLabel").text, LocaleScript.ui("result.turns") % 12, "result renders turn statistics")
			t.assert_eq(view.size, viewport_size, "result root fits viewport")
			var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
			for path in ["%OutcomeLabel", "%WinnerLabel", "%ReasonLabel", "%TurnsLabel", "%RematchButton", "%DeckBuilderButton"]:
				var control: Control = view.get_node(path)
				t.assert_true(viewport_rect.encloses(control.get_global_rect()), "%s stays inside %s" % [path, viewport_size])
			t.assert_true(not view.get_node("%RematchButton").get_global_rect().intersects(view.get_node("%DeckBuilderButton").get_global_rect()), "result commands do not overlap")
			host.queue_free()
			await Engine.get_main_loop().process_frame


static func _test_result_view_signals(t) -> void:
	var view = ResultViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	await Engine.get_main_loop().process_frame
	var events: Array[String] = []
	view.rematch_requested.connect(func() -> void: events.append("rematch"))
	view.deck_builder_requested.connect(func() -> void: events.append("builder"))
	view.get_node("%RematchButton").pressed.emit()
	view.get_node("%DeckBuilderButton").pressed.emit()
	t.assert_eq(events, ["rematch", "builder"], "result exposes both navigation commands")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_main_rematch_preserves_complete_selection(t) -> void:
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	Engine.get_main_loop().root.add_child(host)
	main.catalog = ContentCatalog.load_from_paths("res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json")
	main.screen_factory = func(path: String) -> Control: return ResultViewScene.instantiate() if path.ends_with("result_view.tscn") else TestScreen.new()
	var deck: Dictionary = main.catalog.decks_by_id["us-starter"].duplicate(true)
	deck["id"] = "user-complete-deck"
	main.selected_deck_id = deck.id
	main.selected_player_deck = deck.duplicate(true)
	main.difficulty = "hard"
	main._match_rng.seed = 600
	main.show_screen("result", {"winner_id": "player", "reason": "fatigue", "turns": 8, "seed": 9, "replay_log": {}})
	main.current_screen.rematch_requested.emit()
	await Engine.get_main_loop().process_frame
	var payload: Dictionary = (main.current_screen as TestScreen).payload
	var rematch_seed := main.controller.state.seed
	t.assert_eq(payload.player_deck, deck, "rematch keeps the complete selected player deck")
	t.assert_eq(payload.difficulty, "hard", "rematch keeps difficulty")
	t.assert_true(rematch_seed != 9 and rematch_seed != 0, "rematch advances to a fresh deterministic app RNG seed")
	main.free()
	host.free()


static func _test_main_result_returns_to_builder_with_preferences(t) -> void:
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	main.screen_factory = func(path: String) -> Control: return ResultViewScene.instantiate() if path.ends_with("result_view.tscn") else TestScreen.new()
	main.selected_deck_id = "user-preferred"
	main.selected_player_deck = {"id": "user-preferred", "name": "Session Deck", "cards": ["one"]}
	main.difficulty = "hard"
	main.show_screen("result", {"winner_id": "opponent", "reason": "concede", "turns": 3, "seed": 4, "replay_log": {}})
	main.current_screen.deck_builder_requested.emit()
	var payload: Dictionary = (main.current_screen as TestScreen).payload
	t.assert_eq(payload, {"deck_id": "user-preferred", "difficulty": "hard"}, "home return preserves deck id and difficulty")
	main.free()
	host.free()


static func _test_builder_merges_returned_session_deck(t) -> void:
	var catalog = ContentCatalog.load_from_paths("res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json")
	var session_deck: Dictionary = catalog.decks_by_id["us-starter"].duplicate(true)
	session_deck.id = "user-unsaved-session"
	session_deck.name = "Unsaved Session"
	var view = DeckBuilderScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	view.initialize(null, {"catalog": catalog, "deck_id": session_deck.id, "difficulty": "hard", "player_deck": session_deck})
	await Engine.get_main_loop().process_frame
	t.assert_eq(view.selected_deck(), session_deck, "builder merges and selects returned unsaved session deck")
	t.assert_eq(view.difficulty, "hard", "builder restores returned difficulty")
	(session_deck.cards as Array).clear()
	t.assert_eq((view.selected_deck().cards as Array).size(), 40, "builder owns a deep copy of returned deck")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_rendered_opponent_hand_is_private(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	var snapshot := _match_snapshot()
	snapshot.players.opponent.hand = [
		{"instance_id": "private-o-1", "definition_id": "secret-card", "title": "Secret Tank", "description": "Private plan", "hidden": true},
		{"instance_id": "private-o-2", "hidden": true},
	]
	view.render_snapshot(snapshot)
	await Engine.get_main_loop().process_frame
	t.assert_true("%s 2" % LocaleScript.ui("status.hand") in view.get_node("%OpponentLabel").text, "rendered opponent hand count matches snapshot")
	t.assert_true(view.has_node("%OpponentHand"), "opponent hand fan exists")
	t.assert_eq(view.get_node("%OpponentHand").get_child_count(), 2, "opponent hand fan shows one back per hidden card")
	for card in view.get_node("%OpponentHand").get_children():
		t.assert_eq(card.mode, "hidden", "opponent hand cards stay face-down")
		t.assert_true(card.get_node("CardBack").visible, "opponent hand shows card backs")
	for card in view.snapshot.players.opponent.hand:
		t.assert_eq(card, {"hidden": true}, "rendered hidden card retains no private identifier")
	var rendered_text := _visible_text(view)
	for private_value in ["private-o-1", "private-o-2", "secret-card", "Secret Tank", "Private plan"]:
		t.assert_true(private_value not in rendered_text, "rendered match omits private value %s" % private_value)
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _visible_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += str(node.text) + "\n"
	if node is LineEdit:
		result += str(node.text) + "\n"
	for child in node.get_children():
		result += _visible_text(child)
	return result


static func _test_keyboard_actions(t) -> void:
	for action_name in ["ui_accept", "ui_cancel", "end_turn"]:
		t.assert_true(InputMap.has_action(action_name), "%s is registered in InputMap" % action_name)
	var match_view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(match_view)
	match_view.render_snapshot(_match_snapshot())
	var end_turn = GameAction.create("end_turn", "player", "", [], {}, 5)
	match_view.set_legal_actions([end_turn])
	var submitted: Array = []
	match_view.action_requested.connect(func(action) -> void: submitted.append(action))
	match_view._unhandled_input(_action_event("end_turn"))
	t.assert_eq(submitted, [end_turn], "end_turn keyboard action submits legal command")
	match_view.model.select_source("p-front")
	match_view._unhandled_input(_action_event("ui_cancel"))
	t.assert_eq(match_view.model.selected_source_id, "", "ui_cancel clears match selection")
	match_view._unhandled_input(_action_event("ui_cancel"))
	t.assert_true(match_view.get_node("SettingsDialog").visible, "ui_cancel opens settings when nothing is selected")
	match_view._unhandled_input(_action_event("ui_cancel"))
	t.assert_true(not match_view.get_node("SettingsDialog").visible, "ui_cancel closes the settings overlay")
	match_view.queue_free()
	await Engine.get_main_loop().process_frame

	var result_view = ResultViewScene.instantiate()
	Engine.get_main_loop().root.add_child(result_view)
	await Engine.get_main_loop().process_frame
	var rematches := [0]
	result_view.rematch_requested.connect(func() -> void: rematches[0] += 1)
	result_view._unhandled_input(_action_event("ui_accept"))
	t.assert_eq(rematches[0], 1, "ui_accept activates Result primary action")
	result_view.queue_free()
	await Engine.get_main_loop().process_frame


static func _action_event(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


static func _test_main_routes_complete_terminal_payload(t) -> void:
	var controller = _started_controller_with_active("player")
	controller.state.phase = "complete"
	controller.state.winner_id = ""
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	main.controller = controller
	main.screen_factory = func(_path: String) -> Control: return TestScreen.new()
	t.assert_true(main._route_match_result_if_complete(), "draw terminal state routes")
	var payload: Dictionary = (main.current_screen as TestScreen).payload
	for field in ["winner_id", "reason", "turns", "seed", "replay_log"]:
		t.assert_true(payload.has(field), "terminal payload includes %s" % field)
	t.assert_eq(payload.reason, "draw", "winnerless completion has exact draw reason")
	main.free()
	host.free()


static func _test_match_selection_builds_only_legal_actions(t) -> void:
	var model := MatchViewScript.MatchInteractionModel.new()
	var attack = ActionBuilder.attack("p-unit", "o-unit", "player", 15)
	var hq_attack = GameAction.create("attack_hq", "player", "p-unit", ["o-hq"], {"target_player_id": "opponent"}, 15)
	model.set_legal_actions([attack, hq_attack])
	model.select_source("p-unit")
	t.assert_eq(model.highlighted_targets(), ["o-hq", "o-unit"], "legal targets exposed in stable order")
	t.assert_eq(model.choose_target("o-unit").type, "attack_unit", "selection resolves exact legal action")
	model.select_source("p-unit")
	t.assert_eq(model.choose_target("o-hq").type, "attack_hq", "HQ attack preserves controller action type")


static func _test_match_selection_filters_compound_candidates(t) -> void:
	var model := MatchViewScript.MatchInteractionModel.new()
	var order_ab = GameAction.create("play_order", "player", "p-order", ["a", "b"], {}, 20)
	var order_ba = GameAction.create("play_order", "player", "p-order", ["b", "a"], {}, 20)
	model.set_legal_actions([order_ab, order_ba])
	model.select_source("p-order")
	t.assert_eq(model.choose_target("b"), null, "first target never chooses an unspecified candidate")
	t.assert_eq(model.highlighted_targets(), ["a"], "next target follows selected target order")
	t.assert_eq(model.choose_target("a"), order_ba, "completed ordered action auto-submits")

	var deploy_plain = ActionBuilder.deploy("p-unit", 2, "player", 21)
	var deploy_targeted = GameAction.create("deploy_unit", "player", "p-unit", ["ally"], {"support_slot": 2}, 21)
	model.set_legal_actions([deploy_plain, deploy_targeted])
	model.select_source("p-unit")
	t.assert_eq(model.choose_slot("support", 2), null, "compound deploy does not choose an unspecified target variant")
	t.assert_eq(model.highlighted_targets(), ["ally"], "remaining deploy target is explicit")
	t.assert_eq(model.choose_target("ally"), deploy_targeted, "targeted deploy auto-submits after last target")
	var deploy_slot_one = ActionBuilder.deploy("p-unit", 1, "player", 22)
	var deploy_slot_three = ActionBuilder.deploy("p-unit", 3, "player", 22)
	model.set_legal_actions([deploy_slot_one, deploy_slot_three])
	model.select_source("p-unit")
	t.assert_eq(model.choose_slot("support", 3), deploy_slot_three, "complete slot auto-submits the chosen action")


static func _test_match_selection_cancels_and_reports_rejection(t) -> void:
	var model := MatchViewScript.MatchInteractionModel.new()
	model.set_legal_actions([ActionBuilder.deploy("p-card", 2, "player", 9)])
	model.select_source("p-card")
	t.assert_eq(model.highlighted_slots("support"), [2], "deploy slots exposed")
	model.cancel()
	t.assert_eq(model.selected_source_id, "", "cancel clears source")
	t.assert_eq(model.selected_targets, [], "cancel clears progressive targets")
	model.apply_rejection("insufficient_credit", "Not enough Credit")
	t.assert_eq(model.status_message, "Not enough Credit", "rejection visible")


static func _test_match_scene_contract_and_responsive_layout(t) -> void:
	for viewport_size in [Vector2(1280, 720), Vector2(1024, 720)]:
		var root_control := Control.new()
		root_control.size = viewport_size
		Engine.get_main_loop().root.add_child(root_control)
		var view = MatchViewScene.instantiate()
		root_control.add_child(view)
		view.render_snapshot(_match_snapshot(8))
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().process_frame
		t.assert_true(view.has_node("%OpponentSupport"), "opponent support exists")
		t.assert_true(view.has_node("%Frontline"), "shared frontline exists")
		t.assert_true(view.has_node("%PlayerSupport"), "player support exists")
		t.assert_true(view.has_node("%PlayerHand"), "player hand exists")
		t.assert_true(view.has_node("%Timeline"), "timeline exists")
		t.assert_true(view.has_node("%OpponentHQ"), "opponent HQ target exists")
		t.assert_true(view.has_node("%PlayerHQ"), "player HQ target exists")
		t.assert_true(view.has_node("%HandScroll"), "populated hand is scroll bounded")
		t.assert_eq(view.get_node("%Frontline").get_child_count(), 5, "frontline reserves five slots")
		t.assert_eq(view.get_node("%OpponentSupport").get_child_count(), 4, "opponent reserves four slots")
		t.assert_eq(view.get_node("%PlayerSupport").get_child_count(), 4, "player reserves four slots")
		var player_front = view.get_node("%Frontline").get_child(0).get_child(0)
		var opponent_front = view.get_node("%Frontline").get_child(1).get_child(0)
		t.assert_true(player_front.modulate != opponent_front.modulate, "frontline ownership has clear opposing styles")
		t.assert_eq(view.size, viewport_size, "match root exactly fits viewport")
		var board_rect: Rect2 = view.get_node("%Board").get_global_rect()
		t.assert_true(board_rect.size.x > viewport_size.x * 0.82, "board uses the full table without a log column")
		t.assert_true(view.get_node("%TimelinePanel").get_parent().name == "LogOverlay", "log is an overlay, not a sidebar")
		t.assert_eq(view.get_node("%TimelinePanel").visible, false, "empty log stays out of the table")
		view.render_events([{"type": "turn_started", "player_id": "player"}])
		await Engine.get_main_loop().process_frame
		var timeline_rect: Rect2 = view.get_node("%TimelinePanel").get_global_rect()
		t.assert_eq(view.get_node("%TimelinePanel").visible, true, "log appears after the first report")
		t.assert_true(timeline_rect.size.x <= 280.0 and timeline_rect.size.y <= 220.0, "log stays a corner chip")
		t.assert_true(timeline_rect.position.x > board_rect.position.x + board_rect.size.x * 0.55, "log floats on the right")
		var hand_width: float = view.get_node("%PlayerHand").get_combined_minimum_size().x
		var hand_viewport_width: float = view.get_node("%HandScroll").size.x
		if viewport_size.x == 1024.0:
			t.assert_true(view._hand_layout_width(8) <= hand_viewport_width + 8.0, "eight cards fit the full-width table at 1024")
			view.render_snapshot(_match_snapshot(10))
			await Engine.get_main_loop().process_frame
			await Engine.get_main_loop().process_frame
			hand_width = view.get_node("%PlayerHand").get_combined_minimum_size().x
			hand_viewport_width = view.get_node("%HandScroll").size.x
			t.assert_true(hand_width > hand_viewport_width, "a ten-card hand still scrolls at 1024")
		root_control.free()


static func _test_match_label_reports_active_player_and_player_zones(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	var snapshot := _match_snapshot(2)
	snapshot.players.player.discard = [{"instance_id": "p-discard-1", "title": "Discarded", "category": "Unit", "owner_id": "player"}]
	view.render_snapshot(snapshot)
	t.assert_true(LocaleScript.ui("turn.yours") in view.get_node("%TurnLabel").text, "turn label advertises the active player's turn")
	t.assert_true("%s 1" % LocaleScript.ui("status.discard") in view.get_node("%PlayerLabel").text, "player label reports the discard pile size")
	t.assert_true("%s 34" % LocaleScript.ui("status.deck") in view.get_node("%PlayerLabel").text, "player label reports the deck count for fatigue awareness")

	snapshot.active_player_id = "opponent"
	view.render_snapshot(snapshot)
	t.assert_true(LocaleScript.ui("turn.opponent") in view.get_node("%TurnLabel").text, "turn label advertises the opponent's turn")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_match_concede_button_routes_concede_action(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	view.render_snapshot(_match_snapshot())
	var submitted: Array = []
	view.action_requested.connect(func(action) -> void: submitted.append(action))
	# Player turn, action phase: Concede lives in settings, not on the battlefield.
	view._open_settings()
	var settings = view.get_node("SettingsDialog")
	t.assert_true(settings.get_node("%ConcedeButton").visible, "settings offers concede on the player's action turn")
	settings.close()
	view._on_concede_confirmed()
	t.assert_eq(submitted.size(), 1, "confirming concede emits exactly one action")
	t.assert_eq(submitted[0].type, "concede", "concede confirmation emits a concede action")
	t.assert_eq(submitted[0].actor_id, "player", "concede action belongs to the player")

	# Opponent turn: confirming is a no-op (the dialog is guarded by active player).
	submitted.clear()
	var opponent_turn := _match_snapshot()
	opponent_turn.active_player_id = "opponent"
	view.render_snapshot(opponent_turn)
	view._open_settings()
	t.assert_true(not settings.get_node("%ConcedeButton").visible, "settings hides concede outside the player's turn")
	settings.close()
	view._on_concede_confirmed()
	t.assert_eq(submitted.size(), 0, "concede confirmation is ignored outside the player's turn")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_card_visual_badges_fan_hover_and_ghost(t) -> void:
	# Card face badges render behind the numeric labels.
	var card = CardViewScene.instantiate()
	Engine.get_main_loop().root.add_child(card)
	card.bind(_card_data(), "hand")
	t.assert_true(card.get_node("Frame/Costs/Deployment/BadgeCost").texture != null, "deployment badge art present")
	t.assert_true(card.get_node("Frame/Costs/Operation/BadgeOp").texture != null, "operate badge art present")
	t.assert_true(card.get_node("Frame/Stats/Attack/BadgeAttack").texture != null, "attack badge art present")
	t.assert_true(card.get_node("Frame/Stats/Defense/BadgeDefense").texture != null, "defense badge art present")
	t.assert_true(card.get_node("CardBack/BackTexture").texture != null, "card back uses generated texture")
	# Hand hover lifts and restores.
	var base_y: float = card.position.y
	card._set_hover_lift(true)
	if card._hover_tween != null and card._hover_tween.is_valid():
		await card._hover_tween.finished
	t.assert_true(card.position.y < base_y, "hover lifts hand cards")
	t.assert_eq(card.z_index > 0, true, "hover raises hand card z order")
	card._set_hover_lift(false)
	if card._hover_tween != null and card._hover_tween.is_valid():
		await card._hover_tween.finished
	t.assert_eq(card.position.y, base_y, "hover exit restores hand card position")
	t.assert_eq(card.scale, Vector2.ONE, "hover exit restores hand card scale")
	card.free()

	# Hand fan: edge cards tilt out and the center sits higher, like a held hand.
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	view.render_snapshot(_match_snapshot(3))
	await Engine.get_main_loop().process_frame
	var hand: Control = view.get_node("%PlayerHand")
	var first: Control = hand.get_child(0)
	var middle: Control = hand.get_child(1)
	var last: Control = hand.get_child(2)
	t.assert_true(first.rotation_degrees < -0.5, "fan left edge rotates counterclockwise")
	t.assert_true(last.rotation_degrees > 0.5, "fan right edge rotates clockwise")
	t.assert_eq(middle.rotation_degrees, 0.0, "fan center stays level")
	t.assert_true(absf(first.rotation_degrees) - absf(middle.rotation_degrees) > 0.5, "fan rotation spreads across the hand")
	t.assert_true(first.position.x < middle.position.x and middle.position.x < last.position.x, "fan cards advance left to right")
	t.assert_true(middle.position.y < first.position.y and middle.position.y < last.position.y, "fan center sits higher than the edges")
	t.assert_true(hand.custom_minimum_size.x > 300.0, "fan reserves horizontal scroll width")

	# HQ view keeps the interaction surface of a card slot.
	t.assert_true(view.get_node("%PlayerHQ").has_signal("card_pressed"), "HQ view exposes card_pressed")
	t.assert_true(view.get_node("%OpponentHQ").has_signal("card_dropped"), "HQ view exposes card_dropped")
	t.assert_eq(view.get_node("%PlayerHQ/HpBadge/HpLabel").text, "20", "HQ view renders headquarters defense")
	view.free()

	# The motion proxy renders as a real card face.
	var director = load("res://scripts/ui/card_motion_director.gd").new()
	var motion_view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(motion_view)
	var ghost = director._ghost_card(motion_view, Rect2(10, 10, 116, 162), _card_data())
	t.assert_true(ghost.is_in_group("card_motion_proxy"), "motion ghost keeps the proxy group")
	t.assert_eq(ghost.get_node("Frame/Title").text, "RIFLE PLATOON", "motion ghost renders the card title")
	t.assert_eq(ghost.mode, "hand", "motion ghost matches hand geometry")
	director.cancel()
	motion_view.free()


static func _match_snapshot(hand_count := 0) -> Dictionary:
	var hq := _ui_card("p-hq", "player", "Headquarters")
	var hand: Array = []
	for index in range(hand_count): hand.append(_ui_card("p-hand-%d" % index, "player", "Unit"))
	var player_front := _ui_card("p-front", "player", "Unit")
	var opponent_front := _ui_card("o-front", "opponent", "Unit")
	return {"players": {"player": {"id": "player", "nation": "US", "headquarters": hq, "hq_defense": 20, "deck_count": 34, "hand": hand, "support_line": [null, null, null, null], "credit": 3, "credit_slots": 3}, "opponent": {"id": "opponent", "nation": "SU", "headquarters": hq.merged({"instance_id": "o-hq", "owner_id": "opponent"}, true), "hq_defense": 20, "deck_count": 34, "hand": [{"instance_id": "o-hidden", "hidden": true}], "support_line": [null, null, null, null], "credit": 3, "credit_slots": 3}}, "frontline": [player_front, opponent_front, null, null, null], "active_player_id": "player", "turn": 1, "phase": "action", "sequence": 5, "winner_id": ""}


static func _ui_card(instance_id: String, owner_id: String, category: String) -> Dictionary:
	return {"instance_id": instance_id, "owner_id": owner_id, "title": category, "category": category, "unit_type": "Infantry", "attack": 1, "defense": 20 if category == "Headquarters" else 2, "deployment_cost": 1, "operation_cost": 1, "keywords": []}


static func _test_public_cards_expose_only_safe_ownership(t) -> void:
	var definition := _ui_card("definition", "", "Unit")
	definition["id"] = "unit"
	var card = CardInstanceScript.from_definition(definition, "player", "p-unit")
	t.assert_eq(card.to_public_dict(true).get("owner_id"), "player", "revealed public battlefield card exposes owner")
	t.assert_true(not card.to_public_dict(false).has("owner_id"), "hidden card does not expose owner")


static func _test_match_hq_signals_lock_and_drop_parity(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	view.render_snapshot(_match_snapshot())
	var attack = GameAction.create("attack_hq", "player", "p-front", ["o-hq"], {"target_player_id": "opponent"}, 5)
	view.set_legal_actions([attack])
	var emitted: Array = []
	view.action_requested.connect(func(action) -> void: emitted.append(action))
	view.get_node("%Frontline").get_child(0).get_child(0).card_pressed.emit("p-front")
	view.get_node("%OpponentHQ").card_pressed.emit("o-hq")
	t.assert_eq(emitted, [attack], "HQ click submits exact legal attack")
	view.set_legal_actions([attack])
	view.get_node("%OpponentHQ").card_dropped.emit("p-front", "o-hq")
	t.assert_eq(emitted, [attack, attack], "HQ drop has click parity")
	view.set_input_locked(true)
	view._on_target_dropped("p-front", "o-hq")
	view._on_slot_pressed("frontline", 0)
	view._on_end_turn_pressed()
	t.assert_eq(emitted.size(), 2, "all target slot and command handlers honor lock")
	t.assert_eq(view.get_node("%StatusLabel").text, LocaleScript.ui("reason.locked"), "locked handler explains rejection")
	t.assert_true(view.get_node("%OpponentHQ").disabled, "locked HQ rejects click and drop")
	t.assert_true(view.get_node("%Frontline").get_child(0).disabled, "locked slot rejects drops")
	view.free()


static func _test_match_compound_signals_require_confirmation(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	view.render_snapshot(_match_snapshot(1))
	var deploy = GameAction.create("deploy_unit", "player", "p-hand-0", ["p-front"], {"support_slot": 0}, 5)
	view.set_legal_actions([deploy])
	var emitted: Array = []
	view.action_requested.connect(func(action) -> void: emitted.append(action))
	view.get_node("%PlayerSupport").card_dropped.emit("p-hand-0", "support", 0)
	t.assert_eq(emitted, [], "compound drop waits until the last target is chosen")
	view.get_node("%Frontline").get_child(0).get_child(0).card_pressed.emit("p-front")
	t.assert_eq(emitted, [deploy], "compound drop path auto-submits after last target")
	view.set_legal_actions([deploy])
	view.get_node("%PlayerHand").get_child(0).card_pressed.emit("p-hand-0")
	view.get_node("%PlayerSupport").slot_pressed.emit("support", 0)
	t.assert_eq(emitted, [deploy], "click path still waits for remaining target")
	view.get_node("%Frontline").get_child(0).get_child(0).card_pressed.emit("p-front")
	t.assert_eq(emitted, [deploy, deploy], "compound click and drop paths have parity")
	view.free()


static func _test_main_rejection_recovers_fresh_actions(t) -> void:
	var controller = _started_controller_with_active("player")
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	Engine.get_main_loop().root.add_child(host)
	main.controller = controller
	main.ai = AIPlayerScript.create("easy", 901)
	main.screen_factory = func(path: String) -> Control: return MatchViewScene.instantiate() if path.ends_with("match_view.tscn") else TestScreen.new()
	main.show_screen("match", {"snapshot": controller.state.snapshot_for("player")})
	var stale = controller.legal_actions("player")[0]
	stale.expected_sequence = controller.state.sequence + 99
	main.submit_player_action(stale)
	for frame in range(3): await Engine.get_main_loop().process_frame
	var view = main.current_screen
	t.assert_eq(view.get_node("%StatusLabel").text, "State changed", "rejection is visible through real orchestration")
	for action in view.model._legal_actions:
		t.assert_eq(action.expected_sequence, controller.state.sequence, "rejection refreshes legal actions to current sequence")
	main.free()
	host.free()


static func _test_main_drives_opponent_first_without_reentrancy(t) -> void:
	var controller = _started_controller_with_active("opponent")
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	Engine.get_main_loop().root.add_child(host)
	main.controller = controller
	main.ai = AIPlayerScript.create("easy", 901)
	main.screen_factory = func(path: String) -> Control: return MatchViewScene.instantiate() if path.ends_with("match_view.tscn") else TestScreen.new()
	main.show_screen("match", {"snapshot": controller.state.snapshot_for("player")})
	main.start_match_turn_flow()
	main.start_match_turn_flow()
	for frame in range(20): await Engine.get_main_loop().process_frame
	t.assert_eq(controller.state.active_player_id, "player", "opponent-first initialization drains AI turn")
	t.assert_true(not main._match_submission_active, "duplicate startup does not deadlock or retain guard")
	main.free()
	host.free()


static func _test_main_routes_terminal_payload(t) -> void:
	var controller = _started_controller_with_active("player")
	controller.state.phase = "complete"
	controller.state.winner_id = "player"
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	main.controller = controller
	main.screen_factory = func(_path: String) -> Control: return TestScreen.new()
	t.assert_true(main._route_match_result_if_complete(), "terminal state routes immediately")
	var payload: Dictionary = (main.current_screen as TestScreen).payload
	t.assert_eq(payload.winner_id, "player", "result payload preserves winner")
	t.assert_eq(payload.seed, controller.state.seed, "result payload preserves seed")
	main.free()
	host.free()


static func _started_controller_with_active(actor_id: String):
	var fixture := CoreCards.build_valid_fixture()
	var controller = MatchController.create(fixture.definitions, fixture.player_deck, fixture.enemy_deck, 901)
	for action in [GameAction.create("start_match", "system"), GameAction.create("mulligan", "player"), GameAction.create("mulligan", "opponent"), GameAction.create("confirm_mulligan", "player"), GameAction.create("confirm_mulligan", "opponent")]:
		action.expected_sequence = controller.state.sequence
		assert(controller.submit_action(action).accepted)
	if controller.state.active_player_id != actor_id:
		var end_turn = controller.legal_actions(controller.state.active_player_id).filter(func(candidate) -> bool: return candidate.type == "end_turn")[0]
		assert(controller.submit_action(end_turn).accepted)
	return controller


static func run_task4(t) -> void:
	_test_mulligan_model_selection_and_lock(t)
	_test_ai_mulligan_exact_fixture(t)
	await _test_mulligan_scene_renders_and_confirms(t)
	await _test_mulligan_layout_is_responsive(t)
	await _test_mulligan_prevalidates_selection(t)
	await _test_mulligan_rejections_are_transactional(t)
	await _test_mulligan_renders_before_route(t)


static func _test_theme_and_screen_contract(t) -> void:
	var theme := ThemeFactory.create()
	t.assert_true(theme.has_color("font_color", "Label"), "theme defines label color")
	t.assert_eq(theme.get_color("font_color", "Label"), Color("e8e1d2"), "approved warm text")
	t.assert_true(theme.has_stylebox("panel", "TooltipPanel"), "theme styles the engine tooltip plaque")
	var tip := theme.get_stylebox("panel", "TooltipPanel") as StyleBoxFlat
	t.assert_true(tip != null and tip.bg_color.a >= 0.94, "tooltip plaque is opaque paper, not a glass smear")
	t.assert_eq(theme.get_color("font_color", "TooltipLabel"), Color("e8e1d2"), "tooltip text uses the warm ivory")
	t.assert_true(theme.default_font != null, "theme ships a CJK-capable default font")
	t.assert_true(ResourceLoader.exists("res://game_assets/ui/fonts/oswald_semibold.ttf"), "display font is packaged")
	t.assert_true(ResourceLoader.exists("res://game_assets/ui/fonts/ui_cjk.ttf"), "CJK font is packaged")
	var stacked := theme.default_font as FontVariation
	t.assert_true(stacked != null, "theme stacks a display face, not the engine default")
	t.assert_eq(stacked.base_font, ThemeFactory.DISPLAY_FONT, "Latin and numerals use the plate-cut display face")
	t.assert_true(ResourceLoader.exists("res://game_assets/ui/title_cover.png"), "title cover is packaged")
	t.assert_true(not bool(ProjectSettings.get_setting("application/boot_splash/show_image")), "engine splash stays a flat color so the cover is not stretched into fullscreen")
	t.assert_true(theme.default_font.get_string_size("部署").x > 8, "Chinese UI text has a real advance")
	for key in LocaleScript.STRINGS.keys():
		var text := LocaleScript.ui(str(key))
		for index in text.length():
			var code := text.unicode_at(index)
			t.assert_true(ThemeFactory.UI_FONT.has_char(code) or theme.default_font.has_char(code), "font covers UI glyph in %s" % str(key))
	t.assert_eq(Main.VALID_SCREENS, ["title", "deck_builder", "mulligan", "match", "result"], "complete flow")


static func _test_sfx_maps_match_events(t) -> void:
	t.assert_eq(SfxPlayer.cue_for("card_deployed"), "deploy", "deploy has a card slap")
	t.assert_eq(SfxPlayer.cue_for("damage_dealt"), "damage", "hits share a damage cue")
	t.assert_eq(SfxPlayer.cue_for("turn_started"), "turn", "turns have a cue")
	t.assert_eq(SfxPlayer.cue_for("match_ended", {"winner_id": "player"}), "win", "player win has a cue")
	t.assert_eq(SfxPlayer.cue_for("match_ended", {"winner_id": "opponent"}), "lose", "defeat has a cue")
	t.assert_eq(SfxPlayer.cue_for("credit_refilled"), "", "credit refill stays silent")
	var sfx := SfxPlayer.new()
	Engine.get_main_loop().root.add_child(sfx)
	SfxPlayer.play_event("card_deployed")
	t.assert_true(sfx._streams.has("deploy"), "runtime builds the deploy stream")
	sfx.queue_free()


static func _test_how_to_play_covers_complete_rules(t) -> void:
	var view = HowToPlayScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	await Engine.get_main_loop().process_frame
	t.assert_eq(view.get_node("%Steps").get_child_count(), 6, "how-to teaches the full simple ruleset")
	var sheet := ""
	for index in range(6):
		var step: Node = view.get_node("%Steps").get_child(index)
		var heading := (step.get_node("Heading") as Label).text
		var body := (step.get_node("Body") as Label).text
		t.assert_eq(heading, LocaleScript.ui("how_to.%d.title" % (index + 1)), "how-to step %d heading" % (index + 1))
		t.assert_eq(body, LocaleScript.ui("how_to.%d.body" % (index + 1)), "how-to step %d body" % (index + 1))
		sheet += body
	t.assert_true("to win" in sheet and "loss" in sheet, "how-to names both win and loss")
	t.assert_true("Blitz" in sheet, "how-to names the Blitz exception")
	t.assert_true("in Support can only hit the Frontline" in sheet, "how-to teaches Support-line infantry range")
	t.assert_true("drawing 1" in sheet and "refilling Credit" in sheet, "how-to teaches the turn start")
	t.assert_true("spend Credit" in sheet, "how-to teaches operate cost")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_first_match_opens_how_to(t) -> void:
	var path := "user://test-howto-auto-open.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var main = MainScene.instantiate()
	main.onboarding_store = OnboardingStore.new(path)
	Engine.get_main_loop().root.add_child(main)
	await Engine.get_main_loop().process_frame
	main.show_screen("match", {"auto_how_to_play": true, "snapshot": _match_snapshot()})
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var overlay := main.get_node_or_null("HowToPlayView")
	t.assert_true(overlay != null, "first match opens the how-to sheet")
	if overlay != null:
		overlay._on_close()
	t.assert_true(bool(main.onboarding_store.load().get("how_to_play_seen", false)), "closing how-to marks the sheet seen")
	main.queue_free()
	await Engine.get_main_loop().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _test_router_replaces_screen_and_initializes_payload(t) -> void:
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	main.screen_factory = func(_path: String) -> Control: return TestScreen.new()
	main.show_screen("deck_builder", {"deck_id": "us-starter", "Credit": 3})
	var first_screen := main.current_screen as TestScreen
	t.assert_eq(first_screen.router, main, "screen receives router")
	t.assert_eq(first_screen.payload, {"deck_id": "us-starter", "Credit": 3}, "screen receives payload")
	main.show_screen("match", {"difficulty": "hard"})
	t.assert_true(first_screen.is_queued_for_deletion(), "replaced screen is freed")
	t.assert_eq(host.get_child_count(), 1, "screen host contains only active screen")
	var match_payload: Dictionary = (main.current_screen as TestScreen).payload
	t.assert_eq(match_payload.get("difficulty", ""), "hard", "replacement receives requested payload")
	t.assert_true(match_payload.get("onboarding", null) is Dictionary, "match replacement receives onboarding state")
	first_screen.free()
	main.free()


static func _test_missing_scene_uses_fallback(t) -> void:
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	main.screen_factory = func(_path: String) -> Control: return null
	main.show_screen("result", {})
	t.assert_true(main.current_screen is CenterContainer, "missing screen uses stable fallback")
	t.assert_eq((main.current_screen.get_child(0) as Label).text, "Result", "fallback names requested screen")
	main.free()


static func _test_main_routes_play_to_mulligan_fallback(t) -> void:
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	main.catalog = ContentCatalog.load_from_paths("res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json")
	main.screen_factory = func(path: String) -> Control:
		return TestScreen.new() if path.ends_with("deck_builder_view.tscn") else null
	main.show_screen("deck_builder", {})
	var deck: Dictionary = main.catalog.decks_by_id["us-starter"].duplicate(true)
	deck["id"] = "user-us-starter"
	deck["meta"] = {"unsaved": true}
	(main.current_screen as TestScreen).selected_definition = deck
	(main.current_screen as TestScreen).play_requested.emit("user-us-starter", "hard")
	t.assert_eq(main.selected_deck_id, "user-us-starter", "Play stores selected deck")
	t.assert_eq(main.difficulty, "hard", "Play stores difficulty")
	t.assert_eq(main.selected_player_deck, deck, "Play captures full unsaved deck before freeing builder")
	t.assert_true(main.current_screen is CenterContainer, "missing mulligan scene uses fallback")
	t.assert_eq((main.current_screen.get_child(0) as Label).text, "Mulligan", "Play visibly advances to mulligan fallback")
	main.free()


static func _test_main_passes_selected_deck_to_mulligan(t) -> void:
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	main.catalog = ContentCatalog.load_from_paths("res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json")
	main.screen_factory = func(_path: String) -> Control: return TestScreen.new()
	main.show_screen("deck_builder", {})
	var deck: Dictionary = main.catalog.decks_by_id["us-starter"].duplicate(true)
	deck["id"] = "user-us-starter"
	deck["meta"] = {"unsaved": true}
	(main.current_screen as TestScreen).selected_definition = deck
	(main.current_screen as TestScreen).play_requested.emit("user-us-starter", "standard")
	var payload: Dictionary = (main.current_screen as TestScreen).payload
	t.assert_eq(payload.get("player_deck"), deck, "mulligan payload receives complete selected deck")
	var expected_cards: Array = deck.cards.duplicate()
	deck.cards.clear()
	t.assert_eq((payload.player_deck as Dictionary).cards, expected_cards, "mulligan payload owns a deep copy")
	main.free()


static func _test_content_errors_are_sorted_and_retryable(t) -> void:
	var retried := [false]
	var view := ContentErrorViewScene.instantiate()
	var diagnostics: Array[Dictionary] = [
		{"code": "zeta", "path": "cards[2]", "message": "last"},
		{"code": "alpha", "path": "cards[1]", "message": "first"},
	]
	view.initialize(diagnostics, func() -> void: retried[0] = true)
	var formatted: String = view.get_node("Center/Panel/Margin/Content/Scroll/Diagnostics").text
	t.assert_true(formatted.find("[alpha]") < formatted.find("[zeta]"), "diagnostics render in sorted order")
	t.assert_true("cards[1]\nfirst" in formatted, "diagnostics include path and message")
	view._on_retry_pressed()
	t.assert_true(retried[0], "retry invokes validation callback")
	view.free()


static func _test_main_scene_exposes_screen_host(t) -> void:
	var main := MainScene.instantiate()
	t.assert_true(main.has_node("ScreenHost"), "main scene exposes ScreenHost path")
	t.assert_true(main.get_node("ScreenHost") is Control, "ScreenHost is a Control")
	t.assert_true(main.has_node("%BootLoad"), "main scene keeps a title-art loader until ready")
	Engine.get_main_loop().root.add_child(main)
	await Engine.get_main_loop().process_frame
	t.assert_true(not main.get_node("%BootLoad").visible, "loader hides once the title screen is up")
	t.assert_eq(main.current_screen.name, "TitleView", "boot lands on the title screen")
	t.assert_true(main.current_screen.get_node("%TitleLabel").visible, "title shows the game name")
	t.assert_eq(main.current_screen.get_node("%TitleLabel").text, "OpenCards", "title names the game")
	main.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_action_builders(t) -> void:
	var deploy := ActionBuilder.deploy("p-01", 2, "player", 9)
	t.assert_eq(deploy.type, "deploy_unit", "deploy action type")
	t.assert_eq(deploy.actor_id, "player", "deploy actor")
	t.assert_eq(deploy.source_id, "p-01", "deploy source")
	t.assert_eq(deploy.payload, {"support_slot": 2}, "deploy target")
	t.assert_eq(deploy.expected_sequence, 9, "deploy sequence")

	var move := ActionBuilder.move("p-02", 1, "player", 10)
	t.assert_eq(move.type, "move_unit", "move action type")
	t.assert_eq(move.payload, {"zone": "frontline", "slot": 1}, "move target")

	var attack := ActionBuilder.attack("p-02", "o-03", "player", 11)
	t.assert_eq(attack.type, "attack_unit", "attack action type")
	t.assert_eq(attack.target_ids, ["o-03"], "attack target")

	var order := ActionBuilder.play_order("p-04", ["o-01", "o-02"], "player", 12)
	t.assert_eq(order.type, "play_order", "order action type")
	t.assert_eq(order.target_ids, ["o-01", "o-02"], "order targets")

	var countermeasure := ActionBuilder.toggle_countermeasure("p-05", "player", 13)
	t.assert_eq(countermeasure.type, "toggle_countermeasure", "countermeasure action type")
	t.assert_eq(countermeasure.target_ids, [], "countermeasure has no targets")


static func _test_card_view_modes_and_geometry(t) -> void:
	var card := _card_data()
	var expected_sizes := {
		"catalog": Vector2(180, 252),
		"hand": Vector2(116, 162),
		"battlefield": Vector2(80, 112),
	}
	for mode in expected_sizes:
		var view = CardViewScene.instantiate()
		view.bind(card, mode)
		t.assert_eq(view.custom_minimum_size, expected_sizes[mode], "%s mode has stable geometry" % mode)
		t.assert_eq(view.get_node("Frame/Title").text, "RIFLE PLATOON", "%s mode renders title" % mode)
		t.assert_eq(view.get_node("Frame/Stats/Attack").text, "1", "%s mode renders attack" % mode)
		t.assert_eq(view.get_node("Frame/Stats/Defense").text, "2", "%s mode renders defense" % mode)
		t.assert_true(view.get_node("Frame/Artwork").texture != null, "%s mode has fallback artwork" % mode)
		if mode == "battlefield":
			var title := view.get_node("Frame/Title") as Label
			t.assert_true(title.get_theme_font_size("font_size") >= 10, "battlefield title is at least 10px")
		if mode in ["hand", "battlefield"]:
			var art := view.get_node("Frame/Artwork") as Control
			var stats := view.get_node("Frame/Stats") as Control
			t.assert_true(stats.position.y >= art.position.y + art.size.y - stats.size.y - 4.0, "%s combat numbers sit on the art foot" % mode)
		if mode == "hand":
			t.assert_true(view.get_node("Frame/Costs").position.y <= 8.0, "hand costs sit at the top")
		view.free()


static func _test_card_inspect_lists_combat_and_ability(t) -> void:
	var view := CardViewScene.instantiate() as CardView
	view.bind({
		"title": "Supply Column",
		"definition_id": "us-supply-column",
		"description": "Infantry. Deploy: gain 1 Credit.",
		"category": "Unit",
		"unit_type": "Infantry",
		"deployment_cost": 2,
		"operation_cost": 1,
		"attack": 1,
		"defense": 3,
		"keywords": [],
	}, "hand")
	var text := view.tooltip_text
	t.assert_true(text.contains("Supply Column"), "inspect keeps the card title")
	t.assert_true(text.contains(LocaleScript.ui("type.Infantry")), "inspect names the unit type")
	t.assert_true(text.contains("%s 2" % LocaleScript.ui("inspect.deploy")), "inspect lists deploy cost")
	t.assert_true(text.contains("%s 1" % LocaleScript.ui("inspect.operate")), "inspect lists operate cost")
	t.assert_true(text.contains("%s 1" % LocaleScript.ui("inspect.attack")), "inspect lists attack")
	t.assert_true(text.contains("%s 3" % LocaleScript.ui("inspect.defense")), "inspect lists defense")
	t.assert_true(text.contains(LocaleScript.ui("card.us-supply-column")), "inspect lists the card ability")
	t.assert_true(LocaleScript.ui("inspect.range.infantry") in text, "inspect teaches infantry range, which the card face does not")
	t.assert_true(LocaleScript.ui("role.hold") in CardView.inspect_identity_line(view.card_data), "inspect identity names the hold role")
	t.assert_true("Infantry" in CardView.inspect_identity_line(view.card_data), "inspect identity keeps the unit type")
	t.assert_true(LocaleScript.ui("role.hold") in CardView.inspect_meta_line(view.card_data), "inspect meta names the hold role")
	t.assert_true("Infantry" in CardView.inspect_meta_line(view.card_data), "inspect meta keeps the unit type")
	t.assert_true(LocaleScript.ui("card.us-supply-column") in CardView.inspect_body(view.card_data), "inspect body keeps the ability")
	view.free()


static func _test_card_tooltip_is_a_dossier(t) -> void:
	var view := CardViewScene.instantiate() as CardView
	view.bind(_card_data(), "catalog")
	var sheet = view._make_custom_tooltip(view.tooltip_text)
	t.assert_true(sheet is VBoxContainer, "card tooltip builds a paper sheet instead of the native smear")
	var texts: PackedStringArray = PackedStringArray()
	var art_nodes: Array = []
	_collect_tooltip_bits(sheet, texts, art_nodes)
	var joined := "\n".join(texts)
	t.assert_true(not art_nodes.is_empty() and (art_nodes[0] as TextureRect).texture != null, "tooltip sheet shows the card portrait")
	t.assert_true("Rifle Platoon" in joined, "tooltip sheet keeps the card title")
	t.assert_true(LocaleScript.ui("role.hold") in joined, "tooltip sheet names the role")
	t.assert_true(("%s 1" % LocaleScript.ui("inspect.attack")) in joined, "tooltip sheet lists attack")
	(sheet as Node).free()
	view.native_tooltip = false
	t.assert_eq(view._get_tooltip(Vector2.ZERO), "", "match cards do not advertise a floating tooltip")
	t.assert_true(view._make_custom_tooltip(view.tooltip_text) == null, "match cards do not spawn a blank tooltip plaque")
	view.free()


static func _collect_tooltip_bits(node: Node, texts: PackedStringArray, art_nodes: Array) -> void:
	if node is Label:
		texts.append((node as Label).text)
	if node is TextureRect and node.name == "InspectArt":
		art_nodes.append(node)
	for child in node.get_children():
		_collect_tooltip_bits(child, texts, art_nodes)


static func _test_card_roles_use_distinct_colors(t) -> void:
	var cases: Array = [
		[{"title": "Rifle", "category": "Unit", "unit_type": "Infantry", "attack": 1, "defense": 2, "keywords": ["Guard"]}, "hold"],
		[{"title": "Sherman", "category": "Unit", "unit_type": "Tank", "attack": 4, "defense": 5, "keywords": ["Fury"]}, "strike"],
		[{"title": "Resupply", "category": "Order", "unit_type": "", "attack": 0, "defense": 0, "keywords": []}, "effect"],
		[{"title": "Watch", "category": "Countermeasure", "unit_type": "", "attack": 0, "defense": 0, "keywords": []}, "effect"],
		[{"title": "HQ", "category": "Headquarters", "unit_type": "", "attack": 0, "defense": 20, "keywords": []}, "hold"],
		[{"title": "Rangers", "category": "Unit", "unit_type": "Infantry", "attack": 3, "defense": 3, "keywords": ["Blitz"]}, "strike"],
		[{"title": "Raiders", "category": "Unit", "unit_type": "Infantry", "attack": 3, "defense": 2, "keywords": []}, "strike"],
	]
	var seen_borders: Array[Color] = []
	for case in cases:
		var data: Dictionary = case[0]
		var role: String = case[1]
		t.assert_eq(CardView.card_role(data), role, "%s classifies as %s" % [data.get("title"), role])
		var palette: Dictionary = CardView.role_palette(data)
		var view = CardViewScene.instantiate()
		view.bind(data, "catalog")
		t.assert_eq(view.get_node("Frame/Type").text, LocaleScript.ui("role.%s" % role), "%s catalog names the role" % data.get("title"))
		t.assert_eq(view.get_node("Frame/RoleMark").texture, CardView.role_mark_texture(role), "%s catalog shows the role mark" % data.get("title"))
		t.assert_true(not view.get_node("Frame/CategoryStrip").visible, "%s does not draw a second role bar" % data.get("title"))
		var style := view.get_theme_stylebox("normal") as StyleBoxFlat
		t.assert_eq(style.border_color, palette["border"], "%s frame uses the role color" % data.get("title"))
		t.assert_true(LocaleScript.ui("role.%s" % role) in CardView.inspect_meta_line(data), "%s inspect names the role" % data.get("title"))
		view.free()
		var hand = CardViewScene.instantiate()
		hand.bind(data, "hand")
		t.assert_true(hand.get_node("Frame/RoleMark").visible, "%s hand shows the role mark" % data.get("title"))
		t.assert_eq(hand.get_node("Frame/RoleMark").texture, CardView.role_mark_texture(role), "%s hand uses the role mark" % data.get("title"))
		t.assert_true(not hand.get_node("Frame/Type").visible, "%s hand keeps the role as a mark" % data.get("title"))
		hand.free()
		var border: Color = palette["border"]
		if not border in seen_borders:
			seen_borders.append(border)
	t.assert_eq(seen_borders.size(), 3, "strike, hold, and effect use three different frame colors")


static func _test_card_view_hidden_mode_redacts_data(t) -> void:
	var view = CardViewScene.instantiate()
	view.bind(_card_data(), "hidden")
	t.assert_eq(view.custom_minimum_size, Vector2(116, 162), "hidden mode uses hand geometry")
	t.assert_eq(view.card_data, {"hidden": true}, "hidden mode retains no identity metadata")
	t.assert_eq(view.get_node("Frame/Title").text, "", "hidden mode redacts title")
	t.assert_eq(view.tooltip_text, "", "hidden mode redacts description")
	t.assert_true(view.get_node("CardBack").visible, "hidden mode shows card back")
	t.assert_true(not view.get_node("Frame").visible, "hidden mode hides face")
	view.free()


static func _test_card_view_press_and_drag_share_instance_id(t) -> void:
	var view = CardViewScene.instantiate()
	view.bind(_card_data(), "hand")
	var pressed_ids: Array[String] = []
	var dragged_ids: Array[String] = []
	view.card_pressed.connect(func(instance_id: String) -> void: pressed_ids.append(instance_id))
	view.card_drag_started.connect(func(instance_id: String) -> void: dragged_ids.append(instance_id))
	view._on_pressed()
	var drag_data: Dictionary = view._get_drag_data(Vector2.ZERO)
	t.assert_eq(pressed_ids, ["p-01"], "press emits bound instance ID")
	t.assert_eq(dragged_ids, ["p-01"], "drag emits bound instance ID")
	t.assert_eq(drag_data.get("instance_id"), "p-01", "drag data maps the same instance ID")
	view.free()


static func _test_card_view_container_layout(t) -> void:
	var expected_sizes := {
		"catalog": Vector2(180, 252),
		"hand": Vector2(116, 162),
		"battlefield": Vector2(80, 112),
		"hidden": Vector2(116, 162),
	}
	for mode in expected_sizes:
		var container := CenterContainer.new()
		container.size = Vector2(420, 360)
		Engine.get_main_loop().root.add_child(container)
		var view = CardViewScene.instantiate()
		container.add_child(view)
		view.bind(_card_data(), mode)
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().process_frame
		t.assert_eq(view.size, expected_sizes[mode], "%s stays exact inside a larger container" % mode)
		_assert_visible_layout(t, view, mode)
		container.free()


static func _assert_visible_layout(t, view: Control, mode: String) -> void:
	var paths := [
		"CardBack/Mark",
		"Frame/Artwork",
		"Frame/Title",
		"Frame/Type",
		"Frame/RoleMark",
		"Frame/Costs/Deployment",
		"Frame/Costs/Operation",
		"Frame/Description",
		"Frame/Keywords",
		"Frame/Stats/Attack",
		"Frame/Stats/Defense",
	]
	var visible_controls: Array[Control] = []
	var card_rect := view.get_global_rect()
	for path in paths:
		var control := view.get_node(path) as Control
		if not control.is_visible_in_tree():
			continue
		visible_controls.append(control)
		var rect := control.get_global_rect()
		t.assert_true(card_rect.encloses(rect), "%s %s stays within card bounds" % [mode, path])
	for index in range(visible_controls.size()):
		for other_index in range(index + 1, visible_controls.size()):
			var first := visible_controls[index]
			var second := visible_controls[other_index]
			if _is_art_under_chrome(first, second) or _is_stacked_cost(first, second):
				continue
			t.assert_true(
				not first.get_global_rect().intersects(second.get_global_rect()),
				"%s %s does not overlap %s" % [mode, first.get_path(), second.get_path()]
			)


static func _is_stacked_cost(first: Control, second: Control) -> bool:
	var paths := [str(first.get_path()), str(second.get_path())]
	var has_deploy := paths.any(func(path: String) -> bool: return path.ends_with("/Costs/Deployment"))
	var has_operate := paths.any(func(path: String) -> bool: return path.ends_with("/Costs/Operation"))
	return has_deploy and has_operate


static func _is_art_under_chrome(first: Control, second: Control) -> bool:
	var paths := [str(first.get_path()), str(second.get_path())]
	var has_art := paths.any(func(path: String) -> bool: return path.ends_with("/Artwork"))
	if not has_art:
		return false
	for needle in ["/Title", "/Type", "/RoleMark", "/Costs/", "/Stats/", "/Keywords", "/Description"]:
		if paths.any(func(path: String) -> bool: return needle in path):
			return true
	return false


static func _card_data() -> Dictionary:
	return {
		"instance_id": "p-01",
		"title": "Rifle Platoon",
		"description": "Reliable infantry for holding ground.",
		"category": "Unit",
		"unit_type": "Infantry",
		"deployment_cost": 1,
		"operation_cost": 1,
		"attack": 1,
		"defense": 2,
		"keywords": ["Guard"],
		"image_path": "res://missing-card-art.png",
	}


static func _test_mulligan_model_selection_and_lock(t) -> void:
	var model := MulliganViewModel.new(["p-1", "p-2", "p-3", "p-4"])
	model.toggle("p-2")
	model.toggle("p-4")
	t.assert_eq(model.selected_ids(), ["p-2", "p-4"], "mulligan preserves hand selection order")
	model.toggle("p-2")
	t.assert_eq(model.selected_ids(), ["p-4"], "mulligan click toggles replacement off")
	model.lock()
	model.toggle("p-1")
	t.assert_eq(model.selected_ids(), ["p-4"], "locked mulligan selection is immutable")
	model.free()


static func _test_ai_mulligan_exact_fixture(t) -> void:
	var main := Main.new()
	var ai_hand := [
		{"instance_id": "o-low", "definition_id": "low", "deployment_cost": 2},
		{"instance_id": "o-duplicate", "definition_id": "low", "deployment_cost": 2},
		{"instance_id": "o-high", "definition_id": "high", "deployment_cost": 5},
		{"instance_id": "o-keep", "definition_id": "keep", "deployment_cost": 3},
	]
	var snapshot := {"players": {"player": {"hand": [{"hidden": true}]}, "opponent": {"hand": ai_hand}}}
	var selected: Array[String] = main.ai_mulligan_selection(snapshot)
	t.assert_eq(selected, ["o-duplicate", "o-high"], "AI replaces exact duplicate and high-cost fixture cards")
	var hand_ids: Array[String] = []
	for card in ai_hand:
		hand_ids.append(card.instance_id)
	for instance_id in selected:
		t.assert_true(instance_id in hand_ids, "AI replacement ID belongs to AI hand")
	var changed_player_hand := snapshot.duplicate(true)
	changed_player_hand.players.player.hand = [{"instance_id": "p-secret-a"}, {"instance_id": "p-secret-b"}]
	t.assert_eq(main.ai_mulligan_selection(changed_player_hand), selected, "player hidden-hand variation cannot affect AI mulligan")
	main.free()


static func _test_mulligan_scene_renders_and_confirms(t) -> void:
	var view = MulliganScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	var hand := [_card_data(), _card_data().merged({"instance_id": "p-02", "title": "Combat Engineers"}, true)]
	view.initialize(null, {"snapshot": {"players": {"player": {"hand": hand}}}, "difficulty": "hard"})
	await Engine.get_main_loop().process_frame
	t.assert_eq(view.get_node("%HandRow").get_child_count(), 2, "mulligan renders player hand with CardView")
	t.assert_eq(view.get_node("%DifficultyLabel").text, LocaleScript.ui("builder.diff.hard"), "mulligan displays selected difficulty")
	t.assert_eq(view.get_node("%TitleLabel").text, LocaleScript.ui("mulligan.title"), "mulligan titles the opening hand")
	var first_card = view.get_node("%HandRow").get_child(0)
	first_card.card_pressed.emit("p-01")
	t.assert_true(first_card.button_pressed, "selected replacement has clear toggled state")
	var confirmations: Array = []
	view.confirm_requested.connect(func(ids: Array[String]) -> void: confirmations.append(ids))
	view.get_node("%ConfirmButton").pressed.emit()
	view.get_node("%ConfirmButton").pressed.emit()
	t.assert_eq(confirmations, [["p-01"]], "confirm emits once with selected IDs")
	t.assert_true(view.get_node("%ConfirmButton").disabled, "confirm locks input immediately")
	view.queue_free()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame


static func _test_main_completes_both_mulligans_and_routes(t) -> void:
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	main.catalog = ContentCatalog.load_from_paths("res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json")
	main.screen_factory = func(path: String) -> Control:
		return MulliganScene.instantiate() if path.ends_with("mulligan_view.tscn") else TestScreen.new()
	var player_deck: Dictionary = main.catalog.decks_by_id["us-starter"].duplicate(true)
	main.start_mulligan(player_deck, "hard", 88)
	await Engine.get_main_loop().process_frame
	t.assert_eq(main.controller.state.phase, "mulligan", "main starts controller in mulligan phase")
	t.assert_eq(main.ai.difficulty, "hard", "main constructs AI with selected difficulty")
	var opponent_snapshot: Dictionary = main.controller.state.snapshot_for("opponent")
	var expected_ai_ids: Array[String] = main.ai_mulligan_selection(opponent_snapshot)
	t.assert_eq(main.ai_mulligan_selection(opponent_snapshot), expected_ai_ids, "AI mulligan selection is deterministic")
	var no_replacements: Array[String] = []
	main.current_screen.confirm_requested.emit(no_replacements)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	t.assert_eq(main.controller.state.phase, "action", "both action-contract confirmations start match")
	t.assert_true(main.controller.state.players.player.mulligan_used, "player mulligan action submitted")
	t.assert_true(main.controller.state.players.opponent.mulligan_used, "AI mulligan action submitted")
	t.assert_true(main.controller.state.players.player.mulligan_confirmed, "player mulligan confirmed")
	t.assert_true(main.controller.state.players.opponent.mulligan_confirmed, "AI mulligan confirmed")
	t.assert_eq((main.current_screen as TestScreen).payload.get("controller"), main.controller, "match receives live controller")
	t.assert_eq((main.current_screen as TestScreen).payload.get("ai"), main.ai, "match receives configured AI")
	var ai_action: Dictionary = main.controller.replay_log.actions[2].action
	t.assert_eq(ai_action.type, "mulligan", "AI submits through mulligan action contract")
	t.assert_eq(ai_action.target_ids, expected_ai_ids, "AI submits deterministic own-hand selections")
	main.free()
	host.free()


static func _test_mulligan_rejections_are_transactional(t) -> void:
	for rejected_step in range(4):
		var harness := _task4_main()
		var main: Main = harness.main
		var player_deck: Dictionary = main.catalog.decks_by_id["us-starter"].duplicate(true)
		main.start_mulligan(player_deck, "standard", 88)
		await Engine.get_main_loop().process_frame
		if not main.has_method("set_mulligan_action_submitter"):
			t.assert_true(false, "main exposes injectable mulligan submission boundary")
			await _free_task4_harness(harness)
			return
		var original_hash := main.controller.state_hash()
		main.set_mulligan_action_submitter(func(candidate, action, step_index: int):
			if step_index == rejected_step:
				return ActionResult.reject("injected_rejection", "Choose a different opening hand")
			return candidate.submit_action(action)
		)
		var no_replacements: Array[String] = []
		main.current_screen.confirm_requested.emit(no_replacements)
		await Engine.get_main_loop().process_frame
		t.assert_eq(main.controller.state_hash(), original_hash, "step %d rejection preserves original controller" % rejected_step)
		t.assert_eq(main.controller.state.phase, "mulligan", "step %d rejection remains in mulligan" % rejected_step)
		t.assert_true(not main.current_screen.get_node("%ConfirmButton").disabled, "step %d rejection unlocks confirm" % rejected_step)
		t.assert_true("Choose a different" in main.current_screen.get_node("%StatusLabel").text, "step %d rejection renders actionable error" % rejected_step)
		await _free_task4_harness(harness)


static func _test_mulligan_prevalidates_selection(t) -> void:
	var harness := _task4_main()
	var main: Main = harness.main
	var player_deck: Dictionary = main.catalog.decks_by_id["us-starter"].duplicate(true)
	main.start_mulligan(player_deck, "standard", 88)
	await Engine.get_main_loop().process_frame
	var original_hash := main.controller.state_hash()
	var submit_calls := [0]
	main.set_mulligan_action_submitter(func(candidate, action, step_index: int):
		submit_calls[0] += 1
		return candidate.submit_action(action)
	)
	var invalid_selection: Array[String] = ["p-not-in-hand"]
	main.current_screen.confirm_requested.emit(invalid_selection)
	await Engine.get_main_loop().process_frame
	t.assert_eq(submit_calls[0], 0, "invalid player selection is rejected before setup actions")
	t.assert_eq(main.controller.state_hash(), original_hash, "prevalidation preserves live controller")
	t.assert_true(not main.current_screen.get_node("%ConfirmButton").disabled, "prevalidation failure unlocks view")
	t.assert_true("opening hand" in main.current_screen.get_node("%StatusLabel").text, "prevalidation gives actionable error")
	await _free_task4_harness(harness)


static func _test_mulligan_renders_before_route(t) -> void:
	var harness := _task4_main()
	var main: Main = harness.main
	var mulligan_view := [null]
	var rendered_before_route := [false]
	main.screen_factory = func(path: String) -> Control:
		if path.ends_with("mulligan_view.tscn"):
			mulligan_view[0] = MulliganScene.instantiate()
			return mulligan_view[0]
		rendered_before_route[0] = mulligan_view[0] != null and mulligan_view[0].has_rendered_result()
		return TestScreen.new()
	var player_deck: Dictionary = main.catalog.decks_by_id["us-starter"].duplicate(true)
	main.start_mulligan(player_deck, "hard", 88)
	await Engine.get_main_loop().process_frame
	var no_replacements: Array[String] = []
	main.current_screen.confirm_requested.emit(no_replacements)
	t.assert_true(main.current_screen == mulligan_view[0], "mulligan remains visible immediately after confirm")
	if mulligan_view[0] == null or not mulligan_view[0].has_method("has_rendered_result"):
		t.assert_true(false, "mulligan exposes rendered-result state")
		await _free_task4_harness(harness)
		return
	await Engine.get_main_loop().process_frame
	t.assert_true(mulligan_view[0].has_rendered_result(), "result state renders before route")
	t.assert_true("Opening hand ready" in mulligan_view[0].get_node("%StatusLabel").text, "rendered event summary is visible before route")
	t.assert_true(mulligan_view[0].get_node("%HandRow").get_child_count() in [4, 5], "resulting hand state renders before route")
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	t.assert_true(rendered_before_route[0], "route observes rendered mulligan result")
	t.assert_true(main.current_screen is TestScreen, "route occurs after visible result frame")
	await _free_task4_harness(harness)


static func _test_mulligan_layout_is_responsive(t) -> void:
	for viewport_size in [Vector2(1280, 720), Vector2(1024, 576)]:
		var view = MulliganScene.instantiate()
		view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		view.size = viewport_size
		Engine.get_main_loop().root.add_child(view)
		var hand: Array = []
		for index in range(5):
			hand.append(_card_data().merged({"instance_id": "p-%02d" % index}, true))
		view.initialize(null, {"snapshot": {"players": {"player": {"hand": hand}}}})
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().process_frame
		var panel_rect: Rect2 = view.get_node("Margin/Page/HandPanel").get_global_rect()
		var footer_rect: Rect2 = view.get_node("Margin/Page/Footer").get_global_rect()
		for card in view.get_node("%HandRow").get_children():
			t.assert_true(panel_rect.encloses(card.get_global_rect()), "%s mulligan card stays inside hand panel" % viewport_size.x)
			t.assert_true(not card.get_global_rect().intersects(footer_rect), "%s mulligan card avoids commands" % viewport_size.x)
		view.queue_free()
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().process_frame


static func _task4_main() -> Dictionary:
	var main := Main.new()
	var host := Control.new()
	main.screen_host = host
	main.catalog = ContentCatalog.load_from_paths("res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json")
	main.screen_factory = func(path: String) -> Control:
		return MulliganScene.instantiate() if path.ends_with("mulligan_view.tscn") else TestScreen.new()
	Engine.get_main_loop().root.add_child(host)
	return {"main": main, "host": host}


static func _free_task4_harness(harness: Dictionary) -> void:
	var main: Main = harness.main
	main.free()
	var host: Control = harness.host
	host.queue_free()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame


static func _test_deck_builder_model(t) -> void:
	var catalog = _catalog()
	var model = DeckBuilderViewModel.DeckBuilderViewModel.new(catalog)
	model.select_deck("us-starter")
	t.assert_eq(model.card_count(), 40, "starter deck count")
	t.assert_true(model.validation().valid, "starter deck playable")
	model.add_card("su-yak-patrol")
	t.assert_true(not model.validation().valid, "invalid edit disables play")
	t.assert_true(model.selected_deck_id.begins_with("user-"), "editing shipped deck creates user copy")
	t.assert_eq((catalog.decks_by_id["us-starter"] as Dictionary).cards.size(), 40, "shipped deck remains immutable")
	model.remove_card("su-yak-patrol")
	t.assert_true(model.validation().valid, "removing edit restores validity")
	var selected: Dictionary = model.selected_deck()
	selected.cards.clear()
	t.assert_eq(model.card_count(), 40, "selected deck accessor returns a deep copy")


static func _test_deck_builder_filters(t) -> void:
	var model = DeckBuilderViewModel.DeckBuilderViewModel.new(_catalog())
	model.set_filter("search", "yak")
	model.set_filter("nation", "SovietUnion")
	model.set_filter("category", "Unit")
	model.set_filter("unit_type", "Fighter")
	model.set_filter("rarity", "Special")
	model.set_filter("cost", 5)
	var cards: Array = model.filtered_cards()
	t.assert_eq(cards.size(), 1, "all catalog filters combine")
	t.assert_eq((cards[0] as Dictionary).id, "su-yak-patrol", "filters retain matching card")


static func _test_deck_builder_reuses_existing_user_copy(t) -> void:
	var model = DeckBuilderViewModel.DeckBuilderViewModel.new(_catalog())
	model.select_deck("us-starter")
	model.add_card("su-yak-patrol")
	var copy_id: String = model.selected_deck_id
	model.select_deck("us-starter")
	model.add_card("su-yak-patrol")
	t.assert_eq(model.selected_deck_id, copy_id, "editing shipped deck reselects existing user copy")
	t.assert_eq(model.user_decks().size(), 1, "repeated shipped edits do not create hidden duplicate copies")


static func _test_deck_store_round_trip_and_shipped_immutability(t) -> void:
	var path := "user://test-decks-task3.json"
	var temp_path := path + ".tmp"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	var shipped: Array = [{"id": "us-starter", "cards": ["us-hq"]}]
	var store = DeckStore.new(path)
	t.assert_true(store.save_user_decks([{"id": "user-alpha", "cards": ["su-hq"]}]), "user decks save atomically")
	t.assert_true(store.save_user_decks([{"id": "user-alpha", "cards": ["us-hq", "su-hq"]}]), "atomic save replaces existing data")
	t.assert_true(not FileAccess.file_exists(temp_path), "atomic save leaves no temporary file")
	var loaded: Dictionary = store.load_all(shipped)
	t.assert_eq((loaded["us-starter"] as Dictionary).cards, ["us-hq"], "shipped deck loads")
	t.assert_eq((loaded["user-alpha"] as Dictionary).cards, ["us-hq", "su-hq"], "user deck round trips")
	t.assert_true(not store.save_user_decks([{"id": "us-starter", "cards": []}], shipped), "shipped deck cannot be overwritten")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _test_deck_store_surfaces_corrupt_load(t) -> void:
	var path := "user://test-decks-task3-corrupt.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()
	var store = DeckStore.new(path)
	var loaded: Dictionary = store.load_all([{"id": "us-starter", "cards": ["us-hq"]}])
	t.assert_true(loaded.has("us-starter"), "corrupt user data does not hide shipped decks")
	t.assert_true(not store.last_error.is_empty(), "corrupt user data surfaces a load error")
	t.assert_true("corrupt" in store.last_error.to_lower(), "load error is actionable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _test_deck_builder_scene_contract(t) -> void:
	var view = DeckBuilderScene.instantiate()
	view.theme = ThemeFactory.create()
	Engine.get_main_loop().root.add_child(view)
	view.initialize(null, {"catalog": _catalog(), "deck_id": "us-starter", "difficulty": "standard", "store_path": "user://test-decks-task3.json"})
	for path in ["DeckSelector", "Difficulty", "Search", "NationFilter", "CategoryFilter", "UnitTypeFilter", "RarityFilter", "CostFilter", "CatalogGrid", "DeckList", "NationDistribution", "CardCount", "Validation", "SaveButton", "PlayButton"]:
		t.assert_true(view.has_node("%%%s" % path), "deck builder exposes %s" % path)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	t.assert_eq((view.get_node("%CatalogGrid") as GridContainer).columns, 3, "catalog uses three columns")
	t.assert_true(not (view.get_node("%PlayButton") as Button).disabled, "valid shipped deck enables play")
	await _assert_builder_layout(t, view, Vector2(1280, 720))
	await _assert_builder_layout(t, view, Vector2(1024, 720))
	view.free()


static func _assert_builder_layout(t, view: Control, viewport_size: Vector2) -> void:
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.size = viewport_size
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	t.assert_eq(view.size, viewport_size, "%s-wide builder preserves assigned viewport size" % int(viewport_size.x))
	if viewport_size.x == 1024:
		t.assert_true(view.get_combined_minimum_size().x <= 1024.0, "builder combined minimum genuinely fits 1024")
		t.assert_true((view.get_node("Margin/Page") as Control).get_combined_minimum_size().x <= 992.0, "builder content minimum fits inside 1024 margins")
		t.assert_true((view.get_node("%Filters") as Control).size.x <= 160.0, "1024 layout compacts filter rail")
		t.assert_true((view.get_node("%DeckPanel") as Control).size.x <= 245.0, "1024 layout compacts deck rail")
	var columns := [view.get_node("%Filters") as Control, view.get_node("%Catalog") as Control, view.get_node("%DeckPanel") as Control]
	for index in range(columns.size() - 1):
		t.assert_true(columns[index].get_global_rect().end.x <= columns[index + 1].get_global_rect().position.x, "%s-wide builder columns do not overlap" % int(viewport_size.x))
	var viewport_rect := view.get_global_rect()
	for path in ["DeckSelector", "Difficulty", "Search", "NationFilter", "CategoryFilter", "UnitTypeFilter", "RarityFilter", "CostFilter", "Catalog", "DeckList", "NationDistribution", "CardCount", "Validation", "SaveButton", "PlayButton"]:
		var control := view.get_node("%%%s" % path) as Control
		t.assert_true(viewport_rect.encloses(control.get_global_rect()), "%s-wide viewport contains %s" % [int(viewport_size.x), path])


static func _test_deck_builder_copy_selection_and_save_failure(t) -> void:
	var path := "user://test-decks-task3-blocker"
	var blocker := FileAccess.open(path, FileAccess.WRITE)
	blocker.store_string("file blocks directory creation")
	blocker.close()
	var view = DeckBuilderScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	view.initialize(null, {"catalog": _catalog(), "deck_id": "us-starter", "difficulty": "standard", "store_path": path + "/decks.json"})
	view._on_add_card("su-yak-patrol")
	var selector := view.get_node("%DeckSelector") as OptionButton
	t.assert_eq(str(selector.get_item_metadata(selector.selected)), view.model.selected_deck_id, "copy-on-edit visibly selects user deck")
	t.assert_eq(selector.item_count, view.model.decks.size(), "selector rebuild includes user copy exactly once")
	view._on_save_pressed()
	t.assert_true("failed" in (view.get_node("%Validation") as Label).text.to_lower(), "failed persistence never claims Saved")
	t.assert_true(not view.store.last_error.is_empty(), "save failure exposes actionable detail")
	view.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _test_deck_builder_falls_back_when_selected_deck_invalid(t) -> void:
	# Simulate a stale, invalid user deck persisted from a previous session and
	# selected as the entry deck. Start Battle must not strand the player on it:
	# initialize falls back to a valid shipped starter so play is always reachable.
	var path := "user://test-decks-stale-invalid.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([{"id": "user-broken", "cards": ["us-hq"]}]))
	file.close()
	var view = DeckBuilderScene.instantiate()
	view.theme = ThemeFactory.create()
	Engine.get_main_loop().root.add_child(view)
	view.initialize(null, {"catalog": _catalog(), "deck_id": "user-broken", "difficulty": "standard", "store_path": path})
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	t.assert_eq((view.get_node("%PlayButton") as Button).disabled, false, "invalid selected deck falls back so Start Battle is enabled")
	t.assert_eq(view.model.selected_deck_id, "us-starter", "invalid entry deck falls back to the US starter")
	view.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _test_deck_builder_displays_corrupt_load_status(t) -> void:
	var path := "user://test-decks-task3-ui-corrupt.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var view = DeckBuilderScene.instantiate()
	view.initialize(null, {"catalog": _catalog(), "deck_id": "us-starter", "difficulty": "standard", "store_path": path})
	t.assert_true("corrupt" in (view.get_node("%Validation") as Label).text.to_lower(), "builder displays corrupt persistence status")
	view.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _catalog():
	return ContentCatalog.load_from_paths("res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json")
