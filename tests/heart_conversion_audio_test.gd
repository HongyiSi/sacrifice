extends SceneTree
const H=preload("res://tests/helpers.gd")
const Audio=preload("res://scripts/attack_audio.gd")
var s
var checks=0
var failures=0
var played=[]
var serial=997500
func check(ok,label):
	checks+=1
	if not ok:failures+=1;push_error("HEART_CONVERSION_AUDIO_FAIL "+label)
func _initialize():run.call_deferred()
func fixture(actor,n,hp,blocked=false,retained=false):
	var g=H.fixture(8);serial+=1;g.match_id=serial;g.characters[actor].hp=hp
	g.presentation_enabled=true;g.resolution_presentation_enabled=true
	for i in range(n):H.give(g,actor,["defense","heal","strike","collect","badge","warcry","bloodletting"][i])
	if retained:g.characters[actor].hand.append(104);g.death_deck.erase(104)
	if blocked:
		var owner=(actor+1)%6;var id=H.give_death(g,owner,"blessing")
		g._activate({"actor":owner,"card":id,"death":true},actor)
	H.begin(g,{actor:H.give(g,actor,"cards_to_heart")},false)
	return g
func run():
	s=Audio.new();root.add_child(s);s.set_process(false);s.level=0.
	s.cue_played.connect(func(file,offset):played.append({"file":file,"offset":offset}))
	var normal={}
	for actor in [0,3]:
		for mode in ["four","seven","near_full","full","blocked","empty","retained"]:
			var n=7 if mode=="seven" else 0 if mode=="empty" else 4
			var hp=1 if mode=="seven" else 7 if mode=="near_full" else 8 if mode=="full" else 3
			var expected=0 if mode=="blocked" else mini(8-hp,n)
			var g=fixture(actor,n,hp,mode=="blocked",mode=="retained")
			var seen_heal=false;var seen_conversion=false
			for _i in range(40):
				if g.animation.is_empty():break
				var e=g.animation
				var own=g.snapshot(actor/3);var opponent=g.snapshot(1-actor/3)
				var cues=s.cues_for(own)
				check(cues==s.cues_for(opponent),"public playback identical: "+mode)
				for c in cues:
					var resource=load(c.file)
					check(resource!=null and resource.get_length()>.1,"real imported sound available")
					check(not c.cut_with_stage,"natural sound tail survives stage transition")
				if e.get("style","")=="cards_to_heart":
					if e.kind=="card_effect" and e.stage=="travel":
						seen_conversion=true
						check(e.hand_motion.slots.size()==n,"convert only discardable cards")
						check(own.animation.hand_motion.get("owner_cards",[]).size()==n,"own physical hand identities retained")
						check(not opponent.animation.hand_motion.has("owner_cards") and not opponent.animation.hand_motion.has("owner_slots"),"opponent receives no private identities or sort order")
						check(cues.size()==n*2,"one paper flight and one conversion per actual card")
						for c in cues:check(c.delay<e.travel_ms/1000.0,"all conversion cues fit the real stage")
					if e.kind=="heal" and e.stage=="impact":
						seen_heal=true
						var restores=cues.filter(func(c):return "/restore_" in c.file)
						check(restores.size()==expected,"no extra success sounds at full health or blocked healing")
						check(e.targets[0].after-e.targets[0].before==expected,"visual increment count follows actual recovery")
						check(cues.filter(func(c):return "heart_flight" in c.file).size()==n,"one small heart for each converted card")
						for c in restores:check(c.delay<e.impact_ms/1000.0,"every recovery fits the stage")
						if mode=="four" and actor==0:normal=own.duplicate(true)
				g.advance_animation()
			check(g.phase in ["review","ended"],"scenario completed: "+mode)
			check(seen_conversion and (seen_heal or n==0),"expected animation stages exist")
			check(g.characters[actor].hp==hp+expected,"actual final HP unchanged")
			check(g.characters[actor].hand==([104] if mode=="retained" else []),"uncastable and undiscardable card retained")
	# Drive the real player through four separate recovery instants.
	s.reset();played.clear();s.sync_view(normal,Time.get_ticks_msec())
	for i in range(4):
		var at=.74+.55*i
		s.stage_started=Time.get_ticks_msec()-roundi((at-.015)*1000);s._process(0)
		check(played.filter(func(p):return "/restore_" in p.file).size()==i,"next recovery cannot sound early")
		s.stage_started=Time.get_ticks_msec()-roundi((at+.001)*1000);s._process(0)
		check(played.filter(func(p):return "/restore_" in p.file).size()==i+1,"one new sound at each heart arrival")
		var previous=played.size();s.sync_view(normal,Time.get_ticks_msec())
		check(played.size()==previous,"same state never restarts recovery")
	check(s.voices.any(func(v):return v.playing),"actual audio players run")
	s.reset();played.clear();s.sync_view(normal,Time.get_ticks_msec()-840)
	var delayed=played.filter(func(p):return "/restore_" in p.file)
	check(delayed.size()==1 and delayed[0].offset>=.095,"late snapshot seeks into current healing tail")
	s.reset();check(s.pending.is_empty() and s.voices.all(func(v):return not v.playing),"leave stops sounds and pending future hearts")
	print("HEART_CONVERSION_AUDIO_RESULT checks=%d failures=%d"%[checks,failures])
	s.queue_free();await process_frame;quit(0 if failures==0 else 1)
