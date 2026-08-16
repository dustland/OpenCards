extends RefCounted

const CardInstance = preload("res://scripts/core/card_instance.gd")
const CombatRules = preload("res://scripts/core/combat_rules.gd")
const ContentCatalog = preload("res://scripts/content/content_catalog.gd")
const GameAction = preload("res://scripts/core/game_action.gd")
const MatchController = preload("res://scripts/core/match_controller.gd")

const LOCKED_MATRIX := {
	"us-hq": ["US Command Post", "UnitedStates", "Headquarters", "", "Standard", 0, 0, 0, 20, []],
	"us-rifle-platoon": ["Rifle Platoon", "UnitedStates", "Unit", "Infantry", "Standard", 1, 1, 1, 2, []],
	"us-combat-engineers": ["Combat Engineers", "UnitedStates", "Unit", "Infantry", "Standard", 2, 1, 2, 3, []],
	"us-field-hospital": ["Field Hospital", "UnitedStates", "Unit", "Infantry", "Standard", 2, 1, 1, 4, []],
	"us-supply-column": ["Supply Column", "UnitedStates", "Unit", "Infantry", "Standard", 2, 1, 1, 3, []],
	"us-forward-observers": ["Forward Observers", "UnitedStates", "Unit", "Infantry", "Standard", 3, 1, 2, 3, []],
	"us-p40-patrol": ["P-40 Patrol", "UnitedStates", "Unit", "Fighter", "Standard", 3, 1, 3, 2, ["Smokescreen"]],
	"us-rapid-resupply": ["Rapid Resupply", "UnitedStates", "Order", "", "Standard", 2, 0, 0, 0, []],
	"us-signal-watch": ["Signal Watch", "UnitedStates", "Countermeasure", "", "Standard", 2, 0, 0, 0, []],
	"us-ranger-company": ["Ranger Company", "UnitedStates", "Unit", "Infantry", "Limited", 3, 1, 3, 3, ["Blitz"]],
	"us-armored-group": ["Armored Group", "UnitedStates", "Unit", "Tank", "Limited", 4, 2, 4, 5, ["Fury"]],
	"us-field-battery": ["105mm Field Battery", "UnitedStates", "Unit", "Artillery", "Limited", 4, 2, 4, 3, []],
	"us-emergency-repairs": ["Emergency Repairs", "UnitedStates", "Countermeasure", "", "Limited", 2, 0, 0, 0, []],
	"us-tank-hunters": ["Tank Hunters", "UnitedStates", "Unit", "Artillery", "Special", 5, 2, 6, 3, []],
	"us-b25-strike-group": ["B-25 Strike Group", "UnitedStates", "Unit", "Bomber", "Special", 6, 2, 5, 4, ["Bypass Guard"]],
	"us-air-superiority": ["Air Superiority", "UnitedStates", "Order", "", "Elite", 5, 0, 0, 0, []],
	"us-combined-arms": ["Combined Arms", "UnitedStates", "Order", "", "Elite", 6, 0, 0, 0, []],
	"su-hq": ["Soviet Command Post", "SovietUnion", "Headquarters", "", "Standard", 0, 0, 0, 20, []],
	"su-guards-rifle": ["Guards Rifle Section", "SovietUnion", "Unit", "Infantry", "Standard", 1, 1, 1, 3, ["Guard"]],
	"su-siberian-volunteers": ["Siberian Volunteers", "SovietUnion", "Unit", "Infantry", "Standard", 2, 1, 2, 3, []],
	"su-combat-sappers": ["Combat Sappers", "SovietUnion", "Unit", "Infantry", "Standard", 2, 1, 2, 2, []],
	"su-medical-battalion": ["Medical Battalion", "SovietUnion", "Unit", "Infantry", "Standard", 2, 1, 1, 4, []],
	"su-rail-convoy": ["Rail Supply Convoy", "SovietUnion", "Unit", "Infantry", "Standard", 3, 1, 1, 4, []],
	"su-partisan-scouts": ["Partisan Scouts", "SovietUnion", "Unit", "Infantry", "Standard", 2, 1, 2, 2, []],
	"su-massed-assault": ["Massed Assault", "SovietUnion", "Order", "", "Standard", 3, 0, 0, 0, []],
	"su-maskirovka": ["Maskirovka", "SovietUnion", "Countermeasure", "", "Standard", 2, 0, 0, 0, []],
	"su-t34-spearhead": ["T-34 Spearhead", "SovietUnion", "Unit", "Tank", "Limited", 4, 1, 4, 4, ["Blitz"]],
	"su-heavy-breakthrough": ["Heavy Breakthrough Regiment", "SovietUnion", "Unit", "Tank", "Limited", 6, 2, 6, 7, ["Heavy Armor"]],
	"su-katyusha-battery": ["Katyusha Battery", "SovietUnion", "Unit", "Artillery", "Limited", 4, 2, 3, 3, []],
	"su-hold-the-line": ["Hold the Line", "SovietUnion", "Countermeasure", "", "Limited", 3, 0, 0, 0, []],
	"su-yak-patrol": ["Yak Patrol", "SovietUnion", "Unit", "Fighter", "Special", 5, 1, 4, 4, ["Fury"]],
	"su-pe2-bomber-wing": ["Pe-2 Bomber Wing", "SovietUnion", "Unit", "Bomber", "Special", 6, 2, 5, 4, []],
	"su-deep-battle": ["Deep Battle", "SovietUnion", "Order", "", "Elite", 5, 0, 0, 0, []],
	"su-artillery-preparation": ["Artillery Preparation", "SovietUnion", "Order", "", "Elite", 6, 0, 0, 0, []],
}


