class_name Locale
extends RefCounted

const LANG := "zh"

const STRINGS := {
	"app.title": {"zh": "OPENCARDS", "en": "OPENCARDS"},
	"app.subtitle": {"zh": "二战卡牌 · 人机对战", "en": "WW2 cards · versus AI"},
	"title.start": {"zh": "开始对战", "en": "Start Battle"},
	"title.how_to_play": {"zh": "玩法说明", "en": "How to Play"},
	"title.decks": {"zh": "卡组编辑", "en": "Deck Editor"},
	"how_to.title": {"zh": "怎么玩", "en": "How to Play"},
	"how_to.close": {"zh": "知道了", "en": "Got it"},
	"how_to.1.title": {"zh": "1  目标", "en": "1  Objective"},
	"how_to.1.body": {"zh": "把敌方 HQ 的防御打到 0。双方开局都是 20 点。", "en": "Reduce the enemy HQ to 0 defense. Both start at 20."},
	"how_to.2.title": {"zh": "2  信用点", "en": "2  Credit"},
	"how_to.2.body": {"zh": "每回合上限 +1。打出卡牌、移动和攻击都要花信用。", "en": "Credit slots grow by 1 each turn. Deploying, moving, and attacking all spend Credit."},
	"how_to.3.title": {"zh": "3  部署", "en": "3  Deploy"},
	"how_to.3.body": {"zh": "点金框手牌再点支援线空位，或把牌拖过去。没有额外目标时会立刻放下。", "en": "Click a gold-bordered hand card then a Support slot, or drag it there. Simple deploys land immediately."},
	"how_to.4.title": {"zh": "4  前线", "en": "4  Frontline"},
	"how_to.4.body": {"zh": "单位先到前线才能推进。步兵和坦克只能从前线打对方支援线或 HQ。", "en": "Move units onto the Frontline to push. Infantry and Tanks attack Support or HQ only from the Frontline."},
	"how_to.5.title": {"zh": "5  攻击与回合", "en": "5  Attack and turns"},
	"how_to.5.body": {"zh": "选单位，再点高亮目标。没有可做的事时按 E 结束回合。", "en": "Select a unit, then a highlighted target. Press E to end the turn when nothing else is legal."},
	"zone.enemy_support": {"zh": "敌方支援线", "en": "Enemy Support"},
	"zone.frontline": {"zh": "前线", "en": "Frontline"},
	"zone.player_support": {"zh": "你的支援线", "en": "Your Support"},
	"zone.unused": {"zh": "—", "en": "—"},
	"status.hq": {"zh": "HQ", "en": "HQ"},
	"status.hand": {"zh": "手牌", "en": "Hand"},
	"status.deck": {"zh": "牌库", "en": "Deck"},
	"status.discard": {"zh": "弃牌", "en": "Discard"},
	"status.credit": {"zh": "信用", "en": "Credit"},
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
	"coach.deploy": {"zh": "点金框手牌部署，或把牌拖到支援线。当前信用 %d。", "en": "Select a highlighted card to deploy, or drag it to Support. You have %d Credit."},
	"coach.move": {"zh": "点可行动的单位，再拖到或点高亮前线空位。", "en": "Select a ready unit, then drag or click a highlighted Frontline slot."},
	"coach.attack": {"zh": "点可行动的单位，再拖到或点高亮目标。", "en": "Select a ready unit, then drag or click a highlighted target."},
	"coach.order": {"zh": "点金框指令卡打出。", "en": "Select a highlighted Order card to play."},
	"coach.countermeasure": {"zh": "点金框反制卡来埋伏或取消埋伏。", "en": "Select a highlighted Countermeasure card to activate or deactivate."},
	"coach.ability": {"zh": "点可行动的单位使用技能。", "en": "Select a ready unit to use an ability."},
	"coach.end_turn": {"zh": "没有其他行动了。结束回合以增加信用上限。", "en": "No other actions are available. End the turn to gain another Credit slot."},
	"coach.confirm": {"zh": "按确认完成这一步。", "en": "Press Confirm to finish this action."},
	"reason.wait": {"zh": "等待你的回合", "en": "Wait for your turn"},
	"reason.credit": {"zh": "信用不足", "en": "Not enough Credit"},
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
	"event.credit_refilled": {"zh": "信用回复", "en": "Credit refilled"},
	"event.credit_spent": {"zh": "花费信用", "en": "Credit spent"},
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
	"mulligan.title": {"zh": "起始手牌", "en": "Opening Hand"},
	"mulligan.help": {"zh": "点不要的牌替换。先手 4 张、后手 5 张；换掉的牌回库后再抽。", "en": "Tap cards to replace. First player 4, second player 5. Replaced cards return to the deck before you draw."},
	"mulligan.confirm": {"zh": "确认手牌", "en": "Confirm hand"},
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
