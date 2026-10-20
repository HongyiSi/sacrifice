extends SceneTree
const H=preload("res://tests/helpers.gd")
var checks=0
var failures=[]
var player
func _initialize():run.call_deferred()
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func drain(g,limit=250):
	var steps=0;var trace=[]
	while steps<limit:
		steps+=1
		if not g.animation.is_empty():
			trace.append(g.animation.duplicate(true));g.advance_animation();continue
		if g.phase in ["review","planning","ended"]:break
		if not g.request.is_empty():
			if g.phase in ["targeting","death_targeting"]:
				check(g.target(g.request.team,g.request.options[0]).is_empty(),"automatic real target")
			elif g.phase=="selecting":check(g.pick(g.request.team,g.request.options.slice(0,g.request.count)).is_empty(),"automatic real picker")
			else:break
		else:break
	check(steps<limit,"no pending loop")
	return trace
func reserve(key,present,hp=4,blessed=false):
	var g=H.fixture(hp);g.presentation_enabled=present;g.phase="resolution"
	var ordinary=H.give(g,0,"strike")
	var special=H.give(g,0,key)
	if blessed:
		var id=H.give_death(g,0,"blessing");g.effects.append({"card":id,"key":"blessing","owner":0,"target":0})
	var before=g.characters[0].hand.duplicate()
	g._discard_hand_card(g.characters[0],ordinary);g._discard_hand_card(g.characters[0],special)
	check(g.discard.is_empty(),"cards withheld before passive "+key)
	check(g.characters[0].hand.is_empty(),"hand capacity released "+key)
	g._push([{"op":"planning"}]);g._pump()
	if present:
		check(g.discard.is_empty(),"not discarded at first animation")
	var trace=drain(g)
	check(g.discard.has(ordinary) and g.discard.has(special),"whole original batch reaches discard")
	check(g.staged_discards.is_empty() and g.discard_batch_pending.is_empty(),"staging fully cleared")
	if key=="spare_food":check(g.characters[0].hp==(hp if blessed or hp==0 else mini(8,hp+2)),"exact food recovery")
	else:check(g.characters[0].hand.size()==(0 if hp==0 else 3),"exact three supplies draws")
	if key=="spare_supplies" and present and hp>0:
		var kinds=trace.map(func(e):return e.get("op",e.kind))
		check(kinds.find("draw_cards")<kinds.find("discard_finish"),"supplies draws precede discard")
func run():
	player=preload("res://scripts/attack_audio.gd").new();root.add_child(player);await process_frame
	for p in [false,true]:
		for k in ["spare_food","spare_supplies"]:reserve(k,p)
	reserve("spare_food",true,8);reserve("spare_food",true,4,true);reserve("spare_food",true,0)
	var batch=H.fixture(4);batch.presentation_enabled=true;batch.phase="resolution"
	var original=[H.give(batch,0,"spare_food"),H.give(batch,0,"spare_supplies")]
	for i in range(6):original.append(H.give(batch,0,"strike"))
	batch._discard_hand(batch.characters[0]);batch._push([{"op":"planning"}]);batch._pump()
	var trace_batch=drain(batch)
	check(batch.discard.size()==8 and original.all(func(id):return batch.discard.count(id)==1),"eight-card mixed discard commits exactly once")
	check(batch.characters[0].hp==6 and batch.characters[0].hand.size()==3,"both reserve effects resolve before batch disposal")
	for i in range(8):
		var p=preload("res://scripts/ordinary_pose.gd").staged_at(i)
		check(p.x<1385 and p.y>310 and p.y<490,"full discard batch fits the cloth")
	for hp in [8,2,1]:
		var g=H.fixture(hp);g.presentation_enabled=true
		var death=H.give_death(g,0,"sacrifice_badges")
		H.begin(g,{0:H.give(g,0,"feign")},false)
		var trace=drain(g)
		var cost=trace.filter(func(e):return e.get("op","")=="lose_hp" and e.stage=="impact")
		var death_fx=trace.filter(func(e):return e.get("action",{}).get("death",false))
		check(cost.size()==1,"one mask cost")
		check(not death_fx.is_empty(),"forced deathrattle follows cost")
		if not death_fx.is_empty():check(trace.find(cost[0])<trace.find(death_fx[0]),"mask cost order")
		check(g.badges[0]==2,"forced badge deathrattle still resolves after zero hp")
	var sound=player.support_bank.ordinary_suite.badge
	for style in ["badge","glory","sacrifice_badges"]:
		var e={"kind":"card_effect","style":style,"op":"badges","stage":"impact","card_count":2 if style=="sacrifice_badges" else 1,"reward_count":1}
		var cues=player.cues_for({"animation":e})
		check(cues.size()==e.card_count,"one unified cue per badge: "+style)
		check(cues.all(func(c):return c.file==sound),"same badge asset: "+style)
	var prophecy=player.cues_for({"animation":{"kind":"card_effect","style":"badge","source_key":"prophecy","stage":"impact"}})
	check(prophecy.size()==1 and prophecy[0].file==sound,"prophecy reward uses unified badge cue")
	var gem=player.cues_for({"animation":{"kind":"gem_trigger","style":"topaz","stage":"travel","gem_polished":true}})
	check(gem.filter(func(c):return c.file==sound).size()==1,"topaz reward uses unified badge cue")
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	check(data.filter(func(c):return c.key=="feign")[0].text=="失去2点生命。立刻打出这个棋子的所有亡语牌。","exact feign description")
	# The first discarded card can be any ordinary card, not only a reserve.
	for k in ["strike","badge","rally","plunder","feign","cards_to_heart","spare_food","spare_supplies"]:
		for stage in ["travel","impact"]:
			var e={"kind":"card_effect","style":k,"op":"discard_finish","stage":stage}
			check(preload("res://scripts/cinema/cinema.gd").family_for(e)=="ordinary_pose","discard batch never replays first card theme: "+k)
			var cues=player.cues_for({"animation":e})
			check(cues.size()==(1 if stage=="travel" else 0),"discard batch only sounds once: "+k)
			if stage=="travel":check(cues[0].file==player.support_bank.ordinary_suite.discard,"discard never awards a badge or repeats first spell")
	print("ORDINARY_SUITE_RESULT checks=%d failures=%d"%[checks,failures.size()])
	player.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
