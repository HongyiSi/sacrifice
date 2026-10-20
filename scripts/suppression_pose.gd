extends RefCounted
## Same illustrated objects as the printed cards. No replacement symbols.
const Art=preload("res://scripts/cinema/atlas.gd")
const TRAVEL={"suppress":1500,"late_suppress":1700}
const IMPACT={"suppress":850,"late_suppress":1000}
const SIDE=1.22
static func contact(key):return TRAVEL[key]/1000.0
static func raw_prop(c,key,p,side,angle=0.,opacity=1.,crank=0.,squash=Vector2.ONE,tint=Color.WHITE):
	if opacity<.001:return
	if key=="suppress":Art.draw_prop(c,key,p,side,angle,opacity,squash,tint);return
	var tex=Art.texture(key);var dim=tex.get_size();var ratio=side/maxf(dim.x,dim.y)
	var cut=97.;var ink=Color(tint,opacity)
	# Only the real upper handle turns. Brass body and lower plate stay rigid.
	c.draw_set_transform(p,angle,squash)
	c.draw_texture_rect_region(tex,Rect2(Vector2(-dim.x*.5,cut-dim.y*.5)*ratio,Vector2(dim.x,dim.y-cut)*ratio),Rect2(0,cut,dim.x,dim.y-cut),ink)
	var grip=Vector2(0,(cut*.5-dim.y*.5)*ratio)
	c.draw_set_transform(p+(grip*squash).rotated(angle),angle+.035*sin(crank),squash*Vector2(.23+.77*absf(cos(crank)),1.))
	c.draw_texture_rect_region(tex,Rect2(Vector2(-dim.x,-cut)*ratio*.5,Vector2(dim.x,cut)*ratio),Rect2(0,0,dim.x,cut),ink)
	c.draw_set_transform(Vector2.ZERO)
static func prop(c,key,p,side,angle=0.,opacity=1.,crank=0.,squash=Vector2.ONE,lift=0.):
	# Close, shape-matched contact shadow anchors the metal/wood to the paper.
	for i in range(3):
		var d=Vector2(1.4+i*.35,2.0+i*.40+lift*.06)
		raw_prop(c,key,p+d,side*(1.012+i*.012),angle,opacity*(.13-i*.028)*(1.-lift*.004),crank,squash,Color("21180f"))
	raw_prop(c,key,p,side,angle,opacity,crank,squash)
static func settled(c,key,center,side,seconds=100.):
	var t=maxf(0,seconds-contact(key))
	var weight=sin(t*PI/.29)*exp(-t*13.) if t<.29 else 0.
	var lean=.027*sin(t*18.)*exp(-t*15.) if t<.50 else 0.
	prop(c,key,center+Vector2(0,weight*2.4),side,lean,1.,TAU if key=="late_suppress" else 0.,Vector2(1.+weight*.014,1.-weight*.018))
	if t<.55:
		var col=Color("dfa265") if key=="suppress" else Color("c6b687")
		for i in range(14):
			var seed=fposmod(sin(i*63.78+3.14)*7219.7,1.)
			var speed=side*(.20+seed*.28);var direction=Vector2.from_angle(i*2.39996)*Vector2(1,.48)
			var at=center+direction*(side*.18+speed*t)+Vector2(0,side*.17+t*t*15.)
			var alpha=sin(clampf(t/.55,0,1)*PI)*(.25+seed*.2)
			c.draw_line(at-direction*1.2,at+direction*.7,Color(col,alpha),.7+seed*.5,true)
static func draw_flight(f):
	if f.stage!="travel":return
	var key=f.key;var age=f.elapsed;var end=contact(key);var c=f.target_widget
	if not is_instance_valid(c):return
	var tr=f.board.canvas.get_global_transform().affine_inverse()*c.get_global_transform()
	var dest=tr*(c.size*.5+Vector2(0,-3.))
	var final_side=c.size.x*SIDE*tr.get_scale().x
	var start_side=minf(f.source_widget.size.x-25,46.)*f.source_widget.get_global_transform().get_scale().x/f.board.canvas.get_global_transform().get_scale().x if is_instance_valid(f.source_widget) else 42.
	var lift=smoothstep(.06,.42,age);var fly=smoothstep(.30,end-.32,age);var press=smoothstep(end-.23,end,age)
	var origin=f.source+Vector2(10,-29*lift)
	var position=origin.lerp(dest+Vector2(0,-23),fly)+Vector2(0,-sin(fly*PI)*47)
	position.y+=23*press
	var scale_side=lerpf(start_side,94. if key=="suppress" else 98.,lift)
	scale_side=lerpf(scale_side,final_side,smoothstep(end-.55,end-.05,age))
	var angle=(-.09 if key=="suppress" else .065)*sin(fly*PI)*(1.-press)
	var crank=TAU*smoothstep(.92,end-.04,age) if key=="late_suppress" else 0.
	prop(f,key,position,scale_side,angle,smoothstep(.0,.10,age),crank,Vector2.ONE,23*(1.-press))
