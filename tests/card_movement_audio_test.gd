extends SceneTree
const H=preload("res://tests/helpers.gd")
const Cases=preload("res://tests/v011_scenarios.gd")
var main
var sound
var checks:=0
var failures:=0
var played:Array=[]
var serial:=26100600
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("CARD_MOVEMENT_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func frames()->void:
	for i in range(3):await process_frame
func fixture():
	var g=H.fixture();serial+=1;g.match_id=serial
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	return g
func show(g,viewer:int=0)->void:
	main.session.team=viewer;main.session.state=g.snapshot(viewer)
	main.session.state.names=["动作声音测试","对手"]
	main.session.changed.emit();await frames()
func movement(g)->Array:
	var cues:Array=sound.cues_for(g.snapshot(0))
	check(cues==sound.cues_for(g.snapshot(1)),"both viewers share public sounds")
	return cues.filter(func(c):return c.get("category","")=="card_movement")
func drain(g)->void:
	for i in range(250):
		if g.animation.is_empty() and g.phase in ["planning","review","ended"]:return
		check(Cases.step(g).is_empty(),"real rules progress")
	check(false,"scenario finished")
func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	await create_timer(.3).timeout
	sound=main.attack_audio;sound.settings_path="res://test-results/card-movement-sound.cfg"
	sound.cue_played.connect(func(file,offset):played.append({"file":file,"offset":offset}))
	var place:String=sound.support_bank.card_movement.place
	var play:String=sound.support_bank.card_movement.play
	var recovery:String=sound.support_bank.cards.heal.impact
	for file in [place,play]:
		var stream=load(file)
		check(stream!=null and stream.get_length()>0 and not stream.loop,"short source imported: "+file)
	# Successful and failed immediate resurrection follow the real result flag.
	for success in [true,false]:
		var g=fixture();H.give_death(g,0,"immortal");g.characters[0].hp=0
		if not success:g.characters[1].hp=0;g.characters[2].hp=0
		g.phase="resolution";g.turn_stage="resolution";g._try_immortal(0);g._pump()
		var arrivals:=0;var flights:=0
		for i in range(12):
			if g.animation.is_empty():break
			check(sound.cues_for(g.snapshot(0))==sound.cues_for(g.snapshot(1)),"resurrection shared")
			for c in sound.cues_for(g.snapshot(0)):
				if c.file==recovery:arrivals+=1
				if c.file==sound.support_bank.cards.heal.travel:flights+=1
			g.advance_animation()
		check(arrivals==int(success) and flights==int(success),"resurrection success/failure audio")
	# Blood rite heals living allies as one batch; blocked recovery is silent.
	for blocked in [false,true]:
		var g=fixture();H.give_death(g,0,"blood_rite");g.characters[0].hp=0;g.characters[0].death_round=g.round_number
		if blocked:
			var id:int=H.give_death(g,3,"blessing")
			g._activate({"actor":3,"card":id},1);g.characters[2].hp=0
		H.begin(g,{})
		var arrivals:=0
		for i in range(150):
			if g.animation.is_empty() and g.phase in ["review","ended"]:break
			for c in sound.cues_for(g.snapshot(0)):
				if c.file==recovery:arrivals+=1
			check(Cases.step(g).is_empty(),"blood rite progresses")
		check(arrivals==int(not blocked),"one team heal sound, blocked=%s arrivals=%d"%[blocked,arrivals])
	# Real accelerated draws: one landing sound per accepted card at its arrival.
	for existing in [0,7,8]:
		var g=fixture()
		for i in range(existing):g.characters[0].hand.append(g.deck.pop_back())
		g.phase="resolution";g.turn_stage="resolution"
		g._push([{"op":"draw","target":0,"count":3},{"op":"planning"}]);g._pump()
		check(g.animation.kind=="draw_cards","actual draw batch")
		var cues:=movement(g);var d:Dictionary=g.animation.draws[0]
		check(cues.size()==mini(3,8-existing),"overflow draws are silent")
		for i in range(cues.size()):
			check(cues[i].file==place and is_equal_approx(cues[i].delay,(d.starts[i]+d.durations[i])/1000.0),"sound follows accelerated arrival")
		await drain(g)
	# Whole resolving cards enter hands; rejected transfers have no landing cue.
	for accepted in [true,false]:
		var g=fixture();var id:int=H.give(g,0,"ruby")
		if not accepted:
			for i in range(8):g.characters[1].hand.append(g.deck.pop_back())
		H.begin(g,{0:id});var found:=false
		for i in range(80):
			if g.animation.get("kind","")=="hand_transfer":
				found=true
				var cues:=movement(g)
				check(cues.size()==(1 if accepted and g.animation.stage=="travel" else 0),"whole-card contact scheduled on flight clock, accepted only")
				if not cues.is_empty():check(is_equal_approx(cues[0].delay,g.animation.travel_ms/1000.0),"transfer sound at exact local flight completion")
			if g.animation.is_empty() and g.phase in ["review","ended"]:break
			if g.phase=="targeting":check(g.target(g.request.team,1).is_empty(),"transfer target")
			else:check(Cases.step(g).is_empty(),"transfer progresses")
		check(found,"real transfer observed")
	# Drive the actual card and audio on the same clock, while holding back the
	# server's impact snapshot. Both views must sound as soon as flight stops.
	for viewer in [0,1]:
		var transfer=fixture();H.begin(transfer,{0:H.give(transfer,0,"ruby")})
		for i in range(80):
			if transfer.animation.get("kind","")=="hand_transfer":break
			if transfer.phase=="targeting":transfer.target(transfer.request.team,1)
			else:Cases.step(transfer)
		sound.reset();sound.set_process(false);played.clear();main.effect_key=""
		await show(transfer,viewer)
		var fx=main.board.canvas.get_children().filter(func(c):return c.has_meta("hand_transfer_animation"))[0]
		fx.set_process(false)
		var before:int=Time.get_ticks_msec()-int(transfer.animation.travel_ms)+60
		main.effect_started=before;fx.clock_started=before;sound.stage_started=before
		fx._process(0);sound._process(0)
		check(fx.progress()<1 and played.is_empty(),"no contact before landing, viewer %d"%viewer)
		var landed:int=Time.get_ticks_msec()-int(transfer.animation.travel_ms)
		main.effect_started=landed;fx.clock_started=landed;sound.stage_started=landed
		fx._process(0);sound._process(0)
		check(fx.progress()==1 and played.size()==1 and played[0].file==place,"contact at stopped card without impact snapshot, viewer %d"%viewer)
		check(fx.flying.position.is_equal_approx(fx.destination-fx.flying.pivot_offset),"card is at its exact destination")
		main._schedule_render();await frames()
		check(played.size()==1,"redrawing the stopped card does not replay contact")
		await create_timer(.12).timeout
		transfer.advance_animation();await show(transfer,viewer)
		check(played.size()==1,"late impact snapshot does not replay contact")
		var impact_view:Dictionary=transfer.snapshot(viewer)
		var travel_view:Dictionary=impact_view.duplicate(true);travel_view.animation.stage="travel"
		sound.reset();played.clear();sound.sync_view(travel_view,Time.get_ticks_msec())
		sound.sync_view(impact_view,Time.get_ticks_msec())
		check(played.size()==1,"early impact lands once even before scheduled audio frame")
		sound.reset();played.clear();sound.sync_view(impact_view,Time.get_ticks_msec());sound.sync_view(impact_view,Time.get_ticks_msec())
		check(played.size()==1,"first impact view gets one fallback contact")
		sound.set_process(true)
	# Accepted gains sound once at arrival; hidden identities remain private.
	for key in ["gift","poisoning","obstruct","search","plunder"]:
		for full in [false,true]:
			var g=fixture();var id:int=H.give(g,0,key)
			if full:
				for i in range(8):g.characters[1].hand.append(g.deck.pop_back())
			var a:Dictionary={"actor":0,"card":id,"death":false}
			g.phase="resolution";g.turn_stage="resolution"
			check(g._put_in_hand(1,g.deck.pop_back(),a)==not full,"actual placement capacity")
			g._pump()
			check(movement(g).size()==int(not full),"instant placement sound: "+key)
			if not full:check(not g.snapshot(1).animation.has("incoming_card"),"receipt contains no private card identity")
	for slots in [1,2]:
		var batch=fixture();var id:int=H.give(batch,0,"obstruct")
		for i in range(8-slots):batch.characters[1].hand.append(batch.deck.pop_back())
		batch.phase="resolution";batch.turn_stage="resolution"
		var action:Dictionary={"actor":0,"card":id,"death":false,"private_unused":123}
		for i in range(2):batch._put_in_hand(1,batch.deck.pop_back(),action)
		batch._pump()
		check(batch.animation.kind=="draw_cards" and batch.visual_queue.size()==int(slots==1),"accepted cards fly before the single overflow bubble")
		check(movement(batch).size()==slots,"one placement sound per flying card")
		for d in batch.animation.draws:
			check(movement(batch).any(func(c):return is_equal_approx(c.delay,(d.starts[0]+d.durations[0])/1000.0)),"generated card sounds on exact arrival")
	# Burst-arriving snapshots retain the object flight and its single landing cue.
	var receipt=fixture();var receipt_id:int=H.give(receipt,0,"plunder")
	receipt.phase="resolution";receipt.turn_stage="resolution"
	receipt._put_in_hand(1,receipt.deck.pop_back(),{"actor":0,"card":receipt_id,"death":false});receipt._pump()
	var receipt_view:Dictionary=receipt.snapshot(0);receipt_view.names=["动作声音测试","对手"]
	receipt.advance_animation();var impact_view:Dictionary=receipt.snapshot(0);impact_view.names=receipt_view.names
	receipt.advance_animation();var after_view:Dictionary=receipt.snapshot(0);after_view.names=receipt_view.names
	played.clear();main.session.team=0;main.session._receive_view(receipt_view);main.session._receive_view(impact_view);main.session._receive_view(after_view)
	check(main.session.state.animation.get("kind","")=="draw_cards","network queue holds placement flight")
	await frames();check(played.filter(func(c):return c.file==place).is_empty(),"placement sound waits for object to become a card")
	await create_timer((receipt_view.animation.travel_ms+receipt_view.animation.impact_ms)/1000.0+.2).timeout
	check(played.filter(func(c):return c.file==place).size()==1,"network burst plays contact once")
	check(main.session.state.animation.is_empty(),"network queue proceeds after landing")
	# Local planning: land once; redraws, stale clicks and opponent clicks are silent.
	var g=fixture();var a:int=H.give(g,0,"strike");var b:int=H.give(g,0,"heal")
	await show(g);sound.reset();sound.sync_view(main.session.state,main.effect_started);played.clear()
	main._play_hand(0,a,g.revision)
	await create_timer(.1).timeout;check(played.is_empty(),"play waits until tabletop landing")
	main._schedule_render();await create_timer(.24).timeout
	check(played.size()==1 and played[0].file==play,"play once after landing")
	main._schedule_render();await frames();check(played.size()==1,"redraw does not replay")
	main._play_hand(0,b,g.revision-1);main._play_hand(3,a,g.revision)
	check(sound.planning_pending.is_empty(),"invalid and opponent clicks silent")
	played.clear();main._return_planned(0,a,g.revision)
	await create_timer(.34).timeout
	check(played.size()==1 and played[0].file==place,"undo plays hand placement")
	played.clear();main._play_hand(0,a,g.revision);await create_timer(.07).timeout
	main._play_hand(0,b,g.revision);await create_timer(.34).timeout
	check(played.filter(func(c):return c.file==play).size()==1 and played.filter(func(c):return c.file==place).size()==1,"replacement cancels abandoned play sound")
	played.clear();main._return_planned(0,b,g.revision)
	var view:Dictionary=main.session.state.duplicate(true);view.phase="resolution";sound.sync_view(view,0)
	await create_timer(.34).timeout;check(played.is_empty() and sound.planning_pending.is_empty(),"phase change clears pending local sounds")
	sound.set_level(0);check(sound.voices.all(func(v):return v.volume_db<=-80),"card movement obeys sound mute")
	sound.reset();check(sound.pending.is_empty() and sound.planning_pending.is_empty(),"leaving match clears both queues")
	main.queue_free();await frames()
	print("CARD_MOVEMENT_AUDIO checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
