extends SceneTree
const H = preload("res://tests/helpers.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V012_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func status(g, id: int, key: String, viewer: int = 0) -> Dictionary:
	for s in g.snapshot(viewer).characters[id].ongoing_effects:
		if s.key == key: return s
	return {}
func die(g, id: int) -> void:
	g.characters[id].hp = 0; g.characters[id].death_round = g.round_number
func activate(g, owner: int, key: String, target: int) -> int:
	var card: int = H.give_death(g,owner,key)
	g._activate({"actor":owner,"card":card},target)
	g.death_revealed.append(card)
	return card
func _run() -> void:
	# All targeted damage permits either team's corpses, without a new death.
	for key in ["strike","double_strike","triple_strike","quick_strike","holy_strike","magic_strike","hasty_spell","bounty","glory","judgment"]:
		for victim in [1,3]:
			var g = H.fixture(8); die(g,victim)
			H.give_death(g,victim,"immortal")
			var before: int = g.characters[0].hand.size()
			H.begin(g,{0:H.give(g,0,key)})
			check(g.request.options == [0,1,2,3,4,5],key+" includes all six roles")
			check(g.request.description.contains("选择一个棋子") and not g.request.description.contains("苦肉"),key+" explains its own target effect")
			check(g.target(0,victim) == "",key+" accepts corpse")
			check(g.characters[victim].hp == 0 and g.badges[0] == 0 and g.characters[0].hand.size() == before,key+" corpse cannot grant kill/revival/reward")
			check(not g.death_revealed.has(120),key+" corpse hit cannot retrigger immortal")
	var g = H.fixture(8); die(g,3)
	H.begin(g,{0:H.give(g,0,"godslayer")})
	check(not g.request.options.has(3),"godslayer still requires a revealed target")
	g = H.fixture(8)
	var high: int = H.give(g,0,"godslayer",12)
	H.begin(g,{0:high,3:H.give(g,3,"godslayer",11)})
	die(g,3)
	check(g.request.options.has(3) and g.target(0,3) == "","already-revealed dead role is a legal godslayer target")
	for key in ["death_sentence","last_dance","life_steal"]:
		g = H.fixture(); die(g,0); die(g,3); H.give_death(g,0,key); H.begin(g,{})
		check(g.request.options == [0,1,2,3,4,5],key+" allows all living and dead roles")
		check(g.target(0,3) == "" and g.characters[0].hp == 0,key+" dead enemy cannot trigger life steal")
		if key == "last_dance":
			check(g.request.description.contains("2 / 5"),"corpse hit spends one dance iteration")
			for i in range(4): check(g.target(0,3) == "","dance can repeatedly target a corpse")
		check(g.characters[3].hp == 0,"corpse stays dead")
	# Defensive stacks persist across unrelated steps and leave only on use/expiry.
	g = H.fixture(8)
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike"),4:H.give(g,4,"double_strike")})
	check(status(g,0,"defense").count == 1,"shield persists after card completion")
	g.target(1,0); g.defend(0,false)
	check(status(g,0,"defense").count == 1,"declining defense keeps its aura")
	g.target(1,0); g.defend(0,true)
	check(status(g,0,"defense").is_empty(),"consumed shield removes aura")
	g = H.fixture(); H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"strike")}); g.skip_effect(1)
	check(status(g,0,"defense").is_empty(),"unused shield expires at settlement end")
	for key in ["prison","blessing","privilege","ghost","pain","eye","divinity"]:
		g = H.fixture(); var card := activate(g,0,key,1 if key in ["prison","blessing","privilege"] else 0)
		var target := 1 if key in ["prison","blessing","privilege"] else 0
		check(not status(g,target,key).is_empty(),key+" retained after activation")
		check(status(g,target,key) == status(g,target,key,1),key+" same public state on both peers")
		if key in ["pain","eye","divinity"]:
			check(status(g,target,key).dormant,key+" alive owner waits for death")
			die(g,0); check(not status(g,target,key).dormant,key+" activates while dead")
			g._revive(0,5); check(status(g,target,key).dormant,key+" revival retains dormant binding")
		g._lose_death(0,card)
		check(status(g,target,key).is_empty(),key+" source loss removes aura")
	g = H.fixture(); g.characters[0].overload_round = 2; g.characters[1].silenced_round = 2
	g.characters[2].extra_round = 2; g.characters[2].extra_count = 2
	for pair in [[0,"overload"],[1,"silence"],[2,"heart"]]: check(status(g,pair[0],pair[1]).waiting,"next-round passive already visible")
	g.phase = "review"; g.advance_round()
	for pair in [[0,"overload"],[1,"silence"],[2,"heart"]]: check(not status(g,pair[0],pair[1]).waiting,"passive turns active in its round")
	g.phase = "review"; g.advance_round()
	for pair in [[0,"overload"],[1,"silence"],[2,"heart"]]: check(status(g,pair[0],pair[1]).is_empty(),"expired delayed passive removed")
	g = H.fixture(); H.give_death(g,3,"immortal")
	check(status(g,3,"immortal").is_empty(),"held secret immortal has no public aura")
	die(g,3); g._try_immortal(3)
	check(not status(g,3,"immortal").is_empty(),"triggered immortal remains visible")
	g = H.fixture(); H.give_death(g,0,"curse")
	g._move_death_to_hand({"actor":0,"card":104},3)
	check(not status(g,3,"curse").is_empty(),"public curse application stays visible")
	g.characters[3].curse_exposed = false
	check(status(g,3,"curse").is_empty() and not status(g,3,"curse",1).is_empty(),"secretly transferred curse does not reveal a hand")
	g._discard_hand_card(g.characters[3],104)
	check(not status(g,3,"curse",1).is_empty(),"blocked curse discard retains its status overlay")
	print("V012_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
