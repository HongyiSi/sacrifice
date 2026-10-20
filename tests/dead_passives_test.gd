extends "res://tests/v018_test.gd"
const G = preload("res://tests/gem_scenarios.gd")

func _initialize() -> void:
	_amulets()
	_anticipation_with_ghost()
	_stale_responses()
	_gems_while_dead()
	_defense_owners()
	_death_exceptions()
	print("DEAD_PASSIVES_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func settle_animation(g) -> void:
	for _i in range(100):
		if g.animation.is_empty(): return
		g.advance_animation()
	check(false,"animation completes")

func _amulets() -> void:
	for presented in [false,true]:
		for holder in [0,3]:
			for key in ["holy_amulet","attack_amulet","magic_amulet"]:
				for revived in [false,true]:
					var g = H.fixture(8)
					g.presentation_enabled = presented
					var guard: int = H.give(g,holder,key)
					g.defiled_cards[guard] = true
					g.characters[holder].hp = 0
					if revived: g._revive(holder,4)
					var attacker: int = 3 if holder == 0 else 0
					var card: int = H.give(g,attacker,"magic_strike" if key == "magic_amulet" else "strike")
					H.begin(g,{attacker:card})
					settle_animation(g)
					check(g.target(g.request.team,holder) == "","can still target a corpse")
					if revived:
						check(g.phase == "responding" and g.request.options == [guard],"revival restores amulet response")
						check(g.respond(g.request.team,guard) == "","revived pawn accepts amulet")
					else:
						check(g.phase != "responding","dead pawn never receives amulet prompt")
					check(G.drain(g),"amulet scenario completes")
					check(g.characters[holder].hand.has(guard) and not g.discard.has(guard),"dead or defiled amulet remains in hand")
					check(g.queue.any(func(a): return a.get("hand_response",false)) == revived,"dead amulet creates no reaction or animation action")
					check(g.characters[holder].hp == (4 if revived else 0) and _conserved(g),"HP and physical cards conserved")

func _anticipation_with_ghost() -> void:
	var g = H.fixture(8)
	g.characters[0].hp = 0
	activate(g,0,"ghost")
	var guard: int = H.give(g,0,"magic_amulet")
	H.begin(g,{3:H.give(g,3,"anticipation"),1:H.give(g,1,"strike")})
	check(g.phase != "responding" and not g.queue.any(func(a): return a.get("hand_response",false)),"anticipation ignores dead ghost holder's amulet")
	check(G.drain(g) and g.characters[0].hand.has(guard),"screenshot scenario finishes without dead amulet prompt")
	g = H.fixture(8)
	g.characters[0].hp = 0
	H.give(g,0,"magic_amulet")
	guard = H.give(g,1,"magic_amulet")
	H.begin(g,{3:H.give(g,3,"anticipation"),1:H.give(g,1,"strike")})
	check(g.phase == "responding" and g.request.options == [guard],"multi-target response skips dead holder and offers living ally")
	check(g.respond(0,guard) == "" and not g.reveal_locked_teams[0],"living ally can still cancel anticipation")
	check(G.drain(g),"living ally response completes")

func _stale_responses() -> void:
	var g = H.fixture(8)
	var guard: int = H.give(g,0,"attack_amulet")
	H.begin(g,{3:H.give(g,3,"strike")});g.target(1,0)
	g.characters[0].hp = 0
	check(g.respond(0,guard) != "" and g.characters[0].hand.has(guard),"stale amulet acceptance is rejected without consuming card")
	check(g.respond(0,0) == "" and G.drain(g),"stale amulet prompt can still be declined")
	g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike")})
	g.target(1,0);g.characters[0].hp = 0
	check(g.defend(0,true) != "" and g.characters[0].shield == 1,"stale defense acceptance is rejected without consuming shield")
	check(g.defend(0,false) == "" and G.drain(g),"stale defense prompt can still be declined")

func _gems_while_dead() -> void:
	for presented in [false,true]:
		for key in ["sapphire","ruby"]:
			var g = H.fixture(8)
			g.presentation_enabled = presented
			var gem: int = H.give(g,0,key)
			g.characters[0].hp = 0
			if key == "sapphire": g._begin_round()
			else: H.begin(g,{})
			var triggered := false
			for _i in range(200):
				if g.animation.is_empty() and g.phase in ["planning","review","ended"]: break
				if g.animation.get("kind","") == "gem_trigger": triggered = true
				check(G.S.step(g) == "","dead gem flow advances")
			check(not triggered and not str(g.log_lines).contains("手牌中的"),"dead gem produces no effect animation or trigger log")
			check(g.characters[0].hp == 0 and g.characters[0].hand == [gem] and _conserved(g),"dead gems neither draw nor heal nor consume")
			g._revive(0,2)
			g._begin_round();check(G.drain(g),"revived pawn reaches planning")
			if key == "ruby": H.begin(g,{});check(G.drain(g),"revived ruby resolution completes")
			check(g.characters[0].hand.size() == (3 if key == "sapphire" else 2),"revived sapphire resumes extra draw")
			check(g.characters[0].hp == (3 if key == "ruby" else 2),"revived ruby resumes healing")
	# Earlier round-start damage can kill a holder after gem jobs were scheduled.
	var g = H.fixture(8)
	g.characters[0].hp = 1;H.give(g,0,"sapphire");curse(g,0)
	g._begin_round()
	check(g.characters[0].hp == 0 and g.characters[0].hand.size() == 2,"queued sapphire rechecks life after lethal wither")

func _defense_owners() -> void:
	var g = H.fixture(8)
	var strike: int = H.give(g,4,"final_strike")
	g.final_strike_damage[strike] = 4
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike"),4:strike})
	g.characters[0].hp = 0;g.target(1,0)
	check(g.phase != "reacting" and g.characters[0].shield == 1,"dead defense owner cannot respond; unspent shield retained")
	g._revive(0,4);g.target(1,0)
	check(g.phase == "reacting" and g.pending_attack.owner == 0,"revival restores unspent defense within the round")
	g.defend(0,true)
	check(g.characters[0].hp == 4,"restored defense cancels the later attack")
	check(G.drain(g),"dead defense resolution completes")
	g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"defense"),1:H.give(g,1,"defense"),3:H.give(g,3,"double_strike"),4:H.give(g,4,"magic_strike")},false)
	while g.phase == "targeting" and g._info(g.input_action).key == "defense": g.target(0,2)
	g.characters[0].hp = 0;g.target(1,2)
	check(g.phase == "reacting" and g.pending_attack.owner == 1,"defense skips dead caster and preserves living caster option")
	g.defend(0,true)
	check(g.characters[2].hp == 8 and g.characters[2].shield_sources == [0],"only living caster's shield was consumed")
	# A living caster may still protect a dead target: the caster owns this trigger.
	g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike")},false)
	g.target(0,1);g.characters[1].hp = 0;g.target(1,1)
	check(g.phase == "reacting" and g.pending_attack.owner == 0,"living defense caster can protect a corpse")
	g.defend(0,true);check(G.drain(g),"living defense response completes")

func _death_exceptions() -> void:
	for presented in [false,true]:
		var g = H.fixture(8);g.presentation_enabled = presented
		var gem: int = H.give(g,0,"amethyst")
		g.characters[0].hp = 0;g.characters[0].death_round = g.round_number
		H.begin(g,{});check(G.drain(g),"amethyst exception completes")
		check(g.characters[0].hp == 1 and g.discard.has(gem),"amethyst still revives dead holder and discards")
	var g = H.fixture()
	g.characters[0].hp = 1
	H.begin(g,{0:H.give(g,0,"mirror"),3:H.give(g,3,"judgment"),4:H.give(g,4,"strike")})
	g.choose(0,H.action_for(g,4).id);g.target(1,0)
	check(g.characters[0].hp == 0 and not H.action_for(g,0,true).is_empty(),"mirror still copies after owner's death")
	g.target(1,1);g.target(0,3)
	check(g.characters[3].hp == 4 and _conserved(g),"dead owner's mirror copy still resolves")
	g = H.fixture(8)
	H.give_death(g,0,"sacrifice_badges")
	g.characters[0].hp = 0;g.characters[0].death_round = g.round_number
	H.begin(g,{});check(G.drain(g) and g.badges[0] > 0,"deathrattle still triggers normally")
