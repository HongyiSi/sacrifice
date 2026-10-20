extends "res://tests/v0203_ui_test.gd"
var out="res://../work/prophecy-occlusion-oct15/"
var baseline=false
var sheet:Image
var tile=0
func capture_piece(rect:Rect2i,name:String)->void:
	await RenderingServer.frame_post_draw
	var img=root.get_texture().get_image()
	img.save_png(out+name+".png")
	var crop=img.get_region(rect)
	crop.resize(400,300,Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(crop,Rect2i(0,0,400,300),Vector2i((tile%4)*400,(tile/4)*300));tile+=1
func _run()->void:
	baseline=OS.get_cmdline_user_args().has("--baseline")
	out+="before-" if baseline else "after-"
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.set_level(0);main.attack_audio.level=0
	sheet=Image.create(1600,900,false,Image.FORMAT_RGBA8)
	var g=H.fixture(7);g.presentation_enabled=true;g.match_id=150060
	H.give(g,0,"strike");g._draw(g.characters[0],1);g._pump()
	await show_game(g,0)
	var fx=meta(main,"draw_animation",g.animation.id)
	check(fx!=null,"real deal animation exists")
	fx.set_process(false);fx.clock_started=-1
	var flight=fx.flights[0]
	for progress in [.0,.04,.07,.10,.13,.16,.19,.22,.25,.30,.38,.50]:
		fx.elapsed=flight.started+flight.duration*progress;fx._process(0)
		await capture_piece(Rect2i(0,250,340,255),"chest-"+str(progress))
	sheet.save_png(out+"chest-sheet.png");tile=0
	sheet=Image.create(1600,900,false,Image.FORMAT_RGBA8)
	g=H.fixture(7);g.presentation_enabled=true;g.match_id=150061
	var played=H.give(g,0,"prepared");H.give(g,0,"strike");H.give(g,0,"heal")
	H.begin(g,{0:played},false)
	for i in range(20):
		if g.animation.get("prepared_draw",false):break
		g.advance_animation()
	await show_game(g,0)
	fx=meta(main,"prepared_effect","draw")
	check(fx!=null,"real prepared draw animation exists")
	fx.set_process(false);fx.clock_started=-1
	for age in [2.64,2.73,2.78,2.83,2.88,2.93,3.0,3.08,5.20,5.30,5.40,5.51]:
		fx.present(age-2.)
		var center:Vector2=fx.bag.position
		await capture_piece(Rect2i(Vector2i(center)-Vector2i(120,140),Vector2i(240,180)),"bag-"+str(age))
	sheet.save_png(out+"bag-sheet.png")
	if not baseline:
		fx.present(.93)
		await verify_bag_lip(fx)
		# Reuse the same real effect after confirming discards: the incoming and
		# outgoing legs must use the same foreground lip.
		finish_fx(g)
		check(g.pick(0,g.request.options.slice(0,2))=="","real prepared discard accepted")
		await show_game(g,0);fx=meta(main,"prepared_effect","pack")
		fx.set_process(false);fx.clock_started=-1;fx.present(.96)
		await verify_bag_lip(fx)
		await capture_piece(Rect2i(Vector2i(fx.bag.position)-Vector2i(120,140),Vector2i(240,180)),"bag-pack")
		await identity_and_choices()
	print("OCCLUSION_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)

func verify_bag_lip(fx):
	await frames()
	await RenderingServer.frame_post_draw
	var visible_image=root.get_texture().get_image()
	var hidden=[]
	for f in fx.incoming+fx.outgoing:
		if f.node.visible:hidden.append(f.node);f.node.hide()
	await frames()
	await RenderingServer.frame_post_draw
	var empty_image=root.get_texture().get_image()
	for q in [Vector2(.44,.400),Vector2(.48,.402),Vector2(.52,.401),Vector2(.56,.397)]:
		var p:Vector2i=Vector2i(fx.bag.get_global_transform_with_canvas()*((q-Vector2(.5,.5))*fx.bag.side))
		# Imported texture filtering/alpha may shift a color by 1–2 levels.
		var diff=visible_image.get_pixelv(p)-empty_image.get_pixelv(p)
		check(maxf(absf(diff.r),maxf(absf(diff.g),absf(diff.b)))<=3./255.,"card cannot paint over the leather lip")
	for n in hidden:n.show()

func identity_and_choices():
	var expected=["blue_sword","blue_shield","blue_mage","red_spear","red_axe","red_archer"]
	for owner_team in [0,1]:
		var g=H.fixture(7);g.match_id=150070+owner_team
		g.characters[4].hp=0
		for actor in [owner_team*3]:
			var death=H.give_death(g,actor,"divinity")
			g._activate({"actor":actor,"card":death},actor)
		H.begin(g,{owner_team*3:H.give(g,owner_team*3,"obstruct")})
		for viewer in [0,1]:
			main.session.game=g;await show_game(g,viewer)
			for id in range(6):
				var pawn=meta(main,"knight_id",id)
				var sprite=meta(pawn,"pawn_art",expected[id])
				check(sprite!=null and sprite.texture==main.board.texture(expected[id]),"same actor keeps same actual texture in both viewpoints")
				var outline=meta(pawn,"target_outline",id)
				check((outline!=null and not outline.paths.is_empty()) if viewer==owner_team else outline==null,"target silhouettes remain interactive only for acting player")
				if id==owner_team*3:check(meta(pawn,"divinity_actor",id).red==(id==3),"divinity art belongs to fixed team")
				if id==4:check(sprite.modulate.a<1,"dead pawn retains dimming")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"view-%d-%d.png"%[owner_team,viewer])
		# Both desktop and a small mobile-sized window expose all ten buttons.
		for window in [Vector2i(1440,960),Vector2i(926,428)]:
			root.size=window;await frames()
			g=H.fixture(7);serial+=1;g.match_id=serial
			g.characters[owner_team*3].max_hp=10;g.characters[owner_team*3].hp=10
			H.begin(g,{owner_team*3:H.give(g,owner_team*3,"prophecy")})
			main.session.game=g;await show_game(g,owner_team)
			var buttons=[];var footer=meta(main,"skip_effect_button",true).get_global_rect()
			for value in range(1,11):
				var b=meta(main,"priority_choice",value)
				check(b!=null and not b.disabled,"prophecy number button enabled")
				check(Rect2(Vector2.ZERO,Vector2(1440,960)).encloses(main.board._board_rect(b)) and not b.get_global_rect().intersects(footer),"number button fits the logical board without overlapping footer")
				for previous in buttons:check(not b.get_global_rect().intersects(previous.get_global_rect()),"number buttons never overlap")
				buttons.append(b)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"prophecy-%d-%d.png"%[owner_team,window.x])
			await click_widget(meta(main,"priority_choice",10))
			check(g.badges[owner_team]==1,"clicking actual 10 button awards matching prediction")
		root.size=Vector2i(1440,960);await frames()
