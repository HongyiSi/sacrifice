extends "res://tests/v0203_ui_test.gd"
const Transfers=preload("res://tests/hand_transfer_scenarios.gd")

func fill_to(g,actor:int,n:int) -> void:
	while g.characters[actor].hand.size()<n:g.characters[actor].hand.append(g.deck.pop_front())

func _run() -> void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume();main.session.set_process(false)
	for owner in [0,3]:
		var viewer:int=owner/3
		var g=H.fixture(8);serial+=1;g.match_id=serial;main.session.game=g
		var id:int=H.give_death(g,owner,"divinity");g.characters[owner].hp=0
		g._activate({"actor":owner,"card":id},owner);g.presentation_enabled=true
		fill_to(g,1,7);fill_to(g,2,8)
		g._push([{"op":"draw","target":1,"count":3},{"op":"draw","target":2,"count":1},{"op":"draw","target":4,"count":2},{"op":"planning"}]);g._pump();finish_fx(g)
		await show_game(g,viewer)
		check(g.request.count==1 and meta(main,"pick_confirm",true)!=null,"one free slot shows a one-card picker")
		var first:int=g.request.options[0]
		meta(main,"pick_card_id",first).pressed.emit();await frames()
		meta(main,"pick_confirm",true).pressed.emit();await frames()
		check(g.animation.is_empty() and g.request.target==4 and g.request.count==2,"confirmation opens next picker without waiting for draw animation")
		check(main.pick_cards.is_empty() and meta(main,"pick_card_id",first)==null,"next picker resets selection and removes previously drawn card")
		check(meta(main,"auto_pick",true)!=null and not meta(main,"auto_pick",true).disabled,"next selection is immediately interactive")
		if owner==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/draw-flow-next-choice.png")
		meta(main,"auto_pick",true).pressed.emit();await frames()
		check(g.animation.kind=="draw_cards" and meta(main,"draw_animation",g.animation.id)!=null,"draw batch plays after last choice")
		finish_fx(g);await show_game(g,viewer)
		check(g.phase=="planning" and g.characters[1].hand.size()==8 and g.characters[4].hand.size()==2,"continuous picker completes with correct hands")
		# Overflow speech stays beside the actor in either player's orientation.
		var target:int=3 if owner==0 else 0
		for key in ["obstruct","ruby"]:
			g=H.fixture(8);serial+=1;g.match_id=serial;main.session.game=g;g.presentation_enabled=true
			var played:int=H.give(g,owner,key);fill_to(g,target,8)
			H.begin(g,{owner:played},false);finish_fx(g);g.target(viewer,target)
			if key=="ruby":check(Transfers.seek(g),"gem overflow enters its existing transfer presentation")
			for observer in [0,1]:
				await show_game(g,observer)
				var bubble=meta(main,"pawn_speech",owner)
				check(bubble!=null and bubble.message_label.text=="它的手牌满了！","giver says the target hand is full")
				check(meta(main,"pawn_speech",target)==null,"recipient no longer speaks for another pawn's placement")
				if bubble!=null:
					bubble.started=-1;bubble.present(.4);bubble.set_process(false)
					check(bubble.body.get_center().x<Layout.pawn_rect(owner,owner/3==observer).get_center().x,"speech stays left of correct pawn in both views")
					if owner==0 and observer==0 and key=="obstruct":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("res://test-results/draw-flow-giver-speech.png")
	print("DRAW_FLOW_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
