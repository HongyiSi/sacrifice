extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
var session
var role := "host"
var port := 24887
var waiting := false
var finishing := false
var started := 0
var last_intent := ""
var last_view: Dictionary = {}
var responses := 0
var inspections := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	session = Session.new(); session.name = "Session"
	root.add_child.call_deferred(session)
	_begin.call_deferred()

func _begin() -> void:
	started = Time.get_ticks_msec()
	session.changed.connect(_changed)
	session.problem.connect(func(message): push_error(message); quit(2))
	var error: Error = session.host_room("房主测试",port) if role == "host" else session.join_room("访客测试","127.0.0.1",port)
	if error != OK: quit(3)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 20000: push_error("NORMAL_NETWORK_TIMEOUT " + role); quit(4)
	return false

func _changed() -> void:
	var s: Dictionary = session.state
	if not s.is_empty():
		for c in s.characters:
			if c.team != session.team and not c.hand.is_empty(): push_error("PRIVATE_HAND_LEAK"); quit(5)
		if s.input.get("type","") == "amulet" and s.input.team != session.team and not s.input.options.is_empty(): push_error("PRIVATE_AMULET_LEAK"); quit(6)
		if s.input.get("type","") == "inspect" and s.input.team != session.team and not s.input.cards.is_empty(): push_error("PRIVATE_PEEK_LEAK"); quit(7)
		for a in s.queue:
			if not a.revealed and (a.base_main != -1 or a.base_secondary != -1): push_error("PRIVATE_PRIORITY_LEAK"); quit(8)
	if not waiting and not finishing:
		waiting = true; _play.call_deferred()

func _prepare(serial: int) -> void:
	var g = H.fixture(); g.match_id = serial
	match serial:
		30:
			H.begin(g,{0:H.give(g,0,"holy_amulet"),1:H.give(g,1,"strike"),3:H.give(g,3,"attack_amulet")})
		31:
			H.give(g,0,"feign"); H.give(g,0,"reverse")
			H.begin(g,{3:H.give(g,3,"peek")})
		32:
			H.give_death(g,0,"death_sentence"); H.give_death(g,3,"blood_rite"); g.characters[4].hp = 2
			H.begin(g,{0:H.give(g,0,"feign"),1:H.give(g,1,"skip_death")})
		33:
			H.begin(g,{0:H.give(g,0,"overload")})
		34:
			H.begin(g,{0:H.give(g,0,"reverse"),1:H.give(g,1,"holy_strike"),2:H.give(g,2,"strike"),3:H.give(g,3,"magic_strike")})
	session.game = g
	session._broadcast()

func _send(kind: String, values: Array = []) -> void:
	var s: Dictionary = session.state
	var key := "%d:%d:%s:%d" % [s.match,s.round,kind,0 if kind in ["plan","confirm"] else s.revision]
	if key == last_intent: return
	last_intent = key
	if kind == "respond": responses += 1
	if kind == "pick": inspections += 1
	session.act(kind,values)

func _play() -> void:
	waiting = false
	var s: Dictionary = session.state
	if s.is_empty(): return
	if s.match == 1:
		if role == "host": _prepare(30)
		return
	if s.phase == "planning":
		if not s.ready[session.team]:
			if role == "host":
				if s.characters[0].play_limit != 3: push_error("OVERLOAD_LIMIT_BAD"); quit(9); return
				_send("plan",[s.characters[0].hand.slice(0,3),0,0])
			else: _send("plan",[0,0,0])
		return
	if s.phase == "responding" and s.input.team == session.team:
		_send("respond",[0 if s.active_card.key == "strike" and role == "host" else s.input.options[0]])
		return
	if s.phase == "selecting" and s.input.team == session.team:
		if s.input.type == "inspect" and s.input.cards.size() != 2: push_error("PEEK_CARDS_BAD"); quit(10); return
		_send("pick",H.auto_pick(s))
		return
	if s.input.get("can_skip",false) and s.input.team == session.team:
		if s.match == 30: _send("target",[3])
		elif s.match == 31: _send("target",[0])
		elif s.match == 32: _send("target",[3])
		else: _send("skip_effect")
		return
	if s.phase != "review": return
	if s.match == 30 and s.characters[3].hp != 5: push_error("COUNTER_RESULT_BAD"); quit(11); return
	if s.match == 32 and (s.characters[4].hp != 2 or not s.skip_death_phase): push_error("FEIGN_SKIP_BAD"); quit(12); return
	if s.match == 33:
		if s.round == 1:
			if role == "host" and s.confirmed == [false,false]:
				for rank in [1,2,3]: H.give(session.game,0,"strike",rank)
			if not s.confirmed[session.team]: _send("confirm")
			return
		if s.queue.size() != 3: push_error("OVERLOAD_PLAN_BAD"); quit(13); return
	if s.match == 34:
		if responses != (0 if role == "host" else 1): push_error("TARGET_RESPONSE_NOT_EXERCISED"); quit(15); return
		if not s.reversed_order: push_error("REVERSE_RESULT_BAD"); quit(14); return
		last_view = s.duplicate(true)
		for k in ["confirmed","revision","my_plan","omniscient","deck_view","discard_view","death_deck_view","seen_plans"]: last_view.erase(k)
		for c in last_view.characters: c.erase("hand"); c.deathrattles = c.known_deathrattles.duplicate()
		if role == "client":
			finishing = true; _send("confirm")
			await create_timer(0.25).timeout
			_finish()
		elif s.confirmed[1]: _finish()
		return
	if role == "host": _prepare(int(s.match) + 1)

func _finish() -> void:
	finishing = true
	var file := FileAccess.open("res://test-results/network-all-normal-" + role + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"role":role,"responses":responses,"inspections":inspections,"public_state":last_view},"\t")); file.close()
	print("ALL_NORMAL_NETWORK_RESULT ",role," responses=",responses," inspections=",inspections," scenarios=5 passed=true")
	quit(0)
