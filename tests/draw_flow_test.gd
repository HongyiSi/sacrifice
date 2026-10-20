extends "res://tests/v018_test.gd"

func _initialize() -> void:
	for shown in [false,true]:
		var opening=H.Rules.new();opening.presentation_enabled=shown;opening.start(48006)
		if shown:check(opening.characters.all(func(c):return c.hand.size()==4),"opening deals four before first round draw")
		finish_motion(opening)
		check(opening.phase=="planning" and opening.characters.all(func(c):return c.hand.size()==5),"first planning has five cards per pawn")
		check(opening.deck.size()==90 and _conserved(opening),"opening consumes exactly thirty normal cards")
		for slots in [0,1,3]:
			var g=god_game(shown);fill_to(g,1,8-slots)
			g._push([{"op":"draw","target":1,"count":3},{"op":"planning"}]);g._pump();finish_motion(g)
			if slots==0:
				check(g.phase=="planning" and g.request.is_empty(),"full hand skips divine picker entirely")
			else:
				check(g.phase=="selecting" and g.request.count==slots and g.request.accept_count==slots,"divinity asks only for cards that fit")
				check(g.pick(0,g.request.options.slice(0,slots))=="","capacity-limited selection accepted")
				finish_motion(g)
			check(g.characters[1].hand.size()==8 and _conserved(g),"limited divine draw conserves cards without overflow")
		_choice_chain(shown)
		_refill_chain(shown)
	_notifications()
	print("DRAW_FLOW_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)

func god_game(shown:bool):
	var g=H.fixture(8);g.characters[0].hp=0;activate(g,0,"divinity")
	g.presentation_enabled=shown;g.phase="resolution";g.turn_stage="resolution"
	return g

func fill_to(g,actor:int,n:int) -> void:
	while g.characters[actor].hand.size()<n:g.characters[actor].hand.append(g.deck.pop_front())

func finish_motion(g) -> void:
	for _i in range(200):
		if g.animation.is_empty():return
		g.advance_animation()
	check(false,"motion completes")

func _choice_chain(shown:bool) -> void:
	var g=god_game(shown);fill_to(g,1,7);fill_to(g,2,8)
	g._push([{"op":"draw","target":1,"count":3},{"op":"draw","target":2,"count":2},
		{"op":"draw","target":3,"count":2},{"op":"planning"}]);g._pump();finish_motion(g)
	check(g.request.target==1 and g.request.count==1,"first choice uses its one free slot")
	var first:Array=g.request.options.slice(0,1)
	check(g.pick(0,first)=="","first divine choice accepted")
	check(g.animation.is_empty() and g.phase=="selecting" and g.request.target==3,"next eligible pawn can choose immediately, skipping full recipient")
	check(not g.request.options.has(first[0]),"reserved card cannot be selected twice")
	check(g.snapshot(1).input.options.is_empty() and g.snapshot(1).characters[1].hand.is_empty(),"opponent cannot inspect private options or chosen friendly cards")
	var second:Array=g.request.options.slice(0,2);g.pick(0,second)
	if shown:
		check(g.animation.kind=="draw_cards" and g.animation.draws.size()==3,"one batch replays draws and full-hand speech after choices")
		check(g.animation.draws[0].ids==first and g.animation.draws[2].ids==second,"animation preserves chosen order and recipients")
	finish_motion(g)
	check(g.phase=="planning" and g.characters[1].hand.size()==8 and g.characters[2].hand.size()==8 and g.characters[3].hand==second,"all choices finish with correct hands")
	check(_conserved(g),"consecutive choices preserve deck conservation")
	# Selection cannot move past a non-draw effect before its earlier draw is shown.
	g=god_game(shown);g.characters[1].hp=4
	var a:Dictionary=g._visual_action("heal",1)
	g._push([{"op":"draw","target":1,"count":1},g._job("heal",a,{"target":1,"amount":1}),{"op":"draw","target":1,"count":1},{"op":"planning"}]);g._pump();finish_motion(g)
	g.pick(0,g.request.options.slice(0,1))
	if shown:check(g.animation.kind=="draw_cards" and g.characters[1].hp==4,"batch never advances past intervening gameplay effects")
	finish_motion(g)
	check(g.characters[1].hp==5 and g.request.get("type","")=="deck","healing completes before subsequent independent draw choice")
	g.pick(0,g.request.options.slice(0,1));finish_motion(g)

func _refill_chain(shown:bool) -> void:
	var g=god_game(shown)
	g.discard=g.deck.slice(1);g.deck=g.deck.slice(0,1)
	g._push([{"op":"draw","target":1,"count":3},{"op":"planning"}]);g._pump();finish_motion(g)
	check(g.request.count==1 and g.request.remaining==2,"partial deck preserves remaining accepted draw")
	g.pick(0,g.request.options.duplicate())
	check(g.animation.is_empty() and g.request.count==2,"refilled deck immediately opens remaining selection")
	g.pick(0,g.request.options.slice(0,2));finish_motion(g)
	check(g.characters[1].hand.size()==3 and _conserved(g),"refill chain finishes with three distinct cards")

func _notifications() -> void:
	for actor in [0,3]:
		var target:int=3 if actor==0 else 0
		for key in ["obstruct","poisoning","gift"]:
			var g=H.fixture(8);g.presentation_enabled=true
			fill_to(g,target,7 if key!="poisoning" else 8)
			var card:int=H.give(g,actor,key);var values:Array=[]
			if key=="gift":values=[H.give(g,actor,"warcry"),H.give(g,actor,"bloodletting")]
			H.begin(g,{actor:card},false);finish_motion(g);g.target(actor/3,target)
			if key=="gift":g.pick(actor/3,values)
			check(g.animation.get("kind","")=="pawn_speech" and g.animation.action.actor==actor,"active giver speaks when placement overflows")
			check(g.animation.get("message","")=="它的手牌满了！" and g.visual_queue.is_empty(),"partial or full overflow uses one line per effect")
			check(g.snapshot(0).animation==g.snapshot(1).animation,"full-hand notification exposes no private chosen card IDs")
			finish_motion(g)
			check(g.characters[target].hand.size()==8 and _conserved(g),"bubble leaves placement and discard rules unchanged")
