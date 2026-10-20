extends RefCounted
const Art=preload("res://scripts/cinema/atlas.gd")
const ShaderFile=preload("res://scripts/blood_dagger.gdshader")
const STAB=1.20
const TOTAL=3.80
const RELEASE=2.22
const UNLOCK=2.76
var f
var chest
var dagger:Sprite2D
var material:ShaderMaterial
func setup(effect,pile):
	f=effect;chest=pile;f.z_index=160
	dagger=Sprite2D.new();dagger.name="BloodlettingDagger";dagger.set_meta("bloodletting_dagger",true)
	var tex:AtlasTexture=Art.texture("bloodletting")
	dagger.texture=tex.atlas;dagger.region_enabled=true;dagger.region_rect=tex.region
	material=ShaderMaterial.new();material.shader=ShaderFile
	material.set_shader_parameter("region_start",tex.region.position/tex.atlas.get_size())
	material.set_shader_parameter("region_size",tex.region.size/tex.atlas.get_size())
	dagger.material=material;f.add_child(dagger)
func clock():return f.t+(STAB if f.stage=="impact" else 0.0)
func contact():return f.pawn(f.actor)+Vector2(-8,10)
func tip_offset(side,angle):return ((Vector2(.032,.970)-Vector2(.5,.5))*Vector2(253,299)*(side/299.0)).rotated(angle)
func pose(at):
	var side=112.0;var angle=.52
	var start=f.source;var hit=contact()
	var rest=hit+Vector2(81,-21)-tip_offset(side,angle)
	var pos=f.bezier(start,rest,f.smooth(.12,.88,at),-49)
	side=lerpf(62,side,f.smooth(0,.56,at));angle=lerpf(0,.52,f.smooth(.10,.86,at))
	if at>=.88:
		side=112;angle=.52
		var tip=hit+Vector2(81,-21)+Vector2(12,-2)*f.smooth(.88,1.04,at)
		tip=tip.lerp(hit,f.smooth(1.04,STAB,at))
		tip=tip.lerp(hit+Vector2(55,-13),f.smooth(1.31,1.66,at))
		pos=tip-tip_offset(side,angle)
	if at>=1.98:
		var swipe=f.smooth(1.98,2.36,at)
		angle=.52-.16*sin(swipe*PI)+.74*swipe
		pos+=Vector2(-10*swipe,-7*sin(swipe*PI))
	if at>=2.78:
		var home=f.smooth(2.78,3.64,at)
		pos=f.bezier(pos,start,home,-36)
		angle=lerpf(angle,0,home);side=lerpf(side,62,home)
	return {"position":pos,"angle":angle,"side":side,"tip":pos+tip_offset(side,angle)}
func update():
	var at=clock();var p=pose(at)
	dagger.position=p.position;dagger.rotation=p.angle;dagger.scale=Vector2.ONE*p.side/299.0
	dagger.modulate.a=f.smooth(0,.09,at)*(1-f.smooth(3.42,3.72,at))
	var stain=f.smooth(STAB,1.34,at)*(1-f.smooth(3.12,3.6,at))
	material.set_shader_parameter("blood",stain)
	material.set_shader_parameter("buried",.108*f.smooth(1.135,STAB,at)*(1-f.smooth(1.32,1.46,at)))
	if is_instance_valid(f.source_widget):
		f.source_widget.motif_alpha=1-f.smooth(0,.09,at)*(1-f.smooth(3.42,3.72,at));f.source_widget.queue_redraw()
	if f.sprites.has(f.actor) and at>=STAB:
		var s=f.sprites[f.actor];var age=at-STAB
		var recoil=exp(-age*11)*(1-f.smooth(.30,.56,age))
		s.node.pivot_offset=Vector2(s.node.size.x*.5,s.node.size.y*.88)
		s.node.position=s.position+Vector2(-3.2,-1.4)*recoil
		s.node.rotation=s.rotation-.031*recoil
		s.node.scale=s.scale*Vector2(1+.014*recoil,1-.017*recoil)
	if is_instance_valid(chest):chest.present(f.smooth(UNLOCK,3.48,at))
func thread_point(u):
	var launch=pose(RELEASE).tip;var end=f.Layout.DECK_LOCK
	return f.bezier(launch,end,u,-48)
func draw():
	var at=clock();var p=pose(at)
	# A short arc is attached to the moving blade; no free-floating emblem.
	if at>2.02 and at<2.51:
		var pts=PackedVector2Array()
		for i in range(18):pts.append(pose(maxf(1.99,at-i*.010)).tip)
		f.ribbon(pts,2.3,.28*(1-f.smooth(2.36,2.51,at)),Color("dbab8a"))
	if at>=RELEASE and at<UNLOCK+.23:
		var u=clampf((at-RELEASE)/(UNLOCK-RELEASE),0,1)
		var fade=1-f.smooth(UNLOCK,UNLOCK+.23,at)
		var points=PackedVector2Array()
		for i in range(25):points.append(thread_point(lerpf(maxf(0,u-.24),u,i/24.0)))
		f.ribbon(points,3.1,.66*fade,Color("bf6058"))
		var head=thread_point(u)
		f.glow(head,14,.28*fade,Color("f0c19a"))
		for i in range(9):
			var v=u-i*.021
			if v<0:continue
			var q=thread_point(v)+Vector2(sin(i*7.1),cos(i*8.3))*2.6
			f.draw_circle(q,.60+(i%3)*.24,Color("edd6ab",fade*(1-i/10.0)*.74))
	if at>UNLOCK and at<UNLOCK+.55:
		var age=at-UNLOCK;var a=exp(-age*6)*(1-f.smooth(.30,.55,age))
		f.glow(f.Layout.DECK_LOCK,28,a*.32,Color("efc583"))
		for i in range(11):
			var dir=Vector2.from_angle(i*2.4)
			var q=f.Layout.DECK_LOCK+dir*(4+age*(12+i%4*7))+Vector2(0,age*age*14)
			f.draw_line(q,q-dir*(1.2+i%3),Color("f4d9a5",a*.78),1.0,true)
