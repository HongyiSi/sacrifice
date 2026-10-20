extends "res://tests/v018_test.gd"

func _initialize() -> void:
	_catalog()
	_draw_cards()
	_gems()
	_restrictions()
	_rally_and_strike()
	print("V019_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func top(g, keys: Array) -> Array:
	var ids: Array = []
	for key in keys:
		var id: int = H.give(g,5,key)
		g.characters[5].hand.erase(id)
		ids.append(id)
	for id in ids: g.deck.append(id)
	return ids

func _draw_cards() -> void:
	var g = H.fixture(8)
	g.characters[0].hp = 1
	H.begin(g,{0:H.give(g,0,"bloodletting")})
	check(g.characters[0].hp == 0 and g.characters[0].hand.size() == 5,"bloodletting still draws after lethal HP loss")
	g = H.fixture(8)
	activate(g,0,"blessing")
	H.begin(g,{0:H.give(g,0,"bloodletting")})
	check(g.characters[0].hp == 7 and g.characters[0].hand.size() == 5,"HP loss bypasses blessing")
	g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"bloodletting"),1:H.give(g,1,"magic_amulet")})
	drain(g)
	check(g.characters[0].hp == 7,"amulet protecting another pawn does not cancel self draw")
	g = H.fixture(8)
	var blood: int = H.give(g,0,"bloodletting")
	var guard: int = H.give(g,0,"magic_amulet")
	H.begin(g,{0:blood})
	check(g.phase == "review","amulet never responds to own self-targeted skill")
	check(g.characters[0].hp == 7 and g.characters[0].hand.has(guard),"own HP loss and draw proceed, amulet remains in hand")
	for divine in [false,true]:
		g = H.fixture(8)
		var previous: Array = []
		for key in ["strike","heal","mirror","heal_other","warcry"]: previous.append(H.give(g,0,key))
		var drawn: Array = top(g,["strike","defense","badge","magic_strike","final_strike"])
		if divine:
			g.characters[3].hp = 0
			activate(g,3,"divinity")
		H.begin(g,{0:H.give(g,0,"gold_panning")})
		if divine:
			check(g.request.type == "deck" and g.request.team == 1,"gold panning allows divinity replacement")
			check(g.pick(1,drawn.slice(0,g.request.count)) == "","divinity selects only available hand slots")
		check(g.phase == "review" and g.characters[0].hand.size() == (6 if divine else 8),"gold admits only available slots then filters accepted cards")
		check(previous.all(func(id):return g.characters[0].hand.has(id)),"gold never discards pre-existing matching cards")
		check((g.discard.has(drawn[0]) and g.discard.has(drawn[1])) if divine else (g.deck.has(drawn[0]) and g.deck.has(drawn[1])),"gold filters matching accepted cards but returns rejected draws")
	g = H.fixture(8);activate(g,0,"privilege")
	top(g,["strike","defense","heal","double_strike","triple_strike"])
	H.begin(g,{0:H.give(g,0,"gold_panning")})
	check(g.characters[0].hand.size() == 5,"gold uses actual priorities including privilege")
	g = H.fixture(8)
	var rock: int = g._generate_card(g.BOULDER)
	g.characters[0].hand.append(rock);curse(g,0)
	H.begin(g,{0:H.give(g,0,"gambler")})
	check(g.characters[0].hand.size() == 8 and g.characters[0].hand.has(rock) and g.characters[0].hand.has(104),"gambler fills to cap including locked slots")
	g = H.fixture(8)
	activate(g,1,"prison",0);activate(g,3,"divinity");g.characters[3].hp = 0
	H.give(g,0,"heal")
	H.begin(g,{0:H.give(g,0,"search")})
	check(g.request.type == "search" and g.request.team == 0,"search is a gain, unaffected by prison and divinity")
	var chosen: int = g.request.options[-1]
	check(g.snapshot(1).input.options.is_empty(),"search pile selection stays private")
	check(g.pick(1,[chosen]) != "" and g.pick(0,[]) != "","search rejects wrong controller and wrong count")
	g.pick(0,[chosen])
	check(g.characters[0].hand.has(chosen) and not g.deck.has(chosen),"search transfers chosen physical card")
	g = H.fixture(8)
	var search: int = H.give(g,0,"search")
	g.discard = g.deck.duplicate();g.deck.clear()
	H.begin(g,{0:search})
	check(g.phase == "review" and g.characters[0].hand.is_empty(),"search does not refill empty pile")

