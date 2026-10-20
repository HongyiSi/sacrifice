extends SceneTree
const S=preload("res://tests/reveal_scenarios.gd")
const H=preload("res://tests/helpers.gd")
const BASE=183000
const CASES=8
var main
var role:="host"
var prepared:=false
var done:=false
var results:Array=[]
var errors:Array=[]
var observed:={}
var seen:={}
var started:=0
var request_key:=""
var privacy_ok:=true

func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	_run.call_deferred()
func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await process_frame
	main.music.set_level(0);main.attack_audio.level=0
	main.session.changed.connect(_changed)
	main.session.problem.connect(func(message):errors.append(message))
	started=Time.get_ticks_msec()
	if role=="host":main.session.host_room("翻牌房主",25193)
	else:main.session.join_room("翻牌访客","127.0.0.1",25193)

func _setup(index:int)->void:
	var g
	if index==0:g=S.setup([0,3],BASE+index)
	elif index==7:
		g=H.fixture(8);g.match_id=BASE+index;g.presentation_enabled=true;g.resolution_presentation_enabled=true
		H.give(g,0,"heal");H.give(g,0,"warcry")
		H.begin(g,{0:H.give(g,0,"frenzy")},false)
	else:g=S.Amulets.setup(["holy_amulet","holy_amulet","attack_amulet","attack_amulet","magic_amulet","magic_amulet"][index-1],[0,3,1,4,2,5][index-1],BASE+index)
	main.session.game=g;main.session._broadcast()

func _changed()->void:
	var s:Dictionary=main.session.state
	if s.is_empty() or done:return
	if role=="host" and not prepared:prepared=true;_setup.call_deferred(0);return
	if s.match<BASE:return
	for c in s.characters:
		if c.team!=main.session.team:privacy_ok=privacy_ok and c.hand.is_empty()
	for a in s.queue:
		if a.actor/3!=main.session.team and not a.revealed:privacy_ok=privacy_ok and a.card==0
	if s.phase!="review" or seen.has(s.match):return
	seen[s.match]=true
	var events:Array=[]
	for key in observed:
		if key.begins_with(str(s.match)+"/"):events.append(observed[key])
	var complete:bool=events.size()>=2 and events.all(func(e):return e.before_edge and e.after_edge and e.visible==e.actions.size())
	results.append({"index":s.match-BASE,"hp":s.characters.map(func(c):return c.hp),"burned":s.queue.filter(func(a):return a.has("burned_by_amulet")).map(func(a):return a.burned_by_amulet),"flip_actions":events.map(func(e):return e.actions),"rendered_complete_flips":complete})
	if s.match-BASE==CASES-1:done=true;_finish.call_deferred()
	elif role=="host":_next.call_deferred(s.match-BASE+1)
func _next(index:int)->void:
	await create_timer(.6).timeout;_setup(index)
func find_flip(node:Node,id:int):
	if node.get_meta("card_reveal_action",-1)==id:return node
	for child in node.get_children():
		var result=find_flip(child,id)
		if result!=null:return result
	return null
func _process(_delta:float)->bool:
	if started and Time.get_ticks_msec()-started>110000:push_error("NETWORK_V0183_TIMEOUT");quit(2)
	if main==null or done or main.session.state.is_empty():return false
	var s:Dictionary=main.session.state
	if s.match<BASE:return false
	var event:Dictionary=s.animation
	if event.get("kind","")=="card_reveal":
		var key:="%d/%d"%[s.match,event.id]
		if not observed.has(key):observed[key]={"actions":event.actions.duplicate(),"before_edge":false,"after_edge":false,"visible":0}
		var visible:=0
		for id in event.actions:
			var fx=find_flip(main,id)
			if fx!=null:
				visible+=1
				observed[key].before_edge=observed[key].before_edge or fx.progress<.45
				observed[key].after_edge=observed[key].after_edge or fx.progress>.6
		observed[key].visible=maxi(observed[key].visible,visible)
	if s.input.is_empty() or s.input.team!=main.session.team:return false
	var stamp:="%d/%d"%[s.match,s.revision]
	if stamp==request_key:return false
	request_key=stamp
	match s.phase:
		"targeting":
			var actor:int=s.active_action.actor
			main.session.act("target",[(1-s.characters[actor].team)*3+(actor+1)%3])
		"responding":main.session.act("respond",[s.input.options[0]])
		"selecting":main.session.act("pick",[H.auto_pick(s)])
		"reacting":main.session.act("defend",[true])
	return false
func _finish()->void:
	await create_timer(.2).timeout
	var ok:bool=results.size()==CASES and results.all(func(r):return r.rendered_complete_flips) and privacy_ok and errors.is_empty()
	var f:=FileAccess.open("res://test-results/network-v0183-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok":ok,"results":results,"privacy_ok":privacy_ok,"errors":errors},"\t"));f.close()
	print("NETWORK_V0183_RESULT role=%s cases=%d ok=%s"%[role,results.size(),ok])
	if role=="host":await create_timer(1.5).timeout
	main.session.leave();main.queue_free();await process_frame;quit(0 if ok else 1)
