class_name MatchView
extends Control

signal action_requested(action: GameAction)

const ActionBuilderScript = preload("res://scripts/ui/action_builder.gd")
const CardViewScene = preload("res://scenes/ui/card_view.tscn")
const MatchCoachModelScript = preload("res://scripts/ui/match_coach_model.gd")
const CardMotionDirectorScript = preload("res://scripts/ui/card_motion_director.gd")
const LocaleScript = preload("res://scripts/ui/locale.gd")

var router: Main
var model := MatchInteractionModel.new()
var snapshot: Dictionary = {}
var _input_locked := false
var _onboarding_state: Dictionary = {}
var _coach_state: Dictionary = {}
var _rejection_message := ""
var animation_mode := "on"
var animation_speed_scale := 0.01 if DisplayServer.get_name() == "headless" else 1.0
var _motion_director = CardMotionDirectorScript.new()
var _card_registry: Dictionary = {}
var _coach_pulse: Tween
var _inspect_panel: PanelContainer
var _last_layout_size := Vector2.ZERO

signal how_to_play_requested

class MatchInteractionModel:
	var selected_source_id := ""
	var status_message := ""
	var rejection_code := ""
	var selected_targets: Array[String] = []
	var selected_zone := ""
	var selected_slot := -1
	var _legal_actions: Array = []
	func set_legal_actions(actions: Array) -> void:
		_legal_actions = actions.duplicate()
	func select_source(instance_id: String) -> void:
		selected_source_id = instance_id
		selected_targets.clear()
		selected_zone = ""
		selected_slot = -1
		status_message = ""
	func highlighted_targets() -> Array[String]:
		var result: Array[String] = []
		for action in _candidate_actions():
			if action.target_ids.size() > selected_targets.size():
				var target_id: String = action.target_ids[selected_targets.size()]
				if target_id not in result: result.append(target_id)
		result.sort()
		return result
	func highlighted_slots(zone: String) -> Array[int]:
		var result: Array[int] = []
		for action in _candidate_actions():
			var action_zone := "support" if action.type == "deploy_unit" else str(action.payload.get("zone", ""))
			var slot := int(action.payload.get("support_slot", action.payload.get("slot", -1)))
			if action_zone == zone and slot >= 0 and slot not in result: result.append(slot)
		result.sort()
		return result
	func choose_target(target_id: String):
		if target_id not in highlighted_targets(): return null
		selected_targets.append(target_id)
		return _take_immediate_if_complete()
	func choose_slot(zone: String, slot: int):
		if slot not in highlighted_slots(zone): return null
		selected_zone = zone
		selected_slot = slot
		return _take_immediate_if_complete()
	func immediate_action():
		for action in _candidate_actions():
			if action.type == "toggle_countermeasure":
				cancel()
				return action
		return null
	func confirm_action():
		if _has_unspecified_dimension(): return null
		var complete := _complete_actions()
		if complete.size() != 1: return null
		var action = complete[0]
		cancel()
		return action
	func can_confirm() -> bool:
		if selected_source_id.is_empty():
			return false
		return not _has_unspecified_dimension() and _complete_actions().size() == 1
	func _take_immediate_if_complete():
		if _has_unspecified_dimension(): return null
		var complete := _complete_actions()
		if complete.size() != 1: return null
		var action = complete[0]
		cancel()
		return action
	func _complete_actions() -> Array:
		return _candidate_actions().filter(func(action) -> bool:
			return action.target_ids.size() == selected_targets.size() and (not _requires_slot(action) or selected_slot >= 0)
		)
	func _candidate_actions() -> Array:
		return _source_actions().filter(func(action) -> bool:
			if selected_slot >= 0:
				var action_zone := _action_zone(action)
				var action_slot := _action_slot(action)
				if action_zone != selected_zone or action_slot != selected_slot: return false
			if selected_targets.size() > action.target_ids.size(): return false
			for index in range(selected_targets.size()):
				if action.target_ids[index] != selected_targets[index]: return false
			return true
		)
	func _requires_slot(action) -> bool:
		return action.type in ["deploy_unit", "move_unit"]
	func _has_unspecified_dimension() -> bool:
		if not highlighted_targets().is_empty(): return true
		if selected_slot < 0:
			for zone in ["support", "frontline"]:
				if not highlighted_slots(zone).is_empty(): return true
		return false
	func _action_zone(action) -> String:
		return "support" if action.type == "deploy_unit" else str(action.payload.get("zone", ""))
	func _action_slot(action) -> int:
		return int(action.payload.get("support_slot", action.payload.get("slot", -1)))
	func cancel() -> void:
		selected_source_id = ""
		selected_targets.clear()
		selected_zone = ""
		selected_slot = -1
	func apply_rejection(code: String, message: String) -> void:
		rejection_code = code
		status_message = message
	func _source_actions() -> Array:
		return _legal_actions.filter(func(action) -> bool: return action.source_id == selected_source_id)


