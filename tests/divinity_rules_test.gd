extends SceneTree
const H=preload("res://tests/helpers.gd")
const Cases=preload("res://tests/divinity_scenarios.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("DIVINITY_FAIL "+label)
func _initialize()->void:
	for owner in range(6):
		for recipient in range(6):
			var g=Cases.setup(owner,90000+checks)
			var before:int=g.characters[recipient].hand.size()
			g._push([{"op":"draw","target":recipient,"count":2}]);g._pump()
			check(g.animation.kind=="divinity_pulse" and g.animation.targets[0].id==owner,"wave uses owner for any recipient")
			check(g.characters[recipient].hand.size()==before,"pulse cannot prematurely add cards")
			check(g.snapshot(0).animation==g.snapshot(1).animation,"identical public wave")
			check(g.skip_effect(owner/3)!="","pulse cannot be skipped")
			g.advance_animation()
			check(g.phase=="selecting" and g.request.target==recipient and g.request.count==2,"resume unchanged private choice")
			var chosen:Array=g.request.options.slice(0,2)
			check(g.pick(1-owner/3,chosen)!="","opponent cannot choose")
			check(g.pick(owner/3,chosen)=="" and chosen.all(func(id):return g.characters[recipient].hand.has(id)),"chosen cards reach recipient")
		# Living holder is dormant; empty decks and Prison never emit a fake draw.
		var g=Cases.setup(owner,94000+checks);g.characters[owner].hp=1
		g._push([{"op":"draw","target":owner,"count":1}]);g._pump()
		check(g.animation.kind=="draw_cards","living holder does not intercept draw")
		g=Cases.setup(owner,95000+checks);g.deck.clear();g.discard.clear()
		g._push([{"op":"draw","target":owner,"count":1}]);g._pump()
		check(g.animation.is_empty(),"empty draw has no wave")
		g=Cases.setup(owner,96000+checks)
		var prison:int=H.give_death(g,(owner+1)%6,"prison")
		g._activate({"actor":(owner+1)%6,"card":prison},owner)
		g._push([{"op":"draw","target":owner,"count":1}]);g._pump()
		check(g.animation.kind!="divinity_pulse","blocked draw does not emit god wave")
	# Activation keeps the card's rules outcome while the pawn acquires its form.
	var g=H.fixture(8);var id:int=H.give_death(g,0,"divinity");g.characters[0].hp=0;g.presentation_enabled=true
	g._push([g._job("activate",{"id":1,"actor":0,"card":id,"death":true,"status":"active"},{"target":0})]);g._pump()
	check(g.animation.kind=="divinity_awaken" and g._effect_owner("divinity",true)==0,"activation uses angel form instead of sun flight")
	g.advance_animation();check(g.animation.is_empty(),"awakening completes once")
	print("DIVINITY_RULES_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
