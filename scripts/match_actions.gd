extends RefCounted
## Shared intent validation for LAN hosts and dedicated rooms.
static func apply(game, actor_team: int, kind: String, payload: Array, match_serial: int, round_serial: int, revision: int) -> String:
	if game == null: return "对局尚未开始。"
	if actor_team not in [0,1]: return "你不在这场对局中。"
	if payload.size() > 128: return "操作数据过长。"
	if match_serial != game.match_id or round_serial != game.round_number: return "回合已更新，请重新操作。"
	if kind == "plan": return game.submit(actor_team,payload)
	# Both players may request a rematch against the same final snapshot.
	if kind == "confirm": return game.confirm(actor_team) if payload.is_empty() else "无效操作。"
	if kind == "unlock":
		if revision != game.revision or not payload.is_empty(): return "出牌状态已更新，不能取消这次锁定。"
		return game.unlock(actor_team)
	if revision != game.revision: return "结算已更新，请重新操作。"
	match kind:
		"end_round_early":
			return game.end_round_early(actor_team) if payload.is_empty() else "无效操作。"
		"reselect_targets":
			return game.reselect_targets(actor_team) if payload.is_empty() else "无效操作。"
		"skip_effect":
			return game.skip_effect(actor_team) if payload.is_empty() else "无效操作。"
		"pick":
			if not payload.all(func(v): return typeof(v) == TYPE_INT): return "无效选牌。"
			return game.pick(actor_team,payload)
		"target","choose","defend","respond":
			if payload.size() != 1 or typeof(payload[0]) != TYPE_INT: return "无效的选择。"
			match kind:
				"target": return game.target(actor_team,payload[0])
				"choose": return game.choose(actor_team,payload[0])
				"respond": return game.respond(actor_team,payload[0])
				"defend": return game.defend(actor_team,payload[0] == 1) if payload[0] in [0,1] else "无效的防御选择。"
	return "未知操作。"
