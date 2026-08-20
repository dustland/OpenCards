class_name CardMotionDirector
extends RefCounted

const CardViewScene = preload("res://scenes/ui/card_view.tscn")

const DURATIONS_MS := {
	"card_drawn": 240.0, "card_deployed": 260.0, "unit_moved": 220.0,
	"attack_started": 260.0, "damage_dealt": 200.0, "fatigue_damage": 200.0,
	"card_destroyed": 220.0, "order_played": 240.0,
	"countermeasure_activated": 220.0, "countermeasure_deactivated": 220.0,
	"countermeasure_triggered": 220.0,
	"turn_started": 320.0, "credit_refilled": 180.0,
}

var speed_scale := 1.0
var processed_event_types: Array[String] = []
var last_duration_ms := 0.0
var last_source_rect := Rect2()
var last_destination_rect := Rect2()
var current_event_type := ""
var _generation := 0
var _transients: Array[Node] = []
var _active_tween: Tween
var _aux_tweens: Array[Tween] = []
var _flash_cards: Dictionary = {}

func play(events: Array, before_snapshot: Dictionary, after_snapshot: Dictionary, view: MatchView) -> void:
	cancel()
	var generation := _generation
	processed_event_types.clear()
	var before_rects := view.snapshot_card_rects(before_snapshot)
	var after_rects := view.snapshot_card_rects(after_snapshot)
	for value in events:
		if generation != _generation or not is_instance_valid(view): break
		if not (value is Dictionary): continue
		var event: Dictionary = value
		var event_type := str(event.get("type", ""))
		if not DURATIONS_MS.has(event_type): continue
		processed_event_types.append(event_type)
		current_event_type = event_type
		await _play_event(event_type, event, before_snapshot, after_snapshot, before_rects, after_rects, view, generation)
	current_event_type = ""
	_cleanup_transients()

func cancel() -> void:
	_generation += 1
	current_event_type = ""
	if _active_tween != null and _active_tween.is_valid(): _active_tween.kill()
	_active_tween = null
	for tween in _aux_tweens:
		if tween != null and tween.is_valid(): tween.kill()
	_aux_tweens.clear()
	for card in _flash_cards:
		if is_instance_valid(card):
			card.modulate = _flash_cards[card]
			card.set_meta("motion_flash_active", false)
	_flash_cards.clear()
	_cleanup_transients()

