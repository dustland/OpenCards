class_name AIPlayer
extends RefCounted

const ActionGenerator = preload("res://scripts/ai/action_generator.gd")
const BoardEvaluator = preload("res://scripts/ai/board_evaluator.gd")
const GameAction = preload("res://scripts/core/game_action.gd")

var difficulty: String = "standard"
var node_budget: int = 256
var max_depth: int = 4
var beam_width: int = 8
var visited_nodes: int = 0
var search_metrics: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _validation_workspaces: Dictionary = {}


static func create(difficulty_name: String, seed: int) -> AIPlayer:
	var player: AIPlayer = load("res://scripts/ai/ai_player.gd").new()
	player._configure(difficulty_name)
	player._rng.seed = seed
	return player


func _configure(difficulty_name: String) -> void:
	match difficulty_name.to_lower():
		"easy":
			difficulty = "easy"
			node_budget = 32
			max_depth = 1
			beam_width = 4
		"hard":
			difficulty = "hard"
			node_budget = 1200
			max_depth = 8
			beam_width = 16
		_:
			difficulty = "standard"
			node_budget = 256
			max_depth = 4
			beam_width = 8


func choose_action(controller, actor_id: String) -> GameAction:
	visited_nodes = 0
	search_metrics = _empty_search_metrics()
	_validation_workspaces.clear()
	var snapshot := _snapshot_for(controller, actor_id)
	if not _is_action_turn(snapshot, actor_id):
		return _null_action()
	var actions: Array[GameAction] = _generate_actions(controller, actor_id)
	if actions.is_empty():
		return _null_action()
	var end_turn := _end_turn_action(actions)
	if difficulty != "easy":
		var lethal := _confirmed_immediate_lethal(controller, actor_id, snapshot, actions)
		if not lethal.is_empty():
			return _choose_tied_nodes(lethal).first_action
	var baseline := BoardEvaluator.score(snapshot, actor_id)
	var selected: GameAction = _choose_easy(controller, actor_id, baseline, actions) if difficulty == "easy" else _choose_beam(controller, actor_id, baseline, actions)
	if not selected.type.is_empty():
		return selected
	return end_turn if end_turn != null else _null_action()


func _choose_easy(controller, actor_id: String, baseline: float, actions: Array[GameAction]) -> GameAction:
	var candidates: Array[Dictionary] = []
	for action in _easy_sample_actions(actions):
		var node := _simulate(controller, actor_id, action)
		if node.is_empty():
			if visited_nodes >= node_budget:
				break
			continue
		if float(node.score) <= baseline:
			continue
		node["priority"] = _easy_priority(action, float(node.score) - baseline)
		candidates.append(node)
	if candidates.is_empty():
		return _null_action()
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.priority) != int(right.priority):
			return int(left.priority) < int(right.priority)
		if not is_equal_approx(float(left.score), float(right.score)):
			return float(left.score) > float(right.score)
		return _action_key(left.first_action) < _action_key(right.first_action)
	)
	var best_priority := int(candidates[0].priority)
	var best_score := float(candidates[0].score)
	var tied: Array[Dictionary] = []
	for candidate in candidates:
		if int(candidate.priority) != best_priority or not is_equal_approx(float(candidate.score), best_score):
			break
		tied.append(candidate)
	return _choose_tied_nodes(tied).first_action


func _easy_sample_actions(actions: Array[GameAction]) -> Array[GameAction]:
	var buckets := {}
	for action in _ordered_actions(actions):
		if action.type == "end_turn":
			continue
		var rank := _action_rank(action)
		if not buckets.has(rank):
			buckets[rank] = []
		buckets[rank].append(action)
	var ranks: Array = buckets.keys()
	ranks.sort()
	for rank in ranks:
		_shuffle_actions(buckets[rank])
	var samples: Array[GameAction] = []
	while samples.size() < node_budget:
		var sampled := false
		for rank in ranks:
			var bucket: Array = buckets[rank]
			if bucket.is_empty():
				continue
			samples.append(bucket.pop_front())
			sampled = true
			if samples.size() >= node_budget:
				break
		if not sampled:
			break
	return samples


