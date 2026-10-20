extends "res://tests/v0174_ui_test.gd"
const S=preload("res://tests/v011_scenarios.gd")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0176_UI_FAIL "+label)
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0176-"+name+".png")
func draw_pose(g,t:float):
	var fx=meta(main,"draw_animation",g.animation.id)
	check(fx!=null,"real draw layer exists")
	if fx==null:return null
	fx.clock_started=-1;fx.set_process(false);fx.elapsed=t;fx._process(0)
	await RenderingServer.frame_post_draw
	return fx
func make_draw(actor:int,count:int):
	var g=H.fixture(8);serial+=1;g.match_id=serial
	for id in range(6):
		for k in ["strike","heal"]:H.give(g,id,k)
	g.presentation_enabled=true;g._push([{"op":"draw","target":actor,"count":count}]);g._pump()
	return g
func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	for actor in range(6):
		var g=make_draw(actor,3)
		for viewer in [0,1]:
			await show_game(g,viewer)
			var fx=await draw_pose(g,0)
			check(fx.flights.size()==3 and fx.rows.size()==1,"actual gained cards become three flights")
			check(fx.pile!=null and fx.pile.count==g.animation.pile_before,"permanent pile starts at original count")
			check(fx.rows[actor].label!=null and fx.rows[actor].count==2,"hand count stays old before arrivals")
			var tag:String="hand_actor" if actor/3==viewer else "enemy_hand_actor"
			check(not meta(main,tag,actor).visible,"original cards hidden during replacement flight")
			for f in fx.flights:
				check(f.node.hidden_card,"all departures show backs")
				check((not f.node.card.is_empty())==(actor/3==viewer),"opponent identities never reach drawing nodes")
			for t in [0.22,0.9,1.68,2.1,2.5]:
				fx=await draw_pose(g,t)
				var count:=2;var pile:int=g.animation.pile_before
				for f in fx.flights:
					if t>=f.started+f.duration:count+=1
					if t>=f.started+f.duration*.13:pile=f.pile_after
					if f.node.visible:
						var center:Vector2=f.node.position+f.node.pivot_offset
						check(Rect2(110,80,1200,820).has_point(center),"flight stays within parchment")
				check(fx.rows[actor].count==count and fx.pile.count==pile,"counts follow each takeoff and landing")
			check(fx.rows[actor].cards.all(func(c):return c.hidden_card==(actor/3!=viewer)),"friendly arrival reveals fronts; enemy keeps backs")
			check(fx.rows[actor].cards.all(func(c):return c.visible),"all final cards visible")
			if actor==0 and viewer==0:await draw_pose(g,1.7);await shot("draw-three")
			if actor==5 and viewer==0:await draw_pose(g,1.1);await shot("enemy-draw")
			# Rebuild from the same event must retain its starting timestamp.
			var began:int=main.effect_started;await show_game(g,viewer)
			check(main.effect_started==began,"unrelated redraw does not restart flight")
		g.advance_animation();await show_game(g);var fx=await draw_pose(g,0)
		check(fx.rows[actor].count==5 and fx.pile.count==g.deck.size(),"impact shows completed counts")
		g.advance_animation();await show_game(g)
		check(meta(main,"draw_animation",g.animation.get("id",-99))==null,"draw overlay removed")
		check(meta(main,"draw_pile",true)!=null and meta(main,"hand_actor",0).visible,"pile remains, hand inspection restored")
	# A new match deals three cards plus the first round draw for every pawn.
	var g=H.Rules.new();g.presentation_enabled=true;g.start(812);serial+=1;g.match_id=serial
	await show_game(g)
	check(g.animation.is_empty() and g.phase=="planning","initial four-card hands need no animation")
	await shot("initial-deal")
	g.stage_presentation_enabled=false;g.phase="review";g.advance_round();await show_game(g)
	var fx
	fx=await draw_pose(g,1.4);check(fx.flights.size()==6 and fx.rows.size()==6,"six round draws share one timeline")
	await shot("round-draw")
	# Hand-limit picker is shown only after cards arrive.
	g=H.fixture(8);g._draw(g.characters[0],6);g.presentation_enabled=true;serial+=1;g.match_id=serial
	g._push([{"op":"draw","target":0,"count":5}]);g._pump();await show_game(g)
	fx=await draw_pose(g,2.5);check(fx.flights.size()==5 and meta(main,"selection_panel",true)==null,"overflow remains flight before selection")
	await shot("five-cards")
	finish_fx(g);await show_game(g);check(meta(main,"selection_panel",true)!=null,"owner chooses excess after landing")
	# New card visuals use actual source symbols and two independent targets.
	for key in ["warcry","precise_strike","greed","privilege","heart"]:
		g=S.setup(key,key in ["greed","privilege","heart"],true);serial+=1;g.match_id=serial
		for _i in range(30):
			if not g.animation.is_empty():break
			check(S.step(g).is_empty(),"resolve new card choices")
		for viewer in [0,1]:
			await show_game(g,viewer)
			if g.animation.kind=="draw_cards":await draw_pose(g,1.4)
			else:
				var effect=await pose(g,.65)
				if key=="precise_strike":check(effect.event.targets.size()==2 and effect.launch_effect!=null,"two teal blades launched from precise strike")
				if key in ["greed","privilege"]:check(effect.event.targets.size()==3,"team aura points to all three allies")
				clear_card(main.board._active_widget())
			if viewer==0:await shot(key)
	# Smaller viewport and leaving during flight.
	root.size=Vector2i(960,640);await frames();g=make_draw(1,3);await show_game(g,1);await draw_pose(g,1.2);await shot("small-window")
	main.session.leave();await frames();check(meta(main,"draw_pile",true)==null,"leaving removes pile and flight")
	print("V0176_UI_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
