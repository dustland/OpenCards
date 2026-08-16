extends RefCounted

const ContentCatalog = preload("res://scripts/content/content_catalog.gd")
const ASSET_DIRECTORY := "res://game_assets/generated_cards"
const EXPECTED_FILES := [
	"su-armor.png",
	"su-artillery-preparation.png",
	"su-artillery.png",
	"su-bomber.png",
	"su-combat-sappers.png",
	"su-deep-battle.png",
	"su-fighter.png",
	"su-guards-rifle.png",
	"su-heavy-breakthrough.png",
	"su-hold-the-line.png",
	"su-hq.png",
	"su-infantry.png",
	"su-katyusha-battery.png",
	"su-maskirovka.png",
	"su-massed-assault.png",
	"su-medical-battalion.png",
	"su-partisan-scouts.png",
	"su-pe2-bomber-wing.png",
	"su-rail-convoy.png",
	"su-siberian-volunteers.png",
	"su-support.png",
	"su-t34-spearhead.png",
	"su-yak-patrol.png",
	"us-air-superiority.png",
	"us-armor.png",
	"us-armored-group.png",
	"us-artillery.png",
	"us-b25-strike-group.png",
	"us-bomber.png",
	"us-combat-engineers.png",
	"us-combined-arms.png",
	"us-emergency-repairs.png",
	"us-field-battery.png",
	"us-field-hospital.png",
	"us-fighter.png",
	"us-forward-observers.png",
	"us-hq.png",
	"us-infantry.png",
	"us-p40-patrol.png",
	"us-ranger-company.png",
	"us-rapid-resupply.png",
	"us-rifle-platoon.png",
	"us-signal-watch.png",
	"us-supply-column.png",
	"us-support.png",
	"us-tank-hunters.png",
]
const EXPECTED_CARD_IMAGES := {
	"us-hq": "us-hq.png",
	"us-rifle-platoon": "us-rifle-platoon.png",
	"us-combat-engineers": "us-combat-engineers.png",
	"us-field-hospital": "us-field-hospital.png",
	"us-supply-column": "us-supply-column.png",
	"us-forward-observers": "us-forward-observers.png",
	"us-p40-patrol": "us-p40-patrol.png",
	"us-rapid-resupply": "us-rapid-resupply.png",
	"us-signal-watch": "us-signal-watch.png",
	"us-ranger-company": "us-ranger-company.png",
	"us-armored-group": "us-armored-group.png",
	"us-field-battery": "us-field-battery.png",
	"us-emergency-repairs": "us-emergency-repairs.png",
	"us-tank-hunters": "us-tank-hunters.png",
	"us-b25-strike-group": "us-b25-strike-group.png",
	"us-air-superiority": "us-air-superiority.png",
	"us-combined-arms": "us-combined-arms.png",
	"su-hq": "su-hq.png",
	"su-guards-rifle": "su-guards-rifle.png",
	"su-siberian-volunteers": "su-siberian-volunteers.png",
	"su-combat-sappers": "su-combat-sappers.png",
	"su-medical-battalion": "su-medical-battalion.png",
	"su-rail-convoy": "su-rail-convoy.png",
	"su-partisan-scouts": "su-partisan-scouts.png",
	"su-massed-assault": "su-massed-assault.png",
	"su-maskirovka": "su-maskirovka.png",
	"su-t34-spearhead": "su-t34-spearhead.png",
	"su-heavy-breakthrough": "su-heavy-breakthrough.png",
	"su-katyusha-battery": "su-katyusha-battery.png",
	"su-hold-the-line": "su-hold-the-line.png",
	"su-yak-patrol": "su-yak-patrol.png",
	"su-pe2-bomber-wing": "su-pe2-bomber-wing.png",
	"su-deep-battle": "su-deep-battle.png",
	"su-artillery-preparation": "su-artillery-preparation.png",
}

static func run(t) -> void:
	var actual_files := _png_files_in(ASSET_DIRECTORY)
	t.assert_eq(actual_files, EXPECTED_FILES, "generated card art has the exact expected PNG file set")

	for filename in EXPECTED_FILES:
		var path := "%s/%s" % [ASSET_DIRECTORY, filename]
		t.assert_true(FileAccess.file_exists(path), "%s exists" % path)
		var image := Image.new()
		var decode_error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		t.assert_eq(decode_error, OK, "%s decodes" % path)
		if decode_error != OK:
			continue
		t.assert_true(
			image.get_width() >= 1024 and image.get_height() >= 1536,
			"%s is at least 1024x1536" % path,
		)
		var ratio := float(image.get_width()) / float(image.get_height())
		t.assert_true(absf(ratio - (2.0 / 3.0)) < 0.08, "%s is near 2:3" % path)

	var catalog = ContentCatalog.load_from_paths(
		"res://data/cards.json",
		"res://data/abilities.json",
		"res://data/decks.json",
		"res://data/rules.json",
	)
	t.assert_eq(catalog.cards.size(), EXPECTED_CARD_IMAGES.size(), "every starter card has an expected art mapping")
	for card in catalog.cards:
		var card_id: String = card.get("id", "")
		var image_path: String = card.get("image_path", "")
		var expected_path := "%s/%s" % [ASSET_DIRECTORY, EXPECTED_CARD_IMAGES.get(card_id, "")]
		t.assert_true(image_path.begins_with(ASSET_DIRECTORY + "/"), "%s uses generated art" % card_id)
		t.assert_true(FileAccess.file_exists(image_path), "%s art exists" % card_id)
		t.assert_eq(image_path, expected_path, "%s uses its unique card art" % card_id)

static func _png_files_in(path: String) -> Array[String]:
	var files: Array[String] = []
	var directory := DirAccess.open(path)
	if directory == null:
		return files
	for filename in directory.get_files():
		if filename.get_extension().to_lower() == "png":
			files.append(filename)
	files.sort()
	return files
