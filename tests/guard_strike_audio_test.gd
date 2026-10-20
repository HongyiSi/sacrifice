extends SceneTree
const H=preload("res://tests/helpers.gd")
const Scenes=preload("res://tests/art_scenarios.gd")
const Audio=preload("res://scripts/attack_audio.gd")
var s
var checks=0
var failures=0
var played=[]
func check(ok,label):
	checks+=1
	if not ok:failures+=1;push_error("GUARD_STRIKE_AUDIO_FAIL "+label)
func _initialize():run.call_deferred()
func snapshot(key):
	var setup=Scenes.setup(key,88000+checks);var g=setup[0];var ctx=setup[1]
	for i in range(100):
		if g.animation.get("kind","")=="strike" and g.animation.get("stage","")=="impact":return g.snapshot(0)
		check(Scenes.step(g,ctx)=="","legal scenario step")
	assert(false,"no impact");return {}
func run():
	s=Audio.new();root.add_child(s);s.set_process(false);s.level=0.
	s.cue_played.connect(func(file,offset):played.append({"file":file,"offset":offset}))
	for key in ["strike","double_strike","triple_strike","final_strike","quick_strike","area_strike","precise_strike","godslayer","holy_strike","bounty","glory","judgment"]:
		var view=snapshot(key);var cues=s.cues_for(view);var count={"double_strike":2,"triple_strike":3}.get(key,1)
		check(cues.size()==count,"visible hits each have a separate cue: "+key)
		for cue in cues:
			check(not cue.cut_with_stage,"contact tail survives stage redraw")
			check(s.streams.has(cue.file),"hit loaded before first playback")
			check(s.streams[cue.file].get_length()>.10,"nonempty physical contact recording")
		if count>1:
			var expected=[0.,.21] if count==2 else [0.,.1495,.299]
			for i in count:check(absf(cues[i].delay-expected[i])<.00001,"multiple hit spacing follows visible animation")
			# Drive the actual scheduling node across the separate hit times.
			s.reset();played.clear();s.sync_view(view,Time.get_ticks_msec())
			check(played.size()==1,"first hit sounds now, later blades stay queued")
			for i in range(1,count):
				s.stage_started=Time.get_ticks_msec()-int((expected[i]-.012)*1000);s._process(0)
				check(played.size()==i,"no early overlapping next hit")
				s.stage_started=Time.get_ticks_msec()-int(ceil(expected[i]*1000));s._process(0)
				check(played.size()==i+1,"next sound fires with next visual contact")
				s.sync_view(view,Time.get_ticks_msec());check(played.size()==i+1,"same snapshot never replays contact")
			check(s.pending.is_empty(),"all contacts drain once")
		# Joining after contacts seeks their natural tails instead of restarting a burst.
		s.reset();played.clear();s.sync_view(view,Time.get_ticks_msec()-350)
		check(played.size()==count,"late view plays each audible tail once")
		for item in played:check(item.offset>=.045,"late playback seeks into elapsed recording")
		s.reset();check(s.pending.is_empty() and s.voices.all(func(v):return not v.playing),"leaving stops pending and playing sounds")
	# A missed judgment must remain silent at contact.
	var miss=snapshot("judgment");miss.animation.targets[0].miss=true
	check(s.cues_for(miss).is_empty(),"failed conditional hit has no impact sound")
	# Defense has one shield contact even against a multi-hit card.
	var blocked=snapshot("triple_strike");blocked.animation.kind="shield_block";blocked.animation.guard_style="defense"
	var cues=s.cues_for(blocked)
	check(cues.size()==1 and cues[0].file==s.support_bank.defense_block,"shield contact replaces all blocked damage sounds")
	# Flush a flight cue at a travel/impact transition rather than losing it.
	var v=snapshot("triple_strike");var travel=v.duplicate(true);travel.animation.stage="travel"
	s.reset();played.clear();s.sync_view(travel,Time.get_ticks_msec())
	s.stage_started=Time.get_ticks_msec()-710;s._process(0)
	check(s.pending.size()==1,"last third-blade whoosh waiting near transition")
	s.sync_view(v,Time.get_ticks_msec())
	check(played.filter(func(p):return "flight_standard" in p.file).size()==3,"last delayed flight survives travel stage handoff")
	# Fire effects retain their previously approved native sound bank.
	for key in ["magic_strike","hasty_spell"]:
		var c=s.cues_for(snapshot(key));check(c.size()==1 and c[0].file==s.bank.cards[key].impact,"fire contact unchanged")
	print("GUARD_STRIKE_AUDIO_RESULT checks=%d failures=%d"%[checks,failures])
	s.queue_free();await process_frame;quit(0 if failures==0 else 1)
