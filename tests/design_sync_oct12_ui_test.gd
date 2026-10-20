extends "res://tests/v0203_ui_test.gd"

func _run() -> void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.25).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for team in [0,1]:
		var owner=team*3
		var g=H.fixture(8);serial+=1;g.match_id=serial
		var card=H.give(g,owner,"strike")
		var keep=H.give(g,owner,"defense")
		H.give_death(g,owner+2,"legacy")
		g.characters[owner+2].hp=0;g.characters[owner+2].death_round=g.round_number
		H.begin(g,{})
		main.session.game=g;await show_game(g,1-team)
		check(meta(main,"selection_panel",true)==null,"opponent has no legacy discard controls")
		await show_game(g,team)
		var confirm=meta(main,"pick_confirm",true)
		check(confirm!=null and not confirm.disabled and confirm.text=="确认弃置 0 张并补牌","zero-card confirmation is available and clearly labeled")
		await click_widget(meta(main,"pick_card_id",card))
		check(main.pick_cards==[card] and not meta(main,"pick_confirm",true).disabled,"partial selection is valid")
		await click_widget(meta(main,"pick_card_id",card))
		check(main.pick_cards.is_empty() and not meta(main,"pick_confirm",true).disabled,"deselecting returns to valid zero choice")
		await click_widget(meta(main,"pick_card_id",card))
		await click_widget(meta(main,"pick_confirm",true))
		check(g.phase=="review" and g.characters[owner].hand.size()==8 and g.characters[owner].hand.has(keep) and g.discard.has(card),"real UI dispatch discards chosen card and refills both living teammates")
		# Reuse the same real UI with no discards selected.
		g=H.fixture(8);serial+=1;g.match_id=serial
		keep=H.give(g,owner,"strike")
		H.give_death(g,owner+2,"legacy")
		g.characters[owner+2].hp=0;g.characters[owner+2].death_round=g.round_number
		H.begin(g,{})
		main.session.game=g;await show_game(g,team)
		await click_widget(meta(main,"pick_confirm",true))
		check(g.phase=="review" and g.characters[owner].hand.size()==8 and g.characters[owner].hand.has(keep),"zero-card button keeps existing cards and completes legacy")
	print("DESIGN_SYNC_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
