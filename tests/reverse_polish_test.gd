extends SceneTree
const H=preload("res://tests/helpers.gd")
const Scenarios=preload("res://tests/art_scenarios.gd")
const Timing=preload("res://scripts/reverse_timing.gd")
const Audio=preload("res://scripts/attack_audio.gd")
var checks=0
var failures=0
var snapshots={}
var main
var sound
var heard=[]
var capture=false

func check(ok,label):
	checks+=1
	if not ok:failures+=1;push_error("REVERSE_FAIL "+label)
func _initialize():
	capture="--capture" in OS.get_cmdline_user_args()
	run.call_deferred()
func walk(node):
	var all=[node]
	for child in node.get_children():all.append_array(walk(child))
	return all
func drain(g,context,expect_reverse=true):
	var restores=0;var stages=0;var later_effects=0
	for i in range(220):
		var e=g.animation
		if not e.is_empty():
			var a=g.snapshot(0);var b=g.snapshot(1)
			check(a.reverse_cloth_active==b.reverse_cloth_active,"public cloth state agrees")
			check(sound.cues_for(a)==sound.cues_for(b),"both viewers receive identical audio cues")
			if Timing.is_reverse(e):
				stages+=1;snapshots[e.stage]=[a,b]
				check(e.travel_ms==2700 and e.impact_ms==3700,"approved complete reverse timing")
				var cues=sound.cues_for(a)
				check(cues.size()==1,"one sound at this reverse stage")
				if e.stage=="travel":
					check(not a.reverse_cloth_active,"no dye before sphere turns")
					check(is_equal_approx(cues[0].delay,1.5),"metal follows rotation start")
				else:
					check(a.reverse_cloth_active,"purple retained after effect applies")
					check(cues[0].delay==0,"magic starts on dye boundary")
			elif e.kind=="reverse_restore":
				restores+=1;snapshots.restore=[a,b]
				check(g.phase=="animating" and g.animation_resume_phase in ["review","ended"],"restore runs after all normal and death effects")
				check(e.action.is_empty() and e.targets.is_empty(),"restore has no hidden card or pawn data")
				check(H.Rules.StrikeStyles.duration(e)==3000,"full three-second restore")
				check(g.reverse_cloth_active,"purple remains until restore finishes")
				check(sound.cues_for(a).size()==1,"one restore sound")
			elif stages>0 and e.kind=="card_effect":
				later_effects+=1;snapshots.later=[a,b]
				check(a.reverse_cloth_active,"purple persists through later effects")
			g.advance_animation()
		elif g.phase in ["review","ended","planning"]:break
		else:
			var error=Scenarios.step(g,context);check(error.is_empty() or error=="done","normal rule progression "+error)
	check(g.phase in ["review","ended","planning"],"fixture terminates")
	check(restores==(1 if expect_reverse else 0),"exactly one restore per reversed round")
	check(not g.reverse_cloth_active,"cloth state cleared after ending")
	return {"stages":stages,"later_effects":later_effects}

func show(view,team,age=0.0):
	main.session.team=team;main.session.state=view.duplicate(true);main.session.state.names=["实装验证","对手"]
	main.session.changed.emit()
	for i in range(4):await process_frame
	for node in walk(main):
		if node.has_meta("cinema_effect"):
			node.set_process(false);node.clock_started=-1;node.present(age)
		if node.has_meta("phase_banner") or node.has_meta("center_phase_title"):
			node.set_process(false);node.started=Time.get_ticks_msec()-5000;node._process(0)
	main.reverse_tablecloth.set_process(false);main.reverse_tablecloth.clock_started=-1;main.reverse_tablecloth.present(age)
	if capture:await RenderingServer.frame_post_draw

func screenshot(name):
	if capture:root.get_texture().get_image().save_png("res://test-results/reverse-"+name+".png")

