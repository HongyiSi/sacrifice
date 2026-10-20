extends "res://scripts/arcane_strikes_launch.gd"
var book:RefCounted
static func supports(event:Dictionary)->bool:
	return preload("res://scripts/arcane_strikes_launch.gd").supports(event) or event.get("kind","") in ["card_effect","death_strike","heal","shield","blessing","shield_block"] or event.get("style","")=="judgment"
func _init(layer:Control)->void:
	super(layer)
	book=preload("res://scripts/card_motif_effects.gd").new(layer)
func travel(t:float)->void:
	var key:String=fx.event.get("style","")
	if key in ["strike","double_strike","triple_strike","final_strike","godslayer","bounty","area_strike","precise_strike","glory","holy_strike","quick_strike","hasty_spell","magic_strike","defense","heal"]:
		super.travel(t);return
	book.travel(t)
func impact(t:float)->void:
	if fx.event.get("style","")=="judgment":
		book.impact(t);return
	super.impact(t)
func support_impact(t:float)->void:book.impact(t)
