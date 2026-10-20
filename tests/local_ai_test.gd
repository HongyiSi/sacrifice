extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const AI = preload("res://scripts/local_ai.gd")
const Actions = preload("res://scripts/match_actions.gd")
const H = preload("res://tests/helpers.gd")
var checks := 0
var failures := 0
var inputs := {}
var cards := {}
var wins := [0,0,0]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)

func _initialize() -> void:
	var g = Rules.new(); g.start(42)
	check(g.characters.all(func(c): return c.hp==7 and c.max_hp==7),"All six pawns start with seven HP and max HP")
	check(g.characters.all(func(c): return c.hand.size()==5),"Opening deal still four plus first-round draw")
	g.characters[0].hp=6; g._heal(g.characters[0],20)
	check(g.characters[0].hp==7,"Healing caps at seven")
	g._run_job({"op":"heal","a":{},"target":0,"amount":20,"max_bonus":2})
	check(g.characters[0].max_hp==9 and g.characters[0].hp==9,"Blood rite can still raise the maximum")
	var ai = AI.new(42)
	# Find a lethal target, don't waste healing on the enemy, and skip impossible revival.
	g=H.fixture(); var strike=H.give(g,0,"triple_strike"); g.characters[3].hp=2
	H.begin(g,{0:strike}); var s=g.snapshot(0); var d=ai.decide(s,0)
	check(d.kind=="target" and d.payload==[3],"AI prioritizes a lethal enemy target")
	# The snapshot's restrictions apply to planning, including poison and defile.
	g=H.fixture(); var badge=H.give(g,3,"badge"); var hit=H.give(g,3,"strike")
	g.defiled_cards[badge]=true; g.catalog[1000]=Rules.POISON.duplicate();g.characters[3].hand.append(1000)
	s=g.snapshot(1);d=ai.decide(s,1)
	check(not d.payload[0].has(badge) and not d.payload[0].has(hit),"AI respects sealed cards and poison")
	check(Actions.apply(g,1,d.kind,d.payload,s.match,s.round,s.revision)=="","Restricted plan is legal")
	# Identical player-visible state produces the same plan regardless of secret changes.
	g=Rules.new();g.start(314);s=g.snapshot(1)
	var before=AI.new(17).decide(s,1)
	g.deck.reverse();g.characters[0].hand.reverse();g.plans[0]=[[],[],[]]
	var after=AI.new(17).decide(g.snapshot(1),1)
	check(before==after,"Planning ignores opposing plans and hidden draw order")
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))+JSON.parse_string(FileAccess.get_file_as_string("res://data/deathrattles.json"))
	for row in rows: exercise_card(row.key)
	# Pain offers optional extra cards and greed forces a discard after drawing.
	g=H.fixture();H.give(g,1,"badge");H.give(g,1,"strike")
	g._push([{"op":"planning"}]);g._run_job({"op":"bonus","a":{},"target":1});drive_effect(g,"bonus")
	g=H.fixture();H.give(g,1,"strike");H.give(g,1,"spare_food")
	g._push([{"op":"planning"}]);g._run_job({"op":"discard_one","a":{},"target":1});drive_effect(g,"hand")
	for seed_value in range(1,41): simulate(seed_value)
	print("LOCAL_AI_RESULT checks=%d failures=%d wins=%s input_types=%s resolved_cards=%d" % [checks,failures,wins,inputs.keys(),cards.size()])
	quit(0 if failures==0 else 1)

func exercise_card(key: String) -> void:
	var pair=preload("res://tests/art_scenarios.gd").setup(key)
	drive_effect(pair[0],key)

func drive_effect(g, label: String) -> void:
	var bot=AI.new(19)
	for step in range(800):
		if not g.animation.is_empty():g.advance_animation();continue
		if g.phase in ["planning","review","ended"]:check(true,"card completes "+label);return
		var team=int(g.request.get("team",-1))
		if team<0:check(false,"No input for "+label);return
		var s=g.snapshot(team);inputs[s.input.type]=true
		var d=bot.decide(s,team)
		if d.is_empty():check(false,"Card stalls "+label);return
		var error=Actions.apply(g,team,d.kind,d.payload,s.match,s.round,s.revision)
		if error!="":check(false,"Card %s failed: %s %s"%[label,error,d]);return
	check(false,"Card action limit "+label)

func simulate(seed_value: int) -> void:
	var g=Rules.new();g.start(seed_value)
	var bots=[AI.new(seed_value*11),AI.new(seed_value*13)]
	for step in range(2500):
		if g.phase=="ended":
			wins[g.winner if g.winner in [0,1] else 2]+=1
			check(true,"completed seed %d"%seed_value);return
		if g.phase=="review":g.advance_round();continue
		if not g.animation.is_empty():g.advance_animation();continue
		var team=0 if g.phase=="planning" and g.plans[0]==null else (1 if g.phase=="planning" else int(g.request.get("team",-1)))
		if team<0:check(false,"No owner seed %d phase %s"%[seed_value,g.phase]);return
		var s=g.snapshot(team)
		if not s.input.is_empty():inputs[s.input.type]=true
		if not s.active_card.is_empty():cards[s.active_card.key]=true
		var d=bots[team].decide(s,team)
		if d.is_empty():check(false,"AI stalled seed %d round %d input %s"%[seed_value,g.round_number,s.input]);return
		var error=Actions.apply(g,team,d.kind,d.payload,s.match,s.round,s.revision)
		if error!="":check(false,"Illegal AI action seed %d: %s %s %s"%[seed_value,error,d,s.input]);return
		if not g.characters.all(func(c):return c.hp>=0 and c.hp<=c.max_hp and c.hand.size()<=Rules.HAND_LIMIT):
			check(false,"State invariant failed seed %d"%seed_value);return
	check(false,"Simulation exceeded action limit seed %d round %d"%[seed_value,g.round_number])
