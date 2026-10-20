extends RefCounted
## Reuse the real rules, including ordering, reactions and deathrattles.
const Rules=preload("res://scripts/rules.gd")
const Belief=preload("res://scripts/ai_belief.gd")
const Policy=preload("res://scripts/ai_policy.gd")
const Actions=preload("res://scripts/match_actions.gd")
var game=Rules.new()
var policy=Policy.new(1)
var finished=true
var valid=true
var steps=0
var result=0.
var perspective=0
var initial_round=0
var first_score=0.
var evaluator:Callable

func score_position()->float:
	return evaluator.call(game,perspective) if evaluator.is_valid() else evaluate(game,perspective)

func begin(state:Dictionary,team:int,plan:Array,opponent:Array,seed_value:int)->void:
	Belief.restore(game,state);policy.rng.seed=seed_value
	perspective=team;steps=0;valid=true;finished=false
	initial_round=game.round_number;first_score=0.
	var a=game.submit(team,plan);var b=game.submit(1-team,opponent) if a.is_empty() else a
	if not a.is_empty() or not b.is_empty():valid=false;finished=true;result=-1000000.

func step()->void:
	if finished:return
	if game.phase=="ended":
		finished=true;result=score_position()
		# Prefer winning now to a merely predicted win after another draw.
		if game.winner==perspective:result-=(game.round_number-initial_round)*25.
		elif game.winner==1-perspective:result+=(game.round_number-initial_round)*10.
		return
	if game.phase=="review":
		if game.round_number>initial_round:
			finished=true;result=first_score*.35+score_position()*.65;return
		first_score=score_position();game.advance_round();return
	steps+=1
	if steps>360:
		finished=true;valid=false;result=-1000000.;return
	if not game.animation.is_empty():game.advance_animation();return
	var team=(0 if game.plans[0]==null else 1) if game.phase=="planning" else int(game.request.get("team",-1))
	if team<0:finished=true;valid=false;result=-1000000.;return
	var view=game.snapshot(team);var choice=policy.decide(view,team)
	if choice.is_empty():finished=true;valid=false;result=-1000000.;return
	var error=Actions.apply(game,team,choice.kind,choice.payload,view.match,view.round,view.revision)
	if not error.is_empty():finished=true;valid=false;result=-1000000.

static func evaluate(g,team:int)->float:
	if g.phase=="ended":return 250. if g.winner==team else 0. if g.winner==-1 else -250.
	var score=0.;var badge_values=[0.,24.,56.,106.,100000.]
	for side in [team,1-team]:
		var value=badge_values[clampi(g.badges[side],0,4)]
		for c in g.characters:
			if c.team!=side:continue
			var alive=c.hp>0
			if alive:value+=22.+c.hp*2.2+(c.max_hp-7)*.5
			var hand=0.
			for id in c.hand:
				var key=g.catalog.get(id,g.death_catalog.get(id,{})).get("key","")
				var v=2.2
				if g.defiled_cards.has(id) or key in ["boulder","curse"]:v=-1.8
				elif key=="poison":v=-3.5
				elif key in ["badge","topaz"]:v=4.5
				elif key in ["sapphire","ruby","holy_amulet","amethyst"]:v=4.
				elif key in ["attack_amulet","magic_amulet","raise_dead","final_strike"]:v=3.
				hand+=v
			value+=hand*(1. if alive else .18)
			if alive and c.hand.size()>0:
				if c.get("silenced_round",-1)>g.round_number:value-=7.
				if c.get("overload_round",-1)>g.round_number:value+=minf(c.hand.size(),3)*2.
				if c.get("extra_round",-1)>g.round_number:value+=minf(c.hand.size(),c.extra_count)*2.
				if c.get("warcry_round",-1)>g.round_number:value+=3.
		for e in g.effects:
			var key=g.death_catalog[e.card].key
			if not g.characters[e.owner].deathrattles.has(e.card):continue
			if key=="prison" and g.characters[e.target].team==side:value-=5.
			elif g.characters[e.owner].team==side:value+={"greed":13.,"privilege":15.,"divinity":9.,"eye":6.,"blessing":8.,"ghost":5.,"pain":7.}.get(key,3.)
		score+=value if side==team else -value
	return clampf(score,-200.,200.)
