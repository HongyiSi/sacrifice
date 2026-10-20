extends SceneTree
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/v011_scenarios.gd")
const Launch=preload("res://scripts/card_emblem_launch.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0175_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func activate(g,owner:int,key:String,target:int)->void:
	var card:int=H.give_death(g,owner,key);g._activate({"actor":owner,"card":card},target)
func seek(g,op:String)->bool:
	for _i in range(100):
		if g.animation.get("op","")==op:return true
		if g.phase in ["review","ended"] and g.animation.is_empty():return false
		if not S.step(g).is_empty():return false
	return false
func _run()->void:
	for actor in range(6):
		for key in ["holy_strike","quick_strike","hasty_spell","magic_strike"]:
			var g=H.fixture(8);g.presentation_enabled=true
			H.begin(g,{actor:H.give(g,actor,key)});var target:int=(actor+3)%6;g.target(actor/3,target)
			check(Launch.supports(g.animation),"new attack supported "+key)
			check(g.animation.travel_ms=={"holy_strike":1080,"quick_strike":500,"hasty_spell":600,"magic_strike":864}[key],"approved motion timing "+key)
			check(g.characters[target].hp==8,"HP stays unchanged during flight")
			g.advance_animation();check(g.characters[target].hp==(5 if key=="holy_strike" else 6),"single impact damage")
			check(g.snapshot(0).animation==g.snapshot(1).animation,"identical public impact")
	for mode in ["ready","blocked","empty","partial","divinity"]:
		var g=H.fixture(8);g.presentation_enabled=true;H.give(g,4,"heal")
		if mode=="blocked":activate(g,0,"prison",4)
		if mode=="divinity":activate(g,0,"divinity",0);S.die(g,0)
		var c:int=H.give(g,4,"collect")
		if mode=="empty":g.deck.clear();g.discard.clear()
		if mode=="partial":g.deck=[g.deck[0]];g.discard.clear()
		H.begin(g,{4:c});var before:int=g.characters[4].hand.size();var e:Dictionary=g.animation
		check(e.draw_mode==("ready" if mode=="partial" else mode),"draw mode "+mode)
		check(e.card_count==(0 if mode=="empty" else 1 if mode=="partial" else 3),"available public count "+mode)
		g.advance_animation()
		check(g.characters[4].hand.size()-before==(1 if mode=="partial" else 3 if mode=="ready" else 0),"draw result matches visuals "+mode)
		if mode=="divinity":
			for _i in range(30):
				if g.animation.is_empty():break
				g.advance_animation()
			check(g.request.type=="deck","divinity picker waits for choice")
			g.pick(g.request.team,g.request.options.slice(0,g.request.count))
			check(g.animation.effect_state=="chosen" and g.animation.op=="draw" and g.animation.card_count==3,"chosen cards have their own flight")
			check(g.snapshot(1).input.get("options",[]).is_empty(),"chosen identities remain private")
	# A group cancellation can protect the other team, and mixed targets must
	# be taken from the real response rather than assumed to be slots 0..2.
	for team in [0,1]:
		var g=H.fixture(8);g.presentation_enabled=true
		var owner:int=team*3+2;var guard:int=H.give(g,owner,"attack_amulet")
		var enemy:int=(1-team)*3;var hit:int=H.give(g,enemy,"area_strike")
		for t in [0,1]:
			var plan:Array=[0,0,0]
			if t==team:plan[2]={"cards":[guard],"guards":{guard:team*3+1}}
			else:plan[0]=hit
			check(g.submit(t,plan)=="","guard plan")
		check(g.phase=="responding","guard response offered")
		g.respond(team,g.request.options[0])
		check(g.animation.guard_target==team*3+1,"actual protected pawn")
		check(g.animation.affected_targets==[team*3,team*3+1,team*3+2],"all real group targets")
		g.advance_animation();check(g.characters.all(func(c):return c.hp==8),"entire attack cancelled")
	for number in [0,1,6]:
		var g=H.fixture(8);g.presentation_enabled=true;H.begin(g,{5:H.give(g,5,"ignore")});g.choose(1,number)
		check(g.animation.value==number,"skip numeral is not a demo constant")
		g.advance_animation();check(g.skipped==[number],"skip visual agrees with actual rule")
	var g=H.fixture(8);g.presentation_enabled=true
	g.characters[3].hand.append(104);g.death_deck.erase(104);H.give(g,3,"heal");H.give(g,3,"strike")
	H.give_death(g,0,"vanish");S.die(g,0);H.begin(g,{});g.target(0,3)
	check(g.animation.card_count==2,"curse excluded from outgoing count")
	g.advance_animation();check(g.characters[3].hand==[104],"curse stays after outgoing flight")
	g=H.fixture(8);g.presentation_enabled=true;activate(g,3,"prison",4);g._lose_death(3,112);g._pump()
	check(g.animation.effect_state=="removed" and not g._has_effect("prison",4),"removal feedback reflects terminated binding")
	g=H.fixture(8);g.presentation_enabled=true;H.give_death(g,0,"immortal")
	for id in [0,1,2]:g.characters[id].hp=0
	g._try_immortal(0);g._pump();check(g.animation.revived==false and g.characters[0].hp==0,"failed immortal does not animate successful revival")
	print("V0175_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
