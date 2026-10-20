extends RefCounted
## Motifs use the very same SVG stamps as their printed cards.
const Layout = preload("res://scripts/board_layout.gd")
var book_ref: WeakRef
var book: RefCounted:
	get: return book_ref.get_ref()
var fx: Control
var key: String
var op: String
var ink: Color

func _init(parent: RefCounted) -> void:
	book_ref = weakref(parent);fx = book.fx;key = book.key;op = book.op;ink = book.ink

func sparkle(at: Vector2, t: float, radius: float = 45) -> void:
	for i in range(8):
		var angle: float = i*TAU/8+.3*t
		book.brush._star(at+Vector2.from_angle(angle)*(12+t*radius),4*(1-t),Color(ink,(1-t)*.8),angle)

func flight(start: Vector2, finish: Vector2, t: float, side: float = 60, which: String = "") -> void:
	var u: float = smoothstep(0,1,t)
	var at: Vector2 = book.bezier(start,finish,u,-45)
	book.trail(start,finish,u,-45,3)
	fx._glow(at,ink,side*.4,.25)
	book.icon(at,side,sin(t*PI)*.09,1,which)

func motion_point(i: int) -> Vector2:
	if i < fx.motion_points.size(): return fx.motion_points[i]
	var motion: Dictionary = fx.event.hand_motion
	var own: bool = int(motion.actor)/3 == fx.mine
	var slots: Array = motion.get("owner_slots",motion.slots)
	return Layout.hand_position(motion.actor,slots[i],own)+Layout.CARD_SIZE*Layout.hand_scale(own)/2

func hand_cards(t: float) -> void:
	var motion: Dictionary = fx.event.get("hand_motion",{})
	var count: int = motion.get("slots",[]).size()
	var actor: int = fx.event.action.actor
	var center: Vector2 = fx._knight(actor)
	var lift: Vector2 = fx.source+Vector2(0,-38)
	if op == "gold_filter":
		book.icon(lift,72,sin(t*TAU*5)*.065)
	elif op == "frenzy":
		book.icon(lift,66,sin(t*TAU*3)*.2)
	else: book.icon(lift,62,0,.6)
	if count == 0:
		book.ring(lift,30+20*t,.6*(1-t),t)
		return
	var spread: float = minf(.34,(count-1)*.055)
	for i in range(count):
		var delay: float = spread*i/maxi(1,count-1)
		var u: float = clampf((t-.16-delay)/(.84-spread),0,1)
		if u <= 0: continue
		var start: Vector2 = motion_point(i)
		var finish: Vector2 = center
		if op == "gold_filter": finish = book.DISCARD
		elif op == "frenzy": finish = fx.source+Vector2((i-(count-1)*.5)*48,-64)
		var at: Vector2 = book.bezier(start,finish,smoothstep(0,1,u),-55)
		var alpha: float = 1-smoothstep(.88,1,u)
		var face: String = fx.motion_faces[i] if i<fx.motion_faces.size() else ""
		var scale_value: float = lerpf(2.1*Layout.hand_scale(int(motion.actor)/3==fx.mine),1,smoothstep(0,.3,u))
		if op == "convert_hand":
			book.little_card(at,sin(u*PI)*.18,1-smoothstep(.2,.48,u),false,scale_value,face)
			book.icon(at,42+sin(u*PI)*9,0,smoothstep(.2,.48,u)*alpha,"cards_to_heart")
			book.trail(start,finish,smoothstep(0,1,u),-55,3)
		elif op == "gold_filter":
			# Only the eligible newly gained cards are represented here.
			book.little_card(at,sin(u*PI)*.28,alpha,false,scale_value,face)
			if u>.35: sparkle(at,(u-.35)/.65,24)
		else:
			book.little_card(at,sin(u*PI)*(i%2*2-1)*.16,alpha,false,scale_value+.15*sin(u*PI),face)
			book.trail(start,finish,smoothstep(0,1,u),-55,2)

