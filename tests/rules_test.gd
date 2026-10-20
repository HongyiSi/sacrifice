extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const H = preload("res://tests/helpers.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	_catalog_and_privacy()
	_order_and_death()
	_draw_and_heal()
	_defense()
	_attacks()
	_control_and_prophecy()
	_mirror()
	_full_matches()
	print("RULES_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _conserved(game) -> bool:
	var ids: Array = game.deck.duplicate()
	ids.append_array(game.discard)
	for c in game.characters: ids.append_array(c.hand.filter(func(id): return game.catalog.has(id)))
	for a in game.queue:
		if not a.virtual and not a.discarded: ids.append(a.card)
	var unique := {}
	for id in ids: unique[id] = true
	return ids.size() == 89 and unique.size() == 89

func _catalog_and_privacy() -> void:
	var g = Rules.new()
	g.start(42)
	var names := {}
	var priorities := {}
	for c in g.catalog.values():
		names[c.name] = true
		var priority := "%s:%s" % [c.main, c.secondary]
		check(not priorities.has(priority), "unique physical priority " + priority)
		priorities[priority] = true
		check(c.main >= 0 and c.main <= 10, "scope")
	check(names.size() == 35 and g.catalog.size() == 89, "35 types / 89 cards")
	check(g.deck.size() == 65 and _conserved(g), "setup plus first draw")
	var view: Dictionary = g.snapshot(1)
	check(view.characters[0].hand.is_empty() and view.characters[0].hand_count == 4, "opponent hand redacted")
	check(view.characters[3].hand.size() == 4, "own hand visible")
	check(g.submit(0, [int(g.characters[0].hand[0]), 0, 0]) == "", "legal plan")
	check(g.snapshot(1).queue.is_empty() and g.snapshot(1).my_plan.is_empty(), "committed plan secret")
	check(g.submit(0, [0, 0, 0]) != "", "cannot change commitment")
	check(g.submit(1, [int(g.characters[0].hand[0]), 0, 0]) != "", "other role's card rejected")
	check(g.submit(1, [0.0, 0, 0]) != "" and g.submit(1, [0, 0]) != "", "malformed plans rejected")

func _order_and_death() -> void:
	var g = H.fixture()
	var a: int = H.give(g, 0, "strike", 10)
	var b: int = H.give(g, 3, "strike", 1)
	var c: int = H.give(g, 4, "triple_strike", 6)
	g.characters[3].hp = 1
	H.begin(g, {0:a, 3:b, 4:c})
	check(g._action(g.current_id).actor == 0, "same main higher secondary first")
	check(g.characters[0].revealed and g.characters[3].revealed and not g.characters[4].revealed, "same-main simultaneous reveal; lower main hidden")
	for item in g.snapshot(0).queue:
		if item.actor == 4: check(item.card == 0 and item.main == -1 and item.secondary == -1, "unrevealed enemy metadata redacted")
	check(g.target(1, 0) != "" and g.target(0, 99) != "", "invalid target / wrong team rejected")
	g.target(0, 3)
	check(g.characters[3].hp == 0 and H.action_for(g,3).status == "cancelled", "same-main death cancels pending card")
	check(g.characters[4].revealed and g._action(g.current_id).actor == 4, "next group revealed after cancellation")
	check(g.request.options.has(3), "dead target remains selectable")
	g.target(1, 0)
	check(g.characters[0].hp == 2 and g.phase == "review" and _conserved(g), "triple strike and cleanup")
	g.confirm(0)
	check(g.round_number == 1, "both players must confirm")
	g.confirm(1)
	check(g.round_number == 2 and g.characters[3].hand.is_empty(), "dead character never draws")

func _draw_and_heal() -> void:
	var g = H.fixture()
	var collect: int = H.give(g, 0, "collect")
	var gamble: int = H.give(g, 1, "gambler")
	H.give(g, 1, "strike")
	H.give(g, 1, "double_strike")
	H.begin(g, {0:collect, 1:gamble})
	check(g.characters[0].hand.size() == 3 and g.characters[1].hand.size() == 7, "collect and discard-all gambler")
	check(g.phase == "review" and _conserved(g), "draw effects finish and preserve cards")
	g = H.fixture()
	gamble = H.give(g,0,"gambler")
	H.give(g,0,"strike")
	g.discard.append_array(g.deck)
	g.deck.clear()
	H.begin(g,{0:gamble})
	check(g.characters[0].hand.size() == 7 and not g.characters[0].hand.has(gamble), "gambler recycles discards but never draws its still-resolving card")
	check(_conserved(g), "recycling preserves every physical card")
	g = H.fixture()
	var heal: int = H.give(g, 0, "heal")
	var team_heal: int = H.give(g, 1, "team_heal")
	g.characters[0].hp = 2
	g.characters[1].hp = 4
	g.characters[2].hp = 0
	H.begin(g, {0:heal, 1:team_heal})
	check(g.characters[0].hp == 5 and g.characters[1].hp == 5 and g.characters[2].hp == 0, "healing caps; team heal never resurrects")
	check(g.characters[3].hp == 5, "team heal excludes opponent")

func _defense() -> void:
	var g = H.fixture()
	H.begin(g, {0:H.give(g,0,"defense"),3:H.give(g,3,"strike"),4:H.give(g,4,"double_strike")})
	check(g.characters[0].shield == 1, "defense activates before attacks")
	g.target(1,0)
	check(g.phase == "reacting" and g.characters[0].hp == 5, "damage waits for defender decision")
	check(g.defend(1,true) != "", "attacker cannot decide defender reaction")
	g.defend(0,false)
	check(g.characters[0].hp == 4 and g.characters[0].shield == 1, "declining defense retains use")
	g.target(1,0)
	g.defend(0,true)
	check(g.characters[0].hp == 4 and g.characters[0].shield == 0 and g.phase == "review", "consume defense cancels full second attack")
	check(H.action_for(g,4).status == "blocked", "blocked card tracked")
	g = H.fixture()
	g.characters[0].hp = 1
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"bounty")})
	g.target(1,0)
	g.defend(0,true)
	check(g.characters[0].hp == 1 and g.characters[3].hand.is_empty(), "defense cancels bounty reward too")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"area_strike")})
	check(g.phase == "review" and g.characters[0].hp == 4 and g.characters[1].hp == 4, "area damage bypasses single-target defense")
	check(g.characters[0].shield == 0, "unused defense expires")

