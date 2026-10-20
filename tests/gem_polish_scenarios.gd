extends RefCounted
const H=preload("res://tests/helpers.gd")
const G=preload("res://tests/gem_scenarios.gd")
const S=preload("res://tests/art_scenarios.gd")
static func setup(key:String,actor:int,serial:int):
	if key in H.Rules.GEMS:
		var g=G.setup(key,actor,serial)
		assert(G.seek(g));return g
	var g=H.fixture(8);g.match_id=serial;g.presentation_enabled=true;g.resolution_presentation_enabled=true
	var id=H.give(g,actor,key)
	for c in range(6):
		H.give(g,c,"strike");H.give(g,c,"defense")
		if c<3:H.give(g,c,"heal")
	g.characters[actor].hp=3
	H.begin(g,{actor:id},false)
	var ctx={"key":key,"target_index":0,"follow":false,"targets":[],"selected":id}
	for i in range(100):
		if g.animation.get("gem_polished",false):return g
		assert(S.step(g,ctx).is_empty())
	assert(false,"gem scenario never reached cast");return g
