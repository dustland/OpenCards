class_name MatchController
extends RefCounted

const ActionResult = preload("res://scripts/core/action_result.gd")
const ActionGenerator = preload("res://scripts/ai/action_generator.gd")
const CardInstance = preload("res://scripts/core/card_instance.gd")
const CombatRules = preload("res://scripts/core/combat_rules.gd")
const EffectEngine = preload("res://scripts/core/effect_engine.gd")
const GameAction = preload("res://scripts/core/game_action.gd")
const GameConstants = preload("res://scripts/core/game_constants.gd")
const MatchState = preload("res://scripts/core/match_state.gd")
const PlayerState = preload("res://scripts/core/player_state.gd")
const ReplayLog = preload("res://scripts/core/replay_log.gd")

var state: MatchState
var initial_deck_ids: Dictionary
var card_definitions: Dictionary
var replay_log: ReplayLog
var event_history: Array = []
var invalid_diagnostics: Dictionary = {}
var _definitions: Dictionary
var _rng := RandomNumberGenerator.new()
var _effect_engine: EffectEngine
var _debug_trigger_hook: Callable
var _debug_modifier_expiry_hook: Callable
var _simulation_mode: bool = false

static func create(card_definitions: Dictionary, player_deck: Array, opponent_deck: Array, seed: int) -> MatchController:
	var controller: MatchController = load("res://scripts/core/match_controller.gd").new()
	controller.card_definitions = card_definitions.duplicate(true)
	controller._definitions = controller.card_definitions.duplicate(true)
	controller.initial_deck_ids = {
		"player": player_deck.duplicate(),
		"opponent": opponent_deck.duplicate(),
	}
	controller._rng.seed = seed
	var player := controller._create_player("player", "p", player_deck)
	var opponent := controller._create_player("opponent", "o", opponent_deck)
	controller.state = MatchState.create(player, opponent, seed)
	controller._effect_engine = EffectEngine.create(controller.state, controller._definitions, controller._rng)
	controller._shuffle_deck(player.deck)
	controller._shuffle_deck(opponent.deck)
	controller.replay_log = ReplayLog.create(seed, player_deck, opponent_deck)
	controller.replay_log.terminal_result = controller._replay_terminal_result()
	return controller

func submit_action(action: GameAction) -> ActionResult:
	if state == null:
		return ActionResult.reject("match_uninitialized", "Match is not initialized")
	if state.phase == "invalid":
		return _reject(action, "match_invalid", "Match is invalid")
	if _is_terminal():
		return _reject(action, "match_complete", "Match is complete")
	if action.expected_sequence > 0 and action.expected_sequence != state.sequence:
		return _reject(action, "stale_action", "State changed")
	var transaction := _capture_transaction()
	_effect_engine.begin_action()
	var result := _dispatch_action(action)
	if action.type in ["attack_unit", "attack_hq"]:
		_expire_temporary_statuses("combat")
	var resolution := _effect_engine.finish_action()
	if not result.accepted or not resolution.valid:
		_restore_transaction(transaction)
		if not resolution.valid:
			return _reject_rule(action, resolution)
		return _reject(action, result.reason_code, result.message)
	if _is_terminal():
		_synchronize_frontline_controller()
	var invariants := _validate_invariants()
	if not invariants.valid:
		return _abort_invalid("state_invariant", invariants)
	event_history.append_array(result.events.duplicate(true))
	if not _simulation_mode and replay_log != null:
		replay_log.record(action, state.sequence)
		replay_log.starting_player_id = state.starting_player_id
		replay_log.terminal_result = _replay_terminal_result()
	return result

func state_hash() -> String:
	return JSON.stringify(_canonicalize(_authoritative_state())).sha256_text()

func effect_metrics() -> Dictionary:
	return {"max_queue_size": _effect_engine.max_queue_size if _effect_engine != null else 0}

func abort_invalid(code: String, details: Dictionary = {}) -> ActionResult:
	return _abort_invalid(code, details)

func legal_actions(actor_id: String) -> Array[GameAction]:
	return ActionGenerator.generate(self, actor_id)

func clone_for_simulation(perspective_id: String) -> MatchController:
	if perspective_id not in ["player", "opponent"] or state == null or not state.players.has(perspective_id):
		return null
	var clone := MatchController.create(
		card_definitions.duplicate(true),
		initial_deck_ids.get("player", []).duplicate(),
		initial_deck_ids.get("opponent", []).duplicate(),
		state.seed
	)
	clone.initial_deck_ids = initial_deck_ids.duplicate(true)
	var hidden_player_id := _other_player_id(perspective_id)
	clone.initial_deck_ids[hidden_player_id] = _anonymous_definition_ids(
		(initial_deck_ids.get(hidden_player_id, []) as Array).size()
	)
	clone.event_history = []
	clone.invalid_diagnostics = invalid_diagnostics.duplicate(true)
	clone._simulation_mode = true
	clone.replay_log = null
	clone._restore_simulation_snapshot(_simulation_snapshot_for(perspective_id))
	return clone

func can_simulate_action(action: GameAction) -> bool:
	if not _simulation_mode:
		return false
	var transaction := _capture_transaction()
	var event_count := event_history.size()
	var diagnostics := invalid_diagnostics.duplicate(true)
	var result := submit_action(action)
	_restore_transaction(transaction)
	event_history.resize(event_count)
	invalid_diagnostics = diagnostics
	return result.accepted

func simulate_action_clone(action: GameAction, perspective_id: String) -> MatchController:
	if not _simulation_mode:
		return null
	var transaction := _capture_transaction()
	var event_count := event_history.size()
	var diagnostics := invalid_diagnostics.duplicate(true)
	var result := submit_action(action)
	var child: MatchController = clone_for_simulation(perspective_id) if result.accepted else null
	_restore_transaction(transaction)
	event_history.resize(event_count)
	invalid_diagnostics = diagnostics
	return child

func _simulation_snapshot_for(perspective_id: String) -> Dictionary:
	var snapshot := _invalid_replay_snapshot()
	var hidden_player_id := _other_player_id(perspective_id)
	var hidden_player: Dictionary = snapshot.players[hidden_player_id]
	var active_ids := {}
	for card_id in hidden_player.active_countermeasures:
		active_ids[card_id] = true
	var hidden_ids := {}
	for card_id in hidden_player.deck:
		hidden_ids[card_id] = true
	for card_id in hidden_player.hand:
		var card: Dictionary = snapshot.cards[card_id]
		if active_ids.has(card_id) or not bool((card.revealed_to as Dictionary).get(perspective_id, false)):
			hidden_ids[card_id] = true
	for card_id in hidden_ids:
		snapshot.cards.erase(card_id)
	hidden_player.deck = _anonymous_zone_cards(snapshot.cards, hidden_player_id, "deck", hidden_player.deck.size())
	var anonymous_hand: Array = []
	var hidden_hand_index := 0
	for card_id in (snapshot.players[hidden_player_id] as Dictionary).hand:
		if hidden_ids.has(card_id):
			var anonymous_id := _unique_anonymous_id(snapshot.cards, hidden_player_id, "hand", hidden_hand_index)
			hidden_hand_index += 1
			snapshot.cards[anonymous_id] = _anonymous_card_state(hidden_player_id, anonymous_id, "hand")
			anonymous_hand.append(anonymous_id)
		else:
			anonymous_hand.append(card_id)
	hidden_player.hand = anonymous_hand
	hidden_player.active_countermeasures = []
	snapshot.players[hidden_player_id] = hidden_player
	return snapshot

func _anonymous_zone_cards(cards: Dictionary, owner_id: String, zone: String, count: int) -> Array:
	var ids: Array = []
	for index in range(count):
		var instance_id := _unique_anonymous_id(cards, owner_id, zone, index)
		cards[instance_id] = _anonymous_card_state(owner_id, instance_id, zone)
		ids.append(instance_id)
	return ids

func _unique_anonymous_id(cards: Dictionary, owner_id: String, zone: String, index: int) -> String:
	var base := "__simulation_%s_%s_%03d" % [owner_id, zone, index]
	var instance_id := base
	var suffix := 0
	while cards.has(instance_id):
		suffix += 1
		instance_id = "%s_%d" % [base, suffix]
	return instance_id

func _anonymous_card_state(owner_id: String, instance_id: String, zone: String) -> Dictionary:
	return {
		"definition_id": "",
		"instance_id": instance_id,
		"owner_id": owner_id,
		"title": "",
		"description": "",
		"category": "",
		"unit_type": "",
		"base_attack": 0,
		"current_attack": 0,
		"base_defense": 0,
		"current_defense": 0,
		"deployment_cost": 0,
		"operation_cost": 0,
		"keywords": [],
		"abilities": [],
		"zone": zone,
		"slot": -1,
		"operations_used": 0,
		"operation_chain": 0,
		"smokescreen_revealed": false,
		"deployed_turn": -1,
		"modifiers": [],
		"statuses": {},
		"temporary_statuses": [],
		"revealed_to": {},
		"face_down": false,
		"countermeasure_active": false,
		"countermeasure_activation_cost": 0,
	}

func _anonymous_definition_ids(count: int) -> Array:
	var ids: Array = []
	ids.resize(count)
	ids.fill("")
	return ids

