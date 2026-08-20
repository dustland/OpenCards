class_name MatchView
extends Control

signal action_requested(action: GameAction)

const ActionBuilderScript = preload("res://scripts/ui/action_builder.gd")
const CardViewScene = preload("res://scenes/ui/card_view.tscn")
const MatchCoachModelScript = preload("res://scripts/ui/match_coach_model.gd")
const CardMotionDirectorScript = preload("res://scripts/ui/card_motion_director.gd")
const LocaleScript = preload("res://scripts/ui/locale.gd")
const SettingsDialogScene = preload("res://scenes/ui/settings_dialog.tscn")

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
var _inspect_text: Label
var _hovered_inspect: Dictionary = {}
var _last_layout_size := Vector2.ZERO
var _card_titles: Dictionary = {}
var _guard_segments: Array = []
var _aim_legal := false
var _chrome_overlay: Control
var _top_bar: Control
var _player_bar: Control

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
	%OpponentHQ.mouse_entered.connect(_on_hq_inspected.bind(%OpponentHQ))
	%OpponentHQ.mouse_exited.connect(_on_card_inspected.bind({}))
	%OpponentSupport.card_pressed.connect(_on_board_card_pressed)
	%OpponentSupport.target_dropped.connect(_on_target_dropped)
	%Frontline.card_pressed.connect(_on_board_card_pressed)
	%Frontline.slot_pressed.connect(_on_slot_pressed)
	%Frontline.card_dropped.connect(_on_card_dropped)
	%Frontline.target_dropped.connect(_on_target_dropped)
	%PlayerHQ.card_pressed.connect(_on_board_card_pressed)
	%PlayerHQ.card_dropped.connect(_on_target_dropped)
	%PlayerHQ.mouse_entered.connect(_on_hq_inspected.bind(%PlayerHQ))
	%PlayerHQ.mouse_exited.connect(_on_card_inspected.bind({}))
	%PlayerSupport.card_pressed.connect(_on_board_card_pressed)
	%PlayerSupport.slot_pressed.connect(_on_slot_pressed)
	%PlayerSupport.card_dropped.connect(_on_card_dropped)
	%PlayerSupport.target_dropped.connect(_on_target_dropped)
	%CancelButton.pressed.connect(_on_cancel_pressed)
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%EndTurnButton.pressed.connect(_on_end_turn_pressed)
	%ConcedeDialog.confirmed.connect(_on_concede_confirmed)
	resized.connect(_apply_responsive_layout)
	tree_exiting.connect(cancel_motion)
	_install_lane_chrome()
	_install_help_button()
	_install_inspect_panel()
	_lift_table_chrome()
	_style_coach()
	_style_table_chrome()
	_bind_chrome()
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var compact := size.x <= 1000.0
	var size_changed := not size.is_equal_approx(_last_layout_size)
	_last_layout_size = size
	_pin_log_chip(Vector2(188.0, 28.0) if compact else Vector2(220.0, 28.0))
	%HandScroll.clip_contents = false
	%HandScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	%HandScroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	%HandScroll.get_h_scroll_bar().visible = false
	%HandScroll.custom_minimum_size.y = HAND_STRIP_HEIGHT
	var hand_area := get_node("Margin/Columns/Board/HandArea") as Control
	hand_area.size_flags_vertical = 0
	hand_area.custom_minimum_size.y = HAND_STRIP_HEIGHT
	if has_node("%OpponentHandStrip"):
		%OpponentHandStrip.custom_minimum_size.y = OPP_HAND_STRIP
		%OpponentHandStrip.size_flags_vertical = 0
	var row_height := 128.0 if compact else 132.0
	var row_gap := 8.0
	for path in ["Margin/Columns/Board/OpponentArea", "Margin/Columns/Board/Frontline", "Margin/Columns/Board/PlayerArea"]:
		var row := get_node(path) as Control
		row.custom_minimum_size.y = row_height
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for path in ["Margin/Columns/Board/PlayGap1", "Margin/Columns/Board/PlayGap2"]:
		var gap := get_node(path) as Control
		gap.custom_minimum_size.y = row_gap
		gap.size_flags_vertical = 0
	%StatusLabel.size_flags_vertical = 0
	_present_status(%StatusLabel.text)
	%CoachObjective.custom_minimum_size.y = 22.0
	%CoachObjective.size_flags_vertical = 0
	%CoachObjective.clip_contents = true
	_place_table_chrome()
	var margin := get_node("Margin") as MarginContainer
	margin.offset_left = 6.0 if compact else 8.0
	margin.offset_top = 0.0
	margin.offset_right = -6.0 if compact else -8.0
	margin.offset_bottom = 0.0
	%CancelButton.custom_minimum_size = Vector2(56.0 if compact else 68.0, 36.0)
	%ConfirmButton.custom_minimum_size = Vector2(64.0 if compact else 78.0, 36.0)
	%EndTurnButton.custom_minimum_size = Vector2(76.0 if compact else 88.0, 36.0)
	%CoachObjective.add_theme_font_size_override("font_size", 13 if compact else 14)
	if size_changed:
		cancel_motion()
		call_deferred("_refresh_guard_links")
		call_deferred("_apply_hand_transforms")
		call_deferred("_apply_opponent_hand_transforms")
		call_deferred("_place_table_chrome")


