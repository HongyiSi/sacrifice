extends SceneTree
const H = preload("res://tests/helpers.gd")
var main
var checks := 0
var failures := 0
var serial := 171000
var played: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("V01710_SUPPORT_FAIL "+label)

func _initialize() -> void: _run.call_deferred()
func frames() -> void:
	for i in range(3): await process_frame

func show_game(g, viewer: int = 0) -> void:
	main.session.team = viewer
	main.session.state = g.snapshot(viewer)
	main.session.state.names = ["本地音效测试","对手"]
	main.session.changed.emit()
	await frames()

func fixture(hp: int = 4):
	var g = H.fixture(hp)
	serial += 1; g.match_id = serial
	g.presentation_enabled = true; g.resolution_presentation_enabled = true
	return g

func activate(g, target: int) -> void:
	var id: int = H.give_death(g,2,"blessing")
	g._activate({"actor":2,"card":id},target)

func step(g, cancel: bool = true) -> void:
	if not g.animation.is_empty(): g.advance_animation(); return
	if g.phase == "targeting":
		var key: String = g._info(g.input_action).key
		var target := 1 if key == "heal_other" else 0
		check(g.target(g.request.team,target).is_empty(),"target accepted: "+key)
	elif g.phase == "reacting": check(g.defend(g.request.team,cancel).is_empty(),"defense response accepted")
	elif g.phase == "responding": g.respond(g.request.team,g.request.options[0])
	elif g.phase == "selecting": g.pick(g.request.team,g.request.options.slice(0,g.request.count))
	else: check(false,"unexpected phase "+g.phase)

func reach(g, kind: String, stage: String) -> bool:
	for i in range(80):
		if g.animation.get("kind","") == kind and g.animation.get("stage","") == stage: return true
		if g.phase in ["review","ended"]: break
		step(g)
	check(false,"reach "+kind+"/"+stage)
	return false

