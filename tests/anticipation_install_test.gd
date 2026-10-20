extends "res://tests/v0174_ui_test.gd"
const Audio=preload("res://scripts/attack_audio.gd")
const Mark=preload("res://scripts/anticipation_mark.gd")
const Cases=preload("res://tests/art_scenarios.gd")
var sound
var played=[]
var clock_travel={}
var clock_impact={}
var clock_failed={}
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("ANTICIPATION_INSTALL_FAIL "+label)
func walk(node):
	var out=[node]
	for child in node.get_children():out.append_array(walk(child))
	return out
func own(cues):return cues.filter(func(c):return "/sfx/anticipation/" in c.file)
func marks():return walk(main).filter(func(n):return n.has_meta("anticipation_mark"))
func make_game(actor,mode):
	var g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=true;g.resolution_presentation_enabled=true
	var enemy=3*(1-actor/3);var plan={actor:H.give(g,actor,"anticipation")}
	if mode=="mixed":
		plan[enemy]=H.give(g,enemy,"warcry");plan[enemy+1]=H.give(g,enemy+1,"badge")
	elif mode!="empty":
		plan[enemy]=H.give(g,enemy,"triple_strike" if mode=="failure" else "magic_strike")
		plan[enemy+1]=H.give(g,enemy+1,"magic_strike" if mode=="failure" else "late_suppress")
		plan[enemy+2]=H.give(g,enemy+2,"peek")
	H.begin(g,plan,false)
	var context={"key":"anticipation","target_index":0,"targets":[],"follow":false}
	for i in range(80):
		if g.animation.get("op","")=="anticipation" and g.animation.stage=="travel":return g
		check(Cases.step(g,context)=="","reach real prediction event")
	check(false,"prediction never began");return g
func ui_state(g,viewer,count,applying):
	await show_game(g,viewer)
	var attached=marks();check(attached.size()==count,"one mark per affected card in each viewpoint")
	var view=g.snapshot(viewer)
	for n in walk(main):
		if not n.has_meta("played_action_id"):continue
		var action=view.queue.filter(func(a):return a.id==n.get_meta("played_action_id"))
		if action.is_empty():continue
		var children=n.get_children().filter(func(c):return c.has_meta("anticipation_mark"))
		check(children.size()==int(Mark.applies(view,action[0])),"marker attaches to the actual affected ordinary card")
		if n.get_meta("played_owner",0)/3!=viewer and not n.get_meta("played_revealed",false):check(n.hidden_card and n.card.is_empty(),"enemy identities remain private")
	for mark in attached:
		mark.set_process(false)
		check(mark.mouse_filter==Control.MOUSE_FILTER_IGNORE and mark.brushes.size()==2,"brush overlay does not consume clicks")
		check(mark.active==applying,"settled mark does not restart its reveal")
		if applying:
			mark.present(0.);check(mark.brushes.all(func(b):return not b.visible),"cross does not flash before first brush contact")
			mark.present(.29);check(mark.brushes[0].visible and not mark.brushes[1].visible,"first stroke finishes before the second starts")
			mark.present(.55);check(mark.brushes.all(func(b):return b.visible and is_equal_approx(b.material.get_shader_parameter("reveal"),1.)),"both approved brush textures finish drawing")
		else:
			mark.present(0.);check(mark.brushes.all(func(b):return b.visible and is_equal_approx(b.material.get_shader_parameter("reveal"),1.)),"persistent mark remains fully drawn after a rebuild")
	await RenderingServer.frame_post_draw
