extends RefCounted
var f
func progress():return f.u if f.stage=="travel" else 1.0
func alpha():return f.smooth(0,.10,f.u) if f.stage=="travel" else 1-f.smooth(.38,1,f.u)
func podium():return f.source+Vector2(35,-39*f.spring(minf(1,progress()/.30)))
func update():
	if f.key in ["warcry","rally"] and f.stage=="impact":
		for id in f.target_ids:f.react(id,f.t,1.1,true)
func draw():
	match f.key:
		"prophecy":book()
		"mirror":mirror()
		"reverse":armillary()
		"ignore":bookmarks()
		"skip_death":hourglass()
		"suppress","late_suppress":seal()
		"anticipation","peek":observe()
		"silence":bell()
		"defile":ink()
		"warcry":horn()
		"rally":flag()
		"overload":coil()
		"poison":poison()
func book():
	var u=progress();var a=alpha();var p=podium();var opened=f.smooth(.16,.38,u)
	f.shadow(p+Vector2(0,48),54,a*.15)
	f.prop("book_closed",p,135,-.1,a*(1-opened),Vector2(1,1-.08*sin(u*PI)))
	f.prop("prophecy",p,145,0,a*opened)
	for i in range(4):
		var v=clampf((u-.30-i*.09)/.20,0,1)
		if v<=0 or v>=1:continue
		var wing=Vector2(cos(v*PI)*54,-sin(v*PI)*35)
		var pts=PackedVector2Array([p+Vector2(0,-25),p+wing+Vector2(0,-31),p+wing+Vector2(2,26),p+Vector2(0,19)])
		f.draw_colored_polygon(pts,Color("f8eccc",a));f.line(pts,Color("b69b70",a),1.6)
	var reveal=f.smooth(.67,.84,u)
	f.glow(p+Vector2(0,-54),67,a*reveal*.24,Color("9fdbdf"))
	f.label_at(p+Vector2(0,-42-8*sin(u*PI)),str(f.event.get("value",8)),Color("fff0c8"),a*reveal,42)
	if u>.75:
		var pts=PackedVector2Array()
		for i in range(35):
			var v=float(i)/34;pts.append(p+Vector2(42-v*68,-29+sin(v*PI)*11))
		f.ribbon(pts,6,a*f.smooth(.75,.95,u),Color("b67670"))
func mirror():
	var u=progress();var a=alpha();var p=podium()+Vector2(0,-3)
	var copied=f.event.get("copied_key","");var target=f.target_point if f.target_point!=Vector2.ZERO else f.source+Vector2(120,0)
	f.prop("mirror",p,155,-.08*sin(u*10),a,Vector2(.50+.50*f.smooth(.08,.36,u),1))
	var glass=p+Vector2(0,-21)
	if copied=="":
		var v=f.smooth(.35,.78,u)
		f.stream(target,glass,v,11,Color("9bcbdc"),a*.65,-26)
		f.little_card(f.bezier(target,glass,v,-26),-.13*(1-v),lerpf(1.2,.64,v),a*v)
	else:
		var reveal=f.smooth(.18,.45,u)
		f.prop(copied,glass,47,0,a*reveal,Vector2(.92,1))
		for i in range(3):f.ellipse(glass,24+i*7+u*3,33+i*4,Color("c2e4df",a*(1-f.smooth(.3+i*.1,.6+i*.1,u))*.5))
		var v=f.smooth(.52,.93,u);var q=f.bezier(glass,f.source+Vector2(113,-4),v,-38)
		f.little_card(q,.12*sin(v*PI),.62+.65*v,a*f.smooth(.48,.56,u),copied)
		f.stream(glass,q,1,12,Color("b2d7e0"),a*.55,-27)
func armillary():
	var age=preload("res://scripts/reverse_timing.gd").age(f.event,f.elapsed)
	preload("res://scripts/cinema/reverse_armillary.gd").draw(f,f.source,age)