func _ready() -> void:
	%OpponentHQ.bind_hq({}, "SovietUnion", 0)
	%PlayerHQ.bind_hq({}, "UnitedStates", 0)
	%OpponentHQ.card_pressed.connect(_on_board_card_pressed)
	%OpponentHQ.card_dropped.connect(_on_target_dropped)
	%OpponentSupport.card_pressed.connect(_on_board_card_pressed)
	%OpponentSupport.target_dropped.connect(_on_target_dropped)
	%Frontline.card_pressed.connect(_on_board_card_pressed)
	%Frontline.slot_pressed.connect(_on_slot_pressed)
	%Frontline.card_dropped.connect(_on_card_dropped)
	%Frontline.target_dropped.connect(_on_target_dropped)
	%PlayerHQ.card_pressed.connect(_on_board_card_pressed)
	%PlayerHQ.card_dropped.connect(_on_target_dropped)
	%PlayerSupport.card_pressed.connect(_on_board_card_pressed)
	%PlayerSupport.slot_pressed.connect(_on_slot_pressed)
	%PlayerSupport.card_dropped.connect(_on_card_dropped)
	%PlayerSupport.target_dropped.connect(_on_target_dropped)
	%CancelButton.pressed.connect(_on_cancel_pressed)
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%EndTurnButton.pressed.connect(_on_end_turn_pressed)
	%ConcedeButton.pressed.connect(_on_concede_pressed)
	%ConcedeDialog.confirmed.connect(_on_concede_confirmed)
	%AnimationButton.pressed.connect(_on_animation_pressed)
	resized.connect(_apply_responsive_layout)
	tree_exiting.connect(cancel_motion)
	_install_lane_chrome()
	_install_help_button()
	_style_coach()
	_bind_chrome()
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var compact := size.x <= 1000.0
	var size_changed := not size.is_equal_approx(_last_layout_size)
	_last_layout_size = size
	%TimelinePanel.custom_minimum_size.x = 120.0 if compact else 148.0
	%HandScroll.custom_minimum_size.y = 158.0 if compact else 178.0
	var row_height := 112.0 if compact else 118.0
	for path in ["Margin/Columns/Board/OpponentArea", "Margin/Columns/Board/Frontline", "Margin/Columns/Board/PlayerArea"]:
		(get_node(path) as Control).custom_minimum_size.y = row_height
	var margin := get_node("Margin") as MarginContainer
	margin.offset_left = 6.0 if compact else 8.0
	margin.offset_right = -6.0 if compact else -8.0
	%CancelButton.custom_minimum_size.x = 56.0 if compact else 72.0
	%ConfirmButton.custom_minimum_size.x = 64.0 if compact else 82.0
	%EndTurnButton.custom_minimum_size.x = 76.0 if compact else 90.0
	%ConcedeButton.custom_minimum_size.x = 64.0 if compact else 86.0
	%AnimationButton.visible = not compact
	%CoachObjective.add_theme_font_size_override("font_size", 14 if compact else 16)
	if size_changed:
		cancel_motion()

func initialize(main: Main, payload: Dictionary) -> void:
	router = main
	_onboarding_state = payload.get("onboarding", {}).duplicate(true)
	_bind_chrome()
	render_events(payload.get("events", []))
	render_snapshot(payload.get("snapshot", {}))

