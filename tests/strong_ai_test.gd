extends "res://tests/v018_test.gd"
const AI=preload("res://scripts/local_ai.gd")
const Policy=preload("res://scripts/ai_policy.gd")
const Belief=preload("res://scripts/ai_belief.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():
	for side in [0,1]:
		var actor=side*3;var enemy=(1-side)*3
		var g=H.fixture(7);g.badges[side]=3
		var badge=H.give(g,actor,"badge");H.give(g,actor,"triple_strike");g.characters[enemy].hp=1
		var ai=AI.new(444);var s=g.snapshot(side);var original=s.duplicate(true);var d=ai.decide(s,side)
		check(d.payload[0].has(badge),"choose immediate badge victory instead of an attractive kill")
		check(s==original,"search does not mutate player snapshot")
		check(ai.last_stats.invalid==0,"all hypothetical plans and reactions legal")
		g=H.fixture(7);g.badges[1-side]=2;var death=H.give_death(g,enemy,"sacrifice_badges");g.death_revealed.append(death)
		g.characters[enemy].hp=1;H.begin(g,{actor:H.give(g,actor,"strike")})
		d=ai.decide(g.snapshot(side),side)
		check(d.kind=="target" and d.payload[0]!=enemy,"do not give the opponent a winning sacrifice")
		g=H.fixture(7);H.give_death(g,enemy,"blessing");g._activate({"card":108,"actor":enemy},enemy)
		H.begin(g,{actor:H.give(g,actor,"triple_strike")});s=g.snapshot(side);d=ai.decide(s,side)
		check(d.kind=="target" and d.payload[0]!=enemy,"attack avoids actual public blessing status")
		var predicted=Belief.world(s,side,42)
		check(predicted._has_effect("blessing",enemy),"sampled world preserves public bound effects")
		g=H.fixture(7);var good=H.give(g,actor,"badge");var hit=H.give(g,actor,"strike")
		g.defiled_cards[good]=true;g.catalog[1000]=Rules.POISON.duplicate();g.catalog[1000].generated=true;g.characters[actor].hand.append(1000)
		d=ai.decide(g.snapshot(side),side)
		check(not d.payload[0].has(good) and not d.payload[0].has(hit),"poison and defile remain enforced in search")
		check(g.submit(side,d.payload)=="","restricted search plan accepted by real engine")
		g=H.fixture(7);g.characters[actor].hp=5
		var hit_a=H.give(g,actor,"strike");H.give(g,actor,"heal");var hit_b=H.give(g,actor+1,"strike")
		g.characters[enemy].hp=2;g.characters[enemy+1].hp=0;g.characters[enemy+2].hp=0
		d=AI.new(444).decide(g.snapshot(side),side)
		check(d.payload[0].has(hit_a) and d.payload[1].has(hit_b),"coordinate two one-damage attacks for immediate team victory instead of healing")
		g=H.fixture(7);g.badges[side]=2;H.give_death(g,actor,"sacrifice_badges")
		var feign=H.give(g,actor,"feign");H.give(g,actor,"double_strike")
		d=AI.new(8).decide(g.snapshot(side),side)
		check(d.payload[0].has(feign),"recognize forced deathrattle badge victory")
		g=H.fixture(7);g.characters[actor].overload_round=g.round_number;g.badges[side]=2
		var badge_a=H.give(g,actor,"badge");var badge_b=H.give(g,actor,"badge")
		d=AI.new(9).decide(g.snapshot(side),side)
		check(d.payload[0].has(badge_a) and d.payload[0].has(badge_b),"search supports multi-card quota and a combined badge victory")
	# Visible-state determinism: unrelated hidden data and the opponent's locked
	# plan must not influence hypotheses or the selected plan.
	var g=Rules.new();g.start(854);var before=g.snapshot(1)
	var a=AI.new(8).decide(before,1)
	g.deck.reverse();g.characters[0].hand.reverse();g.plans[0]=[[],[],[]]
	var b=AI.new(8).decide(g.snapshot(1),1)
	check(a==b,"same visible position ignores real deck order and opposing plan")
	var ai=AI.new(9);var s=before;var decision={};var polls=0;var worst=0
	while decision.is_empty() and polls<2000:
		var start=Time.get_ticks_usec();decision=ai.poll(s,1,2000);worst=maxi(worst,Time.get_ticks_usec()-start);polls+=1
	check(not decision.is_empty() and polls>1,"cooperative search yields before choosing")
	check(ai.pending==null,"completed search releases hypothetical worlds")
	ai.poll(s,1,1);ai.cancel_search();check(ai.pending==null,"leaving or restarting can cancel search")
	ai=AI.new(43);decision=ai.poll(s,1,1,1)
	if decision.is_empty():ai.pending_started-=100;decision=ai.poll(s,1,1,1)
	check(decision.kind=="plan" and ai.last_stats.truncated,"wall-time limit returns a completed plan or legal fallback")
	var fresh=Belief.world(s,1,42)
	check(fresh.submit(1,decision.payload)=="","deadline fallback is legal")
	print("AI_SLICES calls=",polls," max_us=",worst)
	# Every existing interactive card must still complete through the policy.
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))+JSON.parse_string(FileAccess.get_file_as_string("res://data/deathrattles.json"))
	for row in rows:drive(preload("res://tests/art_scenarios.gd").setup(row.key)[0],row.key)
	print("STRONG_AI_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
func drive(g,key:String):
	var ai=AI.new(21)
	for step in range(800):
		if not g.animation.is_empty():g.advance_animation();continue
		if g.phase in ["planning","review","ended"]:check(true,"complete "+key);return
		var side=int(g.request.get("team",-1));var s=g.snapshot(side);var d=ai.decide(s,side)
		if d.is_empty():check(false,"stalled "+key);return
		var error=Actions.apply(g,side,d.kind,d.payload,s.match,s.round,s.revision)
		if error!="":check(false,"illegal "+key+": "+error);return
	check(false,"loop "+key)
