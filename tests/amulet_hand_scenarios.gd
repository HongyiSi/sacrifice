extends RefCounted
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/reveal_scenarios.gd")
static func setup(key:String,holder:int,serial:int,retained:bool=false,present:bool=true):
	var g=H.fixture(8);g.match_id=serial
	for card in ["strike","heal","defense"]:H.give(g,holder,card)
	var guard:int=H.give(g,holder,key)
	for card in ["collect","warcry","double_strike"]:H.give(g,holder,card)
	var curse:int=H.give_death(g,holder,"curse");g.characters[holder].deathrattles.erase(curse);g.characters[holder].hand.append(curse)
	if retained:g.defiled_cards[guard]=true
	var enemy:int=(1-holder/3)*3
	g.presentation_enabled=present;g.resolution_presentation_enabled=present
	H.begin(g,{enemy:H.give(g,enemy,"magic_strike" if key=="magic_amulet" else "strike")},false)
	for i in range(80):
		if g.phase=="responding":return g
		if g.phase=="targeting":g.target(enemy/3,holder)
		else:S.step(g)
	return g
