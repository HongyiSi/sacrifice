extends RefCounted
var f
func count():return preload("res://scripts/strike_timing.gd").count(f.key)
func gap():return preload("res://scripts/strike_timing.gd").gap(f.event)
func progress(i):
	var d=float(f.event.travel_ms)/1000.0
	return (f.t-i*gap())/d if f.stage=="travel" else 1+(f.t-i*gap())/d
func path(u,p,i=0):
	var lift=f.source+Vector2((i-(count()-1)*.5)*20,-34)
	if u<.24:return f.source.lerp(lift,f.smooth(0,.24,u))
	if f.key in ["holy_strike","judgment"]:
		var top=p+Vector2(0,-48)
		if u<.65:return f.bezier(lift,top,f.smooth(.24,.65,u),-24)
		if u<.78:return top
		return top.lerp(p,pow(clampf((u-.78)/.22,0,1),2.25))
	if u<.45:return lift+Vector2(-5*sin((u-.24)/.21*PI),-3*sin((u-.24)/.21*PI))
	var a=pow(clampf((u-.45)/.55,0,1),1.72)
	var normal=(p-lift).normalized().orthogonal();var bend=(48+float(i)*16)*sin(a*PI)
	if f.key=="quick_strike":bend=0
	if f.key=="bounty":bend*=.45
	if f.key in ["magic_strike","hasty_spell"]:bend=sin(a*TAU*1.3)*17*sin(a*PI)+(25 if f.key=="magic_strike" else -20)*sin(a*PI)
	return lift.lerp(p,a)+normal*bend
func facing(u,p,i):
	if f.key in ["magic_strike","hasty_spell"] and u<.45:return 0.0
	if u<.45:return lerp_angle(preload("res://scripts/strike_timing.gd").CARD_ANGLE if f.key in preload("res://scripts/strike_timing.gd").SINGLE_CARD else .36,(p-f.source).angle()+PI/2,f.smooth(.28,.45,u))
	if f.key in ["holy_strike","judgment"] and u>.64:return PI
	return (path(minf(1,u+.004),p,i)-path(maxf(0,u-.004),p,i)).angle()+PI/2
func update():
	if f.sprites.has(f.actor):
		var s=f.sprites[f.actor];var dir=(f.targets[0]-f.source).normalized()
		var wind=f.smooth(.12,.4,f.u)*(1-f.smooth(.45,.6,f.u)) if f.stage=="travel" else 0.0
		var thrust=f.smooth(.48,.98,f.u) if f.stage=="travel" else exp(-f.t*6)
		s.node.position=s.position+dir*(11*thrust-4*wind);s.node.rotation=s.rotation+dir.x*(.035*thrust-.02*wind)
	if f.stage!="travel":
		var a=fmod(f.t,gap()) if f.t<(count()-1)*gap() else f.t-(count()-1)*gap()
		for hit_info in f.event.get("targets",[]):
			if not hit_info.get("miss",false) and not hit_info.get("blocked",false):f.react(hit_info.id,a,1.25 if f.key in ["godslayer","final_strike"] else 1)
func draw():
	for p in f.targets:
		for i in range(count()):
			var u=progress(i)
			if u>=0 and u<1:flying(p,u,i)
		if f.stage!="travel":
			var index=f.targets.find(p)
			var hit_info=f.event.get("targets",[])[index] if index<f.event.get("targets",[]).size() else {}
			if hit_info.get("miss",false):continue
			if hit_info.get("blocked",false):
				var a=1-f.smooth(.40,.9,f.u)
				f.ellipse(p,75,85,Color("e9d58d",a*.45))
				f.flash(p+Vector2(-42,-28),f.t,.63,Color("ead9a1"))
				f.label_at(p+Vector2(68,-40),"保佑",Color("f7e9be"),a,19)
				continue
			for i in range(count()):hit(p,f.t-i*gap(),i)
func flying(target,u,i):
	var p=path(u,target,i);var angle=facing(u,target,i);var alpha=f.smooth(0,.06,u)
	var side=lerpf(55,105,f.smooth(0,.29,u))
	if f.key in ["godslayer","holy_strike","final_strike"]:side*=1.18
	if f.key=="quick_strike":side*=.92
	if u<.43:
		f.shadow(f.source+Vector2(0,26),23*alpha,.12*alpha)
		f.glow(p,65,sin(minf(1,u/.43)*PI)*.22)
	if u>.48:
		var points=PackedVector2Array()
		for j in range(45):points.append(path(lerpf(maxf(.45,u-.26),u,float(j)/44),target,i))
		f.ribbon(points,19 if f.key!="quick_strike" else 11,.86)
		for j in range(3,0,-1):
			var a=maxf(.45,u-float(j)*.024)
			f.prop(f.key,path(a,target,i),side,facing(a,target,i),.05*(4-j))
	var squash=Vector2.ONE
	if f.key in ["magic_strike","hasty_spell"]:
		side=lerpf(51,95,f.smooth(0,.4,u));squash=Vector2(1+.12*sin(u*35),1-.09*sin(u*35))
		if u>.45:squash=Vector2(.8,1.3)
		f.glow(p,69,.34)
		for j in range(2):
			var phase=u*9+j*PI;f.prop(f.key,p+Vector2(sin(phase)*4,-cos(phase)*5),side*(.86+j*.14),angle+sin(phase)*.06,.18,squash)
	if f.key=="judgment" and u<.64:
		f.prop("judgment",p,112,sin(u*18)*.075,alpha)
		f.ring(p,64,.32*alpha)
	else:
		var which="holy_strike" if f.key=="judgment" else f.key
		f.prop(which,p,side,angle,alpha,squash)
	if f.key not in ["magic_strike","hasty_spell"]:f.star(p+Vector2.UP.rotated(angle)*side*.32,8,angle,Color("fff9e3",alpha*.85))
	if f.key in ["precise_strike","bounty"]:
		var a=f.smooth(.28,.5,u)*(1-f.smooth(.91,1,u));var r=lerpf(40,22,f.smooth(.3,.9,u))
		for k in range(4):
			var theta=k*PI/2;f.ring(target,r,a*.78,f.accent,2.2,theta+.1,theta+.7)
		f.ellipse(target,r*1.3,r*.23,Color(f.ink,a*.22))
	if f.key=="godslayer":
		var a=f.smooth(.32,.65,u);var r=53+4*sin(u*9)
		for k in range(3):f.ring(target,r,a*.6,f.accent,2.0,k*TAU/3+u*.3,k*TAU/3+u*.3+1.6)
	if f.key=="holy_strike" and u>.52:
		var a=sin(clampf((u-.52)/.48,0,1)*PI)
		f.ellipse(target+Vector2(0,-57),42,10,Color(f.accent,a*.75))