func _gems() -> void:
	for key in ["sapphire","ruby","amethyst"]:
		var g = H.fixture(8)
		var gem: int = H.give(g,0,key)
		H.begin(g,{0:gem})
		check(g.request.options == [0,1,2,3,4,5],key+" can be given to any pawn")
		g.target(0,3)
		check(g.characters[3].hand == [gem] and not g.discard.has(gem),key+" physical card remains in recipient hand")
		check(_conserved(g),key+" transfer keeps each physical ID exactly once")
	var g = H.fixture(8)
	var gem: int = H.give(g,0,"sapphire")
	var virtual: Dictionary = g._add_action(0,gem,true)
	g._transfer_gem(virtual,1)
	check(g.characters[0].hand == [gem] and g.characters[1].hand.size() == 1 and g.characters[1].hand[0] != gem,"mirror gem creates independent hand instance")
	check(g.catalog[g.characters[1].hand[0]].key == "sapphire","generated gem preserves its passive")
	for count in [4,5,6,7,8]:
		g = H.fixture(8);H.give(g,0,"sapphire")
		for _i in range(count-1): H.give(g,0,"strike")
		g._begin_round()
		check(g.characters[0].hand.size() == mini(8,count+(2 if count<=6 else 1)),"sapphire threshold uses hand before routine draw at %d" % count)
	g = H.fixture(8);H.give(g,0,"sapphire");preload("res://tests/gem_scenarios.gd").give_copy(g,0,"sapphire")
	g.characters[0].hp = 0;g._begin_round()
	check(g.characters[0].hand.size() == 2,"dead holder cannot trigger sapphire copies")
	g = H.fixture(8);H.give(g,0,"sapphire");activate(g,1,"prison",0);g._begin_round()
	check(g.characters[0].hand.size() == 1,"prison blocks sapphire extra draw")
	g = H.fixture(8);g.characters[0].hp = 3
	H.give(g,0,"ruby");preload("res://tests/gem_scenarios.gd").give_copy(g,0,"ruby");H.begin(g,{})
	check(g.characters[0].hp == 7,"unplayed ruby copies heal at resolution start")
	g = H.fixture(8);g.characters[0].hp = 3;H.give(g,0,"ruby")
	H.begin(g,{0:H.give(g,0,"warcry")})
	check(g.characters[0].hp == 3,"ruby does not heal a pawn that played")
	g = H.fixture(8);g.characters[0].hp = 3;H.give(g,0,"ruby");activate(g,1,"blessing",0);H.begin(g,{})
	check(g.characters[0].hp == 3,"blessing still blocks passive ruby healing")
	g = H.fixture(8);gem = H.give(g,0,"amethyst");preload("res://tests/gem_scenarios.gd").give_copy(g,0,"amethyst")
	H.give_death(g,0,"sacrifice_badges");g.characters[0].hp = 0;g.characters[0].death_round = g.round_number
	H.begin(g,{})
	check(g.characters[0].hp == 1 and g.discard.has(gem) and g.characters[0].hand.size() == 1,"one amethyst revives and is consumed")
	check(g.badges[0] == 0 and g.characters[0].deathrattles.size() == 1,"amethyst revives before deathrattle queue is built")
	g = H.fixture(8);gem = H.give(g,0,"amethyst");g.characters[0].hp = 0
	H.begin(g,{1:H.give(g,1,"skip_death")})
	check(g.characters[0].hp == 0 and g.characters[0].hand.has(gem),"skipped death stage does not trigger amethyst")
	g = H.fixture(8);gem = H.give(g,0,"amethyst");g.characters[0].hp = 0;g.defiled_cards[gem] = true
	H.begin(g,{})
	check(g.characters[0].hp == 1 and g.characters[0].hand.has(gem),"defile stops discard but does not silence amethyst passive")

