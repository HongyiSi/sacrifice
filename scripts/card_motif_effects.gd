extends "res://scripts/card_effects.gd"
## Every branch is keyed to a real card and a real resolution event.
const Palette=preload("res://scripts/card_palette.gd")
const Symbols=preload("res://scripts/art_symbols.gd")
var key:String
var op:String
var gambler_dice:RefCounted
var collect_launch:RefCounted
var new_effect:RefCounted
const DECK=preload("res://scripts/board_layout.gd").DECK_CENTER
const DISCARD=Vector2(1280,533)
const WARCRY_RISE_END := 0.18
const WARCRY_BLOW_END := 0.58
func _init(layer:Control)->void:
	if not layer.event.has("motif"):layer.event.motif=""
	if not layer.event.has("color"):layer.event.color=Palette.glow(layer.event.get("style","defense")).to_html(false)
	super(layer)
	key=fx.event.get("style","");op=fx.event.get("op","")
	ink=Palette.glow(key)
	if key in preload("res://scripts/card_effect_styles.gd").NEW_CARDS:new_effect=preload("res://scripts/new_card_effects.gd").new(self)
	if key=="collect" and op=="collect_launch":collect_launch=preload("res://scripts/collect_launch.gd").new(self)
	if key=="gambler" and op=="discard_all":gambler_dice=preload("res://scripts/gambler_dice.gd").new(self)
func icon(at:Vector2,side:float,angle:float=0,alpha:float=1,which:String="")->void:
	var glyph:String=key if which.is_empty() else which
	fx.draw_set_transform(at+Vector2(2,3),angle)
	fx.draw_texture_rect(Symbols.icon(glyph,"514134"),Rect2(-side/2,-side/2,side,side),false,Color(1,1,1,alpha*.22))
	fx.draw_set_transform(at,angle)
	fx.draw_texture_rect(Symbols.icon(glyph,Palette.ink(glyph)),Rect2(-side/2,-side/2,side,side),false,Color(1,1,1,alpha))
	fx.draw_set_transform(Vector2.ZERO)
func hand(id:int)->Vector2:
	var layout=preload("res://scripts/board_layout.gd")
	return layout.hand_origin(id,id/3==fx.mine)+layout.hand_size(id/3==fx.mine)/2
func death_fan(id:int)->Vector2:return Vector2(454+(id%3)*390,587) if id/3==fx.mine else preload("res://scripts/board_layout.gd").death_origin(id,false)+Vector2(60,27)
func crest()->Vector2:return Vector2(1090 if int(fx.event.action.actor)/3==fx.mine else 403,60)
func bezier(a:Vector2,b:Vector2,t:float,bend:float=-48)->Vector2:
	return a.lerp(b,t)+Vector2(0,sin(t*PI)*bend)
func trail(a:Vector2,b:Vector2,t:float,bend:float=-48,width:float=3)->void:
	for i in range(9,0,-1):
		var p:Vector2=bezier(a,b,maxf(0,t-i*.025),bend)
		var q:Vector2=bezier(a,b,maxf(0,t-(i-1)*.025),bend)
		fx.draw_line(p,q,Color(ink,(1-i/10.0)*.6),width,true)
func ring(at:Vector2,r:float,alpha:float,t:float=0)->void:
	fx.draw_arc(at,r,t,t+TAU*.87,50,Color(ink,alpha),2.5,true)
	for i in range(4):brush._star(at+Vector2.from_angle(i*PI/2+t)*r,4,Color(ink,alpha),t)