func _lift_table_chrome() -> void:
	_chrome_overlay = get_node_or_null("ChromeOverlay") as Control
	_top_bar = %TurnLabel.get_parent() as Control
	_player_bar = %CreditLabel.get_parent().get_parent() as Control
	if _player_bar != null:
		_player_bar.alignment = BoxContainer.ALIGNMENT_END
		_player_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	if _top_bar != null:
		_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%PlayerLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%OpponentLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%TurnLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _place_table_chrome() -> void:
	if not is_node_ready():
		return
	if _chrome_overlay == null:
		_lift_table_chrome()
	_dock_headquarters(%OpponentHQ, %OpponentSupport)
	_dock_headquarters(%PlayerHQ, %PlayerSupport)
	_place_top_bar()
	_place_player_commands()
	_place_lane_chips()


func _dock_headquarters(hq: Control, grid: Control) -> void:
	var holder := hq.get_parent() as Control
	if holder == null or grid == null or grid.size.x < 2.0:
		return
	var gap := 10.0
	var grid_left: float = grid.grid_left_x() if grid is ZoneView else grid.get_global_rect().position.x
	var holder_rect := holder.get_global_rect()
	hq.position.x = floorf(grid_left - gap - hq.size.x - holder_rect.position.x)
	hq.position.x = maxf(0.0, hq.position.x)
	hq.position.y = floorf((holder.size.y - hq.size.y) * 0.5)


func _place_top_bar() -> void:
	if _top_bar == null:
		return
	_top_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_top_bar.position = Vector2(8.0, 4.0)
	_top_bar.size = Vector2(maxf(200.0, size.x - 16.0), 30.0)


func _place_player_commands() -> void:
	if _player_bar == null:
		return
	var area := get_node("Margin/Columns/Board/PlayerArea") as Control
	var support := %PlayerSupport
	if area.size.x < 2.0 or support.size.x < 2.0:
		return
	var area_rect: Rect2 = area.get_global_rect()
	var support_rect: Rect2 = support.get_global_rect()
	var pocket_left: float = support_rect.position.x + support_rect.size.x + 12.0
	var pocket_right: float = area_rect.position.x + area_rect.size.x - 6.0
	var bar_size: Vector2 = _player_bar.get_combined_minimum_size()
	bar_size.x = maxf(bar_size.x, pocket_right - pocket_left)
	bar_size.y = maxf(bar_size.y, 36.0)
	var pos := Vector2(
		maxf(pocket_left, pocket_right - bar_size.x),
		area_rect.position.y + floorf((area_rect.size.y - bar_size.y) * 0.5)
	)
	_player_bar.global_position = pos
	_player_bar.size = bar_size


func _place_lane_chips() -> void:
	_pin_lane_chip("OpponentLaneChip", %OpponentSupport)
	_pin_lane_chip("PlayerLaneChip", %PlayerSupport)


func _pin_lane_chip(chip_name: String, grid: Control) -> void:
	var chip := get_node_or_null("%" + chip_name) as Control
	if chip == null or grid == null or grid.size.x < 2.0:
		return
	var host := chip.get_parent() as Control
	if host == null:
		return
	var local := host.get_global_transform().affine_inverse() * Vector2(grid.get_global_rect().position.x, host.get_global_rect().position.y + 2.0)
	chip.position = Vector2(local.x, 2.0)

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
	%OpponentLabel.add_theme_font_size_override("font_size", 13)
	%PlayerLabel.text = _status_strip(player, true)
	%PlayerLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	%PlayerLabel.add_theme_font_size_override("font_size", 12)
	%CreditLabel.text = "%d / %d" % [int(player.get("credit", 0)), int(player.get("credit_slots", 0))]
	_credit_chip().tooltip_text = LocaleScript.ui("status.credit_hint")
	_update_lane_chips()
	%OpponentSupport.render(opponent.get("support_line", []), false, _resolve_card_view)
	%Frontline.render(snapshot.get("frontline", []), false, _resolve_card_view)
	%PlayerSupport.render(player.get("support_line", []), false, _resolve_card_view)
	%OpponentHQ.bind_hq(opponent.get("headquarters", {}), str(opponent.get("nation", "SovietUnion")), int(opponent.get("hq_defense", 0)))
	%PlayerHQ.bind_hq(player.get("headquarters", {}), str(player.get("nation", "UnitedStates")), int(player.get("hq_defense", 0)))
	_render_piles(player, opponent)
	_render_hand(player.get("hand", []))
	_render_opponent_hand(opponent.get("hand", []))
	_release_missing_card_views(_public_instance_ids(snapshot))
	_remember_card_titles()
	_refresh_coach()
	call_deferred("_refresh_guard_links")
	call_deferred("_place_table_chrome")


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
	%Timeline.render_events(events, _card_titles)
	_refresh_log_chip()


func _pin_log_chip(log_size: Vector2) -> void:
	%TimelinePanel.custom_minimum_size = log_size
	%TimelinePanel.offset_left = -log_size.x - 10.0
	%TimelinePanel.offset_top = 6.0
	%TimelinePanel.offset_right = -10.0
	%TimelinePanel.offset_bottom = 6.0 + log_size.y
	var gap: Control = null
	if _top_bar != null:
		gap = _top_bar.get_node_or_null("LogGap") as Control
	if gap == null:
		gap = get_node_or_null("Margin/Columns/Board/Top/LogGap") as Control
	if gap != null:
		gap.custom_minimum_size.x = log_size.x + 8.0


func _refresh_log_chip() -> void:
	%TimelinePanel.visible = %Timeline.get_child_count() > 0