static func run(t) -> void:
	var catalog = ContentCatalog.load_from_paths(
		"res://data/cards.json", "res://data/abilities.json", "res://data/decks.json", "res://data/rules.json"
	)
	_test_us_command_post_defeat(t, catalog)
	_test_us_rifle_platoon_deployment_sickness(t, catalog)
	_test_us_combat_engineers_deploy_repairs_hq(t, catalog)
	_test_us_field_hospital_deploy_repairs_unit(t, catalog)
	_test_us_supply_column_deploy_adds_credit(t, catalog)
	_test_us_forward_observers_frontline_draw(t, catalog)
	_test_us_p40_patrol_smokescreen(t, catalog)
	_test_us_rapid_resupply_draws_two(t, catalog)
	_test_us_signal_watch_cancels_targeted_order(t, catalog)
	_test_us_ranger_company_blitz(t, catalog)
	_test_us_armored_group_fury(t, catalog)
	_test_us_field_battery_long_range_no_counterattack(t, catalog)
	_test_us_emergency_repairs_prevents_hq_defeat(t, catalog)
	_test_us_tank_hunters_bonus_damage(t, catalog)
	_test_us_b25_strike_group_bypasses_guard(t, catalog)
	_test_us_air_superiority_damages_only_air(t, catalog)
	_test_us_combined_arms_buffs_and_draws(t, catalog)
	_test_soviet_command_post_defeat(t, catalog)
	_test_su_guards_rifle_protects_adjacent(t, catalog)
	_test_su_siberian_volunteers_damaged_bonus(t, catalog)
	_test_su_combat_sappers_deploy_damage(t, catalog)
	_test_su_medical_battalion_turn_end_repair(t, catalog)
	_test_su_rail_convoy_deploy_adds_credit_slot(t, catalog)
	_test_su_partisan_scouts_intel_perspective_reveal(t, catalog)
	_test_su_massed_assault_buffs_infantry(t, catalog)
	_test_su_maskirovka_temporary_defender_ambush(t, catalog)
	_test_su_t34_spearhead_blitz(t, catalog)
	_test_su_heavy_breakthrough_heavy_armor(t, catalog)
	_test_su_katyusha_battery_adjacent_damage(t, catalog)
	_test_su_hold_the_line_repairs_lethal_frontline(t, catalog)
	_test_su_yak_patrol_fury(t, catalog)
	_test_su_pe2_bomber_wing_deploy_hq_damage(t, catalog)
	_test_su_deep_battle_retreats_and_draws(t, catalog)
	_test_su_artillery_preparation_area_damage(t, catalog)


static func _test_us_command_post_defeat(t, catalog) -> void:
	_assert_locked(t, catalog, "us-hq")
	_assert_hq_defeat(t, catalog, "us-hq", "su-hq", 701)


static func _test_us_rifle_platoon_deployment_sickness(t, catalog) -> void:
	_assert_locked(t, catalog, "us-rifle-platoon", "Infantry. From Support, attack the Frontline. From the Frontline, attack Support or HQ.")
	var controller := _controller(catalog, 702)
	var rifle := _put_hand(controller, _card(catalog, "us-rifle-platoon", "player", "rifle"))
	var deployed = _deploy(controller, rifle, 0)
	t.assert_true(deployed.accepted, "Rifle Platoon deploys")
	var moved = _move(controller, rifle, 0)
	t.assert_eq(moved.reason_code, "deployment_sickness", "vanilla Rifle Platoon cannot operate on deployment turn")


static func _test_us_combat_engineers_deploy_repairs_hq(t, catalog) -> void:
	_assert_locked(t, catalog, "us-combat-engineers")
	var controller := _controller(catalog, 703)
	controller.state.players.player.headquarters.current_defense = 18
	var engineers := _put_hand(controller, _card(catalog, "us-combat-engineers", "player", "engineers"))
	var result = _deploy(controller, engineers, 0)
	t.assert_true(result.accepted, "Combat Engineers deploy action resolves")
	t.assert_eq(controller.state.players.player.headquarters.current_defense, 19, "Combat Engineers repair friendly HQ by one")


static func _test_us_field_hospital_deploy_repairs_unit(t, catalog) -> void:
	_assert_locked(t, catalog, "us-field-hospital")
	var controller := _controller(catalog, 704)
	var patient := _place_support(controller, _card(catalog, "us-rifle-platoon", "player", "patient"), 1)
	patient.current_defense = 1
	var hospital := _put_hand(controller, _card(catalog, "us-field-hospital", "player", "hospital"))
	var result = _deploy(controller, hospital, 0, [patient.instance_id])
	t.assert_true(result.accepted, "Field Hospital deploy accepts a friendly target")
	t.assert_eq(patient.current_defense, 2, "Field Hospital repairs its selected unit by two up to base defense")


static func _test_us_supply_column_deploy_adds_credit(t, catalog) -> void:
	_assert_locked(t, catalog, "us-supply-column")
	var controller := _controller(catalog, 705)
	controller.state.players.player.credit = 5
	var supply := _put_hand(controller, _card(catalog, "us-supply-column", "player", "supply"))
	var result = _deploy(controller, supply, 0)
	t.assert_true(result.accepted, "Supply Column deploy resolves")
	t.assert_eq(controller.state.players.player.credit, 4, "Supply Column refunds one Credit after paying two")


