extends SceneTree
const H = preload("res://tests/helpers.gd")
const Session = preload("res://scripts/session.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ALL_NORMAL_FAIL " + label)

func _initialize() -> void:
	_reversal()
	_amulets()
	_low_cards()
	_feign_and_skip()
	_extra_and_silence()
	_pain_reverse()
	_interactions()
	print("ALL_NORMAL_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func die(g, actor: int) -> void:
	g.characters[actor].hp = 0
	g.characters[actor].death_round = g.round_number

func activate(g, owner: int, key: String, target: int = -1) -> void:
	var id: int = H.give_death(g,owner,key)
	g._activate({"actor":owner,"card":id},owner if target < 0 else target)

func key(g) -> String:
	return g._info(g.input_action).key if not g.request.is_empty() else ""

func finish(g) -> void:
	for _i in range(200):
		match g.phase:
			"targeting","death_targeting","choosing": g.skip_effect(g.request.team)
			"responding": g.respond(g.request.team,0)
			"reacting": g.defend(g.request.team,false)
			"selecting": g.pick(g.request.team,H.auto_pick(g.snapshot(g.request.team)))
			_: return
	check(false,"scenario terminates")

func _reversal() -> void:
	var g = H.fixture()
	H.begin(g,{0:H.give(g,0,"reverse"),1:H.give(g,1,"holy_strike"),2:H.give(g,2,"strike"),3:H.give(g,3,"magic_strike"),4:H.give(g,4,"double_strike")})
	check(key(g) == "holy_strike" and not g.reversed_order,"reverse waits for remaining main 10 card")
	g.target(0,3)
	check(g.reversed_order and key(g) == "magic_strike","lower main 2 after completing main 10")
	g.target(1,0)
	check(key(g) == "double_strike","main 4 before main 5 in reversed order")
	g.skip_effect(1); g.skip_effect(0)
	check(g.phase == "review","reverse round completes")
	g.confirm(0); g.confirm(1)
	check(not g.reversed_order,"reverse resets next round")
	g = H.fixture()
	activate(g,0,"privilege",3)
	H.begin(g,{0:H.give(g,0,"reverse"),3:H.give(g,3,"strike"),4:H.give(g,4,"magic_strike")})
	check(key(g) == "strike" and g.input_action.main == 105,"privilege precedes reversal")
	g.skip_effect(1)
	check(g.reversed_order and key(g) == "magic_strike","reversal applies after privileged cards")
	finish(g)
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"reverse"),1:H.give(g,1,"strike",1),3:H.give(g,3,"strike",10)})
	check(g.input_action.actor == 3,"reversal preserves secondary descending order")
	finish(g)

