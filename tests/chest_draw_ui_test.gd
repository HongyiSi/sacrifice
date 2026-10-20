extends "res://tests/v0203_ui_test.gd"
const Cases=preload("res://tests/art_scenarios.gd")
const Art=preload("res://scripts/cinema/atlas.gd")
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/chest-"+name+".png")
func draw_at(fx,seconds:float)->void:
	fx.set_process(false);fx.clock_started=-1;fx.elapsed=seconds;fx._process(0)
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"));root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.set_level(0);main.attack_audio.level=0
	check(Art.card_texture("collect")==Art.texture("collection_key"),"printed collect and animated key share the same artwork")
	for viewer in [0,1]:
		var pair=Cases.setup("collect",90000+viewer);var g=pair[0]
		var seen_intro=false;var seen_draw=false
		for step in range(140):
			var e=g.animation
			if e.get("op","")=="collect_launch":
				await show_game(g,viewer)
				var fx=meta(main,"cinema_effect",e.id);fx.set_process(false)
				var pile=meta(main,"draw_pile",true)
				check(pile.position.x+pile.size.x<150,"chest stays on left red area")
				if e.stage=="travel":
					seen_intro=true
					for u in [0.0,.35,.62,.90,1.0]:
						fx.present(u*e.travel_ms/1000.0)
						if u<=.62:check(is_zero_approx(pile.opening),"lid waits until key has turned")
						if u==1.0:check(pile.opening>.99,"key leaves chest fully open for actual receipt")
						if viewer==0:await shot("key-"+str(u))
				else:
					fx.present(0);check(pile.opening>.99,"impact rebuild preserves the open lid")
			if e.get("kind","")=="draw_cards":
				await show_game(g,viewer)
				var fx=meta(main,"draw_animation",e.id);var pile=fx.pile
				if e.stage=="travel":
					seen_draw=true;check(fx.flights.size()==3,"collect launches exactly three real cards")
					for t in [0.0,.30,1.0,fx.chest_last,fx.chest_last+.15]:
						draw_at(fx,t)
						if t<=fx.chest_last:check(pile.opening>.99,"chest stays open across the three real landings")
						for flight in fx.flights:
							check(flight.origin==Layout.DECK_CENTER,"real card originates inside chest")
							if viewer==1:check(flight.node.card.is_empty() and flight.node.hidden_card,"opponent cards stay hidden")
						if viewer==0:await shot("draw-"+str(t))
					# Rebuilding/resizing at a mid-flight timestamp must preserve lid pose.
					draw_at(fx,1.0);var old_open=pile.opening
					await show_game(g,viewer);fx=meta(main,"draw_animation",e.id);draw_at(fx,1.0)
					check(is_equal_approx(fx.pile.opening,old_open),"rebuild restores chest from event time")
				else:
					draw_at(fx,.15);check(fx.pile.opening<.01,"lid finishes closing after last arrival")
			var error=Cases.step(g,pair[1]);if error=="done":break
			check(error.is_empty(),"collect scenario advances")
		check(seen_intro and seen_draw,"both key and real draw stages covered")
	# Normal and rejected batches use the same chest, without changing game timing.
	for amount in [0,7,8]:
		var g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=true
		while g.characters[0].hand.size()<amount:g.characters[0].hand.append(g.deck.pop_back())
		g._draw(g.characters[0],3);g._pump();await show_game(g,0)
		var fx=meta(main,"draw_animation",g.animation.id)
		check(fx!=null,"ordinary draw has a receipt")
		draw_at(fx,0);check(fx.pile.opening==0,"ordinary batch begins with closed lid")
		draw_at(fx,.28);check(fx.pile.opening>.99,"ordinary batch opens chest")
		check(fx.flights.size()==mini(3,8-amount),"full hands do not create decorative cards")
		draw_at(fx,fx.chest_last+.34);check(fx.pile.opening<.01,"ordinary/rejected batch closes")
		if amount==0:await shot("closed-board")
	# Non-deck transfers must not animate the draw chest.
	for key in ["obstruct","poisoning","gift","plunder"]:
		var pair=Cases.setup(key,91000+serial);serial+=1;var g=pair[0]
		for step in range(150):
			if g.animation.get("kind","")=="draw_cards" and g.animation.stage=="travel":
				await show_game(g,0);var fx=meta(main,"draw_animation",g.animation.id)
				draw_at(fx,.5);check(fx.pile.opening==0,"transfers keep chest closed: "+key)
			var error=Cases.step(g,pair[1]);if error=="done":break
	# Empty, blocked and interactive outcomes end the prelude with a closed lid.
	for mode in ["empty","blocked","divinity"]:
		var pair=Cases.setup("collect",92000+serial);serial+=1;var g=pair[0]
		if mode=="empty":g.deck.clear();g.discard.clear()
		elif mode=="blocked":
			var id=H.give_death(g,3,"prison");g._activate({"actor":3,"card":id},0)
		else:
			var id=H.give_death(g,1,"divinity");g.characters[1].hp=0;g._activate({"actor":1,"card":id},1)
		for _step in range(80):
			if g.animation.get("op","")=="collect_launch":break
			Cases.step(g,pair[1])
		check(g.animation.get("draw_mode","")==mode,"actual rules report collect outcome: "+mode)
		await show_game(g,0);var fx=meta(main,"cinema_effect",g.animation.id);fx.set_process(false);fx.present(g.animation.travel_ms/1000.0)
		check(meta(main,"draw_pile",true).opening==0,"non-ready prelude closes: "+mode)
		var real_draws=0
		for _step in range(160):
			if g.animation.get("kind","")=="draw_cards" and g.animation.stage=="travel":
				real_draws+=1;await show_game(g,0)
				var receipt=meta(main,"draw_animation",g.animation.id);draw_at(receipt,0)
				check(receipt.pile.opening==0,"interactive selection returns to a fresh opening")
			var error=Cases.step(g,pair[1]);if error=="done":break
			check(error.is_empty(),"edge scenario completes: "+mode)
		check(real_draws==(1 if mode=="divinity" else 0),"only actual selected cards produce a draw receipt")
	print("CHEST_DRAW_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
