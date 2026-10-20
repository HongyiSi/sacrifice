extends SceneTree
const H = preload("res://tests/helpers.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V09_FAIL "+label)
func _initialize() -> void:
	_run.call_deferred()
func _finish_fx(g) -> void:
	var guard := 0
	while not g.animation.is_empty() and guard < 30:
		g.advance_animation(); guard += 1
	check(guard < 30,"animation queue drains")
func _run() -> void:
	var g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"prophecy")})
	check(g.request.options == [1,2,3,4,5,6,7,8],"prophecy offers full health range")
	check(g.choose(0,9) != "" and g.choose(0,0) != "","prophecy rejects outside range")
	check(g.choose(0,8) == "" and g.badges[0] == 1,"eight HP prophecy awards badge")
	g = H.fixture(5); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"heal"),3:H.give(g,3,"strike")})
	check(g.phase == "animating" and g.animation.kind == "heal","heal pauses for travel")
	check(g.characters[0].hp == 5 and g.animation.targets[0].after == 7,"HP remains old until light arrives")
	check(g.target(1,0) != "" and g.choose(0,1) != "" and g.submit(0,[0,0,0]) != "","inputs cannot race the animation")
	var before = g.snapshot(1)
	check(before.active_card.key == "heal" and before.animation == g.snapshot(0).animation,"both clients see same public effect")
	check(before.characters[0].hand.is_empty(),"animation never exposes enemy hands")
	g.advance_animation()
	check(g.phase == "animating" and g.characters[0].hp == 7 and g.animation.stage == "impact","healing applies exactly on impact")
	g.advance_animation()
	check(g.phase == "targeting" and g.input_action.actor == 3,"lower priority action waits for impact hold")
	g.target(1,0)
	_finish_fx(g)
	check(g.characters[0].hp == 6,"later attack resolves normally")
	g = H.fixture(5); g.presentation_enabled = true
	g.characters[1].hp = 0
	H.begin(g,{0:H.give(g,0,"team_heal")})
	check(g.animation.targets.map(func(t): return t.id) == [0,2],"team heal covers living allies only")
	g.advance_animation()
	check(g.characters[0].hp == 6 and g.characters[2].hp == 6 and g.characters[1].hp == 0,"team heal has simultaneous impact")
	_finish_fx(g)
	g = H.fixture(8); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"heal")})
	check(g.animation.targets[0].amount == 0,"full health has clear zero-gain feedback")
	_finish_fx(g)
	check(g.characters[0].hp == 8,"heal never exceeds maximum")
	g = H.fixture(5); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"heal_other")})
	g.target(0,1)
	check(g.animation.targets[0].id == 1,"targeted heal travels to selected ally")
	_finish_fx(g)
	check(g.characters[1].hp == 8,"targeted heal restores three")
	g = H.fixture(5); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike")})
	check(g.animation.kind == "shield" and g.characters[0].shield == 0,"shield formation precedes activation")
	g.advance_animation()
	check(g.characters[0].shield == 1,"shield granted on impact")
	g.advance_animation(); g.target(1,0); g.defend(0,true)
	check(g.animation.kind == "shield_block" and g.characters[0].hp == 5,"block has its own visible event and prevents damage")
	_finish_fx(g)
	check(g.phase == "review" and g.characters[0].shield == 0,"block consumes one shield and completes round")
	g = H.fixture(5); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"heal_other")})
	g.skip_effect(0)
	check(g.animation.is_empty() and g.characters[0].hp == 5,"skipped heal produces no effect")
	g = H.fixture(5); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"heal_other"),3:H.give(g,3,"magic_amulet")})
	g.target(0,3)
	if g.phase == "responding": g.respond(1,g.request.options[0])
	check(g.animation.kind == "shield_block","amulet cancellation has protective feedback")
	_finish_fx(g)
	check(g.animation.is_empty() and g.characters[3].hp == 5,"cancelled heal never starts animation")
	g = H.fixture(5); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"holy_amulet")})
	check(g.phase != "responding","unrelated defense never prompts holy amulet")
	g.advance_animation()
	check(g.characters[0].shield == 1,"unrelated defense grants its shield on impact")
	_finish_fx(g)
	check(g.phase == "review" and g.characters[0].shield == 0,"shield expires normally at round end")
	g = H.fixture(5); g.presentation_enabled = true
	H.give_death(g,0,"blessing")
	g.characters[0].hp = 0; g.characters[0].death_round = g.round_number
	H.begin(g,{})
	g.target(0,1)
	check(g.animation.kind == "blessing" and not g._has_effect("blessing",1),"blessing formation precedes persistent activation")
	_finish_fx(g)
	check(g._has_effect("blessing",1),"blessing remains active after animation")
	g.advance_round()
	H.begin(g,{3:H.give(g,3,"strike")}); g.target(1,1)
	check(g.animation.kind == "shield_block","persistent blessing visibly blocks attack")
	_finish_fx(g)
	check(g.characters[1].hp == 5,"blessing animation preserves immunity")
	g = H.fixture(3); g.presentation_enabled = true
	H.give_death(g,0,"blood_rite")
	g.characters[0].hp = 0; g.characters[0].death_round = g.round_number
	H.begin(g,{})
	check(g.animation.kind == "heal" and g.animation.targets.size() == 3,"blood rite animates cap increase on all allies")
	_finish_fx(g)
	check(g.characters[1].hp == 10 and g.characters[2].hp == 10 and g.characters[0].hp == 0,"death healing fills health without reviving source")
	print("V09_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