func _amulets() -> void:
	var g = H.fixture()
	var shield: int = H.give(g,0,"attack_amulet")
	H.begin(g,{0:shield,3:H.give(g,3,"quick_strike")})
	check(not g.characters[0].revealed and key(g) == "quick_strike","amulet stays facedown through its priority")
	var hidden: Dictionary = g.snapshot(1).queue.filter(func(a): return a.actor == 0)[0]
	check(hidden.card == 0 and hidden.base_main == -1 and hidden.base_secondary == -1,"hidden reaction card has no rank leak")
	g.target(1,0)
	check(g.phase == "responding" and g.characters[0].hp == 5,"attack pauses before damage")
	check(g.respond(1,g.request.options[0]) != "" and g.respond(0,999) != "","wrong owner and invalid reaction rejected")
	check(g.snapshot(1).input.options.is_empty(),"response options private")
	g.respond(0,g.request.options[0])
	check(g.phase == "review" and g.characters[0].hp == 5 and g.discard.has(shield),"attack amulet cancels whole card and consumes itself")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"attack_amulet"),3:H.give(g,3,"strike"),4:H.give(g,4,"double_strike")})
	g.target(1,0); g.respond(0,0)
	check(g.characters[0].hp == 4 and key(g) == "double_strike","declined response preserves amulet")
	g.target(1,0); g.respond(0,g.request.options[0])
	check(g.characters[0].hp == 4,"preserved amulet can cancel later attack")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"attack_amulet"),3:H.give(g,3,"area_strike")})
	check(g.phase == "responding" and g.characters[0].hp == 5,"area attack offers amulet before any damage")
	g.respond(0,g.request.options[0])
	check(g.phase == "review" and g.characters.slice(0,3).all(func(c): return c.hp == 5),"attack amulet cancels all group targets")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"magic_amulet"),3:H.give(g,3,"hasty_spell")})
	g.target(1,0)
	check(g.phase == "responding","magic amulet targets lower secondary in same main")
	g.respond(0,g.request.options[0])
	check(g.characters[0].hp == 5,"magic damage cancelled")
	g = H.fixture()
	g.characters[0].hp = 2; g.characters[1].hp = 2
	H.begin(g,{0:H.give(g,0,"magic_amulet"),1:H.give(g,1,"team_heal")})
	check(g.phase == "responding","magic amulet recognizes membership in group skill target")
	g.respond(0,g.request.options[0])
	check(g.characters[0].hp == 2 and g.characters[1].hp == 2,"cancels all targets of group skill")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"magic_amulet"),3:H.give(g,3,"holy_strike")})
	g.target(1,0)
	check(g.phase == "review" and g.characters[0].hp == 2,"lower rank amulet cannot cancel holy strike")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"holy_amulet"),3:H.give(g,3,"holy_strike")})
	check(g.phase == "targeting" and key(g) == "holy_strike","holy amulet waits for a target")
	g.target(1,0)
	check(g.phase == "responding","holy amulet responds after its owner becomes target")
	g.respond(0,g.request.options[0])
	check(g.phase == "review" and g.characters[0].hp == 5,"holy strike cancelled before damage")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"holy_amulet"),1:H.give(g,1,"strike"),3:H.give(g,3,"attack_amulet")})
	g.target(0,3)
	check(g.phase == "responding" and g.request.team == 1,"enemy can respond with attack amulet")
	g.respond(1,g.request.options[0])
	check(g.phase == "review" and g.characters[3].hp == 5,"unrelated holy amulet cannot counter another amulet")
	g = H.fixture()
	g.characters[0].hp = 1; g.badges[1] = 3
	H.begin(g,{0:H.give(g,0,"attack_amulet"),3:H.give(g,3,"glory")})
	g.target(1,0); g.respond(0,g.request.options[0])
	check(g.badges[1] == 3 and g.characters[0].hp == 1,"cancelled glory has no damage or reward")
	g = H.fixture()
	g.characters[0].hp = 1
	H.begin(g,{0:H.give(g,0,"attack_amulet"),3:H.give(g,3,"holy_strike"),4:H.give(g,4,"strike")})
	g.target(1,0)
	check(H.action_for(g,0).status == "held","unrevealed amulet waits for possible revival")
	finish(g)

