class_name Locale
extends RefCounted

const LANG := "en"

const STRINGS := {
	"app.title": {"zh": "OpenCards", "en": "OpenCards"},
	"app.eyebrow": {"zh": "西线战场", "en": "WESTERN FRONT"},
	"app.subtitle": {"zh": "前线卡牌作战", "en": "Command the frontline"},
	"title.start": {"zh": "开始对战", "en": "Start Battle"},
	"title.how_to_play": {"zh": "玩法说明", "en": "How to Play"},
	"title.decks": {"zh": "卡组编辑", "en": "Deck Editor"},
	"title.settings": {"zh": "设置", "en": "Settings"},
	"title.loading": {"zh": "载入中", "en": "Loading"},
	"settings.title": {"zh": "设置", "en": "Settings"},
	"settings.menu": {"zh": "菜单", "en": "Menu"},
	"settings.motion": {"zh": "卡牌动画", "en": "Card motion"},
	"settings.motion_full": {"zh": "完整", "en": "Full"},
	"settings.motion_reduced": {"zh": "精简", "en": "Reduced"},
	"settings.motion_hint": {"zh": "完整动画会表现卡牌移动。精简则让战场保持静止。", "en": "Full motion shows cards travel. Reduced keeps the board still."},
	"settings.close": {"zh": "关闭", "en": "Close"},
	"settings.exit": {"zh": "退出", "en": "Exit"},
	"how_to.title": {"zh": "怎么玩", "en": "How to Play"},
	"how_to.close": {"zh": "知道了", "en": "Got it"},
	"how_to.1.title": {"zh": "1  目标", "en": "1  Objective"},
	"how_to.1.body": {"zh": "把敌方 HQ 的防御打到 0 就赢。你的 HQ 到 0 就失败。双方开局防御都是 20。", "en": "Reduce the enemy HQ to 0 defense to win. Your HQ reaching 0 is a loss. Both start at 20."},
	"how_to.2.title": {"zh": "2  卡牌", "en": "2  The card"},
	"how_to.2.body": {"zh": "移到牌上可知说明。闪击和守卫在说明中。子弹是进攻，盾牌是防守，十字是指令或反制。锈红、钢青、暗金只描边，和符号同色。左上深灰格里大号是打出费用，小号是行动费用。画心底下左侧井是攻击，右侧盾是防御。手牌上方金标是你当前的点 / 上限。每回合上限 +1。", "en": "Hover a card to read what it does, including Blitz and Guard. A bullet is a strike unit, a shield holds the line, and a cross is an Order or Countermeasure. Rust, steel, and gold stay on the rim and the mark. The dark square at top left is deploy over operate. Attack is the well under the art; defense is the shield. The gold pip above your hand is current Credit / the turn cap, which grows by 1 each turn."},
	"how_to.card.deploy": {"zh": "部署费用：打出", "en": "Deploy cost"},
	"how_to.card.operate": {"zh": "行动费用：再行动", "en": "Operate cost"},
	"how_to.card.attack": {"zh": "攻击", "en": "Attack"},
	"how_to.card.defense": {"zh": "防御", "en": "Defense"},
	"how_to.3.title": {"zh": "3  部署", "en": "3  Deploy"},
	"how_to.3.body": {"zh": "开局只有 1 点。点金框手牌再点支援线空位，或把牌拖过去。刚部署还不能行动。闪击单位当回合就可以行动。", "en": "The first turn has 1 Credit. Click a gold-bordered hand card then a Support slot, or drag it there. A unit deployed this turn cannot act yet, unless it has Blitz."},
	"how_to.4.title": {"zh": "4  前线", "en": "4  Frontline"},
	"how_to.4.body": {"zh": "步兵和坦克在支援线只打前线，在前线打支援线或 HQ。战机可从支援线攻击。有的牌可从支援线打支援线、前线或 HQ，移到牌上可知。对方占据前线时，你进不去。", "en": "Infantry and Tanks in Support can only hit the Frontline; from the Frontline they hit Support or HQ. Fighters can strike from Support. Some cards can hit Support, Frontline, or HQ from Support — hover to read. If the enemy holds the Frontline, you cannot enter."},
	"how_to.5.title": {"zh": "5  攻击与回合", "en": "5  Attack and turns"},
	"how_to.5.body": {"zh": "选可行动的单位，再点高亮目标。推进前线和攻击要使用点。每回合开始抽 1 张，点回满。没有可做的事时按 E 结束回合，上限 +1。", "en": "Select a ready unit, then a highlighted target. Moving and attacking spend Credit. Each turn starts by drawing 1 and refilling Credit to the cap. Press E to end the turn when nothing else is legal; the cap grows by 1."},
	"how_to.6.title": {"zh": "6  指令与反制", "en": "6  Orders and Countermeasures"},
	"how_to.6.body": {"zh": "指令当回合打出。反制先在手牌埋伏。对局中点 ? 可再打开本说明。", "en": "Orders play on the turn you spend them. Countermeasures arm in hand first. Press ? during a match to reopen this sheet."},
	"zone.enemy_support": {"zh": "敌方支援线", "en": "Enemy Support"},
	"zone.frontline": {"zh": "前线", "en": "Frontline"},
	"zone.player_support": {"zh": "你的支援线", "en": "Your Support"},
	"zone.unused": {"zh": "—", "en": "—"},
	"status.hq": {"zh": "HQ", "en": "HQ"},
	"status.hand": {"zh": "手牌", "en": "Hand"},
	"status.deck": {"zh": "牌库", "en": "Deck"},
	"status.discard": {"zh": "弃牌", "en": "Discard"},
	"status.credit": {"zh": "点", "en": "Credit"},
	"status.credit_hint": {"zh": "当前 / 上限", "en": "Current / cap"},
	"frontline.yours": {"zh": "你控制前线", "en": "You control the Frontline"},
	"frontline.enemy": {"zh": "对方占据前线", "en": "Enemy holds the Frontline"},
	"frontline.open": {"zh": "前线空置", "en": "Frontline is open"},
	"turn.yours": {"zh": "你的回合", "en": "YOUR TURN"},
	"turn.opponent": {"zh": "对方回合", "en": "OPPONENT'S TURN"},
	"turn.header": {"zh": "第 %d 回合  |  %s", "en": "Turn %d  |  %s"},
	"coach.none": {"zh": "当前没有可做的行动。", "en": "No legal action is available."},
	"coach.opponent": {"zh": "对方正在行动。", "en": "Opponent is acting."},
	"coach.support_slot": {"zh": "拖到或点高亮的支援线空位。", "en": "Drag or click a highlighted Support Line slot."},
	"coach.frontline_slot": {"zh": "拖到或点高亮的前线空位。", "en": "Drag or click a highlighted Frontline slot."},
	"coach.target": {"zh": "拖到或点高亮的目标。", "en": "Drag or click a highlighted target."},
	"coach.deploy": {"zh": "点金框手牌部署到支援线。移到牌上可知说明。", "en": "Select a highlighted card and deploy it to Support. Hover a card to read what it does."},
	"coach.move": {"zh": "点可行动的单位，再拖到或点高亮前线空位。", "en": "Select a ready unit, then drag or click a highlighted Frontline slot."},
	"coach.attack": {"zh": "点可行动的单位，再拖到或点高亮目标。", "en": "Select a ready unit, then drag or click a highlighted target."},
	"coach.order": {"zh": "点金框指令卡打出。", "en": "Select a highlighted Order card to play."},
	"coach.countermeasure": {"zh": "点金框反制卡来埋伏或取消埋伏。", "en": "Select a highlighted Countermeasure card to activate or deactivate."},
	"coach.ability": {"zh": "点可行动的单位使用技能。", "en": "Select a ready unit to use an ability."},
	"coach.end_turn": {"zh": "结束回合。", "en": "End the turn."},
	"coach.confirm": {"zh": "按确认完成这一步。", "en": "Press Confirm to finish this action."},
	"reason.wait": {"zh": "等待你的回合", "en": "Wait for your turn"},
	"reason.credit": {"zh": "点不足", "en": "Not enough Credit"},
	"reason.support_full": {"zh": "支援线已满", "en": "Support Line is full"},
	"reason.no_target": {"zh": "没有合法目标", "en": "No legal target"},
	"reason.active": {"zh": "已经埋伏", "en": "Already active"},
	"reason.none": {"zh": "这张牌现在不能用", "en": "No legal action for this card"},
	"reason.needs_friendly": {"zh": "需要一个友军单位", "en": "Needs a friendly unit"},
	"reason.enemy_frontline": {"zh": "对方占据前线，无法进入", "en": "Enemy holds the Frontline"},
	"reason.sickness": {"zh": "本回合刚部署，还不能行动", "en": "Just deployed this turn"},
	"reason.acted": {"zh": "本回合已经行动过", "en": "Already operated this turn"},
	"duty.ready": {"zh": "可行动", "en": "Ready"},
	"duty.ready_more": {"zh": "还可行动", "en": "Can act again"},
	"duty.deployed": {"zh": "刚部署", "en": "Just deployed"},
	"duty.spent": {"zh": "已行动", "en": "Spent"},
	"event.card_drawn": {"zh": "抽牌", "en": "Drew a card"},
	"event.card_deployed": {"zh": "部署", "en": "Deployed"},
	"event.unit_moved": {"zh": "推进前线", "en": "Moved to Frontline"},
	"event.attack_started": {"zh": "攻击", "en": "Attack"},
	"event.damage_dealt": {"zh": "造成伤害", "en": "Damage"},
	"event.fatigue_damage": {"zh": "疲劳伤害", "en": "Fatigue"},
	"event.card_destroyed": {"zh": "被摧毁", "en": "Destroyed"},
	"event.order_played": {"zh": "打出指令", "en": "Played an Order"},
	"event.countermeasure_activated": {"zh": "埋伏反制", "en": "Armed a Countermeasure"},
	"event.countermeasure_deactivated": {"zh": "取消埋伏", "en": "Disarmed a Countermeasure"},
	"event.countermeasure_triggered": {"zh": "反制触发", "en": "Countermeasure triggered"},
	"event.turn_started": {"zh": "回合开始", "en": "Turn started"},
	"event.credit_refilled": {"zh": "点回满", "en": "Credit refilled"},
	"event.credit_spent": {"zh": "使用点", "en": "Credit spent"},
	"event.match_ended": {"zh": "对局结束", "en": "Match ended"},
	"event.frontline_changed": {"zh": "前线易手", "en": "Frontline changed"},
	"event.player_conceded": {"zh": "认输", "en": "Conceded"},
	"actor.you": {"zh": "你", "en": "You"},
	"actor.opponent": {"zh": "对方", "en": "Enemy"},
	"reason.locked": {"zh": "等待对方行动结束。", "en": "Wait for the opponent action to finish."},
	"match.cancel": {"zh": "取消", "en": "Cancel"},
	"match.confirm": {"zh": "确认", "en": "Confirm"},
	"match.end_turn": {"zh": "结束回合", "en": "End Turn"},
	"match.concede": {"zh": "认输", "en": "Concede"},
	"match.concede_title": {"zh": "认输？", "en": "Concede Match?"},
	"match.concede_body": {"zh": "确定放弃这局？对方将获胜。", "en": "Forfeit this match? The opponent will be declared the winner."},
	"match.concede_ok": {"zh": "认输", "en": "Concede"},
	"match.concede_cancel": {"zh": "继续打", "en": "Keep Playing"},
	"match.animation_on": {"zh": "动画：开", "en": "Animation: On"},
	"match.animation_reduced": {"zh": "动画：减", "en": "Animation: Reduced"},
	"match.help": {"zh": "?", "en": "?"},
	"keyword.Blitz": {"zh": "闪击：部署当回合就可以行动。", "en": "Blitz: can operate the turn it is deployed."},
	"keyword.Guard": {"zh": "守卫：必须先打相邻的守卫单位。", "en": "Guard: adjacent units must be attacked first."},
	"keyword.Smokescreen": {"zh": "烟幕：自己行动前不能被选中。", "en": "Smokescreen: cannot be targeted until this unit acts."},
	"keyword.Fury": {"zh": "狂怒：每回合可以行动两次。", "en": "Fury: can operate twice each turn."},
	"keyword.Heavy Armor": {"zh": "重甲：受到的伤害减 1。", "en": "Heavy Armor: takes 1 less damage."},
	"keyword.Bypass Guard": {"zh": "穿透守卫：无视守卫保护。", "en": "Bypass Guard: ignores Guard."},
	"builder.title": {"zh": "卡组编辑", "en": "Deck Builder"},
	"builder.home": {"zh": "返回主页", "en": "Home"},
	"builder.play": {"zh": "开始对战", "en": "Start Battle"},
	"builder.save": {"zh": "保存", "en": "Save"},
	"builder.hint": {"zh": "选难度后开打，或点卡编辑。不确定就回去用起始卡组。", "en": "Choose a difficulty and start battle, or click cards to edit."},
	"builder.starter_ready": {"zh": "起始卡组就绪 — 40 张合法卡。", "en": "Starter deck ready - 40 valid cards."},
	"builder.ready": {"zh": "卡组就绪 — %d 张合法卡。", "en": "Deck ready - %d valid cards."},
	"builder.invalid": {"zh": "卡组不合法。回去选起始卡组。", "en": "Deck invalid. Pick a starter from the Deck menu."},
	"builder.filter_all": {"zh": "不限", "en": "All"},
	"builder.filter_cost": {"zh": "费用不限", "en": "All costs"},
	"builder.filter_heading": {"zh": "选卡", "en": "Filters"},
	"builder.search": {"zh": "输入", "en": "Search"},
	"builder.nation": {"zh": "来自", "en": "Nation"},
	"builder.category": {"zh": "单位指令", "en": "Category"},
	"builder.unit_type": {"zh": "兵", "en": "Unit type"},
	"builder.rarity": {"zh": "Rarity", "en": "Rarity"},
	"builder.cost": {"zh": "费用", "en": "Deployment cost"},
	"builder.deck_heading": {"zh": "卡组", "en": "Deck"},
	"builder.deck.us-starter": {"zh": "美国起始", "en": "US starter"},
	"builder.deck.su-starter": {"zh": "苏联起始", "en": "Soviet starter"},
	"builder.saved": {"zh": "已保存", "en": "Saved"},
	"builder.diff.easy": {"zh": "易", "en": "Easy"},
	"builder.diff.standard": {"zh": "中", "en": "Standard"},
	"builder.diff.hard": {"zh": "难", "en": "Hard"},
	"mulligan.title": {"zh": "起始手牌", "en": "Opening Hand"},
	"mulligan.help": {"zh": "点不要的牌替换。先手 4 张、后手 5 张；换掉的牌回库后再抽。", "en": "Tap cards to replace. First player 4, second player 5. Replaced cards return to the deck before you draw."},
	"mulligan.confirm": {"zh": "确认手牌", "en": "Confirm hand"},
	"mulligan.back": {"zh": "返回", "en": "Back"},
	"mulligan.ready": {"zh": "起始手牌就绪 — 替换了 %d 张", "en": "Opening hand ready - %d cards replaced"},
	"result.victory": {"zh": "胜利", "en": "Victory"},
	"result.defeat": {"zh": "失败", "en": "Defeat"},
	"result.draw": {"zh": "平局", "en": "Draw"},
	"result.player_wins": {"zh": "你赢了", "en": "Player wins"},
	"result.opponent_wins": {"zh": "对方赢了", "en": "Opponent wins"},
	"result.no_winner": {"zh": "没有胜者", "en": "No winner"},
	"result.turns": {"zh": "%d 回合", "en": "%d turns"},
	"result.turn": {"zh": "%d 回合", "en": "%d turn"},
	"result.rematch": {"zh": "再来一局", "en": "Rematch"},
	"result.home": {"zh": "返回主页", "en": "Home"},
	"reason.headquarters_destroyed": {"zh": "总部被摧毁", "en": "Headquarters destroyed"},
	"reason.fatigue": {"zh": "疲劳伤害", "en": "Fatigue"},
	"reason.concede": {"zh": "认输", "en": "Conceded"},
	"reason.draw": {"zh": "平局", "en": "Draw"},
	"reason.invalid": {"zh": "对局无效", "en": "Invalid match"},
	"nation.UnitedStates": {"zh": "美国", "en": "United States"},
	"nation.SovietUnion": {"zh": "苏联", "en": "Soviet Union"},
	"type.Infantry": {"zh": "步兵", "en": "Infantry"},
	"type.Tank": {"zh": "坦克", "en": "Tank"},
	"type.Fighter": {"zh": "战机", "en": "Fighter"},
	"type.Artillery": {"zh": "Artillery", "en": "Artillery"},
	"type.Bomber": {"zh": "Bomber", "en": "Bomber"},
	"type.Unit": {"zh": "单位", "en": "Unit"},
	"type.Order": {"zh": "指令", "en": "Order"},
	"type.Countermeasure": {"zh": "反制", "en": "Countermeasure"},
	"type.Headquarters": {"zh": "HQ", "en": "Headquarters"},
	"role.strike": {"zh": "进攻", "en": "Strike"},
	"role.hold": {"zh": "防守", "en": "Hold"},
	"role.effect": {"zh": "效果", "en": "Effect"},
	"inspect.deploy": {"zh": "打出", "en": "Deploy"},
	"inspect.operate": {"zh": "行动", "en": "Operate"},
	"inspect.attack": {"zh": "攻击", "en": "Attack"},
	"inspect.defense": {"zh": "防御", "en": "Defense"},
	"inspect.zone.hand": {"zh": "在手牌", "en": "In hand"},
	"inspect.zone.support_line": {"zh": "在支援线", "en": "On Support"},
	"inspect.zone.frontline": {"zh": "在前线", "en": "On the Frontline"},
	"inspect.zone.headquarters": {"zh": "总部", "en": "Headquarters"},
	"inspect.armed": {"zh": "已埋伏，等待触发。", "en": "Armed and waiting to trigger."},
	"inspect.range.infantry": {"zh": "在支援线只能打前线。在前线可打支援线或 HQ。", "en": "In Support, can only hit the Frontline. From the Frontline, hits Support or HQ."},
	"inspect.range.tank": {"zh": "在支援线只能打前线。在前线可打支援线或 HQ。", "en": "In Support, can only hit the Frontline. From the Frontline, hits Support or HQ."},
	"inspect.range.fighter": {"zh": "可从支援线攻击。", "en": "Can strike from Support."},
	"inspect.range.artillery": {"zh": "可从支援线打支援线、前线或 HQ。", "en": "Can attack Support, Frontline, or HQ from Support."},
	"inspect.range.bomber": {"zh": "可从支援线打支援线、前线或 HQ。", "en": "Can attack Support, Frontline, or HQ from Support."},
	"inspect.range.order": {"zh": "指令当回合打出，打出后离开手牌。", "en": "An Order is spent this turn, then leaves your hand."},
	"inspect.range.countermeasure": {"zh": "先在手牌埋伏，满足条件时自动触发。", "en": "Arm it in hand first. It waits, then triggers on its condition."},
	"inspect.range.hq": {"zh": "总部。防御到 0 时对局结束。", "en": "Headquarters. The match ends when this reaches 0 defense."},
	"card.us-hq": {"zh": "你的总部。防御到 0 时对局结束。", "en": "Your headquarters. The match ends when this reaches 0 defense."},
	"card.su-hq": {"zh": "你的总部。防御到 0 时对局结束。", "en": "Your headquarters. The match ends when this reaches 0 defense."},
	"card.us-rifle-platoon": {"zh": "在支援线可打前线。在前线可打支援线或 HQ。", "en": "From Support, attack the Frontline. From the Frontline, attack Support or HQ."},
	"card.us-combat-engineers": {"zh": "部署：HQ 防御 +1。", "en": "Deploy: restore 1 defense to your HQ."},
	"card.us-field-hospital": {"zh": "部署：一个友军单位防御 +2。需要一个友军单位。", "en": "Deploy: restore 2 defense to a friendly unit."},
	"card.us-supply-column": {"zh": "部署：加 1 点。", "en": "Deploy: gain 1 Credit."},
	"card.us-forward-observers": {"zh": "进入前线时抽 1 张。", "en": "When this unit enters the Frontline, draw 1."},
	"card.us-p40-patrol": {"zh": "可从支援线攻击。", "en": "Can strike from Support."},
	"card.us-rapid-resupply": {"zh": "抽 2 张牌。", "en": "Draw 2 cards."},
	"card.us-signal-watch": {"zh": "在手牌埋伏。取消打你的敌方指令。", "en": "Arm in hand. Cancels an enemy Order that targets you."},
	"card.us-ranger-company": {"zh": "闪击：部署当回合就可以行动。", "en": "Blitz: can operate the turn it is deployed."},
	"card.us-armored-group": {"zh": "狂怒：每回合可以行动两次。推进前线后可再攻击，不再用点。", "en": "Fury: can operate twice each turn. After moving to the Frontline, may attack without paying again."},
	"card.us-field-battery": {"zh": "可从支援线打支援线、前线或 HQ。", "en": "Can attack Support, Frontline, or HQ from Support."},
	"card.us-emergency-repairs": {"zh": "HQ 将被摧毁时，回复 3 防御。", "en": "If your HQ would be destroyed, restore 3 defense instead."},
	"card.us-tank-hunters": {"zh": "打坦克时伤害 +2。", "en": "When attacking a Tank, deal 2 extra damage."},
	"card.us-b25-strike-group": {"zh": "穿透守卫。可从支援线打支援线、前线或 HQ。", "en": "Bypass Guard. Can attack Support, Frontline, or HQ from Support."},
	"card.us-air-superiority": {"zh": "对每个敌方空中单位造成 3 伤害。需要敌方战机或 Bomber。", "en": "Deal 3 damage to each enemy air unit."},
	"card.us-combined-arms": {"zh": "友军单位本回合攻击和防御 +1，再抽 1 张。", "en": "Friendly units get +1/+1 this turn, then draw 1."},
	"card.su-guards-rifle": {"zh": "守卫：必须先打相邻的守卫单位。", "en": "Guard: adjacent units must be attacked first."},
	"card.su-siberian-volunteers": {"zh": "第一次受伤时攻击 +1。", "en": "Gains +1 attack the first time it is damaged."},
	"card.su-combat-sappers": {"zh": "部署：对一个敌方单位造成 1 伤害。", "en": "Deploy: deal 1 damage to an enemy unit."},
	"card.su-medical-battalion": {"zh": "你的回合结束时，友军单位防御 +1。", "en": "At the end of your turn, restore 1 defense to friendly units."},
	"card.su-rail-convoy": {"zh": "部署：点上限 +1。", "en": "Deploy: gain 1 Credit slot."},
	"card.su-partisan-scouts": {"zh": "部署：视对方一张手牌。", "en": "Deploy: reveal a random card in the enemy hand."},
	"card.su-massed-assault": {"zh": "友军步兵本回合攻击 +1。", "en": "Friendly Infantry get +1 attack this turn."},
	"card.su-maskirovka": {"zh": "在手牌埋伏。敌方攻击你的单位时，防守方先出手。", "en": "Arm in hand. When an enemy attacks one of your units, that defender strikes first."},
	"card.su-t34-spearhead": {"zh": "闪击：部署当回合就可以行动。推进前线后可再攻击，不再用点。", "en": "Blitz: can operate the turn it is deployed. After moving to the Frontline, may attack without paying again."},
	"card.su-heavy-breakthrough": {"zh": "重甲：受到的伤害减 1。推进前线后可再攻击，不再用点。", "en": "Heavy Armor: takes 1 less damage. After moving to the Frontline, may attack without paying again."},
	"card.su-katyusha-battery": {"zh": "攻击时对相邻敌方单位造成 1 伤害。", "en": "When this attacks, deal 1 damage to adjacent enemy units."},
	"card.su-hold-the-line": {"zh": "友军前线单位被摧毁时，前线友军防御 +2。", "en": "If a friendly Frontline unit is destroyed in combat, restore 2 defense to your Frontline units."},
	"card.su-yak-patrol": {"zh": "狂怒：每回合可以行动两次。可从支援线攻击。", "en": "Fury: can operate twice each turn. Can strike from Support."},
	"card.su-pe2-bomber-wing": {"zh": "部署：对敌方 HQ 造成 2 伤害。", "en": "Deploy: deal 2 damage to the enemy HQ."},
	"card.su-deep-battle": {"zh": "把一个敌方单位返还支援线，再抽 1 张。需要一个敌方单位。", "en": "Retreat an enemy unit to Support, then draw 1."},
	"card.su-artillery-preparation": {"zh": "对每个敌方单位造成 2 伤害。", "en": "Deal 2 damage to every enemy unit."},
}


