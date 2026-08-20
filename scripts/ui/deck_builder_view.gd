class_name DeckBuilderView
extends Control

signal play_requested(deck_id: String, difficulty: String)
signal home_requested

const DeckValidator = preload("res://scripts/core/deck_validator.gd")
const DeckStore = preload("res://scripts/ui/deck_store.gd")
const OnboardingStore = preload("res://scripts/ui/onboarding_store.gd")
const CardViewScene = preload("res://scenes/ui/card_view.tscn")
const LocaleScript = preload("res://scripts/ui/locale.gd")


class DeckBuilderViewModel:
	extends RefCounted

	var catalog
	var decks: Dictionary = {}
	var selected_deck_id := ""
	var filters := {"search": "", "nation": "", "category": "", "unit_type": "", "rarity": "", "cost": -1}

	func _init(content_catalog, loaded_decks: Dictionary = {}) -> void:
		catalog = content_catalog
		if loaded_decks.is_empty():
			for deck_value in catalog.decks:
				var deck: Dictionary = deck_value
				decks[str(deck.id)] = deck.duplicate(true)
		else:
			decks = loaded_decks.duplicate(true)

	func select_deck(deck_id: String) -> void:
		if decks.has(deck_id):
			selected_deck_id = deck_id

	func merge_session_deck(deck: Dictionary) -> void:
		var deck_id := str(deck.get("id", ""))
		if deck_id.is_empty() or not (deck.get("cards", null) is Array):
			return
		decks[deck_id] = deck.duplicate(true)
		selected_deck_id = deck_id

	func card_count() -> int:
		return _cards().size()

	func validation() -> Dictionary:
		return DeckValidator.validate(_cards(), catalog.cards_by_id)

	func selected_deck() -> Dictionary:
		if not decks.has(selected_deck_id):
			return {}
		return (decks[selected_deck_id] as Dictionary).duplicate(true)

	func add_card(card_id: String) -> void:
		if not catalog.cards_by_id.has(card_id) or selected_deck_id.is_empty():
			return
		_ensure_user_copy()
		_cards().append(card_id)

	func remove_card(card_id: String) -> void:
		if selected_deck_id.is_empty() or card_id not in _cards():
			return
		_ensure_user_copy()
		_cards().erase(card_id)

	func set_filter(key: String, value: Variant) -> void:
		if filters.has(key):
			filters[key] = value

	func filtered_cards() -> Array:
		var result: Array = []
		var search := str(filters.search).strip_edges().to_lower()
		for card_value in catalog.cards:
			var card: Dictionary = card_value
			if not search.is_empty() and search not in (str(card.get("title", "")) + " " + str(card.get("description", ""))).to_lower():
				continue
			var rejected := false
			for key in ["nation", "category", "unit_type", "rarity"]:
				if not str(filters[key]).is_empty() and str(card.get(key, "")) != str(filters[key]):
					rejected = true
					break
			if rejected or (int(filters.cost) >= 0 and int(card.get("deployment_cost", -1)) != int(filters.cost)):
				continue
			result.append(card.duplicate(true))
		return result

	func user_decks() -> Array:
		var result: Array = []
		for deck_id in decks:
			if str(deck_id).begins_with("user-"):
				result.append((decks[deck_id] as Dictionary).duplicate(true))
		return result

	func _cards() -> Array:
		if not decks.has(selected_deck_id):
			return []
		return (decks[selected_deck_id] as Dictionary).cards

	func _ensure_user_copy() -> void:
		if selected_deck_id.begins_with("user-"):
			return
		var source: Dictionary = decks[selected_deck_id]
		var user_id := "user-%s" % selected_deck_id
		if decks.has(user_id):
			selected_deck_id = user_id
			return
		var copy := source.duplicate(true)
		copy.id = user_id
		copy.name = "%s Copy" % _deck_name(source)
		decks[user_id] = copy
		selected_deck_id = user_id

	func _deck_name(deck: Dictionary) -> String:
		return str(deck.get("name", str(deck.get("id", "Deck")).replace("-", " ").capitalize()))


var router
var catalog
var model: DeckBuilderViewModel
var store
var onboarding_store
var difficulty := "standard"


func _ready() -> void:
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func selected_deck() -> Dictionary:
	return {} if model == null else model.selected_deck()


func _apply_responsive_layout() -> void:
	var compact := size.x <= 1100.0
	%Filters.custom_minimum_size.x = 152.0 if compact else 184.0
	%DeckPanel.custom_minimum_size.x = 240.0 if compact else 284.0
	%Filters.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	%DeckPanel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var filter_margin := get_node("Margin/Page/Workspace/Filters/Margin") as MarginContainer
	for side in ["margin_left", "margin_right"]:
		filter_margin.add_theme_constant_override(side, 6 if compact else 10)
	var page_margin := get_node("Margin") as MarginContainer
	page_margin.offset_left = 10.0 if compact else 16.0
	page_margin.offset_right = -10.0 if compact else -16.0


