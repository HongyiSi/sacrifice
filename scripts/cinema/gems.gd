extends RefCounted
var f
func update():
	if f.kind=="gem_trigger" and f.stage=="impact" and f.key in ["ruby","amethyst"]:f.react(f.actor,f.t,.9,true)
func draw():
	var u=f.u;var transfer=f.kind=="hand_transfer";var travel=f.stage=="travel"
	var c=Color({"sapphire":"69bedd","ruby":"dc6372","amethyst":"b79ae8","topaz":"edc35f","emerald":"63c493","amber":"e6b26b"}.get(f.key,"b9cbe4"))
	if transfer:
		var destination=f.landing(int(f.event.get("recipient",f.target_ids[0])))
		var v=f.smooth(.22,.93,u) if travel else 1.0
		var p=f.bezier(f.source,destination,v,-82);var a=f.smooth(0,.10,u) if travel else 1-f.smooth(.05,.75,u)
		f.stream(f.source,p,1,12,c,a*.52,-44)
		f.prop(f.key,p,lerpf(66,55,f.smooth(.80,1,v)),sin(v*PI)*.32,a,Vector2(.86+.14*absf(cos(v*TAU)),1+.08*sin(v*TAU)))
		if not travel:f.ellipse(destination,35+u*28,8+u*6,Color(c,(1-u)*.5))
		return
	var top=f.pawn(f.actor)+Vector2(0,-73)
	var p=f.bezier(f.source,top,f.smooth(0,.33,u),-22) if travel else top
	var a=1.0
	if f.stage in ["return","discard"]:
		var end=f.DISCARD if f.stage=="discard" else f.source
		p=f.bezier(top,end,f.smooth(0,1,u),-36);a=1-f.smooth(.74,1,u)
	var expand=f.smooth(.35,.75,u) if travel else 1-f.smooth(.55,1,u)
	f.shadow(p+Vector2(0,44),31,.13*a)
	if f.key=="amethyst":
		for h in [-1,1]:f.prop_half(f.key,p,96,h,Vector2(h*16*expand,-7*expand),h*.13*expand,a*.85)
	else:f.prop(f.key,p,94,0,a,Vector2(.84+.16*absf(cos(f.t*2.3)),1+.06*sin(f.t*8)))
	f.glow(p,84,.23*a)
	if travel:
		if f.key=="sapphire":
			for i in range(3):f.ellipse(p+Vector2(0,30-i*17),44*expand,10*expand,Color(c,expand*(.5-i*.08)))
			if u>.55:f.stream(p,f.DECK,f.smooth(.55,1,u),13,c,.65,-50)
		elif f.key=="ruby":
			var dest=f.pawn(f.actor)+Vector2(0,48)
			f.stream(p,dest,expand,18,c,.7,25)
			f.coil(dest,48,108,u*3,expand,.72,c,1.4)
		elif f.key=="amethyst":
			var soul=f.pawn(f.actor)+Vector2(0,-125+78*f.smooth(.56,1,u))
			f.prop("ghost",soul,68,0,expand,Vector2(.9,1+.15*sin(u*8)))
			for h in [-1,1]:f.stream(p+Vector2(h*18,0),f.pawn(f.actor)+Vector2(h*15,32),expand,12,c,.55,-30)
	elif f.stage=="impact":
		var q=f.pawn(f.actor);var pulse=1-f.smooth(.42,1,u)
		if f.key=="sapphire":
			for i in range(2):f.ellipse(f.DECK,42+u*38+i*12,13+u*8+i*4,Color(c,pulse*.6))
		elif f.key=="ruby":
			f.prop("heart",q+Vector2(0,-31-13*u),48,0,pulse,Vector2.ONE*(1+.12*sin(u*TAU*2)))
			f.coil(q+Vector2(0,51),46,98,-u*2,1,pulse*.7,c)
			f.label_at(q+Vector2(62,-40),"+2",Color("ffe3e0"),pulse,23)
		else:
			for h in [-1,1]:f.leaf(q+Vector2(h*12,48),72*f.spring(minf(1,u*3)),-PI/2+h*.38,c,pulse,.22)
			f.glow(q,110,pulse*.34,c)
