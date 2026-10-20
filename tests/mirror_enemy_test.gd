extends "res://tests/v018_test.gd"
const G = preload("res://tests/gem_scenarios.gd")

func _initialize() -> void:
	for presented in [false,true]:
		for team in [0,1]:
			var g = H.fixture(8);g.presentation_enabled = presented
			var owner: int = team*3;var enemy: int = (1-team)*3
			g.characters[owner].overload_round = g.round_number
			var mirror: int = H.give(g,owner,"mirror")
			var own_strike: int = H.give(g,owner,"strike")
			H.give(g,enemy,"heal") # A card still in hand is not a table target.
			var chosen: Dictionary = {owner:[mirror,own_strike],owner+1:H.give(g,owner+1,"strike"),enemy:H.give(g,enemy,"strike")}
			for side in [0,1]:
				var plan: Array = []
				for slot in range(3): plan.append(chosen.get(side*3+slot,0))
				check(g.submit(side,plan) == "","mixed single and multi-card plan is valid")
			var opposing: Dictionary = H.action_for(g,enemy)
			var friendly: Dictionary = H.action_for(g,owner+1)
			var own: Dictionary = g.queue.filter(func(a):return a.card == own_strike)[0]
			check(g.phase == "choosing" and g.request.options == [opposing.id],"only enemy facedown played card is offered")
			check(g.request.description.contains("敌方打出的"),"target instruction names enemy played cards")
			check(g.snapshot(team).input.options == [opposing.id],"client highlights only legal enemy card")
			check(g.choose(team,friendly.id) != "" and g.choose(team,own.id) != "","host rejects teammate and caster's own played cards")
			check(g.phase == "choosing" and g.mirrors.is_empty(),"invalid choices preserve pending prompt")
			check(g.choose(team,opposing.id) == "" and G.drain(g),"enemy selection resolves with and without animation")
			check(not H.action_for(g,owner,true).is_empty() and H.action_for(g,owner,true).secondary == 0,"enemy card still generates a priority-zero copy")
			check(_conserved(g),"copy preserves physical card count")
	# Friendly-only tables and revealed enemy cards do not offer a Mirror target.
	for revealed_enemy in [false,true]:
		var g = H.fixture(8)
		var plan: Dictionary = {0:H.give(g,0,"mirror"),1:H.give(g,1,"strike")}
		if revealed_enemy: plan[3] = H.give(g,3,"judgment")
		H.begin(g,plan)
		check(g.request.get("type","") != "card" and g.mirrors.is_empty(),"no enemy hidden card means Mirror safely has no target")
		check(G.drain(g) and not g.queue.any(func(a):return a.virtual),"no-target Mirror completes without producing a copy")
	# The shared target-selection branch must preserve Suppression's own rules.
	var g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"suppress"),1:H.give(g,1,"collect"),3:H.give(g,3,"strike")})
	var friendly: Dictionary = H.action_for(g,1)
	check(g.request.options.has(friendly.id),"suppression still permits friendly hidden cards")
	check(g.choose(0,friendly.id) == "" and friendly.status == "suppressed","suppression selection still works")
	check(G.drain(g),"suppression scenario completes")
	print("MIRROR_ENEMY_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
