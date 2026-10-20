extends SceneTree
const G=preload("res://tests/hand_transfer_scenarios.gd")
const Styles=preload("res://scripts/strike_styles.gd")
const BASE=220550
const KEYS=["sapphire","ruby","amethyst","holy_amulet","attack_amulet","magic_amulet","curse","ruby"]
const ACTORS=[0,3,1,4,2,5,0,3]
const TARGETS=[3,1,1,5,4,2,3,0]
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
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	_run.call_deferred()
func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await process_frame
	main.music.set_level(0);main.attack_audio.level=0
	main.session.changed.connect(_changed);main.session.problem.connect(func(message):errors.append(message))
	started=Time.get_ticks_msec()
	if role=="host":main.session.host_room("转移房主",25226)
	else:main.session.join_room("转移访客","127.0.0.1",25226)
func _setup(index:int)->void:
	main.session.game=G.setup(KEYS[index],ACTORS[index],TARGETS[index],BASE+index)
	if index==7:
		for key in ["collect","defense","warcry","double_strike","triple_strike","quick_strike"]:G.H.give(main.session.game,0,key)
	main.session._broadcast()
func _changed()->void:
	var s:Dictionary=main.session.state
	if s.is_empty() or done:return
	if role=="host" and not prepared:prepared=true;_setup.call_deferred(0);return
	if s.match<BASE:return
	for c in s.characters:
		if c.team!=main.session.team:privacy_ok=privacy_ok and c.hand.is_empty()
	var flags:Dictionary=observed.get(s.match,{})
	if s.animation.get("kind","")=="hand_transfer" or not flags.get("landing",false) or seen.has(s.match):return
	seen[s.match]=true
	var index:int=s.match-BASE
	var complete:bool=["start","middle","end","landing"].all(func(k):return flags.get(k,false))
	results.append({"key":KEYS[index],"actor":ACTORS[index],"recipient":TARGETS[index],"ok":complete,"observed":flags.duplicate()})
	if index==KEYS.size()-1:done=true;_finish.call_deferred()
	elif role=="host":_next.call_deferred(index+1)
func _next(index:int)->void:
	await create_timer(.5).timeout;_setup(index)
func find_fx(node:Node,id:int):
	if node.get_meta("hand_transfer_animation",-999)==id:return node
	for child in node.get_children():
		var found=find_fx(child,id)
		if found!=null:return found
	return null
func _process(_delta:float)->bool:
	if started and Time.get_ticks_msec()-started>60000:push_error("NETWORK_TRANSFER_TIMEOUT");quit(2)
	if main==null or done or main.session.state.is_empty():return false
	var s:Dictionary=main.session.state
	if s.match<BASE:return false
	var index:int=s.match-BASE
	var e:Dictionary=s.animation
	if e.get("kind","")=="hand_transfer":
		var own:bool=e.recipient/3==main.session.team
		privacy_ok=privacy_ok and e.has("incoming_card")==own and e.has("owner_slot")==own
		var fx=find_fx(main,e.id)
		if fx!=null and fx.event.stage==e.stage:
			if not observed.has(s.match):observed[s.match]={}
			var flags:Dictionary=observed[s.match]
			var t:float=fx.elapsed/(Styles.duration(e)/1000.0)
			var valid:bool=not fx.source_card.visible and (not fx.incoming.visible if e.accepted else fx.incoming==null)
			if valid and e.stage=="travel":
				if t<.2:flags.start=true
				if t>.3 and t<.7:flags.middle=true
				if t>.94:flags.end=fx.flying.hidden_card==not own if e.accepted else fx.flying.modulate.a<.5
			elif valid and t>.4:flags.landing=fx.progress()==1 and (fx.flying.hidden_card==not own if e.accepted else fx.flying.modulate.a==0)
	if s.input.is_empty() or s.input.team!=main.session.team:return false
	var stamp:="%d/%d"%[s.match,s.revision]
	if stamp==request_key:return false
	request_key=stamp
	if s.phase in ["targeting","death_targeting"]:main.session.act("target",[TARGETS[index]])
	return false
func _finish()->void:
	await create_timer(.2).timeout
	var ok:bool=results.size()==KEYS.size() and results.all(func(r):return r.ok) and privacy_ok and errors.is_empty()
	var f:=FileAccess.open("res://test-results/network-hand-transfer-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok":ok,"results":results,"privacy_ok":privacy_ok,"errors":errors},"\t"));f.close()
	print("NETWORK_HAND_TRANSFER_RESULT role=%s cases=%d ok=%s"%[role,results.size(),ok])
	if role=="host":await create_timer(1.5).timeout
	main.session.leave();main.queue_free();await process_frame;quit(0 if ok else 1)
