extends RefCounted
const Card=preload("res://scripts/card_widget.gd")
var f
var hand_points=[]
var hand_faces=[]
func setup():
	if f.key!="vanish":return
	var target=f.target_ids[0]
	for n in f.all_nodes(f.board.canvas):
		if n.get_meta("hand_actor",-1)==target or n.get_meta("enemy_hand_actor",-1)==target:
			for c in n.get_children():
				if c is Card:
					var key=c.card.get("key","")
					if key=="curse" or not c.card.get("discardable",true):continue
					if hand_points.size()>=int(f.event.get("card_count",0)):continue
					hand_points.append(f.local_center(c));hand_faces.append(key);c.hide();f.hidden_nodes.append(c)
func progress():return f.u if f.stage=="travel" else 1.0
func alpha():return f.smooth(0,.10,f.u) if f.stage=="travel" else 1-f.smooth(.40,1,f.u)
func update():
	if f.key=="pain":return
	if f.stage=="impact":
		for id in f.target_ids:f.react(id,f.t,.9,f.key in ["immortal","raise_dead","resurrection"] or f.op=="life_after")
	if f.key in ["feign","death"] and f.stage=="travel" and f.sprites.has(f.target_ids[0]):
		var s=f.sprites[f.target_ids[0]];var v=f.smooth(.38,.83,f.u)
		s.node.modulate=s.color.lerp(Color(.64,.67,.74,s.color.a*.66),v)
func draw():
	match f.key:
		"death_sentence":reaper()
		"last_dance":dance()
		"life_steal":drain()
		"raise_dead","resurrection":revival()
		"immortal":phoenix()
		"ghost","death":ghost()
		"elegy":music_box()
		"feign":mask()
		"mediocrity":shears()
		"prison":cage()
		"pain":pain()
		"curse":vines()
		"vanish":vanish()
		"eye":eye()
		"divinity":divinity()
		"privilege":crown()
		_:ghost()
func soul(p,side,phase,a=1.0):
	f.Art.draw_warp(f,"ghost_left" if sin(phase*.7)<0 else "ghost_right",p,side,phase*2,a)
func gate(p,v,a,col):
	for h in [-1,1]:
		f.leaf(p+Vector2(h*14,52),92*f.smooth(0,.56,v),-PI/2+h*.48,col,a,.21)
		f.leaf(p+Vector2(h*30,33),51*f.smooth(.15,.70,v),-PI/2+h*.82,col.lightened(.24),a,.20)
	f.ellipse(p+Vector2(0,50),60,15,Color(col,a*.6))
func reaper():
	var u=progress();var a=alpha();var target=f.targets[0];var center=target+Vector2(-85,-29)
	if f.stage=="travel":
		var v=f.smooth(.12,.58,u);var p=f.bezier(f.source,center,v,-49)
		var emerge=f.smooth(.06,.25,u);f.shadow(p+Vector2(0,63),50,a*.21)
		f.prop("reaper_windup",p,137,-.08,a,Vector2(emerge,1+.035*sin(u*16)))
		var wind=f.smooth(.56,.87,u)
		f.prop("scythe",p+Vector2(39,-6),152,lerpf(.18,-.72,wind),a)
		var pts=PackedVector2Array()
		for j in range(40):
			var x=float(j)/39;pts.append(p+Vector2(sin(x*PI)*39,-x*88+58))
		f.ribbon(pts,23,a*.42,Color("76518f"))
	else:
		var v=f.ease(f.u/.31)
		var pose="reaper_windup" if v<.48 else "reaper_follow"
		f.prop(pose,center+Vector2(22*v,0),137,lerpf(-.08,.05,v),a,Vector2(1+.035*sin(v*PI),1-.025*sin(v*PI)))
		var q=center+Vector2(41+40*v,-6+17*sin(v*PI))
		f.prop("scythe",q,156,lerpf(-.72,1.44,v),a)
		f.slash(target,-.13,112,f.t,Color("bb9be1"));f.flash(target,f.t,1.18,Color("c9a9e7"))
		var reap=f.smooth(.12,.80,f.u)
		soul(f.bezier(target,center+Vector2(16,0),reap,-42),60,2+f.u,a*f.smooth(.1,.25,f.u))
		f.stream(target,center,reap,24,Color("bc9ce0"),a*.65,-33)
