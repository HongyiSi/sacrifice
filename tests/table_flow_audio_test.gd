extends SceneTree
var failed:=false
func _initialize()->void:
	_run.call_deferred()
func _run()->void:
	var music=preload("res://scripts/music.gd").new()
	var sound=preload("res://scripts/attack_audio.gd").new()
	root.add_child(music);root.add_child(sound)
	var expected_music:=.5;var expected_sound:=.5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--music="):expected_music=arg.trim_prefix("--music=").to_float()
		if arg.begins_with("--sound="):expected_sound=arg.trim_prefix("--sound=").to_float()
	failed=not is_equal_approx(music.level,expected_music) or not is_equal_approx(sound.level,expected_sound)
	print("TABLE_FLOW_AUDIO_RESULT music=%s sound=%s ok=%s"%[music.level,sound.level,not failed])
	music.queue_free();sound.queue_free();quit(1 if failed else 0)