func set_animation_mode(mode: String) -> void:
	animation_mode = mode if mode in ["on", "reduced"] else "on"


func can_concede() -> bool:
	return not _input_locked and str(snapshot.get("active_player_id", "")) == "player" and str(snapshot.get("phase", "")) == "action"


func _open_settings() -> void:
	var context := {"can_concede": can_concede()}
	if router != null and router.has_method("show_settings"):
		router.show_settings(context)
		return
	var overlay = get_node_or_null("SettingsDialog")
	if overlay == null:
		overlay = SettingsDialogScene.instantiate()
		overlay.name = "SettingsDialog"
		add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.animation_mode_changed.connect(_on_settings_animation_changed)
		overlay.concede_requested.connect(_on_concede_pressed)
	overlay.present(animation_mode, context)


func _on_settings_animation_changed(mode: String) -> void:
	set_animation_mode(mode)
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
	if player_id == "opponent":
		var hand_rect := opponent_hand_origin_rect()
		if hand_rect.has_area():
			return hand_rect
		return %OpponentSupport.get_global_rect()
	return %PlayerHand.get_global_rect()


func opponent_hand_origin_rect(index: int = -1) -> Rect2:
	if not has_node("%OpponentHand"):
		return Rect2()
	var cards: Array = %OpponentHand.get_children()
	if cards.is_empty():
		var host := %OpponentHand as Control
		return Rect2(host.get_global_rect().get_center() - Vector2(HAND_CARD_WIDTH, HAND_CARD_HEIGHT) * 0.5, Vector2(HAND_CARD_WIDTH, HAND_CARD_HEIGHT))
	var card: Control = cards[index] if index >= 0 and index < cards.size() else cards[cards.size() - 1]
	var center := card.get_global_rect().get_center()
	return Rect2(center - Vector2(HAND_CARD_WIDTH, HAND_CARD_HEIGHT) * 0.5, Vector2(HAND_CARD_WIDTH, HAND_CARD_HEIGHT))

func deck_edge_rect(player_id: String) -> Rect2:
	var pile := %OpponentDeckPile if player_id == "opponent" else %PlayerDeckPile
	if pile.visible and pile.size.x > 1.0:
		return pile.get_global_rect()
	var area: Rect2 = (%OpponentSupport if player_id == "opponent" else %HandScroll).get_global_rect()
	return Rect2(area.end.x - 18.0, area.position.y + area.size.y * 0.5 - 24.0, 36.0, 48.0)

func command_area_rect() -> Rect2:
	for path in ["%EndTurnButton", "%SettingsButton", "%ConfirmButton"]:
		if has_node(path):
			var command := get_node(path) as Control
			if command.visible and command.size.x > 1.0:
				return command.get_global_rect()
	return (%PlayerLabel as Control).get_global_rect()


func _credit_chip() -> Control:
	var parent := %CreditLabel.get_parent()
	return parent if parent is HBoxContainer else %CreditLabel


# Emphasized by CardMotionDirector on credit_refilled events.
func pulse_credit() -> void:
	if not is_node_ready():
		return
	var chip := _credit_chip()
	chip.pivot_offset = chip.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(chip, "scale", Vector2(1.28, 1.28), 0.10)
	tween.tween_property(chip, "scale", Vector2.ONE, 0.14)


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
	var origin_x := _hand_origin_x(hand.size())
	for index in range(hand.size()):
		if hand[index] is Dictionary and not bool(hand[index].get("hidden", false)):
			var instance_id := str(hand[index].get("instance_id", ""))
			if not instance_id.is_empty():
				var pos: Vector2 = transforms[index].pos
				result[instance_id] = Rect2(hand_rect.position.x + origin_x + pos.x, hand_rect.position.y + pos.y, HAND_CARD_WIDTH, HAND_CARD_HEIGHT)
	return result

func _add_zone_snapshot_rects(result: Dictionary, cards: Array, zone: ZoneView) -> void:
	for index in range(mini(cards.size(), zone.get_child_count())):
		if cards[index] is Dictionary and not bool(cards[index].get("hidden", false)):
			var instance_id := str(cards[index].get("instance_id", ""))
			if not instance_id.is_empty():
				result[instance_id] = zone.field_card_rect_at(index)

func set_legal_actions(actions: Array) -> void:
	model.set_legal_actions(actions)
	_refresh_coach()


func set_onboarding_state(state: Dictionary) -> void:
	_onboarding_state = state.duplicate(true)
	_refresh_coach()


func handle_back() -> bool:
	var settings = get_node_or_null("SettingsDialog")
	if settings != null and bool(settings.visible):
		settings.close()
		return true
	if has_node("%ConcedeDialog") and %ConcedeDialog.visible:
		%ConcedeDialog.hide()
		return true
	if not model.selected_source_id.is_empty():
		if _reject_locked():
			return true
		_on_cancel_pressed()
		return true
	_open_settings()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and model.can_confirm():
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()

func set_input_locked(locked: bool) -> void:
	_input_locked = locked
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
	_present_status(message)
	_refresh_coach()

const HAND_CARD_WIDTH := 116.0
const HAND_CARD_HEIGHT := 162.0
const HAND_ADVANCE := 100.0
const HAND_MAX_ROTATION := 12.0
const HAND_ARC_DEPTH := 12.0
const HAND_MARGIN := 24.0
const HAND_TOP_PAD := 6.0
const HAND_STRIP_HEIGHT := 86.0
const OPP_HAND_SCALE := 0.64
const OPP_HAND_ADVANCE := 64.0
const OPP_HAND_MAX_ROTATION := 12.0
const OPP_HAND_ARC := 6.0
const OPP_HAND_STRIP := 26.0
const OPP_HAND_PEEK := 8.0


