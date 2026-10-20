extends SceneTree
const H = preload("res://tests/helpers.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V0171_FAIL "+label)
func cursed(g, actor: int) -> void:
	g.death_deck.erase(104); g.characters[actor].hand.append(104); g.characters[actor].curse_exposed=true
func retained(g, actor: int) -> void:
	check(g.characters[actor].hand.has(104),"curse retained")
	check(not g.discard.has(104) and not g.death_discard.has(104),"no discard pile contains curse")
	check(g.characters[actor].curse_exposed,"public curse status preserved")
func _initialize() -> void:
	# Central protection covers direct, repeated and whole-hand discard.
	var g = H.fixture(8); cursed(g,0); var plain = H.give(g,0,"strike")
	g._discard_hand_card(g.characters[0],104); retained(g,0)
	g._discard_hand(g.characters[0]); retained(g,0)
	check(g.characters[0].hand == [104] and g.discard.has(plain),"whole hand discards only ordinary cards")
	g._discard_hand(g.characters[0]); retained(g,0)
	# Cap counts the curse but only offers discardable cards.
	g=H.fixture(8); cursed(g,3); g._draw(g.characters[3],8); g._pump()
	check(g.request.type=="hand_limit" and g.request.count==1 and g.request.options.size()==8,"eight eligible choices for nine-card hand")
	check(g.pick(1,[104])!="","network choice cannot discard curse")
	g.pick(1,[g.request.options[0]])
	retained(g,3); check(g.characters[3].hand.size()==8,"curse occupies one of eight slots")
	# Even a forged/stale option list cannot bypass the central selection guard.
	g=H.fixture(8); cursed(g,0); g._draw(g.characters[0],8); g._pump(); g.request.options.append(104)
	check(g.pick(0,[104])!="" and g.request.type=="hand_limit","forged option does not mutate state")
	# Curse cannot fund elegy; with enough ordinary cards the cost still works.
	g=H.fixture(8); cursed(g,0); var one = H.give(g,0,"strike"); var two = H.give(g,0,"heal")
	H.begin(g,{0:H.give(g,0,"elegy")})
	check(g.request.type=="elegy" and not g.request.options.has(104),"elegy filters curse")
	check(g.pick(0,[one,104])!="" and g.characters[0].hand.has(one),"invalid cost atomic")
	check(g.pick(0,[one,two])=="" and g.characters[0].deathrattles.size()==1,"eligible cost obtains deathrattle")
	retained(g,0)
	# Only the curse remains: mandatory one-card discard must not deadlock.
	g=H.fixture(8); cursed(g,0)
	g._push([{"op":"discard_one","target":0,"a":{}}]); g._pump()
	check(g.request.is_empty(),"no impossible forced discard prompt")
	retained(g,0)
	# Gambler still draws seven. Together with the retained curse it exactly
	# fills the new eight-slot hand, so there is no unnecessary discard prompt.
	g=H.fixture(8); cursed(g,0); var old = H.give(g,0,"strike")
	H.begin(g,{0:H.give(g,0,"gambler")})
	check(g.request.is_empty() and g.phase=="review","gambler plus curse fits new limit")
	check(g.discard.has(old),"gambler discards old ordinary hand")
	retained(g,0)
	check(g.characters[0].hand.size()==8,"gambler finishes with seven ordinary cards and curse")
	# Disappearance uses the same invariant on a dead target.
	g=H.fixture(8); cursed(g,3); g.characters[3].hp=0; H.give(g,3,"strike")
	g._push([{"op":"discard_all","target":3}]);g._pump()
	retained(g,3);check(g.characters[3].hand==[104],"dead pawn keeps curse after disappearance")
	# Transfer is not discard: theft is allowed, new holder remains protected.
	g=H.fixture(8);cursed(g,3)
	g._push([{"op":"plunder","target":3,"a":{"actor":0,"status":"active"}}]);g._pump()
	check(g.characters[0].hand==[104] and g.characters[3].hand.is_empty(),"theft still transfers curse")
	g._discard_hand(g.characters[0]);check(g.characters[0].hand==[104],"transferred curse still cannot be discarded")
	print("V0171_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
