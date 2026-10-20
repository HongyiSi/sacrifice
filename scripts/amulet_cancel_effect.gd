extends RefCounted
const KEYS=["holy_amulet","attack_amulet","magic_amulet"]
var fx
var visual
static func supports(e:Dictionary)->bool:
	return e.get("kind","")=="shield_block" and e.get("style","") in KEYS and e.has("cancelled_style")
func _init(layer)->void:
	fx=layer;visual=preload("res://scripts/amulet_visual.gd").new();fx.add_child(visual);visual.configure(fx)
func update(t:float)->void:
	var age=t*fx.event.travel_ms/1000. if fx.event.stage=="travel" else fx.event.travel_ms/1000.+t*fx.event.impact_ms/1000.
	visual.present(age)
func draw(_t:float)->void:pass
func dispose()->void:
	if is_instance_valid(visual):visual.dispose()
	visual=null;fx=null
