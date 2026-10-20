extends "res://tests/v018_test.gd"
const G=preload("res://tests/gem_scenarios.gd")
const Session=preload("res://scripts/session.gd")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("GEM_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func _run()->void:
	for key in H.Rules.GEMS:
		for actor in range(6):
			for retained in [false,true]:
				var g=G.setup(key,actor,260000+checks,retained);check(G.seek(g),"real passive reaches gem motion")
				var id:int=g.animation.gem_card;var hand:Array=g.characters[actor].hand.duplicate();var hp:int=g.characters[actor].hp
				var own:Dictionary=g.snapshot(actor/3);var enemy:Dictionary=g.snapshot(1-actor/3)
				check(own.animation.gem_card==id and own.animation.has("owner_slot"),"owner can locate exact gem instance")
				check(not enemy.animation.has("gem_card") and not enemy.animation.has("owner_slot") and enemy.characters[actor].hand.is_empty(),"opponent learns only triggered gem type and occupied slot")
				own.animation.erase("gem_card");own.animation.erase("owner_slot")
				check(own.animation==enemy.animation,"shared public motion and timing")
				check(g.characters[actor].hand==hand and g.characters[actor].hp==hp,"gem remains in hand through flight and return")
				var client=Session.new();root.add_child(client);client.set_process(false)
				var event_id:int=g.animation.id
				while G.supports(g.animation) and g.animation.id==event_id:
					var duration:int=H.Rules.StrikeStyles.duration(g.animation)
					var stage:String=g.animation.stage
					var before:Dictionary=g.snapshot(1);client._receive_view(before)
					g.advance_animation();var after:Dictionary=g.snapshot(1);client._receive_view(after)
					client.received_animation_started=Time.get_ticks_msec()-duration+30;client._drain_received_views()
					check(client.state.animation==before.animation,"client waits for complete gem stage")
					client.received_animation_started=Time.get_ticks_msec()-duration-1;client._drain_received_views()
					check(client.state.revision==after.revision,"client releases after stage")
					if stage=="travel":
						check(g.characters[actor].hand.has(id),"gem remains in hand when it reaches pawn")
						if key!="sapphire":check(g.characters[actor].hp==(4 if key=="ruby" else 1),"HP changes exactly at pawn contact")
					if stage=="impact" and key!="sapphire":
						check(g.animation.stage=="return" and g.characters[actor].hand.has(id),"healed gem returns before any discard")
					if stage=="return":
						check(g.characters[actor].hand.has(id)==(key!="amethyst" or retained),"only eligible purple gem consumed after return")
				client.leave();client.queue_free()
				check(G.drain(g) and _conserved(g),"passive completes with all cards conserved")
				check(g.characters[actor].hand.has(id)==(key!="amethyst" or retained),"retained gems stay in hand")
				if key=="ruby":check(g.characters[actor].hp==4,"ruby heals one once")
				if key=="amethyst":check(g.characters[actor].hp==1,"amethyst revives before death queue")
				if key=="sapphire":check(g.characters[actor].hand.size()==hand.size()+2,"sapphire adds one then normal round draw")
	for key in H.Rules.GEMS:
		var g=G.setup(key,0,270000+checks,false,2);var count:=0
		for _i in range(200):
			if g.animation.is_empty() and g.phase in ["planning","review","ended"]:break
			if G.supports(g.animation) and g.animation.stage=="travel":count+=1
			check(G.S.step(g)=="","multiple gems advance")
		check(count==(1 if key=="amethyst" else 2),"each eligible copy animates once")
	# Presentation disabled and enabled must produce the same rules outcomes.
	for key in H.Rules.GEMS:
		for variant in ["blocked","dead","full"]:
			var outcomes:Array=[]
			for presented in [false,true]:
				var g=H.fixture(8);var id:int=H.give(g,0,key);g.characters[0].hp=3
				if variant=="blocked":activate(g,3,"prison" if key=="sapphire" else "blessing",0)
				elif variant=="dead":g.characters[0].hp=0;g.characters[0].death_round=g.round_number
				else:g.characters[0].hp=8
				g.presentation_enabled=presented
				if key=="sapphire":g._begin_round()
				else:H.begin(g,{})
				check(G.drain(g),"edge case completes")
				outcomes.append([g.characters[0].hp,g.characters[0].hand.duplicate(),g.discard.duplicate(),g.deck.duplicate(),g.phase])
			check(outcomes[0]==outcomes[1],"animation preserves blocked, dead and full-health rules")
	print("GEM_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
