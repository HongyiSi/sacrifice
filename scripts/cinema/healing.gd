extends RefCounted
var f
func update():
	if f.stage=="impact":
		for id in f.target_ids:f.react(id,f.t,.8,true)
func draw():
	var travel=f.stage=="travel";var u=f.u;var a=f.envelope(u,.10,.78) if travel else 1-f.smooth(.10,.75,u)
	var lift=f.source+Vector2(0,-35*f.spring(minf(1,u/.35))) if travel else f.source+Vector2(0,-35)
	var size_value=lerpf(54,110,f.smooth(0,.22,u)) if travel else 110
	var tip=lift+Vector2(32,-20)
	var origin_key=f.key
	if f.key=="cards_to_heart":origin_key="heart"
	if f.key in ["heal","heal_other"]:
		var tilt=f.smooth(.20,.48,u)*.88 if travel else .88*(1-f.smooth(0,.8,u))
		f.prop(f.key,lift,size_value,tilt,a,Vector2(1+.05*sin(u*18),1-.04*sin(u*18)))
		tip=lift+Vector2(0,-size_value*.32).rotated(tilt)
	elif f.key=="spare_food":
		var split=f.smooth(.17,.38,u) if travel else 1.0
		for h in range(2):f.prop_half("spare_food",lift,size_value,h,Vector2((h*2-1)*12*split,-4*split),(h*2-1)*.10*split,a)
		for i in range(3):
			var pts=PackedVector2Array()
			for j in range(32):
				var v=float(j)/31;pts.append(lift+Vector2((i-1)*15+7*sin(v*TAU+u*7),-14-v*49))
			f.ribbon(pts,4,a*.55,Color("fff1c9"))
	elif f.key=="spare_supplies":
		f.prop(f.key,lift,size_value,sin(u*11)*.05,a,Vector2(1+.08*sin(u*PI),1))
		f.prop("heal_other",lift+Vector2(-26,-28*f.smooth(.12,.4,u)),54,-.28,a*f.smooth(.15,.35,u))
	elif f.key=="team_heal":
		f.prop(f.key,lift,size_value,0,a,Vector2(1+.18*f.smooth(.1,.5,u),1+.05*sin(u*13)))
		for i in range(3):f.leaf(lift+Vector2((i-1)*10,13),30*f.smooth(.16,.48,u),-PI*.5+(i-1)*.8,Color("a8d876"),a)
	elif f.key=="blood_rite":
		f.prop(f.key,lift,size_value,0,a,Vector2(1,1+.06*sin(u*PI)))
		f.ellipse(lift+Vector2(0,-23),24,7,Color("ffaca1",a*.8),0,true)
	else:
		f.prop(origin_key,lift,size_value,0,a,Vector2.ONE*(1+.065*sin(u*TAU*3)))
		f.glow(lift,76,a*.23)
	for i in range(f.targets.size()):
		var p=f.targets[i];var delay=i*.065
		if travel:
			var v=f.smooth(.32+delay,.93,u)
			if v>0:
				var tint=Color("eee9ca") if f.key=="spare_supplies" else f.accent
				f.stream(tip,p+Vector2(0,19),v,18,tint,a*.8,-55-18*i)
				var head=f.bezier(tip,p+Vector2(0,19),v,-55-18*i)
				if f.key in ["team_heal","amber"]:f.leaf(head,26,-PI/4+u*2,tint,a)
				elif f.key=="spare_supplies":f.ellipse(head,16,5,Color("fff2d0",a),.4,true)
				else:f.ellipse(head,11,16,Color(tint.lightened(.22),a),-.5,true)
			if u>.70:healing_wrap(p,f.smooth(.70,1,u)*.32,.7, i)
		else:
			var blocked=f.event.get("targets",[])[i].get("heal_blocked",false)
			if blocked:
				f.ellipse(p,74,84,Color(f.accent,(1-u)*.45));continue
			healing_wrap(p,.32+u*.68,1-f.smooth(.6,1,u),i)
func healing_wrap(p,v,a,index):
	var col=f.accent;var base=p+Vector2(0,54)
	f.glow(p,94,.21*a)
	f.ellipse(base,48+8*sin(v*PI),11,Color(col,a*.5))
	f.coil(base,48,108,-v*2.5+index,.18+.82*v,a*.8,col,1.65 if f.key=="heal_other" else 1.25)
	var growth=f.smooth(.22,.65,v)
	if f.key=="blood_rite":
		for h in [-1,1]:
			var q=base+Vector2(h*31,-8);f.leaf(q,31*growth,-PI/2+h*.45,Color("eab08a"),a)
		f.prop("heart",p+Vector2(0,-52-9*v),30*(.8+.2*sin(v*PI)),0,a)
	elif f.key=="spare_supplies":
		f.coil(base+Vector2(0,-15),36,62,.4-v*2,1,a*.75,Color("f8eaca"),1.25)
	else:
		for h in [-1,1]:
			var q=base+Vector2(h*34,-2)
			f.leaf(q,33*growth,-PI/2+h*.64,col.lightened(.08),a)
			f.leaf(q+Vector2(-h*6,-14*growth),22*growth,-PI/2-h*.45,col.lightened(.32),a)
		if f.key=="team_heal":
			for k in range(5):f.leaf(base+Vector2(0,-5),15*growth,k*TAU/5,Color("ffefd0"),a,.48)

