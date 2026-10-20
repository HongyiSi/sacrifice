extends "res://tests/v018_test.gd"
const Session=preload("res://scripts/session.gd")

func _initialize() -> void:
	var g=H.Rules.new();g.presentation_enabled=true;g.start(82008)
	check(g.animation.get("turn_stage","")=="start" and g.animation.announce,"game begins with its own announcement")
	var stages:Array=[]
	for _i in range(150):
		if g.phase=="planning" and g.animation.is_empty():break
		if g.animation.get("kind","")=="phase_change" and g.animation.stage=="travel" and g.animation.announce:stages.append(g.animation.turn_stage)
		if not g.animation.is_empty():g.advance_animation()
		elif not g.request.is_empty():H.auto_pick(g.snapshot(g.request.team))
	check(stages==["start","planning"],"start and initial planning each announce once")
	g=H.fixture(8);g.presentation_enabled=true;g.stage_presentation_enabled=true
	var first:int=H.give(g,0,"strike");var other:int=H.give(g,3,"heal")
	g.submit(0,[first,0,0])
	check(g.phase=="planning" and g.queue.is_empty(),"single confirmation keeps staged cards local")
	check(g.unlock(0)=="","confirmation can be cancelled before opponent confirms")
	g.submit(0,[first,0,0]);g.submit(1,[other,0,0])
	check(g.animation.get("turn_stage","")=="resolution" and g.animation.announce,"both confirmations enter announced resolution before effects")
	check(g.animation.conceal_actions.size()==2 and g.queue.all(func(a):return not a.revealed),"conceal event references unrevealed table slots")
	for team in [0,1]:
		var s:Dictionary=g.snapshot(team)
		check(s.queue.filter(func(a):return a.actor/3!=team).all(func(a):return a.card==0),"conceal phase reveals no opponent card")
		check(s.animation==g.snapshot(1-team).animation,"conceal animation contains public slot IDs only")
	var client=Session.new()
	var first_view:Dictionary=g.snapshot(0);client._receive_view(first_view)
	g.advance_animation();client._receive_view(g.snapshot(0))
	client.received_animation_started=Time.get_ticks_msec()-300;client._drain_received_views()
	check(client.state.animation.stage=="travel","fast next packets cannot skip conceal or announcement")
	client.received_animation_started=Time.get_ticks_msec()-1601;client._drain_received_views()
	check(client.state.animation.stage=="impact","client releases after full announcement duration")
	client.free()
	g.advance_animation()
	check(g.animation.get("kind","")=="phase_change" and not g.animation.announce,"priority changes do not repeat central stage text")
	g=H.fixture(8);g.presentation_enabled=true;g.stage_presentation_enabled=true;g.submit(0,[0,0,0]);g.submit(1,[0,0,0])
	stages=[]
	for _i in range(100):
		if g.phase in ["review","ended"] and g.animation.is_empty():break
		if g.animation.get("kind","")=="phase_change" and g.animation.stage=="travel" and g.animation.announce:stages.append(g.animation.turn_stage)
		if not g.animation.is_empty():g.advance_animation()
	check(stages==["resolution"],"empty death stage is skipped without an announcement")
	g.advance_round()
	check(g.animation.get("turn_stage","")=="planning" and g.animation.announce,"following planning is announced")
	print("TABLE_FLOW_RULES_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
