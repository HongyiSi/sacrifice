extends "res://tests/v0174_ui_test.gd"
const Audio=preload("res://scripts/attack_audio.gd")
var played=[]
var sound
var clock_view={}
func walk(n):
	var out=[n]
	for child in n.get_children():out.append_array(walk(child))
	return out
func start_case(actor,count,hp=8):
	var g=H.fixture(8);serial+=1;g.match_id=serial
	g.characters[actor].hp=hp;g.presentation_enabled=true;g.resolution_presentation_enabled=true
	var card=H.give(g,actor,"bloodletting")
	for i in range(count):g.characters[actor].hand.append(g.deck.pop_front())
	H.begin(g,{actor:card},false)
	return g
func own(cues):return cues.filter(func(c):return "/sfx/bloodletting/" in c.file)
func rules_audio(actor,count):
	var g=start_case(actor,count);var stabs=0;var drawers=0
	for i in range(80):
		if g.animation.is_empty():break
		var e=g.animation;var left=g.snapshot(0);var right=g.snapshot(1)
		var cues=own(sound.cues_for(left))
		check(cues==own(sound.cues_for(right)),"public sound timing matches for both clients")
		if e.get("style","")=="bloodletting" and e.kind=="card_effect":
			if e.stage=="travel":
				check(g.characters[actor].hp==8 and e.travel_ms==1200,"HP unchanged until blade contact")
				check(cues.size()==1 and cues[0].file.ends_with("/knife.wav"),"one lift/stab sound")
			else:
				stabs+=1;check(g.characters[actor].hp==7 and e.impact_ms==2600,"one life lost on contact")
				check(cues.size()==2 and is_equal_approx(cues[0].delay,.8) and is_equal_approx(cues[1].delay,1.56),"flick then lock/open cues retain approved timing")
				if clock_view.is_empty():clock_view=left.duplicate(true)
		elif e.kind=="draw_cards" and e.stage=="travel":
			drawers+=1;var accepted=mini(5,8-count)
			check(cues.size()==accepted+(1 if accepted>0 else 0),"only accepted cards emit paper plus lid close")
			var placements=sound.cues_for(left).filter(func(c):return c.get("category","")=="card_movement")
			check(placements.size()==accepted,"no placement sound for rejected cards")
			var d=e.draws[0]
			for j in range(accepted):
				check(is_equal_approx(cues[j].delay,d.starts[j]/1000.0+.07),"paper sound follows real extraction")
				check(is_equal_approx(placements[j].delay,(d.starts[j]+d.durations[j])/1000.0),"placement sound exactly on arrival")
		else:check(cues.is_empty(),"no duplicate bloodletting sounds outside its events")
		g.advance_animation()
	check(stabs==1 and drawers==1 and g.phase=="review","full real effect resolves once")
	check(g.characters[actor].hp==7 and g.characters[actor].hand.size()==mini(8,count+5),"HP and hand outcomes unchanged")
func ui_case(actor,count):
	var g=start_case(actor,count)
	for i in range(80):
		if g.animation.is_empty():break
		var e=g.animation
		if e.kind=="card_effect" and e.get("style","")=="bloodletting":
			for viewer in [0,1]:
				await show_game(g,viewer)
				var effects=walk(main).filter(func(n):return n.has_meta("cinema_effect"))
				check(effects.size()==1,"one effect visible to each viewer")
				var fx=effects[0];fx.set_process(false)
				var dagger=walk(fx).filter(func(n):return n.has_meta("bloodletting_dagger"))
				check(dagger.size()==1 and dagger[0].region_enabled,"one unchanged atlas dagger")
				check(fx.mouse_filter==Control.MOUSE_FILTER_IGNORE,"animation never blocks input")
				if e.stage=="travel":
					fx.present(.6)
					check(fx.source_widget.motif_alpha<.01,"no duplicate dagger on source card")
					check(dagger[0].material.get_shader_parameter("blood")==0.0,"clean blade before stab")
				else:
					fx.present(.55)
					check(dagger[0].material.get_shader_parameter("blood")>.99,"small stain after withdrawal")
					fx.present(2.55)
					check(fx.source_widget.motif_alpha>.99 and dagger[0].modulate.a<.01,"dagger returns without duplicate image")
		elif e.kind=="draw_cards" and e.stage=="travel":
			for viewer in [0,1]:
				await show_game(g,viewer)
				check(walk(main).filter(func(n):return n.has_meta("bloodletting_dagger")).is_empty(),"dagger removed before cards leave chest")
				var fx=meta(main,"draw_animation",e.id);fx.set_process(false);fx.clock_started=-1
				var accepted=mini(5,8-count)
				check(fx.chest_preopened and fx.flights.size()==accepted,"open chest continues into real accepted flights")
				fx.elapsed=0.;fx._process(0)
				check(fx.flights.all(func(f):return not f.landed),"no premature landed incoming cards")
				if viewer!=actor/3:check(fx.flights.all(func(f):return f.node.card.is_empty()),"opponent card faces stay private")
				fx.elapsed=e.travel_ms/1000.;fx._process(0)
				check(fx.flights.all(func(f):return f.landed and f.node.visible),"accepted cards settle in real hand")
				check(fx.speeches.has(actor)==(count>3),"full-hand notice only when needed")
				var closes=own(sound.cues_for(g.snapshot(viewer))).filter(func(c):return c.file.ends_with("/close.wav"))
				if accepted>0:check(closes.size()==1 and is_equal_approx(closes[0].delay,fx.chest_last+.015),"lid sound follows actual close even when overflow speech extends it")
		g.advance_animation()
func _run():
	sound=Audio.new();root.add_child(sound);sound.set_process(false)
	sound.settings_path="res://test-results/bloodletting-audio.cfg"
	sound.cue_played.connect(func(file,offset):played.append(file))
	for key in ["knife","flourish","open","deal_0","deal_1","deal_2","close"]:
		var resource=load(sound.support_bank.cards.bloodletting[key])
		check(resource is AudioStreamWAV and resource.mix_rate==48000 and resource.stereo,"approved stereo PCM imported: "+key)
		check(resource.loop_mode==AudioStreamWAV.LOOP_DISABLED,"one-shot audio: "+key)
	for actor in [0,3]:
		for count in [0,3,7,8]:rules_audio(actor,count)
	sound.reset();sound.sync_view(clock_view,Time.get_ticks_msec())
	check(played.is_empty(),"no premature flourish on stab")
	sound.stage_started=Time.get_ticks_msec()-810;sound._process(0)
	check(played.size()==1 and played[0].ends_with("/flourish.wav"),"flourish at its actual cue")
	sound.sync_view(clock_view,Time.get_ticks_msec());sound._process(0)
	check(played.size()==1,"snapshot refresh does not restart sounds")
	sound.stage_started=Time.get_ticks_msec()-1570;sound._process(0)
	check(played.size()==2 and played[1].ends_with("/open.wav"),"chest sound waits for lock arrival")
	sound.set_level(0);check(sound.voices.all(func(p):return p.volume_db<=-79.9),"mute affects existing voices")
	sound.reset();played.clear();sound.sync_view(clock_view,Time.get_ticks_msec()-5000)
	check(played.is_empty(),"stale snapshot cannot replay expired audio")
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.player.stop();main.attack_audio.level=0
	for actor in range(6):await ui_case(actor,3)
	root.size=Vector2i(960,640)
	for actor in [1,4]:
		for count in [7,8]:await ui_case(actor,count)
	print("BLOODLETTING_INSTALL_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();sound.queue_free();await frames();quit(0 if failures==0 else 1)