func _restrictions() -> void:
	var g = H.fixture(8)
	var chosen: int = H.give(g,3,"strike")
	H.give(g,3,"heal")
	H.begin(g,{0:H.give(g,0,"defile")});g.target(0,3)
	check(g.request.type == "defile" and g.request.options.size() == 2,"defile shows complete target hand")
	check(g.snapshot(1).input.options.is_empty(),"private target picker is redacted for other player")
	check(g.pick(0,[99999]) != "","defile rejects invented IDs")
	g.pick(0,[chosen])
	check(not g.snapshot(1).catalog[chosen].playable and g.snapshot(1).catalog[chosen].defiled,"target owner sees lasting hand restriction")
	check(not g.snapshot(0).catalog[chosen].get("defiled",false),"hidden catalogue does not reveal restricted hand IDs")
	check(not g._can_discard_hand_card(g.characters[3],chosen),"defiled ordinary card cannot be discarded")
	g.characters[3].hand.erase(chosen);g.characters[0].hand.append(chosen)
	g.phase = "planning";g.plans = [null,null]
	check(g.submit(0,[chosen,0,0]) != "","host rejects playing transferred defiled card")
	g._discard_hand(g.characters[0]);check(g.characters[0].hand.has(chosen),"mass discard preserves defiled cards")
	var rock: int = g._generate_card(g.BOULDER);g.characters[0].hand.append(rock);curse(g,0)
	var legal: int = H.give(g,0,"heal")
	g.queue.clear();g._play_revealed_hand(0,[chosen,rock,104,legal],"疯狂")
	check(g.queue.size() == 1 and g.queue[0].card == legal and g.characters[0].hand.size() == 3,"forced plays preserve all unplayable cards")
	g = H.fixture(8)
	for _i in range(8): H.give(g,3,"strike")
	H.begin(g,{0:H.give(g,0,"obstruct")});g.target(0,3)
	check(g.request.is_empty() and g.phase == "review","full-hand obstruction does not request a discard")
	check(g.characters[3].hand.all(func(id):return g.catalog[id].key != "boulder"),"existing full hand remains unchanged")
	check(g.discard.filter(func(id):return g.catalog[id].key == "boulder").size() == 2,"both rejected boulders enter discard")
	check(g.characters[3].hand.size() == 8 and _conserved(g),"obstruction conserves generated cards within hand limit")
	g = H.fixture(8)
	for _i in range(10): g.characters[0].hand.append(g._generate_card(g.BOULDER))
	g._queue_hand_limit(0);g._pump()
	check(g.request.is_empty() and g.characters[0].hand.size() == 10,"fully locked overflow cannot deadlock")
	H.give(g,0,"strike");g._queue_hand_limit(0);g._pump()
	check(g.request.count == 1,"partly discardable overflow requests only possible discards")
	g.pick(0,g.request.options.duplicate())
	check(g.characters[0].hand.size() == 10 and g.request.is_empty(),"all locked overflow remains after legal discard")
	g.start(45)
	check(g.catalog.size() == 128 and g.defiled_cards.is_empty(),"new match clears generated cards and restrictions")

func _rally_and_strike() -> void:
	var g = H.fixture(8)
	g.characters[2].hp = 0
	H.begin(g,{0:H.give(g,0,"rally"),1:H.give(g,1,"overload")})
	g.advance_round()
	check(g.play_limit(g.characters[0]) == 2 and g.play_limit(g.characters[1]) == 4 and g.play_limit(g.characters[2]) == 1,"rally stacks with overload and excludes dead recipients")
	check(g.snapshot(0).characters[0].ongoing_effects.any(func(e):return e.key == "rally" and not e.waiting),"rally appears as current turn status")
	g.characters[0].silenced_round = g.round_number
	check(g.play_limit(g.characters[0]) == 0,"silence still overrides bonus plays")
	for protected in [false,true]:
		g = H.fixture(8)
		if protected: activate(g,3,"blessing")
		g.characters[0].warcry_round = g.round_number;g.characters[0].warcry_bonus = 3
		H.begin(g,{0:H.give(g,0,"final_strike")});g.target(0,3)
		check(g.characters[3].hp == (8 if protected else 5),"new final strike has zero base damage and respects buffs/protection")
