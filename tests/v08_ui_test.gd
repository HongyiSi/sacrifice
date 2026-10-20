extends SceneTree
const H = preload("res://tests/helpers.gd")
const Card = preload("res://scripts/card_widget.gd")
var main
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures+=1; push_error("V08_UI_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func frames() -> void:
	for _i in range(5): await process_frame
func find_meta(node: Node, key: String, value):
	if node.has_meta(key) and node.get_meta(key) == value: return node
	for child in node.get_children():
		var found=find_meta(child,key,value)
		if found != null: return found
	return null
func button(node: Node, text: String):
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found=button(child,text)
		if found != null: return found
	return null
func count_card(node: Node, id: int) -> int:
	var count: int=1 if node is Card and node.card.get("id",-1) == id else 0
	for child in node.get_children(): count+=count_card(child,id)
	return count
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v08-"+name+".png")
func _run() -> void:
	main=load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(0.9).timeout
	check(main.music.context == 0 and main.music.player.playing,"lobby music starts")
	check(main.music.player.stream.get_length() > 10,"lobby audio decodes")
	check(main.music.player.stream.loop_end > 0,"lobby loop has an end point")
	main.session.host_room("新版测试",24992)
	main.session.names=["新版测试","对手"]
	var g=H.fixture(8); g.match_id=81
	for id in range(6):
		H.give(g,id,"strike")
		H.give(g,id,"double_strike")
		H.give(g,id,"triple_strike" if id < 5 else "magic_strike")
	for pair in [[0,"resurrection"],[1,"life_steal"],[2,"legacy"],[3,"immortal"],[4,"blood_rite"],[5,"divinity"]]: H.give_death(g,pair[0],pair[1])
	main.session.game=g; main.session._broadcast()
	await create_timer(0.9).timeout
	check(main.music.context == 1 and main.music.player.playing and main.music.player.stream.loop,"match music starts and loops")
	check(main.music.player.stream.get_length() > 60,"match audio decodes")
	var position: float=main.music.player.get_playback_position()
	main._schedule_render(); await create_timer(0.1).timeout
	check(main.music.player.get_playback_position() >= position,"UI refresh never restarts music")
	await shot("planning")
	for id in range(6): check(find_meta(main,"health_actor",id).get_meta("max_hp") == 8,"eight health gems per role")
	for actor in range(3):
		var card_id: int=g.characters[actor].hand[1]
		main._inspect_hand(actor,card_id); await frames()
		check(count_card(main,card_id) == 1,"inspection has one physical card widget")
		var lifted: Control=main.hand_lift.card
		check(lifted.get_parent().has_meta("hand_preview_card"),"selected card leaves original hand slot")
		check(lifted.scale.x >= 1 and lifted.scale.x < 1.7,"card lift is animated")
		await create_timer(0.25).timeout
		check(is_equal_approx(lifted.scale.x,1.7),"lift finishes at requested scale")
		var details: Control=find_meta(main,"card_description",card_id)
		check(not details.get_global_rect().intersects(lifted.get_global_rect()),"full description never overlaps card")
		check(details.get_global_rect().end.x <= 1440 and details.get_global_rect().position.x >= 0,"description stays within board")
		check(lifted.get_child_count() == 0 and lifted.tooltip_text.is_empty(),"no card-face rules or covering tooltip")
		await shot("lift-"+str(actor))
		main._close_hand(); await create_timer(0.25).timeout
		check(main.hand_focus.is_empty() and find_meta(main,"card_id",card_id) != null,"putting card down restores hand")
	main.choices=[g.characters[0].hand[0],0,0]
	button(main,"锁定全队出牌").pressed.emit(); await frames()
	check(button(main,"取消锁定出牌") != null,"unlock offered while opponent is not ready")
	button(main,"取消锁定出牌").pressed.emit(); await frames()
	check(g.plans[0] == null and main._selected_cards(0).size() == 1,"unlock preserves staged plan for editing")
	g=H.fixture(8); g.match_id=82
	H.begin(g,{0:H.give(g,0,"ignore")})
	main.session.game=g; main.session._broadcast(); await frames()
	var decision: Control=find_meta(main,"decision_panel",true)
	check(decision.size.x < 300 and decision.position.y < 600,"number choices sit beside resolving card")
	check(button(main,"查看卡牌效果") != null,"effect button has full wording")
	await shot("number-choice")
	button(main,"0").pressed.emit(); await frames()
	check(g.phase == "review" and button(main,"下一回合") == null,"round ends without confirmation button")
	await create_timer(1.15).timeout
	check(g.round_number == 2 and g.phase == "planning","host automatically advances round")
	g=H.fixture(8); g.match_id=83
	var god: int=H.give_death(g,0,"divinity")
	g.characters[0].hp=0; g.characters[0].death_round=g.round_number
	g._activate({"actor":0,"card":god},0)
	H.begin(g,{1:H.give(g,1,"collect")})
	main.session.game=g; main.session._broadcast(); await frames()
	var confirm: Control=find_meta(main,"pick_confirm",true)
	var grid_scroll: Control=find_meta(main,"scroll_key","pick_%s" % g.revision)
	check(confirm.get_global_rect().position.y >= grid_scroll.get_global_rect().end.y,"divinity confirm directly below card list")
	check(confirm.get_global_rect().position.y < 800,"divinity confirm is not in bottom bar")
	await shot("divinity")
	main.session.leave(); await create_timer(0.85).timeout
	check(main.music.context == 0 and main.music.player.playing,"leaving restores lobby music")
	print("V08_UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
