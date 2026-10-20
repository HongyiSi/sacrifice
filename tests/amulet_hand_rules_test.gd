extends SceneTree
const Cases=preload("res://tests/amulet_hand_scenarios.gd")
const S=preload("res://tests/reveal_scenarios.gd")
const Timing=preload("res://scripts/draw_timing.gd")
const Styles=preload("res://scripts/strike_styles.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("AMULET_HAND_FAIL "+label)
func drain(g)->void:
	for i in range(100):
		if g.phase in ["review","ended"]:return
		check(S.step(g)=="","finish remaining jobs")
	check(false,"resolution timeout")
func _initialize()->void:
	for holder in range(6):
		for key in ["holy_amulet","attack_amulet","magic_amulet"]:
			for retained in [false,true]:
				var g=Cases.setup(key,holder,8000+checks,retained)
				check(g.phase=="responding","matching response requested")
				var id:int=g.request.options[0]
				check(g.respond(holder/3,id)=="","valid response accepted")
				check(g.animation.get("hand_response",false) and g.animation.stage=="travel","go straight to hand effect without reveal or card start")
				check(g.characters[holder].hand.has(id) and g.discard.count(id)==0,"amulet remains a real hand card during emission")
				check(g.animation.hand_index==3,"public hand slot uses insertion order")
				var enemy:int=1-holder/3
				check(not g.snapshot(enemy).animation.has("owner_slot") and g.snapshot(enemy).characters[holder].hand.is_empty(),"other identities and sorted hand slot private")
				g.advance_animation()
				check(g.animation.stage=="impact" and g.characters[holder].hand.has(id),"hand stays intact while target burns")
				check(g.characters[holder].hp==8,"canceled card deals no damage")
				g.advance_animation()
				if retained:
					check(g.animation.get("stage","")!="discard" and g.characters[holder].hand.has(id),"defiled amulet returns to hand without discard")
				else:
					check(g.animation.stage=="discard" and Styles.duration(g.animation)==700,"discard follows complete effect")
					check(not g.characters[holder].hand.has(id) and g.discard.count(id)==1,"hand discard exactly once")
				drain(g)
				check(g.discard.count(id)==(0 if retained else 1),"completion never duplicates discarded card")
				var plain=Cases.setup(key,holder,9000+checks,retained,false)
				plain.respond(holder/3,plain.request.options[0]);drain(plain)
				for field in ["characters","deck","discard","queue","phase","log_lines"]:
					check(g.get(field)==plain.get(field),"presentation preserves rules: "+field)
	for index in range(30):
		check(Timing.flight(index)>=1100,"flight never exceeds 1.5 times initial speed")
		check(Timing.gap(index)>=200,"launch cadence never exceeds double initial rate")
		if index>0:check(Timing.flight(index)<=Timing.flight(index-1),"acceleration remains monotonic")
	check(Timing.flight(0)==1650 and Timing.flight(7)==1100,"initial duration unchanged and speed ceiling reached")
	print("AMULET_HAND_RULES_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