func little_card(at:Vector2,angle:float=0,alpha:float=1,death:bool=false,scale_value:float=1,face:String="")->void:
	fx.draw_set_transform(at,angle,Vector2.ONE*scale_value)
	var box:=StyleBoxFlat.new();box.bg_color=Color("3d3347" if death else "343742")*Color(1,1,1,alpha)
	box.border_color=Color("a993b8" if death else "d1b478")*Color(1,1,1,alpha);box.set_border_width_all(2);box.set_corner_radius_all(2)
	if not face.is_empty():box.bg_color=Color("f4e5c7")*Color(1,1,1,alpha)
	fx.draw_style_box(box,Rect2(-18,-25,36,50))
	fx.draw_texture_rect(Symbols.icon(("death" if death else "back") if face.is_empty() else face,"d7bd91" if face.is_empty() else Palette.ink(face)),Rect2(-13,-13,26,26),false,Color(1,1,1,alpha))
	fx.draw_set_transform(Vector2.ZERO)
func caption(at:Vector2,text:String,alpha:float=1)->void:
	var font:Font=fx.get_theme_font("font")
	var width:float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+18
	var box:=StyleBoxFlat.new();box.bg_color=Color("f4e6cc")*Color(1,1,1,.95*alpha);box.border_color=Color(ink.darkened(.3),alpha);box.set_border_width_all(1);box.set_corner_radius_all(5)
	fx.draw_style_box(box,Rect2(at-Vector2(width/2,17),Vector2(width,32)))
	fx.draw_string(font,at+Vector2(-width/2+9,6),text,HORIZONTAL_ALIGNMENT_CENTER,width-18,17,Color("4c4138")*Color(1,1,1,alpha))
func stream_cards(start:Vector2,end:Vector2,t:float,n:int,death:bool=false,face:String="")->void:
	var delay:float=minf(.045,.55/maxi(1,n-1))
	for i in range(n):
		var u:float=clampf((t-i*delay)/(1-maxi(0,n-1)*delay),0,1)
		if u<=0 or u>=1:continue
		var offset:=Vector2((i-(n-1)*.5)*minf(19,130.0/maxi(1,n-1)),0)
		var at:Vector2=bezier(start+offset*.3,end+offset,u,-60)
		trail(start+offset*.3,end+offset,u,-60,2)
		little_card(at,sin(u*PI)*(i-(n-1)*.5)*.10,1,death,1,face)
func draw(t:float,impact_stage:bool)->void:
	if impact_stage:impact(t)
	else:travel(t)
func destination(id:int)->Vector2:
	if fx.target_point!=Vector2.ZERO:return fx.target_point
	if key in ["badge","sacrifice_badges"] or op=="badges":return crest()
	if op in ["draw","draw_death","discard_all","plunder","curse_move","strip","curse_after"]:
		return death_fan(id) if op in ["strip","curse_after","draw_death"] else hand(id)
	if fx.event.get("flow","")=="out":return hand(id)
	return fx._knight(id)
func visual_targets()->Array:
	if fx.event.has("guard_target"):
		var recipients:Array=[]
		for id in fx.event.get("affected_targets",[fx.event.guard_target]):recipients.append({"id":id})
		return recipients
	return fx.event.targets
func dissolving()->bool:
	return fx.event.get("effect_state","")=="removed" or (key=="immortal" and fx.event.has("revived") and not fx.event.revived)
func dissolve(t:float,impact_stage:bool)->void:
	for target in visual_targets():
		var at:Vector2=fx._knight(target.id)
		if not impact_stage:
			icon(at,62,0,1-t)
			for i in range(6):brush._star(at+Vector2.from_angle(i*TAU/6)*(20+t*37),6*(1-t),Color(ink,1-t),t)
		else:fx.result_text(at,target.get("label","持续效果解除"),ink,t)
func warcry_position(t:float,target:Vector2)->Vector2:
	var lift:Vector2=fx.source+Vector2(0,-38)
	if t<WARCRY_RISE_END:return fx.source.lerp(lift,smoothstep(0,WARCRY_RISE_END,t))
	if t<WARCRY_BLOW_END:return lift
	var flight:float=clampf((t-WARCRY_BLOW_END)/(1-WARCRY_BLOW_END),0,1)
	return bezier(lift,target,pow(flight,1.3),-38)

