class_name TimelineView
extends VBoxContainer

const LocaleScript = preload("res://scripts/ui/locale.gd")
const MAX_ENTRIES := 40

func render_events(events: Array) -> void:
	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var label := Label.new()
		label.text = _format_event(event)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)
	while get_child_count() > MAX_ENTRIES:
		get_child(0).free()

func _format_event(event: Dictionary) -> String:
	var event_type := str(event.get("type", "event"))
	var key := "event.%s" % event_type
	var title := LocaleScript.ui(key) if LocaleScript.STRINGS.has(key) else event_type.replace("_", " ")
	var actor_id := str(event.get("actor_id", event.get("player_id", "")))
	var payload: Variant = event.get("payload", {})
	if actor_id.is_empty() and payload is Dictionary:
		actor_id = str((payload as Dictionary).get("actor_id", ""))
	var actor := ""
	if actor_id == "player":
		actor = LocaleScript.ui("actor.you")
	elif actor_id == "opponent":
		actor = LocaleScript.ui("actor.opponent")
	return title if actor.is_empty() else "%s · %s" % [actor, title]