static func _test_us_forward_observers_frontline_draw(t, catalog) -> void:
	_assert_locked(t, catalog, "us-forward-observers")
	var controller := _controller(catalog, 706)
	_place_support(controller, _card(catalog, "us-forward-observers", "player", "observers"), 1)
	_place_support(controller, _card(catalog, "us-forward-observers", "opponent", "enemy-observers"), 0)
	var capturing_unit := _place_support(controller, _card(catalog, "us-rifle-platoon", "player", "capturing-unit"), 0)
	_ready(controller, capturing_unit)
	_put_deck(controller, _card(catalog, "us-rifle-platoon", "player", "drawn"))
	_put_deck(controller, _card(catalog, "us-rifle-platoon", "opponent", "enemy-draw"))
	var before: int = controller.state.players.player.hand.size()
	var result = _move(controller, capturing_unit, 0)
	t.assert_true(result.accepted, "different friendly unit captures Frontline")
	t.assert_eq(controller.state.players.player.hand.size(), before + 1, "standing Forward Observers draw one for friendly Frontline capture")
	t.assert_eq(controller.state.players.opponent.hand.size(), 0, "enemy Forward Observers do not trigger")


static func _test_us_p40_patrol_smokescreen(t, catalog) -> void:
	_assert_locked(t, catalog, "us-p40-patrol")
	var controller := _controller(catalog, 707)
	var patrol := _place_frontline(controller, _card(catalog, "us-p40-patrol", "opponent", "patrol"), 0)
	var attacker := _place_support(controller, _card(catalog, "su-yak-patrol", "player", "fighter"), 0)
	_ready(controller, attacker)
	t.assert_true(not CombatRules.legal_targets(controller.state, attacker.instance_id).has(patrol.instance_id), "Smokescreen hides P-40 before it operates")
	controller.state.active_player_id = "opponent"
	_ready(controller, patrol)
	var target := _place_support(controller, _card(catalog, "us-rifle-platoon", "player", "target"), 1)
	var result = _attack(controller, patrol, target)
	t.assert_true(result.accepted and patrol.smokescreen_revealed, "P-40 attack reveals Smokescreen")


static func _test_us_rapid_resupply_draws_two(t, catalog) -> void:
	_assert_locked(t, catalog, "us-rapid-resupply")
	var controller := _controller(catalog, 708)
	var order := _put_hand(controller, _card(catalog, "us-rapid-resupply", "player", "resupply"))
	_put_deck(controller, _card(catalog, "us-rifle-platoon", "player", "draw-a"))
	_put_deck(controller, _card(catalog, "us-rifle-platoon", "player", "draw-b"))
	var result = _play_order(controller, order)
	t.assert_true(result.accepted, "Rapid Resupply order resolves")
	t.assert_eq(controller.state.players.player.hand.size(), 2, "Rapid Resupply draws exactly two cards")


static func _test_us_signal_watch_cancels_targeted_order(t, catalog) -> void:
	_assert_locked(t, catalog, "us-signal-watch")
	var controller := _controller(catalog, 709)
	var watched := _place_frontline(controller, _card(catalog, "us-rifle-platoon", "player", "watched"), 0)
	var signal_watch := _put_hand(controller, _card(catalog, "us-signal-watch", "player", "signal"))
	t.assert_true(_activate_countermeasure(controller, signal_watch).accepted, "Signal Watch activates")
	controller.state.active_player_id = "opponent"
	var order := _put_hand(controller, _card(catalog, "su-deep-battle", "opponent", "enemy-order"))
	var result = _play_order(controller, order, [watched.instance_id], "opponent")
	t.assert_true(result.accepted, "targeted enemy Order action resolves through cancellation")
	t.assert_eq(watched.zone, "frontline", "Signal Watch cancels retreat of friendly target")
	t.assert_eq(signal_watch.zone, "discard", "Signal Watch reveals and discards after triggering")


static func _test_us_ranger_company_blitz(t, catalog) -> void:
	_assert_locked(t, catalog, "us-ranger-company")
	_assert_blitz_deploy_move(t, catalog, "us-ranger-company", 710)


static func _test_us_armored_group_fury(t, catalog) -> void:
	_assert_locked(t, catalog, "us-armored-group")
	_assert_two_attacks(t, catalog, "us-armored-group", 711)


static func _test_us_field_battery_long_range_no_counterattack(t, catalog) -> void:
	_assert_locked(t, catalog, "us-field-battery")
	var controller := _controller(catalog, 712)
	var battery := _place_support(controller, _card(catalog, "us-field-battery", "player", "battery"), 0)
	var defender := _place_support(controller, _card(catalog, "su-heavy-breakthrough", "opponent", "defender"), 0)
	_ready(controller, battery)
	var result = _attack(controller, battery, defender)
	t.assert_true(result.accepted, "105mm battery makes long-range Support attack")
	t.assert_eq(battery.current_defense, battery.base_defense, "Artillery attack receives no counterattack")


static func _test_us_emergency_repairs_prevents_hq_defeat(t, catalog) -> void:
	_assert_locked(t, catalog, "us-emergency-repairs")
	var controller := _controller(catalog, 713)
	var counter := _put_hand(controller, _card(catalog, "us-emergency-repairs", "player", "repairs"))
	t.assert_true(_activate_countermeasure(controller, counter).accepted, "Emergency Repairs activates")
	var attacker := _place_support(controller, _card(catalog, "su-pe2-bomber-wing", "opponent", "bomber"), 0)
	attacker.current_attack = 20
	_ready(controller, attacker)
	controller.state.active_player_id = "opponent"
	var result = _attack_hq(controller, attacker, "player")
	t.assert_true(result.accepted, "lethal HQ attack reaches prevention checkpoint")
	t.assert_eq(controller.state.players.player.headquarters.current_defense, 3, "Emergency Repairs restores three after lethal damage")
	t.assert_eq([controller.state.phase, counter.zone], ["action", "discard"], "Emergency Repairs prevents defeat and discards")


