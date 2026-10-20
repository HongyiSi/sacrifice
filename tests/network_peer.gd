extends SceneTree
## Run two independent Godot processes against localhost; uses real ENet RPC.
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
var session
var role := "host"
var port := 24881
var ticks := 0
var last_view: Dictionary = {}
var public_view: Dictionary = {}
var waiting := false
var finishing := false
var saw_rematch := false
var saw_disconnect := false
var started := 0
var last_intent := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	session = Session.new()
	session.name = "Session"
	root.add_child.call_deferred(session)
	_begin.call_deferred()

func _begin() -> void:
	started = Time.get_ticks_msec()
	session.changed.connect(_changed)
	session.problem.connect(func(message): push_error(message); quit(2))
	var error: Error
	if role == "host": error = session.host_room("测试房主", port)
	else: error = session.join_room("测试访客", "127.0.0.1", port)
	if error != OK: quit(3)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 35000:
		push_error("NETWORK_TIMEOUT " + role)
		quit(4)
	return false

func _changed() -> void:
	if session.state.is_empty():
		if role == "host" and saw_rematch:
			saw_disconnect = true
			_finish()
		return
	var s: Dictionary = session.state
	for c in s.characters:
		if c.team != session.team and not s.omniscient and not c.hand.is_empty():
			push_error("Opponent hand leaked")
			quit(5)
		if c.team != session.team and not s.omniscient and c.deathrattles != c.known_deathrattles:
			push_error("Opponent hidden deathrattle leaked")
			quit(6)
	if s.match == 2:
		saw_rematch = true
		if role == "client" and not finishing:
			finishing = true
			_disconnect.call_deferred()
		return
	if s.phase == "ended":
		last_view = s.duplicate(true)
		public_view = s.duplicate(true)
		public_view.erase("my_plan")
		public_view.erase("revision")
		public_view.erase("confirmed")
		for key in ["omniscient","deck_view","discard_view","death_deck_view","seen_plans"]: public_view.erase(key)
		for c in public_view.characters:
			c.erase("hand")
			c.deathrattles = c.known_deathrattles.duplicate()
		for action in public_view.queue:
			action.inspected = false
			if not action.revealed:
				action.card = 0
				action.main = -1
				action.secondary = -1
				# Eye can legitimately expose these only to one side. They are
				# private until revealed, just like main and secondary above.
				action.base_main = -1
				action.base_secondary = -1
	if not waiting:
		waiting = true
		_play.call_deferred()

func _play() -> void:
	waiting = false
	var s: Dictionary = session.state
	if s.is_empty() or s.match != 1: return
	var team: int = session.team
	match s.phase:
		"planning":
			if s.ready[team]: return
			_act("plan", H.auto_plan(s,team))
		"targeting", "death_targeting":
			if s.input.team == team: _act("target", [H.auto_input(s)])
		"choosing":
			if s.input.team == team: _act("choose", [H.auto_input(s)])
		"selecting":
			if s.input.team == team: _act("pick", H.auto_pick(s))
		"responding":
			if s.input.team == team: _act("respond", [s.input.options[0]])
		"reacting":
			if s.input.team == team: _act("defend", [1])
		"review", "ended":
			if not s.confirmed[team]: _act("confirm")

func _act(kind: String, values: Array = []) -> void:
	var s: Dictionary = session.state
	var key := "%d:%d:%s:%d" % [s.match,s.round,kind,0 if kind in ["plan","confirm"] else s.revision]
	if key == last_intent: return
	last_intent = key
	session.act(kind,values)

func _disconnect() -> void:
	await create_timer(0.3).timeout
	session.leave()
	_finish()

func _finish() -> void:
	var result := {"role": role, "rematch": saw_rematch, "disconnect_seen": saw_disconnect,
		"rounds": last_view.get("round", 0), "winner": last_view.get("winner", -2), "public_state": public_view}
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var file := FileAccess.open("res://test-results/network-" + role + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("NETWORK_RESULT ", role, " rounds=", result.rounds, " winner=", result.winner, " rematch=", saw_rematch, " disconnect=", saw_disconnect)
	quit(0)
