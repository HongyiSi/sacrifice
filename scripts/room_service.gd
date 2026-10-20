extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const Actions = preload("res://scripts/match_actions.gd")
const PROTOCOL := "sacrifice-0.20.69"
const ALPHABET := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const MAX_ROOMS := 32
var rooms: Dictionary = {}
var peer_rooms: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init() -> void: rng.randomize()
static func normalize_code(value: String) -> String: return value.strip_edges().to_upper()
static func valid_code(value: String) -> bool:
	if value.length() != 6: return false
	for c in value:
		if not ALPHABET.contains(c): return false
	return true
static func clean_name(value: String) -> String:
	var result := value.strip_edges().replace("\n"," ").replace("\r"," ").substr(0,16)
	return "玩家" if result.is_empty() else result
func enter(peer: int, protocol: String, nickname: String, create: bool, requested: String = "") -> Dictionary:
	if protocol != PROTOCOL: return {"error":"版本不一致，请刷新网页或更新游戏。"}
	if peer_rooms.has(peer): return {"error":"已经在房间中。"}
	var code := normalize_code(requested)
	if create:
		if rooms.size() >= MAX_ROOMS: return {"error":"房间已满，请稍后重试。"}
		for _attempt in range(128):
			code = ""
			for _i in range(6): code += ALPHABET[rng.randi_range(0,ALPHABET.length()-1)]
			if not rooms.has(code): break
		if rooms.has(code): return {"error":"创建房间失败，请重试。"}
		rooms[code] = {"peers":[0,0],"names":["等待加入","等待加入"],"game":null,"animation_key":"","animation_started":0,"review_key":"","review_started":0}
	elif not valid_code(code) or not rooms.has(code): return {"error":"房间不存在，请核对房间号。"}
	var room: Dictionary = rooms[code]
	var team: int = room.peers.find(0)
	if team < 0: return {"error":"这个房间已有两名玩家。"}
	room.peers[team] = peer; room.names[team] = clean_name(nickname); peer_rooms[peer] = code
	if not room.peers.has(0) and room.game == null:
		room.game = Rules.new(); room.game.presentation_enabled = true; room.game.start()
	return {"room":code,"team":team}

func act(peer: int, kind: String, payload: Array, serial: int, round_serial: int, revision: int) -> String:
	if not peer_rooms.has(peer): return "尚未加入房间。"
	var room: Dictionary = rooms[peer_rooms[peer]]
	if room.peers.has(0): return "对方已离线，请等待对方用原房间号重新加入。"
	return Actions.apply(room.game,room.peers.find(peer),kind,payload,serial,round_serial,revision)

func view(peer: int) -> Dictionary:
	if not peer_rooms.has(peer): return {}
	var code: String = peer_rooms[peer]
	var room: Dictionary = rooms[code]
	var team: int = room.peers.find(peer)
	var state: Dictionary = {} if room.game == null else room.game.snapshot(team)
	if not state.is_empty(): state.names = room.names.duplicate()
	return {"room":code,"team":team,"names":room.names.duplicate(),"connected":room.peers.map(func(id): return id != 0),"state":state}

func leave(peer: int) -> Array:
	if not peer_rooms.has(peer): return []
	var code: String = peer_rooms[peer]
	var room: Dictionary = rooms[code]
	room.peers[room.peers.find(peer)] = 0
	peer_rooms.erase(peer)
	var others: Array = room.peers.filter(func(id): return id != 0)
	# Fixed seats preserve each team's hand, choices and pending response.
	# Restart presentation clocks on reunion; never advance an unattended game.
	room.animation_key = ""; room.review_key = ""
	if others.is_empty(): rooms.erase(code)
	return others

func tick(now: int) -> Array:
	var changed: Array = []
	for code in rooms:
		var room: Dictionary = rooms[code]
		var game = room.game
		if game == null or room.peers.has(0): continue
		if not game.animation.is_empty():
			var key := "%d/%d/%s" % [game.match_id,game.animation.id,game.animation.stage]
			if room.animation_key != key: room.animation_key = key; room.animation_started = now
			elif now-room.animation_started >= Rules.StrikeStyles.duration(game.animation):
				game.advance_animation(); changed.append(code)
		else: room.animation_key = ""
		if game.phase == "review":
			var key := "%d/%d" % [game.match_id,game.round_number]
			if room.review_key != key: room.review_key = key; room.review_started = now
			elif now-room.review_started >= 1000:
				game.advance_round()
				if not changed.has(code): changed.append(code)
		else: room.review_key = ""
	return changed
