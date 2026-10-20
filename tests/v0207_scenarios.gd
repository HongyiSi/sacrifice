extends RefCounted
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/reveal_scenarios.gd")
static func blades(actor:int,serial:int):
	var g=H.fixture(8);g.match_id=serial
	for key in ["strike","heal","defense"]:H.give(g,actor,key)
	var curse:int=H.give_death(g,actor,"curse");g.characters[actor].deathrattles.erase(curse);g.characters[actor].hand.append(curse)
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	H.begin(g,{actor:H.give(g,actor,"cards_to_blades")},false)
	for _i in range(50):
		if g.phase=="targeting":break
		S.step(g)
	return g
static func draw(actor:int,count:int,before:int,serial:int):
	var g=H.fixture(8);g.match_id=serial
	for _i in range(before):g.characters[actor].hand.append(g.deck.pop_back())
	g.presentation_enabled=true
	g._push([{"op":"draw","target":actor,"count":count}]);g._pump()
	return g
