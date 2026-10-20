extends SceneTree
const H = preload("res://tests/helpers.gd")
const S = preload("res://tests/v011_scenarios.gd")
const Styles = preload("res://scripts/card_effect_styles.gd")
var main
var checks := 0
var failures := 0
var motifs := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V011_UI_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func frames() -> void:
	for _i in range(3): await process_frame
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
func pose(g, fraction: float):
	await frames()
	var effect = meta(main,"effect_animation",g.animation.id)
	check(effect != null,"renderer exists")
	if effect == null: return null
	effect.set_process(false); effect.clock_started = -1
	effect.elapsed = H.Rules.StrikeStyles.duration(effect.event)/1000.0*fraction
	effect._process(0)
	await RenderingServer.frame_post_draw
	return effect
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v011-"+name+".png")
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(0.3).timeout
	var serial := 1100
	for key in Styles.PROFILES:
		if key in ["bounty","glory","death"]: continue
		var death: bool = H.fixture().death_catalog.values().any(func(c): return c.key == key)
		var g = S.setup(key,death,true); serial += 1; g.match_id = serial
		for _i in range(160):
			if not g.animation.is_empty() and g.animation.get("style","") == key: break
			if g.phase in ["review","ended"]: break
			S.step(g)
		check(not g.animation.is_empty(),key+" live effect found")
		if g.animation.is_empty(): continue
		show_game(g)
		var effect = await pose(g,0.65)
		check(effect.card_effect != null,key+" uses family renderer")
		check(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE,key+" visual cannot intercept input")
		check(effect.sprites.size() == 6,key+" sprites bound in board coordinates")
		if key in ["mirror","suppress"]: check(effect.target_point != Vector2.ZERO,key+" points at the actual played card")
		await shot(key+"-travel")
		g.advance_animation(); show_game(g); effect = await pose(g,0.24)
		check(g.phase == "animating" and g.animation.stage == "impact",key+" impact remains visible")
		check(effect.card_effect.motif == g.animation.motif,key+" distinctive motif selected")
		motifs[g.animation.motif] = true
		await shot(key+"-impact")
		for fraction in [0.0,0.99,1.0]:
			effect = await pose(g,fraction)
		show_game(g,1); effect = await pose(g,0.28)
		check(effect._knight(3).y > effect._knight(0).y,key+" guest perspective aligned")
		if key == "last_dance":
			root.size = Vector2i(960,640); await frames()
			effect = await pose(g,0.25)
			await shot("guest-small")
			root.size = Vector2i(1200,800); await frames()
		if key == "collect":
			effect.set_process(true); effect.clock_started = Time.get_ticks_msec()-100
			main.effect_started = effect.clock_started
			await create_timer(0.05).timeout
			var elapsed: float = effect.elapsed
			main._schedule_render(); await frames()
			check(meta(main,"effect_animation",g.animation.id).elapsed >= elapsed,"UI rebuild keeps animation progress")
	main.session.leave(); await frames()
	check(meta(main,"effect_animation",-1) == null,"leaving cleans effect overlay")
	print("V011_UI_RESULT checks=%d failures=%d motifs=%d" % [checks,failures,motifs.size()])
	quit(0 if failures == 0 else 1)
