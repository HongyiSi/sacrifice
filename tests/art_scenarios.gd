extends RefCounted
const H=preload("res://tests/helpers.gd")
static func is_death(key):
	var cards=JSON.parse_string(FileAccess.get_file_as_string("res://data/deathrattles.json"))
	return cards.any(func(c):return c.key==key)
static func dead(g,id):g.characters[id].hp=0;g.characters[id].death_round=g.round_number
static func setup(key,serial=70000):
	var g=H.fixture(8);g.match_id=serial;g.presentation_enabled=true;g.resolution_presentation_enabled=true
	var ctx={"key":key,"selected":0,"targets":[],"target_index":0,"follow":false}
	if key in ["spare_food","spare_supplies"]:
		g.characters[0].hp=4;var card=H.give(g,0,key);ctx.selected=card
		g.phase="resolution";g.turn_stage="resolution";g._discard_hand_card(g.characters[0],card)
		g._push([{"op":"planning"}]);g._pump();return [g,ctx]
	var chosen=0
	if key=="poison":chosen=g._generate_card(H.Rules.POISON);g.characters[0].hand.append(chosen)
	elif key=="boulder":chosen=H.give(g,0,"obstruct")
	elif not is_death(key):chosen=H.give(g,0,key)
	for id in range(6):
		H.give(g,id,"strike");H.give(g,id,"defense")
	for id in [0,1,2]:H.give(g,id,"heal")
	if key in ["heal","team_heal","heal_other","blood_rite","cards_to_heart","ruby","amber"]:
		for id in [0,1,2]:g.characters[id].hp=3
	if key=="gold_panning":
		# Deliberately include both kept and rejected priorities in the five drawn cards.
		var selected=[]
		for wanted in ["collect","defense","magic_strike","badge","heal_other"]:
			for id in g.deck:
				if g.catalog[id].key==wanted:selected.append(id);break
		for id in selected:g.deck.erase(id)
		for id in selected:g.deck.push_back(id)
	if is_death(key):
		chosen=H.give_death(g,0,key);ctx.selected=chosen
		if key=="immortal":
			g.characters[0].hp=1;H.begin(g,{3:H.give(g,3,"strike")},false);return [g,ctx]
		if key=="life_steal":g.characters[3].hp=3
		if key=="mediocrity":H.give_death(g,3,"ghost");H.give_death(g,3,"prison")
		if key=="resurrection":dead(g,1)
		if key=="vanish":
			var curse=H.give_death(g,3,"curse");g.characters[3].deathrattles.erase(curse);g.characters[3].hand.append(curse);g.characters[3].curse_exposed=true
		dead(g,0);H.begin(g,{},false)
	else:
		ctx.selected=chosen;var plan={0:chosen}
		if key in ["mirror","suppress","ignore","defense"]:plan[3]=H.give(g,3,"strike")
		if key in ["anticipation","late_suppress"]:plan[3]=H.give(g,3,"badge")
		if key=="godslayer":plan[3]=H.give(g,3,"collect")
		if key=="raise_dead":dead(g,1)
		if key=="feign":H.give_death(g,0,"sacrifice_badges")
		if key=="skip_death":H.give_death(g,1,"legacy");dead(g,1)
		if key in ["bounty","glory"]:g.characters[3].hp=1
		if key=="judgment":g.characters[3].hp=2
		if key=="final_strike":g.final_strike_damage[chosen]=4
		if key=="peek":H.give_death(g,3,"heart");H.give_death(g,3,"resurrection")
		if key=="reverse":plan[3]=H.give(g,3,"strike");plan[1]=H.give(g,1,"badge")
		if key in ["holy_amulet","attack_amulet","magic_amulet"]:plan[3]=H.give(g,3,"magic_strike" if key=="magic_amulet" else "strike")
		if key=="frenzy":
			# A controlled hand shows three different actual follow-up actions.
			for id in g.characters[0].hand.duplicate():
				if id!=chosen:g.characters[0].hand.erase(id);g.deck.append(id)
			H.give(g,0,"strike");H.give(g,0,"heal");H.give(g,0,"badge")
		H.begin(g,plan,false)
	return [g,ctx]