func scenario(actor,mode):
	var g=make_game(actor,mode);var enemy=1-actor/3
	var success=mode in ["success","mixed"];var count=1 if mode=="mixed" else 3 if success else 0
	var pending=0 if mode=="empty" else 1 if mode=="mixed" else 3
	var left=g.snapshot(0);var right=g.snapshot(1)
	check(own(sound.cues_for(left))==own(sound.cues_for(right)),"both clients share observation timing")
	var cues=own(sound.cues_for(left));check(cues.size()==1 and cues[0].file.ends_with("/observe.wav"),"observe plays once for all targets")
	check(g.animation.travel_ms==1450 and g.animation.impact_ms==950,"approved timing preserved")
	if actor==0 and mode=="success":clock_travel=left.duplicate(true)
	for viewer in [0,1]:
		await ui_state(g,viewer,0,false)
		var effects=walk(main).filter(func(n):return n.has_meta("cinema_effect"))
		check(effects.size()==1 and effects[0].key=="anticipation","native telescope handles prediction")
		check(effects[0].marked_points.size()==pending,"scans only real, still-unrevealed opposing ordinary cards")
	g.advance_animation();check(g.animation.succeeded==success,"visual success follows authoritative rule result")
	cues=own(sound.cues_for(g.snapshot(0)))
	check(cues==own(sound.cues_for(g.snapshot(1))),"both clients share seal timing")
	check(cues.size()==int(success),"success has one shared seal cue; failure and empty targets have none")
	if success:check(cues[0].file.ends_with("/seal.wav") and not cues[0].cut_with_stage,"seal preserves its natural short tail")
	if actor==0 and mode=="success":clock_impact=g.snapshot(0).duplicate(true)
	if actor==0 and mode=="failure":clock_failed=g.snapshot(0).duplicate(true)
	for viewer in [0,1]:
		await ui_state(g,viewer,count,success)
		var started=main.effect_started
		await show_game(g,viewer)
		check(marks().size()==count and main.effect_started==started,"repeated snapshot neither duplicates marks nor restarts their clock")
	if success:
		check(g.queue.filter(func(a):return a.actor/3==enemy and not a.revealed).size()==count,"all affected hidden cards are represented")
		var view=g.snapshot(actor/3)
		check(view.queue.filter(func(a):return a.actor/3==enemy and not a.revealed).all(func(a):return a.card==0 and a.main==-1 and a.secondary==-1),"cross does not expose hidden card ranks")
		g.advance_animation()
		var context={"key":"anticipation","target_index":0,"targets":[],"follow":false}
		for i in range(100):
			if g.phase=="review":break
			check(Cases.step(g,context)=="","already-revealed cards continue resolving")
		check(g.phase=="review","suppressed cards stay on table through round end")
		for viewer in [0,1]:await ui_state(g,viewer,count,false)
		if actor==0 and mode=="success":
			root.size=Vector2i(960,640);await frames();await ui_state(g,1,count,false)
			root.size=Vector2i(1440,960);await frames()
		g.presentation_enabled=false;g.resolution_presentation_enabled=false;g.advance_round()
		check(not g.reveal_locked_teams[enemy],"round lock clears next round")
		for viewer in [0,1]:await ui_state(g,viewer,0,false)
func special_targets():
	var g=H.fixture(8);serial+=1;g.match_id=serial;g.reveal_locked_teams[1]=true
	var card=H.give(g,3,"strike");g._play_revealed_hand(3,[card],"疯狂")
	check(not g.queue[0].revealed and g.queue[0].status=="suppressed","future forced play remains locked")
	for viewer in [0,1]:
		var view=g.snapshot(viewer);check(Mark.applies(view,view.queue[0]),"future forced card inherits blue cross")
		var a=view.queue[0].duplicate(true);a.death=true;check(not Mark.applies(view,a),"death cards never get prediction cross")
		a.death=false;a.revealed=true;check(not Mark.applies(view,a),"already revealed ordinary cards never get cross")
		a.revealed=false
		for status in ["removed","returned","cancelled"]:a.status=status;check(not Mark.applies(view,a),"removed, returned or cancelled cards do not retain a cross")
func _run():
	root.size=Vector2i(1440,960);DirAccess.make_dir_recursive_absolute("res://test-results")
	sound=Audio.new();root.add_child(sound);sound.set_process(false);sound.settings_path="res://test-results/anticipation-audio.cfg"
	sound.cue_played.connect(func(file,offset):played.append(file))
	for key in ["observe","seal"]:
		var resource=load(sound.support_bank.cards.anticipation[key])
		check(resource is AudioStreamWAV and resource.mix_rate==48000 and resource.stereo,"approved stereo PCM loads")
		check(resource.format==AudioStreamWAV.FORMAT_16_BITS and resource.loop_mode==AudioStreamWAV.LOOP_DISABLED,"approved one-shot format preserved")
	check(Mark.BRUSH.get_image().has_mipmaps(),"brush texture is filtered cleanly at actual card size")
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.player.stop();main.attack_audio.level=0.
	for actor in range(6):
		for mode in ["success","failure","empty"]:await scenario(actor,mode)
	for actor in [0,5]:await scenario(actor,"mixed")
	special_targets()
	sound.reset();played.clear();sound.sync_view(clock_travel,Time.get_ticks_msec())
	check(played.size()==1 and played[0].ends_with("/observe.wav"),"real audio scheduler starts observation once")
	sound.sync_view(clock_travel,Time.get_ticks_msec());check(played.size()==1,"repeated travel snapshot does not replay observation")
	sound.sync_view(clock_impact,Time.get_ticks_msec());check(played.size()==2 and played[1].ends_with("/seal.wav"),"real scheduler starts seal only at successful result")
	sound.sync_view(clock_impact,Time.get_ticks_msec());check(played.size()==2,"repeated impact snapshot does not replay seal")
	sound.set_level(0);check(sound.voices.all(func(v):return v.volume_db<=-79.9),"mute affects both new sounds")
	sound.reset();played.clear();sound.sync_view(clock_failed,Time.get_ticks_msec());check(played.is_empty(),"failed prediction never plays success sound")
	sound.reset();sound.sync_view(clock_travel,Time.get_ticks_msec()-5000);check(played.is_empty(),"late stale snapshot does not replay expired observation")
	print("ANTICIPATION_INSTALL_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();sound.queue_free();await frames();quit(0 if failures==0 else 1)
