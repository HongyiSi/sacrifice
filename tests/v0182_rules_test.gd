extends SceneTree
const H = preload("res://tests/helpers.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V0182_RULES_FAIL "+label)

func finish_fx(g) -> void:
	for _i in range(100):
		if g.animation.is_empty(): return
		g.advance_animation()
	check(false,"animation chain terminates")

func reach_suppression(g) -> void:
	for _i in range(100):
		finish_fx(g)
		if g.phase == "choosing": return
		if g.phase == "responding": g.respond(g.request.team,0)
		else: break
	check(false,"suppression reaches facedown-card choice")

func begin_suppression(g, chosen: Dictionary) -> void:
	# Run suppression before ordinary reveals (as privilege/reversal can do).
	for actor in chosen:
		var id: int = chosen[actor]
		g.characters[actor].hand.erase(id)
		g._add_action(actor,id)
	var source: Dictionary = H.action_for(g,0)
	source.revealed = true
	g.current_main = source.main
	g._start_effect(source)
	g._pump()

func suppression(key: String, amulet: String, presentation: bool) -> void:
	var g = H.fixture(8)
	g.presentation_enabled = presentation
	var strike_key := "strike" if amulet == "attack_amulet" else "magic_strike"
	H.give(g,1,strike_key)
	begin_suppression(g,{0:H.give(g,0,key),1:H.give(g,1,"frenzy"),3:H.give(g,3,amulet)})
	reach_suppression(g)
	var guard: Dictionary = H.action_for(g,3)
	check(g.request.options.has(guard.id),"ordinary-priority hidden amulet is selectable: "+key+"/"+amulet)
	check(g.choose(0,guard.id) == "","suppression choice accepted")
	if presentation:
		check(g.animation.get("style","") == key and g.animation.get("target_action",-1) == guard.id,"both suppression animations point at the actual facedown card")
		check(g.animation.stage == "travel" and guard.status == "pending","suppression holds rule mutation until impact")
		g.advance_animation()
		check(g.animation.stage == "impact" and g.animation.targets[0].label == "压制已施放","same neutral impact caption for immune amulet")
	check(guard.status == ("pending" if presentation else "active"),"suppression never disables amulet; instant mode reaches its normal resolution")
	var enemy_view: Dictionary = g.snapshot(0).queue.filter(func(a): return a.id == guard.id)[0]
	var owner_view: Dictionary = g.snapshot(1).queue.filter(func(a): return a.id == guard.id)[0]
	if presentation:
		check(enemy_view.status == "suppressed" and enemy_view.card == 0 and enemy_view.main == -1,"opponent sees the same sealed hidden card at suppression impact")
	else:
		check(enemy_view.revealed and enemy_view.card == guard.card,"normal later resolution publicly reveals the amulet transfer")
	check(owner_view.status in ["pending","active"] and owner_view.card == guard.card,"owner retains truthful usable amulet state")
	var again: Array = g._effects_for(H.action_for(g,0))[0].options
	check(not again.has(guard.id),"second suppression cannot identify immunity via target availability")
	# Frenzy releases a real later attack even after late suppression's priority.
	var triggered := false
	for _i in range(100):
		finish_fx(g)
		if g.phase == "targeting": g.target(g.request.team,3)
		elif g.phase == "responding":
			if g._info(g.input_action).key == "frenzy": g.respond(g.request.team,0)
			else:
				check(g.request.options.has(guard.card),"suppressed amulet still offered against later card")
				check(g.respond(g.request.team,guard.card) == "","amulet can still activate")
				triggered = true
		elif g.phase in ["review","ended"]: break
		else: break
	check(triggered and guard.revealed,"suppressed amulet still transfers and activates")
	check(g.characters[3].hp == 8,"amulet prevents later damage after apparent suppression")
	var blocked: Array = g.queue.filter(func(a):return g.catalog[a.card].key == strike_key and a.actor == 1)
	check(not blocked.is_empty() and blocked[0].status == "blocked","later whole card is cancelled normally")

func public_suppression(key: String, card_key: String) -> Dictionary:
	var g = H.fixture(8);g.presentation_enabled = true
	begin_suppression(g,{0:H.give(g,0,key),3:H.give(g,3,card_key)})
	reach_suppression(g)
	var other: Dictionary = H.action_for(g,3)
	g.choose(0,other.id)
	var travel: Dictionary = g.snapshot(0).animation
	g.advance_animation()
	var impact: Dictionary = g.snapshot(0).animation
	var public_card: Dictionary = g.snapshot(0).queue.filter(func(a):return a.actor == 3)[0]
	return {"travel":travel,"impact":impact,"card":public_card,"log":g.log_lines}

func _initialize() -> void:
	for key in ["suppress","late_suppress"]:
		for amulet in H.Rules.AMULETS:
			for presentation in [false,true]: suppression(key,amulet,presentation)
		var normal := public_suppression(key,"badge")
		var immune := public_suppression(key,"attack_amulet")
		check(normal.travel == immune.travel,"hidden card identity never changes travel payload: "+key)
		check(normal.impact == immune.impact,"hidden card identity never changes impact payload: "+key)
		check(normal.card == immune.card,"public facedown state stays identical until the actual reveal: "+key)
		check(normal.log == immune.log,"battle log does not identify immune amulet: "+key)
	var g = H.fixture(8)
	for item in ["strike","heal","defense","collect"]: H.give(g,0,item)
	g.characters[5].hp = 0
	H.begin(g,{0:H.give(g,0,"cards_to_blades")})
	check(g.request.options == [0,1,2,3,4,5],"blade can select self, allies, enemies and dead pawns")
	for target in [0,1,4,5]: check(g.target(0,target) == "","blade accepts target %d" % target)
	check(g.characters[0].hp == 7 and g.characters[1].hp == 7 and g.characters[4].hp == 7 and g.characters[5].hp == 0,"each blade hits only its selected pawn")
	check(g.phase == "review" and g.characters[0].hand.is_empty(),"blade finishes after all four paid hits")
	print("V0182_RULES_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
