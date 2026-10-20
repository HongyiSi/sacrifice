extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
const Styles = preload("res://scripts/strike_styles.gd")
var session
var role := "host"
var port := 24996
var prepared := false
var completed := false
var started := 0
var last_request := ""
var seen := {}
var reviews := {}
var planned := {}
var trace: Array = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	session = Session.new(); session.name = "Session"
	root.add_child.call_deferred(session); _begin.call_deferred()
func fail(message: String) -> void:
	push_error("V010_NETWORK_FAIL "+message); quit(2)
func _begin() -> void:
	started = Time.get_ticks_msec()
	session.problem.connect(fail); session.changed.connect(_changed)
	if role == "host": session.host_room("打击房主",port)
	else: session.join_room("打击访客","127.0.0.1",port)
func _changed() -> void:
	var s: Dictionary = session.state
	if s.is_empty() or completed: return
	if role == "host" and not prepared:
		prepared = true; _setup.call_deferred(0); return
	if s.match < 1000: return
	for c in s.characters:
		if c.team != session.team and not c.hand.is_empty(): fail("private hand leak"); return
	# Later versions also animate rewards and immediate resurrection. This suite
	# compares the twelve strike payloads; support/other effects have separate tests.
	if s.phase == "animating" and s.animation.kind == "strike":
		var event: Dictionary = s.animation
		var key: String = "%d/%d/%s" % [s.match,event.id,event.stage]
		if not seen.has(key):
			seen[key] = Time.get_ticks_msec()
			trace.append({"match":s.match,"stage":event.stage,"style":event.style,"targets":event.targets,"hp":s.characters.map(func(c): return c.hp),"action":event.action})
			for target in event.targets:
				var expected: int = target.before if event.stage == "travel" else target.after
				if s.characters[target.id].hp != expected: fail("HP outside impact boundary"); return
			if event.stage == "impact":
				var travel: String = "%d/%d/travel" % [s.match,event.id]
				if not seen.has(travel): fail("impact without travel"); return
				if Time.get_ticks_msec()-int(seen[travel]) < int(event.travel_ms)-130: fail("windup cut short %s: received %d ms / expected %d ms" % [event.style,Time.get_ticks_msec()-int(seen[travel]),event.travel_ms]); return
	if s.phase == "review" and not reviews.has(s.match):
		reviews[s.match] = true
		if reviews.size() == Styles.PROFILES.size():
			completed = true
			if trace.size() != 24: fail("missing attack stages: "+str(trace.size())); return
			var file = FileAccess.open("res://test-results/network-v010-"+role+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify(trace)); file.close()
			print("NETWORK_V010_RESULT role=%s styles=%d stages=%d HP_timing=true" % [role,reviews.size(),trace.size()])
			_finish.call_deferred()
		elif role == "host": _next.call_deferred(int(s.match)-1000+1)
func _setup(index: int) -> void:
	var key: String = Styles.PROFILES.keys()[index]
	var g = H.fixture(8); g.match_id = 1000+index; g.presentation_enabled = true
	H.give(g,0,key)
	if key == "godslayer": H.give(g,3,"collect")
	if key == "judgment": g.characters[3].hp = 2
	if key in ["bounty","glory","area_strike"]:
		g.characters[3].hp = 1; H.give_death(g,3,"immortal")
	if key == "area_strike": g.characters[4].hp = 1; g.characters[5].hp = 1
	session.game = g; session._broadcast()
func _next(index: int) -> void:
	await create_timer(0.12).timeout; _setup(index)
func _finish() -> void:
	await create_timer(0.5).timeout; quit(0)
func _process(_delta: float) -> bool:
	if started > 0 and Time.get_ticks_msec()-started > 54000: fail("timeout")
	if completed or session == null or session.state.is_empty(): return false
	var s: Dictionary = session.state
	var request_key: String = "%d/%d" % [s.match,s.revision]
	if s.match < 1000 or last_request == request_key: return false
	last_request = request_key
	if s.phase == "planning" and not s.ready[session.team] and not planned.has(s.match):
		planned[s.match] = true
		var plan := [0,0,0]
		for slot in range(3):
			var hand: Array = s.characters[session.team*3+slot].hand
			if not hand.is_empty(): plan[slot] = hand[0]
		session.act("plan",plan)
	elif s.phase == "targeting" and s.input.team == session.team: session.act("target",[3])
	return false
