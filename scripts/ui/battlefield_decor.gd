class_name BattlefieldDecor
extends Control

var _bound := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_install_surfaces()
	resized.connect(queue_redraw)
	call_deferred("_bind_board")


func _install_surfaces() -> void:
	if get_node_or_null("Felt") != null:
		return
	var felt := ColorRect.new()
	felt.name = "Felt"
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.set_anchors_preset(Control.PRESET_FULL_RECT)
	felt.color = Color(0.10, 0.09, 0.06, 0.28)
	felt.material = BattlefieldChrome.felt_material(0.08, 0.04)
	add_child(felt)
	var vignette := ColorRect.new()
	vignette.name = "Vignette"
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color.WHITE
	vignette.material = BattlefieldChrome.vignette_material()
	add_child(vignette)


func _bind_board() -> void:
	var host := get_parent()
	if host == null:
		return
	for path in [
		"Margin/Columns/Board",
		"Margin/Columns/Board/OpponentArea",
		"Margin/Columns/Board/Frontline",
		"Margin/Columns/Board/PlayerArea",
		"Margin/Columns/Board/HandArea",
	]:
		var node := host.get_node_or_null(path)
		if node is Control and not (node as Control).resized.is_connected(queue_redraw):
			(node as Control).resized.connect(queue_redraw)
	_bound = true
	queue_redraw()


func _draw() -> void:
	if not _bound:
		return
	var host := get_parent()
	if host == null:
		return
	var board := host.get_node_or_null("Margin/Columns/Board") as Control
	if board != null:
		var board_rect := _local_rect(board)
		BattlefieldChrome.draw_corner_brackets(self, board_rect.grow(-2.0), Color(0.72, 0.62, 0.38, 0.28), 22.0, 1.4)
	var opponent := host.get_node_or_null("Margin/Columns/Board/OpponentArea") as Control
	if opponent != null:
		BattlefieldChrome.draw_stitches(self, _local_rect(opponent), Color(0.62, 0.36, 0.30, 0.28))
	var player := host.get_node_or_null("Margin/Columns/Board/PlayerArea") as Control
	if player != null:
		BattlefieldChrome.draw_stitches(self, _local_rect(player), Color(0.38, 0.52, 0.60, 0.28))
	var hand := host.get_node_or_null("%HandScroll") as Control
	if hand != null:
		var hand_rect := _local_rect(hand).grow_individual(4.0, 2.0, 4.0, 2.0)
		draw_rect(hand_rect, Color(0.08, 0.07, 0.05, 0.22), true)
		BattlefieldChrome.draw_stitches(self, hand_rect, Color(0.58, 0.50, 0.32, 0.22))
		BattlefieldChrome.draw_corner_brackets(self, hand_rect, Color(0.62, 0.54, 0.34, 0.32), 14.0, 1.3)


func _local_rect(control: Control) -> Rect2:
	var world := control.get_global_rect()
	return Rect2(get_global_transform().affine_inverse() * world.position, world.size)
