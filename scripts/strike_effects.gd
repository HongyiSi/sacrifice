extends RefCounted
## Distinct hand-drawn motifs, rendered in board coordinates. No rules or random state.
var fx: Control
var color: Color
var key := ""

func _init(layer: Control) -> void:
	fx = layer
	key = str(fx.event.style)
	color = Color(fx.event.get("color","f2c78a"))

func _stroke(points: PackedVector2Array, tint: Color, width: float) -> void:
	if points.size() < 2: return
	fx.draw_polyline(points,Color(0.22,0.15,0.2,tint.a*0.28),width+5,true)
	fx.draw_polyline(points,tint,width,true)
	fx.draw_polyline(points,Color(1,0.98,0.85,tint.a*0.95),maxf(1.4,width*0.19),true)

func _star(at: Vector2, radius: float, tint: Color, angle: float = 0) -> void:
	if radius <= 0.1 or tint.a <= 0.01: return
	if radius < 1.5:
		fx.draw_circle(at,radius,tint)
		return
	var p := PackedVector2Array()
	for i in range(8):
		p.append(at+Vector2.from_angle(angle+i*PI/4)*(radius if i%2 == 0 else radius*0.23))
	fx.draw_colored_polygon(p,tint)

func _slash(at: Vector2, angle: float, progress: float, tint: Color, width: float = 10) -> void:
	if progress <= 0 or progress >= 1: return
	# A fast, straight cut: the leading edge crosses in about 30–70 ms,
	# then a short luminous trail retracts along exactly the same axis.
	var head := minf(1,progress/0.12)
	var tail := pow(clampf((progress-0.26)/0.74,0,1),2)
	var fade := 1.0-smoothstep(0.26,1,progress)
	var axis := Vector2.from_angle(angle)
	var start := at+axis*lerpf(-82,82,tail)
	var end := at+axis*lerpf(-82,82,head)
	if start.distance_squared_to(end) < 1: return
	var middle := start.lerp(end,0.42)
	var edge := axis.orthogonal()*width*0.4
	fx.draw_line(start,end,Color(tint,fade*0.18),width*1.5,true)
	fx.draw_colored_polygon(PackedVector2Array([start,middle+edge,end,middle-edge]),Color(tint,fade))
	fx.draw_line(start.lerp(end,0.06),start.lerp(end,0.94),Color("fff7df")*Color(1,1,1,fade),maxf(1.4,width*0.18),true)
	# Keep the leading glint compact so the cut reads as a blade, not an orb.
	var flash := 1.0-smoothstep(0.12,0.38,progress)
	_star(end,7,Color("fff4da")*Color(1,1,1,flash),angle)

func _burst(at: Vector2, t: float, tint: Color, count: int = 12) -> void:
	var fade := 1.0-t
	for i in range(count):
		var angle := i*TAU/count+0.18
		var ray := Vector2.from_angle(angle)
		fx.draw_line(at+ray*(14+42*t),at+ray*(23+60*t),Color(tint,fade),2.5,true)
		if i%3 == 0: _star(at+ray*(34+t*49),6*fade,Color(tint,fade),angle)

func _rune(at: Vector2, radius: float, alpha: float, rotation: float = 0) -> void:
	fx.draw_arc(at,radius,0,TAU,60,Color(color,alpha),2,true)
	fx.draw_arc(at,radius*0.8,rotation,rotation+TAU*0.8,48,Color(color,alpha*0.6),1.5,true)
	for i in range(6):
		var p := at+Vector2.from_angle(rotation+i*TAU/6)*radius
		_star(p,5,Color(color,alpha),rotation)

func _blade(at: Vector2, angle: float, scale_factor: float, tint: Color) -> void:
	var outline := PackedVector2Array()
	for p in [Vector2(-8,-20),Vector2(8,-20),Vector2(7,28),Vector2(0,45),Vector2(-7,28)]:
		outline.append(at+(p*scale_factor).rotated(angle))
	fx.draw_colored_polygon(outline,tint)
	outline.append(outline[0]); fx.draw_polyline(outline,Color("554046"),2,true)
	fx.draw_line(at+Vector2(0,-16).rotated(angle)*scale_factor,at+Vector2(0,37).rotated(angle)*scale_factor,Color("fff4cd"),2,true)
	fx.draw_line(at+Vector2(-19,-22).rotated(angle)*scale_factor,at+Vector2(19,-22).rotated(angle)*scale_factor,Color("d5ad67"),5,true)
	fx.draw_line(at+Vector2(0,-23).rotated(angle)*scale_factor,at+Vector2(0,-43).rotated(angle)*scale_factor,Color("845b48"),6,true)

func _reticle(at: Vector2, t: float, alpha: float) -> void:
	var radius := lerpf(62,40,minf(1,t*2))
	for i in range(4):
		var angle := i*PI/2+0.22
		fx.draw_arc(at,radius,angle,angle+0.8,14,Color("b56646")*Color(1,1,1,alpha),3,true)
		fx.draw_line(at+Vector2.from_angle(angle)*(radius-7),at+Vector2.from_angle(angle)*(radius+7),Color(color,alpha),3,true)