# Playing-card arch: edges sit lower and tilt out, the center sits higher and
# stays level. Live view and motion snapshot rects share this layout.
func _hand_layout(count: int) -> Array:
	var transforms := []
	for index in range(count):
		var t := 0.5 if count <= 1 else float(index) / float(count - 1)
		var center_offset := (2.0 * t - 1.0)
		var rotation_deg := HAND_MAX_ROTATION * center_offset
		var drop := HAND_ARC_DEPTH * center_offset * center_offset
		transforms.append({
			"pos": Vector2(index * HAND_ADVANCE, HAND_TOP_PAD + drop),
			"rot": rotation_deg,
		})
	return transforms


func _hand_layout_width(count: int) -> float:
	return HAND_CARD_WIDTH + HAND_MARGIN * 2.0 + maxf(0.0, count - 1) * HAND_ADVANCE


func _hand_area_width(count: int) -> float:
	var content := _hand_layout_width(count)
	if not is_node_ready() or not has_node("%HandScroll"):
		return content
	return maxf(content, %HandScroll.size.x)


func _hand_origin_x(count: int) -> float:
	return HAND_MARGIN + maxf(0.0, _hand_area_width(count) - _hand_layout_width(count)) * 0.5


func _apply_hand_transforms() -> void:
	if not is_node_ready() or not has_node("%PlayerHand"):
		return
	var cards: Array = %PlayerHand.get_children()
	var transforms := _hand_layout(cards.size())
	var origin_x := _hand_origin_x(cards.size())
	for index in range(cards.size()):
		var card: Control = cards[index]
		card.pivot_offset = Vector2(HAND_CARD_WIDTH, HAND_CARD_HEIGHT) * 0.5
		card.position = Vector2(origin_x + transforms[index].pos.x, transforms[index].pos.y)
		card.rotation_degrees = transforms[index].rot
	%PlayerHand.custom_minimum_size = Vector2(_hand_area_width(cards.size()), HAND_STRIP_HEIGHT)


func _render_opponent_hand(cards: Array) -> void:
	if not has_node("%OpponentHand"):
		return
	var host := %OpponentHand as Control
	var count := 0
	for card_data in cards:
		if card_data is Dictionary:
			count += 1
	while host.get_child_count() > count:
		host.get_child(host.get_child_count() - 1).free()
	while host.get_child_count() < count:
		var card = CardViewScene.instantiate()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.disabled = true
		card.native_tooltip = false
		host.add_child(card)
	var nation := str(snapshot.get("players", {}).get("opponent", {}).get("nation", "SovietUnion"))
	for card in host.get_children():
		card.bind({"hidden": true, "owner_id": "opponent", "nation": nation}, "hidden")
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.disabled = true
	_apply_opponent_hand_transforms()
	call_deferred("_apply_opponent_hand_transforms")


func _opponent_hand_layout(count: int, advance: float = OPP_HAND_ADVANCE) -> Array:
	var transforms := []
	var peek_y := OPP_HAND_PEEK - HAND_CARD_HEIGHT * (0.5 + 0.5 * OPP_HAND_SCALE)
	for index in range(count):
		var t := 0.5 if count <= 1 else float(index) / float(count - 1)
		var center_offset := (2.0 * t - 1.0)
		transforms.append({
			"pos": Vector2(index * advance, peek_y + OPP_HAND_ARC * center_offset * center_offset),
			"rot": -OPP_HAND_MAX_ROTATION * center_offset,
		})
	return transforms


func _apply_opponent_hand_transforms() -> void:
	if not is_node_ready() or not has_node("%OpponentHand"):
		return
	var host := %OpponentHand as Control
	var cards: Array = host.get_children()
	var right_pad := 220.0 if host.size.x > 900.0 else 188.0
	var inner := maxf(80.0, host.size.x - 16.0 - right_pad)
	var advance := OPP_HAND_ADVANCE
	if cards.size() > 1:
		var needed := HAND_CARD_WIDTH * OPP_HAND_SCALE + (cards.size() - 1) * advance
		if needed > inner:
			advance = maxf(22.0, (inner - HAND_CARD_WIDTH * OPP_HAND_SCALE) / float(cards.size() - 1))
	var transforms := _opponent_hand_layout(cards.size(), advance)
	var row_width := HAND_CARD_WIDTH * OPP_HAND_SCALE + maxf(0.0, cards.size() - 1) * advance
	var origin_x := 16.0 + maxf(0.0, (inner - row_width) * 0.5)
	for index in range(cards.size()):
		var card: Control = cards[index]
		card.scale = Vector2(OPP_HAND_SCALE, OPP_HAND_SCALE)
		card.pivot_offset = Vector2(HAND_CARD_WIDTH, HAND_CARD_HEIGHT) * 0.5
		card.position = Vector2(origin_x + transforms[index].pos.x, transforms[index].pos.y)
		card.rotation_degrees = transforms[index].rot


