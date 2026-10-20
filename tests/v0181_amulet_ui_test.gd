extends "res://tests/v0174_ui_test.gd"
const S=preload("res://tests/amulet_scenarios.gd")
const Burn=preload("res://scripts/amulet_cancel_effect.gd")
const Palette=preload("res://scripts/card_palette.gd")

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0181_AMULET_FAIL "+label)

func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0181-"+name+".png")

func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for key in ["holy_amulet","attack_amulet","magic_amulet"]:
		for actor in range(6):
			serial+=1
			var g=S.setup(key,actor,serial)
			check(S.seek(g),"amulet reaches animation "+key)
			if not Burn.supports(g.animation):continue
			var target_id:int=g.animation.target_action
			for viewer in [0,1]:
				await show_game(g,viewer)
				var fx=await pose(g,.94)
				check(fx.amulet_effect!=null,"dedicated burn renderer "+key)
				if fx.amulet_effect==null:continue
				var a=fx.amulet_effect.visual
				check(fx.cancel_target.get_meta("played_action_id")==target_id,"beam targets canceled table action")
				check(fx.launch_effect==null and fx.strike_effect==null,"no pawn shield or attack effect")
				check(fx.source_widget.motif_alpha==0,"one detached emblem")
				var holder:int=g.animation.action.actor
				var expected:Vector2=preload("res://scripts/board_layout.gd").pawn_center(holder,holder/3==viewer)+Vector2(6 if holder/3==viewer else 4,9)
				check(a.port.distance_to(expected)<.2,"physical amulet settles on right-facing chest")
				check(a.portrait.texture==preload("res://scripts/cinema/atlas.gd").texture(key),"card and moving amulet share exact art")
				check(a.burn==0 and a.beam_mat.get_shader_parameter("head")>0,"beam travels without burning early")
				check(g.animation.travel_ms==2100 and g.animation.impact_ms==2880,"approved absolute duration, without legacy rescale")
				check(fx.cancel_target.modulate.a==0 and a.face.texture!=null,"burn face replaces original card")
				check(a.area.has_point(a.hit),"impact stays inside target card")
				if actor==0 and viewer==0:await shot(key+"-travel")
			var left:Dictionary=g.snapshot(0).animation;var right:Dictionary=g.snapshot(1).animation
			left.erase("owner_slot");right.erase("owner_slot")
			check(left==right,"public event identical, sorted owner slot remains private")
			g.advance_animation()
			check(g._action(target_id).get("burned_by_amulet","")==key,"burn state survives snapshots")
			for viewer in [0,1]:
				await show_game(g,viewer)
				var fx=await pose(g,.25)
				check(fx.amulet_effect!=null,"impact rebuild retains effect")
				if fx.amulet_effect==null:continue
				var a=fx.amulet_effect.visual
				check(a.beam_mat.get_shader_parameter("tail")>0 and a.beam_mat.get_shader_parameter("head")==1 and a.burn>0,"cutoff tail advances while card burns")
				if actor==0 and viewer==0:await shot(key+"-burn")
				await pose(g,1)
				check(a.burn==1 and a.beam_mat.get_shader_parameter("strength")==0,"target fully burned and ray gone")
				check(a.port.distance_to(a.source)<.01 and not a.portrait.visible,"emblem returns without resizing")
			check(S.drain(g),"cancellation finishes")
			check(g.characters.all(func(c):return c.hp==8),"canceled spell causes no damage")
			for viewer in [0,1]:
				await show_game(g,viewer)
				var burned=meta(main,"played_action_id",target_id)
				check(burned!=null and burned.modulate.a==0,"burned card stays gone after refresh")
				check(burned.mouse_filter==Control.MOUSE_FILTER_IGNORE,"invisible slot cannot intercept clicks")
	# A declined amulet does not consume or hide the source card.
	var g=S.setup("holy_amulet",0,19001)
	check(S.drain(g,false),"declined response finishes")
	check(g.characters[1].hp==6,"declined response retains damage")
	check(g.queue.all(func(a):return not a.has("burned_by_amulet")),"declining does not mark any card burned")
	# Ordinary defense remains a pawn shield, with the blocked card still visible.
	g=H.fixture(8);g.match_id=19002;g.presentation_enabled=true
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike")},false)
	for _i in range(100):
		if g.animation.get("kind","")=="shield_block":break
		if g.phase=="targeting":g.target(g.request.team,0)
		else:check(S.step(g)=="","defense flow")
	check(not Burn.supports(g.animation),"ordinary defense excluded")
	await show_game(g);var defense=meta(main,"cinema_effect",g.animation.id)
	check(defense!=null and main.board._active_widget().modulate.a>0,"ordinary defense retains current cinema renderer and visible card")
	# Virtual table actions and the new conversion card use their own real slots.
	for spec in [["magic_amulet","magic_strike",true],["magic_amulet","cards_to_blades",false]]:
		g=S.setup(spec[0],3,19003 if spec[2] else 19004,spec[1],spec[2])
		check(S.seek(g),"virtual/new-card cancellation is animated")
		await show_game(g,0);var fx=await pose(g,.8)
		check(fx.amulet_effect!=null and fx.cancel_target.card.key==spec[1],"correct canceled virtual/new card")
		root.size=Vector2i(960,640);await frames();main._schedule_render();await frames()
		fx=await pose(g,.8)
		check(fx.amulet_effect!=null and fx.amulet_effect.visual.area.has_point(fx.amulet_effect.visual.hit),"resized viewport preserves target")
		await shot("small-"+str(spec[2]));root.size=Vector2i(1440,960);await frames()
	# Freeing an interrupted effect restores the ordinary table card and motif.
	g=S.setup("holy_amulet",0,19005);check(S.seek(g),"cleanup fixture")
	await show_game(g);var fx=await pose(g,.5);var source=fx.source_widget;var target=fx.cancel_target
	fx.queue_free();await frames()
	check(source.motif_alpha==1 and target.modulate.a==1,"interrupted effect restores display")
	print("V0181_AMULET_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames()
	quit(0 if failures==0 else 1)
