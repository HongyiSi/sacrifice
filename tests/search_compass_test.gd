extends "res://tests/v0174_ui_test.gd"
const Scenarios=preload("res://tests/art_scenarios.gd")
const Pose=preload("res://scripts/search_compass_pose.gd")
func walk(n):
	var out=[n]
	for child in n.get_children():out.append_array(walk(child))
	return out
func start(actor):
	var g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=true;g.resolution_presentation_enabled=true
	H.give(g,actor,"defense");H.begin(g,{actor:H.give(g,actor,"search")},false)
	for i in range(100):
		if g.phase=="selecting" and g.request.type=="search":return g
		check(Scenarios.step(g,{"key":"search"})=="","advance to real picker")
	assert(false);return g
func _run():
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.player.stop();main.attack_audio.level=0
	for actor in [1,4]:
		var g=start(actor)
		for team in [0,1]:
			for dimensions in [Vector2i(960,640),Vector2i(1920,1280)]:
				root.size=dimensions;await show_game(g,team)
				var marker=walk(main).filter(func(n):return n.has_meta("search_compass_wait"))
				check(marker.size()==1 and marker[0].visible,"either viewer keeps exactly one waiting compass")
				check(not marker[0].is_processing(),"no timeout or drifting wait animation")
				check(marker[0].mouse_filter==Control.MOUSE_FILTER_IGNORE,"compass cannot block selection")
				check(Pose.REST.x+Pose.SIDE/2<166,"compass stays beside the full picker")
				check(main.attack_audio.cues_for(g.snapshot(team)).is_empty(),"waiting remains silent")
				if actor/3!=team:check(main.session.state.input.options.is_empty(),"opponent deck choice privacy")
		var selected=g.request.options[0];var before=g.characters[actor].hand.size()
		check(g.pick(actor/3,[selected])=="","real pick accepted")
		check(g.animation.op=="search_depart","compass departure precedes the receipt")
		for team in [0,1]:
			await show_game(g,team)
			check(main.session.state.characters[actor].hand_count==before,"no extra hand count before receipt")
			check(not main.session.state.characters[actor].hand.has(selected),"selected card is not prematurely shown")
			check(main.attack_audio.cues_for(g.snapshot(team)).size()==1,"one confirmation sound")
		g.advance_animation();g.advance_animation()
		check(g.animation.kind=="draw_cards","next animation is real card flight")
		for team in [0,1]:
			await show_game(g,team)
			var fx=meta(main,"draw_animation",g.animation.id)
			check(fx.flights.size()==1 and not fx.flights[0].placement,"real card, no compass replacement in flight")
			check(walk(main).filter(func(n):return n.has_meta("search_compass_wait")).is_empty(),"compass stays gone during flight")
			var e=g.animation;var flight=e.draws[0].durations[0]/1000.0
			var cues=main.attack_audio.cues_for(g.snapshot(team))
			check(cues.size()==2,"one paper flight and one existing placement sound")
			check(absf(cues.filter(func(c):return c.get("category","")=="card_movement")[0].delay-flight)<.001,"placement sound matches exact landing")
			fx.clock_started=-1;fx.set_process(false);fx.elapsed=flight;fx._process(0)
			check(fx.flights[0].landed and fx.flights[0].node.visible,"card becomes settled at real arrival")
			check(fx.flights[0].node.hidden_card==(team!=actor/3),"card identity remains private from opponent")
		# Declining and a full hand must never leave a stale compass or fake gain.
		g=start(actor);check(g.skip_effect(actor/3)=="","skip accepted")
		await show_game(g,actor/3)
		check(walk(main).filter(func(n):return n.has_meta("search_compass_wait")).is_empty(),"skip clears waiting prop")
		g=start(actor)
		while g.characters[actor].hand.size()<8:H.give(g,actor,"strike")
		selected=g.request.options.filter(func(id):return not g.characters[actor].hand.has(id))[0]
		check(g.pick(actor/3,[selected])=="","full-hand pick follows existing rules")
		check(g.characters[actor].hand.size()==8 and g.discard.has(selected),"full-hand handling unchanged")
		for i in range(60):
			check(g.animation.get("kind","")!="draw_cards","no flight into a full hand")
			if g.phase=="review" and g.animation.is_empty():break
			check(Scenarios.step(g,{"key":"search"})=="","full-hand sequence advances")
	print("SEARCH_COMPASS_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
