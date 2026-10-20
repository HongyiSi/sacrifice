extends SceneTree
## Real RPC coverage: both ordinary owners, both dead owners, and a partial dance.
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
var session
var role := "host"
var port := 24883
var waiting := false
var finishing := false
var started := 0
var skips := 0
var last_view: Dictionary = {}

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
	var error: Error = session.host_room("房主测试",port) if role == "host" else session.join_room("访客测试","127.0.0.1",port)
	if error != OK: quit(3)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 20000:
		push_error("SKIP_NETWORK_TIMEOUT " + role)
		quit(4)
	return false

func _changed() -> void:
	if not waiting and not finishing:
		waiting = true
		_play.call_deferred()

func _prepare(serial: int) -> void:
	var g = H.fixture()
	g.match_id = serial
	match serial:
		10:
			H.begin(g,{0:H.give(g,0,"strike",10),3:H.give(g,3,"strike",1)})
		11:
			H.give_death(g,0,"resurrection")
			H.give_death(g,3,"vanish")
			for id in [0,3]:
				g.characters[id].hp = 0
				g.characters[id].death_round = g.round_number
			g._finish_round()
		12:
			H.give_death(g,3,"last_dance")
			H.give_death(g,0,"blood_rite")
			H.give_death(g,4,"vanish")
			for id in [3,4]:
				g.characters[id].hp = 0
				g.characters[id].death_round = g.round_number
			g.characters[0].hp = 1
			g.characters[1].hp = 2
			g._finish_round()
	session.game = g
	session._broadcast()

func _play() -> void:
	waiting = false
	var s: Dictionary = session.state
	if s.is_empty(): return
	if s.match == 1:
		if role == "host": _prepare(10)
		return
	if s.input.get("can_skip",false) and s.input.team == session.team:
		if s.match == 12 and s.active_card.key == "last_dance" and s.active_action.hits == 0:
			session.act("target",[0])
		else:
			skips += 1
			session.act("skip_effect")
		return
	if s.phase != "review": return
	if s.match == 10:
		if not s.queue.all(func(a): return a.status == "declined") or not s.characters.all(func(c): return c.hp == 5):
			push_error("NETWORK_ORDINARY_SKIP_FAILED"); quit(5); return
	elif s.match == 11:
		if s.characters[3].hp != 0 or s.death_discard != [110,109]:
			push_error("NETWORK_REVIVAL_SKIP_FAILED"); quit(6); return
	elif s.match == 12:
		if s.characters[0].hp != 0 or s.characters[1].hp != 8 or s.death_discard != [116,118,109]:
			push_error("NETWORK_DANCE_SKIP_FAILED"); quit(7); return
		last_view = s.duplicate(true)
		last_view.erase("confirmed")
		last_view.erase("revision")
		last_view.erase("my_plan")
		for c in last_view.characters:
			c.erase("hand")
			c.deathrattles = c.known_deathrattles.duplicate()
		if role == "client":
			finishing = true
			session.act("confirm")
			await create_timer(0.25).timeout
			_finish()
		elif s.confirmed[1]: _finish()
		return
	if role == "host": _prepare(int(s.match) + 1)

func _finish() -> void:
	finishing = true
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var file := FileAccess.open("res://test-results/network-skip-" + role + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"role":role,"skips":skips,"public_state":last_view},"\t"))
	file.close()
	print("SKIP_NETWORK_RESULT ",role," skips=",skips," scenarios=3 passed=true")
	quit(0)
