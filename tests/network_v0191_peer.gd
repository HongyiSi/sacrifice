extends SceneTree
const H = preload("res://tests/helpers.gd")
const Session = preload("res://scripts/session.gd")
const CASES := ["collect_full","collect_one_slot","bloodletting_full","gold_panning_full","round_draw_full","divinity_full","divinity_partial"]
const BASE := 191000
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
var observed_returns := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	_run.call_deferred()

func _run() -> void:
	session = Session.new();root.add_child(session)
	session.changed.connect(_changed)
	session.problem.connect(func(message): errors.append(message);push_error(message))
	started = Time.get_ticks_msec()
	if role == "host": session.host_room("新卡房主",25191)
	else: session.join_room("新卡访客","127.0.0.1",25191)

func _setup(index: int) -> void:
	var key: String = CASES[index]
	var actor := (index%2)*3
	var enemy := 3-actor
	var g = H.fixture(8);g.match_id = BASE+index
	g._draw(g.characters[actor],7 if key in ["collect_one_slot","divinity_partial"] else 8)
	if key.begins_with("divinity"):
		H.give_death(g,enemy+1,"divinity");g.characters[enemy+1].hp=0
		g._activate({"actor":enemy+1,"card":102},enemy+1)
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	if key=="round_draw_full":g._begin_round()
	else:
		var name: String="bloodletting" if key=="bloodletting_full" else "gold_panning" if key=="gold_panning_full" else "collect"
		H.begin(g,{actor:H.give(g,actor,name)},false)
	session.game=g;session._broadcast()

func _changed() -> void:
	var s: Dictionary = session.state
	if s.is_empty() or done: return
	if role == "host" and not prepared:
		prepared = true;_setup.call_deferred(0);return
	if s.match < BASE: return
	if not s.input.is_empty() and s.input.type in ["deck","hand_limit"] and s.input.team != session.team:
		privacy_ok = privacy_ok and s.input.options.is_empty()
	for c in s.characters:
		if c.team != session.team: privacy_ok = privacy_ok and c.hand.is_empty()
	if s.animation.get("kind","")=="draw_cards":
		for draw in s.animation.draws:
			if draw.returned.has(true):observed_returns[s.match]=true
			if draw.has("ids"):
				for i in range(draw.count):
					if draw.returned[i]:privacy_ok=privacy_ok and draw.ids[i]==0
	if s.phase != ("planning" if CASES[s.match-BASE]=="round_draw_full" else "review") or seen.has(s.match): return
	seen[s.match] = true
	var index: int = s.match-BASE
	var key: String = CASES[index]
	var actor := (index%2)*3
	var enemy := 3-actor
	var ok: bool=s.characters[actor].hand_count==8 and observed_returns.has(s.match) and s.input.is_empty()
	if key=="bloodletting_full":ok=ok and s.characters[actor].hp==7
	if key=="round_draw_full":ok=ok and s.round==2 and s.deck_count==112
	else:ok=ok and s.discard_count==1
	results.append({"key":key,"ok":ok,"hp":s.characters.map(func(c):return c.hp),"hands":s.characters.map(func(c):return c.hand_count),"discard":s.discard_count})
	if index == CASES.size()-1: done = true;_finish.call_deferred()
	elif role == "host": _next.call_deferred(index+1)

func _next(index: int) -> void:
	await create_timer(.6).timeout
	_setup(index)

func _process(_delta: float) -> bool:
	if started and Time.get_ticks_msec()-started > 160000: push_error("NETWORK_V0191_TIMEOUT");quit(2)
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
	var file := FileAccess.open("res://test-results/network-v0191-"+role+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":ok,"privacy_ok":privacy_ok,"results":results,"errors":errors}));file.close()
	print("NETWORK_V0191_RESULT role=%s cases=%d ok=%s" % [role,results.size(),ok])
	if role == "host": await create_timer(1.5).timeout
	session.leave();quit(0 if ok else 1)
