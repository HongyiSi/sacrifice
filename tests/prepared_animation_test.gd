extends "res://tests/choice_ui_rules_test.gd"
const Audio=preload("res://scripts/attack_audio.gd")
var audio
var saw=[]
func step_animations(g):
	for i in range(120):
		if g.animation.is_empty():return
		var e=g.animation
		if e.stage=="travel":saw.append(e.get("op",e.kind))
		check(audio.cues_for(g.snapshot(0))==audio.cues_for(g.snapshot(1)),"both peers receive the same prepared audio schedule")
		if e.get("prepared_draw",false):
			for team in [0,1]:
				for d in g.snapshot(team).animation.draws:
					if d.target/3!=team:check(not d.has("ids") and not d.has("before_hand"),"draw receipts redact enemy cards")
			var count=0
			for d in e.draws:count+=d.count-d.returned.count(true)
			if e.stage=="travel":check(audio.cues_for(g.snapshot(0)).filter(func(c):return c.file.ends_with("/place.ogg")).size()==count,"only accepted cards produce a hand landing sound")
		if e.get("op","")=="prepared_pack":
			var owner=e.action.actor/3
			check(not g.snapshot(1-owner).animation.hand_motion.has("owner_cards"),"discard identities stay private")
		g.advance_animation()
	check(false,"animation sequence terminates")
func _initialize():
	audio=Audio.new();audio.bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/attack_sounds.json"));audio.support_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/support_sounds.json"))
	for team in [0,1]:
		var actor=team*3
		for variant in ["normal","full","prison","empty","divinity","passives"]:
			var g=H.fixture(8);g.presentation_enabled=true;saw=[]
			var played=H.give(g,actor,"prepared")
			if variant in ["normal","full","prison","divinity"]:
				H.give(g,actor,"strike");H.give(g,actor,"heal")
			if variant=="full":
				for i in range(5):H.give(g,actor,"strike")
			if variant=="prison":activate(g,actor,"prison",actor)
			if variant=="empty":g.deck.clear()
			if variant=="divinity":g.characters[3-actor].hp=0;activate(g,3-actor,"divinity")
			var passive_ids=[]
			if variant=="passives":
				g.characters[actor].hp=4;passive_ids=[H.give(g,actor,"spare_food"),H.give(g,actor,"spare_supplies")]
			var before=g.characters[actor].hand.size()-1
			H.begin(g,{actor:played},false)
			check(g.animation.get("op","")=="prepared_depart","backpack leaves before any draw")
			check(g.characters[actor].hand.size()==before,"no cards drawn before backpack departure")
			step_animations(g)
			if variant=="divinity":
				check(g.request.type=="deck" and g.prepared_backpack.stage=="chest","bag waits at chest throughout godhood choice")
				check(not g.snapshot(team).input.has("draw_source") and not g.snapshot(1-team).input.has("draw_source"),"private continuation never appears in public request")
				var picks=g.request.options.filter(func(id):return g.catalog[id].key=="defense").slice(0,2)
				check(g.pick(1-team,picks)=="","godhood owner chooses real cards")
				step_animations(g)
			if variant=="empty":
				check(g.phase=="review" and g.prepared_backpack.is_empty(),"empty deck and empty hand close and remove backpack")
				continue
			check(g.phase=="selecting" and g.request.type=="discard","discard choice waits until all delivery animations complete")
			check(g.prepared_backpack.stage=="hand","bag waits beside hand until user confirms")
			check(g.request.count==2,"ordinary prepared requires exactly two eligible discards")
			var selected=passive_ids if variant=="passives" else g.request.options.slice(0,2)
			var hand=g.characters[actor].hand.duplicate()
			check(g.pick(team,selected)=="","actual mandatory pick accepted")
			check(g.animation.get("op","")=="prepared_pack" and g.animation.stage=="travel","selection starts packing animation")
			check(g.characters[actor].hand==hand and selected.all(func(id):return not g.discard.has(id)),"selected cards wait for packing before entering discard")
			if variant=="passives":check(g.characters[actor].hp==4,"discard passives have not fired during flight")
			step_animations(g)
			check(g.phase=="review" and g.prepared_backpack.is_empty(),"round completes and prop state is cleared")
			check(selected.all(func(id):return g.discard.has(id)),"both physical cards discarded exactly once")
			check(_conserved(g),"physical card count conserved")
			if variant=="passives":check(g.characters[actor].hp==6 and g.characters[actor].hand.size()==5,"reserve food and supplies resolve after packing with their own effects")
			if variant=="full":check(g.characters[actor].hand.size()==6,"overflow draws do not create cards or flights")
			if variant=="prison":check(not saw.has("draw_cards") and saw.has("prepared_arrive"),"blocked draw carries an empty bag to discard selection")
	# A new match cannot retain a waiting backpack.
	var g=H.fixture();g.prepared_backpack={"stage":"hand"};g.start(42)
	check(g.prepared_backpack.is_empty(),"match reset clears backpack state")
	audio.free();print("PREPARED_ANIMATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