func bookmarks():
	var u=progress();var a=alpha();var p=podium();var values=f.event.get("values",[5,0])
	for i in range(6):
		var q=p+Vector2((i-2.5)*31,37);var selected=i in values
		var shrink=f.smooth(.50,.87,u) if selected else 0.0
		f.draw_style_box(card_box(a*(1-shrink*.7)),Rect2(q-Vector2(13,17*(1-shrink*.7)),Vector2(26,34*(1-shrink*.7))))
		f.label_at(q+Vector2(0,6),str(i),Color("e0cfac"),a*(1-shrink),19)
	f.prop("ignore",p+Vector2(0,-18),109,sin(u*10)*.08,a)
	for j in range(values.size()):
		var q=p+Vector2((int(values[j])-2.5)*31,37);var v=f.smooth(.27+j*.13,.72+j*.1,u)
		f.stream(p,q,v,9,Color("bd83a3"),a*.8,0)
func card_box(a):
	var b=StyleBoxFlat.new();b.bg_color=Color("50434a",a);b.border_color=Color("c7ab75",a);b.set_border_width_all(1);b.set_corner_radius_all(3);return b
func hourglass():
	var u=progress();var a=alpha();var p=podium();var rotate=PI*f.smooth(.16,.58,u)
	f.prop("skip_death",p,144,rotate,a)
	var stop=f.smooth(.61,.8,u)
	var top=p+Vector2(0,-25).rotated(rotate);var bottom=p+Vector2(0,25).rotated(rotate)
	var points=PackedVector2Array([top,p,bottom]);f.line(points,Color("f6d998",a*(1-stop)*.8),2.2)
	if stop>0:
		f.ellipse(p,65,78,Color("a68ecb",a*stop*.12),0,true)
		for h in [-1,1]:f.stream(p+Vector2(h*60,-35),p+Vector2(h*60,56),stop,17,Color("9680ba"),a*.55,0)
		f.ellipse(p,66,79,Color("d1bae8",a*stop*.70))
func seal():
	preload("res://scripts/suppression_pose.gd").draw_flight(f)
func observe():
	var u=progress();var a=alpha();var p=podium();var telescope=f.key=="anticipation"
	var dest=f.hand(f.target_ids[0])+Vector2(0,-10)
	if telescope:
		f.prop("anticipation",p,141,-.3+sin(u*PI)*.38,a,Vector2(1+.18*f.smooth(.2,.5,u),1))
		var targets=f.marked_points
		for i in range(targets.size()):
			var v=f.smooth(.32+i*.10,.82+i*.04,u);var q=targets[i]
			f.stream(p,q,v,10,Color("86c8d0"),a*.55,0)

	else:
		var scan=f.smooth(.25,.91,u);var q=dest+Vector2(-54+108*scan,4)
		f.prop("peek",f.bezier(p,q,f.smooth(.08,.31,u),-70),122,.25,a)
func bell():
	var u=progress();var a=alpha();var dest=f.targets[0]+Vector2(0,-54);var p=f.bezier(f.source,dest,f.smooth(.1,.58,u),-30)
	var rocking=sin(u*39)*.16*(1-f.smooth(.3,.68,u))
	f.prop("silence",p,111,rocking,a,Vector2(1-.07*f.smooth(.4,.75,u),1))
	for h in [-1,1]:
		for i in range(3):
			var pts=PackedVector2Array();var radius=32+i*13
			for j in range(25):
				var angle=lerpf(-.68,.68,float(j)/24);pts.append(p+Vector2(h*cos(angle)*radius,sin(angle)*radius))
			f.line(pts,Color("a3b1ce",a*(1-f.smooth(.40+i*.06,.7+i*.06,u))),2.5)
	for h in [-1,1]:f.stream(p+Vector2(h*43,9),p+Vector2(-h*15,-27),f.smooth(.40,.75,u),12,Color("5d689a"),a*.8,0)
