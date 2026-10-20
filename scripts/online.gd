extends Node
## RPCs only carry player intents or individually redacted snapshots.
signal updated(view: Dictionary)
signal failed(message: String)
signal refused(message: String)
signal rejected(message: String)
const Rooms = preload("res://scripts/room_service.gd")
const Diagnostics = preload("res://scripts/server_diagnostics.gd")
const DEFAULT_URL := "wss://sacrifice.shytomato.top/game"
var service = null
var enabled := false
var dedicated := false
var connected_at := 0
var pending: Dictionary = {}
var peers: Dictionary = {}
var budgets: Dictionary = {}
var logged_states: Dictionary = {}
var peer: WebSocketMultiplayerPeer

func _ready() -> void:
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): _fail("无法连接服务器，请检查网络后重试。"))
	multiplayer.server_disconnected.connect(func(): _fail("服务器连接已断开，请重新加入房间。"))
	multiplayer.peer_connected.connect(_joined)
	multiplayer.peer_disconnected.connect(_left)

static func default_url() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("new URL('game', window.location.href.split('?')[0]).href.replace(/^http/, 'ws')",true))
	return DEFAULT_URL
func _new_peer() -> WebSocketMultiplayerPeer:
	var p := WebSocketMultiplayerPeer.new()
	p.inbound_buffer_size = 2097152; p.outbound_buffer_size = 2097152
	p.max_queued_packets = 256; p.handshake_timeout = 10.0
	return p
func start_server(port: int, bind_address: String = "127.0.0.1") -> Error:
	peer = _new_peer()
	var error := peer.create_server(port,bind_address)
	if error != OK: return error
	service = Rooms.new(); dedicated = true; enabled = true
	multiplayer.multiplayer_peer = peer
	multiplayer.server_relay = false
	print("SACRIFICE_SERVER_READY bind=%s port=%d protocol=%s" % [bind_address,port,Rooms.PROTOCOL])
	return OK
func connect_service(nickname: String, create: bool, room: String, url: String = "") -> Error:
	close()
	pending = {"nickname":nickname,"create":create,"room":Rooms.normalize_code(room)}
	peer = _new_peer()
	var error := peer.create_client(default_url() if url.is_empty() else url)
	if error != OK: return error
	enabled = true; connected_at = Time.get_ticks_msec()
	multiplayer.multiplayer_peer = peer
	return OK
func close() -> void:
	enabled = false; dedicated = false; pending = {}; connected_at = 0
	if peer != null: peer.close()
	peer = null; service = null; peers.clear(); budgets.clear()
	logged_states.clear()
func _connected() -> void:
	if not enabled or dedicated: return
	_enter.rpc_id(1,Rooms.PROTOCOL,pending.nickname,pending.create,pending.room)
func _joined(id: int) -> void:
	if not dedicated: return
	if peers.size() >= 64: peer.disconnect_peer(id); return
	peers[id] = Time.get_ticks_msec()
	Diagnostics.write("connected",{"peer":id})
	# Native server pings also detect a crashed browser's abandoned connection.
	peer.get_peer(id).heartbeat_interval = 10.0
func _left(id: int) -> void:
	if not dedicated: return
	var duration := Time.get_ticks_msec()-int(peers.get(id,Time.get_ticks_msec()))
	peers.erase(id); budgets.erase(id)
	var code: String = service.peer_rooms.get(id,"")
	service.leave(id)
	Diagnostics.write("disconnected",{"peer":id,"room":code,"connected_ms":duration,"retained":service.rooms.has(code)})
	if not service.rooms.has(code): logged_states.erase(code)
	if not code.is_empty(): _broadcast(code)
func _fail(message: String) -> void:
	if not enabled or dedicated: return
	close(); failed.emit(message)
func _process(_delta: float) -> void:
	if not enabled: return
	var now := Time.get_ticks_msec()
	if dedicated:
		for id in peers.keys():
			if not service.peer_rooms.has(id) and now-int(peers[id]) > 30000: peer.disconnect_peer(id)
		for code in service.tick(now): _broadcast(code)
	elif connected_at > 0 and now-connected_at > 15000: _fail("连接超时，请稍后重试。")
func _allowed(id: int) -> bool:
	if not dedicated or not peers.has(id): return false
	var now := Time.get_ticks_msec()
	var budget: Dictionary = budgets.get(id,{"at":now,"count":0})
	if now-int(budget.at) >= 1000: budget = {"at":now,"count":0}
	budget.count += 1; budgets[id] = budget
	if budget.count > 40: peer.disconnect_peer(id); return false
	return true
@rpc("any_peer","call_remote","reliable")
func _enter(protocol: String, nickname: String, create: bool, room: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _allowed(sender): return
	var result: Dictionary = service.enter(sender,protocol,nickname,create,room)
	if result.has("error"):
		Diagnostics.write("join_refused",{"peer":sender,"reason":result.error})
		_closed.rpc_id(sender,result.error); return
	Diagnostics.write("room_joined",{"peer":sender,"room":result.room,"team":result.team,"create":create})
	_broadcast(result.room)
func send_action(kind: String, payload: Array, state: Dictionary) -> void:
	if enabled and not dedicated and not state.is_empty():
		_intent.rpc_id(1,kind,payload,int(state.match),int(state.round),int(state.revision))
@rpc("any_peer","call_remote","reliable")
func _intent(kind: String, payload: Array, serial: int, round_serial: int, revision: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _allowed(sender): return
	var error: String = service.act(sender,kind,payload,serial,round_serial,revision)
	Diagnostics.write("intent",{"peer":sender,"room":service.peer_rooms.get(sender,""),"kind":kind.substr(0,40),"round":round_serial,"revision":revision,"accepted":error.is_empty()})
	if not error.is_empty(): _rejected.rpc_id(sender,error)
	if service.peer_rooms.has(sender): _broadcast(service.peer_rooms[sender])
func _broadcast(code: String) -> void:
	if not service.rooms.has(code): return
	var info := Diagnostics.state(service.rooms[code])
	var stamp := JSON.stringify(info)
	if logged_states.get(code,"") != stamp:
		logged_states[code] = stamp
		info.room = code; Diagnostics.write("state",info)
	for id in service.rooms[code].peers:
		if id <= 0 or not peers.has(id) or not multiplayer.get_peers().has(id): continue
		var socket := peer.get_peer(id)
		if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_view.rpc_id(id,service.view(id))
@rpc("authority","call_remote","reliable")
func _view(value: Dictionary) -> void:
	if not enabled or dedicated: return
	connected_at = 0; updated.emit(value)
@rpc("authority","call_remote","reliable")
func _closed(message: String) -> void:
	if not enabled or dedicated: return
	close(); refused.emit(message)
@rpc("authority","call_remote","reliable")
func _rejected(message: String) -> void:
	if enabled and not dedicated: rejected.emit(message)
