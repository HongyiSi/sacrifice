extends "res://tests/v0174_ui_test.gd"
const Audio=preload("res://scripts/attack_audio.gd")
var sound
var played=[]
var clock_view={}
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("GIFT_INSTALL_FAIL "+label)
func walk(n):
	var out=[n]
	for child in n.get_children():out.append_array(walk(child))
	return out
func own(cues):return cues.filter(func(c):return "/sfx/gift/" in c.file)
func start_case(actor,target,count,room):
	var g=H.fixture(8);serial+=1;g.match_id=serial
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	var values=[H.give(g,actor,"heal")]
	if count==2:values.append(H.give(g,actor,"strike"))
	H.give(g,actor,"defense")
	for i in range(8-room):g.characters[target].hand.append(g.deck.pop_back())
	H.begin(g,{actor:H.give(g,actor,"gift")},false);finish_fx(g)
	check(g.target(actor/3,target)=="","recipient accepted")
	check(g.pick(actor/3,values)=="","one or two chosen cards accepted")
	return {"game":g,"values":values}
func scenario(actor,target,count,room,with_ui):
	var fixture_data=start_case(actor,target,count,room);var g=fixture_data.game;var values=fixture_data.values
	var accepted=mini(count,room);var effects=0;var drawers=0;var speeches=0
	for step in range(50):
		if g.animation.is_empty():break
		var e=g.animation;var left=g.snapshot(0);var right=g.snapshot(1)
		var cues=own(sound.cues_for(left))
		check(cues==own(sound.cues_for(right)),"both clients receive identical public sound timings")
		if e.kind=="card_effect" and e.get("op","")=="gift_transfer":
			effects+=1
			check(left.characters[target].hand_count==8-room and right.characters[target].hand_count==8-room,"recipient has no premature cards before gift opens")
			check(g.snapshot(1-actor/3).animation.hand_motion.get("owner_cards",[]).is_empty(),"selected enemy card identities remain private")
			if e.stage=="travel":
				check(cues.size()==count+2 and e.travel_ms==2950,"approved packing duration and exact packing sound count")
				check(values.all(func(id):return g.characters[actor].hand.has(id)),"cards remain authoritative with sender until packed")
				if clock_view.is_empty():clock_view=left.duplicate(true)
			else:
				check(cues.size()==2 and e.impact_ms==2000,"one flight sound and one opening sound")
				check(not values.any(func(id):return g.characters[actor].hand.has(id)),"packed cards removed from sender exactly once")
			if with_ui:
				for viewer in [0,1]:
					await show_game(g,viewer)
					var nodes=walk(main).filter(func(n):return n.has_meta("cinema_effect"))
					check(nodes.size()==1,"exactly one gift animation on both clients")
					var fx=nodes[0];fx.set_process(false)
					var pose=fx.handler.gift_pose
					check(pose!=null and fx.mouse_filter==Control.MOUSE_FILTER_IGNORE,"gift rig exists and does not block input")
					if e.stage=="travel":
						check(pose.cards.size()==count,"exact selected cards are packed")
						if viewer==actor/3:check(pose.cards.map(func(c):return c.node.card.id)==values,"packing keeps click order and original card faces")
						else:check(pose.cards.all(func(c):return c.node.card.is_empty()),"opponent packing shows card backs")
						fx.present(.5);check(pose.cards.all(func(c):return c.original.visible and not c.node.visible),"original hand cards stay visible before departure")
						fx.present(.95);check(pose.cards[0].node.z_index>pose.box.front.z_index,"ascending card stays outside the opaque box")
						fx.present(1.63)
						var card=pose.cards[0]
						check(card.center.y+card.node.size.y*card.node.scale.y*.5<pose.box.position.y-33,"entire card clears rim before insertion")
						check(card.node.z_index<pose.box.front.z_index,"rim masks only the final insertion")
						fx.present(1.98)
						check(pose.cards[0].center.y+pose.cards[0].node.size.y*pose.cards[0].node.scale.y*.5<pose.box.position.y+59,"card does not emerge through box bottom")
						fx.present(2.94);check(pose.cards.all(func(c):return not c.node.visible and not c.original.visible),"all selected cards fully inside closed box")
					else:
						fx.present(1.99);check(pose.box.opened>.99,"box opens at the recipient before cards emerge")
						check(pose.box.position.distance_to(pose.Box.dock(target,viewer))<.01,"parcel docks by the actual recipient in either viewpoint")
		elif e.kind=="draw_cards":
			if e.stage=="travel":
				drawers+=1;check(cues.size()==accepted,"only accepted cards play unpacking sounds")
				var placement=sound.cues_for(left).filter(func(c):return c.get("category","")=="card_movement")
				check(placement.size()==accepted,"only accepted cards play landing sounds")
				for i in range(e.draws.size()):
					var d=e.draws[i]
					check(d.origin.kind=="gift_box" and not d.placement,"accepted cards emerge from the actual parcel")
					check(is_equal_approx(placement[i].delay,(d.starts[0]+d.durations[0])/1000.0),"landing sound coincides with the real card arrival")
				if with_ui:
					for viewer in [0,1]:
						await show_game(g,viewer)
						var fx=meta(main,"draw_animation",e.id);fx.set_process(false);fx.clock_started=-1
						check(fx.flights.size()==accepted and fx.gift_boxes.size()==1,"one gift box and only accepted flights")
						fx.elapsed=0.;fx._process(0)
						check(fx.flights.all(func(f):return not f.node.visible),"no flash of already placed incoming cards")
						if viewer!=target/3:check(fx.flights.all(func(f):return f.node.card.is_empty()),"recipient enemy cards remain hidden")
						fx.elapsed=e.travel_ms/1000.;fx._process(0)
						check(fx.flights.all(func(f):return f.landed and f.node.visible),"accepted physical cards finish in recipient hand")
		elif e.kind=="pawn_speech":
			speeches+=1;check(cues.is_empty(),"full hand speech has no rejected-card sound")
		g.advance_animation()
	check(effects==2 and drawers==int(accepted>0) and speeches==int(count>room),"one complete gift with correct arrival and overflow phases")
	check(g.characters[target].hand.size()==8-room+accepted and g.characters[actor].hand.size()==1,"hand counts conserve accepted and unselected cards")
	check(values.slice(accepted).all(func(id):return g.discard.has(id)),"only excess chosen cards are discarded")
	check(g.phase=="review","full gift resolves normally")
