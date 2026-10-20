extends RefCounted
const H=preload("res://tests/helpers.gd")
static func setup(actor:int,serial:int):
	var g=H.fixture(8);g.match_id=serial
	for c in g.characters:
		H.give(g,c.id,"strike");H.give(g,c.id,"defense")
	var card:int=H.give_death(g,actor,"divinity")
	g.characters[actor].hp=0;g.death_revealed.append(card)
	g._activate({"actor":actor,"card":card,"death":true},actor)
	g.phase="resolution";g.turn_stage="resolution";g.stage_main=2
	g.presentation_enabled=true
	return g
