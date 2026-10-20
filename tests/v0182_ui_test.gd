extends "res://tests/v0174_ui_test.gd"
const Layout = preload("res://scripts/board_layout.gd")
const Outline = preload("res://scripts/target_outline.gd")
const Card = preload("res://scripts/card_widget.gd")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V0182_UI_FAIL "+label)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0182-"+name+".png")

func move_mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	root.push_input(event)
	await frames()

func populated(count: int):
	var g = H.fixture(8)
	serial += 1; g.match_id = serial
	for id in range(6):
		g._draw(g.characters[id],count)
		H.give_death(g,id,["resurrection","legacy","pain","divinity","immortal","heart"][id])
	return g

func verify_grid() -> void:
	for id in range(6):
		var friendly: bool = id/3 == main.session.team
		var slots = meta(main,"hand_slots_actor",id)
		var hand = meta(main,"hand_actor" if friendly else "enemy_hand_actor",id)
		check(slots != null and hand != null,"persistent slots exist for pawn %d" % id)
		check(slots.mouse_filter == Control.MOUSE_FILTER_IGNORE,"slot outlines do not intercept cards")
		var cards: Array = hand.get_children().filter(func(c): return c is Card)
		check(cards.size() == 8,"eight visible hand cards %d" % id)
		for i in range(8):
			check(cards[i].position.is_equal_approx(Layout.hand_slot(i,friendly)),"four columns and two rows %d/%d" % [id,i])
			var bounds: Rect2 = main.board._board_rect(cards[i])
			check(Rect2(0,0,1440,960).encloses(bounds),"hand card stays inside canvas")
			if i > 0: check(not bounds.intersects(main.board._board_rect(cards[i-1])),"adjacent hand cards never overlap")
		check(not hand.get_global_rect().intersects(meta(main,"knight_id",id).get_global_rect()),"hand clears pawn %d" % id)
		check(not hand.get_global_rect().intersects(meta(main,"health_actor",id).get_global_rect()),"hand clears health %d" % id)
	var bar = meta(main,"planning_bar",true)
	check(bar != null and bar.get_global_rect().position.y > meta(main,"health_actor",(1-main.session.team)*3).get_global_rect().end.y and bar.get_global_rect().end.y < meta(main,"played_actor",main.session.team*3).get_global_rect().position.y,"planning bar separates opposing pawns from friendly played cards")

