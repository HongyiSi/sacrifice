extends RefCounted
## Fast tactical policy, also used to finish hypothetical rounds during search.
## All decisions use player-visible information; never an authoritative game object.
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value

func action(kind: String, payload: Array = []) -> Dictionary:
	return {"kind":kind,"payload":payload}

func decide(view: Dictionary, team: int) -> Dictionary:
	if view.is_empty() or not view.get("animation",{}).is_empty(): return {}
	if view.phase == "ended":
		return action("confirm") if not view.confirmed[team] and view.confirmed[1-team] else {}
	if view.phase == "planning":
		if view.ready[team]: return {}
		var plan: Array = []
		for c in view.characters:
			if c.team != team: continue
			var picked: Array = []
			if c.hp > 0:
				var candidates: Array = []
				for id in c.hand:
					if not card(view,id).get("playable",true): continue
					candidates.append({"id":id,"score":play_value(view,c,id)+rng.randf()*0.15})
				candidates.sort_custom(func(a,b): return a.score>b.score)
				for item in candidates:
					if picked.size() >= c.play_limit or item.score <= 0: break
					picked.append(int(item.id))
			plan.append(picked)
		return action("plan",plan)
	var q: Dictionary = view.get("input",{})
	if q.is_empty() or q.get("team",-1) != team: return {}
	var options: Array = q.get("options",[])
	var info: Dictionary = view.get("active_card",{})
	var key: String = info.get("key","")
	var actor: int = view.get("active_action",{}).get("actor",team*3)
	match q.type:
		"character":
			var scores: Array = []
			for id in options: scores.append({"id":id,"score":target_value(view,team,actor,int(id),info)})
			# Finish an already useful dance selection even
			# when earlier choices account for every enemy's remaining health.
			if (key=="last_dance" and not view.active_action.get("dance_targets",[]).is_empty()) or (key=="precise_strike" and not view.active_action.get("selected_targets",[]).is_empty()):
				return best_choice(scores,"target",{})
			return best_choice(scores,"target",q)
		"card":
			var scores: Array = []
			for id in options:
				var score := 0.0
				for played in view.queue:
					if played.id != id: continue
					var enemy: bool = view.characters[played.actor].team != team
					score = 6.0 if enemy else -6.0
					# An unseen card is evaluated from its public owner, never its identity.
					if played.get("revealed",false): score += 0.1*play_value(view,view.characters[played.actor],played.card)
				scores.append({"id":id,"score":score})
			return best_choice(scores,"choose",q)
		"number":
			var scores: Array = []
			for number in options:
				var score := 0.0
				if key == "prophecy": score = -absf(float(number)-predicted_hp(view,actor))
				else:
					# Attack ranks are common, but don't suppress our own known attacks.
					score = 2.0 if number in [2,3,4,5] else 0.0
					for played in view.queue:
						if played.get("status","") not in ["pending","held"]: continue
						if played.card == 0: continue
						if int(card(view,played.card).get("main",-1)) == number:
							score += -4.0 if view.characters[played.actor].team == team else 4.0
				scores.append({"id":number,"score":score})
			# Prophecy guesses are allowed even when the heuristic score is negative.
			return best_choice(scores,"choose",{})
		"defense":
			var victim: Dictionary = view.characters[q.target]
			return action("defend",[int(victim.team == team and victim.hp > 0)])
		"amulet":
			var friendly := key in ["heal_other","raise_dead","defense","sapphire","ruby","amethyst","holy_amulet","attack_amulet","magic_amulet"]
			if friendly or options.is_empty():return action("respond",[0])
			var holder=view.characters.filter(func(c):return c.hand.has(options[0]))
			var urgent=not holder.is_empty() and holder[0].hp<=damage(info)
			var harmful=damage(info)>=2 or info.get("type","")!="攻击" or key in ["area_strike","precise_strike","bounty","glory"]
			return action("respond",[int(options[0]) if urgent or harmful else 0])
		"inspect": return action("pick")
		"deck","search","plunder","defile","gift","hand","discard","elegy","hand_limit","bonus":
			return pick_cards(view,team,actor,q)
	push_error("Local AI encountered an unsupported input: "+str(q.type))
	return action("skip_effect") if q.get("can_skip",false) else {}

