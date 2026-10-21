extends SceneTree
## Scripted inputs, production rules and renderer; no altered card effects.
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/reveal_scenarios.gd")
const Card=preload("res://scripts/card_widget.gd")
const Reveal=preload("res://scripts/card_reveal.gd")
const Flight=preload("res://scripts/planning_flight.gd")
const FPS=30
var main
var folder=ProjectSettings.globalize_path("res://test-results/portfolio-frames")
var frame_no=0
var chapter="planning"
var timeline=[]
var preview=false
var serial=81000

func _initialize():
	preview="--preview" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):folder=arg.trim_prefix("--output=")
	if preview:folder+="-preview"
	DirAccess.make_dir_recursive_absolute(folder)
	run.call_deferred()

func nodes(n:Node)->Array:
	var result:Array=[n]
	for c in n.get_children():result.append_array(nodes(c))
	return result

func meta(key:String,value):
	for n in nodes(main):
		if n.has_meta(key) and n.get_meta(key)==value:return n
	return null

func show(g):
	main.session.game=g;main.session.team=0;main.session.state=g.snapshot(0)
	main.session.state.names=["我方","对方"]
	main.session.changed.emit()
	for _i in range(3):await process_frame
	for n in nodes(main):n.set_process(false)

func clip(g,seconds:float,label:String,refresh=true):
	if refresh:await show(g)
	var first=frame_no
	var animated=[]
	for n in nodes(main):
		var props=n.get_property_list().map(func(p):return p.name)
		if "elapsed" in props and n.has_method("_process"):
			if "clock_started" in props:n.clock_started=-1
			animated.append(n)
	var count=maxi(1,roundi(seconds*FPS))
	var samples=[0.0,0.5,0.98] if preview else range(count).map(func(i):return float(i)/count)
	for fraction in samples:
		var t=float(fraction)*seconds
		for n in animated:
			if is_instance_valid(n):n.elapsed=t;n._process(0)
		for n in nodes(main):
			if n is Reveal:n.set_progress(t/Reveal.DURATION)
			if n is Flight:n.present(n.started+int(t*1000))
			if n is Card and n.resolution_started>=0:
				n.resolution_started=Time.get_ticks_msec()-int(t*1000);n._process(0)
			if n.get_script()==preload("res://scripts/phase_announcement.gd"):
				n.started=Time.get_ticks_msec()-int(t*1000);n._process(0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(folder+"/frame-%05d.jpg"%frame_no,.94)
		frame_no+=1
	timeline.append({"chapter":chapter,"label":label,"first":first,"last":frame_no-1,"seconds":seconds,"phase":g.phase,"event":g.animation.get("kind",""),"hp":g.characters.map(func(c):return c.hp),"badges":g.badges.duplicate()})
	print("CAPTURE ",chapter," ",label," ",frame_no)

func play_out(g,target:int=3):
	for _i in range(120):
		if not g.animation.is_empty():
			await clip(g,H.Rules.StrikeStyles.duration(g.animation)/1000.0,g.animation.kind+"/"+g.animation.stage)
			g.advance_animation()
		elif g.phase in ["planning","review","ended"]:return
		else:
			await clip(g,0.7,"decision")
			var error=""
			if g.phase=="targeting" and g.request.options.has(target):error=g.target(g.request.team,target)
			else:error=S.step(g)
			if not error.is_empty():push_error(error);quit(2);return
	push_error("capture did not reach a stable state");quit(2)

func fixture():
	var g=H.fixture(7);serial+=1;g.match_id=serial
	for actor in range(6):
		for key in ["strike","defense","heal","magic_strike"]:
			var found=false
			for id in g.deck:
				if g.catalog[id].key==key:found=true;break
			if found:H.give(g,actor,key)
	var deaths=["heart","divinity","blessing","sacrifice_badges","life_steal","last_dance"]
	for actor in range(6):H.give_death(g,actor,deaths[actor])
	g.presentation_enabled=true;g.resolution_presentation_enabled=true;g.stage_presentation_enabled=true
	return g

func threat():
	var g=fixture();g.characters[3].hp=1;g.badges[1]=2
	g.death_revealed.append(106)
	return g

func run():
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	main.get_node("Session").ai_checkpoint.enabled=false
	root.add_child(main);await create_timer(.4).timeout
	main.session.set_process(false);main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume()
	var g=fixture()
	await clip(g,3.5,"board")
	var strike=g.characters[0].hand.filter(func(id):return g.catalog[id].key=="strike")[0]
	meta("card_id",strike).pressed.emit();await process_frame;await process_frame
	for n in nodes(main):n.set_process(false)
	await clip(g,1.4,"stage-card",false)
	await clip(g,1.8,"planned")
	chapter="priority"
	H.begin(g,{0:strike,3:g.characters[3].hand.filter(func(id):return g.catalog[id].key=="magic_strike")[0]},false)
	await play_out(g,3)
	await clip(g,2.0,"round-result")
	chapter="death-risk"
	g=threat();await clip(g,5.0,"two-badges-and-living-ally")
	strike=g.characters[0].hand.filter(func(id):return g.catalog[id].key=="strike")[0]
	H.begin(g,{0:strike},false);await play_out(g,3)
	assert(g.phase=="ended" and g.winner==1 and g.badges[1]==4,"death threat must be real")
	await clip(g,3.0,"kill-loses")
	chapter="alternative"
	g=threat();await clip(g,2.5,"same-starting-position")
	strike=g.characters[0].hand.filter(func(id):return g.catalog[id].key=="strike")[0]
	H.begin(g,{0:strike},false);await play_out(g,4)
	assert(g.phase=="review" and g.badges[1]==2 and g.characters[3].hp==1,"alternative must keep the threat alive")
	await clip(g,3.0,"avoid-trigger")
	var file=FileAccess.open(folder+"/timeline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":FPS,"frames":frame_no,"preview":preview,"segments":timeline,"assertions":["lethal attack grants enemy fourth badge","alternate target preserves enemy at two badges"]},"  "));file.close()
	print("PORTFOLIO_CAPTURE_OK frames=",frame_no)
	main.queue_free();await process_frame;quit()
