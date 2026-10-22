extends Node
## LAN hosts and online clients share rules and individually redacted snapshots.

signal changed
signal problem(message: String)

const Rules = preload("res://scripts/rules.gd")
const PROTOCOL := "sacrifice-0.20.70"
const Online = preload("res://scripts/online.gd")
const Actions = preload("res://scripts/match_actions.gd")
const LocalAI = preload("res://scripts/local_ai.gd")
const LearningAI = preload("res://scripts/learning_ai.gd")
const Checkpoint = preload("res://scripts/ai_checkpoint.gd")
const Tutorial = preload("res://scripts/tutorial.gd")
var tutorial: RefCounted
var ai_checkpoint = Checkpoint.new()
var ai_learned := false
var ai_local_plan: Dictionary = {}
var ai_save_warning := false
var ai_mode := false
var ai_opponent: RefCounted
var ai_next_action := 0
var ai_failed_revision := -1
var ai_thinking_view: Dictionary = {}
var online: Node
var online_mode := false
var dedicated := false
var room_code := ""
var peer_missing := false
var reconnecting := false
var reconnect_attempt := 0
var reconnect_at := 0
var reconnect_deadline := 0
var online_address := ""
const RECONNECT_WINDOW_MS := 120000
var game = null
var state: Dictionary = {}
var team := -1
var opponent_peer := 0
var active := false
var hosting := false
var joining := false
var status := ""
var player_name := ""
var names: Array = ["玩家一", "玩家二"]
var port := 24771
var connection_started := 0
var review_game = null
var review_round := -1
var review_started := 0
var animation_key := ""
var animation_started := 0
var received_views: Array = []
const MAX_RECEIVED_VIEWS := 24
var received_animation_key := ""
var received_animation_started := 0

func _ready() -> void:
	online = Online.new(); online.name = "Online"; add_child(online)
	online.updated.connect(_online_view)
	online.failed.connect(_online_failed)
	online.refused.connect(_online_refused)
	online.rejected.connect(func(message): problem.emit(message))
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_server_left)
	multiplayer.peer_disconnected.connect(_peer_left)

func _process(_delta: float) -> void:
	if ai_mode and active and ai_checkpoint.enabled and Time.get_unix_time_from_system()-ai_checkpoint.last_attempt >= 15:
		# Background tabs must not keep an abandoned match alive indefinitely.
		if not OS.has_feature("web") or JavaScriptBridge.eval("!document.hidden",true) == true:
			ai_checkpoint.touch()
	if reconnecting:
		_process_reconnect(Time.get_ticks_msec())
		return
	_drain_received_views()
	if online_mode or dedicated: return
	if joining and Time.get_ticks_msec() - connection_started > 10000:
		_failed()
	if tutorial != null and tutorial.holds_animation(): return
	if hosting and active and game != null and not game.animation.is_empty():
		var key := "%d/%d/%s" % [game.match_id,game.animation.id,game.animation.stage]
		if animation_key != key:
			animation_key = key
			animation_started = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - animation_started >= Rules.StrikeStyles.duration(game.animation):
			game.advance_animation()
			_broadcast()
	else: animation_key = ""
	if tutorial == null and hosting and active and game != null and game.phase == "review":
		if review_game != game or review_round != game.round_number:
			review_game = game
			review_round = game.round_number
			review_started = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - review_started >= 1000:
			game.advance_round()
			_broadcast()
	else:
		review_game = null
		review_round = -1
	if tutorial != null:
		if tutorial.tick(game,Time.get_ticks_msec()): _broadcast()
	else: _process_ai()

func start_tutorial(nickname: String = "") -> void:
	leave(false)
	tutorial = Tutorial.new()
	game = tutorial.create_game()
	hosting = true; active = true; team = 0
	player_name = _clean_name(nickname,"玩家")
	names = [player_name,"练习对手"]
	status = "新手教程"
	_broadcast()

func tutorial_next() -> void:
	if tutorial == null or game == null: return
	tutorial.next(game)
	animation_key = ""
	_broadcast()

func start_ai(nickname: String, seed_value: int = 0, learned: bool = false) -> void:
	leave()
	ai_mode = true
	ai_learned = learned
	ai_next_action = Time.get_ticks_msec()+450
	hosting = true; active = true; team = 0
	player_name = _clean_name(nickname,"玩家")
	names = [player_name,"自学习 AI" if learned else "本地 AI"]
	game = Rules.new()
	game.presentation_enabled = true
	game.start(seed_value)
	ai_opponent = LearningAI.new(game.rng.seed) if learned else LocalAI.new(game.rng.seed)
	game._note("%s 对战 · 随机种子 %d" % [names[1],game.rng.seed])
	status = names[1]+" 对战"
	_broadcast()

