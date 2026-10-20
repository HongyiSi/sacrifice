extends SceneTree
const Cases=preload("res://tests/divinity_scenarios.gd")
const Styles=preload("res://scripts/strike_styles.gd")
const BASE=920100
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
	if role=="host":main.session.host_room("神化房主",25240)
	else:main.session.join_room("神化访客","127.0.0.1",25240)
func _setup(actor:int)->void:
	var g=Cases.setup(actor,BASE+actor);g.effects.clear()
	var action:={"id":-20,"actor":actor,"card":102,"death":true,"status":"active"}
	g._push([g._job("activate",action,{"target":actor}),{"op":"draw","target":(actor+2)%6,"count":2},{"op":"advance"}]);g._pump()
	main.session.game=g;main.session._broadcast()
func _changed()->void:
	var s:Dictionary=main.session.state
	if s.is_empty() or done:return
	if role=="host" and not prepared:prepared=true;_setup.call_deferred(0);return
	if s.match<BASE:return
	print("DIVINITY_NETWORK_STATE %s match=%d phase=%s kind=%s input=%s"%[role,s.match,s.phase,s.animation.get("kind",""),s.input.get("type","")])
	for c in s.characters:
		if c.team!=main.session.team:privacy_ok=privacy_ok and c.hand.is_empty()
	if s.input.get("type","")=="deck":
		privacy_ok=privacy_ok and s.input.options.is_empty()==(s.input.team!=main.session.team)
	var flags:Dictionary=observed.get(s.match,{})
	if not s.animation.is_empty() or s.phase not in ["planning","review"] or seen.has(s.match) or flags.is_empty():return
	seen[s.match]=true
	var actor:int=s.match-BASE
	var expected:Array=["awake_start","awake_end","pulse_start","pulse_end","caster_origin","no_sun","draw_start","draw_end"]
	var complete:bool=expected.all(func(k):return flags.get(k,false)) and s.characters[(actor+2)%6].hand_count==4
	results.append({"actor":actor,"ok":complete,"observed":flags.duplicate()})
	if actor==5:done=true;_finish.call_deferred()
	elif role=="host":_next.call_deferred(actor+1)
func _next(actor:int)->void:
	await create_timer(.6).timeout;_setup(actor)
func find_fx(node:Node,key:String,id:int):
	if node.get_meta(key,-999)==id:return node
	for child in node.get_children():
		var found=find_fx(child,key,id)
		if found!=null:return found
	return null
func _process(_delta:float)->bool:
	if started and Time.get_ticks_msec()-started>90000:push_error("NETWORK_DIVINITY_TIMEOUT");quit(2)
	if main==null or done or main.session.state.is_empty():return false
	var s:Dictionary=main.session.state
	if s.match<BASE:return false
	var actor:int=s.match-BASE
	if not observed.has(s.match):observed[s.match]={}
	var flags:Dictionary=observed[s.match]
	var e:Dictionary=s.animation
	var form=find_fx(main,"divinity_actor",actor)
	if e.get("kind","")=="divinity_awaken" and form!=null:
		if form.strength<.2:flags.awake_start=true
		if form.strength>.96:flags.awake_end=true
	if e.get("kind","")=="divinity_pulse":
		var pulse=find_fx(main,"divinity_pulse",e.id)
		if pulse!=null:
			if pulse.elapsed<.25:flags.pulse_start=true
			if pulse.elapsed>1.43:flags.pulse_end=true
			flags.caster_origin=pulse.owner_pose==form
			var card=find_fx(main,"death_card_id",102)
			flags.no_sun=find_fx(main,"effect_animation",e.id)==null and card!=null and card.motif_alpha==1
	if e.get("kind","")=="draw_cards":
		var fx=find_fx(main,"draw_animation",e.id)
		if fx!=null:
			var t:float=fx.elapsed/(Styles.duration(e)/1000.0)
			if t<.2:flags.draw_start=true
			if t>.95:flags.draw_end=true
	if s.phase=="selecting" and s.input.get("type","")=="deck" and s.input.team==main.session.team:
		var stamp:="%d/%d"%[s.match,s.revision]
		if stamp!=request_key:request_key=stamp;main.session.act("pick",s.input.options.slice(0,s.input.count))
	return false
func _finish()->void:
	await create_timer(.2).timeout
	var ok:bool=results.size()==6 and results.all(func(r):return r.ok) and privacy_ok and errors.is_empty()
	var f:=FileAccess.open("res://test-results/network-divinity-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok":ok,"results":results,"privacy_ok":privacy_ok,"errors":errors},"\t"));f.close()
	print("NETWORK_DIVINITY_RESULT role=%s cases=%d ok=%s"%[role,results.size(),ok])
	if role=="host":await create_timer(1.5).timeout
	main.session.leave();main.queue_free();await process_frame;quit(0 if ok else 1)
