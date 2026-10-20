extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
var session
var role := "create"
var group := "a"
var url := "ws://127.0.0.1:25016"
var started := 0
var last_request := ""
var planned_round := ""
var traces: Array = []
var seen := {}
var done := false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--group="): group = arg.trim_prefix("--group=")
		if arg.begins_with("--url="): url = arg.trim_prefix("--url=")
	_run.call_deferred()
func fail(message: String) -> void: push_error("V016_NETWORK_FAIL "+message); quit(2)
func _run() -> void:
	started = Time.get_ticks_msec()
	var main := Node.new(); main.name = "Main"; root.add_child(main)
	session = Session.new(); session.name = "Session"; main.add_child(session)
	session.changed.connect(_changed); session.problem.connect(fail)
	var code := ""
	var path := "res://test-results/v016-room-"+group+".txt"
	if role == "join":
		while not FileAccess.file_exists(path): await create_timer(.1).timeout
		code = FileAccess.get_file_as_string(path).strip_edges()
	session.connect_online(group+"-"+role,role=="create",code,url)
func _changed() -> void:
	if done: return
	if not session.room_code.is_empty() and role == "create":
		var file = FileAccess.open("res://test-results/v016-room-"+group+".txt",FileAccess.WRITE)
		file.store_string(session.room_code); file.close()
	if session.state.is_empty(): return
	var s: Dictionary = session.state
	for c in s.characters:
		if c.team != session.team and not s.omniscient and not c.hand.is_empty(): fail("opponent hand leaked"); return
	var stamp := "%d/%d" % [s.match,s.revision]
	if not seen.has(stamp):
		seen[stamp] = true
		traces.append({"revision":s.revision,"round":s.round,"phase":s.phase,"hp":s.characters.map(func(c):return c.hp),"badges":s.badges,"animation":s.animation})
	if s.phase == "ended" or (s.phase == "review" and s.round >= 12):
		done = true
		var file = FileAccess.open("res://test-results/v016-network-"+group+"-"+role+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(traces)); file.close()
		print("NETWORK_V016_RESULT group=%s role=%s rounds=%d snapshots=%d room=%s" % [group,role,s.round,traces.size(),session.room_code])
		await create_timer(.5).timeout; quit(0)
func _process(_delta: float) -> bool:
	if started > 0 and Time.get_ticks_msec()-started > 240000: fail("timeout")
	if done or session == null or session.state.is_empty(): return false
	var s: Dictionary = session.state
	var stamp := "%d/%d" % [s.match,s.revision]
	if stamp == last_request: return false
	last_request = stamp
	if s.phase == "planning" and not s.ready[session.team]:
		var key := "%d/%d" % [s.match,s.round]
		if planned_round != key:
			planned_round = key
			session.act("plan",H.auto_plan(s,session.team))
	elif not s.input.is_empty() and s.input.team == session.team:
		match s.phase:
			"targeting","death_targeting": session.act("target",[H.auto_input(s)])
			"choosing": session.act("choose",[H.auto_input(s)])
			"reacting": session.act("defend",[1])
			"responding": session.act("respond",[s.input.options[0]])
			"selecting": session.act("pick",H.auto_pick(s))
	return false