func _play_event(event_type: String, event: Dictionary, before: Dictionary, after: Dictionary, before_rects: Dictionary, after_rects: Dictionary, view: MatchView, generation: int) -> void:
	SfxPlayer.play_event(event_type, event)
	var duration_ms: float = float(DURATIONS_MS[event_type])
	if view.animation_mode == "reduced": duration_ms = minf(duration_ms, 80.0)
	last_duration_ms = duration_ms
	var duration := duration_ms * speed_scale / 1000.0

	# View-level flourishes that do not involve a moving card proxy.
	if event_type == "turn_started":
		await _play_turn_banner(view, str(event.get("player_id", "")), duration, generation)
		return
	if event_type == "credit_refilled":
		if view.has_method("pulse_credit"): view.pulse_credit()
		await _wait_frames(view, generation, 2)
		return
	if event_type in ["damage_dealt", "fatigue_damage"]:
		await _play_damage(view, event, before_rects, after_rects, duration, generation)
		return

	var source_id := _source_id(event_type, event, before, after)
	var target_id := _target_id(event_type, event, before, after)
	var source_rect: Rect2 = before_rects.get(source_id, Rect2())
	var destination_rect: Rect2 = after_rects.get(source_id, source_rect)
	var actor_id := str(event.get("player_id", ""))
	if event_type == "card_drawn" and not source_rect.has_area():
		source_rect = view.deck_edge_rect(actor_id if not actor_id.is_empty() else "player")
	if event_type == "card_drawn" and actor_id == "opponent" and not destination_rect.has_area():
		destination_rect = view.opponent_hand_origin_rect()
	if event_type in ["card_deployed", "order_played", "countermeasure_activated"] and actor_id == "opponent" and not source_rect.has_area():
		source_rect = view.opponent_hand_origin_rect()
	if event_type in ["order_played", "countermeasure_activated", "countermeasure_deactivated", "countermeasure_triggered"]:
		destination_rect = view.command_area_rect()
	last_source_rect = source_rect
	last_destination_rect = destination_rect

	var card_info := _card_info_for(source_id, before, after)
	var ghost := _ghost_card(view, source_rect if source_rect.has_area() else view.animation_zone_rect(str(event.get("player_id", ""))), card_info)
	_active_tween = view.create_tween()

	if view.animation_mode == "reduced" or not source_rect.has_area():
		_active_tween.tween_property(ghost, "modulate:a", 0.0, duration)
	elif event_type == "attack_started":
		var target_rect: Rect2 = before_rects.get(target_id, after_rects.get(target_id, Rect2()))
		var lunge := source_rect.position.lerp(target_rect.position, 0.38) if target_rect.has_area() else source_rect.position
		_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_active_tween.tween_property(ghost, "global_position", lunge, duration * 0.45)
		_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(ghost, "global_position", source_rect.position, duration * 0.55)
		_flash_target(view.card_view(target_id), duration)
		_shake(view.card_view(target_id))
	elif event_type == "card_destroyed":
		ghost.modulate = Color("fff2cf")
		_active_tween.set_parallel(true)
		_active_tween.tween_property(ghost, "scale", Vector2(0.82, 0.82), duration)
		_active_tween.tween_property(ghost, "modulate:a", 0.0, duration)
	elif event_type == "card_deployed":
		_active_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_active_tween.set_parallel(true)
		_active_tween.tween_property(ghost, "global_position", destination_rect.position, duration)
		if ghost.size.x > 0.0 and ghost.size.y > 0.0 and destination_rect.has_area():
			var uniform := minf(destination_rect.size.x / ghost.size.x, destination_rect.size.y / ghost.size.y)
			_active_tween.tween_property(ghost, "scale", Vector2(uniform, uniform), duration)
		_active_tween.tween_property(ghost, "modulate:a", 0.25 if destination_rect.has_area() else 0.0, duration)
	elif event_type == "order_played" or event_type.begins_with("countermeasure_"):
		ghost.modulate = Color("ffe9b8")
		_active_tween.set_parallel(true)
		_active_tween.tween_property(ghost, "global_position", destination_rect.position + Vector2(0, -10), duration)
		_active_tween.tween_property(ghost, "modulate:a", 0.0, duration)
		_active_tween.tween_property(ghost, "scale", Vector2(0.9, 0.9), duration)
	elif event_type == "card_drawn":
		ghost.rotation_degrees = -9.0
		_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_active_tween.set_parallel(true)
		_active_tween.tween_property(ghost, "global_position", destination_rect.position, duration)
		_active_tween.tween_property(ghost, "rotation_degrees", 0.0, duration)
		_active_tween.tween_property(ghost, "modulate:a", 0.35 if destination_rect.has_area() else 0.0, duration)
	else:
		_active_tween.set_parallel(true)
		_active_tween.tween_property(ghost, "global_position", destination_rect.position, duration)
		_active_tween.tween_property(ghost, "modulate:a", 0.15 if destination_rect.has_area() else 0.0, duration)
	await _wait_for_tween(view, generation)
	_active_tween = null
	if generation == _generation:
		_finish_flashes()
		_cleanup_transients()

func _play_damage(view: MatchView, event: Dictionary, before_rects: Dictionary, after_rects: Dictionary, duration: float, generation: int) -> void:
	var target_id := _target_id("damage_dealt", event, {}, {})
	var rect: Rect2 = before_rects.get(target_id, after_rects.get(target_id, Rect2()))
	if view.has_method("flash_hq"): view.flash_hq(target_id)
	var card = view.card_view(target_id)
	if card != null:
		_flash_target(card, duration)
		_shake(card)
	if rect.has_area():
		_add_damage_indicator(view, rect, int(event.get("damage", event.get("amount", 0))))
	await _wait_frames(view, generation, 2)

