extends "res://tests/v0174_ui_test.gd"
const Scenarios=preload("res://tests/v011_scenarios.gd")
const Arcane=preload("res://scripts/arcane_strikes_launch.gd")
const Palette=preload("res://scripts/card_palette.gd")
func shot_new(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0175-"+name+".png")
func clear_feedback(fx)->void:
	var card=main.board._active_widget()
	if card==null:return
	var rect:Rect2=main.board._board_rect(card)
	for label in fx.feedback_positions.values():
		check(not label.intersects(rect),"effect feedback avoids raised card")
func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	for key in ["holy_strike","quick_strike","hasty_spell","magic_strike"]:
		for actor in range(6):
			var g=fixture(key,actor)
			for viewer in [0,1]:
				await show_game(g,viewer);var fx=await pose(g,.69)
				check(fx.launch_effect!=null and fx.strike_effect!=null,"new attack uses card-origin and old impact")
				clear_card(main.board._active_widget())
				if key=="holy_strike":
					var target:Vector2=fx._knight(g.animation.targets[0].id)
					var top:Vector2=fx.launch_effect.flight_position(target,.7,0,1)
					check(top.x==target.x and top.y<target.y,"sword reaches above actual target")
					check(Vector2.from_angle(fx.launch_effect.blade_angle(target,.7,0,1)+Arcane.TIP_ANGLE).dot(Vector2.DOWN)>.999,"sword points downward in either view")
				if actor==0 and viewer==0:await shot_new(key+"-travel")
			g.advance_animation()
			for viewer in [0,1]:
				await show_game(g,viewer);await pose(g,.2)
				if actor==0 and viewer==0:await shot_new(key+"-impact")
	var seen:Dictionary={}
	var base=H.fixture()
	for death in [false,true]:
		for c in (base.death_catalog if death else base.catalog).values():
			if seen.has(c.key):continue
			seen[c.key]=true
			var g=Scenarios.setup(c.key,death,true);serial+=1;g.match_id=serial
			for _i in range(150):
				if g.animation.get("style","")==c.key:break
				if g.phase in ["review","ended"] and g.animation.is_empty():break
				check(Scenarios.step(g).is_empty(),"actual effect reached "+c.key)
			check(not g.animation.is_empty(),"visible effect "+c.key)
			if g.animation.is_empty():continue
			for viewer in [0,1]:
				await show_game(g,viewer);var fx=await pose(g,.7)
				check(fx.launch_effect!=null or fx.attack_reward!=null,"all cards have card-driven presentation "+c.key)
				check(fx.mouse_filter==Control.MOUSE_FILTER_IGNORE,"effect does not block input")
				var card=main.board._active_widget()
				if card!=null:
					clear_card(card)
					if death:
						var side=main.board._find_display_card(main.board.canvas,"death_%d_%d"%[g.animation.action.actor,g.animation.action.card])
						if side!=null and side!=card:check(not side.visible,"death card side copy hidden")
				if viewer==0 and c.key in ["blood_rite","team_heal","collect","gambler","prison","divinity","curse","mirror"]:await shot_new(c.key+"-travel")
			g.advance_animation()
			if not g.animation.is_empty():
				await show_game(g,1);var fx=await pose(g,.25);clear_feedback(fx)
				if c.key in ["blood_rite","resurrection","death_sentence","prophecy","last_dance"]:await shot_new(c.key+"-impact")
	check(seen.size()==55,"55 unique card types rendered")
	# A blocked new spell must retain its identity without a damage impact.
	var g=H.fixture(8);g.presentation_enabled=true
	H.begin(g,{0:H.give(g,0,"holy_strike"),3:H.give(g,3,"defense")});finish_fx(g)
	# Holy priority 10 precedes defense, so provide the pre-existing shield explicitly.
	g.characters[3].shield=1;g.characters[3].shield_sources=[3];g.target(0,3);g.defend(1,true)
	await show_game(g);await pose(g,.75);g.advance_animation();await show_game(g);await pose(g,.2);await shot_new("holy-blocked")
	check(g.characters[3].hp==8,"blocked holy animation causes no damage")
	root.size=Vector2i(960,640);await frames()
	g=fixture("magic_strike",5);await show_game(g,1);await pose(g,.68);clear_card(main.board._active_widget());await shot_new("magic-small-opponent")
	main.session.leave();await frames();check(main.resolution_focus.is_empty(),"leave clears presentation focus")
	print("V0175_UI_RESULT checks=%d failures=%d cards=%d"%[checks,failures,seen.size()]);quit(0 if failures==0 else 1)
