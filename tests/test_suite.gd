extends SceneTree

const TestCase = preload("res://tests/support/test_case.gd")
const UI_SUITE = preload("res://tests/ui/test_ui_contracts.gd")
const ART_ASSET_SUITE = preload("res://tests/content/test_art_assets.gd")
const SUITES := [
	preload("res://tests/core/test_contracts.gd"),
	preload("res://tests/core/test_state.gd"),
	preload("res://tests/core/test_setup.gd"),
	preload("res://tests/core/test_turns.gd"),
	preload("res://tests/core/test_combat.gd"),
	preload("res://tests/core/test_effects.gd"),
		preload("res://tests/core/test_replay.gd"),
		preload("res://tests/core/test_full_match.gd"),
		preload("res://tests/core/test_concede.gd"),
	preload("res://tests/content/test_catalog.gd"),
	preload("res://tests/content/test_card_behaviors.gd"),
	ART_ASSET_SUITE,
	preload("res://tests/ai/test_ai.gd"),
	preload("res://tests/ai/test_ai_matches.gd"),
	UI_SUITE,
]

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_case := TestCase.new()
	var args := OS.get_cmdline_user_args()
	var suites := SUITES
	if "--ui-only" in args:
		suites = [UI_SUITE]
	elif "--art-assets-only" in args:
		suites = [ART_ASSET_SUITE]
	var failures := 0
	for suite in suites:
		# A suite whose script failed to parse has no run(); report and keep
		# going so quit() still fires (a stray runtime error would otherwise
		# leave the headless process alive until the CI job timeout).
		if suite == null or not suite.has_method("run"):
			push_error("Test suite script failed to load: %s" % suite)
			failures += 1
			continue
		await suite.run(test_case)
	failures += test_case.finish()
	await process_frame
	await process_frame
	if failures == 0:
		if "--art-assets-only" in args:
			print("PASS generated card art assets")
		else:
			print("PASS contracts, state, setup, turns, combat, effects, replay, and full match")
	quit(failures)
