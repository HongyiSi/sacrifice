extends SceneTree
const H = preload("res://tests/helpers.gd")
const Session = preload("res://scripts/session.gd")
const CASES := ["plunder","poisoning","holy_amulet","attack_amulet","magic_amulet","plunder","poisoning","holy_amulet","attack_amulet","magic_amulet","poison","prison"]
const BASE := 200000
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
	if role == "host": session.host_room("新卡房主",25200)
	else: session.join_room("新卡访客","127.0.0.1",25200)

func _setup(index: int) -> void:
	var key: String = CASES[index]
	var actor := (index%2)*3
	var enemy := 3-actor
	var g = H.fixture(8);g.match_id = BASE+index
	var card := 0
	match key:
		"plunder":
			H.give(g,enemy,"strike");H.give(g,enemy,"heal")
			card=H.give(g,actor,key)
		"poisoning": card=H.give(g,actor,key)
		"poison":
			card=g._generate_card(g.POISON);g.characters[actor].hand.append(card)
		"prison":
			H.give_death(g,enemy,"prison");g._activate({"actor":enemy,"card":112},actor)
			g.characters[actor].hand.append(g._generate_card(g.BOULDER))
			g.death_deck.erase(104);g.characters[actor].hand.append(104)
			card=H.give(g,actor,"collect")
		_:
			H.give(g,enemy,key)
			card=H.give(g,actor,"magic_strike" if key=="magic_amulet" else "area_strike" if key=="attack_amulet" else "strike")
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	H.begin(g,{actor:card},false)
	session.game=g;session._broadcast()

func _changed() -> void:
	var s: Dictionary = session.state
	if s.is_empty() or done: return
	if role == "host" and not prepared:
		prepared = true;_setup.call_deferred(0);return
	if s.match < BASE: return
	if not s.input.is_empty() and s.input.type in ["plunder","amulet","hand_limit"] and s.input.team != session.team:
		privacy_ok = privacy_ok and s.input.options.is_empty()
	for c in s.characters:
		if c.team != session.team: privacy_ok = privacy_ok and c.hand.is_empty()
	if s.phase != "review" or seen.has(s.match): return
	seen[s.match] = true
	var index: int = s.match-BASE
	var key: String = CASES[index]
	var actor := (index%2)*3
	var enemy := 3-actor
	var ok: bool=s.input.is_empty()
	match key:
		"plunder":
			ok=ok and s.characters[actor].hand_count==1 and s.characters[enemy].hand_count==1
			if s.characters[actor].team==session.team:ok=ok and s.catalog[s.characters[actor].hand[0]].key=="heal"
			if s.characters[enemy].team==session.team:ok=ok and s.catalog[s.characters[enemy].hand[0]].key=="strike"
		"poisoning":
			ok=ok and s.characters[enemy].hand_count==1
			if s.characters[enemy].team==session.team:ok=ok and s.catalog[s.characters[enemy].hand[0]].key=="poison"
		"poison":ok=ok and s.characters[actor].hand_count==0 and s.characters[actor].hp==7
		"prison":ok=ok and s.characters[actor].hand_count==5
		_:ok=ok and s.characters.all(func(c):return c.hp==8) and s.characters[enemy].hand_count==0 and s.discard_count==2
	results.append({"key":key,"ok":ok,"hp":s.characters.map(func(c):return c.hp),"hands":s.characters.map(func(c):return c.hand_count),"discard":s.discard_count})
	if index == CASES.size()-1: done = true;_finish.call_deferred()
	elif role == "host": _next.call_deferred(index+1)

func _next(index: int) -> void:
	await create_timer(.6).timeout
	_setup(index)

func _process(_delta: float) -> bool:
	if started and Time.get_ticks_msec()-started > 160000: push_error("NETWORK_V020_TIMEOUT");quit(2)
	if session == null or done or session.state.is_empty(): return false
	var s: Dictionary = session.state
	if s.match < BASE or s.input.is_empty() or s.input.team != session.team: return false
	var next_stamp := "%d/%d" % [s.match,s.revision]
	if next_stamp == stamp: return false
	stamp = next_stamp
	var actor: int = ((s.match-BASE)%2)*3
	match s.phase:
		"targeting": session.act("target",[3-actor])
		"selecting":
			var selected:Array=H.auto_pick(s)
			if s.input.type=="plunder":selected=s.input.options.filter(func(id):return s.catalog[id].key=="heal").slice(0,1)
			session.act("pick",selected)
		"responding": session.act("respond",[s.input.options[0]])
		"reacting": session.act("defend",[0])
	return false

func _finish() -> void:
	await create_timer(.2).timeout
	var ok: bool = results.size() == CASES.size() and results.all(func(r):return r.ok) and privacy_ok and errors.is_empty()
	var file := FileAccess.open("res://test-results/network-v020-"+role+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":ok,"privacy_ok":privacy_ok,"results":results,"errors":errors}));file.close()
	print("NETWORK_V020_RESULT role=%s cases=%d ok=%s" % [role,results.size(),ok])
	if role == "host": await create_timer(1.5).timeout
	session.leave();quit(0 if ok else 1)
