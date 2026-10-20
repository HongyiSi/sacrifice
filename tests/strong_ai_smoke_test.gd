extends SceneTree
const AI=preload("res://scripts/local_ai.gd")
const Rules=preload("res://scripts/rules.gd")
const Actions=preload("res://scripts/match_actions.gd")
var failures=0
func _initialize():
	var g=Rules.new();g.start(431)
	var ai=AI.new(123);var before=g.snapshot(1)
	var start=Time.get_ticks_msec();var d=ai.decide(before,1)
	print("AI_SEARCH ",ai.last_stats," wall_ms=",Time.get_ticks_msec()-start," plan=",d)
	if d.kind!="plan" or not Actions.apply(g,1,d.kind,d.payload,before.match,before.round,before.revision).is_empty():failures+=1
	if ai.last_stats.invalid>0:failures+=1
	print("STRONG_AI_SMOKE_RESULT checks=2 failures=",failures)
	quit(failures)