func _low_cards() -> void:
	var g = H.fixture()
	H.begin(g,{0:H.give(g,0,"magic_strike")})
	g.target(0,3)
	check(g.characters[3].hp == 3,"magic strike deals two skill damage")
	g = H.fixture()
	H.give_death(g,3,"immortal"); g.characters[3].hp = 1; g.badges[0] = 3
	H.begin(g,{0:H.give(g,0,"glory")}); g.target(0,3)
	check(g.phase == "ended" and g.winner == 0 and g.characters[3].hp == 1,"glory rewards death event despite instant revival and wins immediately")
	g = H.fixture(); g.characters[1].hp = 1
	H.begin(g,{0:H.give(g,0,"glory")}); g.target(0,1)
	check(g.badges[0] == 0,"friendly glory kill gives no badge")
	g = H.fixture(); g.badges[0] = 3
	H.begin(g,{0:H.give(g,0,"badge")})
	check(g.phase == "ended" and g.winner == 0 and g.discard.size() == 1,"badge card wins and is consumed")
	g = H.fixture()
	var secret: int = H.give(g,3,"holy_strike")
	H.begin(g,{0:H.give(g,0,"peek")}); g.target(0,3)
	check(g.phase == "selecting" and g.request.type == "inspect" and g.snapshot(0).input.cards == [secret],"peek exposes current hand to caster")
	check(g.snapshot(1).input.cards.is_empty() and g.snapshot(0).characters[3].hand.is_empty(),"peek is a private one-time view, not ongoing hand access")
	check(g.pick(1,[]) != "" and g.pick(0,[secret]) != "","peek acknowledgement validates controller and payload")
	g.pick(0,[])
	check(g.phase == "review" and not g.snapshot(0).input.has("cards"),"peek closes after acknowledgement")
	g = H.fixture(); g.death_deck.erase(104); g.characters[3].hand = [104]
	H.begin(g,{0:H.give(g,0,"plunder")}); g.target(0,3)
	check(g.characters[0].hand == [104] and g.characters[3].hand.is_empty(),"plunder can transfer cursed hand card without discarding it")
	check(not g.death_discard.has(104) and not g.discard.has(104),"plunder preserves physical death card identity")
	g = H.fixture(); die(g,3)
	H.begin(g,{0:H.give(g,0,"raise_dead")}); g.target(0,3)
	check(g.characters[3].hp == 1,"raise dead may revive enemy at one hp")
	g = H.fixture(); g.characters[1].hp = 1
	H.begin(g,{0:H.give(g,0,"heal_other")})
	check(not g.request.options.has(0),"heal other excludes self")
	g.target(0,1)
	check(g.characters[1].hp == 4,"heal other restores three hp")
	g = H.fixture()
	H.give(g,0,"strike"); H.give(g,0,"heal")
	H.begin(g,{0:H.give(g,0,"elegy")})
	if g.request.get("type","") == "elegy": g.pick(0,g.request.options.slice(0,2))
	check(g.characters[0].deathrattles.size() == 1 and g.death_deck.size() == 19,"elegy draws one death card")
	check(g.snapshot(1).characters[0].deathrattles.is_empty() and g.snapshot(1).characters[0].death_count == 1,"drawn death identity remains private")
	g = H.fixture(); g.death_discard = g.death_deck.duplicate(); g.death_deck.clear()
	H.give(g,0,"strike"); H.give(g,0,"heal")
	H.begin(g,{0:H.give(g,0,"elegy")})
	if g.request.get("type","") == "elegy": g.pick(0,g.request.options.slice(0,2))
	check(g.phase == "review" and g.characters[0].deathrattles.is_empty(),"empty death deck does not recycle consumed deaths")

func _feign_and_skip() -> void:
	var g = H.fixture()
	H.give_death(g,0,"death_sentence"); H.give_death(g,3,"blood_rite"); g.characters[4].hp = 2
	H.begin(g,{0:H.give(g,0,"feign"),1:H.give(g,1,"skip_death")})
	check(key(g) == "death_sentence" and g.characters[0].hp == 3 and not g.death_phase,"feign pays health before starting own death cards before normal death phase")
	g.target(0,3)
	check(g.phase == "review" and g.skip_death_phase and g.characters[4].hp == 2,"feign-caused deaths wait for normal phase which fate can skip")
	check(g.characters[3].deathrattles == [118],"skipped phase retains unconsumed card")
	g.confirm(0); g.confirm(1); H.begin(g,{})
	check(g.characters[4].hp == 2 and g.characters[3].deathrattles == [118],"old skipped death not carried into next round")
	g = H.fixture()
	activate(g,0,"blessing",1); H.give_death(g,0,"legacy"); H.give_death(g,0,"immortal")
	H.begin(g,{0:H.give(g,0,"feign")})
	check(g.phase == "review" and g.characters[0].hp == 3 and g._has_effect("blessing",1),"feign preserves already activated target and does not revive living immortal")
	check(g.characters[1].hand.size() == 5 and g.death_discard.has(114),"feign consumes one-shot death card")
	g = H.fixture()
	H.give_death(g,0,"sacrifice_badges"); g.badges[0] = 2
	H.begin(g,{0:H.give(g,0,"feign")})
	check(g.phase == "ended" and g.winner == 0,"feign death can end match immediately")
	g = H.fixture()
	H.give_death(g,0,"blood_rite"); H.give_death(g,0,"death_sentence")
	g.characters[1].hp = 1
	H.begin(g,{0:H.give(g,0,"feign")})
	check(g.characters[1].hp == 10 and key(g) == "death_sentence","feign resolves all own unactivated death cards in priority order")
	finish(g)