func _run():
	root.size=Vector2i(1440,960)
	sound=Audio.new();root.add_child(sound);sound.set_process(false);sound.settings_path="res://test-results/gift-audio.cfg"
	sound.cue_played.connect(func(file,offset):played.append(file))
	for key in ["unfold","pack_0","pack_1","close","carry","open","unpack_0","unpack_1"]:
		var resource=load(sound.support_bank.cards.gift[key])
		check(resource is AudioStreamWAV and resource.mix_rate==48000 and resource.stereo,"approved PCM included: "+key)
		check(resource.loop_mode==AudioStreamWAV.LOOP_DISABLED,"one-shot sound: "+key)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.player.stop();main.attack_audio.level=0.
	for actor in range(6):
		for enemy in [false,true]:
			var target=(actor+1)%3+(3*(1-actor/3) if enemy else 3*(actor/3))
			for count in [1,2]:
				for room in [0,1,3]:await scenario(actor,target,count,room,room==3 and count==2 or actor==0 and enemy and room<2)
	sound.reset();sound.sync_view(clock_view,Time.get_ticks_msec())
	check(played.size()==1 and played[0].ends_with("/unfold.wav"),"one opening sound on start")
	sound.stage_started=Time.get_ticks_msec()-700;sound._process(0)
	check(played.size()==2 and played[1].ends_with("/pack_0.wav"),"paper sound waits for actual first departure")
	sound.sync_view(clock_view,Time.get_ticks_msec());sound._process(0)
	check(played.size()==2,"repeated network snapshot does not replay sounds")
	sound.set_level(0);check(sound.voices.all(func(v):return v.volume_db<=-79.9),"mute affects gift audio")
	sound.reset();played.clear();sound.sync_view(clock_view,Time.get_ticks_msec()-6000)
	check(played.is_empty(),"stale animation does not replay expired audio")
	print("GIFT_INSTALL_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();sound.queue_free();await frames();quit(0 if failures==0 else 1)
