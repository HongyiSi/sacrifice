extends "res://tests/gem_ui_test.gd"
var output_dir:=""
var frame:=0
func capture()->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output_dir+"/frame-%05d.jpg"%frame,.96)
	frame+=1
func _run()->void:
	output_dir=ProjectSettings.globalize_path("res://../work/gem-heal/frames")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	var layer:=CanvasLayer.new();layer.layer=90;root.add_child(layer)
	var heading:=Label.new();heading.position=Vector2(430,877);heading.size=Vector2(580,44);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",24);heading.add_theme_color_override("font_color",Color("f5e6c8"));heading.add_theme_color_override("font_shadow_color",Color("312632"));heading.add_theme_constant_override("shadow_offset_x",2);heading.add_theme_constant_override("shadow_offset_y",2);layer.add_child(heading)
	for key in ["ruby","amethyst"]:
		for actor in [0,3]:
			var g=G.setup(key,actor,300000+frame);check(G.seek(g),"demo reaches gem")
			heading.text={"sapphire":"蓝宝石","ruby":"红宝石","amethyst":"紫宝石"}[key]+(" · 我方手牌" if actor==0 else " · 对方手牌")
			var event_id:int=g.animation.id
			while G.supports(g.animation) and g.animation.id==event_id:
				await show_game(g,0)
				var count:int=roundi(Styles.duration(g.animation)/1000.0*60)
				for i in range(count):
					await pose(g,i/float(count-1));await capture()
					if g.animation.stage=="impact" and i==count/2:await shot(key+"-%d-heal-final"%actor)
				g.advance_animation()
			for i in range(21):await capture()
	print("GEM_DEMO_RESULT frames=%d checks=%d failures=%d"%[frame,checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
