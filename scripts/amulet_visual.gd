extends Control
## Deterministic physical prop, light, and paper combustion.
const Art=preload("res://scripts/cinema/atlas.gd")
const Card=preload("res://scripts/card_widget.gd")
const Layout=preload("res://scripts/board_layout.gd")
const Timing=preload("res://scripts/amulet_timing.gd")
const LIFT_START=Timing.LIFT_START
const LIFT_END=Timing.LIFT_END
const FIRE_START=Timing.FIRE_START
const HIT=Timing.HIT
const FIRE_OFF=Timing.FIRE_OFF
const BURN_END=Timing.BURN_END
const RETURN_START=Timing.RETURN_START
const RETURN_END=Timing.RETURN_END
const END=Timing.END
const PAD=Vector2(50,85)
var fx
var key=""
var variant=0
var tint=Color.WHITE
var hot=Color.WHITE
var source_card
var target_card
var source_alpha=1.
var target_alpha=1.
var source=Vector2.ZERO
var chest=Vector2.ZERO
var port=Vector2.ZERO
var hit=Vector2.ZERO
var area=Rect2()
var side=46.
var age=0.
var lift=0.
var charge=0.
var burn=0.
var release=0.
var face:TextureRect
var face_mat:ShaderMaterial
var beam:ColorRect
var beam_mat:ShaderMaterial
var smoke:ColorRect
var smoke_mat:ShaderMaterial
var aura:ColorRect
var aura_mat:ShaderMaterial
var impact_aura:ColorRect
var impact_mat:ShaderMaterial
var view:SubViewport
var portrait:TextureRect
var particles:Control

func rect_shader(shader_path:String)->ColorRect:
	var node=ColorRect.new();node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var mat=ShaderMaterial.new();mat.shader=load(shader_path);node.material=mat
	add_child(node);return node

func configure(owner_effect)->void:
	fx=owner_effect;key=fx.event.style;source_card=fx.source_widget;target_card=fx.cancel_target
	variant=["holy_amulet","attack_amulet","magic_amulet"].find(key)
	tint=[Color("ffc154"),Color("fa432b"),Color("b878f3")][variant]
	hot=[Color("fff5ce"),Color("ffe2b6"),Color("ffe5fd")][variant]
	mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(1440,960)
	source_alpha=source_card.motif_alpha;target_alpha=target_card.modulate.a
	aura=rect_shader("res://scripts/shaders/amulet_aura.gdshader");aura_mat=aura.material
	aura_mat.set_shader_parameter("tint",tint);aura.z_index=1
	impact_aura=rect_shader("res://scripts/shaders/amulet_aura.gdshader");impact_mat=impact_aura.material
	impact_mat.set_shader_parameter("tint",tint);impact_aura.z_index=3
	view=SubViewport.new();view.transparent_bg=true;view.disable_3d=true
	view.size=Vector2i((target_card.size+PAD*2)*3)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(view)
	var clone=Card.new();clone.card=target_card.card.duplicate(true);clone.card_size=target_card.size
	clone.size=target_card.size;clone.compact=target_card.compact;clone.death=target_card.death
	clone.priority_bonus=target_card.priority_bonus;clone.action_status="";clone.selected=false
	clone.add_theme_font_override("font",target_card.get_theme_font("font"))
	view.add_child(clone);clone.position=PAD*3;clone.scale=Vector2.ONE*3
	clone.set_process(false);clone.mouse_filter=Control.MOUSE_FILTER_IGNORE
	face=TextureRect.new();face.texture=view.get_texture();face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode=TextureRect.STRETCH_SCALE;face.mouse_filter=Control.MOUSE_FILTER_IGNORE
	face_mat=ShaderMaterial.new();face_mat.shader=preload("res://scripts/shaders/amulet_burn.gdshader");face.material=face_mat
	face_mat.set_shader_parameter("ember_color",tint);face_mat.set_shader_parameter("hot_color",hot)
	face_mat.set_shader_parameter("variant",float(variant))
	face_mat.set_shader_parameter("face_origin",PAD/(target_card.size+PAD*2))
	face_mat.set_shader_parameter("face_size",target_card.size/(target_card.size+PAD*2))
	add_child(face);face.z_index=2
	smoke=rect_shader("res://scripts/shaders/amulet_smoke.gdshader");smoke_mat=smoke.material;smoke.z_index=4
	smoke_mat.set_shader_parameter("tint",[Color("665d4f"),Color("534843"),Color("635567")][variant])
	beam=rect_shader("res://scripts/shaders/amulet_beam.gdshader");beam_mat=beam.material;beam.z_index=5
	beam_mat.set_shader_parameter("tint",tint);beam_mat.set_shader_parameter("hot",hot)
	beam_mat.set_shader_parameter("variant",float(variant))
	portrait=TextureRect.new();portrait.texture=Art.texture(key);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_SCALE;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(portrait);portrait.z_index=6
	particles=Control.new();particles.z_index=7;particles.mouse_filter=Control.MOUSE_FILTER_IGNORE
	particles.draw.connect(_draw_particles);particles.set_meta("particles",true);add_child(particles)
	present(0.)

