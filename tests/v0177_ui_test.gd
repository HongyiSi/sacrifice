extends "res://tests/v0174_ui_test.gd"
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0177_UI_FAIL "+label)
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0177-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false)
	var g=H.Rules.new();g.presentation_enabled=true;g.start(177)
	await show_game(g)
	check(meta(main,"draw_animation",0)==null and g.animation.is_empty(),"initial cards already dealt")
	check(meta(main,"phase_title",true).text=="出 牌 阶 段","large phase title replaces logo")
	check(meta(main,"phase_label",true).text=="第 1 回合","only round below planning title")
	await shot("opening")
	var started:int=main.phase_banner_started
	await create_timer(1.5).timeout
	check(meta(main,"phase_title",true).visible and meta(main,"phase_title",true).text=="出 牌 阶 段","title persists after illumination fades")
	main._schedule_render();await frames()
	check(main.phase_banner_started==started,"redraw never replays stage prompt")
	# Staged, locked, and resolving-unrevealed states are visibly dark.
	var id:int=g.characters[0].hand[0];main.choices[0]=id;main._schedule_render();await frames()
	var card=meta(main,"staged_card_id",id)
	check(card.self_modulate.r<.6 and not card.hidden_card,"staged own card readable but dark")
	for viewer in [0,1]:
		g=H.fixture(8);serial+=1;g.match_id=serial
		H.give_death(g,viewer*3,"blessing");H.give_death(g,viewer*3+2,"legacy")
		g.presentation_enabled=true;g.stage_presentation_enabled=true;g.resolution_presentation_enabled=true
		var chosen={}
		for actor in range(6):
			var key:String=["collect","heal","strike"][actor%3]
			chosen[actor]=H.give(g,actor,key)
			H.give(g,actor,"strike")
		H.begin(g,chosen,false);await show_game(g,viewer)
		check(meta(main,"phase_title",true).text=="结 算 阶 段","ordinary phase title")
		check(meta(main,"phase_label",true).text=="第 1 回合 · 主优先级 8","priority shown on initial cue")
		for action in g.queue:
			card=meta(main,"played_action_id",action.id)
			check(card.hidden_card==(action.actor/3!=viewer),"opponent still shows back")
			check(card.self_modulate.r<.6 if action.actor/3==viewer else card.self_modulate==Color.WHITE,"only own unrevealed faces dim")
		await create_timer(.3).timeout
		if viewer==0:await shot("priority-before-reveal")
		g.advance_animation();g.advance_animation();await show_game(g,viewer)
		await create_timer(.3).timeout
		for action in g.queue:
			card=meta(main,"played_action_id",action.id)
			if action.actor/3==viewer:check(card.self_modulate==Color.WHITE if action.revealed else card.self_modulate.r<.6,"brightness follows reveal")
		if viewer==0:await shot("revealed")
		# Phase remains stable during card intros and a target request.
		var phase_clock:int=main.phase_banner_started
		g.advance_animation();await show_game(g,viewer)
		check(main.phase_banner_started==phase_clock,"card effects and questions do not restart banner")
	# Inspect each friendly death card, including long descriptions and narrow viewport.
	for width in [1440,960]:
		root.size=Vector2i(width,width*2/3);await frames()
		for viewer in [0,1]:
			for slot in range(3):
				for key in ["blessing","pain","legacy","immortal"]:
					g=H.fixture(8);serial+=1;g.match_id=serial
					var actor:int=viewer*3+slot
					var death_id:int=H.give_death(g,actor,key)
					H.give(g,actor,"heal")
					await show_game(g,viewer)
					var original=meta(main,"death_card_id",death_id)
					var origin:Vector2=main.board._board_rect(original).position
					main._inspect_visible(original,actor);await frames();await create_timer(.25).timeout
					var lift:Dictionary=main.hand_lift
					check(not lift.is_empty(),"death card inspection exists")
					check(lift.card.position.distance_to(origin)<80 and lift.card.scale.is_equal_approx(Vector2(1.7,1.7)),"death card raises locally in .2s")
					check(lift.controls.get_child_count()==0,"death inspection never has play control")
					check(not lift.card.get_global_rect().intersects(lift.details.get_global_rect()),"description stays outside card")
					check(meta(main,"death_card_id",death_id)==lift.card,"one physical card, no duplicate")
					for pawn in range(6):
						var knight=meta(main,"knight_id",pawn)
						check(not lift.card.get_global_rect().intersects(knight.get_global_rect()),"death inspection avoids all pawns")
						check(not lift.details.get_global_rect().intersects(knight.get_global_rect()),"description avoids all pawns")
					if viewer==0 and key=="blessing" and slot==0:await shot("death-inspect-"+str(width))
					main._close_hand();await create_timer(.25).timeout;await frames()
					check(main.hand_focus.is_empty() and meta(main,"death_card_id",death_id).scale==Vector2.ONE,"death card returns exactly")
	# Normal hands retain the same nearby lift and planning-only play button.
	root.size=Vector2i(1440,960);await frames()
	g=H.fixture(8);serial+=1;g.match_id=serial;id=H.give(g,0,"heal");await show_game(g)
	main._inspect_hand(0,id);await frames();await create_timer(.25).timeout
	check(main.hand_lift.destination.distance_to(main.hand_lift.origin)<145 and main.hand_lift.controls.get_child_count()==1,"normal planning hand lift/play retained")
	main._close_hand();await create_timer(.25).timeout
	g.presentation_enabled=true;g.stage_presentation_enabled=true;H.begin(g,{},false);finish_fx(g);await show_game(g)
	check(meta(main,"phase_title",true).text=="亡 语 阶 段" and meta(main,"phase_label",true).text=="第 1 回合","death stage retained through empty review")
	await create_timer(1.5).timeout;await shot("death-stage-persistent")
	main.session.leave();await frames();check(meta(main,"phase_banner",true)==null and main.phase_banner_key=="","leave clears presentation")
	print("V0177_UI_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
