extends "res://tests/v0203_ui_test.gd"
func pointer_press(at:Vector2,touch:bool)->void:
	for pressed in [true,false]:
		if touch:
			var event:=InputEventScreenTouch.new();event.position=at;event.pressed=pressed
			root.push_input(event,true)
		else:
			var event:=InputEventMouseButton.new();event.position=at;event.global_position=at
			event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true)
	await frames()
func _run()->void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for viewer in [0,1]:
		var actor:int=viewer*3
		var g=H.fixture(7);serial+=1;g.match_id=serial;g.presentation_enabled=false
		var id:int=H.give(g,actor,"cards_to_blades")
		var blessed:int=H.give_death(g,actor,"blessing")
		g._activate({"id":-1,"actor":actor,"card":blessed,"death":true},actor)
		main.session.game=g;await show_game(g,viewer)
		for touch in [false,true]:
			var source=hand_card(id)
			await move_mouse(Vector2(20,350))
			await move_mouse(source.get_global_rect().get_center())
			check(not main.card_hover_state.is_empty(),"hover opens card description")
			var empty:=Vector2(600,310)
			check(not main._hint_control_at(main.board.canvas,empty),"chosen blank position has no controls")
			# Do not move the mouse first: touch can leave a stale hovered card.
			await pointer_press(empty,touch)
			check(main.card_hover_state.is_empty(),"blank press dismisses card hint with mouse/touch")
			main._schedule_render();await frames()
			check(main.board.card_hover==null and main.card_hover_state.is_empty(),"redraw does not resurrect dismissed hint")
			var badge=meta(main,"status_hover_key","%d/blessing"%actor)
			await move_mouse(badge.get_global_rect().get_center())
			check(main.card_hover_state.has("description"),"status hint opens immediately")
			await pointer_press(empty,touch)
			check(main.card_hover_state.is_empty(),"blank press dismisses status hint")
			main._inspect_hand(actor,id);await frames();await create_timer(.3).timeout
			check(not main.hand_focus.is_empty(),"explicit details panel opens for test")
			await pointer_press(main.hand_lift.details.get_global_rect().get_center(),touch)
			check(not main.hand_focus.is_empty(),"press inside detail panel preserves it")
			await pointer_press(empty,touch);await create_timer(.3).timeout;await frames()
			check(main.hand_focus.is_empty(),"blank press closes expanded detail panel")
		await click_widget(hand_card(id))
		check(main._selected_cards(actor)==[id],"card click still plays rather than dismissing")
		await click_widget(staged(id))
		check(main._selected_cards(actor).is_empty(),"played card can still be retracted")
	print("BLANK_HINT_DISMISS checks=",checks," failures=",failures)
	main.queue_free();await frames();quit(0 if failures==0 else 1)