func opponent_card_visual_rect(card: Control) -> Rect2:
	var xform := card.get_global_transform()
	var corners := PackedVector2Array([
		Vector2.ZERO,
		Vector2(card.size.x, 0.0),
		card.size,
		Vector2(0.0, card.size.y),
	])
	var first := xform * corners[0]
	var min_p := first
	var max_p := first
	for corner in corners:
		var point: Vector2 = xform * corner
		min_p.x = minf(min_p.x, point.x)
		min_p.y = minf(min_p.y, point.y)
		max_p.x = maxf(max_p.x, point.x)
		max_p.y = maxf(max_p.y, point.y)
	return Rect2(min_p, max_p - min_p)


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
	_apply_hand_transforms()
	call_deferred("_apply_hand_transforms")
	_apply_card_states()

func _resolve_card_view(card_data: Dictionary, mode: String):
	var instance_id := str(card_data.get("instance_id", ""))
	var card = _card_registry.get(instance_id)
	if card == null or not is_instance_valid(card):
		card = CardViewScene.instantiate()
		_card_registry[instance_id] = card
		card.card_pressed.connect(_on_registered_card_pressed.bind(card))
		card.card_dropped.connect(_on_registered_card_dropped.bind(card))
		card.card_drag_started.connect(_on_card_drag_started)
		card.inspected.connect(_on_card_inspected)
	card.native_tooltip = false
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

func _is_legal_source(instance_id: String) -> bool:
	if instance_id.is_empty():
		return false
	for action in model._legal_actions:
		if str(action.source_id) == instance_id:
			return true
	return false


func _reject_illegal_source(instance_id: String) -> void:
	model.cancel()
	var reason := str(_coach_state.get("source_reasons", {}).get(instance_id, ""))
	if not reason.is_empty():
		model.status_message = reason
		_present_status(reason)
	_refresh_coach()


func _try_select_source(instance_id: String) -> bool:
	if _is_legal_source(instance_id):
		model.select_source(instance_id)
		return true
	_reject_illegal_source(instance_id)
	return false


func _source_can_aim() -> bool:
	if _input_locked or model.selected_source_id.is_empty() or not _is_legal_source(model.selected_source_id):
		return false
	if not model.highlighted_targets().is_empty():
		return true
	for zone in ["support", "frontline"]:
		if not model.highlighted_slots(zone).is_empty():
			return true
	return false


func _on_card_pressed(instance_id: String) -> void:
	if _reject_locked(): return
	_clear_rejection()
	if not _try_select_source(instance_id):
		return
	var action = model.immediate_action()
	if action != null: action_requested.emit(action)
	_present_status("")
	_refresh_coach()


func _on_card_drag_started(instance_id: String) -> void:
	if _reject_locked(): return
	_clear_rejection()
	if not _try_select_source(instance_id):
		return
	_present_status("")
	_refresh_coach()

func _on_board_card_pressed(instance_id: String) -> void:
	if _reject_locked(): return
	_clear_rejection()
	if model.selected_source_id.is_empty():
		if not _try_select_source(instance_id):
			return
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
	if not _try_select_source(instance_id):
		return
	_on_slot_pressed(zone, slot)

func _on_target_dropped(source_id: String, target_id: String) -> void:
	if _reject_locked(): return
	_clear_rejection()
	if not _try_select_source(source_id):
		return
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
		_present_status("")
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
	_present_status("")
	_refresh_coach()

func _reject_locked() -> bool:
	if not _input_locked: return false
	show_rejection("input_locked", LocaleScript.ui("reason.locked"))
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_back()

func _refresh_highlights() -> void:
	var targets := model.highlighted_targets()
	%OpponentSupport.set_highlights([], targets)
	%Frontline.set_highlights(model.highlighted_slots("frontline"), targets)
	%PlayerSupport.set_highlights(model.highlighted_slots("support"), targets)
	%OpponentHQ.set_highlight(str(%OpponentHQ.card_data.get("instance_id", "")) in targets)
	%PlayerHQ.set_highlight(str(%PlayerHQ.card_data.get("instance_id", "")) in targets)
	%OpponentHQ.set_meta("can_receive_drop", str(%OpponentHQ.card_data.get("instance_id", "")) in targets)
	%PlayerHQ.set_meta("can_receive_drop", str(%PlayerHQ.card_data.get("instance_id", "")) in targets)
	_present_command(%ConfirmButton, not _input_locked and model.can_confirm())
	_present_command(%CancelButton, not _input_locked and not model.selected_source_id.is_empty())
	_apply_card_states()
	_refresh_end_turn_state()
	_refresh_coach_objective()
	_sync_aiming()


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
	_present_command(%EndTurnButton, not _input_locked and can_end)
	%EndTurnButton.remove_theme_stylebox_override("normal")
	if not can_end:
		%EndTurnButton.set_meta("action_state", "disabled")
	elif bool(_coach_state.get("end_turn_only", false)):
		%EndTurnButton.set_meta("action_state", "strong")
		var style := BattlefieldChrome.plaque(Color("2b2d24"), Color("f0cf55"), 3, 4, 8)
		%EndTurnButton.add_theme_stylebox_override("normal", style)
	else:
		%EndTurnButton.set_meta("action_state", "normal")


func _present_command(button: BaseButton, available: bool) -> void:
	button.visible = available
	button.disabled = not available


func _present_status(text: String) -> void:
	%StatusLabel.text = text
	%StatusLabel.visible = not text.strip_edges().is_empty()
	%StatusLabel.custom_minimum_size.y = 20.0 if %StatusLabel.visible else 0.0