func _shuffle_actions(actions: Array) -> void:
	for index in range(actions.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var action = actions[index]
		actions[index] = actions[swap_index]
		actions[swap_index] = action


func _choose_beam(controller, actor_id: String, baseline: float, actions: Array[GameAction]) -> GameAction:
	var best_nodes: Array[Dictionary] = []
	var best_score := baseline
	var frontier: Array[Dictionary] = []
	for action in _ordered_actions(actions):
		if action.type == "end_turn":
			continue
		var node := _simulate(controller, actor_id, action)
		if node.is_empty():
			if visited_nodes >= node_budget:
				break
			continue
		node["first_action"] = action
		best_score = _record_best(node, best_score, best_nodes)
		if bool(node.continues):
			frontier.append(node)
	frontier = _top_beam(frontier)
	var depth := 1
	while depth < max_depth and not frontier.is_empty() and visited_nodes < node_budget:
		var next_frontier: Array[Dictionary] = []
		for parent in frontier:
			var branch_actions: Array[GameAction] = _generate_actions(parent.controller, actor_id)
			for action in _ordered_actions(branch_actions):
				var node := _simulate(parent.controller, actor_id, action, float(parent.score))
				if node.is_empty():
					if visited_nodes >= node_budget:
						break
					continue
				node["first_action"] = parent.first_action
				if str((node.snapshot as Dictionary).get("winner_id", "")) == actor_id:
					return node.first_action
				best_score = _record_best(node, best_score, best_nodes)
				if bool(node.continues):
					next_frontier.append(node)
			if visited_nodes >= node_budget:
				break
		frontier = _top_beam(next_frontier)
		depth += 1
	if best_nodes.is_empty():
		return _null_action()
	return _choose_tied_nodes(best_nodes).first_action


func _record_best(node: Dictionary, best_score: float, best_nodes: Array[Dictionary]) -> float:
	var score := float(node.score)
	if score > best_score and not is_equal_approx(score, best_score):
		best_nodes.clear()
		best_nodes.append(node)
		return score
	if is_equal_approx(score, best_score) and not best_nodes.is_empty():
		best_nodes.append(node)
	return best_score


func _confirmed_immediate_lethal(controller, actor_id: String, snapshot: Dictionary, actions: Array[GameAction]) -> Array[Dictionary]:
	var lethal: Array[Dictionary] = []
	for action in _ordered_actions(actions):
		if action.type != "attack_hq":
			continue
		var node := _simulate(controller, actor_id, action)
		if node.is_empty():
			if visited_nodes >= node_budget:
				break
			continue
		var result_snapshot: Dictionary = node.snapshot
		if str(result_snapshot.get("winner_id", "")) == actor_id:
			lethal.append(node)
	return lethal


func _simulate(controller, actor_id: String, action: GameAction, accumulated_score: float = 0.0) -> Dictionary:
	if visited_nodes >= node_budget or not (controller is Object) or not controller.has_method("clone_for_simulation"):
		return {}
	visited_nodes += 1
	search_metrics["simulation_attempts"] = int(search_metrics.get("simulation_attempts", 0)) + 1
	var workspace = _validation_workspace_for(controller, actor_id)
	if not (workspace is Object) or not workspace.has_method("simulate_action_clone"):
		search_metrics["rejected_simulations"] = int(search_metrics.get("rejected_simulations", 0)) + 1
		return {}
	var clone = workspace.simulate_action_clone(action, actor_id)
	if not (clone is Object):
		search_metrics["rejected_simulations"] = int(search_metrics.get("rejected_simulations", 0)) + 1
		return {}
	var snapshot := _snapshot_for(clone, actor_id)
	if snapshot.is_empty():
		return {}
	var terminal := _is_terminal(snapshot)
	return {
		"controller": clone,
		"first_action": action,
		"score": accumulated_score + BoardEvaluator.score(snapshot, actor_id),
		"snapshot": snapshot,
		"continues": not terminal and action.type != "end_turn" and _is_action_turn(snapshot, actor_id),
	}


func _validation_workspace_for(controller, actor_id: String):
	var cache_key := str(controller.get_instance_id())
	if not _validation_workspaces.has(cache_key):
		_validation_workspaces[cache_key] = controller.clone_for_simulation(actor_id)
	return _validation_workspaces[cache_key]


func _generate_actions(controller, actor_id: String) -> Array[GameAction]:
	var snapshot := _snapshot_for(controller, actor_id)
	var actions: Array[GameAction] = []
	for action in ActionGenerator.generate(controller, actor_id, false):
		if _is_countermeasure_deactivation(snapshot, actor_id, action):
			continue
		actions.append(action)
	search_metrics["action_lists"] = int(search_metrics.get("action_lists", 0)) + 1
	search_metrics["candidate_actions"] = int(search_metrics.get("candidate_actions", 0)) + actions.size()
	return actions


func _is_countermeasure_deactivation(snapshot: Dictionary, actor_id: String, action: GameAction) -> bool:
	if action.type != "toggle_countermeasure":
		return false
	var me: Variant = snapshot.get("players", {}).get(actor_id, {})
	if not (me is Dictionary):
		return false
	for card_value in (me as Dictionary).get("hand", []):
		if card_value is Dictionary and str(card_value.get("instance_id", "")) == action.source_id:
			return bool(card_value.get("countermeasure_active", false))
	return false


func _empty_search_metrics() -> Dictionary:
	return {
		"action_lists": 0,
		"candidate_actions": 0,
		"simulation_attempts": 0,
		"rejected_simulations": 0,
	}


func _top_beam(nodes: Array[Dictionary]) -> Array[Dictionary]:
	nodes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if not is_equal_approx(float(left.score), float(right.score)):
			return float(left.score) > float(right.score)
		return _action_key(left.first_action) < _action_key(right.first_action)
	)
	var limited: Array[Dictionary] = []
	var represented_types := {}
	for node in nodes:
		if limited.size() >= beam_width:
			break
		var action_type := str(node.first_action.type)
		if not represented_types.has(action_type):
			represented_types[action_type] = true
			limited.append(node)
	for node in nodes:
		if limited.size() >= beam_width:
			break
		if not limited.has(node):
			limited.append(node)
	return limited