func present(seconds:float)->void:
	age=seconds
	var inv=fx.get_global_transform().affine_inverse()
	var st=inv*source_card.get_global_transform()
	source=st*source_card.emblem_center()
	var source_side=minf(source_card.size.x-25,42 if source_card.compact else 46)*st.get_scale().x
	var tr=inv*target_card.get_global_transform()
	area=Rect2(tr*Vector2.ZERO,target_card.size*tr.get_scale());hit=area.get_center()+Vector2(0,-area.size.y*.01)
	var friendly=int(fx.event.action.actor)/3==fx.mine
	# Follow the illustrated torso, which faces slightly right of the base center.
	chest=Layout.pawn_center(int(fx.event.action.actor),friendly)+Vector2(6 if friendly else 4,9)
	lift=smoothstep(LIFT_START,LIFT_END,age);release=smoothstep(RETURN_START,RETURN_END,age)
	port=source.lerp(chest,lift)+Vector2(22*sin(lift*PI),-22*sin(lift*PI))
	port=port.lerp(source,release)+Vector2(-14*sin(release*PI),-18*sin(release*PI))
	var settle=sin((age-LIFT_END)*8.)*exp(-(age-LIFT_END)*7.) if age>LIFT_END else 0.
	port.y+=settle*3*(1.-release)
	side=lerpf(source_side,57. if int(fx.event.action.actor)/3==fx.mine else 49.,lift*(1.-release))
	var dimensions=portrait.texture.get_size();portrait.size=dimensions*(side/maxf(dimensions.x,dimensions.y))
	portrait.pivot_offset=portrait.size*.5;portrait.position=port-portrait.size*.5
	portrait.rotation=-.16*sin(lift*PI)*(1.-release)+.11*sin(release*PI)
	portrait.visible=age<RETURN_END
	source_card.motif_alpha=0. if age<RETURN_END else 1.;source_card.queue_redraw()
	charge=smoothstep(1.06,FIRE_START,age)*(1.-smoothstep(FIRE_OFF,FIRE_OFF+.36,age))
	portrait.self_modulate=Color.WHITE.lerp(hot,.16*charge)
	aura.position=port-Vector2(77,77);aura.size=Vector2(154,154)
	aura_mat.set_shader_parameter("strength",charge*.62+sin(lift*PI)*.19)
	aura_mat.set_shader_parameter("clock_time",age)
	face.position=area.position-PAD*tr.get_scale();face.size=(target_card.size+PAD*2)*tr.get_scale()
	target_card.modulate.a=0.
	burn=clampf((age-HIT)/(BURN_END-HIT),0.,1.)
	face_mat.set_shader_parameter("progress",burn);face_mat.set_shader_parameter("clock_time",age)
	face_mat.set_shader_parameter("ember_amount",smoothstep(HIT,HIT+.13,age)*(1.-smoothstep(BURN_END-.30,BURN_END+.16,age)))
	if is_instance_valid(target_card.status_label):target_card.status_label.modulate.a=1.-smoothstep(HIT,HIT+.4,age)
	var emit=port+Vector2(0,side*.075);var axis=hit-emit
	beam.position=emit+Vector2(0,-48).rotated(axis.angle());beam.size=Vector2(axis.length(),96);beam.rotation=axis.angle()
	beam_mat.set_shader_parameter("head",clampf((age-FIRE_START)/(HIT-FIRE_START),0.,1.))
	beam_mat.set_shader_parameter("tail",clampf((age-FIRE_OFF)/(HIT-FIRE_START),0.,1.))
	beam_mat.set_shader_parameter("strength",smoothstep(FIRE_START,FIRE_START+.035,age)*(1.-smoothstep(FIRE_OFF+.24,FIRE_OFF+.29,age)))
	beam_mat.set_shader_parameter("clock_time",age)
	impact_aura.position=hit-Vector2(95,95);impact_aura.size=Vector2(190,190)
	var ignition=exp(-maxf(age-HIT,0.)*7.) if age>=HIT else 0.
	impact_mat.set_shader_parameter("strength",ignition*.85+smoothstep(HIT,HIT+.12,age)*(1.-smoothstep(3.,3.5,age))*.22)
	impact_mat.set_shader_parameter("clock_time",age)
	smoke.size=Vector2(area.size.x*2.4,area.size.y*2.25);smoke.position=hit-Vector2(smoke.size.x*.5,smoke.size.y*.82)
	smoke_mat.set_shader_parameter("clock_time",age-HIT)
	smoke_mat.set_shader_parameter("strength",smoothstep(HIT+.32,HIT+1.2,age)*(1.-smoothstep(BURN_END-.05,BURN_END+.7,age)))
	for child in get_children():
		if child.has_meta("particles"):child.queue_redraw()
	queue_redraw()

