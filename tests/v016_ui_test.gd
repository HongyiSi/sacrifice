extends "res://tests/v015_ui_test.gd"
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await frames()
	check(nodes(main).any(func(n): return n is Button and n.text == "创建房间"),"online lobby is default")
	var g = H.fixture(8)
	var amulet: int = H.give(g,0,"attack_amulet")
	show_game(g); await frames()
	for c in g.characters:
		check(meta(main,"pawn_title",c.id).text == "棋子%d" % (c.id%3+1),"title has only pawn number")
	main._play_hand(0,amulet,g.revision); await frames()
	check(main.guard_dialog.visible and main._selected_cards(0).is_empty(),"amulet waits for planning target")
	var targets: Array = nodes(main.guard_dialog).filter(func(n): return n is Button and n.text.begins_with("我方 · 棋子2"))
	check(targets.size() == 1,"protect ally target offered")
	targets[0].pressed.emit(); await frames()
	check(main._plan_payload()[0].guards[amulet] == 1 and main._selected_cards(0)==[amulet],"plan carries chosen target")
	main._inspect_hand(0,amulet); await frames(); await create_timer(.25).timeout
	check(nodes(main).any(func(n): return n is Label and n.text == "保护目标：我方 棋子2"),"planned protection can be reviewed")
	check(nodes(main).any(func(n): return n is Button and n.text == "更改保护目标"),"target can be changed before lock")
	var detail: Control = meta(main,"card_description",amulet)
	check(root.get_visible_rect().encloses(detail.get_global_rect()),"protection description stays on screen")
	check(detail.size.x <= 600,"protection description keeps its assigned width")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v016-guard-target.png")
	main.session.leave(); await frames()
	print("V016_UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
