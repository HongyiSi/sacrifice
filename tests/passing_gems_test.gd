extends "res://tests/v018_test.gd"
const S=preload("res://tests/reveal_scenarios.gd")

func _initialize() -> void:
	_catalog()
	for shown in [false,true]:
		for actor in [0,3]:
			for key in H.Rules.PASSING_GEMS:
				for full in [false,true]:_play_gem(key,actor,shown,full)
		for key in H.Rules.PASSING_GEMS:_cancel_gem(key,shown)
		_death_stages(shown)
	_exceptions()
	print("PASSING_GEMS_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)

func seek_choice(g) -> void:
	for _i in range(200):
		if not g.animation.is_empty():g.advance_animation();continue
		if g.phase=="targeting":return
		if g.phase in ["review","ended"]:break
		check(S.step(g)=="","advance to target selection")
	check(false,"gem requests a recipient")

func _play_gem(key:String,actor:int,shown:bool,full:bool) -> void:
	var g=H.fixture(8);g.presentation_enabled=shown;g.stage_presentation_enabled=shown
	var target:int=3 if actor==0 else 0
	g.characters[actor].hp=3;g.characters[target+2].hp=0
	var card:int=H.give(g,actor,key)
	if full:
		for _i in range(8):H.give(g,target,"strike")
	H.begin(g,{actor:card},false);seek_choice(g)
	check(g.request.options==[target,target+1],"only living opponents receive new gems")
	check(g.target(actor/3,actor)!="" and g.target(actor/3,target+2)!="","ally and dead recipient rejected")
	check(g.target(actor/3,target)=="","legal recipient accepted")
	drain(g)
	check(g.badges[actor/3]==(1 if key=="topaz" else 0),"yellow gem awards its caster's team")
	check(g.characters[actor].hp==(6 if key=="amber" else 3),"orange gem heals caster, not recipient")
	check(g.characters[actor].hand.size()==(4 if key=="emerald" else 0),"green gem draws four for caster")
	check(g.characters[target].hand.has(card)==not full,"gem enters recipient hand only if space exists")
	check(g.discard.has(card)==full,"overflow gem is discarded after granting its benefit")
	check(not g.characters[actor].hand.has(card) and _conserved(g),"physical gem is transferred without duplication")
	if not full:
		# The recipient can play the same physical card back next round.
		g.advance_round();drain(g)
		var before:int=g.badges[target/3]
		H.begin(g,{target:card},false);seek_choice(g)
		check(g.target(target/3,actor)=="","received gem can be played back")
		drain(g)
		check(g.characters[actor].hand.has(card),"same gem returns to original owner")
		check(g.badges[target/3]==before+(1 if key=="topaz" else 0),"second caster receives their own reward")

func _cancel_gem(key:String,shown:bool) -> void:
	var g=H.fixture(8);g.presentation_enabled=shown;g.characters[0].hp=3
	var card:int=H.give(g,0,key);var guard:int=H.give(g,3,"magic_amulet")
	H.begin(g,{0:card},false);seek_choice(g);g.target(0,3)
	check(g.phase=="responding" and g.request.team==1,"recipient may cancel with magic amulet")
	g.respond(1,guard);drain(g)
	check(g.badges==[0,0] and g.characters[0].hp==3 and g.characters[0].hand.is_empty(),"cancel blocks the entire benefit and transfer")
	check(not g.characters[3].hand.has(card) and g.discard.has(card),"cancelled gem is discarded")

func _exceptions() -> void:
	var g=H.fixture(8);var card:int=H.give(g,0,"emerald")
	for _i in range(7):H.give(g,0,"strike")
	H.begin(g,{0:card},false);g.target(0,3);drain(g)
	check(g.characters[0].hand.size()==8 and g.characters[3].hand.has(card) and _conserved(g),"green gem respects caster hand cap and still passes")
	g=H.fixture(8);g.characters[0].hp=7;card=H.give(g,0,"amber")
	H.begin(g,{0:card},false);g.target(0,3);drain(g)
	check(g.characters[0].hp==8,"orange healing stops at maximum HP")
	g=H.fixture(8);g.characters[0].hp=3;activate(g,1,"blessing",0);card=H.give(g,0,"amber")
	H.begin(g,{0:card},false);g.target(0,3);drain(g)
	check(g.characters[0].hp==3 and g.characters[3].hand.has(card),"blocked healing does not stop gem transfer")
	g=H.fixture(8);activate(g,1,"prison",0);H.give(g,0,"strike");card=H.give(g,0,"emerald")
	H.begin(g,{0:card},false);g.target(0,3);drain(g)
	check(g.characters[0].hand.size()==1 and g.characters[3].hand.has(card),"blocked draw does not stop gem transfer")
	g=H.fixture(8);g.badges[0]=3;card=H.give(g,0,"topaz")
	H.begin(g,{0:card},false);g.target(0,3)
	check(g.phase=="ended" and g.winner==0,"fourth badge ends game immediately")
	# A mirror copy transfers a generated card rather than stealing its source.
	g=H.fixture(8);card=H.give(g,3,"amber");g.characters[0].hp=3
	g.queue=[];g.phase="resolving";g.turn_stage="resolution"
	var action:Dictionary=g._add_action(0,card,true)
	g._start_effect(action);g._pump();g.target(0,4);drain(g)
	check(g.characters[0].hp==6 and g.characters[3].hand.has(card),"virtual gem leaves original physical card untouched")
	check(g.characters[4].hand.size()==1 and g.catalog[g.characters[4].hand[0]].get("generated",false),"mirror creates a transferable copy")

func _death_stages(shown:bool) -> void:
	for scenario in ["alive","no_cards","immortal","bound","old_death","new_death","purple","skip","wipe"]:
		var g=H.fixture(8);g.presentation_enabled=shown;g.stage_presentation_enabled=shown
		var death_card := -1
		if scenario!="alive":g.characters[0].hp=0;g.characters[0].death_round=g.round_number
		if scenario=="immortal":H.give_death(g,0,"immortal")
		if scenario=="bound":activate(g,0,"eye")
		if scenario in ["old_death","new_death","skip","purple"]:death_card=H.give_death(g,0,"sacrifice_badges")
		if scenario=="old_death":g.characters[0].death_round=g.round_number-1
		if scenario=="purple":H.give(g,0,"amethyst")
		if scenario=="skip":g.skip_death_phase=true
		if scenario=="wipe":g.characters[1].hp=0;g.characters[2].hp=0
		H.begin(g,{},false)
		var announced:=false
		for _i in range(250):
			if g.animation.get("turn_stage","")=="death" and g.animation.get("announce",false):announced=true
			if g.animation.is_empty() and g.phase in ["review","ended"]:break
			check(S.step(g)=="","death stage advances")
		check(announced==(shown and scenario in ["new_death","purple"]),"skip only inactive death stages: "+scenario)
		check(g.badges[0]==(2 if scenario=="new_death" else 0),"eligible death effect is preserved: "+scenario)
		if scenario=="purple":
			check(g.characters[0].hp==1 and g.death_queue.is_empty() and not g.death_revealed.has(death_card),"purple revives before death cards are queued or revealed")
		if scenario=="wipe":check(g.phase=="ended" and g.winner==1,"empty death phase still detects team elimination")
		else:check(g.phase=="review","round finishes after death handling")