func _warcry(t:float)->void:
	var rise:float=smoothstep(0,WARCRY_RISE_END,t)
	var side:float=lerpf(fx.icon_side,66,rise)
	var lift:Vector2=fx.source+Vector2(0,-38)
	var blowing:bool=t>=WARCRY_RISE_END and t<WARCRY_BLOW_END
	var blow:float=clampf((t-WARCRY_RISE_END)/(WARCRY_BLOW_END-WARCRY_RISE_END),0,1)
	var envelope:float=sin(blow*PI) if blowing else 0.0
	var angle:float=sin(blow*TAU*4)*0.035*envelope
	for target in visual_targets():
		var at:Vector2=destination(target.id)
		var point:Vector2=warcry_position(t,at)
		if blowing:
			# Hold the horn in place while three finite waves leave its bell.
			var bell:Vector2=point+(Vector2(21,-9)*side/64).rotated(angle)
			fx._glow(bell,ink,20,.35*envelope)
			for i in range(3):
				var wave:float=(blow-i*.22)/.52
				if wave<=0 or wave>=1:continue
				var radius:float=10+wave*52
				var alpha:float=sin(wave*PI)*.95
				fx.draw_arc(bell,radius,-.96+angle,.46+angle,32,Color(ink,alpha*.16),8,true)
				fx.draw_arc(bell,radius,-.96+angle,.46+angle,32,Color(Palette.ink(key),alpha),3.4,true)
		elif t>=WARCRY_BLOW_END:
			var flight:float=clampf((t-WARCRY_BLOW_END)/(1-WARCRY_BLOW_END),0,1)
			trail(lift,at,pow(flight,1.3),-38,4)
			ring(point,43,.72*smoothstep(0,.16,flight),t*2)
		icon(point,side*(1+.035*envelope),angle)

