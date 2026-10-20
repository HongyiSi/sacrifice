extends "res://tests/v0203_ui_test.gd"
func _run() -> void:
	root.size=Vector2i(1200,800)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").ai_checkpoint.path="res://test-results/ai-checkpoint-ui"
	main.get_node("Session").ai_checkpoint.clear()
	root.add_child(main); await frames()
	main.session.set_process(false)
	main.session.start_ai("界面恢复",127)
	for i in range(150):
		if main.session.game.animation.is_empty():break
		main.session.game.advance_animation()
	main.session._broadcast(); await frames()
	var actor=main.session.game.characters[0]
	var id=0
	for card in actor.hand:
		if main.session.game._can_play_hand_card(actor,card):id=card;break
	check(id>0,"fixture has playable card")
	main._toggle_plan(0,id); await frames()
	check(main.choices[0]==[id],"hand click stages card")
	var before=main.session.state.duplicate(true)
	main.free(); await frames()
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").ai_checkpoint.path="res://test-results/ai-checkpoint-ui"
	main.get_node("Session").set_process(false)
	root.add_child(main); await frames()
	check(main.session.ai_mode,"startup automatically resumes local AI")
	check(main.session.state==before,"same board and rule state restored")
	check(main.choices[0]==[id],"unconfirmed planned card restored")
	await create_timer(.4).timeout
	check(staged(id)!=null,"planned card visible at its staged location")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/ai-checkpoint-resumed.png")
	main.session.leave(); await frames()
	check(main.session.ai_checkpoint.read().is_empty(),"exit button discards saved match")
	main.free()
	print("AI_CHECKPOINT_UI checks=",checks," failures=",failures)
	quit(1 if failures else 0)
