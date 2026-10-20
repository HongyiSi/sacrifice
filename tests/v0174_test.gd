extends SceneTree
const H=preload("res://tests/helpers.gd")
const Rewards=preload("res://scripts/attack_rewards.gd")
const Launch=preload("res://scripts/signature_strike_launch.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0174_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func activate(g,owner:int,key:String,target:int)->void:
	var id:int=H.give_death(g,owner,key);g._activate({"actor":owner,"card":id},target)
func finish_fx(g)->void:
	for _i in range(100):
		if g.animation.is_empty():return
		g.advance_animation()
	check(false,"finite animation sequence")
func reward(g)->bool:
	for _i in range(100):
		if g.animation.is_empty():return false
		if Rewards.supports(g.animation):return true
		g.advance_animation()
	return false
func fixture(key:String,actor:int=0,victim:int=4,hp:int=1,mode:String=""):
	var g=H.fixture(8);g.presentation_enabled=true;g.characters[victim].hp=hp
	if mode=="immortal":H.give_death(g,victim,"immortal")
	if mode=="blocked":H.give(g,actor,"heal");activate(g,(actor+1)%6,"prison",actor)
	if mode=="divinity":activate(g,(actor+1)%6,"divinity",(actor+1)%6);g.characters[(actor+1)%6].hp=0
	var card:int=H.give(g,actor,key)
	if mode=="empty":g.deck.clear();g.discard.clear()
	if mode=="one":g.deck=[g.deck[0]];g.discard.clear()
	H.begin(g,{actor:card});check(g.target(actor/3,victim)=="","attack target accepted")
	return g
func _run()->void:
	for key in ["bounty","glory"]:
		for actor in range(6):
			var victim:int=(actor+1)%3+(3 if actor<3 else 0)
			var g=fixture(key,actor,victim)
			check(Launch.supports(g.animation),"weapon renderer supports "+key)
			check(g.animation.travel_ms==764,"approved flight timing")
			g.advance_animation()
			check(g.characters[victim].hp==0,"damage lands once before reward")
			check(g.characters[actor].hand.is_empty() and g.badges[actor/3]==0,"no early rewards")
			check(reward(g),"actual reward phase exists")
			check(g.animation.reward_source==victim and g.animation.action.actor==actor,"dynamic source and recipient")
			check(g.animation.reward_count==(2 if key=="bounty" else 1),"correct public reward count")
			check(g.snapshot(0).animation==g.snapshot(1).animation,"same public payload on both clients")
			check(g.animation.travel_ms==650 and g.animation.impact_ms==600,"approved reward timing")
			g.advance_animation()
			check(g.characters[actor].hand.size()==2 if key=="bounty" else g.badges[actor/3]==1,"reward only at arrival")
			check(g.snapshot(1-actor/3).characters[actor].hand.is_empty(),"opponent receives no reward card identities")
			finish_fx(g)
		for condition in ["friendly","nonlethal","corpse"]:
			var g=fixture(key,0,1 if condition=="friendly" else 4,8 if condition=="nonlethal" else 0 if condition=="corpse" else 1)
			check(not reward(g),"no reward for "+condition+" "+key)
		var g=fixture(key,0,4,1,"immortal");g.advance_animation()
		check(g.characters[4].hp==1 and g.animation.targets[0].revived,"instant revival preserves death event")
		check(reward(g) and g.animation.reward_source==4,"reward remains after immortal revival")
		g.advance_animation();check(g.characters[0].hand.size()==2 if key=="bounty" else g.badges[0]==1,"immortal reward counted once");finish_fx(g)
	for mode in ["blocked","empty","one","divinity"]:
		var g=fixture("bounty",0,4,1,mode)
		check(reward(g),"special draw still presents reward request "+mode)
		check(g.animation.reward_mode==("ready" if mode=="one" else mode),"truthful reward availability "+mode)
		if mode=="one":check(g.animation.reward_count==1,"one remaining card flies")
		g.advance_animation()
		check(g.animation.targets[0].amount==(1 if mode=="one" else 0),"actual draw count "+mode)
		finish_fx(g)
		if mode=="divinity":check(g.phase=="selecting" and g.request.type=="deck","divinity choice resumes after pending reward")
	# Hand limit must resume after the reward's impact, with the actual cards.
	var g=H.fixture(8);g.presentation_enabled=true;g.characters[4].hp=1
	for _i in range(7):H.give(g,0,"strike")
	H.begin(g,{0:H.give(g,0,"bounty")});g.target(0,4);check(reward(g),"reward before hand limit")
	g.advance_animation();check(g.characters[0].hand.size()==9,"two cards arrive before discarding");finish_fx(g)
	check(g.phase=="selecting" and g.request.type=="hand_limit" and g.request.count==2,"owner discards excess after reward")
	# Group attack has one blade per living target; blocked hits stay shielded.
	for count in [1,2,3]:
		g=H.fixture(8);g.presentation_enabled=true
		for id in range(3+count,6):g.characters[id].hp=0
		H.begin(g,{0:H.give(g,0,"area_strike")})
		check(Launch.supports(g.animation) and g.animation.targets.size()==count,"AOE adapts to living enemy count")
		g.advance_animation()
		for id in range(3,3+count):check(g.characters[id].hp==7,"AOE exactly one damage per target")
		finish_fx(g)
	g=H.fixture(8);g.presentation_enabled=true;activate(g,3,"blessing",4)
	H.begin(g,{0:H.give(g,0,"area_strike")});g.advance_animation()
	check(g.animation.targets[1].blocked and g.characters[4].hp==8,"blessing produces no slash damage")
	finish_fx(g)
	for key in ["godslayer","bounty","glory"]:
		g=H.fixture(8);g.presentation_enabled=true
		H.begin(g,{0:H.give(g,0,key),4:H.give(g,4,"defense")});finish_fx(g)
		check(g.target(0,4)=="" and g.phase=="reacting","defense choice remains interactive "+key)
		g.defend(1,true)
		check(g.animation.kind=="shield_block" and Launch.supports(g.animation),"blocked weapon is still recognizable "+key)
		check(g.animation.travel_ms==764 and g.animation.has("color"),"blocked flight has matching timing and palette")
		finish_fx(g);check(g.characters[4].hp==8 and g.badges[0]==0 and g.characters[0].hand.is_empty(),"block causes neither damage nor rewards")
	print("V0174_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
