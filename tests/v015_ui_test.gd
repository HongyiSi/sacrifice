extends SceneTree
const H = preload("res://tests/helpers.gd")
const Card = preload("res://scripts/card_widget.gd")
var main
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V015_UI_FAIL "+label)
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
	root.get_texture().get_image().save_png("res://test-results/v015-"+name+".png")
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(.75).timeout
	var m = main.music
	check(m.context == 0 and m.player.playing,"lobby continues normally")
	var g = H.fixture(8)
	var cards := []
	for id in range(3):
		cards.append(H.give(g,id,"holy_strike" if id==0 else "hasty_spell" if id==1 else "feign"))
		H.give(g,id,"strike"); H.give(g,id,"heal")
	H.give_death(g,0,"immortal")
	show_game(g); await frames(); await create_timer(.75).timeout
	check(m.context == 1 and m.player.playing,"original battle track starts")
	check(m.player.stream is AudioStreamMP3 and m.player.stream.loop,"battle uses original looping MP3")
	check(m.player.stream.data == FileAccess.get_file_as_bytes("res://assets/music/woodland_fantasy.mp3"),"playing bytes exactly match original MP3")
	check(m.player.stream.get_length() > 140,"original music decodes")
	for card in nodes(main).filter(func(n): return n is Card):
		var expected: bool = not card.hidden_card and not card.death and not card.card.has("priority") and card.card.get("main",-1) in [0,9,10]
		check(card.glow_enabled() == expected,"only revealed gold/red ordinary faces glow")
	await shot("gold-red-glow")
	for i in range(3):
		var source: Control = meta(main,"card_id",cards[i])
		var original := source.global_position
		main._inspect_hand(i,cards[i]); await frames()
		var lifted: Control = main.hand_lift.card
		await create_timer(.24).timeout
		check(absf(lifted.position.x-main.hand_lift.origin.x) < 30,"lift stays in its hand column")
		check(is_equal_approx(lifted.position.y,main.hand_lift.origin.y-128),"lift remains near hand, not board center")
		check(lifted.global_position.y < original.y and is_equal_approx(lifted.scale.x,1.7),"original card raises and enlarges")
		check(nodes(main).filter(func(n): return n is Card and n.card.get("id",-1)==cards[i]).size()==1,"no duplicated hand card")
		var details: Control = meta(main,"card_description",cards[i])
		check(not details.get_global_rect().intersects(lifted.get_global_rect()),"description does not cover card")
		for id in range(6): check(not details.get_global_rect().intersects(meta(main,"knight_id",id).get_global_rect()),"description avoids knight")
		check(meta(main,"play_card_id",cards[i]) != null,"local card has play button")
		await shot("local-hand-%d" % i)
		main._close_hand(); await create_timer(.25).timeout
		check(main.hand_focus.is_empty(),"preview closes")
	# Deaths and snapshots have no connection to music context or playback.
	m.focused = true
	var original_stream: AudioStream = m.player.stream
	var previous_position: float = m.player.get_playback_position()
	for count in [1,2,4,12]:
		g.death_events = count
		g.characters[3].hp = 0
		show_game(g); await create_timer(.15).timeout
		check(m.player.stream == original_stream and m.player.playing,"death keeps original track "+str(count))
	check(m.player.get_playback_position() > previous_position,"death updates do not restart original music")
	previous_position = m.player.get_playback_position()
	main._inspect_visible(meta(main,"death_card_id",120),0); await create_timer(.25).timeout
	check(m.player.playing and m.player.stream == original_stream and m.player.get_playback_position() > previous_position,"death card inspection keeps original music running")
	main._close_hand(); await create_timer(.25).timeout
	m.focused = false; m._apply_volume()
	check(m.player.volume_db <= -79 and m.player.playing,"focus mute retains playback")
	m.focused = true; m._apply_volume()
	check(m.player.volume_db > -79,"focus restores music volume")
	m.player.seek(m.player.stream.get_length()-.3); await create_timer(.8).timeout
	check(m.player.playing and m.player.get_playback_position() < 2,"original MP3 loops at end")
	# Current rule text and ordinary card targeting must use the formal pawn name.
	g = H.fixture(8); H.begin(g,{0:H.give(g,0,"holy_strike")})
	show_game(g); await frames()
	check(main.session.state.input.description.contains("棋子") and main.session.state.input.description.contains("3点伤害"),"updated holy strike targeting text rendered")
	await shot("holy-strike-target")
	g = H.fixture(8); H.give_death(g,2,"blessing"); g._activate({"actor":2,"card":108},0)
	g.characters[0].hp = 3; g.characters[1].hp = 4; g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"team_heal")}); g.advance_animation()
	show_game(g); await create_timer(.20).timeout
	check(main.session.state.characters[0].hp == 3 and main.session.state.characters[1].hp == 5,"blocked and successful heals display distinct real HP")
	check(main.session.state.animation.targets[0].heal_blocked,"blocked healing result reaches UI")
	await shot("blessing-blocked-heal")
	main.session.leave(); await create_timer(.75).timeout
	check(m.context == 0 and m.player.playing and m.player.stream is AudioStreamWAV,"leaving restores original lobby track")
	print("V015_UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
