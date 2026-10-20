extends "res://tests/v018_test.gd"
const G = preload("res://tests/gem_scenarios.gd")

func act(g, team: int, kind: String, payload: Array = []) -> String:
	return Actions.apply(g,team,kind,payload,g.match_id,g.round_number,g.revision)

func finish_animation(g) -> void:
	for _i in range(100):
		if g.animation.is_empty(): return
		g.advance_animation()

func _initialize() -> void:
	for team in [0,1]:
		var owner: int = team*3
		var enemy: int = (1-team)*3
		var g = H.fixture(8);g.presentation_enabled = false
		H.begin(g,{owner:H.give(g,owner,"ignore")})
		check(g.choose(team,4) == "","first priority accepted")
		check(g.snapshot(team).input.selected_numbers == [4],"selected priority remains in snapshot for pressed styling")
		check(g.request.options == [0,1,2,3,5,6],"remaining options exclude duplicate priority")
		var revision: int = g.revision
		check(g.choose(team,4) != "" and g.revision == revision,"selected priority cannot be chosen twice")
		check(g.choose(team,2) == "" and G.drain(g),"second distinct priority resolves normally")
		for presented in [false,true]:
			for key in ["precise_strike","last_dance"]:
				g = H.fixture(8);g.presentation_enabled = presented
				if key == "last_dance":
					H.give_death(g,owner,key);g.characters[owner].hp=0;g.characters[owner].death_round=g.round_number;H.begin(g,{})
				else: H.begin(g,{owner:H.give(g,owner,key)})
				finish_animation(g)
				check(g.phase == ("death_targeting" if key == "last_dance" else "targeting"),"selection opens with and without animation")
				check(act(g,team,"reselect_targets") != "","no reset before choosing any target")
				check(g.target(team,enemy) == "","first target chosen")
				if key == "last_dance": check(g.target(team,enemy) == "","dance permits repeated pending targets")
				var before_discard: Array = g.discard.duplicate()
				var before_hand: Array = g.characters[owner].hand.duplicate()
				var before_jobs: Array = g.jobs.map(func(j):return {"op":j.op,"frame":j.get("frame","")})
				var stale: int = g.revision
				check(g.characters.all(func(c):return c.hp == (0 if key == "last_dance" and c.id == owner else 8)),"pending targets have no damage yet")
				check(g.snapshot(team).input.can_reselect,"choosing player can see reset capability")
				check(act(g,1-team,"reselect_targets") != "","opponent cannot reset targets")
				check(act(g,team,"reselect_targets",[0]) != "","malformed reset is rejected")
				check(act(g,team,"reselect_targets") == "","shared network route resets targets")
				check(g.request.options == [0,1,2,3,4,5] and g.request.get("selected_targets",[]).is_empty(),"reset restores first target and all legal pawns")
				check(g.characters[owner].hand == before_hand and g.discard == before_discard and g.jobs.map(func(j):return {"op":j.op,"frame":j.get("frame","")}) == before_jobs,"reset preserves paid discard cost and parent continuation")
				check(not g.request.get("can_reselect",false),"reset is unavailable until another target is chosen")
				check(Actions.apply(g,team,"reselect_targets",[],g.match_id,g.round_number,stale) != "","stale reset is rejected")
				check(g.target(team,enemy+1) == "" and act(g,team,"reselect_targets") == "","targets can be reset more than once")
				check(g.target(team,owner+1) == "","new selection can use a friendly pawn")
				check(g.target(team,enemy+1) == "","second new target accepted")
				if key == "last_dance":
					for i in range(3): check(g.target(team,enemy+1) == "","remaining dance target selected")
				check(act(g,team,"reselect_targets") != "","cannot undo a completed selection or resolved effects")
				check(G.drain(g),"effect and round still finish")
				check(g.characters[enemy].hp == 8 and g.characters[owner+1].hp == 7 and g.characters[enemy+1].hp == (4 if key == "last_dance" else 7),"only final targets receive intended damage")
				check(_conserved(g),"reset preserves physical cards")
	print("CHOICE_UI_RULES_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
