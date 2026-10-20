extends "res://tests/v0174_ui_test.gd"

class LocalSession extends "res://scripts/session.gd":
	# Exercise the real intent validator without opening a network port.
	func _broadcast() -> void:
		state = game.snapshot(team)
		state.names = ["本地测试","对手"]
		changed.emit()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error("V0182_GIFT_UI_FAIL "+label)

func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new();motion.position = at;root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at;event.global_position = at;event.pressed = pressed
		root.push_input(event,true)
	await frames()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0182-gift-"+name+".png")

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
	var card: int = H.give(g,0,"strike")
	var extra: int = H.give(g,0,"heal")
	g.death_deck.erase(104);g.characters[0].hand.append(104)
	H.begin(g,{0:H.give(g,0,"gift")})
	main.session.game = g;main.session._broadcast();await frames()
	check("1/2" in meta(main,"target_description",true).text,"gift explicitly identifies recipient step")
	await click(main.board._find_hand_card(card))
	check(main.hand_focus.is_empty() and "先点击" in main.notice,"clicking hand before recipient explains next action")
	check(meta(main,"selection_panel",true) == null,"no premature card choice")
	await shot("step-one")
	await click(meta(main,"knight_id",1))
	check(g.phase == "selecting" and g.request.type == "gift","actual recipient click opens private gift selection")
	check(main.notice.is_empty() and meta(main,"selection_panel",true) != null,"old reminder clears and picker is visible")
	check(meta(main,"pick_confirm",true).disabled,"empty selection requires explicit skip")
	await click(meta(main,"pick_card_id",card))
	check(main.pick_cards == [card] and not meta(main,"pick_confirm",true).disabled,"actual first card click enables confirmation")
	await click(meta(main,"pick_card_id",extra))
	check(main.pick_cards.size() == 2 and not meta(main,"pick_confirm",true).disabled,"two real card clicks enable confirmation")
	await click(meta(main,"pick_card_id",card))
	check(main.pick_cards == [extra],"actual second click deselects")
	await click(meta(main,"pick_card_id",104))
	check(main.pick_cards.has(104) and main.pick_cards.size() == 2,"curse can be selected for transfer")
	await shot("step-two")
	await click(meta(main,"pick_confirm",true))
	check(g.characters[1].hand.has(extra) and g.characters[1].hand.has(104),"confirmation transfers both chosen physical cards")
	check(g.characters[0].hand == [card] and g.phase == "review","unchosen card remains and gift finishes")
	# A second fixture exercises actual one-card submission through the same UI.
	g=H.fixture(8);serial+=1;g.match_id=serial
	card=H.give(g,0,"strike");extra=H.give(g,0,"heal")
	H.begin(g,{0:H.give(g,0,"gift")})
	main.session.game=g;main.session._broadcast();await frames()
	await click(meta(main,"knight_id",1))
	await click(meta(main,"pick_card_id",card))
	check(main.pick_cards==[card] and not meta(main,"pick_confirm",true).disabled,"one of two available cards is sufficient")
	await click(meta(main,"pick_confirm",true))
	check(g.characters[1].hand==[card] and g.characters[0].hand==[extra],"UI confirms exactly the single selected physical card")
	check(g.phase=="review","single-card gift finishes normally")
	print("V0182_GIFT_UI_RESULT checks=%d failures=%d" % [checks,failures])
	main.session.leave();main.queue_free();await frames()
	quit(0 if failures == 0 else 1)
