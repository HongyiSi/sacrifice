extends RefCounted
## Public reward animation, triggered by the actual reward job, never by a guess.
const Symbols=preload("res://scripts/art_symbols.gd")
var fx:Control
func _init(layer:Control)->void:fx=layer
static func supports(event:Dictionary)->bool:
	return event.get("kind","")=="card_effect" and event.get("style","") in ["bounty","glory"] and event.has("reward_source")
func bounty()->bool:return fx.event.style=="bounty"
func friendly()->bool:return int(fx.event.action.actor)/3==fx.mine
func destination()->Vector2:
	var pawn:Vector2=fx._knight(fx.event.action.actor)
	return preload("res://scripts/board_layout.gd").hand_origin(fx.event.action.actor,friendly())+preload("res://scripts/board_layout.gd").hand_size(friendly())/2 if bounty() else Vector2(1012 if friendly() else 429,60)
func reward_position(t:float,i:int)->Vector2:
	var source:Vector2=fx._knight(fx.event.reward_source)
	var pawn:Vector2=fx._knight(fx.event.action.actor)
	var down:=1.0 if friendly() else -1.0
	var start:Vector2=source+Vector2((i-.5)*32,20*down)
	var end:Vector2=destination()+Vector2((i-(int(fx.event.reward_count)-1)*.5)*38 if bounty() else 0,0)
	var side:float=-1 if pawn.x<900 else 1
	var c1:=Vector2(pawn.x+side*240,source.y+80*down) if bounty() else source+Vector2((destination().x-source.x)*.4,-26)
	var c2:=Vector2(pawn.x+side*215,890 if friendly() else 125) if bounty() else destination()+Vector2(0,95)
	# Keep trajectories inside the parchment for the two outer pawn slots.
	c1.x=clampf(c1.x,150,1280);c2.x=clampf(c2.x,150,1280)
	var u:=smoothstep(0,1,t)
	return pow(1-u,3)*start+3*pow(1-u,2)*u*c1+3*(1-u)*u*u*c2+u*u*u*end
func outcome()->String:
	var result:Dictionary=fx.event.targets[0]
	if not bounty():return "荣耀斩杀 · 徽章 +%d"%int(fx.event.reward_count)
	if int(result.amount)>0:return "悬赏达成 · 手牌 +%d"%int(result.amount)
	return "悬赏达成 · "+{"blocked":"摸牌被禁锢","empty":"牌库已空","divinity":"等待神化选牌"}.get(fx.event.get("reward_mode","ready"),result.get("label","未获得手牌"))
func draw(t:float)->void:
	var pawn:Vector2=fx._knight(fx.event.action.actor)
	var end:=destination()
	var tint:=Color("e5bc82") if bounty() else Color("f3cc77")
	var ready:bool=fx.event.get("reward_mode","ready")=="ready"
	if fx.event.stage=="travel":
		if not ready:
			fx._glow(fx.source,tint,20,.4*sin(t*PI))
			fx.result_text(pawn,{"blocked":"悬赏 · 摸牌被禁锢","empty":"悬赏 · 牌库已空","divinity":"悬赏 · 等待神化选牌"}.get(fx.event.reward_mode,"悬赏达成"),tint,t)
			return
		for i in range(int(fx.event.reward_count)):
			var point:=reward_position(t,i)
			fx._glow(point,tint,16,.40)
			if bounty():
				fx.draw_set_transform(point,sin(t*PI)*(.10 if i==0 else -.10))
				var style:=StyleBoxFlat.new();style.bg_color=Color("f0d8a5");style.border_color=Color("996f42");style.set_border_width_all(2);style.set_corner_radius_all(2)
				fx.draw_style_box(style,Rect2(-17,-23,34,46))
				# This is a symbolic card back, never the opponent's drawn identity.
				fx.draw_texture_rect(Symbols.icon("collect","996f42"),Rect2(-12,-14,24,28),false)
				fx.draw_set_transform(Vector2.ZERO)
			else:
				fx.draw_circle(point,24,Color("f3d17d"));fx.draw_arc(point,24,0,TAU,42,Color("815338"),2,true)
				fx.draw_texture_rect(Symbols.icon("badge","815338"),Rect2(point-Vector2(18,18),Vector2(36,36)),false)
	else:
		if ready and (not bounty() or fx.event.targets[0].amount>0):
			fx._glow(end,tint,24,.65*(1-t))
			fx.draw_arc(end,25+t*35,0,TAU,48,Color(tint,1-t),3,true)
		fx.result_text(pawn,outcome(),Color("ffe6a7"),t)
