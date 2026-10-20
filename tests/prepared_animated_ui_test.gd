extends "res://tests/v0203_ui_test.gd"

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/prepared-install-oct11/"+name+".png")

func _run() -> void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.25).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for team in [0,1]:
		var owner: int=team*3
		var g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=true
		var card: int=H.give(g,owner,"prepared")
		var old: int=H.give(g,owner,"strike")
		main.session.game=g;await show_game(g,team)
		await move_mouse(hand_card(card).get_global_rect().get_center())
		var tip=meta(main,"hover_card_description",card)
		check(tip!=null and tip.get_child(0).text.contains("摸两张牌。弃置两张牌。"),"new card description is available before playing")
		if team==0:await shot("prepared-hand")
		H.begin(g,{owner:card});finish_animations(g);await show_game(g,1-team)
		check(meta(main,"selection_panel",true)==null,"opponent cannot access discard picker")
		await show_game(g,team)
		check(meta(main,"selection_panel",true)!=null,"caster gets discard picker")
		var confirm=meta(main,"pick_confirm",true)
		check(confirm.disabled and confirm.text.begins_with("确认弃牌"),"discard confirmation is initially disabled")
		for control in main.board._all_controls(meta(main,"selection_panel",true)):
			if control is Button:check(not control.text.begins_with("跳过"),"mandatory discard has no skip button")
		await click_widget(meta(main,"pick_card_id",old))
		check(main.pick_cards==[old] and meta(main,"pick_confirm",true).disabled,"selecting just one card is insufficient")
		await click_widget(meta(main,"pick_card_id",old))
		check(main.pick_cards.is_empty(),"selected discard can be deselected")
		var drawn: int=g.request.options.back()
		await click_widget(meta(main,"pick_card_id",old))
		await click_widget(meta(main,"pick_card_id",drawn))
		check(not meta(main,"pick_confirm",true).disabled and main.pick_cards==[old,drawn],"two cards enable confirmation")
		if team==0:await shot("prepared-discard")
		await click_widget(meta(main,"pick_confirm",true))
		check(g.animation.get("op","")=="prepared_pack" and g.characters[owner].hand.has(old),"confirm starts real animation before discarding")
		finish_animations(g)
		check(g.phase=="review" and g.characters[owner].hand.size()==1 and g.discard.has(old) and g.discard.has(drawn),"real confirm dispatch discards exactly the selected cards")
	print("PREPARED_ANIMATED_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)

func finish_animations(g):
	for i in range(100):
		if g.animation.is_empty():return
		g.advance_animation()