func _choose_tied_nodes(nodes: Array[Dictionary]) -> Dictionary:
	if nodes.is_empty():
		return {}
	var ordered := nodes.duplicate()
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _action_key(left.first_action) < _action_key(right.first_action)
	)
	return ordered[_rng.randi_range(0, ordered.size() - 1)]


func _ordered_actions(actions: Array[GameAction]) -> Array[GameAction]:
	var ordered := actions.duplicate()
	ordered.sort_custom(func(left: GameAction, right: GameAction) -> bool:
		var left_rank := _action_rank(left)
		var right_rank := _action_rank(right)
		if left_rank != right_rank:
			return left_rank < right_rank
		return _action_key(left) < _action_key(right)
	)
	return ordered


func _action_rank(action: GameAction) -> int:
	match action.type:
		"attack_hq":
			return 0
		"attack_unit":
			return 1
		"activate_ability", "play_order":
			return 2
		"deploy_unit":
			return 3
		"move_unit":
			return 4
		"toggle_countermeasure":
			return 5
		"end_turn":
			return 9
	return 8


func _easy_priority(action: GameAction, delta: float) -> int:
	if action.type == "attack_hq" and delta > 0.0:
		return 0
	if action.type == "attack_unit" and delta > 0.0:
		return 1
	if action.type == "deploy_unit":
		return 2
	return 3 if delta > 0.0 else 8


func _end_turn_action(actions: Array[GameAction]) -> GameAction:
	for action in actions:
		if action.type == "end_turn":
			return action
	return null


func _snapshot_for(controller, actor_id: String) -> Dictionary:
	if not (controller is Object):
		return {}
	var state: Variant = controller.get("state")
	if not (state is Object) or not state.has_method("snapshot_for"):
		return {}
	var snapshot: Variant = state.snapshot_for(actor_id)
	return snapshot if snapshot is Dictionary else {}


func _is_action_turn(snapshot: Dictionary, actor_id: String) -> bool:
	if actor_id not in ["player", "opponent"] or snapshot.is_empty() or _is_terminal(snapshot):
		return false
	var players: Variant = snapshot.get("players", null)
	return players is Dictionary and players.size() == 2 and players.has("player") and players.has("opponent") \
		and str(snapshot.get("phase", "")) == "action" and str(snapshot.get("active_player_id", "")) == actor_id


func _is_terminal(snapshot: Dictionary) -> bool:
	return str(snapshot.get("phase", "")) in ["complete", "invalid"] or not str(snapshot.get("winner_id", "")).is_empty()


func _null_action() -> GameAction:
	return GameAction.create("", "")


func _action_key(action: GameAction) -> String:
	return JSON.stringify(_canonicalize([action.type, action.source_id, action.target_ids, action.payload]))


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var entries: Array = []
		for key in value:
			entries.append({"key": _canonicalize(key), "value": _canonicalize(value[key])})
		entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return JSON.stringify(left.key) < JSON.stringify(right.key)
		)
		return {"type": typeof(value), "entries": entries}
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_canonicalize(item))
		return {"type": typeof(value), "items": items}
	return {"type": typeof(value), "value": value}
