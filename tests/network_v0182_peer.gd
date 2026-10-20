extends SceneTree
const H = preload("res://tests/helpers.gd")
const Session = preload("res://scripts/session.gd")
const CASES := ["suppress_amulet","late_suppress_amulet","late_suppress_amulet","suppress_amulet","blade_friendly","blade_self","gift_overflow","gift"]
const BASE := 182000
var session
var role := "host"
var prepared := false
var done := false
var results: Array = []
var seen := {}
var stamp := ""
var started := 0
var privacy_ok := true
var errors: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	_run.call_deferred()

func _run() -> void:
	session = Session.new(); session.name = "Session"; root.add_child(session)
	session.changed.connect(_changed)
	session.problem.connect(func(message): errors.append(message); push_error(message))
	started = Time.get_ticks_msec()
	if role == "host": session.host_room("新卡房主",25182)
	else: session.join_room("新卡访客","127.0.0.1",25182)

func _setup(index: int) -> void:
	var key: String = CASES[index]
	var actor := (index%2)*3
	var enemy := 3-actor
	var g = H.fixture(8); g.match_id = BASE+index
	g.presentation_enabled = true; g.resolution_presentation_enabled = true
	if key in ["cards_to_heart","frenzy"]: g.characters[actor].hp = 3
	if key in ["gift","cards_to_heart","cards_to_blades","gift_overflow","blade_cancel"]:
		H.give(g,actor,"heal"); H.give(g,actor,"defense")
	if key == "frenzy": H.give(g,actor,"warcry"); H.give(g,actor,"heal")
	if key == "gift_overflow":
		for _i in range(7): H.give(g,enemy,"strike")
	var actual := "gift" if key == "gift_overflow" else "cards_to_blades" if key == "blade_cancel" else key
	if key in ["suppress_amulet","late_suppress_amulet"]:
		actual = key.trim_suffix("_amulet")
		H.give(g,actor+1,"strike")
	if key in ["blade_friendly","blade_self"]:
		actual = "cards_to_blades"
		H.give(g,actor,"heal");H.give(g,actor,"defense")
	var chosen := {actor:H.give(g,actor,actual)}
	if key in ["suppress_amulet","late_suppress_amulet"]:
		chosen[actor+1] = H.give(g,actor+1,"frenzy")
		chosen[enemy] = H.give(g,enemy,"attack_amulet")
	if key in ["anticipation","suppress","late_suppress"]: chosen[enemy] = H.give(g,enemy,"badge")
	if key == "blade_cancel": chosen[enemy] = H.give(g,enemy,"magic_amulet")
	H.begin(g,chosen,false)
	session.game = g; session._broadcast()

func _changed() -> void:
	var s: Dictionary = session.state
	if s.is_empty() or done: return
	if role == "host" and not prepared:
		prepared = true; _setup.call_deferred(0); return
	if s.match < BASE: return
	if not s.input.is_empty() and s.input.type in ["gift","hand_limit"] and s.input.team != session.team:
		privacy_ok = privacy_ok and s.input.options.is_empty()
	for c in s.characters:
		if c.team != session.team: privacy_ok = privacy_ok and c.hand.is_empty()
	if s.phase != "review" or seen.has(s.match): return
	seen[s.match] = true
	var index: int = s.match-BASE
	var key: String = CASES[index]
	var actor := (index%2)*3
	var enemy := 3-actor
	var ok := true
	match key:
		"suppress_amulet","late_suppress_amulet":
			var guard: Dictionary = s.queue.filter(func(a):return a.actor == enemy)[0]
			ok = guard.revealed and s.characters[enemy].hp == 8 and s.queue.any(func(a):return a.actor == actor+1 and a.status == "blocked")
		"blade_friendly": ok = s.characters[actor+1].hp == 6 and s.characters[enemy].hp == 8
		"blade_self": ok = s.characters[actor].hp == 6 and s.characters[enemy].hp == 8
		"warcry": ok = s.characters[actor].warcry_bonus == 3
		"anticipation": ok = s.reveal_locked_teams[1-actor/3] and s.badges[1-actor/3] == 0
		"gift": ok = s.characters[actor].hand_count == 0 and s.characters[enemy].hand_count == 2
		"gift_overflow": ok = s.characters[actor].hand_count == 0 and s.characters[enemy].hand_count == 8
		"cards_to_heart": ok = s.characters[actor].hp == 5 and s.characters[actor].hand_count == 0
		"cards_to_blades": ok = s.characters[enemy].hp == 6
		"suppress","late_suppress": ok = s.queue.filter(func(a): return a.actor == enemy)[0].status == "suppressed" and s.badges[1-actor/3] == 0
		"frenzy": ok = s.queue.size() == 3 and s.characters[actor].hp == 5 and s.characters[actor].warcry_bonus == 3
		"blade_cancel": ok = s.characters[enemy].hp == 8 and s.characters[actor].hand_count == 0
	results.append({"key":key,"ok":ok,"hp":s.characters.map(func(c): return c.hp),"hands":s.characters.map(func(c): return c.hand_count),"badges":s.badges,"discard":s.discard_count})
	if index == CASES.size()-1: done = true; _finish.call_deferred()
	elif role == "host": _next.call_deferred(index+1)

func _next(index: int) -> void:
	await create_timer(.55).timeout
	_setup(index)

func _process(_delta: float) -> bool:
	if started and Time.get_ticks_msec()-started > 65000: push_error("NETWORK_V0182_TIMEOUT"); quit(2)
	if session == null or done or session.state.is_empty(): return false
	var s: Dictionary = session.state
	if s.match < BASE or s.input.is_empty() or s.input.team != session.team: return false
	var next_stamp := "%d/%d" % [s.match,s.revision]
	if next_stamp == stamp: return false
	stamp = next_stamp
	var actor: int = ((s.match-BASE)%2)*3
	match s.phase:
		"targeting":
			var key: String = CASES[s.match-BASE]
			session.act("target",[actor+1 if key == "blade_friendly" else actor if key == "blade_self" else 3-actor])
		"choosing": session.act("choose",[H.auto_input(s)])
		"selecting": session.act("pick",H.auto_pick(s))
		"responding": session.act("respond",[s.input.options[0]])
		"reacting": session.act("defend",[0])
	return false

func _finish() -> void:
	await create_timer(.2).timeout
	var ok: bool = results.size() == CASES.size() and results.all(func(r): return r.ok) and privacy_ok and errors.is_empty()
	var file := FileAccess.open("res://test-results/network-v0182-"+role+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":ok,"privacy_ok":privacy_ok,"results":results,"errors":errors})); file.close()
	print("NETWORK_V0182_RESULT role=%s cases=%d ok=%s" % [role,results.size(),ok])
	if role == "host": await create_timer(1.5).timeout
	session.leave(); quit(0 if ok else 1)
