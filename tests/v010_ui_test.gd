extends SceneTree
const H = preload("res://tests/helpers.gd")
const Styles = preload("res://scripts/strike_styles.gd")
var main
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V010_UI_FAIL "+label)
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
	main.session.team = team
	main.session.state = g.snapshot(team)
	main.session.state.names = ["特效测试","对手"]
	main.session.changed.emit()
func pose(g, fraction: float) -> Control:
	await frames()
	var effect: Control = meta(main,"effect_animation",g.animation.id)
	check(effect != null and effect.strike_effect != null,"strike renderer created")
	effect.set_process(false)
	effect.clock_started = -1
	effect.elapsed = Styles.duration(effect.event)/1000.0*fraction
	effect._process(0)
	await RenderingServer.frame_post_draw
	return effect
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v010-"+name+".png")
func fixture(key: String, serial: int):
	var g = H.fixture(8); g.match_id = serial; g.presentation_enabled = true
	if key in ["glory","bounty"]: g.characters[3].hp = 1
	if key == "judgment": g.characters[3].hp = 2
	for actor in range(6):
		H.give(g,actor,"strike"); H.give(g,actor,"heal")
	H.give_death(g,1,"pain"); H.give_death(g,4,"resurrection")
	var chosen := {0:H.give(g,0,key)}
	if key == "godslayer": chosen[3] = H.give(g,3,"collect")
	H.begin(g,chosen)
	if key == "godslayer":
		while not g.animation.is_empty(): g.advance_animation()
	if g.phase == "targeting": g.target(0,3)
	return g
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(0.35).timeout
	var serial := 100
	for key in Styles.PROFILES:
		serial += 1
		var g = fixture(key,serial)
		show_game(g)
		var effect: Control = await pose(g,0.58)
		check(effect.strike_effect.key == key,"distinct profile displayed: "+key)
		check(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE,"effect never swallows controls")
		check(effect.sprites.has(3),"target knight bound for hit response")
		await shot(key+"-travel")
		var before: int = g.characters[3].hp
		check(main.session.state.characters[3].hp == before,"HP unchanged while weapon is travelling")
		g.advance_animation(); show_game(g)
		effect = await pose(g,0.22)
		check(main.session.state.characters[3].hp == g.characters[3].hp,"HP changes with displayed impact")
		var saved: Dictionary = effect.sprites[3]
		check(not saved.node.position.is_equal_approx(saved.position),"knight recoils at impact: "+key)
		await shot(key+"-impact")
		# Resizing and either team perspective must use corresponding knight anchors.
		show_game(g,1); effect = await pose(g,0.22)
		check(effect._knight(3).y > effect._knight(0).y,"guest sees hit on the same role at bottom")
		if key == "magic_strike":
			root.size = Vector2i(960,640); await frames()
			effect = await pose(g,0.3)
			check(root.get_visible_rect().has_point(effect.get_global_transform()*effect._knight(3)),"hit remains aligned in small window")
			await shot("guest-small")
			root.size = Vector2i(1200,800); await frames()
		g.advance_animation()
		while not g.animation.is_empty(): g.advance_animation()
		show_game(g); await frames()
		check(meta(main,"effect_animation",g.animation.get("id",-1)) == null,"effects cleaned up after continuation")
	var g = fixture("area_strike",201)
	# Real-time continuity: an unrelated UI rebuild must not restart the windup.
	show_game(g); await frames(); await create_timer(0.16).timeout
	var effect: Control = meta(main,"effect_animation",g.animation.id)
	var elapsed: float = effect.elapsed
	main._schedule_render(); await frames()
	check(meta(main,"effect_animation",g.animation.id).elapsed >= elapsed,"UI refresh preserves flight progress")
	main.session.leave(); await frames()
	check(meta(main,"effect_animation",1) == null,"leaving removes effects")
	print("V010_UI_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
