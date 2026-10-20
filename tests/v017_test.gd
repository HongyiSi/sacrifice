extends SceneTree
const H = preload("res://tests/helpers.gd")
const Actions = preload("res://scripts/match_actions.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V017_FAIL "+label)
func draw(g, actor: int, count: int) -> void:
	g._push([{"op":"draw","target":actor,"count":count}]); g._pump()
func clear_limit(g) -> void:
	check(g.request.get("type","") == "hand_limit","excess opens mandatory hand selection")
	var target: int = g.request.target
	check(g.request.team == g.characters[target].team and not g.request.can_skip,"owner controls mandatory discard")
	var chosen: Array = g.request.options.slice(0,g.request.count)
	check(g.pick(g.request.team,chosen) == "","chosen excess accepted")
	check(g.characters[target].hand.size() == 8,"eight cards remain")
func _initialize() -> void:
	var g = H.fixture(8)
	check(g.catalog.size() == 107,"current total physical count")
	check(g.catalog.values().filter(func(c):return c.key=="badge").size()==2,"two badges")
	check(g.catalog.values().filter(func(c):return c.key=="heal_other").size()==3,"three healing others")
	var ranks := {}
	for c in g.catalog.values().filter(func(c):return c.main==1):
		check(not ranks.has(c.secondary),"unique priority one ranks"); ranks[c.secondary]=true
	draw(g,0,11)
	check(g.request.count==3 and g.request.options.size()==11,"whole draw batch then choose three")
	check(g.snapshot(1).input.options.is_empty() and g.snapshot(1).characters[0].hand.is_empty(),"discard candidates stay private")
	check(g.snapshot(0).hand_limit==8,"limit in snapshot")
	var original: Array = g.characters[0].hand.duplicate()
	check(g.pick(1,original.slice(0,3))!="","opponent cannot discard for owner")
	check(g.pick(0,original.slice(0,2))!="","too few rejected")
	check(g.pick(0,[original[0],original[0],original[1]])!="","duplicate rejected")
	check(g.pick(0,[9999,original[0],original[1]])!="","foreign id rejected")
	check(g.skip_effect(0)!="","cannot skip hand limit")
	check(g.submit(0,[0,0,0])!="","cannot submit during discard")
	check(g.characters[0].hand==original,"invalid attempts do not mutate hand")
	var selected: Array = [original[1],original[5],original[8]]
	check(g.pick(0,selected)=="","arbitrary chosen cards accepted")
	check(g.characters[0].hand==original.filter(func(id):return not selected.has(id)),"retains exactly chosen survivors")
	check(selected.all(func(id):return g.discard.has(id)),"discarded cards return to normal pile")
	check(g.phase=="planning" and g.request.is_empty(),"resume pre-draw phase")
	draw(g,0,1); clear_limit(g)
	# Preparation visits every living pawn, pausing independently for each owner.
	for c in g.characters:
		c.hand.clear(); g._draw(c,8)
	g._begin_round()
	for actor in range(6):
		check(g.request.get("target",-1)==actor,"round draw target order")
		clear_limit(g)
	check(g.phase=="planning","all six limit choices finish before planning")
	# Divinity chooses the gained cards, but the recipient chooses overflow.
	g=H.fixture(8)
	H.give_death(g,0,"divinity"); g.characters[0].hp=0
	g.effects.append({"card":102,"owner":0,"target":0,"round":g.round_number})
	g._draw(g.characters[4],7)
	draw(g,4,3)
	check(g.request.type=="deck" and g.request.team==0 and g.request.target==4,"god selects for enemy pawn")
	g.pick(0,g.request.options.slice(0,3))
	check(g.request.type=="hand_limit" and g.request.team==1 and g.request.count==2,"recipient owns overflow decision after divinity")
	check(g.snapshot(0).input.options.is_empty(),"divinity does not reveal enemy's retained hand")
	clear_limit(g)
	# Theft and a curse placed into hand also count; dead pawns obey the cap.
	g=H.fixture(8); g._draw(g.characters[0],8); g._draw(g.characters[3],1)
	var plunder: int=H.give(g,1,"plunder")
	var action := {"id":1,"actor":0,"card":plunder,"status":"active"}
	g._push([g._job("plunder",action,{"target":3})]); g._pump(); clear_limit(g)
	check(g.characters[3].hand.is_empty(),"theft still removes victim's card")
	g=H.fixture(8); g._draw(g.characters[3],8); g.characters[3].hp=0
	H.give_death(g,0,"curse")
	action={"id":1,"actor":0,"card":104,"death":true,"status":"active"}
	g._push([g._job("curse_move",action,{"target":3})]); g._pump()
	check(g.request.type=="hand_limit" and not g.request.options.has(104),"curse counts toward cap but is not a discard option")
	check(g.pick(1,[104])!="" and g.characters[3].curse_exposed,"curse discard rejected and remains exposed")
	clear_limit(g)
	check(g.characters[3].hand.has(104) and not g.death_discard.has(104),"discard another card and retain curse")
	# Overflow resumes Greed's additional mandatory discard, without losing it.
	g=H.fixture(8); g._draw(g.characters[4],4)
	H.give_death(g,0,"greed")
	action={"id":1,"actor":0,"card":113,"death":true,"status":"active"}
	g._push([g._job("draw",action,{"target":4,"count":6}),g._job("discard_one",action,{"target":4})]); g._pump()
	clear_limit(g)
	check(g.request.type=="hand" and g.request.team==1,"card's own discard continues after cap")
	g.pick(1,[g.request.options[0]])
	check(g.characters[4].hand.size()==7,"greed extra discard is not waived by cap")
	# Requests travel through the real server action validator.
	g=H.fixture(8); draw(g,2,9)
	check(Actions.apply(g,0,"pick",[g.request.options[0]],g.match_id,g.round_number,g.revision-1)!="","stale discard action rejected")
	check(Actions.apply(g,0,"pick",[g.request.options[0]],g.match_id,g.round_number,g.revision)=="","current discard action accepted")
	# Peek is private and identifies which of the same-named pawns is inspected.
	g=H.fixture(8); var peek=H.give(g,0,"peek"); var secret=H.give(g,3,"strike"); var death=H.give_death(g,3,"immortal")
	H.begin(g,{0:peek}); g.target(0,3)
	check(g.request.type=="inspect" and g.request.target==3,"peek target metadata")
	check(g.snapshot(0).input.cards==[secret] and g.snapshot(0).input.deaths==[death],"caster sees full inspection")
	check(g.snapshot(1).input.cards.is_empty() and g.snapshot(1).input.deaths.is_empty(),"inspection remains private")
	g.pick(0,[])
	check(g.characters[3].deathrattles==[death] and not g.death_revealed.has(death),"inspection never plays or publicly reveals death")
	# Production pauses for animations before exposing the mandatory choice.
	g=H.fixture(8);g.presentation_enabled=true
	g._draw(g.characters[0],7);var collect=H.give(g,0,"collect")
	H.begin(g,{0:collect})
	for _i in range(80):
		if g.animation.is_empty():break
		g.advance_animation()
	check(g.phase=="selecting" and g.request.get("type","")=="hand_limit","animated draw pauses for overflow")
	clear_limit(g)
	for _i in range(80):
		if g.animation.is_empty():break
		g.advance_animation()
	check(g.phase=="review" and g.request.is_empty(),"animated parent card resumes and round finishes")
	print("V017_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
