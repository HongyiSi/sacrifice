extends "res://scripts/ai_policy.gd"
## Strong local opponent. The live session polls search in small frame budgets;
## decide() also provides deterministic, synchronous decisions for simulations.
const Search=preload("res://scripts/ai_search.gd")
var pending:RefCounted
var pending_match=-1
var pending_round=-1
var pending_started=0
var last_stats={}

func cancel_search()->void:
	pending=null;pending_match=-1;pending_round=-1

func poll(view:Dictionary,team:int,budget_us:int=6000,limit_ms:int=4000)->Dictionary:
	if view.is_empty() or not view.get("animation",{}).is_empty():return {}
	if view.phase!="planning" or view.ready[team]:
		cancel_search();return super.decide(view,team)
	if pending==null or pending_match!=view.match or pending_round!=view.round:
		pending=Search.new();pending_match=view.match;pending_round=view.round
		pending_started=Time.get_ticks_msec()
		pending.begin(view,team,rng.randi())
	if not pending.advance(budget_us):
		if limit_ms<=0 or Time.get_ticks_msec()-pending_started<limit_ms:return {}
		pending.finish()
	pending.stats.wall_ms=Time.get_ticks_msec()-pending_started
	var plan=pending.result;last_stats=pending.stats.duplicate();cancel_search()
	return action("plan",plan)

func decide(view:Dictionary,team:int)->Dictionary:
	if view.is_empty() or view.phase!="planning" or not view.get("animation",{}).is_empty() or view.ready[team]:return super.decide(view,team)
	var choice=poll(view,team,1000000,0)
	while choice.is_empty():choice=poll(view,team,1000000,0)
	return choice
