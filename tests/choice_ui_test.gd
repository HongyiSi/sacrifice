extends "res://tests/v0203_ui_test.gd"

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/card-sync-oct15/"+name+".png")

func _run() -> void:
	root.size = Vector2i(1200,800)
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for team in [0,1]:
		var owner: int = team*3
		var g = H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=false
		H.begin(g,{owner:H.give(g,owner,"ignore")})
		main.session.game=g;await show_game(g,team)
		await click_widget(meta(main,"priority_choice",4))
		for number in range(7): check(meta(main,"priority_choice",number)!=null,"all seven priorities remain visible")
		var pressed: Button = meta(main,"priority_choice",4)
		check(pressed.button_pressed and pressed.disabled,"chosen priority retains its pressed style without accepting a duplicate")
		check(pressed.get_theme_stylebox("disabled")==pressed.get_theme_stylebox("pressed"),"selected priority uses pressed appearance")
		if team==0: await shot("selected-priority")
		await click_widget(meta(main,"priority_choice",2))
		check(g.request.get("type","")!="number","second distinct priority completes selection")
		for key in ["precise_strike","last_dance"]:
			g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=false
			if key=="last_dance":
				H.give_death(g,owner,key);g.characters[owner].hp=0;g.characters[owner].death_round=g.round_number;H.begin(g,{})
			else: H.begin(g,{owner:H.give(g,owner,key)})
			g.target(team,(1-team)*3)
			main.session.game=g;await show_game(g,1-team)
			check(meta(main,"reselect_targets_button",true)==null,"waiting opponent has no reset button")
			await show_game(g,team)
			var reset=meta(main,"reselect_targets_button",true)
			check(reset!=null,"multi-target prompt has reset button")
			if reset==null: continue
			var panel=meta(main,"decision_panel",true)
			check(panel.get_global_rect().encloses(reset.get_global_rect()),"reset button fits the decision panel")
			check(not reset.get_global_rect().intersects(meta(main,"skip_effect_button",true).get_global_rect()),"reset and skip buttons do not overlap")
			if team==0: await shot(key+"-reselect")
			await click_widget(reset)
			check(g.request.get("selected_targets",[]).is_empty() and g.request.options.size()==6,"click resets selection through actual session")
			check(meta(main,"reselect_targets_button",true)==null,"reset disappears after selection clears")
		g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=false
		for key in ["prison","blessing","privilege","eye"]:
			var id: int=H.give_death(g,owner,key)
			g._activate({"id":-1,"actor":owner,"card":id,"death":true},owner)
		var hand: int=H.give(g,owner,"strike")
		main.session.game=g;await show_game(g,team)
		for key in ["prison","blessing","all"]:
			var status_key: String="%d/%s"%[owner,key]
			var badge=meta(main,"status_hover_key",status_key)
			check(badge!=null,"single and aggregate status badges exist")
			if badge==null: continue
			await move_mouse(badge.get_global_rect().get_center())
			var tip=meta(main,"hover_status_description",status_key)
			check(tip!=null and badge.tooltip_text.is_empty(),"status description appears immediately with no native delayed tooltip")
			if tip!=null:
				check(tip.get_child(0).text==badge.get_meta("status_description"),"status and aggregate content is preserved")
				check(tip.mouse_filter==Control.MOUSE_FILTER_IGNORE,"hover text never blocks clicks")
			main._schedule_render();await frames()
			check(meta(main,"hover_status_description",status_key)!=null,"board redraw preserves status being read")
			if team==0 and key=="all": await shot("status-hover")
		await move_mouse(hand_card(hand).get_global_rect().get_center())
		check(meta(main,"hover_card_description",hand)!=null and meta(main,"hover_status_description","%d/all"%owner)==null,"moving from status to card immediately switches descriptions")
		await move_mouse(Vector2(30,350))
		check(main.card_hover_state.is_empty(),"leaving hover sources hides description")
	print("CHOICE_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