func _crown(at: Vector2, size: float, alpha: float) -> void:
	var shape := PackedVector2Array()
	for p in [Vector2(-1,-0.4),Vector2(-0.35,0),Vector2(0,-1),Vector2(0.35,0),Vector2(1,-0.4),Vector2(0.75,0.6),Vector2(-0.75,0.6)]:
		shape.append(at+p*size)
	fx.draw_colored_polygon(shape,Color("e8ba62")*Color(1,1,1,alpha))
	shape.append(shape[0]); fx.draw_polyline(shape,Color("784a36")*Color(1,1,1,alpha),2,true)

func _sweep(t: float, impact: bool) -> void:
	var points := PackedVector2Array()
	for target in fx.event.targets:
		var at: Vector2 = fx._knight(target.id)
		points.append(fx.source.lerp(at,t) if not impact else at+Vector2(0,-30+65*t))
	if points.size() > 1:
		_stroke(points,Color(color,0.8*(1-t) if impact else 0.85),14 if impact else 10)
	if not impact:
		for p in points: fx._glow(p,color,13,0.65)

func draw(t: float, impact: bool) -> void:
	if key == "area_strike": _sweep(t,impact)
	if not impact:
		fx._glow(fx.source,color,22,0.3+sin(t*PI)*0.35)
	for target in fx.event.targets:
		var at: Vector2 = fx._knight(target.id)
		if impact:
			_hit(at,target,t)
		else:
			_windup(at,t)

func _windup(at: Vector2, t: float) -> void:
	var direction: Vector2 = (at-fx.source).normalized()
	var point: Vector2 = fx.source.lerp(at,t)
	match key:
		"strike","double_strike","triple_strike":
			var counts := {"strike":1,"double_strike":2,"triple_strike":3}
			var count: int = counts[key]
			_stroke(PackedVector2Array([fx.source,fx.source.lerp(at,minf(1,t*2))]),Color(color,0.22*(1-t)),3)
			for i in range(count):
				var angle: float = [-0.65,0.85,0.1][i]
				var progress := (t-0.12-i*0.2)/(0.8-i*0.12)
				_slash(at+Vector2(0,i*7-7),angle,progress,color,9+i*2)
		"quick_strike":
			for i in range(3):
				var offset := direction.orthogonal()*(i-1)*10
				_stroke(PackedVector2Array([fx.source.lerp(at,maxf(0,t-0.33))+offset,point+offset]),Color(color,0.8-i*0.15),3)
			_star(point,18,Color("e6ffff"),direction.angle())
		"area_strike":
			fx.draw_arc(at,50,PI,PI+PI*t,28,Color(color,0.5),3,true)
		"godslayer":
			_rune(at,54,0.6,t*0.8)
			var blade_at := Vector2(at.x,lerpf(maxf(150,at.y-165),at.y-35,pow(t,3)))
			fx._glow(blade_at,color,27,0.6)
			_blade(blade_at,0,1.2,Color("c4a3e1"))
		"holy_strike":
			var top := Vector2(at.x,maxf(132,at.y-185))
			_star(top,24+8*sin(t*PI),Color(color,0.9),PI/4)
			fx.draw_rect(Rect2(top.x-9,top.y,18,(at.y-top.y)*t),Color(color,0.34))
			_stroke(PackedVector2Array([top,top.lerp(at,t)]),Color(color,0.8),6)
			fx.draw_arc(at,44,0,TAU,48,Color(color,t*0.7),2,true)
		"magic_strike":
			_rune(fx.source,37,0.55*(1-t),t*2)
			var swirl := point+direction.orthogonal()*sin(t*TAU*1.5)*24*sin(t*PI)
			for i in range(12):
				var u := maxf(0,t-i*0.015)
				var tail: Vector2 = fx.source.lerp(at,u)+direction.orthogonal()*sin(u*TAU*1.5)*24*sin(u*PI)
				fx.draw_circle(tail,6*(1-i/13.0),Color(color,(1-i/13.0)*0.45))
			fx._glow(swirl,color,23,0.95)
			_rune(swirl,23,0.7,t*5)
		"bounty":
			_reticle(at,t,0.75)
			_blade(point,direction.angle()-PI/2,0.62,Color("ead0a4"))
		"glory":
			var tip: Vector2 = fx.source.lerp(at,pow(t,0.85))
			_stroke(PackedVector2Array([tip-direction*82,tip]),Color(color,0.95),7)
			var pennant := PackedVector2Array([tip-direction*26,tip-direction*70+direction.orthogonal()*30,tip-direction*64])
			fx.draw_colored_polygon(pennant,Color("b65c46"))
			_star(tip,17,Color(color,0.9),direction.angle())
		"hasty_spell":
			var bolt := PackedVector2Array()
			for i in range(12):
				var u := t*i/11
				bolt.append(fx.source.lerp(at,u)+direction.orthogonal()*sin(i*2.3+t*10)*15*sin(u*PI))
			_stroke(bolt,Color(color,0.8),3)
			_star(point,14,Color("ffe2f6"),t*5)
		"judgment":
			var top := at+Vector2(0,-126)
			# Scales and a falling red sword distinguish it from the holy beam.
			fx.draw_line(top+Vector2(-42,0),top+Vector2(42,0),Color(color,0.8),3,true)
			for side in [-1,1]:
				var p := top+Vector2(side*34,0)
				fx.draw_line(p,p+Vector2(0,25),Color(color,0.8),2,true)
				fx.draw_arc(p+Vector2(0,25),16,0,PI,20,Color(color,0.8),3,true)
			_blade(Vector2(at.x,lerpf(maxf(145,at.y-115),at.y-33,pow(t,3))),0,1.0,Color("e4b1a3"))

