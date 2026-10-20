extends SceneTree
const H = preload("res://tests/helpers.gd")
var main
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V012_UI_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func frames() -> void:
	for _i in range(4): await process_frame
func meta(node: Node, key: String, value):
	if node.has_meta(key) and node.get_meta(key) == value: return node
	for child in node.get_children():
		var found = meta(child,key,value)
		if found != null: return found
	return null
func show_game(g, team: int = 0) -> void:
	main.session.team = team; main.session.state = g.snapshot(team)
	main.session.state.names = ["状态测试","对手"]
	main.session.changed.emit()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v012-"+name+".png")
func activate(g, owner: int, key: String, target: int) -> int:
	var card: int = H.give_death(g,owner,key)
	g._activate({"actor":owner,"card":card},target); g.death_revealed.append(card)
	return card
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(0.25).timeout
	var g = H.fixture(8)
	for id in range(6): H.give(g,id,"strike"); H.give(g,id,"heal")
	activate(g,0,"blessing",1); activate(g,2,"prison",3); activate(g,3,"privilege",5)
	activate(g,4,"ghost",4); activate(g,0,"pain",0); activate(g,1,"eye",1); activate(g,2,"divinity",2)
	H.give_death(g,0,"immortal"); g.death_revealed.append(120)
	g.characters[0].shield = 2; g.characters[1].prediction = 5
	g.characters[3].silenced_round = 2; g.characters[4].overload_round = 2
	g.characters[5].extra_round = 2; g.characters[5].extra_count = 1
	show_game(g); await frames(); await shot("persistent-statuses")
	for id in range(6):
		var aura: Control = meta(main,"status_actor",id)
		check(aura != null and aura.is_processing(),"each affected knight has an active loop")
		check(aura.mouse_filter == Control.MOUSE_FILTER_IGNORE,"aura does not intercept target clicks")
		check(aura.get_parent() == meta(main,"knight_id",id),"aura attached to corresponding knight")
	var first: Control = meta(main,"status_actor",0)
	var elapsed: float = first.elapsed
	await create_timer(1.6).timeout
	check(first.elapsed > elapsed+1.3 and is_instance_valid(first),"loop survives past one-shot animation duration")
	main._schedule_render(); await frames()
	check(meta(main,"status_actor",0).elapsed > elapsed+1.3,"board rebuild keeps continuous clock")
	for team in [0,1]:
		show_game(g,team); await frames()
		for id in range(6):
			var aura: Control = meta(main,"status_actor",id)
			check(root.get_visible_rect().encloses(aura.get_global_rect()),"state overlay in viewport for both teams")
		await shot("perspective-%d" % team)
	root.size = Vector2i(960,640); await frames(); await shot("small-window")
	root.size = Vector2i(1200,800); await frames()
	# Actual defense application, unrelated decision, decline, consumption.
	g = H.fixture(8); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike"),4:H.give(g,4,"double_strike")})
	show_game(g); await frames(); check(meta(main,"status_actor",0) == null,"shield absent before application impact")
	g.advance_animation(); g.advance_animation(); show_game(g); await frames()
	check(meta(main,"status_actor",0) != null and g.animation.is_empty(),"shield remains after animation completes")
	await shot("defense-held")
	g.target(1,0); g.defend(0,false)
	while not g.animation.is_empty(): g.advance_animation()
	show_game(g); await frames(); check(meta(main,"status_actor",0) != null,"declined defense still visible")
	g.target(1,0); g.defend(0,true); show_game(g); await frames()
	check(meta(main,"status_actor",0) == null,"consuming defense removes its loop immediately")
	g = H.fixture(8); var card := activate(g,0,"prison",3)
	show_game(g); await frames(); check(meta(main,"status_actor",3) != null,"prison persists outside activation")
	g._lose_death(0,card); show_game(g); await frames(); check(meta(main,"status_actor",3) == null,"losing source clears ongoing loop")
	for key in ["hasty_spell","bounty","godslayer","plunder","silence","heal_other"]:
		g = H.fixture(8)
		g.characters[3].hp = 0
		var chosen := {0:H.give(g,0,key)}
		if key == "godslayer": chosen[1] = H.give(g,1,"collect")
		H.begin(g,chosen); show_game(g); await frames()
		var label: RichTextLabel = meta(main,"target_description",true)
		var panel: Control = meta(main,"decision_panel",true)
		check(label != null and not label.text.contains("苦肉"),key+" has card-specific instruction")
		check(label.get_line_count() == label.get_visible_line_count(),key+" full instruction visible")
		check(panel.get_global_rect().encloses(label.get_global_rect()),key+" description within panel")
		for id in range(6):
			var target: Control = meta(main,"target_character_id",id)
			if not target.disabled: check(not panel.get_global_rect().intersects(target.get_global_rect()),key+" target remains unobscured")
		if key == "hasty_spell":
			check(not meta(main,"target_character_id",3).disabled,"dead enemy button selectable")
			await shot("target-instruction")
		if key == "bounty": await shot("long-target-instruction")
	main.session.leave(); await frames()
	check(meta(main,"status_actor",0) == null,"leaving removes status loops")
	print("V012_UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
