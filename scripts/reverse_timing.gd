extends RefCounted
## Shared authoritative presentation boundaries and client choreography.
const TRAVEL_MS := 2700
const IMPACT_MS := 3700
const RESTORE_MS := 3000
const ROTATE_START := 1.50
const ROTATE_END := 2.50
const DYE_START := 2.70
const DYE_END := 5.60

static func age(event: Dictionary, elapsed: float) -> float:
	return elapsed + (TRAVEL_MS/1000.0 if event.get("stage","") == "impact" else 0.0)

static func is_reverse(event: Dictionary) -> bool:
	return event.get("kind","") == "card_effect" and event.get("op","") == "reverse"

static func restore_event() -> Dictionary:
	return {"kind":"reverse_restore","style":"reverse","source_key":"reverse","stage":"travel","action":{},"targets":[],
		"travel_ms":RESTORE_MS,"impact_ms":0,"caption":"回合结束 · 桌布恢复"}
