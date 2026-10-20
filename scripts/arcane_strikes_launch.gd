extends "res://scripts/signature_strike_launch.gd"
## Approved card-origin sword and spell motions; presentation only.
const ARCANE_STYLES := ["holy_strike","quick_strike","hasty_spell","magic_strike"]
static func supports(event:Dictionary)->bool:
	return preload("res://scripts/signature_strike_launch.gd").supports(event) or (event.get("kind","") in ["strike","shield_block"] and event.get("style","") in ARCANE_STYLES)
func _init(layer:Control)->void:super(layer)
func flight_position(at:Vector2,t:float,i:int,n:int)->Vector2:
	if fx.event.get("style","")!="holy_strike":return super.flight_position(at,t,i,n)
	var lift:Vector2=fx.source+Vector2(0,-35)
	var overhead:Vector2=at+Vector2(0,-62)
	if t<.25:return fx.source.lerp(lift,smoothstep(0,.25,t))
	if t<.67:
		var u:float=smoothstep(.25,.67,t)
		return lift.lerp(overhead,u)+Vector2(0,-sin(u*PI)*32)
	if t<.76:return overhead
	return overhead.lerp(at+Vector2(0,12),pow(clampf((t-.76)/.24,0,1),2))
func blade_angle(at:Vector2,t:float,i:int,n:int)->float:
	if fx.event.get("style","")!="holy_strike":return super.blade_angle(at,t,i,n)
	var lift:Vector2=fx.source+Vector2(0,-35)
	var angle:float=(at+Vector2(0,-62)-lift).angle()-TIP_ANGLE
	if t<.47:return lerp_angle(0,angle,smoothstep(.25,.47,t))
	return lerp_angle(angle,PI/2-TIP_ANGLE,smoothstep(.47,.69,t))
func _spell_point(at:Vector2,t:float,key:String)->Vector2:
	var point:Vector2=flight_position(at,t,0,1)
	if t>AIM_END and key=="magic_strike":
		var u:float=clampf((t-AIM_END)/(1-AIM_END),0,1)
		var direction:Vector2=(at-fx.source).normalized()
		point+=direction.orthogonal()*sin(u*TAU*1.5)*14*sin(u*PI)
	return point
func _tail(at:Vector2,t:float,key:String,tint:Color)->void:
	if t<=AIM_END:return
	var point:Vector2=_spell_point(at,t,key)
	var direction:Vector2=(at-fx.source).normalized()
	if key=="quick_strike":
		for lane in [-1,0,1]:
			var offset:Vector2=direction.orthogonal()*lane*10
			var start:Vector2=flight_position(at,maxf(AIM_END,t-.18+abs(lane)*.03),0,1)
			fx.strike_effect._stroke(PackedVector2Array([start+offset,point+offset]),Color(tint,.68 if lane==0 else .44),3 if lane==0 else 2)
	elif key=="hasty_spell":
		var bolt:=PackedVector2Array()
		for i in range(11):
			var u:float=maxf(AIM_END,t-.16+i*.016)
			var p:Vector2=flight_position(at,u,0,1)
			p+=direction.orthogonal()*sin(i*2.3+t*20)*8*sin(i*PI/10)
			bolt.append(p)
		fx.strike_effect._stroke(bolt,Color(tint,.90),4)
	else:
		for j in range(10,0,-1):
			var p:Vector2=_spell_point(at,maxf(AIM_END,t-j*.014),key)
			var q:Vector2=_spell_point(at,maxf(AIM_END,t-(j-1)*.014),key)
			fx.draw_line(p,q,Color(tint,(1-j/11.0)*.75),5 if key=="magic_strike" else 4,true)
			if key=="holy_strike" and j%3==0:
				fx.strike_effect._star(p+direction.orthogonal()*sin(j*3+t*20)*12,4,Color(tint,.65),t)
