extends SceneTree
const H=preload("res://tests/helpers.gd")
const Audio=preload("res://scripts/attack_audio.gd")
var sound
var checks:=0
var failures:=0
var played:Array=[]
var playback_view:Dictionary={}
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("GOLD_AUDIO_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func own(cues:Array)->Array:return cues.filter(func(c):return "/sfx/gold_panning/" in c.file)
func fixture(actor:int,count:int,full:bool):
	var g=H.fixture(8);g.match_id=39000+actor*100+count+int(full)*10
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	var card:int=H.give(g,actor,"gold_panning")
	if full:
		for i in range(8):g.characters[actor].hand.append(g.deck.pop_front())
	var selected:Array=[]
	for reject in [true,false]:
		var candidates:Array=g.deck.filter(func(id):return (int(g.catalog[id].main) in [3,4,5,6])==reject)
		selected.append_array(candidates.slice(0,count if reject else 5-count))
	for id in selected:g.deck.erase(id)
	for id in selected:g.deck.append(id)
	H.begin(g,{actor:card},false)
	return g
func scenario(actor:int,count:int,full:bool)->void:
	var g=fixture(actor,count,full);var prepared:=0;var filtered:=0
	for step in range(100):
		if g.animation.is_empty():break
		var e:Dictionary=g.animation
		var left:Dictionary=g.snapshot(0);var right:Dictionary=g.snapshot(1)
		var cues:Array=own(sound.cues_for(left))
		check(cues==own(sound.cues_for(right)),"public audio agrees for both viewers")
		if e.get("style","")=="gold_panning" and e.stage=="travel":
			if e.op=="gold_begin":
				prepared+=1
				check(cues.size()==1 and cues[0].file.ends_with("/prepare.wav"),"prepare only on first shake")
			elif e.op=="gold_filter":
				filtered+=1
				var actual:int=0 if full else count
				check(e.hand_motion.slots.size()==actual,"real rules select only actual filtered cards")
				check(cues.size()==actual+1,"one sieve plus actual paper departures")
				var suffix:String="/filter.wav" if actual==1 else "/filter_%d.wav"%actual
				check(cues[0].file.ends_with(suffix),"duration variant matches count")
				var resource=load(cues[0].file)
				var duration:float=float(e.travel_ms)/1000.0
				check(absf(resource.get_length()-1.95*duration/1.55)<.035,"sound retimed to real animation duration")
				for i in range(actual):
					var c:Dictionary=cues[i+1]
					check(c.file.ends_with("/discard.wav") and is_equal_approx(c.delay,(.12+i*.04)*duration),"paper follows actual departure")
					check(is_equal_approx(c.gain,2.0/sqrt(float(actual))),"paper overlap keeps consistent level")
				var other:Dictionary=g.snapshot(1-actor/3).animation.hand_motion
				check(not other.has("owner_cards") and not other.has("owner_slots"),"sound does not require hidden identities")
				if actor==0 and count==1 and not full:playback_view=left.duplicate(true)
			for cue in cues:check(not cue.cut_with_stage,"natural tail survives stage transition")
		else:check(cues.is_empty(),"intros, draw, impact and unrelated events do not duplicate sieve sounds")
		g.advance_animation()
	check(g.phase=="review","real gold effect finishes")
	check(prepared==1 and filtered==1,"each shake plays once per card")
	check(g.characters[actor].hand.size()==(8 if full else 5-count),"unchanged accepted-hand result")
func _run()->void:
	sound=Audio.new();root.add_child(sound);sound.set_process(false)
	sound.settings_path="res://test-results/gold-panning-sound.cfg"
	sound.cue_played.connect(func(file,offset):played.append({"file":file,"offset":offset}))
	var bank:Dictionary=sound.support_bank.cards.gold_panning
	for key in ["prepare","filter","discard","filter_0","filter_2","filter_3","filter_4","filter_5"]:
		var stream=load(bank[key])
		check(stream is AudioStreamWAV and stream.format==AudioStreamWAV.FORMAT_16_BITS,"lossless PCM imported: "+key)
		check(stream.mix_rate==48000 and stream.stereo and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"stereo48k, no looping: "+key)
	for actor in [0,3]:
		for count in range(6):scenario(actor,count,false)
		scenario(actor,5,true)
	check(not playback_view.is_empty(),"captured real selection for clock test")
	if not playback_view.is_empty():
		sound.reset();played.clear();sound.sync_view(playback_view,Time.get_ticks_msec())
		check(played.size()==1 and played[0].file.ends_with("/filter.wav"),"sieve starts immediately")
		sound.sync_view(playback_view,Time.get_ticks_msec());sound._process(0)
		check(played.size()==1,"refresh does not replay sieve or early paper")
		sound.stage_started=Time.get_ticks_msec()-200;sound._process(0)
		check(played.size()==2 and played[1].file.ends_with("/discard.wav"),"actual delayed paper voice emitted")
		sound.set_level(0)
		check(sound.voices.all(func(p):return p.volume_db<=-79.9),"mute applies to active voices")
		sound.set_level(.5)
		check(sound.voices.filter(func(p):return p.stream!=null).all(func(p):return absf(p.volume_db)<.01),"default volume matches approved single-card mix")
		var before:int=played.size();var impact:Dictionary=playback_view.duplicate(true);impact.animation.stage="impact"
		sound.sync_view(impact,Time.get_ticks_msec())
		check(played.size()==before and sound.voices.any(func(p):return p.playing),"impact preserves tail without replay")
		sound.reset();sound.sync_view(playback_view,Time.get_ticks_msec()-2200)
		check(played.size()==before,"expired snapshot does not replay stale sounds")
	var result:Dictionary={"checks":checks,"failures":failures,"passed":failures==0}
	DirAccess.make_dir_recursive_absolute("res://test-results")
	FileAccess.open("res://test-results/gold-panning-audio.json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print("GOLD_AUDIO_RESULT ",JSON.stringify(result));quit(0 if failures==0 else 1)
