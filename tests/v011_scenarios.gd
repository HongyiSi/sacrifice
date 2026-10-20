extends RefCounted
const H = preload("res://tests/helpers.gd")

static func die(g, id: int) -> void:
	g.characters[id].hp = 0; g.characters[id].death_round = g.round_number

static func setup(key: String, death: bool, animated: bool = true):
	var g = H.fixture(5)
	g.presentation_enabled = animated
	if key in g.BASIC_CARDS: g.resolution_presentation_enabled = true
	if key in g.DISCARD_CARDS:
		var card: int = H.give(g,0,key)
		g.phase="resolution";g.turn_stage="resolution"
		g._discard_hand_card(g.characters[0],card)
		g._push([{"op":"planning"}]);g._pump()
		return g
	for id in range(6): H.give(g,id,"strike")
	if death:
		H.give_death(g,0,key)
		if key == "immortal":
			g.characters[0].hp = 1
			H.begin(g,{3:H.give(g,3,"strike")})
			g.target(1,0)
			return g
		if key == "life_steal": g.characters[3].hp = 1
		if key == "mediocrity":
			H.give_death(g,3,"ghost"); H.give_death(g,3,"immortal")
			g._activate({"actor":3,"card":115},3)
		die(g,0); H.begin(g,{})
	else:
		var chosen := {0:H.give(g,0,key)}
		if key == "elegy": H.give(g,0,"heal")
		if key == "gift": H.give(g,0,"heal")
		if key in ["anticipation","late_suppress"]: chosen[3] = H.give(g,3,"badge")
		if key in ["mirror","suppress"]: chosen[3] = H.give(g,3,"strike")
		if key == "godslayer": chosen[3] = H.give(g,3,"collect")
		if key == "raise_dead": die(g,1)
		if key == "feign": H.give_death(g,0,"legacy")
		if key == "judgment": g.characters[3].hp = 2
		if key in ["holy_amulet","attack_amulet","magic_amulet"]:
			chosen[3] = H.give(g,3,"magic_strike" if key == "magic_amulet" else "strike")
		H.begin(g,chosen)
	return g

static func step(g) -> String:
	if not g.animation.is_empty(): g.advance_animation(); return ""
	if g.request.is_empty(): return "no request in "+g.phase
	var team: int = g.request.team
	var s: Dictionary = g.snapshot(team)
	match g.phase:
		"targeting","death_targeting":
			var target: int = H.auto_input(s)
			if s.active_card.key in ["strike","magic_strike"] and s.active_action.actor == 3 and g.request.options.has(0): target = 0
			return g.target(team,target)
		"choosing": return g.choose(team,H.auto_input(s))
		"selecting": return g.pick(team,H.auto_pick(s))
		"responding": return g.respond(team,g.request.options[0])
		"reacting": return g.defend(team,true)
	return "unexpected phase "+g.phase
