extends RefCounted
## Device-local crash recovery. No private hands/deck data is sent to telemetry.
const Rules = preload("res://scripts/rules.gd")
const TTL := 30 * 60
const KEY := "sacrifice.ai.checkpoint.v1"
const MAX_BYTES := 2 * 1024 * 1024
var path := "user://ai-checkpoint"
var enabled := true
var fingerprint := ""
var cached := ""
var last_saved := 0.0
var last_attempt := 0.0
var slot := 0

func signature() -> String:
	if fingerprint.is_empty():
		# Exported builds remap scripts to compiled .gdc files.
		var rules_path := "res://scripts/rules.gd"
		var remap := ConfigFile.new()
		if FileAccess.file_exists(rules_path+".remap") and remap.load(rules_path+".remap") == OK:
			rules_path = str(remap.get_value("remap","path",rules_path))
		fingerprint = (FileAccess.get_sha256(rules_path) + FileAccess.get_sha256("res://data/cards.json") + FileAccess.get_sha256("res://data/deathrattles.json")).sha256_text()
	return fingerprint

func capture(game, details: Dictionary) -> Dictionary:
	var fields := {}
	for p in game.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.name != "rng":
			fields[p.name] = game.get(p.name)
	# A checkpoint is taken only after an action has finished, never mid-pump.
	fields.pumping = false
	var payload := {"fields":fields, "rng_seed":game.rng.seed, "rng_state":game.rng.state, "details":details}
	var graph := Graph.new()
	var root = graph.encode(payload)
	var bytes := var_to_bytes({"root":root, "nodes":graph.nodes})
	return {"format":1, "rules":signature(), "payload":Marshalls.raw_to_base64(bytes), "sha256":bytes.hex_encode().sha256_text()}

func write(game, details: Dictionary, now: float = -1.0) -> bool:
	if not enabled: return true
	cached = JSON.stringify(capture(game, details))
	return touch(now)

func touch(now: float = -1.0) -> bool:
	if not enabled or cached.is_empty(): return true
	if now < 0: now = Time.get_unix_time_from_system()
	last_attempt = now
	var envelope = JSON.parse_string(cached)
	envelope.saved_at = now
	var text := JSON.stringify(envelope)
	if text.length() > MAX_BYTES: return false
	var ok := false
	if OS.has_feature("web"):
		ok = JavaScriptBridge.eval("(()=>{try{localStorage.setItem("+JSON.stringify(KEY)+","+JSON.stringify(text)+");return true}catch(e){return false}})()", true) == true
	else:
		# Alternating slots leave a complete previous checkpoint if a write fails.
		var file := FileAccess.open(path+"-"+str(slot)+".json", FileAccess.WRITE)
		if file:
			file.store_string(text); file.flush(); ok = file.get_error() == OK
		if ok: slot = 1-slot
	if ok: last_saved = now
	return ok

func read(now: float = -1.0) -> Dictionary:
	if not enabled: return {}
	if now < 0: now = Time.get_unix_time_from_system()
	var candidates := []
	if OS.has_feature("web"):
		var text = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem("+JSON.stringify(KEY)+")||''}catch(e){return ''}})()", true)
		if text is String: candidates.append(text)
	else:
		for i in range(2):
			var file := FileAccess.open(path+"-"+str(i)+".json", FileAccess.READ)
			if file and file.get_length() <= MAX_BYTES: candidates.append(file.get_as_text())
	var result := {}
	for text in candidates:
		var value := decode(text, now)
		if not value.is_empty() and float(value.saved_at) > float(result.get("saved_at", 0)):
			result = value
	if result.is_empty(): clear()
	return result

func decode(text: String, now: float) -> Dictionary:
	if text.is_empty() or text.length() > MAX_BYTES: return {}
	var envelope = JSON.parse_string(text)
	if not envelope is Dictionary or envelope.get("format") != 1 or envelope.get("rules") != signature(): return {}
	var saved := float(envelope.get("saved_at",0))
	if saved <= 0 or now-saved >= TTL or saved-now > 60: return {}
	if not envelope.get("payload") is String or not envelope.get("sha256") is String: return {}
	var bytes := Marshalls.base64_to_raw(envelope.payload)
	if bytes.is_empty() or bytes.hex_encode().sha256_text() != envelope.sha256: return {}
	var packed = bytes_to_var(bytes) # Never deserialize Objects/scripts from storage.
	if not packed is Dictionary or not packed.get("nodes") is Array: return {}
	var graph := Graph.new()
	var value = graph.decode(packed)
	if not value is Dictionary or not value.get("fields") is Dictionary or not value.get("details") is Dictionary: return {}
	var g := Rules.new()
	var fields: Dictionary = value.fields
	var expected := 0
	for p in g.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or p.name == "rng": continue
		expected += 1
		if not fields.has(p.name) or typeof(fields[p.name]) != typeof(g.get(p.name)): return {}
	if fields.size() != expected or fields.characters.size() != 6 or fields.plans.size() != 2: return {}
	if not value.get("rng_seed") is int or not value.get("rng_state") is int: return {}
	for key in fields: g.set(key, fields[key])
	g.rng.seed = value.rng_seed; g.rng.state = value.rng_state
	return {"game":g, "details":value.details, "saved_at":saved}

func clear() -> void:
	cached = ""; last_saved = 0.0; last_attempt = 0.0
	if not enabled: return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(()=>{try{localStorage.removeItem("+JSON.stringify(KEY)+")}catch(e){}})()", true)
	else:
		for i in range(2):
			var file := path+"-"+str(i)+".json"
			if FileAccess.file_exists(file): DirAccess.remove_absolute(file)

class Graph extends RefCounted:
	# Jobs, requests and queues share mutable dictionaries. Plain JSON or
	# duplicate(true) loses those aliases and can repeat/skip effects on resume.
	var originals := []
	var nodes := []
	var decoded := []
	var valid := true
	func encode(value):
		if not (value is Array or value is Dictionary): return value
		for i in range(originals.size()):
			if is_same(value, originals[i]): return {"ref":i}
		var index := originals.size()
		originals.append(value)
		var node := {"type":"dict" if value is Dictionary else "array", "items":[]}
		nodes.append(node)
		if value is Dictionary:
			for key in value: node.items.append([encode(key), encode(value[key])])
		else:
			for item in value: node.items.append(encode(item))
		return {"ref":index}
	func decode(packed):
		if packed.nodes.size() > 10000: return null
		for node in packed.nodes:
			if not node is Dictionary or not node.get("items") is Array or node.get("type") not in ["dict","array"]: return null
			decoded.append({} if node.type == "dict" else [])
		for i in range(packed.nodes.size()):
			var node = packed.nodes[i]
			for item in node.items:
				if node.type == "dict":
					if not item is Array or item.size() != 2: return null
					decoded[i][resolve(item[0])] = resolve(item[1])
				else: decoded[i].append(resolve(item))
		var result = resolve(packed.get("root"))
		return result if valid else null
	func resolve(value):
		if value is Dictionary:
			if value.size() != 1 or not value.get("ref") is int or value.ref < 0 or value.ref >= decoded.size():
				valid = false; return null
			return decoded[value.ref]
		return value
