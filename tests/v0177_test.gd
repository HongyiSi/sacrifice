extends SceneTree
const H = preload("res://tests/helpers.gd")
const S = preload("res://tests/v011_scenarios.gd")
var checks := 0
var failures := 0
var cues: Array = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V0177_FAIL "+label)
func fixture():
	var g = H.fixture(8)
	g.presentation_enabled = true
	g.stage_presentation_enabled = true
	g.resolution_presentation_enabled = true
	return g
func cue(g, stage: String, rank: int = -1) -> void:
	check(g.animation.get("kind","") == "phase_change", "transition is synchronized before next effect")
	check(g.turn_stage == stage and g.stage_main == rank, "authoritative stage/rank")
	check(g.snapshot(0).turn_stage == g.snapshot(1).turn_stage and g.snapshot(0).stage_main == rank,"same broad stage for both peers")
	if not g.animation.is_empty():
		check(g.animation.action.is_empty() and g.animation.targets.is_empty(), "stage cue does not impersonate card effect")
		check(g.animation.travel_ms >= 900, "transition visible long enough")
func clear_cue(g) -> void:
	check(g.animation.get("kind","") == "phase_change","phase cue pending")
	g.advance_animation();g.advance_animation()
func drain(g, stop: Array = ["review","ended"]) -> void:
	for _i in range(250):
		if g.animation.is_empty() and g.phase in stop: return
		if g.animation.get("kind","") == "phase_change" and g.animation.stage == "travel": cues.append([g.turn_stage,g.stage_main])
		check(S.step(g).is_empty(),"nested effect advances")
	check(false,"drain terminates")
func _run() -> void:
	var g = H.Rules.new();g.presentation_enabled=true;g.start(177)
	check(g.phase=="planning" and g.animation.is_empty() and g.visual_queue.is_empty(),"initial hands appear immediately")
	check(g.characters.all(func(c):return c.hand.size()==4),"exactly four cards for every pawn")
	check(g.deck.size()==g.catalog.size()-24 and g.turn_stage=="planning","initial deck counter and stage")
	for viewer in [0,1]:
		for c in g.snapshot(viewer).characters: check(c.hand.size()==(4 if c.team==viewer else 0),"opening privacy")
	# Several cards at the same rank cause one cue, not one per card/response.
	g=fixture();var a=H.give(g,0,"heal");var b=H.give(g,1,"heal");var c=H.give(g,3,"strike")
	H.begin(g,{0:a,1:b,3:c},false);cue(g,"resolution",6)
	check(g.queue.all(func(q):return not q.revealed),"priority notification precedes simultaneous reveal")
	check(g.snapshot(1).queue.filter(func(q):return q.actor<3).all(func(q):return q.card==0),"notification does not reveal enemy cards early")
	cues=[["resolution",6]];clear_cue(g);drain(g)
	check(cues==[["resolution",6],["resolution",5],["death",-1]],"one cue per rank then death even with empty death queue")
	check(g.turn_stage=="death" and g.phase=="review","death banner retained through automatic round end")
	g.advance_round();cue(g,"planning");clear_cue(g)
	check(g.animation.kind=="draw_cards" and g.animation.draws.size()==6,"later round draws retain flights")
	drain(g,["planning"])
	# Entirely skipped round still shows the ordinary and death stages.
	g=fixture();H.begin(g,{},false);cue(g,"resolution");clear_cue(g);cue(g,"death");clear_cue(g)
	check(g.phase=="review","empty round never stalls")
	# Reverse changes actual rank order, never the order within a rank.
	g=fixture();H.begin(g,{0:H.give(g,0,"reverse"),1:H.give(g,1,"heal"),3:H.give(g,3,"strike")},false)
	cues=[];drain(g)
	check(cues==[["resolution",10],["resolution",5],["resolution",6],["death",-1]],"reverse uses actual 10-5-6 progression")
	# Privilege's modified priorities must display their actual values.
	g=fixture();var p=H.give_death(g,0,"privilege");g._activate({"actor":0,"card":p},0)
	H.begin(g,{0:H.give(g,0,"strike"),3:H.give(g,3,"heal")},false);cue(g,"resolution",105)
	cues=[];drain(g);check(cues.has(["resolution",6]),"nonprivileged cards follow privileged batch")
	# Death cards triggered by feign belong to the ordinary phase.
	g=fixture();H.give_death(g,0,"legacy");H.begin(g,{0:H.give(g,0,"feign")},false);clear_cue(g)
	var forced_death:=false
	for _i in range(120):
		if g.animation.get("action",{}).get("death",false):
			forced_death=true;check(g.turn_stage=="resolution" and g.stage_main==0,"feign retains ordinary phase through immediate deaths")
		if g.phase in ["review","ended"] and g.animation.is_empty():break
		check(S.step(g).is_empty(),"feign advances")
	check(forced_death,"forced death sequence exercised")
	# Start a new match on the same Rules object: no leftover flights or cursors.
	g.start(178,2)
	check(g.phase=="planning" and g.animation.is_empty() and g.stage_main==-1 and not g.initial_deal,"rematch resets presentation")
	check(g.characters.all(func(x):return x.hand.size()==4),"rematch begins with four cards")
	print("V0177_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
