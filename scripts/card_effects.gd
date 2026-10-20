extends RefCounted
## Paper, ink and luminous heraldry in the same board coordinate system as the knights.
var fx: Control
var ink: Color
var motif: String
var brush: RefCounted
var stroke_scale := 1.0

func _init(layer: Control) -> void:
	fx = layer
	ink = Color(fx.event.color)
	motif = fx.event.motif
	brush = preload("res://scripts/strike_effects.gd").new(layer)

func _line(points: Array, alpha: float = 1, width: float = 3) -> void:
	fx.draw_polyline(PackedVector2Array(points),Color(ink,alpha),width*stroke_scale,true)

func _card(at: Vector2, angle: float, alpha: float, death: bool = false) -> void:
	var p := PackedVector2Array()
	for v in [Vector2(-12,-18),Vector2(12,-18),Vector2(12,18),Vector2(-12,18)]: p.append(at+v.rotated(angle))
	fx.draw_colored_polygon(p,Color(Color("645374") if death else Color("435969"),alpha))
	p.append(p[0]); fx.draw_polyline(p,Color("e5c58a")*Color(1,1,1,alpha),2*stroke_scale,true)
	brush._star(at,7,Color(ink,alpha),angle)

func _eye(at: Vector2, t: float, alpha: float) -> void:
	var points: Array = []
	for i in range(33):
		var u := i*TAU/32
		points.append(at+Vector2(cos(u)*48,sin(u)*23*(0.5+0.5*sin(PI*t))))
	_line(points,alpha,3)
	fx.draw_circle(at,12,Color(ink,alpha*0.35))
	fx.draw_arc(at,12,0,TAU,32,Color(ink,alpha),3*stroke_scale,true)
	fx.draw_circle(at+Vector2(3,-3),4,Color("fff8e4")*Color(1,1,1,alpha))

