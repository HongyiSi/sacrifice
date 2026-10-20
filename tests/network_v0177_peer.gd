extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
const S = preload("res://tests/v011_scenarios.gd")
const CASES := ["ranks", "reverse", "empty", "death", "round_draw"]
var session
var role := "host"
var port := 25177
var prepared := false
var completed := false
var started := 0
var last_request := ""
var seen := {}
var reviews := {}
var trace: Array = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	session = Session.new(); session.name = "Session"
	root.add_child.call_deferred(session); _begin.call_deferred()
func fail(message: String) -> void:
	push_error("V0177_NETWORK_FAIL "+message); quit(2)
func _begin() -> void:
	started = Time.get_ticks_msec()
	session.problem.connect(fail); session.changed.connect(_changed)
	if role == "host": session.host_room("特效房主",port)
	else: session.join_room("特效访客","127.0.0.1",port)
func _changed() -> void:
	var s: Dictionary = session.state
	if s.is_empty() or completed: return
	if role == "host" and not prepared:
		prepared = true; _setup.call_deferred(0); return
	if s.match < 2000: return
	for c in s.characters:
		if c.team != session.team and not s.omniscient and not c.hand.is_empty(): fail("private hand leak"); return
	if s.input.get("type","") in ["deck","hand","bonus"] and s.input.team != session.team and not s.omniscient and not s.input.options.is_empty(): fail("private picker leak"); return
	if s.input.has("cards") and s.input.team != session.team and not s.input.cards.is_empty(): fail("peek leak"); return
	if s.phase == "animating":
		var event: Dictionary = s.animation
		if event.kind == "phase_change":
			if s.turn_stage != event.turn_stage or s.stage_main != event.main: fail("stage header differs from cue"); return
		var key: String = "%d/%d/%s" % [s.match,event.id,event.stage]
		if not seen.has(key):
			seen[key] = Time.get_ticks_msec()
			var public_event=event.duplicate(true)
			for d in public_event.get("draws",[]):
				if int(d.target)/3 != session.team and not s.omniscient and (d.has("ids") or d.has("before_hand")): fail("draw flight leaks opponent card"); return
				d.erase("ids"); d.erase("before_hand")
			trace.append({"match":s.match,"event":public_event,"hp":s.characters.map(func(c): return c.hp),"hand_counts":s.characters.map(func(c): return c.hand_count),"badges":s.badges,"turn_stage":s.turn_stage,"stage_main":s.stage_main})
			if event.stage == "impact":
				var travel: String = "%d/%d/travel" % [s.match,event.id]
				if not seen.has(travel): fail("impact without travel"); return
				if Time.get_ticks_msec()-int(seen[travel]) < int(event.get("travel_ms",650))-140: fail("windup cut short"); return
	var scenario_index := int(s.match) - 2000
	var final_phase: bool = s.phase in ["review","ended"] or (scenario_index == CASES.find("round_draw") and s.phase == "planning")
	if final_phase and not reviews.has(s.match):
		reviews[s.match] = true
		if reviews.size() == CASES.size():
			completed = true
			for match_serial in reviews:
				var stages: Array = trace.filter(func(e): return e.match == match_serial)
				if stages.is_empty() or stages.size()%2 != 0: fail("incomplete scenario stages"); return
				for e in stages:
					if e.event.stage == "travel" and not seen.has("%d/%d/impact" % [match_serial,e.event.id]): fail("travel without impact"); return
			var file = FileAccess.open("res://test-results/network-v0177-"+role+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify(trace)); file.close()
			print("NETWORK_V0177_RESULT role=%s scenarios=%d stages=%d privacy=true timing=true" % [role,reviews.size(),trace.size()])
			_finish.call_deferred()
		elif role == "host": _next.call_deferred(int(s.match)-2000+1)
func _setup(index: int) -> void:
	var key: String = CASES[index]
	var g = H.fixture(8)
	g.presentation_enabled = true
	g.stage_presentation_enabled = true
	g.resolution_presentation_enabled = true
	match key:
		"ranks": H.begin(g,{0:H.give(g,0,"heal"),3:H.give(g,3,"strike")},false)
		"reverse": H.begin(g,{0:H.give(g,0,"reverse"),1:H.give(g,1,"heal"),3:H.give(g,3,"strike")},false)
		"empty": H.begin(g,{},false)
		"death":
			H.give_death(g,0,"resurrection");S.die(g,0);H.begin(g,{},false)
		"round_draw":
			g.turn_stage="death";g.phase="review";g.advance_round()
	g.match_id = 2000+index
	session.game = g; session._broadcast()
func _next(index: int) -> void:
	await create_timer(0.15).timeout; _setup(index)
func _finish() -> void:
	# Scenario replacement skips the warm-up deal on the host; let the remote
	# presentation buffer finish its already received opening flight before exit.
	await create_timer(12.0 if role == "host" else 0.5).timeout; quit(0)
func _process(_delta: float) -> bool:
	if started > 0 and Time.get_ticks_msec()-started > 290000: fail("timeout")
	if completed or session == null or session.state.is_empty(): return false
	var s: Dictionary = session.state
	var request_key: String = "%d/%d" % [s.match,s.revision]
	if s.match < 2000 or last_request == request_key: return false
	last_request = request_key
	if s.input.is_empty() or s.input.team != session.team: return false
	match s.phase:
		"targeting","death_targeting":
			var target: int = H.auto_input(s)
			if s.active_card.key in ["strike","magic_strike"] and s.active_action.actor == 3 and s.input.options.has(0): target = 0
			session.act("target",[target])
		"choosing": session.act("choose",[H.auto_input(s)])
		"responding": session.act("respond",[s.input.options[0]])
		"reacting": session.act("defend",[1])
		"selecting": session.act("pick",H.auto_pick(s))
	return false