func _restore_simulation_snapshot(snapshot: Dictionary) -> void:
	var cards := {}
	for card_id in snapshot.cards:
		var data: Dictionary = snapshot.cards[card_id]
		var card: CardInstance = CardInstance.headquarters(data.definition_id, data.owner_id, data.instance_id, _definitions.get(data.definition_id, {})) \
			if data.category == "Headquarters" else CardInstance.from_definition(_definitions.get(data.definition_id, {}), data.owner_id, data.instance_id)
		_apply_card_snapshot(card, data)
		cards[card_id] = card
	for player_id in state.players:
		var player: PlayerState = state.players[player_id]
		var player_snapshot: Dictionary = snapshot.players[player_id]
		player.id = player_snapshot.id
		player.nation = player_snapshot.nation
		player.headquarters = cards[player_snapshot.headquarters]
		player.deck = _cards_from_snapshot_ids(player_snapshot.deck, cards)
		player.hand = _cards_from_snapshot_ids(player_snapshot.hand, cards)
		player.support_line = _cards_from_snapshot_ids(player_snapshot.support_line, cards)
		player.discard = _cards_from_snapshot_ids(player_snapshot.discard, cards)
		player.active_countermeasures = _cards_from_snapshot_ids(player_snapshot.active_countermeasures, cards)
		player.credit_slots = player_snapshot.credit_slots
		player.credit = player_snapshot.credit
		player.fatigue = player_snapshot.fatigue
		player.turns_started = player_snapshot.turns_started
		player.mulligan_used = player_snapshot.mulligan_used
		player.mulligan_confirmed = player_snapshot.mulligan_confirmed
		player.max_hand_size = player_snapshot.max_hand_size
	state.active_player_id = snapshot.active_player_id
	state.starting_player_id = snapshot.starting_player_id
	state.turn = snapshot.turn
	state.frontline = _cards_from_snapshot_ids(snapshot.frontline, cards)
	state.frontline_controller_id = snapshot.frontline_controller_id
	state.winner_id = snapshot.winner_id
	state.seed = snapshot.seed
	state.rng_state = snapshot.rng_state
	_rng.state = snapshot.rng_internal_state
	state.sequence = snapshot.sequence
	state.phase = snapshot.phase
	invalid_diagnostics = snapshot.invalid_diagnostics.duplicate(true)
	_effect_engine.reset_after_rollback()

func _replay_terminal_result() -> Dictionary:
	return {
		"type": "state",
		"phase": state.phase,
		"winner_id": state.winner_id,
		"sequence": state.sequence,
	}

func _authoritative_state() -> Dictionary:
	var players := {}
	for player_id in state.players:
		var player: PlayerState = state.players[player_id]
		players[player_id] = {
			"id": player.id,
			"nation": player.nation,
			"headquarters": _card_state(player.headquarters),
			"deck": _cards_state(player.deck),
			"hand": _cards_state(player.hand),
			"support_line": _cards_state(player.support_line),
			"discard": _cards_state(player.discard),
			"active_countermeasures": _cards_state(player.active_countermeasures),
			"credit_slots": player.credit_slots,
			"credit": player.credit,
			"fatigue": player.fatigue,
			"turns_started": player.turns_started,
			"mulligan_used": player.mulligan_used,
			"mulligan_confirmed": player.mulligan_confirmed,
			"max_hand_size": player.max_hand_size,
		}
	return {
		"players": players,
		"active_player_id": state.active_player_id,
		"starting_player_id": state.starting_player_id,
		"turn": state.turn,
		"frontline": _cards_state(state.frontline),
		"frontline_controller_id": state.frontline_controller_id,
		"winner_id": state.winner_id,
		"seed": state.seed,
		"rng_state": state.rng_state,
		"rng_internal_state": _rng.state,
		"sequence": state.sequence,
		"phase": state.phase,
		"invalid_diagnostics": invalid_diagnostics.duplicate(true),
	}

func _abort_invalid(code: String, details: Dictionary = {}) -> ActionResult:
	if state == null:
		return ActionResult.reject("match_invalid", "Match is invalid")
	if state.phase == "invalid":
		return _reject(GameAction.create("", ""), "match_invalid", "Match is invalid")
	var pre_abort_sequence := state.sequence
	var pre_abort_state_hash := state_hash()
	var pre_abort_snapshot := _invalid_replay_snapshot()
	invalid_diagnostics = {
		"code": code,
		"details": details.duplicate(true),
	}
	state.phase = "invalid"
	var events: Array = []
	_emit(events, "match_invalid", invalid_diagnostics.duplicate(true))
	event_history.append_array(events.duplicate(true))
	if replay_log != null:
		replay_log.record_invalid_terminal(
			code,
			details,
			pre_abort_sequence,
			state.sequence,
			state_hash(),
			pre_abort_state_hash,
			pre_abort_snapshot
		)
	var result := ActionResult.reject("match_invalid", "Match is invalid", state.snapshot_for("system"))
	result.events = events
	return result

func _predicted_invalid_terminal_hash(code: String, details: Dictionary) -> String:
	var transaction := _capture_transaction()
	var diagnostics_before := invalid_diagnostics.duplicate(true)
	invalid_diagnostics = {"code": code, "details": details.duplicate(true)}
	state.phase = "invalid"
	state.sequence += 1
	var predicted_hash := state_hash()
	_restore_transaction(transaction)
	invalid_diagnostics = diagnostics_before
	return predicted_hash

func _invalid_replay_snapshot() -> Dictionary:
	var cards := {}
	var players := {}
	for player_id in state.players:
		var player: PlayerState = state.players[player_id]
		players[player_id] = {
			"id": player.id,
			"nation": player.nation,
			"headquarters": _snapshot_card_id(player.headquarters, cards),
			"deck": _snapshot_card_ids(player.deck, cards),
			"hand": _snapshot_card_ids(player.hand, cards),
			"support_line": _snapshot_card_ids(player.support_line, cards),
			"discard": _snapshot_card_ids(player.discard, cards),
			"active_countermeasures": _snapshot_card_ids(player.active_countermeasures, cards),
			"credit_slots": player.credit_slots,
			"credit": player.credit,
			"fatigue": player.fatigue,
			"turns_started": player.turns_started,
			"mulligan_used": player.mulligan_used,
			"mulligan_confirmed": player.mulligan_confirmed,
			"max_hand_size": player.max_hand_size,
		}
	return {
		"players": players,
		"cards": cards,
		"active_player_id": state.active_player_id,
		"starting_player_id": state.starting_player_id,
		"turn": state.turn,
		"frontline": _snapshot_card_ids(state.frontline, cards),
		"frontline_controller_id": state.frontline_controller_id,
		"winner_id": state.winner_id,
		"seed": state.seed,
		"rng_state": state.rng_state,
		"rng_internal_state": _rng.state,
		"sequence": state.sequence,
		"phase": state.phase,
		"invalid_diagnostics": invalid_diagnostics.duplicate(true),
	}

func _snapshot_card_id(card, cards: Dictionary) -> Variant:
	if card == null:
		return null
	if not cards.has(card.instance_id):
		cards[card.instance_id] = _card_state(card)
	return card.instance_id

func _snapshot_card_ids(collection: Array, cards: Dictionary) -> Array:
	var ids: Array = []
	for card in collection:
		ids.append(_snapshot_card_id(card, cards))
	return ids

func _restore_invalid_replay_snapshot(snapshot: Dictionary) -> Dictionary:
	var validation := _validate_invalid_replay_snapshot(snapshot)
	if not validation.valid:
		return validation
	var cards := {}
	for card_id in snapshot.cards:
		var data: Dictionary = snapshot.cards[card_id]
		var card: CardInstance = CardInstance.headquarters(data.definition_id, data.owner_id, data.instance_id, _definitions.get(data.definition_id, {})) \
			if data.category == "Headquarters" else CardInstance.from_definition(_definitions.get(data.definition_id, {}), data.owner_id, data.instance_id)
		_apply_card_snapshot(card, data)
		cards[card_id] = card
	for player_id in state.players:
		var player: PlayerState = state.players[player_id]
		var player_snapshot: Dictionary = snapshot.players[player_id]
		player.id = player_snapshot.id
		player.nation = player_snapshot.nation
		player.headquarters = cards[player_snapshot.headquarters]
		player.deck = _cards_from_snapshot_ids(player_snapshot.deck, cards)
		player.hand = _cards_from_snapshot_ids(player_snapshot.hand, cards)
		player.support_line = _cards_from_snapshot_ids(player_snapshot.support_line, cards)
		player.discard = _cards_from_snapshot_ids(player_snapshot.discard, cards)
		player.active_countermeasures = _cards_from_snapshot_ids(player_snapshot.active_countermeasures, cards)
		player.credit_slots = player_snapshot.credit_slots
		player.credit = player_snapshot.credit
		player.fatigue = player_snapshot.fatigue
		player.turns_started = player_snapshot.turns_started
		player.mulligan_used = player_snapshot.mulligan_used
		player.mulligan_confirmed = player_snapshot.mulligan_confirmed
		player.max_hand_size = player_snapshot.max_hand_size
	state.active_player_id = snapshot.active_player_id
	state.starting_player_id = snapshot.starting_player_id
	state.turn = snapshot.turn
	state.frontline = _cards_from_snapshot_ids(snapshot.frontline, cards)
	state.frontline_controller_id = snapshot.frontline_controller_id
	state.winner_id = snapshot.winner_id
	state.seed = snapshot.seed
	state.rng_state = snapshot.rng_state
	_rng.state = snapshot.rng_internal_state
	state.sequence = snapshot.sequence
	state.phase = snapshot.phase
	invalid_diagnostics = snapshot.invalid_diagnostics.duplicate(true)
	_effect_engine.reset_after_rollback()
	return {"valid": true}

func _cards_from_snapshot_ids(ids: Array, cards: Dictionary) -> Array:
	var restored: Array = []
	for card_id in ids:
		restored.append(cards[card_id] if card_id != null else null)
	return restored

func _apply_card_snapshot(card: CardInstance, data: Dictionary) -> void:
	card.definition_id = data.definition_id
	card.instance_id = data.instance_id
	card.owner_id = data.owner_id
	card.title = data.title
	card.description = str(data.get("description", ""))
	card.category = data.category
	card.unit_type = data.unit_type
	card.base_attack = data.base_attack
	card.current_attack = data.current_attack
	card.base_defense = data.base_defense
	card.current_defense = data.current_defense
	card.deployment_cost = data.deployment_cost
	card.operation_cost = data.operation_cost
	card.keywords = data.keywords.duplicate(true)
	card.abilities = data.abilities.duplicate(true)
	card.zone = data.zone
	card.slot = data.slot
	card.operations_used = data.operations_used
	card.operation_chain = data.operation_chain
	card.smokescreen_revealed = data.smokescreen_revealed
	card.deployed_turn = data.deployed_turn
	card.modifiers = data.modifiers.duplicate(true)
	card.statuses = data.statuses.duplicate(true)
	card.temporary_statuses = data.temporary_statuses.duplicate(true)
	card.revealed_to = data.revealed_to.duplicate(true)
	card.face_down = data.face_down
	card.countermeasure_active = data.countermeasure_active
	card.countermeasure_activation_cost = data.countermeasure_activation_cost

