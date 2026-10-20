extends "res://tests/v018_test.gd"
func finish_motion(g):
	for i in range(120):
		if g.animation.is_empty():return
		g.advance_animation()
	check(false,"animation queue completes")
func _initialize():
	_gift()
	for actor in [0,3]:
		for count in [1,2]:
			for room in [0,1,2]:
				var g=H.fixture(8);g.presentation_enabled=true
				var recipient=3 if actor==0 else 0
				var values=[H.give(g,actor,"strike")]
				if count==2:values.append(H.give(g,actor,"heal"))
				for i in range(8-room):g.characters[recipient].hand.append(g.deck.pop_front())
				var old_hand=g.characters[recipient].hand.duplicate()
				H.begin(g,{actor:H.give(g,actor,"gift")},false);finish_motion(g)
				check(g.target(actor/3,recipient)=="","valid recipient for one or two cards")
				check(g.request.count==count,"selection limit follows available hand")
				check(g.snapshot(1-actor/3).input.options.is_empty(),"selection remains private")
				check(g.pick(actor/3,[])!="","zero uses existing skip action")
				check(g.pick(actor/3,values)=="","one or two selected cards accepted")
				finish_motion(g)
				var accepted=mini(room,count)
				check(g.characters[actor].hand.is_empty(),"all selected physical cards leave sender")
				check(g.characters[recipient].hand==old_hand+values.slice(0,accepted),"ordered delivery respects capacity")
				check(values.slice(accepted).all(func(id):return g.discard.has(id)),"only overflow is discarded")
				check(_conserved(g) and g.phase=="review","transfer conserves cards and finishes")
		var g=H.fixture(8);var one=H.give(g,actor,"strike")
		H.begin(g,{actor:H.give(g,actor,"gift")},false);g.target(actor/3,1 if actor==0 else 4)
		check(g.skip_effect(actor/3)=="" and g.characters[actor].hand==[one],"skip gifts zero cards")
		g=H.fixture(8);H.begin(g,{actor:H.give(g,actor,"gift")},false)
		check(g.phase=="review","empty hand finishes without impossible choice")
	print("GIFT_UPTO_TWO_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
