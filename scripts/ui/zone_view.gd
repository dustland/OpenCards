class_name ZoneView
extends Control

signal slot_pressed(zone: String, slot: int)
signal card_pressed(instance_id: String)
signal card_dropped(instance_id: String, zone: String, slot: int)
signal target_dropped(source_id: String, target_id: String)

const CardViewScene = preload("res://scenes/ui/card_view.tscn")

@export var zone_name := "support"
@export var slot_count := 4
@export var grid_cell_count := 5
@export var slot_width := 80.0
@export var slot_gap := 8.0
var highlighted_slots: Array = []
var highlighted_targets: Array = []
var input_locked := false
var lane_caption := ""

func _ready() -> void:
	var card_size: Vector2 = CardView.MODE_SIZES["battlefield"]
	slot_width = card_size.x
	custom_minimum_size = Vector2(_grid_width(), card_size.y)

func render(cards: Array, hidden := false, card_resolver: Callable = Callable()) -> void:
	for child in get_children():
		if child is Control and child.get_child_count() > 0 and child.get_child(0) is CardView:
			var retained := child.get_child(0)
			child.remove_child(retained)
			add_child(retained)
	for child in get_children():
		if child is CardView:
			continue
		if not (child is _DropSlot):
			continue
		child.free()
	for index in range(slot_count):
		var slot := _DropSlot.new()
		slot.custom_minimum_size = _slot_size()
		slot.zone = zone_name
		slot.slot_index = index
		slot.input_locked = input_locked
		slot.disabled = input_locked
		var slot_style := _slot_style(zone_name)
		slot.add_theme_stylebox_override("normal", slot_style)
		slot.add_theme_stylebox_override("hover", slot_style)
		slot.add_theme_stylebox_override("disabled", slot_style)
		slot.pressed.connect(func() -> void: slot_pressed.emit(zone_name, index))
		slot.card_dropped.connect(func(instance_id: String) -> void: card_dropped.emit(instance_id, zone_name, index))
		add_child(slot)
		var card_data: Variant = cards[index] if index < slot_count and index < cards.size() else null
		if card_data is Dictionary:
			var card = card_resolver.call(card_data, "hidden" if hidden else "battlefield") if card_resolver.is_valid() else CardViewScene.instantiate()
			if card.get_parent() != null:
				card.get_parent().remove_child(card)
			slot.add_child(card)
			card.rotation_degrees = 0.0
			card.bind(card_data, "hidden" if hidden else "battlefield")
			card.set_anchors_preset(Control.PRESET_TOP_LEFT)
			card.disabled = input_locked
			card.set_meta("owner_id", str(card_data.get("owner_id", "")))
			if not card_resolver.is_valid():
				if not card.card_pressed.is_connected(_relay_card_pressed): card.card_pressed.connect(_relay_card_pressed)
				if not card.card_dropped.is_connected(_relay_target_dropped): card.card_dropped.connect(_relay_target_dropped)
	for child in get_children():
		if child is CardView:
			remove_child(child)
	_apply_highlights()
	_layout_slots()

func _relay_card_pressed(instance_id: String) -> void:
	card_pressed.emit(instance_id)

func _relay_target_dropped(source_id: String, target_id: Variant) -> void:
	target_dropped.emit(source_id, str(target_id))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_slots()
		queue_redraw()

func _draw() -> void:
	if zone_name == "frontline":
		var local_centers: Array = []
		for center in grid_column_centers():
			local_centers.append(center - global_position.x)
		BattlefieldChrome.draw_frontline(self, Rect2(Vector2.ZERO, size), highlighted_slots, local_centers)
	else:
		for index in range(slot_count):
			BattlefieldChrome.draw_slot_pad(self, _slot_cell(index), zone_name, index in highlighted_slots)
	if not lane_caption.is_empty():
		var font := get_theme_default_font()
		if font != null:
			var label_y := size.y * 0.5 - 16.0 if zone_name == "frontline" else maxf(14.0, _slot_cell(0).position.y - 2.0)
			var label_x := 18.0 if zone_name == "frontline" else _slot_cell(0).position.x
			var text_size: Vector2 = font.get_string_size(lane_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			var plate := Rect2(label_x - 5.0, label_y - 13.0, text_size.x + 10.0, 18.0)
			draw_rect(plate, Color(0.08, 0.07, 0.04, 0.72), true)
			draw_rect(plate, Color(0.72, 0.60, 0.34, 0.70), false, 1.0)
			draw_string(font, Vector2(label_x, label_y), lane_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.94, 0.88, 0.70, 0.96))

