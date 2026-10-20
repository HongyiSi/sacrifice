extends "res://tests/v0203_ui_test.gd"
func _run()->void:
	root.size=Vector2i(1200,800);main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.4).timeout
	main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume();main.session.set_process(false)
	for viewport_size in [Vector2i(1200,800),Vector2i(1280,720)]:
		root.size=viewport_size;await frames()
		for key in ["local_ai_start","learning_ai_start"]:
			var entry=meta(main,key,true);check(entry!=null and entry.is_visible_in_tree(),key+" is visible")
			check(root.get_visible_rect().encloses(entry.get_global_rect()),key+" fits viewport")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://test-results/learning-ai-lobby.png")
	meta(main,"learning_ai_start",true).pressed.emit();await frames()
	check(main.session.ai_opponent.get_script().resource_path=="res://scripts/learning_ai.gd","new button selects trained AI")
	check(main.session.ai_mode and not main.session.online_mode and main.session.names[1]=="自学习 AI","trained session stays local and names opponent")
	var g=main.session.game
	for i in range(100):
		if g.animation.is_empty():break
		g.advance_animation()
	main.session._broadcast();main.session.ai_next_action=0;main.session._process_ai()
	check(main.session.ai_opponent.pending!=null,"learning search yields to UI")
	for i in range(3000):
		if g.plans[1]!=null:break
		main.session.ai_next_action=0;main.session._process_ai();await process_frame
	check(g.plans[1]!=null and g.plans[0]==null,"trained AI plans independently")
	main.session.leave();await frames();meta(main,"local_ai_start",true).pressed.emit();await frames()
	check(main.session.ai_opponent.get_script().resource_path=="res://scripts/local_ai.gd","old entry still selects original AI")
	main.session.leave();await frames()
	check(main.session.ai_opponent==null and main.session.ai_thinking_view.is_empty(),"leaving cleans up search")
	print("LEARNING_AI_UI_RESULT checks=%d failures=%d"%[checks,failures]);main.queue_free();await frames();quit(0 if failures==0 else 1)
