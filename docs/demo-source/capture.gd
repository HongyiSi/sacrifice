extends SceneTree
## Scripted inputs, production rules and renderer; no altered card effects.
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/reveal_scenarios.gd")
const Card=preload("res://scripts/card_widget.gd")
const Reveal=preload("res://scripts/card_reveal.gd")
const Flight=preload("res://scripts/planning_flight.gd")
const Cinema=preload("res://scripts/cinema/cinema.gd")
const FPS=30
var main
var folder=ProjectSettings.globalize_path("res://test-results/portfolio-frames")
var frame_no=0
var chapter="planning"
var timeline=[]
var motion_evidence=[]
var preview=false
var audio_only=false
var audio_cues=[]
var audio_matches=[]
var serial=81000

func _initialize():
	preview="--preview" in OS.get_cmdline_user_args()
	audio_only="--audio-only" in OS.get_cmdline_user_args()
	assert(not (preview and audio_only),"audio-only requires the complete frame timeline")
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
	if audio_matches.is_empty() or audio_matches[-1].match!=g.match_id:
		audio_matches.append({"match":g.match_id,"first":first})
	var animated=[]
	for n in nodes(main):
		var props=n.get_property_list().map(func(p):return p.name)
		if "elapsed" in props and n.has_method("_process"):
			animated.append(n)
	var count=maxi(1,roundi(seconds*FPS))
	# Export the production sound schedule on the same sampled frame clock.
	# Recording wall-clock playback would drift while JPEGs are being written.
	var cues:Array=main.attack_audio.cues_for(g.snapshot(0))
	if label=="stage-card":main.attack_audio._movement_cue(cues,"play",Flight.DURATION_MS/1000.0)
	for cue in cues:
		var offset=float(cue.get("delay",0.0))
		if offset>seconds+.001:continue
		var entry=cue.duplicate(true)
		entry.merge({"frame":first+offset/seconds*count,"stage_first":first,"stage_last":first+count-1,
			"chapter":chapter,"label":label,"kind":g.animation.get("kind",""),
			"style":g.animation.get("style",""),"match":g.match_id})
		audio_cues.append(entry)
	var samples=[0.0,0.25,0.5,0.7,0.88,0.98] if preview else range(count).map(func(i):return float(i)/count)
	if audio_only:frame_no+=count
	for fraction in ([] if audio_only else samples):
		var t=float(fraction)*seconds
		# Move the real card before sampling effects that use its emblem as
		# their origin. Only card_start/travel raises it; subsequent stages
		# retain the settled location instead of restarting the lift.
		for n in nodes(main):
			if n is Reveal:n.set_progress(t/Reveal.DURATION)
			if n is Flight:n.present(n.started+int(t*1000))
			if n is Card and n.resolution_started>=0:
				var age=t if n.returning or (g.animation.get("kind","")=="card_start" and g.animation.get("stage","")=="travel") else t+1.0
				n.resolution_started=Time.get_ticks_msec()-int(age*1000);n._process(0)
			if n.get_script()==preload("res://scripts/phase_announcement.gd"):
				n.started=Time.get_ticks_msec()-int(t*1000);n._process(0)
		for n in animated:
			if not is_instance_valid(n):continue
			# Cinema derives its pose from wall-clock time in _process. Calling it
			# with clock_started=-1 skipped the entire flight in the old capture.
			# Drive its production presentation method with the sampled stage age.
			if n is Cinema:
				n.present(t)
				assert(absf(n.t-t)<.0001 and absf(n.u-clampf(t/n.duration,0,1))<.0001)
				if n.kind=="strike" and n.stage=="travel" and n.handler.has_method("path"):
					var p:Vector2=n.handler.path(n.handler.progress(0),n.targets[0],0)
					motion_evidence.append({"frame":frame_no,"style":n.key,"t":t,"u":n.u,"position":[p.x,p.y]})
			else:
				n.elapsed=t
				if "clock_started" in n:n.clock_started=Time.get_ticks_msec()-roundi(t*1000)
				n._process(0)
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
			var chosen=target if g.request.get("team",0)==0 else 0
			if g.phase=="targeting" and g.request.options.has(chosen):error=g.target(g.request.team,chosen)
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
	assert(g.characters[0].hp==5 and g.characters[3].hp==6,"opposing attacks must hit the other team")
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
	file.store_string(JSON.stringify({"fps":FPS,"frames":frame_no,"preview":preview,"audio_only":audio_only,"segments":timeline,"audio_cues":audio_cues,"audio_matches":audio_matches,"motion_evidence":motion_evidence,"assertions":["audio cues follow production sampled stages" if audio_only else "production cinema stage ages match sampled frames","lethal attack grants enemy fourth badge","alternate target preserves enemy at two badges"]},"  "));file.close()
	print("PORTFOLIO_CAPTURE_OK frames=",frame_no)
	main.queue_free();await process_frame;quit()
