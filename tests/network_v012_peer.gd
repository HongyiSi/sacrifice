extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
const CASES := ["defense","remove_source","dead_target","dead_dance","immortal","conditional"]
var session
var role := "host"
var port := 24998
var prepared := false
var completed := false
var started := 0
var last_request := ""
var seen := {}
var reviews := {}
var observed := {}
var trace: Array = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
	session = Session.new(); session.name = "Session"
	root.add_child.call_deferred(session); _begin.call_deferred()
func fail(message: String) -> void:
	push_error("V012_NETWORK_FAIL "+message); quit(2)
func _begin() -> void:
	started = Time.get_ticks_msec()
	session.problem.connect(fail); session.changed.connect(_changed)
	if role == "host": session.host_room("状态房主",port)
	else: session.join_room("状态访客","127.0.0.1",port)
func has(s: Dictionary, id: int, key: String) -> bool:
	return s.characters[id].ongoing_effects.any(func(e): return e.key == key)
func _changed() -> void:
	var s: Dictionary = session.state
	if s.is_empty() or completed: return
	if role == "host" and not prepared:
		prepared = true; _setup.call_deferred(0); return
	if s.match < 3000: return
	var stamp := "%d/%d" % [s.match,s.revision]
	if not seen.has(stamp):
		seen[stamp] = true
		trace.append({"match":s.match,"revision":s.revision,"phase":s.phase,"statuses":s.characters.map(func(c): return c.ongoing_effects),"hp":s.characters.map(func(c): return c.hp)})
	var key: String = CASES[int(s.match) - 3000]
	if key == "defense" and s.phase == "targeting" and s.active_card.key == "double_strike":
		if not has(s,0,"defense"): fail("declined defense lost its loop"); return
		observed.held = true
	if key == "remove_source" and has(s,3,"blessing") and has(s,4,"prison"): observed.bound = true
	if key == "conditional" and has(s,1,"eye"):
		var effect: Dictionary = s.characters[1].ongoing_effects.filter(func(e): return e.key == "eye")[0]
		if effect.dormant: observed.dormant = true
		else: observed.awake = true
	if key in ["dead_target","dead_dance"] and s.phase in ["targeting","death_targeting"]:
		if not s.input.options.has(3): fail("corpse not selectable"); return
		if s.input.description.contains("苦肉"): fail("old targeting instruction"); return
	if s.phase == "review" and not reviews.has(s.match):
		reviews[s.match] = true
		if key == "defense" and has(s,0,"defense"): fail("consumed shield still visible"); return
		if key == "remove_source" and (has(s,3,"blessing") or has(s,4,"prison")): fail("lost sources still visible"); return
		if key == "immortal" and not has(s,0,"immortal"): fail("triggered immortal lost overlay"); return
		if key in ["dead_target","dead_dance"] and s.characters[3].hp != 0: fail("corpse damage revived victim"); return
		if reviews.size() == CASES.size():
			for feature in ["held","bound","dormant","awake"]:
				if not observed.has(feature): fail("missing lifecycle: "+feature); return
			completed = true
			var file = FileAccess.open("res://test-results/network-v012-"+role+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify(trace)); file.close()
			print("NETWORK_V012_RESULT role=%s scenarios=%d snapshots=%d lifecycle=true dead_targets=true" % [role,reviews.size(),trace.size()])
			_finish.call_deferred()
		elif role == "host": _next.call_deferred(int(s.match) - 3000 + 1)
func activate(g, owner: int, key: String, target: int) -> void:
	var card: int = H.give_death(g,owner,key)
	g._activate({"actor":owner,"card":card},target); g.death_revealed.append(card)
func _setup(index: int) -> void:
	var g = H.fixture(8); g.presentation_enabled = true
	match CASES[index]:
		"defense": H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike"),4:H.give(g,4,"double_strike")})
		"remove_source":
			activate(g,1,"blessing",3); activate(g,1,"prison",4)
			H.give_death(g,0,"mediocrity"); g.characters[0].hp = 0; g.characters[0].death_round = g.round_number
			H.begin(g,{})
		"dead_target":
			g.characters[3].hp = 0; H.begin(g,{0:H.give(g,0,"hasty_spell")})
		"dead_dance":
			g.characters[0].hp = 0; g.characters[0].death_round = g.round_number; g.characters[3].hp = 0
			H.give_death(g,0,"last_dance"); H.begin(g,{})
		"immortal":
			H.give_death(g,0,"immortal"); g.characters[0].hp = 1
			H.begin(g,{3:H.give(g,3,"strike")})
		"conditional":
			activate(g,1,"eye",1); g.characters[1].hp = 1
			H.begin(g,{3:H.give(g,3,"strike")})
	g.match_id = 3000+index; session.game = g; session._broadcast()
func _next(index: int) -> void:
	await create_timer(0.12).timeout; _setup(index)
func _finish() -> void:
	await create_timer(0.4).timeout; quit(0)
func _process(_delta: float) -> bool:
	if started > 0 and Time.get_ticks_msec()-started > 65000: fail("timeout")
	if completed or session == null or session.state.is_empty(): return false
	var s: Dictionary = session.state
	var stamp := "%d/%d" % [s.match,s.revision]
	if s.match < 3000 or stamp == last_request: return false
	last_request = stamp
	if s.input.is_empty() or s.input.team != session.team: return false
	var key: String = CASES[int(s.match) - 3000]
	if s.phase in ["targeting","death_targeting"]:
		var target := 0
		if key in ["remove_source","conditional"]: target = 1
		if key in ["dead_target","dead_dance"]: target = 3
		session.act("target",[target])
	elif s.phase == "reacting": session.act("defend",[1 if s.active_card.key == "double_strike" else 0])
	return false