func best_choice(scores: Array, kind: String, request: Dictionary) -> Dictionary:
	if scores.is_empty(): return action("skip_effect") if request.get("can_skip",false) else {}
	scores.sort_custom(func(a,b): return a.score>b.score)
	if scores[0].score < 0 and request.get("can_skip",false): return action("skip_effect")
	return action(kind,[int(scores[0].id)])

func card(view: Dictionary, id: int) -> Dictionary:
	return view.catalog.get(id,{})

func missing_hp(c: Dictionary) -> int:
	return 0 if c.hp <= 0 or has_status(c,"blessing") else maxi(0,int(c.max_hp)-int(c.hp))

func has_status(c:Dictionary,key:String)->bool:
	return key in c.get("statuses",[]) or c.get(key,false)==true

func predicted_hp(view:Dictionary,actor:int)->int:
	var c=view.characters[actor];var hp=int(c.hp)
	for a in view.get("queue",[]):
		if a.get("status","") not in ["pending","held"] or a.card==0:continue
		var key=card(view,a.card).get("key","")
		if a.actor==actor and key=="heal":hp=mini(c.max_hp,hp+2)
		if a.actor/3==c.team and key=="team_heal":hp=mini(c.max_hp,hp+1)
	return hp

func death_risk(view:Dictionary,c:Dictionary)->float:
	var allies=view.characters.filter(func(p):return p.id!=c.id and p.team==c.team and p.hp>0).size()
	var risk=0.
	for id in c.get("deathrattles",[]):
		var key=view.death_catalog.get(id,{}).get("key","")
		if key=="sacrifice_badges" and allies>0:risk+=150. if view.badges[c.team]>=2 else 15.
		elif key=="resurrection":risk+=6.
		elif key in ["last_dance","death_sentence"]:risk+=6.
	return risk

func threat(view:Dictionary,c:Dictionary)->float:
	var score=2.+(4. if c.hp<=3 else 0.)
	for a in view.get("queue",[]):
		if a.get("status","") not in ["pending","held","active"] or a.actor/3==c.team:continue
		var info=card(view,a.card)
		if info.get("type","")=="攻击" or a.card==0:score+=1.5
	return score

func damage(info: Dictionary) -> int:
	match info.get("key",""):
		"death_sentence","judgment": return 99
		"final_strike": return int(info.get("damage",0))
		"triple_strike","holy_strike","godslayer","life_steal": return 3
		"double_strike","quick_strike","magic_strike","hasty_spell": return 2
	return 1

func known_immortal(view: Dictionary, c: Dictionary) -> bool:
	# Opposing death cards only enter this snapshot after they are revealed.
	for id in c.get("deathrattles",[]):
		if view.death_catalog.get(id,{}).get("key","")=="immortal": return true
	return c.get("ongoing_effects",[]).any(func(e):return e.key=="immortal")

func immortal_protected(view: Dictionary, c: Dictionary, health: Array) -> bool:
	if not known_immortal(view,c): return false
	return view.characters.any(func(other):return other.id!=c.id and other.team==c.team and health[other.id]>0)

func target_health(view: Dictionary, info: Dictionary) -> Array:
	var health: Array = view.characters.map(func(c):return int(c.hp))
	if info.get("key","") == "last_dance":
		# These hits are selected together but land in order. Killing the last
		# teammate can make a later dance hit lethal to an immortal pawn.
		for id in view.get("active_action",{}).get("dance_targets",[]):
			if health[id]<=0: continue
			health[id]=maxi(0,health[id]-1)
			if health[id]==0 and immortal_protected(view,view.characters[id],health): health[id]=1
	return health

