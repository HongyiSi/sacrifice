extends "res://tests/v0174_ui_test.gd"
const S=preload("res://tests/reveal_scenarios.gd")
const Flip=preload("res://scripts/card_reveal.gd")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0183_REVEAL_UI_FAIL "+label)
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0183-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for viewer in [0,1]:
		for actor in range(6):
			serial+=1;var g=S.setup([actor],serial)
			await show_game(g,viewer)
			check(S.seek(g),"real game reaches flip")
			await show_game(g,viewer)
			var id:int=g.animation.actions[0]
			var fx=meta(main,"card_reveal_action",id)
			check(fx!=null,"real card uses reveal renderer")
			if fx==null:continue
			var card=fx.source;var origin:Vector2=card.position;var original_scale:Vector2=card.scale
			var started:int=fx.started_ms
			fx.set_process(false)
			check(fx.initial_hidden,"all viewers reveal a face-down card")
			check(not card.visible and card.status_label.text=="翻开中","one displayed card, with reveal caption")
			check(fx.front_view.get_child(0).card==card.card,"actual card face preserves rank and appearance")
			for t in [0.0,.24,.38,.48,.6,.88,1.0]:
				fx.set_progress(t)
				var points:PackedVector2Array=fx.pose().points
				var bounds:=Rect2(points[0],Vector2.ZERO)
				for p in points:bounds=bounds.expand(p)
				bounds=fx.get_global_transform()*bounds
				for pawn in range(6):check(not bounds.intersects(meta(main,"health_actor",pawn).get_global_rect()),"turn avoids health")
			fx.set_progress(.38)
			main._schedule_render();await frames()
			fx=meta(main,"card_reveal_action",id)
			check(fx!=null and fx.started_ms==started,"UI rebuild resumes original clock")
			if fx!=null:
				if actor==0:
					fx.set_process(false);fx.set_progress(.38)
					await shot("turn-view-"+str(viewer))
				card=fx.source;fx.started_ms=Time.get_ticks_msec()-681;fx._process(0);await frames()
				check(card.visible and card.self_modulate==Color.WHITE,"completed flip restores clear face")
				check(card.position==origin and card.scale==original_scale,"completed flip stays in exact slot")
			g.advance_animation();await show_game(g,viewer)
			check(meta(main,"card_reveal_action",id)==null,"following effect has no remaining flip overlay")
	# Two cards share a single reveal clock, including window resizing.
	serial+=1;var g=S.setup([0,3],serial);check(S.seek(g),"same-group fixture")
	await show_game(g)
	var ids:Array=g.animation.actions
	var first=meta(main,"card_reveal_action",ids[0]);var second=meta(main,"card_reveal_action",ids[1])
	check(first!=null and second!=null and first.started_ms==second.started_ms,"simultaneous flip shares one start")
	root.size=Vector2i(960,640);main._schedule_render();await frames()
	first=meta(main,"card_reveal_action",ids[0]);second=meta(main,"card_reveal_action",ids[1])
	check(first!=null and second!=null,"resize retains both physical cards")
	if first!=null:first.set_process(false);first.set_progress(.6)
	if second!=null:second.set_process(false);second.set_progress(.6)
	await shot("both-small")
	# Mid-flip interruption cannot leave an invisible card behind.
	var source=first.source;first.queue_free();await frames()
	check(source.visible and source.status_label.text=="已翻开","interruption restores source and caption")
	main.session.leave();await frames()
	check(main.reveal_times.is_empty(),"leaving clears all reveal clocks")
	print("V0183_REVEAL_UI_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
