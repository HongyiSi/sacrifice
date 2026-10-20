extends RefCounted
## The printed two-card emblem unfolds; only the following real draw reveals identities.
const Symbols=preload("res://scripts/art_symbols.gd")
const Palette=preload("res://scripts/card_palette.gd")
const RISE_END:=.23
const OPEN_END:=.47
const FLIGHT_START:=.63
const FLIGHT_END:=.94
const DECK:=preload("res://scripts/board_layout.gd").DECK_CENTER
var owner_ref:WeakRef
var book:RefCounted:
	get:return owner_ref.get_ref()
var fx:Control
var ink:=Color("4389a8")
var glow:=Color("8ecceb")
func _init(motif)->void:
	owner_ref=weakref(motif);fx=book.fx
func position_at(t:float)->Vector2:
	var lift:Vector2=fx.source+Vector2(0,-44)
	if t<RISE_END:return fx.source.lerp(lift,smoothstep(0,RISE_END,t))
	var fly:=smoothstep(FLIGHT_START,FLIGHT_END,t)
	return lift.lerp(DECK,fly)+Vector2(0,-sin(fly*PI)*36)
func draw(t:float,impact:bool)->void:
	if impact:
		fx.draw_arc(DECK,34+16*t,0,TAU,64,Color(ink,.45*(1-t)),2,true)
		return
	var rise:=smoothstep(0,RISE_END,t)
	var spread:=smoothstep(RISE_END,OPEN_END,t)
	var fold:=smoothstep(.55,.70,t)
	var fly:=smoothstep(FLIGHT_START,FLIGHT_END,t)
	var at:=position_at(t)
	var side:float=lerpf(fx.icon_side,76,rise)*(1-.26*fly)
	var alpha:=1-smoothstep(.92,1,t)
	var tilt:float=-.10*sin(fly*PI)
	fx._glow(at,glow,29,.20*rise*alpha)
	if fly>0 and fly<1:
		for i in range(9,0,-1):
			var a:=position_at(maxf(FLIGHT_START,t-i*.006))
			var b:=position_at(maxf(FLIGHT_START,t-(i-1)*.006))
			fx.draw_line(a,b,Color(ink,(1-i/10.0)*.45*alpha),2.3,true)
	_emblem(at,side,spread,fold,tilt,alpha)
	if t>.40 and t<.63:
		var shine:=sin(clampf((t-.40)/.23,0,1)*PI)
		for i in range(3):
			var tip:Vector2=at+Vector2((i-1)*29,-27-8*(1-abs(i-1)))
			book.brush._star(tip,4.5*shine,Color(ink,.85*shine),PI*.25)
	if t>.88:
		var pulse:=smoothstep(.88,1,t)
		fx.draw_arc(DECK,27+7*pulse,0,TAU,56,Color(ink,.45*pulse),2,true)
func _emblem(at:Vector2,side:float,spread:float,fold:float,angle:float,alpha:float)->void:
	fx.draw_set_transform(at,angle,Vector2.ONE*side/64)
	if spread<=0:
		fx.draw_texture_rect(Symbols.icon("collect",Palette.ink("collect")),Rect2(-32,-32,64,64),false,Color(1,1,1,alpha))
		fx.draw_set_transform(Vector2.ZERO);return
	var back:=PackedVector2Array([Vector2(-21,-21),Vector2(6,-25),Vector2(13,18),Vector2(-14,22)])
	var front:=PackedVector2Array([Vector2(-7,-16),Vector2(21,-16),Vector2(21,26),Vector2(-7,26)])
	for i in range(3):
		var visible_alpha:float=alpha*(spread if i==1 else 1.0)
		var fan_center:=Vector2((i-1)*18,2 if i!=1 else -4)
		var stack_center:=Vector2((i-1)*4,(i-1)*3)
		var center:Vector2=fan_center.lerp(stack_center,fold)
		var rotation:float=(i-1)*.27*(1-fold)
		var original:PackedVector2Array=back if i==0 else front
		var points:=PackedVector2Array()
		var corners:=[Vector2(-13,-21),Vector2(13,-21),Vector2(13,21),Vector2(-13,21)]
		for j in range(4):points.append(original[j].lerp(center+corners[j].rotated(rotation),spread))
		if i>0 or spread>0:fx.draw_colored_polygon(points,Color(ink,visible_alpha*(spread if i==0 else 1.0)))
		var edge:=points.duplicate();edge.append(edge[0])
		if i==0:fx.draw_polyline(edge,Color(ink,alpha),3,true)
		if i>0:fx.draw_polyline(edge,Color("f3dfb6",visible_alpha*spread*.85),1.4,true)
		var original_star:=Vector2(-5,-1) if i==0 else Vector2(7,5)
		var star_center:Vector2=original_star.lerp(center,spread)
		var star_alpha:float=visible_alpha*(spread if i==0 else 1.0)
		var star:=PackedVector2Array()
		for point in [Vector2(0,-11),Vector2(3,-3),Vector2(11,0),Vector2(3,3),Vector2(0,11),Vector2(-3,3),Vector2(-11,0),Vector2(-3,-3)]:
			star.append(star_center+point.rotated(rotation*spread))
		fx.draw_colored_polygon(star,Color("f3dfb6",star_alpha))
		star.append(star[0]);fx.draw_polyline(star,Color("f3dfb6",star_alpha),.55,true)
	fx.draw_set_transform(Vector2.ZERO)