static func _test_us_tank_hunters_bonus_damage(t, catalog) -> void:
	_assert_locked(t, catalog, "us-tank-hunters")
	var tank_fixture := _attack_fixture(catalog, "us-tank-hunters", "su-t34-spearhead", 714)
	tank_fixture.defender.base_defense = 20
	tank_fixture.defender.current_defense = 20
	var tank_result = _attack(tank_fixture.controller, tank_fixture.attacker, tank_fixture.defender)
	t.assert_true(tank_result.accepted, "Tank Hunters attack Tank")
	t.assert_eq(tank_fixture.defender.current_defense, 12, "Tank target takes six attack plus two bonus damage")
	var infantry_fixture := _attack_fixture(catalog, "us-tank-hunters", "su-guards-rifle", 715)
	infantry_fixture.defender.base_defense = 20
	infantry_fixture.defender.current_defense = 20
	_attack(infantry_fixture.controller, infantry_fixture.attacker, infantry_fixture.defender)
	t.assert_eq(infantry_fixture.defender.current_defense, 14, "non-Tank target receives no bonus damage")


static func _test_us_b25_strike_group_bypasses_guard(t, catalog) -> void:
	_assert_locked(t, catalog, "us-b25-strike-group")
	var controller := _controller(catalog, 716)
	var bomber := _place_support(controller, _card(catalog, "us-b25-strike-group", "player", "b25"), 0)
	var guard := _place_frontline(controller, _card(catalog, "su-guards-rifle", "opponent", "guard"), 1)
	var protected := _place_frontline(controller, _card(catalog, "su-siberian-volunteers", "opponent", "protected"), 2)
	_ready(controller, bomber)
	t.assert_true(CombatRules.legal_targets(controller.state, bomber.instance_id).has(protected.instance_id), "B-25 can select unit adjacent to Guard")
	t.assert_true(guard != null, "Guard fixture is present")


static func _test_us_air_superiority_damages_only_air(t, catalog) -> void:
	_assert_locked(t, catalog, "us-air-superiority")
	var controller := _controller(catalog, 717)
	var order := _put_hand(controller, _card(catalog, "us-air-superiority", "player", "air-order"))
	var fighter := _place_support(controller, _card(catalog, "su-yak-patrol", "opponent", "yak"), 0)
	var bomber := _place_support(controller, _card(catalog, "su-pe2-bomber-wing", "opponent", "pe2"), 1)
	var infantry := _place_support(controller, _card(catalog, "su-guards-rifle", "opponent", "infantry"), 2)
	var result = _play_order(controller, order)
	t.assert_true(result.accepted, "Air Superiority resolves")
	t.assert_eq([fighter.current_defense, bomber.current_defense, infantry.current_defense], [1, 1, 3], "Air Superiority deals three only to enemy air units")


static func _test_us_combined_arms_buffs_and_draws(t, catalog) -> void:
	_assert_locked(t, catalog, "us-combined-arms")
	var controller := _controller(catalog, 718)
	var order := _put_hand(controller, _card(catalog, "us-combined-arms", "player", "combined"))
	var unit := _place_support(controller, _card(catalog, "us-rifle-platoon", "player", "friendly"), 0)
	_put_deck(controller, _card(catalog, "us-rifle-platoon", "player", "drawn"))
	var result = _play_order(controller, order)
	t.assert_true(result.accepted, "Combined Arms resolves")
	t.assert_eq([unit.current_attack, unit.current_defense], [2, 3], "Combined Arms grants plus one attack and defense this turn")
	t.assert_eq(controller.state.players.player.hand.size(), 1, "Combined Arms also draws one")
	var ended = controller.submit_action(GameAction.create("end_turn", "player", "", [], {}, controller.state.sequence))
	t.assert_true(ended.accepted, "Combined Arms turn ends")
	t.assert_eq([unit.current_attack, unit.current_defense, unit.modifiers.size()], [1, 2, 0], "Combined Arms buff expires exactly at owner turn end")


static func _test_soviet_command_post_defeat(t, catalog) -> void:
	_assert_locked(t, catalog, "su-hq")
	_assert_hq_defeat(t, catalog, "su-hq", "us-hq", 719)


static func _test_su_guards_rifle_protects_adjacent(t, catalog) -> void:
	_assert_locked(t, catalog, "su-guards-rifle")
	var controller := _controller(catalog, 720)
	var attacker := _place_support(controller, _card(catalog, "us-ranger-company", "player", "attacker"), 0)
	var guard := _place_frontline(controller, _card(catalog, "su-guards-rifle", "opponent", "guard"), 1)
	var protected := _place_frontline(controller, _card(catalog, "su-siberian-volunteers", "opponent", "protected"), 2)
	_ready(controller, attacker)
	var targets := CombatRules.legal_targets(controller.state, attacker.instance_id)
	t.assert_true(targets.has(guard.instance_id), "Guard remains directly targetable")
	t.assert_true(not targets.has(protected.instance_id), "Guard blocks adjacent friendly target")


