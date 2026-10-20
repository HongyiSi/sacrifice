extends SceneTree
const S=preload("res://tests/art_scenarios.gd")
const D=preload("res://scripts/death_audio.gd")
const Styles=preload("res://scripts/strike_styles.gd")
var audio
var checks=0
var failures=0
var coverage={}
var dance_contacts=0
var media={}
var events=[]
var plays=0
func check(ok,label):
	checks+=1
	if not ok:failures+=1;push_error("DEATH_AUDIO_FAIL "+label)
func _initialize():run.call_deferred()
func drain(g,ctx):
	for i in range(250):
		if not g.animation.is_empty():
			var e=g.animation
			var v=g.snapshot(0);var cues=audio.cues_for(v);var added=D.cues(e,audio.support_bank)
			check(cues==audio.cues_for(g.snapshot(1)),"same schedule for both players")
			for cue in added:
				check(cue.delay>=0 and cue.delay<=Styles.duration(e)/1000.,"cue belongs to its visual stage")
				check(not cue.cut_with_stage,"retain natural sound tail")
				media[cue.file]=true
			if not added.is_empty():coverage[ctx.key]=true
			if e.get("style","")=="last_dance" and e.stage=="impact":
				check(added.size()==1 and added[0].delay==0.,"one contact per dance strike")
				dance_contacts+=added.size()
			if e.kind in ["card_start","card_reveal"]:check(added.is_empty(),"never fire effects when revealing")
			if ctx.key in ["immortal","blood_rite","divinity","sacrifice_badges"]:check(added.is_empty(),"keep established death sound unchanged")
			if not added.is_empty():events.append(v)
			g.advance_animation()
		elif g.phase in ["planning","review","ended"]:return
		else:check(S.step(g,ctx).is_empty(),"valid rule selection")
	check(false,"bounded sequence")
func run():
	audio=load("res://scripts/attack_audio.gd").new();root.add_child(audio);audio.set_process(false)
	audio.cue_played.connect(func(_file,_offset):plays+=1)
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/deathrattles.json")):
		var pair=S.setup(c.key,45000+checks);drain(pair[0],pair[1])
		for f in S.followups(pair[0],pair[1]):
			drain(f[0],f[1])
			for second in S.second_followup(f[0],f[1]):drain(second[0],second[1])
	for key in D.KEYS:check(coverage.has(key),"new sound coverage "+key)
	check(coverage.size()==16,"exactly sixteen missing death cards")
	check(dance_contacts==5,"five separate dance contacts")
	for path in media:
		var stream=load(path)
		check(stream is AudioStream and stream.get_length()>0.,"decodable sound asset")
	for key in ["death_sentence","last_dance","life_steal","curse"]:
		for hit in [{"amount":0,"miss":true},{"amount":0,"blocked":true},{"amount":0}]:
			check(D.cues({"kind":"death_strike","style":key,"stage":"impact","targets":[hit]},audio.support_bank).is_empty(),"no false damage contact")
	var blank={"kind":"card_effect","style":"mediocrity","op":"discard_finish","stage":"travel"}
	check(D.cues(blank,audio.support_bank).is_empty(),"shared discard never replays the death effect")
	for v in events:
		audio.reset();plays=0
		# Advance to 200 ms, then rebuild the identical state. No second playback.
		audio.sync_view(v,Time.get_ticks_msec()-200)
		var before=plays
		audio.sync_view(v,Time.get_ticks_msec()-200)
		check(plays==before,"UI rebuild cannot replay cue")
	print("DEATH_AUDIO_RESULT checks=%d failures=%d new_cards=%d dance_contacts=%d"%[checks,failures,coverage.size(),dance_contacts])
	audio.queue_free();await process_frame;quit(0 if failures==0 else 1)
