extends SceneTree
const H = preload("res://tests/helpers.gd")
const Styles = preload("res://scripts/strike_styles.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V010_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func finish_fx(g) -> void:
	for _i in range(100):
		if g.animation.is_empty(): return
		g.advance_animation()
	check(false,"effect queue terminates")
func scenario(key: String, animate: bool = true):
	var g = H.fixture(8); g.presentation_enabled = animate
	if key == "judgment": g.characters[3].hp = 2
	var chosen := {0:H.give(g,0,key)}
	if key == "godslayer": chosen[3] = H.give(g,3,"collect")
	H.begin(g,chosen)
	if key == "godslayer": finish_fx(g)
	if g.phase == "targeting": g.target(0,3)
	return g
func activate(g, owner: int, key: String, target: int) -> void:
	var id: int = H.give_death(g,owner,key)
	g._activate({"actor":owner,"card":id},target)
func _run() -> void:
	var keys := Styles.PROFILES.keys()
	check(keys.size() == 12,"ten named strikes plus two damage spells have profiles")
	check(Styles.PROFILES.quick_strike.travel_ms < Styles.PROFILES.strike.travel_ms,"quick strike visibly travels faster")
	for key in keys:
		var g = scenario(key)
		check(g.phase == "animating" and g.animation.style == key,"specific profile: "+key)
		var count: int = 3 if key == "area_strike" else 1
		check(g.animation.targets.size() == count,"target count: "+key)
		var old_hp: int = 2 if key == "judgment" else 8
		check(g.characters[3].hp == old_hp,"windup does not apply damage: "+key)
		check(g.snapshot(0).animation == g.snapshot(1).animation,"public animation agrees: "+key)
		check(g.target(0,4) != "" and g.skip_effect(0) != "","cannot retarget or skip during effect: "+key)
		g.advance_animation()
		var damage: int = 3 if key in ["triple_strike","godslayer","holy_strike"] else 2 if key in ["double_strike","magic_strike","quick_strike","hasty_spell"] else 99 if key == "judgment" else 1
		check(g.characters[3].hp == maxi(0,old_hp-damage),"one damage application at impact: "+key)
		check(g.phase == "animating" and g.animation.stage == "impact","impact remains visible: "+key)
		g.advance_animation()
		var instant = scenario(key,false)
		finish_fx(g)
		check(g.characters == instant.characters and g.queue == instant.queue and g.log_lines == instant.log_lines,"animated rules equal instantaneous rules: "+key)
		check(g.phase == instant.phase and g.discard == instant.discard,"continuation and card consumption preserved: "+key)
	# Double/triple visual slashes still cause ONE death, even against immortal.
	for key in ["double_strike","triple_strike"]:
		var g = H.fixture(8); g.presentation_enabled = true
		g.characters[3].hp = 1; H.give_death(g,3,"immortal")
		H.begin(g,{0:H.give(g,0,key)}); g.target(0,3); g.advance_animation()
		check(g.characters[3].hp == 1 and g.animation.targets[0].revived,"immediate revival visible: "+key)
		check(g.log_lines.filter(func(s): return s == g.characters[3].name+" 死亡。").size() == 1,"one death event despite multiple slashes: "+key)
		finish_fx(g)
	# AOE must retain original target order for immortal with last surviving ally.
	var g = H.fixture(8); g.presentation_enabled = true
	for id in [3,4,5]: g.characters[id].hp = 1
	H.give_death(g,3,"immortal")
	H.begin(g,{0:H.give(g,0,"area_strike")})
	g.advance_animation()
	check(g.characters[3].hp == 1 and g.characters[4].hp == 0 and g.characters[5].hp == 0,"AOE runs instant revival per target in original order")
	check(g.animation.targets[0].revived and g.animation.targets[1].died,"AOE publishes each actual outcome")
	finish_fx(g)
	g = H.fixture(8); g.presentation_enabled = true
	activate(g,3,"blessing",4)
	H.begin(g,{0:H.give(g,0,"area_strike")}); g.advance_animation()
	check(g.characters[3].hp == 7 and g.characters[4].hp == 8 and g.characters[5].hp == 7,"AOE respects individual blessing")
	check(g.animation.targets[1].blocked and g.animation.targets[1].amount == 0,"blocked target gets shield, not false damage")
	finish_fx(g)
	# Kill rewards are earned by death event, not whether the victim stays dead.
	for key in ["bounty","glory"]:
		g = H.fixture(8); g.presentation_enabled = true
		g.characters[3].hp = 1; H.give_death(g,3,"immortal")
		H.begin(g,{0:H.give(g,0,key)}); g.target(0,3); g.advance_animation()
		check(g.animation.targets[0].reward == key and g.animation.targets[0].revived,"kill reward survives immediate revival: "+key)
		finish_fx(g)
		check(g.characters[0].hand.size() == 2 if key == "bounty" else g.badges[0] == 1,"original reward still applied exactly once: "+key)
		g = H.fixture(8); g.presentation_enabled = true; g.characters[1].hp = 1
		H.begin(g,{0:H.give(g,0,key)}); g.target(0,1); g.advance_animation()
		check(g.animation.targets[0].reward == "","friendly kill never shows reward: "+key)
		finish_fx(g)
	# Skip/cancel never launches a successful hit.
	g = H.fixture(); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"strike")}); g.skip_effect(0)
	check(g.animation.is_empty(),"skipped strike has no hit animation")
	g = H.fixture(); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"magic_strike"),3:H.give(g,3,"magic_amulet")})
	g.target(0,3); g.respond(1,g.request.options[0]); finish_fx(g)
	check(g.characters[3].hp == 5 and g.animation.is_empty(),"cancelled magic strike does no damage")
	g = H.fixture(8); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"judgment")}); g.target(0,3); g.advance_animation()
	check(g.characters[3].hp == 8 and g.animation.targets[0].miss,"unsuccessful judgment has fizzle, no damage")
	finish_fx(g)
	# Pain remains pending until the single strike animation completes.
	g = H.fixture(); g.presentation_enabled = true
	activate(g,1,"pain",1); g.characters[1].hp = 0
	H.begin(g,{0:H.give(g,0,"triple_strike")}); g.target(0,1); g.advance_animation()
	check(g.animation.targets[0].pain and g.animation.targets[0].amount == 0,"dead ally hit shows pain trigger instead of lost HP")
	g.advance_animation()
	finish_fx(g)
	check(g.phase == "selecting" and g.request.type == "bonus","pain automatically draws then offers extra cards after effect")
	# A copied card gets its own event and source actor, without physical duplication.
	g = H.fixture(); g.presentation_enabled = true
	H.begin(g,{0:H.give(g,0,"mirror"),3:H.give(g,3,"strike")})
	g.choose(0,H.action_for(g,3).id); finish_fx(g); g.target(1,0)
	var first: int = g.animation.id
	finish_fx(g); g.target(0,3)
	check(g.animation.style == "strike" and g.animation.action.actor == 0 and g.animation.action.virtual and g.animation.id > first,"mirror copy uses strike style with its own source/event")
	finish_fx(g)
	print("V010_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