func travel(t:float)->void:
	var key:String=fx.event.get("style","")
	if key not in ARCANE_STYLES:super.travel(t);return
	if key=="magic_strike":
		var ms:float=t*864.0
		t=ms/764.0 if ms<=.48*764.0 else .48+(ms-.48*764.0)*.8/764.0
		t=clampf(t,0,1)
	var tint:=Color(fx.event.color)
	var spell:bool=key in ["hasty_spell","magic_strike"]
	fx._glow(fx.source,tint,22,.55*(1-smoothstep(.1,.52,t)))
	for target in fx.event.targets:
		var at:Vector2=fx._knight(target.id)
		if fx.event.kind=="shield_block":fx._shield(at,.95,.78)
		var point:Vector2=_spell_point(at,t,key)
		var angle:float=blade_angle(at,t,0,1)
		if spell:
			var axis:Vector2=(at-flight_position(at,AIM_END,0,1)).normalized()
			angle=lerp_angle(0,axis.angle()+PI/2,smoothstep(RAISE_END,AIM_END,t))
		var side:float=lerpf(fx.icon_side,76 if spell else 92,smoothstep(0,RAISE_END,t))
		_tail(at,t,key,tint)
		match key:
			"holy_strike":
				fx._glow(point,tint,28,.52)
				var aim:Vector2=Vector2.from_angle(angle+TIP_ANGLE)
				# A halo folds around the blade while it lifts, then trails behind.
				fx.draw_arc(point,34,-.15+t,PI*.8+t,32,Color(tint,.75*sin(PI*minf(1,t/.8))),2.5,true)
				fx.strike_effect._star(point+aim*30,9,Color("fff5c9"),angle)
				icon(point,key,side,angle,"b48a32")
				fx.draw_arc(at+Vector2(0,31),34,0,TAU,48,Color("d2a54a")*Color(1,1,1,.50*smoothstep(.4,1,t)),2,true)
			"quick_strike":
				if t>AIM_END:
					for j in [2,1]:
						icon(flight_position(at,maxf(AIM_END,t-j*.025),0,1),key,side,angle,"4f9eab",.16/j)
				fx._glow(point,tint,15,.38)
				icon(point,key,side,angle,"438899")
			"hasty_spell":
				fx._glow(point,tint,24,.64)
				icon(point,key,side,angle,"b35b91")
				for i in range(3):
					var offset:Vector2=Vector2.from_angle(i*TAU/3+t*11)*(24+4*sin(t*15+i))
					fx.strike_effect._star(point+offset,5,Color("ffd7eb"),i+t*3)
			"magic_strike":
				fx._glow(point,tint,31,.75)
				fx.strike_effect._rune(point,35,.82*smoothstep(.08,.30,t),t*4)
				icon(point,key,side*.91,angle,"8256b0")
				for i in range(3):
					var p:Vector2=point+Vector2.from_angle(t*8+i*TAU/3)*27
					fx.draw_circle(p,2.5,Color("eee1ff"))
func impact(t:float)->void:
	var key:String=fx.event.get("style","")
	if key not in ARCANE_STYLES:super.impact(t);return
	var tint:=Color(fx.event.color)
	for target in fx.event.targets:
		if target.get("blocked",false) or target.get("miss",false):continue
		var at:Vector2=fx._knight(target.id)
		var alpha:float=1-smoothstep(.15,.39,t)
		match key:
			"holy_strike":
				var direction:=Vector2.DOWN
				var point:Vector2=at+direction*lerpf(-20,28,smoothstep(0,.22,t))
				icon(point,key,84,PI/2-TIP_ANGLE,"b48a32",alpha)
				fx.strike_effect._slash(at,PI/2,.2+t*.8,Color("fff0b5"),15)
				fx.draw_arc(at+Vector2(0,24),32+t*35,0,TAU,48,Color("d7ab55")*Color(1,1,1,.8*(1-t)),2.6,true)
			"quick_strike":
				var direction:Vector2=(at-fx.source).normalized()
				var point:Vector2=at+direction*lerpf(-30,75,smoothstep(0,.20,t))
				icon(point,key,92,direction.angle()-TIP_ANGLE,"438899",alpha)
				fx.strike_effect._slash(at,direction.angle(),.2+t*.8,tint,10)
			"hasty_spell":
				icon(at,key,76*(1+t*.8),t*.5,"b35b91",alpha)
				fx._glow(at,tint,32*(1-t),.5*(1-t))
				for i in range(5):
					var direction:=Vector2.from_angle(i*TAU/5+.2)
					var points:=PackedVector2Array([at+direction*13,at+direction*(25+t*18)+direction.orthogonal()*7,at+direction*(40+t*28)])
					fx.strike_effect._stroke(points,Color(tint,.65*(1-t)),2)
			"magic_strike":
				icon(at,key,70*(1+t*.9),0,"8256b0",alpha)
				fx.draw_arc(at,23+t*70,0,TAU,64,Color("e6d2ff")*Color(1,1,1,.7*(1-t)),3.0,true)
