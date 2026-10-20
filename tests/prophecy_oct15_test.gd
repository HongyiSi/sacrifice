extends SceneTree
const H=preload("res://tests/helpers.gd")
const G=preload("res://tests/gem_scenarios.gd")
const AI=preload("res://scripts/local_ai.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func settle(g):
	for i in range(100):
		if g.animation.is_empty():return
		g.advance_animation()
func _initialize():
	for team in [0,1]:
		for hp in range(1,11):
			for presented in [false,true]:
				var g=H.fixture(7);var actor=team*3
				g.presentation_enabled=presented
				g.characters[actor].max_hp=maxi(7,hp);g.characters[actor].hp=hp
				var card=H.give(g,actor,"prophecy");H.begin(g,{actor:card});settle(g)
				check(g.request.options==[1,2,3,4,5,6,7,8,9,10],"complete prophecy range")
				check(g.catalog[card].text.contains("1~10"),"card description synchronized")
				var revision=g.revision
				check(g.choose(team,0)!="" and g.choose(team,11)!="" and g.choose(1-team,hp)!="" and g.revision==revision,"invalid choices do not mutate state")
				check(AI.new(60).decide(g.snapshot(team),team).payload==[hp],"AI can select every legal health value")
				check(g.choose(team,hp)=="" and G.drain(g),"selection resolves")
				check(g.badges[team]==1 and g.badges[1-team]==0,"matching prediction earns exactly one badge")
		# Blood rite raises the real cap to 9; prophecy can guess that new value.
		var g=H.fixture(7);var actor=team*3
		var rite=H.give_death(g,actor,"blood_rite")
		g.characters[actor].hp=0;g.characters[actor].death_round=g.round_number
		H.begin(g,{});check(G.drain(g) and g.characters[actor+1].max_hp==9,"blood rite raises the cap")
		g.characters[actor+1].prediction=9;var badges=g.badges[team]
		g._finish_round();check(G.drain(g) and g.badges[team]==badges+1,"nine-health blood rite prediction succeeds")
	print("PROPHECY_OCT15_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
