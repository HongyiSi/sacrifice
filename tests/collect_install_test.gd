extends "res://tests/v018_test.gd"
const C=preload("res://tests/collect_scenarios.gd")
const Session=preload("res://scripts/session.gd")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("COLLECT_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func _run()->void:
	for actor in range(6):
		for remaining in [2,7]:
			var g=C.setup(actor,220000+checks,remaining)
			check(C.seek(g),"real resolution reaches collect intro")
			var hand:Array=g.characters[actor].hand.duplicate();var pile:Array=g.deck.duplicate()
			check(hand.size()==remaining,"no early draw during intro")
			check(g.snapshot(0).animation==g.snapshot(1).animation,"public intro is identical for both viewers")
			check(g.animation.travel_ms==1700 and g.animation.impact_ms==120,"approved timing")
			var client=Session.new();root.add_child(client);client.set_process(false)
			for duration in [1700,120]:
				var before:Dictionary=g.snapshot(1);client._receive_view(before)
				g.advance_animation();var after:Dictionary=g.snapshot(1);client._receive_view(after)
				client.received_animation_started=Time.get_ticks_msec()-duration+20;client._drain_received_views()
				check(client.state.animation==before.animation,"client buffers each full intro stage")
				client.received_animation_started=Time.get_ticks_msec()-duration-1;client._drain_received_views()
				check(client.state.revision==after.revision,"buffer releases at stage boundary")
				if duration==1700:check(g.characters[actor].hand==hand and g.deck==pile,"deck and hand unchanged until emblem lands")
			client.leave();client.queue_free()
			check(g.animation.kind=="draw_cards","real draw follows deck pulse")
			check(g.characters[actor].hand.size()==mini(8,remaining+3),"draw obeys hand limit")
			var draw:Dictionary=g.animation.draws[0]
			check(draw.returned==([false,false,false] if remaining==2 else [false,true,true]),"correct flights and returns")
			check(not g.snapshot(1-actor/3).animation.draws[0].has("ids"),"opponent drawn cards remain private")
			check(C.drain(g) and _conserved(g),"round finishes and conserves cards")
	# Queue a Collect draw behind another draw: batching must stop before its intro.
	var g=H.fixture(8);var card:int=H.give(g,0,"collect")
	var a:Dictionary={"id":999,"actor":0,"card":card,"death":false,"status":"active"}
	g.presentation_enabled=true
	g._push([{"op":"draw","target":1,"count":1},g._job("draw",a,{"target":0,"count":3})]);g._pump()
	check(g.animation.kind=="draw_cards" and g.characters[0].hand.size()==1,"preceding draw does not swallow intro")
	while g.animation.get("kind","")=="draw_cards":g.advance_animation()
	check(C.supports(g.animation),"queued collect gets its own intro")
	while not g.animation.is_empty():g.advance_animation()
	check(g.characters[0].hand.size()==4 and g.characters[1].hand.size()==1,"each queued draw runs once")
	for status in ["blocked","declined","removed"]:
		a.status=status
		check(not g._needs_collect_intro(g._job("draw",a,{"target":0,"count":3})),"cancelled action has no intro")
	# Check current prison and divinity rules after the visual delay.
	for key in ["prison","divinity","empty"]:
		g=C.setup(0,230000+checks);check(C.seek(g),"special fixture")
		var before:int=g.characters[0].hand.size()
		if key=="empty":g.deck.clear();g.discard.clear()
		else:activate(g,3,key,0);g.characters[3].hp=0
		g.advance_animation();g.advance_animation()
		if key=="divinity":
			while not g.animation.is_empty():g.advance_animation()
			check(g.phase=="selecting" and g.request.type=="deck","divinity selects after intro")
			check(g.pick(1,g.request.options.slice(0,3))=="","divinity selection accepted")
		check(C.drain(g),"special case completes")
		check(g.characters[0].hand.size()==before+(3 if key=="divinity" else 0),"special case keeps actual draw outcome")
	print("COLLECT_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
