extends "res://tests/v0203_ui_test.gd"
const Mark=preload("res://scripts/defile_mark.gd")
func mark_count(card)->int:
	return card.get_children().filter(func(n):return n is Mark).size()
func freeze(fx,t:float)->void:
	fx.clock_started=-1;fx.set_process(false);fx.elapsed=t;fx._process(0)
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/draw-marks-"+name+".png")

func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume()
	for owner in [0,3]:
		var g=H.fixture(7);serial+=1;g.match_id=serial;main.session.game=g
		var marked=H.give(g,owner,"emerald");g.defiled_cards[marked]=true
		var ordinary=H.give(g,owner,"strike");H.give(g,owner,"spare_food")
		g.presentation_enabled=true;g._draw(g.characters[owner],2);g._pump()
		check(g.animation.kind=="draw_cards","drawing uses animated hand copies")
		for viewer in [0,1]:
			await show_game(g,viewer)
			var fx=meta(main,"draw_animation",g.animation.id)
			var marked_slot:int=main.board.view.characters[owner].defiled_slots[0]
			var copies:Array=fx.rows[owner].cards
			var copy=copies.filter(func(c):return c.get_meta("hand_slot")==marked_slot)[0]
			for t in [0.0,.5,float(g.animation.travel_ms)/1000.0]:
				freeze(fx,t)
				check(copy.is_visible_in_tree() and mark_count(copy)==1,"defile cross remains at every deal timestamp")
				var brush=copy.get_children().filter(func(n):return n is Mark)[0]
				check(brush.brushes.all(func(b):return b.is_visible_in_tree()),"both cross strokes stay visible")
				check(copies.all(func(c):return mark_count(c)==(1 if c==copy else 0)),"no mark leaks onto unsealed or incoming cards")
				copy.pressed.emit();await frames()
				check(main.hand_focus.is_empty() and main.hand_lift.is_empty(),"deal clicks never open old details")
			if viewer==owner/3:
				check(copy.card.get("defiled",false),"visible clone preserves card restriction")
				var plain=copies.filter(func(c):return c.card.get("id",-1)==ordinary)[0]
				await move_mouse(plain.get_global_rect().get_center())
				check(meta(root,"hover_card_description",ordinary)!=null,"hover details remain immediate during deal")
				var position_before=plain.position
				await click_widget(plain)
				check(main.hand_focus.is_empty() and main.hand_lift.is_empty() and plain.position==position_before,"actual click has no lift or popup")
				check(main._selected_cards(owner).is_empty(),"cannot play temporary cards before deal ends")
			else:
				check(copy.card.is_empty() and copy.hidden_card,"public cross does not reveal opponent card face")
			await move_mouse(Vector2(40,400));await capture("deal-%d-view-%d"%[owner,viewer])
			# A rebuild/resize during the same receipt also keeps the cross.
			root.size=Vector2i(960,640);await show_game(g,viewer)
			fx=meta(main,"draw_animation",g.animation.id);freeze(fx,.5)
			check(fx.rows[owner].cards.filter(func(c):return mark_count(c)==1).size()==1,"resize preserves a single cross")
			root.size=Vector2i(1440,960)
		finish_fx(g);g.phase="planning";await show_game(g,owner/3)
		check(mark_count(hand_card(marked))==1,"real hand retains cross after draw completes")
		await click_widget(hand_card(marked))
		check(main.hand_focus.is_empty() and main._selected_cards(owner).is_empty(),"sealed hand clicks remain inert after deal")
		await click_widget(hand_card(ordinary))
		check(main._selected_cards(owner)==[ordinary] and main.hand_focus.is_empty(),"ordinary card can be played after deal")
		await capture("after-%d"%owner)
	print("DRAW_MARKS_CLICK_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