func ink():
	var u=progress();var a=alpha();var dest=f.hand(f.target_ids[0]);var endpoint=dest+Vector2(35,-31);endpoint.y=maxf(157,endpoint.y)
	var p=f.bezier(f.source,endpoint,f.smooth(.1,.44,u),-25)
	f.prop("defile",p,107,f.smooth(.38,.70,u)*.75,a)
	var pour=f.smooth(.43,.80,u)
	f.stream(p+Vector2(21,-20),dest,pour,20,Color("7c539c"),a*.85,10)
	var positions=[dest]
	if f.op=="defile_seal" and f.event.has("hand_motion"):
		positions=[]
		var own=f.target_ids[0]/3==f.mine
		for slot in f.event.hand_motion.get("owner_slots",f.event.hand_motion.get("slots",[])):positions.append(f.Layout.hand_position(f.target_ids[0],int(slot),own)+f.Layout.CARD_SIZE*f.Layout.hand_scale(own)*.5)
	for center in positions:
		var v=f.smooth(.63,.96,u)
		for h in [-1,1]:f.coil(center+Vector2(h*21,20),12,46,u*.5+h,v,a*.7,Color("826197"),.8)
		f.ellipse(center,22*v,31*v,Color("674d83",a*v*.30),0,true)
func horn():
	var u=progress();var a=alpha();var p=podium();var pump=.05*sin(u*TAU*3)*f.smooth(.20,.4,u)
	f.prop("warcry",p,135,-.12,a,Vector2(1+pump,1-pump))
	var start=p+Vector2(46,5);var end=f.targets[0]
	for i in range(3):
		var v=clampf((u-.24-i*.14)/.42,0,1)
		if v<=0 or v>=1:continue
		var q=start.lerp(end,v);var dir=(end-start).angle()
		var pts=PackedVector2Array()
		for j in range(35):
			var theta=lerpf(-.85,.85,float(j)/34);pts.append(q+Vector2(cos(theta)*(28+22*v),sin(theta)*(31+35*v)).rotated(dir))
		f.ribbon(pts,11,a*sin(v*PI),Color("e5b269"))
func flag():
	var u=progress();var a=alpha();var p=podium();var drop=f.smooth(.12,.35,u)
	p.y-=45*(1-drop)
	f.prop("rally",p,148,-.1+.035*sin(u*24),a,Vector2(1+.05*sin(u*24),1))
	for i in range(f.targets.size()):
		var dest=f.targets[i]+Vector2(0,-20);var v=f.smooth(.35+i*.06,.95,u)
		var pts=PackedVector2Array()
		for j in range(50):
			var x=float(j)/49*v;pts.append(p.lerp(dest,x)+Vector2(0,-sin(x*PI)*35+sin(x*TAU*1.2+u*10)*8*sin(x*PI)))
		f.ribbon(pts,15,a*.7,Color("8fb9d2"));f.prop("badge",dest+Vector2(38,0),31,0,a*f.smooth(.83,1,u))
func coil():
	var u=progress();var a=alpha();var p=podium();f.prop("overload",p,126,0,a,Vector2(1,1+.025*sin(u*55)))
	for i in range(3):
		var v=f.smooth(.2+i*.17,.48+i*.16,u);var dest=f.targets[0]+Vector2(-37+i*37,-66)
		var start=p+Vector2(0,-i*15);var pts=PackedVector2Array()
		for j in range(13):
			var x=float(j)/12*v;pts.append(start.lerp(dest,x)+Vector2(sin(j*2.6+u*35)*7*sin(x*PI),0))
		f.line(pts,Color("77b7df",a*v*.4),7);f.line(pts,Color("e0f7ef",a*v),2.3)
		f.prop("sapphire",dest,24,0,a*v)
func poison():
	var u=progress();var a=alpha();var p=f.source.lerp(f.targets[0]+Vector2(55,-18),f.smooth(.1,.5,u))
	f.prop("poison",p,108,-.2+sin(u*31)*.045,a,Vector2(1+.1*sin(u*PI),1-.05*sin(u*PI)))
	for i in range(3):
		var points=PackedVector2Array()
		for j in range(51):
			var v=float(j)/50*f.smooth(.28+i*.07,.85,u)
			points.append(p+Vector2(-sin(v*PI)*(53+i*12),-39-v*49+cos(v*TAU+u*3)*10))
		f.ribbon(points,15-i*2,a*.68,Color("87a264") if i%2==0 else Color("917596"))
	if f.stage=="impact":f.label_at(f.targets[0]+Vector2(62,-42),"-1",Color("e7ead0"),a,23)
