extends "res://tests/v0174_ui_test.gd"
const C=preload("res://tests/collect_scenarios.gd")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("COLLECT_UI_FAIL "+label)
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/collect-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for actor in range(6):
		var g=C.setup(actor,240000+actor,7 if actor in [1,4] else 2);check(C.seek(g),"collect fixture")
		for viewer in [0,1]:
			await show_game(g,viewer)
			for t in [0.0,.12,.23,.47,.63,.86,.94,1.0]:
				var fx=await pose(g,t)
				check(fx.launch_effect.book.collect_launch!=null and fx.card_effect.collect_launch!=null,"dedicated approved motif connected")
				check(fx.source_widget.motif_alpha==0,"only the flying emblem is visible")
				var motif=fx.launch_effect.book.collect_launch
				check(motif.position_at(0).distance_to(fx.source)<.01,"emblem starts on displayed card")
				check(motif.position_at(.23).distance_to(fx.source+Vector2(0,-44))<.01,"approved rise distance")
				check(motif.position_at(1).distance_to(preload("res://scripts/board_layout.gd").DECK_CENTER)<.01,"emblem arrives at deck")
				if actor in [0,3] and viewer==0 and t==.47:await shot("actor-%d-fan"%actor)
			var fx=await pose(g,.5);var started:int=Time.get_ticks_msec()-850
			main.effect_started=started;fx.clock_started=started;main._schedule_render();await frames()
			fx=meta(main,"effect_animation",g.animation.id)
			check(fx.clock_started==started and fx.elapsed>=.85,"refresh preserves animation clock")
			if actor==0 and viewer==0:
				root.size=Vector2i(960,640);main._schedule_render();await frames();await pose(g,.47);await shot("small")
				root.size=Vector2i(1440,960);await frames()
			fx=await pose(g,.5);var source=fx.source_widget;fx.queue_free();await frames()
			check(source.motif_alpha==1,"interruption restores printed emblem")
		g.advance_animation();await show_game(g,actor/3);var impact=await pose(g,1)
		check(impact.source_widget.motif_alpha==1,"deck pulse restores card")
		g.advance_animation()
		for viewer in [0,1]:
			await show_game(g,viewer);var draw=meta(main,"draw_animation",g.animation.id)
			check(draw!=null and draw.flights.size()==3-g.animation.draws[0].returned.count(true),"only accepted cards have draw flights")
			for flight in draw.flights:
				if actor/3!=viewer:check(flight.node.hidden_card,"enemy drawn faces stay hidden")
		check(C.drain(g),"draw finishes")
	print("COLLECT_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
