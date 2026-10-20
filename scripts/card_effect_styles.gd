extends RefCounted
## Public presentation data only. No hidden card identities enter these events.
const PROFILES := {
	"spare_food":["heart","e9c285","备用食品 · 弃置后补充体力"],
	"spare_supplies":["heart","a7d6c5","备用物资 · 弃置后补充体力"],
	"anticipation":["eye","92cdda","预判 · 洞察并封锁翻牌"],
	"gift":["draw","e6c17a","馈赠 · 两张手牌送出"],
	"cards_to_heart":["heart","95d4a7","化牌为心 · 手牌化为生机"],
	"frenzy":["dice","e58f76","疯狂 · 手牌接连打出"],
	"bloodletting":["drop","d97070","放血 · 以生命换取手牌"],
	"gold_panning":["sieve","e8c477","淘金 · 筛选新摸到的牌"],
	"search":["eye","9bcdd0","搜寻 · 寻找抽牌堆中的牌"],
	"rally":["flag","ebbe78","摇旗 · 号召存活队友"],
	"defile":["seal","b999d5","玷污 · 封锁选中的手牌"],
	"obstruct":["rocks","b4b8bc","阻碍 · 巨石进入手牌"],
	"poisoning":["drop","a9c67c","下毒 · 毒药进入手牌"],
	"poison":["skull","a9c67c","毒药 · 毒性发作"],
	"topaz":["gem","f0ce74","黄宝石 · 凝聚胜利徽章"],
	"emerald":["gem","86cf9b","绿宝石 · 唤出四张牌"],
	"amber":["gem","efb974","橙宝石 · 恢复生命"],
	"warcry":["horn","f2ad64","战吼 · 蓄积下一回合攻势"],
	"collect":["draw","8ecceb","收集 · 卡牌飞入手中"],
	"gambler":["dice","efba76","赌徒 · 弃旧换新"],
	"prophecy":["eye","91d8f2","预言 · 铭刻生命数字"],
	"mirror":["mirror","b6deeb","魔镜 · 建立映照"],
	"suppress":["seal","e48a76","先手压制 · 施放压制"],
	"late_suppress":["seal","e48a76","后手压制 · 施放压制"],
	"ignore":["seal","bcb1ec","忽视 · 划去优先级"],
	"reverse":["reverse","ba8ada","扭转乾坤 · 改变结算方向"],
	"skip_death":["hourglass","bca8ee","戏命 · 封存本轮亡语"],
	"badge":["badge","f3cc77","胜利徽章 · 荣誉入账"],
	"glory":["badge","f3cc77","荣耀打击 · 获得徽章"],
	"bounty":["draw","e5bc82","悬赏打击 · 领取赏金"],
	"overload":["lightning","9edfff","过载 · 蓄积下回合力量"],
	"elegy":["soul","beabec","悲歌 · 亡语牌入手"],
	"feign":["soul","b9a5eb","假死 · 唤醒自己的亡语"],
	"peek":["eye","92d7e9","窥探 · 洞察手牌与亡语"],
	"plunder":["steal","e2b57a","掠夺 · 夺取一张手牌"],
	"silence":["seal","a8b4d4","沉默 · 封印下回合出牌"],
	"raise_dead":["revive","96e6bb","死者苏生 · 灵魂归来"],
	"immortal":["phoenix","ffe095","不死 · 立刻重生"],
	"mediocrity":["shatter","b9b0d5","凡庸 · 消去亡语能力"],
	"death_sentence":["scythe","c099e5","赐死 · 灵魂收割"],
	"last_dance":["dance","f199c4","终舞 · 五重舞步"],
	"ghost":["ghost","a6d8ed","幽灵 · 灵体苏醒"],
	"legacy":["draw","e6c486","遗产 · 赠予存活队友"],
	"greed":["coins","eed080","贪婪 · 满溢的馈赠"],
	"prison":["chains","adb4d7","禁锢 · 锁住摸牌"],
	"pain":["thorns","e5a0bd","苦肉 · 以伤痛换取行动"],
	"resurrection":["revive","a3ead8","复活 · 重返战场"],
	"vanish":["dissolve","b9a7d7","消逝 · 手牌散尽"],
	"heart":["heart","f4a5ac","心脏 · 传递生命之力"],
	"sacrifice_badges":["badge","f3cd81","取义 · 荣耀传承"],
	"life_steal":["drain","e89bb2","贪生 · 汲取生机"],
	"curse":["curse","ae92da","凋萎 · 黑印蔓延"],
	"eye":["eye","a5daef","天眼 · 洞悉战场"],
	"divinity":["divinity","f8df9d","神化 · 改写命运"],
	"privilege":["crown","f3d585","特权 · 优先结算"],
	"death":["soul","baa7d8","阵亡 · 灵魂离体"]
}
const OPS := ["draw","discard_all","reverse","skip_death","overload","warcry","silence","draw_death","feign","lose_hp","peek","plunder","revive","life_after","activate","strip","curse_after","curse_move","heart","badges","chosen"]
const NEW_OPS := ["anticipation","gift_transfer","convert_hand","frenzy","gold_begin","gold_filter","search","rally","defile","defile_seal","obstruct","poisoning"]
const NEW_CARDS := ["anticipation","gift","cards_to_heart","frenzy","bloodletting","gold_panning","search","rally","defile","obstruct","poisoning","poison","topaz","emerald","amber","legacy","spare_food","spare_supplies"]

