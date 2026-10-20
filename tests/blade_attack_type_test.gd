extends SceneTree
const H=preload("res://tests/helpers.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func settle(g)->void:
	for i in range(200):
		if g.animation.is_empty():return
		g.advance_animation()
	check(false,"animation limit")
func fixture(actor:int,presented:bool=false):
	var g=H.fixture(20)
	for c in g.characters:c.max_hp=20
	var id=H.give(g,actor,"cards_to_blades")
	H.give(g,actor,"strike");H.give(g,actor,"heal")
	g.presentation_enabled=presented
	return {"g":g,"id":id,"actor":actor,"enemy":3 if actor==0 else 0,"team":actor/3}
func begin(f)->void:
	H.begin(f.g,{f.actor:f.id});settle(f.g)
	check(f.g.phase=="targeting","two converted cards offer one target")
	check(f.g.catalog[f.id].type=="攻击","catalog exposes attack type")
func _initialize()->void:
	for actor in [0,3]:
		for presented in [false,true]:
			var f=fixture(actor,presented);var g=f.g
			begin(f);g.target(f.team,f.enemy);settle(g)
			check(g.characters[f.enemy].hp==18,"base volley still has two one-damage hits")
			for cancel in [false,true]:
				f=fixture(actor,presented);g=f.g
				g.characters[f.enemy].shield=1;g.characters[f.enemy].shield_sources=[f.enemy]
				begin(f);g.target(f.team,f.enemy)
				check(g.phase=="reacting" and g.request.type=="defense","defense can respond before any blade damage")
				check(g.characters[f.enemy].hp==20,"defense decision precedes damage")
				check(g.defend(1-f.team,cancel)=="","defense response accepted")
				settle(g)
				check(g.characters[f.enemy].hp==(20 if cancel else 18),"defense blocks whole card or allows full volley")
				check(g.log_lines.any(func(line):return "防御，取消" in line)==cancel,"only accepted defense cancels the card")
			for key in ["attack_amulet","magic_amulet","holy_amulet"]:
				f=fixture(actor,presented);g=f.g
				var guard=H.give(g,f.enemy,key)
				begin(f);g.target(f.team,f.enemy)
				if key=="magic_amulet":
					check(g.phase!="responding","magic amulet no longer counters an attack")
					settle(g);check(g.characters[f.enemy].hp==18,"magic amulet does not block blades")
				else:
					check(g.phase=="responding","attack and holy amulets counter blades")
					check(g.respond(1-f.team,guard)=="","amulet accepted")
					settle(g);check(g.characters[f.enemy].hp==20,"amulet cancels entire volley")
			f=fixture(actor,presented);g=f.g
			var blessing=H.give_death(g,f.enemy,"blessing")
			g._activate({"id":-1,"actor":f.enemy,"card":blessing,"death":true},f.enemy)
			begin(f);g.target(f.team,f.enemy);settle(g)
			check(g.characters[f.enemy].hp==20,"blessing blocks attack conversion")
			f=fixture(actor,presented);g=f.g
			g.characters[actor].warcry_round=g.round_number;g.characters[actor].warcry_bonus=3
			begin(f);g.target(f.team,f.enemy)
			if presented:
				check(g.animation.kind=="blade_volley","attack keeps blade animation")
				g.advance_animation()
				check(g.animation.hits[0].amount==4 and g.characters[f.enemy].hp==16,"warcry damage text matches actual first hit")
			settle(g);check(g.characters[f.enemy].hp==12,"each hit follows attack damage modifiers")
		var f=fixture(actor);var g=f.g
		var poison=g._generate_card(g.POISON);g.characters[actor].hand.append(poison)
		var plan=[0,0,0];plan[actor%3]=f.id
		check(not g.submit(f.team,plan).is_empty(),"poison prevents playing blades")
	print("BLADE_ATTACK_TYPE checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
