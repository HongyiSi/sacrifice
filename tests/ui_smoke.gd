extends SceneTree
const H = preload("res://tests/helpers.gd")
var main
var child_pid := -1
var failures := 0
var checks := 0
var initial_preferences := PackedByteArray()
var had_preferences := false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("UI_FAIL " + label)

func _frames(count: int = 4) -> void:
	for _i in range(count): await process_frame

func _run() -> void:
	had_preferences = FileAccess.file_exists("res://local-data/preferences.cfg")
	if had_preferences: initial_preferences = FileAccess.get_file_as_bytes("res://local-data/preferences.cfg")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames()
	await _capture("lobby")
	_find_button(main, "规则").pressed.emit()
	await _frames()
	check(main.tooltip_dialog.visible and main.tooltip_dialog.size.y < root.size.y, "scrollable rules fit the window")
	await _capture("rules")
	main.tooltip_dialog.hide()
	main.nickname.text = "界面测试"
	main.room_port.value = 24982
	_find_button(main, "创建房间").pressed.emit()
	await _frames()
	check(main.session.hosting and main.session.state.is_empty(), "host lobby entered")
	child_pid = main._open_second()
	check(child_pid > 0, "second instance launched")
	var started := Time.get_ticks_msec()
	while main.session.state.is_empty() and Time.get_ticks_msec() - started < 12000:
		await process_frame
	check(not main.session.state.is_empty(), "second game window joined")
	if main.session.state.is_empty():
		_finish()
		return
	await _frames()
	check(_card_buttons(main).size() == 12, "all friendly hands visible")
	var opening: Dictionary = main.session.state
	var death_id: int = opening.characters[0].deathrattles[0]
	_find_meta_button(main,"death_card_id",death_id).pressed.emit()
	await _frames()
	check(main.hand_lift.get("card") != null and main.hand_lift.card.card.name == opening.death_catalog[death_id].name, "own deathrattle detail opens")
	main._close_hand()
	await create_timer(0.25).timeout
	await _frames()
	await _capture("death-planning")

	# Controlled real-session round covers card, number, character and reaction UI.
	var game = H.fixture()
	var strike: int = H.give(game,0,"strike",10)
	var prophecy: int = H.give(game,1,"prophecy")
	var mirror: int = H.give(game,2,"mirror")
	var defense: int = H.give(game,3,"defense")
	var enemy_strike: int = H.give(game,4,"strike",1)
	for actor in range(3):
		H.give(game,actor,"double_strike")
		H.give(game,actor,"heal")
		H.give(game,actor,"triple_strike")
	main.session.game = game
	main.session._broadcast()
	await _frames()
	for id in [strike,prophecy,mirror]:
		await _plan_card(id)
		await _frames()
	check(main.choices == [strike,prophecy,mirror], "card clicks select each role")
	await _capture("planning")
	_find_button(main,"锁定全队出牌").pressed.emit()
	await _frames()
	check(main.session.state.ready[0], "lock button commits")
	_remote("plan",[defense,enemy_strike,0])
	await _frames()
	check(main.session.state.phase == "choosing" and main.session.state.input.type == "card", "mirror card selection UI")
	await _capture("mirror")
	_find_meta_button(main,"target_action_id",H.action_for(game,4).id).pressed.emit()
	await _frames()
	check(main.session.state.input.type == "number", "prophecy number UI")
	await _capture("number")
	_find_button(main,"5").pressed.emit()
	await _frames()
	check(game.characters[1].prediction == 5 and game.phase == "targeting", "number choice applied")
	await _capture("targeting")
	main._choose_target(0)
	await _frames()
	check(main.confirmation.visible, "friendly target confirmation displayed")
	main.confirmation.confirmed.emit()
	await _frames()
	check(game.characters[0].hp == 4, "self-target damage through UI")
	_remote("target",[0])
	await _frames()
	main._choose_target(3)
	await _frames()
	check(game.phase == "reacting" and game.request.team == 1, "client defense decision requested")
	_remote("defend",[1])
	await _frames()
	check(game.phase == "review" and game.badges[0] == 1, "round ends with prophecy badge")
	await _capture("review")
	check(_find_button(main,"下一回合") == null, "no next-round confirmation button")
	await create_timer(1.15).timeout
	await _frames()
	check(game.round_number == 2 and main.choices == [0,0,0], "new round resets selections")

	game = H.fixture()
	game.match_id = 3
	main.session.game = game
	H.begin(game,{0:H.give(game,0,"defense"),3:H.give(game,3,"triple_strike")})
	game.target(1,0)
	main.session._broadcast()
	await _frames()
	await _capture("defense")
	_find_button(main,"使用防御 · 取消攻击").pressed.emit()
	await _frames()
	check(game.characters[0].hp == 5 and game.phase == "review", "local defense button cancels attack")
	game = H.fixture()
	game.match_id = 4
	main.session.game = game
	H.give_death(game,0,"last_dance")
	H.give_death(game,3,"blood_rite")
	H.give_death(game,1,"resurrection")
	H.give_death(game,2,"vanish")
	for id in [0,1,2]:
		game.characters[id].hp = 0
		game.characters[id].death_round = game.round_number
	game.characters[3].hp = 1
	game.characters[4].hp = 2
	game._finish_round()
	main.session._broadcast()
	await _frames()
	check(game.phase == "death_targeting" and main.session.state.active_card.key == "last_dance", "dead team's deathrattle selection appears")
	check(_find_meta_button(main,"target_character_id",0).disabled and not _find_meta_button(main,"target_character_id",3).disabled, "death targeting buttons reflect legal living targets")
	_find_meta_button(main,"target_character_id",3).pressed.emit()
	await _frames()
	check(game._death_action().hits == 1 and game.characters[4].hp == 2, "dance hit queues blood rite without interrupting")
	await _capture("death-dance")
	for _i in range(4):
		_find_meta_button(main,"target_character_id",5).pressed.emit()
		await _frames()
	check(main.session.state.active_card.key == "resurrection" and game.characters[4].hp == 8, "five clicks finish dance then higher priority heal")
	await _capture("death-revive")
	var revive_button = _find_meta_button(main,"target_character_id",2)
	check(revive_button.get_global_rect().end.y < main.size.y - 40, "friendly revival target visible without scrolling")
	_find_meta_button(main,"target_character_id",2).pressed.emit()
	await _frames()
	check(game.characters[2].hp == 5 and game.characters[2].deathrattles == [109] and game.phase == "review", "revive dead ally and retrieve pending card through UI")
	check(not main.confirmation.visible, "beneficial revival needs no friendly damage confirmation")
	await _capture("death-returned")
	# Reproduce the two reported forced-target cases with the actual skip buttons.
	game = H.fixture()
	game.match_id = 5
	main.session.game = game
	H.begin(game,{0:H.give(game,0,"godslayer"),1:H.give(game,1,"strike")})
	main.session._broadcast()
	await _frames()
	check(game.request.options == [0,1], "godslayer has only friendly targets")
	await _capture("skip-ordinary")
	_find_button(main,"跳过效果").pressed.emit()
	await _frames()
	check(game.characters[0].hp == 5 and game.characters[1].hp == 5 and game._action(game.current_id).actor == 1, "skip button avoids friendly godslayer damage")
	_find_button(main,"跳过效果").pressed.emit()
	await _frames()
	check(game.phase == "review", "successive ordinary skip buttons advance")
	game = H.fixture()
	game.match_id = 6
	main.session.game = game
	H.give_death(game,0,"resurrection")
	for id in [0,3]:
		game.characters[id].hp = 0
		game.characters[id].death_round = game.round_number
	game._finish_round()
	main.session._broadcast()
	await _frames()
	check(game.request.options == [0,3], "revival includes self and enemy targets")
	await _capture("skip-resurrection")
	_find_button(main,"跳过效果").pressed.emit()
	await _frames()
	check(game.characters[3].hp == 0 and game.death_discard == [110], "skip button avoids enemy revival and consumes card")
	game = H.fixture()
	game.match_id = 7
	main.session.game = game
	H.give_death(game,0,"last_dance")
	game.characters[0].hp = 0
	game.characters[0].death_round = game.round_number
	game._finish_round()
	main.session._broadcast()
	await _frames()
	_find_meta_button(main,"target_character_id",3).pressed.emit()
	await _frames()
	await _capture("skip-dance")
	_find_button(main,"跳过剩余效果").pressed.emit()
	await _frames()
	check(game.phase == "review" and game.characters[3].hp == 4 and game.death_discard == [116], "partial dance skip keeps prior damage")
	game = H.fixture()
	game.match_id = 8
	main.session.game = game
	_activate(game,0,"divinity")
	_dead(game,0)
	H.give_death(game,3,"greed")
	_dead(game,3)
	game._finish_round()
	game.target(1,4)
	main.session._broadcast()
	await _frames()
	check(game.request.type == "deck" and game.request.count == 6,"god deck selection interface opened")
	var god_cards: Array = game.request.options.slice(0,6)
	for id in god_cards:
		_find_meta_button(main,"pick_card_id",id).pressed.emit()
		await _frames()
	await _capture("divinity")
	_find_button(main,"确认选牌 (6/6)").pressed.emit()
	await _frames()
	check(game.request.type == "hand" and game.request.team == 1,"greed discard handed to recipient")
	_remote("pick",[game.request.options[0]])
	await _frames()
	check(game.phase == "review" and game.characters[4].hand.size() == 5,"god choice resumes greed through real UI")
	game = H.fixture()
	game.match_id = 9
	main.session.game = game
	_activate(game,0,"pain")
	_dead(game,0)
	var extra_one: int = H.give(game,1,"strike",10)
	var extra_two: int = H.give(game,1,"strike",9)
	H.begin(game,{1:H.give(game,1,"strike",8)})
	game.target(0,0)
	main.session._broadcast()
	await _frames()
	check(game.request.type == "bonus","pain offers hand multi-selection after draw")
	for id in [extra_one,extra_two]:
		_find_meta_button(main,"pick_card_id",id).pressed.emit()
		await _frames()
	await _capture("pain")
	_find_button(main,"确认选牌 (2/2)").pressed.emit()
	await _frames()
	check(game.queue.size() == 3 and game._action(game.current_id).card == extra_one,"pain selected cards enter ordered queue")
	_find_button(main,"跳过效果").pressed.emit()
	await _frames()
	_find_button(main,"跳过效果").pressed.emit()
	await _frames()
	game = H.fixture()
	game.match_id = 10
	main.session.game = game
	_activate(game,0,"eye")
	_dead(game,0)
	H.give_death(game,3,"heart")
	_dead(game,3)
	H.give(game,4,"strike")
	game._finish_round()
	game.target(1,1)
	game.confirm(0); game.confirm(1)
	main.session._broadcast()
	await _frames()
	check(main.session.state.omniscient and main.session.state.characters[1].play_limit == 2,"eye and heart states shown")
	_find_button(main,"天眼 · 查看卡牌").pressed.emit()
	await _frames()
	check(main.eye_dialog.visible and main.eye_text.text.contains("未分配的亡语牌"),"eye inspection dialog shows all card locations")
	await _capture("eye")
	game._strip_deaths(0)
	main.session._broadcast()
	await _frames()
	check(not main.eye_dialog.visible and main.eye_text.text.is_empty(),"lost eye closes stale inspection view")
	var heart_cards: Array = game.characters[1].hand.slice(0,2)
	for id in heart_cards:
		await _plan_card(id)
		await _frames()
	check(main.choices[1] is Array and main.choices[1].size() == 2,"heart multi-selects two physical cards")
	await _capture("heart")
	_find_button(main,"锁定全队出牌").pressed.emit()
	await _frames()
	_remote("plan",[0,0,0])
	await _frames()
	check(game.queue.size() == 2,"heart two-card plan accepted by host")
	game = H.fixture()
	game.match_id = 11
	main.session.game = game
	H.give_death(game,0,"curse")
	_dead(game,0)
	game._finish_round()
	game.target(0,1)
	game.confirm(0); game.confirm(1)
	main.session._broadcast()
	await _frames()
	check(not _find_meta_button(main,"card_id",104).card.get("playable",true) and game.characters[1].hp == 3,"curse shown in hand but unplayable after start-of-round damage")
	await _capture("curse")
	game = H.fixture()
	game.match_id = 12
	main.session.game = game
	H.begin(game,{0:H.give(game,0,"attack_amulet"),3:H.give(game,3,"quick_strike")})
	game.target(1,0)
	main.session._broadcast()
	await _frames()
	check(game.phase == "responding" and _find_button(main,"翻开攻击护符 · 取消效果") != null,"amulet response controls visible")
	await _capture("amulet")
	_find_button(main,"翻开攻击护符 · 取消效果").pressed.emit()
	await _frames()
	check(game.phase == "review" and game.characters[0].hp == 5,"UI response cancels enemy attack")
	game = H.fixture()
	game.match_id = 13
	main.session.game = game
	H.give(game,3,"feign"); H.give(game,3,"magic_strike"); H.give(game,3,"holy_amulet")
	H.begin(game,{0:H.give(game,0,"peek")})
	game.target(0,3)
	main.session._broadcast()
	await _frames()
	check(game.request.type == "inspect" and _find_button(main,"查看完毕") != null,"private peek acknowledgement displayed")
	await _capture("peek")
	_find_button(main,"查看完毕").pressed.emit()
	await _frames()
	check(game.phase == "review" and not main.session.state.input.has("cards"),"peek UI clears inspected hand after continue")
	game = H.fixture()
	game.match_id = 14
	main.session.game = game
	H.begin(game,{0:H.give(game,0,"overload")})
	game.confirm(0); game.confirm(1)
	H.give(game,0,"strike",10); H.give(game,0,"strike",9)
	main.session._broadcast()
	await _frames()
	var overload_cards: Array = game.characters[0].hand.slice(0,3)
	for id in overload_cards:
		await _plan_card(id)
		await _frames()
	check(main.choices[0] is Array and main.choices[0].size() == 3,"overload selects three ordinary cards in UI")
	await _capture("overload")
	_find_button(main,"锁定全队出牌").pressed.emit()
	await _frames()
	_remote("plan",[0,0,0])
	await _frames()
	check(game.queue.size() == 3,"overload UI submits all three cards")
	game = H.fixture()
	game.match_id = 15
	main.session.game = game
	H.begin(game,{0:H.give(game,0,"reverse"),1:H.give(game,1,"magic_strike"),3:H.give(game,3,"strike")})
	main.session._broadcast()
	await _frames()
	check(game.reversed_order and game.input_action.actor == 1,"reversed priority display matches active low-main card")
	await _capture("reverse")
	game = H.fixture()
	game.match_id = 16
	main.session.game = game
	H.give_death(game,0,"death_sentence")
	H.begin(game,{0:H.give(game,0,"feign")})
	main.session._broadcast()
	await _frames()
	check(game.characters[0].hp == 5 and game.phase == "death_targeting","feign opens living character death selection")
	await _capture("feign")
	_find_button(main,"跳过效果").pressed.emit()
	await _frames()
	check(game.phase == "review","feign resumes after skipped death target")
	_find_button(main,"离开房间").pressed.emit()
	await _frames()
	check(main.session.state.is_empty() and not main.session.active, "leave returns to lobby")
	_finish()

