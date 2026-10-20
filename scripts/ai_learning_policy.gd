extends "res://scripts/ai_policy.gd"
## Shared by offline self-play and the optional learned search opponent.
## These multipliers are fitted from wins/losses, not changed during a live match.
const DEFAULTS={"attack":1.0,"healing":1.0,"drawing":1.0,"control":1.0,"tempo":1.0,"badges":1.0,"death_setup":1.0,"information":1.0,"death_caution":1.0,"pain_combo":1.0,"board_alive":1.0,"board_hp":1.0,"board_hand":1.0,"board_badges":1.0,"board_effects":1.0,"board_tempo":1.0}
var weights:Dictionary=DEFAULTS.duplicate()
func configure(values:Dictionary)->void:
	for key in DEFAULTS:weights[key]=clampf(float(values.get(key,1.0)),0.35,2.8)
func category(info:Dictionary)->String:
	var key=info.get("key","")
	if key in ["badge","topaz","prophecy"]:return "badges"
	if key in ["heal","team_heal","heal_other","cards_to_heart","amber","raise_dead"]:return "healing"
	if key in ["collect","gambler","search","gold_panning","bloodletting","prepared","emerald"]:return "drawing"
	if key in ["suppress","late_suppress","defense","ignore","silence","obstruct","poisoning","defile","plunder","anticipation"]:return "control"
	if key in ["overload","rally","warcry","frenzy"]:return "tempo"
	if key in ["feign","elegy","skip_death"]:return "death_setup"
	if key in ["peek","reverse","mirror"]:return "information"
	return "attack"
func play_value(view:Dictionary,c:Dictionary,id:int)->float:
	var base=super.play_value(view,c,id)
	return base*weights[category(card(view,id))] if base>0 else base
func death_risk(view:Dictionary,c:Dictionary)->float:
	var risk=super.death_risk(view,c)
	for id in c.get("deathrattles",[]):
		var key=view.death_catalog.get(id,{}).get("key","")
		# Activation already paid its cost; killing it again does not reactivate it.
		if id in c.get("active_deathrattles",[]):continue
		var others=view.characters.filter(func(p):return p.id!=c.id and p.team==c.team and p.hp>0)
		if key=="blood_rite":
			for other in others:risk+=minf(6,missing_hp(other))+2
		elif key in ["greed","divinity","privilege"]:risk+=others.size()*3
	return risk*weights.death_caution
func target_value(view:Dictionary,team:int,actor:int,target:int,info:Dictionary)->float:
	var c=view.characters[target];var owner=view.characters[actor];var key=info.get("key","")
	var damaging=info.get("type","")=="攻击" or key in ["hasty_spell","magic_strike","judgment","cards_to_blades","death_sentence","last_dance","life_steal"]
	if damaging and c.hp==0 and c.team==team and c.id!=actor and has_status(c,"pain") and owner.hp>0:
		# A corpse can be a useful target: only offer the line if there are cards
		# to continue with, instead of throwing an empty hand into a combo.
		var playable=owner.hand.filter(func(id):return card(view,id).get("playable",true)).size()
		if playable>0 and owner.play_limit>0:return (4.+mini(playable,2)*3.)*weights.pain_combo
	var score=super.target_value(view,team,actor,target,info)
	if not damaging or c.team==team or c.hp<=0:return score
	var amount=int(view.get("active_action",{}).get("convert_count",1)) if key=="cards_to_blades" else damage(info)
	if info.get("type","")=="攻击" and owner.get("warcry_round",-1)==view.round:
		amount+=owner.get("warcry_bonus",0)*(amount if key=="cards_to_blades" else 1)
	if amount<c.hp or view.get("skip_death_phase",false):return score
	# Do not knowingly lose the last living pawn to a revealed deathrattle.
	# This is a rules safeguard, reported separately from learned preferences.
	var survivors=view.characters.filter(func(p):return p.team==team and p.hp>0)
	if survivors.size()==1:
		for id in c.get("deathrattles",[]):
			var death=view.death_catalog.get(id,{}).get("key","")
			if death=="death_sentence" or (death=="last_dance" and survivors[0].hp<=5) or (death=="life_steal" and survivors[0].hp<=3):return minf(score,-180.)
	return score
