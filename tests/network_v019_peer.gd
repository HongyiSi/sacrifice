extends SceneTree
const H = preload("res://tests/helpers.gd")
const Session = preload("res://scripts/session.gd")
const CASES := ["bloodletting","gold_panning","search","sapphire","ruby","amethyst","rally","defile","obstruct","final_strike","sapphire_tick","ruby_tick","amethyst_tick"]
const BASE := 190000
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
	session = Session.new();root.add_child(session)
	session.changed.connect(_changed)
	session.problem.connect(func(message): errors.append(message);push_error(message))
	started = Time.get_ticks_msec()
	if role == "host": session.host_room("新卡房主",25190)
	else: session.join_room("新卡访客","127.0.0.1",25190)

func _setup(index: int) -> void:
	var key: String = CASES[index]
	var actor := (index%2)*3
	var enemy := 3-actor
	var g = H.fixture(8);g.match_id = BASE+index
	var chosen := {}
	if key == "defile": H.give(g,enemy,"strike");H.give(g,enemy,"heal")
	if key == "obstruct":
		for _i in range(8): H.give(g,enemy,"strike")
	if key.ends_with("_tick"):
		H.give(g,actor,key.trim_suffix("_tick"))
		if key == "sapphire_tick": g._begin_round()
		elif key == "ruby_tick": g.characters[actor].hp = 3
		else: g.characters[actor].hp = 0
	else:
		chosen[actor] = H.give(g,actor,key)
		if key == "gold_panning":
			for name in ["strike","defense","badge","magic_strike","frenzy"]:
				var id: int = H.give(g,actor,name)
				g.characters[actor].hand.erase(id);g.deck.append(id)
	g.presentation_enabled = true;g.resolution_presentation_enabled = true
	H.begin(g,chosen,false)
	session.game = g;session._broadcast()

func _changed() -> void:
	var s: Dictionary = session.state
	if s.is_empty() or done: return
	if role == "host" and not prepared:
		prepared = true;_setup.call_deferred(0);return
	if s.match < BASE: return
	if not s.input.is_empty() and s.input.type in ["defile","search","hand_limit"] and s.input.team != session.team:
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
		"bloodletting": ok = s.characters[actor].hp == 7 and s.characters[actor].hand_count == 5
		"gold_panning": ok = s.characters[actor].hand_count == 3 and s.discard_count == 3
		"search": ok = s.characters[actor].hand_count == 1
		"sapphire","ruby","amethyst": ok = s.characters[enemy].hand_count == 1 and s.discard_count == 0
		"rally": ok = s.characters[actor].get("rally_count",0) == 1 and s.characters[actor+2].get("rally_count",0) == 1
		"defile":
			ok = s.characters[enemy].hand_count == 2
			if session.team == enemy/3: ok = ok and s.characters[enemy].hand.any(func(id):return s.catalog[id].get("defiled",false))
		"obstruct": ok = s.characters[enemy].hand_count == 8 and s.discard_count == 3
		"final_strike": ok = s.characters[enemy].hp == 4
		"sapphire_tick": ok = s.characters[actor].hand_count == 3
		"ruby_tick": ok = s.characters[actor].hp == 4
		"amethyst_tick": ok = s.characters[actor].hp == 1 and s.characters[actor].hand_count == 0 and s.discard_count == 1
	results.append({"key":key,"ok":ok,"hp":s.characters.map(func(c):return c.hp),"hands":s.characters.map(func(c):return c.hand_count),"discard":s.discard_count})
	if index == CASES.size()-1: done = true;_finish.call_deferred()
	elif role == "host": _next.call_deferred(index+1)

func _next(index: int) -> void:
	await create_timer(.6).timeout
	_setup(index)

func _process(_delta: float) -> bool:
	if started and Time.get_ticks_msec()-started > 160000: push_error("NETWORK_V019_TIMEOUT");quit(2)
	if session == null or done or session.state.is_empty(): return false
	var s: Dictionary = session.state
	if s.match < BASE or s.input.is_empty() or s.input.team != session.team: return false
	var next_stamp := "%d/%d" % [s.match,s.revision]
	if next_stamp == stamp: return false
	stamp = next_stamp
	var actor: int = ((s.match-BASE)%2)*3
	match s.phase:
		"targeting": session.act("target",[3-actor])
		"selecting": session.act("pick",H.auto_pick(s))
		"responding": session.act("respond",[0])
		"reacting": session.act("defend",[0])
	return false

func _finish() -> void:
	await create_timer(.2).timeout
	var ok: bool = results.size() == CASES.size() and results.all(func(r):return r.ok) and privacy_ok and errors.is_empty()
	var file := FileAccess.open("res://test-results/network-v019-"+role+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":ok,"privacy_ok":privacy_ok,"results":results,"errors":errors}));file.close()
	print("NETWORK_V019_RESULT role=%s cases=%d ok=%s" % [role,results.size(),ok])
	if role == "host": await create_timer(1.5).timeout
	session.leave();quit(0 if ok else 1)
