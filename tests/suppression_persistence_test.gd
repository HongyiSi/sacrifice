extends "res://tests/v0174_ui_test.gd"
const Scenes=preload("res://tests/art_scenarios.gd")
var stages=0
func walk(n):
	var out=[n]
	for child in n.get_children():out.append_array(walk(child))
	return out
func _run():
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.player.stop();main.music.level=0;main.attack_audio.level=0
	for key in ["suppress","late_suppress"]:
		var setup=Scenes.setup(key,90000+checks);var g=setup[0];var ctx=setup[1];var target=-1
		var sound_count=0
		for i in range(120):
			var e=g.animation
			if e.get("style","")==key and e.get("op","")=="chosen":
				target=e.target_action
				var cues=main.attack_audio.cues_for(g.snapshot(0)).filter(func(c):return "/suppression/" in c.file)
				check(cues==main.attack_audio.cues_for(g.snapshot(1)).filter(func(c):return "/suppression/" in c.file),"public sound identical")
				sound_count+=cues.size()
				check(cues.size()==(1 if e.stage=="travel" else 0),"one foley cue, no persistence loop or repeated impact sound")
			if target>=0 and g._action(target).has("suppression_key"):
				for viewer in [0,1]:
					await show_game(g,viewer)
					var card=walk(main).filter(func(n):return n.get_meta("played_action_id",-999)==target and not n.get_meta("played_death",false))[0]
					var seals=card.get_children().filter(func(n):return n.has_meta("persistent_suppression"))
					check(seals.size()==1 and seals[0].key==key and seals[0].visible,"exactly one seal on the real card from either viewer")
					check(seals[0].mouse_filter==Control.MOUSE_FILTER_IGNORE,"marker never intercepts clicks")
					check(card.hidden_card==(g._action(target).actor/3!=viewer),"marked hidden card obeys viewer privacy")
					if not seals[0].active:
						seals[0].present(30.);check(seals[0].visible,"persistent pose has no fade-out timer")
					stages+=1
			if g.phase in ["review","ended"] and e.is_empty():break
			check(Scenes.step(g,ctx)=="","original rules advance")
		check(sound_count==1,"only actual trigger plays this card's foley")
		check(g.phase=="review" and g._action(target).status=="suppressed","effect survives real round end")
		for dimensions in [Vector2i(960,640),Vector2i(1920,1280)]:
			root.size=dimensions;main._schedule_render();await frames()
			var seals=walk(main).filter(func(n):return n.has_meta("persistent_suppression"))
			check(seals.size()==1 and seals[0].visible,"resize rebuild retains marker")
			check(seals[0].get_parent().get_meta("played_action_id")==target,"resize keeps the correct card anchor")
		g.advance_round()
		await show_game(g,0)
		check(walk(main).filter(func(n):return n.has_meta("persistent_suppression")).is_empty(),"next round clears every old seal")
	print("SUPPRESSION_PERSISTENCE_RESULT checks=%d failures=%d visible_states=%d"%[checks,failures,stages])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
