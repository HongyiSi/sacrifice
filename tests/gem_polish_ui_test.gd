extends "res://tests/v0174_ui_test.gd"
const Gems=preload("res://tests/gem_polish_scenarios.gd")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("GEM_POLISH_UI_FAIL "+label)
func pose_gem(g,seconds):
	var draw=meta(main,"draw_animation",g.animation.id)
	if draw!=null:draw.set_process(false);draw.clock_started=-1;draw.elapsed=seconds;draw._process(0)
	var fx=meta(main,"gem_animation",g.animation.id)
	check(fx!=null,"native gem layer exists")
	if fx==null:return null
	fx.set_process(false);fx.clock_started=-1;fx.elapsed=seconds;fx._process(0)
	return fx
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"));root.add_child(main)
	await create_timer(.3).timeout;main.session.set_process(false);main.music.level=0;main.music.player.stop();main.attack_audio.level=0
	var dir="D:/Godot projects/sacrifice/work/gems-polish-install-oct10/screens"
	DirAccess.make_dir_recursive_absolute(dir)
	for key in ["ruby","amber","sapphire","emerald","amethyst","topaz"]:
		for actor in [1,4]:
			var g=Gems.setup(key,actor,833400+checks)
			for viewer in [0,1]:
				await show_game(g,viewer)
				var fx=pose_gem(g,1.10)
				if fx==null:continue
				check(is_instance_valid(fx.source_card),"real source card exists")
				check(fx.visual.port.distance_to(fx.visual.chest)<1.,"attached to chest")
				check(fx.visual.chest==Layout.pawn_center(actor,actor/3==viewer)+Vector2(6 if actor/3==viewer else 4,9),"amulet chest offset")
				check(fx.source_card.motif_alpha==0.,"no duplicate printed gem")
				if key in H.Rules.GEMS and actor/3!=viewer:check(fx.source_card.hidden_card,"opponent source hidden")
				await RenderingServer.frame_post_draw
				if viewer==0:root.get_texture().get_image().save_png(dir.path_join(key+"-%d-chest.png"%actor))
				var original=Time.get_ticks_msec()-1100;main.effect_started=original;main._schedule_render();await frames()
				fx=meta(main,"gem_animation",g.animation.id)
				check(fx.clock_started==original and fx.elapsed>=1.1,"refresh keeps clock")
				if viewer==0 and actor==1:
					root.size=Vector2i(960,640);main._schedule_render();await frames();fx=pose_gem(g,1.10)
					check(fx.visual.port.distance_to(fx.visual.chest)<1.,"resize keeps chest alignment")
					root.size=Vector2i(1440,960);await frames()
			g.advance_animation()
			for viewer in [0,1]:
				await show_game(g,viewer)
				var fx=pose_gem(g,.35)
				if fx==null:continue
				if key in ["sapphire","emerald"]:
					var draw=meta(main,"draw_animation",g.animation.id)
					check(draw!=null and draw.flights.size()==(1 if key=="sapphire" else 4),"native flights coexist")
					check(fx.visual.facet.visible and fx.visual.age>1.32,"gem continues during draw")
					if key=="sapphire":check(draw.rows[actor].cards.has(fx.source_card),"return targets animated hand")
					else:check(fx.source_card==main.board._active_widget(),"green returns to played card before transfer")
					pose_gem(g,1.25 if key=="sapphire" else 2.24)
					check(fx.visual.port.distance_to(fx.source)<15.,"return follows moving source")
				await RenderingServer.frame_post_draw
				if viewer==0:root.get_texture().get_image().save_png(dir.path_join(key+"-%d-effect.png"%actor))
			check(Gems.G.drain(g),"scenario completes")
	print("GEM_POLISH_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
const Layout=preload("res://scripts/board_layout.gd")
