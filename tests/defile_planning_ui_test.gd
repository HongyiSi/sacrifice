extends "res://tests/v0203_ui_test.gd"
const Mark=preload("res://scripts/defile_mark.gd")
const HandCard=preload("res://scripts/card_widget.gd")
func marked(card)->bool:
	return card.get_children().filter(func(n):return n is Mark).size()==1
func verify_marks(ids:Array,label:String)->void:
	for id in ids:
		var widget=hand_card(id)
		if widget!=null:check(marked(widget)==bool(widget.card.get("defiled",false)),label+" cross follows physical card")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume()
	for viewer in [0,1]:
		var actor=viewer*3+2;var g=H.fixture(7);serial+=1;g.match_id=serial;main.session.game=g
		var ids=[]
		for key in ["reverse","bloodletting","gift","heal","skip_death","final_strike"]:ids.append(H.give(g,actor,key))
		for i in range(2):
			var rock=g._generate_card(H.Rules.BOULDER);g.characters[actor].hand.append(rock);ids.append(rock)
		g.defiled_cards[ids[5]]=true
		await show_game(g,viewer)
		verify_marks(ids,"initial")
		var opponent_before=g.snapshot(1-viewer)
		hand_card(ids[2]).pressed.emit();await frames()
		check(main._selected_cards(actor)==[ids[2]],"play triggers hand compression")
		verify_marks(ids,"play and row crossing")
		for t in [0,150,299]:
			var flight=flying(ids[5])
			if flight!=null:flight.set_process(false);flight.present(flight.started+t)
			verify_marks(ids,"in flight")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/defile-plan-%d.png"%viewer)
		# A second selection replaces the first, then withdrawing restores all slots.
		hand_card(ids[0]).pressed.emit();await frames();verify_marks(ids,"replacement")
		staged(ids[0]).pressed.emit();await frames();verify_marks(ids,"withdraw")
		check(g.snapshot(1-viewer)==opponent_before,"local choices do not move opponent marks")
		g.characters[actor].extra_round=g.round_number;g.characters[actor].extra_count=1
		await show_game(g,viewer)
		for id in [ids[0],ids[2]]:hand_card(id).pressed.emit();await frames()
		verify_marks(ids,"two cards played")
		root.size=Vector2i(960,640);main._schedule_render();await frames();verify_marks(ids,"resize")
		root.size=Vector2i(1440,960)
		# Hidden hands retain the public cross without exposing a card identity.
		await show_game(g,1-viewer)
		var fan=meta(main,"enemy_hand_actor",actor)
		var hidden=fan.get_children().filter(func(c):return c is HandCard)
		check(hidden.filter(func(c):return marked(c)).size()==1,"opponent keeps one public mark")
		check(hidden.all(func(c):return c.card.is_empty() and c.hidden_card),"mark does not reveal opponent identities")
	print("DEFILE_PLANNING_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
