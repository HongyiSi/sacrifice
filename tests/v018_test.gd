extends SceneTree
const H = preload("res://tests/helpers.gd")
const Actions = preload("res://scripts/match_actions.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V018_FAIL " + label)

func _initialize() -> void:
	_catalog()
	_prediction()
	_gift()
	_conversions()
	_suppression()
	_frenzy()
	_presentation()
	_random_matches()
	print("V018_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func activate(g, owner: int, key: String, target: int = -1) -> void:
	var id: int = H.give_death(g,owner,key)
	g._activate({"actor":owner,"card":id},owner if target < 0 else target)

func curse(g, actor: int) -> void:
	g.death_deck.erase(104)
	g.characters[actor].hand.append(104)

func drain(g) -> void:
	for _i in range(1000):
		if not g.animation.is_empty(): g.advance_animation(); continue
		if g.phase in ["review","ended","planning"]: return
		var team: int = g.request.get("team",0)
		match g.phase:
			"targeting","death_targeting": g.target(team,H.auto_input(g.snapshot(team)))
			"choosing": g.choose(team,H.auto_input(g.snapshot(team)))
			"selecting": g.pick(team,H.auto_pick(g.snapshot(team)))
			"responding": g.respond(team,0)
			"reacting": g.defend(team,false)
			_: check(false,"unexpected phase "+g.phase); return
	check(false,"finite resolution")

func _catalog() -> void:
	var g = H.fixture(8)
	check(g.normal_type_count == 60 and g.catalog.size() == 128,"60 types and 128 physical ordinary cards")
	var ranks := {}
	for id in g.catalog:
		check(not g.death_catalog.has(id),"ordinary/death ID disjoint "+str(id))
		var c: Dictionary = g.catalog[id]
		if c.main < 0: continue # Unplayable spare cards have no printed priorities.
		var rank := "%d/%d" % [c.main,c.secondary]
		check(not ranks.has(rank),"unique priority "+rank)
		ranks[rank] = true
	check(g.snapshot(0).catalog[104].key == "curse" and not g.snapshot(0).catalog[104].playable,"curse remains unplayable after deck expansion")
	for data in [["cards_to_heart",10],["cards_to_blades",2],["late_suppress",14]]:
		var id: int = H.give(g,0,data[0],data[1])
		check(g.snapshot(0).catalog[id].key == data[0],"new high ID reaches snapshot "+data[0])
	check(g.catalog[H.give(g,1,"suppress")].name == "先手压制","early suppression renamed")

func _prediction() -> void:
	var g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"anticipation"),3:H.give(g,3,"magic_strike"),4:H.give(g,4,"late_suppress"),5:H.give(g,5,"peek")})
	check(g.phase == "review" and g.reveal_locked_teams == [false,true],"average exactly two locks opposing team")
	check(g.queue.filter(func(a): return a.actor >= 3).all(func(a): return not a.revealed and a.status == "suppressed"),"locked cards stay hidden")
	check(g.snapshot(0).queue.filter(func(a): return a.actor >= 3).all(func(a): return a.card == 0 and a.main == -1),"lock reveals no card identities or priorities")
	check(g.snapshot(1).characters[3].ongoing_effects.any(func(e): return e.key == "anticipation"),"lock is visible as a persistent round status")
	g.advance_round()
	check(g.reveal_locked_teams == [false,false],"lock resets on next round")
	g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"anticipation"),3:H.give(g,3,"triple_strike"),4:H.give(g,4,"magic_strike"),5:H.give(g,5,"peek")})
	check(not g.reveal_locked_teams[1] and g.phase == "targeting","average above two allows ordinary resolution")
	drain(g)
	g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"anticipation")})
	check(not g.reveal_locked_teams[1],"empty opposing set is not a successful prediction")
	g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"anticipation"),3:H.give(g,3,"warcry"),4:H.give(g,4,"badge")})
	check(g.reveal_locked_teams[1] and g.characters[3].warcry_bonus == 3,"same-priority cards already flipped still resolve")
	check(g.badges[1] == 0,"later badge is suppressed")
	g = H.fixture(8)
	activate(g,3,"privilege")
	var a: Dictionary = g._add_action(0,H.give(g,0,"anticipation"))
	g._add_action(3,H.give(g,3,"badge"))
	g._anticipation(a)
	check(not g.reveal_locked_teams[1],"prediction uses effective main priorities including privilege")
	g = H.fixture(8)
	var guard: int = H.give(g,3,"magic_amulet")
	H.begin(g,{0:H.give(g,0,"anticipation"),4:H.give(g,4,"badge")})
	check(g.phase == "responding","enemy skill amulet may protect team from prediction")
	g.respond(1,0)
	check(g.reveal_locked_teams[1] and g.characters[3].hand.has(guard),"declined in-hand amulet stays private and does not affect hidden-table average")
	g = H.fixture(8)
	g.reveal_locked_teams[1] = true
	var extra: int = H.give(g,3,"strike")
	g._play_revealed_hand(3,[extra],"疯狂")
	check(g.queue[0].status == "suppressed" and not g.queue[0].revealed,"round lock also stops future forced reveals")
	check(g.snapshot(0).queue[0].card == 0,"forced locked card remains private")