func initialize(main, payload: Dictionary) -> void:
	router = main
	catalog = payload.get("catalog")
	if catalog == null:
		return
	store = DeckStore.new(str(payload.get("store_path", DeckStore.DEFAULT_PATH)))
	onboarding_store = payload.get("onboarding_store")
	if onboarding_store == null:
		onboarding_store = OnboardingStore.new(str(payload.get("onboarding_path", "user://onboarding.json")))
	model = DeckBuilderViewModel.new(catalog, store.load_all(catalog.decks))
	var session_deck: Dictionary = payload.get("player_deck", {})
	if session_deck.is_empty():
		model.select_deck(str(payload.get("deck_id", "us-starter")))
	else:
		model.merge_session_deck(session_deck)
	# Never strand the player on an invalid deck (e.g. a stale saved user deck
	# from a previous session). If the selected deck fails validation, fall
	# back to a valid shipped starter so Start Battle is always available.
	if not model.validation().valid:
		model.select_deck("us-starter")
		if not model.validation().valid:
			for deck_id in model.decks:
				model.select_deck(deck_id)
				if model.validation().valid:
					break
	difficulty = str(payload.get("difficulty", "standard"))
	_populate_controls()
	_apply_onboarding_hint(onboarding_store.load())
	_bind_chrome()
	_refresh()
	if not store.last_error.is_empty():
		%Validation.text = store.last_error


func _populate_controls() -> void:
	_populate_deck_selector()
	for filter_data in [[%NationFilter, "nation"], [%CategoryFilter, "category"], [%UnitTypeFilter, "unit_type"], [%RarityFilter, "rarity"]]:
		var control := filter_data[0] as OptionButton
		control.fit_to_longest_item = false
		control.clear()
		control.add_item(LocaleScript.ui("builder.filter_all"))
		control.set_item_metadata(0, "")
		var values: Array[String] = []
		for card_value in catalog.cards:
			var value := str((card_value as Dictionary).get(filter_data[1], ""))
			if not value.is_empty() and value not in values:
				values.append(value)
		values.sort()
		for value in values:
			control.add_item(LocaleScript.filter_value(str(filter_data[1]), value))
			control.set_item_metadata(control.item_count - 1, value)
	var costs := %CostFilter as OptionButton
	costs.fit_to_longest_item = false
	costs.clear()
	costs.add_item(LocaleScript.ui("builder.filter_cost"), -1)
	for cost in range(0, 8):
		costs.add_item(str(cost), cost)
	for button in (%Difficulty as HBoxContainer).get_children():
		(button as Button).button_pressed = (button as Button).name.to_lower() == difficulty


func _populate_deck_selector() -> void:
	var selector := %DeckSelector as OptionButton
	selector.clear()
	for deck_id in model.decks:
		selector.add_item(LocaleScript.deck_title(str(deck_id)))
		selector.set_item_metadata(selector.item_count - 1, deck_id)
		if deck_id == model.selected_deck_id:
			selector.select(selector.item_count - 1)


func _refresh() -> void:
	_refresh_catalog()
	_refresh_deck()


func _refresh_catalog() -> void:
	for child in %CatalogGrid.get_children():
		child.queue_free()
	for card_value in model.filtered_cards():
		var card: Dictionary = card_value
		var view = CardViewScene.instantiate()
		%CatalogGrid.add_child(view)
		card.instance_id = str(card.id)
		view.bind(card, "catalog")
		view.card_pressed.connect(_on_add_card)


func _refresh_deck() -> void:
	for child in %DeckRows.get_children():
		child.queue_free()
	var counts := {}
	var nations := {}
	for card_id in model._cards():
		counts[card_id] = int(counts.get(card_id, 0)) + 1
		var nation := str((catalog.cards_by_id.get(card_id, {}) as Dictionary).get("nation", "Unknown"))
		nations[nation] = int(nations.get(nation, 0)) + 1
	for card_id in counts:
		var row := Button.new()
		row.text = "%dx  %s" % [counts[card_id], str((catalog.cards_by_id[card_id] as Dictionary).get("title", card_id))]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.clip_text = true
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(_on_remove_card.bind(card_id))
		%DeckRows.add_child(row)
	%NationDistribution.text = "  ".join(nations.keys().map(func(key): return "%s %d" % [key, nations[key]]))
	%CardCount.text = "%d / 40" % model.card_count()
	var validation := model.validation()
	var status := _readiness_status(validation)
	%StarterStatus.text = status
	%Validation.text = status
	%PlayButton.disabled = not validation.valid


