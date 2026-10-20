extends "res://tests/v0174_ui_test.gd"
const Layout=preload("res://scripts/board_layout.gd")

func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0191-"+name+".png")

func sample(fx,at:float)->void:
	fx.clock_started=-1;fx.set_process(false);fx.elapsed=at;fx._process(0)

func _run()->void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	await create_timer(.4).timeout;main.music.set_level(0)
	var g=H.fixture(8)
	for id in range(6):g._draw(g.characters[id],4)
	await show_game(g)
	var bar=meta(main,"planning_bar",true)
	var lock=meta(main,"planning_lock_button",true)
	check(bar.size.x<600 and bar.size.x>400,"planning panel fits actual text instead of full table")
	check(is_equal_approx(bar.position.x+bar.size.x/2,720),"compact planning panel stays centered")
	check(bar.get_global_rect().encloses(lock.get_global_rect()),"lock button remains entirely inside compact panel")
	await shot("compact-planning")
	g.submit(0,[0,0,0]);await show_game(g)
	check(meta(main,"planning_bar",true).size.x<600,"locked text also receives a fitted panel")
	check(meta(main,"planning_lock_button",true).text=="取消锁定出牌","unlock control is retained")
	# Mixed accepted/rejected draws, including card-count restoration.
	g=H.fixture(8);g.match_id=19100;g._draw(g.characters[0],7);g.presentation_enabled=true
	g._push([{"op":"draw","target":0,"count":4}]);g._pump()
	await show_game(g)
	var fx=meta(main,"draw_animation",g.animation.id)
	check(fx.flights.size()==4 and fx.rows[0].cards.size()==8,"return cards are flight-only objects, not extra hand slots")
	for at in [0.0,.4,1.7,2.2,2.8,3.5,4.5,5.0]:
		sample(fx,at)
		check(fx.rows[0].count<=8,"visible hand count never exceeds eight")
		check(fx.pile.count>=0,"animated pile count never becomes negative")
		for flight in fx.flights:
			if flight.returned:check(flight.node.hidden_card and flight.node.card.is_empty(),"rejected card remains an anonymous back")
	sample(fx,2.30)
	var speech=meta(fx,"pawn_speech",0)
	check(speech.visible and speech.message_label.text=="我的手牌满了！","full-hand line appears when card reaches pawn")
	check(speech.body.encloses(Rect2(speech.message_label.position,speech.message_label.size)),"dialogue text fits inside its bubble")
	check(speech.body.end.x<Layout.pawn_rect(0,true).get_center().x,"speech sits to the left of the pawn")
	check(speech.mouse_filter==Control.MOUSE_FILTER_IGNORE and speech.message_label.mouse_filter==Control.MOUSE_FILTER_IGNORE,"speech never intercepts input")
	await shot("return-and-speech")
	sample(fx,3.40)
	check(speech.visible,"one dialogue remains visible across a batch of returns")
	await shot("return-flight")
	sample(fx,20)
	check(fx.flights.filter(func(f):return f.returned).all(func(f):return not f.node.visible),"returned flight nodes disappear at pile")
	check(fx.pile.count==g.deck.size() and fx.rows[0].count==8 and not speech.visible,"final counters and dialogue settle correctly")
	while not g.animation.is_empty():g.advance_animation()
	await show_game(g)
	check(meta(main,"selection_panel",true)==null,"overflow does not create a discard UI")
	# Every pawn, both perspectives; several batches may use the same top card.
	g=H.fixture(8);g.match_id=19101
	for id in range(6):g._draw(g.characters[id],8)
	g.presentation_enabled=true
	var sequence:Array=[]
	for id in range(6):sequence.append({"op":"draw","target":id,"count":1})
	g._push(sequence);g._pump()
	for team in [0,1]:
		await show_game(g,team)
		fx=meta(main,"draw_animation",g.animation.id)
		check(fx.flights.size()==6,"all six rejected flights exist for each viewer")
		for flight in fx.flights:
			sample(fx,flight.started+flight.duration+.25)
			speech=meta(fx,"pawn_speech",flight.id)
			check(speech.visible and flight.node.visible,"both viewers see the same pawn return and line")
			check(Rect2(0,0,1440,960).encloses(speech.body),"speech is inside logical viewport")
			check(speech.body.end.x<Layout.pawn_rect(flight.id,flight.id/3==team).get_center().x,"dialogue stays left after viewpoint swap")
			check(fx.rows[flight.id].count==8,"full hand remains at eight on each side")
			if flight.id==3 and team==0:await shot("enemy-speech")
			if flight.id==0 and team==1:await shot("opposite-perspective")
		sample(fx,100)
		check(fx.pile.count==g.deck.size(),"all-return sequence restores pile count")
	root.size=Vector2i(960,640);await show_game(g)
	fx=meta(main,"draw_animation",g.animation.id);sample(fx,1.95)
	await shot("speech-small")
	# Refresh keeps the shared draw clock; it neither duplicates nor restarts speech.
	main.effect_started=Time.get_ticks_msec()-2100
	main._schedule_render();await frames()
	fx=meta(main,"draw_animation",g.animation.id)
	check(fx.elapsed>=2.1 and fx.elapsed<2.6,"draw and dialogue clock survive render refresh")
	check(meta(fx,"pawn_speech",0).visible,"rebuilt dialogue resumes active interval")
	root.size=Vector2i(1200,800)
	g=H.fixture(8);g.match_id=19102;g._draw(g.characters[1],7)
	H.give_death(g,0,"divinity");g.characters[0].hp=0;g._activate({"actor":0,"card":102},0)
	g._push([{"op":"draw","target":1,"count":3}]);g._pump()
	await show_game(g)
	var choices:Array=g.request.options.slice(0,3)
	for id in choices:
		meta(main,"pick_card_id",id).pressed.emit();await frames()
	check(main.pick_cards==choices,"divinity picker preserves click order")
	for i in range(3):check(meta(main,"pick_card_id",choices[i]).selection_order==i+1,"selected cards display admission order")
	await shot("divinity-order")
	g.pick(0,main.pick_cards.duplicate())
	check(g.characters[1].hand.has(choices[0]) and not g.characters[1].hand.has(choices[1]),"displayed first choice is the one admitted")
	main.queue_free();await frames()
	print("V0191_UI_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
