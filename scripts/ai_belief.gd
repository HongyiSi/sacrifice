extends RefCounted
## A hypothetical world built ONLY from a player's redacted snapshot.
const Rules=preload("res://scripts/rules.gd")

static func world(view:Dictionary,team:int,seed_value:int):
	var g=Rules.new();g.rng.seed=seed_value
	g.presentation_enabled=false;g.stage_presentation_enabled=false;g.resolution_presentation_enabled=false
	g.round_number=view.round;g.match_id=view.match;g.revision=view.revision
	g.badges=view.badges.duplicate();g.characters=view.characters.duplicate(true)
	g.reversed_order=view.get("reversed_order",false);g.skip_death_phase=view.get("skip_death_phase",false)
	g.normal_type_count=view.normal_type_count
	for id in view.catalog:
		if not g.catalog.has(id) and id!=104:
			g.catalog[id]=view.catalog[id].duplicate(true)
			g.catalog[id].erase("defiled")
			g.catalog[id].playable=g.catalog[id].key!="boulder"
			g.catalog[id].discardable=g.catalog[id].key not in ["poison","boulder"]
		g.next_generated_card_id=maxi(g.next_generated_card_id,int(id)+1)
	var occupied=[];var deaths=view.death_discard.duplicate()
	g.death_discard=deaths.duplicate()
	for c in g.characters:
		for id in c.get("active_deathrattles",[]):
			if not c.deathrattles.has(id):c.deathrattles.append(id)
			if not g.death_revealed.has(id):g.death_revealed.append(id)
		occupied.append_array(c.hand);deaths.append_array(c.deathrattles)
		for id in c.get("known_deathrattles",[]):
			if not g.death_revealed.has(id):g.death_revealed.append(id)
		for id in c.hand:
			if view.catalog.get(id,{}).get("defiled",false):g.defiled_cards[id]=true
			if view.catalog.get(id,{}).get("key","")=="final_strike":g.final_strike_damage[id]=view.catalog[id].get("damage",0)
		if c.get("ongoing_effects",[]).any(func(e):return e.key=="curse") and not occupied.has(104) and c.hand_count>c.hand.size():
			c.hand.append(104);occupied.append(104)
	# A privately transferred curse still consumes one visible hand slot. Infer
	# only its possible location from public counts, never its actual holder.
	var locations=view.deck_count+view.discard_count
	for c in g.characters:locations+=c.hand_count
	if locations>g.catalog.size() and not occupied.has(104):
		var unknown=g.characters.filter(func(c):return c.hand_count>c.hand.size())
		if not unknown.is_empty():
			var c=unknown[g.rng.randi_range(0,unknown.size()-1)];c.hand.append(104);occupied.append(104)
	var pool=g.catalog.keys().filter(func(id):return not occupied.has(id))
	g._shuffle(pool)
	var death_pool=g.death_catalog.keys().filter(func(id):return not deaths.has(id) and not occupied.has(id))
	g._shuffle(death_pool)
	for c in g.characters:
		while c.hand.size()<c.hand_count and not pool.is_empty():c.hand.append(pool.pop_back())
		while c.deathrattles.size()<c.death_count and not death_pool.is_empty():c.deathrattles.append(death_pool.pop_back())
		if c.team!=team and not view.get("omniscient",false):
			for slot in c.get("defiled_slots",[]):
				if slot<c.hand.size():g.defiled_cards[c.hand[slot]]=true
		# Reconstruct public, bound death effects without treating spent faces as owned.
		for id in c.get("active_deathrattles",[]):
			var key=g.death_catalog[id].key;var affected=c.id
			for other in g.characters:
				if key in other.get("statuses",[]):affected=other.id;break
			g.effects.append({"card":id,"owner":c.id,"target":affected,"round":g.round_number-1})
	if view.get("omniscient",false):
		g.deck=view.deck_view.duplicate();g.discard=view.discard_view.duplicate();g.death_deck=view.death_deck_view.duplicate()
	else:
		g.deck=pool.slice(0,mini(view.deck_count,pool.size()));g.discard=pool.slice(g.deck.size())
		g.death_deck=death_pool
	return g

static func capture(g)->Dictionary:
	var state={}
	for p in g.get_property_list():
		if p.usage&PROPERTY_USAGE_SCRIPT_VARIABLE and p.name!="rng":
			var value=g.get(p.name)
			state[p.name]=value.duplicate(true) if value is Array or value is Dictionary else value
	state.rng_state=g.rng.state
	return state

static func restore(g,state:Dictionary)->void:
	for key in state:
		if key=="rng_state":g.rng.state=state[key];continue
		var value=state[key]
		g.set(key,value.duplicate(true) if value is Array or value is Dictionary else value)
