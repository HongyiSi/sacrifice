extends RefCounted
## Shared formatting for an individual card's persistent or copied state.
static func final_strike_info(definition: Dictionary, damage: int) -> Dictionary:
	var info := definition.duplicate(true)
	info.damage = damage
	info.base_text = definition.get("base_text",definition.text)
	info.text = str(info.base_text).replace("造成0点伤害","造成%d点伤害" % damage)
	info.short = "造成%d点伤害 · 手牌中蓄力" % damage
	return info
