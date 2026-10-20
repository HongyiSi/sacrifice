extends RefCounted
const Policy=preload("res://scripts/ai_learning_policy.gd")
const Rollout=preload("res://scripts/ai_rollout.gd")
const PATH="res://data/ai_learning_weights.json"
static func load_weights()->Dictionary:
	if not FileAccess.file_exists(PATH):return Policy.DEFAULTS.duplicate()
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed.get("weights",Policy.DEFAULTS).duplicate() if parsed is Dictionary else Policy.DEFAULTS.duplicate()
static func evaluate(g,team:int,weights:Dictionary)->float:
	var score=Rollout.evaluate(g,team)
	if g.phase=="ended":return score
	# Keep the tested terminal and material evaluator. The fitted preferences
	# gently adjust its valuation of resources at the search horizon.
	for side in [team,1-team]:
		var value=0.
		value+=(weights.get("badges",1.)-1.)*minf(g.badges[side],3)*5.
		for c in g.characters:
			if c.team!=side or c.hp<=0:continue
			value+=(weights.get("healing",1.)-1.)*c.hp*.5
			value+=(weights.get("drawing",1.)-1.)*c.hand.size()*.4
			if g.play_limit(c)>1:value+=(weights.get("tempo",1.)-1.)*(g.play_limit(c)-1)*2.
		for e in g.effects:
			if g.characters[e.owner].team==side and g.characters[e.owner].deathrattles.has(e.card):value+=(weights.get("death_setup",1.)-1.)*2.
		score+=value if side==team else -value
	# Optional coefficients learned with the full deployed search. Older
	# checkpoints default to one, preserving their exact original evaluation.
	var keys=["board_alive","board_hp","board_hand","board_badges","board_effects","board_tempo"]
	if keys.any(func(key):return not is_equal_approx(float(weights.get(key,1.)),1.)):
		var material=material_features(g,team)
		for key in keys:score+=(weights.get(key,1.)-1.)*material[key]
	return clampf(score,-200.,200.)

static func material_features(g,team:int)->Dictionary:
	var totals={"board_alive":0.,"board_hp":0.,"board_hand":0.,"board_badges":0.,"board_effects":0.,"board_tempo":0.}
	for side in [team,1-team]:
		var sign_value=1. if side==team else -1.
		totals.board_badges+=sign_value*[0.,24.,56.,106.,200.][clampi(g.badges[side],0,4)]
		for c in g.characters:
			if c.team!=side:continue
			var alive=c.hp>0
			if alive:
				totals.board_alive+=sign_value*22.
				totals.board_hp+=sign_value*(c.hp*2.2+(c.max_hp-7)*.5)
			var hand=0.
			for id in c.hand:
				var key=g.catalog.get(id,g.death_catalog.get(id,{})).get("key","")
				var value=2.2
				if g.defiled_cards.has(id) or key in ["boulder","curse"]:value=-1.8
				elif key=="poison":value=-3.5
				elif key in ["badge","topaz"]:value=4.5
				elif key in ["sapphire","ruby","holy_amulet","amethyst"]:value=4.
				elif key in ["attack_amulet","magic_amulet","raise_dead","final_strike"]:value=3.
				hand+=value
			totals.board_hand+=sign_value*hand*(1. if alive else .18)
			if alive and c.hand.size()>0:
				var tempo=0.
				if c.get("silenced_round",-1)>g.round_number:tempo-=7.
				if c.get("overload_round",-1)>g.round_number:tempo+=minf(c.hand.size(),3)*2.
				if c.get("extra_round",-1)>g.round_number:tempo+=minf(c.hand.size(),c.extra_count)*2.
				if c.get("warcry_round",-1)>g.round_number:tempo+=3.
				totals.board_tempo+=sign_value*tempo
		for effect in g.effects:
			if not g.characters[effect.owner].deathrattles.has(effect.card):continue
			var key=g.death_catalog[effect.card].key
			if key=="prison" and g.characters[effect.target].team==side:totals.board_effects-=sign_value*5.
			elif g.characters[effect.owner].team==side:totals.board_effects+=sign_value*{"greed":13.,"privilege":15.,"divinity":9.,"eye":6.,"blessing":8.,"ghost":5.,"pain":7.}.get(key,3.)
	return totals
