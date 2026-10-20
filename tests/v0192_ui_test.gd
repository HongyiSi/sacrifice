extends "res://tests/v0174_ui_test.gd"
const G=preload("res://tests/gambler_scenarios.gd")
const Card=preload("res://scripts/card_widget.gd")
const Die=preload("res://scripts/gambler_die_art.gd")
const Symbols=preload("res://scripts/art_symbols.gd")
const Palette=preload("res://scripts/card_palette.gd")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0192_UI_FAIL "+label)
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0192-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	check(Symbols.icon("gambler",Palette.ink("gambler"))==Die.texture(Palette.ink("gambler")),"card uses approved shared die art")
	check(Symbols.icon("frenzy",Palette.ink("gambler"))!=Die.texture(Palette.ink("gambler")),"other dice card keeps original icon")
	for actor in range(6):
		var g=G.setup(actor,19400+actor,true);check(G.seek(g),"gambler fixture")
		for viewer in [0,1]:
			await show_game(g,viewer)
			for t in [0.0,.14,.3,.5,.64,.7,.8,1.0]:
				var fx=await pose(g,t)
				check(fx.card_effect.gambler_dice!=null and fx.launch_effect.book.gambler_dice!=null,"dedicated die motion connected")
				check(fx.source_widget.motif_alpha==0,"printed emblem hidden during flight")
				check(fx.outgoing_cards.size()==3,"only three discarded cards fade")
				if t<.69:
					for item in fx.outgoing_cards:check(is_equal_approx(item.node.modulate.a,item.alpha),"old hand stays through dice roll")
				if t==1:
					for item in fx.outgoing_cards:check(item.node.modulate.a==0,"discarded hand leaves after roll")
				if actor/3==viewer:
					var hand=meta(main,"hand_actor",actor)
					for c in hand.get_children():
						if c is Card and (not c.card.get("discardable",true) or c.card.get("key","")=="curse"):
							check(c.modulate.a==1,"non-discardable card never fades")
				if actor==0 and viewer==0 and t==.3:await shot("gambler-roll")
			var fx=await pose(g,.4)
			var started:int=Time.get_ticks_msec()-880
			main.effect_started=started;fx.clock_started=started
			main._schedule_render();await frames()
			fx=meta(main,"effect_animation",g.animation.id)
			check(fx.clock_started==started and fx.elapsed>.8,"UI refresh resumes dice progress")
			if actor==0 and viewer==0:
				root.size=Vector2i(960,640);main._schedule_render();await frames();fx=await pose(g,.3)
				check(fx.card_effect.gambler_dice!=null,"resize retains rolling die")
				await shot("gambler-small");root.size=Vector2i(1440,960);await frames()
			fx=await pose(g,.8);var source=fx.source_widget;var outgoing:Array=fx.outgoing_cards.duplicate()
			fx.queue_free();await frames()
			check(source.motif_alpha==1,"interrupted effect restores printed die")
			for item in outgoing:check(item.node.modulate.a==item.alpha,"interruption restores hand display")
		g.advance_animation()
		await show_game(g,actor/3);var impact=await pose(g,1)
		check(impact.source_widget.motif_alpha==1,"impact restores original shared die")
		check(G.drain(g),"gameplay finishes after visual")
	print("V0192_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