func _validate_invalid_replay_snapshot(snapshot: Dictionary) -> Dictionary:
	if not (snapshot is Dictionary) or not (snapshot.get("players", null) is Dictionary) or not (snapshot.get("cards", null) is Dictionary):
		return {"valid": false, "code": "invalid_snapshot_shape"}
	for field in ["active_player_id", "starting_player_id", "frontline_controller_id", "winner_id", "phase"]:
		if typeof(snapshot.get(field, null)) != TYPE_STRING:
			return {"valid": false, "code": "invalid_snapshot_string"}
	for field in ["turn", "seed", "rng_state", "rng_internal_state", "sequence"]:
		if typeof(snapshot.get(field, null)) != TYPE_INT:
			return {"valid": false, "code": "invalid_snapshot_number"}
	for field in ["frontline", "invalid_diagnostics"]:
		if not (snapshot.get(field, null) is Array) and field == "frontline":
			return {"valid": false, "code": "invalid_snapshot_frontline"}
		if not (snapshot.get(field, null) is Dictionary) and field == "invalid_diagnostics":
			return {"valid": false, "code": "invalid_snapshot_diagnostics"}
	if not (snapshot.phase in ["setup", "mulligan", "action"]) or not snapshot.invalid_diagnostics.is_empty():
		return {"valid": false, "code": "invalid_snapshot_pre_abort_state"}
	if snapshot.players.size() != 2:
		return {"valid": false, "code": "invalid_snapshot_players"}
	var seen_instance_ids := {}
	for card_id in snapshot.cards:
		if typeof(card_id) != TYPE_STRING:
			return {"valid": false, "code": "invalid_snapshot_card"}
		var card_data: Dictionary = snapshot.cards[card_id]
		if not _valid_card_snapshot(card_data) \
			or card_data.instance_id != card_id \
			or seen_instance_ids.has(card_data.instance_id) \
			or not _valid_snapshot_definition(card_data) \
			or not (card_data.owner_id in ["player", "opponent"]) \
			or not (card_data.zone in ["headquarters", "deck", "hand", "support_line", "discard", "frontline"]):
			return {"valid": false, "code": "invalid_snapshot_card"}
		seen_instance_ids[card_data.instance_id] = true
	var primary_card_ids := {}
	var headquarters_ids := {}
	var hand_ids_by_player := {}
	for player_id in ["player", "opponent"]:
		if not snapshot.players.has(player_id) or not _valid_player_snapshot_fields(snapshot.players[player_id], player_id):
			return {"valid": false, "code": "invalid_snapshot_player"}
		var player_snapshot: Dictionary = snapshot.players[player_id]
		if not _valid_snapshot_headquarters(player_snapshot.headquarters, snapshot.cards, player_id, headquarters_ids):
			return {"valid": false, "code": "invalid_snapshot_headquarters"}
		if not _valid_snapshot_primary_zone(player_snapshot.deck, snapshot.cards, player_id, "deck", primary_card_ids, false):
			return {"valid": false, "code": "invalid_snapshot_deck"}
		if not _valid_snapshot_primary_zone(player_snapshot.hand, snapshot.cards, player_id, "hand", primary_card_ids, false):
			return {"valid": false, "code": "invalid_snapshot_hand"}
		hand_ids_by_player[player_id] = _snapshot_id_set(player_snapshot.hand)
		if player_snapshot.support_line.size() != GameConstants.SUPPORT_UNIT_SLOTS \
			or not _valid_snapshot_primary_zone(player_snapshot.support_line, snapshot.cards, player_id, "support_line", primary_card_ids, true):
			return {"valid": false, "code": "invalid_snapshot_support_line"}
		if not _valid_snapshot_primary_zone(player_snapshot.discard, snapshot.cards, player_id, "discard", primary_card_ids, false):
			return {"valid": false, "code": "invalid_snapshot_discard"}
		if not _valid_snapshot_active_countermeasures(player_snapshot.active_countermeasures, snapshot.cards, player_id, hand_ids_by_player[player_id]):
			return {"valid": false, "code": "invalid_snapshot_active_countermeasures"}
	if snapshot.frontline.size() != GameConstants.FRONTLINE_SLOTS \
		or not _valid_snapshot_primary_zone(snapshot.frontline, snapshot.cards, "", "frontline", primary_card_ids, true):
		return {"valid": false, "code": "invalid_snapshot_frontline"}
	var frontline_controller := ""
	for card_id in snapshot.frontline:
		if card_id != null:
			var card_owner_id: String = snapshot.cards[card_id].owner_id
			if frontline_controller.is_empty():
				frontline_controller = card_owner_id
			elif frontline_controller != card_owner_id:
				return {"valid": false, "code": "mixed_snapshot_frontline_owners"}
	if frontline_controller != snapshot.frontline_controller_id:
		return {"valid": false, "code": "invalid_snapshot_frontline_controller"}
	for card_id in snapshot.cards:
		var card: Dictionary = snapshot.cards[card_id]
		if card.category == "Headquarters":
			if not headquarters_ids.has(card_id):
				return {"valid": false, "code": "unreferenced_snapshot_headquarters"}
		elif not primary_card_ids.has(card_id):
			return {"valid": false, "code": "unreferenced_snapshot_card"}
	return {"valid": true}

func _valid_snapshot_definition(card_data: Dictionary) -> bool:
	if card_data.category == "Headquarters" and card_data.definition_id.is_empty():
		return true
	if not _definitions.has(card_data.definition_id):
		return false
	var definition: Dictionary = _definitions[card_data.definition_id]
	return str(definition.get("category", "")) == card_data.category

func _valid_player_snapshot_fields(data, player_id: String) -> bool:
	if not (data is Dictionary):
		return false
	for field in ["id", "nation", "headquarters"]:
		if typeof(data.get(field, null)) != TYPE_STRING:
			return false
	if data.id != player_id:
		return false
	for field in ["deck", "hand", "support_line", "discard", "active_countermeasures"]:
		if not (data.get(field, null) is Array):
			return false
	for field in ["credit_slots", "credit", "fatigue", "turns_started", "max_hand_size"]:
		if typeof(data.get(field, null)) != TYPE_INT:
			return false
	return typeof(data.get("mulligan_used", null)) == TYPE_BOOL and typeof(data.get("mulligan_confirmed", null)) == TYPE_BOOL

func _valid_snapshot_headquarters(card_id, cards: Dictionary, owner_id: String, headquarters_ids: Dictionary) -> bool:
	if typeof(card_id) != TYPE_STRING or not cards.has(card_id) or headquarters_ids.has(card_id):
		return false
	var card: Dictionary = cards[card_id]
	if card.owner_id != owner_id or card.category != "Headquarters" or card.zone != "headquarters" or card.slot != -1:
		return false
	headquarters_ids[card_id] = true
	return true

func _valid_snapshot_primary_zone(value, cards: Dictionary, owner_id: String, zone: String, primary_card_ids: Dictionary, allow_null: bool) -> bool:
	if not (value is Array):
		return false
	for index in range(value.size()):
		var card_id = value[index]
		if card_id == null:
			if allow_null:
				continue
			return false
		if typeof(card_id) != TYPE_STRING or not cards.has(card_id) or primary_card_ids.has(card_id):
			return false
		var card: Dictionary = cards[card_id]
		if card.category == "Headquarters" or card.zone != zone:
			return false
		if not owner_id.is_empty() and card.owner_id != owner_id:
			return false
		if zone in ["support_line", "frontline"]:
			if card.slot != index:
				return false
		elif card.slot != -1:
			return false
		primary_card_ids[card_id] = true
	return true

func _valid_snapshot_active_countermeasures(value, cards: Dictionary, owner_id: String, hand_ids: Dictionary) -> bool:
	if not (value is Array):
		return false
	var seen := {}
	for card_id in value:
		if typeof(card_id) != TYPE_STRING or seen.has(card_id) or not hand_ids.has(card_id) or not cards.has(card_id):
			return false
		var card: Dictionary = cards[card_id]
		if card.owner_id != owner_id or card.category != "Countermeasure" or card.zone != "hand" \
			or not card.countermeasure_active or not card.face_down:
			return false
		seen[card_id] = true
	return true

func _snapshot_id_set(value: Array) -> Dictionary:
	var ids := {}
	for card_id in value:
		if card_id != null:
			ids[card_id] = true
	return ids

func _valid_card_snapshot(data) -> bool:
	if not (data is Dictionary):
		return false
	for field in ["definition_id", "instance_id", "owner_id", "title", "category", "unit_type", "zone"]:
		if typeof(data.get(field, null)) != TYPE_STRING:
			return false
	if data.has("description") and typeof(data.get("description")) != TYPE_STRING:
		return false
	for field in ["base_attack", "current_attack", "base_defense", "current_defense", "deployment_cost", "operation_cost", "slot", "operations_used", "operation_chain", "deployed_turn", "countermeasure_activation_cost"]:
		if typeof(data.get(field, null)) != TYPE_INT:
			return false
	for field in ["keywords", "abilities", "modifiers", "temporary_statuses"]:
		if not (data.get(field, null) is Array):
			return false
	if not (data.get("statuses", null) is Dictionary):
		return false
	if not _valid_revealed_to(data.get("revealed_to", null)):
		return false
	for field in ["smokescreen_revealed", "face_down", "countermeasure_active"]:
		if typeof(data.get(field, null)) != TYPE_BOOL:
			return false
	return true

func _valid_revealed_to(value) -> bool:
	if not (value is Dictionary):
		return false
	for viewer_id in value:
		if not (viewer_id in ["player", "opponent"]) or typeof(value[viewer_id]) != TYPE_BOOL:
			return false
	return true