func render_snapshot(next_snapshot: Dictionary) -> void:
	var previous_state_key := _snapshot_state_key(snapshot)
	var next_state_key := _snapshot_state_key(next_snapshot)
	if not _rejection_message.is_empty() and not previous_state_key.is_empty() and next_state_key != previous_state_key:
		_clear_rejection()
	snapshot = next_snapshot.duplicate(true)
	_sanitize_hidden_opponent_hand()
	var players: Dictionary = snapshot.get("players", {})
	var player: Dictionary = players.get("player", {})
	var opponent: Dictionary = players.get("opponent", {})
	var active_player_id := str(snapshot.get("active_player_id", ""))
	var phase_text := LocaleScript.ui("turn.yours") if active_player_id == "player" else LocaleScript.ui("turn.opponent")
	if str(snapshot.get("phase", "")).to_lower() != "action":
		phase_text = str(snapshot.get("phase", "")).capitalize()
	%TurnLabel.text = LocaleScript.ui("turn.header") % [int(snapshot.get("turn", 0)), phase_text]
	_style_turn_chip(active_player_id == "player" and str(snapshot.get("phase", "")).to_lower() == "action")
	%OpponentLabel.text = _status_strip(opponent, false)
	%OpponentLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	%PlayerLabel.text = _status_strip(player, true)
	%PlayerLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	%CreditLabel.text = "%s %d / %d" % [LocaleScript.ui("status.credit"), int(player.get("credit", 0)), int(player.get("credit_slots", 0))]
	_update_lane_chips()
	%OpponentSupport.render(opponent.get("support_line", []), false, _resolve_card_view)
	%Frontline.render(snapshot.get("frontline", []), false, _resolve_card_view)
	%PlayerSupport.render(player.get("support_line", []), false, _resolve_card_view)
	%OpponentHQ.bind_hq(opponent.get("headquarters", {}), str(opponent.get("nation", "SovietUnion")), int(opponent.get("hq_defense", 0)))
	%PlayerHQ.bind_hq(player.get("headquarters", {}), str(player.get("nation", "UnitedStates")), int(player.get("hq_defense", 0)))
	_render_piles(player, opponent)
	_render_hand(player.get("hand", []))
	_release_missing_card_views(_public_instance_ids(snapshot))
	_refresh_coach()


func _render_piles(player: Dictionary, opponent: Dictionary) -> void:
	%PlayerDeckCount.text = str(int(player.get("deck_count", 0)))
	%PlayerDiscardCount.text = str((player.get("discard", []) as Array).size())
	%OpponentDeckCount.text = str(int(opponent.get("deck_count", 0)))
	%OpponentDiscardCount.text = str((opponent.get("discard", []) as Array).size())


func _sanitize_hidden_opponent_hand() -> void:
	var opponent: Dictionary = snapshot.get("players", {}).get("opponent", {})
	var hand: Array = opponent.get("hand", [])
	for index in range(hand.size()):
		if hand[index] is Dictionary and bool((hand[index] as Dictionary).get("hidden", false)):
			hand[index] = {"hidden": true}

func render_events(events: Array) -> void:
	%Timeline.render_events(events)

func set_animation_mode(mode: String) -> void:
	animation_mode = mode if mode in ["on", "reduced"] else "on"
	if has_node("%AnimationButton"):
		%AnimationButton.text = LocaleScript.ui("match.animation_reduced") if animation_mode == "reduced" else LocaleScript.ui("match.animation_on")
		%AnimationButton.tooltip_text = "Use full card motion" if animation_mode == "reduced" else "Use reduced card motion"

func _on_animation_pressed() -> void:
	set_animation_mode("reduced" if animation_mode == "on" else "on")
	if router != null:
		router.set_animation_mode(animation_mode)

func play_motion(events: Array, before_snapshot: Dictionary, after_snapshot: Dictionary) -> void:
	_motion_director.speed_scale = animation_speed_scale
	await _motion_director.play(events, before_snapshot, after_snapshot, self)

func cancel_motion(final_snapshot: Dictionary = {}) -> void:
	_motion_director.cancel()
	if not final_snapshot.is_empty():
		render_snapshot(final_snapshot)

func animation_zone_rect(player_id: String) -> Rect2:
	return (%OpponentSupport if player_id == "opponent" else %PlayerHand).get_global_rect()

