extends "res://scripts/cinema/cinema.gd"
const GemPalette=preload("res://scripts/gem_timing.gd")
var chest=Vector2.ZERO
var base=Vector2.ZERO
var age=0.
var gem_side=54.
var port=Vector2.ZERO
var lift=0.
var release=0.
var pulse=0.
var facet:TextureRect
var facet_mat:ShaderMaterial
var motes:Control
var aura:ColorRect
var aura_mat:ShaderMaterial
var source_side=46.
var initial_source=Vector2.ZERO
var return_start=2.52
var return_end=3.10
var hp_gain=2
var effect_end=3.45
var pawn_sprite
func configure(table,gem,owner,origin,side):
	board=table;mine=table.mine;key=gem;actor=owner;source=origin;initial_source=origin;source_side=side
	chest=pawn(actor)+Vector2(6 if actor/3==mine else 4,9);base=pawn(actor)+Vector2(0,54)
	accent=Color(GemPalette.COLORS[key]);ink=accent.darkened(.55)
	mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(1440,960);z_index=85;set_process(false)
	for node in board.canvas.get_children():
		if node.get_meta("knight_id",-1)==actor:pawn_sprite=node.get_child(0)
	if key=="sapphire":return_start=2.05;return_end=2.64
	if key=="emerald":return_start=3.00;return_end=3.58
	if key=="amber":hp_gain=3
	if key=="amethyst":hp_gain=1
	aura=ColorRect.new();aura.mouse_filter=Control.MOUSE_FILTER_IGNORE;aura_mat=ShaderMaterial.new();aura_mat.shader=preload("res://scripts/shaders/amulet_aura.gdshader");aura.material=aura_mat;add_child(aura);aura_mat.set_shader_parameter("tint",accent)
	facet=TextureRect.new();facet.texture=Art.texture(key);facet.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;facet.stretch_mode=TextureRect.STRETCH_SCALE;facet.mouse_filter=Control.MOUSE_FILTER_IGNORE
	facet_mat=ShaderMaterial.new();facet_mat.shader=preload("res://scripts/shaders/gem_glint.gdshader");facet_mat.set_shader_parameter("tint",accent);facet.material=facet_mat;add_child(facet)
	motes=Control.new();motes.mouse_filter=Control.MOUSE_FILTER_IGNORE;motes.draw.connect(draw_motes);add_child(motes)
	present(0.)
func present(seconds):
	age=seconds;t=seconds;lift=smoothstep(.22,.92,age);release=smoothstep(return_start,return_end,age)
	port=initial_source.lerp(chest,lift)+Vector2(20,-28)*sin(lift*PI)
	port=port.lerp(initial_source,release)+Vector2(-10,-20)*sin(release*PI)
	if age>.92:port.y+=sin((age-.92)*10.)*exp(-(age-.92)*7.)*2.2*(1-release)
	gem_side=lerpf(source_side,54. if actor/3==mine else 45.,lift*(1.-release))
	pulse=sin(smoothstep(1.,1.45,age)*PI)
	var texsize=facet.texture.get_size();facet.size=texsize*(gem_side/maxf(texsize.x,texsize.y));facet.pivot_offset=facet.size*.5;facet.position=port-facet.size*.5
	facet.rotation=-.12*sin(lift*PI)*(1-release)+.09*sin(release*PI);facet.visible=age>=.22 and age<return_end
	facet_mat.set_shader_parameter("pulse",pulse);facet_mat.set_shader_parameter("sweep",lerpf(-.3,1.6,smoothstep(.92,1.52,age)))
	aura.position=port-Vector2(60,60);aura.size=Vector2(120,120)
	aura_mat.set_shader_parameter("clock_time",age);aura_mat.set_shader_parameter("strength",(pulse*.50+smoothstep(.8,1.,age)*(1.-smoothstep(return_start-.3,return_end,age))*.13) if facet.visible else 0.)
	if key=="amethyst" and age>=1.52 and is_instance_valid(pawn_sprite):pawn_sprite.modulate=Color(.70,.65,.78,.55).lerp(Color.WHITE,smoothstep(1.52,1.95,age))
	queue_redraw();motes.queue_redraw()
func hashf(n):return fposmod(sin(n*127.1+27.3)*43758.5453,1.)
func sparkle(canvas,p,r,alpha,tint):
	if alpha<.003:return
	var pts=PackedVector2Array()
	for j in range(8):pts.append(p+Vector2.from_angle(j*PI/4)*(r if j%2==0 else r*.13))
	canvas.draw_colored_polygon(pts,Color(tint,alpha))
