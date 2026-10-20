extends "res://scripts/card_launch_effect.gd"
## Approved weapon motifs layered over the shared lift/aim/flight sequence.
const NEW_STYLES := ["godslayer","bounty","area_strike","glory","precise_strike"]
static func supports(event:Dictionary)->bool:
	return preload("res://scripts/card_launch_effect.gd").supports(event) or (event.get("kind","") in ["strike","shield_block"] and event.get("style","") in NEW_STYLES)
func _init(layer:Control)->void:super(layer)
func travel(t:float)->void:
	var key:String=fx.event.get("style","")
	if key not in NEW_STYLES:super.travel(t);return
	var tint:=Color(fx.event.color)
	var group:bool=key in ["area_strike","precise_strike"]
	var count:int=fx.event.targets.size() if group else 1
	fx._glow(fx.source,tint,23,.55*(1-smoothstep(.1,.52,t)))
	for j in range(fx.event.targets.size()):
		var at:Vector2=fx._knight(fx.event.targets[j].id)
		if fx.event.kind=="shield_block":fx._shield(at,.95,.78)
		var i:int=j if group else 0
		var point:Vector2=flight_position(at,t,i,count)
		var angle:float=blade_angle(at,t,i,count)
		var final_side:float=112 if key=="godslayer" else 90
		var side:float=lerpf(fx.icon_side,final_side,smoothstep(0,RAISE_END,t))
		if key=="godslayer":fx.strike_effect._rune(at,53,.74*smoothstep(.1,.40,t),t*.6)
		if key in ["bounty","precise_strike"]:fx.strike_effect._reticle(at,t,.86*smoothstep(.08,.35,t))
		if group:fx.draw_arc(at,49,PI,TAU,36,Color(tint,.40*smoothstep(.2,.48,t)),2.5,true)
		if t>AIM_END:
			for tail in range(9,0,-1):
				var p:Vector2=flight_position(at,maxf(AIM_END,t-tail*.014),i,count)
				var q:Vector2=flight_position(at,maxf(AIM_END,t-(tail-1)*.014),i,count)
				fx.draw_line(p,q,Color(tint,(1-tail/10.0)*.78),5.5 if key=="godslayer" else 3.5,true)
		fx._glow(point,tint,18 if key=="godslayer" else 13,.32)
		# Keep the exact card sword silhouette; its accent follows the old effect.
		var ink:String={"godslayer":"8962a1","bounty":"a16d37","area_strike":"a65a3c","glory":"b18a36","precise_strike":"347f77"}[key]
		icon(point,"strike",side,angle,ink)
		if key=="glory":
			var axis:=Vector2.from_angle(angle+TIP_ANGLE)
			var across:=axis.orthogonal()
			var flag:=PackedVector2Array([point-axis*17,point-axis*63+across*(19+4*sin(t*19)),point-axis*52,point-axis*73-across*6])
			fx.draw_colored_polygon(flag,Color("b65c46")*Color(1,1,1,smoothstep(.08,.25,t)))
			flag.append(flag[0]);fx.draw_polyline(flag,Color("704431")*Color(1,1,1,smoothstep(.08,.25,t)),1.6,true)
			fx.strike_effect._star(point+axis*27,6,Color("fff0b7"),angle)
func impact(t:float)->void:
	var key:String=fx.event.get("style","")
	if key not in NEW_STYLES:super.impact(t);return
	var tint:=Color(fx.event.color)
	for target in fx.event.targets:
		if target.get("blocked",false) or target.get("miss",false):continue
		var at:Vector2=fx._knight(target.id)
		var angle:float=PI/2 if key=="godslayer" else .7 if key=="bounty" else -.65
		var axis:=Vector2.from_angle(angle)
		var alpha:float=1-smoothstep(.16,.39,t)
		var point:Vector2=at+axis*lerpf(-48,64,smoothstep(0,.22,t))
		if key in ["glory","area_strike","precise_strike"]:
			fx.strike_effect._slash(at,angle,.2+t*.8,tint,12)
		if alpha>0:
			icon(point,"strike",112 if key=="godslayer" else 90,angle-TIP_ANGLE,{"godslayer":"8962a1","bounty":"a16d37","area_strike":"a65a3c","glory":"b18a36","precise_strike":"347f77"}[key],alpha)
		if key=="godslayer":
			for i in range(6):
				var ray:=Vector2.from_angle(i*TAU/6+.15)
				fx.strike_effect._star(at+ray*(46+t*48),6*(1-t),Color(tint,1-t),i+t)