func _attacks() -> void:
	var g = H.fixture()
	g.characters[0].hp = 2
	g.characters[0].shield = 1
	H.begin(g,{0:H.give(g,0,"strike"),3:H.give(g,3,"judgment")})
	g.target(1,0)
	check(g.characters[0].hp == 0 and g.phase == "review", "judgment skill executes <=2; bypasses defense")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"judgment")})
	g.target(0,3)
	check(g.characters[3].hp == 5, "judgment does nothing above threshold")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"godslayer"),3:H.give(g,3,"strike"),4:H.give(g,4,"triple_strike")})
	check(g.request.options.has(3) and not g.request.options.has(4) and not g.request.options.has(1), "godslayer targets only already revealed characters")
	check(g.target(0,4) != "", "unrevealed target rejected for godslayer")
	g.target(0,3)
	check(g.characters[3].hp == 2, "godslayer deals three")
	g.target(1,0)
	g.target(1,0)
	check(g.characters[0].hp == 1 and _conserved(g), "remaining attacks resolve")
	g = H.fixture()
	g.characters[3].hp = 1
	H.begin(g,{0:H.give(g,0,"bounty")})
	g.target(0,3)
	check(g.characters[0].hand.size() == 2, "bounty enemy death draws two")
	g = H.fixture()
	g.characters[1].hp = 1
	H.begin(g,{0:H.give(g,0,"bounty")})
	g.target(0,1)
	check(g.characters[0].hand.is_empty(), "bounty friendly death has no reward")
	g = H.fixture()
	g.characters[0].hp = 1
	H.begin(g,{0:H.give(g,0,"strike")})
	g.target(0,0)
	check(g.characters[0].hp == 0 and H.action_for(g,0).status == "done", "running self-kill card completes")

func _control_and_prophecy() -> void:
	var g = H.fixture()
	H.begin(g,{0:H.give(g,0,"prophecy"),3:H.give(g,3,"ignore"),4:H.give(g,4,"strike")})
	check(g._action(g.current_id).actor == 3, "ignore precedes prophecy")
	check(g.choose(0,5) != "" and g.choose(1,7) != "", "choice ownership and range validated")
	g.choose(1,5)
	g.choose(0,5)
	check(g.badges[0] == 1 and g.phase == "review", "prophecy checked at ordinary phase end")
	check(H.action_for(g,4).status == "skipped" and not g.characters[4].revealed, "ignore prevents reveal")
	var hidden: Dictionary = g.snapshot(0).queue.filter(func(a): return a.actor == 4)[0]
	check(hidden.card == 0 and hidden.main == -1, "skipped enemy card remains private")
	g = H.fixture()
	g.badges = [3,0]
	H.begin(g,{0:H.give(g,0,"prophecy")})
	g.choose(0,5)
	check(g.phase == "ended" and g.winner == 0 and g.win_reason == "徽章", "fourth badge wins immediately")
	g.confirm(0)
	g.confirm(1)
	check(g.match_id == 2 and g.badges == [0,0] and g.phase == "planning", "rematch resets badges and deck")
	g = H.fixture()
	g.characters[0].hp = 4
	H.begin(g,{0:H.give(g,0,"prophecy")})
	g.choose(0,5)
	check(g.badges[0] == 0, "failed prophecy gives nothing")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"suppress"),3:H.give(g,3,"strike")})
	g.choose(0,H.action_for(g,3).id)
	check(g.phase == "review" and not g.characters[3].revealed and H.action_for(g,3).status == "suppressed", "suppression prevents reveal and effect")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"suppress"),3:H.give(g,3,"judgment")})
	check(g.phase == "targeting" and g._action(g.current_id).actor == 3, "same-main cards revealed together")
	g.target(1,0)
	check(g.phase == "review", "suppression cannot select already revealed same-main card")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"mirror")})
	check(g.phase == "review", "no valid mirror target safely fizzles")

