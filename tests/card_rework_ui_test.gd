extends "res://tests/v0203_ui_test.gd"

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Godot projects/sacrifice/work/card-rework-oct06/"+name+".png")

func _run() -> void:
	root.size = Vector2i(1200,800)
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false)
	for viewer in [0,1]:
		var g = H.fixture(8);serial += 1;g.match_id = serial
		var actor: int = viewer*3
		var strike: int = H.give(g,actor,"final_strike")
		g.final_strike_damage[strike] = 3
		var food: int = H.give(g,actor,"spare_food")
		var supplies: int = H.give(g,actor,"spare_supplies")
		H.give(g,actor+1,"suppress")
		main.session.game = g;await show_game(g,viewer)
		check(hand_card(strike).card.damage == 3,"held face receives current damage")
		for id in [food,supplies]:
			check(hand_card(id).card.main == -1 and not hand_card(id).card.playable,"spare face has no priority and is unplayable")
			await click_widget(hand_card(id))
			check(main._selected_cards(actor).is_empty(),"clicking spare never stages it")
			await move_mouse(hand_card(id).get_global_rect().get_center())
			var tip = meta(root,"hover_card_description",id)
			check(tip != null and tip.get_child(0).text.contains(g.catalog[id].text),"spare hover shows complete multiline description")
		await move_mouse(hand_card(strike).get_global_rect().get_center())
		var tooltip = meta(root,"hover_card_description",strike)
		check(tooltip != null and tooltip.get_child(0).text.contains("造成3点伤害"),"hover shows charged damage")
		await shot("planning-"+str(viewer))
		await click_widget(hand_card(strike))
		await create_timer(.5).timeout
		check(staged(strike) != null and staged(strike).card.damage == 3,"staged face retains charge")
		H.begin(g,{actor:strike});await show_game(g,viewer)
		var action: Dictionary = H.action_for(g,actor)
		check(meta(main,"played_action_id",action.id).card.damage == 3,"revealed physical card retains charge")
		var copy: Dictionary = g._add_action((1-viewer)*3,strike,true,"mirror")
		await show_game(g,viewer)
		check(meta(main,"played_action_id",copy.id).card.damage == 0,"mirror face shows fresh zero damage")
		check(meta(main,"played_action_id",copy.id).card.text.contains("造成0点伤害"),"mirror hover data uses its own damage")
		await move_mouse(Vector2(25,350));await shot("physical-and-copy-"+str(viewer))
	main.queue_free();await frames()
	print("CARD_REWORK_UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
