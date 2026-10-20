extends SceneTree
const H = preload("res://tests/helpers.gd")
const S = preload("res://tests/v011_scenarios.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V013_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func drain(g) -> void:
	for _i in range(300):
		if g.phase in ["review","ended"] and g.animation.is_empty(): return
		check(S.step(g).is_empty(),"resumable resolution")
	check(false,"resolution terminates")
func _run() -> void:
	var g = H.fixture(8)
	check(g.catalog.size() == 89,"balanced deck has 89 physical cards")
	for spec in [["double_strike",[2,3,4,5,6]],["triple_strike",[2,4,6]],["area_strike",[3,5,7,8,9]]]:
		check(g.catalog.values().filter(func(c): return c.key == spec[0]).map(func(c): return c.secondary) == spec[1],"document ranks: "+spec[0])
	H.begin(g,{0:H.give(g,0,"holy_strike")}); g.target(0,3)
	check(g.characters[3].hp == 5,"holy strike deals three")
	g = H.fixture(8); H.give(g,3,"strike"); H.give_death(g,3,"immortal"); H.give_death(g,3,"blood_rite")
	H.begin(g,{0:H.give(g,0,"peek")}); g.target(0,3)
	check(g.request.cards.size() == 1 and g.request.deaths.size() == 2,"peek includes both hand and death cards")
	check(g.snapshot(1).input.cards.is_empty() and g.snapshot(1).input.deaths.is_empty(),"inspection content private")
	check(g.snapshot(0).characters[3].deathrattles.is_empty(),"peek does not permanently publish target deaths")
	g.pick(0,[]); check(g.phase == "review","peek finishes")
	for count in [0,1,2,3]:
		g = H.fixture(8)
		for _i in range(count): H.give(g,0,"strike")
		var before: Array = g.characters[0].hand.duplicate()
		H.begin(g,{0:H.give(g,0,"elegy")})
		if count < 2:
			check(g.phase == "review" and g.characters[0].hand == before and g.characters[0].deathrattles.is_empty(),"elegy requires two cards")
		else:
			check(g.request.type == "elegy" and g.request.count == 2,"elegy chooses its cost")
			check(g.snapshot(1).input.options.is_empty(),"discard options private")
			check(g.pick(0,[before[0]]) != "" and g.pick(0,[before[0],before[0]]) != "","cost must be two distinct cards")
			g.pick(0,before.slice(0,2))
			check(g.characters[0].hand.size() == count-2 and g.characters[0].deathrattles.size() == 1,"elegy consumes chosen cost then draws")
	g = H.fixture(); H.give(g,0,"strike"); H.give(g,0,"heal")
	H.begin(g,{0:H.give(g,0,"elegy")}); g.skip_effect(0)
	check(g.characters[0].hand.size() == 2 and g.characters[0].deathrattles.is_empty(),"skipped elegy spends no cost")
	g = H.fixture(); g.death_deck.erase(104); g.characters[0].hand.append(104); var cost := H.give(g,0,"strike")
	H.begin(g,{0:H.give(g,0,"elegy")}); g.pick(0,[104,cost])
	check(g.characters[0].hand.has(104) and g.characters[0].hand.has(cost) and g.characters[0].deathrattles.is_empty(),"curse cannot pay elegy cost and insufficient eligible cards are untouched")
	g = H.fixture(8); S.die(g,0); g.characters[1].hp = 2; H.give_death(g,0,"blood_rite")
	g.presentation_enabled = true; H.begin(g,{})
	check(g.characters[0].max_hp == 8 and g.animation.kind == "heal","blood rite waits for impact")
	g.advance_animation()
	check(g.characters[0].max_hp == 10 and g.characters[0].hp == 0,"dead owner gains cap without revival")
	check(g.characters[1].max_hp == 10 and g.characters[1].hp == 10 and g.characters[2].hp == 10,"living allies fill new cap")
	check(g.characters[3].max_hp == 8,"enemy cap unchanged")
	drain(g); g._revive(0,5); g._heal(g.characters[0],99)
	check(g.characters[0].hp == 10,"revival and later heals respect increased cap")
	# A real reversed round: kill at 10, revive at 1, reveal preserved strike at 5.
	g = H.fixture(8); g.characters[0].hp = 1
	H.begin(g,{0:H.give(g,0,"strike"),1:H.give(g,1,"reverse"),2:H.give(g,2,"raise_dead"),3:H.give(g,3,"holy_strike")})
	g.target(1,0)
	check(not H.action_for(g,0).revealed and H.action_for(g,0).status == "pending","death retains unrevealed ordinary card")
	g.target(0,0)
	check(g.phase == "targeting" and g.input_action.actor == 0 and H.action_for(g,0).revealed,"revived before reveal can resolve")
	g.target(0,3); check(g.characters[3].hp == 7,"preserved strike applies normally")
	g = H.fixture(8); g.characters[0].hp = 1; H.give_death(g,0,"immortal")
	H.begin(g,{0:H.give(g,0,"double_strike",2),3:H.give(g,3,"double_strike",6)})
	g.target(1,0)
	check(g.characters[0].hp == 1 and H.action_for(g,0).status == "cancelled" and g.phase == "review","already revealed card stays cancelled after instant revival")
	g = H.fixture(8); g.characters[0].hp = 1; H.give_death(g,0,"immortal")
	H.begin(g,{0:H.give(g,0,"strike"),3:H.give(g,3,"quick_strike")}); g.target(1,0)
	check(g.phase == "targeting" and g.input_action.actor == 0,"instant revival preserves unrevealed card")
	g.target(0,3)
	g = H.fixture(8); g.characters[0].hp = 1
	H.begin(g,{0:H.give(g,0,"strike",1),1:H.give(g,1,"strike",10),3:H.give(g,3,"quick_strike")}); g.target(1,0)
	check(not H.action_for(g,0).revealed and H.action_for(g,0).status == "cancelled","dead member of live reveal batch never flips")
	g._revive(0,5); g.target(0,3)
	check(g.phase == "review" and H.action_for(g,0).status == "cancelled","revival after missed reveal does not recover action")
	# Both ordinary and queued death cards must expose a dedicated start boundary.
	for death in [false,true]:
		g = H.fixture(8); g.presentation_enabled = true; g.resolution_presentation_enabled = true
		if death: S.die(g,0); H.give_death(g,0,"blood_rite"); H.begin(g,{})
		else: H.begin(g,{0:H.give(g,0,"heal")})
		check(g.animation.kind == "card_start" and g.animation.action.get("death",false) == death,"public card start before effects")
		check(g.snapshot(0).animation == g.snapshot(1).animation,"start cue identical in both views")
		g.advance_animation(); check(g.animation.kind == "card_start" and g.animation.stage == "impact","brief lifted hold")
		g.advance_animation(); check(g.animation.kind == "heal","effect follows card cue")
		drain(g)
	print("V013_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
