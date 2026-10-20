extends SceneTree
const H = preload("res://tests/helpers.gd")
const S = preload("res://tests/v011_scenarios.gd")
const Card = preload("res://scripts/card_widget.gd")
var main
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V013_UI_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func frames() -> void:
	for _i in range(4): await process_frame
func meta(node: Node, key: String, value):
	if node.has_meta(key) and node.get_meta(key) == value: return node
	for child in node.get_children():
		var found = meta(child,key,value)
		if found != null: return found
	return null
func nodes(node: Node) -> Array:
	var result: Array = [node]
	for child in node.get_children(): result.append_array(nodes(child))
	return result
func show_game(g, team: int = 0) -> void:
	main.session.team = team; main.session.state = g.snapshot(team)
	main.session.state.names = ["界面测试","对手"]
	main.session.changed.emit()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v013-"+name+".png")
func no_obscured_knights(panel: Control, label: String) -> void:
	for id in range(6):
		var knight: Control = meta(main,"knight_id",id)
		check(not panel.get_global_rect().intersects(knight.get_global_rect()),label+" knight %d unobscured" % id)
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(0.25).timeout
	var g = H.fixture(8)
	var keys := ["elegy","overload","peek","triple_strike","double_strike","strike","heal","prophecy","collect","quick_strike","holy_strike"]
	for i in range(keys.size()): H.give(g,i/4,keys[i])
	for id in range(3,6): H.give(g,id,"strike")
	show_game(g); await frames()
	for card in nodes(main).filter(func(n): return n is Card and not n.hidden_card and not n.death):
		var rank: int = card.card.main
		var expected: Color = Color("c59832") if rank >= 9 else Color("397eb6") if rank >= 7 else Color("796040") if rank >= 3 else Color("438559") if rank >= 1 else Color("b64c42")
		check(card.rarity_border() == expected,"priority determines face border")
		card.priority_bonus = 100; check(card.rarity_border() == expected,"privilege does not alter rarity")
	for node in nodes(main):
		if node is Label: check(node.text != "出牌区" and not node.text.begins_with("主优先级从"),"old zone labels removed")
	await shot("rarity-borders")
	# Enemy choice and own numeric picker both live in the middle gap.
	g = H.fixture(8); H.begin(g,{3:H.give(g,3,"prophecy")})
	for team in [0,1]:
		show_game(g,team); await frames()
		var panel: Control = meta(main,"decision_panel",true)
		no_obscured_knights(panel,"center decision team %d" % team)
		check(panel.position.y >= 313 and panel.position.y+panel.size.y <= 590,"decision remains in middle band")
		await shot("decision-%d" % team)
	# Original card lifts gradually, remains raised across rebuild, and can be inspected.
	g = H.fixture(8); g.presentation_enabled = true; g.resolution_presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"heal")}); show_game(g); await frames()
	var card: Control = meta(main,"resolving_card",true)
	var initial_scale := card.scale.x
	await create_timer(0.23).timeout
	check(card.scale.x > initial_scale and is_equal_approx(card.scale.x,0.88*1.32),"ordinary card rises and scales over 0.2 seconds")
	check(card.position.y < card.resolution_origin.y,"card moves upward")
	main._schedule_render(); await frames()
	card = meta(main,"resolving_card",true)
	check(is_equal_approx(card.scale.x,0.88*1.32),"rebuild does not restart lift")
	await shot("ordinary-start")
	var inspect_id: int = card.card.id
	main._inspect_visible(card,0); await frames(); await create_timer(0.25).timeout
	var details: Control = meta(main,"card_description",inspect_id)
	no_obscured_knights(details,"card description")
	await shot("card-description")
	main._close_hand(); await create_timer(0.25).timeout
	g = H.fixture(8); g.death_deck.erase(104); g.characters[0].hand.append(104)
	show_game(g); await frames(); main._inspect_hand(0,104); await frames(); await create_timer(0.25).timeout
	no_obscured_knights(meta(main,"card_description",104),"long card description")
	await shot("long-description")
	main._close_hand(); await create_timer(0.25).timeout
	g = H.fixture(8); g.presentation_enabled = true; g.resolution_presentation_enabled = true
	H.give_death(g,0,"blood_rite"); S.die(g,0); H.begin(g,{})
	show_game(g); await frames(); await create_timer(0.23).timeout
	card = meta(main,"resolving_card",true)
	check(card != null and card.death and card.scale.x > 0.88,"death card lifts before effect")
	await shot("death-start")
	while not g.animation.is_empty(): g.advance_animation()
	show_game(g); await frames()
	check(meta(main,"health_actor",0).get_meta("max_hp") == 10 and meta(main,"health_actor",1).get_meta("max_hp") == 10,"health gems use individual caps")
	await shot("blood-rite-cap")
	# Divinity can hide its picker without changing selection, scroll or server state.
	g = H.fixture(8); H.give_death(g,0,"divinity"); S.die(g,0); g._activate({"actor":0,"card":102},0)
	H.begin(g,{1:H.give(g,1,"collect")}); show_game(g); await frames()
	var pick_id: int = g.request.options[0]
	meta(main,"pick_card_id",pick_id).pressed.emit(); await frames()
	var revision: int = g.revision
	var scroll: ScrollContainer = nodes(main).filter(func(n): return n is ScrollContainer and n.has_meta("scroll_key"))[0]
	scroll.scroll_vertical = 90; await frames()
	meta(main,"picker_toggle",true).pressed.emit(); await frames()
	check(meta(main,"selection_panel",true) == null and main.pick_cards == [pick_id] and g.revision == revision,"hide preserves choice and rules")
	no_obscured_knights(meta(main,"picker_collapsed",true),"collapsed picker")
	await shot("picker-collapsed")
	meta(main,"picker_toggle",true).pressed.emit(); await frames()
	check(meta(main,"pick_card_id",pick_id).selected and main.pick_cards == [pick_id],"reopen preserves selected card")
	scroll = nodes(main).filter(func(n): return n is ScrollContainer and n.has_meta("scroll_key"))[0]
	check(scroll.scroll_vertical == 90,"reopen preserves scroll position")
	await shot("picker-expanded")
	g = H.fixture(8); g.characters[0].prediction = 8; g.characters[1].overload_round = 2; g.characters[2].shield = 1
	show_game(g); await frames()
	check(meta(main,"status_actor",0).MARKER_RADIUS == 14,"larger status medallions")
	await shot("stronger-statuses")
	root.size = Vector2i(960,640); await frames(); await shot("small-window")
	main.session.leave(); await frames()
	check(meta(main,"resolving_card",true) == null,"leaving clears card animation")
	print("V013_UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