func travel(t: float) -> void:
	var actor: int = fx.event.action.actor
	var pawn: Vector2 = fx._knight(actor)
	var lift: Vector2 = fx.source+Vector2(0,-38)
	var risen: Vector2 = fx.source.lerp(lift,smoothstep(0,.22,t))
	if op in ["convert_hand","gold_filter","frenzy"]:
		hand_cards(t);return
	match key:
		"spare_food","spare_supplies":
			var end: Vector2 = book.DECK if op=="draw_invocation" else pawn
			var u: float = smoothstep(0,1,t)
			var at: Vector2 = book.bezier(fx.source,end,u,-75)
			book.trail(fx.source,end,u,-75,4)
			book.icon(at,65,0,1-smoothstep(.4,.75,t))
			book.icon(at,48,0,smoothstep(.4,.75,t),"collect" if op=="draw_invocation" else "cards_to_heart")
			book.ring(end,20+22*t,.6*t,t*2)
		"anticipation":
			book.icon(risen,lerpf(fx.icon_side,72,smoothstep(0,.22,t)),0,1)
			var scan: float = smoothstep(.22,.85,t)
			for point in fx.marked_points:
				var end: Vector2 = risen.lerp(point,scan)
				fx.draw_line(risen,end,Color(ink,.24*sin(t*PI)),2,true)
				book.ring(end,18+8*sin(t*PI),.7*sin(t*PI),t*3)
		"rally","legacy":
			book.icon(risen,72,sin(t*TAU*2)*(.13 if key=="rally" else .04))
			for target in book.visual_targets():
				var end: Vector2 = fx._knight(target.id)+Vector2(0,-25)
				var u: float = smoothstep(.32,1,t)
				if t>.32:
					var at: Vector2 = book.bezier(lift,end,u,-60)
					book.trail(lift,end,u,-60,4)
					if key=="rally":book.icon(at,42,sin(t*TAU*2)*.12)
					else:
						for i in range(3):book.little_card(at+Vector2((i-1)*14,abs(i-1)*5),(i-1)*.17,.9,false,.65)
		"bloodletting","poison":
			var u: float = smoothstep(.18,.72,t)
			flight(risen,pawn+Vector2(0,-12),u,58)
			if t>.65:
				var pulse: float = smoothstep(.65,1,t)
				book.ring(pawn,18+pulse*39,.65*pulse,-t*2)
				for i in range(5):
					var at: Vector2 = pawn+Vector2((i-2)*12,15+pulse*30)
					book.icon(at,12+3*sin(t*PI),0,pulse*.7,"bloodletting" if key=="bloodletting" else "poisoning")
		"gift":
			# Selected cards depart from their actual slots in the following gain.
			book.icon(risen,66,sin(t*PI)*.08)
			var at: Vector2 = book.hand(actor)+Vector2(0,-55)
			var u: float = smoothstep(.28,1,t)
			book.trail(lift,at,u,-35,4)
			for i in range(int(fx.event.get("placed_count",0))):
				book.ring(at+Vector2((i-.5)*37,0),18+6*u,.65*sin(t*PI),t)
		"gold_panning":
			flight(fx.source,book.DECK+Vector2(0,-72),smoothstep(0,.58,t),70)
			if t>.45:
				var at: Vector2 = book.DECK+Vector2(0,-72)
				for i in range(10):
					var u: float = fmod(t*2+i*.13,1)
					book.brush._star(at+Vector2((i%5-2)*12,u*53),3,Color(ink,sin(u*PI)*.8),u)
		"search":
			var scan: Vector2 = book.DECK+Vector2(sin(t*TAU)*25,-55+cos(t*TAU)*10)
			var at: Vector2 = fx.source.lerp(scan,smoothstep(0,.42,t))
			book.icon(at,74,sin(t*TAU)*.10)
			book.ring(book.DECK,35,.6*sin(t*PI),t*2)
		"defile":
			var target: int = fx.event.targets[0].id
			var at: Vector2 = motion_point(0) if op=="defile_seal" else book.hand(target)
			flight(fx.source,at,smoothstep(0,.82,t),64)
			if op=="defile_seal" and t>.75:
				book.ring(at,34+sin(t*PI)*10,smoothstep(.75,1,t),-t*3)
		"obstruct","poisoning":
			book.icon(risen,68,sin(t*TAU*2)*.05)
			var count: int = fx.event.get("placed_count",0)
			for i in range(count):
				var u: float = smoothstep(.28+i*.12,.85+i*.12,t)
				var at: Vector2 = risen+Vector2((i-(count-1)*.5)*65,-sin(u*PI)*35)
				book.icon(at,40*u,t*.12,u,"boulder" if key=="obstruct" else "poison")
				book.ring(at,26*u,sin(u*PI)*.65,t)
		"topaz":
			var at: Vector2 = risen
			book.icon(at,62+5*sin(t*PI),0,1-smoothstep(.6,.94,t))
			if t>.3:flight(at,book.crest(),smoothstep(.3,1,t),49,"badge")
		"emerald":
			flight(fx.source,book.DECK+Vector2(0,-60),smoothstep(0,.7,t),66)
			if t>.5:
				var u: float = smoothstep(.5,1,t)
				for i in range(4):
					book.brush._star(book.DECK+Vector2.from_angle(-PI*.8+i*.55)*(28+u*19),5,Color(ink,u),t)
		"amber","cards_to_heart":
			flight(fx.source,pawn,smoothstep(0,1,t),64)
			book.ring(pawn,25+16*t,.55*t,t)

