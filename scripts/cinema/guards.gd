extends RefCounted
var f
func update():
	if f.stage=="impact":
		for id in f.target_ids:f.react(id,f.t,.38)
func draw():
	var key=f.event.get("guard_style",f.key)
	if key not in f.GUARDS:key="defense"
	var block=f.kind=="shield_block";var travel=f.stage=="travel";var u=f.u
	var a=f.smooth(0,.13,u) if travel else 1-f.smooth(.6,1,u)
	if key=="defense":
		a=1.0 if block or not travel else f.smooth(0,.13,u)
		if block and not travel and f.board.view.characters[f.target_ids[0]].shield<=0:a=1-f.smooth(.18,.58,f.t)
		a*=.93
	var col=Color({"defense":"75b9dd","holy_amulet":"ebca76","attack_amulet":"fa432b","magic_amulet":"b597ed","blessing":"d6dc8a"}[key])
	for p in f.targets:
		var defense_scale=1.0
		var id=f.target_ids[f.targets.find(p)]
		# Blessing cancels attacks without spending a defense charge. Its
		# persistent foreground umbrella is already the visible protection.
		var blessing_block=block and f.event.get("guard_style","")!="defense" and f.board.view.characters[id].get("ongoing_effects",[]).any(func(s):return s.key=="blessing" and not s.get("dormant",false))
		if key=="defense":
			defense_scale=preload("res://scripts/defense_guard.gd").scale_for(f.board,id)
			p=preload("res://scripts/defense_guard.gd").anchor(f.board,id)
		var open=f.spring(minf(1,u/.56)) if travel else 1.0
		var location=f.source.lerp(p,f.smooth(.08,.53,u)) if travel and not block else p
		var squash=Vector2(1,1)
		if not travel:squash=Vector2(1-.14*exp(-u*8)*cos(u*18),1+.08*exp(-u*8)*cos(u*18))
		f.shadow(p+Vector2(0,56),55,a*.17)
		if key=="blessing":
			f.prop("blessing",p+Vector2(0,-42),144,0,a,Vector2(maxf(.12,open),.9+.1*open))
			canopy(p,col,a,open)
		elif key=="magic_amulet":
			for i in range(6):
				var angle=i*TAU/6+u*.8;var q=location+Vector2.from_angle(angle)*(40*open)
				f.leaf(q,38*open,angle+PI*.6,col,a*.55,.54)
			f.prop(key,location,79+12*open,0,a,squash)
			f.ellipse(location,68*open,77*open,Color(col,a*.6),0,true)
			f.ellipse(location,68*open,77*open,Color("fff0df",a*.8))
		elif key=="holy_amulet":
			for h in [-1,1]:
				for i in range(4):
					var q=location+Vector2(h*(20+i*9)*open,-8+i*9)
					f.leaf(q,(52-i*7)*open,(-.65-i*.09) if h>0 else PI+.65+i*.09,Color("f7e9b4"),a,.25)
			f.prop(key,location,104,0,a,squash)
			canopy(location,col,a*.62,open)
		elif key=="defense":
			# A second defense can arrive while an existing charge still protects.
			if travel and not block and f.board.view.characters[f.target_ids[0]].shield>0:
				preload("res://scripts/defense_guard.gd").paint(f,p,.93*(1-f.smooth(.4,.55,u)),1.,Vector2.ONE,defense_scale)
			if not blessing_block:preload("res://scripts/defense_guard.gd").paint(f,location,a,open,squash,defense_scale)
		else:
			for h in [-1,1]:
				f.prop("defense" if key=="defense" else key,location+Vector2(h*44*open,8),83,h*.38*open,a*.8,Vector2(.58,1)*squash)
			f.prop(key,location,111,0,a,squash)
			f.ellipse(location,72*open,80*open,Color(col,a*.24))
		if block:
			var incoming=f.event.get("cancelled_style",f.key)
			if incoming not in f.WEAPONS:incoming="strike"
			var start=f.pawn(int(f.event.get("cancelled_actor",f.actor)))
			var dir=(p-start).normalized();var contact=p-dir*47
			if travel:
				var v=f.smooth(.56,.95,u);var q=start.lerp(contact,v)
				f.stream(start,q,1,14,col,f.smooth(.55,.66,u)*.6,0)
				f.prop(incoming,q,94,dir.angle()+PI/2,f.smooth(.51,.61,u))
			else:
				var bounce=f.ease(u/.42)
				f.prop(incoming,contact-dir*(bounce*65)+Vector2(0,-sin(bounce*PI)*27),92,dir.angle()+PI/2+bounce*.9,1-f.smooth(.16,.54,u))
				f.flash(contact,f.t,.76,col)
				for i in range(3):f.ellipse(p,57+i*9+u*13,69+i*8,Color(col,(1-f.smooth(.1+i*.1,.5+i*.12,u))*.42))
func canopy(p,col,a,open):
	var points=PackedVector2Array()
	for j in range(65):
		var theta=lerpf(PI,TAU,float(j)/64);points.append(p+Vector2(cos(theta)*80*open,sin(theta)*92*open+35))
	f.ribbon(points,9,a*.85,col)
	f.ellipse(p+Vector2(0,35),80*open,17*open,Color(col,a*.40))
	for h in [-1,1]:
		var pts=PackedVector2Array()
		for j in range(40):
			var x=float(j)/39;pts.append(p+Vector2(h*sin(x*PI/2)*44*open,-57+92*x))
		f.line(pts,Color(col,a*.36),2)