func _validate_invariants() -> Dictionary:
	if state == null:
		return {"valid": false, "code": "state_missing"}
	if state.phase == "invalid" and not invalid_diagnostics.is_empty():
		return {"valid": true}
	if not state.players.has("player") or not state.players.has("opponent") or state.players.size() != 2:
		return {"valid": false, "code": "invalid_players"}
	if state.frontline.size() != GameConstants.FRONTLINE_SLOTS:
		return {"valid": false, "code": "invalid_frontline_size"}
	var seen_references := {}
	var seen_instance_ids := {}
	for player_id_value in state.players:
		var player_id := str(player_id_value)
		var player: PlayerState = state.players[player_id]
		if player == null or player.id != player_id:
			return {"valid": false, "code": "invalid_player", "player_id": player_id}
		var headquarters_result := _validate_card_membership(
			player.headquarters, player_id, "headquarters", -1, "headquarters", seen_references, seen_instance_ids
		)
		if not headquarters_result.valid:
			return headquarters_result
		if player.headquarters.category != "Headquarters":
			return {"valid": false, "code": "invalid_headquarters", "player_id": player_id}
		for zone_info in [
			{"cards": player.deck, "zone": "deck", "slots": false},
			{"cards": player.hand, "zone": "hand", "slots": false},
			{"cards": player.support_line, "zone": "support_line", "slots": true},
			{"cards": player.discard, "zone": "discard", "slots": false},
		]:
			var collection_result := _validate_card_collection(
				zone_info.cards,
				player_id,
				str(zone_info.zone),
				bool(zone_info.slots),
				seen_references,
				seen_instance_ids
			)
			if not collection_result.valid:
				return collection_result
		var countermeasure_result := _validate_active_countermeasures(player)
		if not countermeasure_result.valid:
			return countermeasure_result
	var frontline_owner_id := ""
	for slot in range(state.frontline.size()):
		var frontline_card = state.frontline[slot]
		if frontline_card == null:
			continue
		if not state.players.has(frontline_card.owner_id):
			return {"valid": false, "code": "invalid_frontline_owner", "slot": slot}
		var frontline_result := _validate_card_membership(
			frontline_card,
			frontline_card.owner_id,
			"frontline",
			slot,
			"frontline",
			seen_references,
			seen_instance_ids
		)
		if not frontline_result.valid:
			return frontline_result
		if frontline_owner_id.is_empty():
			frontline_owner_id = frontline_card.owner_id
		elif frontline_owner_id != frontline_card.owner_id:
			return {"valid": false, "code": "mixed_frontline_owners"}
	if frontline_owner_id != state.frontline_controller_id:
		return {
			"valid": false,
			"code": "invalid_frontline_controller",
			"expected_controller_id": frontline_owner_id,
			"actual_controller_id": state.frontline_controller_id,
		}
	return _validate_terminal_invariants()

func _synchronize_frontline_controller() -> void:
	var controller_id := ""
	for card in state.frontline:
		if card != null:
			controller_id = card.owner_id
			break
	state.frontline_controller_id = controller_id

func _validate_card_collection(
	cards: Array,
	owner_id: String,
	zone: String,
	uses_slots: bool,
	seen_references: Dictionary,
	seen_instance_ids: Dictionary
) -> Dictionary:
	for index in range(cards.size()):
		var card = cards[index]
		if card == null:
			if uses_slots:
				continue
			return {"valid": false, "code": "null_card", "zone": zone, "index": index}
		var slot := index if uses_slots else -1
		var result := _validate_card_membership(card, owner_id, zone, slot, zone, seen_references, seen_instance_ids)
		if not result.valid:
			return result
	return {"valid": true}

func _validate_card_membership(
	card,
	owner_id: String,
	zone: String,
	slot: int,
	location: String,
	seen_references: Dictionary,
	seen_instance_ids: Dictionary
) -> Dictionary:
	if card == null:
		return {"valid": false, "code": "null_card", "location": location}
	if seen_references.has(card) or seen_instance_ids.has(card.instance_id):
		return {"valid": false, "code": "duplicate_card_reference", "instance_id": card.instance_id}
	seen_references[card] = true
	seen_instance_ids[card.instance_id] = true
	if card.owner_id != owner_id:
		return {"valid": false, "code": "card_owner_mismatch", "instance_id": card.instance_id}
	if card.zone != zone:
		return {"valid": false, "code": "card_zone_mismatch", "instance_id": card.instance_id, "expected_zone": zone, "actual_zone": card.zone}
	if card.slot != slot:
		return {"valid": false, "code": "card_slot_mismatch", "instance_id": card.instance_id, "expected_slot": slot, "actual_slot": card.slot}
	if zone != "headquarters" and card.category == "Headquarters":
		return {"valid": false, "code": "headquarters_in_card_zone", "instance_id": card.instance_id}
	return {"valid": true}

func _validate_active_countermeasures(player: PlayerState) -> Dictionary:
	var seen_references := {}
	for countermeasure in player.active_countermeasures:
		if countermeasure == null or seen_references.has(countermeasure):
			return {"valid": false, "code": "duplicate_active_countermeasure", "player_id": player.id}
		seen_references[countermeasure] = true
		if countermeasure.category != "Countermeasure" \
			or countermeasure.owner_id != player.id \
			or countermeasure.zone != "hand" \
			or not countermeasure.countermeasure_active \
			or not countermeasure.face_down \
			or player.hand.count(countermeasure) != 1:
			return {"valid": false, "code": "invalid_active_countermeasure", "instance_id": countermeasure.instance_id}
	for card in player.hand:
		if card.category == "Countermeasure" and card.countermeasure_active and not seen_references.has(card):
			return {"valid": false, "code": "untracked_active_countermeasure", "instance_id": card.instance_id}
	return {"valid": true}

func _validate_terminal_invariants() -> Dictionary:
	var player: PlayerState = state.players.player
	var opponent: PlayerState = state.players.opponent
	if state.phase == "complete":
		if not state.players.has(state.winner_id):
			return {"valid": false, "code": "terminal_winner_missing"}
		if state.players[state.winner_id].headquarters.current_defense <= 0:
			return {"valid": false, "code": "terminal_headquarters_contradiction"}
		var loser_id := _other_player_id(state.winner_id)
		if state.players[loser_id].headquarters.current_defense != 0:
			return {"valid": false, "code": "terminal_loser_headquarters_not_zero"}
		return {"valid": true}
	if not state.winner_id.is_empty():
		return {"valid": false, "code": "winner_without_complete_phase"}
	if player.headquarters.current_defense <= 0 or opponent.headquarters.current_defense <= 0:
		return {"valid": false, "code": "defeated_headquarters_without_terminal_state"}
	return {"valid": true}

func _cards_state(cards: Array) -> Array:
	var serialized: Array = []
	for card in cards:
		serialized.append(_card_state(card))
	return serialized

func _card_state(card) -> Variant:
	if card == null:
		return null
	return {
		"definition_id": card.definition_id,
		"instance_id": card.instance_id,
		"owner_id": card.owner_id,
		"title": card.title,
		"description": card.description,
		"category": card.category,
		"unit_type": card.unit_type,
		"base_attack": card.base_attack,
		"current_attack": card.current_attack,
		"base_defense": card.base_defense,
		"current_defense": card.current_defense,
		"deployment_cost": card.deployment_cost,
		"operation_cost": card.operation_cost,
		"keywords": card.keywords.duplicate(true),
		"abilities": card.abilities.duplicate(true),
		"zone": card.zone,
		"slot": card.slot,
		"operations_used": card.operations_used,
		"operation_chain": card.operation_chain,
		"smokescreen_revealed": card.smokescreen_revealed,
		"deployed_turn": card.deployed_turn,
		"modifiers": card.modifiers.duplicate(true),
		"statuses": card.statuses.duplicate(true),
		"temporary_statuses": card.temporary_statuses.duplicate(true),
		"revealed_to": card.revealed_to.duplicate(true),
		"face_down": card.face_down,
		"countermeasure_active": card.countermeasure_active,
		"countermeasure_activation_cost": card.countermeasure_activation_cost,
	}

func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var entries: Array = []
		for key in value:
			var key_record := _canonical_key_record(key)
			entries.append({
				"sort_key": JSON.stringify(key_record),
				"key": key_record,
				"value": _canonicalize(value[key]),
			})
		entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.sort_key) < str(right.sort_key)
		)
		var canonical_entries: Array = []
		for entry in entries:
			canonical_entries.append({"key": entry.key, "value": entry.value})
		return {"dictionary_entries": canonical_entries}
	if value is Array:
		var canonical_array: Array = []
		for entry in value:
			canonical_array.append(_canonicalize(entry))
		return canonical_array
	return value

func _canonical_key_record(key: Variant) -> Dictionary:
	var key_value: Variant = key
	if not (key is bool or key is int or key is float or key is String or key == null):
		key_value = str(key)
	return {"type": typeof(key), "value": key_value}

func _dispatch_action(action: GameAction) -> ActionResult:
	match action.type:
		"start_match":
			return _start_match(action)
		"mulligan":
			return _mulligan(action)
		"confirm_mulligan":
			return _confirm_mulligan(action)
		"end_turn":
			return _end_turn(action)
		"deploy_unit":
			return _deploy_unit(action)
		"move_unit":
			return _move_unit(action)
		"attack_unit":
			return _attack_unit(action)
		"attack_hq":
			return _attack_hq(action)
		"play_order":
			return _play_order(action)
		"toggle_countermeasure":
			return _toggle_countermeasure(action)
		"activate_ability":
			return _activate_ability(action)
		"concede":
			return _concede(action)
		_:
			return _reject(action, "unknown_action", "Unknown action")

func _capture_transaction() -> Dictionary:
	var player_snapshots := {}
	var card_snapshots: Array[Dictionary] = []
	var seen_cards := {}
	for player_id in state.players:
		var player: PlayerState = state.players[player_id]
		player_snapshots[player_id] = {
			"deck": player.deck.duplicate(),
			"hand": player.hand.duplicate(),
			"support_line": player.support_line.duplicate(),
			"discard": player.discard.duplicate(),
			"active_countermeasures": player.active_countermeasures.duplicate(),
			"credit_slots": player.credit_slots,
			"credit": player.credit,
			"fatigue": player.fatigue,
			"turns_started": player.turns_started,
			"mulligan_used": player.mulligan_used,
			"mulligan_confirmed": player.mulligan_confirmed,
			"max_hand_size": player.max_hand_size,
		}
		_capture_card(player.headquarters, card_snapshots, seen_cards)
		for collection in [player.deck, player.hand, player.support_line, player.discard, state.frontline]:
			for card in collection:
				_capture_card(card, card_snapshots, seen_cards)
	return {
		"active_player_id": state.active_player_id,
		"starting_player_id": state.starting_player_id,
		"turn": state.turn,
		"frontline": state.frontline.duplicate(),
		"frontline_controller_id": state.frontline_controller_id,
		"winner_id": state.winner_id,
		"rng_state": state.rng_state,
		"rng_internal_state": _rng.state,
		"sequence": state.sequence,
		"phase": state.phase,
		"players": player_snapshots,
		"cards": card_snapshots,
	}