func _run() -> void:
	root.size = Vector2i(1440,960)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(.4).timeout
	main.music.set_level(0)
	var g = populated(4)
	await show_game(g)
	await shot("four-cards-slots")
	g = populated(8)
	await show_game(g)
	verify_grid()
	await shot("eight-cards")
	var hand = meta(main,"hand_actor",0)
	var second_row = hand.get_child(7)
	var second_row_id: int = second_row.card.id
	second_row.pressed.emit(); await frames(); await create_timer(.3).timeout
	check(main._selected_cards(0)==[second_row_id] and main.hand_focus.is_empty(),"eighth card plays directly")
	check(meta(main,"staged_card_id",second_row_id)!=null,"second-row card reaches played slot")
	check(Rect2(0,0,1440,960).encloses(main.board._board_rect(meta(main,"staged_card_id",second_row_id))),"second-row played card stays on screen")
	await shot("second-row-played")
	meta(main,"staged_card_id",second_row_id).pressed.emit();await frames();await create_timer(.35).timeout
	main.choices = [g.characters[0].hand[0],g.characters[1].hand[0],g.characters[2].hand[0]]
	main._schedule_render(); await frames()
	var bar = meta(main,"planning_bar",true)
	for id in range(3):
		var zone = meta(main,"played_actor",id)
		check(zone.get_global_rect().position.y > bar.get_global_rect().end.y and zone.get_global_rect().end.y < meta(main,"pawn_title",id).get_global_rect().position.y,"staged cards stay below lock bar and above their pawn's name")
	await shot("staged")
	main.choices = [0,0,0]
	root.size = Vector2i(960,640)
	await show_game(g)
	verify_grid(); await shot("eight-small")
	root.size = Vector2i(1440,960)
	# Ordinary strikes allow both sides, including dead pawns.
	g = populated(4)
	g.characters[4].hp = 0
	H.begin(g,{0:H.give(g,0,"strike")})
	await show_game(g)
	await create_timer(.35).timeout
	var skip = meta(main,"skip_effect_button",true)
	var details = meta(main,"show_card_button",true)
	check(not meta(main,"decision_panel",true).get_global_rect().intersects(main.board._active_widget().get_global_rect()),"decision panel clears the settled active card")
	check(skip != null and details != null,"both decision buttons exist")
	check(is_equal_approx(skip.position.y,details.position.y) and skip.position.x+skip.size.x <= details.position.x,"skip and details share one row without overlap")
	var tint: Color = skip.get_theme_stylebox("normal").bg_color
	check(tint.r > tint.g*1.5 and tint.r > tint.b*1.5,"skip button has red fill")
	for id in range(6):
		var outline = meta(main,"target_outline",id)
		check(outline != null and not outline.paths.is_empty(),"all legal pawns have silhouette contours %d" % id)
		check(outline.paths[0].size() > 15,"outline follows artwork instead of a rectangle")
	check(is_equal_approx(Outline.width_at(0,false),Outline.MIN_WIDTH),"pulse starts thin")
	check(is_equal_approx(Outline.width_at(.75,false),Outline.MAX_WIDTH),"half period reaches maximum")
	check(is_equal_approx(Outline.width_at(1.5,false),Outline.MIN_WIDTH),"pulse period is 1.5 seconds")
	check(Outline.HOVER_WIDTH > Outline.MAX_WIDTH,"hover is thicker than pulse maximum")
	await move_mouse(Vector2(40,400))
	await shot("targets-pulse")
	var pawn = meta(main,"knight_id",3)
	await move_mouse(pawn.get_global_rect().get_center())
	var outline = meta(main,"target_outline",3)
	check(outline.hovered and is_equal_approx(outline.stroke_width,Outline.HOVER_WIDTH),"real hover fixes maximum outline")
	await create_timer(.25).timeout
	check(is_equal_approx(outline.stroke_width,Outline.HOVER_WIDTH),"hover width stays fixed with time")
	await shot("targets-hover")
	await move_mouse(Vector2(40,400))
	check(not outline.hovered and outline.stroke_width <= Outline.MAX_WIDTH,"mouse exit resumes breathing")
	await show_game(g,1)
	for id in range(6): check(meta(main,"target_outline",id) == null,"waiting opponent has no misleading target outline")
	# Revised blade targets include both sides, even dead pawns.
	g = H.fixture(8); serial += 1; g.match_id = serial
	H.give(g,0,"strike")
	var blade: int = H.give(g,0,"cards_to_blades")
	H.begin(g,{0:blade})
	await show_game(g)
	for id in range(6): check(meta(main,"target_outline",id) != null,"outline is restricted to legal targets")
	root.size = Vector2i(960,640)
	await frames(); await shot("targets-small")
	# Batch draw crosses rows; the ninth card flies back without a discard picker.
	root.size = Vector2i(1440,960)
	g = H.fixture(8); serial += 1; g.match_id = serial
	g._draw(g.characters[0],3);g._draw(g.characters[3],3)
	g.presentation_enabled = true
	g._push([{"op":"draw","target":0,"count":6},{"op":"draw","target":3,"count":5}]);g._pump()
	await show_game(g)
	var draw_fx = meta(main,"draw_animation",g.animation.id)
	check(draw_fx != null,"new draw flight layer exists")
	draw_fx.clock_started = -1;draw_fx.elapsed = 20;draw_fx.set_process(false);draw_fx._process(0)
	for id in draw_fx.rows:
		var row: Dictionary = draw_fx.rows[id]
		for i in range(row.cards.size()):
			var c = row.order[i]
			check((c.position+c.pivot_offset*(Vector2.ONE-c.scale)).is_equal_approx(Layout.hand_position(id,i,row.friendly)),"draw lands in matching grid slot")
		check("/8" in row.label.text,"animated count uses eight-card limit")
		check(meta(main,"hand_slots_actor",id).is_visible_in_tree(),"slot frames remain visible during draw")
	await shot("draw-grid")
	while not g.animation.is_empty():g.advance_animation()
	check(g.request.is_empty() and g.characters[0].hand.size() == 8,"ninth drawn card returns without a mandatory discard")
	await show_game(g)
	await shot("overflow")
	print("V0182_UI_RESULT checks=%d failures=%d" % [checks,failures])
	main.session.leave()
	quit(0 if failures == 0 else 1)
