extends SceneTree
const H = preload("res://tests/helpers.gd")
var main
var checks := 0
var failures := 0
var serial := 17900
var played: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V0179_AUDIO_FAIL "+label)

func _initialize() -> void: _run.call_deferred()
func frames() -> void:
	for i in range(3): await process_frame

func show_game(g, viewer: int = 0) -> void:
	main.session.team = viewer
	main.session.state = g.snapshot(viewer)
	main.session.state.names = ["本地音效测试","对手"]
	main.session.changed.emit()
	await frames()

func fixture(key: String, lethal: bool = false):
	var g = H.fixture(8)
	serial += 1; g.match_id = serial
	g.presentation_enabled = true
	g.resolution_presentation_enabled = true
	var choices := {0:H.give(g,0,key)}
	if key == "godslayer": choices[3] = H.give(g,3,"heal")
	if key in ["bounty","glory"] and lethal: g.characters[3].hp = 1
	if key == "judgment" and lethal: g.characters[3].hp = 2
	H.begin(g,choices,false)
	return g

func step(g) -> void:
	if not g.animation.is_empty(): g.advance_animation(); return
	if g.phase == "targeting":
		var target := 3 if g.request.options.has(3) else int(g.request.options[0])
		check(g.target(g.request.team,target).is_empty(),"target accepted")
	elif g.phase == "reacting": g.defend(g.request.team,true)
	elif g.phase == "responding": g.respond(g.request.team,g.request.options[0])
	elif g.phase == "selecting": g.pick(g.request.team,g.request.options.slice(0,g.request.count))
	else: check(false,"unexpected phase "+g.phase)