func _run() -> void:
	root.size = Vector2i(1440,960)
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(.3).timeout
	var sound = main.attack_audio
	sound.settings_path = "res://test-results/v01710-sound.cfg"
	main.music.settings_path = "res://test-results/v01710-music.cfg"
	sound.set_level(1); main.music.set_level(.3)
	sound.cue_played.connect(func(file,offset): played.append({"file":file,"offset":offset}))
	check(["defense","heal","team_heal","heal_other"].all(func(key): return sound.support_bank.cards.has(key)),"four approved support cards registered")
	var files: Array = [sound.support_bank.defense_block]
	for c in sound.support_bank.cards.values():
		for slot in ["rise","travel","impact"]:
			if str(c.get(slot,"")).is_empty(): continue
			if not files.has(c[slot]): files.append(c[slot])
	for file in files:
		var stream = load(file)
		check(stream != null and stream.get_length() > 0 and (stream.loop_mode==AudioStreamWAV.LOOP_DISABLED if stream is AudioStreamWAV else not stream.loop),"audio imported without looping: "+file)
	for key in ["heal","team_heal","heal_other","defense"]:
		var g = fixture()
		var choices := {0:H.give(g,0,key)}
		if key == "defense": choices[3] = H.give(g,3,"strike")
		H.begin(g,choices,false)
		var saw_travel := false
		var saw_apply := false
		var saw_block := false
		for i in range(80):
			await show_game(g)
			var cues: Array = sound.cues_for(g.snapshot(0))
			check(cues == sound.cues_for(g.snapshot(1)),"both public views use same cues: "+key)
			var e: Dictionary = g.animation
			if e.get("kind","") in ["heal","shield"] and e.get("style","") == key:
				if e.stage == "travel":
					saw_travel = true
					check(cues.size() == 1 and cues[0].file == sound.support_bank.cards[key].travel,"flight has no recovery arrival: "+key)
					check(g.characters[0].hp == 4 and g.characters[1].hp == 4,"HP waits for arrival: "+key)
				else:
					saw_apply = true
					check(cues.size() == 1 and cues[0].file == sound.support_bank.cards[key].impact,"one application sound: "+key)
					check(sound.voices.any(func(p): return p.playing and p.stream.resource_path == cues[0].file),"real player starts application audio: "+key)
					if key == "heal": check(g.characters[0].hp == 6,"self heal recovers two")
					if key == "heal_other": check(g.characters[1].hp == 7 and g.characters[0].hp == 4,"other heal recovers three")
					if key == "team_heal": check(g.characters.slice(0,3).all(func(c): return c.hp == 5),"team heal simultaneous recovery")
					if key == "defense": check(g.characters[0].shield == 1,"shield applied")
					var n := played.size()
					main._schedule_render(); await frames()
					main._schedule_render(); await frames()
					check(played.size() == n,"redraw does not replay: "+key)
			if e.get("kind","") == "shield_block" and e.get("stage","") == "impact":
				saw_block = true
				check(e.get("guard_style","") == "defense","actual consumed defense tagged")
				check(cues.filter(func(c): return c.file == sound.support_bank.defense_block).size() == 1,"one shield contact")
				check(g.characters[0].hp == 4 and g.characters[0].shield == 0,"block consumes shield without damage")
			if g.phase in ["review","ended"]: break
			step(g)
		check(saw_travel and saw_apply,"support reaches both stages: "+key)
		if key == "defense": check(saw_block,"defense demo includes real block")
	# Full health and Blessing do not announce a successful recovery.
	for key in ["heal","team_heal","heal_other"]:
		var full = fixture(8); H.begin(full,{0:H.give(full,0,key)},false)
		if reach(full,"heal","impact"): check(sound.cues_for(full.snapshot(0)).is_empty(),"full health has no recovery sound: "+key)
		var blocked = fixture()
		if key == "team_heal": blocked.characters[1].hp = 8; blocked.characters[2].hp = 0
		activate(blocked,1 if key == "heal_other" else 0)
		H.begin(blocked,{0:H.give(blocked,0,key)},false)
		if reach(blocked,"heal","impact"): check(sound.cues_for(blocked.snapshot(0)).is_empty(),"blocked recovery has no success sound: "+key)
	var partial = fixture(); partial.characters[2].hp = 0; activate(partial,0)
	H.begin(partial,{0:H.give(partial,0,"team_heal")},false)
	if reach(partial,"heal","impact"):
		check(sound.cues_for(partial.snapshot(0)).size() == 1,"partial team recovery plays one E")
		check(partial.characters[0].hp == 4 and partial.characters[1].hp == 5 and partial.characters[2].hp == 0,"only eligible ally recovers")
	# Skip and cancellation must not play a healing arrival.
	for key in ["heal_other","defense"]:
		var skipped = fixture(); H.begin(skipped,{0:H.give(skipped,0,key)},false)
		while not skipped.animation.is_empty(): skipped.advance_animation()
		check(skipped.skip_effect(0).is_empty(),"skip support target: "+key)
		check(sound.cues_for(skipped.snapshot(0)).is_empty(),"skip has no effect sounds: "+key)
	var canceled = fixture(); H.give(canceled,3,"magic_amulet"); H.begin(canceled,{0:H.give(canceled,0,"heal_other")},false)
	var healing_cue := false
	for i in range(70):
		if canceled.phase == "targeting": canceled.target(canceled.request.team,3)
		elif canceled.phase in ["review","ended"]: break
		else: step(canceled)
		for cue in sound.cues_for(canceled.snapshot(0)):
			if cue.file.contains("heal_flight") or cue.file.contains("heal_E_arrival"): healing_cue = true
	check(not healing_cue and canceled.characters[3].hp == 4,"amulet-cancelled healing stays silent")
	# Blessing and a declined shield response are not Defense block events.
	var blessed = fixture(); activate(blessed,0); H.begin(blessed,{3:H.give(blessed,3,"strike")},false)
	if reach(blessed,"shield_block","impact"):
		check(not sound.cues_for(blessed.snapshot(0)).any(func(c): return c.file == sound.support_bank.defense_block),"blessing does not borrow defense sound")
	var declined = fixture(); declined.characters[0].shield = 1
	H.begin(declined,{3:H.give(declined,3,"strike")},false)
	var saw_declined_hit := false
	for i in range(60):
		check(not sound.cues_for(declined.snapshot(0)).any(func(c): return c.file == sound.support_bank.defense_block),"declined defense stays silent")
		if declined.animation.get("kind","") == "strike" and declined.animation.get("stage","") == "impact":
			saw_declined_hit = true
			check(declined.characters[0].hp == 3 and declined.characters[0].shield == 1,"decline keeps shield and allows attack")
		if declined.phase in ["review","ended"]: break
		step(declined,false)
	check(saw_declined_hit,"declined shield reaches actual hit before end-of-round expiry")
	# Recovery tail survives next state, dialogs and independent music controls.
	var tail_game = fixture(); H.begin(tail_game,{0:H.give(tail_game,0,"heal")},false)
	if reach(tail_game,"heal","impact"):
		await show_game(tail_game,1)
		var voices: Array = sound.voices.filter(func(p): return p.playing and p.stream.resource_path.contains("heal_E_arrival"))
		check(voices.size() == 1,"opponent view plays E once")
		if not voices.is_empty():
			var voice = voices[0]
			check(voice.stream.get_length() > 1.7,"complete E tail retained")
			main.music_dialog.popup_centered(Vector2i(720,440)); await create_timer(.2).timeout
			check(voice.playing and main.music.player.playing,"popup does not stop music or E")
			if "--shots" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-results/v01710-sound-settings.png")
			sound.set_level(0); check(voice.playing and voice.volume_db <= -79 and main.music.level > 0,"SFX mute leaves music alone")
			sound.set_level(.4); main.music_dialog.hide()
			tail_game.advance_animation(); await show_game(tail_game,1)
			check(voice.playing,"recovery tail survives following state")
			main.session.leave(); await frames()
			check(sound.pending.is_empty() and sound.voices.all(func(p): return not p.playing),"leave cleans sound state")
	print("V01710_SUPPORT_RESULT checks=%d failures=%d" % [checks,failures])
	main.queue_free(); await frames(); quit(0 if failures == 0 else 1)
