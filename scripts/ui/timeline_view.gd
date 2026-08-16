class_name TimelineView
extends VBoxContainer

const LocaleScript = preload("res://scripts/ui/locale.gd")
const MAX_ENTRIES := 40
const REPORT_TYPES := {
	"card_deployed": true,
	"unit_moved": true,
	"attack_started": true,
	"damage_dealt": true,
	"fatigue_damage": true,
	"card_destroyed": true,
	"order_played": true,
	"countermeasure_activated": true,
	"countermeasure_deactivated": true,
	"countermeasure_triggered": true,
	"turn_started": true,
	"frontline_changed": true,
	"player_conceded": true,
	"match_ended": true,
}

var _titles: Dictionary = {}


func render_events(events: Array, titles: Dictionary = {}) -> void:
	if not titles.is_empty():
		_titles.merge(titles, true)
	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		if not REPORT_TYPES.has(str(event.get("type", ""))):
			continue
		var label := Label.new()
		label.text = _format_event(event)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)
	while get_child_count() > MAX_ENTRIES:
		get_child(0).free()


func _format_event(event: Dictionary) -> String:
	var event_type := str(event.get("type", "event"))
	var key := "event.%s" % event_type
	var verb := LocaleScript.ui(key) if LocaleScript.STRINGS.has(key) else event_type.replace("_", " ")
	var actor := _actor_name(event)
	var subject := _subject_name(event)
	var amount := int(event.get("damage", event.get("amount", 0)))
	var parts: PackedStringArray = PackedStringArray()
	if not actor.is_empty():
		parts.append(actor)
	parts.append(verb)
	if not subject.is_empty():
		parts.append(subject)
	if amount > 0:
		parts.append(str(amount))
	return " · ".join(parts)


func _actor_name(event: Dictionary) -> String:
	var actor_id := str(event.get("actor_id", event.get("player_id", "")))
	if actor_id == "player":
		return LocaleScript.ui("actor.you")
	if actor_id == "opponent":
		return LocaleScript.ui("actor.opponent")
	return ""


func _subject_name(event: Dictionary) -> String:
	for key in ["instance_id", "source_id", "attacker_id", "order_id", "target_id"]:
		var instance_id := str(event.get(key, ""))
		if not instance_id.is_empty() and _titles.has(instance_id):
			return str(_titles[instance_id])
	return ""
