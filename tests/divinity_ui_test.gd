extends "res://tests/v0174_ui_test.gd"
const Cases=preload("res://tests/divinity_scenarios.gd")
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/divinity-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for actor in range(6):
		serial+=1;var g=Cases.setup(actor,serial)
		for viewer in [0,1]:
			await show_game(g,viewer)
			var angel=meta(main,"divinity_actor",actor)
			check(angel!=null and not angel.original.visible,"active divinity replaces exactly one pawn sprite")
			var saved:int=angel.started
			angel.pose(3.0,1.0);angel.set_process(false)
			var factor=angel.texture_rect.size.x/angel.texture.get_width()
			var lowest=angel.base_bounds.position.y
			for p in angel.body_edge:
				if p.x>angel.base_bounds.position.x and p.x<angel.base_bounds.end.x:lowest=maxf(lowest,p.y)
			var clearance=(angel.base_bounds.position.y-lowest)*factor+angel.lift
			check(angel.strength==1 and angel.lift<30 and clearance>1.5,"small hover clears the complete stationary pedestal for each figure")
			check(angel.body_edge.size()>=18 and angel.texture!=null,"every knight has its own body cutout")
			await capture("form-%d-%d"%[actor,viewer])
			main._schedule_render();await frames();angel=meta(main,"divinity_actor",actor)
			check(angel.started==saved,"UI rebuild preserves activation clock")
		var recipient:int=(actor+1)%6
		for repeat in range(2):
			g._push([{"op":"draw","target":recipient,"count":1}]);g._pump()
			check(g.animation.kind=="divinity_pulse" and g.animation.action.actor==actor,"each draw radiates from divinity owner")
			for viewer in [0,1]:
				await show_game(g,viewer)
				var pulse=meta(main,"divinity_pulse",g.animation.id)
				var angel=meta(main,"divinity_actor",actor)
				angel.pose(4.0,1.0);angel.set_process(false)
				pulse.started=-1;pulse.set_process(false);pulse.elapsed=.75;pulse._process(0)
				check(pulse!=null and meta(main,"effect_animation",g.animation.id)==null,"old sun-launch layer replaced")
				var expected:Vector2=pulse.get_global_transform().affine_inverse()*(angel.get_global_transform()*angel.chest_position())
				check(pulse.center.distance_to(expected)<.1,"wave follows caster torso, not recipient or card")
				var card=meta(main,"death_card_id",102)
				check(card!=null and card.motif_alpha==1 and card.resolution_started<0,"sun remains printed on stationary death card")
				if repeat==0 and actor==0:await capture("pulse-"+str(viewer))
				if actor==2 and viewer==0 and repeat==0:
					var started:int=Time.get_ticks_msec()-650;main.effect_started=started
					root.size=Vector2i(960,640);main._schedule_render();await frames();pulse=meta(main,"divinity_pulse",g.animation.id)
					check(pulse.started==started and pulse.elapsed>=.65,"resize preserves pulse progress")
					await capture("small");root.size=Vector2i(1440,960);await frames()
			g.advance_animation()
			check(g.phase=="selecting" and g.request.type=="deck","pulse finishes before private selection")
			for viewer in [0,1]:
				check(not g.snapshot(viewer).input.options.is_empty()==(viewer==actor/3),"only divinity owner can see the deck choices")
			g.pick(actor/3,g.request.options.slice(0,1));finish_fx(g);g.phase="resolution"
		g._revive(actor,1)
		await show_game(g,actor/3)
		check(meta(main,"divinity_actor",actor)!=null and not meta(main,"knight_id",actor).get_child(0).visible,"revival preserves activated divinity until its source is lost")
		g.characters[actor].hp=0;g._lose_death(actor,102)
		await show_game(g,actor/3)
		check(meta(main,"divinity_actor",actor)==null,"losing the source card removes wings and halo")
	print("DIVINITY_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