func _capture_card(card, snapshots: Array[Dictionary], seen: Dictionary) -> void:
	if card == null or seen.has(card):
		return
	seen[card] = true
	snapshots.append({
		"card": card,
		"current_attack": card.current_attack,
		"current_defense": card.current_defense,
		"zone": card.zone,
		"slot": card.slot,
		"operations_used": card.operations_used,
		"operation_chain": card.operation_chain,
		"smokescreen_revealed": card.smokescreen_revealed,
		"deployed_turn": card.deployed_turn,
		"modifiers": card.modifiers.duplicate(true),
		"statuses": card.statuses.duplicate(true),
		"temporary_statuses": card.temporary_statuses.duplicate(true),
		"revealed_to": card.revealed_to.duplicate(true),
		"face_down": card.face_down,
		"countermeasure_active": card.countermeasure_active,
		"countermeasure_activation_cost": card.countermeasure_activation_cost,
	})

func _restore_transaction(transaction: Dictionary) -> void:
	state.active_player_id = transaction.active_player_id
	state.starting_player_id = transaction.starting_player_id
	state.turn = transaction.turn
	state.frontline = transaction.frontline.duplicate()
	state.frontline_controller_id = transaction.frontline_controller_id
	state.winner_id = transaction.winner_id
	state.rng_state = transaction.rng_state
	state.sequence = transaction.sequence
	state.phase = transaction.phase
	_rng.state = transaction.rng_internal_state
	for player_id in transaction.players:
		var player: PlayerState = state.players[player_id]
		var snapshot: Dictionary = transaction.players[player_id]
		player.deck = snapshot.deck.duplicate()
		player.hand = snapshot.hand.duplicate()
		player.support_line = snapshot.support_line.duplicate()
		player.discard = snapshot.discard.duplicate()
		player.active_countermeasures = snapshot.active_countermeasures.duplicate()
		player.credit_slots = snapshot.credit_slots
		player.credit = snapshot.credit
		player.fatigue = snapshot.fatigue
		player.turns_started = snapshot.turns_started
		player.mulligan_used = snapshot.mulligan_used
		player.mulligan_confirmed = snapshot.mulligan_confirmed
		player.max_hand_size = snapshot.max_hand_size
	for snapshot in transaction.cards:
		var card = snapshot.card
		card.current_attack = snapshot.current_attack
		card.current_defense = snapshot.current_defense
		card.zone = snapshot.zone
		card.slot = snapshot.slot
		card.operations_used = snapshot.operations_used
		card.operation_chain = snapshot.operation_chain
		card.smokescreen_revealed = snapshot.smokescreen_revealed
		card.deployed_turn = snapshot.deployed_turn
		card.modifiers = snapshot.modifiers.duplicate(true)
		card.statuses = snapshot.statuses.duplicate(true)
		card.temporary_statuses = snapshot.temporary_statuses.duplicate(true)
		card.revealed_to = snapshot.revealed_to.duplicate(true)
		card.face_down = snapshot.face_down
		card.countermeasure_active = snapshot.countermeasure_active
		card.countermeasure_activation_cost = snapshot.countermeasure_activation_cost
	_effect_engine.reset_after_rollback()

func _create_player(player_id: String, instance_prefix: String, deck_ids: Array) -> PlayerState:
	var cards: Array = []
	var headquarters: CardInstance = CardInstance.headquarters("", player_id, "%s-hq" % instance_prefix)
	var nation := ""
	for index in range(deck_ids.size()):
		var definition_id := str(deck_ids[index])
		var definition: Dictionary = _definitions.get(definition_id, {})
		var instance_id := "%s-%03d" % [instance_prefix, index]
		if str(definition.get("category", "")) == "Headquarters":
			headquarters = CardInstance.headquarters(definition_id, player_id, instance_id, definition)
			nation = str(definition.get("nation", ""))
			continue
		var card := CardInstance.from_definition(definition, player_id, instance_id)
		card.zone = "deck"
		cards.append(card)
	return PlayerState.create(player_id, nation, headquarters, cards)

func _start_match(action: GameAction) -> ActionResult:
	if state.phase != "setup":
		return _reject(action, "invalid_phase", "Match already started")
	if action.actor_id != "system":
		return _reject(action, "invalid_actor", "Only the system starts a match")
	state.starting_player_id = "player" if _rng.randi_range(0, 1) == 0 else "opponent"
	state.rng_state = _rng.state
	var events: Array = []
	var starting_player: PlayerState = state.players[state.starting_player_id]
	var other_player: PlayerState = state.players[_other_player_id(state.starting_player_id)]
	_draw_opening_cards(starting_player, 4, events)
	_draw_opening_cards(other_player, 5, events)
	state.phase = "mulligan"
	return _accept(action, events)

func _mulligan(action: GameAction) -> ActionResult:
	if state.phase != "mulligan":
		return _reject(action, "invalid_phase", "Mulligan is not available")
	if not state.players.has(action.actor_id):
		return _reject(action, "invalid_actor", "Unknown player")
	var player: PlayerState = state.players[action.actor_id]
	if player.mulligan_confirmed:
		return _reject(action, "mulligan_confirmed", "Mulligan already confirmed")
	if player.mulligan_used:
		return _reject(action, "mulligan_used", "Mulligan already used")
	var selected_cards: Array = []
	var selected_ids := {}
	for selected_id_value in action.target_ids:
		var selected_id := str(selected_id_value)
		if selected_ids.has(selected_id):
			return _reject(action, "invalid_selection", "Duplicate mulligan selection")
		selected_ids[selected_id] = true
		var selected_card = _card_in_hand(player, selected_id)
		if selected_card == null:
			return _reject(action, "invalid_selection", "Mulligan card is not in hand")
		selected_cards.append(selected_card)

	if selected_cards.is_empty():
		player.mulligan_used = true
		return _accept(action)

	var events: Array = []
	for card in selected_cards:
		player.hand.erase(card)
		card.zone = "deck"
		player.deck.append(card)
		_emit(events, "card_returned", {"player_id": player.id, "instance_id": card.instance_id})
	_shuffle_deck(player.deck)
	_emit(events, "deck_shuffled", {"player_id": player.id})
	for ignored in selected_cards:
		_draw_card(player, events)
	player.mulligan_used = true
	return _accept(action, events)

func _confirm_mulligan(action: GameAction) -> ActionResult:
	if state.phase != "mulligan":
		return _reject(action, "invalid_phase", "Mulligan is not available")
	if not state.players.has(action.actor_id):
		return _reject(action, "invalid_actor", "Unknown player")
	var player: PlayerState = state.players[action.actor_id]
	if player.mulligan_confirmed:
		return _reject(action, "already_confirmed", "Mulligan already confirmed")
	player.mulligan_confirmed = true
	var events: Array = []
	if _both_mulligans_confirmed():
		state.phase = "action"
		state.active_player_id = state.starting_player_id
		_start_turn(state.players[state.active_player_id], events)
	return _accept(action, events)

func _end_turn(action: GameAction) -> ActionResult:
	if state.phase != "action":
		return _reject(action, "invalid_phase", "Turn actions are not available")
	if action.actor_id != state.active_player_id:
		return _reject(action, "not_active_player", "Only the active player can end the turn")
	var events: Array = []
	var player: PlayerState = state.players[action.actor_id]
	var next_player_id := _other_player_id(player.id)
	var next_player: PlayerState = state.players[next_player_id]
	_resolve_trigger("turn_end", {"player_id": player.id}, events)
	if _is_terminal():
		return _accept(action, events)
	_expire_temporary_modifiers(player, events)
	if _is_terminal():
		return _accept(action, events)
	next_player.deactivate_countermeasures()
	_emit(events, "turn_ended", {"player_id": player.id, "turn": state.turn})
	state.active_player_id = next_player_id
	_start_turn(next_player, events)
	return _accept(action, events)

func _concede(action: GameAction) -> ActionResult:
	# A player may concede from the action or mulligan phase. The conceding
	# player loses immediately; the opponent is declared the winner and the
	# match enters the complete phase. The conceding player's Headquarters is
	# reduced to zero so the existing terminal invariants (loser HQ at 0)
	# hold and replays stay deterministic alongside natural HQ defeats.
	if _is_terminal():
		return _reject(action, "match_complete", "Match is already complete")
	if not state.players.has(action.actor_id):
		return _reject(action, "invalid_actor", "Unknown player cannot concede")
	var conceding: PlayerState = state.players[action.actor_id]
	var events: Array = []
	_emit(events, "player_conceded", {"player_id": action.actor_id})
	# Drop the conceding HQ to zero so the shared terminal invariants
	# (loser Headquarters at 0, winner still standing) hold, matching the
	# natural Headquarters-defeat end state.
	conceding.headquarters.current_defense = 0
	state.winner_id = _other_player_id(action.actor_id)
	state.phase = "complete"
	_emit(events, "match_ended", {
		"winner_id": state.winner_id,
		"loser_id": action.actor_id,
		"reason": "concede",
	})
	return _accept(action, events)