func deck_edge_rect(player_id: String) -> Rect2:
	var pile := %OpponentDeckPile if player_id == "opponent" else %PlayerDeckPile
	if pile.visible and pile.size.x > 1.0:
		return pile.get_global_rect()
	var area: Rect2 = (%OpponentSupport if player_id == "opponent" else %HandScroll).get_global_rect()
	return Rect2(area.end.x - 18.0, area.position.y + area.size.y * 0.5 - 24.0, 36.0, 48.0)

func command_area_rect() -> Rect2:
	var command := %AnimationButton as Control
	if command.visible and command.size.x > 1.0:
		return command.get_global_rect()
	return (%EndTurnButton as Control).get_global_rect()


# Emphasized by CardMotionDirector on credit_refilled events.
func pulse_credit() -> void:
	if not is_node_ready():
		return
	%CreditLabel.pivot_offset = (%CreditLabel as Control).size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(%CreditLabel, "scale", Vector2(1.28, 1.28), 0.10)
	tween.tween_property(%CreditLabel, "scale", Vector2.ONE, 0.14)


func flash_hq(instance_id: String) -> void:
	if not is_node_ready():
		return
	for hq in [%PlayerHQ, %OpponentHQ]:
		if str(hq.card_data.get("instance_id", "")) == instance_id:
			hq.flash_damage()
			return

func visible_card_rects() -> Dictionary:
	var result := {}
	for card in _card_registry.values():
		var instance_id := str(card.card_data.get("instance_id", ""))
		if is_instance_valid(card) and card.is_visible_in_tree() and not instance_id.is_empty() and not bool(card.card_data.get("hidden", false)):
			result[instance_id] = card.get_global_rect()
	for card in [%OpponentHQ, %PlayerHQ]:
		var instance_id := str(card.card_data.get("instance_id", ""))
		if not instance_id.is_empty(): result[instance_id] = card.get_global_rect()
	return result

func card_view(instance_id: String):
	return _card_registry.get(instance_id)

func snapshot_card_rects(value: Dictionary) -> Dictionary:
	var result := {}
	var players: Dictionary = value.get("players", {})
	_add_zone_snapshot_rects(result, players.get("opponent", {}).get("support_line", []), %OpponentSupport)
	_add_zone_snapshot_rects(result, value.get("frontline", []), %Frontline)
	_add_zone_snapshot_rects(result, players.get("player", {}).get("support_line", []), %PlayerSupport)
	for pair in [[players.get("opponent", {}).get("headquarters", {}), %OpponentHQ], [players.get("player", {}).get("headquarters", {}), %PlayerHQ]]:
		if pair[0] is Dictionary:
			var instance_id := str(pair[0].get("instance_id", ""))
			if not instance_id.is_empty(): result[instance_id] = (pair[1] as Control).get_global_rect()
	var hand: Array = players.get("player", {}).get("hand", [])
	var hand_rect := (%HandScroll as Control).get_global_rect()
	var transforms := _hand_layout(hand.size())
	for index in range(hand.size()):
		if hand[index] is Dictionary and not bool(hand[index].get("hidden", false)):
			var instance_id := str(hand[index].get("instance_id", ""))
			if not instance_id.is_empty():
				var pos: Vector2 = transforms[index].pos
				result[instance_id] = Rect2(hand_rect.position.x + pos.x + HAND_MARGIN, hand_rect.position.y + pos.y, HAND_CARD_WIDTH, HAND_CARD_HEIGHT)
	return result

func _add_zone_snapshot_rects(result: Dictionary, cards: Array, zone: ZoneView) -> void:
	for index in range(mini(cards.size(), zone.get_child_count())):
		if cards[index] is Dictionary and not bool(cards[index].get("hidden", false)):
			var instance_id := str(cards[index].get("instance_id", ""))
			if not instance_id.is_empty():
				var slots: Array = zone._drop_slots()
				if index >= slots.size():
					continue
				var slot_rect := (slots[index] as Control).get_global_rect()
				result[instance_id] = Rect2(slot_rect.position.x, zone.global_position.y, 108.0, 118.0)

func set_legal_actions(actions: Array) -> void:
	model.set_legal_actions(actions)
	_refresh_coach()


