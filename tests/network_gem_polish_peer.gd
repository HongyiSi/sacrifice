extends SceneTree
const Cases=preload("res://tests/gem_polish_scenarios.gd")
const KEYS=["ruby","amber","sapphire","emerald","amethyst","topaz"]
const BASE=934000
var main
var role="host"
var prepared=false
var done=false
var started=0
var results=[]
var errors=[]
var seen={}
var observed={}
var privacy=true
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	run.call_deferred()
func run():
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await process_frame
	main.music.level=0.;main.music.player.stop();main.attack_audio.level=0.
	main.session.changed.connect(changed);main.session.problem.connect(func(message):errors.append(message))
	started=Time.get_ticks_msec()
	if role=="host":main.session.host_room("宝石测试房主",25234)
	else:main.session.join_room("宝石测试访客","127.0.0.1",25234)
func setup(index):
	var key=KEYS[index%6];var actor=1 if index<6 else 4
	var g=Cases.setup(key,actor,BASE+index)
	if key in ["ruby","sapphire","amethyst"]:g.jobs=[{"op":"planning"}]
	main.session.game=g;main.session._broadcast()
func changed():
	var view=main.session.state
	if view.is_empty() or done:return
	if role=="host" and not prepared:prepared=true;setup.call_deferred(0);return
	if view.match<BASE:return
	for c in view.characters:
		if c.team!=main.session.team:privacy=privacy and c.hand.is_empty()
	var gem=view.animation.get("gem_overlay",view.animation)
	if gem.get("kind","")=="gem_trigger" and gem.action.actor/3!=main.session.team:
		privacy=privacy and not gem.has("gem_card") and not gem.has("owner_slot")
	if not view.animation.is_empty() or view.phase not in ["planning","review","ended"] or seen.has(view.match):return
	seen[view.match]=true
	var index=view.match-BASE;var key=KEYS[index%6];var actor=1 if index<6 else 4
	var flags=observed.get(view.match,{})
	var expected_hp={"ruby":5,"amber":6,"sapphire":8,"emerald":3,"amethyst":1,"topaz":3}[key]
	var ok=view.characters[actor].hp==expected_hp and flags.get("chest",false) and flags.get("effect",false)
	if key in ["sapphire","emerald"]:ok=ok and flags.get("overlap",false)
	results.append({"key":key,"actor":actor,"ok":ok,"flags":flags,"hp":view.characters[actor].hp,"hands":view.characters.map(func(c):return c.hand_count),"badges":view.badges})
	print("GEM_NETWORK_CASE ",role," ",index," ",ok)
	if index==11:done=true;finish.call_deferred()
	elif role=="host":next.call_deferred(index+1)
func next(index):
	await create_timer(.25).timeout;setup(index)
func find(node,key,value):
	if node.get_meta(key,-999)==value:return node
	for child in node.get_children():
		var result=find(child,key,value)
		if result!=null:return result
	return null
func _process(_delta):
	if started and Time.get_ticks_msec()-started>180000:push_error("GEM_NETWORK_TIMEOUT");quit(2)
	if main==null or done or main.session.state.is_empty():return false
	var view=main.session.state
	if view.match<BASE or view.animation.is_empty():return false
	var fx=find(main,"gem_animation",view.animation.id)
	if fx!=null and is_instance_valid(fx.visual):
		if not observed.has(view.match):observed[view.match]={}
		var flags=observed[view.match];var age=fx.visual.age
		if age>1.0 and age<1.3:flags.chest=fx.visual.port.distance_to(fx.visual.chest)<2
		if age>1.6:flags.effect=true
		if view.animation.has("gem_overlay") and age<2.05:
			flags.overlap=find(main,"draw_animation",view.animation.id)!=null and fx.visual.facet.visible
	return false
func finish():
	await create_timer(.3).timeout
	var ok=results.size()==12 and results.all(func(r):return r.ok) and privacy and errors.is_empty()
	var f=FileAccess.open("res://test-results/network-gem-polish-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok":ok,"cases":results,"privacy":privacy,"errors":errors},"\t"));f.close()
	print("GEM_NETWORK_RESULT ",role," cases=",results.size()," ok=",ok)
	if role=="host":await create_timer(1.0).timeout
	main.session.leave();main.queue_free();await process_frame;quit(0 if ok else 1)
