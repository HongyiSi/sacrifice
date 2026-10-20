extends SceneTree
const H = preload("res://tests/helpers.gd")
const Table = preload("res://scripts/table_ui.gd")
var main
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V017_UI_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func frames() -> void:
	for _i in range(5): await process_frame
func meta(node: Node,key: String,value):
	if node.has_meta(key) and node.get_meta(key)==value:return node
	for child in node.get_children():
		var found=meta(child,key,value)
		if found!=null:return found
	return null
func nodes(node: Node) -> Array:
	var result: Array=[node]
	for child in node.get_children():result.append_array(nodes(child))
	return result
func show_game(g,team: int=0) -> void:
	main.pick_revision=-1 # Every call replaces the fixture with a new logical view.
	main.session.team=team;main.session.state=g.snapshot(team);main.session.state.names=["甲","乙"]
	main.session.changed.emit()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v017-"+name+".png")
func click(control: Control) -> void:
	var pos:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=pos;root.push_input(motion,true)
	var down:=InputEventMouseButton.new();down.position=pos;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;root.push_input(down,true)
	var up:=InputEventMouseButton.new();up.position=pos;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;root.push_input(up,true)
	await frames()
func _run() -> void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	var g=H.fixture(8)
	g._push([{"op":"draw","target":0,"count":10}]);g._pump()
	show_game(g);await frames()
	var heading=meta(main,"input_heading",true)
	check(heading.get_meta("target_color")==Table.BLUE and "我方 · 棋子1" in heading.get_parsed_text(),"own discard target blue and qualified")
	check(meta(main,"pick_confirm",true).disabled,"confirm disabled before correct discard count")
	check(not nodes(main.page).any(func(n):return n is Button and n.text=="自动选择"),"mandatory discard has no auto-discard button")
	for id in g.request.options.slice(0,3):
		await click(meta(main,"pick_card_id",int(id)))
	check(main.pick_cards.size()==3 and not meta(main,"pick_confirm",true).disabled,"clicking any three enables confirmation")
	await shot("discard-seven")
	show_game(g,1);await frames()
	check(meta(main,"selection_panel",true)==null and meta(main,"decision_panel",true)!=null,"opponent waits without hidden card picker")
	# A dead divinity holder chooses a card for a same-named enemy pawn.
	g=H.fixture(8);H.give_death(g,0,"divinity");g.characters[0].hp=0
	g.effects.append({"card":102,"owner":0,"target":0,"round":g.round_number})
	g._push([{"op":"draw","target":3,"count":1}]);g._pump()
	show_game(g);await frames()
	heading=meta(main,"input_heading",true)
	check(heading.get_meta("target_color")==Table.RED and "敌方 · 棋子1" in heading.get_parsed_text(),"enemy divinity recipient red despite allied chooser")
	await shot("divinity-enemy")
	main.picker_collapsed=true;main._schedule_render();await frames()
	check(meta(main,"picker_toggle",true)!=null,"picker may still be hidden and restored")
	# Inspecting must allow both types to lift, with no play button or ownership mutation.
	g=H.fixture(8);var peek=H.give(g,0,"peek");var hand=H.give(g,3,"strike");var death=H.give_death(g,3,"immortal")
	H.begin(g,{0:peek});g.target(0,3)
	show_game(g);await frames()
	var b=meta(main,"inspection_card",death)
	check(b!=null and not b.disabled,"peek death is clickable")
	await click(b);await create_timer(.25).timeout
	check(not main.hand_lift.is_empty() and main.hand_lift.card.card.id==death and main.hand_lift.card.death,"real mouse opens inspected death")
	check(meta(main,"card_description",death)!=null and main.hand_lift.controls.get_child_count()==0,"death description without play button")
	check(main.music.player.playing,"inspection leaves music playing")
	await shot("peek-death")
	main._close_hand();await create_timer(.25).timeout;await frames()
	b=meta(main,"inspection_card",hand);await click(b);await create_timer(.25).timeout
	check(main.hand_lift.card.card.id==hand and main.hand_lift.controls.get_child_count()==0,"ordinary peek card also opens readonly")
	check(g.characters[3].deathrattles==[death] and not g.death_revealed.has(death),"UI does not mutate or reveal enemy death")
	main._close_hand();await create_timer(.25).timeout;await frames()
	show_game(g,1);await frames()
	check(meta(main,"inspection_card",death)==null,"other player receives no inspection cards")
	# Amulet choice buttons and chosen target text share the same team palette.
	g=H.fixture(8);var amulet=H.give(g,0,"holy_amulet");show_game(g);await frames()
	main._pick_guard_target(0,amulet);await frames()
	check(meta(main,"guard_target",0).get_theme_color("font_color")==Table.BLUE,"friendly guard target blue")
	check(meta(main,"guard_target",3).get_theme_color("font_color")==Table.RED,"enemy guard target red")
	main.guard_dialog.hide()
	print("V017_UI_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
