extends SceneTree
const H = preload("res://tests/helpers.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V08_FAIL "+label)

func _initialize() -> void:
	var g = Rules.new()
	g.start(42)
	check(g.characters.all(func(c): return c.hp == 8),"all six start at eight")
	g.characters[0].hp = 7
	g._heal(g.characters[0],3)
	check(g.characters[0].hp == 8,"healing clamps to eight")
	var plan: Array = [g.characters[0].hand[0],0,0]
	var cards: Array = g.characters[0].hand.duplicate()
	check(g.submit(0,plan) == "","first team locks")
	check(g.snapshot(1).my_plan.is_empty() and g.snapshot(1).characters[0].hand.is_empty(),"locked plan remains secret")
	check(g.unlock(1) != "" and g.unlock(-1) != "","unlocked and invalid team cannot unlock")
	check(g.unlock(0) == "" and g.plans[0] == null,"first team may unlock")
	check(g.characters[0].hand == cards and g.queue.is_empty(),"unlock consumes no card and reveals nothing")
	check(g.submit(0,[0,0,0]) == "" and g.submit(1,[0,0,0]) == "","revised plan accepted")
	check(g.unlock(0) != "" and g.unlock(1) != "","no unlocking once both lock")
	var previous_round: int = g.round_number
	g.advance_round()
	check(g.round_number == previous_round+1 and g.phase == "planning","automatic advance starts next round once")
	g.advance_round()
	check(g.round_number == previous_round+1,"duplicate advance is harmless")

	g = H.fixture(8)
	H.give_death(g,0,"resurrection"); H.give_death(g,0,"eye")
	g.characters[0].hp=0; g.characters[0].death_round=g.round_number
	g._finish_round()
	check(g.request.options == [0],"resurrection can target its sole dead owner")
	check(g.target(0,0) == "" and g.characters[0].hp == 5,"self resurrection grants five")
	check(g.death_discard == [110] and g.characters[0].deathrattles == [103],"self revival consumes current card and retrieves pending eye")
	check(g._effect_owner("eye") == -1,"retrieved eye did not activate")
	g._finish_round()
	check(g.characters[0].hp == 5 and g.death_discard.count(110) == 1,"resurrection cannot repeat")

	g = H.fixture(8)
	H.give_death(g,0,"life_steal"); H.give_death(g,3,"immortal")
	g.characters[0].hp=0; g.characters[0].death_round=g.round_number
	g.characters[3].hp=2
	g._finish_round(); g.target(0,3)
	check(g.characters[0].hp == 5 and g.characters[3].hp == 1,"life steal revives to five even when victim immediately revives")

	g = H.fixture(8)
	H.give_death(g,0,"legacy")
	g.characters[0].hp=0; g.characters[0].death_round=g.round_number
	g.characters[2].hp=0; g.characters[2].death_round=g.round_number
	g._finish_round()
	check(g.characters[1].hand.size() == 5,"legacy grants five to living teammate")
	check(g.characters[0].hand.is_empty() and g.characters[2].hand.is_empty() and g.characters[3].hand.is_empty(),"legacy excludes dead and opposing roles")

	g = H.fixture(8)
	H.give_death(g,0,"blood_rite")
	g.characters[0].hp=0; g.characters[0].death_round=g.round_number
	g.characters[1].hp=1; g.characters[2].hp=7
	g._finish_round()
	check(g.characters[1].hp == 8 and g.characters[2].hp == 8 and g.characters[0].hp == 0,"blood rite remains a full heal at the new cap")

	# Revision validation protects unlocks arriving after an opponent's lock.
	var session = preload("res://scripts/session.gd").new()
	g = H.fixture(8)
	session.game=g
	var errors: Array=[]
	session.problem.connect(func(message): errors.append(message))
	var attack: int=H.give(g,0,"strike")
	g.submit(0,[attack,0,0])
	var old_revision: int=g.revision
	g.submit(1,[0,0,0])
	session._apply(0,"unlock",[],g.match_id,g.round_number,old_revision)
	check(errors.size() == 1 and g.phase == "targeting" and g.plans[0] != null,"late unlock rejected after simultaneous commitment")
	session.free()
	print("V08_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
