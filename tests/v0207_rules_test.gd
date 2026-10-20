extends SceneTree
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/reveal_scenarios.gd")
const Cases=preload("res://tests/v0207_scenarios.gd")
const Timing=preload("res://scripts/blade_volley_timing.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0207_FAIL "+label)
func drain(g)->void:
	for _i in range(100):
		if g.phase in ["review","ended"]:return
		S.step(g,false)
func _initialize()->void:
	for actor in range(6):
		var enemy:int=(1-actor/3)*3
		var g=Cases.blades(actor,7207+actor)
		H.give_death(g,enemy,"immortal");g.characters[enemy].hp=1
		for i in range(3):
			g.target(actor/3,enemy)
			check(g.death_events==0,"selecting never kills target")
		for i in range(3):
			check(g.animation.slice_ms==(1080 if i==0 else 300),"server waits for arrival cadence")
			g.advance_animation()
			check(g.death_events==i+1 and g.characters[enemy].hp==1,"each impact resurrects before next impact")
			check(g.animation.hits[-1].revived,"hit publishes real resurrection")
		drain(g)
		g=Cases.blades(actor,7307+actor)
		var guard:int=H.give(g,enemy,"magic_amulet")
		for i in range(2):g.target(actor/3,enemy);check(g.phase=="targeting","response waits for all targets")
		g.target(actor/3,enemy)
		check(g.phase=="responding" and g.characters[enemy].hp==8,"amulet reacts before any knife damage")
		g.respond(enemy/3,guard)
		for _i in range(100):
			check(g.animation.get("kind","")!="blade_volley","cancelled card launches no knives")
			if g.phase in ["review","ended"]:break
			S.step(g,false)
		check(g.characters[enemy].hp==8,"cancelled volley deals zero damage")
		g=Cases.blades(actor,7407+actor);g.target(actor/3,enemy);g.skip_effect(actor/3)
		check(g.characters[enemy].hp==8 and g.characters[actor].hand==[104],"skip before all targets retains cost but no early hits")
		# Snapshot mutation must never change host-private source identities.
		g=Cases.blades(actor,7507+actor)
		var original:Array=g.input_action.blade_source.owner_hand.duplicate()
		for viewer in [0,1]:
			var view:Dictionary=g.snapshot(viewer)
			check(view.active_action.blade_source.has("owner_hand")== (viewer==actor/3),"selection source identities private")
		check(g.input_action.blade_source.owner_hand==original,"redaction never mutates host source")
		# Full hand takes no time per rejected card; accepted arrivals speed up.
		for count in [1,4,8,20]:
			g=Cases.draw(actor,count,8,7607+actor)
			check(g.animation.travel_ms==1900 and g.animation.draws[0].durations.all(func(ms):return ms==0),"one speech replaces any number of rejected flights")
	# Skill damage still ignores Warcry/attack-only protection and honors corpses.
	var g=Cases.blades(0,7707);g.characters[0].warcry_bonus=3;g.characters[0].warcry_round=g.round_number
	var blessing:int=H.give_death(g,4,"blessing");g._activate({"actor":4,"card":blessing},3)
	g.characters[5].hp=0
	for target in [0,3,5]:g.target(0,target)
	for _i in range(3):g.advance_animation()
	check(g.characters[0].hp==7 and g.characters[3].hp==7 and g.characters[5].hp==0,"skill damage obeys existing rules")
	check(g.animation.hits[-1].amount==0,"corpse hit reports no health loss")
	# Final strike can be stopped by an existing shield without early HP loss.
	g=H.fixture(8);g.presentation_enabled=true;g.characters[3].shield=1
	H.begin(g,{0:H.give(g,0,"final_strike")},false);g.target(0,3);g.defend(1,true)
	check(g.animation.kind=="shield_block" and g.animation.style=="final_strike","new strike has shield interception animation")
	drain(g);check(g.characters[3].hp==8,"blocked final strike deals no damage")
	print("V0207_RULES_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