func dance():
	var u=progress();var a=alpha();var target=f.targets[0];var twist=f.smooth(.24,.92,u)
	var p=f.bezier(f.source,target,twist,-80)
	if f.stage=="travel":
		f.prop("last_dance",p,115,twist*TAU*.85,a,Vector2(1-.09*sin(u*PI),1+.10*sin(u*PI)))
		var points=PackedVector2Array()
		for i in range(60):
			var v=float(i)/59*twist;points.append(f.bezier(f.source,target,v,-80)+Vector2(0,sin(v*TAU*1.4)*17))
		f.ribbon(points,17,a*.84,Color("db93bb"))
	else:
		var points=PackedVector2Array()
		for i in range(64):
			var theta=lerpf(-PI,PI*.75,float(i)/63);points.append(target+Vector2(cos(theta)*90,sin(theta)*39))
		f.ribbon(points,19,a*.85,Color("e9abc8"));f.slash(target,.4,90,f.t,Color("ecc3ad"))
		f.prop("last_dance",target+Vector2(54,-27-11*sin(f.u*PI)),102,-.25+f.u*.7,a)
		f.flash(target,f.t,.7,Color("ebbad7"))
func drain():
	var u=progress();var a=alpha();var target=f.targets[0]
	if f.op=="life_after":
		var start=f.pawn(int(f.event.get("drain_source",3)));var end=target;var v=f.smooth(.12,.84,u)
		f.stream(start,end,v,29,Color("d786a2"),a*.85,-82)
		f.prop("heart",f.bezier(start,end,v,-82),54,0,a,Vector2.ONE*(1+.1*sin(u*20)))
		gate(end,f.smooth(.55,1,u),a*.75,Color("bf84a6"))
	else:
		var v=f.smooth(.2,.93,u)
		for h in [-1,1]:
			var points=PackedVector2Array()
			for i in range(61):
				var x=float(i)/60*v;points.append(f.source.lerp(target,x)+Vector2(sin(x*TAU)*18*h,sin(x*PI)*h*43))
			f.ribbon(points,13,a*.85,Color("885771"));f.prop("pain",points[-1],70,h*.4,a)
		if f.stage=="impact":f.coil(target+Vector2(0,43),46,92,-f.u*2,1,a*.75,Color("d18aaf"),1.4)
func revival():
	var u=progress();var a=alpha();var target=f.targets[0];var lamp=target+Vector2(72,-64)
	f.prop("lantern",f.bezier(f.source,lamp,f.smooth(.1,.5,u),-32),104,sin(u*14)*.07,a)
	var v=f.smooth(.35,.93,u);var upper=target+Vector2(0,-122)
	f.stream(lamp,upper,f.smooth(.35,.58,u),13,Color("7cccd2"),a*.70,-30)
	soul(upper.lerp(target+Vector2(0,-2),f.smooth(.53,.97,u)),95,1+u*3,a*f.smooth(.25,.5,u)*(1-f.smooth(.89,1,u)))
	gate(target,v,a*.78,Color("78c8b4"))
	if f.stage=="impact":
		f.glow(target,111,a*.37,Color("afded0"))
		f.coil(target+Vector2(0,44),53,103,-f.u*2,1,a*.55,Color("a6d9c5"),1.0)
