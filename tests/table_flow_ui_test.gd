extends "res://tests/v0203_ui_test.gd"
const Flip=preload("res://scripts/card_reveal.gd")

func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/table-flow-"+name+".png")

func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume();main.session.set_process(false)
	await _opening_after_slow_load()
	for viewer in [0,1]:
		var g=H.fixture(8);serial+=1;g.match_id=serial
		var actor:int=viewer*3
		var card:int=H.give(g,actor,"strike")
		H.give(g,actor+1,"heal");H.give(g,actor+2,"poisoning")
		for id in range(6):H.give_death(g,id,["privilege","heart","legacy","curse","blessing","eye"][id])
		g.characters[actor].hp=5;g.characters[actor+1].max_hp=12;g.characters[actor+1].hp=9
		main.session.game=g;await show_game(g,viewer)
		check(meta(main,"planning_bar",true)==null,"central played-count bar removed")
		var pile=meta(main,"draw_pile",true)
		check(main.board._board_rect(pile)==Layout.DECK_RECT,"pile occupies left position")
		var confirm=meta(main,"planning_lock_button",true)
		check(confirm.text=="确认出牌" and main.board._board_rect(confirm)==Layout.CONFIRM_RECT,"confirmation occupies old pile position")
		await click_widget(hand_card(card));await create_timer(.35).timeout
		check(not staged(card).hidden_card and staged(card).self_modulate==Color.WHITE,"staged face remains bright")
		await shot("planning-"+str(viewer))
		confirm=meta(main,"planning_lock_button",true);confirm.pressed.emit();await frames()
		check(meta(main,"planning_lock_button",true).text=="取消确认","confirmed player may cancel")
		check(not staged(card).hidden_card and staged(card).self_modulate==Color.WHITE,"waiting for opponent keeps face visible")
		meta(main,"planning_lock_button",true).pressed.emit();await frames()
		check(not g.snapshot(viewer).ready[viewer],"cancel reopens editing")
		g.presentation_enabled=true;g.stage_presentation_enabled=true;g.resolution_presentation_enabled=true
		meta(main,"planning_lock_button",true).pressed.emit();await frames()
		g.submit(1-viewer,[[],[],[]]);await show_game(g,viewer)
		var action_id:int=H.action_for(g,actor).id
		var fx=meta(main,"card_conceal_action",action_id)
		check(fx!=null,"resolution starts a real front-to-back flip")
		if fx!=null:
			check(not fx.initial_hidden and not fx.final_hidden and fx.final_tint==Flip.UNREVEALED_TINT,"owner flip ends on a dim readable face")
			check(fx.initial_view.get_child(0).self_modulate==Color.WHITE,"flip begins at full face brightness")
			fx.set_process(false);fx.set_progress(.32)
			var started:int=fx.started_ms
			var cue=meta(main,"center_phase_title","resolution")
			check(cue!=null and cue.tint==Layout.PHASE_COLORS.resolution,"central resolution text matches header tint")
			if cue!=null:cue.started=Time.get_ticks_msec()-400;cue._process(0);cue.set_process(false)
			main._schedule_render();await frames()
			fx=meta(main,"card_conceal_action",action_id)
			check(fx!=null and fx.started_ms==started,"rebuild continues original conceal clock")
			if fx!=null:
				fx.set_process(false);fx.set_progress(.32)
				await shot("conceal-"+str(viewer))
				var source=fx.source;fx.started_ms=Time.get_ticks_msec()-700;fx._process(0);await frames()
				check(source.visible and not source.hidden_card and source.self_modulate==Flip.UNREVEALED_TINT,"conceal ends with one dim owner face")
		# Moving to the priority reveal flips the same card back to its face.
		for _i in range(30):
			if g.animation.get("kind","")=="card_reveal":break
			if not g.animation.is_empty():g.advance_animation()
		check(g.animation.get("kind","")=="card_reveal","normal reveal still occurs")
		await show_game(g,viewer)
		fx=meta(main,"card_reveal_action",action_id)
		check(fx!=null and not fx.initial_hidden and not fx.final_hidden and fx.initial_view.get_child(0).self_modulate==Flip.UNREVEALED_TINT,"owner priority reveal goes from dim to bright face")
		if fx!=null:
			fx.set_process(false);fx.set_progress(.7)
		await shot("reveal-"+str(viewer))
	# All announcement titles, exact stage colours and scalable central text.
	var g=H.fixture(8);serial+=1;g.match_id=serial;main.session.game=g
	for stage in ["start","planning","resolution","death"]:
		g.animation=g._stage_event(stage,-1,true);g.animation.id=100+serial;serial+=1;g.phase="animating"
		root.size=Vector2i(960,640) if stage=="death" else Vector2i(1440,960)
		await show_game(g)
		var cue=meta(main,"center_phase_title",stage)
		check(cue!=null and cue.title==Layout.PHASE_TITLES[stage],"stage announces "+stage)
		if cue!=null:
			cue.started=Time.get_ticks_msec()-500;cue._process(0);cue.set_process(false)
			check(cue.UI.CREAM==meta(main,"phase_title",true).get_theme_color("font_color"),"header and center use the approved ivory text")
			await shot("title-"+stage)
			cue.started=Time.get_ticks_msec()-1600;cue._process(0)
			check(not cue.visible,"stage text fades after its duration")
	# Draw / collect use the actual relocated pile.
	check(preload("res://scripts/draw_animation.gd").DECK==Layout.DECK_CENTER and preload("res://scripts/collect_launch.gd").DECK==Layout.DECK_CENTER,"draw and collect share new pile origin")
	print("TABLE_FLOW_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)

func _opening_after_slow_load() -> void:
	# Simulate texture loading taking longer than the incoming opening cue.
	for host in [false,true]:
		var g=H.Rules.new();g.presentation_enabled=true;g.start(82008)
		serial+=1;g.match_id=serial
		main.session.game=g;main.session.hosting=host
		var stamp:String=main.session._animation_stamp(g.snapshot(0))
		main.session.received_animation_key=stamp
		main.session.received_animation_started=Time.get_ticks_msec()-3000
		main.session.animation_key=stamp
		main.session.animation_started=Time.get_ticks_msec()-3000
		await show_game(g)
		var cue=meta(main,"center_phase_title","start")
		check(cue!=null and cue.visible,"slow first load still displays game-start announcement")
		if cue==null:continue
		var started:int=cue.started
		check(Time.get_ticks_msec()-started<1000,"opening starts when board becomes visible")
		if host:
			check(main.session.animation_started==started,"host waits for visible opening before advancing")
		else:
			g.advance_animation();main.session._receive_view(g.snapshot(0))
			check(main.session.state.animation.stage=="travel","queued server update cannot immediately dismiss opening")
		main._schedule_render();await frames()
		cue=meta(main,"center_phase_title","start")
		check(cue!=null and cue.started==started,"rebuilding the board does not restart opening")
		main.session.received_views.clear()
	main.session.hosting=false
	main.session.received_animation_key=""