func _refresh_coach_objective() -> void:
	var next := _rejection_message if not _rejection_message.is_empty() else str(_coach_state.get("objective", LocaleScript.ui("coach.none")))
	if model.can_confirm() and _rejection_message.is_empty():
		next = LocaleScript.ui("coach.confirm")
	var idle := _rejection_message.is_empty() and str(_coach_state.get("next_kind", "")) in ["end_turn", "none", "opponent_turn"]
	if idle:
		next = ""
	%CoachObjective.visible = not next.is_empty()
	if %CoachObjective.text != next:
		%CoachObjective.text = next
		if not idle:
			_pulse_coach()
	%CoachObjective.tooltip_text = next
	_style_coach_for_rejection(not _rejection_message.is_empty())


func _apply_card_states() -> void:
	var legal_ids: Array = _coach_state.get("legal_source_ids", [])
	var reasons: Dictionary = _coach_state.get("source_reasons", {})
	for child in %PlayerHand.get_children():
		_apply_source_state(child, legal_ids, reasons)
	for zone in [%OpponentSupport, %Frontline, %PlayerSupport]:
		for card in zone.card_views():
			_apply_source_state(card, legal_ids, reasons)
			card.set_duty_caption(_duty_caption(card.card_data))
	_refresh_inspect()


func _apply_source_state(card, legal_ids: Array, reasons: Dictionary) -> void:
	var instance_id := str(card.card_data.get("instance_id", ""))
	if instance_id == model.selected_source_id:
		card.set_action_state("selected")
	elif instance_id in legal_ids:
		card.set_action_state("legal")
	elif reasons.has(instance_id):
		card.set_action_state("unavailable", str(reasons[instance_id]))
	else:
		card.set_action_state("normal")
	card.set_meta("can_receive_drop", instance_id in model.highlighted_targets())


func _duty_caption(card: Dictionary) -> String:
	if str(card.get("category", "")) != "Unit":
		return ""
	if MatchCoachModelScript._just_deployed(card, snapshot):
		return LocaleScript.ui("duty.deployed")
	if MatchCoachModelScript._operations_spent(card):
		return LocaleScript.ui("duty.spent")
	if int(card.get("operations_used", 0)) > 0:
		return LocaleScript.ui("duty.ready_more")
	return LocaleScript.ui("duty.ready")


func _clear_rejection() -> void:
	_rejection_message = ""
	model.rejection_code = ""
	if is_node_ready():
		_present_status("")


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
	%ConcedeDialog.title = LocaleScript.ui("match.concede_title")
	%ConcedeDialog.dialog_text = LocaleScript.ui("match.concede_body")
	%ConcedeDialog.ok_button_text = LocaleScript.ui("match.concede_ok")
	%ConcedeDialog.cancel_button_text = LocaleScript.ui("match.concede_cancel")
	if has_node("%SettingsButton"):
		%SettingsButton.text = LocaleScript.ui("settings.menu")
	set_animation_mode(animation_mode)


func _status_strip(side: Dictionary, include_discard: bool) -> String:
	var parts: PackedStringArray = PackedStringArray([
		"● %s %d" % [LocaleScript.ui("status.hq"), int(side.get("hq_defense", 0))],
		"%s %d" % [LocaleScript.ui("status.hand"), (side.get("hand", []) as Array).size()],
		"%s %d" % [LocaleScript.ui("status.deck"), int(side.get("deck_count", 0))],
	])
	if include_discard:
		parts.append("%s %d" % [LocaleScript.ui("status.discard"), (side.get("discard", []) as Array).size()])
	return "   ".join(parts)


func _install_lane_chrome() -> void:
	_attach_lane(get_node("Margin/Columns/Board/OpponentArea") as Control, Color(0.28, 0.12, 0.10, 0.18), "OpponentLaneChip", "zone.enemy_support")
	_attach_lane(get_node("Margin/Columns/Board/PlayerArea") as Control, Color(0.10, 0.16, 0.20, 0.18), "PlayerLaneChip", "zone.player_support")


func _remember_card_titles() -> void:
	for card in _public_cards():
		var instance_id := str(card.get("instance_id", ""))
		var title := str(card.get("title", ""))
		if not instance_id.is_empty() and not title.is_empty():
			_card_titles[instance_id] = title


func _public_cards() -> Array:
	var cards: Array = []
	var players: Dictionary = snapshot.get("players", {})
	for side_id in ["player", "opponent"]:
		var side: Dictionary = players.get(side_id, {})
		for zone_name in ["hand", "support_line", "discard"]:
			for slot in side.get(zone_name, []):
				if slot is Dictionary:
					cards.append(slot)
		var headquarters: Variant = side.get("headquarters", {})
		if headquarters is Dictionary and not (headquarters as Dictionary).is_empty():
			cards.append(headquarters)
	for slot in snapshot.get("frontline", []):
		if slot is Dictionary:
			cards.append(slot)
	return cards


func _refresh_guard_links() -> void:
	if not is_node_ready():
		return
	var segments: Array = []
	_collect_guard_segments(%PlayerSupport, %PlayerHQ, segments)
	_collect_guard_segments(%OpponentSupport, %OpponentHQ, segments)
	_collect_guard_segments(%Frontline, null, segments)
	_guard_segments = segments
	queue_redraw()


