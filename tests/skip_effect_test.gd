extends SceneTree
const H = preload("res://tests/helpers.gd")
const Session = preload("res://scripts/session.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SKIP_FAIL " + label)

func _initialize() -> void:
	_ordinary()
	_mirror()
	_deaths()
	_protocol()
	print("SKIP_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _ordinary() -> void:
	for key in ["strike", "double_strike", "triple_strike", "bounty", "judgment", "godslayer"]:
		var g = H.fixture()
		var id: int = H.give(g,0,key)
		H.begin(g,{0:id})
		check(g.phase == "targeting" and g.request.can_skip, key + " offers skip")
		check(g.skip_effect(1) != "" and g.discard.is_empty(), "other player cannot skip " + key)
		check(g.skip_effect(0) == "" and g.phase == "review", "skip advances " + key)
		check(g.discard == [id] and g.characters[0].hand.is_empty(), "card consumed " + key)
		check(g.characters.all(func(c): return c.hp == 5 and c.hand.is_empty()), "no damage or draw reward " + key)
		check(g.queue[0].status == "declined", "public reason retained")
		check(g.skip_effect(0) != "", "cannot skip during review")
	var g = H.fixture()
	var id: int = H.give(g,0,"godslayer")
	H.begin(g,{0:id,1:H.give(g,1,"strike")})
	check(g.request.options == [0,1], "only friendly roles have revealed")
	g.skip_effect(0)
	check(g._action(g.current_id).actor == 1 and g.characters[0].hp == 5 and g.characters[1].hp == 5, "godslayer avoids mandatory friendly fire, next action continues")
	g.skip_effect(0)
	check(g.phase == "review", "consecutive skips complete round")
	for key in ["mirror", "suppress"]:
		g = H.fixture()
		H.begin(g,{0:H.give(g,0,key),3:H.give(g,3,"strike")})
		check(g.request.type == "card" and g.request.can_skip, "card-target skip " + key)
		g.skip_effect(0)
		check(g.mirrors.is_empty() and H.action_for(g,3).status == "active", "no link or suppression " + key)
		g.target(1,0)
		check(g.characters[0].hp == 4 and g.queue.size() == 2, "original target action unaffected")
	for key in ["ignore", "prophecy"]:
		g = H.fixture()
		H.begin(g,{0:H.give(g,0,key)})
		check(g.request.type == "number" and g.request.can_skip, "number selection skip " + key)
		g.skip_effect(0)
		check(g.phase == "review" and g.badges == [0,0] and g.skipped.is_empty(), "numeric skip has no effect")
	g = H.fixture()
	check(g.skip_effect(0) != "", "cannot skip during planning")
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike")})
	g.target(1,0)
	check(g.phase == "reacting" and not g.request.get("can_skip",false), "no skip after target commits into defense")
	check(g.skip_effect(0) != "" and g.skip_effect(1) != "", "neither side can withdraw an attack during defender decision")
	g.defend(0,true)
	check(g.phase == "review" and g.characters[0].hp == 5, "normal defender cancellation remains valid")

func _mirror() -> void:
	var g = H.fixture()
	H.begin(g,{0:H.give(g,0,"mirror"),3:H.give(g,3,"strike")})
	g.choose(0,H.action_for(g,3).id)
	g.characters[0].hp = 1
	g.target(1,0)
	check(g.characters[0].hp == 0 and g._action(g.current_id).virtual, "dead mirror owner receives copied target choice")
	check(g.skip_effect(0) == "" and g.characters[3].hp == 5, "dead mirror owner may decline copied attack")
	check(g.discard.size() == 2 and H.action_for(g,0,true).status == "declined", "skipping copy does not create physical discard")
	for c in g.catalog.values():
		if c.key == "mirror": check(not c.text.contains("强制"), "mirror wording updated")

func _die(g, actor: int) -> void:
	g.characters[actor].hp = 0
	g.characters[actor].death_round = g.round_number

func _deaths() -> void:
	for key in ["death_sentence", "resurrection", "vanish", "last_dance"]:
		var g = H.fixture()
		var id: int = H.give_death(g,0,key)
		_die(g,0)
		_die(g,3)
		H.give(g,4,"strike")
		g._finish_round()
		check(g.request.can_skip and g.request.team == 0, "death offers skip " + key)
		check(g.skip_effect(1) != "", "opponent cannot skip deathrattle")
		if key == "resurrection": check(g.request.options == [0,3], "self and enemy can be resurrected")
		check(g.skip_effect(0) == "" and g.phase == "review", "death skip completes " + key)
		check(g.characters[3].hp == 0 and g.characters[4].hp == 5 and g.characters[4].hand.size() == 1, "no forced enemy benefit or friendly harm")
		check(g.death_discard == [id] and g.characters[0].deathrattles.is_empty() and g.death_queue[0].status == "declined", "death still consumed " + key)
	var g = H.fixture()
	H.give_death(g,0,"last_dance")
	H.give_death(g,3,"blood_rite")
	H.give_death(g,1,"vanish")
	_die(g,0)
	_die(g,1)
	g.characters[3].hp = 1
	g.characters[4].hp = 2
	g._finish_round()
	g.target(0,3)
	check(g._death_action().hits == 1 and g.characters[4].hp == 2, "dance mid-hit queues heal")
	g.skip_effect(0)
	check(g.characters[3].hp == 0 and g.characters[4].hp == 10, "past death stays and newly queued heal runs")
	check(g.death_discard == [116,118] and g.death_catalog[g._death_action().card].key == "vanish", "skip runs highest newly queued death before older pending one")
	g.skip_effect(0)
	check(g.phase == "review" and g.death_discard == [116,118,109], "next death still independently skippable")
	g = H.fixture()
	H.give_death(g,0,"resurrection")
	H.give_death(g,1,"vanish")
	_die(g,0)
	_die(g,1)
	g._finish_round()
	g.skip_effect(0)
	check(g.death_catalog[g._death_action().card].key == "vanish" and g.characters[1].hp == 0, "declining revival does not retrieve target's pending card")
	g.skip_effect(0)
	g = H.fixture()
	H.give_death(g,0,"resurrection")
	for id in range(6): _die(g,id)
	g._finish_round()
	g.skip_effect(0)
	check(g.phase == "ended" and g.winner == -1, "skip final revival permits terminal draw")

func _protocol() -> void:
	var session = Session.new()
	var g = H.fixture()
	session.game = g
	var errors: Array = []
	session.problem.connect(func(message): errors.append(message))
	H.begin(g,{0:H.give(g,0,"strike",10),1:H.give(g,1,"strike",9)})
	var revision: int = g.revision
	session._apply(0,"skip_effect",[0],g.match_id,g.round_number,revision)
	check(errors.size() == 1 and g.revision == revision, "skip rejects malformed payload")
	session._apply(0,"skip_effect",[],g.match_id - 1,g.round_number,revision)
	check(errors.size() == 2 and g.revision == revision, "skip rejects prior match")
	session._apply(0,"skip_effect",[],g.match_id,g.round_number - 1,revision)
	check(errors.size() == 3 and g.revision == revision, "skip rejects prior round")
	session._apply(0,"skip_effect",[],g.match_id,g.round_number,revision)
	check(g._action(g.current_id).actor == 1, "valid skip advances to next same-team action")
	session._apply(0,"skip_effect",[],g.match_id,g.round_number,revision)
	check(errors.size() == 4 and g._action(g.current_id).actor == 1, "double-click cannot skip next action")
	session.free()
