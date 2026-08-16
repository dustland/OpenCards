class_name BoardEvaluator
extends RefCounted


static func score(snapshot: Variant, actor_id: String) -> float:
	if not (snapshot is Dictionary):
		return 0.0
	var players_value: Variant = snapshot.get("players", null)
	if not (players_value is Dictionary):
		return 0.0
	var players: Dictionary = players_value
	if actor_id not in ["player", "opponent"] \
		or players.size() != 2 \
		or not players.has("player") \
		or not players.has("opponent"):
		return 0.0
	var opponent_id := "opponent" if actor_id == "player" else "player"
	var me_value: Variant = players.get(actor_id, null)
	var them_value: Variant = players.get(opponent_id, null)
	if not (me_value is Dictionary) or not (them_value is Dictionary):
		return 0.0
	var me: Dictionary = me_value
	var them: Dictionary = them_value
	return (_number(me.get("hq_defense", 0)) - _number(them.get("hq_defense", 0))) * 8.0 \
		+ _unit_value(snapshot, me, actor_id) - _unit_value(snapshot, them, opponent_id) \
		+ float(_hand_count(me) - _hand_count(them)) * 1.5 \
		+ _frontline_value(snapshot, actor_id) \
		+ (_number(me.get("credit", 0)) - _number(them.get("credit", 0))) * 0.25 \
		+ _countermeasure_value(me) - _countermeasure_value(them)


static func _hand_count(player: Dictionary) -> int:
	var explicit_count: Variant = player.get("hand_count", null)
	if explicit_count is int:
		return maxi(0, explicit_count)
	var hand: Variant = player.get("hand", [])
	return hand.size() if hand is Array else 0


static func _unit_value(snapshot: Dictionary, player: Dictionary, player_id: String) -> float:
	var value := _cards_value(player.get("support_line", []))
	if str(snapshot.get("frontline_controller_id", "")) == player_id:
		value += _cards_value(snapshot.get("frontline", []))
	return value


static func _cards_value(cards: Variant) -> float:
	if not (cards is Array):
		return 0.0
	var value := 0.0
	for card_value in cards:
		if not (card_value is Dictionary):
			continue
		var card: Dictionary = card_value
		if str(card.get("category", "")) == "Unit":
			value += _number(card.get("attack", 0)) + _number(card.get("defense", 0))
	return value


static func _countermeasure_value(player: Dictionary) -> float:
	var hand: Variant = player.get("hand", [])
	if not (hand is Array):
		return 0.0
	var value := 0.0
	for card_value in hand:
		if card_value is Dictionary and bool(card_value.get("countermeasure_active", false)):
			value += 2.0
	return value


static func _frontline_value(snapshot: Dictionary, actor_id: String) -> float:
	var controller_id: Variant = snapshot.get("frontline_controller_id", "")
	if not (controller_id is String) or controller_id.is_empty():
		return 0.0
	return 10.0 if controller_id == actor_id else -10.0


static func _number(value: Variant) -> float:
	if value is int or value is float:
		return float(value)
	return 0.0
