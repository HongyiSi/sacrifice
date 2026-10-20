extends "res://tests/v0203_ui_test.gd"
const DrawPile=preload("res://scripts/draw_pile.gd")
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/perspective-"+name+".png")
func draw_at(fx,seconds:float)->void:
	fx.set_process(false);fx.clock_started=-1;fx.elapsed=seconds;fx._process(0)
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.set_level(0);main.attack_audio.level=0
	for viewer in [0,1]:
		var g=H.fixture(8);g.match_id=94010+viewer;g.presentation_enabled=true
		for actor in range(6):
			H.give(g,actor,"strike");H.give(g,actor,"defense")
			g._draw(g.characters[actor],1)
		g._pump();await show_game(g,viewer)
		var fx=meta(main,"draw_animation",g.animation.id);var pile=fx.pile
		var closed=pile.lid_corners(0)
		var front=(closed[2]+closed[3])/2;var rear=(closed[0]+closed[1])/2
		check(front.x-rear.x>50 and absf(front.y-rear.y)<.1,"chest front points due right, parallel to the cloth")
		check(absf(closed[1].y-closed[0].y)>12,"hinge follows table perspective")
		check(Geometry2D.is_point_in_polygon(Layout.DECK_CENTER-pile.position,closed),"card source lies inside the projected mouth")
		check(Layout.DECK_LOCK.x>Layout.DECK_CENTER.x+25,"keyhole lies on the right face")
		for amount in [0.0,.15,.3,.5,.8,1.0]:
			var corners=pile.lid_corners(amount)
			check(corners[0].is_equal_approx(closed[0]) and corners[1].is_equal_approx(closed[1]),"hinge stays fixed throughout the swing")
			for p in corners:check(Rect2(0,0,1440,960).has_point(p+pile.position),"lid stays on screen")
		check(pile.lid_corners(1)[2].x<closed[1].x and pile.lid_corners(1)[3].x<closed[0].x,"open lid tilts toward the left rear")
		check(fx.flights.size()==6,"one real draw for each player pawn")
		for flight in fx.flights:
			var end=Layout.hand_position(flight.id,2,flight.id/3==viewer)+Layout.CARD_SIZE*Layout.hand_scale(flight.id/3==viewer)*.5
			check(fx.flight_path(flight,0,end).is_equal_approx(Layout.DECK_CENTER),"all pawns share the same mouth")
			check(fx.flight_path(flight,.13,end).is_equal_approx(Layout.DECK_EXIT),"cards first leave to the right before branching")
			check(fx.flight_path(flight,1,end).distance_to(end)<.1,"each flight reaches the correct hand")
			for sample in range(21):check(Rect2(0,0,1440,960).has_point(fx.flight_path(flight,sample/20.0,end)),"complete flight remains on table")
		for t in [0.0,.09,.3,1.0,2.0,3.0,fx.chest_last+.34]:
			draw_at(fx,t)
			for flight in fx.flights:
				if flight.id/3!=viewer:check(flight.node.card.is_empty() and flight.node.hidden_card,"opponent identity remains hidden during perspective emergence")
			if viewer==0:await shot("both-players-"+str(t))
		if viewer==0:
			root.size=Vector2i(960,640);await frames();await show_game(g,viewer)
			fx=meta(main,"draw_animation",g.animation.id);draw_at(fx,.3)
			check(main.board._board_rect(fx.pile).is_equal_approx(Layout.DECK_RECT),"small window retains the projected chest layout")
			await shot("small-window");root.size=Vector2i(1440,960);await frames()
	print("CHEST_PERSPECTIVE_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
