extends "res://tests/v0174_ui_test.gd"
const Cases=preload("res://tests/v011_scenarios.gd")
const Card=preload("res://scripts/card_widget.gd")
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/arrival-endgame-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.level=0;main.attack_audio.level=0;main.session.set_process(false)
	for key in ["gift","poisoning","obstruct","search","ruby","topaz","curse","heart"]:
		for viewer in [0,1]:
			var g=Cases.setup(key,key in ["curse","heart"],true);serial+=1;g.match_id=serial
			for i in range(180):
				if g.animation.is_empty() and g.phase in ["planning","review","ended"]:break
				var pending:Dictionary=g._pending_hand_arrivals()
				if not pending.is_empty():
					await show_game(g,viewer)
					for target in pending:
						var fan=meta(main,"hand_actor" if target/3==viewer else "enemy_hand_actor",target)
						var count:int=g.characters[target].hand.size()-pending[target].size()
						check(fan.get_children().filter(func(c):return c is Card).size()==count,"no early card widgets in preceding impact")
						check(main.board.view.characters[target].hand_count==count,"no early hand count")
					if key=="obstruct":await capture("before-flight-%d"%viewer)
				if g.animation.get("kind","")=="draw_cards":
					await show_game(g,viewer)
					var fx=meta(main,"draw_animation",g.animation.id)
					for t in [0.0,.5,1.0]:
						fx.clock_started=-1;fx.set_process(false);fx.elapsed=t*g.animation.travel_ms/1000.0;fx._process(0)
						for f in fx.flights:
							if t==0 and g.animation.stage=="travel":check(not f.landed and f.node.get_meta("flying",false),"incoming card belongs to flight from first frame")
							if t==1:check(f.landed,"card settles after flying")
						if key=="obstruct":await capture("flight-%d-%d"%[viewer,int(t*100)])
				elif g.animation.get("kind","")=="hand_transfer":
					await show_game(g,viewer)
					var fx=meta(main,"hand_transfer_animation",g.animation.id)
					if fx.accepted:check(fx.incoming!=null and not fx.incoming.visible,"whole transfer hides destination card throughout flight")
				check(Cases.step(g)=="","effect progresses "+key)
	# The same final panel must fit every label at all supported window sizes.
	for size_value in [Vector2i(1440,960),Vector2i(960,640),Vector2i(1920,1080)]:
		root.size=size_value
		for viewer in [0,1]:
			var g=H.fixture();serial+=1;g.match_id=serial;g.phase="ended";g.winner=0;g.win_reason="徽章"
			await show_game(g,viewer)
			var panel=meta(main,"match_result_panel",true)
			check(panel!=null and panel.size.x<300 and panel.size.y<=130,"compact content-sized result panel")
			for tag in ["match_result_title","match_result_reason"]:
				var label:Label=meta(main,tag,true)
				var font:Font=label.get_theme_font("font")
				check(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x+.1,"full text fits "+tag)
			var button=meta(main,"rematch_button",true)
			check(button.position.y+button.size.y<=panel.size.y-10,"rematch button fits inside panel")
			if size_value==Vector2i(1440,960):await capture("result-%d"%viewer)
	print("ARRIVAL_ENDGAME_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