static func _test_su_siberian_volunteers_damaged_bonus(t, catalog) -> void:
	_assert_locked(t, catalog, "su-siberian-volunteers")
	var controller := _controller(catalog, 721)
	var volunteers := _place_frontline(controller, _card(catalog, "su-siberian-volunteers", "player", "volunteers"), 0)
	var attacker := _place_support(controller, _card(catalog, "us-rifle-platoon", "opponent", "attacker"), 0)
	_ready(controller, attacker)
	controller.state.active_player_id = "opponent"
	var attacked = _attack(controller, attacker, volunteers)
	t.assert_true(attacked.accepted, "Siberian Volunteers take combat damage")
	t.assert_eq(volunteers.current_attack, 3, "damaged Siberian Volunteers gain one attack")
	controller.state.active_player_id = "player"
	var hospital := _put_hand(controller, _card(catalog, "us-field-hospital", "player", "hospital"))
	var repaired = _deploy(controller, hospital, 0, [volunteers.instance_id])
	t.assert_true(repaired.accepted, "Field Hospital repairs Volunteers")
	t.assert_eq(volunteers.current_attack, 2, "full repair removes damaged attack bonus")


static func _test_su_combat_sappers_deploy_damage(t, catalog) -> void:
	_assert_locked(t, catalog, "su-combat-sappers")
	var controller := _controller(catalog, 722)
	var target := _place_support(controller, _card(catalog, "us-field-hospital", "opponent", "target"), 0)
	var sappers := _put_hand(controller, _card(catalog, "su-combat-sappers", "player", "sappers"))
	var result = _deploy(controller, sappers, 0, [target.instance_id])
	t.assert_true(result.accepted, "Combat Sappers deploy with enemy target")
	t.assert_eq(target.current_defense, 3, "Combat Sappers deal one deploy damage")


static func _test_su_medical_battalion_turn_end_repair(t, catalog) -> void:
	_assert_locked(t, catalog, "su-medical-battalion")
	var controller := _controller(catalog, 723)
	var medical := _place_support(controller, _card(catalog, "su-medical-battalion", "player", "medical"), 0)
	var patient := _place_support(controller, _card(catalog, "su-siberian-volunteers", "player", "patient"), 1)
	medical.current_defense = 2
	patient.current_defense = 1
	var result = controller.submit_action(GameAction.create("end_turn", "player", "", [], {}, controller.state.sequence))
	t.assert_true(result.accepted, "Medical Battalion owner ends turn")
	t.assert_eq([medical.current_defense, patient.current_defense], [3, 2], "turn-end trigger repairs every friendly unit by one")


static func _test_su_rail_convoy_deploy_adds_credit_slot(t, catalog) -> void:
	_assert_locked(t, catalog, "su-rail-convoy")
	var controller := _controller(catalog, 724)
	controller.state.players.player.credit_slots = 5
	var convoy := _put_hand(controller, _card(catalog, "su-rail-convoy", "player", "convoy"))
	var result = _deploy(controller, convoy, 0)
	t.assert_true(result.accepted, "Rail Supply Convoy deploy resolves")
	t.assert_eq(controller.state.players.player.credit_slots, 6, "Rail Supply Convoy adds one Credit slot")


static func _test_su_partisan_scouts_intel_perspective_reveal(t, catalog) -> void:
	_assert_locked(t, catalog, "su-partisan-scouts")
	var controller := _controller(catalog, 725)
	var enemy_a := _put_hand(controller, _card(catalog, "us-rifle-platoon", "opponent", "enemy-a"))
	var enemy_b := _put_hand(controller, _card(catalog, "us-field-hospital", "opponent", "enemy-b"))
	var scouts := _put_hand(controller, _card(catalog, "su-partisan-scouts", "player", "scouts"))
	var result = _deploy(controller, scouts, 0)
	t.assert_true(result.accepted, "Partisan Scouts deploy resolves Intel")
	var revealed_count := int(enemy_a.revealed_to.has("player")) + int(enemy_b.revealed_to.has("player"))
	t.assert_eq(revealed_count, 1, "Intel reveals exactly one deterministic enemy hand card")
	var player_view: Dictionary = controller.state.snapshot_for("player")
	var opponent_view: Dictionary = controller.state.snapshot_for("opponent")
	t.assert_eq(_visible_hand_count(player_view.players.opponent.hand), 1, "revealed card is visible from scout owner's perspective")
	t.assert_eq(_visible_hand_count(opponent_view.players.opponent.hand), 2, "hand owner sees both own cards")
	var ended = controller.submit_action(GameAction.create("end_turn", "player", "", [], {}, controller.state.sequence))
	t.assert_true(ended.accepted, "Intel observer ends turn into revealed hand owner's turn")
	t.assert_eq([enemy_a.revealed_to, enemy_b.revealed_to], [{}, {}], "Intel reveal expires when hand owner's next turn starts")
	t.assert_eq(_visible_hand_count(controller.state.snapshot_for("player").players.opponent.hand), 0, "expired Intel card is hidden from former viewer")


static func _test_su_massed_assault_buffs_infantry(t, catalog) -> void:
	_assert_locked(t, catalog, "su-massed-assault")
	var controller := _controller(catalog, 726)
	var order := _put_hand(controller, _card(catalog, "su-massed-assault", "player", "assault"))
	var infantry := _place_support(controller, _card(catalog, "su-guards-rifle", "player", "infantry"), 0)
	var tank := _place_support(controller, _card(catalog, "su-t34-spearhead", "player", "tank"), 1)
	var result = _play_order(controller, order)
	t.assert_true(result.accepted, "Massed Assault resolves")
	t.assert_eq([infantry.current_attack, tank.current_attack], [2, 4], "Massed Assault buffs friendly Infantry only")
	var ended = controller.submit_action(GameAction.create("end_turn", "player", "", [], {}, controller.state.sequence))
	t.assert_true(ended.accepted, "Massed Assault turn ends")
	t.assert_eq([infantry.current_attack, infantry.modifiers.size(), tank.current_attack], [1, 0, 4], "Massed Assault Infantry buff expires exactly at owner turn end")


