extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const H = preload("res://tests/helpers.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("DEATH_FAIL " + label)

func _initialize() -> void:
	_setup_and_visibility()
	_healing_and_hands()
	_dynamic_queue_and_dance()
	_resurrection_and_reentry()
	_eligibility_and_victory()
	_full_matches()
	print("DEATH_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _die(g, actor: int, this_round: bool = true) -> void:
	g.characters[actor].hp = 0
	g.characters[actor].death_round = g.round_number if this_round else g.round_number - 1

func _conserved(g) -> bool:
	var ids: Array = g.death_discard.duplicate()
	ids.append_array(g.death_deck)
	for c in g.characters:
		ids.append_array(c.deathrattles)
		ids.append_array(c.hand.filter(func(id): return g.death_catalog.has(id)))
	var unique := {}
	for id in ids: unique[id] = true
	return ids.size() == 20 and unique.size() == 20

func _current(g) -> String:
	var action: Dictionary = g._death_action()
	return "" if action.is_empty() else g.death_catalog[action.card].key

func _setup_and_visibility() -> void:
	var g = Rules.new()
	g.start(42)
	check(g.death_catalog.size() == 20 and g.death_deck.size() == 14 and _conserved(g), "twenty distinct deathrattles; six dealt")
	var expected := {"blood_rite":18, "death_sentence":17, "last_dance":16, "legacy":14, "resurrection":10, "vanish":9}
	for card in g.death_catalog.values():
		if expected.has(card.key): check(card.priority == expected[card.key] and card.type == "一次性", "document priority " + card.name)
	for team in range(2):
		var s: Dictionary = g.snapshot(team)
		for c in s.characters:
			check(c.death_count == 1, "one card per character")
			check(c.deathrattles.size() == (1 if c.team == team else 0), "only own starting deathrattles visible")
	var snapshot: Dictionary = g.snapshot(0)
	snapshot.characters[0].deathrattles.clear()
	check(g.characters[0].deathrattles.size() == 1, "snapshot detached from authoritative hands")
	g.start(99, 2)
	check(g.death_queue.is_empty() and g.death_discard.is_empty() and g.death_revealed.is_empty() and _conserved(g), "rematch resets cards and public knowledge")

func _healing_and_hands() -> void:
	var g = H.fixture()
	H.give_death(g, 0, "blood_rite")
	_die(g, 0)
	_die(g, 2)
	g.characters[1].hp = 1
	g.characters[3].hp = 2
	g._finish_round()
	check(g.characters[1].hp == 10 and g.characters[3].hp == 2, "blood rite heals living allies only")
	check(g.characters[0].hp == 0 and g.characters[2].hp == 0, "healing never resurrects")
	check(g.death_discard == [118] and g.characters[0].deathrattles.is_empty(), "one-shot consumed once")
	g = H.fixture()
	H.give_death(g, 0, "legacy")
	_die(g, 0)
	_die(g, 2)
	# Empty draw pile must recycle ordinary discards for this deathrattle.
	g.discard = g.deck.duplicate()
	g.deck.clear()
	g._finish_round()
	check(g.characters[1].hand.size() == 5 and g.characters[0].hand.is_empty() and g.characters[2].hand.is_empty(), "legacy only draws for living allies")
	check(g.characters[3].hand.is_empty() and g.deck.size() == g.catalog.size()-5, "legacy leaves opponents unchanged and recycles deck")
	g = H.fixture()
	H.give_death(g, 0, "vanish")
	H.give_death(g, 3, "legacy")
	var card: int = H.give(g, 3, "strike")
	H.give(g, 3, "heal")
	_die(g, 0)
	_die(g, 3, false)
	g._finish_round()
	check(g.request.options == [0,1,2,3,4,5], "vanish permits dead and living targets")
	check(g.target(1,3) != "", "opponent cannot control dead owner's choice")
	check(g.target(0,6) != "", "invalid target rejected")
	check(g.target(0,3) == "" and g.characters[3].hand.is_empty() and g.discard.has(card), "vanish discards corpse's ordinary hand")
	check(g.characters[3].deathrattles == [114], "vanish does not discard deathrattles")

func _dynamic_queue_and_dance() -> void:
	var g = H.fixture()
	H.give_death(g, 0, "death_sentence")
	H.give_death(g, 3, "blood_rite")
	H.give_death(g, 1, "last_dance")
	_die(g, 0)
	_die(g, 1)
	g.characters[4].hp = 1
	g._finish_round()
	check(_current(g) == "death_sentence", "initial queue selects highest priority")
	g.characters[3].shield = 1
	check(g.target(0,3) == "", "sentence targets a living enemy")
	check(g.characters[3].hp == 0 and g.characters[3].shield == 1, "deathrattle damage does not invoke ordinary defense")
	check(g.characters[4].hp == 10 and g.death_discard == [117,118] and _current(g) == "last_dance", "new priority 18 resolves before pending priority 16")
	check(g.snapshot(1).death_queue.size() == 3, "newly queued cards immediately public")
	for _i in range(5): check(g.target(0,4) == "", "dance five legal hits")
	check(g.characters[4].hp == 5 and g.death_discard == [117,118,116], "five damage then discard")

	g = H.fixture()
	H.give_death(g, 0, "last_dance")
	H.give_death(g, 3, "blood_rite")
	_die(g, 0)
	g.characters[3].hp = 1
	g.characters[4].hp = 2
	g._finish_round()
	g.target(0,3)
	check(_current(g) == "last_dance" and g._death_action().hits == 1 and g.characters[4].hp == 2, "higher priority new death waits until all dance hits finish")
	check(g.request.options.has(3), "next hit permits newly dead target")
	check(g.request.description.contains("2 / 5"), "dance progress updates")
	for target_id in [5,1,5,1]: check(g.target(0,target_id) == "", "dance can distribute or repeat targets")
	check(g.characters[5].hp == 10 and g.characters[1].hp == 3 and g.death_discard == [116,118], "queued blood rite waits for fifth hit then heals allies")
	check(g.phase == "review", "dance chain completes")

	g = H.fixture()
	H.give_death(g, 0, "last_dance")
	for id in [0,1,2,3,4]: _die(g,id)
	g.characters[5].hp = 1
	g._finish_round()
	g.target(0,5)
	check(g.phase == "death_targeting" and g.request.options.size() == 6,"dance can still target corpses when everyone is dead")
	for _i in range(4): check(g.target(0,5) == "","remaining dance hits may select the same corpse")
	check(g.phase == "ended" and g.winner == -1 and g.death_discard == [116], "all-dead draw waits for remaining dance resolution")

func _resurrection_and_reentry() -> void:
	var g = H.fixture()
	H.give_death(g, 0, "resurrection")
	H.give_death(g, 1, "vanish")
	_die(g, 0)
	_die(g, 1)
	_die(g, 3, false)
	g._finish_round()
	check(g.request.options == [0,1,3], "revive includes self and old enemy corpse")
	check(g.target(0,2) != "", "cannot resurrect a living target")
	check(g.target(0,1) == "" and g.characters[1].hp == 5 and g.phase == "review", "resurrect with five health, below the new maximum")
	check(g.characters[1].deathrattles == [109] and g.death_discard == [110], "revive retrieves pending card without consuming it")
	check(g.death_queue.filter(func(a): return a.card == 109)[0].status == "returned", "pending event marked returned")
	check(g.snapshot(1).characters[1].deathrattles == [109], "returned card remains known to opponent")
	g.confirm(0)
	g.confirm(1)
	check(g.snapshot(1).characters[1].deathrattles == [109], "known identity persists into new round")
	g.characters[1].hp = 1
	H.begin(g, {4:H.give(g,4,"strike")})
	g.target(1,1)
	check(_current(g) == "vanish" and g.request.team == 0, "retrieved card triggers on later death")
	g.target(0,4)
	check(g.death_discard == [110,109], "each physical card consumed at most once")

	g = H.fixture()
	H.give_death(g, 0, "resurrection")
	_die(g, 0)
	_die(g, 3, false)
	g._finish_round()
	g.target(0,3)
	check(g.characters[3].hp == 5, "enemy revival allowed by card text")

	g = H.fixture()
	H.give_death(g, 1, "resurrection")
	H.give_death(g, 0, "legacy")
	g.characters[0].hp = 1
	_die(g, 1)
	H.begin(g, {0:H.give(g,0,"triple_strike"),3:H.give(g,3,"strike")})
	g.target(1,0)
	check(_current(g) == "resurrection" and g.death_discard == [114], "higher priority legacy already consumed before revive")
	g.target(0,0)
	check(g.characters[0].hp == 5 and g.characters[0].deathrattles.is_empty(), "revive does not retrieve consumed card")
	check(H.action_for(g,0).status == "cancelled" and g.characters[3].hp == 5, "revive does not restore cancelled ordinary action")

	# Exercise the queue invariant for future multi-card hands: retrieve/re-kill in one phase.
	g = H.fixture()
	H.give_death(g, 0, "last_dance")
	H.give_death(g, 1, "vanish")
	_die(g, 0)
	_die(g, 1)
	g._finish_round()
	g._revive(1)
	g._damage(g._death_action(), 1, 99)
	g._enqueue_deaths(g.characters[1])
	var pending: Array = g.death_queue.filter(func(a): return a.card == 109 and a.status == "pending")
	check(pending.size() == 1 and g.characters[1].deathrattles == [109], "re-death enqueues retrieved card exactly once")
	for _i in range(5): g.target(0,3)
	check(_current(g) == "vanish", "requeued card resolves after current effect")
	g.target(0,4)
	check(g.death_discard == [116,109], "returned event never also resolves")

func _eligibility_and_victory() -> void:
	var g = H.fixture()
	H.give_death(g, 0, "vanish")
	_die(g, 0, false)
	g._finish_round()
	check(g.death_queue.is_empty() and g.characters[0].deathrattles == [109], "old dead role does not trigger every round")
	g = H.fixture()
	H.give_death(g, 0, "vanish")
	_die(g, 0)
	g._revive(0)
	g._finish_round()
	check(g.death_queue.is_empty(), "role revived before death phase does not trigger")
	g = H.fixture()
	H.give_death(g, 0, "vanish")
	_die(g, 0, false)
	g._revive(0)
	g.characters[0].hp = 1
	H.begin(g, {3:H.give(g,3,"strike")})
	g.target(1,0)
	check(_current(g) == "vanish", "old dead revived then killed this round triggers")
	g.target(0,3)

	g = H.fixture()
	H.give_death(g, 0, "resurrection")
	for id in range(6): _die(g,id)
	g._finish_round()
	check(g.phase == "death_targeting" and g.winner == -2, "both teams dead still wait for pending resurrection")
	g.target(0,1)
	check(g.phase == "ended" and g.winner == 0, "revival changes result before final victory check")
	g = H.fixture()
	H.give_death(g, 0, "death_sentence")
	for id in [0,1,2,4,5]: _die(g,id)
	g._finish_round()
	check(g.phase == "death_targeting", "wiped team retains deathrattle choices")
	g.target(0,3)
	check(g.phase == "ended" and g.winner == -1, "last deathrattle can turn defeat into draw")
	g = H.fixture()
	H.give_death(g, 0, "resurrection")
	_die(g, 0)
	g._finish_round()
	check(g.phase == "death_targeting" and g.request.options == [0], "sole dead actor can choose self revival")
	check(g.target(0,0) == "" and g.characters[0].hp == 5 and g.death_discard == [110], "self revival consumes resurrection once")

func _full_matches() -> void:
	var used := {}
	for seed_value in range(1, 25):
		var g = Rules.new()
		g.start(seed_value)
		for _step in range(1600):
			check(_conserved(g), "death card conservation throughout match")
			for id in g.death_discard: used[id] = true
			if g.phase == "ended": break
			match g.phase:
				"planning":
					g.submit(0, H.auto_plan(g.snapshot(0),0))
					g.submit(1, H.auto_plan(g.snapshot(1),1))
				"targeting", "death_targeting":
					check(g.target(g.request.team,H.auto_input(g.snapshot(g.request.team))) == "", "bot legal target")
				"choosing": g.choose(g.request.team,H.auto_input(g.snapshot(g.request.team)))
				"selecting": check(g.pick(g.request.team,H.auto_pick(g.snapshot(g.request.team))) == "", "bot legal selection")
				"responding": g.respond(g.request.team,g.request.options[0])
				"reacting": g.defend(g.request.team,true)
				"review":
					g.confirm(0)
					g.confirm(1)
		check(g.phase == "ended", "mixed full match finishes seed %d" % seed_value)
	check(used.size() >= 6, "full matches exercise multiple one-shot and transfer deathrattles")
