extends SceneTree
const H=preload("res://tests/helpers.gd")
const Session=preload("res://scripts/session.gd")
const MODES=["gain","gain","full","full","skip","skip","empty","empty"]
const BASE=250000
var session
var role="host"
var prepared=false
var done=false
var results=[]
var seen={}
var observed={}
var stamp=""
var started=0
var privacy_ok=true
var errors=[]
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	run.call_deferred()
func run():
	session=Session.new();root.add_child(session)
	session.changed.connect(changed)
	session.problem.connect(func(message):errors.append(message);push_error(message))
	started=Time.get_ticks_msec()
	if role=="host":session.host_room("搜寻房主",25250)
	else:session.join_room("搜寻访客","127.0.0.1",25250)
func setup(index):
	var actor=1+(index%2)*3;var mode=MODES[index]
	var g=H.fixture(8);g.match_id=BASE+index;g.presentation_enabled=true;g.resolution_presentation_enabled=true
	H.give(g,actor,"defense")
	if mode=="full":
		while g.characters[actor].hand.size()<8:H.give(g,actor,"strike")
	var card=H.give(g,actor,"search")
	if mode=="empty":g.deck.clear()
	H.begin(g,{actor:card},false)
	session.game=g;session._broadcast()
func changed():
	var s:Dictionary=session.state
	if s.is_empty() or done:return
	if role=="host" and not prepared:prepared=true;setup.call_deferred(0);return
	if s.match<BASE:return
	var index=int(s.match)-BASE;var actor=1+(index%2)*3;var mode=MODES[index]
	if not observed.has(s.match):observed[s.match]={"wait":false,"depart":false,"flight":false,"order":true}
	var state:Dictionary=observed[s.match]
	if s.phase=="selecting" and s.input.get("type","")=="search":
		state.wait=true
		if s.input.team!=session.team:privacy_ok=privacy_ok and s.input.options.is_empty()
	for c in s.characters:
		if c.team!=session.team:privacy_ok=privacy_ok and c.hand.is_empty()
	var e:Dictionary=s.animation
	if e.get("op","")=="search_depart":
		state.depart=true;state.order=state.order and state.wait
		privacy_ok=privacy_ok and s.characters[actor].hand_count==(8 if mode=="full" else 1)
	if e.get("kind","")=="draw_cards":
		state.flight=true;state.order=state.order and state.depart and mode=="gain"
		if session.team!=actor/3:
			for entry in e.draws:privacy_ok=privacy_ok and not entry.has("ids")
	if s.phase!="review" or seen.has(s.match):return
	seen[s.match]=true
	var expected=2 if mode=="gain" else 8 if mode=="full" else 1
	var ok=s.characters[actor].hand_count==expected and state.order and state.wait==(mode!="empty") and state.depart==(mode in ["gain","full"]) and state.flight==(mode=="gain")
	results.append({"mode":mode,"actor":actor,"ok":ok,"observed":state.duplicate(),"hand_count":s.characters[actor].hand_count})
	if index==MODES.size()-1:done=true;finish.call_deferred()
	elif role=="host":next_case.call_deferred(index+1)
func next_case(index):
	await create_timer(.5).timeout;setup(index)
func _process(_delta)->bool:
	if started and Time.get_ticks_msec()-started>120000:push_error("NETWORK_SEARCH_TIMEOUT");quit(2)
	if session==null or done or session.state.is_empty():return false
	var s:Dictionary=session.state
	if s.match<BASE or s.input.is_empty() or s.input.team!=session.team:return false
	var next_stamp="%d/%d"%[s.match,s.revision]
	if next_stamp==stamp:return false
	stamp=next_stamp
	if s.phase=="selecting" and s.input.type=="search":
		if MODES[int(s.match)-BASE]=="skip":session.act("skip_effect",[])
		else:session.act("pick",[s.input.options[0]])
	return false
func finish():
	await create_timer(.2).timeout
	var ok=results.size()==MODES.size() and results.all(func(r):return r.ok) and privacy_ok and errors.is_empty()
	var f=FileAccess.open("res://test-results/network-search-compass-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok":ok,"privacy_ok":privacy_ok,"results":results,"errors":errors}));f.close()
	print("NETWORK_SEARCH_RESULT role=%s cases=%d ok=%s"%[role,results.size(),ok])
	if role=="host":await create_timer(1.5).timeout
	session.leave();quit(0 if ok else 1)
