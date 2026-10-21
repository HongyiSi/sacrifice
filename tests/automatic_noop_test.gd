extends "res://tests/v018_test.gd"
const G = preload("res://tests/gem_scenarios.gd")

func trace_until_idle(g) -> Array:
	var events: Array = []
	for _i in range(600):
		if not g.animation.is_empty():
			var a: Dictionary = g.animation.get("action",{})
			if not a.is_empty(): events.append(g._info(a).key)
		if g.animation.is_empty() and g.phase in ["planning","review","ended"]: return events
		check(G.S.step(g)=="","automatic sequence advances legally")
	check(false,"automatic sequence terminates")
	return events

func _initialize() -> void:
	for presented in [false,true]:
		for actor in [0,3]:
			for hp in [0,6,7]:
				var g=H.fixture(7);g.presentation_enabled=presented;g.characters[actor].hp=hp
				var id=H.give(g,actor,"ruby");G.give_copy(g,actor,"ruby")
				H.begin(g,{});var events=trace_until_idle(g)
				check(g.characters[actor].hp==(7 if hp>0 else 0),"ruby heals only missing health")
				check(g.log_lines.filter(func(l):return "手牌中的红宝石触发" in l).size()==(1 if hp==6 else 0),"duplicate rubies recheck after the first heal")
				check(events.has("ruby")== (presented and hp==6),"no empty ruby animation")
				check(g.characters[actor].hand.has(id),"skipped ruby is retained")
			for count in [5,6,7,8]:
				var g=H.fixture(7);g.presentation_enabled=presented
				H.give(g,actor,"sapphire");G.give_copy(g,actor,"sapphire")
				while g.characters[actor].hand.size()<count:G.give_copy(g,actor,"strike")
				g._begin_round();var events=trace_until_idle(g)
				check(g.characters[actor].hand.size()==8,"extra draws reserve a normal draw slot")
				check(g.log_lines.filter(func(l):return "手牌中的蓝宝石触发" in l).size()==mini(2,maxi(0,7-count)),"each sapphire rechecks remaining capacity")
				check(events.has("sapphire")== (presented and count<=6),"no empty sapphire animation")
			for key in ["ruby","sapphire"]:
				var g=H.fixture(7);g.presentation_enabled=presented;g.characters[actor].hp=3
				H.give(g,actor,key);activate(g,3 if actor==0 else 0,"blessing" if key=="ruby" else "prison",actor)
				g.visual_queue.clear();g.log_lines.clear()
				if key=="ruby":H.begin(g,{})
				else:g._begin_round()
				var events=trace_until_idle(g)
				check(not events.has(key) and not str(g.log_lines).contains("手牌中的"),"blocked passive has no trigger or animation")
				check(g.characters[actor].hp==3,"blocked passive leaves health unchanged")
		for hp in [0,2,5]:
			var g=H.fixture(7);g.presentation_enabled=presented;g.characters[0].hp=hp
			g.death_deck.erase(104);g.characters[0].hand.append(104);var death=H.give_death(g,0,"eye")
			g._begin_round();var events=trace_until_idle(g)
			check(events.has("curse")== (presented and hp>0),"wither never animates against a corpse")
			check(g.characters[0].hp==maxi(0,hp-3),"living holders still take three damage")
			check(g.characters[0].deathrattles.has(death)==(hp!=2),"only an actual wither kill strips death cards")
			check(g.characters[0].hand.has(104),"wither stays in hand even when skipped")
		for key in ["spare_food","spare_supplies"]:
			for useful in [false,true]:
				var g=H.fixture(7);g.presentation_enabled=presented;g.characters[0].hp=5 if useful else 7
				var id=H.give(g,0,key)
				if key=="spare_supplies" and not useful:g.deck.clear();g.discard.clear()
				g._discard_hand_card(g.characters[0],id);g._pump();trace_until_idle(g)
				check(str(g.log_lines).contains("触发弃牌效果")==useful,"discard passives skip only ineffective rewards")
				check(g.discard.has(id) and not g.characters[0].hand.has(id),"cost is still discarded even when reward skips")
		for ally in [false,true]:
			var g=H.fixture(7);g.presentation_enabled=presented;H.give_death(g,0,"immortal")
			g.characters[0].hp=0;g.characters[1].hp=1 if ally else 0;g.characters[2].hp=0
			g._try_immortal(0);g._pump();var events=trace_until_idle(g)
			check(g.characters[0].hp==(1 if ally else 0),"immortal still revives with a living ally")
			check(events.has("immortal")== (presented and ally),"immortal skips empty resurrection")
			check(g.death_revealed.has(120)==ally,"skipped immortal is not revealed")
		for key in ["sacrifice_badges","legacy"]:
			for ally in [false,true]:
				var g=H.fixture(7);g.presentation_enabled=presented
				var id=H.give_death(g,0,key);g.characters[0].hp=0;g.characters[0].death_round=g.round_number
				g.characters[1].hp=7 if ally else 0;g.characters[2].hp=0
				H.begin(g,{});var events=trace_until_idle(g)
				check(events.has(key)==(presented and ally),"one-shot automatic death skips a missing beneficiary")
				check(g.characters[0].deathrattles.has(id)==not ally,"unused one-shot death is retained")
				check(g.death_discard.has(id)==ally,"only a triggered death is discarded")
				check(g.triggered_deaths.get(0,[]).any(func(d):return d.card==id)==ally,"skipped death has no triggered marker")
		for can_draw in [false,true]:
			for can_play in [false,true]:
				var g=H.fixture(7);g.presentation_enabled=presented;g.characters[1].hp=0
				activate(g,1,"pain");g.visual_queue.clear();g.log_lines.clear()
				if can_play:H.give(g,0,"strike")
				while g.characters[0].hand.size()<(7 if can_draw else 8):g.characters[0].hand.append(g._generate_card(g.BOULDER))
				var attack=g._visual_action("strike",0)
				g._damage(attack,1,1);g._pump();var events: Array=[]
				for _i in range(50):
					if g.animation.is_empty():break
					var a: Dictionary=g.animation.get("action",{})
					if not a.is_empty():events.append(g._info(a).key)
					g.advance_animation()
				check(g.animation.is_empty(),"pain cue finishes before bonus choice")
				check(str(g.log_lines).contains("苦肉自动发动")== (can_draw or can_play),"pain skips only when both draw and bonus play are unavailable")
				check(events.has("pain")== (presented and (can_draw or can_play)),"pain retains real draw or extra-play benefits")
	# A pending gem must recheck both ownership and current capacity, not a cached flag.
	var g=H.fixture(7);var id=H.give(g,0,"sapphire")
	while g.characters[0].hand.size()<6:G.give_copy(g,0,"strike")
	activate(g,1,"greed");g.round_number+=1
	check(not g._gem_valid({"target":0,"card":id}),"greed reserves both normal round draws")
	g=H.fixture(7);id=H.give(g,0,"sapphire");g.deck=g.deck.slice(0,1);g.discard.clear()
	check(not g._gem_valid({"target":0,"card":id}),"last drawable card is reserved for normal draw")
	g.discard.append(g._generate_card(g.catalog[id]))
	check(g._gem_valid({"target":0,"card":id}),"reshufflable discard counts as available cards")
	g.characters[0].hand.erase(id)
	check(not g._gem_valid({"target":0,"card":id}),"removed gem never triggers")
	print("AUTOMATIC_NOOP_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
