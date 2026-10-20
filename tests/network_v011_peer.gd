extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
const S = preload("res://tests/v011_scenarios.gd")
const CASES := ["collect","gambler","mirror","suppress","prophecy","reverse","peek","plunder","feign","immortal","last_dance","resurrection","mediocrity","life_steal","curse","prison","heart","divinity","winning_badge","curse_tick","divinity_draw","ghost_attack"]
var session
var role := "host"
var port := 24997
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
	push_error("V011_NETWORK_FAIL "+message); quit(2)
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
		var key: String = "%d/%d/%s" % [s.match,event.id,event.stage]
		if not seen.has(key):
			seen[key] = Time.get_ticks_msec()
			trace.append({"match":s.match,"event":event,"hp":s.characters.map(func(c): return c.hp),"hand_counts":s.characters.map(func(c): return c.hand_count),"badges":s.badges})
			if event.stage == "impact":
				var travel: String = "%d/%d/travel" % [s.match,event.id]
				if not seen.has(travel): fail("impact without travel"); return
				if Time.get_ticks_msec()-int(seen[travel]) < int(event.get("travel_ms",650))-140: fail("windup cut short"); return
	var scenario_index := int(s.match) - 2000
	var final_phase: bool = s.phase in ["review","ended"] or (scenario_index == CASES.find("curse_tick") and s.phase == "planning")
	if final_phase and not reviews.has(s.match):
		reviews[s.match] = true
		if reviews.size() == CASES.size():
			completed = true
			for match_serial in reviews:
				var stages: Array = trace.filter(func(e): return e.match == match_serial)
				if stages.is_empty() or stages.size()%2 != 0: fail("incomplete scenario stages"); return
				for e in stages:
					if e.event.stage == "travel" and not seen.has("%d/%d/impact" % [match_serial,e.event.id]): fail("travel without impact"); return
			var file = FileAccess.open("res://test-results/network-v011-"+role+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify(trace)); file.close()
			print("NETWORK_V011_RESULT role=%s scenarios=%d stages=%d privacy=true timing=true" % [role,reviews.size(),trace.size()])
			_finish.call_deferred()
		elif role == "host": _next.call_deferred(int(s.match)-2000+1)
func _setup(index: int) -> void:
	var key: String = CASES[index]
	var g
	if key in ["winning_badge","curse_tick","divinity_draw","ghost_attack"]:
		g = H.fixture(5)
		match key:
			"winning_badge":
				g.badges[0] = 3; g.presentation_enabled = true
				H.begin(g,{0:H.give(g,0,"badge")})
			"curse_tick":
				g.characters[3].hand.append(104); g.death_deck.erase(104)
				H.give_death(g,3,"immortal"); H.give_death(g,3,"eye")
				g.characters[3].hp = 1; g.phase = "review"; g.presentation_enabled = true; g.advance_round()
			"divinity_draw":
				H.give_death(g,0,"divinity"); S.die(g,0)
				g._activate({"actor":0,"card":102},0); g.death_revealed.append(102)
				g.presentation_enabled = true; H.begin(g,{1:H.give(g,1,"collect")})
			"ghost_attack":
				H.give_death(g,0,"ghost"); S.die(g,0)
				g._activate({"actor":0,"card":115},0); g.death_revealed.append(115)
				g.presentation_enabled = true; H.begin(g,{})
	else:
		var death: bool = H.fixture().death_catalog.values().any(func(c): return c.key == key)
		g = S.setup(key,death,true)
	g.match_id = 2000+index
	session.game = g; session._broadcast()
func _next(index: int) -> void:
	await create_timer(0.15).timeout; _setup(index)
func _finish() -> void:
	await create_timer(0.5).timeout; quit(0)
func _process(_delta: float) -> bool:
	if started > 0 and Time.get_ticks_msec()-started > 165000: fail("timeout")
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
