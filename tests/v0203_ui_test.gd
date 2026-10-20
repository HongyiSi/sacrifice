extends "res://tests/v0174_ui_test.gd"
const Layout = preload("res://scripts/board_layout.gd")
const Flight = preload("res://scripts/planning_flight.gd")

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0203-"+name+".png")

func hand_card(id: int): return meta(main,"card_id",id)
func staged(id: int): return meta(main,"staged_card_id",id)
func flying(id: int): return meta(main,"planning_flight_card",id)

func move_mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at;event.global_position = at
	root.push_input(event,true)
	await frames()

func click_widget(widget: Control) -> void:
	var at := widget.get_global_rect().get_center()
	await move_mouse(at)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=at;event.global_position=at
		root.push_input(event,true)
	await frames()

func _run() -> void:
	root.size = Vector2i(1200,800)
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for viewer in [0,1]:
		var g=H.fixture(8);serial+=1;g.match_id=serial
		var actor:int=viewer*3
		var first:int=H.give(g,actor,"holy_amulet")
		var second:int=H.give(g,actor,"strike")
		for key in ["heal","defense","collect","sapphire","magic_strike","warcry"]:H.give(g,actor,key)
		main.session.game=g
		await show_game(g,viewer)
		var untouched:Dictionary=g.snapshot(1-viewer)
		for id in range(actor,actor+3):check(meta(main,"skip_plan_actor",id)==null,"skip-plan button removed")
		await move_mouse(hand_card(first).get_global_rect().get_center())
		var tooltip=meta(root,"hover_card_description",first)
		check(tooltip!=null,"hover immediately creates full card description without clicking")
		if tooltip!=null:
			check(tooltip.get_child(0).text.contains(g.catalog[first].text),"hover keeps full multiline description")
			check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(tooltip.get_global_rect()),"hover description stays in viewport")
		await shot("hover-"+str(viewer))
		await move_mouse(Vector2(30,350))
		var origin:Rect2=main.board._board_rect(hand_card(first))
		await click_widget(hand_card(first))
		check(main._selected_cards(actor)==[first] and main.hand_focus.is_empty(),"single click stages card without preview or extra button")
		check(staged(first)!=null and hand_card(first)==null,"one real copy changes location")
		var flight=flying(first)
		check(flight!=null,"play creates local flight")
		if flight!=null:
			check(main.planning_motions[first].from.is_equal_approx(origin),"flight starts at real hand position")
			check(staged(first).position.distance_to(flight.to_position)>10,"played card is visibly travelling before it settles")
		await shot("play-"+str(viewer))
		# Replace during motion: both cards move and no gameplay state is sent.
		hand_card(second).pressed.emit();await frames()
		check(main._selected_cards(actor)==[second],"click another hand card replaces previous selection")
		check(flying(first)!=null and flying(second)!=null,"replacement has simultaneous return and play flights")
		check(g.snapshot(1-viewer)==untouched and g.plans==[null,null],"planning and animation send nothing to opponent")
		check(main.board._plan_widgets(main.board.canvas,actor).size()==8,"rapid replacement never duplicates or drops a card")
		# A redraw and resize continue from the original local timestamp.
		var started:int=main.planning_motions[second].started
		root.size=Vector2i(960,640);main._schedule_render();await frames()
		check(main.planning_motions[second].started==started,"resize preserves motion clock")
		await shot("replace-"+str(viewer))
		await create_timer(.35).timeout
		check(flying(second)==null,"play animation finishes")
		check(staged(second).scale.is_equal_approx(Vector2.ONE*Layout.PLAYED_SCALE),"card finishes at shared planning and resolution size")
		await click_widget(staged(second))
		check(main._selected_cards(actor).is_empty() and hand_card(second)!=null and flying(second)!=null,"click staged card retracts with return flight")
		await shot("return-"+str(viewer))
		await create_timer(.35).timeout
		check(hand_card(second).scale.is_equal_approx(Vector2.ONE),"return restores original hand size")
		var all:Array=main.board._plan_widgets(main.board.canvas,actor)
		for widget in all:
			check(widget.position.is_equal_approx(Layout.hand_slot(widget.get_meta("hand_slot"),true)),"returned hand settles in sorted grid")
		# Empty plan locks as passing; no skip control is needed.
		meta(main,"planning_lock_button",true).pressed.emit();await frames()
		check(g.plans[viewer]==[[],[],[]],"locking an empty team plan defaults every pawn to no card")
		var before:Array=main.choices.duplicate(true)
		hand_card(first).pressed.emit();await frames()
		check(main.choices==before,"locked plan cannot be edited")
		root.size=Vector2i(1200,800)
	# Extra play allowance: append until full, then replace only the latest.
	var g=H.fixture(8);serial+=1;g.match_id=serial
	g.characters[0].extra_round=g.round_number;g.characters[0].extra_count=2
	var ids:Array=[]
	for key in ["strike","heal","defense","magic_strike"]:ids.append(H.give(g,0,key))
	main.session.game=g;await show_game(g)
	for id in ids:hand_card(id).pressed.emit();await frames()
	check(main._selected_cards(0)==[ids[0],ids[1],ids[3]],"full three-card allowance replaces latest card only")
	staged(ids[1]).pressed.emit();await frames()
	check(main._selected_cards(0)==[ids[0],ids[3]],"individual staged card can be withdrawn from multi-play")
	hand_card(ids[2]).pressed.emit();await frames()
	check(main._selected_cards(0)==[ids[0],ids[3],ids[2]],"new card fills freed allowance")
	# Switching to actual resolution cancels every local flight cleanly.
	meta(main,"planning_lock_button",true).pressed.emit();await frames()
	g.submit(1,[[],[],[]]);await show_game(g)
	check(main.planning_motions.is_empty(),"resolution clears private planning motion")
	check(flying(ids[2])==null,"local flight cannot overwrite real resolution animation")
	# Curses and dead or silenced pawns still provide descriptions without staging.
	g=H.fixture(8);serial+=1;g.match_id=serial
	var rock:int=g._generate_card(g.BOULDER);g.characters[0].hand.append(rock)
	var dead:int=H.give(g,1,"strike");g.characters[1].hp=0
	var poison:int=g._generate_card(g.POISON);g.characters[2].hand.append(poison)
	var banned:int=H.give(g,2,"strike")
	main.session.game=g;await show_game(g)
	for id in [rock,dead,banned]:hand_card(id).pressed.emit();await frames()
	check(main._plan_payload()==[[],[],[]] and main.planning_motions.is_empty(),"unplayable and dead-owner cards cannot stage or animate")
	await move_mouse(hand_card(rock).get_global_rect().get_center())
	check(meta(root,"hover_card_description",rock)!=null,"unplayable curse remains readable on hover")
	await shot("curse-hover")
	print("V0203_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames()
	quit(0 if failures==0 else 1)
