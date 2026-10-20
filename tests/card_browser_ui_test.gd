extends "res://tests/v0203_ui_test.gd"

func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/card-browser-"+name+".png")

func visible_picks()->Array:
	var grid=meta(main,"picker_grid",true)
	return grid.get_children().filter(func(n):return n.has_meta("pick_card_id") and n.visible)

func labels(node:Node)->Array:
	var result:Array=[]
	if node is Label:result.append(node.text)
	for child in node.get_children():result.append_array(labels(child))
	return result

func _run()->void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume();main.session.set_process(false)
	for viewer in [0,1]:
		var actor:int=viewer*3
		var g=H.fixture(8);serial+=1;g.match_id=serial
		for id in range(6):
			for key in ["strike",("heal" if id<3 else "heal_other"),"defense",("magic_strike" if id<3 else "precise_strike")]:H.give(g,id,key)
			H.give_death(g,id,["privilege","heart","curse","resurrection","legacy","eye"][id])
		g.characters[actor].hp=5;g.characters[actor+1].max_hp=12;g.characters[actor+1].hp=9
		main.session.game=g;await show_game(g,viewer)
		check(labels(main.board.canvas).all(func(s):return not s.begins_with("手牌 ") and not s.begins_with("已出 ") and not s.begins_with("亡语 ")),"table count labels removed")
		check(meta(main,"planning_lock_button",true).get_children().any(func(n):return n.get_script()==preload("res://scripts/art_ui/confirm_skin.gd")),"confirm uses parchment button style")
		await shot("table-"+str(viewer))
		var card:int=g.characters[actor].hand[0]
		await click_widget(hand_card(card));await create_timer(.4).timeout
		check(main.card_hover_state.is_empty() and main.board.card_hover==null,"stationary pointer after play has no stale or replacement tooltip")
		await move_mouse(staged(card).get_global_rect().get_center())
		check(meta(main,"hover_card_description",card)!=null,"moving onto played card restores hover")
		await click_widget(staged(card));await create_timer(.4).timeout
		check(main.card_hover_state.is_empty(),"return also dismisses hover until mouse moves")
		await move_mouse(Vector2(40,420));await move_mouse(hand_card(card).get_global_rect().get_center())
		check(meta(main,"hover_card_description",card)!=null,"original hand card remains readable")
		# A real deal mutates and sorts the hand while the mouse stays still.
		g.presentation_enabled=true;g._draw(g.characters[actor],2);g._pump()
		await show_game(g,viewer)
		check(g.animation.get("kind","")=="draw_cards","fixture starts production dealing animation")
		check(meta(main,"hover_card_description",card)!=null,"description survives deal start snapshot")
		await create_timer(.45).timeout
		check(meta(main,"hover_card_description",card)!=null,"moving deal widgets do not dismiss stationary reading")
		for _i in range(3):
			main._schedule_render();await frames()
			check(meta(main,"hover_card_description",card)!=null,"description survives automatic board rebuild")
		while not g.animation.is_empty():g.advance_animation();await show_game(g,viewer)
		check(meta(main,"hover_card_description",card)!=null,"description survives deal completion")
		await shot("reading-after-deal-"+str(viewer))
		await move_mouse(Vector2(40,420))
		check(main.card_hover_state.is_empty(),"real mouse departure closes retained description")
		# Explicitly opened descriptions also remain visible across later deals.
		g.phase="review";await show_game(g,viewer)
		main._inspect_hand(actor,card);await create_timer(.25).timeout
		check(meta(main,"card_description",card)!=null,"opened description appears")
		var previous_position:Vector2=meta(main,"card_description",card).position
		g._draw(g.characters[(actor+1)%3+viewer*3],1);g._pump();await show_game(g,viewer)
		check(meta(main,"card_description",card)!=null and meta(main,"card_description",card).modulate.a==1,"expanded reading stays fully visible during dealing")
		check(meta(main,"card_description",card).position==previous_position,"automatic update does not move expanded description")
		main._close_hand();await create_timer(.3).timeout
		check(main.hand_focus.is_empty(),"user can still close the retained description")
	# Cards remain readable when the animation temporarily owns the hand widgets.
	var dealing=H.fixture(8);serial+=1;dealing.match_id=serial
	var readable:int=H.give(dealing,0,"heal")
	H.give(dealing,0,"defense");dealing.presentation_enabled=true
	dealing._draw(dealing.characters[0],2);dealing._pump()
	main.session.game=dealing;await show_game(dealing)
	var animation=meta(main,"draw_animation",dealing.animation.id)
	var copy=animation.rows[0].cards.filter(func(c):return c.card.id==readable)[0]
	await move_mouse(copy.get_global_rect().get_center())
	check(meta(main,"hover_card_description",readable)!=null,"can start reading an existing card while dealing")
	await click_widget(copy);await create_timer(.25).timeout
	check(meta(main,"card_description",readable)!=null,"animated hand card opens readable details")
	dealing.advance_animation();await show_game(dealing)
	check(meta(main,"card_description",readable)!=null,"details opened during dealing survive next snapshot")
	main._close_hand();await create_timer(.3).timeout
	# Full-pile selection: sort a view copy, filter locally, retain choice and query.
	for kind in ["search","deck"]:
		var g=H.fixture(8);serial+=1;g.match_id=serial
		if kind=="search":H.begin(g,{0:H.give(g,0,"search")})
		else:
			var id:int=H.give_death(g,0,"divinity");g.characters[0].hp=0
			g._activate({"id":900,"actor":0,"card":id,"death":true,"status":"active"},0)
			g._push([{"op":"draw","target":1,"count":2},{"op":"planning"}]);g._pump()
		main.session.game=g;await show_game(g)
		check(g.request.type==kind,"real full-pile request: "+kind)
		var untouched:Array=g.deck.duplicate()
		var expected:Array=g.request.options.duplicate()
		expected.sort_custom(func(a,b):
			var ca:Dictionary=g.catalog[a];var cb:Dictionary=g.catalog[b]
			return ca.main>cb.main if ca.main!=cb.main else ca.secondary>cb.secondary)
		check(visible_picks().map(func(n):return n.card.id)==expected,"full pile sorts by main then secondary descending")
		var search=meta(main,"deck_search",true)
		check(search!=null,"search field exists in full-pile picker")
		search.grab_focus();search.text="打击";search.text_changed.emit(search.text);await frames()
		check(search.has_focus(),"typing filter keeps keyboard focus")
		check(visible_picks().size()>1 and visible_picks().all(func(n):return str(n.card.name).contains("打击")),"partial name search filters all matching copies")
		var chosen:int=visible_picks()[0].card.id
		visible_picks()[0].pressed.emit();await frames()
		check(main.pick_cards==[chosen] and meta(main,"deck_search",true).text=="打击","choice rebuild retains query and selection")
		search=meta(main,"deck_search",true);search.text="不存在的卡牌";search.text_changed.emit(search.text);await frames()
		check(visible_picks().is_empty() and meta(main,"picker_empty",true).visible,"empty results explained")
		check(meta(main,"auto_pick",true).disabled,"automatic selection never chooses a hidden non-match")
		check(main.pick_cards==[chosen],"search does not discard previously selected card")
		search.text="";search.text_changed.emit("");await frames()
		check(visible_picks().map(func(n):return n.card.id)==expected,"clearing query restores priority ordering")
		root.size=Vector2i(960,640);main._schedule_render();await frames()
		check(main.board._board_rect(meta(main,"deck_search",true)).end.x<1274,"search stays inside small-window panel")
		if kind=="deck":
			var other:int=expected.filter(func(id):return id!=chosen)[0]
			meta(main,"pick_card_id",other).pressed.emit();await frames()
			check(meta(main,"pick_card_id",chosen).selection_order==1 and meta(main,"pick_card_id",other).selection_order==2,"godhood still uses click order for multi-card selection")
		check(g.deck==untouched,"browsing and filtering never reorder actual deck")
		await shot("picker-"+kind)
		meta(main,"pick_confirm",true).pressed.emit();await frames()
		check(g.characters[0 if kind=="search" else 1].hand.has(chosen),"confirmation receives selected entity")
		check(not g.deck.has(chosen),"selected entity leaves actual deck")
		root.size=Vector2i(1200,800)
	var filtered=H.fixture(8);serial+=1;filtered.match_id=serial
	H.begin(filtered,{0:H.give(filtered,0,"search")});main.session.game=filtered;await show_game(filtered)
	var filter_input=meta(main,"deck_search",true);filter_input.text="防御";filter_input.text_changed.emit("防御");await frames()
	meta(main,"auto_pick",true).pressed.emit();await frames()
	check(filtered.catalog[filtered.characters[0].hand[0]].name=="防御","automatic selection respects current search")
	var g=H.fixture(8);serial+=1;g.match_id=serial
	H.give_death(g,0,"curse");main.session.game=g;await show_game(g)
	check(g.death_catalog[104].text.count("\n")==2 and g.snapshot(0).catalog[104].text==g.death_catalog[104].text,"wither keeps two document line breaks in both card forms")
	var death=meta(main,"death_card_id",104);await move_mouse(death.get_global_rect().get_center());await shot("wither-description")
	# Both three-digit ranks stay separate after privilege boosts.
	var boosted:int=H.give(g,1,"defense");await show_game(g)
	var face=hand_card(boosted);face.priority_bonus=100;face.queue_redraw()
	await move_mouse(Vector2(30,400));await shot("priority-boost")
	main.session.leave();await frames()
	check(main.card_hover_state.is_empty() and main.hand_focus.is_empty(),"leaving match clears descriptions")
	print("CARD_BROWSER_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
