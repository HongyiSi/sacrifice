extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
var session
var role := "host"
var port := 24885
var waiting := false
var finishing := false
var started := 0
var picks := 0
var last_intent := ""
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
	if Time.get_ticks_msec() - started > 20000: push_error("ALL_NETWORK_TIMEOUT " + role); quit(4)
	return false

func _changed() -> void:
	var s: Dictionary = session.state
	if not s.is_empty():
		if not s.omniscient:
			for c in s.characters:
				if c.team != session.team and not c.hand.is_empty(): push_error("PRIVATE_HAND_LEAK"); quit(5)
			if not s.deck_view.is_empty() or not s.death_deck_view.is_empty(): push_error("PRIVATE_DECK_LEAK"); quit(6)
		if s.input.get("type","") in ["deck","hand","bonus"] and s.input.team != session.team and not s.omniscient:
			if not s.input.options.is_empty(): push_error("PRIVATE_PICK_LEAK"); quit(7)
	if not waiting and not finishing:
		waiting = true
		_play.call_deferred()

func _dead(g, id: int) -> void:
	g.characters[id].hp = 0
	g.characters[id].death_round = g.round_number

func _activate(g, owner: int, key: String) -> void:
	var id: int = H.give_death(g,owner,key)
	g._activate({"actor":owner,"card":id},owner)
	g.death_revealed.append(id)
	_dead(g,owner)

func _prepare(serial: int) -> void:
	var g = H.fixture()
	g.match_id = serial
	match serial:
		20:
			_activate(g,0,"divinity")
			H.give_death(g,3,"greed"); _dead(g,3)
			g._finish_round()
		21:
			_activate(g,0,"divinity")
			_activate(g,3,"pain")
			H.give(g,4,"strike",10); H.give(g,4,"strike",9)
			H.begin(g,{4:H.give(g,4,"strike",8)})
		22:
			_activate(g,3,"eye")
			H.give(g,0,"triple_strike"); H.give(g,1,"strike"); H.give(g,4,"strike")
		23:
			H.give_death(g,3,"heart"); _dead(g,3)
			g._finish_round()
	session.game = g
	session._broadcast()

func _send(kind: String, values: Array = []) -> void:
	var s: Dictionary = session.state
	var key := "%d:%d:%s:%d" % [s.match,s.round,kind,0 if kind in ["plan","confirm"] else s.revision]
	if key == last_intent: return
	last_intent = key
	if kind == "pick": picks += 1
	session.act(kind,values)

func _play() -> void:
	waiting = false
	var s: Dictionary = session.state
	if s.is_empty(): return
	if s.match == 1:
		if role == "host": _prepare(20)
		return
	if s.phase == "planning":
		if s.ready[session.team]: return
		if s.match == 22:
			if role == "client" and (not s.omniscient or s.characters[0].hand.is_empty() or s.deck_view.is_empty()):
				push_error("EYE_VIEW_MISSING"); quit(8); return
			_send("plan",H.auto_plan(s,session.team))
		else:
			_send("plan",[s.characters[0].hand.slice(0,2),0,0] if role == "host" else [0,0,0])
		return
	if s.phase == "selecting" and s.input.team == session.team:
		_send("pick",[1] if s.input.type == "pain" else s.input.options.slice(0,s.input.count))
		return
	if s.input.get("can_skip",false) and s.input.team == session.team:
		if s.match == 20: _send("target",[4])
		elif s.match == 21 and s.active_action.id == 1 and not s.active_action.get("death",false): _send("target",[3])
		elif s.match == 23: _send("target",[0])
		else: _send("skip_effect")
		return
	if s.phase != "review": return
	if s.match == 20 and s.characters[4].hand_count != 5: push_error("GREED_RESULT_BAD"); quit(9); return
	if s.match == 21 and (s.queue.size() != 3 or s.characters[4].hand_count != 1): push_error("PAIN_RESULT_BAD"); quit(10); return
	if s.match == 23:
		if s.round == 1:
			if not s.confirmed[session.team]: _send("confirm")
			return
		if s.queue.size() != 2 or not s.characters[0].deathrattles.has(107): push_error("HEART_RESULT_BAD"); quit(11); return
		last_view = s.duplicate(true)
		for key in ["confirmed","revision","my_plan","omniscient","deck_view","discard_view","death_deck_view","seen_plans"]: last_view.erase(key)
		for c in last_view.characters:
			c.erase("hand")
			c.deathrattles = c.known_deathrattles.duplicate()
		if role == "client":
			finishing = true
			_send("confirm")
			await create_timer(0.25).timeout
			_finish()
		elif s.confirmed[1]: _finish()
		return
	if role == "host": _prepare(int(s.match) + 1)

func _finish() -> void:
	finishing = true
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var file := FileAccess.open("res://test-results/network-all-deaths-" + role + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"role":role,"picks":picks,"public_state":last_view},"\t"))
	file.close()
	print("ALL_DEATH_NETWORK_RESULT ",role," picks=",picks," scenarios=4 passed=true")
	quit(0)