func _gift() -> void:
	var g = H.fixture(8)
	var card: int = H.give(g,0,"strike")
	curse(g,0)
	H.begin(g,{0:H.give(g,0,"gift")})
	check(g.request.options.size() == 5 and not g.request.options.has(0),"gift targets another pawn on either team")
	check(g.target(0,0) != "","gift rejects self")
	g.target(0,3)
	check(g.request.type == "gift" and g.request.count == 2,"gift permits up to two hand cards")
	check(g.snapshot(1).input.options.is_empty(),"gift chooser hides hand from opponent")
	check(g.snapshot(0).input.options.has(104),"curse can be transferred without discarding")
	check(g.pick(0,[card,card]) != "" and g.pick(0,[]) != "" and g.pick(1,[card,104]) != "","gift rejects duplicates count and wrong controller")
	var revision: int = g.revision
	check(Actions.apply(g,0,"pick",[card,104],g.match_id,g.round_number,revision) == "","gift resolves through shared intent path")
	check(g.characters[0].hand.is_empty() and g.characters[3].hand.has(card) and g.characters[3].hand.has(104),"gift transfers both physical cards")
	check(not g.discard.has(card) and not g.death_discard.has(104),"transferred cards never enter discard")
	check(Actions.apply(g,0,"pick",[card,104],g.match_id,g.round_number,revision) != "","repeated stale intent cannot transfer twice")
	g = H.fixture(8)
	for _i in range(7): H.give(g,3,"strike")
	var one: int = H.give(g,0,"heal")
	var two: int = H.give(g,0,"defense")
	activate(g,1,"prison",3)
	activate(g,2,"divinity"); g.characters[2].hp = 0
	var deck_before: int = g.deck.size()
	H.begin(g,{0:H.give(g,0,"gift")}); g.target(0,3); g.pick(0,[one,two])
	check(g.request.is_empty() and g.characters[3].hand.has(one) and g.discard.has(two),"gift keeps first card and discards incoming overflow")
	check(g.characters[3].hand.size() == 8 and g.deck.size() == deck_before-1,"transfer bypasses prison and divinity without drawing")
	check(g.characters[3].hand.size() == 8 and g.phase == "review","overflow completes without a discard decision")
	g = H.fixture(8)
	one = H.give(g,0,"strike"); two = H.give(g,0,"heal")
	var guard: int = H.give(g,3,"magic_amulet")
	H.begin(g,{0:H.give(g,0,"gift")}); g.target(0,3); g.pick(0,[one,two])
	check(g.phase == "responding" and g.characters[0].hand.size() == 2,"amulet response occurs before transfer")
	check(not JSON.stringify(g.snapshot(1).active_action).contains("values"),"selected gift identities never enter public action")
	g.respond(1,g.request.options[0])
	check(g.characters[0].hand.size() == 2 and g.characters[3].hand.is_empty(),"cancelled gift leaves both hands unchanged")
	g = H.fixture(8); H.give(g,0,"strike"); H.begin(g,{0:H.give(g,0,"gift")})
	check(g.phase == "targeting" and g.characters[0].hand.size() == 1,"single remaining card can be gifted")
	check(g.target(0,1) == "" and g.request.count == 1,"one-card hand uses one available option")
	check(g.pick(0,g.characters[0].hand.duplicate()) == "" and g.characters[1].hand.size() == 1,"single card transfer completes")
	g = H.fixture(8); one = H.give(g,0,"strike"); two = H.give(g,0,"heal"); g.characters[1].hp = 0
	H.begin(g,{0:H.give(g,0,"gift")}); g.target(0,1); g.pick(0,[one,two])
	check(g.characters[1].hand.size() == 2,"gift may transfer to a dead ally")