func _dead(game, id: int) -> void:
	game.characters[id].hp = 0
	game.characters[id].death_round = game.round_number

func _activate(game, owner: int, key: String) -> void:
	var id: int = H.give_death(game,owner,key)
	game._activate({"actor":owner,"card":id},owner)
	game.death_revealed.append(id)

func _remote(kind: String, values: Array) -> void:
	var game = main.session.game
	main.session._apply(1,kind,values,game.match_id,game.round_number,game.revision)

func _find_button(node: Node, title: String):
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found = _find_button(child,title)
		if found != null: return found
	return null

func _find_meta_button(node: Node, key: String, value: int):
	if node is Button and node.get_meta(key,-1) == value: return node
	for child in node.get_children():
		var found = _find_meta_button(child,key,value)
		if found != null: return found
	return null

func _card_buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button and node.has_meta("card_id"): result.append(node)
	for child in node.get_children(): result.append_array(_card_buttons(child))
	return result

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-results")
	root.get_texture().get_image().save_png("res://test-results/ui-" + label + ".png")

func _finish() -> void:
	if child_pid > 0 and OS.is_process_running(child_pid): OS.kill(child_pid)
	if had_preferences:
		var file := FileAccess.open("res://local-data/preferences.cfg",FileAccess.WRITE)
		file.store_buffer(initial_preferences)
		file.close()
	else:
		DirAccess.remove_absolute("res://local-data/preferences.cfg")
	print("UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _plan_card(id: int) -> void:
	_find_meta_button(main,"card_id",id).pressed.emit()
	await _frames()
	_find_meta_button(main,"play_card_id",id).pressed.emit()
	await _frames()
