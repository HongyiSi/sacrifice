extends SceneTree
const Tutorial = preload("res://scripts/tutorial.gd")
const UI = preload("res://scripts/tutorial_ui.gd")
var main
var failures := 0
var visited := {}
var rewound := {}
var folder := "res://test-results/tutorial"
var realtime := false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func settle() -> void:
	for i in range(3): await process_frame

func click(control: Control) -> void:
	# Exercise hit testing, not just signal callbacks (overlays must not steal clicks).
	await create_timer(.35).timeout
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at; root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at; event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event,true)
	await settle()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label+".png")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder = arg.trim_prefix("--output=")
		if arg == "--realtime": realtime = true
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,960)
	main = load("res://scenes/main.tscn").instantiate()
	main.preview = true
	main.get_node("Session").ai_checkpoint.enabled = false
	root.add_child(main)
	main.session.set_process(realtime)
	main.music.level=0; main.music._apply_volume()
	main.attack_audio.level=0; main.attack_audio._apply_volume()
	main.session.leave(false)
	await settle()
	await shot("lobby")
	var start = UI.find_tag(main,"tutorial_start",true)
	check(start != null,"Lobby has tutorial entry")
	await click(start)
	await settle()
	await shot("welcome")
	for i in range(3000 if realtime else 500):
		var t = main.session.tutorial
		var g = main.session.game
		var panel = UI.find_tag(main,"tutorial_panel",true)
		var body = UI.find_tag(main,"tutorial_body",true)
		check(panel != null,"Lesson is visible throughout the match")
		check(panel.position == t.panel_rect().position,"Reading panel stays at its chapter position")
		var back = UI.find_tag(main,"tutorial_previous",true)
		check(back != null and back.disabled == (t.playing or t.history.size() < 2),"Previous waits for complete animation")
		check(body.get_content_height() <= 100,"Lesson text fits its reading area at step %d (height %d)" % [t.step,body.get_content_height()])
		if not visited.has(t.step):
			visited[t.step] = true
			print("TUTORIAL_UI_STEP ",t.step)
			if t.step in [Tutorial.Step.UNDO,Tutorial.Step.REPLACE,Tutorial.Step.GUARD_TARGET,Tutorial.Step.GUARD_REACT,Tutorial.Step.DEATH,Tutorial.Step.ROUND_END,Tutorial.Step.HEAL_TARGET]:
				await create_timer(.45).timeout
				await shot("step-%02d" % t.step)
		if t.step == Tutorial.Step.COMPLETE: break
		if not realtime and not t.playing and not rewound.has(t.step) and t.history.size() > 1:
			rewound[t.step] = true
			var previous: Dictionary = t.history[-2]
			var expected = preload("res://scripts/ai_checkpoint.gd").Graph.new().decode(bytes_to_var(previous.data))
			await click(back)
			check(t.step == previous.step,"Previous restores the actual lesson step")
			check(main.choices == expected.choices,"Previous restores staged cards")
			check(g.characters == expected.fields.characters and g.badges == expected.fields.badges,"Previous restores HP, hands, and badges")
			check(g.plans == expected.fields.plans and g.phase == expected.fields.phase,"Previous restores confirmation and resolution")
			continue
		var next = UI.find_tag(main,"tutorial_next",true)
		if next != null: check(next.text == "确认","Every next-page button says confirm")
		if not g.animation.is_empty(): check(next == null and not t.holds_animation(),"No confirmation interrupts an in-flight animation")
		if next != null and g.lesson_boundary:
			await shot("completed-effect-%d" % g.lesson_boundary_id)
		for id in [t.card(1,"defense"),t.card(2,"heal_other")]:
			var staged = UI.find_tag(main.board.canvas,"staged_card_id",id)
			if staged != null and t.step >= Tutorial.Step.ORDER:
				check(not panel.get_rect().intersects(UI.rect_on_board(staged,main.board.canvas)),"Panel leaves defense/healing staged cards visible")
		if not main.resolution_focus.is_empty():
			var card_rect := Rect2(main.resolution_focus.destination,main.board.Layout.CARD_SIZE*main.resolution_focus.scale)
			check(not panel.get_rect().intersects(card_rect),"Lesson does not cover the resolving card")
		var f: Dictionary = t.focus()
		if next != null: await click(next)
		elif not f.is_empty():
			var control = UI.find_tag(main.board.canvas,f.keys()[0],f.values()[0])
			check(control is BaseButton and not control.disabled,"Guided target is clickable at %d" % t.step)
			await click(control)
		elif realtime: await create_timer(.1).timeout
		elif not g.animation.is_empty() and not t.holds_animation():
			g.advance_animation(); main.session._broadcast()
		elif t.tick(g,1000+i*1000): main.session._broadcast()
		await settle()
	check(main.session.tutorial.step==Tutorial.Step.COMPLETE,"Actual UI buttons complete the entire lesson")
	await shot("complete")
	# Same UI tree is scaled by the production viewport, including touch buttons.
	root.size = Vector2i(960,640)
	main._schedule_render(); await settle()
	await shot("compact-complete")
	await click(UI.find_tag(main,"tutorial_restart",true))
	await settle()
	check(main.session.tutorial.step==Tutorial.Step.WELCOME,"Restart button works")
	main.session.leave(); await settle()
	check(UI.find_tag(main,"tutorial_start",true)!=null,"Exit returns to lobby")
	print("TUTORIAL_UI_RESULT steps=%d failures=%d" % [visited.size(),failures])
	main.queue_free(); await process_frame
	quit(0 if failures==0 else 1)