func _layout_slots() -> void:
	var slots := _drop_slots()
	for index in range(slots.size()):
		var slot := slots[index] as _DropSlot
		var cell := _slot_cell(index)
		slot.position = cell.position
		slot.size = cell.size
		if slot.get_child_count() > 0:
			_place_field_card(slot.get_child(0) as Control, cell.size)

func _place_field_card(card: Control, slot_size: Vector2) -> void:
	var card_size: Vector2 = CardView.MODE_SIZES["battlefield"]
	if card is CardView:
		card_size = CardView.MODE_SIZES.get((card as CardView).mode, card_size)
	card.scale = Vector2.ONE
	card.rotation_degrees = 0.0
	card.custom_minimum_size = card_size
	card.size = card_size
	card.pivot_offset = card_size * 0.5
	card.position = ((slot_size - card_size) * 0.5).floor()


func field_card_rect(slot: Control) -> Rect2:
	var index := _drop_slots().find(slot)
	return field_card_rect_at(index if index >= 0 else 0)


func field_card_rect_at(index: int) -> Rect2:
	var card_size := CardView.MODE_SIZES["battlefield"]
	var cell := _slot_cell(index)
	var origin := global_position + cell.position + ((cell.size - card_size) * 0.5).floor()
	return Rect2(origin, card_size)


func _slot_size() -> Vector2:
	return CardView.MODE_SIZES["battlefield"]


func _grid_width() -> float:
	return slot_width * grid_cell_count + slot_gap * (grid_cell_count - 1)


func grid_left_x() -> float:
	return global_position.x + floorf((size.x - _grid_width()) * 0.5)


func _slot_cell(index: int) -> Rect2:
	var cell := _slot_size()
	var left: float = floorf((size.x - _grid_width()) * 0.5)
	return Rect2(
		Vector2(left + index * (slot_width + slot_gap), floorf((size.y - cell.y) * 0.5)),
		cell
	)


func card_views() -> Array:
	var cards: Array = []
	for slot in _drop_slots():
		if slot.get_child_count() > 0 and slot.get_child(0) is CardView:
			cards.append(slot.get_child(0))
	return cards


func _drop_slots() -> Array:
	var slots: Array = []
	for child in get_children():
		if child is _DropSlot:
			slots.append(child)
	return slots

func grid_column_centers() -> Array[float]:
	var result: Array[float] = []
	var left: float = grid_left_x()
	for index in range(grid_cell_count):
		result.append(snappedf(left + index * (slot_width + slot_gap) + slot_width * 0.5, 0.01))
	return result

func _slot_style(zone: String) -> StyleBox:
	if zone == "frontline":
		return StyleBoxEmpty.new()
	return BattlefieldChrome.slot_pad(zone, false)

func set_input_locked(locked: bool) -> void:
	input_locked = locked
	for slot in _drop_slots():
		slot.input_locked = locked
		slot.disabled = locked
		if slot.get_child_count() > 0:
			slot.get_child(0).disabled = locked

func set_highlights(slots: Array, targets: Array) -> void:
	highlighted_slots = slots.duplicate()
	highlighted_targets = targets.duplicate()
	_apply_highlights()

func _apply_highlights() -> void:
	var slots := _drop_slots()
	for index in range(slots.size()):
		var slot: _DropSlot = slots[index]
		var highlighted := index in highlighted_slots
		var style := _slot_style(zone_name)
		var hover := style
		if zone_name != "frontline":
			style = BattlefieldChrome.slot_pad(zone_name, highlighted)
			hover = BattlefieldChrome.slot_pad(zone_name, highlighted)
			if highlighted:
				hover.bg_color = Color(0.36, 0.30, 0.10, 0.42)
				hover.border_color = Color("ffe08a")
		slot.add_theme_stylebox_override("normal", style)
		slot.add_theme_stylebox_override("hover", hover)
		slot.add_theme_stylebox_override("disabled", style)
		slot.modulate = Color.WHITE
		if slot.get_child_count() > 0:
			var card = slot.get_child(0)
			var owner_color := Color("b9d8e8") if str(card.get_meta("owner_id", "")) == "player" else Color("e8b9b9")
			card.modulate = Color("f2d66d") if str(card.card_data.get("instance_id", "")) in highlighted_targets else owner_color
	queue_redraw()

class _DropSlot:
	extends Button
	signal card_dropped(instance_id: String)
	var zone := ""
	var slot_index := -1
	var input_locked := false
	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		if input_locked or not (data is Dictionary) or str(data.get("instance_id", "")).is_empty():
			return false
		var zone := get_parent() as ZoneView
		return zone != null and slot_index in zone.highlighted_slots
	func _drop_data(_position: Vector2, data: Variant) -> void:
		if _can_drop_data(_position, data):
			card_dropped.emit(str(data.instance_id))
