extends SceneTree
const Session = preload("res://scripts/session.gd")
var session
var role := "host"
var port := 24994
var stage := 0
var started := 0
var deadline := 0
var saw_locked := false
var saw_unlocked := false
var completed := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port=int(arg.trim_prefix("--port="))
	session=Session.new(); session.name="Session"
	root.add_child.call_deferred(session)
	_begin.call_deferred()

func _begin() -> void:
	started=Time.get_ticks_msec()
	session.problem.connect(func(message): push_error(message); quit(2))
	session.changed.connect(_changed)
	if role == "host": session.host_room("新版房主",port)
	else: session.join_room("新版访客","127.0.0.1",port)

func _changed() -> void:
	var s: Dictionary=session.state
	if s.is_empty(): return
	for c in s.characters:
		if c.team != session.team and not c.hand.is_empty(): push_error("PRIVATE_HAND_LEAK"); quit(3)
	if role == "client" and s.round == 1 and s.phase == "planning":
		if s.ready[0]: saw_locked=true
		elif saw_locked: saw_unlocked=true
	if s.round == 2 and not completed:
		completed=true
		if role == "client" and not saw_unlocked: push_error("UNLOCK_NOT_BROADCAST"); quit(4); return
		if not s.characters.all(func(c): return c.hp == 8): push_error("BAD_INITIAL_HP"); quit(5); return
		print("NETWORK_V08_RESULT role=%s round=%d automatic=true unlock_seen=%s" % [role,s.round,saw_unlocked if role == "client" else true])
		_finish.call_deferred()

func _finish() -> void:
	await create_timer(0.2).timeout
	quit(0)

func _process(_delta: float) -> bool:
	if started > 0 and Time.get_ticks_msec()-started > 12000: push_error("NETWORK_V08_TIMEOUT"); quit(6)
	if completed or session == null or session.state.is_empty(): return false
	var s: Dictionary=session.state
	if s.round != 1 or s.phase != "planning": return false
	if role == "host":
		if stage == 0:
			stage=1; deadline=Time.get_ticks_msec()+200
			session.act("plan",[0,0,0])
		elif stage == 1 and Time.get_ticks_msec() >= deadline:
			stage=2; deadline=Time.get_ticks_msec()+200
			session.act("unlock")
		elif stage == 2 and Time.get_ticks_msec() >= deadline:
			stage=3
			session.act("plan",[0,0,0])
	elif saw_unlocked and s.ready[0] and stage == 0:
		stage=1
		session.act("plan",[0,0,0])
	return false
