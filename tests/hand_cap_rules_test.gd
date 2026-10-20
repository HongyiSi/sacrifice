extends "res://tests/v018_test.gd"

func fill(g, actor: int, count: int) -> Array:
	var ids: Array = []
	for _i in range(count): ids.append(H.give(g,actor,"strike"))
	return ids

func settle(g) -> void:
	for _i in range(150):
		check(g.characters.all(func(c): return c.hand.size() <= 8),"every intermediate state respects the hand cap")
		if g.animation.is_empty(): return
		g.advance_animation()
	check(false,"animation terminates")

func _initialize() -> void:
	for animated in [false,true]:
		for count in [6,7,8]:
			for target in [0,1,3]:
				for key in ["obstruct","poisoning"]:
					var g=H.fixture(8);g.presentation_enabled=animated
					var card:int=H.give(g,0,key)
					H.begin(g,{0:card});settle(g)
					var old:Array=fill(g,target,count)
					check(g.target(0,target)=="","placement target accepts full hands")
					settle(g)
					var n:int=2 if key=="obstruct" else 1
					check(g.characters[target].hand.size()==mini(count+n,8),"generated placement fills only free slots")
					check(old.all(func(id):return g.characters[target].hand.has(id)),"incoming overflow never evicts existing cards")
					check(g.discard.filter(func(id):return g.catalog[id].get("generated",false)).size()==maxi(0,count+n-8),"rejected tokens go to discard")
					check(g.phase=="review" and _conserved(g),"generated placement finishes and conserves every entity")
			# Gift order is chosen by the player, including unplayable cards.
			for reverse in [false,true]:
				var g=H.fixture(8);g.presentation_enabled=animated
				var first:int=H.give(g,0,"heal")
				var second:int=g._generate_card(g.BOULDER);g.characters[0].hand.append(second)
				g.defiled_cards[first]=true
				var old:Array=fill(g,3,count)
				H.begin(g,{0:H.give(g,0,"gift")});settle(g);g.target(0,3)
				var order:Array=[second,first] if reverse else [first,second]
				check(g.pick(0,order)=="","gift accepts restricted cards in chosen order")
				settle(g)
				check(g.characters[3].hand==old+order.slice(0,8-count),"gift retains only the earliest fitting cards")
				check(order.slice(8-count).all(func(id):return g.discard.has(id)),"gift discards even restricted overflow")
				check(g.characters[0].hand.is_empty() and _conserved(g),"gift transfers or discards each entity once")
		for key in H.Rules.GEMS+H.Rules.AMULETS:
			for count in [7,8]:
				var g=H.fixture(8);g.presentation_enabled=animated
				var card:int=H.give(g,0,key);fill(g,3,count)
				H.begin(g,{0:card});settle(g);g.target(0,3);settle(g)
				check(g.characters[3].hand.has(card)==(count==7),key+" transfers only when a slot exists")
				check(g.discard.has(card)==(count==8) and _conserved(g),key+" overflow goes to discard exactly once")
		# A copied physical gem gets a distinct entity; its overflow is discarded.
		var g=H.fixture(8);g.presentation_enabled=animated
		var gem:int=H.give(g,0,"ruby");fill(g,1,8)
		g._transfer_gem(g._add_action(0,gem,true),1)
		check(g.characters[0].hand.has(gem) and g.characters[1].hand.size()==8,"copied gem preserves original card")
		check(g.discard.size()==1 and g.discard[0]!=gem and _conserved(g),"copied overflow has one generated discarded entity")
	for count in [7,8]:
		for key in ["search","plunder"]:
			var g=H.fixture(8)
			var stolen:int=H.give(g,3,"heal")
			H.begin(g,{0:H.give(g,0,key)})
			fill(g,0,count)
			if key=="plunder":g.target(0,3)
			var id:int=stolen if key=="plunder" else g.request.options[0]
			check(g.pick(0,[id])=="","private pickup accepts a full receiver")
			check(g.characters[0].hand.has(id)==(count==7) and g.discard.has(id)==(count==8),"search and plunder discard incoming overflow")
			check(not g.deck.has(id) and not g.characters[3].hand.has(id) and _conserved(g),"pickup removes source entity exactly once")
		# A death card rejected on placement returns to the death discard pile.
		var g=H.fixture(8);fill(g,3,count);var id:int=H.give_death(g,0,"curse")
		var a:Dictionary={"actor":0,"card":id,"death":true,"id":1,"status":"active","virtual":false}
		g._move_death_to_hand(a,3);g._complete_death(a)
		check(g.characters[3].hand.has(id)==(count==7) and g.death_discard.has(id)==(count==8),"wither overflow goes to the correct discard pile")
		check(not g.discard.has(id) and not g.characters[0].deathrattles.has(id),"wither never leaks into normal deck or remains with source")
	# Gift can discard wither, but accepted wither retains its existing protection.
	var g=H.fixture(8);curse(g,0);var first:int=H.give(g,0,"heal");fill(g,3,7)
	H.begin(g,{0:H.give(g,0,"gift")});g.target(0,3);g.pick(0,[first,104])
	check(g.death_discard==[104] and not g.characters[0].hand.has(104) and not g.characters[3].hand.has(104),"gift overflow discards wither exactly once")
	check(not g.characters[0].get("curse_exposed",false) and not g.characters[3].get("curse_exposed",false),"discarded wither leaves no hand effect marker")
	print("HAND_CAP_RULES_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
