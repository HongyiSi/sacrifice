extends "res://tests/v0203_ui_test.gd"
const Outline=preload("res://scripts/target_outline.gd")
const Staging=preload("res://scripts/discard_staging.gd")
const Layout2=preload("res://scripts/board_layout.gd")

func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/target-blade-"+name+".png")

func show(g,viewer:int=0)->void:
	main.session.game=g
	await show_game(g,viewer)
	await frames()

func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume()
	var g=H.fixture(7);g.match_id=5601
	var hand=H.give(g,0,"strike");H.give(g,0,"spare_food");H.give_death(g,0,"ghost")
	g.characters[4].hp=0;H.begin(g,{2:H.give(g,2,"obstruct")})
	await show(g)
	for id in range(6):
		var outline=meta(main,"target_outline",id)
		check(outline!=null and not outline.paths.is_empty(),"compressed pawn atlas yields visible contour %d"%id)
		check(outline.paths[0].size()>15,"outline follows alpha silhouette %d"%id)
		outline.set_process(false);outline.stroke_width=Outline.width_at(.75,false);outline.queue_redraw()
	await shot("targets")
	for id in range(6):meta(main,"target_outline",id).set_process(true)
	check(is_equal_approx(Outline.width_at(0,false),Outline.MIN_WIDTH) and is_equal_approx(Outline.width_at(1.5,false),Outline.MIN_WIDTH),"pulse keeps 1.5-second period")
	check(is_equal_approx(Outline.width_at(.75,false),2.94),"pulse maximum keeps previously reduced width")
	await move_mouse(meta(main,"knight_id",3).get_global_rect().get_center())
	var edge=meta(main,"target_outline",3)
	check(edge.hovered and is_equal_approx(edge.stroke_width,Outline.HOVER_WIDTH),"hover fixes thicker silhouette")
	await create_timer(.2).timeout
	check(is_equal_approx(edge.stroke_width,Outline.HOVER_WIDTH),"hover width remains constant")
	await shot("hover")
	await move_mouse(Vector2(40,400))
	check(not edge.hovered and edge.stroke_width<=Outline.MAX_WIDTH,"leaving resumes breathing")
	# Read-only cards keep hover descriptions, but clicking does not lift or pin them.
	var widget=hand_card(hand);var origin=widget.position
	await move_mouse(widget.get_global_rect().get_center())
	check(meta(root,"hover_card_description",hand)!=null,"hover description remains available")
	widget.pressed.emit();await create_timer(.3).timeout
	check(main.hand_focus.is_empty() and main.hand_lift.is_empty() and hand_card(hand).position==origin,"resolution hand click has no legacy popup or lift")
	check(not hand_card(hand).expanded,"read-only hand stays unexpanded")
	main.board._active_widget().pressed.emit()
	meta(main,"death_card_id",g.characters[0].deathrattles[0]).pressed.emit();await frames()
	check(main.hand_focus.is_empty(),"read-only played and death cards also use hover only")
	# The explicit details button still works, without changing the hand-click policy.
	meta(main,"show_card_button",true).pressed.emit();await frames()
	check(not main.hand_focus.is_empty(),"explicit view-effect button remains usable")
	main._close_hand();await create_timer(.3).timeout
	await show(g,1)
	for id in range(6):check(meta(main,"target_outline",id)==null,"waiting side has no legal-target highlight")
	root.size=Vector2i(960,640);await show(g);await shot("small")
	check(not meta(main,"target_outline",4).paths.is_empty(),"dead target still outlined at small viewport")
	root.size=Vector2i(1440,960)
	# Locked, dead, and unplayable planning cards cannot open the old preview either.
	g=H.fixture(7);g.match_id=5602;var ordinary=H.give(g,0,"strike");var spare=H.give(g,1,"spare_food");var dead=H.give(g,2,"heal");g.characters[2].hp=0
	await show(g)
	hand_card(spare).pressed.emit();hand_card(dead).pressed.emit();await frames()
	check(main.hand_focus.is_empty() and main._plan_payload()==[[],[],[]],"unplayable and dead-owner cards do nothing on click")
	hand_card(ordinary).pressed.emit();await frames()
	check(main._selected_cards(0)==[ordinary],"legal card still plays on click")
	staged(ordinary).pressed.emit();await frames()
	check(main._selected_cards(0).is_empty(),"staged card still retracts on click")
	g.submit(0,[[],[],[]]);await show(g)
	hand_card(ordinary).pressed.emit();await frames()
	check(main.hand_focus.is_empty() and main._selected_cards(0).is_empty(),"confirmed hand remains inert")
	# Morph preview keeps original positions; reserve animations cannot appear first.
	g=H.fixture(7);g.match_id=5603;g.characters[0].hp=2
	for key in ["spare_food","spare_supplies","strike"]:H.give(g,0,key)
	var rock=g._generate_card(g.BOULDER);g.characters[0].hand.append(rock)
	H.begin(g,{0:H.give(g,0,"cards_to_blades")});g.presentation_enabled=true
	for viewer in [0,1]:
		await show(g,viewer)
		var prep=meta(main,"blade_preparation",true)
		check(prep!=null and prep.cards.size()==4,"original hand continuously visible while aiming")
		for i in range(prep.cards.size()):check(prep.cards[i].position==Layout2.hand_position(0,i,viewer==0),"original card stays in hand slot")
		check(g.snapshot(viewer).staged_discards.is_empty(),"no premature reserve tray")
		await shot("blade-prepare-"+str(viewer))
	g.target(0,3)
	for viewer in [0,1]:
		await show(g,viewer)
		var fx=meta(main,"blade_volley_animation",g.animation.id)
		check(fx!=null and fx.cards.size()==4,"volley uses original hand, not a refilled one")
		fx.set_process(false);fx.clock_started=-1;fx.elapsed=.32;fx._process(0)
		await shot("blade-morph-"+str(viewer))
	for i in range(4):g.advance_animation()
	await show(g)
	check(g.animation.get("style","")=="spare_food","food animation follows the completed volley")
	check(meta(main,"blade_preparation",true)==null and meta(main,"blade_volley_animation",g.animation.id)==null,"old hand cannot return during reserve effects")
	await shot("reserve-after-blades")
	print("TARGET_BLADE_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