func phoenix():
	var u=progress();var a=alpha();var target=f.targets[0];var p=target+Vector2(0,-43-22*sin(u*PI))
	var props=preload("res://scripts/persistent_death_props.gd")
	var owner=f.board.view.characters[f.target_ids[0]]
	var dock=props.world_pose(f.board,owner.id,"immortal",props.visible_keys(owner,f.event))
	var settle=0.0 if f.stage=="travel" else f.smooth(0,.55,f.u)
	p=p.lerp(dock.at,settle)
	if f.stage!="travel":a=1-f.smooth(.55,.95,f.u)
	var fly=f.smooth(.04,.20,u);var phase=u*3.0
	var wings=["phoenix_down","phoenix_up","phoenix_mid","phoenix_down"]
	var index=mini(2,int(phase));var blend=f.smooth(0,1,phase-index)
	if f.stage!="travel":index=1;blend=f.smooth(0,.70,f.u)
	f.glow(p,130,a*.3,Color("f7d182"))
	if f.stage=="travel":f.Art.draw_warp(f,"phoenix_mid",p,184*(.78+.22*fly),f.t*5-PI/2,a,true)
	else:f.prop("phoenix_mid",p,lerpf(184,dock.side,settle),0,a,Vector2(1,1+.018*sin(f.t*1.2)))
	for h in [-1,1]:
		var pts=PackedVector2Array()
		for i in range(55):
			var v=float(i)/54*f.smooth(.25,.8,u);pts.append(target+Vector2(h*sin(v*PI)*69,-85+147*v))
		f.ribbon(pts,16,a*.72,Color("f4d395"))
	if f.stage=="impact":f.ellipse(target+Vector2(0,52),65,17,Color("e2ba72",a*.6))
func ghost():
	if f.key=="ghost" and f.op!="activate":
		# Its small spirit remains on the pawn while a short blade gesture
		# accompanies the virtual strike; no second, fading spirit is spawned.
		var props=preload("res://scripts/persistent_death_props.gd")
		var owner=f.board.view.characters[f.target_ids[0]]
		var dock=props.world_pose(f.board,owner.id,"ghost",props.visible_keys(owner,f.event))
		if f.stage=="travel":f.prop("quick_strike",dock.at+Vector2(25,-8),42,.65,f.smooth(.55,.7,f.u)*(1-f.smooth(.82,1.,f.u)))
		return
	var u=progress();var a=alpha();var target=f.targets[0];var v=f.smooth(.1,.85,u)
	var p=target+Vector2(28*sin(v*PI),25-105*v)
	p.y=maxf(158,p.y)
	f.shadow(target+Vector2(0,51),50,a*.17)
	soul(p,118,1+u*3,a)
	for h in [-1,1]:f.stream(target+Vector2(h*19,31),p+Vector2(h*20,30),1,11,Color("9bcbdc"),a*.5,20)
	if f.key=="ghost" and u>.65:f.prop("quick_strike",p+Vector2(41,14),71,.8,a*f.smooth(.65,.85,u))
func music_box():
	var u=progress();var a=alpha();var p=f.source+Vector2(25,-37)
	f.prop("elegy",p,135,0,a,Vector2(1,1+.04*sin(u*12)))
	var rows=3
	for j in range(rows):
		var pts=PackedVector2Array()
		for i in range(60):
			var v=float(i)/59;pts.append(p+Vector2(-73+146*v,-57+j*9+sin(v*TAU+u*8)*7))
		f.line(pts,Color("ac93c7",a*.6),1.7)
	if f.event.get("flow","")=="out":
		for i in range(int(f.event.get("card_count",2))):
			var v=f.smooth(.17+i*.12,.83+i*.08,u)
			f.little_card(f.bezier(f.hand(f.actor)+Vector2(i*40,0),p,v,-60),-.2+i*.4,1.3*(1-.8*v),a*(1-v))
	else:
		var v=f.smooth(.24,.84,u);f.little_card(p+Vector2(0,-26-54*v),sin(v*PI)*.1,1.12,a*v,"",true)
		f.stream(p,p+Vector2(0,-75),1,14,Color("a591cd"),a*.4,0)