func save_ai_checkpoint() -> void:
	if not ai_mode or not active or game == null or ai_opponent == null: return
	var details := {"name":player_name,"names":names,"learned":ai_learned,
		"ai_seed":ai_opponent.rng.seed,"ai_state":ai_opponent.rng.state,
		"plan":ai_local_plan,"thinking_view":ai_thinking_view}
	if ai_learned: details.weights = ai_opponent.weights
	if not ai_checkpoint.write(game,details) and not ai_save_warning:
		ai_save_warning = true
		problem.emit("无法保存对局进度：请检查浏览器是否允许保存网站数据。")

func remember_ai_plan(choices: Array) -> void:
	if not ai_mode or game == null: return
	ai_local_plan = {"match":game.match_id,"round":game.round_number,"choices":choices.duplicate(true)}
	save_ai_checkpoint()

func resume_ai() -> bool:
	if active: return false
	var saved: Dictionary = ai_checkpoint.read()
	if saved.is_empty(): return false
	var info: Dictionary = saved.details
	if not info.get("names") is Array or info.names.size()!=2 or not info.get("ai_seed") is int or not info.get("ai_state") is int:
		ai_checkpoint.clear(); return false
	leave(false)
	ai_mode = true; ai_learned = bool(info.get("learned",false))
	hosting = true; active = true; team = 0
	game = saved.game
	player_name = str(info.get("name","玩家")); names = info.names
	ai_opponent = LearningAI.new(info.ai_seed) if ai_learned else LocalAI.new(info.ai_seed)
	ai_opponent.rng.state = info.ai_state
	if ai_learned: ai_opponent.configure(info.get("weights",{}))
	ai_local_plan = info.get("plan",{})
	ai_thinking_view = info.get("thinking_view",{})
	ai_next_action = Time.get_ticks_msec()+450
	status = "已恢复 " + names[1] + " 对局"
	_broadcast()
	return true

func _process_ai() -> void:
	if not ai_mode or not active or game == null or not game.animation.is_empty(): return
	if game.revision == ai_failed_revision or Time.get_ticks_msec()<ai_next_action: return
	# Don't rebuild a snapshot while the human is reading or choosing.
	if game.phase == "planning":
		if game.plans[1] != null: return
	elif game.phase == "ended":
		if not game.confirmed[0] or game.confirmed[1]: return
	elif game.request.get("team",-1) != 1: return
	# A redacted player snapshot is the sole input to the opponent.
	var view: Dictionary
	if game.phase=="planning":
		if ai_thinking_view.is_empty() or ai_thinking_view.match!=game.match_id or ai_thinking_view.round!=game.round_number:
			ai_thinking_view=game.snapshot(1)
		view=ai_thinking_view
	else:
		ai_thinking_view={};view=game.snapshot(1)
	var decision: Dictionary = ai_opponent.poll(view,1)
	if decision.is_empty(): return
	ai_thinking_view={};ai_next_action=Time.get_ticks_msec()+450
	var error: String = Actions.apply(game,1,decision.kind,decision.payload,view.match,view.round,view.revision)
	if not error.is_empty():
		ai_failed_revision = game.revision
		push_error("Local AI: "+error)
		problem.emit("本地 AI 操作失败："+error)
	_broadcast()

func host_room(nickname: String, room_port: int) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(room_port, 1)
	if result != OK:
		status = "建房失败：端口可能被占用，请换一个端口。"
		changed.emit()
		return result
	multiplayer.multiplayer_peer = peer
	hosting = true
	active = true
	team = 0
	port = room_port
	player_name = _clean_name(nickname, "玩家一")
	names = [player_name, "等待加入"]
	status = "房间已创建，等待另一名玩家加入。"
	changed.emit()
	return OK

func join_room(nickname: String, address: String, room_port: int) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address.strip_edges(), room_port)
	if result != OK:
		status = "无法连接，请检查地址与端口。"
		changed.emit()
		return result
	multiplayer.multiplayer_peer = peer
	team = 1
	active = true
	joining = true
	port = room_port
	player_name = _clean_name(nickname, "玩家二")
	connection_started = Time.get_ticks_msec()
	status = "正在连接房间…"
	changed.emit()
	return OK

func leave(clear_ai_save: bool = true) -> void:
	# Tutorials neither overwrite nor erase an interrupted AI match.
	if clear_ai_save and tutorial == null: ai_checkpoint.clear()
	tutorial = null
	ai_local_plan.clear(); ai_save_warning = false; ai_learned = false
	ai_mode = false; ai_opponent = null; ai_next_action = 0; ai_failed_revision = -1; ai_thinking_view={}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.sacrificeClearResume?.()",true)
	reconnecting = false; reconnect_attempt = 0; reconnect_at = 0; reconnect_deadline = 0
	received_views.clear()
	received_animation_key = ""
	received_animation_started = 0
	if online != null: online.close()
	online_mode = false; dedicated = false; room_code = ""; peer_missing = false
	animation_key = ""
	active = false
	hosting = false
	joining = false
	opponent_peer = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	game = null
	review_game = null; review_round = -1; animation_key = ""
	state = {}
	team = -1
	status = ""
	changed.emit()