static func _test_su_maskirovka_temporary_defender_ambush(t, catalog) -> void:
	_assert_locked(t, catalog, "su-maskirovka")
	var controller := _controller(catalog, 727)
	var defender := _place_frontline(controller, _card(catalog, "su-katyusha-battery", "player", "defender"), 0)
	var attacker := _place_support(controller, _card(catalog, "us-rifle-platoon", "opponent", "attacker"), 0)
	attacker.current_defense = 2
	var maskirovka := _put_hand(controller, _card(catalog, "su-maskirovka", "player", "maskirovka"))
	t.assert_true(_activate_countermeasure(controller, maskirovka).accepted, "Maskirovka activates")
	controller.state.active_player_id = "opponent"
	_ready(controller, attacker)
	var result = _attack(controller, attacker, defender)
	t.assert_true(result.accepted, "enemy attack triggers Maskirovka")
	t.assert_eq([attacker.current_defense, attacker.zone, defender.current_defense], [0, "discard", 3], "attacked defender receives lethal Ambush before combat")
	t.assert_true(not defender.has_keyword_or_status("Ambush"), "temporary Ambush is cleaned after combat")
	t.assert_eq(maskirovka.zone, "discard", "Maskirovka reveals and discards")


static func _test_su_t34_spearhead_blitz(t, catalog) -> void:
	_assert_locked(t, catalog, "su-t34-spearhead")
	_assert_blitz_deploy_move(t, catalog, "su-t34-spearhead", 728)


static func _test_su_heavy_breakthrough_heavy_armor(t, catalog) -> void:
	_assert_locked(t, catalog, "su-heavy-breakthrough")
	var controller := _controller(catalog, 729)
	var attacker := _place_support(controller, _card(catalog, "us-ranger-company", "player", "attacker"), 0)
	var heavy := _place_frontline(controller, _card(catalog, "su-heavy-breakthrough", "opponent", "heavy"), 0)
	_ready(controller, attacker)
	var result = _attack(controller, attacker, heavy)
	t.assert_true(result.accepted, "Heavy Breakthrough is attacked")
	t.assert_eq(heavy.current_defense, 5, "Heavy Armor reduces incoming three damage to two")
	var effect_controller := _controller(catalog, 736)
	var effect_heavy := _place_support(effect_controller, _card(catalog, "su-heavy-breakthrough", "opponent", "effect-heavy"), 0)
	var order := _put_hand(effect_controller, _card(catalog, "su-artillery-preparation", "player", "effect-damage"))
	var effect_result = _play_order(effect_controller, order)
	t.assert_true(effect_result.accepted, "EffectEngine damage Order resolves against Heavy Armor")
	t.assert_eq(effect_heavy.current_defense, 6, "Heavy Armor reduces EffectEngine two damage to one")


static func _test_su_katyusha_battery_adjacent_damage(t, catalog) -> void:
	_assert_locked(t, catalog, "su-katyusha-battery")
	var controller := _controller(catalog, 730)
	var katyusha := _place_support(controller, _card(catalog, "su-katyusha-battery", "player", "katyusha"), 0)
	var left := _place_support(controller, _card(catalog, "us-field-hospital", "opponent", "left"), 0)
	var target := _place_support(controller, _card(catalog, "us-field-hospital", "opponent", "target"), 1)
	var right := _place_support(controller, _card(catalog, "us-field-hospital", "opponent", "right"), 2)
	_ready(controller, katyusha)
	var result = _attack(controller, katyusha, target)
	t.assert_true(result.accepted, "Katyusha attacks middle unit")
	t.assert_eq([left.current_defense, right.current_defense], [3, 3], "Katyusha deals one to both adjacent enemy units")


static func _test_su_hold_the_line_repairs_lethal_frontline(t, catalog) -> void:
	_assert_locked(t, catalog, "su-hold-the-line")
	var controller := _controller(catalog, 731)
	var defender := _place_frontline(controller, _card(catalog, "su-guards-rifle", "player", "frontline"), 0)
	defender.current_defense = 1
	var counter := _put_hand(controller, _card(catalog, "su-hold-the-line", "player", "hold"))
	t.assert_true(_activate_countermeasure(controller, counter).accepted, "Hold the Line activates")
	var attacker := _place_support(controller, _card(catalog, "us-rifle-platoon", "opponent", "attacker"), 0)
	controller.state.active_player_id = "opponent"
	_ready(controller, attacker)
	var result = _attack(controller, attacker, defender)
	t.assert_true(result.accepted, "lethal Frontline attack reaches Hold the Line checkpoint")
	t.assert_eq(defender.current_defense, 2, "Hold the Line repairs lethal defender by two")
	t.assert_eq(counter.zone, "discard", "Hold the Line reveals and discards")


static func _test_su_yak_patrol_fury(t, catalog) -> void:
	_assert_locked(t, catalog, "su-yak-patrol")
	_assert_two_attacks(t, catalog, "su-yak-patrol", 732)


