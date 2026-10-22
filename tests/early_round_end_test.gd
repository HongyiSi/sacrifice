extends "res://tests/choice_ui_rules_test.gd"

func scenario(team: int, presented: bool = false, death_key: String = "resurrection", last_key: String = "badge"):
	var g = H.fixture(8)
	var owner: int = team*3
	var enemy: int = (1-team)*3
	for id in range(enemy,enemy+3): g.characters[id].hp = 1
	if not death_key.is_empty(): H.give_death(g,enemy,death_key)
	g.presentation_enabled = presented
	g.resolution_presentation_enabled = presented
	g.stage_presentation_enabled = presented
	H.begin(g,{owner:H.give(g,owner,"area_strike"),owner+1:H.give(g,owner+1,"magic_strike"),owner+2:H.give(g,owner+2,last_key)})
	return g

func _initialize() -> void:
	for team in [0,1]:
		var owner: int = team*3
		var enemy: int = (1-team)*3
		for presented in [false,true]:
			var g = scenario(team,presented)
			var guarded_animation := false
			for _i in range(200):
				if g.animation.is_empty(): break
				if g.early_end_available(team):
					guarded_animation = true
					var unchanged: Dictionary = g.animation.duplicate(true)
					check(not g.can_end_round_early(team) and act(g,team,"end_round_early") != "" and g.animation == unchanged,"cannot interrupt an in-flight effect")
				g.advance_animation()
			check(not presented or guarded_animation,"button can appear disabled during the final kill animation")
			check(g.phase == "targeting" and g._info(g.input_action).key == "magic_strike","no automatic skip after enemy wipe")
			check(g.snapshot(team).can_end_round_early and not g.snapshot(1-team).early_end_available,"only surviving side receives early-end capability")
			var revision: int = g.revision
			check(act(g,1-team,"end_round_early") != "" and act(g,team,"end_round_early",[1]) != "","opponent and malformed requests are rejected")
			check(Actions.apply(g,team,"end_round_early",[],g.match_id,g.round_number,revision-1) != "","stale snapshot cannot end round")
			check(act(g,team,"end_round_early") == "","early end accepted through shared network route")
			check(H.action_for(g,owner).status == "done" and H.action_for(g,owner+1).status == "declined" and H.action_for(g,owner+2).status == "declined","completed action remains; current and pending own cards are skipped")
			check(g.badges[team] == 0 and g.winner == -2,"skipped badge does not execute and wipe is not an immediate victory")
			finish_animation(g)
			check(g.phase == "death_targeting" and g.request.team == 1-team and g._info(g.input_action).key == "resurrection","opponent retains deathrattle choice")
			check(g.early_end_team == -1 and not g.early_end_available(team),"early end stops at the death phase")
			check(g.target(1-team,enemy) == "" and G.drain(g),"opponent can revive normally")
			check(g.phase == "review" and g.characters[enemy].hp == 5,"deathrattle comeback reaches next round")
			check(_conserved(g),"all played physical cards discarded exactly once")
			g.advance_round();check(G.drain(g),"next round starts")
			check(g.phase == "planning" and not g.early_end_available(team),"no early-end state leaks into next round")
		# Declining the shortcut still allows a strategic seal against deathrattles.
		var g = scenario(team,false,"resurrection","skip_death")
		check(g.target(team,owner) == "" and G.drain(g),"player can continue resolving instead of ending early")
		check(g.characters[owner].hp == 6 and g.skip_death_phase and g.phase == "ended" and g.winner == team,"remaining cards can prevent the enemy comeback")
		g = scenario(team,false,"resurrection","skip_death")
		check(act(g,team,"end_round_early") == "" and not g.skip_death_phase and g.phase == "death_targeting","shortcut does not play the skipped death-phase seal")
		# Round-end rewards and explicit death exceptions still occur.
		g = scenario(team,false,"")
		g.characters[owner].prediction = 8
		H.give(g,enemy,"amethyst")
		check(act(g,team,"end_round_early") == "" and G.drain(g),"amethyst and round-end prediction resolve")
		check(g.characters[enemy].hp == 1 and g.badges[team] == 1 and g.phase == "review","amethyst revival and already-set prediction are preserved")
		g = scenario(team,false,"")
		check(act(g,team,"end_round_early") == "" and g.phase == "ended" and g.winner == team,"no death actions safely finishes a wipe victory")
		g = scenario(team)
		var strike: int = g.catalog.keys().filter(func(id):return g.catalog[id].key == "strike")[0]
		var mirror: Dictionary = g._add_action(enemy,strike,true)
		check(act(g,team,"end_round_early") == "" and g.request.team == 1-team and g.input_action == mirror,"enemy death-enabled Mirror copy is not cancelled")
		check(g.target(1-team,owner) == "" and g.characters[owner].hp == 7,"enemy copy retains its effect")
		check(g.phase == "death_targeting","deathrattle still follows the enemy copy")
		var extra: Dictionary = g._add_action(owner,strike,true)
		check(G.drain(g) and extra.status == "done","new ordinary plays during death phase still resolve")
		# Eligibility changes immediately if an enemy is revived before the click.
		g = scenario(team)
		g._revive(enemy,1)
		check(not g.early_end_available(team) and act(g,team,"end_round_early") != "","one living enemy disables shortcut")
		g.characters[enemy].hp = 0
		for id in range(owner,owner+3): g.characters[id].hp = 0
		check(not g.early_end_available(team) and act(g,team,"end_round_early") != "","mutual wipe grants neither side a shortcut")
	# The whole volley now targets one pawn; end early before committing it.
	var g = H.fixture(7)
	for id in [3,4,5]: g.characters[id].hp = 0;g.characters[id].death_round = g.round_number
	H.give_death(g,3,"resurrection")
	var blade: int = H.give(g,0,"cards_to_blades")
	H.give(g,0,"heal");H.give(g,0,"defense")
	H.begin(g,{0:blade})
	check(g.phase=="targeting" and g.characters[0].hand.is_empty(),"blade conversion pays discard before choosing the single target")
	check(act(g,0,"end_round_early") == "" and g.characters[1].hp == 7 and g.characters[0].hand.is_empty(),"early end keeps paid discard but cancels the uncommitted volley")
	check(_conserved(g),"blade cost and skipped played card are conserved")
	g=H.fixture(7)
	for id in [3,4,5]: g.characters[id].hp=0;g.characters[id].death_round=g.round_number
	H.give_death(g,3,"resurrection")
	blade=H.give(g,0,"cards_to_blades")
	H.give(g,0,"heal");H.give(g,0,"defense")
	H.begin(g,{0:blade,1:H.give(g,1,"final_strike")})
	check(g.target(0,1)=="" and g.characters[1].hp==5,"single target commits both blade hits")
	check(act(g,0,"end_round_early")=="" and g.characters[1].hp==5 and _conserved(g),"ending later skips remaining cards without undoing committed damage")
	print("EARLY_ROUND_END_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
