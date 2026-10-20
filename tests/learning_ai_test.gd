extends "res://tests/v018_test.gd"
const AI=preload("res://scripts/learning_ai.gd")
const Old=preload("res://scripts/local_ai.gd")
const Policy=preload("res://scripts/ai_learning_policy.gd")
const Model=preload("res://scripts/ai_learning_model.gd")
const Belief=preload("res://scripts/ai_belief.gd")
var test_weights={}
func make_ai(seed_value:int):
	var agent=AI.new(seed_value)
	if not test_weights.is_empty():agent.configure(test_weights)
	return agent
func _initialize():
	var args=OS.get_cmdline_user_args()
	if not args.is_empty():test_weights=JSON.parse_string(FileAccess.get_file_as_string(args[0])).weights
	var weights=Model.load_weights()
	check(weights!=Policy.DEFAULTS,"load independently trained checkpoint")
	for side in [0,1]:
		var actor=side*3;var enemy=(1-side)*3
		for key in ["death_sentence","last_dance","life_steal","sacrifice_badges"]:
			var g=H.fixture(7);g.presentation_enabled=false;g.characters[actor].hp=3;g.characters[actor+1].hp=0;g.characters[actor+2].hp=0;g.characters[enemy].hp=1;g.characters[enemy+2].hp=0;g.badges[1-side]=2
			var id=H.give_death(g,enemy,key);g.death_revealed.append(id)
			H.begin(g,{actor:H.give(g,actor,"strike")});var s=g.snapshot(side);var before=s.duplicate(true);var d=make_ai(33).decide(s,side)
			check(d.kind=="target" and d.payload[0]==enemy+1,"avoid known lethal deathrattle "+key)
			check(s==before,"tactical evaluation preserves snapshot")
		var g=H.fixture(7);g.presentation_enabled=false;g.characters[actor+1].hp=0;var death=H.give_death(g,actor+1,"pain");g._activate({"actor":actor+1,"card":death},actor+1)
		H.give(g,actor,"triple_strike");H.give(g,actor,"magic_strike");H.begin(g,{actor:H.give(g,actor,"strike")})
		var d=make_ai(44).decide(g.snapshot(side),side)
		check(d.kind=="target" and d.payload[0]==actor+1,"recognize allied pain combo")
	var g=H.fixture(7);g.presentation_enabled=false;g.badges[0]=3;var badge=H.give(g,0,"badge");H.give(g,0,"triple_strike")
	var view=g.snapshot(0);var before=view.duplicate(true);var ai=make_ai(444);var d=ai.decide(view,0)
	check(d.payload[0].has(badge),"learned preferences preserve immediate victory")
	check(ai.last_stats.invalid==0 and before==view,"learned search uses legal isolated simulations")
	g=H.Rules.new();g.presentation_enabled=false;g.start(997);view=g.snapshot(1)
	var a=make_ai(88).decide(view,1);g.deck.reverse();g.characters[0].hand.reverse();g.plans[0]=[[],[],[]]
	var b=make_ai(88).decide(g.snapshot(1),1);check(a==b,"hidden real deck and locked plans cannot influence AI")
	ai=make_ai(19);d=ai.poll(view,1,1,1)
	if d.is_empty():ai.pending_started-=100;d=ai.poll(view,1,1,1)
	check(d.kind=="plan" and ai.last_stats.truncated,"bounded wall time produces a plan")
	check(Belief.world(view,1,9).submit(1,d.payload)=="","deadline fallback is legal")
	# Unconfigured rollout path remains numerically identical to the old AI.
	var Rollout=preload("res://scripts/ai_rollout.gd");var r=Rollout.new();r.game=g;r.perspective=1
	check(r.score_position()==Rollout.evaluate(g,1),"baseline evaluator unchanged without learned hook")
	var definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))+JSON.parse_string(FileAccess.get_file_as_string("res://data/deathrattles.json"))
	for row in definitions:drive(preload("res://tests/art_scenarios.gd").setup(row.key)[0],row.key)
	print("LEARNING_AI_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
func drive(g,key:String):
	var ai=make_ai(21)
	for step in range(1000):
		if not g.animation.is_empty():g.advance_animation();continue
		if g.phase in ["planning","review","ended"]:check(true,"complete "+key);return
		var side=int(g.request.get("team",-1));var s=g.snapshot(side);var d=ai.decide(s,side)
		if d.is_empty():check(false,"stalled "+key);return
		var error=Actions.apply(g,side,d.kind,d.payload,s.match,s.round,s.revision)
		if error!="":check(false,"illegal "+key+": "+error);return
	check(false,"loop "+key)
