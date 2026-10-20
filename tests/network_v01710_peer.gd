extends SceneTree
const H = preload("res://tests/helpers.gd")
var main
var role := "host"
var port := 25180
var prepared := false
var done := false
var seen := {}
var cues: Array = []
var results: Array = []
var started := 0
var request_key := ""
const BASE := 171010

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await process_frame
	main.attack_audio.cue_played.connect(func(file,offset):
		var e: Dictionary = main.session.state.get("animation",{})
		cues.append({"file":file.get_file(),"offset":offset,"kind":e.get("kind",""),"stage":e.get("stage",""),"match":main.session.state.get("match",0)}))
	main.session.changed.connect(_changed)
	main.session.problem.connect(func(message): push_error(message); quit(2))
	started = Time.get_ticks_msec()
	if role == "host": main.session.host_room("回复音效房主",port)
	else: main.session.join_room("回复音效访客","127.0.0.1",port)

func _setup(index: int) -> void:
	var g = H.fixture(4); g.match_id = BASE+index
	g.presentation_enabled = true; g.resolution_presentation_enabled = true
	var key: String = ["heal","team_heal","heal_other","defense"][index]
	var actor := 3 if index == 2 else 0
	var choices := {actor:H.give(g,actor,key)}
	if index == 3: choices[3] = H.give(g,3,"strike")
	H.begin(g,choices,false)
	main.session.game = g; main.session._broadcast()

func _changed() -> void:
	var s: Dictionary = main.session.state
	if s.is_empty() or done: return
	if role == "host" and not prepared:
		prepared = true; _setup.call_deferred(0); return
	if s.match < BASE: return
	if s.phase == "review" and not seen.has(s.match):
		seen[s.match] = true
		var index: int = s.match-BASE
		var hp: Array = s.characters.map(func(c): return c.hp)
		var expected: Array = [[6,4,4,4,4,4],[5,5,5,4,4,4],[7,4,4,4,4,4],[4,4,4,4,4,4]][index]
		results.append({"index":index,"hp":hp,"ok":hp == expected})
		if index == 3: done = true; _finish.call_deferred()
		elif role == "host": _next.call_deferred(index+1)

func _next(index: int) -> void:
	await create_timer(.5).timeout
	_setup(index)

func _process(_delta: float) -> bool:
	if started and Time.get_ticks_msec()-started > 45000: push_error("network support audio timeout"); quit(2)
	if main == null or done or main.session.state.is_empty(): return false
	var s: Dictionary = main.session.state
	if s.match < BASE or s.input.is_empty() or s.input.team != main.session.team: return false
	var key := "%d/%d" % [s.match,s.revision]
	if key == request_key: return false
	request_key = key
	if s.phase == "targeting": main.session.act("target",[0 if s.match == BASE+2 else 1])
	elif s.phase == "reacting": main.session.act("defend",[1])
	return false

func _finish() -> void:
	await create_timer(.25).timeout
	var counts := {}
	for cue in cues: counts[cue.file] = int(counts.get(cue.file,0))+1
	var ok: bool = results.size() == 4 and results.all(func(r): return r.ok)
	for file in ["heal_rise.ogg","heal_flight.ogg","heal_E_arrival.ogg"]: ok = ok and counts.get(file,0) == 3
	for file in ["defense_rise.ogg","defense_flight.ogg","defense_apply.ogg","defense_block.ogg"]: ok = ok and counts.get(file,0) == 1
	ok = ok and cues.filter(func(c): return c.file == "heal_E_arrival.ogg").all(func(c): return c.kind == "heal" and c.stage == "impact")
	var f := FileAccess.open("res://test-results/network-v01710-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"counts":counts,"ok":ok,"cues":cues,"scenarios":results})); f.close()
	print("NETWORK_V01710_RESULT role=%s ok=%s" % [role,ok])
	if role == "host": await create_timer(2).timeout
	main.session.leave(); quit(0 if ok else 1)