static func _test_su_pe2_bomber_wing_deploy_hq_damage(t, catalog) -> void:
	_assert_locked(t, catalog, "su-pe2-bomber-wing")
	var controller := _controller(catalog, 733)
	var bomber := _put_hand(controller, _card(catalog, "su-pe2-bomber-wing", "player", "pe2"))
	var result = _deploy(controller, bomber, 0)
	t.assert_true(result.accepted, "Pe-2 deploy resolves")
	t.assert_eq(controller.state.players.opponent.headquarters.current_defense, 18, "Pe-2 deploy deals two to enemy HQ")


static func _test_su_deep_battle_retreats_and_draws(t, catalog) -> void:
	_assert_locked(t, catalog, "su-deep-battle")
	var controller := _controller(catalog, 734)
	var order := _put_hand(controller, _card(catalog, "su-deep-battle", "player", "deep"))
	var target := _place_frontline(controller, _card(catalog, "us-rifle-platoon", "opponent", "target"), 0)
	_put_deck(controller, _card(catalog, "su-guards-rifle", "player", "drawn"))
	var result = _play_order(controller, order, [target.instance_id])
	t.assert_true(result.accepted, "Deep Battle resolves")
	t.assert_eq(target.zone, "support_line", "Deep Battle retreats enemy Frontline unit")
	t.assert_eq(controller.state.players.player.hand.size(), 1, "Deep Battle draws one after retreat")


static func _test_su_artillery_preparation_area_damage(t, catalog) -> void:
	_assert_locked(t, catalog, "su-artillery-preparation")
	var controller := _controller(catalog, 735)
	var order := _put_hand(controller, _card(catalog, "su-artillery-preparation", "player", "preparation"))
	var first := _place_support(controller, _card(catalog, "us-field-hospital", "opponent", "first"), 0)
	var second := _place_frontline(controller, _card(catalog, "us-combat-engineers", "opponent", "second"), 0)
	var friendly := _place_support(controller, _card(catalog, "su-medical-battalion", "player", "friendly"), 0)
	var result = _play_order(controller, order)
	t.assert_true(result.accepted, "Artillery Preparation resolves")
	t.assert_eq([first.current_defense, second.current_defense, friendly.current_defense], [2, 1, 4], "Artillery Preparation deals two to every enemy unit only")


static func _assert_locked(t, catalog, card_id: String, description: String = "") -> void:
	var card: Dictionary = catalog.cards_by_id.get(card_id, {})
	var expected: Array = LOCKED_MATRIX[card_id]
	var actual := [
		card.get("id"), card.get("title"), card.get("nation"), card.get("category"), card.get("unit_type"),
		card.get("rarity"), card.get("deployment_cost"), card.get("operation_cost"), card.get("attack"),
		card.get("defense"), card.get("keywords", []),
	]
	t.assert_eq(actual, [card_id] + expected, "%s exact locked matrix row" % card_id)
	if not description.is_empty():
		t.assert_eq(card.get("description"), description, "%s locked description" % card_id)


static func _controller(catalog, seed: int) -> MatchController:
	var controller: MatchController = MatchController.create(catalog.cards_by_id, ["us-hq"], ["su-hq"], seed)
	controller.state.phase = "action"
	controller.state.active_player_id = "player"
	controller.state.starting_player_id = "player"
	controller.state.turn = 5
	for player_id in controller.state.players:
		controller.state.players[player_id].credit_slots = 12
		controller.state.players[player_id].credit = 12
	return controller


static func _card(catalog, card_id: String, owner_id: String, instance_id: String) -> CardInstance:
	return CardInstance.from_definition(catalog.cards_by_id[card_id], owner_id, instance_id)


static func _put_hand(controller: MatchController, card: CardInstance) -> CardInstance:
	_remove(controller, card)
	controller.state.players[card.owner_id].hand.append(card)
	card.zone = "hand"
	card.slot = -1
	return card


static func _put_deck(controller: MatchController, card: CardInstance) -> CardInstance:
	_remove(controller, card)
	controller.state.players[card.owner_id].deck.append(card)
	card.zone = "deck"
	card.slot = -1
	return card


static func _place_support(controller: MatchController, card: CardInstance, slot: int) -> CardInstance:
	_remove(controller, card)
	controller.state.players[card.owner_id].support_line[slot] = card
	card.zone = "support_line"
	card.slot = slot
	return card


static func _place_frontline(controller: MatchController, card: CardInstance, slot: int) -> CardInstance:
	_remove(controller, card)
	controller.state.frontline[slot] = card
	controller.state.frontline_controller_id = card.owner_id
	card.zone = "frontline"
	card.slot = slot
	return card


static func _remove(controller: MatchController, card: CardInstance) -> void:
	for player_id in controller.state.players:
		var player = controller.state.players[player_id]
		player.deck.erase(card)
		player.hand.erase(card)
		player.discard.erase(card)
		player.active_countermeasures.erase(card)
		for slot in range(player.support_line.size()):
			if player.support_line[slot] == card:
				player.support_line[slot] = null
	for slot in range(controller.state.frontline.size()):
		if controller.state.frontline[slot] == card:
			controller.state.frontline[slot] = null


static func _ready(controller: MatchController, card: CardInstance) -> void:
	card.deployed_turn = controller.state.turn - 1
	card.operations_used = 0


static func _deploy(controller: MatchController, card: CardInstance, slot: int, targets: Array = []):
	return controller.submit_action(GameAction.create(
		"deploy_unit", card.owner_id, card.instance_id, _string_ids(targets), {"support_slot": slot}, controller.state.sequence
	))


static func _move(controller: MatchController, card: CardInstance, slot: int):
	return controller.submit_action(GameAction.create(
		"move_unit", card.owner_id, card.instance_id, [], {"zone": "frontline", "slot": slot}, controller.state.sequence
	))


