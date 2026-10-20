extends SceneTree
const H = preload("res://tests/helpers.gd")
var main
var role := "host"
var port := 25179
var prepared := false
var done := false
var seen := {}
var cues: Array = []
var started := 0
var request_key := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await process_frame
	main.attack_audio.cue_played.connect(func(file,offset): cues.append({"file":file.get_file(),"offset":offset}))
	main.session.changed.connect(_changed)
	main.session.problem.connect(func(message): push_error(message); quit(2))
	started = Time.get_ticks_msec()
	if role == "host": main.session.host_room("音效房主",port)
	else: main.session.join_room("音效访客","127.0.0.1",port)

func _setup(index: int) -> void:
	var g = H.fixture(8)
	g.match_id = 17900+index
	g.presentation_enabled = true; g.resolution_presentation_enabled = true
	var key := "hasty_spell" if index == 0 else "bounty"
	if index == 1: g.characters[3].hp = 1
	H.begin(g,{0:H.give(g,0,key)},false)
	main.session.game = g; main.session._broadcast()

func _changed() -> void:
	var s: Dictionary = main.session.state
	if s.is_empty() or done: return
	if role == "host" and not prepared:
		prepared = true; _setup.call_deferred(0); return
	if s.match < 17900: return
	if s.phase == "review" and not seen.has(s.match):
		seen[s.match] = true
		if s.match == 17901:
			done = true; _finish.call_deferred()
		elif role == "host": _next.call_deferred()

func _next() -> void:
	await create_timer(.5).timeout
	_setup(1)

func _process(_delta: float) -> bool:
	if started and Time.get_ticks_msec()-started > 45000: push_error("network sound timeout"); quit(2)
	if main == null or done or main.session.state.is_empty(): return false
	var s: Dictionary = main.session.state
	if s.match < 17900 or s.input.is_empty() or s.input.team != main.session.team: return false
	var key := "%d/%d" % [s.match,s.revision]
	if key == request_key: return false
	request_key = key
	if s.phase == "targeting": main.session.act("target",[3])
	return false

func _finish() -> void:
	await create_timer(.25).timeout
	var counts := {}
	for cue in cues: counts[cue.file] = int(counts.get(cue.file,0))+1
	var ok := true
	for file in ["hasty_spell_travel.ogg","hasty_spell_impact.ogg","bounty_travel.ogg","bounty_impact.ogg"]:
		ok = ok and counts.get(file,0) == 1
	ok = ok and counts.get("bounty_depart.ogg",0) == 2 and counts.get("bounty_arrive.ogg",0) == 2
	var f := FileAccess.open("res://test-results/network-v0179-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"counts":counts,"ok":ok,"cues":cues})); f.close()
	print("NETWORK_V0179_RESULT role=%s ok=%s" % [role,ok])
	if role == "host": await create_timer(2).timeout
	main.session.leave()
	quit(0 if ok else 1)
