extends SceneTree
const H=preload("res://tests/helpers.gd")
const AI=preload("res://scripts/local_ai.gd")
const Actions=preload("res://scripts/match_actions.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fixture(presented:bool=true,owner:int=0):
	var g=H.fixture(H.Rules.MAX_HP);g.characters[owner].hp=2
	var food=H.give(g,owner,"spare_food")
	var supplies=H.give(g,owner,"spare_supplies")
	var ordinary=H.give(g,owner,"strike")
	var rock=g._generate_card(g.BOULDER);g.characters[owner].hand.append(rock)
	var locked=H.give(g,owner,"spare_food");g.defiled_cards[locked]=true
	var blade=H.give(g,owner,"cards_to_blades")
	g.presentation_enabled=presented
	return {"g":g,"owner":owner,"blade":blade,"used":[food,supplies,ordinary],"kept":[rock,locked]}

func settle(g)->void:
	for i in range(400):
		if g.animation.is_empty():return
		g.advance_animation()
	check(false,"animation limit")

func finish(g)->Array:
	var events:Array=[];var bot=AI.new(7)
	for i in range(800):
		if not g.animation.is_empty():
			events.append(g.animation.get("kind","")+"/"+g.animation.get("style","")+"/"+g.animation.get("op",""))
			g.advance_animation();continue
		if g.phase in ["review","ended","planning"]:return events
		var t=int(g.request.get("team",-1))
		if t<0:check(false,"missing input "+g.phase);return events
		var s=g.snapshot(t);var d=bot.decide(s,t)
		if d.is_empty():check(false,"missing decision");return events
		check(Actions.apply(g,t,d.kind,d.payload,s.match,s.round,s.revision)=="","follow-up choice valid")
	check(false,"effect limit");return events

func _initialize()->void:
	for owner in [0,3]:
		var team=int(owner/3);var enemy=(1-team)*3
		for presented in [false,true]:
			var f=fixture(presented,owner);var g=f.g
			H.begin(g,{owner:f.blade});settle(g)
			check(g.request.type=="character" and g.characters[owner].hp==2,"choosing blades precedes reserve effects")
			check(g.characters[owner].hand==f.kept and g.input_action.convert_count==3,"fixed discard cost keeps curses and sealed reserve")
			check(g.snapshot(team).staged_discards.is_empty(),"discard tray stays hidden until conversion completes")
			check(not g.snapshot(1-team).active_action.blade_source.has("owner_hand"),"opponent does not learn converted hand identities from preview")
			check(g.target(team,enemy)=="","single target commits the entire volley")
			check(g.reselect_targets(team)!="","committed single target cannot be changed")
			if presented:
				check(g.animation.kind=="blade_volley" and g.characters[owner].hp==2,"volley appears before food or supplies")
				check(g.snapshot(team).staged_discards.is_empty(),"no duplicate discarded cards during morph")
				for i in range(3):
					g.advance_animation()
					check(g.characters[owner].hp==2 and g.characters[owner].hand==f.kept,"reserve waits through every blade impact")
			var events=finish(g)
			check(g.characters[enemy].hp==4 and g.characters[owner].hp==4,"three hits then food heal resolve exactly once")
			check(g.characters[owner].hand.size()==5 and f.kept.all(func(id):return g.characters[owner].hand.has(id)),"supplies draws three new cards after conversion")
			check(f.used.all(func(id):return g.discard.count(id)==1),"each original card reaches discard once")
			check(g.staged_discards.is_empty() and g.discard_triggers.is_empty() and g.discard_batch_pending.is_empty(),"discard state fully drains")
			if presented:check(events.any(func(e):return "/spare_food/" in e) and events.any(func(e):return "/spare_supplies/" in e),"both reserve animations remain present")
		for interruption in ["skip","amulet","early"]:
			var f=fixture(true,owner);var g=f.g;var guard=0
			if interruption=="amulet":guard=H.give(g,enemy,"attack_amulet")
			if interruption=="early":
				for id in range(enemy,enemy+3):g.characters[id].hp=0
			H.begin(g,{owner:f.blade});settle(g)
			if interruption=="skip":check(g.skip_effect(team)=="","skip during blade targeting")
			elif interruption=="early":check(g.end_round_early(team)=="","early end during blade targeting")
			else:
				g.target(team,enemy)
				check(g.phase=="responding" and g.respond(1-team,guard)=="","amulet cancels volley after paid discard")
			finish(g)
			check(g.characters[owner].hp==4 and g.characters[owner].hand.size()==5,"paid discard reactions survive "+interruption)
			check(f.used.all(func(id):return g.discard.count(id)==1) and g.staged_discards.is_empty(),"interruption cleans pending batch: "+interruption)
	# Delaying passives retains the previously requested dead-holder restriction.
	var f=fixture(true);var g=f.g;H.begin(g,{0:f.blade});settle(g)
	g.target(0,0)
	finish(g)
	check(g.characters[0].hp==0 and g.characters[0].hand==f.kept,"self-lethal volley does not revive holder or trigger dead supplies")
	check(f.used.all(func(id):return g.discard.count(id)==1),"self-lethal volley still discards original costs")
	# A nested divinity picker starts only after the volley; refill choices are not blades.
	f=fixture(true);g=f.g;var god=H.give_death(g,1,"divinity");g._activate({"actor":1,"card":god},1)
	H.begin(g,{0:f.blade});settle(g)
	check(g.request.type=="character","divinity cannot interrupt blade selection")
	g.target(0,3)
	settle(g)
	check(g.characters[3].hp==4 and g.request.type=="deck" and g.request.count==3,"divinity chooses supplies after all three hits")
	finish(g);check(g.characters[0].hand.size()==5,"nested divinity keeps new cards")
	print("BLADE_RESERVE_ORDER_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