static func step(g,ctx):
	if not g.animation.is_empty():g.advance_animation();return ""
	if g.phase in ["review","ended","planning"]:return "done"
	if g.request.is_empty():return "No request: "+g.phase
	var team=g.request.team;var info=g._info(g.input_action);var actual=info.get("key","");var key=ctx.key
	match g.phase:
		"targeting","death_targeting":
			var target=3
			if actual in ["heal_other","heart","greed","blessing","privilege","raise_dead","resurrection","sapphire","ruby","amethyst"]:target=1
			if actual=="defense":target=0
			if actual in ["holy_amulet","attack_amulet","magic_amulet"]:target=1
			if g.input_action.actor>=3:target=1 if key in ["holy_amulet","attack_amulet","magic_amulet"] else 0
			if actual=="precise_strike":target=[3,5][mini(ctx.target_index,1)];ctx.target_index+=1
			if actual=="last_dance":target=[3,4,5,4,3][ctx.target_index%5];ctx.target_index+=1
			if actual=="cards_to_blades":target=[3,4,5][ctx.target_index%3];ctx.target_index+=1
			if ctx.follow and key=="blessing":target=1
			if ctx.follow and key=="pain" and g.input_action.actor==1 and actual=="strike":target=0
			if not g.request.options.has(target):target=g.request.options[0]
			ctx.targets.append(target)
			return g.target(team,target)
		"choosing":
			if g.request.type=="number":return g.choose(team,8 if actual=="prophecy" else (5 if g.request.options.has(5) else g.request.options[0]))
			return g.choose(team,g.request.options[0])
		"selecting":
			if g.request.type=="inspect":return g.pick(team,[])
			if g.request.type=="pain":return g.pick(team,[1])
			if ctx.follow and key=="pain" and g.request.type=="bonus":return g.pick(team,g.request.options.slice(0,mini(2,g.request.options.size())))
			return g.pick(team,H.auto_pick(g.snapshot(team)))
		"responding":return g.respond(team,g.request.options[0])
		"reacting":return g.defend(team,true)
	return "Unexpected phase: "+g.phase
static func followups(g,ctx):
	var out=[];var key=ctx.key
	if key=="boulder":
		var tokens=g.characters[3].hand.filter(func(id):return g.catalog.get(id,{}).get("key","")=="boulder")
		assert(tokens.size()==2)
		for id in tokens:assert(not g._can_play_hand_card(g.characters[3],id) and not g._can_discard_hand_card(g.characters[3],id))
		# A presentation-only gesture demonstrates the two actual rule rejections.
		g.animation_jobs=[];g._show_visual({"kind":"card_effect","stage":"travel","style":"boulder","op":"immovable","travel_ms":1800,"impact_ms":850,"action":{"id":-70,"card":tokens[0],"actor":3},"targets":[{"id":3,"amount":0}],"rules_verified":{"playable":false,"discardable":false}})
		out.append([g,{"key":key,"follow":true,"selected":tokens[0],"target_index":0,"targets":[]}])
	elif key in ["sapphire","ruby","amethyst"]:
		var f=H.fixture(4);var c=H.give(f,1,key)
		if key=="amethyst":dead(f,1)
		f.presentation_enabled=true;f.phase="resolution";f.turn_stage="resolution"
		f._push([{"op":"gem_trigger","target":1,"card":c},{"op":"planning"}]);f._pump();out.append([f,{"key":key,"follow":true,"selected":c,"target_index":0,"targets":[]}])
	elif key in ["ghost","prison","pain","blessing","curse","divinity","greed","privilege","overload","rally","silence","heart"] and g.phase=="review":
		g.advance_round();out.append([g,{"key":key,"follow":true,"selected":ctx.selected,"target_index":0,"targets":[]}])
	return out
static func second_followup(g,ctx):
	if g.phase!="planning":return []
	var key=ctx.key;var choices={}
	if key=="prison":choices[3]=H.give(g,3,"collect")
	elif key=="pain":choices[1]=H.give(g,1,"strike")
	elif key=="blessing":choices[3]=H.give(g,3,"strike");choices[2]=H.give(g,2,"heal_other")
	elif key=="privilege":choices[1]=H.give(g,1,"strike")
	elif key!="ghost":return []
	H.begin(g,choices,false)
	return [[g,{"key":key,"follow":true,"selected":ctx.selected,"target_index":0,"targets":[]}]]
