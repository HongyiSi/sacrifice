extends "res://tests/v0174_ui_test.gd"
const Cases=preload("res://tests/v0207_scenarios.gd")
const Timing=preload("res://scripts/blade_volley_timing.gd")
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0207-"+name+".png")
func freeze(fx,ms:float)->void:
	fx.clock_started=-1;fx.set_process(false);fx.elapsed=ms/1000.0;fx._process(0)
func cinema_pose(g,t:float):
	var fx=meta(main,"cinema_effect",g.animation.id)
	check(fx!=null,"new cinematic layer exists")
	if fx!=null:fx.set_process(false);fx.present(t*Styles.duration(fx.event)/1000.0)
	await RenderingServer.frame_post_draw
	return fx
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for actor in range(6):
		for config in [[6,0],[4,6],[4,8]]:
			serial+=1;var g=Cases.draw(actor,config[0],config[1],serial)
			var entry:Dictionary=g.animation.draws[0]
			var received:int=mini(config[0],8-config[1])
			for i in range(1,received):
				check(entry.durations[i]<=entry.durations[i-1],"successive draws accelerate until the speed ceiling")
				check(entry.starts[i]+entry.durations[i]>entry.starts[i-1]+entry.durations[i-1],"faster cards never overtake")
			for viewer in [0,1]:
				await show_game(g,viewer)
				var fx=meta(main,"draw_animation",g.animation.id)
				check(fx.flights.size()==received,"only accepted draw cards fly")
				check(fx.flights.all(func(f):return not f.returned),"no refused card flight")
				freeze(fx,900)
				if actor==0 and config==[6,0]:await capture("fast-draw-%d"%viewer)
				if received<config[0]:
					freeze(fx,entry.speech_start+350)
					check(fx.speeches.size()==1 and fx.speeches[actor].node.visible,"one full-hand speech per pawn")
					check(fx.speeches[actor].node.message_label.text=="我的手牌满了！","requested speech stays")
					if actor==0 and received==0:await capture("full-hand-%d"%viewer)
				freeze(fx,g.animation.travel_ms)
				check(fx.rows[actor].count==config[1]+received and fx.pile.count==g.deck.size(),"draw counts settle correctly")
		# Multi-target volley: no damage during selection, then one hit per arrival.
		serial+=1;var g=Cases.blades(actor,serial)
		var targets:Array=[(1-actor/3)*3,(1-actor/3)*3,(1-actor/3)*3+1]
		for step in range(3):
			for viewer in [0,1]:
				await show_game(g,viewer)
				var preview=meta(main,"blade_preparation",true)
				check(preview!=null and preview.cards.size()==4,"hand remains visible during all target choices")
				check(preview.cards.all(func(c):return c.hidden_card==(viewer!=actor/3)),"preparation preserves hand privacy")
				if actor==0 and step==2 and viewer==0:await capture("choose-targets")
			check(g.target(actor/3,targets[step])=="","each target can be selected including duplicates")
			check(g.characters[targets[0]].hp==8 and g.characters[targets[2]].hp==8,"all choices precede any damage")
		check(g.animation.kind=="blade_volley","one volley begins after final target")
		var event:Dictionary=g.animation.duplicate(true)
		for viewer in [0,1]:
			await show_game(g,viewer)
			var fx=meta(main,"blade_volley_animation",event.id)
			check(fx.source_hand.has("owner_hand")== (viewer==actor/3),"source card IDs private on both peers")
			freeze(fx,Timing.MORPH_MS+Timing.STEP_MS)
			var first:float=(fx.tick-Timing.MORPH_MS)/Timing.FLIGHT_MS
			check(is_equal_approx(first,1.0/3),"next blade launches at one third of previous flight")
			check(fx.cards.filter(func(c):return c.visible).size()==2,"one-by-one transformation retains protected card")
			freeze(fx,760)
			if actor==0:await capture("volley-%d"%viewer)
			for i in range(3):check(Rect2(110,80,1220,840).has_point(fx.blade_position(i,600)),"all blades stay on board")
			if actor==5:
				var started:int=main.effect_started
				main.effect_started=Time.get_ticks_msec()-650;root.size=Vector2i(960,640);main._schedule_render();await frames()
				fx=meta(main,"blade_volley_animation",event.id)
				check(fx.tick>=650 and fx.tick<950,"resize continues volley clock")
				root.size=Vector2i(1440,960);main._schedule_render();await frames();main.effect_started=started
		for i in range(3):
			g.advance_animation()
			check(g.animation.hits.size()==i+1,"exactly one damage event at each knife impact")
			check(g.characters[targets[0]].hp==8-mini(i+1,2) and g.characters[targets[2]].hp==(7 if i==2 else 8),"chosen order determines actual damage")
			await show_game(g,actor/3)
			var fx=meta(main,"blade_volley_animation",event.id);freeze(fx,80)
			check(fx.tick==Timing.arrival(i)+80,"impact snapshots preserve continuous flight timeline")
			if actor==0 and i==1:await capture("volley-hit")
		g.advance_animation()
		check(g.characters[actor].hand==[104],"unconvertible curse remains in hand")
		# Charged damage remains authoritative; the new art uses one heavy sword.
		g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=true
		var strike:int=H.give(g,actor,"final_strike");g.final_strike_damage[strike]=4
		H.begin(g,{actor:strike},false);g.target(actor/3,targets[0])
		check(g.animation.get("style","")=="final_strike" and g.characters[targets[0]].hp==8,"final strike waits for impact")
		for viewer in [0,1]:
			await show_game(g,viewer);var fx=await cinema_pose(g,.78)
			check(fx.handler!=null and fx.handler.count()==1,"charged final strike uses the approved single heavy sword")
			if actor==0:await capture("final-strike-%d"%viewer)
		g.advance_animation();check(g.characters[targets[0]].hp==4,"final strike applies four damage once")
		await show_game(g,actor/3);await cinema_pose(g,.15)
		if actor==0:await capture("final-strike-impact")
	# A copied conversion can consume all eight slots; check the long chooser
	# and an omniscient opponent's insertion order instead of owner sort order.
	var full=H.fixture(8);full.match_id=207888;full.presentation_enabled=true
	for _i in range(8):full.characters[0].hand.append(full.deck.pop_back())
	var original:Array=full.characters[0].hand.duplicate()
	var id:int=full.catalog.keys().filter(func(card_id):return full.catalog[card_id].key=="cards_to_blades")[0]
	var a:Dictionary=full._add_action(0,id,true);a.status="active"
	full._push([full._job("convert_hand",a),full._job("complete",a)]);full._pump()
	finish_fx(full)
	for i in range(7):full.target(0,3+i%3)
	await show_game(full,0);await capture("eight-blade-selection")
	check(full.characters[3].hp==8,"eight-blade preparation still causes no early damage")
	var eye:int=H.give_death(full,4,"eye");full.characters[4].hp=0;full._activate({"actor":4,"card":eye},4)
	await show_game(full,1)
	var preview=meta(main,"blade_preparation",true)
	check(preview.cards.map(func(c):return c.card.id)==original,"omniscient opponent retains original hand order")
	full.target(0,3);await show_game(full,1)
	var volley=meta(main,"blade_volley_animation",full.animation.id);freeze(volley,1000)
	check(volley.slots.size()==8 and not volley.cards[0].hidden_card,"eight known cards convert from the correct enemy slots")
	# Refused placements, like refused draws, only retain the pawn's speech.
	var refused=H.fixture(8);refused.match_id=207889;refused.presentation_enabled=true
	for _i in range(8):refused.characters[3].hand.append(refused.deck.pop_back())
	var gem:int=H.give(refused,0,"ruby");H.begin(refused,{0:gem},false);refused.target(0,3)
	await show_game(refused,0)
	var transfer=meta(main,"hand_transfer_animation",refused.animation.id);freeze(transfer,500)
	check(not transfer.flying.visible and transfer.speech.visible,"full-hand transfer also shows speech without flight")
	print("V0207_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
