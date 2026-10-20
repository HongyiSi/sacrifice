extends "res://tests/v0203_ui_test.gd"
const AI = preload("res://scripts/local_ai.gd")

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/local-ai-"+name+".png")

func _run() -> void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main);await create_timer(.4).timeout
	main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume()
	main.session.set_process(false)
	await shot("lobby")
	var start=meta(main,"local_ai_start",true)
	check(start!=null and start.is_visible_in_tree(),"AI entry visible in normal lobby")
	check(root.get_visible_rect().encloses(start.get_global_rect()),"AI entry stays inside screen")
	main.tooltip_dialog.popup_centered(Vector2i(900,550));await frames()
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/game_rules.json"))
	for i in range(data.sections.size()):
		meta(main.tooltip_dialog,"rules_tab",i).pressed.emit();await frames()
		var body=meta(main.tooltip_dialog,"rules_body",true)
		check(body.get_parsed_text()==data.sections[i].title+"\n\n"+str(data.sections[i].text).replace("**",""),"Rules preserve source text section %d"%i)
		await shot("rules-"+str(i))
	main.tooltip_dialog.hide()
	start.pressed.emit();await frames()
	check(main.session.ai_mode and main.session.opponent_peer==0 and not main.session.online_mode,"AI starts without network peer or room")
	var g=main.session.game
	for i in range(100):
		if g.animation.is_empty():break
		g.advance_animation()
	main.session._broadcast();await frames()
	main.session.ai_next_action=0;main.session._process_ai();await frames()
	check(main.session.ai_opponent.pending!=null and g.plans[1]==null,"AI yields while evaluating instead of blocking the interface")
	for i in range(2000):
		if g.plans[1]!=null:break
		main.session.ai_next_action=0;main.session._process_ai();await process_frame
	check(g.plans[1]!=null and g.plans[0]==null,"AI independently plans while human is choosing")
	check(g.characters.all(func(c):return c.hp==7 and c.max_hp==7),"Board starts at seven HP")
	await shot("board")
	# A normal human click stages a real playable card; confirmation starts resolution.
	var c=g.characters[0]
	for id in c.hand:
		if g._can_play_hand_card(c,id):hand_card(id).pressed.emit();break
	await create_timer(.35).timeout
	meta(main,"planning_lock_button",true).pressed.emit();await frames()
	check(g.plans[0]!=null and g.phase!="planning","Human confirmation starts the shared rules engine")
	# Exercise the production session path through a whole local game, without wall-clock animation waits.
	var bot=AI.new(8);g.presentation_enabled=false
	for step in range(12000):
		if g.phase=="ended":break
		if not g.animation.is_empty():g.advance_animation();continue
		if g.phase=="review":g.advance_round();continue
		main.session._broadcast()
		var d=bot.decide(main.session.state,0)
		if not d.is_empty():main.session.act(d.kind,d.payload)
		main.session.ai_next_action=0;main.session._process_ai()
	check(g.phase=="ended","Production local session completes a game")
	check(not g.confirmed[1],"AI waits for human to request a rematch")
	var old_match=g.match_id
	main.session.act("confirm");main.session.ai_next_action=0;main.session._process_ai()
	check(g.match_id==old_match+1,"Rematch starts with the same local opponent")
	main.session.leave();await frames()
	check(not main.session.ai_mode and main.session.game==null and main.session.state.is_empty(),"Leaving local play clears the game and opponent")
	check(meta(main,"local_ai_start",true)!=null,"Leaving returns to usable lobby")
	main.session.start_ai("取消思考测试",41);g=main.session.game
	for i in range(100):
		if g.animation.is_empty():break
		g.advance_animation()
	main.session.ai_next_action=0;main.session._process_ai()
	check(main.session.ai_opponent.pending!=null,"second match begins cooperative search")
	main.session.leave();await frames()
	check(main.session.ai_opponent==null and main.session.ai_thinking_view.is_empty(),"leaving during search releases all pending work")
	print("LOCAL_AI_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