func _deploy_unit(action: GameAction) -> ActionResult:
	var context := _validate_turn_action(action)
	if not context.valid:
		return _reject_rule(action, context)
	var player: PlayerState = state.players[action.actor_id]
	var card: CardInstance = _card_in_hand(player, action.source_id)
	if card == null:
		return _reject(action, "source_not_in_hand", "Unit is not in hand")
	if card.category != "Unit":
		return _reject(action, "invalid_card_type", "Only Units deploy to the Support Line")
	if _occupied_count(player.support_line) >= GameConstants.SUPPORT_UNIT_SLOTS:
		return _reject(action, "support_line_full", "Support Line is full")
	if not action.payload.has("support_slot") or typeof(action.payload.support_slot) != TYPE_INT:
		return _reject(action, "invalid_slot", "Support slot is invalid")
	var slot: int = action.payload.support_slot
	if slot < 0 or slot >= GameConstants.SUPPORT_UNIT_SLOTS:
		return _reject(action, "invalid_slot", "Support slot is invalid")
	if player.support_line[slot] != null:
		return _reject(action, "slot_occupied", "Support slot is occupied")
	if player.credit < card.deployment_cost:
		return _reject(action, "insufficient_credit", "Not enough Credit")
	var deploy_validation := _effect_engine.validate_trigger("deploy", {
		"source_id": card.instance_id,
		"actor_id": player.id,
		"target_ids": action.target_ids.duplicate(),
	})
	if not deploy_validation.valid:
		return _reject_rule(action, deploy_validation)

	var events: Array = []
	_spend_credit(player, card.deployment_cost, "deployment", card.instance_id, events)
	player.hand.erase(card)
	player.support_line[slot] = card
	card.zone = "support_line"
	card.slot = slot
	card.deployed_turn = state.turn
	card.reset_operation_state()
	_emit(events, "card_deployed", {
		"player_id": player.id,
		"instance_id": card.instance_id,
		"zone": "support_line",
		"slot": slot,
	})
	_resolve_trigger("deploy", {"source_id": card.instance_id, "actor_id": player.id, "target_ids": action.target_ids.duplicate()}, events)
	if not _effect_engine.last_resolution.valid:
		return _reject_rule(action, _effect_engine.last_resolution)
	return _accept(action, events)

func _move_unit(action: GameAction) -> ActionResult:
	var context := _validate_turn_action(action)
	if not context.valid:
		return _reject_rule(action, context)
	var unit: CardInstance = CombatRules.find_card(state, action.source_id)
	if unit == null:
		return _reject(action, "card_not_found", "Unit was not found")
	if unit.owner_id != action.actor_id:
		return _reject(action, "not_owner", "Unit belongs to another player")
	if str(action.payload.get("zone", "")) != "frontline":
		return _reject(action, "invalid_destination", "Units only move to the Frontline")
	if not action.payload.has("slot") or typeof(action.payload.slot) != TYPE_INT:
		return _reject(action, "invalid_slot", "Frontline slot is invalid")
	var slot: int = action.payload.slot
	var validation := CombatRules.validate_move_to_frontline(state, unit.instance_id, slot)
	if not validation.valid:
		return _reject_rule(action, validation)

	var events: Array = []
	var player: PlayerState = state.players[action.actor_id]
	_spend_credit(player, unit.operation_cost, "operation", unit.instance_id, events)
	unit.operations_used += 1
	unit.smokescreen_revealed = true
	unit.operation_chain = CardInstance.OperationChain.TANK_ADVANCE \
		if CombatRules.opens_tank_advance(unit) else CardInstance.OperationChain.NONE
	var from_slot := unit.slot
	player.support_line[from_slot] = null
	state.frontline[slot] = unit
	unit.zone = "frontline"
	unit.slot = slot
	_emit(events, "unit_moved", {
		"player_id": player.id,
		"instance_id": unit.instance_id,
		"from_zone": "support_line",
		"from_slot": from_slot,
		"to_zone": "frontline",
		"to_slot": slot,
	})
	_resolve_trigger("move", {
		"source_id": unit.instance_id,
		"actor_id": player.id,
		"target_ids": [],
	}, events)
	if _is_terminal() or not _is_current_frontline_unit(unit, slot):
		return _accept(action, events)
	_update_frontline_control(events, unit, player.id)
	return _accept(action, events)

func _play_order(action: GameAction) -> ActionResult:
	var validation := _validate_turn_action(action)
	if not validation.valid:
		return _reject_rule(action, validation)
	var player: PlayerState = state.players[action.actor_id]
	var order: CardInstance = _card_in_hand(player, action.source_id)
	if order == null:
		return _reject(action, "source_not_in_hand", "Order is not in hand")
	if order.category != "Order":
		return _reject(action, "invalid_card_type", "Only Orders can be played")
	if player.credit < order.deployment_cost:
		return _reject(action, "insufficient_credit", "Not enough Credit")
	var context := {
		"source_id": order.instance_id,
		"actor_id": player.id,
		"target_ids": action.target_ids.duplicate(),
	}
	var effect_validation := _effect_engine.validate_trigger("play_order", context)
	if not effect_validation.valid:
		return _reject_rule(action, effect_validation)
	var pending_event := {
		"type": "order_played",
		"order_id": order.instance_id,
		"actor_id": player.id,
		"target_ids": action.target_ids.duplicate(),
		"cancelled": false,
	}
	var counter_context := {
		"source_id": order.instance_id,
		"actor_id": player.id,
		"target_ids": action.target_ids.duplicate(),
		"event": pending_event,
	}
	var counter_validation := _effect_engine.validate_trigger("order_played", counter_context)
	if not counter_validation.valid:
		return _reject_rule(action, counter_validation)

	var events: Array = []
	_spend_credit(player, order.deployment_cost, "order", order.instance_id, events)
	_emit(events, "order_played", pending_event)
	var counter_events := _effect_engine.resolve_trigger("order_played", counter_context)
	events.append_array(counter_events)
	if not _effect_engine.last_resolution.valid:
		return _reject_rule(action, _effect_engine.last_resolution)
	if _is_terminal() or bool(pending_event.get("cancelled", false)) or not _can_continue_order(player, order, context):
		_finalize_order(player, order, events)
		return _accept(action, events)
	if not bool(pending_event.get("cancelled", false)):
		events.append_array(_effect_engine.resolve_trigger("play_order", context))
		if not _effect_engine.last_resolution.valid:
			return _reject_rule(action, _effect_engine.last_resolution)
	_finalize_order(player, order, events)
	return _accept(action, events)


func _toggle_countermeasure(action: GameAction) -> ActionResult:
	var validation := _validate_turn_action(action)
	if not validation.valid:
		return _reject_rule(action, validation)
	var player: PlayerState = state.players[action.actor_id]
	var countermeasure: CardInstance = _card_in_hand(player, action.source_id)
	if countermeasure == null:
		return _reject(action, "source_not_in_hand", "Countermeasure is not in hand")
	if countermeasure.category != "Countermeasure":
		return _reject(action, "invalid_card_type", "Only Countermeasures can be activated")
	var events: Array = []
	if countermeasure.countermeasure_active:
		countermeasure.countermeasure_active = false
		player.active_countermeasures.erase(countermeasure)
		player.credit += countermeasure.countermeasure_activation_cost
		_emit(events, "credit_refunded", {
			"player_id": player.id,
			"source_id": countermeasure.instance_id,
			"amount": countermeasure.countermeasure_activation_cost,
			"credit": player.credit,
		})
		countermeasure.countermeasure_activation_cost = 0
		_emit(events, "countermeasure_deactivated", {"player_id": player.id, "instance_id": countermeasure.instance_id})
		return _accept(action, events)
	if player.credit < countermeasure.deployment_cost:
		return _reject(action, "insufficient_credit", "Not enough Credit")
	countermeasure.countermeasure_activation_cost = countermeasure.deployment_cost
	_spend_credit(player, countermeasure.countermeasure_activation_cost, "countermeasure", countermeasure.instance_id, events)
	countermeasure.countermeasure_active = true
	countermeasure.face_down = true
	player.active_countermeasures.append(countermeasure)
	_emit(events, "countermeasure_activated", {"player_id": player.id, "instance_id": countermeasure.instance_id})
	return _accept(action, events)


func _activate_ability(action: GameAction) -> ActionResult:
	var validation := _validate_turn_action(action)
	if not validation.valid:
		return _reject_rule(action, validation)
	var source: CardInstance = CombatRules.find_card(state, action.source_id)
	if source == null:
		return _reject(action, "card_not_found", "Ability source was not found")
	if source.owner_id != action.actor_id:
		return _reject(action, "not_owner", "Ability source belongs to another player")
	var ability_id := str(action.payload.get("ability_id", ""))
	var ability: Dictionary = {}
	for candidate_value in source.abilities:
		var candidate: Dictionary = candidate_value
		if str(candidate.get("id", "")) == ability_id and str(candidate.get("trigger", "")) == "manual":
			ability = candidate
			break
	if ability.is_empty():
		return _reject(action, "ability_not_found", "Manual ability was not found")
	var allowed_zones: Array = ability.get("allowed_zones", ["support_line", "frontline"])
	if not (source.zone in allowed_zones):
		return _reject(action, "invalid_origin", "Ability source is not on the battlefield")
	var player: PlayerState = state.players[action.actor_id]
	var credit_cost := int(ability.get("credit_cost", 0))
	if player.credit < credit_cost:
		return _reject(action, "insufficient_credit", "Not enough Credit")
	var context := {
		"source_id": source.instance_id,
		"actor_id": player.id,
		"target_ids": action.target_ids.duplicate(),
		"ability_id": ability_id,
	}
	var effect_validation := _effect_engine.validate_trigger("manual", context)
	if not effect_validation.valid:
		return _reject_rule(action, effect_validation)
	var events: Array = []
	_spend_credit(player, credit_cost, "ability", source.instance_id, events)
	events.append_array(_effect_engine.resolve_trigger("manual", context))
	if not _effect_engine.last_resolution.valid:
		return _reject_rule(action, _effect_engine.last_resolution)
	return _accept(action, events)

