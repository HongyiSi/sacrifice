extends SceneTree
const Cases=preload("res://tests/amulet_hand_scenarios.gd")
const Draw=preload("res://tests/v0207_scenarios.gd")
const Styles=preload("res://scripts/strike_styles.gd")
const BASE=820800
const KEYS=["holy_amulet","holy_amulet","attack_amulet","attack_amulet","magic_amulet","magic_amulet","retained","retained","draw","draw"]
const ACTORS=[0,3,1,4,2,5,0,3,2,5]
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
var order_ok:=true
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	_run.call_deferred()
func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await process_frame
	main.music.set_level(0);main.attack_audio.level=0
	main.session.changed.connect(_changed);main.session.problem.connect(func(message):errors.append(message))
	started=Time.get_ticks_msec()
	if role=="host":main.session.host_room("动画房主",25238)
	else:main.session.join_room("动画访客","127.0.0.1",25238)
func _setup(index:int)->void:
	var g
	if KEYS[index]=="draw":g=Draw.draw(ACTORS[index],8,0,BASE+index)
	else:g=Cases.setup("holy_amulet" if KEYS[index]=="retained" else KEYS[index],ACTORS[index],BASE+index,KEYS[index]=="retained")
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
	var key:String=KEYS[index]
	var expected:Array=["emission","burn","hand_source","no_played"]
	if key=="draw":expected=["start","middle","end","speed_cap"]
	elif key!="retained":expected.append_array(["discard_start","discard_end"])
	var holder:Dictionary=s.characters[ACTORS[index]]
	var complete:bool=expected.all(func(k):return flags.get(k,false)) and holder.hp==8 and holder.hand_count==(8 if key in ["retained","draw"] else 7)
	results.append({"key":key,"actor":ACTORS[index],"ok":complete,"observed":flags.duplicate()})
	if index==KEYS.size()-1:done=true;_finish.call_deferred()
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
	if started and Time.get_ticks_msec()-started>150000:push_error("NETWORK_AMULET_HAND_TIMEOUT");quit(2)
	if main==null or done or main.session.state.is_empty():return false
	var s:Dictionary=main.session.state
	if s.match<BASE:return false
	var index:int=s.match-BASE
	var e:Dictionary=s.animation
	if e.get("hand_response",false) or e.get("kind","")=="draw_cards":
		var fx=find_fx(main,"draw_animation" if KEYS[index]=="draw" else "effect_animation",e.id)
		if fx!=null and fx.event.stage==e.stage:
			if not observed.has(s.match):observed[s.match]={}
			var flags:Dictionary=observed[s.match]
			var t:float=fx.elapsed/(Styles.duration(e)/1000.0)
			if KEYS[index]=="draw":
				if t<.2:flags.start=true
				if t>.3 and t<.7:flags.middle=true
				if t>.95:flags.end=true
				flags.speed_cap=e.draws[0].durations.all(func(ms):return ms>=1100) and e.draws[0].durations[-1]==1100
			else:
				privacy_ok=privacy_ok and e.has("owner_slot")==(ACTORS[index]/3==main.session.team)
				flags.no_played=find_fx(main,"played_action_id",e.action.id)==null
				if e.stage=="travel":
					if t>.25 and t<.8:flags.emission=true
					flags.hand_source=fx.hand_source!=null and fx.hand_source.get_parent().has_meta("hand_actor" if ACTORS[index]/3==main.session.team else "enemy_hand_actor")
				if e.stage=="impact" and t>.6:flags.burn=true
				if e.stage=="discard":
					if t<.25:flags.discard_start=true
					if t>.95:flags.discard_end=true
				order_ok=order_ok and s.characters[ACTORS[index]].hand_count==(7 if e.stage=="discard" else 8)
	if s.phase=="responding" and s.input.team==main.session.team:
		var stamp:="%d/%d"%[s.match,s.revision]
		if stamp!=request_key:request_key=stamp;main.session.act("respond",[s.input.options[0]])
	return false
func _finish()->void:
	await create_timer(.2).timeout
	var ok:bool=results.size()==KEYS.size() and results.all(func(r):return r.ok) and privacy_ok and order_ok and errors.is_empty()
	var f:=FileAccess.open("res://test-results/network-amulet-hand-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok":ok,"results":results,"privacy_ok":privacy_ok,"order_ok":order_ok,"errors":errors},"\t"));f.close()
	print("NETWORK_AMULET_HAND_RESULT role=%s cases=%d ok=%s"%[role,results.size(),ok])
	if role=="host":await create_timer(1.5).timeout
	main.session.leave();main.queue_free();await process_frame;quit(0 if ok else 1)
