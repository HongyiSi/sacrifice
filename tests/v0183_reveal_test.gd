extends SceneTree
const S=preload("res://tests/reveal_scenarios.gd")
const H=preload("res://tests/helpers.gd")
const Session=preload("res://scripts/session.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0183_REVEAL_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var g=S.setup([0,3],18300)
	for team in [0,1]:
		for a in g.snapshot(team).queue:
			if a.actor/3!=team:check(a.card==0 and not a.revealed,"hidden cards remain private before reveal")
	check(S.seek(g),"reveal precedes resolution")
	var event:Dictionary=g.animation.duplicate(true)
	check(event.actions.size()==2 and event.travel_ms==680,"one 680 ms event for both same-priority cards")
	check(event.action.is_empty() and event.targets.is_empty(),"no card is prematurely raised or hit")
	check(g.characters.all(func(c):return c.get("warcry_bonus",0)==0),"no gain before reveal finishes")
	check(g.snapshot(0).animation==g.snapshot(1).animation,"identical public reveal event for both viewers")
	for a in g.queue:
		check(a.revealed==event.actions.has(a.id),"only this priority group reveals")
	var client=Session.new();root.add_child(client);client.set_process(false)
	client._receive_view(g.snapshot(1))
	var began:int=client.received_animation_started
	client._receive_view(g.snapshot(1))
	check(began==client.received_animation_started,"duplicate snapshot does not restart flip")
	g.advance_animation()
	check(g.animation.kind=="card_start","reveal ends directly in existing card intro")
	client._receive_view(g.snapshot(1))
	check(client.state.animation.kind=="card_reveal","burst of packets cannot skip reveal")
	client.received_animation_started=Time.get_ticks_msec()-681;client._drain_received_views()
	check(client.state.animation.kind=="card_start","card intro follows the complete reveal")
	client.leave();client.queue_free()
	# Accepted guards reveal before burning; declining never reveals the guard.
	for accepted in [true,false]:
		g=S.Amulets.setup("holy_amulet",0,18301 if accepted else 18302)
		var guard_events:=0
		for _i in range(200):
			if g.phase=="review":break
			if g.animation.get("kind","")=="card_reveal":
				for id in g.animation.actions:
					if g._info(g._action(id)).key=="holy_amulet":guard_events+=1
			check(S.Amulets.step(g,accepted)=="","guard response advances")
		check(guard_events==0,"passive amulet stays in hand without a played-card reveal")
		check(g.phase=="review","guard scenario finishes")
	# Real extra cards, suppressed extras and virtual copies are distinct.
	for suppressed in [false,true]:
		g=H.fixture(8);g.presentation_enabled=true;g.resolution_presentation_enabled=true
		g.reveal_locked_teams[0]=suppressed
		var ids:Array=[H.give(g,0,"heal"),H.give(g,0,"defense")]
		g._play_revealed_hand(0,ids,"疯狂")
		var flips:Array=g.visual_queue.filter(func(e):return e.kind=="card_reveal")
		check(flips.size()==(0 if suppressed else 1),"extra play respects reveal lock")
		if not flips.is_empty():check(flips[0].actions.size()==2,"extra batch flips together")
		g.visual_queue.clear()
		var copy=g._add_action(0,ids[0],true);g._queue_card_reveal([copy.id])
		check(g.visual_queue.is_empty(),"face-up virtual copies never flip a second time")
	g=S.setup([0],18303);g.skipped.append(8)
	for _i in range(100):
		if g.phase in ["review","ended"]:break
		if g.animation.get("kind","")=="card_reveal":
			check(g.animation.actions.all(func(id):return g._info(g._action(id)).key!="warcry"),"skipped group never flips")
		check(S.step(g)=="","skipped scenario advances")
	print("V0183_REVEAL_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
