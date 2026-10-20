extends SceneTree
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/gem_polish_scenarios.gd")
var checks=0
var failures=0
var audio
var played=[]
func _initialize():run.call_deferred()
func check(ok,label):
	checks+=1
	if not ok:failures+=1;push_error("GEM_POLISH_FAIL "+label)
func run():
	audio=load("res://scripts/attack_audio.gd").new();root.add_child(audio);audio.set_process(false)
	audio.settings_path="res://test-results/gem-polish-audio.cfg";audio.level=.5
	audio.cue_played.connect(func(file,offset):played.append([file,offset]))
	var example={}
	for key in ["ruby","amber","sapphire","emerald","amethyst","topaz"]:
		for actor in range(6):
			var g=S.setup(key,actor,803400+checks)
			var before=g.characters[actor].hand.size();var before_hp=g.characters[actor].hp
			var first=g.animation.duplicate(true)
			var cues=audio.cues_for(g.snapshot(0))
			check(cues==audio.cues_for(g.snapshot(1)),"shared sound "+key)
			check(cues.filter(func(c):return c.file.ends_with("/shimmer.wav") and c.delay==1.02).size()==1,"one chest shimmer "+key)
			check(cues.size()==(2 if key=="topaz" else 1),"silent lift and no premature effect")
			if key=="ruby" and actor==0:example=g.snapshot(0)
			g.advance_animation()
			if key in ["sapphire","emerald"]:
				check(g.animation.kind=="draw_cards" and g.animation.has("gem_overlay"),"draw starts before gem returns")
				check(g.animation.gem_offset_ms==1320,"draw at magic packet arrival")
				check(g.characters[actor].hand.size()==before+(1 if key=="sapphire" else 4),"actual draw count")
				var enemy=g.snapshot(1-actor/3)
				check(enemy.characters[actor].hand.is_empty(),"other hand hidden")
				check(not enemy.animation.gem_overlay.has("gem_card") and not enemy.animation.gem_overlay.has("owner_slot"),"nested metadata private")
				check(enemy.animation.draws.all(func(d):return not d.has("ids") and not d.has("before_hand")),"draw identities private")
				var effect=audio.cues_for(g.snapshot(0))
				check(effect.filter(func(c):return c.file.ends_with("/"+key+".wav") and c.delay==0).size()==1,"one draw effect sound")
				check(effect.filter(func(c):return c.file.ends_with("/deal.wav")).size()==(1 if key=="sapphire" else 4),"one deal per accepted card")
			elif key=="topaz":
				check(g.badges[actor/3]==1 and first.travel_ms==2360,"badge at arrival")
				check(audio.cues_for(g.snapshot(0)).is_empty(),"badge audio not duplicated")
			else:
				check(g.characters[actor].hp==before_hp+({"ruby":1,"amber":3,"amethyst":1}[key]),"HP at contact")
				check(audio.cues_for(g.snapshot(0)).size()==1,"one actual healing sound")
		# Empty/full/blocked draws retain rule behavior; overflow has no flight foley.
		if key in ["sapphire","emerald"]:
			for mode in ["full","empty","prison","divinity"]:
				var g=S.setup(key,0,813400+checks)
				if mode=="full":
					while g.characters[0].hand.size()<8:g.characters[0].hand.append(g.deck.pop_back())
				elif mode=="empty":g.deck.clear();g.discard.clear()
				else:
					var owner=3;var id=H.give_death(g,owner,mode)
					if mode=="divinity":g.characters[owner].hp=0
					g._activate({"actor":owner,"card":id},0 if mode=="prison" else owner)
				g.advance_animation()
				if mode=="full":check(audio.cues_for(g.snapshot(0)).all(func(c):return not c.file.ends_with("/deal.wav") and c.get("category","")!="card_movement"),"full hand has no dealing/landing sound")
				check(S.G.drain(g),"special draw completes "+mode)
		if key in ["ruby","amber"]:
			var g=S.setup(key,0,823400+checks)
			var id=H.give_death(g,3,"blessing");g._activate({"actor":3,"card":id},0)
			g.advance_animation();check(g.animation.hp_gain==0 and audio.cues_for(g.snapshot(0)).is_empty(),"blocked healing is not audible success")
	# Sound starts at its cue, survives rebuild, seeks late snapshots and mutes.
	audio.sync_view(example,Time.get_ticks_msec());check(played.is_empty(),"silent initial lift")
	audio.stage_started=Time.get_ticks_msec()-1040;audio._process(0)
	check(played.size()==1 and played[0][0].ends_with("/shimmer.wav"),"actual shimmer voice plays")
	for i in range(3):audio.sync_view(example.duplicate(true),Time.get_ticks_msec())
	check(played.size()==1,"duplicate snapshot does not repeat shimmer")
	var next=example.duplicate(true);next.animation.stage="impact";next.animation.hp_gain=1
	audio.sync_view(next,Time.get_ticks_msec());check(played.size()==2,"healing sound starts with HP")
	check(audio.voices.filter(func(p):return p.playing).size()==2,"shimmer tail preserved")
	audio.set_level(0);check(audio.voices.all(func(p):return p.volume_db<=-79),"mute includes gems")
	audio.reset();played.clear();audio.sync_view(example,Time.get_ticks_msec()-1100)
	check(played.size()==1 and absf(played[0][1]-.08)<.03,"late snapshot seeks sound")
	audio.reset();audio.queue_free();await process_frame
	print("GEM_POLISH_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