func draw_motes():
	if age<.22 or age>return_end+.2:return
	var envelope=smoothstep(.22,.52,age)*(1.-smoothstep(return_start,return_end+.2,age))
	for i in range(25):
		var seed=hashf(i+key.length()*31);var life=fposmod(age*.53+seed,1.)
		var radius=12.+seed*22.+life*8.;var angle=i*2.39996+age*(.22+seed*.3)
		var p=port+Vector2(cos(angle)*radius,sin(angle)*radius*.66-life*8.)
		var alpha=sin(life*PI)*envelope*(.26+.48*pulse);var r=.65+hashf(i+32)*1.1
		motes.draw_circle(p,r*2.2,Color(accent,alpha*.12),true,-1,true)
		motes.draw_circle(p,r,Color(accent.lightened(.65),alpha),true,-1,true)
		if i%7==0:sparkle(motes,p,r*3.6,alpha*.7,accent.lightened(.85))
	if pulse>.01:
		sparkle(motes,port+Vector2(-gem_side*.14,-gem_side*.22),4.+7.*pulse,pulse*.9,Color("fff9ee"))
		sparkle(motes,port+Vector2(gem_side*.27,gem_side*.04),2.+3.*pulse,pulse*.7,accent.lightened(.7))
func _draw():
	if age<.22:return
	var attach=smoothstep(.25,.9,age)*(1-smoothstep(return_start,return_end,age))
	glow(chest,57,attach*.11,accent)
	var effect=smoothstep(1.24,1.50,age)*(1-smoothstep(2.38,3.30,age))
	if key in ["ruby","amber","amethyst"] and hp_gain<=0:effect=0.
	if key in ["ruby","amber","amethyst"]:
		var revive=key=="amethyst"
		glow(pawn(actor)+Vector2(0,25),92,effect*.17,accent)
		# Fine braided light follows the volume of the illustrated figure.
		for side in [-1,1]:
			var points=PackedVector2Array();var extent=smoothstep(1.26,1.95,age)
			for j in range(55):
				var v=j/54.*extent;var theta=v*TAU*1.2-age*2.2+side*PI
				points.append(base+Vector2(sin(theta)*(32.+9.*v),-v*112.))
			ribbon(points,2.8 if revive else 2.1,effect*.45,accent.lightened(.3))
		for i in range(28):
			var life=fposmod((age-1.25)*.52+hashf(i*3),1.)
			var q=base+Vector2((hashf(i*5+1)-.5)*90.+sin(life*5.+i)*8.,-life*118.)
			glow(q,3.2+hashf(i)*2.,sin(life*PI)*effect*.40,accent.lightened(.5))
		if age>=1.52 and hp_gain>0:
			label_at(pawn(actor)+Vector2(60,-30-smoothstep(1.52,2.9,age)*20),"+%d"%hp_gain,accent.lightened(.7),(1-smoothstep(2.1,2.85,age))*.95,23)
		if revive:
			var v=smoothstep(1.20,2.10,age)
			ellipse(base,45+v*13,10+v*4,Color(accent,effect*.3))
	elif key in ["sapphire","emerald"]:
		# A travelling packet of fine, irregular strands reaches the chest at
		# the exact start of the draw, then dissolves instead of holding a cable.
		for strand in range(3):
			var delay=strand*.023
			var head=clampf((age-1.02-delay)/.30,0.,1.)
			var tail=clampf((age-1.15-delay)/.30,0.,1.)
			var alpha=smoothstep(1.02+delay,1.08+delay,age)*(1-smoothstep(1.35+delay,1.48+delay,age))
			var points=PackedVector2Array()
			for j in range(45):
				var v=lerpf(tail,head,j/44.);var p=bezier(chest,DECK,v,-72.)
				p+=Vector2(sin(v*29.+strand*2.+age*13.)*1.2,cos(v*19.+strand*2.-age*10.)*2.2)*sin(v*PI)
				points.append(p)
			ribbon(points,2.5-strand*.6,alpha*(.57-strand*.1),accent.lightened(strand*.12))
			for i in range(14):
				var v=lerpf(tail,head,hashf(i+strand*17));var p=bezier(chest,DECK,v,-72.)
				p+=Vector2(sin(i*2.+age*4.),cos(i*3.-age*7.))*(2.+hashf(i+8)*5.)
				glow(p,1.5+hashf(i)*3.,alpha*.46,accent.lightened(.55))
		glow(DECK,62.,smoothstep(1.25,1.34,age)*(1-smoothstep(1.45,1.9,age))*.24,accent)
	elif key=="topaz":
		var v=smoothstep(1.5,2.35,age);var p=bezier(chest,crest(),v,-92)
		var a=smoothstep(1.32,1.53,age)*(1-smoothstep(2.36,2.64,age))
		glow(p,48,a*.23,accent);prop("badge",p,lerpf(41,24,v),sin(v*PI)*.32,a)
		for i in range(15):
			var q=bezier(chest,crest(),maxf(0,v-i*.012),-92)
			glow(q+Vector2(sin(i*4.)*3.,cos(i*3.)*3.),2.+hashf(i)*2.,a*(1-i/15.)*.38,accent)
		if age>2.3:glow(crest(),44,(1-smoothstep(2.3,2.8,age))*.42,accent)
func _exit_tree():pass