func _run() -> void:
	root.size = Vector2i(1440,960)
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(.3).timeout
	var sound = main.attack_audio
	sound.settings_path = "res://test-results/v0179-sound.cfg"
	main.music.settings_path = "res://test-results/v0179-music.cfg"
	main.music.set_level(.35)
	sound.set_level(1)
	sound.cue_played.connect(func(path,offset): played.append({"file":path,"offset":offset}))
	check(sound.bank.cards.size() == 13,"all approved attack and damage-skill sounds present")
	for card in sound.bank.cards.values():
		for slot in ["rise","travel","impact","death"]:
			if str(card[slot]).is_empty(): continue
			var stream = load(card[slot])
			check(stream != null and stream.get_length() > 0 and not stream.loop,"sound resource imports and never loops")
	# Real rules snapshots, with both clients' public views selecting the same sounds.
	for key in sound.bank.cards:
		var g = fixture(key,true)
		var hit_seen := false
		for i in range(80):
			await show_game(g)
			var cues: Array = sound.cues_for(g.snapshot(0))
			check(cues == sound.cues_for(g.snapshot(1)),"both players hear same event: "+key)
			if not g.animation.is_empty() and g.animation.kind == "strike" and g.animation.stage == "impact" and g.animation.style == key:
				hit_seen = true
				var expected_hits={"double_strike":2,"triple_strike":3}.get(key,1)
				var expected_file=sound.strike_bank[key].impact if sound.strike_bank.has(key) else sound.bank.cards[key].impact
				check(cues.size()==expected_hits and cues.all(func(c):return c.file==expected_file),"each visible blade chooses its approved contact: "+key)
				# Let legitimately staggered contacts finish before checking redraw.
				if expected_hits>1:await create_timer(.4).timeout
				var count := played.size()
				main._schedule_render(); await frames()
				main._schedule_render(); await frames()
				check(played.size() == count,"redraw does not replay impact: "+key)
				check(sound.voices.any(func(p): return p.playing),"AudioStreamPlayer actually plays: "+key)
			if g.phase == "review" or g.phase == "ended": break
			step(g)
		check(hit_seen,"attack reaches hit: "+key)
	# Damage that fails its condition must not sound like a successful hit.
	var miss = fixture("judgment")
	for i in range(40):
		if not miss.animation.is_empty() and miss.animation.kind == "strike" and miss.animation.stage == "impact": break
		step(miss)
	check(sound.cues_for(miss.snapshot(0)).is_empty(),"failed judgment has no contact sound")
	# A deliberately skipped attack has no projectile/contact audio.
	var skipped = fixture("hasty_spell")
	while not skipped.animation.is_empty(): skipped.advance_animation()
	check(skipped.skip_effect(0).is_empty(),"skip attack")
	check(sound.cues_for(skipped.snapshot(0)).is_empty(),"skipping cannot start attack sounds")
	# Bounty rewards are driven by actual draw entries, not by a lethal guess.
	var bounty = fixture("bounty",true)
	for i in range(60):
		if not bounty.animation.is_empty() and bounty.animation.kind == "draw_cards": break
		step(bounty)
	await show_game(bounty)
	var rewards: Array = sound.cues_for(bounty.snapshot(0))
	check(rewards.size() == 6,"two awarded cards each have departure, arrival and card-placement sounds")
	var draw:Dictionary=bounty.animation.draws[0]
	for i in range(2):
		var arrival:float=(draw.starts[i]+draw.durations[i])/1000.0
		check(rewards.any(func(c):return c.file==sound.bank.rewards.bounty_arrive and absf(c.delay-arrival)<.001),"reward matches actual accelerated arrival")
		check(rewards.any(func(c):return c.file==sound.support_bank.card_movement.place and absf(c.delay-arrival)<.001),"card placement matches actual accelerated arrival")
	var count_before := played.size()
	main._schedule_render(); await frames()
	check(played.size() == count_before,"pending reward is not restarted by redraw")
	main.session.leave(); await frames()
	check(sound.pending.is_empty() and sound.voices.all(func(p): return not p.playing),"leaving clears delayed sounds and active voices")
	await create_timer(.5).timeout
	check(played.size() == count_before,"no delayed reward after leaving")
	var normal_bounty = fixture("bounty")
	var has_reward := false
	for i in range(50):
		for cue in sound.cues_for(normal_bounty.snapshot(0)):
			if "bounty_depart" in cue.file or "bounty_arrive" in cue.file: has_reward = true
		if normal_bounty.phase in ["review","ended"]: break
		step(normal_bounty)
	check(not has_reward,"nonlethal bounty has no draw reward sounds")
	# Popup, independent volume changes, rematch IDs and long impact tails.
	var hasty = fixture("hasty_spell")
	while hasty.animation.get("kind","") != "strike" or hasty.animation.get("stage","") != "impact": step(hasty)
	await show_game(hasty)
	await create_timer(.4).timeout
	var voice = sound.voices.filter(func(p): return p.playing and p.stream.resource_path.contains("hasty_spell_impact"))[0]
	check(voice.stream.get_length() > 1.7,"confirmed explosion and complete decay are retained")
	var music_stream = main.music.player.stream
	main.music_dialog.popup_centered(Vector2i(720,440))
	await create_timer(.25).timeout
	if "--shots" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/v0179-sound-settings.png")
	check(main.music_dialog.size.y < 640,"sound settings fit the game window")
	check(voice.playing and main.music.player.playing,"popup leaves impact and music playing")
	sound.set_level(0); check(voice.playing and voice.volume_db <= -79,"muting sound leaves timeline intact")
	check(main.music.player.stream == music_stream and main.music.level > 0,"sound volume does not mute music")
	main.music.set_level(0); sound.set_level(.4)
	check(absf(voice.volume_db-linear_to_db(.4)) < .01,"music and sound volume are independent")
	main.music_dialog.hide()
	var sound_config := ConfigFile.new()
	check(sound_config.load(sound.settings_path) == OK and absf(float(sound_config.get_value("sound","volume"))-.4) < .001,"volume setting is persisted")
	var hits_before := played.size()
	hasty.match_id += 1; await show_game(hasty)
	check(played.size() == hits_before+1,"new match can reuse animation IDs")
	hasty.advance_animation(); await show_game(hasty)
	check(sound.voices.any(func(p): return p.playing and not p.get_meta("cut_with_stage",false)),"impact tail survives next state")
	main.session.leave(); await frames()
	print("V0179_AUDIO_RESULT checks=%d failures=%d" % [checks,failures])
	main.queue_free(); await frames()
	quit(0 if failures == 0 else 1)
