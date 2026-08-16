class_name OnboardingStore
extends RefCounted

const MILESTONES := ["deployed_unit", "moved_to_frontline", "completed_attack", "how_to_play_seen"]

var _path: String
var _state: Dictionary = {}
var _loaded := false
var _valid_path: bool


func _init(path: String = "user://onboarding.json") -> void:
	_path = path
	_valid_path = _is_canonical_user_path(path)


static func defaults() -> Dictionary:
	return {
		"deck_hint_dismissed": false,
		"how_to_play_seen": false,
		"deployed_unit": false,
		"moved_to_frontline": false,
		"completed_attack": false,
	}


func load() -> Dictionary:
	if _loaded:
		return _state.duplicate(true)
	_loaded = true
	_state = defaults()
	if not _valid_path:
		return _state.duplicate(true)
	if not FileAccess.file_exists(_path):
		return _state.duplicate(true)
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		push_warning("Unable to read onboarding state: %s" % _path)
		return _state.duplicate(true)
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	var parsed: Variant = parser.data
	if parse_error != OK or not (parsed is Dictionary):
		print("OnboardingStore: ignoring corrupt state at %s" % _path)
		return _state.duplicate(true)
	for key in _state:
		if typeof(parsed.get(key, null)) == TYPE_BOOL:
			_state[key] = parsed[key]
	return _state.duplicate(true)


func complete(milestone: String) -> bool:
	if not MILESTONES.has(milestone):
		return false
	_ensure_loaded()
	_state[milestone] = true
	return _save()


func dismiss_deck_hint() -> bool:
	_ensure_loaded()
	_state.deck_hint_dismissed = true
	return _save()


func _ensure_loaded() -> void:
	if not _loaded:
		self.load()


func _save() -> bool:
	if not _valid_path:
		return false
	var temporary_path := _path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		print("OnboardingStore: unable to write state at %s" % _path)
		return false
	file.store_string(JSON.stringify(_state))
	file.flush()
	file.close()
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var destination_absolute := ProjectSettings.globalize_path(_path)
	var error := DirAccess.rename_absolute(temporary_absolute, destination_absolute)
	if error != OK:
		DirAccess.remove_absolute(temporary_absolute)
		print("OnboardingStore: unable to replace state at %s" % _path)
		return false
	return true


static func _is_canonical_user_path(path: String) -> bool:
	if not path.begins_with("user://"):
		return false
	var relative := path.trim_prefix("user://")
	if relative.is_empty() or relative.contains("\\"):
		return false
	for segment in relative.split("/", true):
		if segment.is_empty() or segment in [".", ".."]:
			return false
	return true
