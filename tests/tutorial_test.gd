extends SceneTree
const Session = preload("res://scripts/session.gd")
const Tutorial = preload("res://scripts/tutorial.gd")
var checks := 0
var failures := 0
var s

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	s = Session.new()
	root.add_child(s); s.set_process(false)
	s.ai_checkpoint.enabled = false
	s.start_tutorial("新手")
	var t = s.tutorial
	var g = s.game
	check(s.active and s.hosting and not s.ai_mode and not s.online_mode,"Tutorial is isolated from AI and networking")
	check(g.characters.all(func(c):return c.hand.size()==5 and c.max_hp==7),"Five starting cards and seven max HP")
	var owned: Array = g.deck.duplicate()
	for c in g.characters: owned.append_array(c.hand)
	check(owned.size()==g.catalog.size() and owned.all(func(id):return owned.count(id)==1),"No duplicate or missing physical cards")
	s.act("plan",[[],[],[]])
	check(g.plans[0]==null,"Cannot bypass explanations with confirm")
	for i in range(5): s.tutorial_next()
	check(t.step==Tutorial.Step.PLAY,"Explanations wait for Next")
	check(not t.accept_local_plan(1,[t.card(1,"strike")]),"Off-step hand input is rejected")
	check(t.accept_local_plan(0,[t.card(0,"strike")]),"Play a basic attack")
	check(t.accept_local_plan(0,[]),"Withdraw a staged card")
	check(t.accept_local_plan(0,[t.card(0,"strike")]),"Play again")
	check(t.accept_local_plan(0,[t.card(0,"double_strike")]),"Replace the selected card")
	check(t.accept_local_plan(1,[t.card(1,"defense")]),"Plan a teammate's defense")
	s.act("plan",t.expected_plan())
	check(t.step==Tutorial.Step.UNLOCK and g.plans[1]==null,"Opponent waits so cancel-confirm is possible")
	s.act("unlock")
	check(t.step==Tutorial.Step.RECONFIRM and g.plans[0]==null,"Cancel-confirm unlocks real plan")
	s.act("plan",t.expected_plan())
	check(t.step==Tutorial.Step.ORDER,"Priority explanation before resolution")
	s.tutorial_next()
	drive_to(Tutorial.Step.GUARD_TARGET)
	var revision: int = g.revision
	s.act("skip_effect")
	s.act("target",[5])
	check(g.revision==revision,"Skipping/wrong target cannot break the guided battle")
	s.act("target",[2])
	drive_to(Tutorial.Step.GUARD_REACT)
	s.act("defend",[1])
	check(not t.can_confirm() and not t.holds_animation(),"Block animation plays before confirmation")
	drive_to(Tutorial.Step.ATTACK_TARGET)
	check(g.characters[2].hp==7 and g.characters[0].hp==6,"Defense blocks one attack; the other deals real damage")
	s.act("target",[3])
	check(not t.can_confirm() and not t.holds_animation(),"Double strike plays before confirmation")
	drive_to(Tutorial.Step.DEATH)
	check(g.characters[3].hp==0 and g.badges[1]==0,"Attack kills the prepared target before the death explanation")
	check(g.animation.is_empty() and g.visual_queue.is_empty(),"Death explanation follows the complete attack animation")
	for i in range(5): s._process(100.0)
	check(t.step==Tutorial.Step.DEATH and g.badges[1]==0,"Death explanation waits for player at any reading speed")
	s.tutorial_next()
	drive_to(Tutorial.Step.ROUND_END)
	check(g.badges[1]==2 and g.triggered_deaths.has(3),"Real deathrattle gives badges and retains triggered card")
	for i in range(5): s._process(100.0)
	check(g.round_number==1,"Review does not advance automatically")
	s.tutorial_next()
	drive_to(Tutorial.Step.HEAL_PLAY)
	check(g.characters[0].hand.size()==5 and g.characters[2].hand.size()==6,"Normal second-round draw honors unused hands")
	check(t.accept_local_plan(2,[t.card(2,"heal_other")]),"Plan healing in round two")
	s.act("plan",t.expected_plan())
	drive_to(Tutorial.Step.HEAL_TARGET)
	s.act("target",[0])
	check(not t.can_confirm() and not t.holds_animation(),"Healing animation plays before confirmation")
	drive_to(Tutorial.Step.COMPLETE)
	check(g.characters[0].hp==7,"Healing is capped at seven")
	check(g.turn_stage!="death","Empty death phase is skipped normally")
	s.start_tutorial("重试")
	check(s.tutorial.step==Tutorial.Step.WELCOME and s.game.round_number==1,"Restart resets lesson and match")
	s.leave()
	check(s.tutorial==null and s.state.is_empty() and not s.active,"Exit releases tutorial state")
	s.start_ai("测试",123)
	check(s.ai_mode and s.tutorial==null and s.game.characters.all(func(c):return c.hp==7),"Regular AI match remains a normal fresh game")
	s.leave(); s.queue_free()
	print("TUTORIAL_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func drive_to(expected: int) -> void:
	for i in range(600):
		if s.tutorial.step==expected:
			check(true,"Reached tutorial step %d" % expected)
			return
		if s.tutorial.can_confirm():
			check(s.game.animation.is_empty() and s.game.visual_queue.is_empty(),"Confirm is available only after all animation stages")
			var old_step: int = s.tutorial.step
			var old_revision: int = s.game.revision
			for j in range(3): s._process(100.0)
			check(s.tutorial.step == old_step and s.game.revision == old_revision,"Reading page waits for confirmation")
			s.tutorial_next()
		elif not s.game.animation.is_empty() and not s.tutorial.holds_animation():
			s.game.advance_animation(); s._broadcast()
		elif s.tutorial.tick(s.game,1000+i*1000): s._broadcast()
		else: s._broadcast()
	check(false,"Tutorial stalled at %d; expected %d; phase=%s" % [s.tutorial.step,expected,s.game.phase])
