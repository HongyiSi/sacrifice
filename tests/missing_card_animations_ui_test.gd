extends "res://tests/v0174_ui_test.gd"
const Cases = preload("res://tests/v011_scenarios.gd")
const NewStyles = preload("res://scripts/card_effect_styles.gd")
func game(key: String):
	var g
	if key=="poison":
		g=H.fixture();g.presentation_enabled=true
		var id: int = g._generate_card(H.Rules.POISON);g.characters[0].hand.append(id);H.begin(g,{0:id})
	else:g=Cases.setup(key,key=="legacy",true)
	serial+=1;g.match_id=serial;return g
func _run() -> void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume();main.session.set_process(false)
	var covered := {}
	for key in NewStyles.NEW_CARDS:
		var g=game(key)
		for i in range(220):
			if g.animation.is_empty() and g.phase in ["planning","review","ended"]:break
			var e: Dictionary = g.animation
			if not e.is_empty() and ((e.get("style","")==key and e.kind in ["card_effect","heal"]) or (e.kind=="draw_cards" and key in ["gift","search","obstruct","poisoning"])):
				for viewer in [0,1]:
					await show_game(g,viewer)
					if e.kind=="draw_cards":
						var fx=meta(main,"draw_animation",e.id)
						check(fx!=null,"gain renderer "+key)
						if fx==null:continue
						fx.clock_started=-1;fx.set_process(false);fx.elapsed=.8;fx._process(0)
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("res://test-results/new-fx-%s-gain-%d.png"%[key,viewer])
						for f in fx.flights:
							check(fx.flight_path(f,1,f.node.get_meta("goal")+f.node.pivot_offset).distance_to(f.node.get_meta("goal")+f.node.pivot_offset)<.01,"exact hand landing")
							if key!="search":check(f.custom_origin,"non-deck gain starts at actual source")
					else:
						for t in [.2,.58,.92]:
							var fx=await pose(g,t)
							if fx==null:continue
							check(fx.launch_effect.book.new_effect!=null,"themed renderer "+key)
							if e.has("hand_motion"):check(fx.motion_points.size()==e.hand_motion.slots.size(),"selected card positions")
							if e.get("op","")=="anticipation":check(not fx.marked_points.is_empty(),"prediction scans real hidden cards")
							if t==.58:
								root.get_texture().get_image().save_png("res://test-results/new-fx-%s-%s-%s-%d.png"%[key,e.get("op","heal"),e.stage,viewer])
						covered[key]=true
			check(Cases.step(g)=="","scenario progresses "+key)
	check(covered.size()==NewStyles.NEW_CARDS.size(),"all added card effects drawn on both sides")
	print("MISSING_ANIMATIONS_UI_RESULT checks=%d failures=%d covered=%d"%[checks,failures,covered.size()])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