func travel(t:float)->void:
	if new_effect!=null:new_effect.travel(t);return
	if dissolving():dissolve(t,false);return
	if collect_launch!=null:collect_launch.draw(t,false);return
	if gambler_dice!=null:gambler_dice.draw(t);return
	if key=="warcry":_warcry(t);return
	var rise:float=smoothstep(0,.26,t)
	var lift:Vector2=fx.source+Vector2(0,-38)
	var origin:Vector2=fx.source.lerp(lift,rise)
	fx._glow(origin,ink,21,.45*(1-smoothstep(.22,.6,t)))
	if key in ["ignore","reverse","skip_death"]:
		_temporal(t,false);return
	for target in visual_targets():
		var at:Vector2=destination(target.id)
		var u:float=clampf((t-.30)/.70,0,1)
		var point:Vector2=origin if t<.3 else bezier(lift,at,pow(u,1.3),-38)
		var side:float=lerpf(fx.icon_side,66,rise)
		# Draw/discard/transfer animate exact, finite counts, not an endless shower.
		if op in ["draw","draw_death","discard_all","plunder","strip","curse_after","curse_move"] or (fx.event.get("flow","")=="out"):
			var out:bool=op in ["discard_all","strip","curse_after"] or fx.event.get("flow","")=="out"
			var n:int=int(fx.event.get("card_count",1))
			var send:float=smoothstep(.25,.45,t)
			var glyph:Vector2=origin.lerp(DECK,send) if not out and op not in ["plunder","curse_move"] else origin
			if t<.46:icon(glyph,side*(1-.3*send),sin(t*PI)*.12);ring(glyph,37,.55*sin(t*PI),t)
			var start:Vector2=at if out or op=="plunder" else DECK
			var finish:Vector2=DISCARD if out else hand(fx.event.action.actor) if op=="plunder" else at
			if op=="curse_move":start=lift
			var flow:float=clampf((t-.44)/.56,0,1)
			if fx.event.get("draw_mode","")=="blocked":
				var stop:Vector2=finish+Vector2(0,-72 if int(target.id)/3==fx.mine else 72)
				var p:Vector2=bezier(start,stop,minf(flow*1.6,1),-45)
				if flow>.62:p=p.lerp(start,(flow-.62)/.38)
				little_card(p,flow*.8,1,false)
				if flow>.6:caption(stop,"禁锢 · 无法摸牌")
			elif fx.event.get("draw_mode","")=="divinity":
				if t>.4:ring(DECK,37,.8,t*3);caption(DECK+Vector2(0,50),"神化接管选牌")
			elif n==0:
				if t>.45:caption(finish+Vector2(0,-45),"没有可转移的牌" if op=="plunder" else "没有可弃置的牌" if out else "牌库已空")
			elif t>=.44:
				stream_cards(start,finish,flow,n,op in ["draw_death","strip","curse_after","curse_move"],"curse" if op=="curse_move" else "")
			if not out and op not in ["plunder","curse_move"]:
				little_card(DECK,0,.9,op=="draw_death",1.05)
				caption(DECK+Vector2(0,-44),"亡语牌库" if op=="draw_death" else "普通牌库",.9)
			if out:
				for i in range(6):brush._star(DISCARD+Vector2.from_angle(i*TAU/6)*(14+u*26),4,Color(ink,.7*u),i)
				caption(DISCARD+Vector2(0,46),"弃牌",.9)
			continue
		if op=="life_after" and fx.event.has("drain_source"):
			var victim:Vector2=fx._knight(fx.event.drain_source)
			var progress:float=smoothstep(.25,1,t)
			point=bezier(victim,at,progress,45)
			trail(victim,at,progress,45,5);fx._glow(point,ink,26,.75);icon(point,58)
			ring(at+Vector2(0,33),43,.7*t,t)
			continue
		if key in ["heal_other","team_heal","blood_rite"]:
			if t>.30:trail(lift,at,pow(u,1.3),-38,5)
			fx._glow(point,ink,29,.70);icon(point,side*.86)
			for i in range(5):brush._star(point+Vector2.from_angle(t*6+i*TAU/5)*29,4,Color(ink,.85),i)
		elif key in ["holy_amulet","attack_amulet","magic_amulet","blessing"]:
			if t>.3:trail(lift,at,pow(u,1.3),-38,4)
			icon(point,side);ring(point,42,.55,t)
			if u>.68:_ward(at,(u-.68)/.32,.65)
		elif key in ["badge","sacrifice_badges"] or op=="badges":
			var n:int=2 if key=="sacrifice_badges" else 1
			for i in range(n):
				var q:Vector2=point+Vector2((i-(n-1)*.5)*42*sin(t*PI),0)
				trail(lift+Vector2(i*18,0),at,pow(u,1.3),-38)
				fx.draw_circle(q,23,Color("785e38"));fx.draw_circle(q,20,Color(ink,.92));icon(q,30,0,1,"badge")
		elif key=="judgment":
			if t<.60:icon(origin,side);ring(origin,39,.65,t)
			var above:Vector2=at+Vector2(0,-70)
			if not target.get("miss",false):brush._blade(above.lerp(at,pow(clampf((t-.5)/.5,0,1),2)),0,1.0,ink)
			caption(at+Vector2(105,-32),"生命 > 2 · 判定未满足" if target.get("miss",false) else "生命 ≤ 2",smoothstep(.1,.4,t))
		elif key=="death_sentence":
			trail(lift,at,pow(u,1.3),-38,4);fx._glow(point,ink,24,.55);icon(point,90,lerpf(-.6,.4,u))
		elif key=="last_dance":
			var hit:int=fx.event.action.get("hits",1)
			for i in range(5):
				var p:Vector2=lift+Vector2((i-2)*22,0)
				if i==hit-1 and t>.3:p=bezier(p,at,pow(u,1.2),-45)
				brush._star(p,11,Color(ink,1.0 if i>=hit-1 else .2),i+t*2)
			caption(lift+Vector2(0,42),"舞步 %d / 5"%hit)
		elif key=="life_steal" and fx.event.kind=="death_strike":
			trail(lift,at,pow(u,1.3),-38,4);icon(point,side);ring(at,39,.6*u,-t*2)
		elif key=="immortal" or key in ["raise_dead","resurrection"] or op=="life_after":
			trail(lift,at,pow(u,1.3),-65,5);icon(point,side);fx._glow(point,ink,31,.65)
			if u>.55:ring(at+Vector2(0,33),46,(u-.55)*1.5,t)
		elif key in ["peek","eye","prophecy"]:
			trail(lift,at,pow(u,1.3),-38,2.5);icon(point,side)
			for i in range(2):fx.draw_arc(point,side*.55+i*8,-t,t+PI*1.3,40,Color(ink,.40),2,true)
		elif key in ["mirror","suppress","late_suppress","silence","prison"]:
			trail(lift,at,pow(u,1.3),-38,3);icon(point,side,sin(u*PI)*.18)
			if key in ["suppress","late_suppress","prison"]:
				for i in range(6):
					var v:Vector2=bezier(lift,at,maxf(0,u-i*.03),-38)
					fx.draw_arc(v,7,0,TAU,14,Color(ink,.65*(1-i/7.0)),2,true)
		elif key in ["overload","greed","privilege","divinity"]:
			trail(lift,at,pow(u,1.3),-38,4);icon(point,side);ring(point,43,.72,t*2)
			for i in range(3):brush._star(point+Vector2.from_angle(i*TAU/3-t*3)*34,5,Color(ink,.85),i)
		elif key in ["ghost","pain","feign","curse","heart"]:
			trail(lift,at,pow(u,1.3),-38,4);icon(point,side,sin(t*PI)*.15);fx._glow(point,ink,26,.50)
		else:
			trail(lift,at,pow(u,1.3),-38,3);icon(point,side);ring(point,34,.5,t)
