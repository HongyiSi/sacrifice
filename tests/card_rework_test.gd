extends "res://tests/v018_test.gd"
const G = preload("res://tests/gem_scenarios.gd")

func _initialize() -> void:
	_catalog()
	_growth()
	_strike_damage()
	_card_privacy()
	_discard_cards()
	_overflow_and_transfer()
	_suppression_priority()
	print("CARD_REWORK_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _growth() -> void:
	for presented in [false,true]:
		for holder in [0,3]:
			var g = H.fixture(8);g.presentation_enabled = presented
			var card: int = H.give(g,holder,"final_strike")
			for value in range(1,4):
				H.begin(g,{})
				check(G.drain(g),"held strike round completes")
				check(g.final_strike_damage.get(card,0) == value,"held strike grows once per resolution start")
				check(g.snapshot(holder/3).catalog[card].damage == value,"owner sees accumulated damage")
				if value < 3: g._begin_round();check(G.drain(g),"next planning starts")
			g._discard_hand_card(g.characters[holder],card)
			g.discard.erase(card);g._put_in_hand((holder+1)%6,card)
			check(g.final_strike_damage[card] == 3,"discard and transfer preserve physical growth")
			g.start(42)
			check(g.final_strike_damage.is_empty(),"rematch clears old growth")
	var g = H.fixture(8);var card: int = H.give(g,0,"final_strike")
	g.characters[0].hp = 0;H.begin(g,{})
	check(not g.final_strike_damage.has(card),"dead holder cannot charge strike")
	g._revive(0,3);g._begin_round();g.defiled_cards[card] = true;H.begin(g,{})
	check(g.final_strike_damage[card] == 1,"revival restores growth and defile does not block hand passive")
	g = H.fixture(8);card = H.give(g,0,"final_strike")
	check(g.submit(0,[0,0,0]) == "" and g.final_strike_damage.is_empty(),"one confirmation does not grow strike")
	check(g.unlock(0) == "" and g.final_strike_damage.is_empty(),"cancel confirmation does not grow strike")
	H.begin(g,{0:card});g.target(0,3)
	check(g.characters[3].hp == 8 and not g.final_strike_damage.has(card),"newly played strike leaves hand before growth and deals zero")

func _strike_damage() -> void:
	for presented in [false,true]:
		for stored in [0,1,4]:
			var g = H.fixture(8);g.presentation_enabled = presented
			var card: int = H.give(g,0,"final_strike");g.final_strike_damage[card] = stored
			H.begin(g,{0:card});check(g.target(0,3) == "","charged strike accepts target")
			check(G.drain(g) and g.characters[3].hp == 8-stored,"strike deals stored damage exactly once")
			check(g.discard.count(card) == 1 and _conserved(g),"played strike enters discard exactly once")
	var g = H.fixture(8);var card: int = H.give(g,0,"final_strike")
	g.characters[0].warcry_round = g.round_number;g.characters[0].warcry_bonus = 3
	H.begin(g,{0:card});g.target(0,3)
	check(g.characters[3].hp == 5,"warcry adds to zero-base strike")
	g = H.fixture(8);card = H.give(g,0,"final_strike");g.final_strike_damage[card] = 3
	H.begin(g,{0:card,3:H.give(g,3,"mirror")});g.choose(1,H.action_for(g,0).id)
	g.target(0,3);g.target(1,0)
	check(g.characters[3].hp == 5 and g.characters[0].hp == 8,"mirror copy starts at printed zero damage")
	check(H.action_for(g,3,true).damage == 0,"copied strike does not reuse original growth")
	g = H.fixture(8);activate(g,1,"pain");g.characters[1].hp = 0
	H.begin(g,{0:H.give(g,0,"final_strike")});g.target(0,1)
	check(g.phase == "review" and g.characters[0].hand.is_empty(),"zero damage does not trigger pain")

func _card_privacy() -> void:
	var g = H.fixture(8);var card: int = H.give(g,0,"final_strike")
	g.final_strike_damage[card] = 4
	check(g.snapshot(0).catalog[card].text.contains("造成4点伤害"),"held card description shows current damage")
	check(not g.snapshot(1).catalog[card].has("damage") and g.snapshot(1).catalog[card].text.contains("造成0点伤害"),"opponent catalog does not reveal hidden growth")
	var copy: Dictionary = g._add_action(3,card,true,"ghost")
	check(g._info(copy).damage == 0 and not g.snapshot(1).catalog[card].has("damage"),"public ghost copy does not expose a different physical holder's growth")
	g.queue.clear()
	g.presentation_enabled = true;g.resolution_presentation_enabled = true;g.stage_presentation_enabled = true
	H.begin(g,{0:card})
	check(g.snapshot(0).queue[0].damage == 4,"owner sees damage before reveal")
	check(g.snapshot(1).queue[0].card == 0 and not g.snapshot(1).queue[0].has("damage"),"enemy hidden action omits damage")
	check(G.drain(g) and g.characters.filter(func(c):return c.hp == 4).size() == 1,"charged strike resolves through staged animations")
	check(g.snapshot(1).catalog[card].damage == 4,"revealed physical strike exposes its actual damage")
	g = H.fixture(8);card = H.give(g,3,"final_strike");g.final_strike_damage[card] = 2
	H.begin(g,{0:H.give(g,0,"peek")});g.target(0,3)
	check(g.snapshot(0).catalog[card].damage == 3,"peek shows charged card's current state after resolution growth")

func _discard_cards() -> void:
	for key in ["spare_food","spare_supplies"]:
		for presented in [false,true]:
			var g = H.fixture(8);g.presentation_enabled = presented;g.characters[0].hp = 2
			var card: int = H.give(g,0,key)
			check(not g._can_play_hand_card(g.characters[0],card) and g._can_discard_hand_card(g.characters[0],card),"spare card cannot play but can discard")
			check(g.submit(0,[card,0,0]) != "","server rejects direct play of spare card")
			H.begin(g,{0:H.give(g,0,"cards_to_heart")});check(G.drain(g),"discard plus conversion completes")
			var healing: bool = g.catalog[card].discard_effect == "heal"
			check(g.characters[0].hp == (5 if healing else 3),"discard passive and conversion each resolve once")
			check(g.characters[0].hand.size() == (0 if healing else 3) and g.discard.has(card),"newly drawn supplies are not part of conversion batch")
			check(_conserved(g),"conversion with spare conserves physical cards")
		var g = H.fixture(8);g.characters[0].hp = 2
		var card: int = H.give(g,0,key);g.defiled_cards[card] = true
		H.begin(g,{0:H.give(g,0,"cards_to_heart")})
		check(g.characters[0].hp == 2 and g.characters[0].hand.has(card),"defiled spare cannot discard or trigger")
		g = H.fixture(8);card = H.give(g,0,key);g.characters[0].hp = 0
		g._discard_hand_card(g.characters[0],card);g._pump()
		check(g.characters[0].hp == 0 and g.characters[0].hand.is_empty(),"dead pawn discards spare without triggering")
		g = H.fixture(8);card = H.give(g,0,key);activate(g,1,"prison",0)
		check(not g._draw_blocked(g.characters[0]),"unplayable spare alone does not activate prison")
		H.begin(g,{0:H.give(g,0,"frenzy")})
		check(g.characters[0].hand == [card],"frenzy keeps unplayable spare")
	# Both cards in one discard batch should trigger once, with no new-card recursion.
	var g = H.fixture(8);g.characters[0].hp = 1
	var cards: Array = [H.give(g,0,"spare_food"),H.give(g,0,"spare_supplies")]
	H.begin(g,{0:H.give(g,0,"gambler")});check(G.drain(g),"gambler discard batch finishes")
	check(g.characters[0].hand.size() == 8 and cards.all(func(id):return g.discard.has(id)) and _conserved(g),"gambler fills after discard triggers and preserves cap")

func _overflow_and_transfer() -> void:
	for key in ["spare_food","spare_supplies"]:
		var g = H.fixture(8);g.characters[0].hp = 2;g.characters[1].hp = 3
		var card: int = H.give(g,0,key);var other: int = H.give(g,0,"strike")
		for _i in range(8): H.give(g,1,"strike")
		H.begin(g,{0:H.give(g,0,"gift")});g.target(0,1);g.pick(0,[card,other])
		check(G.drain(g) and g.characters[0].hp == 2 and g.characters[1].hp == 3,"gift overflow does not trigger either pawn's spare passive")
		check(g.characters[0].hand.is_empty() and g.characters[1].hand.size() == 8 and g.discard.has(card),"overflow card discarded without triggering draws")
		g = H.fixture(8);g.characters[0].hp = 2;g.characters[1].hp = 3
		card = H.give(g,0,key);other = H.give(g,0,"strike")
		H.begin(g,{0:H.give(g,0,"gift")});g.target(0,1);g.pick(0,[card,other])
		check(g.characters[0].hp == 2 and g.characters[1].hp == 3 and g.characters[1].hand.has(card),"successful transfer does not count as discard")
		g._discard_hand_card(g.characters[1],card);g._pump()
		check(G.drain(g),"new holder can trigger discarded spare")
		check(g.characters[1].hp == (5 if g.catalog[card].discard_effect == "heal" else 3),"discard effect belongs to new holder")

func _suppression_priority() -> void:
	var g = H.fixture(8)
	var suppress: int = H.give(g,0,"suppress")
	check(g.catalog[suppress].main == 9 and g.catalog[suppress].secondary in [9,10],"early suppression uses unique main-nine priorities")
	H.begin(g,{0:suppress,3:H.give(g,3,"collect")})
	check(g.phase == "choosing" and g._info(g.input_action).key == "suppress","main-nine suppression resolves before main-eight collection")
	g.choose(0,H.action_for(g,3).id)
	check(g.characters[3].hand.is_empty(),"suppressed collection never draws")
