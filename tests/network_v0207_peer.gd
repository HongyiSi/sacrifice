extends SceneTree
const H=preload("res://tests/helpers.gd")
const Cases=preload("res://tests/v0207_scenarios.gd")
const Styles=preload("res://scripts/strike_styles.gd")
const BASE=720700
const KINDS=["draw","draw","full","full","final","final","blades","blades"]
const ACTORS=[0,3,1,4,2,5,0,3]
var main
var role:="host"
var prepared:=false
var done:=false
var started:=0
var request_key:=""
var observed:={}
var seen:={}
var results:Array=[]
var errors:Array=[]
var privacy_ok:=true
var no_early_damage:=true
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	_run.call_deferred()
func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await process_frame
	main.music.set_level(0);main.attack_audio.level=0
	main.session.changed.connect(_changed);main.session.problem.connect(func(message):errors.append(message))
	started=Time.get_ticks_msec()
	if role=="host":main.session.host_room("动画房主",25227)
	else:main.session.join_room("动画访客","127.0.0.1",25227)
func _setup(index:int)->void:
	var actor:int=ACTORS[index]
	var g
	match KINDS[index]:
		"draw":g=Cases.draw(actor,6,0,BASE+index)
		"full":g=Cases.draw(actor,5,8,BASE+index)
		"blades":g=Cases.blades(actor,BASE+index)
		_:
			g=H.fixture(8);g.match_id=BASE+index;g.presentation_enabled=true;g.resolution_presentation_enabled=true
			H.begin(g,{actor:H.give(g,actor,"final_strike")},false)
	main.session.game=g;main.session._broadcast()
func _changed()->void:
	var s:Dictionary=main.session.state
	if s.is_empty() or done:return
	if role=="host" and not prepared:prepared=true;_setup.call_deferred(0);return
	if s.match<BASE:return
	for c in s.characters:
		if c.team!=main.session.team:privacy_ok=privacy_ok and c.hand.is_empty()
	var flags:Dictionary=observed.get(s.match,{})
	if not s.animation.is_empty() or s.phase not in ["planning","review"] or seen.has(s.match) or flags.is_empty():return
	seen[s.match]=true
	var index:int=s.match-BASE
	var kind:String=KINDS[index]
	var expected:Array=["start","middle","end"]
	if kind=="full":expected=["speech","no_flight"]
	if kind=="final":expected.append("impact")
	if kind=="blades":expected.append_array(["hit_1","hit_2","hit_3"])
	var complete:bool=expected.all(func(k):return flags.get(k,false))
	var enemy:int=(1-ACTORS[index]/3)*3
	if kind=="final":complete=complete and s.characters[enemy].hp==4
	if kind=="blades":complete=complete and s.characters[enemy].hp==6 and s.characters[enemy+1].hp==7
	results.append({"kind":kind,"actor":ACTORS[index],"ok":complete,"observed":flags.duplicate()})
	if index==KINDS.size()-1:done=true;_finish.call_deferred()
	elif role=="host":_next.call_deferred(index+1)
func _next(index:int)->void:
	await create_timer(.6).timeout;_setup(index)
func find_fx(node:Node,key:String,id:int):
	if node.get_meta(key,-999)==id:return node
	for child in node.get_children():
		var found=find_fx(child,key,id)
		if found!=null:return found
	return null
func _process(_delta:float)->bool:
	if started and Time.get_ticks_msec()-started>90000:push_error("NETWORK_V0207_TIMEOUT");quit(2)
	if main==null or done or main.session.state.is_empty():return false
	var s:Dictionary=main.session.state
	if s.match<BASE:return false
	var index:int=s.match-BASE
	var actor:int=ACTORS[index]
	var enemy:int=(1-actor/3)*3
	var e:Dictionary=s.animation
	var kind:String=KINDS[index]
	var expected_kind:String="draw_cards" if kind in ["draw","full"] else "blade_volley" if kind=="blades" else "strike"
	if e.get("kind","")==expected_kind:
		var tag:String="draw_animation" if kind in ["draw","full"] else "blade_volley_animation" if kind=="blades" else "effect_animation"
		var fx=find_fx(main,tag,e.id)
		if fx!=null and fx.event.stage==e.stage:
			if not observed.has(s.match):observed[s.match]={}
			var flags:Dictionary=observed[s.match]
			var t:float=fx.elapsed/(Styles.duration(e)/1000.0)
			if kind=="full":
				if fx.speeches[actor].node.visible:flags.speech=true
				flags.no_flight=fx.flights.is_empty()
			elif kind=="blades":
				privacy_ok=privacy_ok and e.source_hand.has("owner_hand")== (actor/3==main.session.team)
				if fx.tick<250:flags.start=true
				if fx.tick>450 and fx.tick<950:flags.middle=true
				if fx.tick>1650:flags.end=true
				if e.hits.size()>0 and t>.25:flags[e.stage]=true
			else:
				if e.stage=="travel":
					if t<.2:flags.start=true
					if t>.3 and t<.7:flags.middle=true
					if t>.94:flags.end=true
				elif t>.35:flags.impact=true
	if kind=="blades" and s.phase=="targeting":no_early_damage=no_early_damage and s.characters[enemy].hp==8 and s.characters[enemy+1].hp==8
	if s.input.is_empty() or s.input.team!=main.session.team:return false
	var stamp:="%d/%d"%[s.match,s.revision]
	if stamp==request_key:return false
	request_key=stamp
	if s.phase=="targeting":
		var target:int=enemy
		if kind=="blades" and s.active_action.blade_targets.size()==2:target+=1
		main.session.act("target",[target])
	return false
func _finish()->void:
	await create_timer(.2).timeout
	var ok:bool=results.size()==KINDS.size() and results.all(func(r):return r.ok) and privacy_ok and no_early_damage and errors.is_empty()
	var f:=FileAccess.open("res://test-results/network-v0207-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok":ok,"results":results,"privacy_ok":privacy_ok,"no_early_damage":no_early_damage,"errors":errors},"\t"));f.close()
	print("NETWORK_V0207_RESULT role=%s cases=%d ok=%s"%[role,results.size(),ok])
	if role=="host":await create_timer(1.5).timeout
	main.session.leave();main.queue_free();await process_frame;quit(0 if ok else 1)
