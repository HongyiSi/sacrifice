extends "res://tests/v0174_ui_test.gd"
const Gems=preload("res://tests/gem_scenarios.gd")
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0204-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	var g=H.fixture(8);g.match_id=304000
	var keys:Array=g.death_catalog.keys()
	for actor in range(6):
		for _i in range(2 if actor in [0,3] else 3):
			var id:int=keys.pop_front();H.give_death(g,actor,g.death_catalog[id].key);g.death_revealed.append(id)
		for key in ["strike","heal"]:H.give(g,actor,key)
		g.characters[actor].warcry_bonus=3;g.characters[actor].warcry_round=g.round_number+1
	for viewer in [0,1]:
		await show_game(g,viewer);await shot("deaths-horns-%d"%viewer)
	root.size=Vector2i(960,640);main._schedule_render();await frames();await shot("small")
	root.size=Vector2i(1440,960)
	g=Gems.setup("ruby",0,304001);Gems.seek(g)
	for stage in ["travel","impact","return"]:
		await show_game(g,0)
		var fx=meta(main,"gem_animation",g.animation.id)
		fx.clock_started=-1;fx.set_process(false);fx.elapsed=.45*Styles.duration(fx.event)/1000.0;fx._process(0)
		await shot("ruby-"+stage)
		g.advance_animation()
	await show_game(g,0);await shot("review")
	g=H.fixture(8);g.match_id=304002;H.begin(g,{0:H.give(g,0,"strike")})
	await show_game(g,0);await shot("target-choice")
	print("V0204_PREVIEW_COMPLETE failures=%d"%failures)
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