func _mirror() -> void:
	var g = H.fixture()
	H.begin(g,{0:H.give(g,0,"mirror"),1:H.give(g,1,"suppress"),3:H.give(g,3,"strike")})
	g.choose(0,H.action_for(g,3).id)
	g.choose(0,H.action_for(g,3).id)
	check(g.queue.size() == 3 and g.phase == "review", "suppression prevents attached mirror from triggering")
	g = H.fixture()
	g.characters[0].hp = 1
	H.begin(g,{0:H.give(g,0,"mirror"),3:H.give(g,3,"judgment"),4:H.give(g,4,"strike")})
	g.choose(0,H.action_for(g,4).id)
	g.target(1,0)
	check(g.characters[0].hp == 0 and not H.action_for(g,0,true).is_empty(), "mirror triggers after owner's earlier death")
	g.target(1,1)
	check(g.request.team == 0 and g._action(g.current_id).virtual, "dead owner controls copied effect")
	g.target(0,3)
	check(g.characters[3].hp == 4 and _conserved(g) and g.discard.size() == 3, "virtual copy resolves without adding a physical card")
	g = H.fixture()
	g.characters[0].hp = 1
	H.begin(g,{0:H.give(g,0,"mirror"),3:H.give(g,3,"area_strike")})
	g.choose(0,H.action_for(g,3).id)
	check(g.characters[0].hp == 0 and g.characters[3].hp == 4 and g.characters[4].hp == 4, "copied area attack uses copier's team even after death")
	check(H.action_for(g,0,true).secondary == 0 and _conserved(g), "copy priority zero; conserved deck")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"mirror"),1:H.give(g,1,"ignore"),3:H.give(g,3,"strike")})
	g.choose(0,H.action_for(g,3).id)
	g.choose(0,5)
	check(g.queue.size() == 3 and g.phase == "review", "skip prevents mirror trigger")
	g = H.fixture()
	g.characters[3].hp = 1
	g.characters[4].hp = 0
	g.characters[5].hp = 0
	H.begin(g,{0:H.give(g,0,"area_strike")})
	check(g.phase == "ended" and g.winner == 0, "team wipe after automatic area damage")
	g = H.fixture()
	for c in g.characters: c.hp = 0
	g._finish_round()
	check(g.phase == "ended" and g.winner == -1, "both teams eliminated draw")

func _full_matches() -> void:
	for seed_value in range(1,9):
		var g = Rules.new()
		g.start(seed_value)
		for _step in range(1200):
			check(_conserved(g), "card conservation in mixed match")
			if g.phase == "ended": break
			var s: Dictionary = g.snapshot(0)
			match g.phase:
				"planning":
					g.submit(0,H.auto_plan(g.snapshot(0),0))
					g.submit(1,H.auto_plan(g.snapshot(1),1))
				"targeting", "death_targeting": check(g.target(g.request.team,H.auto_input(s)) == "", "bot legal character target")
				"choosing": check(g.choose(g.request.team,H.auto_input(s)) == "", "bot legal choice")
				"selecting": check(g.pick(g.request.team,H.auto_pick(g.snapshot(g.request.team))) == "", "bot legal selection")
				"responding": check(g.respond(g.request.team,g.request.options[0]) == "", "bot legal amulet")
				"reacting": check(g.defend(g.request.team,true) == "", "bot legal defense")
				"review":
					g.confirm(0)
					g.confirm(1)
		check(g.phase == "ended", "mixed deck complete match seed %d" % seed_value)
	var g = Rules.new()
	g.start(7)
	for _n in range(24):
		g.submit(0,[0,0,0])
		g.submit(1,[0,0,0])
		g.confirm(0)
		g.confirm(1)
		while g.phase == "selecting" and g.request.type == "hand_limit":
			g.pick(g.request.team,H.auto_pick(g.snapshot(g.request.team)))
	check(g.phase == "planning" and _conserved(g) and g.characters.all(func(c):return c.hand.size()==7), "all-pass discards excess while preserving every physical card")
	check(g.log_lines.any(func(line):return "普通弃牌重新洗入牌库" in line),"hand-limit discards safely refill the deck")
