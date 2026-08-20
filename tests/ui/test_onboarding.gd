const CoreCards = preload("res://tests/fixtures/core_cards.gd")
const GameAction = preload("res://scripts/core/game_action.gd")
const MatchController = preload("res://scripts/core/match_controller.gd")
const MatchCoachModel = preload("res://scripts/ui/match_coach_model.gd")
const OnboardingStore = preload("res://scripts/ui/onboarding_store.gd")
const ContentCatalog = preload("res://scripts/content/content_catalog.gd")
const DeckBuilderScene = preload("res://scenes/ui/deck_builder_view.tscn")
const MatchViewScene = preload("res://scenes/ui/match_view.tscn")
const CardMotionDirector = preload("res://scripts/ui/card_motion_director.gd")
const AIPlayer = preload("res://scripts/ai/ai_player.gd")
const LocaleScript = preload("res://scripts/ui/locale.gd")

class MotionProbe:
	extends RefCounted
	var completed := false
	func run_director(director, events: Array, before: Dictionary, after: Dictionary, view) -> void:
		await director.play(events, before, after, view)
		completed = true
	func run_view(view, events: Array, before: Dictionary, after: Dictionary) -> void:
		await view.play_motion(events, before, after)
		completed = true


static func run(t) -> void:
	_test_coach_priority_and_exact_copy(t)
	_test_milestone_objective_progression(t)
	_test_real_first_turn_credit_fixture(t)
	_test_real_active_countermeasure_is_legal(t)
	_test_source_reasons(t)
	_test_end_turn_requires_the_sole_complete_action(t)
	_test_persistence(t)
	_test_persistence_rejects_non_user_paths(t)
	await _test_deck_builder_starter_readiness(t)
	await _test_deck_builder_edited_validation_and_restoration(t)
	await _test_deck_builder_readiness_containment(t)
	await _test_match_coach_and_card_states(t)
	await _test_board_unit_duty_states(t)
	await _test_guard_links_and_timeline_report(t)
	await _test_aim_arrow_and_dual_play(t)
	await _test_illegal_source_does_not_aim(t)
	await _test_dead_commands_stay_hidden(t)
	await _test_hand_fan_is_uncropped(t)
	await _test_opponent_hand_peeks_above_board(t)
	await _test_rejection_refresh_ordering(t)
	await _test_end_turn_semantic_states(t)
	await _test_unavailable_card_does_not_submit(t)
	await _test_target_highlights_preserve_geometry(t)
	await _test_stable_battlefield_grid(t)
	await _test_visible_card_registry(t)
	await _test_event_animation_queue(t)
	await _test_real_move_draw_attack_destroy_and_commands(t)
	await _test_motion_cancellation_resolves(t)
	await _test_lock_blocks_animation_and_keyboard_selection(t)
	_test_animation_preference_reload(t)
	await _test_real_main_milestone_submissions(t)


static func _test_deck_builder_starter_readiness(t) -> void:
	var onboarding_path := "user://test-onboarding-deck-builder.json"
	_cleanup(onboarding_path)
	var view = await _create_deck_builder(onboarding_path, Vector2(1280, 720))
	t.assert_eq(view.get_node("%StarterStatus").text, LocaleScript.ui("builder.starter_ready"), "shipped deck has exact readiness copy")
	t.assert_eq(view.get_node("%StarterHint").text, LocaleScript.ui("builder.hint"), "starter hint uses exact explanatory copy")
	t.assert_true(view.get_node("%StarterHint").visible, "starter hint begins visible")
	t.assert_eq(view.get_node("%PlayButton").text, LocaleScript.ui("builder.play"), "launch command names the battle")
	var dismiss := view.get_node("%DismissHint") as Button
	t.assert_eq(dismiss.tooltip_text, "Hide starter hint", "icon close button explains itself")
	dismiss.pressed.emit()
	await view.get_tree().process_frame
	t.assert_true(not view.get_node("%StarterHint").visible, "dismissal hides only the explanatory sentence")
	t.assert_true(view.get_node("%StarterStatus").visible, "dismissal preserves live readiness")
	view.queue_free()
	await Engine.get_main_loop().process_frame

	view = await _create_deck_builder(onboarding_path, Vector2(1280, 720))
	t.assert_true(not view.get_node("%StarterHint").visible, "dismissal reloads from injected onboarding path")
	t.assert_eq(view.get_node("%StarterStatus").text, LocaleScript.ui("builder.starter_ready"), "readiness remains after persisted dismissal")
	view.queue_free()
	await Engine.get_main_loop().process_frame
	_cleanup(onboarding_path)


static func _test_deck_builder_edited_validation_and_restoration(t) -> void:
	var onboarding_path := "user://test-onboarding-edits.json"
	_cleanup(onboarding_path)
	var view = await _create_deck_builder(onboarding_path, Vector2(1280, 720))
	var shipped_cards: Array = view.model._cards().duplicate()
	view._on_add_card(str(shipped_cards[0]))
	t.assert_eq(view.get_node("%StarterStatus").text, "Deck Size", "added card shows the first concrete validator error")
	t.assert_true(view.get_node("%PlayButton").disabled, "added card disables Start Battle")
	t.assert_true("Starter deck ready" not in view.get_node("%StarterStatus").text, "edited copy loses preset readiness")

	view.model.select_deck("us-starter")
	view._refresh_deck()
	t.assert_eq(view.get_node("%StarterStatus").text, LocaleScript.ui("builder.starter_ready"), "returning to shipped deck restores readiness")
	t.assert_true(not view.get_node("%PlayButton").disabled, "restored shipped deck enables Start Battle")
	view.queue_free()
	await Engine.get_main_loop().process_frame

	view = await _create_deck_builder(onboarding_path + "-remove", Vector2(1280, 720))
	shipped_cards = view.model._cards().duplicate()
	view._on_remove_card(str(shipped_cards[0]))
	t.assert_eq(view.get_node("%StarterStatus").text, "Deck Size", "removed card shows the first concrete validator error")
	t.assert_true(view.get_node("%PlayButton").disabled, "removed card disables Start Battle")
	view.model.select_deck("us-starter")
	view._refresh_deck()
	t.assert_eq(view.get_node("%StarterStatus").text, LocaleScript.ui("builder.starter_ready"), "shipped deck readiness restores after removal edit")
	view.queue_free()
	await Engine.get_main_loop().process_frame
	_cleanup(onboarding_path)


static func _test_deck_builder_readiness_containment(t) -> void:
	for viewport_size in [Vector2(1280, 720), Vector2(1024, 720)]:
		var path := "user://test-onboarding-layout-%d.json" % int(viewport_size.x)
		_cleanup(path)
		var view = await _create_deck_builder(path, viewport_size)
		var strip := view.get_node("%StarterReadiness") as Control
		var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
		t.assert_true(viewport_rect.encloses(strip.get_global_rect()), "readiness strip stays contained at %d" % int(viewport_size.x))
		t.assert_true(strip.get_global_rect().end.y <= (view.get_node("%Workspace") as Control).get_global_rect().position.y, "readiness strip stays above workspace at %d" % int(viewport_size.x))
		t.assert_true(strip.size.y <= 56.0, "readiness strip remains compact at %d" % int(viewport_size.x))
		view.queue_free()
		await Engine.get_main_loop().process_frame
		_cleanup(path)


static func _create_deck_builder(onboarding_path: String, viewport_size: Vector2):
	var root := Engine.get_main_loop().root as Window
	var view = DeckBuilderScene.instantiate()
	root.add_child(view)
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = viewport_size
	var deck_store_path := onboarding_path.replace("onboarding", "decks")
	_cleanup(deck_store_path)
	view.initialize(null, {
		"catalog": ContentCatalog.load_from_paths("res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json"),
		"deck_id": "us-starter",
		"difficulty": "standard",
		"store_path": deck_store_path,
		"onboarding_path": onboarding_path,
	})
	await view.get_tree().process_frame
	return view


