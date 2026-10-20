extends RefCounted
const H=preload("res://tests/helpers.gd")
const Burn=preload("res://scripts/amulet_cancel_effect.gd")

static func setup(key:String,actor:int,serial:int,source_key:String="",virtual:bool=false):
	var g=H.fixture(8);g.match_id=serial
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	var attacker:int=(actor+3)%6
	var protected:int=(actor/3)*3+(actor+1)%3
	for id in range(6):
		H.give(g,id,"strike");H.give(g,id,"heal" if id<3 else "defense")
	var guard:int=H.give(g,protected,key)
	var card_key:String=source_key if source_key!="" else ("area_strike" if key=="attack_amulet" else "magic_strike")
	var card:int=H.give(g,attacker,card_key)
	var chosen:Dictionary={attacker:card}
	for team in [0,1]:
		var plan:Array=[]
		for slot in range(3):plan.append(chosen.get(team*3+slot,0))
		assert(g.submit(team,plan)=="")
	if virtual:
		# A mirror copy has its own table action even when it reuses a card ID.
		var physical=H.action_for(g,attacker)
		physical.status="done"
		var copied=g._add_action(attacker,card,true)
		g.jobs.clear();g.animation.clear();g.animation_jobs.clear();g.request.clear()
		copied.status="active";g.current_id=copied.id
		g._push([g._job("card_start",copied),g._job("responses",copied,{"mode":"target","targets":[protected],"passed":[]}),g._job("complete",copied)])
		g._pump()
	return g

static func step(g,accept:bool=true)->String:
	if not g.animation.is_empty():g.advance_animation();return ""
	if g.phase in ["review","ended","planning"]:return ""
	var team:int=g.request.get("team",0)
	match g.phase:
		"targeting":
			var enemy:int=1-g.characters[g.input_action.actor].team
			return g.target(team,enemy*3+(g.input_action.actor+1)%3)
		"responding":return g.respond(team,g.request.options[0] if accept else 0)
		"reacting":return g.defend(team,true)
		"selecting":return g.pick(team,H.auto_pick(g.snapshot(team)))
		"choosing":return g.choose(team,g.request.options[0])
	return "Unexpected phase: "+g.phase

static func seek(g)->bool:
	for _i in range(120):
		if Burn.supports(g.animation):return true
		if g.phase in ["review","ended"]:return false
		if step(g)!="":return false
	return false

static func drain(g,accept:bool=true)->bool:
	for _i in range(150):
		if g.phase in ["review","ended"] and g.animation.is_empty():return true
		if step(g,accept)!="":return false
	return false
