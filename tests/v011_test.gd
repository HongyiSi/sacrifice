extends SceneTree
const H = preload("res://tests/helpers.gd")
const S = preload("res://tests/v011_scenarios.gd")
var checks := 0
var failures := 0
var observed := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V011_FAIL "+label)

func _initialize() -> void: _run.call_deferred()

func drain(g, label: String) -> void:
	for _i in range(350):
		if g.phase in ["review","ended"] and g.animation.is_empty(): return
		if not g.animation.is_empty():
			var e: Dictionary = g.animation
			observed[g._info(e.action).key] = true
			check(g.snapshot(0).animation == g.snapshot(1).animation,label+" public animation identical")
			check(g.skip_effect(0) != "" and g.skip_effect(1) != "",label+" animation input blocked")
			check(not e.has("options") and not e.has("cards"),label+" no hidden options in effect")
			for team in [0,1]:
				var s: Dictionary = g.snapshot(team)
				if not s.omniscient:
					for c in s.characters:
						if c.team != team: check(c.hand.is_empty(),label+" hidden hands stay private")
		var error: String = S.step(g)
		check(error.is_empty(),label+": "+error)
		if not error.is_empty(): return
	check(false,label+" exceeded effect/choice limit")

func equivalent(g, plain, key: String) -> void:
	for field in ["characters","deck","discard","death_deck","death_discard","effects","queue","death_queue","badges","log_lines","phase","winner","win_reason","skipped","mirrors","reversed_order"]:
		check(g.get(field) == plain.get(field),key+" same rules result: "+field)

func _run() -> void:
	var base = H.fixture()
	for death in [false,true]:
		var seen := {}
		var catalog: Dictionary = base.death_catalog if death else base.catalog
		for card in catalog.values():
			var key: String = card.key
			if seen.has(key): continue
			seen[key] = true
			var g = S.setup(key,death,true)
			var plain = S.setup(key,death,false)
			drain(g,key); drain(plain,key+" instant")
			equivalent(g,plain,key)
			check(observed.has(key),key+" produced a visible effect")
	# A win or a private request reached at impact must survive the visual pause.
	var g = H.fixture(); g.badges[0] = 3; g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"badge")})
	g.advance_animation()
	check(g.winner == 0 and g.phase == "animating","winning badge holds its impact")
	g.advance_animation()
	check(g.phase == "ended" and g.winner == 0,"winning badge resumes ended, not prior phase")
	g = H.fixture(); H.give_death(g,0,"divinity"); S.die(g,0)
	g._activate({"actor":0,"card":102},0); g.presentation_enabled = true
	H.begin(g,{1:H.give(g,1,"collect")})
	for _i in range(20):
		if g.animation.is_empty(): break
		g.advance_animation()
	check(g.phase == "selecting" and g.request.type == "deck","divinity restores private picker")
	check(g.snapshot(1).input.options.is_empty() and not g.snapshot(0).input.options.is_empty(),"divinity private choices remain redacted")
	drain(g,"divinity draw")
	# Curse round tick, immediate immortal revival, and removal of persistent effects.
	g = S.setup("curse",true,true); drain(g,"curse attach")
	var holder: int = g.characters.filter(func(c): return c.hand.has(104))[0].id
	H.give_death(g,holder,"immortal"); g.characters[holder].hp = 1
	g.advance_round()
	for _i in range(80):
		if g.phase == "planning": break
		check(S.step(g).is_empty(),"curse tick resumes round")
	check(g.phase == "planning" and g.characters[holder].hp == 1,"curse immediate revival remains exactly once")
	check(g.characters[holder].deathrattles == [120],"curse strip preserves immortal")
	# Generous random full-card matches exercise nested jobs and forced death queues.
	for seed_value in range(6):
		g = H.Rules.new(); g.start(891+seed_value); g.presentation_enabled = true
		var plain = H.Rules.new(); plain.start(891+seed_value)
		for round_index in range(9):
			if g.phase == "ended": break
			for team in [0,1]:
				var plan: Array = H.auto_plan(plain.snapshot(team),team)
				check(g.submit(team,plan) == "" and plain.submit(team,plan) == "","random submit")
			drain(g,"random"); drain(plain,"random instant"); equivalent(g,plain,"seed %d round %d" % [seed_value,round_index])
			if g.phase == "ended": break
			g.advance_round(); plain.advance_round()
			for _i in range(100):
				if g.phase in ["planning","ended"]: break
				check(S.step(g).is_empty(),"random preparing")
			for _i in range(100):
				if plain.phase in ["planning","ended"]: break
				check(S.step(plain).is_empty(),"random instant preparing")
	print("V011_RESULT checks=%d failures=%d visible_card_types=%d" % [checks,failures,observed.size()])
	quit(0 if failures == 0 else 1)