func _conversions() -> void:
	var g = H.fixture(8); g.characters[0].hp = 2
	for key in ["strike","heal","defense"]: H.give(g,0,key)
	curse(g,0); H.begin(g,{0:H.give(g,0,"cards_to_heart")})
	check(g.characters[0].hp == 5 and g.characters[0].hand == [104],"heart heals once per actually discarded card and preserves curse")
	check(g.discard.size() == 4 and not g.discard.has(104),"conversion and spent cards each discarded once")
	g = H.fixture(8); g.characters[0].hp = 7
	H.give(g,0,"strike"); H.give(g,0,"heal"); H.begin(g,{0:H.give(g,0,"cards_to_heart")})
	check(g.characters[0].hp == 8,"heart respects maximum HP")
	g = H.fixture(8); g.characters[0].hp = 2; activate(g,1,"blessing",0)
	H.give(g,0,"strike"); H.begin(g,{0:H.give(g,0,"cards_to_heart")})
	check(g.characters[0].hp == 2 and g.characters[0].hand.is_empty(),"blessing blocks recovery but not completed discard")
	g = H.fixture(8); curse(g,0); H.begin(g,{0:H.give(g,0,"cards_to_blades")})
	check(g.phase == "review" and g.characters[0].hand == [104],"zero discard creates no blade target prompt")
	g = H.fixture(8)
	for key in ["strike","heal","defense"]: H.give(g,0,key)
	curse(g,0); g.characters[0].warcry_round = g.round_number; g.characters[0].warcry_bonus = 3
	activate(g,4,"blessing",3)
	H.begin(g,{0:H.give(g,0,"cards_to_blades")})
	check(g.request.options == [0,1,2,3,4,5] and "1 / 3" in g.request.description,"blade offers all pawn targets and accurate remaining count")
	check(g.target(0,6) != "","blade rejects invalid targets")
	g.target(0,3); g.target(0,3); g.target(0,4)
	check(g.characters[3].hp == 6 and g.characters[4].hp == 7,"blade can repeat or change targets; skill ignores warcry and attack immunity")
	check(g.phase == "review" and g.characters[0].hand == [104],"blade consumes exact count and retains curse")
	g = H.fixture(8); H.give(g,0,"strike"); H.give(g,0,"heal")
	H.begin(g,{0:H.give(g,0,"cards_to_blades")}); g.target(0,3); g.skip_effect(0)
	check(g.characters[3].hp == 8 and g.characters[0].hand.is_empty() and g.phase == "review","skip before all choices deals no damage and keeps paid discard")
	g = H.fixture(8); H.give(g,0,"strike"); H.give(g,0,"heal")
	var guard: int = H.give(g,3,"magic_amulet")
	H.begin(g,{0:H.give(g,0,"cards_to_blades")}); g.target(0,3)
	check(g.phase == "targeting" and g.characters[3].hp == 8,"amulet waits until every target has been chosen")
	g.target(0,3)
	check(g.phase == "responding","blade skill offers target amulet before first damage")
	g.respond(1,g.request.options[0])
	check(g.characters[3].hp == 8 and g.phase == "review","amulet cancels remaining blade hits")
	g = H.fixture(8); H.give(g,0,"strike"); H.give(g,0,"heal"); H.give_death(g,3,"immortal"); g.characters[3].hp = 1
	H.begin(g,{0:H.give(g,0,"cards_to_blades")}); g.target(0,3)
	check(g.characters[3].hp == 1 and g.death_events == 0 and g.phase == "targeting","partial blade selection never triggers damage or resurrection")
	g.target(0,3); check(g.characters[3].hp == 1 and g.death_events == 2,"second hit can kill the revived target again")

func _suppression() -> void:
	for key in ["suppress","late_suppress"]:
		var g = H.fixture(8)
		H.begin(g,{0:H.give(g,0,key),3:H.give(g,3,"badge")})
		check(g.request.type == "card","suppression uses direct facedown-card selection "+key)
		g.choose(0,H.action_for(g,3).id)
		check(g.badges[1] == 0 and H.action_for(g,3).status == "suppressed","suppression prevents reveal "+key)
	var g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"late_suppress"),3:H.give(g,3,"magic_strike")})
	check(g.request.type == "character" and g.input_action.actor == 3,"late suppression cannot select already flipped same-main skill")
	drain(g)
	g = H.fixture(8); g.reversed_order = true
	H.begin(g,{0:H.give(g,0,"late_suppress"),3:H.give(g,3,"strike")})
	check(g.phase == "targeting" and g.input_action.actor == 3,"reversal does not allow suppression to target higher-priority hidden card")
	drain(g)

