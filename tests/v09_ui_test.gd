extends SceneTree
const H = preload("res://tests/helpers.gd")
const Card = preload("res://scripts/card_widget.gd")
var main
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures+=1; push_error("V09_UI_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func frames() -> void:
	for _i in range(5): await process_frame
func meta(node: Node, key: String, value):
	if node.has_meta(key) and node.get_meta(key) == value: return node
	for child in node.get_children():
		var found = meta(child,key,value)
		if found != null: return found
	return null
func count_card(node: Node, id: int) -> int:
	var count: int = 1 if node is Card and node.card.get("id",-1) == id else 0
	for child in node.get_children(): count += count_card(child,id)
	return count
func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = at
	root.push_input(motion,true); await process_frame
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.position = at; press.pressed = true
	root.push_input(press,true); await process_frame
	press = press.duplicate(); press.pressed = false; root.push_input(press,true)
	await frames()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v09-"+name+".png")
func display(g, team: int = 0) -> void:
	main.session.team = team
	main.session.state = g.snapshot(team)
	main.session.state.names = ["动画测试","对手"]
	main.session.changed.emit()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(0.5).timeout
	var g = H.fixture(5)
	var normal: int = H.give(g,0,"heal")
	var death: int = H.give_death(g,0,"pain")
	display(g); await create_timer(0.8).timeout
	await click(meta(main,"card_id",normal).get_global_rect().get_center())
	await create_timer(0.23).timeout
	check(main.hand_lift.card.expanded and count_card(main,normal) == 1,"normal inspection lifts the single original widget")
	await click(main.hand_lift.details.get_global_rect().get_center())
	check(not main.hand_focus.is_empty(),"description click keeps raised card")
	await click(Vector2(100,420)*main.size/Vector2(1440,960))
	await create_timer(0.23).timeout
	check(main.hand_focus.is_empty() and meta(main,"card_id",normal) != null,"blank board puts card back")
	var focus_before: bool = main.music.focused
	var audio_before: float = main.music.player.get_playback_position()
	await click(meta(main,"death_card_id",death).get_global_rect().get_center())
	await create_timer(0.23).timeout
	check(not main.death_dialog.visible and main.hand_lift.card.death,"death card uses inline lift without modal window")
	check(count_card(main,death) == 1 and meta(main,"play_card_id",death) == null,"death card has single widget and no play button")
	check(main.music.focused == focus_before and main.music.player.playing and main.music.player.get_playback_position() > audio_before,"death inspection preserves audio playback and focus")
	check(not main.hand_lift.card.get_global_rect().intersects(main.hand_lift.details.get_global_rect()),"death description remains beside card")
	await shot("death-inspection")
	await click(Vector2(100,420)*main.size/Vector2(1440,960)); await create_timer(0.23).timeout
	check(main.hand_focus.is_empty(),"death inspection closes on blank board")
	for team in [0,1]:
		for actor in range(6):
			g = H.fixture(8)
			H.begin(g,{actor:H.give(g,actor,"strike")})
			display(g,team); await frames()
			var panel: Control = meta(main,"decision_panel",true)
			var source: Control = main.board._active_widget()
			check(panel.size.x < 300 and not panel.get_global_rect().intersects(source.get_global_rect()),"compact decision beside source team%d actor%d" % [team,actor])
			check(root.get_visible_rect().encloses(panel.get_global_rect()),"decision stays in viewport")
			for id in range(6):
				var knight: Control = meta(main,"knight_id",id)
				if not knight.disabled: check(not panel.get_global_rect().intersects(knight.get_global_rect()),"choice panel leaves legal knights clickable")
			if team == 0 and actor == 0: await shot("target-choice")
	g = H.fixture(8); H.begin(g,{0:H.give(g,0,"prophecy")}); display(g); await frames()
	await shot("prophecy")
	g = H.fixture(5); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"team_heal")}); display(g); await frames()
	await create_timer(0.25).timeout
	var effect = meta(main,"effect_animation",g.animation.id)
	check(effect != null and effect.event.targets.size() == 3,"all living ally heal flights visible")
	await shot("healing-flight")
	var elapsed: float = effect.elapsed
	main._schedule_render(); await frames()
	check(meta(main,"effect_animation",g.animation.id).elapsed >= elapsed,"UI refresh preserves animation progress")
	g.advance_animation(); display(g); await create_timer(0.22).timeout
	check(main.session.state.characters[0].hp == 6,"display HP changes on impact")
	await shot("healing-impact")
	g.advance_animation(); display(g); await frames()
	check(meta(main,"effect_animation",1) == null,"completed effect cleans up")
	g = H.fixture(5); g.match_id = 2; g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike")})
	g.advance_animation(); display(g); await create_timer(0.22).timeout
	await shot("shield")
	g.advance_animation(); g.target(1,0); g.defend(0,true); g.advance_animation()
	display(g); await create_timer(0.22).timeout
	await shot("shield-block")
	check(g.characters[0].hp == 5,"block visual leaves health unchanged")
	main.session.leave(); await frames()
	check(main.hand_focus.is_empty() and meta(main,"effect_animation",g.animation.id) == null,"leaving clears inspection and effects")
	print("V09_UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
