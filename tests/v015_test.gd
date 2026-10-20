extends SceneTree
const H = preload("res://tests/helpers.gd")
const S = preload("res://tests/v011_scenarios.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V015_FAIL "+label)
func activate(g, owner: int, key: String, target: int = -1) -> void:
	var id: int = H.give_death(g,owner,key)
	g._activate({"actor":owner,"card":id},owner if target < 0 else target)
func drain(g) -> void:
	for _i in range(350):
		if g.phase in ["review","ended"] and g.animation.is_empty(): return
		check(S.step(g).is_empty(),"resolution advances")
	check(false,"resolution terminates")
func _initialize() -> void:
	var g = H.fixture(8)
	check(g.catalog.size() == 89 and g.death_catalog.size() == 20,"physical deck counts preserved")
	check(g.catalog.values().filter(func(c): return c.key == "reverse")[0].secondary == 3,"reverse secondary 3")
	check(g.catalog.values().filter(func(c): return c.key == "holy_amulet")[0].secondary == 2,"holy amulet secondary 2")
	for spec in [["holy_strike",3,"攻击"],["quick_strike",2,"攻击"],["hasty_spell",2,"技能"]]:
		g = H.fixture(8); var id: int = H.give(g,0,spec[0]); H.begin(g,{0:id})
		check(g.catalog[id].type == spec[2],"updated type "+spec[0])
		check(g.request.description.contains("选择一个棋子"),"pawn targeting description "+spec[0])
		g.target(0,3); check(g.characters[3].hp == 8-spec[1],"updated damage "+spec[0])
	# A high priority attack is still blocked by an already active defense/blessing.
	g = H.fixture(8); g.characters[3].shield = 1
	H.begin(g,{0:H.give(g,0,"holy_strike")}); g.target(0,3)
	check(g.phase == "reacting","holy strike is now eligible for defense")
	g.defend(1,true); check(g.characters[3].hp == 8 and g.characters[3].shield == 0,"defense consumes exactly one charge")
	g = H.fixture(8); activate(g,4,"blessing",3)
	H.begin(g,{0:H.give(g,0,"holy_strike")}); g.target(0,3)
	check(g.characters[3].hp == 8,"blessing cancels new attack holy strike")
	# Even a privileged magic amulet must not cancel an attack.
	g = H.fixture(8); activate(g,4,"privilege",3)
	H.begin(g,{0:H.give(g,0,"holy_strike"),3:H.give(g,3,"magic_amulet")}); g.target(0,3)
	check(g.phase == "review" and g.characters[3].hp == 5,"holy strike not a skill for magic amulet")
	for immortal in [false,true]:
		g = H.fixture(8); g.characters[3].hp = 1
		if immortal: H.give_death(g,3,"immortal")
		H.begin(g,{0:H.give(g,0,"bounty")}); g.target(0,3)
		check(g.characters[0].hand.size() == 2 and g.death_events == 1,"bounty draws two after death, including immediate revival")
	g = H.fixture(8); g.characters[1].hp = 1
	H.begin(g,{0:H.give(g,0,"bounty")}); g.target(0,1)
	check(g.characters[0].hand.is_empty(),"ally kill still gives no bounty")
	g = H.fixture(8); var loot: int = H.give(g,1,"strike")
	H.begin(g,{0:H.give(g,0,"plunder")})
	check(not g.request.options.has(0) and g.request.options.size() == 5,"plunder other pawns only")
	check(not g.target(0,0).is_empty() and g.request.options.has(1),"self plunder rejected without spending action")
	g.target(0,1); check(g.characters[0].hand == [loot],"plunder ally allowed")
	# Cost follows the entire forced death batch, even its interactive choices.
	g = H.fixture(8); g.characters[0].hp = 1; H.give_death(g,0,"blood_rite")
	H.begin(g,{0:H.give(g,0,"feign")})
	check(g.characters[0].max_hp == 10 and g.characters[0].hp == 8 and g.death_events == 0,"feign heals via blood rite before losing two")
	g = H.fixture(8); H.give_death(g,0,"death_sentence")
	H.begin(g,{0:H.give(g,0,"feign")})
	check(g.request.type == "character" and g.characters[0].hp == 8,"feign waits for forced death target before cost")
	g.skip_effect(0); check(g.characters[0].hp == 6,"skipping a death effect still pays feign HP cost")
	for immortal in [false,true]:
		g = H.fixture(8); g.characters[0].hp = 2
		if immortal: H.give_death(g,0,"immortal")
		H.begin(g,{0:H.give(g,0,"feign")})
		check(g.death_events == 1 and g.characters[0].hp == (1 if immortal else 0),"feign cost produces ordinary death and immediate immortal")
	g = H.fixture(8); activate(g,1,"blessing",0); g.characters[0].shield = 1
	H.begin(g,{0:H.give(g,0,"feign")})
	check(g.characters[0].hp == 6 and g.phase == "review","HP loss bypasses attack protections without a defense prompt")
	# Ghost stays activated but only generates cards while dead.
	for hp in [0,5]:
		g = H.fixture(8); activate(g,0,"ghost"); g.characters[0].hp = hp
		H.begin(g,{})
		var ghosts: Array = g.queue.filter(func(a): return a.origin == "ghost")
		check(ghosts.size() == (1 if hp == 0 else 0),"ghost only plays when dead")
		check(g.snapshot(0).characters[0].ongoing_effects[0].dormant == (hp > 0),"ghost display matches active condition")
		if hp == 0:
			check(ghosts[0].secondary == 100,"ghost keeps secondary 100")
			g.target(0,3); check(g.characters[3].hp == 7,"dead ghost strike still resolves")
	# All healing sources share the prohibition; increasing max HP is independent.
	for key in ["heal","team_heal","heal_other","blood_rite"]:
		g = H.fixture(8); activate(g,2,"blessing",0); g.characters[0].hp = 3
		g.presentation_enabled = true
		if key == "blood_rite": S.die(g,1); H.give_death(g,1,key); H.begin(g,{})
		else:
			H.begin(g,{(1 if key == "heal_other" else 0):H.give(g,1 if key == "heal_other" else 0,key)})
			if key == "heal_other": g.target(0,0)
		check(g.animation.kind == "heal","healing animation available "+key)
		var target: Dictionary = g.animation.targets.filter(func(t): return t.id == 0)[0]
		check(target.heal_blocked and target.amount == 0 and target.after == 3,"heal UI never promises blocked recovery "+key)
		g.advance_animation(); check(g.characters[0].hp == 3,"blessing blocks healing "+key)
		drain(g)
		if key == "blood_rite": check(g.characters[0].max_hp == 10 and g.characters[2].hp == 10,"blood rite still grants cap; others heal")
		g._lose_death(2,108); g._heal(g.characters[0],2)
		check(g.characters[0].hp == 5,"loss of blessing restores ability to heal")
	g = H.fixture(8); activate(g,2,"blessing",0); S.die(g,0); H.give_death(g,1,"resurrection"); S.die(g,1)
	H.begin(g,{}); g.target(0,0)
	check(g.characters[0].hp == 5,"blessing does not prevent resurrection")
	# Original one-use/one-round defense; held amulets stay hidden until used.
	g = H.fixture(8); H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike"),4:H.give(g,4,"double_strike")})
	g.target(1,0); g.defend(0,true); g.target(1,0)
	check(g.characters[0].hp == 6 and g.characters[0].shield == 0,"defense only blocks one attack")
	g = H.fixture(8); H.begin(g,{0:H.give(g,0,"defense")}); g.advance_round()
	check(g.characters[0].shield == 0,"unused defense expires next round")
	g = H.fixture(8); var guard: int = H.give(g,0,"holy_amulet")
	H.begin(g,{0:guard,3:H.give(g,3,"strike")})
	check(not H.action_for(g,0).revealed,"amulet not proactively revealed")
	g.target(1,0); g.respond(0,g.request.options[0])
	check(H.action_for(g,0).revealed and g.discard.has(guard),"response publicly reveals and consumes amulet")
	print("V015_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
