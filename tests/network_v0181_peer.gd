extends SceneTree
const S=preload("res://tests/amulet_scenarios.gd")
const Burn=preload("res://scripts/amulet_cancel_effect.gd")
const BASE=181000
const ACTORS=[0,3,1,4,2,5]
const KEYS=["holy_amulet","holy_amulet","attack_amulet","attack_amulet","magic_amulet","magic_amulet"]
var main
var role:="host"
var prepared:=false
var done:=false
var seen:={}
var observed:={}
var results:Array=[]
var errors:Array=[]
var started:=0
var request_key:=""
var privacy_ok:=true

func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	_run.call_deferred()

func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	await process_frame
	main.music.set_level(0);main.attack_audio.level=0
	main.session.changed.connect(_changed)
	main.session.problem.connect(func(message):errors.append(message);push_error(message))
	started=Time.get_ticks_msec()
	if role=="host":main.session.host_room("护符房主",25189)
	else:main.session.join_room("护符访客","127.0.0.1",25189)

func _setup(index:int)->void:
	main.session.game=S.setup(KEYS[index],ACTORS[index],BASE+index)
	main.session._broadcast()

func _changed()->void:
	var s:Dictionary=main.session.state
	if s.is_empty() or done:return
	if role=="host" and not prepared:
		prepared=true;_setup.call_deferred(0);return
	if s.match<BASE:return
	for c in s.characters:
		if c.team!=main.session.team:privacy_ok=privacy_ok and c.hand.is_empty()
	if s.phase!="review" or seen.has(s.match):return
	seen[s.match]=true
	var index:int=s.match-BASE
	var burned:Array=s.queue.filter(func(a):return a.get("burned_by_amulet","")!="")
	var hp:Array=s.characters.map(func(c):return c.hp)
	var phases:bool=observed.has(str(s.match)+"/travel") and observed.has(str(s.match)+"/impact")
	var ok:bool=hp==[8,8,8,8,8,8] and burned.size()==1 and burned[0].burned_by_amulet==KEYS[index] and phases
	results.append({"key":KEYS[index],"actor":ACTORS[index],"ok":ok,"hp":hp,"target_action":burned[0].id if not burned.is_empty() else -1,"rendered_both_stages":phases})
	if index==KEYS.size()-1:done=true;_finish.call_deferred()
	elif role=="host":_next.call_deferred(index+1)

func _next(index:int)->void:
	await create_timer(.55).timeout
	_setup(index)

func find_effect(node:Node,id:int):
	if node.get_meta("effect_animation",-999)==id:return node
	for child in node.get_children():
		var found=find_effect(child,id)
		if found!=null:return found
	return null

func _process(_delta:float)->bool:
	if started and Time.get_ticks_msec()-started>65000:push_error("NETWORK_V0181_TIMEOUT");quit(2)
	if main==null or done or main.session.state.is_empty():return false
	var s:Dictionary=main.session.state
	if s.match<BASE:return false
	var e:Dictionary=s.animation
	if Burn.supports(e):
		var fx=find_effect(main,e.id)
		if fx!=null and fx.amulet_effect!=null and fx.event.stage==e.stage and is_instance_valid(fx.cancel_target):
			var correct:bool=fx.cancel_target.get_meta("played_action_id")==e.target_action and fx.source_widget.motif_alpha==0
			if correct:observed[str(s.match)+"/"+e.stage]=true
	if s.input.is_empty() or s.input.team!=main.session.team:return false
	var stamp:="%d/%d"%[s.match,s.revision]
	if stamp==request_key:return false
	request_key=stamp
	if s.phase=="targeting":
		var actor:int=s.active_action.actor
		var enemy:int=1-s.characters[actor].team
		main.session.act("target",[enemy*3+(actor+1)%3])
	elif s.phase=="responding":main.session.act("respond",[s.input.options[0]])
	return false

func _finish()->void:
	await create_timer(.2).timeout
	var ok:bool=results.size()==6 and results.all(func(r):return r.ok) and privacy_ok and errors.is_empty()
	var f:=FileAccess.open("res://test-results/network-v0181-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok":ok,"results":results,"privacy_ok":privacy_ok,"errors":errors}));f.close()
	print("NETWORK_V0181_RESULT role=%s cases=%d ok=%s"%[role,results.size(),ok])
	if role=="host":await create_timer(1.5).timeout
	main.session.leave();main.queue_free();await process_frame
	quit(0 if ok else 1)
