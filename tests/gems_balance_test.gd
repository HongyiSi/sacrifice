extends "res://tests/v018_test.gd"
const G=preload("res://tests/gem_scenarios.gd")

func _initialize()->void:
	for presented in [false,true]:
		for count in [4,6,7,8]:
			var g=H.fixture(7);g.presentation_enabled=presented;H.give(g,0,"sapphire")
			for i in range(count-1):G.give_copy(g,0,"strike")
			g._begin_round();check(G.drain(g),"sapphire draw sequence finishes")
			check(g.characters[0].hand.size()==mini(8,count+2),"sapphire extra draw obeys hand limit")
			check(str(g.log_lines).contains("手牌中的蓝宝石触发"),"sapphire triggers even with seven or eight cards")
			check(_conserved(g),"overflow returns cards without loss or duplication")
		for owner in [0,3]:
			for plays in [false,true]:
				for copies in [1,2]:
					for hp in [0,1,6,7]:
						var g=H.fixture(7);g.presentation_enabled=presented;g.characters[owner].hp=hp
						H.give(g,owner,"ruby")
						if copies==2:G.give_copy(g,owner,"ruby")
						var chosen={}
						if plays and hp>0:chosen[owner]=H.give(g,owner,"badge")
						H.begin(g,chosen);check(G.drain(g),"ruby sequence finishes")
						check(g.characters[owner].hp==(0 if hp==0 else mini(7,hp+copies)),"each held ruby heals one regardless of playing")
		var g=H.fixture(7);g.presentation_enabled=presented;g.characters[0].hp=3
		var ruby=H.give(g,0,"ruby");H.begin(g,{0:ruby})
		check(G.drain(g),"played ruby transfer finishes")
		check(g.characters[0].hp==3,"played ruby does not grant hand passive")
	print("GEMS_BALANCE_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