func _frenzy() -> void:
	var g = H.fixture(8); g.characters[0].hp = 3
	for key in ["warcry","heal","overload"]: H.give(g,0,key)
	curse(g,0); H.begin(g,{0:H.give(g,0,"frenzy")})
	check(g.phase == "review" and g.characters[0].hand == [104],"frenzy plays all ordinary hand cards and keeps curse")
	check(g.queue.size() == 4 and g.queue.all(func(a): return a.revealed and a.status == "done"),"all frenzy cards are public and consumed")
	check(g.characters[0].hp == 5 and g.characters[0].warcry_bonus == 3 and g.characters[0].overload_round == 2,"frenzy resolves the actual extra effects")
	var resolves: Array = g.log_lines.filter(func(line): return "结算普通牌" in line)
	check("战吼" in resolves[1] and "愈合" in resolves[2] and "过载" in resolves[3],"frenzy uses descending current priorities")
	g = H.fixture(8); g.reversed_order = true; H.give(g,0,"heal"); H.give(g,0,"overload"); H.begin(g,{0:H.give(g,0,"frenzy")})
	resolves = g.log_lines.filter(func(line): return "结算普通牌" in line)
	check("过载" in resolves[1] and "愈合" in resolves[2],"frenzy honors reversed main priorities")
	g = H.fixture(8); H.give(g,0,"holy_amulet"); H.give(g,0,"strike"); H.begin(g,{0:H.give(g,0,"frenzy")})
	check(g.phase == "targeting" and g._info(g.input_action).key == "holy_amulet","frenzy pauses for amulet recipient")
	g.target(0,0)
	check(g.queue.filter(func(a): return g.catalog[a.card].key == "holy_amulet")[0].status == "done","frenzy amulet resolves normally as a hand transfer")
	g.target(0,3); check(g.characters[3].hp == 7 and g.phase == "review","frenzy resumes after target input")
	g = H.fixture(8); H.give(g,0,"strike"); var guard: int = H.give(g,3,"attack_amulet")
	H.begin(g,{0:H.give(g,0,"frenzy")}); g.target(0,3)
	check(g.phase == "responding","frenzy-created attack respects existing amulet")
	g.respond(1,g.request.options[0]); check(g.characters[3].hp == 8 and g.phase == "review","cancelled extra attack resumes safely")
	g = H.fixture(8); g.characters[0].hp = 1; H.give(g,0,"magic_strike"); H.give(g,0,"overload")
	H.begin(g,{0:H.give(g,0,"frenzy")}); g.target(0,0)
	check(g.characters[0].hp == 0 and g.characters[0].get("overload_round",-1) == -1,"death cancels remaining revealed physical frenzy cards")
	g = H.fixture(8); curse(g,0); H.begin(g,{0:H.give(g,0,"frenzy")})
	check(g.phase == "review" and g.characters[0].hand == [104],"frenzy with no playable hand terminates")

func _presentation() -> void:
	for key in ["gift","cards_to_heart","cards_to_blades","late_suppress","frenzy","anticipation"]:
		var g = H.fixture(8); g.characters[0].hp = 4
		H.give(g,0,"strike"); H.give(g,0,"heal")
		g.presentation_enabled = true; g.resolution_presentation_enabled = true
		H.begin(g,{0:H.give(g,0,key),3:H.give(g,3,"badge")})
		check(g.animation.get("kind","") == "card_reveal","physical cards flip before intro "+key)
		g.advance_animation()
		check(g.animation.get("kind","") == "card_start","basic card intro exists "+key)
		drain(g)
		check(g.phase in ["review","ended"],"presentation jobs and player choices terminate "+key)

func _conserved(g) -> bool:
	var cards: Array = g.deck.duplicate()
	cards.append_array(g.discard)
	for c in g.characters: cards.append_array(c.hand.filter(func(id): return g.catalog.has(id)))
	for a in g.queue:
		if not a.virtual and not a.discarded and not a.get("transferred",false): cards.append(a.card)
	var unique := {}
	for id in cards: unique[id] = true
	return cards.size() == g.catalog.size() and unique.size() == g.catalog.size()

func _random_matches() -> void:
	for seed_value in range(16):
		var g = H.Rules.new(); g.start(18000+seed_value)
		for _round in range(12):
			if g.phase == "ended": break
			check(_conserved(g),"all physical cards conserved at planning")
			for team in [0,1]: check(g.submit(team,H.auto_plan(g.snapshot(team),team)) == "","random legal plan")
			drain(g)
			check(_conserved(g),"transfers discards and forced plays conserve all physical cards")
			if g.phase == "ended": break
			g.advance_round(); drain(g)
			check(g.phase in ["planning","ended"],"random match reaches next planning or win")