func _attack_unit(action: GameAction) -> ActionResult:
	var context := _validate_turn_action(action)
	if not context.valid:
		return _reject_rule(action, context)
	if action.target_ids.size() != 1:
		return _reject(action, "invalid_target", "Attack requires one unit target")
	var attacker: CardInstance = CombatRules.find_card(state, action.source_id)
	if attacker == null:
		return _reject(action, "card_not_found", "Attacker was not found")
	if attacker.owner_id != action.actor_id:
		return _reject(action, "not_owner", "Attacker belongs to another player")
	var defender_id := str(action.target_ids[0])
	var validation := CombatRules.validate_unit_attack(state, attacker.instance_id, defender_id)
	if not validation.valid:
		return _reject_rule(action, validation)
	var defender: CardInstance = CombatRules.find_card(state, defender_id)
	var pending_event := {"type": "attack", "actor_id": action.actor_id, "target_ids": action.target_ids.duplicate(), "cancelled": false}
	var reaction_context := {"source_id": attacker.instance_id, "actor_id": action.actor_id, "target_ids": action.target_ids.duplicate(), "event": pending_event}
	var reaction_validation := _effect_engine.validate_trigger("attack", reaction_context)
	if not reaction_validation.valid:
		return _reject_rule(action, reaction_validation)

	var uses_tank_chain := CombatRules.attack_uses_tank_chain(attacker)
	var events: Array = []
	_reserve_attack_operation(attacker, events)
	_emit(events, "attack_started", {
		"attacker_id": attacker.instance_id,
		"defender_id": defender.instance_id,
		"target_type": "unit",
	})
	_resolve_trigger("attack", reaction_context, events)
	if not _effect_engine.last_resolution.valid:
		return _reject_rule(action, _effect_engine.last_resolution)
	if _is_terminal() or bool(pending_event.get("cancelled", false)) \
		or not _can_continue_unit_attack(attacker, defender, uses_tank_chain):
		return _accept(action, events)
	_resolve_trigger("defend", {
		"source_id": defender.instance_id,
		"actor_id": action.actor_id,
		"target_ids": [attacker.instance_id],
		"event": pending_event,
	}, events)
	if not _effect_engine.last_resolution.valid:
		return _reject_rule(action, _effect_engine.last_resolution)
	if _is_terminal() or bool(pending_event.get("cancelled", false)) \
		or not _can_continue_unit_attack(attacker, defender, uses_tank_chain):
		return _accept(action, events)
	var ambush := CombatRules.receives_counterattack(attacker) and CombatRules.is_ambush(defender)
	if ambush:
		_deal_combat_damage(defender, attacker, defender.current_attack, "ambush", events)
		if _is_terminal() or not _can_continue_unit_attack(attacker, defender, uses_tank_chain):
			return _accept(action, events)
		var attacker_left_frontline := _destroy_if_dead(attacker, events)
		if _is_terminal():
			return _accept(action, events)
		if attacker.current_defense <= 0:
			_update_frontline_control(events, attacker if attacker_left_frontline else null, action.actor_id)
			return _accept(action, events)
		if not _is_current_battlefield_unit(attacker):
			return _accept(action, events)

	var resolves_retaliation := not ambush and CombatRules.receives_counterattack(attacker)
	_deal_combat_damage(attacker, defender, attacker.current_attack, "attack", events)
	if _is_terminal() or not _can_continue_unit_attack(attacker, defender, uses_tank_chain):
		return _accept(action, events)
	if resolves_retaliation:
		_deal_combat_damage(defender, attacker, defender.current_attack, "counterattack", events)
		if _is_terminal() or not _can_continue_unit_attack(attacker, defender, uses_tank_chain):
			return _accept(action, events)
	var defender_left_frontline := _destroy_if_dead(defender, events)
	if _is_terminal() or not _is_current_battlefield_unit(attacker):
		return _accept(action, events)
	var attacker_left_frontline := _destroy_if_dead(attacker, events)
	if _is_terminal():
		return _accept(action, events)
	var frontline_source: CardInstance = defender if defender_left_frontline else attacker if attacker_left_frontline else null
	_update_frontline_control(events, frontline_source, action.actor_id)
	return _accept(action, events)

func _attack_hq(action: GameAction) -> ActionResult:
	var context := _validate_turn_action(action)
	if not context.valid:
		return _reject_rule(action, context)
	var attacker: CardInstance = CombatRules.find_card(state, action.source_id)
	if attacker == null:
		return _reject(action, "card_not_found", "Attacker was not found")
	if attacker.owner_id != action.actor_id:
		return _reject(action, "not_owner", "Attacker belongs to another player")
	if action.target_ids.size() > 1:
		return _reject(action, "invalid_target", "Attack requires at most one Headquarters target")
	var defender_player_id := ""
	if action.target_ids.size() == 1:
		var headquarters: CardInstance = CombatRules.find_card(state, str(action.target_ids[0]))
		if headquarters == null or headquarters.category != "Headquarters":
			return _reject(action, "invalid_target", "Attack target must be a Headquarters")
		defender_player_id = headquarters.owner_id
		var payload_player_id := str(action.payload.get("target_player_id", ""))
		if not payload_player_id.is_empty() and payload_player_id != defender_player_id:
			return _reject(action, "invalid_target", "Headquarters target conflicts with payload")
	else:
		defender_player_id = str(action.payload.get("target_player_id", ""))
	var validation := CombatRules.validate_hq_attack(state, attacker.instance_id, defender_player_id)
	if not validation.valid:
		return _reject_rule(action, validation)
	var defender: PlayerState = state.players[defender_player_id]
	var pending_event := {
		"type": "attack",
		"actor_id": action.actor_id,
		"target_ids": [defender.headquarters.instance_id],
		"cancelled": false,
	}
	var reaction_context := {
		"source_id": attacker.instance_id,
		"actor_id": action.actor_id,
		"target_ids": [defender.headquarters.instance_id],
		"event": pending_event,
	}
	var reaction_validation := _effect_engine.validate_trigger("attack", reaction_context)
	if not reaction_validation.valid:
		return _reject_rule(action, reaction_validation)

	var uses_tank_chain := CombatRules.attack_uses_tank_chain(attacker)
	var events: Array = []
	_reserve_attack_operation(attacker, events)
	_emit(events, "attack_started", {
		"attacker_id": attacker.instance_id,
		"defender_id": defender.headquarters.instance_id,
		"target_type": "headquarters",
	})
	_resolve_trigger("attack", reaction_context, events)
	if not _effect_engine.last_resolution.valid:
		return _reject_rule(action, _effect_engine.last_resolution)
	if _is_terminal() or bool(pending_event.get("cancelled", false)) \
		or not _can_continue_hq_attack(attacker, defender.id, uses_tank_chain):
		return _accept(action, events)
	_resolve_trigger("defend", {
		"source_id": defender.headquarters.instance_id,
		"actor_id": action.actor_id,
		"target_ids": [attacker.instance_id],
		"event": pending_event,
	}, events)
	if not _effect_engine.last_resolution.valid:
		return _reject_rule(action, _effect_engine.last_resolution)
	if _is_terminal() or bool(pending_event.get("cancelled", false)) \
		or not _can_continue_hq_attack(attacker, defender.id, uses_tank_chain):
		return _accept(action, events)
	_deal_combat_damage(attacker, defender.headquarters, attacker.current_attack, "attack", events)
	if defender.headquarters.current_defense <= 0:
		_resolve_headquarters_lethal(defender.headquarters, action.actor_id, events)
		if not _effect_engine.last_resolution.valid:
			return _reject_rule(action, _effect_engine.last_resolution)
	return _accept(action, events)

func _draw_opening_cards(player: PlayerState, count: int, events: Array) -> void:
	for index in range(count):
		_draw_card(player, events)
		if _is_terminal():
			return

func _draw_card(player: PlayerState, events: Array) -> void:
	if _is_terminal():
		return
	if player.deck.is_empty():
		var damage := player.fatigue
		player.headquarters.current_defense = maxi(0, player.headquarters.current_defense - damage)
		player.fatigue += 1
		_emit(events, "fatigue_damage", {"player_id": player.id, "damage": damage})
		_resolve_trigger("damage", {
			"source_id": player.headquarters.instance_id,
			"actor_id": player.id,
			"target_ids": [player.headquarters.instance_id],
		}, events)
		if player.headquarters.current_defense <= 0:
			_resolve_headquarters_lethal(player.headquarters, player.id, events)
		return
	var card: CardInstance = player.deck.pop_back()
	if player.hand.size() >= GameConstants.MAX_HAND_SIZE:
		card.zone = "discard"
		player.discard.append(card)
		_emit(events, "card_overdrawn", {"player_id": player.id, "instance_id": card.instance_id})
		_resolve_trigger("discard", {"source_id": card.instance_id, "actor_id": player.id, "target_ids": []}, events)
		return
	card.zone = "hand"
	player.hand.append(card)
	_emit(events, "card_drawn", {"player_id": player.id, "instance_id": card.instance_id})
	_resolve_trigger("draw", {"source_id": card.instance_id, "actor_id": player.id, "target_ids": []}, events)

func _start_turn(player: PlayerState, events: Array) -> void:
	if _is_terminal():
		return
	state.turn += 1
	for card in player.hand:
		card.revealed_to.clear()
	player.turns_started += 1
	_emit(events, "turn_started", {"player_id": player.id, "turn": state.turn})
	var previous_credit_slots := player.credit_slots
	player.credit_slots = mini(GameConstants.MAX_CREDITS, player.credit_slots + 1)
	if player.credit_slots != previous_credit_slots:
		_emit(events, "credit_slots_changed", {"player_id": player.id, "credit_slots": player.credit_slots})
	player.credit = player.credit_slots
	player.reset_operations()
	for card in player.support_line:
		if card != null:
			card.reset_operation_state()
	for card in state.frontline:
		if card != null and card.owner_id == player.id:
			card.reset_operation_state()
	_emit(events, "credit_refilled", {"player_id": player.id, "credit": player.credit})
	_draw_card(player, events)
	if _is_terminal():
		return
	_resolve_trigger("turn_start", {"player_id": player.id}, events)

func debug_draw(player_id: String) -> Array:
	if not state.players.has(player_id):
		return []
	var events: Array = []
	_draw_card(state.players[player_id], events)
	return events

func debug_set_trigger_hook(hook: Callable) -> void:
	_debug_trigger_hook = hook

func debug_set_modifier_expiry_hook(hook: Callable) -> void:
	_debug_modifier_expiry_hook = hook

func _validate_turn_action(action: GameAction) -> Dictionary:
	if _is_terminal():
		return {"valid": false, "code": "match_complete"}
	if state.phase != "action":
		return {"valid": false, "code": "invalid_phase"}
	if not state.players.has(action.actor_id):
		return {"valid": false, "code": "invalid_actor"}
	if action.actor_id != state.active_player_id:
		return {"valid": false, "code": "not_active_player"}
	return {"valid": true}

