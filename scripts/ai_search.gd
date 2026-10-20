extends RefCounted
## Bounded, cooperative search over whole-team plans and sampled hidden worlds.
const Belief=preload("res://scripts/ai_belief.gd")
const Rollout=preload("res://scripts/ai_rollout.gd")
const Policy=preload("res://scripts/ai_policy.gd")
const SAMPLES=4
const MAX_PLANS=24
var policy=Policy.new(1)
var runner=Rollout.new()
var view={}
var team=0
var seed_value=1
var plans=[]
var worlds=[]
var opponent_plans=[]
var totals=[]
var worst=[]
var failures=[]
var candidate=0
var sample=0
var done=false
var result=[]
var stats={"rollouts":0,"invalid":0,"steps":0,"compute_us":0,"max_slice_us":0,"slices":0}

func begin(snapshot:Dictionary,side:int,seed:int)->void:
	view=snapshot;team=side;seed_value=seed;policy.rng.seed=seed
	plans=candidates(view,team)
	result=plans[0].duplicate(true)
	for p in plans:totals.append(0.);worst.append(INF);failures.append(0)
	stats.candidates=plans.size();stats.samples=SAMPLES

func pawn_options(snapshot:Dictionary,c:Dictionary)->Array:
	if c.hp<=0 or c.play_limit<=0:return [{"cards":[],"score":0.}]
	var ids=c.hand.filter(func(id):return snapshot.catalog[id].get("playable",true))
	var values=ids.map(func(id):return policy.play_value(snapshot,c,id))
	var scored=[]
	for mask in range(1<<ids.size()):
		var picked=[];var value=0.
		for i in range(ids.size()):
			if mask&(1<<i):picked.append(ids[i]);value+=values[i]
		if picked.size()>c.play_limit:continue
		# Do not rank several heals as if they all repaired the same lost HP.
		var heals=picked.filter(func(id):return snapshot.catalog[id].key in ["heal","team_heal","heal_other"]).size()
		if heals>1:value-=float(heals-1)*5.
		scored.append({"cards":picked,"score":value})
	scored.sort_custom(func(a,b):return a.score>b.score if a.score!=b.score else str(a.cards)<str(b.cards))
	var best=scored.slice(0,7)
	if not best.any(func(x):return x.cards.is_empty()):best.append({"cards":[],"score":0.})
	return best

func candidates(snapshot:Dictionary,side:int)->Array:
	var options=[]
	for i in range(3):options.append(pawn_options(snapshot,snapshot.characters[side*3+i]))
	var combinations=[]
	for a in options[0]:
		for b in options[1]:
			for c in options[2]:combinations.append({"plan":[a.cards,b.cards,c.cards],"score":a.score+b.score+c.score})
	combinations.sort_custom(func(a,b):return a.score>b.score if a.score!=b.score else str(a.plan)<str(b.plan))
	var baseline=policy.decide(snapshot,side).get("payload",[[],[],[]])
	var selected=[baseline]
	for item in combinations.slice(0,11):
		if not selected.has(item.plan):selected.append(item.plan)
	# Preserve alternatives from each pawn even when a different pawn's score
	# dominates the beam. This includes passing and saving valuable cards.
	for rank in range(8):
		for slot in range(3):
			if rank>=options[slot].size():continue
			var option=options[slot][rank]
			var p=baseline.duplicate(true);p[slot]=option.cards
			if not selected.has(p):selected.append(p)
	if not selected.has([[],[],[]]):selected.append([[],[],[]])
	if selected.size()>MAX_PLANS:
		var reduced=selected.slice(0,MAX_PLANS-1);reduced.append([[],[],[]]);return reduced
	return selected

func prepare_world()->void:
	var index=worlds.size();var g=Belief.world(view,team,seed_value+index*104729)
	var other=1-team;var s=g.snapshot(other)
	policy.rng.seed=seed_value+index
	var p=policy.decide(s,other).payload
	if index%2==1:
		# A plausible alternative opposing plan, rather than assuming everyone
		# follows exactly our own ranking. Never use the real opponent's plan.
		for slot in range(3):
			var opts=pawn_options(s,s.characters[other*3+slot])
			if opts.size()>1 and opts[1].score>0 and (slot+index)%2==0:p[slot]=opts[1].cards
	if view.get("omniscient",false) and not view.get("seen_plans",[]).is_empty() and view.seen_plans[other]!=null:p=view.seen_plans[other].duplicate(true)
	worlds.append(Belief.capture(g));opponent_plans.append(p)

func advance(budget_us:int=4000)->bool:
	if done:return true
	var started=Time.get_ticks_usec()
	while Time.get_ticks_usec()-started<budget_us:
		if worlds.size()<SAMPLES:prepare_world();continue
		if runner.finished:
			runner.begin(worlds[sample],team,plans[candidate],opponent_plans[sample],seed_value+sample*37)
		runner.step()
		if runner.finished:
			stats.rollouts+=1;stats.steps+=runner.steps
			if not runner.valid:stats.invalid+=1;failures[candidate]+=1
			totals[candidate]+=runner.result;worst[candidate]=minf(worst[candidate],runner.result)
			sample+=1
			if sample==SAMPLES:sample=0;candidate+=1
			if candidate==plans.size():
				finish();break
	var spent=Time.get_ticks_usec()-started
	stats.compute_us+=spent;stats.max_slice_us=maxi(stats.max_slice_us,spent);stats.slices+=1
	return done

func finish()->void:
	var best=-INF
	# Compare only plans evaluated against the same complete set of worlds.
	# An interrupted rollout can never replace the known legal fallback.
	for i in range(candidate):
		if failures[i]>0:continue
		var value=totals[i]/SAMPLES*.95+worst[i]*.05
		if value>best:best=value;result=plans[i].duplicate(true)
	stats.value=best;stats.evaluated_candidates=candidate;stats.truncated=candidate<plans.size();done=true
