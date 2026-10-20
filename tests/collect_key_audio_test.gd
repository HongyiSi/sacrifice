extends SceneTree
const H=preload("res://tests/helpers.gd")
const Cases=preload("res://tests/art_scenarios.gd")
var sound
var checks=0
var failures=0
var played=[]
func _initialize():run.call_deferred()
func check(ok,label):
	checks+=1
	if not ok:failures+=1;push_error("COLLECT_KEY_AUDIO_FAIL "+label)
func run():
	sound=load("res://scripts/attack_audio.gd").new();root.add_child(sound);sound.set_process(false)
	sound.settings_path="res://test-results/collect-key-audio.cfg";sound.level=.5
	sound.cue_played.connect(func(file,offset):played.append({"file":file,"offset":offset}))
	var bank=sound.support_bank.cards.collect
	for entry in [["mechanism",.83],["open",.70],["peek",.87]]:
		var clip=load(bank[entry[0]])
		check(clip is AudioStreamWAV and clip.mix_rate==48000 and clip.stereo and clip.format==AudioStreamWAV.FORMAT_16_BITS,"approved PCM quality")
		check(clip.loop_mode==AudioStreamWAV.LOOP_DISABLED and is_equal_approx(clip.get_length(),entry[1]),"natural one-shot duration")
	var example={}
	for mode in ["ready","blocked","empty","divinity"]:
		var pair=Cases.setup("collect",103200+checks);var g=pair[0]
		if mode=="empty":g.deck.clear();g.discard.clear()
		elif mode=="blocked":
			var id=H.give_death(g,3,"prison");g._activate({"actor":3,"card":id},0)
		elif mode=="divinity":
			var id=H.give_death(g,1,"divinity");g.characters[1].hp=0;g._activate({"actor":1,"card":id},1)
		for step in range(80):
			if g.animation.get("op","")=="collect_launch":break
			var error=Cases.step(g,pair[1]);check(error.is_empty(),"scenario progresses")
		check(g.animation.get("draw_mode","")==mode,"real rules identify "+mode)
		var view=g.snapshot(0);var cues=sound.cues_for(view)
		check(cues==sound.cues_for(g.snapshot(1)),"both viewers share public sound: "+mode)
		check(cues.size()==(1 if mode=="blocked" else 2),"only actual chest motion has audio: "+mode)
		check(cues[0].file==bank.mechanism and is_equal_approx(cues[0].delay,.731),"key insertion aligns with contact")
		if mode!="blocked":
			check(cues[1].file==bank["open" if mode=="ready" else "peek"],"correct lid action")
			check(is_equal_approx(cues[1].delay,1.326 if mode=="ready" else 1.105),"lid sound aligns with opening")
		check(cues.all(func(c):return c.gain==2. and not c.cut_with_stage),"preview gain and natural tails")
		check(cues.all(func(c):return not c.file.ends_with("collect_success.ogg")),"old chime removed")
		if mode=="ready":example=view.duplicate(true)
		g.advance_animation();check(sound.cues_for(g.snapshot(0)).is_empty(),"impact does not repeat unlocking")
	# Actual playback, delayed state delivery and UI rebuild deduplication.
	await create_timer(2.1).timeout
	sound.sync_view(example,Time.get_ticks_msec());check(played.is_empty() and sound.pending.size()==2,"no sound on key lift")
	sound.stage_started=Time.get_ticks_msec()-720;sound._process(0);check(played.is_empty(),"silent before key reaches lock")
	sound.stage_started=Time.get_ticks_msec()-745;sound._process(0);check(played.size()==1 and played[0].file==bank.mechanism,"key contact starts actual audio")
	for i in range(3):sound.sync_view(example.duplicate(true),Time.get_ticks_msec())
	check(played.size()==1 and sound.pending.size()==1,"rebuild neither duplicates nor cancels remaining lid sound")
	sound.stage_started=Time.get_ticks_msec()-1340;sound._process(0)
	check(played.size()==2 and played[1].file==bank.open,"lid opening starts actual audio")
	check(sound.voices.filter(func(p):return p.playing).all(func(p):return is_equal_approx(p.volume_db,0.)),"default volume matches approved preview")
	example.animation.stage="impact";sound.sync_view(example,Time.get_ticks_msec())
	check(sound.voices.filter(func(p):return p.playing).size()==2,"natural tails survive stage rebuild")
	sound.set_level(0);check(sound.voices.all(func(p):return p.volume_db<=-79.),"mute applies to voices")
	sound.set_level(.25);check(sound.voices.filter(func(p):return p.playing).all(func(p):return is_equal_approx(p.volume_db,linear_to_db(.5))),"volume slider scales both stems")
	sound.reset();played.clear();example.animation.stage="travel"
	sound.sync_view(example,Time.get_ticks_msec()-1000)
	check(played.size()==1 and absf(played[0].offset-.269)<.03,"late snapshot seeks into key sound")
	sound.reset();played.clear();sound.sync_view(example,Time.get_ticks_msec()-2100)
	check(played.is_empty() and sound.pending.is_empty(),"expired snapshot does not replay completed sounds")
	sound.reset();sound.sync_view(example,Time.get_ticks_msec());sound.sync_view({},0)
	sound.stage_started=Time.get_ticks_msec()-1400;sound._process(0)
	check(played.is_empty() and sound.pending.is_empty(),"leaving cancels pending sounds")
	sound.queue_free();await process_frame
	print("COLLECT_KEY_AUDIO_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
