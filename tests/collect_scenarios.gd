extends RefCounted
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/reveal_scenarios.gd")
static func setup(actor:int,serial:int,remaining:int=2):
	var g=H.fixture(8);g.match_id=serial
	var card:int=H.give(g,actor,"collect")
	g._draw(g.characters[actor],remaining)
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	H.begin(g,{actor:card},false)
	return g
static func supports(e:Dictionary)->bool:
	return e.get("kind","")=="card_effect" and e.get("op","")=="collect_launch"
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
