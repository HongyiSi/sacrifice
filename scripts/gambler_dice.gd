extends RefCounted
## Approved presentation. A decorative die never chooses the draw count.
const RISE_END:=0.14
const ROLL_END:=0.64
const DISCARD_START:=0.72
const Die=preload("res://scripts/gambler_die_art.gd")
const Palette=preload("res://scripts/card_palette.gd")
var owner_ref:WeakRef
var book:RefCounted:
	get:return owner_ref.get_ref()
var fx:Control
var edge:Color
func _init(motif)->void:
	owner_ref=weakref(motif);fx=book.fx;edge=Color(Palette.ink("gambler"))

func draw(t:float)->void:
	var rise:=smoothstep(0,RISE_END,t)
	var lift:Vector2=fx.source+Vector2(0,-44)
	var at:Vector2=fx.source.lerp(lift,rise)
	var side:float=lerpf(fx.icon_side,72,rise)
	var roll:=clampf((t-RISE_END)/(ROLL_END-RISE_END),0,1)
	var envelope:=pow(sin(roll*PI),0.8)
	at+=Vector2(sin(roll*TAU*3.5)*11,-absf(sin(roll*TAU*2.5))*9)*envelope
	var alpha:=1-smoothstep(.73,.84,t)
	if alpha>0:
		fx._glow(at,book.ink,28,.32*alpha*rise)
		# Two complete turns ease to the original five-pip face.
		var spin:=1-pow(1-roll,1.55)
		var basis:=Basis(Vector3.FORWARD,.27*sin(roll*TAU*3)*envelope)*Basis(Vector3.UP,TAU*spin)*Basis(Vector3.RIGHT,TAU*2*spin)*Die.rest_basis()
		Die.draw(fx,at,side,basis,edge,alpha)
		if envelope>.05:
			for sign_value in [-1,1]:
				var center:Vector2=lift+Vector2(sign_value*39,0)
				var start:float=-.72 if sign_value==1 else PI-.72
				fx.draw_arc(center,8+4*envelope,start,start+1.44,14,Color(edge,.5*envelope*alpha),2,true)
		var settle:=clampf((t-.64)/.13,0,1)
		if settle>0 and settle<1:
			for i in range(4):
				book.brush._star(at+Vector2.from_angle(PI*.25+i*PI*.5)*(30+settle*12),3.5*sin(settle*PI),Color(book.ink,.85*sin(settle*PI)),0)
	if t<DISCARD_START:return
	var flow:=clampf((t-DISCARD_START)/(1-DISCARD_START),0,1)
	var count:int=fx.event.get("card_count",0)
	for target in book.visual_targets():
		if count>0:book.stream_cards(book.destination(target.id),book.DISCARD,flow,count)
		elif flow>.1:book.caption(book.DISCARD+Vector2(0,-45),"没有可弃置的牌")
	book.caption(book.DISCARD+Vector2(0,46),"弃牌",smoothstep(0,.2,flow)*.9)
	for i in range(6):book.brush._star(book.DISCARD+Vector2.from_angle(i*TAU/6)*(14+flow*26),4,Color(book.ink,.7*flow),i)

