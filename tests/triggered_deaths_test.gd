extends "res://tests/v018_test.gd"
const G=preload("res://tests/gem_scenarios.gd")
func _initialize()->void:
	for presented in [false,true]:
		for owner in [0,3]:
			var g=H.fixture(7);g.presentation_enabled=presented
			H.give_death(g,owner,"sacrifice_badges");var secret=H.give_death(g,(owner+1)%6,"vanish")
			g.characters[owner].hp=0;g.characters[owner].death_round=g.round_number
			H.begin(g,{});check(G.drain(g),"one-shot resolves")
			for viewer in [0,1]:
				var s=g.snapshot(viewer);var c=s.characters[owner]
				check(c.death_count==0 and c.deathrattles.is_empty(),"spent death is no longer owned")
				check(c.death_slots==[{"card":106,"triggered":true}],"both viewers retain revealed history")
				if viewer!=int((owner+1)%6)/3:check(s.characters[(owner+1)%6].death_slots[0].card==0,"other unrevealed death stays hidden")
			check(g.death_discard.count(106)==1 and g.badges[owner/3]==2,"discard and badge effect occur once")
			g._revive(owner,3);g.advance_round();check(G.drain(g),"next round begins")
			check(g.snapshot(owner/3).characters[owner].death_slots[0].triggered,"history survives new round")
			g.characters[owner].hp=0;g.characters[owner].death_round=g.round_number;H.begin(g,{})
			check(G.drain(g) and g.badges[owner/3]==2 and g.death_discard.count(106)==1,"dying again does not repeat consumed card")
			g._run_job({"op":"draw_death","a":{"actor":owner}})
			var c=g.snapshot(owner/3).characters[owner]
			check(c.death_count==1 and c.death_slots.size()==2 and c.death_slots[0].card==106,"new death can coexist with old history")
			var other=g.snapshot(1-owner/3).characters[owner]
			check(other.death_slots[1].card==0 and other.death_slots[0].card==106,"new hidden card does not leak beside public history")
			g.start(77);check(g.triggered_deaths.is_empty(),"new match clears history")
	# Resolve the middle, then first slot: the original visual order is preserved.
	var g=H.fixture(7)
	for key in ["vanish","sacrifice_badges","greed"]:H.give_death(g,0,key)
	for card in [106,109]:g._complete_death({"actor":0,"card":card,"status":"active"})
	check(g.snapshot(0).characters[0].death_slots.map(func(s):return s.card)==[109,106,113],"out-of-order completion preserves original slots")
	check(g.characters[0].deathrattles==[113],"persistent card still owned")
	g=H.fixture(7);H.give_death(g,0,"vanish");g._strip_deaths(0)
	check(g.triggered_deaths.is_empty(),"stripped card is not falsely marked triggered")
	g=H.fixture(7);H.give_death(g,0,"vanish");g._complete_death({"actor":0,"card":109,"status":"declined"})
	check(g.triggered_deaths.is_empty() and g.death_discard.has(109),"skipping a death does not mark it triggered")
	print("TRIGGERED_DEATHS_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
