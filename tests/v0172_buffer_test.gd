extends SceneTree
const H=preload("res://tests/helpers.gd")
const Session=preload("res://scripts/session.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0172_BUFFER_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func view(g)->Dictionary:
	var result:Dictionary=g.snapshot(1);result.names=["一","二"];return result
func finish_phase(client)->void:
	client.received_animation_started=Time.get_ticks_msec()-H.Rules.StrikeStyles.duration(client.state.animation)-1
	client._drain_received_views()
func _run()->void:
	var client=Session.new();root.add_child(client)
	var g=H.fixture(8);g.match_id=172;g.presentation_enabled=true
	H.begin(g,{0:H.give(g,0,"triple_strike")});g.target(0,3)
	client._snapshot(view(g))
	var began:int=client.received_animation_started
	client._snapshot(view(g))
	check(client.received_animation_started==began,"duplicate snapshot does not restart flight")
	g.advance_animation();client._snapshot(view(g))
	check(client.state.animation.stage=="travel" and client.state.characters[3].hp==8,"early impact packet cannot truncate weapon flight or HP")
	g.advance_animation();client._snapshot(view(g))
	check(client.received_views.size()==2,"impact and continuation retain order")
	finish_phase(client)
	check(client.state.animation.stage=="impact" and client.state.characters[3].hp==5,"impact releases HP exactly once after flight")
	check(client.received_views.size()==1,"result hold remains visible before continuation")
	finish_phase(client)
	check(client.state.phase=="review" and client.received_views.is_empty(),"round continues after impact hold")
	check(client.state.characters[0].hand.is_empty(),"buffer preserves redacted hands")
	# Reconnection/leave must not let old queued damage enter a new room.
	client._snapshot(view(g))
	g=H.fixture(8);g.presentation_enabled=true;H.begin(g,{0:H.give(g,0,"heal")})
	client._snapshot(view(g));g.advance_animation();client._snapshot(view(g))
	client.leave()
	check(client.received_views.is_empty() and client.received_animation_key.is_empty() and client.state.is_empty(),"leave clears all pending presentation")
	# WebSocket receives the same presentation guarantees without delaying lobby metadata.
	client.online_mode=true
	client._online_view({"team":1,"room":"ABC234","names":["一","二"],"state":{}})
	check(client.room_code=="ABC234" and client.state.is_empty(),"online lobby remains immediate")
	g=H.fixture(8);g.presentation_enabled=true;g.characters[0].hp=3
	H.begin(g,{0:H.give(g,0,"heal")})
	client._online_view({"team":1,"room":"ABC234","names":["一","二"],"state":view(g)})
	g.advance_animation();client._online_view({"team":1,"room":"ABC234","names":["一","二"],"state":view(g)})
	check(client.state.characters[0].hp==3,"online received healing also waits for orb")
	finish_phase(client)
	check(client.state.characters[0].hp==5,"online heal appears on arrival")
	client.leave();client.queue_free()
	print("V0172_BUFFER_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
