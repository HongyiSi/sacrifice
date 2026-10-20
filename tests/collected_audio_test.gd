extends SceneTree
const H=preload("res://tests/helpers.gd")
const Cases=preload("res://tests/v011_scenarios.gd")
const AMULETS=["holy_amulet","attack_amulet","magic_amulet"]
const KEYS=["collect","gambler","prophecy","mirror","divinity"]+AMULETS
var main
var sound
var checks:=0
var failures:=0
var serial:=260600
var played:Array=[]
var saved:Dictionary={}

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("COLLECTED_AUDIO_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func frames()->void:
	for i in range(3):await process_frame
func fixture(key:String,reaction:bool=true):
	var g=H.fixture();serial+=1;g.match_id=serial
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	if key=="divinity":
		H.give_death(g,0,key);g.characters[0].hp=0;g.characters[0].death_round=g.round_number;H.begin(g,{})
	elif key in AMULETS and reaction:
		H.give(g,0,key);H.begin(g,{3:H.give(g,3,"magic_strike" if key=="magic_amulet" else "strike")})
	else:
		H.give(g,0,"strike")
		var choices:Dictionary={0:H.give(g,0,key)}
		if key=="mirror":choices[3]=H.give(g,3,"strike")
		H.begin(g,choices)
	return g
func own(cues:Array)->Array:
	return cues.filter(func(c):return "/sfx/collected/" in c.file or "/sfx/amulets/" in c.file or "/sfx/collect_key/" in c.file or "/sfx/prophecy/" in c.file)
func show(view:Dictionary)->void:
	main.session.team=0;main.session.state=view;main.session.state.names=["音效验证","对手"]
	main.session.changed.emit();await frames()
func walk(g,key:String,decline:bool=false,expected:int=1)->void:
	var count:=0
	for i in range(160):
		var view:Dictionary=g.snapshot(0)
		var cues:Array=own(sound.cues_for(view))
		check(cues==own(sound.cues_for(g.snapshot(1))),"both viewers: "+key)
		if not cues.is_empty():
			count+=cues.size()
			if not saved.has(key):saved[key]=view.duplicate(true)
			var e:Dictionary=g.animation
			check(cues.size()==(2 if key=="collect" else 1),"expected clips per effect: "+key)
			check(not cues[0].cut_with_stage,"natural tail retained: "+key)
			match key:
				"collect":check(e.kind=="card_effect" and e.op=="collect_launch" and e.stage=="travel" and is_equal_approx(cues[0].delay,.731) and is_equal_approx(cues[1].delay,1.326),"collect key and lid synchronize to native motion")
				"gambler":check(e.kind=="card_effect" and e.op=="discard_all" and e.stage=="travel" and is_equal_approx(cues[0].delay,.308),"dice sound starts after lift at 308ms")
				"prophecy":
					if cues[0].file.ends_with("pages.wav"):
						check(e.kind=="card_effect" and e.style=="prophecy" and e.op=="chosen" and e.stage=="travel","page turn only after predicting health")
						check(cues[0].delay==0. and cues[0].gain==2. and e.travel_ms==850,"approved timing and gain retained")
					else:check(e.stage=="impact","original prophecy chime at application or reward")
				"mirror":check(e.kind=="card_effect" and e.stage=="impact" and cues[0].delay==0,"mirror ripple at binding/copy contact")
				"divinity":check(e.kind=="divinity_awaken" and e.stage=="travel" and is_equal_approx(cues[0].delay,.6),"divinity sound waits until pawn lift at 600ms")
				_:
					check(e.kind=="shield_block" and e.has("cancelled_style"),"amulet sound only for accepted cancellation")
					check(cues[0].file.ends_with("_"+e.stage+".wav"),"correct charge, burn or actual discard stem")
					check(is_equal_approx(cues[0].delay,1.08 if e.stage=="travel" else .03 if e.stage=="discard" else 0.),"sound matches approved action timing")
					check(cues[0].gain==2.,"approved preview amplitude at default volume")
			var n:=played.size()
			await show(view)
			if cues[0].delay>0:check(played.size()==n,"delayed cue stays silent before its visual action: "+key)
			if cues[-1].delay>0:await create_timer(cues[-1].delay+.05).timeout
			for cue in cues:check(played.slice(n).filter(func(p):return p.file==cue.file).size()==1,"each scheduled clip emits once: "+key)
			check(played.slice(n).filter(func(p):return p.file==cues[0].file).size()==1,"actual player emits once: "+key)
			check(sound.voices.any(func(p):return p.playing and p.stream.resource_path==cues[-1].file),"latest audio voice is playing: "+key)
			n=played.size();main._schedule_render();await frames();main._schedule_render();await frames()
			check(played.size()==n,"redraw does not replay: "+key)
		if g.phase in ["review","ended"] and g.animation.is_empty():break
		var error:String=g.respond(g.request.team,0) if decline and g.phase=="responding" else Cases.step(g)
		check(error.is_empty(),"scenario progresses: "+key+" "+error)
	check(count==expected,"expected supplied clip count %d, got %d: %s"%[expected,count,key])

func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.25).timeout
	main.session.set_process(false);main.music.player.stop();sound=main.attack_audio
	sound.settings_path="res://test-results/collected-sound.cfg";sound.set_level(.5)
	sound.cue_played.connect(func(file,offset):played.append({"file":file,"offset":offset}))
	var files:Dictionary={}
	for key in KEYS:
		for slot in ["rise","travel","impact","discard","mechanism","open","peek"]:
			var path:String=sound.support_bank.cards[key].get(slot,"")
			if not path.is_empty():files[path]=true
	check(files.size()==17,"four established sounds, three chest stems, nine amulet stems and one page recording")
	for path in files:
		var clip=load(path)
		check(clip!=null and clip.get_length()>.35 and (clip.loop_mode==AudioStreamWAV.LOOP_DISABLED if clip is AudioStreamWAV else not clip.loop),"imported, nonlooping clip: "+path)
	for key in KEYS:
		var g=fixture(key)
		await walk(g,key,false,3 if key in AMULETS or key=="prophecy" else 2 if key in ["collect","mirror"] else 1)
		if key=="divinity":
			g.phase="resolution";g.turn_stage="resolution";g._push([{"op":"draw","target":3,"count":1}]);g._pump()
			check(g.animation.get("kind","")=="divinity_pulse" and own(sound.cues_for(g.snapshot(0))).is_empty(),"draw radiance does not replay the ascension sound")
	# The old trigger boundaries must now be silent.
	var collect:Dictionary=saved.collect.duplicate(true);collect.animation.stage="impact"
	check(own(sound.cues_for(collect)).is_empty(),"deck contact does not replay collect")
	collect.animation.stage="travel";collect.animation.travel_ms=3400
	check(is_equal_approx(own(sound.cues_for(collect))[0].delay,1.462) and is_equal_approx(own(sound.cues_for(collect))[1].delay,2.652),"key and lid cues follow animation duration")
	var mirror:Dictionary=saved.mirror.duplicate(true);mirror.animation.stage="travel"
	check(own(sound.cues_for(mirror)).is_empty(),"mirror launch stays silent")
	# Exercise the real pose clock on each side of the audio start boundary.
	var angel=preload("res://scripts/divinity_pose.gd").new()
	angel.started=Time.get_ticks_msec()-550;angel._process(0)
	check(angel.lift==0,"divinity pawn is grounded before sound onset")
	angel.started=Time.get_ticks_msec()-700;angel._process(0)
	check(angel.lift>0,"divinity pawn lifts after sound onset");angel.free()
	for key in AMULETS:
		await walk(fixture(key,false),key,false,0)
		await walk(fixture(key),key,true,0)
	# Ordinary shield contact must not borrow the new amulet burning sound.
	var shield=H.fixture();shield.presentation_enabled=true;shield.characters[0].shield=1
	H.begin(shield,{3:H.give(shield,3,"strike")})
	await walk(shield,"defense",false,0)
	# Leaving during a delayed dice cue must never produce a late sound.
	sound.reset();var dice:Dictionary=saved.gambler.duplicate(true);dice.match=991001
	var n:=played.size();sound.sync_view(dice,Time.get_ticks_msec())
	check(sound.pending.size()==1,"dice cue waits for rolling")
	sound.sync_view({},0);await create_timer(.4).timeout
	check(played.size()==n and sound.pending.is_empty(),"leaving cancels pending dice sound")
	# A late snapshot starts at the correct audio offset rather than replaying.
	dice.match=991002;sound.sync_view(dice,Time.get_ticks_msec()-500)
	check(played.size()==n+1 and absf(played[-1].offset-.192)<.03,"late snapshot seeks into rolling sound")
	sound.reset()
	var burn:Dictionary=saved.holy_amulet.duplicate(true);burn.match=991003;burn.animation.stage="impact"
	sound.sync_view(burn,Time.get_ticks_msec());await frames()
	var voices:Array=sound.voices.filter(func(p):return p.playing and p.stream.resource_path.ends_with("holy_amulet_impact.wav"))
	check(voices.size()==1,"one burn voice")
	if not voices.is_empty():
		burn.animation.stage="discard";sound.sync_view(burn,Time.get_ticks_msec());await frames()
		check(voices[0].playing,"burn decay survives transition to discard")
		sound.set_level(0);check(voices[0].volume_db<=-79,"existing SFX mute controls new sounds")
		sound.set_level(.5)
		check(is_equal_approx(voices[0].volume_db,0.),"volume slider restores amulet gain")
	# A defiled amulet returns silently to hand, without a discard cue.
	for key in AMULETS:
		var retained=preload("res://tests/amulet_hand_scenarios.gd").setup(key,0,991010+AMULETS.find(key),true)
		retained.respond(0,retained.request.options[0]);await walk(retained,key,false,2)
	sound.sync_view({},0);check(sound.voices.all(func(p):return not p.playing),"leaving stops all voices")
	print("COLLECTED_AUDIO_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
