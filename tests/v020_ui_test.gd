extends "res://tests/v0174_ui_test.gd"

func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v020-"+name+".png")

func find_text(node:Node,text:String):
	if node is Label or node is RichTextLabel or node is Button:
		if node.text == text:return node
	for child in node.get_children():
		var found=find_text(child,text)
		if found!=null:return found
	return null

func _run()->void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main)
	await create_timer(.3).timeout;main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for key in H.Rules.AMULETS + ["poison","sapphire"]:
		var g=H.fixture(8);serial+=1;g.match_id=serial
		var id:int=g._generate_card(g.POISON) if key=="poison" else H.give(g,0,key)
		if key=="poison":g.characters[0].hand.append(id)
		await show_game(g)
		main._inspect_hand(0,id);await frames();await create_timer(.3).timeout
		var details=meta(main,"card_description",id)
		check(details!=null,"card detail visible "+key)
		if details!=null:
			var body=find_text(details,g.catalog[id].text)
			check(body!=null and body.text.contains("\n"),"literal document line break reaches description label "+key)
			check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(details.get_global_rect()),"multiline description fits screen "+key)
			if key=="poison":check(find_text(details,"诅咒牌 · 优先级 0/0")!=null,"curse category is visible")
		await shot(key+"-description")
		if key in H.Rules.AMULETS:
			meta(main,"play_card_id",id).pressed.emit();await frames()
			check(main._selected_cards(0).has(id) and not main.guard_dialog.visible,"amulet plays without obsolete pretarget dialog")
		main.hand_focus.clear();await frames()
	# Selection overlay and actual click/confirm wiring for plunder.
	for viewer in [0,1]:
		var g=H.fixture(8);serial+=1;g.match_id=serial
		var actor:int=viewer*3;var target:int=(1-viewer)*3
		var wanted:int=H.give(g,target,"strike");H.give(g,target,"heal")
		H.begin(g,{actor:H.give(g,actor,"plunder")});g.target(viewer,target)
		main.session.game=g
		await show_game(g,viewer)
		check(meta(main,"selection_panel",true)!=null,"plunder private picker rendered for controller")
		var pick=meta(main,"pick_card_id",wanted);check(pick!=null,"exact desired hand card selectable")
		pick.pressed.emit();await frames()
		var confirm=meta(main,"pick_confirm",true)
		check(not confirm.disabled and confirm.text.begins_with("确认掠夺"),"plunder confirm enables after selecting one")
		await shot("plunder-"+str(viewer))
		# Dispatch through UI, session and host action validation.
		confirm.pressed.emit();await frames()
		check(g.characters[actor].hand.has(wanted),"plunder UI action transfers chosen card")
	# Both perspectives receive a usable hand-amulet button; opponent sees no ID.
	for viewer in [0,1]:
		var g=H.fixture(8);serial+=1;g.match_id=serial
		var actor:int=(1-viewer)*3;var holder:int=viewer*3
		var guard:int=H.give(g,holder,"holy_amulet")
		H.begin(g,{actor:H.give(g,actor,"strike")});g.target(1-viewer,holder)
		main.session.game=g
		await show_game(g,1-viewer)
		check(find_text(main,"使用神圣护符 · 取消效果")==null,"enemy has no private response button")
		await show_game(g,viewer)
		var button=find_text(main,"使用神圣护符 · 取消效果")
		check(button!=null,"holder receives in-hand response button")
		await shot("amulet-response-"+str(viewer))
		button.pressed.emit();await frames()
		check(g.characters[holder].hp==8 and g.discard.has(guard),"response UI dispatches physical hand ID")
	root.size=Vector2i(960,640)
	var g=H.fixture(8);serial+=1;g.match_id=serial
	var id:int=H.give(g,0,"holy_amulet")
	await show_game(g);main._inspect_hand(0,id);await frames();await create_timer(.3).timeout
	var details=meta(main,"card_description",id)
	check(details!=null and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(details.get_global_rect()),"long amulet fits minimum viewport")
	await shot("small-multiline")
	print("V020_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames()
	quit(0 if failures==0 else 1)