func mask():
	var u=progress();var a=alpha();var target=f.targets[0]
	var p=f.bezier(f.source,target+Vector2(0,-15),f.smooth(.1,.7,u),-46)
	f.prop("feign",p,125,-.1*sin(u*PI),a,Vector2(1-.14*f.smooth(.55,1,u),1))
	var v=f.smooth(.48,.88,u)
	soul(target+Vector2(45*v,-57*v),71,u*2,a*v*.65)
	f.ellipse(target+Vector2(0,47),51,14,Color("a691be",a*.5))
func shears():
	var u=progress();var a=alpha();var target=f.targets[0];var p=target+Vector2(0,-78);p.y=maxf(155,p.y)
	var open=1-f.smooth(.56,.73,u)
	f.prop_half("mediocrity",p,112,0,Vector2(-open*9,0),-.16*open,a)
	f.prop_half("mediocrity",p,112,1,Vector2(open*9,0),.16*open,a)
	var count=int(f.event.get("card_count",2))
	for i in range(count):
		var q=target+Vector2((i-(count-1)*.5)*42,-30);var cut=f.smooth(.58,.78,u)
		var pts=PackedVector2Array([q,p+Vector2(0,-24),q+Vector2(0,-80)])
		f.line(pts,Color("a196c2",a*(1-cut)),2.5)
		var destination=f.bezier(q,f.DISCARD,f.smooth(.73,1,u),-35)
		f.little_card(destination,(i-.5)*.18,1,a,"",true)
	if u>.64:f.flash(p,(u-.64)*3,.43,Color("e0d8ed"))
func cage():
	if f.op!="activate" and f.board.view.characters[f.target_ids[0]].get("statuses",[]).has("prison"):
		# The painted cage already surrounds the pawn during blocked draws.
		var u=progress();var p=f.targets[0];var a=alpha()
		var v=f.smooth(.3,.8,u);var q=f.bezier(f.DECK,p+Vector2(0,30),sin(v*PI)*.88,-60)
		f.little_card(q,-v*.25,1.2,a)
		return
	var u=progress();var a=alpha();var target=f.targets[0];var p=target+Vector2(0,-15)
	var drop=f.smooth(.18,.58,u)
	f.prop("prison",p+Vector2(0,-95*(1-drop)),157,0,a,Vector2(.92+.08*drop,1))
	for i in range(9):
		var v=f.smooth(.45+i*.028,.78+i*.024,u);var q=target+Vector2(-63+i*15,48+sin(i*.65)*6)
		f.ellipse(q,9*v,5*v,Color("7b8c9b",a*.85),i*.25)
	if f.op=="":
		var v=f.smooth(.3,.8,u);var q=f.bezier(f.DECK,p+Vector2(0,30),sin(v*PI)*.88,-60)
		f.little_card(q,-v*.25,1.2,a)
func vine_stem(start,end,v,a,col):
	var pts=PackedVector2Array()
	for i in range(65):
		var x=float(i)/64*v;pts.append(start.lerp(end,x)+Vector2(sin(x*TAU*1.3)*19,sin(x*PI)*-26))
	f.line(pts,Color(col.darkened(.5),a),8);f.line(pts,Color(col,a),4.8)
	for i in range(1,6):
		var x=float(i)/6
		if v>x:
			var q=start.lerp(end,x)+Vector2(sin(x*TAU*1.3)*19,sin(x*PI)*-26)
			f.leaf(q,24*f.smooth(x,x+.14,v),(-.4 if i%2==0 else -2.6),col.lightened(.16),a,.29)
func vines():
	var u=progress();var a=alpha();var cursed=f.key=="curse"
	var target=f.landing(int(f.event.get("recipient",f.target_ids[0]))) if f.kind=="hand_transfer" else f.targets[0]
	var col=Color("785991") if cursed else Color("a7658f");var v=f.smooth(.20,.90,u)
	if f.kind=="hand_transfer":
		f.little_card(f.bezier(f.source,target,v,-61),0,1.12,a,"curse",true)
		vine_stem(f.source,target,v,a*.72,col)
	else:
		for h in [-1,1]:vine_stem(target+Vector2(h*45,51),target+Vector2(h*28,-49),v,a*.8,col)
		f.prop(f.key,target+Vector2(0,24-42*v),111,0,a,Vector2(.40+.60*v,.50+.50*v))
	if cursed:
		for h in [-1,1]:vine_stem(target+Vector2(0,26),target+Vector2(h*61,-27),f.smooth(.55,1,u),a,col)