func set_onboarding_state(state: Dictionary) -> void:
	_onboarding_state = state.duplicate(true)
	_refresh_coach()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and model.can_confirm():
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()

func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	%EndTurnButton.disabled = locked or snapshot.get("active_player_id") != "player"
	%ConfirmButton.disabled = locked or not model.can_confirm()
	%CancelButton.disabled = locked or model.selected_source_id.is_empty()
	%ConcedeButton.disabled = locked or str(snapshot.get("phase", "")) == "complete" or str(snapshot.get("active_player_id", "")) != "player"
	%AnimationButton.disabled = locked
	%OpponentHQ.disabled = locked
	%PlayerHQ.disabled = locked
	%OpponentSupport.set_input_locked(locked)
	%Frontline.set_input_locked(locked)
	%PlayerSupport.set_input_locked(locked)
	for card in %PlayerHand.get_children(): card.disabled = locked
	_refresh_coach()

func show_rejection(code: String, message: String) -> void:
	model.apply_rejection(code, message)
	_rejection_message = message
	%StatusLabel.text = message
	_refresh_coach()

const HAND_CARD_WIDTH := 116.0
const HAND_CARD_HEIGHT := 162.0
const HAND_ADVANCE := 124.0
const HAND_MAX_ROTATION := 9.0
const HAND_ARC_DEPTH := 8.0
const HAND_MARGIN := 16.0


# Kards-style hand fan: cards rotate from -10deg to +10deg and dip at the
# edges. Both the live view and the motion snapshot rects use this layout so
# animation start/end positions always match what the player sees.
func _hand_layout(count: int) -> Array:
	var transforms := []
	for index in range(count):
		var t := 0.5 if count <= 1 else float(index) / float(count - 1)
		var center_offset := (2.0 * t - 1.0)
		var rotation_deg := HAND_MAX_ROTATION * center_offset
		var arc := HAND_ARC_DEPTH * center_offset * center_offset
		transforms.append({
			"pos": Vector2(index * HAND_ADVANCE, arc),
			"rot": rotation_deg,
		})
	return transforms


func _hand_layout_width(count: int) -> float:
	return HAND_CARD_WIDTH + HAND_MARGIN * 2.0 + maxf(0.0, count - 1) * HAND_ADVANCE


func _render_hand(cards: Array) -> void:
	for child in %PlayerHand.get_children():
		%PlayerHand.remove_child(child)
	var visible_cards: Array = []
	for card_data in cards:
		if not (card_data is Dictionary): continue
		var card = _resolve_card_view(card_data, "hand")
		if card.get_parent() != null: card.get_parent().remove_child(card)
		%PlayerHand.add_child(card)
		card.bind(card_data, "hand")
		card.disabled = _input_locked
		visible_cards.append(card)
	var transforms := _hand_layout(visible_cards.size())
	for index in range(visible_cards.size()):
		var card: Control = visible_cards[index]
		card.pivot_offset = Vector2(HAND_CARD_WIDTH, HAND_CARD_HEIGHT) * 0.5
		card.position = Vector2(transforms[index].pos.x + HAND_MARGIN, transforms[index].pos.y)
		card.rotation_degrees = transforms[index].rot
	%PlayerHand.custom_minimum_size = Vector2(_hand_layout_width(visible_cards.size()), 182.0)
	_apply_hand_states()

func _resolve_card_view(card_data: Dictionary, mode: String):
	var instance_id := str(card_data.get("instance_id", ""))
	var card = _card_registry.get(instance_id)
	if card == null or not is_instance_valid(card):
		card = CardViewScene.instantiate()
		_card_registry[instance_id] = card
		card.card_pressed.connect(_on_registered_card_pressed.bind(card))
		card.card_dropped.connect(_on_registered_card_dropped.bind(card))
	card.bind(card_data, mode)
	return card

func _on_registered_card_pressed(instance_id: String, card: CardView) -> void:
	if card.mode == "hand": _on_card_pressed(instance_id)
	else: _on_board_card_pressed(instance_id)

func _on_registered_card_dropped(source_id: String, target_id: Variant, card: CardView) -> void:
	if card.mode == "battlefield": _on_target_dropped(source_id, str(target_id))

