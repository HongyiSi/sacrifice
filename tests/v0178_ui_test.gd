extends "res://tests/v0174_ui_test.gd"
const Banner=preload("res://scripts/phase_banner.gd")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0178_UI_FAIL "+label)
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0178-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960);main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.4).timeout
	main.music.settings_path="res://test-results/v0178-music.cfg"
	main.music.set_level(.35);await create_timer(.6).timeout
	var stream=main.music.player.stream
	for dialog in [main.music_dialog,main.tooltip_dialog,main.battle_dialog]:
		var before:float=main.music.player.get_playback_position()
		dialog.popup_centered(Vector2i(720,400));root.focus_exited.emit();await create_timer(.4).timeout
		check(main.music.player.playing and main.music.player.stream==stream,"popup does not stop or replace music")
		check(main.music.player.get_playback_position()>before+.15,"music timeline continues in popup")
		check(absf(main.music.player.volume_db-linear_to_db(.35))<.1,"focus loss never mutes")
		dialog.hide();root.focus_entered.emit()
	main.music.set_level(0);await frames();check(main.music.player.volume_db<=-79 and main.music.player.playing,"manual mute keeps timeline")
	main.music.set_level(.22);await frames();check(absf(main.music.player.volume_db-linear_to_db(.22))<.1,"manual volume works")
	var g=H.Rules.new();g.start(178);await show_game(g)
	var cue=meta(main,"phase_banner",true);cue.set_process(false);cue.started=Time.get_ticks_msec()-240;cue._process(0)
	check(cue.pop_title and cue.pop_detail,"new round emphasizes changed text")
	check(absf(meta(main,"phase_title",true).scale.x-1.28)<.02,"stage text visibly enlarged")
	await shot("stage-pop")
	cue.started=Time.get_ticks_msec()-900;cue._process(0)
	check(meta(main,"phase_title",true).scale==Vector2.ONE,"title returns exactly to original size")
	g.turn_stage="resolution";g.stage_main=7;await show_game(g);var started:int=main.phase_banner_started
	main._schedule_render();await frames();check(main.phase_banner_started==started,"redraw retains pulse timestamp")
	g.stage_main=6;await show_game(g);cue=meta(main,"phase_banner",true)
	check(not cue.pop_title and cue.pop_detail,"rank-only change pulses only changing line")
	cue.set_process(false);cue.started=Time.get_ticks_msec()-240;cue._process(0)
	check(meta(main,"phase_title",true).scale==Vector2.ONE and meta(main,"phase_label",true).scale.x>1.27,"rank pulse leaves phase title steady")
	await shot("priority-pop")
	g=H.fixture(8);g.presentation_enabled=true;H.begin(g,{0:H.give(g,0,"ignore")},false);g.choose(0,5);await show_game(g)
	check(main.session.state.input.description.contains("已选 5") and not main.session.state.input.options.has(5),"second choice explains already selected number")
	g.choose(0,6);await show_game(g);var fx=await pose(g,.85)
	check(fx.event.values==[5,6],"both ticks reach animation")
	await shot("ignore-two")
	print("V0178_UI_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