func _draw() -> void:
	for segment in _guard_segments:
		if not (segment is Dictionary):
			continue
		var from: Vector2 = segment.get("from", Vector2.ZERO)
		var to: Vector2 = segment.get("to", Vector2.ZERO)
		var color: Color = segment.get("color", Color(0.86, 0.74, 0.42, 0.7))
		draw_line(from, to, color, 2.2, true)
		draw_circle(from, 3.2, color)
		draw_circle(to, 2.4, color)
	_draw_aim_arrow()


func _sync_aiming() -> void:
	var aiming := _source_can_aim()
	set_process(aiming)
	if not aiming:
		_aim_legal = false
		queue_redraw()


func _process(_delta: float) -> void:
	if not _source_can_aim():
		_aim_legal = false
		set_process(false)
		queue_redraw()
		return
	_aim_legal = _legal_destination_under_mouse()
	queue_redraw()


func _aim_source_point() -> Vector2:
	var card = card_view(model.selected_source_id)
	if card != null and is_instance_valid(card) and card.is_visible_in_tree():
		return _to_link_space(card.get_global_rect().get_center())
	for hq in [%PlayerHQ, %OpponentHQ]:
		if str(hq.card_data.get("instance_id", "")) == model.selected_source_id:
			return _to_link_space(hq.get_global_rect().get_center())
	return Vector2.ZERO


func _legal_destination_under_mouse() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered is HqView:
			return str((hovered as HqView).card_data.get("instance_id", "")) in model.highlighted_targets()
		if hovered is CardView:
			return str((hovered as CardView).card_data.get("instance_id", "")) in model.highlighted_targets()
		if hovered.get_parent() is ZoneView and "slot_index" in hovered:
			return int(hovered.slot_index) in model.highlighted_slots(str((hovered.get_parent() as ZoneView).zone_name))
		hovered = hovered.get_parent() as Control
	return false


func _draw_aim_arrow() -> void:
	if not _source_can_aim():
		return
	var from := _aim_source_point()
	var to := _to_link_space(get_global_mouse_position())
	if from == Vector2.ZERO or from.distance_to(to) < 18.0:
		return
	var color := Color(0.96, 0.84, 0.38, 0.96) if _aim_legal else Color(0.86, 0.74, 0.42, 0.78)
	var mid := (from + to) * 0.5
	var along := to - from
	var lift := Vector2(-along.y, along.x).normalized() * minf(48.0, along.length() * 0.22)
	if lift.y > 0.0:
		lift = -lift
	var ctrl := mid + lift
	var points := PackedVector2Array()
	for step in range(17):
		var t := float(step) / 16.0
		var inv := 1.0 - t
		points.append(from * inv * inv + ctrl * 2.0 * inv * t + to * t * t)
	draw_polyline(points, Color(0.08, 0.07, 0.04, 0.45), 5.2, true)
	draw_polyline(points, color, 3.1, true)
	var tip_dir := (to - points[14]).normalized()
	var head := PackedVector2Array([
		to,
		to - tip_dir.rotated(0.48) * 16.0,
		to - tip_dir.rotated(-0.48) * 16.0,
	])
	draw_colored_polygon(head, color)
	draw_circle(from, 4.0, color)


func _collect_guard_segments(zone, hq, segments: Array) -> void:
	var cards: Array = zone.card_views()
	for card in cards:
		if not _card_has_keyword(card.card_data, "Guard"):
			continue
		var from := _to_link_space(card.get_global_rect().get_center())
		var slot := int(card.card_data.get("slot", -1))
		var owner_id := str(card.card_data.get("owner_id", ""))
		if hq != null and slot in [1, 2]:
			segments.append({"from": from, "to": _to_link_space(hq.get_global_rect().get_center()), "color": Color(0.86, 0.74, 0.42, 0.78)})
		for other in cards:
			if other == card:
				continue
			if str(other.card_data.get("owner_id", "")) != owner_id:
				continue
			var other_slot := int(other.card_data.get("slot", -2))
			if absi(other_slot - slot) != 1:
				continue
			segments.append({"from": from, "to": _to_link_space(other.get_global_rect().get_center()), "color": Color(0.78, 0.7, 0.4, 0.55)})


func _to_link_space(point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * point


func _card_has_keyword(card: Dictionary, name: String) -> bool:
	for keyword in card.get("keywords", []):
		if str(keyword) == name:
			return true
	return false


func _attach_lane(host: Control, tint: Color, chip_name: String, key: String) -> void:
	if host.get_node_or_null("LaneBand") == null:
		var band := ColorRect.new()
		band.name = "LaneBand"
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.color = tint
		band.material = BattlefieldChrome.felt_material(0.08, 0.04)
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
		chip.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.04, 0.85))
		chip.add_theme_constant_override("outline_size", 3)
		chip.position = Vector2(8, 2)
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
	var bar := %TurnLabel.get_parent() as Control
	if not has_node("%HelpButton"):
		var help := Button.new()
		help.name = "HelpButton"
		help.text = LocaleScript.ui("match.help")
		help.custom_minimum_size = Vector2(36, 28)
		help.pressed.connect(func() -> void: how_to_play_requested.emit())
		_style_quiet_chip(help)
		bar.add_child(help)
		help.owner = self
		help.unique_name_in_owner = true
		_place_before_log_gap(help)
	if has_node("%SettingsButton"):
		return
	var settings := Button.new()
	settings.name = "SettingsButton"
	settings.text = LocaleScript.ui("settings.menu")
	settings.custom_minimum_size = Vector2(64, 28)
	settings.pressed.connect(_open_settings)
	_style_quiet_chip(settings)
	bar.add_child(settings)
	settings.owner = self
	settings.unique_name_in_owner = true
	_place_before_log_gap(settings)