func _play_turn_banner(view: MatchView, player_id: String, duration: float, generation: int) -> void:
	var banner := Label.new()
	banner.text = Locale.ui("turn.yours") if player_id == "player" else Locale.ui("turn.opponent")
	banner.add_theme_font_size_override("font_size", 34)
	banner.add_theme_color_override("font_color", Color("f4dd96"))
	banner.add_theme_color_override("font_outline_color", Color(0.07, 0.08, 0.06, 0.9))
	banner.add_theme_constant_override("outline_size", 6)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(banner)
	var area: Rect2 = view.get_global_rect()
	banner.size = Vector2(area.size.x, 46)
	banner.global_position = Vector2(area.position.x, area.position.y + area.size.y * 0.34)
	banner.modulate.a = 0.0
	_transients.append(banner)
	var tween := view.create_tween()
	_active_tween = tween
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, duration * 0.28)
	tween.tween_property(banner, "position:y", banner.position.y - 6.0, duration * 0.34)
	tween.tween_property(banner, "modulate:a", 0.0, duration * 0.38)
	await _wait_for_tween(view, generation)
	_active_tween = null
	if generation == _generation:
		_cleanup_transients()

func _wait_frames(view: MatchView, generation: int, frames: int) -> void:
	var waited := 0
	while waited < frames and generation == _generation and is_instance_valid(view):
		await view.get_tree().process_frame
		waited += 1

func _wait_for_tween(view: MatchView, generation: int) -> void:
	while generation == _generation and is_instance_valid(view) and _active_tween != null and _active_tween.is_valid() and _active_tween.is_running():
		await view.get_tree().process_frame

# The motion proxy renders as a real card face (title, art, stats) so the
# player can follow exactly which card is moving during AI turns.
func _ghost_card(view: MatchView, rect: Rect2, card_info: Dictionary) -> Control:
	var ghost = CardViewScene.instantiate()
	var mode := "hand" if rect.size.y >= 140.0 else "battlefield"
	ghost.bind(card_info if not card_info.is_empty() else {"title": ""}, mode)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.disabled = true
	ghost.add_to_group("card_motion_proxy")
	ghost.z_index = 32
	view.add_child(ghost)
	ghost.global_position = rect.position
	ghost.pivot_offset = ghost.size * 0.5
	_transients.append(ghost)
	return ghost

func _flash_target(card, duration: float) -> void:
	if card == null or not is_instance_valid(card): return
	var original: Color = card.modulate
	_flash_cards[card] = original
	card.set_meta("motion_flash_active", true)
	var tween: Tween = card.create_tween()
	_aux_tweens.append(tween)
	tween.tween_property(card, "modulate", Color("fff0a0"), duration * 0.5)
	tween.tween_property(card, "modulate", original, duration * 0.5)

func _shake(card) -> void:
	if card == null or not is_instance_valid(card): return
	var original: Vector2 = card.position
	var tween: Tween = card.create_tween().set_trans(Tween.TRANS_SINE)
	_aux_tweens.append(tween)
	for offset in [Vector2(2.5, 0), Vector2(-2.5, 1), Vector2(1.5, -1), Vector2.ZERO]:
		tween.tween_property(card, "position", original + offset, 0.035)

func _finish_flashes() -> void:
	_aux_tweens.clear()
	for card in _flash_cards:
		if is_instance_valid(card):
			card.modulate = _flash_cards[card]
			card.set_meta("motion_flash_active", false)
	_flash_cards.clear()