func _ward(at:Vector2,growth:float,alpha:float)->void:
	var p:=PackedVector2Array()
	for v in [Vector2(0,-55),Vector2(44,-35),Vector2(35,25),Vector2(0,52),Vector2(-35,25),Vector2(-44,-35)]:p.append(at+v*growth)
	fx.draw_colored_polygon(p,Color(ink,.12*alpha));p.append(p[0]);fx.draw_polyline(p,Color(ink,alpha),3.5,true)
	fx.draw_line(at+Vector2(0,-30)*growth,at+Vector2(0,28)*growth,Color(ink,alpha*.7),2,true)
func _temporal(t:float,hit:bool)->void:
	var at:=Vector2(733,395)
	if not hit:icon(fx.source.lerp(at,smoothstep(0,.55,t)),70,t*PI*(1 if key=="reverse" else .1))
	else:ring(at,53,.7*(1-t),t*2)
	if key=="skip_death":
		for i in range(3):
			var p:=at+Vector2((i-1)*61,95)
			little_card(p,0,.65,true)
			fx.draw_line(p-Vector2(15,19),p+Vector2(15,19),Color(ink,.9),3,true)
		caption(at+Vector2(0,145),"本轮亡语暂停")
		return
	var ignored: Array = fx.event.get("values",[int(fx.event.get("value",5))])
	for i in range(11):
		var value:int=i if fx.event.get("reverse_from",false) else 10-i
		var x:float=lerpf(532+i*40,532+(10-i)*40,smoothstep(.25,.95,t)) if key=="reverse" and not hit else 532+(10-i)*40 if key=="reverse" else 532+i*40
		var p:=Vector2(x,490)
		var color:Color=ink if not ignored.has(value) or key!="ignore" else Color("9b5149")
		fx.draw_circle(p,15,Color(color,.20));fx.draw_arc(p,15,0,TAU,24,Color(color,.8),1.5,true)
		var font:Font=fx.get_theme_font("font");fx.draw_string(font,p+Vector2(-12,6),str(value),HORIZONTAL_ALIGNMENT_CENTER,24,16,Color("564538"))
		if key=="ignore" and ignored.has(value) and (hit or t>.6):fx.draw_line(p-Vector2(13,-13),p+Vector2(13,-13),Color("a05049"),3,true)
	caption(Vector2(732,535),"本轮主优先级顺序反转" if key=="reverse" else "本回合跳过主优先级 %s" % "、".join(ignored.map(func(v):return str(v))))
