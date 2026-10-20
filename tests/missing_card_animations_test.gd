extends SceneTree
const H = preload("res://tests/helpers.gd")
const Cases = preload("res://tests/v011_scenarios.gd")
const Styles = preload("res://scripts/card_effect_styles.gd")
var checks := 0
var failures := 0
var seen := {}
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1;push_error("MISSING_ANIMATION_FAIL "+message)
func setup(key: String, shown: bool):
	if key != "poison":return Cases.setup(key,key=="legacy",shown)
	var g = H.fixture();g.presentation_enabled=shown
	var id: int = g._generate_card(H.Rules.POISON)
	g.characters[0].hand.append(id);H.begin(g,{0:id});return g
func drain(g, key: String) -> void:
	for i in range(350):
		if g.animation.is_empty() and g.phase in ["review","planning","ended"]:return
		if not g.animation.is_empty():
			var e: Dictionary = g.animation
			if e.get("style","")==key and e.kind in ["card_effect","heal"]:seen[key]=true
			for viewer in [0,1]:
				var s: Dictionary = g.snapshot(viewer)
				if s.animation.has("hand_motion"):
					var m: Dictionary = s.animation.hand_motion
					if m.actor/3 != viewer and not s.omniscient:
						check(not m.has("owner_cards") and not m.has("owner_slots"),key+" private selected cards")
				if e.kind=="draw_cards":
					for d in s.animation.draws:
						if d.target/3!=viewer and not s.omniscient:check(not d.has("ids") and not d.has("before_hand"),key+" private gains")
		var err: String = Cases.step(g)
		check(err.is_empty(),key+" progresses: "+err)
		if not err.is_empty():return
	check(false,key+" did not finish")
func job_game(key: String, actor: int = 0):
	var g = H.fixture();g.presentation_enabled=true;g.phase="resolution";g.turn_stage="resolution"
	var id: int = H.give(g,actor,key);g.characters[actor].hand.erase(id)
	var a: Dictionary = g._add_action(actor,id);a.status="active"
	return [g,a]
func _initialize() -> void:
	for key in Styles.NEW_CARDS:
		var shown = setup(key,true);var plain = setup(key,false)
		drain(shown,key);drain(plain,key)
		check(seen.has(key),key+" has a thematic event")
		for field in ["characters","deck","discard","death_deck","death_discard","effects","badges","log_lines","phase","winner","defiled_cards","reveal_locked_teams"]:
			check(shown.get(field)==plain.get(field),key+" identical rules: "+field)
	# Placement is an actual gain with exact accepted count, not a draw trigger.
	for key in ["gift","poisoning","obstruct","search"]:
		for actor in [0,3]:
			for space in [0,1,2]:
				var pair: Array = job_game(key,actor);var g = pair[0];var a: Dictionary = pair[1]
				var target: int = 3-actor
				for i in range(8-space):g.characters[target].hand.append(g.deck.pop_back())
				var ids: Array = []
				for i in range(2):ids.append(g.deck.pop_back())
				for i in range(2):g._put_in_hand(target,ids[i],a,{"kind":"hand","actor":actor,"slot":i,"owner_slot":1-i})
				var count := 0;var speech := 0
				for e in g.visual_queue:
					if e.kind=="draw_cards":
						for d in e.draws:count+=d.count
					if e.kind=="pawn_speech":speech+=1
				check(count==space,"only accepted placement flies "+key)
				check(speech==int(space<2),"single overflow speech "+key)
				check(g.characters[target].hand.size()==8,"cap enforced "+key)
	# The conversion and sifting visual selects precisely the cards rules consume.
	var pair: Array = job_game("cards_to_heart");var g = pair[0];var a: Dictionary = pair[1]
	var free: int = H.give(g,0,"strike");var sealed: int = H.give(g,0,"heal")
	g.defiled_cards[sealed]=true;g.characters[0].hand.append(g._generate_card(H.Rules.BOULDER))
	g._push([g._job("convert_hand",a)]);g._pump()
	check(g.animation.hand_motion.owner_cards==[free],"conversion excludes protected cards")
	check(g.characters[0].hand.has(free),"conversion waits for impact")
	g.advance_animation();check(not g.characters[0].hand.has(free) and g.characters[0].hand.has(sealed),"conversion applies once at impact")
	pair=job_game("gold_panning");g=pair[0];a=pair[1]
	var old: int = H.give(g,0,"heal");var fresh: int = H.give(g,0,"heal");sealed=H.give(g,0,"defense")
	g.defiled_cards[sealed]=true
	g._push([g._job("gold_filter",a,{"before":[old]})]);g._pump()
	check(g.animation.hand_motion.owner_cards==[fresh],"sieve only selects eligible newly drawn card")
	g.advance_animation();check(g.characters[0].hand==[old,sealed],"sieve preserves old and protected cards")
	# Private Defile selection acquires its persistent seal exactly at impact.
	pair=job_game("defile");g=pair[0];a=pair[1];free=H.give(g,3,"strike")
	g._push([g._job("defile_seal",a,{"target":3,"value":free})]);g._pump()
	check(not g.defiled_cards.has(free),"seal waits for contact")
	check(not g.snapshot(0).animation.hand_motion.has("owner_cards"),"selected enemy identity absent from animation")
	g.advance_animation();check(g.defiled_cards.has(free),"seal locks selected physical card")
	print("MISSING_ANIMATIONS_RESULT checks=%d failures=%d covered=%d"%[checks,failures,seen.size()])
	quit(0 if failures==0 else 1)