func _connected() -> void:
	if online_mode or dedicated: return
	_hello.rpc_id(1, PROTOCOL, player_name)

@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: String, nickname: String) -> void:
	if not hosting or opponent_peer != 0:
		return
	var sender := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_rejected.rpc_id(sender, "双方游戏版本不一致。")
		return
	opponent_peer = sender
	names[1] = _clean_name(nickname, "玩家二")
	game = Rules.new()
	game.presentation_enabled = true
	game.start()
	status = "已连接"
	_broadcast()

func act(kind: String, payload: Array = []) -> void:
	if tutorial != null and not tutorial.allows(kind,payload):
		tutorial.hint = "请先完成教程当前提示的操作。"
		changed.emit()
		return
	if online_mode:
		if peer_missing or reconnecting: return
		online.send_action(kind,payload,state)
		return
	if not active or state.is_empty():
		return
	if hosting:
		_apply(0, kind, payload, int(state.match), int(state.round), int(state.revision))
	else:
		_intent.rpc_id(1, kind, payload, int(state.match), int(state.round), int(state.revision))

@rpc("any_peer", "call_remote", "reliable")
func _intent(kind: String, payload: Array, match_serial: int, round_serial: int, revision: int) -> void:
	if hosting and multiplayer.get_remote_sender_id() == opponent_peer:
		_apply(1, kind, payload, match_serial, round_serial, revision)

func _apply(actor_team: int, kind: String, payload: Array, match_serial: int, round_serial: int, revision: int) -> void:
	if game == null:
		return
	var error: String = Actions.apply(game,actor_team,kind,payload,match_serial,round_serial,revision)
	if not error.is_empty():
		if actor_team == 0:
			problem.emit(error)
		elif opponent_peer != 0:
			_rejected.rpc_id(opponent_peer, error)
	elif tutorial != null and actor_team == 0:
		tutorial.action_done()
	_broadcast()

func _broadcast() -> void:
	if game == null or not active:
		return
	if tutorial != null: tutorial.observe(game)
	save_ai_checkpoint()
	state = game.snapshot(0)
	state.names = names.duplicate()
	if opponent_peer != 0:
		var remote: Dictionary = game.snapshot(1)
		remote.names = names.duplicate()
		_snapshot.rpc_id(opponent_peer, remote)
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func _snapshot(view: Dictionary) -> void:
	joining = false
	status = "已连接"
	_receive_view(view)

func _animation_stamp(view: Dictionary) -> String:
	var event: Dictionary = view.get("animation",{})
	if event.is_empty(): return ""
	return "%s/%s/%s" % [view.match,event.id,event.stage]

func begin_start_announcement(view: Dictionary) -> int:
	# First-load textures may take longer than the opening cue. Start its clock
	# when the board is ready, and hold queued snapshots for the full duration.
	var started := Time.get_ticks_msec()
	var stamp := _animation_stamp(view)
	if stamp == received_animation_key: received_animation_started = started
	if hosting and stamp == _animation_stamp(state):
		animation_key = stamp
		animation_started = started
	return started

func _receive_view(view: Dictionary) -> void:
	# Reliable network packets can arrive in a burst. Preserve each visible
	# phase before showing the next authoritative snapshot (including its HP).
	# A suspended/slow mobile tab must not retain an unbounded history of full
	# snapshots. The newest authoritative state safely replaces stale animations.
	if received_views.size() >= MAX_RECEIVED_VIEWS:
		received_views.clear(); received_animation_key = ""; received_animation_started = 0
	received_views.append(view)
	_drain_received_views()

func _drain_received_views() -> void:
	while not received_views.is_empty():
		var next: Dictionary = received_views[0]
		var current_stamp := _animation_stamp(state)
		var next_stamp := _animation_stamp(next)
		if not current_stamp.is_empty() and next_stamp != current_stamp and current_stamp == received_animation_key:
			if Time.get_ticks_msec()-received_animation_started < Rules.StrikeStyles.duration(state.animation): return
		state = received_views.pop_front()
		if state.has("names"): names = state.names.duplicate()
		if next_stamp != received_animation_key:
			received_animation_key = next_stamp
			received_animation_started = Time.get_ticks_msec()
		changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rejected(message: String) -> void:
	problem.emit(message)