func _soul(at: Vector2, t: float, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var u := PI+i*PI/24
		points.append(at+Vector2(cos(u)*22,sin(u)*26))
	for i in range(13):
		points.append(at+Vector2(22-i*44.0/12,20+sin(i*1.5+t*8)*5))
	fx.draw_colored_polygon(points,Color(ink,alpha*0.28))
	points.append(points[0]); fx.draw_polyline(points,Color(ink,alpha),2*stroke_scale,true)
	for x in [-7,7]: fx.draw_circle(at+Vector2(x,-4),3,Color("fff6e4")*Color(1,1,1,alpha))

func _heart(at: Vector2, scale_value: float, alpha: float) -> void:
	var p := PackedVector2Array()
	for i in range(49):
		var u := i*TAU/48
		p.append(at+Vector2(16*pow(sin(u),3),-(13*cos(u)-5*cos(2*u)-2*cos(3*u)-cos(4*u)))*scale_value)
	fx.draw_colored_polygon(p,Color(ink,alpha*0.5))
	fx.draw_polyline(p,Color("ffe5cc")*Color(1,1,1,alpha),2*stroke_scale,true)

func _symbol(at: Vector2, t: float, alpha: float) -> void:
	match motif:
		"draw","steal":
			for i in range(3): _card(at+Vector2((i-1)*20,abs(i-1)*8), (i-1)*0.2,alpha)
		"dice":
			var r := Rect2(at-Vector2(22,22),Vector2(44,44))
			fx.draw_style_box(_paper(alpha),r)
			for v in [Vector2(-10,-10),Vector2(10,-10),Vector2.ZERO,Vector2(-10,10),Vector2(10,10)]:
				fx.draw_circle(at+v,3,Color("795b47")*Color(1,1,1,alpha))
		"coins","badge":
			for i in range(3 if motif == "coins" else 1):
				var p := at+Vector2((i-1)*22 if motif == "coins" else 0,abs(i-1)*8 if motif == "coins" else 0)
				fx.draw_circle(p,23,Color("7d6240")*Color(1,1,1,alpha))
				fx.draw_arc(p,22,0,TAU,40,Color(ink,alpha),4*stroke_scale,true)
				brush._star(p,15,Color(ink,alpha),t*0.6)
		"eye": _eye(at,t,alpha)
		"mirror":
			for x in [-17,17]:
				var p := at+Vector2(x,0)
				fx.draw_circle(p,27,Color("a6e4ed")*Color(1,1,1,0.16*alpha))
				fx.draw_arc(p,27,0,TAU,48,Color(ink,alpha),3*stroke_scale,true)
				_line([p+Vector2(-11,12),p+Vector2(11,-12)],alpha*0.8,4)
		"seal":
			fx.draw_arc(at,38,0,TAU,48,Color(ink,alpha),4*stroke_scale,true)
			_line([at+Vector2(-30,30),at+Vector2(30,-30)],alpha,5)
			for i in range(4): brush._star(at+Vector2.from_angle(i*PI/2)*43,5,Color(ink,alpha))
		"reverse":
			for i in range(2):
				var a := i*PI+t*2
				fx.draw_arc(at,37,a,a+2.3,32,Color(ink,alpha),5*stroke_scale,true)
				var tip := at+Vector2.from_angle(a+2.3)*37
				_line([tip+Vector2(12,-7).rotated(a),tip,tip+Vector2(-5,-13).rotated(a)],alpha,4)
		"hourglass":
			_line([at+Vector2(-24,-34),at+Vector2(24,-34),at+Vector2(-24,34),at+Vector2(24,34),at+Vector2(-24,-34)],alpha,3)
			for i in range(6): fx.draw_circle(at+Vector2(sin(i)*3,fmod(t*60+i*6,46)-23),2,Color(ink,alpha))
		"lightning":
			_line([at+Vector2(13,-45),at+Vector2(-15,0),at+Vector2(15,-4),at+Vector2(-14,43)],alpha,8)
			for i in range(3): _card(at+Vector2((i-1)*28,50),0,alpha*0.8)
		"horn":
			var symbols=preload("res://scripts/art_symbols.gd")
			var palette=preload("res://scripts/card_palette.gd")
			fx.draw_texture_rect(symbols.icon("warcry",palette.ink("warcry")),Rect2(at-Vector2(40,40),Vector2(80,80)),false,Color(1,1,1,alpha))
		"soul","ghost": _soul(at+Vector2(0,-t*35),t,alpha)
		"chains":
			for side in [-1,1]:
				for i in range(6):
					var p := at+Vector2((i-2.5)*17,(i-2.5)*side*10)
					fx.draw_arc(p,10,0,TAU,24,Color(ink,alpha),3*stroke_scale,true)
			fx.draw_style_box(_paper(alpha),Rect2(at-Vector2(12,5),Vector2(24,25)))
			fx.draw_circle(at+Vector2(0,5),3,Color("645570")*Color(1,1,1,alpha))
		"thorns":
			for i in range(2):
				var pts: Array = []
				for j in range(33):
					var a := j*TAU/32
					pts.append(at+Vector2(cos(a)*52,sin(a)*26).rotated(i*0.8))
				_line(pts,alpha,2)
			for i in range(8): brush._star(at+Vector2.from_angle(i*TAU/8+t)*45,7,Color(ink,alpha))
			_heart(at,1.1,alpha)
		"revive","phoenix":
			fx.draw_arc(at+Vector2(0,37),44,0,TAU,48,Color(ink,alpha),3*stroke_scale,true)
			for side in [-1,1]:
				var p := PackedVector2Array([at,at+Vector2(side*58,-40-t*15),at+Vector2(side*39,6),at+Vector2(side*17,19)])
				fx.draw_colored_polygon(p,Color(ink,alpha*0.32))
				fx.draw_polyline(p,Color(ink,alpha),2*stroke_scale,true)
			_line([at+Vector2(0,-28),at+Vector2(0,26)],alpha,5)
			_line([at+Vector2(-19,-9),at+Vector2(19,-9)],alpha,5)
		"dissolve","shatter":
			for i in range(12):
				var p := at+Vector2.from_angle(i*TAU/12)*(15+55*t)
				var shard := PackedVector2Array([p,p+Vector2(10,4).rotated(i),p+Vector2(3,15).rotated(i)])
				fx.draw_colored_polygon(shard,Color(ink,alpha))
		"heart": _heart(at,1.9+sin(t*TAU)*0.15,alpha)
		"divinity":
			brush._rune(at,49,alpha,t*1.5)
			for i in range(3): _card(at+Vector2((i-1)*25,0),(i-1)*0.1,alpha)
		"crown":
			brush._crown(at,40,alpha)
			for i in range(5):
				var p := at+Vector2((i-2)*22,-42-t*12)
				_line([p+Vector2(-5,6),p,p+Vector2(5,6)],alpha,2)
		"scythe":
			_line([at+Vector2(25,45),at+Vector2(-18,-38)],alpha,6)
			fx.draw_arc(at+Vector2(4,-5),43,PI*1.1,TAU,40,Color(ink,alpha),8,true)
		"dance":
			for i in range(5):
				var a := i*TAU/5+t*3
				var p := at+Vector2.from_angle(a)*46
				brush._star(p,9,Color(ink,alpha),a)
				fx.draw_arc(at,46,a-0.5,a,12,Color(ink,alpha*0.6),3*stroke_scale,true)
		"drain":
			_heart(at,1.4,alpha)
			for i in range(3): fx.draw_arc(at,32+i*8,t*4+i,t*4+i+PI,32,Color(ink,alpha*0.7),2*stroke_scale,true)
		"curse":
			brush._rune(at,43,alpha,-t)
			for i in range(3):
				var a := i*TAU/3+t
				_line([at+Vector2.from_angle(a)*10,at+Vector2.from_angle(a+0.8)*28,at+Vector2.from_angle(a)*51],alpha,4)

func _paper(alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f2dfac")*Color(1,1,1,alpha)
	box.border_color = Color("9c7a54")*Color(1,1,1,alpha)
	box.set_border_width_all(2); box.set_corner_radius_all(4)
	return box

func _label(at: Vector2, label: String, t: float) -> void:
	var alpha := 1.0-smoothstep(0.76,1,t)
	# The health shields sit 80 px below this anchor; keep feedback above them.
	var p := at+Vector2(-165,61-5*t)
	var font := fx.get_theme_font("font")
	fx.draw_string_outline(font,p,label,HORIZONTAL_ALIGNMENT_CENTER,330,18,4,Color(0.18,0.15,0.19,alpha))
	fx.draw_string(font,p,label,HORIZONTAL_ALIGNMENT_CENTER,330,18,Color("fff5d8")*Color(1,1,1,alpha))

func draw(t: float, impact: bool) -> void:
	var fade := 1.0-smoothstep(0.6,1,t) if impact else 0.85
	if not impact:
		fx._glow(fx.source,ink,24,0.5*sin(t*PI))
		fx.draw_arc(fx.source,38+t*12,0,TAU,40,Color(ink,0.6*(1-t)),2*stroke_scale,true)
	for target in fx.event.targets:
		var knight: Vector2 = fx._knight(target.id)
		var at: Vector2 = fx.target_point if fx.target_point != Vector2.ZERO else knight
		if not impact:
			fx._flight(at,t,ink)
			if motif in ["draw","dice","coins","steal","divinity","dissolve"]:
				for i in range(3):
					var u := clampf(t*1.5-i*0.18,0,1)
					var start: Vector2 = at if fx.event.get("flow","") in ["out","steal"] else fx.source
					var end: Vector2 = fx.source if fx.event.get("flow","") in ["out","steal"] else at
					_card(start.lerp(end,u)+Vector2(0,-sin(u*PI)*60),sin(u*PI)*(i-1)*0.4,0.85)
			_symbol(at,t,0.2+0.6*t)
		else:
			fx._glow(at,ink,30+t*20,0.45*fade)
			_symbol(at,t,fade)
			for i in range(9):
				var p := at+Vector2.from_angle(i*TAU/9)*(30+40*t)+Vector2(0,-t*22)
				brush._star(p,4*fade,Color(ink,fade),t+i)
			var label: String = target.get("label","")
			if fx.event.kind == "death_strike":
				label = "灵魂收割" if fx.event.style == "death_sentence" and target.get("died",false) else "-%d 生命" % target.get("damage",0)
				if fx.event.style == "last_dance": label = "第 %d / 5 次 · -1 生命" % fx.event.action.get("hits",1)
				if target.get("pain",false): label = "触发队友的苦肉"
				if target.get("blocked",false): label = "攻击被抵挡"
				if target.get("before",1) == 0 and not target.get("pain",false): label = "目标已死亡 · 未造成伤害"
			_label(knight,label,t)
			if motif == "drain" and target.get("died",false):
				var old: Vector2 = fx.source
				fx.source = at; fx._flight(fx._knight(fx.event.action.actor),t,ink); fx.source = old
