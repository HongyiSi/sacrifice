extends RefCounted
## Keep the exact engraved brass compass printed on the approved card.
const Art=preload("res://scripts/cinema/atlas.gd")
const REST=Vector2(108,515)
const SIDE=92.0
const TRAVEL_MS=1600
const IMPACT_MS=120
const DEPART_MS=400
const ARRIVAL=1.12
static func prop(c,at,side,angle=0.0,alpha=1.0,lift=0.0,squash=Vector2.ONE):
	for i in range(3):
		Art.draw_prop(c,"search",at+Vector2(1.4+i*.5,2.0+i*.55+lift*.04),side*(1.013+i*.014),angle,alpha*(.12-i*.025),squash,Color("211509"))
	Art.draw_prop(c,"search",at,side,angle,alpha,squash)
static func settled(c,age=100.0):
	var t=maxf(0.0,age-ARRIVAL)
	var weight=sin(t*PI/.28)*exp(-t*14.0) if t<.28 else 0.0
	prop(c,REST+Vector2(0,weight*1.6),SIDE,weight*.018,1.0,0.0,Vector2(1+weight*.006,1-weight*.009))
static func fly(f):
	if f.stage!="travel":settled(f);return
	var t=f.elapsed
	if t>=ARRIVAL:settled(f,t);return
	var lift=smoothstep(.03,.28,t);var travel=smoothstep(.17,ARRIVAL,t)
	var at=f.source.lerp(REST,travel)+Vector2(0,-sin(travel*PI)*48-18*lift*(1-travel))
	var start=46.0
	if is_instance_valid(f.source_widget):start=minf(f.source_widget.size.x-25,46.)*f.source_widget.get_global_transform().get_scale().x/f.board.canvas.get_global_transform().get_scale().x
	var side=lerpf(start,SIDE,smoothstep(0,.72,t))
	prop(f,at,side,-.11*sin(travel*PI),smoothstep(0,.065,t),35*sin(travel*PI))
static func depart(f):
	if f.stage!="travel":return
	var t=f.elapsed
	var alpha=1-smoothstep(.035,.34,t)
	prop(f,REST+Vector2(0,-7*smoothstep(0,.34,t)),lerpf(SIDE,SIDE*.94,smoothstep(0,.34,t)),0,alpha)
	# A few restrained brass glints, rather than a second moving emblem.
	for i in range(6):
		var u=clampf((t-i*.011)/.37,0,1);var a=sin(u*PI)*.5
		var p=REST+Vector2(sin(i*2.4)*(9+12*u),13-24*u+cos(i*1.7)*7)
		f.draw_circle(p,.65+.18*(i%3),Color("f2d8a0",a))
