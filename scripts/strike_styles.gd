extends RefCounted
## Presentation timings and motifs only; damage amounts remain owned by Rules.
const PROFILES := {
	"precise_strike":{"travel_ms":764,"impact_ms":600,"color":"84d5c8","caption":"双目标精准斩击"},
	# Basic blades retain the latest 1.2x speed increase. The four new weapon
	# motifs use their approved 764 ms lift/aim/flight demo. One rules hit each.
	"strike":{"travel_ms":764,"impact_ms":514,"color":"f2c78a","caption":"剑锋斩击"},
	"double_strike":{"travel_ms":764,"impact_ms":556,"color":"f5b465","caption":"双刃交错"},
	"triple_strike":{"travel_ms":764,"impact_ms":598,"color":"f17e51","caption":"三道连斩"},
	"final_strike":{"travel_ms":764,"impact_ms":650,"color":"eb858d","caption":"终末打击"},
	"quick_strike":{"travel_ms":500,"impact_ms":400,"color":"88e6ef","caption":"疾速突刺"},
	"area_strike":{"travel_ms":764,"impact_ms":617,"color":"e8a153","caption":"横扫敌阵"},
	"godslayer":{"travel_ms":764,"impact_ms":667,"color":"c88ff0","caption":"破环重斩"},
	"holy_strike":{"travel_ms":1080,"impact_ms":617,"color":"ffe39b","caption":"圣光降临"},
	"magic_strike":{"travel_ms":864,"impact_ms":600,"color":"b593ff","caption":"奥术爆破"},
	"bounty":{"travel_ms":764,"impact_ms":717,"color":"e0b366","caption":"悬赏追击"},
	"glory":{"travel_ms":764,"impact_ms":717,"color":"f7cf78","caption":"荣耀冲锋"},
	"hasty_spell":{"travel_ms":600,"impact_ms":560,"color":"f6a0d5","caption":"火花急袭"},
	"judgment":{"travel_ms":720,"impact_ms":800,"color":"e77f7e","caption":"审判之剑"}
}

static func duration(event: Dictionary) -> int:
	if event.get("hand_response",false) and event.get("stage","") == "discard": return int(event.discard_ms)
	if event.get("kind","") == "blade_volley": return int(event.slice_ms)
	if event.get("kind","") == "gem_trigger" and event.has("return_ms"):
		return int(event.get(event.get("stage","")+"_ms",650))
	return int(event.get("travel_ms",650) if event.get("stage","") == "travel" else event.get("impact_ms",650))
