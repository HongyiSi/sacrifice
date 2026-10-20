extends Node
func _ready() -> void:
	if not OS.has_feature("dedicated_server") and not OS.get_cmdline_user_args().has("--server"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	var port := 7002
	var bind_address := "127.0.0.1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
		if arg.begins_with("--bind="): bind_address = arg.trim_prefix("--bind=")
	var session = load("res://scripts/session.gd").new()
	session.name = "Session"; add_child(session)
	var error: Error = session.start_dedicated(port,bind_address)
	if error != OK:
		push_error("Dedicated server failed: "+error_string(error)); get_tree().quit(1)