func _public_instance_ids(value: Dictionary) -> Dictionary:
	var result := {}
	var players: Dictionary = value.get("players", {})
	for cards in [players.get("player", {}).get("hand", []), players.get("player", {}).get("support_line", []), players.get("opponent", {}).get("support_line", []), value.get("frontline", [])]:
		for card in cards:
			if card is Dictionary and not bool(card.get("hidden", false)):
				var instance_id := str(card.get("instance_id", ""))
				if not instance_id.is_empty(): result[instance_id] = true
	return result

func _release_missing_card_views(public_ids: Dictionary) -> void:
	for instance_id in _card_registry.keys():
		if not public_ids.has(instance_id):
			var card = _card_registry[instance_id]
			if is_instance_valid(card): card.free()
			_card_registry.erase(instance_id)

func _on_card_pressed(instance_id: String) -> void:
	if _reject_locked(): return
	_clear_rejection()
	var reason := str(_coach_state.get("source_reasons", {}).get(instance_id, ""))
	if not reason.is_empty():
		model.cancel()
		model.status_message = reason
		%StatusLabel.text = reason
		_refresh_coach()
		return
	model.select_source(instance_id)
	var action = model.immediate_action()
	if action != null: action_requested.emit(action)
	%StatusLabel.text = ""
	_refresh_coach()

func _on_board_card_pressed(instance_id: String) -> void:
	if _reject_locked(): return
	_clear_rejection()
	if model.selected_source_id.is_empty():
		model.select_source(instance_id)
	else:
		var action = model.choose_target(instance_id)
		if action != null:
			action_requested.emit(action)
	_refresh_coach()

func _on_slot_pressed(zone: String, slot: int) -> void:
	if _reject_locked(): return
	_clear_rejection()
	var action = model.choose_slot(zone, slot)
	if action != null:
		action_requested.emit(action)
	elif slot not in model.highlighted_slots(zone):
		show_rejection("illegal_drop", LocaleScript.ui("reason.none"))
	_refresh_coach()

func _on_card_dropped(instance_id: String, zone: String, slot: int) -> void:
	if _reject_locked(): return
	model.select_source(instance_id)
	_on_slot_pressed(zone, slot)

func _on_target_dropped(source_id: String, target_id: String) -> void:
	if _reject_locked(): return
	_clear_rejection()
	model.select_source(source_id)
	var action = model.choose_target(target_id)
	if action != null:
		action_requested.emit(action)
	elif not str(target_id).is_empty() and str(target_id) not in model.highlighted_targets():
		show_rejection("illegal_drop", LocaleScript.ui("reason.no_target"))
	_refresh_coach()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _reject_locked(): return
		model.cancel()
		_clear_rejection()
		%StatusLabel.text = ""
		_refresh_coach()

func _on_end_turn_pressed() -> void:
	if _reject_locked(): return
	for action in model._legal_actions:
		if action.type == "end_turn": action_requested.emit(action); return

func _on_concede_pressed() -> void:
	if _reject_locked(): return
	%ConcedeDialog.popup_centered()

func _on_concede_confirmed() -> void:
	if str(snapshot.get("active_player_id", "")) != "player":
		return
	action_requested.emit(GameAction.create("concede", "player"))

func _on_confirm_pressed() -> void:
	if _reject_locked(): return
	var action = model.confirm_action()
	if action != null: action_requested.emit(action)
	_refresh_coach()

func _on_cancel_pressed() -> void:
	if _reject_locked(): return
	model.cancel()
	_clear_rejection()
	%StatusLabel.text = ""
	_refresh_coach()

func _reject_locked() -> bool:
	if not _input_locked: return false
	show_rejection("input_locked", LocaleScript.ui("reason.locked"))
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _reject_locked(): return
		model.cancel()
		_clear_rejection()
		%StatusLabel.text = ""
		_refresh_coach()

