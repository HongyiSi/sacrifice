extends SceneTree
const Rooms = preload("res://scripts/room_service.gd")
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("RECONNECT_FAIL " + label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for missing in [0,1]:
		var service = Rooms.new()
		var code: String = service.enter(2,Rooms.PROTOCOL,"甲",true).room
		service.enter(3,Rooms.PROTOCOL,"乙",false,code)
		var game = H.fixture(8)
		var card: int = H.give(game,0,"precise_strike")
		H.begin(game,{0:card})
		game.target(0,3)
		service.rooms[code].game = game
		var state: Dictionary = game.snapshot(missing).duplicate(true)
		var active_peer: int = 3-missing
		check(service.leave(2+missing)==[active_peer],"only disconnected seat is removed")
		check(service.rooms.has(code) and service.peer_rooms.has(active_peer),"room and other peer survive")
		check(service.view(active_peer).team==1-missing,"remaining team is stable")
		check(service.view(active_peer).connected[missing]==false,"absence is visible")
		check(service.act(active_peer,"skip_effect",[],game.match_id,game.round_number,game.revision)!="","actions paused")
		check(service.tick(100000000).is_empty() and game.snapshot(missing)==state,"unattended game is frozen")
		var resumed: Dictionary = service.enter(4,Rooms.PROTOCOL,"重新加入",false,code.to_lower())
		check(resumed.team==missing,"returning player gets original seat")
		check(service.rooms[code].game==game,"original game object retained")
		check(game.snapshot(missing)==state,"hands and partial target choices retained")
		check(service.view(4).connected==[true,true],"connected presence restored")
		check(service.view(4).state.characters[(1-missing)*3].hand.is_empty(),"reconnect does not expose enemy cards")
		check(service.enter(5,Rooms.PROTOCOL,"第三人",false,code).has("error"),"full room still rejects third player")
		check(service.act(2+missing,"skip_effect",[],game.match_id,game.round_number,game.revision)!="","old peer loses authority")
		service.leave(4); service.leave(active_peer)
		check(service.rooms.is_empty() and service.peer_rooms.is_empty(),"both leave deletes room and mappings")
		check(service.enter(6,Rooms.PROTOCOL,"",false,code).has("error"),"closed code cannot revive stale game")
	var service = Rooms.new()
	var waiting: String = service.enter(8,Rooms.PROTOCOL,"等待",true).room
	service.leave(8)
	check(not service.rooms.has(waiting),"empty unstarted room is deleted")
	var code: String = service.enter(9,Rooms.PROTOCOL,"甲",true).room
	service.enter(10,Rooms.PROTOCOL,"乙",false,code)
	var game = service.rooms[code].game
	var state: Dictionary = game.snapshot(0).duplicate(true)
	service.tick(100)
	service.leave(9); service.tick(1000000)
	check(game.snapshot(0)==state,"disconnect during animation keeps original event")
	service.enter(11,Rooms.PROTOCOL,"甲",false,code)
	service.tick(1000001)
	check(game.snapshot(0)==state,"rejoin starts presentation clock afresh")
	service.tick(1000001+Rooms.Rules.StrikeStyles.duration(game.animation)+1)
	check(game.snapshot(0)!=state,"animation advances after rejoin")
	service.leave(10); service.leave(11)
	var session = Session.new(); root.add_child(session)
	session.online_mode = true
	var sample = H.fixture(8).snapshot(0)
	session._online_view({"team":0,"room":"ABC234","names":["甲","乙"],"connected":[true,false],"state":sample})
	check(session.peer_missing and session.status.contains("ABC234"),"client displays retained room")
	session._online_view({"team":0,"room":"ABC234","names":["甲","乙"],"connected":[true,true],"state":sample})
	check(not session.peer_missing,"client resumes after reunion")
	session._online_failed("断线")
	check(session.reconnecting and session.room_code=="ABC234" and session.state==sample,"disconnected player preserves original room while auto reconnecting")
	session.state = sample.duplicate(true)
	session.state.animation = {"id":1,"stage":"travel","travel_ms":100000}
	session.received_animation_key = session._animation_stamp(session.state)
	session.received_animation_started = Time.get_ticks_msec()
	for i in range(80):
		var next: Dictionary = sample.duplicate(true); next.revision=i
		session._receive_view(next)
	check(session.received_views.size()<=Session.MAX_RECEIVED_VIEWS,"slow client snapshot backlog is bounded")
	check(session.state.revision==79,"overloaded client catches up to latest state")
	session.leave(); session.queue_free()
	print("RECONNECT_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
