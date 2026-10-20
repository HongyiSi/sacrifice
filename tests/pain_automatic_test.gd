extends "res://tests/all_deaths_test.gd"

func _initialize() -> void:
	_pain()
	# Presentation must finish in the actual card picker, never an activation prompt.
	var g = H.fixture()
	activate(g,0,"pain"); die(g,0)
	var extra: int = H.give(g,1,"strike")
	g.presentation_enabled = true
	H.begin(g,{1:H.give(g,1,"strike")})
	g.target(0,0)
	for i in range(100):
		if g.animation.is_empty(): break
		g.advance_animation()
	check(g.phase == "selecting" and g.request.get("type","") == "bonus","animation ends at extra-card selection without activation confirmation")
	check(g.characters[1].hand.has(extra) and g.characters[1].hand.size() == 2,"automatic pain draws exactly once")
	check(g.skip_effect(0) == "","extra cards remain optional")
	for i in range(100):
		if g.animation.is_empty(): break
		g.advance_animation()
	check(g.characters[1].hand.size() == 2 and g.phase == "review","declining extra plays preserves the automatic draw and resumes resolution")
	# The ordinary draw pipeline still enforces the cap.
	g = H.fixture(); activate(g,0,"pain"); die(g,0)
	for id in g.deck.slice(0,8):
		g.deck.erase(id); g.characters[1].hand.append(id)
	var count: int = g.characters[1].hand.size()
	g._run_job({"op":"pain_offer","victim":0,"attacker":1})
	g._pump()
	check(g.characters[1].hand.size() == count,"pain at hand limit does not overfill the hand")
	check(g.request.get("type","") == "bonus","full hand still permits extra plays without activation confirmation")
	print("PAIN_AUTOMATIC_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
