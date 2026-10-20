extends RefCounted
## Card emblems lift, aim, then launch. Does not mutate authoritative game state.
const Symbols=preload("res://scripts/art_symbols.gd")
const RAISE_END := 0.25
const AIM_END := 0.48
const TIP_ANGLE := -0.8058035 # The sword artwork points from (32,32) to (56,7).
const Palette=preload("res://scripts/card_palette.gd")
var fx:Control
func _init(layer:Control)->void:
	fx=layer
static func supports(event: Dictionary) -> bool:
	var key: String = event.get("style","")
	return (event.get("kind","") in ["strike","shield_block"] and key in ["strike","double_strike","triple_strike","final_strike"]) or (event.get("kind","")=="heal" and key=="heal") or (event.get("kind","")=="shield" and key=="defense")
func count_blades()->int:
	return 2 if fx.event.get("style","")=="double_strike" else 3 if fx.event.get("style","")=="triple_strike" else 4 if fx.event.get("style","")=="final_strike" else 1
func is_sword()->bool:
	return fx.event.kind in ["strike","shield_block"]
func icon(at:Vector2,key:String,side:float,angle:float,ink:String,alpha:float=1.0)->void:
	ink=Palette.ink(str(fx.event.get("style",key)))
	fx.draw_set_transform(at+Vector2(1.8,2.5),angle)
	fx.draw_texture_rect(Symbols.icon(key,"503d33"),Rect2(-side/2,-side/2,side,side),false,Color(1,1,1,.28*alpha))
	fx.draw_set_transform(at,angle)
	fx.draw_texture_rect(Symbols.icon(key,ink),Rect2(-side/2,-side/2,side,side),false,Color(1,1,1,alpha))
	fx.draw_set_transform(Vector2.ZERO)
func flight_position(at:Vector2,t:float,i:int,n:int)->Vector2:
	# Emblems first peel out and separate where their exact card artwork was.
	# After this short readable lift, their paths are straight.
	var separation:float=(i-(n-1)*.5)*48
	var launch:Vector2=fx.source+Vector2(separation,-35)
	var landing:Vector2=at+Vector2((i-(n-1)*.5)*31,24 if at.y<fx.source.y else -24)
	var lift_end: float = RAISE_END if is_sword() else .32
	var fly_start: float = AIM_END if is_sword() else .32
	if t<lift_end:
		var u:float=smoothstep(0,lift_end,t)
		return fx.source.lerp(launch,u)
	if t<fly_start: return launch
	var u:float=pow(clampf((t-fly_start)/(1.0-fly_start),0,1),1.35)
	if not is_sword():
		# Support magic bends around the pawn's name, entering from the left.
		var control1:Vector2=Vector2(at.x-210,launch.y+30)
		var control2:Vector2=at+Vector2(-135,-28)
		return pow(1-u,3)*launch+3*pow(1-u,2)*u*control1+3*(1-u)*u*u*control2+u*u*u*at
	return launch.lerp(landing,u)
func blade_angle(at: Vector2,t: float,i: int,n: int) -> float:
	var launch: Vector2 = flight_position(at,AIM_END,i,n)
	var landing: Vector2 = flight_position(at,1,i,n)
	var aim: float = (landing-launch).angle()-TIP_ANGLE
	return lerp_angle(0,aim,smoothstep(RAISE_END,AIM_END,t))
func travel(t:float)->void:
	var sword:bool=is_sword()
	var healing:bool=fx.event.kind=="heal"
	var n:int=count_blades() if sword else 1
	var tint:Color=Color("efbc78") if sword else Color("65df8b") if healing else Color("81c9fa")
	# A quiet pulse on the real card face establishes where the effect comes from.
	fx._glow(fx.source,tint,19,.38*(1-smoothstep(.1,.55,t)))
	for target in fx.event.targets:
		var at:Vector2=fx._knight(target.id)
		if fx.event.kind=="shield_block":fx._shield(at,.95,.78)
		for i in range(n):
			var point:Vector2=flight_position(at,t,i,n)
			var rotation:float=blade_angle(at,t,i,n) if sword else sin(t*PI)*.1
			var size:float=lerpf(fx.icon_side,86 if sword else 66,smoothstep(0,RAISE_END if sword else .32,t))
			# Short tails, not a curved slash: the blade remains the visual focus.
			var fly_start: float = AIM_END if sword else .32
			if t>fly_start:
				for j in range(7,0,-1):
					var previous:Vector2=flight_position(at,maxf(fly_start,t-j*.014),i,n)
					var previous2:Vector2=flight_position(at,maxf(fly_start,t-(j-1)*.014),i,n)
					fx.draw_line(previous,previous2,Color(tint,(1-j/8.0)*.52),2.8 if sword else 5.0,true)
			if sword:
				fx._glow(point,tint,14,.26)
				icon(point,"strike",size,rotation,"a65a3c")
			elif healing:
				fx._glow(point,tint,24,.80)
				# Keep the heart silhouette from the card recognizable inside the orb.
				icon(point,"heal",size*.82,rotation,"3c9c66")
				for j in range(5):
					var v:Vector2=point+Vector2.from_angle(t*7+j*TAU/5)*29
					fx.draw_circle(v,2.1,Color("d4ffbe"))
			else:
				fx._glow(point,tint,24,.38)
				icon(point,"defense",size,rotation,"3c6186")
				fx.draw_arc(point,38,0,TAU,48,Color(tint,.35*sin(t*PI)),2,true)
func impact(t:float)->void:
	# The emblem itself executes a quick cut. The unchanged original renderer
	# underneath supplies its straight white core, warm sparks and damage text.
	var n:int=count_blades()
	var alpha:float=1-smoothstep(.14,.34,t)
	if alpha<=0:return
	for target in fx.event.targets:
		if target.get("blocked",false) or target.get("miss",false): continue
		var at:Vector2=fx._knight(target.id)
		for i in range(n):
			var axis:Vector2=Vector2.from_angle([-.65,.85,.1,1.5][i])
			var progress:float=smoothstep(0,.22,t)
			var point:Vector2=at+axis*lerpf(-42,70,progress)
			icon(point,"strike",86,axis.angle()+PI/4,"a65a3c",alpha)
