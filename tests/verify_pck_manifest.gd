extends SceneTree

const ART_SLUGS := [
	"us-infantry", "us-support", "us-armor", "us-artillery", "us-fighter", "us-bomber",
	"su-infantry", "su-support", "su-armor", "su-artillery", "su-fighter", "su-bomber",
]
const UI_ASSETS := [
	"badge_attack", "badge_cost", "badge_defense",
	"battlefield_bg", "card_back", "hq_su", "hq_us",
]
const REQUIRED_FILES := [
	"project.binary",
	"data/abilities.json",
	"data/cards.json",
	"data/decks.json",
	"data/rules.json",
	"scenes/main.tscn.remap",
	"scripts/main.gd.remap",
	"scenes/ui/hq_view.tscn.remap",
	"scripts/ui/hq_view.gd.remap",
]
const FORBIDDEN_PREFIXES := [
	"tests/",
	"Docs/",
	"game_assets/cards/",
	"game_assets/backgrounds/",
	".superpowers/",
	".worktrees/",
	"builds/",
]


func _init() -> void:
	var entries: Array[String] = []
	_collect_entries("res://", "", entries)
	entries.sort()
	var failures := 0
	for path in REQUIRED_FILES:
		failures += _require_entry(entries, path)
	for slug in ART_SLUGS:
		failures += _require_entry(entries, "game_assets/generated_cards/%s.png.import" % slug)
	for asset in UI_ASSETS:
		failures += _require_entry(entries, "game_assets/ui/%s.png.import" % asset)
	for entry in entries:
		for prefix in FORBIDDEN_PREFIXES:
			if entry.begins_with(prefix):
				push_error("PCK contains forbidden entry: %s" % entry)
				failures += 1
	print("PCK manifest entries: %d" % entries.size())
	quit(1 if failures > 0 else 0)


func _collect_entries(absolute_path: String, relative_path: String, entries: Array[String]) -> void:
	for file in DirAccess.get_files_at(absolute_path):
		entries.append(relative_path + file)
	for directory in DirAccess.get_directories_at(absolute_path):
		_collect_entries(absolute_path.path_join(directory), relative_path + directory + "/", entries)


func _require_entry(entries: Array[String], path: String) -> int:
	if path in entries:
		return 0
	push_error("PCK is missing required entry: %s" % path)
	return 1