func fire_bloom(p,age):
	if age<0 or age>.85:return
	var a=1-f.smooth(.26,.79,age);var s=f.ease(age/.24)
	f.glow(p,122,a*.5)
	if f.key=="magic_strike":
		var bloom=f.smooth(.035,.15,age);var rising=f.smooth(.26,.48,age)
		f.prop("flame_squash",p,130,0,a*(1-bloom),Vector2(1.12,.82))
		f.prop("flame_bloom",p+Vector2(0,-12*s),148,sin(age*13)*.025,a*bloom*(1-rising),Vector2(1+.09*sin(age*17),1))
		f.prop("flame_rise",p+Vector2(0,-23-28*rising),145,0,a*rising,Vector2(1-.22*rising,1+.16*rising))
	else:
		for h in [-1,1]:f.prop(f.key,p+Vector2(h*25*s,-11*s),99,h*.55,a*.65,Vector2(1,.85+.2*s))
		f.prop(f.key,p+Vector2(0,-16*s),lerpf(64,112,s),sin(age*16)*.07,a,Vector2(1.18-.22*s,.70+.30*s))
	f.flash(p,age,.88)
func hit(p,age,index):
	if age<0 or age>.9:return
	if f.key in ["magic_strike","hasty_spell"]:fire_bloom(p,age);return
	var angles=[-.64,.92,.08,1.5];var angle=angles[index]
	if f.key in ["godslayer","holy_strike","judgment"]:angle=-PI/2
	if f.key=="bounty":angle=.70
	var r=102.0 if f.key in ["godslayer","final_strike","judgment"] else 86.0
	if f.key=="quick_strike":
		var dir=(p-f.source).normalized();var points=PackedVector2Array()
		for j in range(30):points.append(p+dir*lerpf(-115,76,float(j)/29))
		f.ribbon(points,13,1-f.smooth(.07,.34,age))
		for j in [-1,1]:f.line(PackedVector2Array([p-dir*83+dir.orthogonal()*j*13,p+dir*64+dir.orthogonal()*j*13]),Color(f.accent,exp(-age*16)),1.8)
	else:f.slash(p,angle,r,age)
	f.flash(p,age,1.20 if f.key in ["godslayer","judgment"] else 1.0)
	# The physical blade follows through the cut rather than vanishing into a symbol.
	if age<.19:
		var a=f.smooth(0,.18,age)
		var follow=Vector2(cos(-2.4+a*3.9)*r,sin(-2.4+a*3.9)*r*.43).rotated(angle)
		# Start exactly where the travelling blade made contact, then accelerate
		# into the sweep; this remains continuous even in the slow-motion clip.
		var center=p+follow*f.smooth(0,.060,age)
		var rotation=lerp_angle(facing(1.0,p,index),angle+(-2.4+a*3.9)+PI/2,f.smooth(0,.075,age))
		if f.key=="quick_strike":
			center=p+(p-f.source).normalized()*65*a
			rotation=facing(1.0,p,index)
		var side=105.0*(1.18 if f.key in ["godslayer","holy_strike","final_strike"] else .92 if f.key=="quick_strike" else 1.0)
		f.prop("holy_strike" if f.key=="judgment" else f.key,center,side,rotation,1-f.smooth(.10,.19,age))
	if f.key in ["holy_strike","judgment"]:
		f.line(PackedVector2Array([p+Vector2(0,-102),p+Vector2(0,60)]),Color(f.accent,exp(-age*15)*.32),24)
		f.line(PackedVector2Array([p+Vector2(0,-102),p+Vector2(0,60)]),Color("fff7df",exp(-age*15)),3)
		f.ellipse(p+Vector2(0,-60),39+age*9,9+age*2,Color(f.accent,(1-f.smooth(.2,.7,age))*.65))
	if f.key=="godslayer":
		for i in range(3):f.ring(p,55+age*28,(1-f.smooth(.10,.43,age))*.64,f.accent,2.4,i*TAU/3+age,i*TAU/3+age+1.55)
	if f.key=="glory":
		var a=f.smooth(.10,.20,age)*(1-f.smooth(.48,.86,age))
		f.prop("badge",p+Vector2(0,-68-12*age),47,0,a,Vector2(1+.07*sin(age*15),1))