func _add_damage_indicator(view: MatchView, rect: Rect2, damage: int) -> void:
	var label := Label.new()
	label.text = "-%d" % damage
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("ff8b5c"))
	label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.03, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 40
	label.add_to_group("card_damage_indicator")
	view.add_child(label)
	label.pivot_offset = Vector2(20, 14)
	label.size = Vector2(40, 28)
	label.global_position = rect.get_center() - Vector2(20, 24)
	label.scale = Vector2(0.4, 0.4)
	_transients.append(label)
	var tween: Tween = label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_aux_tweens.append(tween)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14)
	tween.tween_property(label, "position:y", label.position.y - 16.0, 0.30)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.16)

func _cleanup_transients() -> void:
	for node in _transients:
		if is_instance_valid(node): node.free()
	_transients.clear()

func _source_id(event_type: String, event: Dictionary, before: Dictionary, after: Dictionary) -> String:
	if event_type == "card_destroyed":
		var destroyed_id := str(event.get("target_id", ""))
		if not destroyed_id.is_empty(): return destroyed_id
	for key in ["instance_id", "source_id", "attacker_id", "order_id"]:
		var value := str(event.get(key, ""))
		if not value.is_empty(): return value
	return _infer_changed_id(event_type, before, after)

func _target_id(event_type: String, event: Dictionary, before: Dictionary, after: Dictionary) -> String:
	for key in ["target_id", "defender_id"]:
		var value := str(event.get(key, ""))
		if not value.is_empty(): return value
	var targets: Array = event.get("target_ids", [])
	if not targets.is_empty(): return str(targets[0])
	if event_type == "fatigue_damage": return _headquarters_id(before, str(event.get("player_id", "")))
	return _source_id(event_type, event, before, after)

func _infer_changed_id(event_type: String, before: Dictionary, after: Dictionary) -> String:
	var before_locations := _locations(before)
	var after_locations := _locations(after)
	for instance_id in before_locations:
		if not after_locations.has(instance_id) and event_type in ["card_destroyed", "order_played"]: return instance_id
		if after_locations.has(instance_id) and before_locations[instance_id] != after_locations[instance_id]: return instance_id
	for instance_id in after_locations:
		if not before_locations.has(instance_id): return instance_id
	return ""

func _locations(snapshot: Dictionary) -> Dictionary:
	var result := {}
	var players: Dictionary = snapshot.get("players", {})
	for player_id in ["player", "opponent"]:
		var player: Dictionary = players.get(player_id, {})
		for zone_name in ["hand", "support_line"]:
			var cards: Array = player.get(zone_name, [])
			for index in range(cards.size()):
				if cards[index] is Dictionary:
					var id := str(cards[index].get("instance_id", ""))
					if not id.is_empty() and not bool(cards[index].get("hidden", false)): result[id] = "%s:%s:%d" % [player_id, zone_name, index]
	var frontline: Array = snapshot.get("frontline", [])
	for index in range(frontline.size()):
		if frontline[index] is Dictionary:
			var id := str(frontline[index].get("instance_id", ""))
			if not id.is_empty(): result[id] = "frontline:%d" % index
	return result

func _card_info_for(instance_id: String, before: Dictionary, after: Dictionary) -> Dictionary:
	if instance_id.is_empty():
		return {}
	var found := _find_card_in_snapshot(before, instance_id)
	if found.is_empty():
		found = _find_card_in_snapshot(after, instance_id)
	return found

func _find_card_in_snapshot(snapshot: Dictionary, instance_id: String) -> Dictionary:
	var players: Dictionary = snapshot.get("players", {})
	for player_id in ["player", "opponent"]:
		var player: Dictionary = players.get(player_id, {})
		for zone_name in ["hand", "support_line", "discard"]:
			for card in player.get(zone_name, []):
				if card is Dictionary and str(card.get("instance_id", "")) == instance_id and not bool(card.get("hidden", false)):
					return card
	var frontline: Array = snapshot.get("frontline", [])
	for card in frontline:
		if card is Dictionary and str(card.get("instance_id", "")) == instance_id:
			return card
	return {}

func _headquarters_id(snapshot: Dictionary, player_id: String) -> String:
	return str(snapshot.get("players", {}).get(player_id, {}).get("headquarters", {}).get("instance_id", ""))
