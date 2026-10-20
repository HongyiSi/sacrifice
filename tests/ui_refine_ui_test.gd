extends "res://tests/v0203_ui_test.gd"
const Scenarios=preload("res://tests/art_scenarios.gd")
const Priority=preload("res://scripts/art_ui/priority_style.gd")
const Card=preload("res://scripts/card_widget.gd")
var placement_count=0
var normal_count=0
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/ui-refine-"+name+".png")
func sample_draw(fx,t:float)->void:
	fx.set_process(false);fx.clock_started=-1;fx.elapsed=t;fx._process(0)
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.set_level(0);main.attack_audio.level=0
	var g=H.fixture(8);g.match_id=87400
	for definition in [H.Rules.BOULDER,H.Rules.POISON]:g.characters[0].hand.append(g._generate_card(definition))
	var curse=H.give_death(g,0,"curse");g.characters[0].deathrattles.erase(curse);g.characters[0].hand.append(curse)
	for id in range(6):
		while g.characters[id].hand.size()<8:g.characters[id].hand.append(g.deck.pop_back())
	await show_game(g,0);await move_mouse(Vector2(50,730));await shot("board")
	var pile=meta(main,"draw_pile",true)
	check(pile.get_meta("draw_chest",false) and pile.get_children().all(func(n):return not n is Label and not n is Card),"pile is a single unlabelled chest")
	for id in range(6):
		var label=meta(main,"pawn_title",id);var pawn=main.board.Layout.pawn_rect(id,id<3)
		check(absf(label.position.x+label.size.x/2-pawn.get_center().x)<.01,"name centers above pawn")
		check(label.position.y+label.size.y<=pawn.position.y,"name does not overlap pawn")
		check(label.get_child_count()==0,"name has no backing")
	var hand=meta(main,"hand_actor",0)
	var black=0
	for c in hand.get_children():
		if c is Card and c.card.get("type","")=="诅咒":
			black+=1;check(Priority.group_for(c.card)==4,"all hand curses use black frame")
			var painted=c.get_node("PriorityFrame")
			check(painted.material==null and painted.texture.atlas.resource_path=="res://assets/art_ui/repainted/black.png","curse uses the painted black material without a tint overlay")
	check(black==3,"boulder, poison and transferred curse all covered")
	check(Priority.group_for(H.Rules.POISON,false,true)==-1,"black frame does not reveal a hidden curse")
	for key in ["obstruct","poisoning","gift","search","plunder","collect"]:
		serial+=1;var pair=Scenarios.setup(key,89000+serial);g=pair[0]
		var done=false
		for step in range(160):
			if g.animation.get("kind","")=="draw_cards" and g.animation.stage=="travel":
				for viewer in [0,1]:
					await show_game(g,viewer)
					var fx=meta(main,"draw_animation",g.animation.id)
					for f in fx.flights:
						if f.placement:
							placement_count+=1
							for u in [0.0,.4,.78,.9,1.0]:
								sample_draw(fx,f.started+f.duration*u)
								check(f.node.visible,"one incoming node owns the entire placement")
								if u<.78:check(is_zero_approx(f.node.modulate.a),"object flies without a second visible card")
								else:check((f.node.position-f.node.get_meta("goal")).length()<.1,"card materializes at actual destination")
								if u==.9:check(f.node.modulate.a>0 and f.node.modulate.a<1,"object and card crossfade at destination")
								if u==1:check(is_equal_approx(f.node.modulate.a,1),"card fully visible after landing")
								if viewer!=int(f.id)/3:check(f.node.card.is_empty() and f.node.hidden_card,"opponent receives only a back")
						else:
							normal_count+=1;sample_draw(fx,f.started+f.duration*.45)
							check(is_equal_approx(f.node.modulate.a,1) and f.node.hidden_card,"ordinary dealing keeps its visible flying back")
					if key=="obstruct":
						check(fx.flights.size()==2,"two stones produce two actual cards")
						check(fx.flights[0].origin.distance_to(fx.flights[1].origin)>45,"stones have separate preparation points")
						var f=fx.flights[0];sample_draw(fx,f.started+f.duration*.48);await shot("obstruct-flight-"+str(viewer))
						sample_draw(fx,f.started+f.duration*.9);await shot("obstruct-morph-"+str(viewer))
			var error=Scenarios.step(g,pair[1])
			if error=="done":done=true;break
			if not error.is_empty():check(false,error);break
		check(done,"scenario completes: "+key)
	check(placement_count>=10 and normal_count>=6,"both viewpoints cover placement and normal drawing")
	print("UI_REFINE_RESULT checks=%d failures=%d placements=%d draws=%d"%[checks,failures,placement_count,normal_count])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
