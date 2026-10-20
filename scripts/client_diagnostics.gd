extends Node
## Small, bounded metrics only. Never export hands, nicknames or action payloads.
var session: Node
var elapsed := 0.0
func _process(delta: float) -> void:
	if not OS.has_feature("web") or session == null: return
	elapsed += delta
	if elapsed < 5.0: return
	elapsed = 0.0
	var values := {
		"static_bytes":OS.get_static_memory_usage(),
		"static_peak":OS.get_static_memory_peak_usage(),
		"texture_bytes":int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"fps":Engine.get_frames_per_second(),
		"queued_views":session.received_views.size(),
		"texture_format":"s3tc" if OS.has_feature("s3tc") else "etc2" if OS.has_feature("etc2") else "uncompressed",
	}
	JavaScriptBridge.eval("window.sacrificeNativeMetrics="+JSON.stringify(values),true)