static func profile(key: String) -> Dictionary:
	var p: Array = PROFILES.get(key,["draw","c7d5ea","卡牌生效"])
	if key in ["suppress","late_suppress"]:
		return {"style":key,"motif":p[0],"color":p[1],"caption":p[2],"travel_ms":preload("res://scripts/suppression_pose.gd").TRAVEL[key],"impact_ms":preload("res://scripts/suppression_pose.gd").IMPACT[key]}
	if key == "reverse":
		return {"style":key,"motif":p[0],"color":p[1],"caption":p[2],"travel_ms":preload("res://scripts/reverse_timing.gd").TRAVEL_MS,"impact_ms":preload("res://scripts/reverse_timing.gd").IMPACT_MS}
	return {"style":key,"motif":p[0],"color":p[1],"caption":p[2],"travel_ms":1450 if key == "warcry" else 510 if key in ["last_dance","death"] else 850,"impact_ms":410 if key == "last_dance" else 700}

static func outcome(op: String, key: String, before: Dictionary, after: Dictionary, extra: Dictionary) -> String:
	match op:
		"draw":
			var n: int = after.hand-before.hand
			return "+%d 张手牌" % n if n > 0 else "摸牌被禁锢" if extra.get("prison",false) else "神化接管选牌" if extra.get("divinity",false) else "牌库已空"
		"discard_all": return "弃置 %d 张手牌" % (before.hand-after.hand)
		"draw_death": return "+%d 张亡语牌" % (after.deaths-before.deaths)
		"strip","curse_after": return "移除 %d 张亡语" % (before.deaths-after.deaths)
		"revive","life_after": return "复活 · %d 生命" % after.hp
		"plunder": return "夺取 1 张手牌" if after.hand < before.hand else "目标没有手牌"
		"badges": return "+%d 枚徽章" % extra.get("count",1)
		"chosen":
			if key == "prophecy": return "预言：%d 生命" % extra.value
			if key == "ignore": return "跳过优先级 %s" % "、".join(extra.get("values",[extra.value]).map(func(v):return str(v)))
			return "镜像已绑定" if key == "mirror" else "压制已施放"
		"reverse": return "顺序已反转" if extra.get("immediate",false) else "当前优先级后反转"
		"skip_death": return "跳过本轮亡语阶段"
		"overload": return "下回合可出 3 张牌"
		"warcry": return "下回合攻击伤害 +3"
		"silence": return "下回合不能出牌"
		"feign": return "立即触发未激活亡语"
		"lose_hp": return "失去 %d 点生命" % mini(before.hp,2)
		"peek": return "正在查看手牌"
		"heart": return "心脏转移 · 下回合 +2 出牌"
		"curse_move": return "凋萎进入手牌"
		"activate":
			return {"ghost":"幽灵已激活","pain":"苦肉已激活","eye":"天眼已开启","divinity":"神化已激活","prison":"禁锢已绑定","privilege":"优先级 +100"}.get(key,"能力已激活")
	return "效果生效"
