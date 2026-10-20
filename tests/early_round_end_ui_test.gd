extends "res://tests/v0203_ui_test.gd"

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/early-round-end-oct10/"+name+".png")

func _run() -> void:
	root.size = Vector2i(1200,800)
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for team in [0,1]:
		var owner: int = team*3
		var enemy: int = (1-team)*3
		var g = H.fixture(8);serial+=1;g.match_id=serial
		main.session.game=g;await show_game(g,team)
		check(meta(main,"early_end_round_button",true)==null,"planning has no early-end button")
		for id in range(enemy,enemy+3): g.characters[id].hp=1
		H.give_death(g,enemy,"resurrection")
		H.begin(g,{owner:H.give(g,owner,"area_strike"),owner+1:H.give(g,owner+1,"magic_strike"),owner+2:H.give(g,owner+2,"badge")})
		await show_game(g,1-team)
		check(meta(main,"early_end_round_button",true)==null,"defeated side cannot end opponent's round")
		await show_game(g,team)
		var button=meta(main,"early_end_round_button",true)
		check(button!=null and not button.disabled and button.text=="提前结束回合","surviving side sees enabled labelled button")
		if button==null: continue
		check(button.position==Layout.CONFIRM_RECT.position,"button reuses confirmation area")
		var decision=meta(main,"decision_panel",true)
		check(not button.get_global_rect().intersects(decision.get_global_rect()),"shortcut does not cover the current choice")
		if team==0: await shot("early-end-button")
		await click_widget(button)
		check(g.phase=="death_targeting" and g.request.team==1-team,"real UI click advances to opponent deathrattle")
		check(meta(main,"early_end_round_button",true)==null,"button disappears in death phase")
		await show_game(g,1-team)
		check(meta(main,"decision_panel",true)!=null and meta(main,"early_end_round_button",true)==null,"opponent still has deathrattle controls")
		g.target(1-team,enemy);await show_game(g,team)
		check(g.characters[enemy].hp==5 and g.phase=="review","revival is not bypassed by UI action")
		# An open card picker must leave the shortcut accessible outside the panel.
		g=H.fixture(8);serial+=1;g.match_id=serial
		for id in range(enemy,enemy+3):g.characters[id].hp=0;g.characters[id].death_round=g.round_number
		H.give_death(g,enemy,"resurrection")
		var gift: int=H.give(g,owner,"gift")
		H.give(g,owner,"heal");H.give(g,owner,"strike")
		H.begin(g,{owner:gift});g.target(team,owner+1)
		main.session.game=g;await show_game(g,team)
		button=meta(main,"early_end_round_button",true)
		var picker=meta(main,"selection_panel",true)
		check(button!=null and picker!=null and not button.disabled,"card picker also offers shortcut")
		if button!=null and picker!=null:
			check(not button.get_global_rect().intersects(picker.get_global_rect()),"shortcut sits outside picker")
			if team==0: await shot("early-end-picker")
			await click_widget(button)
			check(g.phase=="death_targeting" and g.characters[owner].hand.size()==2,"shortcut cancels uncommitted gift without moving cards")
	print("EARLY_ROUND_END_UI_RESULT checks=%d failures=%d" % [checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