func _style_quiet_chip(button: Button) -> void:
	var quiet := StyleBoxFlat.new()
	quiet.bg_color = Color(0, 0, 0, 0)
	quiet.set_border_width_all(0)
	quiet.set_content_margin_all(6)
	var hover := BattlefieldChrome.plaque(Color(0.12, 0.11, 0.07, 0.55), Color(0.78, 0.66, 0.38, 0.55), 1, 2, 6)
	button.add_theme_stylebox_override("normal", quiet)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.78, 0.72, 0.56, 0.92))


func _place_before_log_gap(button: Control) -> void:
	var bar := button.get_parent()
	var gap := bar.get_node_or_null("LogGap")
	if gap != null:
		bar.move_child(button, gap.get_index())


func _install_inspect_panel() -> void:
	if has_node("%InspectPanel"):
		_inspect_panel = %InspectPanel
		_inspect_text = _inspect_panel.get_node_or_null("InspectText") as Label
		return
	_inspect_panel = PanelContainer.new()
	_inspect_panel.name = "InspectPanel"
	_inspect_panel.unique_name_in_owner = true
	_inspect_panel.visible = false
	_inspect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_panel.z_index = 24
	_inspect_panel.custom_minimum_size = Vector2(260, 0)
	_inspect_panel.add_theme_stylebox_override("panel", BattlefieldChrome.plaque(Color(0.07, 0.08, 0.06, 0.94), Color(0.82, 0.70, 0.40, 0.92), 2, 6, 12))
	_inspect_text = Label.new()
	_inspect_text.name = "InspectText"
	_inspect_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_text.add_theme_font_size_override("font_size", 14)
	_inspect_text.add_theme_color_override("font_color", Color("f2e6c4"))
	_inspect_text.custom_minimum_size = Vector2(240, 0)
	_inspect_panel.add_child(_inspect_text)
	add_child(_inspect_panel)


func _on_hq_inspected(hq: HqView) -> void:
	_on_card_inspected(hq.card_data)


func _on_card_inspected(data: Dictionary) -> void:
	_hovered_inspect = data.duplicate(true)
	_refresh_inspect()


func _inspect_data() -> Dictionary:
	if not _hovered_inspect.is_empty() and not bool(_hovered_inspect.get("hidden", false)):
		return _hovered_inspect
	if model.selected_source_id.is_empty():
		return {}
	var selected = card_view(model.selected_source_id)
	if selected != null and is_instance_valid(selected):
		return selected.card_data
	for hq in [%PlayerHQ, %OpponentHQ]:
		if str(hq.card_data.get("instance_id", "")) == model.selected_source_id:
			return hq.card_data
	return {}


func _refresh_inspect() -> void:
	if _inspect_panel == null or not is_instance_valid(_inspect_panel):
		return
	var data := _inspect_data()
	if data.is_empty() or bool(data.get("hidden", false)):
		_inspect_panel.visible = false
		return
	var text := CardView.inspect_copy(data)
	var hovered: Variant = card_view(str(data.get("instance_id", "")))
	if hovered is CardView and not str((hovered as CardView).tooltip_text).is_empty():
		text = (hovered as CardView).tooltip_text
	if _inspect_text != null:
		_inspect_text.text = text
	_inspect_panel.visible = not text.is_empty()
	_place_inspect()


func _place_inspect() -> void:
	if _inspect_panel == null or not _inspect_panel.visible:
		return
	var panel_size := Vector2(maxf(_inspect_panel.get_combined_minimum_size().x, 260.0), maxf(_inspect_panel.get_combined_minimum_size().y, 72.0))
	var area := get_global_rect()
	var hand_top: float = %HandScroll.get_global_rect().position.y if has_node("%HandScroll") else area.end.y - HAND_STRIP_HEIGHT
	var pos := Vector2(area.end.x - panel_size.x - 12.0, hand_top - panel_size.y - 8.0)
	pos.x = clampf(pos.x, area.position.x + 8.0, area.end.x - panel_size.x - 8.0)
	pos.y = clampf(pos.y, area.position.y + 36.0, area.end.y - panel_size.y - 8.0)
	_inspect_panel.global_position = pos


func _style_table_chrome() -> void:
	%TimelinePanel.material = BattlefieldChrome.paper_material(0.09)
	for pile in [%OpponentDeckPile, %OpponentDiscardPile, %PlayerDeckPile, %PlayerDiscardPile]:
		pile.material = BattlefieldChrome.paper_material(0.10)
	%CreditLabel.add_theme_color_override("font_color", Color("f2dd9a"))
	_credit_chip().tooltip_text = LocaleScript.ui("status.credit_hint")


func _style_coach() -> void:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 2
	empty.content_margin_right = 2
	empty.content_margin_top = 2
	empty.content_margin_bottom = 2
	%CoachObjective.add_theme_stylebox_override("normal", empty)
	%CoachObjective.add_theme_font_size_override("font_size", 14)
	%CoachObjective.add_theme_color_override("font_color", Color(0.80, 0.72, 0.52, 0.86))
	%CoachObjective.custom_minimum_size.y = 22
	%CoachObjective.clip_contents = true
	%CoachObjective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _style_coach_for_rejection(rejected: bool) -> void:
	%CoachObjective.add_theme_color_override("font_color", Color("e8c36a") if rejected else Color(0.80, 0.72, 0.52, 0.86))


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
