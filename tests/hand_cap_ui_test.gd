extends "res://tests/v0203_ui_test.gd"

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/hand-cap-"+name+".png")

func popups(node: Node) -> int:
	var count:int=1 if node is PopupPanel else 0
	for child in node.get_children(true):count+=popups(child)
	return count

func _run() -> void:
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for viewer in [0,1]:
		for dimensions in [Vector2i(1200,800),Vector2i(960,640)]:
			root.size=dimensions
			var g=H.fixture(8);serial+=1;g.match_id=serial
			var actor:int=viewer*3+(2 if dimensions.x==960 else 0)
			var obstruct:int=H.give(g,actor,"obstruct")
			var poisoning:int=H.give(g,actor,"poisoning")
			for key in ["strike","heal","defense","warcry","sapphire"]:H.give(g,actor,key)
			var poison:int=g._generate_card(g.POISON);g.characters[actor].hand.append(poison);g.defiled_cards[poison]=true
			H.give(g,(1-viewer)*3,"strike")
			main.session.game=g;await show_game(g,viewer)
			for id in [obstruct,poisoning,poison]:
				await move_mouse(hand_card(id).get_global_rect().get_center())
				await create_timer(.85).timeout
				var popup=meta(root,"hover_card_description",id)
				check(popup!=null,"hover shows one immediate readable description")
				check(popups(root)==0,"hover past native delay creates no blank native popup")
				check(hand_card(id)._make_custom_tooltip("")==null,"stale native callback cannot create an empty frame")
				if popup!=null:
					check(Rect2(Vector2.ZERO,main.board.BASE).encloses(main.board._board_rect(popup)),"whole description and references stay inside viewport: viewer=%d requested=%s actual=%s rect=%s"%[viewer,dimensions,root.size,popup.get_global_rect()])
					if id!=poison:
						var key:String="boulder" if id==obstruct else "poison"
						var face=meta(popup,"reference_card_key",key)
						var text=meta(popup,"reference_description_key",key)
						check(face!=null and text!=null,"associated curse face and full description are adjacent")
						check(text.text.contains(g.POISON.text if key=="poison" else g.BOULDER.text),"reference retains all printed line breaks")
						check(face.mouse_filter==Control.MOUSE_FILTER_IGNORE,"reference card never intercepts a play click")
					await shot("hover-%d-%d-%s"%[viewer,dimensions.x,g.catalog[id].key])
			await move_mouse(Vector2(20,400))
			check(meta(root,"hover_card_description",poison)==null,"leaving card removes its description")
			main._inspect_hand(actor,poisoning);await frames();await create_timer(.25).timeout
			var details=meta(root,"card_description",poisoning)
			check(meta(details,"reference_card_key","poison")!=null,"expanded inspection also shows referenced card")
			check(Rect2(Vector2.ZERO,main.board.BASE).encloses(main.board._board_rect(details)),"expanded reference panel stays inside viewport")
			await shot("inspect-%d-%d"%[viewer,dimensions.x])
			main._close_hand();await create_timer(.3).timeout;await frames()
	# Base card position and scale match across phases for every own pawn.
	for viewer in [0,1]:
		root.size=Vector2i(1200,800)
		var g=H.fixture(8);serial+=1;g.match_id=serial
		var ids:Array=[]
		for actor in range(viewer*3,viewer*3+3):ids.append(H.give(g,actor,"strike"))
		main.session.game=g;await show_game(g,viewer)
		for id in ids:hand_card(id).pressed.emit();await frames()
		await create_timer(.35).timeout
		var positions:Array=[]
		var bar=meta(main,"planning_bar",true)
		check(main.board._board_rect(bar).position.y==Layout.PLANNING_BAR_Y,"lock panel moves down with played row")
		for id in ids:
			positions.append(main.board._board_rect(staged(id)))
			check(positions[-1].position.y>main.board._board_rect(bar).end.y,"own played cards stay below lock panel")
		await shot("planning-"+str(viewer))
		g.presentation_enabled=true;g.stage_presentation_enabled=true
		g.submit(viewer,main._plan_payload());g.submit(1-viewer,[[],[],[]]);await show_game(g,viewer)
		for i in range(ids.size()):
			var widget=meta(main,"played_action_id",H.action_for(g,viewer*3+i).id)
			check(widget!=null and main.board._board_rect(widget).is_equal_approx(positions[i]),"locking preserves card position and size")
		await shot("resolution-"+str(viewer))
	# Gift picker numbering describes exactly which card is offered first.
	var g=H.fixture(8);serial+=1;g.match_id=serial
	var first:int=H.give(g,0,"heal");var second:int=H.give(g,0,"defense")
	H.begin(g,{0:H.give(g,0,"gift")});g.target(0,3)
	main.session.game=g;await show_game(g)
	meta(main,"pick_card_id",second).pressed.emit();await frames()
	meta(main,"pick_card_id",first).pressed.emit();await frames()
	check(meta(main,"pick_card_id",second).selection_order==1 and meta(main,"pick_card_id",first).selection_order==2,"gift picker numbers selection order")
	await shot("gift-order")
	print("HAND_CAP_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
