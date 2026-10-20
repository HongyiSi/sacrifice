extends "res://tests/v018_test.gd"
const G = preload("res://tests/gem_scenarios.gd")

func _initialize() -> void:
	for presented in [false,true]:
		for holder in [0,3]:
			var g = H.fixture(8);g.presentation_enabled = presented;g.characters[holder].hp = 2
			var card: int = H.give(g,holder,"spare_supplies")
			check(g.catalog[card].text == "这张牌被弃置时，这个棋子摸3张牌。\n不能被打出。","description matches revised design, including newline")
			check(not g._can_play_hand_card(g.characters[holder],card),"supplies remain unplayable")
			g._discard_hand_card(g.characters[holder],card);g._pump()
			check(G.drain(g),"discard-triggered draw finishes with and without presentation")
			check(g.characters[holder].hand.size() == 3 and g.characters[holder].hp == 2,"discard draws three instead of healing")
			check(g.discard.count(card) == 1 and _conserved(g),"card is discarded once and deck remains conserved")
		var g = H.fixture(8);g.presentation_enabled = presented
		var card: int = H.give(g,0,"spare_supplies")
		for _i in range(7): H.give(g,0,"strike")
		var before: int = g.deck.size()
		g._discard_hand_card(g.characters[0],card);g._pump()
		check(G.drain(g) and g.characters[0].hand.size() == 8,"drawing three fills only the single free slot")
		check(g.deck.size() == before-1 and _conserved(g),"two excess draws remain in draw pile")
		g = H.fixture(8);g.presentation_enabled = presented
		var cards: Array = [H.give(g,0,"spare_supplies"),H.give(g,0,"spare_supplies")]
		g._discard_hand(g.characters[0]);g._pump()
		check(G.drain(g) and g.characters[0].hand.size() == 6,"two supplies in one discard batch draw six once")
		check(cards.all(func(id):return g.discard.count(id) == 1) and _conserved(g),"newly drawn cards are not discarded by the old batch")
	_restrictions()
	_divinity_draw()
	print("SPARE_SUPPLIES_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _restrictions() -> void:
	var g = H.fixture(8);var card: int = H.give(g,0,"spare_supplies")
	g.characters[0].hp = 0;g._discard_hand_card(g.characters[0],card);g._pump()
	check(g.characters[0].hand.is_empty() and g.discard.has(card),"dead holder discards without drawing")
	g = H.fixture(8);card = H.give(g,0,"spare_supplies");g.defiled_cards[card] = true
	g._discard_hand_card(g.characters[0],card);g._pump()
	check(g.characters[0].hand == [card] and not g.discard.has(card),"defiled supplies cannot discard or trigger")
	g = H.fixture(8);card = H.give(g,0,"spare_supplies");activate(g,1,"blessing",0)
	g._discard_hand_card(g.characters[0],card);g._pump()
	check(g.characters[0].hand.size() == 3,"blessing does not block supplies drawing")
	for has_playable in [false,true]:
		g = H.fixture(8);card = H.give(g,0,"spare_supplies");activate(g,1,"prison",0)
		if has_playable: H.give(g,0,"strike")
		g._discard_hand_card(g.characters[0],card);g._pump()
		check(g.characters[0].hand.size() == (1 if has_playable else 3),"prison checks playable cards remaining after discard")

func _divinity_draw() -> void:
	for count in [1,7,8]:
		var g = H.fixture(8);var card: int = H.give(g,0,"spare_supplies")
		for _i in range(count-1): H.give(g,0,"strike")
		g.characters[3].hp = 0;activate(g,3,"divinity")
		g.presentation_enabled = true
		# The isolated discard needs the caller's continuation after its draw.
		g._push([{"op":"planning"}])
		g._discard_hand_card(g.characters[0],card);g._pump()
		for _i in range(20):
			if g.animation.is_empty(): break
			g.advance_animation()
		check(g.request.get("type","") == "deck" and g.request.get("team",-1) == 1,"divinity owner selects supplies draw")
		var expected: int = mini(3,9-count)
		check(g.request.get("count",0) == expected,"divinity only requests available hand slots, up to three")
		check(g.snapshot(0).input.options.is_empty(),"divinity card choices remain private to chooser")
		var selected: Array = g.request.options.slice(0,expected)
		check(g.pick(1,selected) == "" and G.drain(g),"selected supplies cards arrive normally")
		check(g.characters[0].hand.size() == count-1+expected and selected.all(func(id):return g.characters[0].hand.has(id)) and _conserved(g),"divinity grants only selected cards with no overflow")
