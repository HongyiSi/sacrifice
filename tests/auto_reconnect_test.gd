extends SceneTree
const Session = preload("res://scripts/session.gd")
const H = preload("res://tests/helpers.gd")
var failures := 0
var checks := 0
class FakeOnline extends Node:
	var enabled := false
	var attempts: Array = []
	var sent := 0
	func close(): enabled = false
	func connect_service(nickname,create,room,url):
		attempts.append([nickname,create,room,url]); enabled = true; return OK
	func send_action(_kind,_payload,_state): sent += 1
func check(ok: bool,label: String):
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize(): run.call_deferred()
func run():
	var s = Session.new(); root.add_child(s); s.set_process(false)
	s.online.free(); s.online = FakeOnline.new(); s.add_child(s.online)
	var state = H.fixture(8).snapshot(0)
	s.online_mode = true; s.active = true; s.room_code = "ABC234"; s.player_name = "测试"; s.team = 0
	s.online_address = "ws://localhost:12345"; s.state = state
	s._online_failed("网络中断")
	check(s.reconnecting and s.active and s.online_mode,"transient disconnect stays in game")
	check(s.state == state and s.team == 0 and s.room_code == "ABC234","preserve current game until authoritative return")
	s.act("plan",[]); check(s.online.sent == 0,"do not send actions while reconnecting")
	s._process_reconnect(s.reconnect_at-1); check(s.online.attempts.is_empty(),"retry waits for backoff")
	s._process_reconnect(s.reconnect_at)
	check(s.online.attempts == [["测试",false,"ABC234","ws://localhost:12345"]],"retry joins original room instead of creating one")
	s._process_reconnect(s.reconnect_at+1);check(s.online.attempts.size()==1,"only one pending connection")
	s.online.enabled=false;var deadline=s.reconnect_deadline
	s._online_refused("这个房间已有两名玩家。")
	check(s.reconnecting and s.reconnect_deadline==deadline,"occupied stale connection retries without extending deadline")
	s._process_reconnect(s.reconnect_at);check(s.online.attempts.size()==2,"retries occupied room")
	s._online_view({"team":0,"room":"ABC234","names":["甲","乙"],"connected":[true,true],"state":state})
	check(not s.reconnecting and s.status=="已连接","success clears reconnect status")
	check(s.received_views.is_empty() and s.state==state,"fresh authoritative view replaces queued animation")
	s.online.enabled=false;s._online_failed("断线");s.leave()
	check(not s.reconnecting and not s.active and s.room_code.is_empty(),"explicit leave cancels reconnection")
	s.resume_online("恢复者","ABC234","ws://localhost:12345")
	check(s.reconnecting and s.room_code=="ABC234" and s.state.is_empty(),"reload can resume without old in-memory state")
	s._online_refused("房间不存在，请核对房间号。")
	check(not s.active and not s.reconnecting and s.status.contains("房间不存在"),"deleted rooms stop retrying")
	s.resume_online("恢复者","ABC234");s._online_refused("版本不一致，请刷新网页或更新游戏。")
	check(not s.reconnecting and s.status.contains("版本不一致"),"version mismatch is terminal")
	s.resume_online("恢复者","ABC234","",0)
	s._online_view({"team":1,"room":"ABC234","names":["甲","乙"],"connected":[true,true],"state":state})
	check(s.reconnecting and s.team==0 and s.state.is_empty(),"stale socket cannot move reconnecting player into opponent seat")
	s.resume_online("恢复者","ABC234");s._process_reconnect(s.reconnect_deadline)
	check(not s.active and s.status.contains("ABC234"),"retry timeout retains code in explanation")
	s.online_mode=true;s.active=true;s._online_failed("无法连接")
	check(not s.reconnecting and not s.active,"initial join failure does not create phantom room")
	s.free()
	print("AUTO_RECONNECT_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