func _extra_and_silence() -> void:
	var g = H.fixture()
	H.begin(g,{0:H.give(g,0,"overload"),3:H.give(g,3,"silence")})
	g.target(1,0); g.confirm(0); g.confirm(1)
	check(g.play_limit(g.characters[0]) == 0,"silence overrides overload next round")
	check(g.submit(0,[[g.characters[0].hand[0]],0,0]) != "","silenced plans rejected by host")
	H.begin(g,{}); g.confirm(0); g.confirm(1)
	check(g.play_limit(g.characters[0]) == 1,"silence and overload expire together")
	g = H.fixture()
	H.begin(g,{0:H.give(g,0,"overload")})
	g.characters[0].extra_round = 2; g.characters[0].extra_count = 1
	g.confirm(0); g.confirm(1)
	check(g.play_limit(g.characters[0]) == 4,"overload three plus heart one")
	for rank in [1,2,3]: H.give(g,0,"strike",rank)
	var cards: Array = g.characters[0].hand.slice(0,4)
	check(g.submit(0,[cards,0,0]) == "" and g.submit(1,[0,0,0]) == "","host accepts four unique cards with combined effects")
	check(g.queue.size() == 4,"every multi-plan card enters queue")
	finish(g)
	g = H.fixture()
	activate(g,0,"ghost"); die(g,0); g.characters[0].silenced_round = 1
	H.begin(g,{})
	check(g.queue.is_empty(),"silence blocks ghost-generated ordinary play")

func _pain_reverse() -> void:
	var g = H.fixture()
	activate(g,0,"pain"); die(g,0)
	var rev: int = H.give(g,1,"reverse")
	H.begin(g,{1:H.give(g,1,"strike",10),2:H.give(g,2,"strike",9),3:H.give(g,3,"magic_strike"),4:H.give(g,4,"double_strike")})
	g.target(0,0); g.pick(0,[rev])
	check(key(g) == "strike" and g.input_action.actor == 2 and not g.reversed_order,"pain reversal waits for remainder of interrupted main 5")
	g.skip_effect(0)
	check(g.reversed_order and key(g) == "magic_strike","pain reversal starts at lowest remaining main")
	finish(g)

