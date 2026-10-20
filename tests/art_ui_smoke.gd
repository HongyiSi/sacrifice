extends SceneTree
const H = preload("res://tests/helpers.gd")
const Art = preload("res://scripts/table_ui.gd")
var main
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("ART_UI_FAIL " + label)

func frames(count: int = 6) -> void:
	for _i in range(count): await process_frame

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames()
	check(main.session.host_room("绘本测试",24984) == OK,"test room")
	main.session.names = ["绘本测试","对手"]
	var game = H.fixture()
	game.match_id = 61
	for _i in range(10): H.give(game,0,"strike")
	H.give(game,0,"heal"); H.give(game,0,"collect")
	H.give_death(game,0,"immortal"); H.give_death(game,0,"ghost"); H.give_death(game,0,"eye")
	for actor in range(1,6):
		H.give(game,actor,"double_strike")
	main.session.game = game
	main.session._broadcast()
	await frames()
	check(_nodes_with_meta(main,"knight_id").size() == 6,"six separate targetable knights")
	for key in ["blue_sword","blue_shield","blue_mage","red_spear","red_axe","red_archer"]:
		var tex: AtlasTexture = Art.texture(key)
		check(tex != null and tex.region.size.x > 200 and tex.region.size.y > 200,"nonempty sprite "+key)
		var img := tex.atlas.get_image()
		if img.is_compressed(): img.decompress()
		check(img.get_pixel(0,0).a == 0,"transparent sprite "+key)
	var hand = _find_meta(main,"hand_actor",0)
	check(hand != null and not hand is ScrollContainer,"hand is an unscrolled fan")
	var cards: Array = hand.get_children().filter(func(n): return n.has_meta("card_id"))
	check(cards.size() == 12,"all twelve cards present in fan")
	for index in range(cards.size()):
		var card = cards[index]
		check(card.position.x >= 0 and card.position.x+card.size.x <= hand.size.x+1,"every card stays inside its role")
		if index > 0:
			check(card.position.x > cards[index-1].position.x and card.position.x < cards[index-1].position.x+76,"right cards overlap left cards")
	# Hit every exposed strip. Inspecting must never mutate the plan.
	var ids: Array = cards.map(func(c): return c.get_meta("card_id"))
	for id in ids:
		var card = _find_meta(main,"card_id",id)
		await _click(card,Vector2(float(card.get_meta("exposed_width"))/2.0,48))
		check(main.hand_focus.get("card",0) == id and main._selected_cards(0).is_empty(),"exposed strip inspects without playing")
		main.hand_focus.clear(); main._schedule_render(); await frames()
	var chosen_id: int = ids[5]
	await _click(_find_meta(main,"card_id",chosen_id),Vector2(8,45))
	await _capture("hand-expanded")
	var play = _find_meta(main,"play_card_id",chosen_id)
	check(play != null and not play.disabled,"expanded hand has play button")
	await _click(play)
	check(main._selected_cards(0) == [chosen_id],"play button stages chosen card")
	check(_find_meta(main,"card_id",chosen_id) == null and _find_meta(main,"staged_card_id",chosen_id) != null,"staged card moves from hand to table")
	check(game.characters[0].hand.has(chosen_id) and game.plans[0] == null,"staging is local until lock")
	await _click(_find_meta(main,"staged_card_id",chosen_id))
	check(_find_button(main,"撤回出牌") != null,"table card can be withdrawn")
	await _click(_find_button(main,"撤回出牌"))
	check(main._selected_cards(0).is_empty() and _find_meta(main,"card_id",chosen_id) != null,"withdraw returns card to hand")
	var enemy_hand = _find_meta(main,"enemy_hand_actor",3)
	var enemy = _find_meta(main,"knight_id",3)
	check(enemy_hand.position.y < enemy.position.y,"opponent hand is above and behind knight")
	check(enemy_hand.get_children().all(func(c): return c.hidden_card and c.card.is_empty()),"opponent hands conceal identities")
	var death_fan = _find_meta(main,"death_fan_actor",0)
	var own = _find_meta(main,"knight_id",0)
	check(death_fan.position.x > own.position.x+own.size.x-4,"own death cards are right of knight")
	check(death_fan.get_child_count() == 3,"all three death cards have widgets")
	for death_id in game.characters[0].deathrattles.duplicate():
		await _click(_find_meta(main,"death_card_id",int(death_id)),Vector2(4,45))
		check(main.hand_lift.get("card") != null and main.hand_lift.card.death,"each overlapping side death card opens")
		main._close_hand(); await create_timer(0.25).timeout; await frames()
	await _capture("large-hand")
	for window_size in [Vector2i(960,640),Vector2i(1600,900),Vector2i(1200,800)]:
		root.size = window_size
		await frames(10)
		var lock = _find_button(main,"锁定全队出牌")
		var rect: Rect2 = lock.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,lock.size)
		var visible: Rect2 = root.get_visible_rect()
		check(visible.encloses(rect),"lock button fits "+str(window_size))
		for knight in _nodes_with_meta(main,"knight_id"):
			check(visible.encloses(knight.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,knight.size)),"knight fits "+str(window_size))
		if window_size == Vector2i(960,640): await _capture("small-window")
	# True pointer targeting exercises overlays and hitboxes, not just signals.
	game = H.fixture(); game.match_id = 62
	var hit: int = H.give(game,0,"strike",10)
	H.begin(game,{0:hit})
	main.session.game = game; main.session._broadcast()
	await frames()
	await _click(_find_meta(main,"target_character_id",3))
	check(game.characters[3].hp == 4 and game.phase == "review","pointer click on enemy knight applies attack")
	# Direct desktop card targeting, redaction and multi-card actions.
	game = H.fixture(); game.match_id = 621
	var mirror: int = H.give(game,0,"mirror")
	var enemy_card: int = H.give(game,3,"strike")
	var board_plan := {0:mirror,1:H.give(game,1,"strike"),2:H.give(game,2,"double_strike"),3:enemy_card,4:H.give(game,4,"strike"),5:H.give(game,5,"double_strike")}
	for actor in range(6):
		for _n in range(6): game.characters[actor].hand.append(game.deck.pop_back())
	for pair in [[0,"immortal"],[1,"prison"],[2,"death_sentence"],[3,"ghost"],[4,"eye"],[5,"divinity"]]: H.give_death(game,pair[0],pair[1])
	H.begin(game,board_plan)
	main.session.game = game; main.session._broadcast()
	await frames()
	var action_id: int = H.action_for(game,3).id
	var target_card = _find_meta(main,"target_action_id",action_id)
	check(target_card != null and target_card.hidden_card and target_card.card.is_empty(),"mirror target is an actual hidden desktop card")
	check(target_card.get_parent().position.y > _find_meta(main,"knight_id",3).position.y,"enemy played card is below enemy")
	check(_find_meta(main,"played_actor",0).position.y < _find_meta(main,"knight_id",0).position.y,"friendly played card is above own knight")
	await _capture("table-target")
	await _click(target_card)
	check(game.phase == "targeting","pointer click chooses mirror target and resumes")
	var copied = game.queue.filter(func(a): return a.virtual)
	if not copied.is_empty():
		var copied_card = _find_meta(main,"played_action_id",copied[0].id)
		check(copied_card.card.secondary == 0,"mirror desktop card shows copied secondary priority")
	game = H.fixture(); game.match_id = 622
	H.begin(game,{0:H.give(game,0,"suppress"),3:H.give(game,3,"strike")})
	main.session.game = game; main.session._broadcast()
	await frames()
	action_id = H.action_for(game,3).id
	await _click(_find_meta(main,"target_action_id",action_id))
	check(H.action_for(game,3).status == "suppressed","pointer click chooses suppression target")
	game = H.fixture(); game.match_id = 623
	H.begin(game,{0:H.give(game,0,"overload")})
	game.confirm(0); game.confirm(1)
	H.give(game,0,"strike",10); H.give(game,0,"strike",9); H.give(game,0,"strike",8)
	main.session.game = game; main.session._broadcast()
	await frames()
	for card_id in game.characters[0].hand.slice(0,3):
		main._inspect_hand(0,card_id); await frames()
		await _click(_find_meta(main,"play_card_id",card_id))
	check(main._selected_cards(0).size() == 3,"three cards staged through play controls")
	check(_nodes_with_meta(main,"staged_card_id").size() == 3,"three separate desktop cards displayed")
	var extra: int = game.characters[0].hand[3]
	main._inspect_hand(0,extra); await frames()
	check(_find_meta(main,"play_card_id",extra).disabled,"cannot exceed play limit")
	main.hand_focus.clear(); main._schedule_render(); await frames()
	await _click(_find_button(main,"锁定全队出牌"))
	check(game.plans[0].size() == 3 and game.plans[0][0].size() == 3,"lock submits three-card plan")
	main._inspect_hand(0,extra); await frames()
	check(_find_meta(main,"play_card_id",extra).disabled,"locked hands can inspect but cannot play")
	# Snapshot from the other player has neither identities nor a fake staged plan.
	var client: Dictionary = game.snapshot(1)
	check(client.characters[0].hand.is_empty() and client.my_plan.is_empty(),"opponent learns no staged card identities")
	main.hand_focus.clear()
	client.names = ["玩家一","玩家二"]
	main.session.team = 1; main.session.state = client; main._on_state()
	await frames()
	check(_find_meta(main,"hand_actor",3) != null and _find_meta(main,"enemy_hand_actor",0) != null,"guest perspective places own team at bottom")
	check(_find_meta(main,"knight_id",3).position.y > _find_meta(main,"knight_id",0).position.y,"guest knights are below opponents")
	check(_nodes_with_meta(main,"staged_card_id").is_empty(),"guest cannot see opponent staging")
	await _capture("guest-view")
	main.session.team = 0
	# Every physical card stays represented even in an extreme accumulated hand.
	game = H.fixture(); game.match_id = 624
	game.characters[0].hand = game.deck.duplicate(); game.deck.clear()
	main.session.game = game; main.session._broadcast()
	await frames()
	var full_hand = _find_meta(main,"hand_actor",0)
	check(_nodes_with_meta(full_hand,"card_id").size() == 91,"all 91 cards fit without paging or scrolling")
	check(full_hand.get_children().all(func(c): return c.position.x >= 0 and c.position.x+c.size.x <= 345),"extreme fan stays within role width")
	main._inspect_hand(0,game.characters[0].hand[0]); await frames()
	check(_find_meta(main,"hand_preview_card",game.characters[0].hand[0]) != null,"extreme hand still supports inspection")
	main.hand_focus.clear()
	# Death tint, resurrection target and restored appearance.
	game = H.fixture(); game.match_id = 63
	game.characters[1].hp = 0; game.characters[1].death_round = game.round_number
	H.begin(game,{0:H.give(game,0,"raise_dead")})
	main.session.game = game; main.session._broadcast()
	await frames()
	var dead_knight = _find_meta(main,"knight_id",1)
	check(dead_knight.get_child(0).modulate.a < 1,"death changes sprite appearance")
	await _click(dead_knight)
	check(game.characters[1].hp == 1,"pointer click selects dead friendly knight for revival")
	check(game.characters[1].hp == 1 and _find_meta(main,"knight_id",1).get_child(0).modulate.a == 1,"resurrection restores sprite")
	# Selecting from the bottom of the large deck must preserve scroll position.
	game = H.fixture(); game.match_id = 64
	var god: int = H.give_death(game,0,"divinity")
	game.characters[0].hp = 0; game.characters[0].death_round = game.round_number
	game._activate({"actor":0,"card":god},0); game.death_revealed.append(god)
	H.begin(game,{1:H.give(game,1,"collect")})
	main.session.game = game; main.session._broadcast()
	await frames()
	check(game.request.type == "deck","large deck picker opened")
	var pick_scroll = _find_meta(main,"scroll_key","pick_%s" % main.session.state.revision)
	pick_scroll.scroll_vertical = 220
	await frames()
	var pick_offset: int = pick_scroll.scroll_vertical
	check(pick_offset > 0,"deck picker scrolls")
	var pick = null
	for b in _nodes_with_meta(main,"pick_card_id"):
		var top: float = b.position.y-pick_scroll.scroll_vertical
		if top >= 0 and top+b.size.y <= pick_scroll.size.y:
			pick = b
			break
	check(pick != null,"deck has fully visible options after scrolling")
	if pick != null:
		var pick_id: int = pick.get_meta("pick_card_id")
		await _click(pick)
		check(main.pick_cards.has(pick_id),"pointer click selects deck card")
		check(_find_meta(main,"scroll_key","pick_%s" % main.session.state.revision).scroll_vertical == pick_offset,"deck selection preserves scroll")
	await _capture("deck-scrolled")
	await _click(_find_button(main,"战况"))
	check(main.battle_dialog.visible and not main.battle_text.text.is_empty(),"battle log opens from real pointer click")
	main.battle_dialog.hide()
	main.session.leave()
	await frames()
	check(not main.battle_dialog.visible and not main.death_dialog.visible and main.battle_text.text.is_empty(),"leaving clears private dialogs")
	print("ART_UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _click(button: Control, local_point: Vector2 = Vector2(-1,-1)) -> void:
	var position: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5 if local_point.x < 0 else local_point)
	var motion := InputEventMouseMotion.new()
	motion.position = position; motion.global_position = position
	root.push_input(motion,true)
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position = position; click.global_position = position
		click.button_index = MOUSE_BUTTON_LEFT; click.pressed = pressed
		root.push_input(click,true)
	await frames()

func _find_meta(node: Node, key: String, value):
	if node.has_meta(key) and node.get_meta(key) == value: return node
	for child in node.get_children():
		var found = _find_meta(child,key,value)
		if found != null: return found
	return null

func _find_button(node: Node, title: String):
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found = _find_button(child,title)
		if found != null: return found
	return null

func _nodes_with_meta(node: Node, key: String) -> Array:
	var result: Array = [node] if node.has_meta(key) else []
	for child in node.get_children(): result.append_array(_nodes_with_meta(child,key))
	return result

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/art-" + label + ".png")
