extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var original_lobby = load("res://assets/music/old_tower_inn_loop.wav")
	var web_lobby = load("res://build/web/music-lobby.res")
	var original_battle = load("res://assets/music/woodland_fantasy.mp3")
	var web_battle = load("res://build/web/music-battle.res")
	assert(web_lobby is AudioStreamWAV)
	assert(web_lobby.data == original_lobby.data)
	assert(web_lobby.mix_rate == original_lobby.mix_rate)
	assert(is_equal_approx(web_lobby.get_length(),original_lobby.get_length()))
	assert(web_battle is AudioStreamMP3)
	assert(web_battle.data == original_battle.data)
	assert(web_battle.data == FileAccess.get_file_as_bytes("res://assets/music/woodland_fantasy.mp3"))
	assert(web_battle.get_length() > 140)
	var music = load("res://scripts/music.gd").new()
	root.add_child(music)
	music.set_context(false)
	await create_timer(0.8).timeout
	assert(music.player.playing and music.player.stream is AudioStreamWAV)
	music.set_context(true)
	await create_timer(0.8).timeout
	assert(music.player.playing and music.player.stream is AudioStreamMP3 and music.player.stream.loop)
	music.level = 0
	music._apply_volume()
	await process_frame
	assert(music.player.volume_db <= -79)
	music.set_context(false)
	await create_timer(0.8).timeout
	assert(music.player.stream is AudioStreamWAV)
	assert(music.player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	print("V0162_MUSIC_OK web_resources_original=true native_contexts=true loops=true mute=true")
	quit()