func _refresh_highlights() -> void:
	var targets := model.highlighted_targets()
	%OpponentSupport.set_highlights([], targets)
	%Frontline.set_highlights(model.highlighted_slots("frontline"), targets)
	%PlayerSupport.set_highlights(model.highlighted_slots("support"), targets)
	%OpponentHQ.set_highlight(str(%OpponentHQ.card_data.get("instance_id", "")) in targets)
	%PlayerHQ.set_highlight(str(%PlayerHQ.card_data.get("instance_id", "")) in targets)
	%ConfirmButton.disabled = _input_locked or not model.can_confirm()
	%CancelButton.disabled = _input_locked or model.selected_source_id.is_empty()
	_apply_hand_states()
	_refresh_end_turn_state()
	_refresh_coach_objective()


func _refresh_coach() -> void:
	_coach_state = MatchCoachModelScript.derive(snapshot, model._legal_actions, {
		"selected_source_id": model.selected_source_id,
		"selected_targets": model.selected_targets,
		"selected_zone": model.selected_zone,
		"selected_slot": model.selected_slot,
	}, _onboarding_state)
	_refresh_highlights()


func _refresh_end_turn_state() -> void:
	var end_actions := model._legal_actions.filter(func(action) -> bool: return action.type == "end_turn")
	var can_end: bool = not end_actions.is_empty() and str(snapshot.get("active_player_id", "")) == "player" and str(snapshot.get("phase", "")) == "action"
	%EndTurnButton.disabled = _input_locked or not can_end
	%ConcedeButton.disabled = _input_locked or not (str(snapshot.get("active_player_id", "")) == "player" and str(snapshot.get("phase", "")) == "action")
	%EndTurnButton.remove_theme_stylebox_override("normal")
	if not can_end:
		%EndTurnButton.set_meta("action_state", "disabled")
	elif bool(_coach_state.get("end_turn_only", false)):
		%EndTurnButton.set_meta("action_state", "strong")
		var style := StyleBoxFlat.new()
		style.bg_color = Color("2b2d24")
		style.border_color = Color("f0cf55")
		style.set_border_width_all(3)
		style.set_corner_radius_all(4)
		%EndTurnButton.add_theme_stylebox_override("normal", style)
	else:
		%EndTurnButton.set_meta("action_state", "normal")


func _refresh_coach_objective() -> void:
	var next := _rejection_message if not _rejection_message.is_empty() else str(_coach_state.get("objective", LocaleScript.ui("coach.none")))
	if model.can_confirm() and _rejection_message.is_empty():
		next = LocaleScript.ui("coach.confirm")
	if %CoachObjective.text != next:
		%CoachObjective.text = next
		_pulse_coach()


func _apply_hand_states() -> void:
	var legal_ids: Array = _coach_state.get("legal_source_ids", [])
	var reasons: Dictionary = _coach_state.get("source_reasons", {})
	for child in %PlayerHand.get_children():
		var instance_id := str(child.card_data.get("instance_id", ""))
		if instance_id == model.selected_source_id:
			child.set_action_state("selected")
		elif instance_id in legal_ids:
			child.set_action_state("legal")
		elif reasons.has(instance_id):
			child.set_action_state("unavailable", str(reasons[instance_id]))
		else:
			child.set_action_state("normal")


func _clear_rejection() -> void:
	_rejection_message = ""
	model.rejection_code = ""
	if is_node_ready():
		%StatusLabel.text = ""


func _snapshot_state_key(value: Dictionary) -> String:
	if value.is_empty():
		return ""
	return "%s|%s|%s|%s|%s" % [
		str(value.get("sequence", "")),
		str(value.get("turn", "")),
		str(value.get("phase", "")),
		str(value.get("active_player_id", "")),
		str(value.get("winner_id", "")),
	]


func _bind_chrome() -> void:
	%CancelButton.text = LocaleScript.ui("match.cancel")
	%ConfirmButton.text = LocaleScript.ui("match.confirm")
	%EndTurnButton.text = LocaleScript.ui("match.end_turn")
	%ConcedeButton.text = LocaleScript.ui("match.concede")
	%ConcedeDialog.title = LocaleScript.ui("match.concede_title")
	%ConcedeDialog.dialog_text = LocaleScript.ui("match.concede_body")
	%ConcedeDialog.ok_button_text = LocaleScript.ui("match.concede_ok")
	%ConcedeDialog.cancel_button_text = LocaleScript.ui("match.concede_cancel")
	set_animation_mode(animation_mode)


