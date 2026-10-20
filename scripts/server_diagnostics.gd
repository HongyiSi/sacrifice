extends RefCounted
## Structured journal entries. Do not print private hands or intent payloads.
static func write(event: String, values: Dictionary = {}) -> void:
	var row := values.duplicate()
	row.event = event; row.time = Time.get_datetime_string_from_system(true)
	print("SACRIFICE_DIAGNOSTIC " + JSON.stringify(row))

static func state(room: Dictionary) -> Dictionary:
	var g = room.game
	if g == null: return {"phase":"waiting"}
	var a: Dictionary = g.animation
	return {"phase":g.phase,"round":g.round_number,"match":g.match_id,"revision":g.revision,
		"animation":{"id":a.get("id",0),"kind":a.get("kind",""),"stage":a.get("stage",""),"style":a.get("style","")}}