func pain():
	if f.op!="activate":return
	var rose=preload("res://scripts/pain_rose.gd")
	var target=f.pawn(f.actor);var u=progress();var v=f.smooth(.20,.90,u)
	var a=f.smooth(0,.10,f.u) if f.stage=="travel" else 1.0
	var vine_alpha=a*(1-f.smooth(0,.85,f.u)) if f.stage=="impact" else a
	for h in [-1,1]:vine_stem(target+Vector2(h*45,51),target+Vector2(h*28,-49),v,vine_alpha*.8,Color("a7658f"))
	rose.paint(f,rose.anchor(f.board,f.actor)+Vector2(0,42*(1-v)),a,v)
func vanish():
	var u=progress();var a=alpha();var target=f.hand(f.target_ids[0]);var center=target+Vector2(0,26 if f.target_ids[0]/3!=f.mine else -58)
	var width=f.smooth(.12,.47,u)*(1-f.smooth(.78,1,u))
	f.prop("reaper",center,153,0,a,Vector2(.5+width*.8,1))
	for h in [-1,1]:f.leaf(center+Vector2(h*13,18),101*width,0 if h>0 else PI,Color("695477"),a,.55)
	for i in range(hand_points.size()):
		var v=f.smooth(.35+i*.09,.80+i*.07,u);var q=f.bezier(hand_points[i],center,v,-32)
		f.little_card(q,(i-.5)*.5*v,1.5*(1-.8*v),a*(1-f.smooth(.67,1,v)),hand_faces[i])
func eye():
	var u=progress();var a=alpha();var p=f.targets[0]+Vector2(0,-77);var opened=f.smooth(.23,.5,u)
	f.prop("eye_closed",p,122,0,a*(1-opened))
	f.prop("eye",p,122,sin(u*8)*.035,a*opened)
	for i in range(3):
		var target=f.hand(i+3);var v=f.smooth(.45+i*.09,.91+i*.02,u)
		f.stream(p,target,v,10,Color("93b8d3"),a*.5,-40)
		f.ellipse(target,42,16,Color("92bcce",a*v*.35))
func divinity():
	var u=progress();var a=alpha();var p=f.source+Vector2(72,-47)
	f.prop("divinity",p,165,-.04,a,Vector2(1,1+.03*sin(u*12)))
	var count=int(f.event.get("card_count",5));count=clampi(count,3,5)
	for i in range(count):
		var v=f.smooth(.20+i*.065,.71+i*.04,u);var angle=(i-(count-1)*.5)*.25
		var q=p+Vector2(sin(angle)*128,-75-cos(angle)*15)
		f.little_card(f.bezier(f.DECK,q,v,-66),angle,1.1,a*v,"strike" if i==2 else "",false)
		if i==2 and u>.68:f.glow(q,49,a*.30,Color("efce83"))
	f.ellipse(p+Vector2(0,-101),93,19,Color("e2c18b",a*.45))
func crown():
	var u=progress();var a=alpha()
	for i in range(f.targets.size()):
		var target=f.targets[i];var v=f.smooth(.12+i*.1,.71+i*.06,u)
		var p=f.bezier(f.source,target+Vector2(0,-61),v,-70)
		f.prop("privilege",p,86,0,a,Vector2(1,.83+.17*v))
		for j in range(3):
			var growth=f.smooth(.56+j*.07,1,u);var q=target+Vector2(56+j*13,21-j*15)
			f.line(PackedVector2Array([q+Vector2(-11,0),q+Vector2(10,0),q+Vector2(10,-13*growth)]),Color("cda966",a*growth),4.4)