func _status_strip(side: Dictionary, include_discard: bool) -> String:
	var parts: PackedStringArray = PackedStringArray([
		"%s %d" % [LocaleScript.ui("status.hq"), int(side.get("hq_defense", 0))],
		"%s %d" % [LocaleScript.ui("status.hand"), (side.get("hand", []) as Array).size()],
		"%s %d" % [LocaleScript.ui("status.deck"), int(side.get("deck_count", 0))],
	])
	if include_discard:
		parts.append("%s %d" % [LocaleScript.ui("status.discard"), (side.get("discard", []) as Array).size()])
	return "   ".join(parts)


func _install_lane_chrome() -> void:
	_attach_lane(get_node("Margin/Columns/Board/OpponentArea") as Control, Color(0.42, 0.18, 0.14, 0.22), "OpponentLaneChip", "zone.enemy_support")
	_attach_lane(get_node("Margin/Columns/Board/PlayerArea") as Control, Color(0.16, 0.28, 0.38, 0.24), "PlayerLaneChip", "zone.player_support")


func _attach_lane(host: Control, tint: Color, chip_name: String, key: String) -> void:
	if host.get_node_or_null("LaneBand") == null:
		var band := ColorRect.new()
		band.name = "LaneBand"
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.color = tint
		band.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.add_child(band)
		host.move_child(band, 0)
	if host.get_node_or_null(chip_name) == null:
		var chip := Label.new()
		chip.name = chip_name
		chip.unique_name_in_owner = true
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_font_size_override("font_size", 12)
		chip.add_theme_color_override("font_color", Color("e8e1d2"))
		chip.position = Vector2(6, 2)
		chip.z_index = 2
		host.add_child(chip)
	(host.get_node(chip_name) as Label).text = LocaleScript.ui(key)


func _update_lane_chips() -> void:
	if has_node("%OpponentLaneChip"):
		%OpponentLaneChip.text = LocaleScript.ui("zone.enemy_support")
	if has_node("%PlayerLaneChip"):
		%PlayerLaneChip.text = LocaleScript.ui("zone.player_support")
	var controller := str(snapshot.get("frontline_controller_id", ""))
	var control_text := LocaleScript.ui("frontline.open")
	if controller == "player":
		control_text = LocaleScript.ui("frontline.yours")
	elif controller == "opponent":
		control_text = LocaleScript.ui("frontline.enemy")
	%Frontline.lane_caption = "%s · %s" % [LocaleScript.ui("zone.frontline"), control_text]
	%Frontline.queue_redraw()


func _install_help_button() -> void:
	if has_node("%HelpButton"):
		return
	var help := Button.new()
	help.name = "HelpButton"
	help.unique_name_in_owner = true
	help.text = LocaleScript.ui("match.help")
	help.custom_minimum_size = Vector2(36, 36)
	help.pressed.connect(func() -> void: how_to_play_requested.emit())
	%TurnLabel.get_parent().add_child(help)


func _style_coach() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.18, 0.12, 0.92)
	style.border_color = Color("c4a45a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	%CoachObjective.add_theme_stylebox_override("normal", style)
	%CoachObjective.add_theme_font_size_override("font_size", 16)
	%CoachObjective.add_theme_color_override("font_color", Color("f2dd9a"))
	%CoachObjective.custom_minimum_size.y = 36


func _style_turn_chip(active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3a3420") if active else Color(0, 0, 0, 0)
	style.border_color = Color("d1b56f") if active else Color(0, 0, 0, 0)
	style.set_border_width_all(2 if active else 0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	%TurnLabel.add_theme_stylebox_override("normal", style)


func _pulse_coach() -> void:
	if not is_node_ready() or animation_speed_scale < 0.05:
		return
	if _coach_pulse != null and _coach_pulse.is_valid():
		_coach_pulse.kill()
	%CoachObjective.pivot_offset = %CoachObjective.size * 0.5
	_coach_pulse = create_tween()
	_coach_pulse.tween_property(%CoachObjective, "modulate", Color(1.2, 1.15, 0.9), 0.08)
	_coach_pulse.tween_property(%CoachObjective, "modulate", Color.WHITE, 0.18)