func run():
	sound=Audio.new();root.add_child(sound);sound.level=0;sound.set_process(false)
	var pair=Scenarios.setup("reverse",991099)
	var result=drain(pair[0],pair[1])
	check(result.stages==2 and result.later_effects>0,"real reverse plus later action and restoration exercised")
	check(pair[0].phase=="review","review follows complete restoration")
	var saved_snapshots=snapshots.duplicate(true)
	var deaths=H.fixture(8);deaths.match_id=991101;deaths.presentation_enabled=true
	H.give_death(deaths,3,"last_dance");deaths.characters[3].hp=0;deaths.characters[3].death_round=deaths.round_number
	H.begin(deaths,{0:H.give(deaths,0,"reverse")},false)
	var death_result=drain(deaths,{"key":"reverse","target_index":0,"targets":[],"follow":false})
	check(deaths.death_queue.any(func(a):return deaths.death_catalog[a.card].key=="last_dance" and a.status=="done"),"deathrattle completes before restore")
	snapshots=saved_snapshots
	var plain=Scenarios.setup("strike",991100);drain(plain[0],plain[1],false)
	# A copied second reversal changes priority normally, without undyeing cloth.
	var duplicate=snapshots.travel[0].duplicate(true);duplicate.animation.cloth_was_active=true;duplicate.reverse_cloth_active=true
	var repeated=duplicate.duplicate(true);repeated.animation.stage="impact"
	check(sound.cues_for(repeated).is_empty(),"already purple does not replay dye audio")
	# Rules-only simulation remains instant and preserves ordering.
	var raw=H.fixture();raw.phase="resolution"
	var action={"id":99,"actor":0,"card":H.give(raw,0,"reverse"),"main":10,"status":"active"}
	raw._run_job({"op":"reverse","a":action})
	check(raw.reverse_cloth_active and raw.reverse_after==[10],"reverse still schedules priority after current group")
	raw._run_job({"op":"reverse","a":action})
	check(raw.reverse_cloth_active and raw.reverse_after.size()==2,"repeated spell retains purple")
	raw._finish_deaths()
	check(raw.phase=="review" and raw.animation.is_empty() and not raw.reverse_cloth_active,"disabled presentation adds no waiting")
	# Winning while purple queues the same restore only once.
	var win=H.fixture();win.presentation_enabled=true;win.reverse_cloth_active=true
	win._end(0,"徽章");win._queue_reverse_restore();win._pump()
	check(win.animation.get("kind","")=="reverse_restore","winning round also restores")
	win.advance_animation()
	check(win.phase=="ended" and not win.reverse_cloth_active and win.visual_queue.is_empty(),"winner and cleared cloth after restore")
	# A canceled reversal never latches or restores the cloth.
	var blocked=H.fixture();blocked.presentation_enabled=true
	var canceled=action.duplicate(true);canceled.status="blocked"
	check(not blocked._present_job({"op":"reverse","a":canceled}),"canceled effect has no presentation")
	check(not blocked.reverse_cloth_active,"canceled effect never dyes")
	var twins=[]
	for animated in [false,true]:
		var twin=H.fixture(8);twin.presentation_enabled=animated
		H.begin(twin,{0:H.give(twin,0,"reverse"),1:H.give(twin,1,"badge"),3:H.give(twin,3,"strike")},false)
		var context={"key":"reverse","target_index":0,"targets":[],"follow":false}
		for i in range(120):
			if twin.phase in ["review","ended"] and twin.animation.is_empty():break
			Scenarios.step(twin,context)
		twins.append(twin)
	for field in ["characters","deck","discard","badges","queue","death_queue","phase","winner","reversed_order","reverse_after","log_lines"]:
		check(twins[0].get(field)==twins[1].get(field),"approved presentation keeps exact rule result: "+field)
	# Actual audio playback scheduling: refreshes don't duplicate, late entry seeks.
	sound.cue_played.connect(func(file,offset):heard.append({"file":file,"offset":offset}))
	var view=snapshots.travel[0]
	sound.sync_view(view,Time.get_ticks_msec()-1600);var first=heard.size()
	check(first==1 and heard[0].offset>=.09,"late travel seeks matching sound position")
	sound.sync_view(view,Time.get_ticks_msec());sound._process(0)
	check(heard.size()==first,"same snapshot doesn't replay")
	sound.sync_view(snapshots.impact[0],Time.get_ticks_msec()-450)
	check(heard.size()==first+1 and heard[-1].offset>=.44,"dye seeks without restarting on delayed state")
	sound.sync_view(snapshots.restore[0],Time.get_ticks_msec())
	check(heard[-1].file.ends_with("restoration.ogg"),"restore uses approved warm cue")
	sound.sync_view({},0);check(sound.pending.is_empty() and sound.voices.all(func(v):return not v.playing),"leaving clears sound")
	# Burst network snapshots must retain all three seconds before review.
	var client=preload("res://scripts/session.gd").new();root.add_child(client);client.set_process(false)
	var restore_view=snapshots.restore[1].duplicate(true);restore_view.names=["一","二"]
	client._receive_view(restore_view)
	var review=pair[0].snapshot(1);review.names=["一","二"]
	client._receive_view(review)
	check(client.state.animation.get("kind","")=="reverse_restore" and client.received_views.size()==1,"network burst cannot skip restore")
	client.received_animation_started=Time.get_ticks_msec()-3001;client._drain_received_views()
	check(client.state.phase=="review" and client.state.animation.is_empty(),"network review releases after restore duration")
	client.queue_free()

	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"));root.add_child(main)
	await create_timer(.2).timeout
	main.session.set_process(false);main.attack_audio.level=0;main.attack_audio.set_process(false);main.music.player.stop();main.music.level=0
	DirAccess.make_dir_recursive_absolute("res://test-results")
	for team in [0,1]:
		await show(snapshots.travel[team],team,1.45)
		check(is_zero_approx(main.reverse_tablecloth.progress),"yellow before rotation, viewer "+str(team));screenshot("gold-top-"+str(team))
		await show(snapshots.travel[team],team,2.5);screenshot("purple-top-"+str(team))
		await show(snapshots.impact[team],team,1.45)
		check(is_equal_approx(main.reverse_tablecloth.progress,.5),"dye halfway matches both viewers")
		check(main.reverse_tablecloth.particles.active,"particles run on the moving boundary");screenshot("dye-"+str(team))
		var clock=main.effect_started;main._render()
		check(clock==main.effect_started,"rebuild preserves effect clock")
		await show(snapshots.later[team],team,.3)
		check(main.reverse_tablecloth.progress==1 and not main.reverse_tablecloth.particles.active,"stable purple without replay")
		screenshot("held-"+str(team))
		await show(snapshots.restore[team],team,1.5)
		check(is_equal_approx(main.reverse_tablecloth.progress,.5),"restoration halfway");screenshot("restore-"+str(team))
		main.reverse_tablecloth.present(3)
		check(main.reverse_tablecloth.progress==1,"restoration completes before next round")
	await show(duplicate,0,0)
	check(main.reverse_tablecloth.progress==1,"duplicate rotation keeps purple from first frame")
	var late=snapshots.later[0].duplicate(true);late.match+=100
	await show(late,0)
	check(main.reverse_tablecloth.progress==1,"join mid-round restores public purple state without animation")
	main.size=Vector2(1024,768);main._render()
	check(main.reverse_tablecloth.scale==Vector2(1024,768)/Vector2(1440,960),"cloth matches actual table at alternate size")
	main.session.state={};main._render()
	check(not main.reverse_tablecloth.visible and main.reverse_tablecloth.progress==0,"lobby clears tint and particles")
	print("REVERSE_POLISH_TEST checks=",checks," failures=",failures)
	main.queue_free();sound.queue_free();await process_frame;quit(0 if failures==0 else 1)
