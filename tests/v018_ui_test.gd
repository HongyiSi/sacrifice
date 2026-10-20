extends "res://tests/v0174_ui_test.gd"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V018_UI_FAIL " + label)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v018-"+name+".png")

func _run() -> void:
	root.size = Vector2i(1440,960)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(.4).timeout
	main.music.set_level(0)
	var g = H.fixture(8)
	var keys := ["warcry","anticipation","gift","cards_to_heart","cards_to_blades","suppress","late_suppress","frenzy"]
	for i in range(keys.size()): H.give(g,i%3,keys[i])
	await show_game(g)
	for c in g.characters.slice(0,3):
		for id in c.hand:
			var widget = meta(main,"hand_card_id",id)
			# Card identities are also retained in the visible widgets themselves.
			if widget == null: widget = main.board._find_hand_card(id)
			check(widget != null,"new card available in ordinary hand "+g.catalog[id].name)
	await shot("new-cards")
	var blade_id: int = g.characters[1].hand.filter(func(id): return g.catalog[id].key == "cards_to_blades")[0]
	main._inspect_hand(1,blade_id); await frames()
	check(not main.hand_focus.is_empty(),"new long-description card opens full details")
	await shot("blade-details")
	main._close_hand(); await frames()
	for key in keys:
		var id: int = g.catalog.values().filter(func(c): return c.key == key)[0].id
		var card: Dictionary = g.catalog[id]
		check(preload("res://scripts/art_symbols.gd").icon(key) != null,"basic symbol "+key)
		var font = load("res://assets/fonts/NotoSansCJKsc-GameSubset.otf")
		for ch in card.name:
			check(font.has_char(ch.unicode_at(0)),"name glyph exists "+ch)
	g = H.fixture(8); serial += 1; g.match_id = serial
	var one: int = H.give(g,0,"cards_to_blades")
	var two: int = H.give(g,0,"heal")
	g.death_deck.erase(104); g.characters[0].hand.append(104)
	H.begin(g,{0:H.give(g,0,"gift")}); g.target(0,1)
	await show_game(g)
	check(meta(main,"selection_panel",true) != null,"gift shows selection panel")
	var confirm = meta(main,"pick_confirm",true)
	check(confirm != null and confirm.disabled,"gift needs at least one pick or explicit skip")
	var card_button = meta(main,"pick_card_id",one)
	card_button.pressed.emit(); await frames()
	check(not meta(main,"pick_confirm",true).disabled,"one pick enables gift confirmation")
	meta(main,"pick_card_id",104).pressed.emit(); await frames()
	confirm = meta(main,"pick_confirm",true)
	check(not confirm.disabled and "确认赠送" in confirm.text,"two picks enable clear gift confirmation")
	await shot("gift-picker")
	await show_game(g,1)
	check(meta(main,"selection_panel",true) == null,"opponent sees waiting state without private picker")
	await shot("gift-opponent")
	g = H.fixture(8); serial += 1; g.match_id = serial
	H.give(g,0,"strike"); H.give(g,0,"heal")
	H.begin(g,{0:H.give(g,0,"cards_to_blades")}); g.target(0,3)
	await show_game(g)
	var description = meta(main,"target_description",true)
	check(description != null and "2 / 2" in description.text,"blade prompt shows next hit and total")
	check(g.snapshot(0).input.options == [0,1,2,3,4,5],"blade highlights every pawn")
	await shot("blade-target")
	g = H.fixture(8); serial += 1; g.match_id = serial
	H.begin(g,{0:H.give(g,0,"anticipation"),3:H.give(g,3,"badge")})
	await show_game(g)
	check(main.session.state.reveal_locked_teams[1],"prediction lock reaches board state")
	await shot("prediction-lock")
	root.size = Vector2i(960,640)
	await frames(); await shot("prediction-small")
	print("V018_UI_RESULT checks=%d failures=%d" % [checks,failures])
	main.session.leave()
	quit(0 if failures == 0 else 1)
