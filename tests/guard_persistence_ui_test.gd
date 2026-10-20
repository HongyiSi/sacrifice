extends "res://tests/v0174_ui_test.gd"
const Scenes=preload("res://tests/art_scenarios.gd")
const Guard=preload("res://scripts/defense_guard.gd")
func walk(n):
	var out=[n]
	for child in n.get_children():out.append_array(walk(child))
	return out
func holders():return walk(main).filter(func(n):return n.has_meta("persistent_defense"))
func _run():
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.player.stop();main.music.level=0;main.attack_audio.level=0
	for use_defense in [true,false]:
		var g=H.fixture(8);g.match_id=89500+checks;g.presentation_enabled=true;g.resolution_presentation_enabled=true
		H.begin(g,{0:H.give(g,0,"defense"),1:H.give(g,1,"defense"),3:H.give(g,3,"strike"),4:H.give(g,4,"badge")},false)
		var reacted=false;var peak_count=0
		for i in range(70):
			var e=g.animation
			for viewer in [0,1]:
				await show_game(g,viewer)
				var active=e.get("targets",[]).any(func(h):return h.id==0) and e.get("kind","") in ["shield","shield_block"]
				var nodes=holders()
				if g.characters[0].shield>0 and not active:
					check(nodes.size()==1 and nodes[0].actor==0,"both viewers see one guarded pawn")
					check(nodes[0].center.is_equal_approx(Guard.anchor(main.board,0)),"shield anchored to the correct perspective")
					check(not nodes[0].releasing and nodes[0].mouse_filter==Control.MOUSE_FILTER_IGNORE,"retained shield never times out or intercepts clicks")
					peak_count=maxi(peak_count,g.characters[0].shield)
				if active:check(nodes.is_empty(),"arrival/block takes over retained shape without double rendering")
				if g.phase=="review":
					check(g.characters[0].shield==0,"real round clears charges")
					check(nodes.size()==1 and nodes[0].releasing,"round cleanup fades remaining shield for both clients")
			if g.phase=="review":break
			if not e.is_empty():g.advance_animation()
			elif g.phase=="targeting":check(g.target(g.request.team,0)=="","chosen protected pawn")
			elif g.phase=="reacting":
				for dimensions in [Vector2i(960,640),Vector2i(1920,1280)]:
					root.size=dimensions;main._schedule_render();await frames()
					check(holders().size()==1 and not holders()[0].releasing,"resize and rebuild retain shield")
				check(g.defend(g.request.team,use_defense)=="","player defense decision respected");reacted=true
			else:check(Scenes.step(g,{"key":"defense","target_index":0,"targets":[],"follow":false})=="","remaining rules proceed")
		check(reacted and peak_count==2,"two independent defensive charges demonstrated")
		check(g.characters[0].hp==(8 if use_defense else 7),"declining defense keeps the actual damage rule")
		await create_timer(.65).timeout;main._schedule_render();await frames()
		check(holders().is_empty(),"expired visual is removed after its fade")
	print("GUARD_PERSISTENCE_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