func _draw_particles()->void:
	draw_particles(particles)

func randf_fixed(i:float)->float:return fposmod(sin(i*127.1+27.3)*43758.5453,1.)

func soft_spark(c:Control,at:Vector2,r:float,color:Color,alpha:float,velocity=Vector2.ZERO)->void:
	if alpha<.002:return
	c.draw_circle(at,r*2.7,Color(color,alpha*.055),true,-1.,true)
	c.draw_circle(at,r*1.6,Color(color,alpha*.15),true,-1.,true)
	if velocity.length()>2.:c.draw_line(at-velocity*.027,at,Color(color,alpha*.30),r*.8,true)
	c.draw_circle(at,maxf(.38,r*.43),Color(hot,alpha*.88),true,-1.,true)

func draw_particles(c:Control)->void:
	if age>LIFT_START and age<LIFT_END+.35:
		for i in range(18):
			var lag=i*.019;var u=smoothstep(LIFT_START,LIFT_END,age-lag)
			if u<=0. or u>=1.:continue
			var p=source.lerp(chest,u)+Vector2(22*sin(u*PI),-22*sin(u*PI))
			p+=Vector2(sin(i*8.1),cos(i*4.3))*3
			soft_spark(c,p,1.1,tint,(1.-i/18.)*.32)
	if age>1.05 and age<FIRE_OFF+.1:
		for i in range(25):
			var u=fposmod(age*.83+i*.117,1.);var a=i*2.39996+age*.18;var r=lerpf(48.,9.,u)
			soft_spark(c,port+Vector2.from_angle(a)*Vector2(r,r*.76),.65+randf_fixed(i)*.65,tint,sin(u*PI)*charge*.46)
	if age>=FIRE_START and age<FIRE_OFF+.25:
		var a=port+Vector2(0,side*.075);var d=hit-a;var perpendicular=d.normalized().orthogonal()
		var head=clampf((age-FIRE_START)/.25,0.,1.);var tail=clampf((age-FIRE_OFF)/.25,0.,1.)
		for i in range(19):
			var u=fposmod(age*1.9+i*.197,1.)
			if u>head or u<tail:continue
			soft_spark(c,a+d*u+perpendicular*sin(u*20.-age*9.+i)*(.8+variant*1.4),.7+randf_fixed(i)*.7,tint,.26,d.normalized()*155.)
	for i in range(95):
		var spawn=HIT+(i/95.)*(BURN_END-HIT-.20);var t=age-spawn;var lifetime=.42+randf_fixed(i+40)*.58
		if t<0. or t>lifetime:continue
		var phase=(spawn-HIT)/(BURN_END-HIT);var angle=i*2.39996+.17;var radius=phase*.73*area.size.y
		var p=hit+Vector2(cos(angle)*radius/.74,sin(angle)*radius)
		if not area.grow(2).has_point(p):continue
		var v=Vector2((randf_fixed(i+71)-.5)*36.,-26.-randf_fixed(i+53)*42.)
		p+=v*t+Vector2(sin(t*8.+i)*t*7.,t*t*8.)
		var alpha=sin(clampf(t/lifetime,0.,1.)*PI)*.82;var r=.75+randf_fixed(i+13)*1.5
		soft_spark(c,p,r,tint,alpha,v)
		if i%3==0:
			var rot=age*2.3+i
			var shard=PackedVector2Array([Vector2(-r,-r*.4),Vector2(r*.8,-r*.7),Vector2(r*.4,r*.9)])
			for j in range(3):shard[j]=p+shard[j].rotated(rot)
			c.draw_colored_polygon(shard,Color(Color("58433b").lerp(tint,.35*(1.-t/lifetime)),alpha*.65))
	if age>=HIT and age<HIT+.45:
		var t=age-HIT
		for i in range(17):
			var v=Vector2.from_angle(i*2.39996)*(38.+randf_fixed(i)*92.)
			soft_spark(c,hit+v*t,1.1,tint,(1.-t/.45)*.8,v)

func dispose()->void:
	if is_instance_valid(source_card):source_card.motif_alpha=source_alpha;source_card.queue_redraw()
	if is_instance_valid(target_card):
		target_card.modulate.a=target_alpha
		if is_instance_valid(target_card.status_label):target_card.status_label.modulate.a=1.
	if is_instance_valid(face):face.texture=null;face.material=null
	fx=null
