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
@export var slot_width := 108.0
@export var slot_gap := 8.0
var highlighted_slots: Array = []
var highlighted_targets: Array = []
var input_locked := false
var lane_caption := ""

func _ready() -> void:
	custom_minimum_size = Vector2(slot_width * grid_cell_count + slot_gap * (grid_cell_count - 1), 118.0)

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
		slot.custom_minimum_size = Vector2(slot_width, size.y)
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
	if not lane_caption.is_empty():
		var font := get_theme_default_font()
		if font != null:
			draw_string(font, Vector2(8, 14), lane_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.91, 0.88, 0.78, 0.95))
	if slot_count >= grid_cell_count:
		return
	var grid_width: float = slot_width * grid_cell_count + slot_gap * (grid_cell_count - 1)
	var left: float = floorf((size.x - grid_width) * 0.5)
	for index in range(slot_count, grid_cell_count):
		var rect := Rect2(left + index * (slot_width + slot_gap), 0.0, slot_width, size.y)
		var unused := _slot_style(zone_name)
		unused.bg_color.a = 0.18
		unused.border_color = Color("4a5248")
		unused.set_border_width_all(1)
		unused.draw(get_canvas_item(), rect)

func _layout_slots() -> void:
	var grid_width: float = slot_width * grid_cell_count + slot_gap * (grid_cell_count - 1)
	var left: float = floorf((size.x - grid_width) * 0.5)
	var slots := _drop_slots()
	for index in range(slots.size()):
		var slot := slots[index] as _DropSlot
		var cell_height := minf(118.0, size.y)
		slot.position = Vector2(left + index * (slot_width + slot_gap), floorf((size.y - cell_height) * 0.5))
		slot.size = Vector2(slot_width, cell_height)
		if slot.get_child_count() > 0:
			var card := slot.get_child(0) as Control
			card.position = Vector2.ZERO
			card.size = slot.size

func _drop_slots() -> Array:
	var slots: Array = []
	for child in get_children():
		if child is _DropSlot:
			slots.append(child)
	return slots

func grid_column_centers() -> Array[float]:
	var result: Array[float] = []
	var grid_width: float = slot_width * grid_cell_count + slot_gap * (grid_cell_count - 1)
	var left: float = global_position.x + floorf((size.x - grid_width) * 0.5)
	for index in range(grid_cell_count):
		result.append(snappedf(left + index * (slot_width + slot_gap) + slot_width * 0.5, 0.01))
	return result

func _slot_style(zone: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var edge := Color("6f7a6c")
	match zone:
		"frontline":
			style.bg_color = Color(0.185, 0.215, 0.195, 0.62)
			edge = Color("7c8d84")
		"opponent_support":
			style.bg_color = Color(0.21, 0.185, 0.165, 0.62)
			edge = Color("8a6b60")
		_:
			style.bg_color = Color(0.16, 0.195, 0.215, 0.62)
			edge = Color("6d8496")
	style.border_color = edge
	style.set_border_width_all(2)
	style.border_width_top = 2
	style.border_width_bottom = 3
	style.set_corner_radius_all(4)
	return style

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
		if highlighted:
			style.border_color = Color("f0cf55")
			style.set_border_width_all(4)
		slot.add_theme_stylebox_override("normal", style)
		slot.add_theme_stylebox_override("hover", style)
		slot.add_theme_stylebox_override("disabled", style)
		slot.modulate = Color.WHITE
		if slot.get_child_count() > 0:
			var card = slot.get_child(0)
			var owner_color := Color("b9d8e8") if str(card.get_meta("owner_id", "")) == "player" else Color("e8b9b9")
			card.modulate = Color("f2d66d") if str(card.card_data.get("instance_id", "")) in highlighted_targets else owner_color

class _DropSlot:
	extends Button
	signal card_dropped(instance_id: String)
	var zone := ""
	var slot_index := -1
	var input_locked := false
	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		return not input_locked and data is Dictionary and not str(data.get("instance_id", "")).is_empty()
	func _drop_data(_position: Vector2, data: Variant) -> void:
		if _can_drop_data(_position, data):
			card_dropped.emit(str(data.instance_id))
