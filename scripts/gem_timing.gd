extends RefCounted
const COLORS={"ruby":"f14a68","amber":"ffa338","sapphire":"4abffc","amethyst":"bf85ff","topaz":"f8d05a","emerald":"5ee3a5"}
static func age(event:Dictionary,seconds:float)->float:
	if event.has("gem_overlay"):
		return event.gem_offset_ms/1000.0+seconds+(event.travel_ms/1000.0 if event.stage=="impact" else 0.0)
	match event.get("stage",""):
		"impact":return event.travel_ms/1000.0+seconds
		"return":return (event.travel_ms+event.impact_ms)/1000.0+seconds
		"discard":return 3.5+seconds
	return seconds
