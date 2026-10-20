extends RefCounted
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/reveal_scenarios.gd")
const KEYS=["sapphire","ruby","amethyst","holy_amulet","attack_amulet","magic_amulet","curse"]
static func setup(key:String,actor:int,target:int,serial:int):
	var g=H.fixture(8);g.match_id=serial
	for card_key in ["strike","heal"]:H.give(g,target,card_key)
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	if key=="curse":
		H.give_death(g,actor,key);g.characters[actor].hp=0;g.characters[actor].death_round=g.round_number
		H.begin(g,{},false)
	else:H.begin(g,{actor:H.give(g,actor,key)},false)
	for _i in range(100):
		if g.phase in ["targeting","death_targeting"] and g._info(g.input_action).key==key:return g
		if S.step(g)!="":break
	return g
static func seek(g)->bool:
	for _i in range(100):
		if g.animation.get("kind","")=="hand_transfer":return true
		if g.phase in ["review","ended","planning"]:return false
		if S.step(g)!="":return false
	return false
