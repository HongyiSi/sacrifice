extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
const S = preload("res://tests/v011_scenarios.gd")
const CASES := ["revive_unrevealed","blood_rite","elegy","peek","amulet","immortal"]
var session
var role := "host"
var port := 24999
var prepared := false
var completed := false
var started := 0
var last_request := ""
var seen := {}
var reviews := {}
var starts := {}
var trace: Array = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	session = Session.new(); session.name = "Session"
	root.add_child.call_deferred(session); _begin.call_deferred()
func fail(message: String) -> void:
	push_error("V013_NETWORK_FAIL "+message); quit(2)
func _begin() -> void:
	started = Time.get_ticks_msec()
	session.problem.connect(fail); session.changed.connect(_changed)
	if role == "host": session.host_room("平衡房主",port)
	else: session.join_room("平衡访客","127.0.0.1",port)
func _changed() -> void:
	var s: Dictionary = session.state
	if s.is_empty() or completed: return
	if role == "host" and not prepared:
		prepared = true; _setup.call_deferred(0); return
	if s.match < 4000: return
	var stamp := "%d/%d" % [s.match,s.revision]
	if not seen.has(stamp):
		seen[stamp] = true
		trace.append({"match":s.match,"revision":s.revision,"phase":s.phase,"hp":s.characters.map(func(c): return c.hp),"max_hp":s.characters.map(func(c): return c.max_hp),"animation":s.animation})
	var key: String = CASES[int(s.match)-4000]
	if s.animation.get("kind","") == "card_start": starts[s.active_card.key] = true
	if s.phase == "selecting" and key == "peek":
		if s.input.team == session.team and s.input.deaths != [120]: fail("peek missing secret death card"); return
		if s.input.team != session.team and not s.input.deaths.is_empty(): fail("peek leaked"); return
	if s.phase == "selecting" and key == "elegy" and s.input.team != session.team and not s.input.options.is_empty(): fail("cost hand leaked"); return
	if s.phase == "review" and not reviews.has(s.match):
		reviews[s.match] = true
		if key in ["revive_unrevealed","immortal"] and (s.characters[0].hp != 1 or s.characters[3].hp != 7): fail("revived action did not resolve"); return
		if key == "blood_rite" and (s.characters[0].max_hp != 10 or s.characters[0].hp != 0 or s.characters[1].hp != 10): fail("blood rite cap mismatch"); return
		if key == "elegy" and (s.characters[0].hand_count != 0 or s.characters[0].death_count != 1): fail("elegy cost mismatch"); return
		if key == "amulet" and s.characters[0].hp != 8: fail("amulet no longer cancels"); return
		if reviews.size() == CASES.size():
			for required in ["reverse","holy_strike","raise_dead","strike","blood_rite","elegy","peek","magic_amulet","immortal"]:
				if not starts.has(required): fail("missing start cue: "+required); return
			completed = true
			var file = FileAccess.open("res://test-results/network-v013-"+role+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify(trace)); file.close()
			print("NETWORK_V013_RESULT role=%s scenarios=%d snapshots=%d intros=%d" % [role,reviews.size(),trace.size(),starts.size()])
			_finish.call_deferred()
		elif role == "host": _next.call_deferred(int(s.match)-4000+1)
func _setup(index: int) -> void:
	var g = H.fixture(8); g.presentation_enabled = true; g.resolution_presentation_enabled = true
	match CASES[index]:
		"revive_unrevealed":
			g.characters[0].hp = 1
			H.begin(g,{0:H.give(g,0,"strike"),1:H.give(g,1,"reverse"),2:H.give(g,2,"raise_dead"),3:H.give(g,3,"holy_strike")})
		"blood_rite":
			S.die(g,0); H.give_death(g,0,"blood_rite"); g.characters[1].hp = 2; H.begin(g,{})
		"elegy":
			H.give(g,0,"strike"); H.give(g,0,"heal"); H.begin(g,{0:H.give(g,0,"elegy")})
		"peek":
			H.give(g,3,"strike"); H.give_death(g,3,"immortal"); H.begin(g,{0:H.give(g,0,"peek")})
		"amulet": H.begin(g,{0:H.give(g,0,"magic_amulet"),3:H.give(g,3,"magic_strike")})
		"immortal":
			g.characters[0].hp = 1; H.give_death(g,0,"immortal")
			H.begin(g,{0:H.give(g,0,"strike"),3:H.give(g,3,"quick_strike")})
	g.match_id = 4000+index; session.game = g; session._broadcast()
func _next(index: int) -> void:
	await create_timer(0.12).timeout; _setup(index)
func _finish() -> void:
	await create_timer(0.4).timeout; quit(0)
func _process(_delta: float) -> bool:
	if started > 0 and Time.get_ticks_msec()-started > 80000: fail("timeout")
	if completed or session == null or session.state.is_empty(): return false
	var s: Dictionary = session.state
	var stamp := "%d/%d" % [s.match,s.revision]
	if s.match < 4000 or stamp == last_request: return false
	last_request = stamp
	if s.input.is_empty() or s.input.team != session.team: return false
	if s.phase in ["targeting","death_targeting"]:
		session.act("target",[3 if s.active_card.key in ["strike","peek"] else 0])
	elif s.phase == "selecting": session.act("pick",H.auto_pick(s))
	elif s.phase == "responding": session.act("respond",[s.input.options[0]])
	return false
