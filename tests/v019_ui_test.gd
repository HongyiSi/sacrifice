extends "res://tests/v0182_gift_ui_test.gd"

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v019-"+name+".png")

func display(g, team: int = 0) -> void:
	main.session.team = team
	main.session.game = g
	main.session._broadcast()
	await frames()

func _run() -> void:
	root.size = Vector2i(1200,800)
	main = load("res://scenes/main.tscn").instantiate();root.add_child(main)
	await create_timer(.4).timeout
	main.music.set_level(0)
	main.session.leave();main.session.queue_free()
	main.session = LocalSession.new();main.add_child(main.session)
	main.session.changed.connect(main._on_state)
	main.session.problem.connect(func(message):check(false,message))
	main.session.hosting = true;main.session.active = true;main.session.team = 0
	main.session.set_process(false)
	var g = H.fixture(8)
	var keys := ["bloodletting","gold_panning","search","sapphire","ruby","amethyst","rally","defile","obstruct","final_strike"]
	for i in range(keys.size()): H.give(g,i/4,keys[i])
	var rock: int = g._generate_card(g.BOULDER)
	g.characters[2].hand.append(rock)
	var locked: int = H.give(g,2,"strike");g.defiled_cards[locked] = true
	await display(g)
	for c in g.characters.slice(0,3):
		for id in c.hand:
			check(main.board._find_hand_card(id) != null,"new card has visible hand widget")
	await shot("new-cards")
	await click(main.board._find_hand_card(rock));await create_timer(.3).timeout
	check(meta(main,"play_card_id",rock).disabled,"rock cannot be played through UI")
	main._close_hand();await frames();await create_timer(.3).timeout
	await click(main.board._find_hand_card(locked));await create_timer(.3).timeout
	check(meta(main,"play_card_id",locked).disabled,"defiled card has disabled play control")
	await shot("defiled-preview")
	main._close_hand();await frames();await create_timer(.3).timeout
	g = H.fixture(8);g.match_id = 19001
	H.begin(g,{0:H.give(g,0,"search")})
	await display(g)
	check(meta(main,"selection_panel",true) != null,"search opens private deck picker")
	check(meta(main,"pick_confirm",true).disabled,"search requires one selection")
	var selected: int = g.request.options[0]
	await click(meta(main,"pick_card_id",selected))
	check(main.pick_cards == [selected] and not meta(main,"pick_confirm",true).disabled,"actual deck card click enables confirmation")
	await shot("search-picker")
	await click(meta(main,"pick_confirm",true))
	check(g.characters[0].hand == [selected] and g.phase == "review","search confirmation transfers selected card")
	g = H.fixture(8);g.match_id = 19002
	selected = H.give(g,3,"heal");H.give(g,3,"amethyst")
	H.begin(g,{0:H.give(g,0,"defile")})
	await display(g)
	await click(meta(main,"knight_id",3))
	check(g.request.type == "defile" and meta(main,"selection_panel",true) != null,"target click opens defile hand picker")
	await click(meta(main,"pick_card_id",selected))
	await shot("defile-picker")
	await click(meta(main,"pick_confirm",true))
	check(g.defiled_cards.has(selected),"defile commits chosen physical card")
	await display(g,1)
	check(main.board._find_hand_card(selected).card.defiled,"opponent owner sees restricted card marker")
	g = H.fixture(8);g.match_id = 19003
	for _i in range(8): H.give(g,0,"strike")
	H.begin(g,{3:H.give(g,3,"obstruct")});g.target(1,0)
	await display(g)
	for id in g.characters[0].hand:
		if g.catalog[id].key == "boulder": check(meta(main,"pick_card_id",id) == null,"rocks are not selectable as mandatory discard")
	for id in g.request.options.slice(0,2): await click(meta(main,"pick_card_id",id))
	await shot("obstruct-overflow")
	await click(meta(main,"pick_confirm",true))
	check(g.characters[0].hand.size() == 8 and g.phase == "review","recipient completes overflow by real card clicks")
	root.size = Vector2i(960,640)
	g = H.fixture(8);g.match_id = 19004
	H.begin(g,{0:H.give(g,0,"search")});await display(g)
	check(Rect2(0,0,1440,960).encloses(main.board._board_rect(meta(main,"selection_panel",true))),"picker fits minimum window size")
	await shot("search-small")
	print("V019_UI_RESULT checks=%d failures=%d" % [checks,failures])
	main.session.leave();main.queue_free();await frames()
	quit(0 if failures == 0 else 1)