func _hit(at: Vector2, target: Dictionary, t: float) -> void:
	var fade := 1.0-smoothstep(0.48,1,t)
	if target.get("blocked",false):
		fx._shield(at,1+0.07*sin(t*PI),fade)
		_feedback(at,"保佑 · 抵挡",Color("c8e8ff"),t)
		return
	if target.get("miss",false):
		fx.draw_arc(at,40+18*t,0,TAU,48,Color(0.65,0.58,0.55,fade*0.7),2,true)
		_feedback(at,"未满足斩杀条件",Color("ecd4b9"),t)
		return
	match key:
		"strike","precise_strike": _slash(at,-0.65,0.3+t*0.7,color,11)
		"double_strike":
			_slash(at,-0.65,0.3+t*0.7,color,12)
			_slash(at,0.85,0.2+t*0.8,Color("fff0bf"),11)
		"triple_strike":
			for i in range(3): _slash(at+Vector2(0,i*7-7),[-0.65,0.85,0.1][i],0.3+t*0.7,color,12)
		"final_strike":
			for i in range(4): _slash(at+Vector2(0,i*6-9),[-.65,.85,.1,1.5][i],.3+t*.7,color,13)
		"quick_strike":
			_star(at,52*(1-t),Color("d5ffff")*Color(1,1,1,fade),0.25)
			fx.draw_line(at+Vector2(-70,12),at+Vector2(70,-12),Color(color,fade),3,true)
		"area_strike":
			fx.draw_arc(at,30+42*t,0,TAU,48,Color(color,fade*0.85),4,true)
		"godslayer":
			_slash(at,PI/2,0.2+t*0.8,Color("e8beff"),24)
			for i in range(7):
				var angle := i*TAU/7
				var offset := Vector2.from_angle(angle)*t*27
				fx.draw_arc(at+offset,50,angle,angle+0.5,12,Color(color,fade),5,true)
		"holy_strike":
			var top := at.y-42
			fx.draw_rect(Rect2(Vector2(at.x-23,top),Vector2(46,at.y+45-top)),Color(color,0.27*fade))
			fx.draw_line(Vector2(at.x,top),at+Vector2(0,45),Color("fff7cd")*Color(1,1,1,fade),7,true)
			_star(at,55*(1-t*0.4),Color(color,fade),PI/4)
		"magic_strike":
			_rune(at,35+t*48,fade,2*t)
			fx._glow(at,color,35*(1-t)+12,fade*0.8)
		"bounty":
			_reticle(at,1,fade)
			_slash(at,0.7,0.3+t*0.7,Color("f9dfab"),7)
		"glory":
			_crown(at+Vector2(0,-24),29,fade)
			for side in [-1,1]:
				for i in range(5):
					var p := at+Vector2(side*(33-i*3),25-i*12)
					fx.draw_line(p,p+Vector2(side*10,-10),Color(color,fade),5,true)
		"hasty_spell":
			for i in range(5):
				var p := at+Vector2.from_angle(i*TAU/5+t)*(18+t*40)
				_star(p,12*fade,Color(color,fade),i+t*2)
		"judgment":
			_blade(at+Vector2(0,-24),0,1.1,Color("f6ded0")*Color(1,1,1,fade))
			fx.draw_arc(at,47+23*t,0,TAU,50,Color(color,fade),5,true)
	_burst(at,t,color,16 if key in ["godslayer","triple_strike"] else 10)
	var label := "苦肉触发" if target.get("pain",false) else "-%d" % (target.damage if target.amount > 0 else 0)
	if target.get("before",1) == 0 and not target.get("pain",false): label = "目标已死亡 · 生命不变"
	if target.get("revived",false): label += " · 不死复活"
	elif target.get("died",false): label += " · 击倒"
	_feedback(at,label,Color("ffe6c8"),t)
	# Reward objects fly only when the authoritative draw/badge job begins,
	# after the hit and any immediate death/revival presentations have finished.

func _feedback(at:Vector2,label:String,tint:Color,t:float)->void:
	fx.result_text(at,label,tint,t)

func _reward_card() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f0d8a5"); style.border_color = Color("996f42")
	style.set_border_width_all(2); style.set_corner_radius_all(2)
	return style
