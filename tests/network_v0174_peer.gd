extends SceneTree
const Session=preload("res://scripts/session.gd")
const H=preload("res://tests/helpers.gd")
const Styles=preload("res://scripts/strike_styles.gd")
const KEYS=["godslayer","bounty","area_strike","glory"]
var session
var role:="host"
var port:=25174
var started:=0
var prepared:=false
var completed:=false
var seen:={}
var reviewed:={}
var planned:={}
var last_request:=""
var trace:Array=[]
var reward_stages:=0
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
		if arg.begins_with("--port="):port=int(arg.trim_prefix("--port="))
	session=Session.new();session.name="Session";root.add_child.call_deferred(session);_begin.call_deferred()
func fail(message:String)->void:push_error("V0174_NETWORK_FAIL "+message);quit(2)
func _begin()->void:
	started=Time.get_ticks_msec();session.problem.connect(fail);session.changed.connect(_changed)
	if role=="host":session.host_room("房主",port)
	else:session.join_room("访客","127.0.0.1",port)
func _changed()->void:
	var s:Dictionary=session.state
	if s.is_empty() or completed:return
	if role=="host" and not prepared:prepared=true;_setup.call_deferred(0);return
	if s.match<17400:return
	for c in s.characters:
		if c.team!=session.team and not c.hand.is_empty():fail("private draw identities leaked");return
	if not s.animation.is_empty():
		var e:Dictionary=s.animation
		var stamp:String="%d/%d/%s"%[s.match,e.id,e.stage]
		if not seen.has(stamp):
			seen[stamp]=Time.get_ticks_msec()
			trace.append({"match":s.match,"event":e,"hp":s.characters.map(func(c):return c.hp),"hand_counts":s.characters.map(func(c):return c.hand_count),"badges":s.badges})
			if e.stage=="impact":
				var travel:String="%d/%d/travel"%[s.match,e.id]
				if not seen.has(travel) or Time.get_ticks_msec()-int(seen[travel])<Styles.duration(e.merged({"stage":"travel"},true))-120:fail("animation flight shortened");return
			if e.kind=="strike":
				for target in e.targets:
					if s.characters[target.id].hp!=(target.before if e.stage=="travel" else target.after):fail("damage outside impact boundary");return
			if e.has("reward_source"):
				reward_stages+=1
				var actor:int=e.action.actor
				var expected:int=0 if e.stage=="travel" else 2 if e.style=="bounty" else 1
				var actual:int=s.characters[actor].hand_count if e.style=="bounty" else s.badges[actor/3]
				if actual!=expected:fail("reward visible before arrival or incorrect count");return
	if s.phase=="review" and not reviewed.has(s.match):
		reviewed[s.match]=true
		if reviewed.size()==KEYS.size():
			completed=true
			if reward_stages!=4:fail("missing reward stages");return
			var file:=FileAccess.open("res://test-results/network-v0174-"+role+".json",FileAccess.WRITE);file.store_string(JSON.stringify(trace));file.close()
			print("NETWORK_V0174_RESULT role=%s styles=4 stages=%d reward_stages=4 arrival_timing=true"%[role,trace.size()]);_finish.call_deferred()
		elif role=="host":_next.call_deferred(int(s.match)-17400+1)
func _setup(index:int)->void:
	var key:String=KEYS[index]
	var g=H.fixture(8);g.match_id=17400+index;g.presentation_enabled=true
	var actor:int=5 if key=="glory" else 0
	var victim:int=1 if actor==5 else 4
	H.give(g,actor,key)
	if key=="godslayer":H.give(g,victim,"heal")
	if key in ["bounty","glory"]:g.characters[victim].hp=1
	if key=="area_strike":
		var card:int=H.give_death(g,3,"blessing");g._activate({"actor":3,"card":card},4)
	session.game=g;session._broadcast()
func _next(index:int)->void:await create_timer(.18).timeout;_setup(index)
func _finish()->void:await create_timer(.7).timeout;quit(0)
func _process(_delta:float)->bool:
	if started>0 and Time.get_ticks_msec()-started>40000:fail("network timeout")
	if completed or session==null or session.state.is_empty():return false
	var s:Dictionary=session.state
	var key:String="%d/%d"%[s.match,s.revision]
	if s.match<17400 or last_request==key:return false
	last_request=key
	if s.phase=="planning" and not s.ready[session.team] and not planned.has(s.match):
		planned[s.match]=true
		var plan:=[0,0,0]
		for slot in range(3):
			var hand:Array=s.characters[session.team*3+slot].hand
			if not hand.is_empty():plan[slot]=hand[0]
		session.act("plan",plan)
	elif s.phase=="targeting" and s.input.team==session.team:session.act("target",[1 if s.match==17403 else 4])
	return false