func _failed() -> void:
	if online_mode or dedicated: return
	leave()
	status = "连接失败。请确认房主已建房，且双方地址、端口一致。"
	changed.emit()

func _server_left() -> void:
	if online_mode or dedicated: return
	leave()
	status = "房主已离开，连接已结束。请重新加入房间。"
	changed.emit()

func _peer_left(id: int) -> void:
	if online_mode or dedicated: return
	if hosting and id == opponent_peer:
		game = null
		state = {}
		opponent_peer = 0
		names[1] = "等待加入"
		status = "对方已离开。本局结束，等待玩家重新加入。"
		changed.emit()

func _clean_name(value: String, fallback: String) -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ").substr(0, 16)
	return fallback if clean.is_empty() else clean

func start_dedicated(server_port: int = 7002, bind_address: String = "127.0.0.1") -> Error:
	leave(); dedicated = true
	return online.start_server(server_port,bind_address)

func connect_online(nickname: String, create: bool, code: String = "", url: String = "") -> Error:
	leave(); online_mode = true; active = true; joining = true
	online_address = url
	player_name = _clean_name(nickname,"玩家")
	status = "正在连接服务器…"
	var result: Error = online.connect_service(player_name,create,code,url)
	if result != OK: _online_failed("无法连接服务器，请稍后重试。")
	else: changed.emit()
	return result

func _online_view(value: Dictionary) -> void:
	if not online_mode: return
	# If our old socket still occupies a seat and the other player leaves, the
	# server's first free seat is the opponent's. Never adopt it during recovery.
	if reconnecting and team >= 0 and int(value.team) != team:
		online.close(); _begin_reconnect()
		return
	var was_missing := peer_missing
	var was_reconnecting := reconnecting
	reconnecting = false; reconnect_attempt = 0; reconnect_at = 0; reconnect_deadline = 0
	team = int(value.team); room_code = value.room
	names = value.names.duplicate()
	if names.size() == 1: names.append("等待加入")
	peer_missing = not value.state.is_empty() and value.get("connected",[true,true]).has(false)
	joining = false
	status = "房间 %s · 等待另一名玩家加入" % room_code if value.state.is_empty() else "已连接"
	if peer_missing: status = "对方已离线 · 房间 %s 已保留，等待重新加入" % room_code
	if peer_missing or was_missing or was_reconnecting:
		received_views.clear(); received_animation_key = ""; received_animation_started = 0
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.sacrificeSaveResume?.("+JSON.stringify({"room":room_code,"name":player_name,"team":team})+")",true)
	_receive_view(value.state)

func _online_failed(message: String) -> void:
	if not online_mode: return
	if not room_code.is_empty():
		_begin_reconnect()
		return
	_finish_online_failure(message)

func _online_refused(message: String) -> void:
	if not online_mode: return
	# A crashed connection may still occupy its seat until the server detects it.
	if reconnecting and message.contains("已有两名玩家"):
		_begin_reconnect()
		return
	_finish_online_failure(message)

func _finish_online_failure(message: String) -> void:
	var previous_room := room_code
	leave(); status = message
	if not previous_room.is_empty(): status += "\n原房间号：%s；对方仍在房间时可重新加入。" % previous_room
	changed.emit()

func resume_online(nickname: String, code: String, url: String = "", previous_team: int = -1) -> void:
	if not Online.Rooms.valid_code(code): return
	leave(); online_mode = true; active = true; joining = true
	player_name = _clean_name(nickname,"玩家"); room_code = code; online_address = url
	team = previous_team if previous_team in [0,1] else -1
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.sacrificeSaveResume?.("+JSON.stringify({"room":room_code,"name":player_name,"team":team})+")",true)
	_begin_reconnect()
	reconnect_at = Time.get_ticks_msec()

func _begin_reconnect() -> void:
	var now := Time.get_ticks_msec()
	if not reconnecting:
		reconnecting = true; reconnect_attempt = 0; reconnect_deadline = now + RECONNECT_WINDOW_MS
	received_views.clear(); received_animation_key = ""; received_animation_started = 0
	reconnect_at = now + mini(10000,1000 * (1 << mini(reconnect_attempt,4)))
	status = "连接中断，正在自动重连…"
	changed.emit()

func _process_reconnect(now: int) -> void:
	if now >= reconnect_deadline:
		_finish_online_failure("暂时无法恢复连接，请检查网络后重新加入。")
		return
	if online.enabled or now < reconnect_at: return
	reconnect_attempt += 1
	status = "正在自动重连 · 第 %d 次尝试" % reconnect_attempt
	changed.emit()
	var error: Error = online.connect_service(player_name,false,room_code,online_address)
	if error != OK: _begin_reconnect()
