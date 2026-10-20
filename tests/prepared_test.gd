extends "res://tests/choice_ui_rules_test.gd"

func _initialize() -> void:
	var g=H.fixture(8)
	var cards: Array=g.catalog.values().filter(func(c):return c.key=="prepared")
	check(cards.size()==4 and cards.map(func(c):return c.secondary)==[16,17,18,19],"four prepared cards have the designed ranks")
	check(cards.all(func(c):return c.main==6 and c.type=="技能" and c.text=="摸两张牌。弃置两张牌。"),"prepared data matches design")
	check(g.normal_type_count==60 and g.catalog.size()==128,"deck contains 60 types and 128 physical cards")
	for team in [0,1]:
		var owner: int=team*3
		for presented in [false,true]:
			g=H.fixture(8);g.presentation_enabled=presented
			var card: int=H.give(g,owner,"prepared")
			var old: int=H.give(g,owner,"strike")
			H.give(g,owner,"heal")
			var pile: int=g.deck.size()
			H.begin(g,{owner:card});finish_animation(g)
			check(g.phase=="selecting" and g.request.type=="discard" and g.request.count==2,"draw is followed by mandatory two-card selection")
			check(g.characters[owner].hand.size()==4 and g.deck.size()==pile-2,"both new cards arrive before selecting discards")
			check(g.snapshot(1-team).input.options.is_empty() and g.snapshot(team).input.options.size()==4,"opponent cannot inspect private discard choices")
			check(g.skip_effect(team)!="" and g.end_round_early(team)!="","cannot skip the discard after drawing")
			var values: Array=g.request.options.duplicate()
			check(act(g,team,"pick",[old])!="" and act(g,team,"pick",[old,old])!="" and act(g,team,"pick",[old,card])!="","wrong count, duplicates and played card rejected")
			check(act(g,1-team,"pick",values.slice(0,2))!="","opponent cannot choose owner's discards")
			# Deliberately mix an old hand card and one of the newly drawn cards.
			var drawn: int=values[2]
			check(act(g,team,"pick",[old,drawn])=="" and G.drain(g),"old and freshly drawn cards can be discarded together")
			check(g.characters[owner].hand.size()==2 and g.discard.has(old) and g.discard.has(drawn) and g.discard.has(card),"two selected cards and the played card reach discard")
			check(_conserved(g),"all physical cards conserved after complete resolution")
		# Playing from a full hand leaves only one slot for the two draws.
		g=H.fixture(8)
		var card: int=H.give(g,owner,"prepared")
		for _i in range(7):H.give(g,owner,"strike")
		var pile: int=g.deck.size()
		H.begin(g,{owner:card})
		check(g.characters[owner].hand.size()==8 and g.deck.size()==pile-1,"overflow draw returns to deck before discard")
		check(g.pick(team,g.request.options.slice(0,2))=="" and G.drain(g) and g.characters[owner].hand.size()==6,"still discards two after only one accepted draw")
		# Discard passives trigger only after both cards leave the hand.
		g=H.fixture(8);g.characters[owner].hp=4
		card=H.give(g,owner,"prepared")
		var food: int=H.give(g,owner,"spare_food")
		var supplies: int=H.give(g,owner,"spare_supplies")
		H.begin(g,{owner:card})
		check(g.pick(team,[food,supplies])=="" and G.drain(g),"food and supplies discard passives resolve")
		check(g.characters[owner].hp==6 and g.characters[owner].hand.size()==5 and _conserved(g),"discard heals two and draws three without a second forced discard")
		# Prison can cancel drawing, but does not cancel the separate discard.
		for count in [0,1,2]:
			g=H.fixture(8);activate(g,owner,"prison",owner)
			card=H.give(g,owner,"prepared")
			var poison: int=g._generate_card(g.POISON);g.characters[owner].hand.append(poison)
			var stone: int=g._generate_card(g.BOULDER);g.characters[owner].hand.append(stone)
			var sealed: int=H.give(g,owner,"strike");g.defiled_cards[sealed]=true
			for _i in range(count):H.give(g,owner,"heal")
			pile=g.deck.size();H.begin(g,{owner:card})
			check(g.deck.size()==pile,"prison prevents prepared's draw")
			if count>0:
				check(g.request.count==count and g.request.options.size()==count,"if fewer than two eligible cards remain, discard as many as possible")
				check(g.pick(team,[poison] if count==1 else [poison,stone])!="","protected curses cannot be selected")
				check(g.pick(team,g.request.options.duplicate())=="","all available unprotected cards discarded")
			check(G.drain(g) and g.characters[owner].hand==[poison,stone,sealed],"undiscardable and defiled cards remain without stalling")
		# Godhood chooses the draws before returning control to the caster.
		g=H.fixture(8);g.characters[(1-team)*3].hp=0
		activate(g,(1-team)*3,"divinity")
		card=H.give(g,owner,"prepared")
		H.begin(g,{owner:card})
		check(g.request.type=="deck" and g.request.team==1-team and g.request.count==2,"godhood owner chooses the two draws")
		var picks: Array=g.request.options.filter(func(id):return g.catalog[id].key=="strike").slice(0,2)
		check(g.pick(1-team,picks)=="" and g.request.type=="discard" and g.request.team==team,"caster chooses discards after godhood completes")
		check(g.pick(team,picks)=="" and G.drain(g) and _conserved(g),"godhood sequence finishes without lost cards")
	# Mirror copies the complete effect, including mandatory discards.
	g=H.fixture(8)
	H.begin(g,{0:H.give(g,0,"prepared"),3:H.give(g,3,"mirror")})
	check(g.choose(1,H.action_for(g,0).id)=="" and g.request.team==0,"mirror first allows original to resolve")
	check(g.pick(0,g.request.options.slice(0,2))=="" and g.request.type=="discard" and g.request.team==1,"mirror copy draws and requires its own discards")
	check(g.pick(1,g.request.options.slice(0,2))=="" and G.drain(g) and _conserved(g),"original and copy preserve physical cards")
	# An empty library cannot strand the discard step.
	g=H.fixture(8)
	var prepared: int=H.give(g,0,"prepared")
	g.deck.clear();H.begin(g,{0:prepared})
	check(g.phase=="review" and g.request.is_empty(),"empty deck and no eligible hand safely completes")
	print("PREPARED_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
