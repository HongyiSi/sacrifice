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
	if not ok:failures+=1;push_error("IGNORE_AUDIO_FAIL "+label)
func run():
	sound=Audio.new();root.add_child(sound);sound.set_process(false)
	sound.settings_path="res://test-results/ignore-audio.cfg"
	sound.cue_played.connect(func(file,offset):played.append({"file":file,"offset":offset}))
	var bank=sound.support_bank.cards.ignore
	for entry in [["travel",1.28],["impact",.90]]:
		var clip=load(bank[entry[0]])
		check(clip is AudioStreamWAV,"approved stem imports as PCM")
		check(clip.mix_rate==48000 and clip.stereo and clip.format==AudioStreamWAV.FORMAT_16_BITS,"approved quality retained")
		check(clip.loop_mode==AudioStreamWAV.LOOP_DISABLED and is_equal_approx(clip.get_length(),entry[1]),"natural one-shot length retained")
	var example={}
	for actor in range(6):
		var g=H.fixture(8);g.match_id=103600+actor;g.presentation_enabled=true;g.resolution_presentation_enabled=true
		H.begin(g,{actor:H.give(g,actor,"ignore")},false)
		for step in range(16):
			if g.animation.is_empty():break
			check(sound.cues_for(g.snapshot(0)).is_empty() and sound.cues_for(g.snapshot(1)).is_empty(),"no effect sound during card reveal or introduction")
			g.advance_animation()
		check(g.phase=="choosing","waits for real priority selection")
		check(g.choose(actor/3,2).is_empty(),"first choice accepted")
		check(sound.cues_for(g.snapshot(0)).is_empty() and sound.cues_for(g.snapshot(1)).is_empty(),"first choice stays silent for both viewers")
		check(not g.choose(actor/3,2).is_empty() and g.animation.is_empty(),"rejected duplicate does not start sound")
		check(g.choose(actor/3,5).is_empty(),"second distinct choice accepted")
		var stages=[]
		for step in range(8):
			if g.animation.is_empty():break
			var event=g.animation.duplicate(true)
			if event.get("style","")!="ignore" or event.get("op","")!="chosen":break
			stages.append(event.stage)
			var cues=sound.cues_for(g.snapshot(0))
			check(cues==sound.cues_for(g.snapshot(1)),"both viewers hear the same public cues for all six pawns")
			check(cues.size()==1 and cues[0].file==bank[event.stage],"one correct stem for actual stage")
			check(cues[0].delay==0 and cues[0].gain==2. and not cues[0].cut_with_stage,"approved timing, gain and natural tail")
			check(event.travel_ms==850 and event.impact_ms==700 and event.values==[2,5],"original animation timings and choices retained")
			if event.stage=="travel":
				check(g.skipped.is_empty(),"no premature priority effect")
				if actor==0:example=g.snapshot(0).duplicate(true)
			else:check(g.skipped.has(2) and g.skipped.has(5),"priority effect resolves at impact")
			g.advance_animation()
		check(stages==["travel","impact"],"one cast and one landing per resolved Ignore")
	# Actual players, repeated states, delayed snapshots and overlapping tails.
	sound.reset();played.clear();sound.level=.5
	sound.sync_view(example,Time.get_ticks_msec())
	check(played.size()==1 and played[0].file==bank.travel,"player starts bookmarks immediately")
	var voice=sound.voices.filter(func(p):return p.stream!=null and p.playing)[0]
	check(absf(voice.volume_db)<.001,"default volume matches approved audition")
	for i in range(4):sound.sync_view(example.duplicate(true),Time.get_ticks_msec())
	check(played.size()==1,"duplicate network states do not replay")
	example.animation.stage="impact"
	sound.sync_view(example,Time.get_ticks_msec())
	check(played.size()==2 and played[1].file==bank.impact,"landing starts on actual impact stage")
	check(voice.playing,"paper tail survives stage rebuild")
	sound.set_level(0)
	check(sound.voices.all(func(p):return p.volume_db<=-79.9),"mute applies to all active tails")
	sound.set_level(.25)
	check(sound.voices.filter(func(p):return p.playing).all(func(p):return is_equal_approx(p.volume_db,linear_to_db(.5))),"volume updates overlapping stems")
	sound.reset();played.clear();example.animation.stage="travel"
	await create_timer(1.31).timeout
	sound.sync_view(example,Time.get_ticks_msec()-400)
	check(played.size()==1 and played[0].offset>=.39 and played[0].offset<.5,"late snapshot seeks to synchronized sound position")
	sound.reset();played.clear()
	sound.sync_view(example,Time.get_ticks_msec()-1300)
	check(played.is_empty(),"expired stage does not replay a finished stem")
	var unrelated=example.duplicate(true);unrelated.animation.op="ask"
	check(sound.cues_for(unrelated).is_empty(),"selection operation stays silent")
	unrelated.animation={}
	check(sound.cues_for(unrelated).is_empty(),"persistent priority state does not loop")
	sound.reset();check(sound.pending.is_empty() and sound.voices.all(func(p):return not p.playing),"reset clears sound and pending playback")
	sound.queue_free();await process_frame
	print("IGNORE_AUDIO_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
