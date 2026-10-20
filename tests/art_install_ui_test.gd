extends "res://tests/v0203_ui_test.gd"
const Scenarios=preload("res://tests/art_scenarios.gd")
const Art=preload("res://scripts/cinema/atlas.gd")
const Priority=preload("res://scripts/art_ui/priority_style.gd")
const Chrome=preload("res://scripts/art_ui/ui_chrome.gd")
var rendered=0

func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/art-install-"+name+".png")

func text_button(node,value):
	if node is Button and node.text==value:return node
	for child in node.get_children():
		var found=text_button(child,value)
		if found!=null:return found
	return null

func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume()
	await shot("lobby")
	text_button(main,"规则").pressed.emit();await frames()
	check(main.tooltip_dialog.visible,"lobby rules button opens real dialog")
	var tab=meta(main.tooltip_dialog,"rules_tab",3);tab.pressed.emit();await frames()
	check(meta(main.tooltip_dialog,"rules_body",true).text.contains("亡语阶段"),"rules directory keeps latest live rules")
	await shot("rules");main.tooltip_dialog.hide()
	text_button(main,"音乐").pressed.emit();await frames()
	check(main.music_dialog.visible,"lobby music button opens real controls")
	var slider=meta(main.music_dialog,"sound_volume",true);slider.value=37
	check(is_equal_approx(main.attack_audio.level,.37),"styled slider changes real sound level")
	await shot("music");slider.value=0;main.music_dialog.hide()
	root.size=Vector2i(960,640);await frames();await shot("lobby-small")
	root.size=Vector2i(1440,960);await frames()
	var g=H.fixture(8);serial+=1;g.match_id=serial
	for id in range(6):
		var keys=[["double_strike","heal","defense","magic_strike","godslayer","quick_strike","badge","prophecy"],["collect","gambler","mirror","suppress","ignore","team_heal","triple_strike","bounty"],["glory","heal_other","area_strike","holy_strike","collect","final_strike","plunder","frenzy"],["strike","defense","heal","poisoning","search","overload","hasty_spell","holy_amulet"],["strike","defense","heal","heal_other","ruby","emerald","sapphire","gift"],["strike","defense","attack_amulet","magic_amulet","gold_panning","warcry","rally","amber"]][id]
		for key in keys:H.give(g,id,key)
		H.give_death(g,id,["privilege","heart","legacy","ghost","prison","divinity"][id])
	main.session.game=g;await show_game(g)
	await move_mouse(Vector2(20,700));await shot("board")
	for rank in range(11):
		check(Priority.group_for({"main":rank})==({10:0,9:1,8:1,7:1,2:2,1:2,0:3}.get(rank,-1)),"priority colour group "+str(rank))
	check(Priority.group_for({"priority":10},true)==-1,"death cards keep plum frame")
	check(Priority.group_for({"main":10},false,true)==-1,"hidden card has no priority leakage")
	g.characters[0].max_hp=48;g.characters[0].hp=37
	await show_game(g)
	var health=meta(main,"health_actor",0)
	check(health.get_child_count()==3,"large health total uses readable compact display")
	# Exercise seven simultaneous statuses, including dormant and future effects.
	main.session.state.characters[0].ongoing_effects=[]
	for key in ["defense","prophecy","overload","ghost","heart","rally","divinity"]:
		main.session.state.characters[0].ongoing_effects.append({"key":key,"count":2,"waiting":key=="overload","dormant":key=="divinity"})
	main._render();await frames()
	var rack=meta(main,"status_actor",0)
	check(rack.statuses.size()==7 and rack.get_child_count()==3,"status stack preserves all seven effects with overflow indicator")
	rack.get_child(2).pressed.emit();await frames()
	check(main.death_dialog.dialog_text.contains("神化") and main.death_dialog.dialog_text.contains("下回合"),"status detail includes hidden overflow and timing")
	main.death_dialog.hide();await shot("dense-state")
	var normal=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	var deaths=JSON.parse_string(FileAccess.get_file_as_string("res://data/deathrattles.json"))
	var all=normal+deaths+[{"key":"boulder"},{"key":"poison"}]
	for row in all:
		check(Art.supports(row.key),"approved illustration present: "+row.key)
		serial+=1;var pair=Scenarios.setup(row.key,serial);g=pair[0];var context=pair[1];main.session.game=g
		var complete=false
		for step in range(300):
			if not g.animation.is_empty():
				await show_game(g,serial%2)
				var fx=meta(main,"cinema_effect",g.animation.id)
				if fx!=null:
					rendered+=1
					var started=fx.clock_started
					check(fx.is_processing(),"live effect advances: "+row.key)
					fx.clock_started=Time.get_ticks_msec()-120;fx._process(0)
					check(fx.elapsed>=.12,"real clock advances effect")
					if row.key in ["double_strike","godslayer","prophecy","ghost","magic_strike"] and g.animation.stage=="impact":
						fx.set_process(false);fx.present(.11);await shot(row.key)
					main.effect_started=started;main._render();await frames()
					fx=meta(main,"cinema_effect",g.animation.id)
					check(fx.clock_started==started,"UI rebuild preserves effect clock")
					fx.set_process(false);fx.present(fx.duration*.46);await process_frame
					fx.present(fx.duration*.87);await process_frame
			var error=Scenarios.step(g,context)
			if error=="done":complete=true;break
			if not error.is_empty():check(false,row.key+": "+error);break
		check(complete,"real card resolves to completion: "+row.key)
		print("ART_CARD ",row.key," animations=",rendered)
	print("ART_INSTALL_UI_RESULT checks=%d failures=%d cards=%d animations=%d"%[checks,failures,all.size(),rendered])
	main.queue_free();await frames();quit(0 if failures==0 else 1)