func target_value(view: Dictionary, team: int, actor: int, target: int, info: Dictionary) -> float:
	var c: Dictionary = view.characters[target]
	var owner: Dictionary = view.characters[actor]
	var ally: bool = c.team == team
	var key: String = info.get("key","")
	var space: int = maxi(0,int(view.hand_limit)-int(c.hand_count))
	match key:
		"raise_dead","resurrection": return 15.0 if ally and c.hp == 0 else -20.0
		"heal_other": return float(mini(3,missing_hp(c))*3) if ally else -10.0
		"defense","blessing":
			if not ally or c.hp<=0 or has_status(c,"blessing"):return -10.
			return threat(view,c)+c.hand_count*.3-c.get("shield",0)*5.
		"sapphire","ruby","amethyst","holy_amulet","attack_amulet","magic_amulet":
			if not ally or space == 0: return -10.0
			if key == "amethyst": return 14.0 if c.hp==0 else 8.0-c.hp
			if c.hp==0: return -5.0
			return 4.0+space*0.4+(missing_hp(c) if key=="ruby" else 0)
		"heart","privilege": return 6.0+space if ally and c.hp>0 else -10.0
		"obstruct","poisoning","curse": return 4.0+minf(space,2)*2 if not ally and c.hp>0 and space>0 else -8.0
		"silence","prison": return 3.0+c.hand_count if not ally and c.hp>0 else -6.0
		"peek","plunder","defile","vanish": return float(c.hand_count)*2+1 if not ally and c.hand_count>0 else -5.0
		"mediocrity": return float(c.death_count)*4 if not ally and c.hp>0 else -6.0
		"topaz","emerald","amber": return float(c.hand_count)-c.hp*0.2 if not ally else -10.0
		"gift":
			var bad := 0
			for id in owner.hand:
				if hand_value(view,owner,id)<0: bad+=1
			if bad>0 and not ally: return 10.0+space
			return 2.0+space if ally and c.hp>0 and space>0 else -6.0
	# All other character-targeted actions deal damage.
	if c.hp <= 0: return -8.0
	if ally: return -20.0
	if info.get("type","") == "攻击" and has_status(c,"blessing"): return -6.0
	if key == "judgment" and c.hp>2: return -6.0
	var amount := int(view.get("active_action",{}).get("convert_count",1)) if key == "cards_to_blades" else damage(info)
	if info.get("type","")=="攻击" and owner.get("warcry_round",-1)==view.round:
		amount += int(owner.get("warcry_bonus",0)) * (amount if key=="cards_to_blades" else 1)
	var health := target_health(view,info)
	var remaining: int = health[target]
	if remaining<=0: return -4.0
	if immortal_protected(view,c,health):
		# No kill bonus for a pawn that immediately revives. Prefer removing
		# its teammates; at one HP another hit makes no lasting progress.
		var reduction := mini(amount,remaining-1)
		if reduction<=0: return -4.0
		return reduction*0.25-(4.0 if c.get("shield",0)>0 and info.get("type","")=="攻击" else 0.0)
	var score: float = minf(amount,remaining)*2+5.0/remaining
	if amount>=remaining: score+=9.0-death_risk(view,c)
	# A shield cancels the whole card, not a fixed amount of damage. Breaking
	# one can still prepare another ally's attack, but is never a lethal hit.
	if c.get("shield",0)>0 and info.get("type","")=="攻击":score=1.5
	if amount>=remaining:
		for a in view.get("queue",[]):
			if a.actor==target and a.get("status","") in ["pending","held"]:score+=3.
	return score