func _interactions() -> void:
	var g = H.fixture()
	activate(g,0,"privilege",0)
	var mirror: int = H.give(g,0,"mirror")
	var reverse: int = H.give(g,3,"reverse")
	H.begin(g,{0:mirror,3:reverse,4:H.give(g,4,"strike")})
	check(g.request.type == "card" and g.request.options.has(H.action_for(g,3).id),"privileged mirror may target lower priority reversal")
	g.choose(0,H.action_for(g,3).id)
	check(g.reversed_order and key(g) == "strike","privileged copied reversal acts before original and sends main 5 ahead of main 10")
	finish(g)
	check(not g.reversed_order and g.phase == "review","original reversal later toggles the order back")
	g = H.fixture()
	activate(g,0,"privilege",0)
	H.begin(g,{0:H.give(g,0,"mirror"),1:H.give(g,1,"strike"),3:H.give(g,3,"attack_amulet")})
	g.choose(0,H.action_for(g,3).id); g.target(0,3); g.respond(1,g.request.options[0])
	check(g.phase == "review" and g.characters[3].hp == 5,"mirrored amulet is already revealed and has no future facedown response")
	check(g.queue.filter(func(a): return a.virtual).size() == 1,"amulet reveal triggers attached mirror exactly once")
	g = H.fixture()
	activate(g,0,"privilege",0)
	H.begin(g,{0:H.give(g,0,"mirror"),1:H.give(g,1,"strike"),3:H.give(g,3,"holy_amulet")})
	# Attach to the lower-priority holy amulet, then target its owner.
	g.choose(0,H.action_for(g,3).id)
	g.target(0,3)
	g.respond(1,g.request.options[0])
	check(g.phase == "review" and g.characters[0].hp == 5,"copying a reacting holy amulet cannot generate endless response chains")
	g = H.fixture()
	H.give_death(g,3,"death_sentence"); die(g,3)
	H.begin(g,{0:H.give(g,0,"raise_dead")}); g.target(0,3)
	check(g.phase == "review" and g.characters[3].hp == 1 and g.death_queue.is_empty(),"ordinary revival before death phase prevents death entry")
	g = H.fixture()
	g.death_deck = [118]
	H.give(g,0,"strike"); H.give(g,0,"heal")
	H.begin(g,{0:H.give(g,0,"elegy"),3:H.give(g,3,"feign")})
	if g.request.get("type","") == "elegy": g.pick(0,g.request.options.slice(0,2))
	check(g.phase == "review" and g.characters[0].deathrattles == [118],"elegy resolves before main 0 feign by secondary rank")
	g = H.fixture(); g.characters[0].extra_round = 1; g.characters[0].extra_count = 1
	g.death_deck.erase(118); g.death_deck = [118]
	var song: int = H.give(g,0,"elegy"); var fake: int = H.give(g,0,"feign")
	g.characters[1].hp = 1
	H.give(g,0,"strike"); H.give(g,0,"heal")
	g.submit(0,[[song,fake],0,0]); g.submit(1,[0,0,0])
	g.pick(0,g.request.options.slice(0,2))
	check(g.characters[1].hp == 10 and g.death_discard.has(118),"newly drawn death can be immediately used by same-round feign")
	g = H.fixture()
	activate(g,0,"privilege",0)
	activate(g,1,"pain"); die(g,1)
	var reverse_extra: int = H.give(g,0,"reverse")
	H.give_death(g,3,"last_dance"); die(g,3)
	# Ordinary pain while a high-priority caster retains privilege.
	H.begin(g,{0:H.give(g,0,"strike")})
	g.target(0,1); g.pick(0,[reverse_extra])
	check(g.reversed_order and key(g) == "last_dance","privileged pain reversal completes before entering death phase")
	finish(g)
	g = H.fixture()
	var session = Session.new(); session.game = g; session.active = true; session.hosting = true
	H.begin(g,{0:H.give(g,0,"attack_amulet"),3:H.give(g,3,"strike")}); g.target(1,0)
	var before: int = g.revision
	# Direct rules API validates phase; transport additionally validates revision.
	check(g.respond(0,999) != "" and g.revision == before,"invalid response does not consume choice or advance revision")
	g.respond(0,g.request.options[0])
	check(g.respond(0,0) != "","duplicate response cannot affect a later phase")
	session.free()
	g = H.fixture(); die(g,0)
	H.give_death(g,0,"immortal")
	var feign_id: int = H.give(g,0,"feign")
	g.characters[0].hand.erase(feign_id); g.deck.append(feign_id)
	g._add_action(0,feign_id,true)
	g._advance()
	check(g.phase == "review" and g.characters[0].hp == 1 and g.characters[0].deathrattles == [120],"dead virtual feign resolves immortal immediately without consuming it")
