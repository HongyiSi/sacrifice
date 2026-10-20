extends RefCounted
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/reveal_scenarios.gd")
static func give_copy(g,actor:int,key:String) -> int:
	# One printed copy now; additional copies can still be created by Mirror.
	for card in g.catalog.values():
		if card.key==key:
			var id:int=g._generate_card(card)
			g.characters[actor].hand.append(id)
			return id
	return 0

static func setup(key:String,actor:int,serial:int,retained:bool=false,copies:int=1):
	var g=H.fixture(8);g.match_id=serial
	H.give(g,actor,"strike");H.give(g,actor,"heal")
	for _i in range(copies):
		var id:int=H.give(g,actor,key) if _i==0 else give_copy(g,actor,key)
		if retained:g.defiled_cards[id]=true
	if key=="ruby":g.characters[actor].hp=3
	if key=="amethyst":g.characters[actor].hp=0;g.characters[actor].death_round=g.round_number
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	if key=="sapphire":g._begin_round()
	else:H.begin(g,{},false)
	return g
static func supports(e:Dictionary)->bool:return e.get("kind","")=="gem_trigger"
static func seek(g)->bool:
	for _i in range(200):
		if supports(g.animation):return true
		if g.animation.is_empty() and g.phase in ["planning","review","ended"]:return false
		if S.step(g)!="":return false
	return false
static func drain(g)->bool:
	for _i in range(400):
		if g.animation.is_empty() and g.phase in ["planning","review","ended"]:return true
		if S.step(g)!="":return false
	return false
