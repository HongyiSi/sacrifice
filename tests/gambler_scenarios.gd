extends RefCounted
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/reveal_scenarios.gd")
static func setup(actor:int,serial:int,retained:bool=false,empty:bool=false):
	var g=H.fixture(8);g.match_id=serial
	var card:int=H.give(g,actor,"gambler")
	if retained:
		# Put retained cards first to catch accidental fading by card count.
		g.characters[actor].hand.append(g._generate_card(g.BOULDER))
		var locked:int=H.give(g,actor,"heal");g.defiled_cards[locked]=true
		g.death_deck.erase(104);g.characters[actor].hand.append(104)
	if not empty:
		for key in ["strike","defense","collect"]:H.give(g,actor,key)
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	H.begin(g,{actor:card},false)
	return g
static func supports(e:Dictionary)->bool:
	return e.get("kind","")=="card_effect" and e.get("style","")=="gambler" and e.get("op","")=="discard_all"
static func seek(g)->bool:
	for _i in range(150):
		if supports(g.animation):return true
		if g.phase in ["review","ended"]:return false
		if S.step(g)!="":return false
	return false
static func drain(g)->bool:
	for _i in range(200):
		if g.phase in ["review","ended"]:return true
		if S.step(g)!="":return false
	return false
