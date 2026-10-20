extends "res://tests/v0203_ui_test.gd"
const Transfers=preload("res://tests/hand_transfer_scenarios.gd")

func _run() -> void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume();main.session.set_process(false)
	for viewer in [0,1]:
		for key in H.Rules.PASSING_GEMS:
			var actor:int=viewer*3;var recipient:int=(1-viewer)*3
			var g=H.fixture(8);serial+=1;g.match_id=serial;main.session.game=g
			g.characters[actor].hp=3;g.characters[recipient+2].hp=0
			var card:int=H.give(g,actor,key)
			for other in H.Rules.PASSING_GEMS:
				if other!=key:H.give(g,actor,other)
			await show_game(g,viewer)
			await move_mouse(hand_card(card).get_global_rect().get_center())
			var tip=meta(root,"hover_card_description",card)
			check(tip!=null and tip.get_child(0).text.contains(g.catalog[card].text),"new gem hover explains complete benefit and transfer")
			await click_widget(hand_card(card));await create_timer(.35).timeout
			check(staged(card)!=null,"new gem can be selected for play")
			meta(main,"planning_lock_button",true).pressed.emit();await frames()
			g.presentation_enabled=true;g.resolution_presentation_enabled=true
			g.submit(1-viewer,[0,0,0])
			for _i in range(100):
				if g.phase=="targeting":break
				g.advance_animation()
			await show_game(g,viewer)
			check(meta(main,"target_outline",recipient)!=null and meta(main,"target_outline",recipient+1)!=null,"living opponents are highlighted")
			check(meta(main,"target_outline",actor)==null and meta(main,"target_outline",recipient+2)==null,"friendly and dead pawns are not highlighted")
			if viewer==0 and key=="topaz":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-results/passing-gems-targeting.png")
			await click_widget(meta(main,"knight_id",recipient))
			check(Transfers.seek(g),"clicking a highlighted pawn reaches gem transfer")
			for observer in [viewer,1-viewer]:
				await show_game(g,observer)
				var fx=meta(main,"hand_transfer_animation",g.animation.id)
				check(fx!=null,"both viewpoints render gem transfer")
				if fx!=null:
					check(fx.flying.card.key==key,"transfer displays the correct new gem face")
			for _i in range(100):
				if g.phase=="review" and g.animation.is_empty():break
				check(Transfers.S.step(g)=="","gem finishes without getting stuck")
			await show_game(g,1-viewer)
			check(hand_card(card)!=null,"recipient sees transferred gem in their hand")
	print("PASSING_GEMS_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