func _readiness_status(validation: Dictionary) -> String:
	if not validation.valid:
		var errors: Array = validation.get("errors", [])
		if errors.is_empty():
			return LocaleScript.ui("builder.invalid")
		return str(errors[0]).replace("_", " ").capitalize()
	if not model.selected_deck_id.begins_with("user-") and model.card_count() == 40:
		return LocaleScript.ui("builder.starter_ready")
	return LocaleScript.ui("builder.ready") % model.card_count()


func _apply_onboarding_hint(state: Dictionary) -> void:
	var show_hint := not bool(state.get("deck_hint_dismissed", false))
	%StarterHint.visible = show_hint
	%DismissHint.visible = show_hint


func _on_dismiss_hint_pressed() -> void:
	onboarding_store.dismiss_deck_hint()
	_apply_onboarding_hint(onboarding_store.load())


func _on_add_card(card_id: String) -> void:
	var previous_deck_id := model.selected_deck_id
	model.add_card(card_id)
	if model.selected_deck_id != previous_deck_id:
		_populate_deck_selector()
	_refresh_deck()


func _on_remove_card(card_id: String) -> void:
	var previous_deck_id := model.selected_deck_id
	model.remove_card(card_id)
	if model.selected_deck_id != previous_deck_id:
		_populate_deck_selector()
	_refresh_deck()


func _on_deck_selected(index: int) -> void:
	model.select_deck(str(%DeckSelector.get_item_metadata(index)))
	_refresh_deck()


func _on_search_changed(value: String) -> void:
	model.set_filter("search", value)
	_refresh_catalog()


func _on_option_selected(index: int, key: String, control_path: NodePath) -> void:
	var control := get_node(control_path) as OptionButton
	var selected := "" if index == 0 else str(control.get_item_metadata(index))
	model.set_filter(key, selected)
	_refresh_catalog()


func _on_cost_selected(index: int) -> void:
	model.set_filter("cost", -1 if index == 0 else int(%CostFilter.get_item_text(index)))
	_refresh_catalog()


func _on_difficulty_pressed(value: String) -> void:
	difficulty = value
	for button in (%Difficulty as HBoxContainer).get_children():
		(button as Button).button_pressed = (button as Button).name.to_lower() == difficulty


func _on_save_pressed() -> void:
	if store.save_user_decks(model.user_decks(), catalog.decks):
		%Validation.text = LocaleScript.ui("builder.saved")
	else:
		%Validation.text = store.last_error


func _bind_chrome() -> void:
	if has_node("%TitleLabel"):
		%TitleLabel.text = LocaleScript.ui("builder.title")
		%TitleLabel.add_theme_color_override("font_color", Color("f2dd9a"))
	if has_node("%HomeButton"):
		%HomeButton.text = LocaleScript.ui("builder.home")
	if has_node("%PlayButton"):
		%PlayButton.text = LocaleScript.ui("builder.play")
	if has_node("%StarterHint"):
		%StarterHint.text = LocaleScript.ui("builder.hint")
	if has_node("%SaveButton"):
		%SaveButton.text = LocaleScript.ui("builder.save")
	if has_node("%FilterHeading"):
		%FilterHeading.text = LocaleScript.ui("builder.filter_heading")
	if has_node("%Search"):
		%Search.placeholder_text = LocaleScript.ui("builder.search")
	if has_node("%NationLabel"):
		%NationLabel.text = LocaleScript.ui("builder.nation")
	if has_node("%CategoryLabel"):
		%CategoryLabel.text = LocaleScript.ui("builder.category")
	if has_node("%UnitTypeLabel"):
		%UnitTypeLabel.text = LocaleScript.ui("builder.unit_type")
	if has_node("%RarityLabel"):
		%RarityLabel.text = LocaleScript.ui("builder.rarity")
	if has_node("%CostLabel"):
		%CostLabel.text = LocaleScript.ui("builder.cost")
	if has_node("%DeckHeading"):
		%DeckHeading.text = LocaleScript.ui("builder.deck_heading")
	for pair in [["Easy", "builder.diff.easy"], ["Standard", "builder.diff.standard"], ["Hard", "builder.diff.hard"]]:
		var button := %Difficulty.get_node_or_null(str(pair[0])) as Button
		if button != null:
			button.text = LocaleScript.ui(str(pair[1]))


func _on_home_pressed() -> void:
	home_requested.emit()


func _on_play_pressed() -> void:
	if not model.validation().valid:
		return
	play_requested.emit(model.selected_deck_id, difficulty)


func handle_back() -> bool:
	_on_home_pressed()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not %PlayButton.disabled:
		_on_play_pressed()
		get_viewport().set_input_as_handled()