func play_value(view: Dictionary, c: Dictionary, id: int) -> float:
	var info := card(view,id)
	var key: String = info.get("key","")
	var space: int = maxi(0,int(view.hand_limit)-int(c.hand_count)+1)
	var count := 0
	for other in c.hand:
		if other!=id and card(view,other).get("discardable",true): count+=1
	if info.get("type","")=="攻击" or key in ["judgment","hasty_spell","magic_strike"]:
		var score := -5.0
		for target in view.characters:
			if key=="godslayer" and not target.get("revealed",false) and view.phase!="planning": continue
			score=maxf(score,target_value(view,c.team,c.id,target.id,info))
		if key=="area_strike": score+=3.0
		if key=="precise_strike": score+=2.0
		if key=="final_strike" and damage(info)<=0: return -1.0
		return score
	match key:
		"badge","topaz": return 24.0 if view.badges[c.team]>=3 else 14.0
		"heal": return mini(2,missing_hp(c))*4.0-0.5
		"team_heal":
			var value := -0.5
			for friend in view.characters:
				if friend.team==c.team and missing_hp(friend)>0: value+=4.0
			return value
		"heal_other","raise_dead":
			var value := -1.0
			for friend in view.characters:
				if friend.id==c.id and key=="heal_other": continue
				value=maxf(value,target_value(view,c.team,c.id,friend.id,info))
			return value
		"collect": return minf(space,3)*2.3
		"emerald": return minf(space,4)*2.3+2
		"amber": return mini(3,missing_hp(c))*3.5+0.5
		"search": return 8.5 if space>0 else 0
		"prepared": return 5.0 if count>=2 else 2.0
		"bloodletting": return minf(space,5)*2-3 if c.hp>2 else -3.0
		"gold_panning": return minf(space,5)*1.5
		"gambler": return maxf(0,8-c.hand_count)*1.8+2
		"cards_to_heart": return minf(missing_hp(c),count)*3.0-count*0.7
		"cards_to_blades":
			if count==0:return -1.
			var projected=view.duplicate();projected.active_action={"convert_count":count}
			var best=-10.
			for target in view.characters:best=maxf(best,target_value(projected,c.team,c.id,target.id,info))
			return best-count*.7
		"frenzy":
			if c.hp <= 2 and not immortal_protected(view,c,view.characters.map(func(p):return int(p.hp))): return -3.0
			var value := -4.0
			for other in c.hand:
				if other!=id and card(view,other).get("key","")!="frenzy" and card(view,other).get("playable",true):value+=clampf(play_value(view,c,other),-2.,12.)*.6
			return value
		"gift":
			for other in c.hand:
				if other!=id and hand_value(view,c,other)<0: return 11.0
			return 0.2
		"poison": return 10.0 if c.hp>1 else -2.0
		"holy_amulet","attack_amulet","magic_amulet","sapphire","ruby": return -1.0
		"amethyst":
			for friend in view.characters:
				if friend.team==c.team and friend.hp==0 and friend.hand_count<view.hand_limit: return 13.0
			return -1.0
		"overload","warcry": return 5.0 if c.hand_count>=3 else 0.5
		"rally": return 7.0
		"silence","obstruct","poisoning","defile","plunder": return 7.5
		"defense":
			var best=0.
			for friend in view.characters:best=maxf(best,target_value(view,c.team,c.id,friend.id,info))
			return best
		"suppress","late_suppress","mirror": return 6.5
		"prophecy": return 7.5
		"elegy": return 5.0 if count>=2 else -1.0
		"feign":
			if c.death_count==0 or c.hp<=2:return -1.
			return 8.+death_risk(view,c)*.5
		"anticipation": return 4.0
		"ignore": return 2.0
		"peek","reverse","skip_death": return 0.5
	return -1.0

func hand_value(view: Dictionary, c: Dictionary, id: int) -> float:
	var info := card(view,id)
	if info.get("defiled",false): return -6.0
	match info.get("key",""):
		"poison","boulder","curse": return -10.0
		"spare_food": return 3.0
		"spare_supplies": return 4.0
		"holy_amulet": return 9.0
		"attack_amulet","magic_amulet","amethyst": return 7.0
		"sapphire","ruby": return 6.0
		# Avoid recursion through gift's evaluation of the rest of the hand.
		"gift": return 2.0
		"frenzy": return 4.0
	return play_value(view,c,id)

func pick_cards(view: Dictionary, team: int, actor: int, q: Dictionary) -> Dictionary:
	var recipient: int = q.get("recipient",q.get("target",actor))
	var c: Dictionary = view.characters[recipient]
	var own: bool = c.team==team
	var scores: Array = []
	for id in q.options:
		var value := hand_value(view,c,id)
		var score := value
		match q.type:
			"deck": score=value if own else -value
			"gift": score=value-hand_value(view,view.characters[actor],id)*.85 if own else -value
			"defile": score=value if not own else -value
			"hand","discard","elegy","hand_limit":
				score=-value
				var key: String = card(view,id).get("key","")
				if key=="spare_food": score+=mini(2,missing_hp(c))*4
				if key=="spare_supplies": score+=8
			"bonus": score=play_value(view,c,id)
		scores.append({"id":id,"score":score})
	scores.sort_custom(func(a,b): return a.score>b.score)
	var result: Array = []
	var maximum: int = mini(int(q.get("count",0)),scores.size())
	for item in scores:
		if result.size()>=maximum: break
		if q.type in ["gift","bonus"] and item.score<=0: break
		if q.type=="discard" and q.has("min_count") and result.size()>=int(q.min_count) and item.score<0: break
		result.append(int(item.id))
	if result.is_empty() and q.get("can_skip",false): return action("skip_effect")
	return action("pick",result)
