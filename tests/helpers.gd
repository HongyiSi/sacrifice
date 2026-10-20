extends RefCounted
const Rules = preload("res://scripts/rules.gd")

static func fixture(hp: int = 5):
	# Existing tactical scenarios start wounded at five HP; production starts at
	# Rules.MAX_HP. Pass eight explicitly for the current full-health scenarios.
	var game = Rules.new()
	# Legacy animation tests focus on effect impact timings; v013 tests enable card intros explicitly.
	game.resolution_presentation_enabled = false
	game.stage_presentation_enabled = false
	game.start(42)
	game.deck = game.catalog.keys()
	game.discard.clear()
	game.death_deck = game.death_catalog.keys()
	for c in game.characters:
		c.hp = hp
		c.hand.clear()
		c.deathrattles.clear()
	return game

static func give_death(game, actor: int, key: String) -> int:
	for id in game.death_catalog:
		if game.death_catalog[id].key == key:
			for c in game.characters: c.deathrattles.erase(id)
			game.death_discard.erase(id)
			game.death_deck.erase(id)
			game.characters[actor].deathrattles.append(id)
			return id
	assert(false, "Missing deathrattle: " + key)
	return 0

static func give(game, actor: int, key: String, secondary: int = -1) -> int:
	for id in game.deck:
		var info: Dictionary = game.catalog[id]
		if info.key == key and (secondary < 0 or secondary == info.secondary):
			game.deck.erase(id)
			game.characters[actor].hand.append(id)
			return id
	push_error("Missing fixture card: " + key)
	return 0

static func begin(game, chosen: Dictionary, self_defense: bool = true) -> void:
	for team in range(2):
		var plan := [0, 0, 0]
		for slot in range(3): plan[slot] = int(chosen.get(team * 3 + slot, 0))
		# Exported release builds omit assertions. Always execute the action.
		var error: String = game.submit(team, plan)
		assert(error == "",error)
	# Older scenarios expect their defensive card to protect its own caster.
	# Fulfill the new real target request explicitly, without changing rules.
	while self_defense and game.phase == "targeting" and game._info(game.input_action).key == "defense":
		var error: String = game.target(game.request.team,game.input_action.actor)
		assert(error == "",error)

static func action_for(game, actor: int, virtual: bool = false) -> Dictionary:
	for a in game.queue:
		if a.actor == actor and a.virtual == virtual: return a
	return {}

static func auto_plan(s: Dictionary, team: int) -> Array:
	var plan := [0, 0, 0]
	for slot in range(3):
		var c: Dictionary = s.characters[team * 3 + slot]
		if c.hp <= 0 or c.play_limit == 0: continue
		var best := -1
		for id in c.hand:
			var card: Dictionary = s.catalog[id]
			if not card.get("playable",true): continue
			var score := int(card.main)
			if card.type == "攻击": score += 100
			if card.key == "area_strike": score += 30
			if card.key == "judgment": score += 30
			if card.key == "heal" and c.hp <= 2: score += 110
			if score > best:
				best = score
				plan[slot] = id
		if c.play_limit > 1 and plan[slot] != 0:
			var extra: Array = [plan[slot]]
			for id in c.hand:
				if not extra.has(id) and s.catalog[id].get("playable",true) and extra.size() < c.play_limit: extra.append(id)
			plan[slot] = extra
	return plan

static func auto_input(s: Dictionary) -> int:
	var request: Dictionary = s.input
	var team: int = request.team
	match request.type:
		"character":
			if s.active_card.get("key","") in ["defense","holy_amulet","attack_amulet","magic_amulet"]: return s.active_action.actor
			var options: Array = request.options.duplicate()
			var revival: bool = s.active_card.get("key", "") in ["resurrection","raise_dead","heal_other","heart","blessing","greed","privilege"]
			options.sort_custom(func(a, b):
				var ca: Dictionary = s.characters[a]
				var cb: Dictionary = s.characters[b]
				# Corpses are legal targets, but the test bot still tries to damage
				# living roles instead of wasting every turn on the same corpse.
				if not revival and (ca.hp == 0) != (cb.hp == 0): return ca.hp > 0
				if ca.team != cb.team: return (ca.team == team) if revival else (ca.team != team)
				if s.active_card.get("type","") == "攻击":
					var ba: bool = ca.statuses.has("blessing")
					var bb: bool = cb.statuses.has("blessing")
					if ba != bb: return not ba
				var ia: bool = ca.deathrattles.has(120) and s.characters.any(func(c): return c.id != ca.id and c.team == ca.team and c.hp > 0)
				var ib: bool = cb.deathrattles.has(120) and s.characters.any(func(c): return c.id != cb.id and c.team == cb.team and c.hp > 0)
				if ia != ib: return not ia
				return ca.hp < cb.hp)
			return options[0]
		"card":
			for action in s.queue:
				if request.options.has(action.id) and s.characters[action.actor].team != team: return action.id
			return request.options[0]
		"number":
			var action: Dictionary = s.queue[s.cursor]
			if s.catalog[action.card].key == "prophecy": return clampi(s.characters[action.actor].hp,1,10)
			return 5 if request.options.has(5) else request.options[0]
		"defense": return 1
	return 0

static func auto_pick(s: Dictionary) -> Array:
	if s.input.type == "inspect": return []
	if s.input.type == "pain": return [1]
	if s.input.type == "bonus": return []
	return s.input.options.slice(0,s.input.count)
