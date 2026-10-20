extends RefCounted
const H=preload("res://tests/helpers.gd")
const Amulets=preload("res://tests/amulet_scenarios.gd")

static func setup(actors:Array,serial:int,key:String="warcry"):
	var g=H.fixture(8);g.match_id=serial
	g.presentation_enabled=true;g.resolution_presentation_enabled=true;g.stage_presentation_enabled=true
	var choices:Dictionary={}
	for actor in actors:choices[actor]=H.give(g,actor,key)
	for actor in [0 if actors.has(1) else 1,3 if actors.has(4) else 4]:
		if not choices.has(actor):choices[actor]=H.give(g,actor,"strike")
	H.begin(g,choices,false)
	return g

static func seek(g)->bool:
	for _i in range(200):
		if g.animation.get("kind","")=="card_reveal":return true
		if g.phase in ["review","ended"]:return false
		if step(g)!="":return false
	return false

static func step(g,accept:bool=true)->String:
	if not g.animation.is_empty():g.advance_animation();return ""
	if g.phase in ["review","ended","planning"]:return ""
	var team:int=g.request.get("team",0)
	match g.phase:
		"targeting","death_targeting":return g.target(team,H.auto_input(g.snapshot(team)))
		"responding":return g.respond(team,g.request.options[0] if accept else 0)
		"reacting":return g.defend(team,true)
		"selecting":return g.pick(team,H.auto_pick(g.snapshot(team)))
		"choosing":return g.choose(team,H.auto_input(g.snapshot(team)))
	return "Unexpected phase: "+g.phase
