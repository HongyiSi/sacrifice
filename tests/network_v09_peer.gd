extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
var session
var role := "host"
var port := 24995
var prepared := false
var completed := false
var started := 0
var last_revision := -1
var seen := {}
var trace: Array = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	session = Session.new(); session.name = "Session"
	root.add_child.call_deferred(session); _begin.call_deferred()
func fail(message: String) -> void:
	push_error("V09_NETWORK_FAIL "+message); quit(2)
func _begin() -> void:
	started = Time.get_ticks_msec()
	session.problem.connect(fail)
	session.changed.connect(_changed)
	if role == "host": session.host_room("动画房主",port)
	else: session.join_room("动画访客","127.0.0.1",port)
func _changed() -> void:
	var s: Dictionary = session.state
	if s.is_empty() or completed: return
	if role == "host" and not prepared:
		prepared = true
		if not session.game.presentation_enabled: fail("live sessions must enable presentation"); return
		_setup.call_deferred(); return
	if s.match != 91: return
	for c in s.characters:
		if c.team != session.team and not c.hand.is_empty(): fail("private hand leak"); return
	if s.phase == "animating":
		var effect: Dictionary = s.animation
		var key: String = str(effect.id)+effect.stage
		if not seen.has(key):
			seen[key] = true
			trace.append({"id":effect.id,"stage":effect.stage,"kind":effect.kind,"targets":effect.targets,"hp":s.characters.map(func(c): return c.hp),"card":s.active_card.key})
			if effect.kind == "heal":
				for target in effect.targets:
					var expected: int = target.before if effect.stage == "travel" else target.after
					if s.characters[target.id].hp != expected: fail("HP changed before visual impact"); return
	if s.round == 2:
		completed = true
		if trace.size() != 8: fail("missing animation stages: "+str(trace.size())); return
		if s.characters[1].hp != 6: fail("shield failed to prevent attack"); return
		if Time.get_ticks_msec()-started < 5000: fail("effects advanced without waiting"); return
		var file = FileAccess.open("res://test-results/network-v09-"+role+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(trace)); file.close()
		print("NETWORK_V09_RESULT role=%s stages=%d HP_timing=true" % [role,trace.size()])
		_finish.call_deferred()
func _setup() -> void:
	var g = H.fixture(5); g.match_id = 91; g.presentation_enabled = true
	H.give(g,0,"heal"); H.give(g,1,"defense"); H.give(g,2,"team_heal"); H.give(g,3,"double_strike")
	session.game = g; session._broadcast()
func _finish() -> void:
	await create_timer(0.4).timeout; quit(0)
func _process(_delta: float) -> bool:
	if started > 0 and Time.get_ticks_msec()-started > 18000: fail("timeout")
	if completed or session == null or session.state.is_empty(): return false
	var s: Dictionary = session.state
	if s.match != 91 or last_revision == s.revision: return false
	last_revision = s.revision
	if s.phase == "planning" and not s.ready[session.team]:
		var plan := [0,0,0]
		for slot in range(3):
			var hand: Array = s.characters[session.team*3+slot].hand
			if not hand.is_empty(): plan[slot] = hand[0]
		session.act("plan",plan)
	elif s.phase == "targeting" and s.input.team == session.team: session.act("target",[1])
	elif s.phase == "reacting" and s.input.team == session.team: session.act("defend",[1])
	return false
