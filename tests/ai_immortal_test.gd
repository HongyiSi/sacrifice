extends SceneTree
const H=preload("res://tests/helpers.gd")
const AI=preload("res://scripts/local_ai.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func _initialize()->void:
	for team in [0,1]:
		var actor=team*3;var enemy=(1-team)*3
		var g=H.fixture(7);var immortal=H.give_death(g,enemy,"immortal")
		g.characters[enemy].hp=1
		var strike=H.give(g,actor,"strike")
		H.begin(g,{actor:strike})
		var ai=AI.new(57);var s=g.snapshot(team)
		check(not ai.known_immortal(s,s.characters[enemy]),"unrevealed opposing death card remains unknown")
		check(ai.decide(s,team).payload==[enemy],"AI may try the first kill before learning immortal")
		g.death_revealed.append(immortal);s=g.snapshot(team)
		check(ai.known_immortal(s,s.characters[enemy]),"revealed immortal is recognized")
		check(ai.decide(s,team).payload[0] in [enemy+1,enemy+2],"target a teammate rather than repeat a futile kill")
		check(ai.target_value(s,team,actor,enemy,s.active_card)<0,"one HP immortal is not valued as a kill")
		# Taking health off the immortal is possible, but removing its teammates
		# takes precedence even if the immortal looks like an easy lethal target.
		g.characters[enemy].hp=3;s=g.snapshot(team)
		check(ai.decide(s,team).payload[0] in [enemy+1,enemy+2],"prefer teammates over chipping protected immortal")
		g.characters[enemy].hp=1;g.characters[enemy+1].hp=0;g.characters[enemy+2].hp=0
		s=g.snapshot(team)
		check(ai.decide(s,team).payload==[enemy],"last standing immortal can be killed")
		check(g.target(team,enemy)=="" and g.characters[enemy].hp==0,"real rules agree the last immortal dies")
		# Publicly reveal it by actually hitting it, then choose a fresh attack.
		g=H.fixture(7);immortal=H.give_death(g,enemy,"immortal");g.characters[enemy].hp=1
		strike=H.give(g,actor,"strike");H.begin(g,{actor:strike});g.target(team,enemy)
		check(g.characters[enemy].hp==1 and g.death_revealed.has(immortal),"first hit revives and exposes immortal")
		s=g.snapshot(team);s.phase="planning";s.ready=[false,false]
		check(ai.known_immortal(s,s.characters[enemy]),"AI learns from public revival, without hidden-state access")
		# With all other options excluded, skip a useless execution instead of
		# repeatedly triggering revival (judgment/death sentence still use damage).
		for key in ["strike","judgment","death_sentence","magic_strike"]:
			s.phase="targeting";s.animation={};s.input={"type":"character","team":team,"options":[enemy],"can_skip":true}
			s.active_action={"actor":actor};s.active_card={"key":key,"type":"技能"}
			check(ai.decide(s,team).kind=="skip_effect","skip futile protected damage: "+key)
		# A concentrated volley must choose a killable teammate, not spread hits.
		g=H.fixture(7);immortal=H.give_death(g,enemy,"immortal");g.death_revealed.append(immortal)
		g.characters[enemy].hp=1;g.characters[enemy+1].hp=3
		for key in ["strike","heal","defense"]:H.give(g,actor,key)
		H.begin(g,{actor:H.give(g,actor,"cards_to_blades")})
		var d=ai.decide(g.snapshot(team),team)
		check(d.kind=="target" and d.payload==[enemy+1],"concentrated blades prefer a lethal unprotected target")
		g.target(team,d.payload[0])
		check(g.characters[enemy+1].hp==0 and g.characters[enemy].hp==1 and g.characters[enemy+2].hp==7,"all blades hit the single chosen pawn")
		# Last dance plans five hits before impact. Remove both supporters first,
		# then the immortal; surplus selections must not cancel useful damage.
		g=H.fixture(7);immortal=H.give_death(g,enemy,"immortal");g.death_revealed.append(immortal)
		for id in range(enemy,enemy+3):g.characters[id].hp=1
		H.give_death(g,actor,"last_dance");g.characters[actor].hp=0;g.characters[actor].death_round=g.round_number;H.begin(g,{})
		for i in range(5):
			s=g.snapshot(team);d=ai.decide(s,team)
			check(d.kind=="target","dance completes an already useful sequence")
			if d.kind!="target":break
			if i<3:check(d.payload==[[enemy+1,enemy+2,enemy][i]],"dance order removes support before immortal")
			check(g.target(team,d.payload[0])=="","chosen dance target is legal")
		check(g.characters.slice(enemy,enemy+3).all(func(c):return c.hp==0),"ordered dance kills full enemy team")
		g=H.fixture(7);immortal=H.give_death(g,enemy,"immortal");g.death_revealed.append(immortal);g.characters[enemy].hp=1
		s=g.snapshot(team);s.active_action={"actor":actor,"dance_targets":[enemy]}
		var health=ai.target_health(s,{"key":"last_dance"})
		check(health[enemy]==1,"projected immortal revives while a teammate remains")
	print("AI_IMMORTAL_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
