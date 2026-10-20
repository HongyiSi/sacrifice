extends "res://tests/v0203_ui_test.gd"
const G=preload("res://tests/gem_scenarios.gd")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume()
	for viewer in [0,1]:
		var g=H.fixture(7);serial+=1;g.match_id=serial;main.session.game=g;H.give_death(g,0,"sacrifice_badges")
		await show_game(g,viewer)
		var fan=meta(main,"death_fan_actor",0);var original=fan.get_child(0).get_global_rect()
		g.characters[0].hp=0;g.characters[0].death_round=g.round_number;H.begin(g,{});check(G.drain(g),"death resolves")
		await show_game(g,viewer)
		var card=meta(main,"triggered_death_id",106)
		check(card!=null and card.get_global_rect().is_equal_approx(original),"spent death stays in original location")
		check(card!=null and card.action_status=="triggered" and not card.hidden_card,"spent card is face up and marked")
		check(nodes(main).filter(func(n):return n is CardWidget and n.death and n.card.get("id",0)==106).size()==1,"no duplicate played card remains")
		await move_mouse(card.get_global_rect().get_center())
		check(meta(root,"hover_card_description",106)!=null,"spent card still has hover description")
		await move_mouse(Vector2(30,400));await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/triggered-death-view-%d.png"%viewer)
		g._revive(0,3);g.advance_round();check(G.drain(g),"later round begins")
		await show_game(g,viewer);check(meta(main,"triggered_death_id",106)!=null,"UI survives round rebuild")
		H.give_death(g,0,"vanish");g.presentation_enabled=true
		check(g._present_card_job({"op":"strip","a":g._visual_action("mediocrity",3),"target":0}),"strip presentation starts")
		await show_game(g,viewer)
		var effect=meta(main,"cinema_effect",g.animation.id)
		card=meta(main,"triggered_death_id",106)
		check(effect!=null and effect.event.card_count==1 and card.visible and card.modulate.a==1.,"strip counts only live deaths and leaves history visible")
		g.animation={};g.animation_jobs.clear()
		check(g._present_card_job({"op":"draw_death","a":g._visual_action("elegy",0)}) and g.animation.death_slot==2,"new death flies to a slot after live cards and history")
		await show_game(g,viewer);effect=meta(main,"cinema_effect",g.animation.id)
		var landing=effect.handler.death_landing()
		g.animation={};g.animation_jobs.clear();g._run_job({"op":"draw_death","a":{"actor":0}})
		await show_game(g,viewer);fan=meta(main,"death_fan_actor",0)
		check(landing.is_equal_approx(main.board.canvas.get_global_transform().affine_inverse()*fan.get_child(2).get_global_rect().get_center()),"new death animation lands on the actual new card")
	print("TRIGGERED_DEATHS_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
const CardWidget=preload("res://scripts/card_widget.gd")
func nodes(node:Node)->Array:
	var result=[node]
	for child in node.get_children():result.append_array(nodes(child))
	return result