static func _attack(controller: MatchController, attacker: CardInstance, defender: CardInstance):
	return controller.submit_action(GameAction.create(
		"attack_unit", attacker.owner_id, attacker.instance_id, [defender.instance_id], {}, controller.state.sequence
	))


static func _attack_hq(controller: MatchController, attacker: CardInstance, defender_id: String):
	return controller.submit_action(GameAction.create(
		"attack_hq", attacker.owner_id, attacker.instance_id,
		[controller.state.players[defender_id].headquarters.instance_id], {}, controller.state.sequence
	))


static func _play_order(controller: MatchController, order: CardInstance, targets: Array = [], actor_id: String = "player"):
	return controller.submit_action(GameAction.create(
		"play_order", actor_id, order.instance_id, _string_ids(targets), {}, controller.state.sequence
	))


static func _activate_countermeasure(controller: MatchController, counter: CardInstance):
	return controller.submit_action(GameAction.create(
		"toggle_countermeasure", counter.owner_id, counter.instance_id, [], {}, controller.state.sequence
	))


static func _assert_hq_defeat(t, catalog, defeated_hq_id: String, other_hq_id: String, seed: int) -> void:
	var definitions: Dictionary = catalog.cards_by_id.duplicate(true)
	var controller: MatchController
	var defeated_player_id: String
	var winner_id: String
	if defeated_hq_id == "us-hq":
		controller = MatchController.create(definitions, [defeated_hq_id], [other_hq_id], seed)
		defeated_player_id = "player"
		winner_id = "opponent"
	else:
		controller = MatchController.create(definitions, [other_hq_id], [defeated_hq_id], seed)
		defeated_player_id = "opponent"
		winner_id = "player"
	controller.state.phase = "action"
	controller.state.turn = 5
	controller.state.active_player_id = winner_id
	controller.state.players[winner_id].credit = 12
	var attacker := _place_support(controller, _card(catalog, "us-field-battery", winner_id, "hq-attacker"), 0)
	attacker.current_attack = 20
	_ready(controller, attacker)
	var result = _attack_hq(controller, attacker, defeated_player_id)
	t.assert_true(result.accepted, "%s accepts lethal HQ attack" % defeated_hq_id)
	t.assert_eq([controller.state.players[defeated_player_id].headquarters.current_defense, controller.state.winner_id, controller.state.phase], [0, winner_id, "complete"], "%s defeat completes match" % defeated_hq_id)


static func _assert_blitz_deploy_move(t, catalog, card_id: String, seed: int) -> void:
	var controller := _controller(catalog, seed)
	var unit := _put_hand(controller, _card(catalog, card_id, "player", "%s-instance" % card_id))
	var deployed = _deploy(controller, unit, 0)
	var moved = _move(controller, unit, 0)
	t.assert_true(deployed.accepted and moved.accepted, "%s operates on deployment turn via Blitz" % card_id)


static func _assert_two_attacks(t, catalog, card_id: String, seed: int) -> void:
	var controller := _controller(catalog, seed)
	var attacker := _place_support(controller, _card(catalog, card_id, "player", "%s-instance" % card_id), 0)
	var defender := _place_frontline(controller, _card(catalog, "su-heavy-breakthrough", "opponent", "fury-target"), 0)
	defender.base_defense = 30
	defender.current_defense = 30
	defender.current_attack = 0
	_ready(controller, attacker)
	var initial_credit: int = controller.state.players.player.credit
	var first = _attack(controller, attacker, defender)
	var credit_after_first: int = controller.state.players.player.credit
	var second = _attack(controller, attacker, defender)
	var credit_after_second: int = controller.state.players.player.credit
	var third = _attack(controller, attacker, defender)
	t.assert_true(first.accepted and second.accepted, "%s performs two paid attacks via Fury" % card_id)
	t.assert_eq(attacker.operations_used, 2, "%s consumes two operation allowances" % card_id)
	t.assert_eq([initial_credit, credit_after_first, credit_after_second], [12, 12 - attacker.operation_cost, 12 - attacker.operation_cost * 2], "%s deducts exact operation Credit twice" % card_id)
	t.assert_eq([_credit_spent_amount(first.events), _credit_spent_amount(second.events)], [attacker.operation_cost, attacker.operation_cost], "%s emits two exact Credit deductions" % card_id)
	t.assert_eq(third.reason_code, "operation_limit", "%s rejects third operation" % card_id)
	t.assert_eq([controller.state.players.player.credit, third.events.size()], [credit_after_second, 0], "%s third rejection deducts no Credit" % card_id)


static func _attack_fixture(catalog, attacker_id: String, defender_id: String, seed: int) -> Dictionary:
	var controller := _controller(catalog, seed)
	var attacker := _place_support(controller, _card(catalog, attacker_id, "player", "attack-source"), 0)
	var defender := _place_frontline(controller, _card(catalog, defender_id, "opponent", "attack-target"), 0)
	_ready(controller, attacker)
	return {"controller": controller, "attacker": attacker, "defender": defender}


static func _visible_hand_count(hand: Array) -> int:
	var count := 0
	for card in hand:
		if not bool(card.get("hidden", false)):
			count += 1
	return count


static func _credit_spent_amount(events: Array) -> int:
	for event in events:
		if event.type == "credit_spent":
			return int(event.amount)
	return 0


static func _string_ids(values: Array) -> Array[String]:
	var ids: Array[String] = []
	for value in values:
		ids.append(str(value))
	return ids
