class_name MatchCoachModel
extends RefCounted

const LocaleScript = preload("res://scripts/ui/locale.gd")

const ACTION_PRIORITY := [
	"deploy_unit",
	"move_unit",
	"attack_unit",
	"attack_hq",
	"play_order",
	"toggle_countermeasure",
	"activate_ability",
]


static func derive(snapshot: Dictionary, legal_actions: Array, selection: Dictionary, onboarding: Dictionary) -> Dictionary:
	var actions_by_source := _actions_by_source(legal_actions)
	var legal_source_ids: Array = actions_by_source.keys()
	legal_source_ids.sort()
	var result := {
		"objective": LocaleScript.ui("coach.none"),
		"legal_source_ids": legal_source_ids,
		"source_reasons": _source_reasons(snapshot, actions_by_source),
		"end_turn_only": legal_actions.size() == 1 and _action_type(legal_actions[0]) == "end_turn",
		"next_kind": "none",
	}

	if str(snapshot.get("active_player_id", "")) != "player":
		result.objective = LocaleScript.ui("coach.opponent")
		result.next_kind = "opponent_turn"
		return result

	var selected_source_id := str(selection.get("selected_source_id", ""))
	if not selected_source_id.is_empty() and actions_by_source.has(selected_source_id):
		var selected_actions: Array = actions_by_source[selected_source_id]
		var selected_type := _highest_priority_type(selected_actions)
		if selected_type == "deploy_unit" and int(selection.get("selected_slot", -1)) < 0:
			result.objective = LocaleScript.ui("coach.support_slot")
			result.next_kind = "support_slot"
			return result
		if selected_type == "move_unit" and int(selection.get("selected_slot", -1)) < 0:
			result.objective = LocaleScript.ui("coach.frontline_slot")
			result.next_kind = "frontline_slot"
			return result
		if selected_type in ["attack_unit", "attack_hq", "play_order", "activate_ability"] \
				and _selection_needs_target(selected_actions, selection.get("selected_targets", [])):
			result.objective = LocaleScript.ui("coach.target")
			result.next_kind = "target"
			return result

	var next_type := _objective_priority_type(legal_actions, onboarding, snapshot)
	match next_type:
		"deploy_unit":
			var credit := int(_player(snapshot).get("credit", 0))
			result.objective = LocaleScript.ui("coach.deploy") % credit
			result.next_kind = "deploy"
		"move_unit":
			result.objective = LocaleScript.ui("coach.move")
			result.next_kind = "move"
		"attack_unit", "attack_hq":
			result.objective = LocaleScript.ui("coach.attack")
			result.next_kind = "attack"
		"play_order":
			result.objective = LocaleScript.ui("coach.order")
			result.next_kind = "order"
		"toggle_countermeasure":
			result.objective = LocaleScript.ui("coach.countermeasure")
			result.next_kind = "countermeasure"
		"activate_ability":
			result.objective = LocaleScript.ui("coach.ability")
			result.next_kind = "ability"
		"end_turn":
			if result.end_turn_only:
				result.objective = LocaleScript.ui("coach.end_turn")
				result.next_kind = "end_turn"
	return result


static func _actions_by_source(legal_actions: Array) -> Dictionary:
	var grouped := {}
	for action in legal_actions:
		var source_id := _action_source_id(action)
		if source_id.is_empty():
			continue
		if not grouped.has(source_id):
			grouped[source_id] = []
		(grouped[source_id] as Array).append(action)
	return grouped


static func _source_reasons(snapshot: Dictionary, actions_by_source: Dictionary) -> Dictionary:
	var reasons := {}
	var player := _player(snapshot)
	var hand_value: Variant = player.get("hand", [])
	if not (hand_value is Array):
		return reasons
	var is_player_turn := str(snapshot.get("active_player_id", "")) == "player" and str(snapshot.get("phase", "")) == "action"
	for card_value in hand_value:
		if not (card_value is Dictionary):
			continue
		var card: Dictionary = card_value
		var source_id := str(card.get("instance_id", ""))
		if source_id.is_empty() or actions_by_source.has(source_id):
			continue
		if not is_player_turn:
			reasons[source_id] = LocaleScript.ui("reason.wait")
			continue
		var category := str(card.get("category", ""))
		if category == "Countermeasure" and bool(card.get("countermeasure_active", false)):
			reasons[source_id] = LocaleScript.ui("reason.active")
		elif category in ["Unit", "Order", "Countermeasure"] and int(card.get("deployment_cost", 0)) > int(player.get("credit", 0)):
			reasons[source_id] = LocaleScript.ui("reason.credit")
		elif category == "Unit" and _support_is_full(player.get("support_line", [])):
			reasons[source_id] = LocaleScript.ui("reason.support_full")
		elif category == "Order":
			reasons[source_id] = LocaleScript.ui("reason.no_target")
		else:
			reasons[source_id] = LocaleScript.ui("reason.none")
	return reasons


static func _support_is_full(value: Variant) -> bool:
	if not (value is Array) or value.is_empty():
		return false
	for slot in value:
		if slot == null:
			return false
	return true


static func _selection_needs_target(actions: Array, selected_value: Variant) -> bool:
	var selected: Array = selected_value if selected_value is Array else []
	for action in actions:
		var targets: Array = action.get("target_ids") if action is Object else action.get("target_ids", [])
		if targets.size() <= selected.size():
			continue
		var prefix_matches := true
		for index in range(selected.size()):
			if str(targets[index]) != str(selected[index]):
				prefix_matches = false
				break
		if prefix_matches:
			return true
	return false


static func _player(snapshot: Dictionary) -> Dictionary:
	var players_value: Variant = snapshot.get("players", {})
	if players_value is Dictionary:
		var player_value: Variant = players_value.get("player", {})
		if player_value is Dictionary:
			return player_value
	return {}


static func _highest_priority_type(actions: Array) -> String:
	for desired_type in ACTION_PRIORITY:
		for action in actions:
			if _action_type(action) == desired_type:
				return desired_type
	for action in actions:
		if _action_type(action) == "end_turn":
			return "end_turn"
	return ""


static func _objective_priority_type(actions: Array, onboarding: Dictionary, snapshot: Dictionary = {}) -> String:
	var teaching_actions := actions.filter(func(action: Variant) -> bool:
		match _action_type(action):
			"deploy_unit":
				return not bool(onboarding.get("deployed_unit", false))
			"move_unit":
				return not bool(onboarding.get("moved_to_frontline", false))
			"attack_unit", "attack_hq":
				return not bool(onboarding.get("completed_attack", false))
		return false
	)
	var teaching_type := _highest_priority_type(teaching_actions)
	var chosen := teaching_type if not teaching_type.is_empty() else _highest_priority_type(actions)
	if chosen == "deploy_unit" and str(snapshot.get("frontline_controller_id", "")) == "opponent" and _has_attack(actions):
		return _highest_priority_type(actions.filter(func(action: Variant) -> bool:
			return _action_type(action) in ["attack_unit", "attack_hq", "end_turn"]
		))
	return chosen


static func _has_attack(actions: Array) -> bool:
	for action in actions:
		if _action_type(action) in ["attack_unit", "attack_hq"]:
			return true
	return false


static func _action_type(action: Variant) -> String:
	if action is Dictionary:
		return str(action.get("type", ""))
	if action is Object:
		return str(action.get("type"))
	return ""


static func _action_source_id(action: Variant) -> String:
	if action is Dictionary:
		return str(action.get("source_id", ""))
	if action is Object:
		return str(action.get("source_id"))
	return ""
