extends SceneTree
const H=preload("res://tests/helpers.gd")
const Audio=preload("res://scripts/attack_audio.gd")
var sound
var checks=0
var failures=0
var played=[]
func _initialize():run.call_deferred()
func check(ok,label):
	checks+=1
	if not ok:failures+=1;push_error("WARCRY_AUDIO_FAIL "+label)
func run():
	sound=Audio.new();root.add_child(sound);sound.set_process(false)
	sound.settings_path="res://test-results/warcry-audio.cfg"
	sound.cue_played.connect(func(file,offset):played.append({"file":file,"offset":offset}))
	var bank=sound.support_bank.cards.warcry
	for entry in [["travel",1.90],["impact",1.05]]:
		var stream=load(bank[entry[0]])
		check(stream is AudioStreamWAV,"sound imported as PCM")
		check(stream.mix_rate==48000 and stream.stereo and stream.format==AudioStreamWAV.FORMAT_16_BITS,"approved quality preserved")
		check(stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and is_equal_approx(stream.get_length(),entry[1]),"one-shot natural duration")
	var example={}
	for actor in range(6):
		var g=H.fixture(8);g.match_id=103100+actor;g.presentation_enabled=true;g.resolution_presentation_enabled=true
		H.begin(g,{actor:H.give(g,actor,"warcry")},false)
		var count=0
		for step in range(16):
			if g.animation.is_empty():break
			var event=g.animation.duplicate(true)
			var cues=sound.cues_for(g.snapshot(0))
			check(cues==sound.cues_for(g.snapshot(1)),"both viewers receive identical public sounds")
			if event.get("op","")=="warcry":
				count+=1
				check(cues.size()==1 and cues[0].file==bank[event.stage],"one correct sound for actual stage")
				check(cues[0].delay==0 and cues[0].gain==2. and not cues[0].cut_with_stage,"approved gain and natural tail")
				check(event.travel_ms==1450 and event.impact_ms==700,"animation timings unchanged")
				if event.stage=="travel":
					check(g.characters[actor].get("warcry_bonus",0)==0,"no premature buff")
					if actor==0:example=g.snapshot(0).duplicate(true)
				else:check(g.characters[actor].warcry_bonus==3,"buff resolves at impact")
			else:check(cues.is_empty(),"no horn on reveal or card intro")
			g.advance_animation()
		check(count==2 and g.characters[actor].warcry_bonus==3,"one cast and one landing per warcry")
		check(g.characters[actor].warcry_round==g.round_number+1,"next-round rule retained")
	# Exercise the real scheduler: rebuilds and repeated network states must not replay.
	sound.reset();played.clear();sound.level=.5
	sound.sync_view(example,Time.get_ticks_msec())
	check(played.size()==1 and played[0].file==bank.travel,"actual player begins cast")
	var call=sound.voices.filter(func(p):return p.stream!=null and p.playing)[0]
	check(absf(call.volume_db)<.001,"default volume matches approved demo")
	for i in range(4):sound.sync_view(example.duplicate(true),Time.get_ticks_msec())
	check(played.size()==1,"repeated state never duplicates sound")
	example.animation.stage="impact"
	sound.sync_view(example,Time.get_ticks_msec())
	check(played.size()==2 and played[1].file==bank.impact,"actual player begins landing")
	check(call.playing,"cast tail survives stage transition")
	sound.set_level(0)
	check(sound.voices.all(func(p):return p.volume_db<=-79.9),"mute applies to ongoing tails")
	sound.set_level(.25)
	check(sound.voices.filter(func(p):return p.playing).all(func(p):return is_equal_approx(p.volume_db,linear_to_db(.5))),"volume applies to both overlapping stems")
	sound.reset();played.clear();example.animation.stage="travel"
	await create_timer(1.95).timeout
	sound.sync_view(example,Time.get_ticks_msec()-400)
	check(played.size()==1 and played[0].offset>=.39 and played[0].offset<.5,"late snapshot seeks into current sound")
	sound.reset();played.clear()
	sound.sync_view(example,Time.get_ticks_msec()-1920)
	check(played.is_empty(),"expired snapshot does not replay a finished horn")
	var unrelated=example.duplicate(true);unrelated.animation.op="chosen"
	check(sound.cues_for(unrelated).is_empty(),"unrelated operation does not trigger horn")
	unrelated.animation={}
	check(sound.cues_for(unrelated).is_empty(),"persistent status does not repeat horn")
	sound.reset();sound.queue_free();await process_frame
	print("WARCRY_AUDIO_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
