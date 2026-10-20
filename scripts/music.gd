extends Node
## Local playback is independent of snapshots and changes only on scene context.
signal result_played(outcome: String)
const TRACKS := ["res://assets/music/old_tower_inn_loop.wav", "res://assets/music/woodland_fantasy.mp3"]
const RESULT_TRACKS := {"victory":"res://assets/sfx/game/victory.wav","defeat":"res://assets/sfx/game/defeat.wav"}
var player := AudioStreamPlayer.new()
var result_player := AudioStreamPlayer.new()
var result_streams: Dictionary = {}
var result_key := ""
var result_pending := ""
const DEFAULT_LEVEL := 0.5
var level := DEFAULT_LEVEL
var context := -1
var streams: Dictionary = {}
var transition: Tween
var settings_path := ""
var web_started := false
var web_poll := 0.0

func _ready() -> void:
	var config := ConfigFile.new()
	var folder := "res://local-data" if OS.has_feature("editor") else "user://"
	DirAccess.make_dir_recursive_absolute(folder)
	settings_path = folder.path_join("music.cfg")
	if config.load(settings_path) == OK: level = clampf(float(config.get_value("music","volume",DEFAULT_LEVEL)),0,1)
	add_child(player)
	player.volume_db = -80
	add_child(result_player)
	for key in RESULT_TRACKS:
		var stream: AudioStreamWAV = load(RESULT_TRACKS[key])
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		result_streams[key] = stream
	result_player.volume_db = _target_db()

func sync_view(view: Dictionary, team: int) -> void:
	if view.get("phase","") != "ended":
		set_context(not view.is_empty())
		return
	var key := "%s/%s/%s" % [view.match,view.winner,team]
	if key == result_key: return
	result_key = key
	context = 2 # A late lobby/battle download cannot replace the result music.
	if transition != null: transition.kill()
	player.stop()
	if OS.has_feature("web"): JavaScriptBridge.eval("window.sacrificeMusic?.setContext(-1)",true)
	result_player.stop()
	result_pending = "" if view.winner == -1 else "victory" if view.winner == team else "defeat"
	_play_result()

func _play_result() -> void:
	if result_pending.is_empty() or (OS.has_feature("web") and not web_started): return
	var outcome := result_pending
	result_pending = ""
	result_player.stream = result_streams[outcome]
	result_player.volume_db = _target_db()
	result_player.play()
	result_played.emit(outcome)

func set_context(in_match: bool) -> void:
	if not result_key.is_empty():
		result_player.stop()
		result_key = "";result_pending = ""
	var next := 1 if in_match else 0
	if next == context: return
	context = next
	if OS.has_feature("web"):
		_web_context(next)
		return
	_load_local_track(next)

func _load_local_track(next: int) -> void:
	if transition != null: transition.kill()
	if not streams.has(next):
		var path: String = TRACKS[next]
		var stream: AudioStream
		if next == 0:
			var wav: AudioStreamWAV = load(path) if ResourceLoader.exists(path) else AudioStreamWAV.load_from_file(path)
			if wav != null:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(round(wav.get_length()*wav.mix_rate))
			stream = wav
		else:
			var mp3: AudioStreamMP3 = load(path) if ResourceLoader.exists(path) else AudioStreamMP3.load_from_file(path)
			if mp3 == null: return
			mp3.loop = true
			stream = mp3
		if stream == null: return
		streams[next] = stream
	_play_track(next)

func _play_track(next: int) -> void:
	# A slow request for the lobby must never replace battle music after joining.
	if next != context or not streams.has(next): return
	if player.stream == streams[next] and player.playing: return
	if transition != null: transition.kill()
	transition = create_tween()
	transition.tween_property(player,"volume_db",-80.0,0.25 if player.playing else 0.0)
	transition.tween_callback(func():
		player.stream=streams[next]
		player.play()
		if OS.has_feature("web"): print("SACRIFICE_MUSIC_PLAYING track=",next)
	)
	transition.tween_property(player,"volume_db",_target_db(),0.45)

func _web_context(next: int) -> void:
	JavaScriptBridge.eval("window.sacrificeMusic?.setContext(%d);window.sacrificeMusic?.setLevel(%f)" % [next,level],true)

func _target_db() -> float:
	return linear_to_db(level) if level > 0 else -80.0

func _apply_volume() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.sacrificeMusic?.setLevel(%f)" % level,true)
	# Keep transition's track switch, but apply the user-selected volume immediately.
	player.volume_db = _target_db()
	result_player.volume_db = _target_db()

func _process(delta: float) -> void:
	if OS.has_feature("web") and not web_started:
		web_poll += delta
		if web_poll >= 0.25:
			web_poll = 0.0
			web_started = bool(JavaScriptBridge.eval("window.sacrificeReady === true",true))
			if web_started:
				if context in [0,1]: _web_context(context)
				_play_result()
	if level == 0: player.volume_db = -80
	elif transition == null or not transition.is_running(): player.volume_db = _target_db()
	result_player.volume_db = _target_db()

func set_level(value: float) -> void:
	level = clampf(value,0,1)
	_apply_volume()
	var config := ConfigFile.new()
	config.set_value("music","volume",level)
	config.save(settings_path)
