extends Control
## Deterministic tablecloth particles, always behind the playing pieces and cards.
var progress=0.0
var seconds=0.0
var restoring=false
var active=false
var rows=[]
var glow_texture:GradientTexture2D

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(1440,960)
	set_process(false)
	rows=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/reverse_cloth_rows.json"))
	var gradient=Gradient.new()
	gradient.offsets=PackedFloat32Array([0.0,0.16,0.38,0.68,1.0])
	gradient.colors=PackedColorArray([Color(1,1,1,1),Color(1,1,1,.70),Color(1,1,1,.22),Color(1,1,1,.04),Color(1,1,1,0)])
	glow_texture=GradientTexture2D.new();glow_texture.width=96;glow_texture.height=96
	glow_texture.gradient=gradient;glow_texture.fill=GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from=Vector2(.5,.5);glow_texture.fill_to=Vector2(1,.5)

func present(value,time_value,returning=false,enabled=true):
	progress=value;seconds=time_value;restoring=returning;active=enabled
	queue_redraw()

func noise(index,salt=0.0):return fposmod(sin(float(index)*127.1+salt*311.7)*43758.5453,1.0)

func glow(at,dimensions,color):
	draw_texture_rect(glow_texture,Rect2(at-dimensions*.5,dimensions),false,color)

func inside_cloth(at,margin=48.0):
	var y=clampi(roundi(at.y/0.9375),0,1023)
	return y>110 and y<980 and at.x>float(rows[y][0])*.9375+margin and at.x<float(rows[y][1])*.9375-margin

func _draw():
	if not active or progress<=0.0 or progress>=1.0:return
	var front=lerpf(1.075,-.075,progress) if restoring else lerpf(-.075,1.075,progress)
	var native_y=103.0+887.0*front
	var y=native_y*.9375
	var envelope=smoothstep(101,145,native_y)*(1.0-smoothstep(930,992,native_y))
	if envelope<.002:return
	var row=rows[clampi(roundi(native_y),0,1023)]
	var left=float(row[0])*.9375+65.0
	var right=float(row[1])*.9375-65.0
	if right-left<150:return
	var direction=-1.0 if restoring else 1.0
	var aura=Color("eec987") if restoring else Color("c392fa")
	var bright=Color("fff1c4") if restoring else Color("f4ddff")
	# Short, breathing filaments catch the weave; there is no solid laser line.
	for i in range(23):
		var seed=noise(i,1);var center=lerpf(left+28,right-28,seed)
		var pulse=pow(.5+.5*sin(seconds*3.1+seed*TAU*4),2)
		var length=lerpf(23,57,noise(i,2))
		var at=Vector2(center,y+sin(center*.028+seconds)*3.5)
		glow(at,Vector2(length*1.9,13),Color(aura,.19*pulse*envelope))
		var points=PackedVector2Array();var colors=PackedColorArray()
		for j in range(15):
			var t=float(j)/14;points.append(at+Vector2((t-.5)*length,sin(t*PI)*(-2.5+noise(i,3)*5)))
			colors.append(Color(bright,sin(t*PI)*.48*pulse*envelope))
		draw_polyline_colors(points,colors,1.0,true)
	# Different lifetimes, drifting paths, sizes and colors avoid a row of dots.
	for i in range(108):
		var seed=noise(i,7)
		var life=fposmod(seconds*lerpf(.84,1.73,noise(i,8))+noise(i,9),1.0)
		var visibility=pow(sin(life*PI),1.45)*envelope
		if visibility<.012:continue
		var center=lerpf(left+10,right-10,seed)
		var depth=lerpf(4,47,noise(i,11))*pow(life,.7)
		var at=Vector2(center+sin(life*TAU+seed*12)*lerpf(2,13,noise(i,12)),y-direction*depth+sin(seed*31+life*5)*5)
		if not inside_cloth(at):continue
		var radius=lerpf(.75,2.6,pow(noise(i,13),2))
		var color=aura.lerp(bright,noise(i,14)*.8)
		if not restoring and i%7==0:color=Color("f5d79d")
		glow(at,Vector2.ONE*radius*9,Color(color,visibility*.27))
		glow(at,Vector2.ONE*radius*3.3,Color(bright,visibility*.85))
		draw_circle(at,radius*.40,Color(bright,visibility*.94))
		if i%9==0:
			var flare=pow(sin(life*PI),6)*envelope
			var half=radius*2.6
			draw_line(at-Vector2(half,0),at+Vector2(half,0),Color(bright,flare*.75),.8,true)
			draw_line(at-Vector2(0,half*.70),at+Vector2(0,half*.70),Color(bright,flare*.50),.8,true)
		if i%4==0:
			var tail=PackedVector2Array([at-Vector2(3,direction*8),at-Vector2(1,direction*4),at])
			draw_polyline_colors(tail,PackedColorArray([Color(color,0),Color(color,visibility*.18),Color(bright,visibility*.55)]),1,true)