static func _test_match_coach_and_card_states(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	view.render_snapshot(_snapshot())
	view.set_legal_actions([_action("deploy_unit", "one-cost", [], {"support_slot": 0}), _action("end_turn")])
	view.set_onboarding_state(OnboardingStore.defaults())
	await view.get_tree().process_frame
	t.assert_eq(view.get_node("%CoachObjective").text, LocaleScript.ui("coach.deploy"), "coach renders first-turn deploy objective")
	var cards := view.get_node("%PlayerHand").get_children()
	t.assert_eq(cards[0].action_state, "legal", "legal hand source is highlighted")
	t.assert_eq(cards[1].action_state, "unavailable", "illegal hand source is unavailable")
	t.assert_true(cards[1].tooltip_text.begins_with(LocaleScript.ui("reason.credit")), "unavailable source exposes concrete reason")
	view._on_card_pressed("one-cost")
	t.assert_eq(cards[0].action_state, "selected", "selected source has selected semantics")
	t.assert_eq(view.get_node("%CoachObjective").text, LocaleScript.ui("coach.support_slot"), "selection refreshes coach immediately")
	t.assert_eq(view.get_node("%StatusLabel").text, "", "precise coach copy replaces legacy selection status")
	var objective_height := (view.get_node("%CoachObjective") as Control).size.y
	t.assert_true(not view.has_node("%AnimationButton"), "match does not keep animation on the battlefield")
	t.assert_true(view.has_node("%SettingsButton"), "match exposes a settings entry")
	view._open_settings()
	var settings = view.get_node("SettingsDialog")
	t.assert_true(settings.visible, "settings opens from the match menu")
	settings.get_node("%ReducedMotionButton").pressed.emit()
	t.assert_eq(view.animation_mode, "reduced", "settings switches to reduced motion")
	settings.close()
	view.show_rejection("stale_action", "That action is no longer legal.")
	t.assert_eq(view.get_node("%CoachObjective").text, "That action is no longer legal.", "rejection takes coach precedence")
	t.assert_eq((view.get_node("%CoachObjective") as Control).size.y, objective_height, "rejection does not resize coach strip")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_board_unit_duty_states(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	var snapshot := _snapshot()
	snapshot["turn"] = 3
	snapshot.players.player.support_line = [
		{"instance_id": "fresh-unit", "category": "Unit", "unit_type": "Infantry", "owner_id": "player", "deployed_turn": 3, "operations_used": 0, "operation_cost": 1},
		{"instance_id": "spent-unit", "category": "Unit", "unit_type": "Infantry", "owner_id": "player", "deployed_turn": 1, "operations_used": 1, "operation_cost": 1},
		{"instance_id": "ready-unit", "category": "Unit", "unit_type": "Infantry", "owner_id": "player", "deployed_turn": 1, "operations_used": 0, "operation_cost": 1},
		null,
	]
	view.render_snapshot(snapshot)
	view.set_legal_actions([_action("move_unit", "ready-unit", [], {"frontline_slot": 0}), _action("end_turn")])
	await view.get_tree().process_frame
	var cards: Array = view.get_node("%PlayerSupport").card_views()
	t.assert_eq(cards.size(), 3, "support line exposes the three placed units")
	if cards.size() == 3:
		t.assert_eq(cards[0].action_state, "unavailable", "just-deployed unit is unavailable")
		t.assert_true(cards[0].tooltip_text.begins_with(LocaleScript.ui("reason.sickness")), "just-deployed unit explains summoning sickness")
		t.assert_eq(cards[0].get_node("Frame/Type").text, LocaleScript.ui("duty.deployed"), "just-deployed unit shows duty caption")
		t.assert_eq(cards[1].action_state, "unavailable", "spent unit is unavailable")
		t.assert_true(cards[1].tooltip_text.begins_with(LocaleScript.ui("reason.acted")), "spent unit explains it already operated")
		t.assert_eq(cards[1].get_node("Frame/Type").text, LocaleScript.ui("duty.spent"), "spent unit shows duty caption")
		t.assert_eq(cards[2].action_state, "legal", "ready unit is highlighted")
		t.assert_eq(cards[2].get_node("Frame/Type").text, LocaleScript.ui("duty.ready"), "ready unit shows duty caption")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_guard_links_and_timeline_report(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	var snapshot := _snapshot()
	snapshot.players.player.support_line = [
		{"instance_id": "neighbor", "title": "Rifle Platoon", "category": "Unit", "owner_id": "player", "slot": 0, "keywords": []},
		{"instance_id": "guard-unit", "title": "Guards Rifle Section", "category": "Unit", "owner_id": "player", "slot": 1, "keywords": ["Guard"]},
		null,
		null,
	]
	snapshot.players.player["headquarters"] = {"instance_id": "player-hq", "title": "US Command Post", "category": "Headquarters"}
	view.render_snapshot(snapshot)
	await view.get_tree().process_frame
	await view.get_tree().process_frame
	t.assert_true(view._guard_segments.size() >= 2, "Guard links HQ and the adjacent unit")
	view.render_events([
		{"type": "card_deployed", "player_id": "player", "instance_id": "guard-unit"},
		{"type": "credit_spent", "player_id": "player"},
		{"type": "damage_dealt", "player_id": "opponent", "damage": 3, "target_id": "neighbor"},
	])
	var lines: Array[String] = []
	for child in view.get_node("%Timeline").get_children():
		if child is Label:
			lines.append(child.text)
	t.assert_true(lines.size() == 2, "timeline report skips credit noise")
	t.assert_true(LocaleScript.ui("event.card_deployed") in lines[0] and "Guards Rifle Section" in lines[0], "deploy report names the card")
	t.assert_true(LocaleScript.ui("event.damage_dealt") in lines[1] and "3" in lines[1], "damage report includes the amount")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_aim_arrow_and_dual_play(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	view.render_snapshot(_snapshot())
	view.set_legal_actions([_action("deploy_unit", "one-cost", [], {"support_slot": 0}), _action("end_turn")])
	await view.get_tree().process_frame
	view._on_card_pressed("one-cost")
	t.assert_eq(view.model.selected_source_id, "one-cost", "click selects the source card")
	t.assert_true(view.is_processing(), "two-click aiming tracks the mouse")
	t.assert_true(0 in view.model.highlighted_slots("support"), "legal drop slots highlight after click")
	t.assert_true(view._aim_source_point() != Vector2.ZERO, "aim arrow has a source point")
	view.model.cancel()
	view._refresh_coach()
	view._on_card_drag_started("one-cost")
	t.assert_eq(view.model.selected_source_id, "one-cost", "drag start selects the same source")
	t.assert_true(0 in view.model.highlighted_slots("support"), "legal drop slots highlight during drag")
	var slot := view.get_node("%PlayerSupport").get_child(0)
	var other := view.get_node("%PlayerSupport").get_child(1)
	t.assert_true(slot._can_drop_data(Vector2.ZERO, {"instance_id": "one-cost"}), "legal slot accepts the dragged card")
	t.assert_true(not other._can_drop_data(Vector2.ZERO, {"instance_id": "one-cost"}), "unhighlighted slot rejects the drop")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_illegal_source_does_not_aim(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	var snapshot := _snapshot()
	snapshot["turn"] = 3
	snapshot.players.player.support_line = [
		{"instance_id": "fresh-unit", "category": "Unit", "unit_type": "Infantry", "owner_id": "player", "deployed_turn": 3, "operations_used": 0, "operation_cost": 1},
		{"instance_id": "ready-unit", "category": "Unit", "unit_type": "Infantry", "owner_id": "player", "deployed_turn": 1, "operations_used": 0, "operation_cost": 1},
		null,
		null,
	]
	view.render_snapshot(snapshot)
	view.set_legal_actions([_action("move_unit", "ready-unit", [], {"zone": "frontline", "slot": 0}), _action("end_turn")])
	await view.get_tree().process_frame
	view._on_card_pressed("three-cost")
	t.assert_eq(view.model.selected_source_id, "", "unavailable hand card is not selected")
	t.assert_true(not view.is_processing(), "unavailable hand card does not start the aim arrow")
	t.assert_true(not view._source_can_aim(), "unavailable hand card cannot draw an aim arrow")
	view._on_board_card_pressed("fresh-unit")
	t.assert_eq(view.model.selected_source_id, "", "unavailable board unit is not selected")
	t.assert_true(not view.is_processing(), "unavailable board unit does not start the aim arrow")
	t.assert_true(not view._source_can_aim(), "unavailable board unit cannot draw an aim arrow")
	view._on_card_drag_started("three-cost")
	t.assert_eq(view.model.selected_source_id, "", "dragging an unavailable card does not select it")
	t.assert_true(not view._source_can_aim(), "dragging an unavailable card does not start the aim arrow")
	view._on_board_card_pressed("ready-unit")
	t.assert_eq(view.model.selected_source_id, "ready-unit", "legal board unit can still be selected")
	t.assert_true(view._source_can_aim(), "legal board unit can aim at a destination")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_dead_commands_stay_hidden(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	view.render_snapshot(_snapshot())
	view.set_legal_actions([_action("deploy_unit", "one-cost", [], {"support_slot": 0}), _action("end_turn")])
	await view.get_tree().process_frame
	t.assert_true(not view.get_node("%ConfirmButton").visible, "Confirm stays hidden until an action needs it")
	t.assert_true(not view.get_node("%CancelButton").visible, "Cancel stays hidden until a source is selected")
	t.assert_true(view.get_node("%EndTurnButton").visible, "End Turn appears when it can be used")
	view._on_card_pressed("one-cost")
	t.assert_true(view.get_node("%CancelButton").visible, "Cancel appears after a source is selected")
	t.assert_true(not view.get_node("%ConfirmButton").visible, "Confirm stays hidden while a slot is still required")
	view._open_settings()
	var settings = view.get_node("SettingsDialog")
	t.assert_true(settings.visible, "settings dialog opens from the match menu")
	t.assert_eq(settings.get_node("%FullMotionButton").text, LocaleScript.ui("settings.motion_full"), "settings exposes full motion")
	t.assert_true(settings.get_node("%ConcedeButton").visible, "settings offers concede during the player turn")
	t.assert_true(settings.get_node("%ExitButton").visible, "settings offers exit")
	t.assert_eq(settings.get_node("%ExitButton").text, LocaleScript.ui("settings.exit"), "exit uses the settings label")
	settings.close()
	t.assert_true(not settings.visible, "closing settings returns to the board")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_hand_fan_is_uncropped(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	view.render_snapshot(_match_hand_snapshot(5))
	await view.get_tree().process_frame
	await view.get_tree().process_frame
	var hand := view.get_node("%PlayerHand") as Control
	var scroll := view.get_node("%HandScroll") as Control
	t.assert_true(not scroll.clip_contents, "hand scroll does not clip the fan")
	t.assert_true(hand.custom_minimum_size.y <= 96.0, "hand strip stays compact")
	t.assert_true(scroll.custom_minimum_size.y <= 96.0, "hand viewport stays compact")
	var hand_area := view.get_node("Margin/Columns/Board/HandArea") as Control
	t.assert_true(view.size.y - hand_area.get_global_rect().end.y <= 12.0, "hand sits on the bottom edge")
	t.assert_true(not view.has_node("Margin/Columns/Board/BottomFlex"), "leftover height is not parked under the hand")
	var opponent_row := view.get_node("Margin/Columns/Board/OpponentArea") as Control
	var frontline := view.get_node("%Frontline") as Control
	var player_row := view.get_node("Margin/Columns/Board/PlayerArea") as Control
	t.assert_true(opponent_row.size_flags_vertical & Control.SIZE_EXPAND, "opponent row takes leftover height")
	t.assert_true(player_row.size_flags_vertical & Control.SIZE_EXPAND, "player row takes leftover height")
	t.assert_true(frontline.global_position.y - opponent_row.get_global_rect().end.y >= 6.0, "opponent row and frontline keep a gap")
	t.assert_true(player_row.global_position.y - frontline.get_global_rect().end.y >= 6.0, "frontline and player row keep a gap")
	for card in hand.get_children():
		t.assert_true((card as Control).position.y >= 0.0, "hand card is not pushed above the fan")
		t.assert_true((card as Control).position.y < scroll.custom_minimum_size.y, "hand card starts inside the strip")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_opponent_hand_peeks_above_board(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	var snapshot := _snapshot()
	snapshot.players.opponent.hand = [{"hidden": true}, {"hidden": true}, {"hidden": true}, {"hidden": true}]
	snapshot.players.opponent.support_line = [
		{"instance_id": "enemy-guard", "title": "Guards Rifle Section", "category": "Unit", "owner_id": "opponent", "slot": 0},
		null, null, null,
	]
	view.render_snapshot(snapshot)
	await view.get_tree().process_frame
	await view.get_tree().process_frame
	var strip := view.get_node("%OpponentHandStrip") as Control
	var support := view.get_node("%OpponentSupport") as Control
	var hq := view.get_node("%OpponentHQ") as Control
	t.assert_true(strip.custom_minimum_size.y <= 28.0, "opponent hand keeps a short peek strip")
	t.assert_true(strip.get_global_rect().end.y <= support.get_global_rect().position.y + 1.0, "peek strip sits above enemy support")
	t.assert_true(strip.get_global_rect().end.y <= hq.get_global_rect().position.y + 1.0, "peek strip sits above enemy HQ")
	for card in view.get_node("%OpponentHand").get_children():
		var rect: Rect2 = view.opponent_card_visual_rect(card)
		t.assert_true(not rect.intersects(support.get_global_rect()), "opponent hand does not cover support")
		t.assert_true(not rect.intersects(hq.get_global_rect()), "opponent hand does not cover HQ")
		t.assert_true(rect.position.y < strip.get_global_rect().position.y + 2.0, "opponent cards hang off the top of the strip")
		t.assert_true(rect.end.y <= support.get_global_rect().position.y + 1.0, "opponent card bottoms stay out of the play row")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _match_hand_snapshot(hand_count: int) -> Dictionary:
	var snapshot := _snapshot()
	var hand: Array = []
	for index in range(hand_count):
		hand.append({"instance_id": "fan-%d" % index, "title": "Rifle Platoon", "category": "Unit", "owner_id": "player"})
	snapshot.players.player.hand = hand
	return snapshot


static func _test_rejection_refresh_ordering(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	var snapshot := _snapshot().merged({"sequence": 12}, true)
	var actions := [_action("deploy_unit", "one-cost", [], {"support_slot": 0}), _action("end_turn")]
	view.render_snapshot(snapshot)
	view.set_legal_actions(actions)
	view.show_rejection("stale_action", "State changed")
	view.set_legal_actions(actions)
	t.assert_eq(view.get_node("%CoachObjective").text, "State changed", "legal refresh does not erase rejection")
	view.render_snapshot(snapshot)
	t.assert_eq(view.get_node("%CoachObjective").text, "State changed", "same-sequence rerender does not erase rejection")
	var advanced := snapshot.duplicate(true)
	advanced.sequence = 13
	view.render_snapshot(advanced)
	t.assert_eq(view.get_node("%CoachObjective").text, LocaleScript.ui("coach.deploy"), "authoritative sequence advance clears rejection")
	t.assert_eq(view.get_node("%StatusLabel").text, "", "authoritative sequence advance clears rejection status")
	view.show_rejection("stale_action", "State changed")
	view._on_card_pressed("one-cost")
	t.assert_eq(view.get_node("%CoachObjective").text, LocaleScript.ui("coach.support_slot"), "selection change clears rejection")
	view.show_rejection("stale_action", "State changed")
	view._on_cancel_pressed()
	t.assert_eq(view.get_node("%CoachObjective").text, LocaleScript.ui("coach.deploy"), "cancellation clears rejection")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_end_turn_semantic_states(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	view.render_snapshot(_snapshot())
	var button := view.get_node("%EndTurnButton") as Button
	var end := _action("end_turn")
	var deploy := _action("deploy_unit", "one-cost", [], {"support_slot": 0})
	view.set_legal_actions([])
	t.assert_true(button.disabled, "empty legal list disables End Turn")
	t.assert_true(not button.visible, "empty legal list hides End Turn")
	t.assert_eq(button.get_meta("action_state", ""), "disabled", "empty legal list has disabled semantics")
	view.set_legal_actions([deploy])
	t.assert_true(button.disabled, "non-End-Turn legal list disables End Turn")
	t.assert_true(not button.visible, "non-End-Turn legal list hides End Turn")
	view.set_legal_actions([deploy, end])
	t.assert_true(not button.disabled, "exact End Turn candidate enables command")
	t.assert_true(button.visible, "usable End Turn is shown")
	t.assert_eq(button.get_meta("action_state", ""), "normal", "mixed legal actions keep normal End Turn emphasis")
	view.set_legal_actions([end, end])
	t.assert_true(not button.disabled, "End Turn remains enabled whenever an exact candidate exists")
	t.assert_eq(button.get_meta("action_state", ""), "normal", "duplicate candidates are not sole-action emphasis")
	view.set_legal_actions([end])
	t.assert_true(not button.disabled, "sole End Turn remains enabled")
	t.assert_eq(button.get_meta("action_state", ""), "strong", "sole End Turn receives strong semantic emphasis")
	t.assert_true(button.get_theme_stylebox("normal").get_border_width(SIDE_LEFT) >= 3, "strong End Turn state has visible border emphasis")
	t.assert_true(not view.get_node("%CoachObjective").visible, "sole End Turn does not occupy a banner")
	t.assert_eq(view.get_node("%CoachObjective").text, "", "sole End Turn does not lecture the player")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_unavailable_card_does_not_submit(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	view.render_snapshot(_snapshot())
	view.set_legal_actions([_action("end_turn")])
	view.set_onboarding_state(OnboardingStore.defaults())
	var submitted := 0
	view.action_requested.connect(func(_action_value) -> void: submitted += 1)
	view._on_card_pressed("three-cost")
	t.assert_eq(submitted, 0, "unavailable click never submits an action")
	t.assert_eq(view.get_node("%StatusLabel").text, LocaleScript.ui("reason.credit"), "unavailable click displays concrete reason")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_target_highlights_preserve_geometry(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1024, 720)
	view.render_snapshot(_snapshot())
	await view.get_tree().process_frame
	var slot := view.get_node("%PlayerSupport").get_child(0) as Control
	var before := slot.get_global_rect()
	view.get_node("%PlayerSupport").set_highlights([0], [])
	await view.get_tree().process_frame
	t.assert_eq(slot.get_global_rect(), before, "strong slot highlight does not shift layout")
	t.assert_true(slot.get_theme_stylebox("normal").get_border_width(SIDE_LEFT) >= 3, "highlight uses a strong slot border")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_stable_battlefield_grid(t) -> void:
	for viewport_width in [1280, 1024]:
		var view = MatchViewScene.instantiate()
		Engine.get_main_loop().root.add_child(view)
		Engine.get_main_loop().root.size = Vector2i(viewport_width, 720)
		view.render_snapshot(_populated_grid_snapshot())
		await view.get_tree().process_frame
		await view.get_tree().process_frame
		var expected_centers: Array[float] = []
		for zone_name in ["OpponentSupport", "Frontline", "PlayerSupport"]:
			var zone := view.get_node("%%%s" % zone_name) as Control
			var centers: Array[float] = zone.grid_column_centers()
			if expected_centers.is_empty(): expected_centers = centers
			t.assert_eq(centers, expected_centers, "%s shares stable five-column centers at %d" % [zone_name, viewport_width])
			t.assert_eq(centers.size(), 5, "%s exposes five grid cells at %d" % [zone_name, viewport_width])
			for slot in zone.get_children():
				var slot_control := slot as Control
				t.assert_true(is_equal_approx(slot_control.size.x, 80.0), "slot matches battlefield card width at %d" % viewport_width)
				t.assert_true(is_equal_approx(slot_control.size.y, 112.0), "slot matches battlefield card height at %d" % viewport_width)
				if slot_control.get_child_count() > 0:
					t.assert_true(slot_control.get_global_rect().encloses((slot_control.get_child(0) as Control).get_global_rect()), "card fills without escaping its stable slot")
		var grid_left: float = (view.get_node("%Frontline").get_child(0) as Control).get_global_rect().position.x
		var opponent_hq := view.get_node("%OpponentHQ") as Control
		var player_hq := view.get_node("%PlayerHQ") as Control
		t.assert_true(opponent_hq.get_global_rect().end.x < grid_left, "opponent HQ stays outside grid")
		t.assert_true(player_hq.get_global_rect().end.x < grid_left, "player HQ stays outside grid")
		t.assert_true(grid_left - opponent_hq.get_global_rect().end.x <= 16.0, "opponent HQ docks to the support line")
		t.assert_true(grid_left - player_hq.get_global_rect().end.x <= 16.0, "player HQ docks to the support line")
		var hand := view.get_node("%PlayerHand") as Control
		if hand.get_child_count() > 1:
			var hand_gap := (hand.get_child(1) as Control).position.x - (hand.get_child(0) as Control).position.x
			t.assert_eq(snappedf(hand_gap, 0.01), 100.0, "hand uses fixed card spacing")
		view.queue_free()
		await Engine.get_main_loop().process_frame


static func _test_visible_card_registry(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	var controller := _real_action_controller("player")
	var deploy = _first_legal(controller, "player", "deploy_unit")
	var before: Dictionary = controller.state.snapshot_for("player")
	view.render_snapshot(before)
	await view.get_tree().process_frame
	var identity = view.card_view(deploy.source_id)
	var source_rect: Rect2 = view.visible_card_rects()[deploy.source_id]
	var result = controller.submit_action(deploy)
	t.assert_true(result.accepted, "real deploy transition is accepted")
	var after: Dictionary = controller.state.snapshot_for("player")
	var measured_after: Dictionary = view.snapshot_card_rects(after)
	t.assert_true(measured_after.has(deploy.source_id), "after geometry measures deployed public instance off current snapshot")
	t.assert_true(source_rect.get_center().distance_to((measured_after[deploy.source_id] as Rect2).get_center()) > 40.0, "deploy has distinct hand and Support geometry")
	view.render_snapshot(after)
	await view.get_tree().process_frame
	t.assert_true(view.card_view(deploy.source_id) == identity, "deploy reparents the same persistent CardView")
	t.assert_eq(view.visible_card_rects()[deploy.source_id], measured_after[deploy.source_id], "deployed CardView ends at measured Support rect: %s != %s" % [view.visible_card_rects()[deploy.source_id], measured_after[deploy.source_id]])
	for hidden in before.players.opponent.hand:
		if hidden is Dictionary:
			t.assert_true(not view.visible_card_rects().has(str(hidden.get("instance_id", ""))), "hidden opponent hand identity is excluded")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_event_animation_queue(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	var controller := _real_action_controller("player")
	var deploy = _first_legal(controller, "player", "deploy_unit")
	var before: Dictionary = controller.state.snapshot_for("player")
	view.render_snapshot(before)
	await view.get_tree().process_frame
	var result = controller.submit_action(deploy)
	var after: Dictionary = controller.state.snapshot_for("player")
	var director = CardMotionDirector.new()
	director.speed_scale = 1.0
	var probe := MotionProbe.new()
	probe.call_deferred("run_director", director, result.events, before, after, view)
	await Engine.get_main_loop().create_timer(0.08).timeout
	await Engine.get_main_loop().process_frame
	var proxies := view.get_tree().get_nodes_in_group("card_motion_proxy")
	t.assert_true(not proxies.is_empty(), "real deploy exposes an in-flight proxy")
	if not proxies.is_empty():
		var position := (proxies[0] as Control).get_global_rect().get_center()
		var source := (view.snapshot_card_rects(before)[deploy.source_id] as Rect2).get_center()
		var destination := (view.snapshot_card_rects(after)[deploy.source_id] as Rect2).get_center()
		t.assert_true(position.distance_to(source) > 1.0 and position.distance_to(destination) > 1.0, "deploy proxy reaches a true midpoint: %s source %s destination %s" % [position, source, destination])
	while not probe.completed:
		await Engine.get_main_loop().process_frame
	view.render_snapshot(after)
	await view.get_tree().process_frame
	t.assert_eq(view.visible_card_rects()[deploy.source_id], view.snapshot_card_rects(after)[deploy.source_id], "animation reconciles to authoritative destination")
	t.assert_eq(view.get_tree().get_nodes_in_group("card_motion_proxy").size(), 0, "animation queue cleans motion proxies")
	t.assert_eq(view.get_tree().get_nodes_in_group("card_damage_indicator").size(), 0, "animation queue cleans damage indicators")
	view.set_animation_mode("reduced")
	await director.play(result.events, before, after, view)
	t.assert_true(director.last_duration_ms <= 80.0, "reduced mode caps animation duration")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_motion_cancellation_resolves(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	var controller := _real_action_controller("player")
	var action = _first_legal(controller, "player", "deploy_unit")
	var before: Dictionary = controller.state.snapshot_for("player")
	view.render_snapshot(before)
	await view.get_tree().process_frame
	var result = controller.submit_action(action)
	var after: Dictionary = controller.state.snapshot_for("player")
	view.animation_speed_scale = 2.0
	var probe := MotionProbe.new()
	probe.call_deferred("run_view", view, result.events, before, after)
	for _frame in range(20):
		await Engine.get_main_loop().process_frame
		if not view.get_tree().get_nodes_in_group("card_motion_proxy").is_empty(): break
	view.cancel_motion(after)
	await Engine.get_main_loop().process_frame
	t.assert_true(probe.completed, "cancelled motion await resolves")
	t.assert_eq(view.snapshot.get("sequence"), after.get("sequence"), "cancellation snaps authoritative sequence")
	t.assert_true(view.visible_card_rects().has(action.source_id), "cancellation renders deployed card from authoritative after snapshot")
	t.assert_eq(view.get_tree().get_nodes_in_group("card_motion_proxy").size(), 0, "cancellation leaves no proxies")
	view.queue_free()
	await Engine.get_main_loop().process_frame

	var main_controller := _real_action_controller("player")
	var main_action = _first_legal(main_controller, "player", "deploy_unit")
	var runtime := _main_runtime(main_controller, OnboardingStore.new("user://test-cancel-store.json"))
	runtime.main.current_screen.animation_speed_scale = 2.0
	runtime.main.submit_player_action(main_action)
	for _frame in range(30):
		await Engine.get_main_loop().process_frame
		if not runtime.main.current_screen.get_tree().get_nodes_in_group("card_motion_proxy").is_empty(): break
	t.assert_true(runtime.main._match_submission_active and runtime.main.current_screen._input_locked, "Main locks input while accepted motion is active")
	runtime.main.current_screen.size.x -= 1.0
	for _frame in range(60):
		await Engine.get_main_loop().process_frame
		if not runtime.main._match_submission_active: break
	t.assert_true(not runtime.main._match_submission_active and not runtime.main.current_screen._input_locked, "resize cancellation resolves Main queue and unlocks input")
	t.assert_true(runtime.main.current_screen.visible_card_rects().has(main_action.source_id), "resize cancellation snaps final authoritative deployed card")
	t.assert_eq(runtime.main.current_screen.get_tree().get_nodes_in_group("card_motion_proxy").size(), 0, "resize cancellation leaves no Main proxies")
	await _free_runtime(runtime)
	_cleanup("user://test-cancel-store.json")

	var replacement_controller := _real_action_controller("player")
	var replacement_action = _first_legal(replacement_controller, "player", "deploy_unit")
	var replacement := _main_runtime(replacement_controller, OnboardingStore.new("user://test-replacement-store.json"))
	replacement.main.current_screen.animation_speed_scale = 2.0
	replacement.main.submit_player_action(replacement_action)
	for _frame in range(30):
		await Engine.get_main_loop().process_frame
		if not replacement.main.current_screen.get_tree().get_nodes_in_group("card_motion_proxy").is_empty(): break
	replacement.main.show_screen("match", {
		"snapshot": replacement_controller.state.snapshot_for("player"),
		"events": [],
		"onboarding": replacement.main.onboarding_store.load(),
	})
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	t.assert_true(not replacement.main._match_submission_active and not replacement.main.current_screen._input_locked, "screen replacement cancels queue and clears locks")
	t.assert_eq(replacement.main.current_screen.snapshot.get("sequence"), replacement_controller.state.sequence, "replacement renders final authoritative snapshot")
	t.assert_true(replacement.main.current_screen.visible_card_rects().has(replacement_action.source_id), "replacement snapshot contains accepted deployed card")
	t.assert_eq(replacement.main.current_screen.get_tree().get_nodes_in_group("card_motion_proxy").size(), 0, "screen replacement leaves no proxies")
	await _free_runtime(replacement)
	_cleanup("user://test-replacement-store.json")

	var combat := _real_combat_controller()
	combat.state.players.opponent.support_line[0].current_defense = 99
	var attack = _first_legal(combat, "player", "attack_unit")
	var attack_before: Dictionary = combat.state.snapshot_for("player")
	var attack_view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(attack_view)
	attack_view.render_snapshot(attack_before)
	await attack_view.get_tree().process_frame
	var target = attack_view.card_view(attack.target_ids[0])
	var baseline: Color = target.modulate
	var attack_result = combat.submit_action(attack)
	var attack_after: Dictionary = combat.state.snapshot_for("player")
	attack_view.animation_speed_scale = 2.0
	var attack_probe := MotionProbe.new()
	attack_probe.call_deferred("run_view", attack_view, attack_result.events, attack_before, attack_after)
	for _frame in range(30):
		await Engine.get_main_loop().process_frame
		if bool(target.get_meta("motion_flash_active", false)): break
	attack_view.cancel_motion(attack_after)
	await Engine.get_main_loop().process_frame
	t.assert_true(attack_probe.completed, "attack cancellation resolves await")
	t.assert_true(not bool(target.get_meta("motion_flash_active", false)) and target.modulate == baseline, "attack cancellation restores target flash baseline")
	attack_view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_real_move_draw_attack_destroy_and_commands(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	Engine.get_main_loop().root.size = Vector2i(1280, 720)
	var director = CardMotionDirector.new()
	director.speed_scale = 0.25

	var move_controller := _real_action_controller("player")
	var moving = move_controller.state.players.player.hand.pop_front()
	moving.zone = "support_line"
	moving.slot = 0
	moving.deployed_turn = move_controller.state.turn - 1
	move_controller.state.players.player.support_line[0] = moving
	var move = _first_legal(move_controller, "player", "move_unit")
	var move_before: Dictionary = move_controller.state.snapshot_for("player")
	view.render_snapshot(move_before)
	await view.get_tree().process_frame
	var move_identity = view.card_view(moving.instance_id)
	var move_result = move_controller.submit_action(move)
	var move_after: Dictionary = move_controller.state.snapshot_for("player")
	director.speed_scale = 5.0
	var move_probe := MotionProbe.new()
	move_probe.call_deferred("run_director", director, move_result.events, move_before, move_after, view)
	var move_source := (view.snapshot_card_rects(move_before)[moving.instance_id] as Rect2).get_center()
	var move_destination := (view.snapshot_card_rects(move_after)[moving.instance_id] as Rect2).get_center()
	var move_crossed_midpoint := false
	for _frame in range(240):
		await Engine.get_main_loop().process_frame
		var move_proxies := view.get_tree().get_nodes_in_group("card_motion_proxy")
		if director.current_event_type == "unit_moved" and not move_proxies.is_empty():
			var center := (move_proxies[0] as Control).get_global_rect().get_center()
			if center.distance_to(move_source) > 1.0 and center.distance_to(move_destination) > 1.0:
				move_crossed_midpoint = true
		elif move_crossed_midpoint:
			break
	t.assert_true(move_crossed_midpoint, "real move crosses an in-flight point between Support and Frontline")
	while not move_probe.completed: await Engine.get_main_loop().process_frame
	view.render_snapshot(move_after)
	await view.get_tree().process_frame
	t.assert_true(view.card_view(moving.instance_id) == move_identity, "move reparents the same CardView identity")
	t.assert_eq(view.visible_card_rects()[moving.instance_id], view.snapshot_card_rects(move_after)[moving.instance_id], "move ends at authoritative Frontline rect")

	var draw_controller := _real_action_controller("player")
	var player_end = _first_legal(draw_controller, "player", "end_turn")
	draw_controller.submit_action(player_end)
	var draw_before: Dictionary = draw_controller.state.snapshot_for("player")
	var opponent_end = _first_legal(draw_controller, "opponent", "end_turn")
	var draw_result = draw_controller.submit_action(opponent_end)
	var draw_after: Dictionary = draw_controller.state.snapshot_for("player")
	view.render_snapshot(draw_before)
	await view.get_tree().process_frame
	director.speed_scale = 5.0
	var draw_probe := MotionProbe.new()
	draw_probe.call_deferred("run_director", director, draw_result.events, draw_before, draw_after, view)
	for _frame in range(240):
		await Engine.get_main_loop().process_frame
		if director.current_event_type == "card_drawn" and not view.get_tree().get_nodes_in_group("card_motion_proxy").is_empty(): break
	var draw_proxies := view.get_tree().get_nodes_in_group("card_motion_proxy")
	var draw_source: Vector2 = view.deck_edge_rect("player").position
	var drawn_id := str(draw_result.events.filter(func(event) -> bool: return str(event.get("type", "")) == "card_drawn")[-1].get("instance_id", ""))
	var draw_destination: Vector2 = (view.snapshot_card_rects(draw_after).get(drawn_id, Rect2()) as Rect2).position
	var initial_draw_distance: float = (draw_proxies[0] as Control).global_position.distance_to(draw_source) if not draw_proxies.is_empty() else INF
	t.assert_true(not draw_proxies.is_empty() and initial_draw_distance < draw_source.distance_to(draw_destination) * 0.35, "draw proxy begins on deck-edge side of its route")
	await Engine.get_main_loop().create_timer(0.08).timeout
	draw_proxies = view.get_tree().get_nodes_in_group("card_motion_proxy")
	t.assert_true(not draw_proxies.is_empty() and (draw_proxies[0] as Control).global_position.distance_to(draw_source) > initial_draw_distance + 1.0, "draw proxy travels toward new hand position")
	while not draw_probe.completed: await Engine.get_main_loop().process_frame
	t.assert_true("card_drawn" in director.processed_event_types, "real turn transition emits animated draw")
	t.assert_eq(director.last_source_rect, view.deck_edge_rect("player"), "draw originates at player deck/hand edge")
	t.assert_true(director.last_destination_rect != director.last_source_rect, "draw destination is the new hand position")

	var combat := _real_combat_controller()
	var attack = _first_legal(combat, "player", "attack_unit")
	t.assert_true(attack != null, "real combat fixture exposes unit attack")
	if attack != null:
		var attack_before: Dictionary = combat.state.snapshot_for("player")
		view.render_snapshot(attack_before)
		await view.get_tree().process_frame
		var target_id: String = attack.target_ids[0]
		var attacker_start: Vector2 = (view.snapshot_card_rects(attack_before)[attack.source_id] as Rect2).position
		var attack_result = combat.submit_action(attack)
		var attack_after: Dictionary = combat.state.snapshot_for("player")
		director.speed_scale = 1.0
		var probe := MotionProbe.new()
		probe.call_deferred("run_director", director, attack_result.events, attack_before, attack_after, view)
		for _frame in range(120):
			await Engine.get_main_loop().process_frame
			if director.current_event_type == "attack_started" and not view.get_tree().get_nodes_in_group("card_motion_proxy").is_empty(): break
		var attack_proxies := view.get_tree().get_nodes_in_group("card_motion_proxy")
		t.assert_true(bool(view.card_view(target_id).get_meta("motion_flash_active", false)), "real attack flashes target during lunge")
		var farthest := 0.0
		var returned := false
		for _sample in range(240):
			await Engine.get_main_loop().process_frame
			attack_proxies = view.get_tree().get_nodes_in_group("card_motion_proxy")
			if director.current_event_type != "attack_started" or attack_proxies.is_empty(): break
			var distance := (attack_proxies[0] as Control).global_position.distance_to(attacker_start)
			if farthest > 10.0 and distance < farthest - 1.0:
				returned = true
				break
			farthest = maxf(farthest, distance)
		t.assert_true(farthest > 1.0, "attack proxy lunges toward real target")
		t.assert_true(returned, "attack proxy reverses and returns toward attacker rect")
		for _frame in range(240):
			await Engine.get_main_loop().process_frame
			if director.current_event_type == "card_destroyed": break
		await Engine.get_main_loop().create_timer(0.12).timeout
		var destroy_proxies := view.get_tree().get_nodes_in_group("card_motion_proxy")
		t.assert_true(not destroy_proxies.is_empty() and (destroy_proxies[0] as Control).scale.x < 0.98 and (destroy_proxies[0] as Control).modulate.a < 0.8, "destroy proxy visibly shrinks and fades in flight")
		while not probe.completed: await Engine.get_main_loop().process_frame
		t.assert_eq(view.visible_card_rects()[attack.source_id], view.snapshot_card_rects(attack_before)[attack.source_id], "attack completion leaves attacker at authoritative source rect")
		t.assert_true("card_destroyed" in director.processed_event_types, "lethal real attack animates destruction payload")
		t.assert_true(not bool(view.card_view(target_id).get_meta("motion_flash_active", false)), "attack target flash returns to baseline")

	var commands := _real_command_controller()
	for action_type in ["toggle_countermeasure", "play_order"]:
		var command = _first_legal(commands, "player", action_type)
		t.assert_true(command != null, "real fixture exposes %s" % action_type)
		if command != null:
			var command_before: Dictionary = commands.state.snapshot_for("player")
			view.render_snapshot(command_before)
			await view.get_tree().process_frame
			var command_result = commands.submit_action(command)
			var command_after: Dictionary = commands.state.snapshot_for("player")
			director.speed_scale = 1.0
			var command_probe := MotionProbe.new()
			command_probe.call_deferred("run_director", director, command_result.events, command_before, command_after, view)
			for _frame in range(120):
				await Engine.get_main_loop().process_frame
				if director.current_event_type in ["order_played", "countermeasure_activated", "countermeasure_deactivated"] and not view.get_tree().get_nodes_in_group("card_motion_proxy").is_empty(): break
			var command_proxies := view.get_tree().get_nodes_in_group("card_motion_proxy")
			var command_source := (view.snapshot_card_rects(command_before)[command.source_id] as Rect2).position
			await Engine.get_main_loop().create_timer(0.14).timeout
			command_proxies = view.get_tree().get_nodes_in_group("card_motion_proxy")
			t.assert_true(not command_proxies.is_empty() and (command_proxies[0] as Control).global_position.distance_to(view.command_area_rect().position) < command_source.distance_to(view.command_area_rect().position), "%s proxy travels toward command area" % action_type)
			while not command_probe.completed: await Engine.get_main_loop().process_frame
	view.queue_free()
	await Engine.get_main_loop().process_frame
static func _test_lock_blocks_animation_and_keyboard_selection(t) -> void:
	var view = MatchViewScene.instantiate()
	Engine.get_main_loop().root.add_child(view)
	view.render_snapshot(_snapshot())
	view.model.select_source("one-cost")
	view.set_input_locked(true)
	t.assert_true(not view.get_node("%SettingsButton").disabled, "settings stays available while match input is locked")
	t.assert_true(not view.get_node("%EndTurnButton").visible, "locked End Turn is hidden instead of shown disabled")
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	view._unhandled_key_input(event)
	t.assert_eq(view.model.selected_source_id, "one-cost", "locked keyboard input cannot change selection")
	view.queue_free()
	await Engine.get_main_loop().process_frame


static func _test_animation_preference_reload(t) -> void:
	var path := "user://test-match-preferences.cfg"
	_cleanup(path)
	var first := Main.new()
	first.animation_preferences_path = path
	first.set_animation_mode("reduced")
	var second := Main.new()
	second.animation_preferences_path = path
	second._load_animation_mode()
	t.assert_eq(second.animation_mode, "reduced", "animation preference reloads from adjacent config")
	first.free()
	second.free()
	_cleanup(path)


static func _test_real_main_milestone_submissions(t) -> void:
	var path := "user://test-onboarding-main-actions.json"
	_cleanup(path)
	var store = OnboardingStore.new(path)

	var deploy_controller := _real_action_controller("player")
	var deploy_action = _first_legal(deploy_controller, "player", "deploy_unit")
	t.assert_true(deploy_action != null, "real controller exposes accepted deploy candidate")
	var deploy_runtime := await _submit_through_main(deploy_controller, deploy_action, store)
	t.assert_true(deploy_runtime.controller.state.players.player.support_line.any(func(card) -> bool: return card != null), "Main submits deploy through real controller")
	t.assert_true(store.load().deployed_unit, "accepted Main deploy records milestone")
	await _free_runtime(deploy_runtime)

	var move_controller := _real_action_controller("player")
	var moving = move_controller.state.players.player.hand.pop_front()
	moving.zone = "support_line"
	moving.slot = 0
	moving.deployed_turn = move_controller.state.turn - 1
	moving.operations_used = 0
	move_controller.state.players.player.support_line[0] = moving
	var move_action = _first_legal(move_controller, "player", "move_unit")
	t.assert_true(move_action != null, "real controller exposes accepted Frontline move candidate")
	if move_action != null:
		var move_runtime := await _submit_through_main(move_controller, move_action, store)
		t.assert_true(store.load().moved_to_frontline, "accepted Main Frontline move records milestone")
		await _free_runtime(move_runtime)

	var attack_controller := _real_action_controller("player")
	var attacker = attack_controller.state.players.player.hand.pop_front()
	attacker.zone = "frontline"
	attacker.slot = 0
	attacker.deployed_turn = attack_controller.state.turn - 1
	attacker.operations_used = 0
	attack_controller.state.frontline[0] = attacker
	attack_controller.state.frontline_controller_id = "player"
	var attack_action = _first_legal(attack_controller, "player", "attack_hq")
	t.assert_true(attack_action != null, "real controller exposes accepted HQ attack candidate")
	if attack_action != null:
		var attack_runtime := await _submit_through_main(attack_controller, attack_action, store)
		t.assert_true(store.load().completed_attack, "accepted Main attack records milestone")
		await _free_runtime(attack_runtime)

	var rejected_path := "user://test-onboarding-main-rejected.json"
	_cleanup(rejected_path)
	var rejected_store = OnboardingStore.new(rejected_path)
	var rejected_controller := _real_action_controller("player")
	var stale = _first_legal(rejected_controller, "player", "deploy_unit")
	stale.expected_sequence += 99
	var rejected_runtime := await _submit_through_main(rejected_controller, stale, rejected_store)
	t.assert_eq(rejected_store.load(), OnboardingStore.defaults(), "rejected player submission records no milestone")
	t.assert_eq(rejected_runtime.main.current_screen.get_node("%CoachObjective").text, "State changed", "rejection survives Main snapshot/legal/unlock refresh ordering")
	var fresh_deploy = _first_legal(rejected_controller, "player", "deploy_unit")
	rejected_runtime.main.submit_player_action(fresh_deploy)
	for _frame in range(12):
		await Engine.get_main_loop().process_frame
		if not rejected_runtime.main._match_submission_active:
			break
	t.assert_true(rejected_runtime.main.current_screen.get_node("%CoachObjective").text != "State changed", "accepted state advance clears orchestrated rejection")
	await _free_runtime(rejected_runtime)

	var ai_path := "user://test-onboarding-main-ai.json"
	_cleanup(ai_path)
	var ai_store = OnboardingStore.new(ai_path)
	var ai_controller := _real_action_controller("opponent")
	var ai_runtime := _main_runtime(ai_controller, ai_store)
	ai_runtime.main.ai = AIPlayer.create("easy", 811)
	ai_runtime.main._match_generation = 1
	await ai_runtime.main._drive_ai_turn(1)
	t.assert_eq(ai_store.load(), OnboardingStore.defaults(), "accepted AI actions record no player milestones")
	await _free_runtime(ai_runtime)

	var reloaded = OnboardingStore.new(path)
	t.assert_true(reloaded.load().deployed_unit and reloaded.load().moved_to_frontline and reloaded.load().completed_attack, "all accepted milestones survive store reload")
	var rematch_controller := _real_action_controller("player")
	var rematch_runtime := _main_runtime(rematch_controller, reloaded)
	rematch_runtime.main.catalog = ContentCatalog.load_from_paths("res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json")
	rematch_runtime.main.selected_player_deck = rematch_runtime.main.catalog.decks_by_id["us-starter"].duplicate(true)
	rematch_runtime.main.difficulty = "easy"
	rematch_runtime.main._on_rematch_requested()
	t.assert_true(reloaded.load().deployed_unit and reloaded.load().moved_to_frontline and reloaded.load().completed_attack, "real rematch initialization preserves onboarding milestones")
	await _free_runtime(rematch_runtime)
	_cleanup(path)
	_cleanup(rejected_path)
	_cleanup(ai_path)


static func _test_coach_priority_and_exact_copy(t) -> void:
	var snapshot := _snapshot()
	var deploy := _action("deploy_unit", "one-cost", [], {"support_slot": 0})
	var move := _action("move_unit", "support-unit", [], {"zone": "frontline", "slot": 0})
	var attack := _action("attack_unit", "front-unit", ["enemy-unit"])
	var order := _action("play_order", "order", ["enemy-unit"])
	var counter := _action("toggle_countermeasure", "counter")
	var ability := _action("activate_ability", "ability-unit")
	var end := _action("end_turn")

	_assert_coach(t, snapshot.merged({"active_player_id": "opponent"}, true), [deploy, end], {},
		LocaleScript.ui("coach.opponent"), ["one-cost"], "opponent_turn")
	_assert_coach(t, snapshot, [deploy, move, attack, order, counter, end], {"selected_source_id": "one-cost"},
		LocaleScript.ui("coach.support_slot"), ["counter", "front-unit", "one-cost", "order", "support-unit"], "support_slot")
	_assert_coach(t, snapshot, [move, attack, end], {"selected_source_id": "support-unit", "selected_zone": "frontline"},
		LocaleScript.ui("coach.frontline_slot"), ["front-unit", "support-unit"], "frontline_slot")
	_assert_coach(t, snapshot, [order, end], {"selected_source_id": "order"},
		LocaleScript.ui("coach.target"), ["order"], "target")
	var compound_order := _action("play_order", "order", ["enemy-unit", "enemy-hq"])
	_assert_coach(t, snapshot, [compound_order, end], {"selected_source_id": "order", "selected_targets": ["enemy-unit"]},
		LocaleScript.ui("coach.target"), ["order"], "target")
	_assert_coach(t, snapshot, [deploy, move, attack, order, counter, end], {},
		LocaleScript.ui("coach.deploy"), ["counter", "front-unit", "one-cost", "order", "support-unit"], "deploy")
	_assert_coach(t, snapshot, [move, attack, order, counter, end], {},
		LocaleScript.ui("coach.move"), ["counter", "front-unit", "order", "support-unit"], "move")
	_assert_coach(t, snapshot, [attack, order, counter, end], {},
		LocaleScript.ui("coach.attack"), ["counter", "front-unit", "order"], "attack")
	_assert_coach(t, snapshot, [order, counter, end], {},
		LocaleScript.ui("coach.order"), ["counter", "order"], "order")
	_assert_coach(t, snapshot, [counter, end], {},
		LocaleScript.ui("coach.countermeasure"), ["counter"], "countermeasure")
	_assert_coach(t, snapshot, [ability, end], {},
		LocaleScript.ui("coach.ability"), ["ability-unit"], "ability")
	_assert_coach(t, snapshot, [end], {},
		LocaleScript.ui("coach.end_turn"), [], "end_turn")
	_assert_coach(t, snapshot, [], {}, LocaleScript.ui("coach.none"), [], "none")


static func _test_milestone_objective_progression(t) -> void:
	var snapshot := _snapshot()
	var actions := [
		_action("deploy_unit", "one-cost", [], {"support_slot": 0}),
		_action("move_unit", "support-unit", [], {"zone": "frontline", "slot": 0}),
		_action("attack_unit", "front-unit", ["enemy-unit"]),
		_action("end_turn"),
	]
	var onboarding := OnboardingStore.defaults()
	var expected_sources := ["front-unit", "one-cost", "support-unit"]
	var result := MatchCoachModel.derive(snapshot, actions, {}, onboarding)
	var expected_reasons: Dictionary = result.source_reasons.duplicate(true)
	t.assert_eq(result.next_kind, "deploy", "first incomplete milestone teaches deploy")
	t.assert_eq(result.legal_source_ids, expected_sources, "deploy teaching keeps every legal source")
	t.assert_true(not result.end_turn_only, "combined legal fixture is never End-Turn-only")
	onboarding.deployed_unit = true
	result = MatchCoachModel.derive(snapshot, actions, {}, onboarding)
	t.assert_eq(result.next_kind, "move", "completed deploy advances objective to move")
	t.assert_eq(result.legal_source_ids, expected_sources, "move teaching keeps every legal source")
	t.assert_eq(result.source_reasons, expected_reasons, "move teaching keeps complete-list source reasons")
	t.assert_true(not result.end_turn_only, "move teaching keeps complete-list End Turn semantics")
	onboarding.moved_to_frontline = true
	result = MatchCoachModel.derive(snapshot, actions, {}, onboarding)
	t.assert_eq(result.next_kind, "attack", "completed move advances objective to attack")
	t.assert_eq(result.legal_source_ids, expected_sources, "attack teaching keeps every legal source")
	t.assert_eq(result.source_reasons, expected_reasons, "attack teaching keeps complete-list source reasons")
	t.assert_true(not result.end_turn_only, "attack teaching keeps complete-list End Turn semantics")
	onboarding.completed_attack = true
	result = MatchCoachModel.derive(snapshot, actions, {}, onboarding)
	t.assert_eq(result.next_kind, "deploy", "completed milestones fall back to truthful normal priority")
	t.assert_eq(result.objective, LocaleScript.ui("coach.deploy"), "fallback objective describes an available action")
	t.assert_eq(result.legal_source_ids, expected_sources, "fallback keeps every legal source")
	t.assert_eq(result.source_reasons, expected_reasons, "fallback keeps complete-list source reasons")
	t.assert_true(not result.end_turn_only, "fallback keeps complete-list End Turn semantics")


static func _test_real_first_turn_credit_fixture(t) -> void:
	var fixture: Dictionary = CoreCards.build_valid_fixture()
	var controller: MatchController = MatchController.create(fixture.definitions, fixture.player_deck, fixture.enemy_deck, 301)
	for action in [_action("start_match", "", [], {}, "system"), _action("mulligan"), _action("mulligan", "", [], {}, "opponent"), _action("confirm_mulligan"), _action("confirm_mulligan", "", [], {}, "opponent")]:
		controller.submit_action(action)
	if controller.state.active_player_id != "player":
		controller.submit_action(_action("end_turn", "", [], {}, "opponent"))
	var active_id: String = controller.state.active_player_id
	var active = controller.state.players[active_id]
	t.assert_eq(active.credit, 1, "real first turn starts with 1 Credit")
	active.hand[0].deployment_cost = 1
	active.hand[1].deployment_cost = 3
	var public_snapshot: Dictionary = controller.state.snapshot_for(active_id)
	var actions: Array[GameAction] = controller.legal_actions(active_id)
	var result := MatchCoachModel.derive(public_snapshot, actions, {}, {})
	t.assert_true(result.legal_source_ids.has(active.hand[0].instance_id), "one-Credit unit is a legal source")
	t.assert_true(not result.legal_source_ids.has(active.hand[1].instance_id), "three-Credit unit is not a legal source")
	t.assert_eq(result.objective, LocaleScript.ui("coach.deploy"), "real first-turn fixture uses exact deploy copy")


static func _test_real_active_countermeasure_is_legal(t) -> void:
	var fixture: Dictionary = CoreCards.build_valid_fixture()
	var controller: MatchController = MatchController.create(fixture.definitions, fixture.player_deck, fixture.enemy_deck, 317)
	_start_player_turn(controller)
	var player = controller.state.players.player
	player.credit = 0
	var counter = player.hand[0]
	counter.category = "Countermeasure"
	counter.deployment_cost = 0
	counter.countermeasure_active = true
	controller.card_definitions[counter.definition_id]["category"] = "Countermeasure"
	controller.card_definitions[counter.definition_id]["deployment_cost"] = 0
	controller._definitions[counter.definition_id]["category"] = "Countermeasure"
	controller._definitions[counter.definition_id]["deployment_cost"] = 0
	player.active_countermeasures.append(counter)
	var legal_actions: Array[GameAction] = controller.legal_actions("player")
	var toggle_actions := legal_actions.filter(func(action: GameAction) -> bool:
		return action.type == "toggle_countermeasure" and action.source_id == counter.instance_id
	)
	var result := MatchCoachModel.derive(controller.state.snapshot_for("player"), legal_actions, {}, {})
	t.assert_eq(toggle_actions.size(), 1, "real active Countermeasure retains its legal deactivation toggle")
	t.assert_true(result.legal_source_ids.has(counter.instance_id), "active Countermeasure remains a legal coach source")
	t.assert_true(not result.source_reasons.has(counter.instance_id), "legal active Countermeasure is never unavailable")
	t.assert_eq(result.objective, LocaleScript.ui("coach.countermeasure"), "active Countermeasure objective names both toggle directions")


static func _test_source_reasons(t) -> void:
	var snapshot := _snapshot()
	var result := MatchCoachModel.derive(snapshot, [_action("end_turn")], {}, {})
	t.assert_eq(result.source_reasons.get("three-cost"), LocaleScript.ui("reason.credit"), "unaffordable card explains Credit")
	t.assert_eq(result.source_reasons.get("targetless-order"), LocaleScript.ui("reason.no_target"), "targetless Order explains target")
	t.assert_eq(result.source_reasons.get("active-counter"), LocaleScript.ui("reason.active"), "active Countermeasure explains state")
	t.assert_eq(result.source_reasons.get("unknown"), LocaleScript.ui("reason.none"), "unknown category has safe fallback")

	var full := snapshot.duplicate(true)
	full.players.player.support_line = [_card("s0", "Unit", 0), _card("s1", "Unit", 0), _card("s2", "Unit", 0), _card("s3", "Unit", 0)]
	result = MatchCoachModel.derive(full, [_action("end_turn")], {}, {})
	t.assert_eq(result.source_reasons.get("one-cost"), LocaleScript.ui("reason.support_full"), "deployable Unit explains full Support Line")

	var opponent_turn := snapshot.merged({"active_player_id": "opponent"}, true)
	result = MatchCoachModel.derive(opponent_turn, [], {}, {})
	for source_id in ["one-cost", "three-cost", "targetless-order", "active-counter", "unknown"]:
		t.assert_eq(result.source_reasons.get(source_id), LocaleScript.ui("reason.wait"), "opponent turn reason overrides card details")


static func _test_end_turn_requires_the_sole_complete_action(t) -> void:
	var snapshot := _snapshot()
	var sole := MatchCoachModel.derive(snapshot, [_action("end_turn")], {}, {})
	t.assert_true(sole.end_turn_only, "one End Turn action is sole-action guidance")
	var duplicate := MatchCoachModel.derive(snapshot, [_action("end_turn"), _action("end_turn")], {}, {})
	t.assert_true(not duplicate.end_turn_only, "duplicate End Turn candidates are not a sole complete action list")
	var mixed := MatchCoachModel.derive(snapshot, [_action("end_turn"), _action("activate_ability", "support-unit")], {}, {})
	t.assert_true(not mixed.end_turn_only, "any additional legal action disables sole-End-Turn semantics")


static func _test_persistence(t) -> void:
	var path := "user://test-onboarding.json"
	_cleanup(path)
	var store = OnboardingStore.new(path)
	var defaults: Dictionary = store.load()
	t.assert_eq(defaults, {
		"deck_hint_dismissed": false,
		"how_to_play_seen": false,
		"deployed_unit": false,
		"moved_to_frontline": false,
		"completed_attack": false,
	}, "missing persistence uses safe defaults")
	t.assert_true(store.dismiss_deck_hint(), "dismissal persists atomically")
	for milestone in ["deployed_unit", "moved_to_frontline", "completed_attack"]:
		t.assert_true(store.complete(milestone), "%s persists atomically" % milestone)
	t.assert_true(not FileAccess.file_exists(path + ".tmp"), "atomic save leaves no temporary file")
	t.assert_eq(OnboardingStore.new(path).load(), {
		"deck_hint_dismissed": true,
		"how_to_play_seen": false,
		"deployed_unit": true,
		"moved_to_frontline": true,
		"completed_attack": true,
	}, "saved onboarding reloads")
	t.assert_true(not store.complete("not_a_milestone"), "unknown milestones are rejected")

	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	t.assert_eq(OnboardingStore.new(path).load(), OnboardingStore.defaults(), "corrupt JSON falls back safely")

	var unwritable = OnboardingStore.new("user://missing-parent/test-onboarding.json")
	_cleanup("user://missing-parent/test-onboarding.json")
	_cleanup_dir("user://missing-parent")
	unwritable.load()
	t.assert_true(not unwritable.complete("deployed_unit"), "unwritable path reports failure")
	t.assert_true(unwritable.load().deployed_unit, "failed persistence preserves in-memory milestone")
	_cleanup(path)


static func _test_persistence_rejects_non_user_paths(t) -> void:
	var invalid_paths := [
		"res://onboarding-invalid.json",
		"/tmp/opencards-onboarding-invalid.json",
		"user://../opencards-onboarding-invalid.json",
		"user://nested/../../opencards-onboarding-invalid.json",
	]
	for path in invalid_paths:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
		var store = OnboardingStore.new(path)
		t.assert_eq(store.load(), OnboardingStore.defaults(), "%s reads safe defaults" % path)
		t.assert_true(not store.complete("deployed_unit"), "%s rejects persistence" % path)
		t.assert_true(store.load().deployed_unit, "%s preserves failed write in memory" % path)
		t.assert_true(not FileAccess.file_exists(absolute), "%s cannot create a file" % path)


static func _assert_coach(t, snapshot: Dictionary, actions: Array, selection: Dictionary, objective: String, sources: Array, next_kind: String) -> void:
	var result := MatchCoachModel.derive(snapshot, actions, selection, {})
	t.assert_eq(result.objective, objective, "%s objective copy" % next_kind)
	t.assert_eq(result.legal_source_ids, sources, "%s legal source IDs" % next_kind)
	t.assert_eq(result.next_kind, next_kind, "%s next kind" % next_kind)


static func _snapshot() -> Dictionary:
	return {
		"phase": "action",
		"active_player_id": "player",
		"players": {
			"player": {
				"credit": 1,
				"support_line": [null, null, null, null],
				"hand": [
					_card("one-cost", "Unit", 1),
					_card("three-cost", "Unit", 3),
					_card("targetless-order", "Order", 1),
					_card("active-counter", "Countermeasure", 0, true),
					_card("unknown", "Mystery", 0),
				],
			},
			"opponent": {"credit": 1, "support_line": [null, null, null, null], "hand": []},
		},
		"frontline": [null, null, null, null, null],
	}


static func _populated_grid_snapshot() -> Dictionary:
	var value := _snapshot()
	value.players.player["headquarters"] = _card("player-hq", "Headquarters", 0)
	value.players.opponent["headquarters"] = _card("opponent-hq", "Headquarters", 0)
	value.players.opponent.hand = [{"hidden": true}]
	value.players.opponent.support_line = [
		_card("enemy-support-0", "Unit", 1), _card("enemy-support-1", "Unit", 1),
		_card("enemy-support-2", "Unit", 1), _card("enemy-support-3", "Unit", 1),
	]
	value.players.player.support_line = [
		_card("shared-unit", "Unit", 1), _card("player-support-1", "Unit", 1),
		_card("player-support-2", "Unit", 1), _card("player-support-3", "Unit", 1),
	]
	value.frontline = [
		_card("front-0", "Unit", 1), _card("front-1", "Unit", 1), _card("front-2", "Unit", 1),
		_card("front-3", "Unit", 1), _card("front-4", "Unit", 1),
	]
	return value


static func _card(instance_id: String, category: String, cost: int, active: bool = false) -> Dictionary:
	return {"instance_id": instance_id, "category": category, "deployment_cost": cost, "countermeasure_active": active, "zone": "hand"}


static func _action(type: String, source_id: String = "", targets: Array[String] = [], payload: Dictionary = {}, actor_id: String = "player") -> GameAction:
	return GameAction.create(type, actor_id, source_id, targets, payload)


static func _start_player_turn(controller: MatchController) -> void:
	for action in [_action("start_match", "", [], {}, "system"), _action("mulligan"), _action("mulligan", "", [], {}, "opponent"), _action("confirm_mulligan"), _action("confirm_mulligan", "", [], {}, "opponent")]:
		controller.submit_action(action)
	if controller.state.active_player_id != "player":
		controller.submit_action(_action("end_turn", "", [], {}, "opponent"))


static func _real_action_controller(active_player_id: String) -> MatchController:
	var fixture: Dictionary = CoreCards.build_valid_fixture()
	var controller: MatchController = MatchController.create(fixture.definitions, fixture.player_deck, fixture.enemy_deck, 809)
	_start_player_turn(controller)
	if active_player_id == "opponent":
		var end_action = _first_legal(controller, "player", "end_turn")
		controller.submit_action(end_action)
	return controller


static func _real_combat_controller() -> MatchController:
	var controller := _real_action_controller("player")
	var attacker = controller.state.players.player.hand.pop_front()
	var defender = controller.state.players.opponent.hand.pop_front()
	attacker.zone = "frontline"
	attacker.slot = 0
	attacker.deployed_turn = controller.state.turn - 1
	attacker.operations_used = 0
	attacker.current_attack = 20
	defender.zone = "support_line"
	defender.slot = 0
	defender.current_defense = 1
	controller.state.frontline[0] = attacker
	controller.state.players.opponent.support_line[0] = defender
	controller.state.frontline_controller_id = "player"
	controller.state.players.player.credit = 10
	return controller


static func _real_command_controller() -> MatchController:
	var definitions := {
		"player-hq": CoreCards._gameplay_definition("player-hq", "Headquarters"),
		"opponent-hq": CoreCards._gameplay_definition("opponent-hq", "Headquarters"),
		"unit": CoreCards._gameplay_definition("unit", "Unit", 2, 3),
		"order": CoreCards._gameplay_definition("order", "Order"),
		"counter": CoreCards._gameplay_definition("counter", "Countermeasure"),
	}
	var player_deck: Array[String] = []
	var opponent_deck: Array[String] = []
	for index in range(19):
		player_deck.append("order")
		player_deck.append("counter")
		opponent_deck.append("unit")
		opponent_deck.append("unit")
	player_deck.append("unit")
	player_deck.append("player-hq")
	opponent_deck.append("unit")
	opponent_deck.append("opponent-hq")
	var controller := MatchController.create(definitions, player_deck, opponent_deck, 818)
	_start_player_turn(controller)
	for category in ["Order", "Countermeasure"]:
		if not controller.state.players.player.hand.any(func(card) -> bool: return card.category == category):
			for card in controller.state.players.player.deck:
				if card.category == category:
					controller.state.players.player.deck.erase(card)
					card.zone = "hand"
					controller.state.players.player.hand.append(card)
					break
	controller.state.players.player.credit = 10
	return controller


static func _first_legal(controller: MatchController, actor_id: String, action_type: String):
	for action in controller.legal_actions(actor_id):
		if action.type == action_type:
			return action
	return null


static func _main_runtime(controller: MatchController, store) -> Dictionary:
	var main := Main.new()
	var host := Control.new()
	Engine.get_main_loop().root.add_child(host)
	var view = MatchViewScene.instantiate()
	host.add_child(view)
	main.screen_host = host
	main.current_screen = view
	main.controller = controller
	main.ai = null
	main.onboarding_store = store
	view.render_snapshot(controller.state.snapshot_for("player"))
	view.set_legal_actions(controller.legal_actions("player"))
	view.set_onboarding_state(store.load())
	return {"main": main, "host": host, "controller": controller}


static func _submit_through_main(controller: MatchController, action, store) -> Dictionary:
	var runtime := _main_runtime(controller, store)
	runtime.main.submit_player_action(action)
	for _frame in range(12):
		await Engine.get_main_loop().process_frame
		if not runtime.main._match_submission_active:
			break
	return runtime


static func _free_runtime(runtime: Dictionary) -> void:
	var main = runtime.main
	var host = runtime.host
	main.free()
	host.queue_free()
	await Engine.get_main_loop().process_frame


static func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))


static func _cleanup_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)