func impact(t: float) -> void:
	var fade: float = 1-smoothstep(.3,1,t)
	var actor: int = fx.event.action.actor
	if key=="anticipation":
		var success: bool = fx.event.get("succeeded",false)
		for point in fx.marked_points:
			if success:
				book.icon(point,43,0,fade,"suppress")
				book.ring(point,28+12*t,fade*.7,t)
			else: book.ring(point,20+40*t,(1-t)*.3,t)
		return
	if op=="defile_seal":
		var at: Vector2 = motion_point(0)
		book.icon(at,55+8*sin(t*PI),0,fade);sparkle(at,t);return
	if key in ["gift","obstruct","poisoning","search"] or op in ["gold_begin","gold_filter","defile","frenzy"]:
		sparkle(fx.source+Vector2(0,-38),t,30);return
	for target in book.visual_targets():
		var at: Vector2 = book.crest() if key=="topaz" else fx._knight(target.id)
		if op=="draw_invocation" and key in ["emerald","spare_food","spare_supplies"]: at = book.DECK
		if key in ["bloodletting","poison"]:
			book.icon(at+Vector2(0,-30),49,0,fade)
			book.ring(at,15+40*t,fade*.75,-t*2)
			var loss: int = target.get("amount",0)
			if loss>0:fx.result_text(at,"-%d"%loss,Color("bd665c") if key=="bloodletting" else ink,t)
		elif fx.event.kind=="heal":
			if target.get("heal_blocked",false):
				book.icon(at,50,0,fade,"blessing");continue
			var gain: int = target.get("amount",0)
			if gain>0:
				book.ring(at+Vector2(0,22),28+t*32,fade*.7,t)
				for i in range(4):book.icon(at+Vector2((i-1.5)*17,-t*44),20,0,fade*.85,"cards_to_heart")
				fx.result_text(at,"+%d"%gain,ink,t)
		else:
			book.ring(at,28+35*t,fade*.65,t);sparkle(at,t)
			if key=="rally":book.icon(at+Vector2(0,-37),43,0,fade)
			elif key=="legacy":book.icon(at+Vector2(0,-35),43,0,fade)
			elif key=="topaz":book.icon(at,44,0,fade,"badge")