func impact(t:float)->void:
	if new_effect!=null:new_effect.impact(t);return
	if dissolving():dissolve(t,true);return
	if collect_launch!=null:collect_launch.draw(t,true);return
	var fade:float=1-smoothstep(.62,1,t)
	if key in ["ignore","reverse","skip_death"]:_temporal(t,true);return
	for target in visual_targets():
		var at:Vector2=destination(target.id)
		var knight:Vector2=fx._knight(target.id)
		var label:String=target.get("label","")
		if fx.event.kind=="death_strike":
			label="-%d 生命"%target.get("amount",0)
			if key=="last_dance":label="第 %d / 5 次 · -%d"%[fx.event.action.get("hits",1),target.get("amount",0)]
			if target.get("before",0)==0:label="目标已阵亡" + (" · 苦肉触发" if target.get("pain",false) else "")
			elif target.get("revived",false):label+=" · 已立刻复活"
			elif target.get("after",1)==0:label+=" · 阵亡"
		if op in ["draw","draw_death","discard_all","strip","curse_after","plunder","curse_move"] or fx.event.get("flow","")=="out":
			ring(at,33+24*t,.75*fade,t)
			if key=="curse":
				for i in range(6):fx.draw_arc(at+Vector2((i-2.5)*12,20),7,0,TAU,18,Color(ink,fade),2.5,true)
			fx.result_text(knight,label,ink,t);continue
		match key:
			"heal_other","team_heal","blood_rite":
				if target.get("heal_blocked",false):
					_ward(knight,1.0+.08*sin(t*PI),fade)
					for i in range(5):
						var spark:Vector2=knight+Vector2.from_angle(i*TAU/5)*(23+35*t)
						fx.draw_line(spark-Vector2(3,3),spark+Vector2(3,3),Color(ink,fade),2.5,true)
					fx.result_text(knight,"上限 +2 · 保佑阻止回复" if target.get("max_bonus",0)>0 else "保佑 · 无法回复生命",Color("f0d7a3"),t)
					continue
				if target.get("after",0)<=0 and target.get("max_bonus",0)>0:
					ring(knight+Vector2(0,29),35+t*21,.8*fade,t)
					fx.result_text(knight,"上限 +2 · 保持阵亡",ink,t)
					continue
				fx._glow(knight,ink,32,.7*fade);ring(knight+Vector2(0,29),35+t*21,.8*fade,t)
				for i in range(7):
					var p:Vector2=knight+Vector2((i-3)*16,28-t*72-sin(i)*9)
					fx.draw_line(p-Vector2(4,0),p+Vector2(4,0),Color(ink,fade),2.5,true);fx.draw_line(p-Vector2(0,4),p+Vector2(0,4),Color(ink,fade),2.5,true)
				label="+%d 生命"%target.get("amount",0) if target.get("amount",0)>0 else "生命已满"
				if target.get("max_bonus",0)>0:label="上限 +2 · 回满生命" if target.get("after",0)>0 else "上限 +2 · 保持阵亡"
			"holy_amulet","attack_amulet","magic_amulet","blessing":
				_ward(knight,1+.055*sin(t*PI),fade)
				for i in range(6):brush._star(knight+Vector2.from_angle(i*TAU/6)*(30+25*t),6*fade,Color(ink,fade),i)
				label="护符发动 · 整张牌取消" if key!="blessing" else "攻击免疫 · 无法回复"
			"badge","sacrifice_badges":
				ring(crest(),20+t*25,.9*fade,t);brush._crown(crest(),16,fade)
				label="+2 枚胜利徽章" if key=="sacrifice_badges" else "+1 枚胜利徽章"
			"mirror":
				for dx in [-24,24]:
					fx.draw_arc(at+Vector2(dx,0),48,0,TAU,60,Color(ink,fade),3,true)
					fx.draw_line(at+Vector2(dx-20,27),at+Vector2(dx+20,-27),Color(ink,.7*fade),4,true)
				if fx.event.has("copied_key"):little_card(at+Vector2(80*t,0),0,fade,false,1.2,fx.event.copied_key)
			"suppress","late_suppress","silence","prison":
				var old:String=motif;motif="chains" if key=="prison" else "seal";_symbol(at,t,fade);motif=old
				if key in ["suppress","late_suppress"]:caption(at+Vector2(0,74),"压制已施放",fade)
			"prophecy":
				if op=="badges":ring(crest(),24+30*t,.8*fade,t)
				else:_eye(at+Vector2(0,-40),t,fade)
			"peek","eye":
				_eye(at+Vector2(0,-34),t,fade)
				var scan:Vector2=hand(target.id)
				fx.draw_line(scan+Vector2(-72,-22+44*t),scan+Vector2(72,-22+44*t),Color(ink,.85*fade),3,true)
			"overload":
				for i in range(3):
					var p:Vector2=knight+Vector2((i-1)*40,-30)
					fx._glow(p,ink,14,.5*fade);icon(p,32,0,fade)
			"immortal","raise_dead","resurrection":
				var old:String=motif;motif="phoenix" if key=="immortal" else "revive";_symbol(knight,t,fade);motif=old
				icon(knight+Vector2(0,-24),54,0,fade*.55);ring(knight+Vector2(0,30),39+20*t,.8*fade,t)
			"life_steal":
				if op=="life_after":
					var old:String=motif;motif="revive";_symbol(knight,t,fade);motif=old
				else:
					_heart(knight,1.5,fade);brush._burst(knight,t,ink)
			"death_sentence":
				icon(knight,96,lerpf(-.7,.7,smoothstep(0,.25,t)),1-smoothstep(.2,.6,t))
				brush._slash(knight,.7,.15+t*.85,ink,18);_soul(knight+Vector2(0,-t*42),t,fade*.7)
			"last_dance":
				brush._slash(knight,[-.7,.7,0.0,PI/2,-.7][int(fx.event.action.get("hits",1))-1],.2+t*.8,ink,10)
				brush._star(knight,25*(1-t),Color(ink,fade),t)
			"ghost":
				_soul(knight+Vector2(0,-t*18),t,fade);ring(knight+Vector2(0,28),38,.7*fade,-t)
			"pain":
				var old:String=motif;motif="thorns";_symbol(knight,t,fade);motif=old
			"feign":
				if op=="lose_hp":label="失去 2 点生命";_heart(knight,1.6,fade)
				else:
					for i in range(3):_soul(death_fan(fx.event.action.actor)+Vector2((i-1)*30,-t*50),t,fade)
			"heart":
				_heart(knight,1.6+.2*sin(t*TAU*2),fade)
				little_card(bezier(fx.source,death_fan(target.id),smoothstep(0,.65,t),-50),t*.1,1-t,true,1.2)
			"curse":
				var old:String=motif;motif="curse";_symbol(knight,t,fade);motif=old
			"divinity":
				ring(knight,48,fade,t);icon(knight,65,t*.5,fade)
				for i in range(3):little_card(knight+Vector2((i-1)*38,-27),0,fade,false,.8)
			"privilege":
				brush._crown(knight+Vector2(0,-42),25,fade)
				caption(knight+Vector2(103,-25),"优先级 +100",fade)
			"death":_soul(knight+Vector2(0,-t*35),t,fade)
			"judgment":pass # The original sword/scale impact is drawn underneath.
			_:ring(at,30+24*t,fade,t)
		if label!="" and (not fx.event.has("guard_target") or target.id==fx.event.guard_target):fx.result_text(knight,label,ink,t)
