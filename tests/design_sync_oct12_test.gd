extends "res://tests/choice_ui_rules_test.gd"

func begin_legacy(g, owner: int) -> void:
	H.give_death(g,owner,"legacy")
	g.characters[owner].hp=0
	g.characters[owner].death_round=g.round_number
	H.begin(g,{})
	finish_animation(g)

func _initialize() -> void:
	_catalog_changes()
	for team in [0,1]:
		_legacy(team)
		_persistent_senses(team)
	print("DESIGN_SYNC_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)

func _catalog_changes() -> void:
	var g=H.fixture(8)
	var expected={"collect":[9,10],"gift":[1,2],"judgment":[1,2],"prophecy":[3],"mirror":[4],"ignore":[5],"sapphire":[6],"ruby":[7],"amethyst":[8],"topaz":[9],"emerald":[10],"amber":[11]}
	for key in expected:
		var ranks=g.catalog.values().filter(func(c):return c.key==key).map(func(c):return c.secondary)
		check(ranks==expected[key],"updated ranks for "+key)
	check(g.normal_type_count==60 and g.catalog.size()==128 and g.death_catalog.size()==20,"deck counts remain unchanged")
	var used:Dictionary={}
	for c in g.catalog.values():
		if not c.get("playable",true):continue
		var rank="%d/%d"%[c.main,c.secondary]
		check(not used.has(rank),"unique printed priority "+rank)
		used[rank]=true
	var sorted=g.catalog.values().filter(func(c):return c.main==7)
	sorted.sort_custom(func(a,b):return a.secondary>b.secondary)
	check(sorted.map(func(c):return c.key)==["amber","emerald","topaz","amethyst","ruby","sapphire","ignore","mirror","prophecy","judgment","judgment"],"priority seven resolves in new descending order")

func _legacy(team: int) -> void:
	var pawn=team*3
	for presented in [false,true]:
		var g=H.fixture(8);g.presentation_enabled=presented
		g.characters[pawn].hp=3
		var strike=H.give(g,pawn,"strike")
		var food=H.give(g,pawn,"spare_food")
		var supplies=H.give(g,pawn,"spare_supplies")
		var poison=g._generate_card(g.POISON);g.characters[pawn].hand.append(poison)
		var rock=g._generate_card(g.BOULDER);g.characters[pawn].hand.append(rock)
		var marked=H.give(g,pawn,"heal");g.defiled_cards[marked]=true
		var kept=H.give(g,pawn+1,"defense")
		var dead_hand=H.give(g,pawn+2,"strike")
		begin_legacy(g,pawn+2)
		check(g.request.type=="discard" and g.request.target==pawn and g.request.min_count==0,"legacy offers optional discard before drawing")
		check(g.request.options.size()==3 and not g.request.options.has(poison) and not g.request.options.has(rock) and not g.request.options.has(marked),"curse and defiled cards are not discard options")
		check(g.snapshot(1-team).input.options.is_empty() and g.snapshot(team).input.options.size()==3,"discard candidates remain private to owning team")
		check(act(g,1-team,"pick",[])!="" and act(g,team,"pick",[food,food])!="" and act(g,team,"pick",[poison])!="","wrong player, duplicates and protected cards rejected")
		check(g.skip_effect(team)!="","cannot skip all teammates through a discard prompt")
		check(act(g,team,"pick",[strike,food,supplies])=="","any number of eligible cards accepted")
		finish_animation(g)
		check(g.characters[pawn].hp==5 and g.characters[pawn].hand.size()==8,"discard passives resolve before refill is calculated")
		check(g.discard.has(strike) and g.discard.has(food) and g.discard.has(supplies),"discarded cards leave hand exactly once")
		check(g.request.type=="discard" and g.request.target==pawn+1,"next living teammate gets independent choice")
		check(act(g,team,"pick",[])=="","zero-card discard accepted")
		check(G.drain(g),"legacy completes with and without animation")
		check(g.characters[pawn+1].hand.size()==8 and g.characters[pawn+1].hand.has(kept),"zero-card choice keeps hand and fills remaining slots")
		check(g.characters[pawn+2].hand==[dead_hand] and g.death_discard.has(114),"dead teammates do not draw; legacy is consumed")
		check(_conserved(g),"legacy conserves all physical cards")
	# A full protected hand has no selectable discards and no draw or prompt.
	var g=H.fixture(8)
	for _i in range(8):g.characters[pawn].hand.append(g._generate_card(g.BOULDER))
	for _i in range(8):H.give(g,pawn+1,"strike")
	begin_legacy(g,pawn+2)
	check(g.request.target==pawn+1,"fully protected first hand automatically continues")
	var pile=g.deck.size()
	check(act(g,team,"pick",[])=="" and G.drain(g) and g.deck.size()==pile,"full hand choosing zero does not draw")
	# Discarding the last playable card releases Prison, even if a rock remains.
	g=H.fixture(8);activate(g,(1-team)*3,"prison",pawn)
	var only=H.give(g,pawn,"strike")
	g.characters[pawn].hand.append(g._generate_card(g.BOULDER))
	begin_legacy(g,pawn+2)
	check(g.pick(team,[only])=="" and G.drain(g) and g.characters[pawn].hand.size()==8,"prison rechecked after legacy discards")
	# Divine selection belongs to its activated owner even while that pawn lives.
	g=H.fixture(8);activate(g,(1-team)*3,"divinity")
	var keep=H.give(g,pawn,"heal")
	begin_legacy(g,pawn+2)
	check(g.pick(team,[])=="" and g.request.type=="deck" and g.request.team==1-team and g.request.count==7,"legacy refill obeys living divinity and available slots")
	check(G.drain(g) and g.characters[pawn].hand.size()==8 and g.characters[pawn].hand.has(keep) and g.characters[pawn+1].hand.size()==8,"divine choices return to remaining legacy recipients")

func _persistent_senses(team: int) -> void:
	var pawn=team*3
	var enemy=(1-team)*3
	var g=H.fixture(8)
	H.give_death(g,pawn,"eye");H.give_death(g,pawn,"divinity")
	var hidden=H.give(g,enemy,"strike")
	check(not g.snapshot(team).omniscient and g._effect_owner("divinity")==-1,"owning an untriggered death card does not activate it")
	H.begin(g,{pawn:H.give(g,pawn,"feign")})
	check(G.drain(g) and g.characters[pawn].hp==6,"fake death activates both cards while holder survives")
	var view=g.snapshot(team)
	check(view.omniscient and view.characters[enemy].hand.has(hidden) and not g.snapshot(1-team).omniscient,"living activated eye sees opponent cards for its team only")
	check(view.characters[pawn].ongoing_effects.filter(func(e):return e.key in ["eye","divinity"]).all(func(e):return not e.dormant),"living eye and divinity are shown as active buffs")
	g.characters[pawn].hp=0;g._revive(pawn,1)
	check(g.snapshot(team).omniscient,"reviving the holder preserves eye")
	g._push([{"op":"draw","target":enemy,"count":2}]);g._pump()
	check(g.request.type=="deck" and g.request.team==team and g.request.count==2,"reviving holder preserves divine draw selection")
	check(g.snapshot(1-team).input.options.is_empty(),"divine deck choice still private to controller")
	var chosen:Array=g.request.options.slice(0,2)
	check(g.pick(team,chosen)=="" and g.characters[enemy].hand.size()==3,"living divinity selected cards enter target hand")
	g._lose_death(pawn,103);g._lose_death(pawn,102)
	check(not g.snapshot(team).omniscient and g._effect_owner("divinity")==-1,"losing source cards stops both persistent effects")
