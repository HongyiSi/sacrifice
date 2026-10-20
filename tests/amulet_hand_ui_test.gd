extends "res://tests/v0174_ui_test.gd"
const Cases=preload("res://tests/amulet_hand_scenarios.gd")
const Card=preload("res://scripts/card_widget.gd")
const Layout=preload("res://scripts/board_layout.gd")
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/amulet-hand-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for holder in range(6):
		for key in ["holy_amulet","attack_amulet","magic_amulet"]:
			serial+=1;var g=Cases.setup(key,holder,serial)
			var guard:int=g.request.options[0];g.respond(holder/3,guard)
			for stage in ["travel","impact","discard"]:
				check(g.animation.stage==stage,"expected hand response stage")
				for viewer in [0,1]:
					await show_game(g,viewer)
					check(meta(main,"played_action_id",g.animation.action.id)==null,"responding amulet never occupies played area")
					var fx=await pose(g,.55)
					var friendly:bool=holder/3==viewer
					var fan=meta(main,"hand_actor" if friendly else "enemy_hand_actor",holder)
					check(fan.get_children().filter(func(c):return c is Card).size()==(7 if stage=="discard" else 8),"real hand count correct at stage boundary")
					if stage!="discard":
						check(fx.amulet_effect!=null and fx.source_widget.get_parent()==fan,"beam originates from real hand card")
						check(fx.source_widget.position.is_equal_approx(Layout.hand_slot(fx.slot,friendly)),"amulet card stays in original hand slot")
						check(not fx.source_widget.hidden_card and fx.source_widget.card.id==guard,"only accepted amulet face shown")
						check(fx.source_widget.resolution_started<0,"hand card never rises into settlement area")
						check(fx.source_widget.motif_alpha==0,"printed motif replaced by exactly one animated emblem")
						if not friendly:
							check(fan.get_children().filter(func(c):return c is Card and c.hidden_card).size()==7,"other seven opponent cards stay hidden")
					else:
						check(fx.ghost!=null and fx.amulet_effect==null,"discard shows one amulet without replaying beam")
						check(not fx.ghost.hidden_card and fx.ghost.card.id==guard,"used amulet remains public while discarded")
						check(fx.reflow.size()==7-fx.slot,"remaining cards hold gap until departure")
						fx=await pose(g,1)
						check(fx.ghost.modulate.a==0,"discarded amulet fully disappears")
						check(g.characters[holder].hand.size()==7,"final hand count matches visible cards")
						for item in fx.reflow:check(item.node.position.is_equal_approx(item.after),"remaining hand closes gap")
					if holder==0:
						await pose(g,.55);await capture(key+"-"+stage+"-"+str(viewer))
					if holder==1 and key=="holy_amulet" and viewer==1 and stage=="travel":
						var started:int=Time.get_ticks_msec()-550;main.effect_started=started
						root.size=Vector2i(960,640);main._schedule_render();await frames()
						fx=meta(main,"effect_animation",g.animation.id)
						check(fx.clock_started==started and fx.elapsed>=.55,"resize preserves hand effect clock")
						await capture("small-opponent");root.size=Vector2i(1440,960);await frames()
				g.advance_animation()
	# Interrupting a hand effect must restore an opponent's ordinary face-down hand.
	var g=Cases.setup("holy_amulet",3,8900,true);g.respond(1,g.request.options[0])
	await show_game(g,0);var fx=await pose(g,.6);var hand_card=fx.source_widget
	fx.queue_free();await frames()
	check(hand_card.hidden_card and hand_card.card.is_empty() and hand_card.motif_alpha==1,"interruption restores original hidden hand widget")
	g.advance_animation();g.advance_animation();await show_game(g,1)
	check(g.characters[3].hand.size()==8,"defiled amulet remains in hand after completed effect")
	print("AMULET_HAND_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
