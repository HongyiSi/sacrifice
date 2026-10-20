extends SceneTree
const H=preload("res://tests/helpers.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func settle(g)->bool:
	var badge_animation=false
	for i in range(200):
		if g.animation.is_empty():return badge_animation
		if g.animation.get("op","")=="badges":badge_animation=true
		g.advance_animation()
	check(false,"animations finish")
	return badge_animation
func die(g,id):
	g.characters[id].hp=0;g.characters[id].death_round=g.round_number
func scenario(team,presented,allies):
	var g=H.fixture(7);g.presentation_enabled=presented;g.resolution_presentation_enabled=presented
	var owner=team*3;H.give_death(g,owner,"sacrifice_badges");die(g,owner)
	for slot in range(1,3):
		if slot>allies:die(g,owner+slot)
	return g
func _initialize():
	for team in [0,1]:
		var owner=team*3;var enemy=(1-team)*3
		for presented in [false,true]:
			for allies in [0,1,2]:
				var g=scenario(team,presented,allies);g.badges[team]=2
				H.begin(g,{})
				var played=settle(g)
				check(g.badges[team]==(4 if allies>0 else 2),"only living teammates enable the two badges")
				check(g.winner==(team if allies>0 else 1-team),"a wiped team cannot win with disabled badges")
				check(g.death_discard.has(106),"one-shot card is consumed even when condition fails")
				check(played==(presented and allies>0),"no false award animation on failed condition")
				check(g.death_catalog[106].text=="如果有存活的队友，则获得两枚胜利徽章。","description matches rule")
			# A higher-priority resurrection changes the condition before resolution.
			var g=scenario(team,presented,0)
			H.give_death(g,owner,"resurrection");H.begin(g,{});settle(g)
			check(g.target(team,owner+1)=="","earlier deathrattle can revive a teammate")
			settle(g)
			check(g.characters[owner+1].hp==5 and g.badges[team]==2,"newly revived teammate enables sacrifice")
			# Conversely, the last teammate can die to an earlier enemy deathrattle.
			g=scenario(team,presented,1);die(g,enemy);H.give_death(g,enemy,"death_sentence")
			H.begin(g,{});settle(g)
			check(g.target(1-team,owner+1)=="","earlier enemy deathrattle can kill last teammate")
			settle(g)
			check(g.badges[team]==0 and g.death_discard.has(106),"condition uses current health, not phase-start health")
			# Feign can trigger a death card while its caster is alive. Self is not a teammate.
			for allies in [0,1]:
				g=scenario(team,presented,allies);g.characters[owner].hp=7;g.characters[owner].death_round=-1
				H.begin(g,{owner:H.give(g,owner,"feign")});settle(g)
				check(g.characters[owner].hp==5 and g.badges[team]==(2 if allies>0 else 0),"living caster alone does not satisfy teammate condition")
			# Other badge cards still work for a sole surviving pawn.
			g=H.fixture(7);g.presentation_enabled=presented;die(g,owner+1);die(g,owner+2)
			H.begin(g,{owner:H.give(g,owner,"badge")});settle(g)
			check(g.badges[team]==1,"ordinary victory badge remains unconditional")
	print("SACRIFICE_BADGES_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