func _reserve_attack_operation(attacker: CardInstance, events: Array) -> void:
	attacker.smokescreen_revealed = true
	if CombatRules.attack_uses_tank_chain(attacker):
		attacker.operation_chain = CardInstance.OperationChain.NONE
		return
	_spend_credit(
		state.players[attacker.owner_id],
		attacker.operation_cost,
		"operation",
		attacker.instance_id,
		events
	)
	attacker.operations_used += 1
	attacker.operation_chain = CardInstance.OperationChain.NONE

func _spend_credit(player: PlayerState, amount: int, reason: String, source_id: String, events: Array) -> void:
	player.credit -= amount
	if amount <= 0:
		return
	_emit(events, "credit_spent", {
		"player_id": player.id,
		"source_id": source_id,
		"amount": amount,
		"reason": reason,
		"credit": player.credit,
	})

func _deal_combat_damage(
	source: CardInstance,
	target: CardInstance,
	base_damage: int,
	damage_type: String,
	events: Array
) -> void:
	var reduction := 1 if CombatRules.reduces_damage(target) else 0
	var damage := maxi(0, base_damage - reduction)
	target.current_defense = maxi(0, target.current_defense - damage)
	_emit(events, "damage_dealt", {
		"source_id": source.instance_id,
		"target_id": target.instance_id,
		"damage": damage,
		"damage_type": damage_type,
		"remaining_defense": target.current_defense,
	})
	_resolve_trigger("damage", {
		"source_id": target.instance_id,
		"actor_id": source.owner_id,
		"target_ids": [source.instance_id],
	}, events)

func _destroy_if_dead(card: CardInstance, events: Array) -> bool:
	if card.current_defense > 0 or card.zone == "discard" or card.category != "Unit":
		return false
	var left_frontline := card.zone == "frontline"
	var player: PlayerState = state.players[card.owner_id]
	if card.zone == "support_line":
		if card.slot >= 0 and card.slot < player.support_line.size() and player.support_line[card.slot] == card:
			player.support_line[card.slot] = null
	elif card.zone == "frontline":
		if card.slot >= 0 and card.slot < state.frontline.size() and state.frontline[card.slot] == card:
			state.frontline[card.slot] = null
	card.zone = "discard"
	card.slot = -1
	card.operation_chain = CardInstance.OperationChain.NONE
	player.discard.append(card)
	_emit(events, "card_destroyed", {
		"player_id": player.id,
		"instance_id": card.instance_id,
	})
	_resolve_trigger("death", {"source_id": card.instance_id, "actor_id": card.owner_id, "target_ids": []}, events)
	return left_frontline

func _update_frontline_control(events: Array, source: CardInstance = null, actor_id: String = "") -> void:
	var controller_id := ""
	for card in state.frontline:
		if card != null:
			controller_id = card.owner_id
			break
	if controller_id == state.frontline_controller_id:
		return
	var previous_controller := state.frontline_controller_id
	state.frontline_controller_id = controller_id
	_emit(events, "frontline_changed", {
		"previous_controller_id": previous_controller,
		"controller_id": controller_id,
	})
	if source == null:
		return
	if not previous_controller.is_empty():
		_resolve_trigger("frontline_lost", {
			"source_id": source.instance_id,
			"actor_id": actor_id,
			"target_ids": [source.instance_id],
		}, events)
	if not controller_id.is_empty():
		_resolve_trigger("frontline_gained", {
			"source_id": source.instance_id,
			"actor_id": actor_id,
			"target_ids": [source.instance_id],
		}, events)

func _occupied_count(cards: Array) -> int:
	var count := 0
	for card in cards:
		if card != null:
			count += 1
	return count

func _reject_rule(action: GameAction, validation: Dictionary) -> ActionResult:
	var code := str(validation.get("code", "invalid_action"))
	return _reject(action, code, code.replace("_", " ").capitalize())

func _resolve_trigger(trigger: String, context: Dictionary, events: Array) -> void:
	if _is_terminal():
		return
	if _debug_trigger_hook.is_valid():
		_debug_trigger_hook.call(trigger, context, events)
	if _effect_engine != null:
		events.append_array(_effect_engine.resolve_trigger(trigger, context))

func _expire_temporary_modifiers(player: PlayerState, events: Array = []) -> void:
	if _is_terminal():
		return
	if _debug_modifier_expiry_hook.is_valid():
		_debug_modifier_expiry_hook.call(player.id)
	if _is_terminal():
		return
	var frontline_source: CardInstance = null
	for card in _all_cards():
		for modifier in card.expire_temporary_modifiers(player.id):
			_emit(events, "modifier_expired", {
				"instance_id": card.instance_id,
				"source_id": str(modifier.get("source_id", "")),
			})
		var left_frontline := _destroy_if_dead(card, events)
		if left_frontline:
			frontline_source = card
		if card.category == "Headquarters" and card.current_defense <= 0:
			_resolve_headquarters_lethal(card, player.id, events)
		if _is_terminal():
			return
	_update_frontline_control(events, frontline_source, player.id)

func _expire_temporary_statuses(duration: String) -> void:
	for card in _all_cards():
		card.expire_temporary_statuses(duration)

func _can_continue_order(player: PlayerState, order: CardInstance, context: Dictionary) -> bool:
	if order.zone != "hand" or not player.hand.has(order):
		return false
	return _effect_engine.validate_trigger("play_order", context).valid

func _finalize_order(player: PlayerState, order: CardInstance, events: Array) -> void:
	if order.zone != "hand" or not player.hand.has(order):
		return
	player.hand.erase(order)
	order.zone = "discard"
	order.slot = -1
	if not player.discard.has(order):
		player.discard.append(order)
	_emit(events, "card_discarded", {"player_id": player.id, "instance_id": order.instance_id})
	_resolve_trigger("discard", {"source_id": order.instance_id, "actor_id": player.id, "target_ids": []}, events)

func _can_continue_unit_attack(attacker: CardInstance, defender: CardInstance, uses_tank_chain: bool) -> bool:
	if CombatRules.find_card(state, attacker.instance_id) != attacker \
		or CombatRules.find_card(state, defender.instance_id) != defender:
		return false
	return _validate_reserved_attack(attacker, uses_tank_chain, func() -> Dictionary:
		return CombatRules.validate_unit_attack(state, attacker.instance_id, defender.instance_id)
	)

func _is_current_battlefield_unit(card: CardInstance) -> bool:
	return CombatRules.find_card(state, card.instance_id) == card \
		and card.zone in ["support_line", "frontline"]

func _is_current_frontline_unit(card: CardInstance, slot: int) -> bool:
	return _is_current_battlefield_unit(card) \
		and card.zone == "frontline" \
		and card.slot == slot \
		and slot >= 0 and slot < state.frontline.size() \
		and state.frontline[slot] == card

func _can_continue_hq_attack(attacker: CardInstance, defender_player_id: String, uses_tank_chain: bool) -> bool:
	if CombatRules.find_card(state, attacker.instance_id) != attacker:
		return false
	return _validate_reserved_attack(attacker, uses_tank_chain, func() -> Dictionary:
		return CombatRules.validate_hq_attack(state, attacker.instance_id, defender_player_id)
	)

func _validate_reserved_attack(attacker: CardInstance, uses_tank_chain: bool, validator: Callable) -> bool:
	var player: PlayerState = state.players[attacker.owner_id]
	var operations_used := attacker.operations_used
	var operation_chain := attacker.operation_chain
	var credit := player.credit
	if uses_tank_chain:
		attacker.operation_chain = CardInstance.OperationChain.TANK_ADVANCE
	else:
		attacker.operations_used = maxi(0, attacker.operations_used - 1)
		player.credit += attacker.operation_cost
	var validation: Dictionary = validator.call()
	attacker.operations_used = operations_used
	attacker.operation_chain = operation_chain
	player.credit = credit
	return validation.valid

func _resolve_headquarters_lethal(headquarters: CardInstance, actor_id: String, events: Array) -> void:
	if headquarters.current_defense > 0 or _is_terminal():
		return
	_resolve_trigger("hq_lethal", {
		"source_id": headquarters.instance_id,
		"actor_id": actor_id,
		"target_ids": [headquarters.instance_id],
	}, events)
	if not _effect_engine.last_resolution.valid or headquarters.current_defense > 0 or _is_terminal():
		return
	var defender: PlayerState = state.players[headquarters.owner_id]
	_check_headquarters_death(defender)
	if _is_terminal():
		_emit(events, "match_ended", {"winner_id": state.winner_id, "loser_id": defender.id})

func _all_cards() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	var seen := {}
	for player_id in state.players:
		var player: PlayerState = state.players[player_id]
		if not seen.has(player.headquarters):
			seen[player.headquarters] = true
			cards.append(player.headquarters)
		for collection in [player.deck, player.hand, player.support_line, player.discard, state.frontline]:
			for card in collection:
				if card != null and not seen.has(card):
					seen[card] = true
					cards.append(card)
	return cards

func _check_headquarters_death(player: PlayerState) -> void:
	if player.headquarters.current_defense > 0 or _is_terminal():
		return
	state.winner_id = _other_player_id(player.id)
	state.phase = "complete"

func _is_terminal() -> bool:
	return state.phase == "complete" or state.phase == "invalid" or not state.winner_id.is_empty()

func _shuffle_deck(deck: Array) -> void:
	for index in range(deck.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var card = deck[index]
		deck[index] = deck[swap_index]
		deck[swap_index] = card
	if state != null:
		state.rng_state = _rng.state

func _card_in_hand(player: PlayerState, instance_id: String) -> CardInstance:
	for card in player.hand:
		if card.instance_id == instance_id:
			return card
	return null

func _both_mulligans_confirmed() -> bool:
	for player_id in state.players:
		var player: PlayerState = state.players[player_id]
		if not player.mulligan_confirmed:
			return false
	return true

func _other_player_id(player_id: String) -> String:
	return "opponent" if player_id == "player" else "player"

func _emit(events: Array, event_type: String, payload: Dictionary) -> void:
	state.sequence += 1
	var event := {"type": event_type, "sequence": state.sequence}
	for key in payload:
		event[key] = payload[key]
	events.append(event)

func _accept(action: GameAction, events: Array = []) -> ActionResult:
	return ActionResult.accept(events, state.snapshot_for(action.actor_id))

func _reject(action: GameAction, code: String, message: String) -> ActionResult:
	return ActionResult.reject(code, message, state.snapshot_for(action.actor_id))