static func ui(key: String) -> String:
	var entry: Variant = STRINGS.get(key, {})
	if not (entry is Dictionary):
		return key
	var table: Dictionary = entry
	var localized := str(table.get(LANG, ""))
	if not localized.is_empty():
		return localized
	return str(table.get("en", key))


static func nation(nation_id: String) -> String:
	var key := "nation.%s" % nation_id
	if STRINGS.has(key):
		return ui(key)
	return nation_id


static func keyword(name: String) -> String:
	var key := "keyword.%s" % name
	if STRINGS.has(key):
		return ui(key)
	return name


static func difficulty(id: String) -> String:
	var key := "builder.diff.%s" % id
	if STRINGS.has(key):
		return ui(key)
	return id


static func filter_value(key: String, value: String) -> String:
	if value.is_empty():
		return ui("builder.filter_all")
	if key == "nation":
		return nation(value)
	if STRINGS.has("type.%s" % value):
		return ui("type.%s" % value)
	return value


static func deck_title(deck_id: String) -> String:
	var key := "builder.deck.%s" % deck_id
	if STRINGS.has(key):
		return ui(key)
	return deck_id.replace("-", " ").capitalize()


static func card_kind(data: Dictionary) -> String:
	var unit_type := str(data.get("unit_type", ""))
	if STRINGS.has("type.%s" % unit_type):
		return ui("type.%s" % unit_type)
	var category := str(data.get("category", ""))
	if STRINGS.has("type.%s" % category):
		return ui("type.%s" % category)
	if not unit_type.is_empty():
		return unit_type
	return category


static func card_blurb(data: Dictionary) -> String:
	var definition_id := str(data.get("definition_id", data.get("id", "")))
	var key := "card.%s" % definition_id
	if STRINGS.has(key):
		return ui(key)
	return str(data.get("description", "")).strip_edges()
