extends SceneTree
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/v011_scenarios.gd")
var checks:=0
var failures:=0
func _initialize()->void:_run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0178_FAIL "+label)
func setup(animated:bool=false):
	var g=H.fixture(8);g.presentation_enabled=animated
	H.begin(g,{0:H.give(g,0,"ignore"),1:H.give(g,1,"heal"),3:H.give(g,3,"strike")},false)
	return g
func _run()->void:
	for animated in [false,true]:
		var g=setup(animated)
		check(g.request.options==[0,1,2,3,4,5,6],"first number range")
		check(g.choose(1,5)!="" and g.choose(0,7)!="","owner and range validation")
		check(g.choose(0,5)=="" and g.skipped.is_empty(),"first choice has no partial skip")
		check(g.request.options==[0,1,2,3,4,6],"second number excludes first")
		check(g.choose(0,5)!="","duplicate disallowed")
		check(g.choose(0,6)=="","second accepted")
		if animated:
			check(g.animation.values==[5,6] and g.skipped.is_empty(),"animation carries both selections before application")
			g.advance_animation()
			check(g.animation.targets[0].label=="跳过优先级 5、6","feedback shows both")
			g.advance_animation()
		check(g.skipped==[5,6],"both ranks applied together")
		check(g.queue.filter(func(a):return a.actor!=0).all(func(a):return not a.revealed and a.status=="skipped"),"both ranks stay dark")
		check(g.characters[0].hp==8 and g.phase=="review","skipped attacks never damage")
		g.advance_round()
		while not g.animation.is_empty():g.advance_animation()
		check(g.skipped.is_empty(),"next round clears skipped ranks")
	for first in range(7):
		var g=setup();g.choose(0,first)
		check(g.skip_effect(0)=="" and g.skipped.is_empty(),"cancel second selection cancels entire ignore effect")
		for second in range(7):
			if first==second:continue
			g=setup();g.choose(0,first);g.choose(0,second)
			check(g.skipped.has(first) and g.skipped.has(second) and g.skipped.size()==2,"all distinct numeric combinations")
	print("V0178_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
