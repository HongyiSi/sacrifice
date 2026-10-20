extends SceneTree
const H=preload("res://tests/helpers.gd")
const G=preload("res://tests/gem_scenarios.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func settle(g)->void:
	for i in range(400):
		if g.animation.is_empty():return
		g.advance_animation()
	check(false,"animation did not finish")

func dance(owner:int,presented:bool):
	var g=H.fixture(7);g.presentation_enabled=presented
	H.give_death(g,owner,"last_dance")
	g.characters[owner].hp=0;g.characters[owner].death_round=g.round_number
	H.begin(g,{});settle(g)
	return g

func _initialize()->void:
	for team in [0,1]:
		var owner=team*3;var enemy=(1-team)*3
		for presented in [false,true]:
			var g=dance(owner,presented)
			check(g.phase=="death_targeting","last dance opens target picker")
			var before=g.characters.map(func(c):return c.hp)
			for id in [enemy,enemy,owner+1,enemy+2]:
				check(g.target(team,id)=="","pending target accepted, including repeat and ally")
				check(g.characters.map(func(c):return c.hp)==before and g.animation.is_empty(),"no damage or animation during first four selections")
			check(g.request.selected_targets==[enemy,enemy,owner+1,enemy+2],"chosen order exposed for review")
			check(g.target(1-team,enemy)!="" and g.target(team,99)!="","wrong player and invalid pawn rejected")
			check(g.reselect_targets(team)=="" and g.request.selected_targets.is_empty(),"reset clears full pending selection")
			for i in range(5):check(g.target(team,enemy)=="","all five repeated targets accepted")
			if presented:
				check(g.characters[enemy].hp==7,"fifth selection starts travel before damage")
				var hits:Array=[]
				for i in range(100):
					if g.animation.is_empty():break
					if g.animation.get("style","")=="last_dance" and g.animation.get("stage","")=="travel":
						hits.append(g.animation.action.hits)
					g.advance_animation()
				check(hits==[1,2,3,4,5],"animation preserves ordered five impacts")
			check(g.characters[enemy].hp==2 and g.characters[owner+1].hp==7,"only final choices take damage")
			check(g.phase=="review","no target requests interrupt the damage sequence")
			g=dance(owner,presented)
			for i in range(4):g.target(team,enemy)
			check(g.skip_effect(team)=="","can skip an uncommitted dance")
			check(G.drain(g) and g.characters[enemy].hp==7,"skipping partial choices deals no damage")
			# All choices precede impacts, but immediate revival still happens per hit.
			g=dance(owner,presented)
			H.give_death(g,enemy,"immortal")
			for id in range(enemy,enemy+3):g.characters[id].hp=1
			for id in [enemy,enemy+1,enemy+2,enemy,enemy]:g.target(team,id)
			check(G.drain(g) and g.characters.slice(enemy,enemy+3).all(func(c):return c.hp==0),"immortal survives first hit and dies after supporters")
			# Frenzy pays HP before forced cards, and preserves unplayable/defiled cards.
			g=H.fixture(7);g.presentation_enabled=presented
			var frenzy=H.give(g,owner,"frenzy")
			var heal=H.give(g,owner,"heal")
			var sealed=H.give(g,owner,"strike");g.defiled_cards[sealed]=true
			var food=H.give(g,owner,"spare_food")
			H.begin(g,{owner:frenzy})
			var saw_loss=not presented
			for i in range(100):
				if g.animation.is_empty():break
				if g.animation.get("op","")=="lose_hp" and g.animation.get("stage","")=="travel":
					check(g.characters[owner].hp==7 and g.characters[owner].hand.has(heal),"loss animation starts before forced play")
					g.advance_animation();saw_loss=true
					check(g.characters[owner].hp==5 and g.characters[owner].hand.has(heal),"frenzy loses two life before cards leave hand")
				else:g.advance_animation()
			check(saw_loss and G.drain(g),"frenzy loss and continuation finish")
			check(g.characters[owner].hp==7 and g.characters[owner].hand==[sealed,food],"heal resolves after cost; locked and unplayable cards remain")
			g=H.fixture(7);g.presentation_enabled=presented
			H.begin(g,{owner:H.give(g,owner,"frenzy")});check(G.drain(g),"empty-hand frenzy completes")
			check(g.characters[owner].hp==5,"empty-hand frenzy still costs two life")
			# Curse is start-of-round damage, including stripping death cards on lethal.
			for hp in [4,3]:
				g=H.fixture(7);g.presentation_enabled=presented
				g.characters[owner].hp=hp;g.death_deck.erase(104);g.characters[owner].hand.append(104)
				var ghost=H.give_death(g,owner,"ghost")
				g._begin_round();settle(g)
				check(g.characters[owner].hp==maxi(0,hp-3),"curse deals three damage")
				check(g.characters[owner].deathrattles.has(ghost)==(hp>3),"lethal curse still removes death cards")
	print("DESIGN_SYNC_OCT15_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
