extends "res://tests/v0203_ui_test.gd"
const Cinema=preload("res://scripts/cinema/cinema.gd")

func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.sacrificeTestContinue=false;window.sacrificeTestFrame='"+name+"';")
		while not JavaScriptBridge.eval("window.sacrificeTestContinue===true"):
			await create_timer(.1).timeout
	else:root.get_texture().get_image().save_png("res://../work/card-sync-oct15/"+name+".png")

func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.25).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for ch in "-+0123456789生命":check(Cinema.FNT.has_char(ch.unicode_at(0)),"shipped font covers combat label character "+ch)
	for key in ["strike","magic_strike","triple_strike","judgment","heal"]:
		var g=H.fixture(7);serial+=1;g.match_id=serial;g.presentation_enabled=true
		if key=="judgment":g.characters[3].hp=2
		if key=="heal":g.characters[0].hp=3
		H.begin(g,{0:H.give(g,0,key)})
		if key!="heal":g.target(0,3)
		check(not g.animation.is_empty(),"effect starts "+key)
		g.advance_animation()
		check(g.animation.stage=="impact","damage and healing reach impact "+key)
		main.session.game=g;await show_game(g)
		var fx=meta(main,"cinema_effect",g.animation.id)
		check(fx!=null,"actual cinema renderer used "+key)
		if fx!=null:
			fx.set_process(false);fx.clock_started=-1;fx.present(.12)
			check(fx.stage=="impact" and fx.event.targets[0].amount>0,"positive displayed amount "+key)
		await capture("damage-"+key)
	# The real picker stays clickable while the fifth hit has not been selected.
	var g=H.fixture(7);serial+=1;g.match_id=serial
	H.give_death(g,0,"last_dance");g.characters[0].hp=0;g.characters[0].death_round=g.round_number
	H.begin(g,{})
	for id in [3,4,3,5]:g.target(0,id)
	main.session.game=g;await show_game(g)
	check(meta(main,"reselect_targets_button",true)!=null,"last dance can be reset after four selections")
	check(g.characters[3].hp==7,"four pending selections have not damaged the target")
	await capture("dance-four-targets")
	await click_widget(meta(main,"reselect_targets_button",true))
	check(g.request.selected_targets.is_empty(),"real reset button clears all targets")
	print("DESIGN_SYNC_OCT15_UI_RESULT checks=%d failures=%d"%[checks,failures])
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.sacrificeTestDone={checks:%d,failures:%d};"%[checks,failures])
	else:
		main.queue_free();await frames();quit(0 if failures==0 else 1)
